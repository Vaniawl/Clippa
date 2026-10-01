"""Team compatibility, ownership, capability reporting and real-event smoke gates."""
from __future__ import annotations

import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tomllib
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _helpers import REPO_ROOT, copy_repo, render, scratch_dir, validate
import yaml


def module(name, script):
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / 'scripts/agent-framework' / script)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


class TeamRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = scratch_dir()
        self.repo = copy_repo(self.tmp / 'repo')

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def set_team(self, team):
        path = self.repo / 'project.yaml'
        data = yaml.safe_load(path.read_text())
        data.setdefault('agent_framework', {})['team'] = team
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def test_team_config_named_agents_and_model_inheritance(self):
        self.set_team({'default_mode': 'advise', 'max_parallel_workers': 2})
        result = render(self.repo)
        self.assertEqual(result.returncode, 0, result.stderr)
        config = tomllib.loads((self.repo / '.codex/config.toml').read_text())
        self.assertEqual(config['agents']['max_concurrent_threads_per_session'], 2)
        for path in (self.repo / '.codex/agents').glob('*.toml'):
            data = tomllib.loads(path.read_text())
            self.assertEqual(data['name'], path.stem)
            self.assertTrue(data['description'])
            self.assertIn('may_delegate', data['developer_instructions'])
            self.assertNotIn('model', data)
            self.assertNotIn('model_reasoning_effort', data)
            self.assertNotIn('select the model per the delegation policy tiering rules', data['developer_instructions'])
        for path in (self.repo / '.claude/agents').glob('*.md'):
            frontmatter = path.read_text().split('---')[1]
            self.assertEqual(yaml.safe_load(frontmatter)['model'], 'inherit')

    def test_legacy_missing_team_retains_existing_concurrency_and_claude_tiering(self):
        path = self.repo / 'project.yaml'
        data = yaml.safe_load(path.read_text())
        data.setdefault('agent_framework', {}).pop('team', None)
        path.write_text(yaml.safe_dump(data))
        self.assertEqual(render(self.repo).returncode, 0)
        config = tomllib.loads((self.repo / '.codex/config.toml').read_text())
        self.assertNotIn('agents', config)
        role = (self.repo / '.claude/agents/code-reviewer.md').read_text().split('---')[1]
        self.assertIn(yaml.safe_load(role)['model'], ('opus', 'sonnet', 'haiku'))

    def test_invalid_team_rejected_before_writes_and_by_validator(self):
        for team in ({'default_mode': 'unknown'}, {'max_parallel_workers': 0}, {'max_parallel_workers': 4},
                     {'max_parallel_workers': True}, {'max_parallel_workers': 1.5}, None, {'unexpected': True}):
            with self.subTest(team=team):
                self.set_team(team)
                config = (self.repo / '.codex/config.toml').read_bytes()
                result = render(self.repo)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.repo / '.codex/config.toml').read_bytes(), config)
                checked = validate(self.repo)
                self.assertNotEqual(checked.returncode, 0)
                self.assertIn('agent_framework.team', checked.stdout)

    def test_local_codex_overrides_preserved_by_refusal(self):
        self.assertEqual(render(self.repo).returncode, 0)
        path = self.repo / '.codex/config.toml'
        content = path.read_text() + '\nmodel = "local-override"\n'
        path.write_text(content)
        result = render(self.repo)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(path.read_text(), content)
        self.assertIn('locally modified Codex overrides', result.stderr)

    def test_unmanaged_local_codex_agent_preserved(self):
        path = self.repo / '.codex/agents/local.toml'
        content = 'name="local"\ndescription="local role"\ndeveloper_instructions="read only"\n'
        path.write_text(content)
        self.assertEqual(render(self.repo).returncode, 0)
        self.assertEqual(path.read_text(), content)

    def test_validator_requires_native_named_fields(self):
        path = self.repo / '.codex/agents/code-reviewer.toml'
        path.write_text('name="code-reviewer"\ndescription="review"\n')
        result = validate(self.repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('requires a non-empty developer_instructions', result.stdout)

    def test_preflight_no_mutations_and_malformed_report(self):
        checker = module('team_checker', 'check-team.py')
        with mock.patch.object(checker, 'probe', return_value={'status':'UNAVAILABLE'}), mock.patch.object(checker.shutil,'which',return_value=None):
            before = (self.repo / '.codex/config.toml').read_bytes()
            report = checker.preflight(self.repo)
            self.assertEqual(report['native_execution'], 'NOT RUN')
            self.assertEqual(before, (self.repo / '.codex/config.toml').read_bytes())
            path = self.repo / 'project.yaml'
            path.write_text('agent_framework: [ invalid')
            report = checker.preflight(self.repo)
            self.assertEqual(report['structural'], 'FAIL')
            role = self.repo / '.codex/agents/code-reviewer.toml'
            role.write_text('broken = [')
            report = checker.preflight(self.repo)
            self.assertEqual(report['checks']['agents']['status'], 'FAIL')

    def test_session_inventory_separates_configuration_and_availability_without_secrets(self):
        checker = module('team_inventory', 'check-team.py')
        payload = {'config/read': {'config': {'web_search': 'live', 'mcp_servers': {
            'docs': {'url': 'https://invalid/?token=PRIVATE', 'http_headers': {'Authorization': 'SECRET'}}}}},
            'mcpServerStatus/list': {'data': [
                {'name': 'docs', 'runtimeStatus': 'connected', 'authStatus': 'oAuth', 'tools': {'fetch_docs': {'secret': 'PRIVATE'}}},
                {'name': 'offline', 'runtimeStatus': 'failed', 'authStatus': 'unknown', 'tools': {'cached_tool': {}}}], 'nextCursor': None}}
        transport = mock.Mock()
        transport.run_appserver.return_value = checker.subprocess.CompletedProcess([], 0, json.dumps(payload), '')
        with mock.patch.object(checker, 'smoke_tools', return_value=transport):
            report = checker.session_inventory('/unused', self.repo)
        self.assertEqual(report['mcp_servers'][0]['available_tools'], ['fetch_docs'])
        self.assertEqual(report['mcp_servers'][1]['available_tools'], [])
        self.assertEqual(report['web_search']['available'], 'NOT VERIFIED')
        self.assertEqual(report['web_search']['live_retrieval'], 'NOT RUN')
        self.assertNotIn('SECRET', json.dumps(report))
        self.assertNotIn('PRIVATE', json.dumps(report))
        self.assertNotIn('http_headers', json.dumps(report))

    def test_final_prose_empty_tools_and_error_results_do_not_prove_retrieval(self):
        checker = module('team_retrieval', 'check-team.py')
        source = ('https://learn.chatgpt.com/docs/agent-configuration/subagents\n# Subagents\n'
                  'Every standalone custom agent file must define name, description, and developer_instructions. '
                  'These fields identify the custom agent, explain when to use it, and supply its behavioral instructions.')
        def event(item):
            return {'method': 'item/completed', 'params': {'item': item}}
        self.assertEqual(checker.retrieval_evidence([event({'type': 'agentMessage', 'text': source})])['status'], 'NOT VERIFIED')
        item = {'type': 'mcpToolCall', 'status': 'completed', 'server': 'docs', 'tool': 'fetch_docs',
                'result': {'content': [{'type': 'text', 'text': source}]}}
        self.assertEqual(checker.retrieval_evidence([event(item)])['status'], 'VERIFIED')
        item['tool'] = 'search_docs'
        self.assertEqual(checker.retrieval_evidence([event(item)])['status'], 'NOT VERIFIED')
        item['tool'] = 'fetch_docs'
        item['result']['isError'] = True
        self.assertEqual(checker.retrieval_evidence([event(item)])['status'], 'NOT VERIFIED')
        item['result'] = {'content': []}
        self.assertEqual(checker.retrieval_evidence([event(item)])['status'], 'NOT VERIFIED')

    def test_search_metadata_cannot_certify_page_retrieval(self):
        checker = module('team_retrieval_metadata', 'check-team.py')
        metadata = {'results': [{'url': 'https://learn.chatgpt.com/docs/agent-configuration/subagents',
                    'title': 'Standalone subagents configuration',
                    'snippet': 'Standalone custom agents have name, description, developer_instructions. Search index excerpt only; the source page has not been retrieved.',
                    'score': 0.94}]}
        item = {'type': 'mcpToolCall', 'status': 'completed', 'server': 'docs',
                'tool': 'retrieve_search_results', 'result': {'content': [{'type': 'text', 'text': json.dumps(metadata)}]}}
        def evidence():
            return checker.retrieval_evidence([{'method': 'item/completed', 'params': {'item': item}}])['status']
        self.assertEqual(evidence(), 'NOT VERIFIED')
        # A known page tool returning search metadata is also insufficient.
        item['tool'] = 'fetch_openai_doc'
        self.assertEqual(evidence(), 'NOT VERIFIED')
        document = {'url': metadata['results'][0]['url'], 'markdown': '# Subagents\n\nEvery standalone custom agent defines name, description, and developer_instructions.\n'}
        item['result']['content'][0]['text'] = json.dumps(document)
        self.assertEqual(evidence(), 'VERIFIED')
        document['markdown'] = 'Standalone custom agents have name, description, and developer_instructions.'
        item['result']['content'][0]['text'] = json.dumps(document)
        self.assertEqual(evidence(), 'NOT VERIFIED')

    def test_retrieved_page_requires_explicit_exact_official_origin(self):
        checker = module('team_retrieval_origin', 'check-team.py')
        official = 'https://learn.chatgpt.com/docs/agent-configuration/subagents'
        body = '# Subagents\nEvery standalone custom agent defines name, description and developer_instructions.'
        item = {'type': 'mcpToolCall', 'status': 'completed', 'server': 'docs', 'tool': 'fetch_openai_doc',
                'result': {'content': [{'type': 'text', 'text': ''}]}}
        def evidence(text):
            item['result']['content'][0]['text'] = text
            return checker.retrieval_evidence([{'method': 'item/completed', 'params': {'item': item}}])['status']
        self.assertEqual(evidence(json.dumps({'url': official, 'markdown': body})), 'VERIFIED')
        for url in ('https://attacker.invalid/learn.chatgpt.com/docs/agent-configuration/subagents',
                    'https://attacker.invalid/?source=' + official,
                    'https://learn.chatgpt.com/?source=' + official,
                    'http://learn.chatgpt.com/docs/agent-configuration/subagents'):
            with self.subTest(url=url):
                self.assertEqual(evidence(json.dumps({'url': url, 'markdown': body})), 'NOT VERIFIED')
        self.assertEqual(evidence(body + '\nRelated documentation: ' + official), 'NOT VERIFIED')
        self.assertEqual(evidence('Source: ' + official + '\n' + body), 'VERIFIED')

    def test_session_query_does_not_start_model_turn_or_expose_failed_trace(self):
        smoke = module('team_query_transport', 'smoke-team.py')
        process = mock.Mock()
        process.stdin = io.StringIO()
        process.stdout = io.StringIO('\n'.join(json.dumps(message) for message in [
            {'id': 1, 'result': {}}, {'id': 2, 'result': {'thread': {'id': 'ephemeral'}}},
            {'id': 3, 'result': {'data': []}},
        ]) + '\n')
        process.stderr = io.StringIO('')
        with mock.patch.object(smoke.subprocess, 'Popen', return_value=process), mock.patch.object(smoke, 'stop_process_group'):
            smoke.run_appserver('/unused', self.repo, None, 5, queries=[{'method': 'mcpServerStatus/list', 'thread_scoped': True}])
        requests = [json.loads(line) for line in process.stdin.getvalue().splitlines()]
        self.assertNotIn('turn/start', [request.get('method') for request in requests])
        start = next(request for request in requests if request.get('method') == 'thread/start')
        self.assertTrue(start['params']['ephemeral'])
        self.assertEqual(start['params']['sandbox'], 'read-only')
        process.stdout = io.StringIO('{"private":"SECRET"}\n')
        process.stderr = io.StringIO('private SECRET')
        with mock.patch.object(smoke.subprocess, 'Popen', return_value=process), mock.patch.object(smoke, 'stop_process_group'):
            with self.assertRaises(RuntimeError) as raised:
                smoke.run_appserver('/unused', self.repo, None, 5, queries=[])
        self.assertEqual(raised.exception.output, '')
        self.assertEqual(raised.exception.stderr, '')

    def test_smoke_requires_real_events_not_narrative(self):
        smoke = module('team_smoke', 'smoke-team.py')
        events = [{'type':'item.completed','item': {'type':'agent_message','text':'I spawned and waited. marker'}},
                  {'type':'turn.completed'}]
        report = smoke.verify_events(events, ['marker'])
        self.assertFalse(report['real_spawn'])
        self.assertFalse(report['real_wait'])
        events += [{'type':'item.completed','item': {'id':'one','type':'collab_tool_call','tool':'spawn_agent',
                    'status':'completed','receiver_thread_ids':['worker'],'model':None}},
                   {'type':'item.completed','item': {'id':'two','type':'collab_tool_call','tool':'wait','status':'completed'}}]
        report = smoke.verify_events(events,['marker'])
        self.assertTrue(report['real_spawn'])
        self.assertTrue(report['real_wait'])
        self.assertEqual(report['explicit_model_overrides'], [])
        self.assertEqual(report['spawned_receiver_ids'], ['worker'])
        self.assertFalse(report['workers_completed'])
        events[-1]['item']['agents_states'] = {'worker': {'status':'errored','message':'marker'}}
        report = smoke.verify_events(events, ['marker'])
        self.assertFalse(report['workers_completed'])
        self.assertFalse(report['role_instruction_propagation'])
        events[-1]['item']['agents_states'] = {'worker': {'status':'completed','message':'marker'}}
        report = smoke.verify_events(events, ['marker'])
        self.assertTrue(report['workers_completed'])
        self.assertTrue(report['role_instruction_propagation'])
        self.assertEqual(report['completed_worker_ids'], ['worker'])

    def test_raw_appserver_correlates_actual_child_and_rejects_failed_terminal(self):
        smoke = module('team_smoke_raw', 'smoke-team.py')
        events = [
            {'id':2,'result':{'thread':{'id':'main'}}},
            {'method':'rawResponseItem/completed','params':{'item':{'type':'function_call','name':'spawn_agent','call_id':'spawn','arguments':'{"task_name":"reviewer","agent_type":"default"}'}}},
            {'method':'item/completed','params':{'threadId':'main','item':{'type':'subAgentActivity','kind':'started','id':'spawn','agentThreadId':'reviewer'}}},
            {'method':'turn/completed','params':{'threadId':'reviewer','turn':{'id':'child-turn','status':'completed','items':[{'type':'agentMessage','text':'marker'}]}}},
            {'method':'item/completed','params':{'item':{'type':'collabAgentToolCall','tool':'wait','status':'completed','agentsStates':{},'receiverThreadIds':[]}}},
            {'method':'turn/completed','params':{'threadId':'main','turn':{'status':'completed'}}},
        ]
        result = smoke.verify_events(events,['marker'])
        self.assertTrue(result['real_spawn'])
        self.assertTrue(result['workers_completed'])
        self.assertTrue(result['role_instruction_propagation'])
        self.assertEqual(result['completed_worker_ids'],['reviewer'])
        self.assertFalse(smoke.verify_events(events,['marker'],{'code-reviewer':'marker'})['role_instruction_propagation'])
        events[2]['params']['item']['agentPath'] = '/root/code_reviewer'
        self.assertTrue(smoke.verify_events(events,['marker'],{'code-reviewer':'marker'})['role_instruction_propagation'])
        events[3]['params']['turn']['status'] = 'failed'
        result = smoke.verify_events(events,['marker'])
        self.assertFalse(result['workers_completed'])
        self.assertFalse(result['role_instruction_propagation'])
        events[3]['params']['turn']['status'] = 'completed'
        events[-1]['params']['turn']['status'] = 'failed'
        self.assertFalse(smoke.verify_events(events,['marker'])['turn_completed'])

    def test_review_sequence_is_specific_to_author_role_and_final_author_completion(self):
        smoke = module('team_smoke_sequence', 'smoke-team.py')
        def spawned(worker, role):
            return {'method':'item/completed','params':{'item':{'type':'subAgentActivity','kind':'started','id':worker,'agentThreadId':worker,'agentPath':'/root/'+role}}}
        def completed(worker, marker):
            return {'method':'turn/completed','params':{'threadId':worker,'turn':{'id':worker+'-done','status':'completed','items':[{'type':'agentMessage','text':marker}]}}}
        reversed_events = [spawned('reviewer','code_reviewer'),completed('reviewer','review_marker'),
                           spawned('author','implementation_engineer'),completed('author','author_marker')]
        roles = {'implementation-engineer':'author_marker','code-reviewer':'review_marker'}
        self.assertFalse(smoke.verify_events(reversed_events,list(roles.values()),roles)['independent_review_sequence'])
        correct_events = [spawned('author','implementation_engineer'),completed('author','author_marker'),
                          spawned('reviewer','code_reviewer'),completed('reviewer','review_marker')]
        self.assertTrue(smoke.verify_events(correct_events,list(roles.values()),roles)['independent_review_sequence'])
        correct_events += [{'type':'item.completed','item':{'type':'collab_tool_call','tool':'wait','status':'completed',
                            'agents_states':{'author':{'status':'completed','message':'author_marker'}}}}]
        self.assertTrue(smoke.verify_events(correct_events,list(roles.values()),roles)['independent_review_sequence'])
        same_worker_rework = completed('author','author_marker')
        same_worker_rework['params']['turn']['id'] = 'second-author-turn'
        self.assertFalse(smoke.verify_events(correct_events + [same_worker_rework],list(roles.values()),roles)['independent_review_sequence'])
        correct_events += [spawned('rework','implementation_engineer'),completed('rework','author_marker')]
        self.assertFalse(smoke.verify_events(correct_events,list(roles.values()),roles)['independent_review_sequence'])

    def test_generic_marker_success_does_not_prove_native_named_discovery(self):
        smoke = module('team_smoke_named', 'smoke-team.py')
        result = {'scenario':'advise','status':'PASS','evidence':{'agent_types_observed':['default']}}
        self.assertFalse(smoke.named_discovery_verified([result]))
        result['evidence']['agent_types_observed'] = []
        self.assertFalse(smoke.named_discovery_verified([result]))
        result['evidence']['agent_types_observed'] = ['code-reviewer']
        self.assertTrue(smoke.named_discovery_verified([result]))

    def test_bounded_process_cleanup_on_interrupt_and_timeout(self):
        smoke = module('team_smoke_cleanup', 'smoke-team.py')
        for failure in (KeyboardInterrupt(), smoke.subprocess.TimeoutExpired(['fixture'], 1)):
            with self.subTest(failure=type(failure).__name__):
                process = mock.Mock()
                process.communicate.side_effect = failure
                with mock.patch.object(smoke.subprocess, 'Popen', return_value=process), mock.patch.object(smoke, 'stop_process_group') as cleanup:
                    with self.assertRaises(type(failure)):
                        smoke.run_bounded(['fixture'], 1)
                    cleanup.assert_called_once_with(process)

    def test_source_digest_excludes_ignored_artifacts(self):
        smoke = module('team_smoke_digest', 'smoke-team.py')
        repo = self.tmp / 'small-git'
        repo.mkdir()
        smoke.subprocess.run(['git','init','-q',str(repo)], check=True)
        (repo / '.gitignore').write_text('artifacts/\n')
        (repo / 'source.py').write_text('value = 1\n')
        before = smoke.source_digest(repo)
        (repo / 'artifacts').mkdir()
        (repo / 'artifacts/private.log').write_text('ignored runtime data')
        self.assertEqual(smoke.source_digest(repo), before)
        (repo / 'source.py').write_text('value = 2\n')
        self.assertNotEqual(smoke.source_digest(repo), before)


if __name__ == '__main__':
    unittest.main()

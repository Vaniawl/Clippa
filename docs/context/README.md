# ICM workspace: Clippa

Root CONTEXT.md routes project work; component contracts here specify scoped Inputs,
Process and Outputs. Existing product/architecture/provider references remain authoritative.
The canonical framework carries shared methods, separate from per-task working artifacts.

Copy agent-framework/templates/task-folder into a new docs/tasks/<task-id> for authorized
saved execution: 01-scope, 02-design, 03-build, 04-verify. Each stage writes an editable
Markdown handoff in output/; the next reads the latest file, including human edits.
Small tasks explain any omitted stage in task.md. Return to the responsible stage on failure.

Task.md owns scope/approval, decisions.md owns decision links, evidence.md owns actual
command results, and handover.md owns revision/status/next action. Existing independent
review and delivery gates remain binding. Do not infer completion from file presence or
historical template reports. Existing application identity/build/data are preserved.

This is the Apple engineering adaptation of ICM: revisitable delivery stages and existing
independent review/tooling remain supported. It does not impose the starter's native module
layout, product brand, runtime dependencies or bootstrap on an existing app.

# Foundation adoption evidence

- Base revision: 56ae8ee0a922b9ea74077236fd7cabee6d2c7ba9; source ios-starter e6e2e3d.
- Method: recorded in task.md and source provenance; custom variants remain explicit.
- Actual commands: python3 scripts/agent-framework/render.py; python3 scripts/agent-framework/validate.py; python3 scripts/agent-framework/check-drift.py.
- Results: rendered successfully; validation 0 errors/0 warnings; clean drift.
- Focused unittest: test_icm_workspace.py plus existing test_context_navigation.py: 9 tests, OK. Production stage gate rejects forward/missing handoffs and missing output marker.
- Preservation: 70 existing protected files and 1 unowned provider files unchanged; app instructions/product metadata/team/provider policy checks pass.
- Native app/assets/targets/dependencies, existing product docs and CI are preserved. TrafficVienna's only memory change is the required additive task entry with old entries retained.
- Root/component/context/task links checked against this actual repository.
- Native/product/live-provider tests: N/A; framework-only outcome, no native code change.
- Independent review and GitHub delivery: pending at this checkpoint; no hosted pass claimed.

Detailed raw logs and preservation manifests are retained by the coordinator in the source
rollout task docs/tasks/ICM-GITHUB-01/ and its ignored DerivedData/github-icm-rollout.

## Packaging and delivery record

Explicit intended-case Git index includes generated provider files despite existing ignores,
excludes Python caches/personal settings and preserves existing native/CI entries.
Case-sensitive map/task routes and manifest bytes are checked in the candidate Git tree.
Source-inherited blank-EOF warnings are accepted only for exact pinned-source blobs.
[Coordinator report](https://github.com/Vaniawl/ios-starter/blob/main/docs/tasks/ICM-GITHUB-01/evidence.md) owns independent-review verdicts, candidate-tree IDs and verified remote publication SHAs.
This commit carries the verified foundation; coordinator records publication and the remote commit.

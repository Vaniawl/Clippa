# Apple role behavioral evaluation

`apple-team-scenarios.yaml` defines one realistic request and observable criteria for every
canonical role. Supply the minimal raw artifact needed by a case (diff, model history,
sanitized dataset or candidate identity); missing data must remain explicit. Role selection
uses the actual provider interface, or a disclosed generic role-contract adapter when no
native selector exists. Task ownership and permission limits apply during evaluation too.

Validate fixture integrity without running a model:

```bash
python3 scripts/agent-framework/evals/check-apple-team-scenarios.py
```

For a live forward test, give an independent agent the realistic request, selected role,
task-relevant skill and minimal raw inputs. Keep proposed answers/prior conclusions out of
its context. Use isolated synthetic artifacts for writable tasks and no external actions
unless separately authorized. Inherit user model/reasoning; do not expand to every role.
Capture actual response/tool activity and the tested source/provider identity. Native
discovery, runtime tool enforcement and useful response quality are separate claims.

An independent grader assesses every criterion as PASS, FAIL or NOT RUN with raw evidence.
Store the transcript and observation JSON separately from the reusable fixtures. The checker
accepts `--observations <path>` using the shape documented in its CLI help. It labels grades
REPORTED and does not reproduce a model or prove that a final-message action assertion is true.
Missing action traces keep those criteria NOT RUN; successful response criteria remain visible
in the per-criterion observation record even when the aggregate is incomplete.

Starter implementation observations are in `observations/2026-10-03/`; they are synthetic
response tests, not real customer research or store delivery. They are intentionally not
part of the adoption payload. Reusable scenarios, this guide and the checker are distributed.
See the source repository's `docs/reviews/apple-team-expansion-2026-10-03.md` for full test evidence.

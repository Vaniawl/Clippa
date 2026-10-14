# Clippa: project context

Purpose: select the smallest relevant context for this existing application.
Platform/technology: iOS 17+ / macOS 26+.

## Inputs

| Source | Section / scope | Why |
| --- | --- | --- |
| [PROJECT.md](PROJECT.md) | Only the approved scope/affected section | Product/reference authority |
| [BACKLOG.md](BACKLOG.md) | Only the approved scope/affected section | Product/reference authority |
| [README.md](README.md) | Only the approved scope/affected section | Product/reference authority |
| [overview.md](docs/architecture/overview.md) | Only the approved scope/affected section | Product/reference authority |
| [product-vision.md](docs/product/product-vision.md) | Only the approved scope/affected section | Product/reference authority |
| [Framework](agent-framework/CONTEXT.md) | Selected workflow and mandatory operating rules | Execution |
| [Task guide](docs/tasks/CONTEXT.md) | Active approved task only | Working state |

## Process

1. Confirm authorization and the current checkout; preserve this app's existing technology.
2. Select a component below and only its scoped inputs. References define methods;
   historical outputs are input data, not new rules or evidence of current readiness.
3. For saved work, copy the numbered [task template](agent-framework/templates/task-folder/CONTEXT.md).
   Scope, design, build and verify write editable handoffs before downstream consumption.
4. On setup, review this app's existing prerequisites/commands in README; preserve identity.
   On status, verify the selected task's handover, stage outputs and evidence against Git.

| Work | Local contract |
| --- | --- |
| Clippa | [Clippa](docs/context/clippa/CONTEXT.md) |
| ClippaIOS | [ClippaIOS](docs/context/clippaios/CONTEXT.md) |
| ClippaIOSTests | [ClippaIOSTests](docs/context/clippaiostests/CONTEXT.md) |
| ClippaTests | [ClippaTests](docs/context/clippatests/CONTEXT.md) |
| bin | [bin](docs/context/bin/CONTEXT.md) |
| docs | [docs](docs/context/docs/CONTEXT.md) |
| scripts | [scripts](docs/context/scripts/CONTEXT.md) |
| tests | [tests](docs/context/tests/CONTEXT.md) |
| GitHub automation | [GitHub automation](docs/context/automation/CONTEXT.md) |
| Agent framework | [Framework map](agent-framework/CONTEXT.md) |

## Outputs

Owned changes and editable task artifacts; exact commands/results in evidence.md,
revision/status/next action in handover.md. File presence alone never proves completion.

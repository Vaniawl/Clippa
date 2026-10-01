# Native build and Simulator execution

## Execution

Read existing build scripts and resource-limit helpers; the starter uses
scripts/lib/resource-limits.sh. Keep build concurrency and output bounded, and avoid
unbounded background commands when an adopter has no helper. Check xcodebuild -version,
the real shared scheme and simulator availability. Use the existing simulator resolver
(scripts/resolve-ios-simulator.sh in the starter), or inspect available destinations. Do not invent device UUIDs, destinations,
platform support, or success when the simulator service is unavailable.

Use the repository's actual build and test commands; scripts/build.sh and scripts/test.sh
are the starter defaults. Run package or bootstrap suites only when the adopting project
actually has those components. During iteration use a focused equivalent command;
state clearly which layers it covers. Keep derived data and result bundles in ignored/local
locations. Do not erase simulators or terminate unrelated processes to repair an environment.


For runtime UI evidence, use ui-ux-review/references/native-apple.md for the affected journey.
Compilation, launch, screenshot capture and interaction/accessibility observations are distinct
claims; record only those performed. Pure host tests need no Simulator setup.

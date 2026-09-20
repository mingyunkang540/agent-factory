# Exactly one task execution contract

The runtime selects one todo task with all dependencies done, sorting by ascending numeric
priority then ordinal ID. It records in_progress before invoking the implementer with the
selected task and acceptance criteria. The implementer must not select additional work or
edit controller-owned state, automation or approvals. It may add regression tests, but must
preserve existing tests. No Git mutations, PR creation or deployment.

Run actual lint, typecheck, test and build commands. Await independent read-only tester,
reviewer and security results against the same source fingerprint. Each finding needs an
acceptance criterion and evidence. Only the runtime marks done when every gate passes.
Failed evidence feeds another attempt; at most three total attempts. Exhaustion, errors,
missing evidence or controller-state changes block the task. Stop after this selected task.

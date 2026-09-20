# Agent Factory v0.1 architecture

The repository is durable project memory. PowerShell owns task selection and state transitions;
Codex supplies planning and implementation and separate sessions supply independent findings.

## Boundaries

- `template/`: app rules, eight Codex role configurations, planning documents, prompts and CI.
- `presets/<name>/preset.json`: supported flag and structured executable/argument commands.
- `presets/<name>/files/`: a minimal runnable stack seed, never a specific product.
- `scripts/`: distributable PowerShell runtime, copied to generated `automation/scripts/`.
- `.agent-factory/`: local locks, execution logs and review/quality evidence (gitignored).
- `docs/ROADMAP.json`, `docs/STATUS.json`: versioned, validated state. JSON avoids a YAML module.

## Runtime contract

PowerShell 7.4+ is required. File encoding is UTF-8. All JSON is schema version 1.
`agent-factory.json` stores project, preset, agent_factory_version, max_attempts=3,
max_tasks_per_run=5 and structured commands copied from a preset.

ROADMAP: `{schema_version:1, project:string, tasks:[{id:"TASK-001", title:string,
priority:positive integer, status:"todo|in_progress|done|blocked", acceptance:[string],
depends_on:[task ID]}]}`. IDs are unique; dependencies exist and are acyclic. Select only
todo tasks whose dependencies are done; order by numeric priority then ordinal ID.

STATUS includes current_task, blocked, block_reason, initialized, quality, approvals,
last_run, last_quality and history. Quality keys: lint, typecheck, test, build, tester,
reviewer, security. Allowed result states include unknown/pass/fail/missing.
Only the runtime marks a task done. A project lock prevents overlapping writes. An atomic
transaction journal contains both state documents before either is replaced; the next locked
operation rolls it forward after interruption. An in-progress task still requires `resume`.

## Execution

Init obtains structured planning output in three read-only calls: product, architect, UX.
The runtime writes returned documents and roadmap after validation. No implementation code
is writable during init. A product approval records a planning-content fingerprint.

Next snapshots the roadmap and approval state, selects exactly one task and persists
in_progress. Implementation gets workspace-write; verification sessions get read-only.
Implementation uses `on-request` with automatic approval review so non-interactive Codex can
authorize eligible workspace edits without granting access beyond the workspace. Planning and
verification retain `never` approval with read-only access.
Real quality commands run before independent tester/reviewer/security findings. All must pass
against the same source fingerprint. Reviews can run concurrently and all are awaited.
The review verdict determines pass or fail; a passing response may retain acceptance evidence
in its findings array. A failing verdict always fails the gate regardless of its findings text.
Failed results feed the next implementation attempt; at most three attempts total. Errors,
exhaustion and unexpected changes to controller-owned state fail closed as blocked.
Interrupted work requires an explicit resume; it never silently selects another task.

Run calls Next 1–5 times and stops immediately on a failure, blocked state or empty queue.
Check executes lint/typecheck/test/build and captures exit codes and logs. A missing required
npm script is reported as missing without attempting it and makes the gate fail.

Review refresh runs actual checks and three independent reviews for the last completed task
after manual edits. It changes no task state. Status labels old passing results as stale when
the source fingerprint has changed. Reapprove product direction if planning content changed.

## Human and Git boundaries

`approve -Gate product|mvp|release` records an explicit human acknowledgement in STATUS.
Product approval binds the planning files; MVP/release approvals bind the source fingerprint.
PR preparation requires current command and review evidence. It writes a PR body and prints
branch/commit/push/gh commands for the operator; it executes none of them.
Release rechecks readiness and reports all three human gates. No deployment implementation exists.

## Honest limitations

Workspace-write is a sandbox boundary, not path-level authorization inside the project.
Prompts prohibit source-scope expansion and changing automation/approvals; snapshots detect
controller-state changes but cannot prove that an AI implemented only the intended behavior.
Local logs and approvals are not tamper-proof attestations. Human code review, MVP acceptance,
GitHub required checks and least-privilege credentials remain necessary.
Process deadlines cover input, execution and output draining. A timeout is a failed gate.
The process runner kills a living process tree; a detached descendant whose original parent
has already exited cannot be contained portably by .NET Process. Do not use background/watch
commands in quality gates; use an OS job/container boundary if stronger containment is needed.
CLI options and role syntax are verified against installed help and official docs. The runner
uses `--ignore-user-config` to avoid inheriting unrelated hooks/provider settings; authentication
still uses the installed Codex account. No model is hardcoded: Codex chooses its default, or
the operator passes `-Model`. Custom providers need a separately reviewed runner adaptation.

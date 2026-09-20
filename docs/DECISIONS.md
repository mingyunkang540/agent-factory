# Technical decisions

## ADR-001 — JSON state and explicit commands
Use JSON instead of YAML so PowerShell can parse/write state without extra modules. Commands
use executable plus argument arrays, never Invoke-Expression or interpolated shell programs.

## ADR-002 — PowerShell 7.4+
Require modern cross-platform PowerShell for UTF-8, JSON validation and bounded parallel
read-only reviews. Windows PowerShell 5.1 is not supported. The inspected host runs 7.6.6.

## ADR-003 — Fresh sessions with structured outputs
Use separate Codex exec calls, a JSON output schema and persisted final output for each role.
Do not depend on a conversation ID or invent a role-selection CLI flag. Role instructions
are injected explicitly by the runtime; TOMLs also support native custom-agent usage.

## ADR-004 — Three total attempts and five-task ceiling
Each task has one initial implementation and at most two repairs. This is stricter than an
initial attempt plus three retries. `run` accepts only 1–5; all gates fail closed.

## ADR-005 — Safe PR preparation and no deployment
v0.1 writes PR content and operator commands only. Creating remote repositories, committing,
pushing, merging, signing and production deployment remain explicit operator actions.

## ADR-006 — Distributable runtime and reproducible seeds
Copy runtime scripts into every app and record the Factory version. Existing apps do not
depend on the Factory's absolute path. Preserve lockfiles. Preset upgrades are explicit future work.

## ADR-007 — Approval validity and evidence
Bind product approval to planning content; bind MVP/release approvals and review evidence to
source content. State/log-only updates do not stale evidence. Changed code requires new checks.

## ADR-008 — Input document authority
The pasted request is the task instruction. The supplied September 2026 DOCX is its referenced
design source; it remains unchanged. More specific request constraints override report examples.

## ADR-009 — Recoverable state transitions
Persist the intended ROADMAP and STATUS pair in one atomic local journal before replacing
either file. The next operation holding the project lock rolls the pair forward after a
crash. Recovery does not start an implementation; in-progress work still requires resume.

## ADR-010 — Review refresh for manual corrections
Expose `ai-review` for a completed task after operator changes. Run actual commands and
three independent read-only reviews again without marking another task done. Preserve
the distinction between historical passing evidence and current source content in status.

## ADR-011 — Bounded processes across supported hosts
Use one deadline for stdin, process exit and output pipe draining. Interpret timeout as
failure even when the immediate parent has exited successfully. Resolve Windows npm shims
through node; use the native executable on Unix. Native process-tree containment is limited
after a parent exits, so background/watch commands are outside the quality gate contract.

## ADR-012 — Non-interactive implementation approvals
Run implementers with `workspace-write`, `on-request` and automatic approval review. A live
Windows CLI trial showed that `never` rejects workspace patches and npm commands classified by
the execution policy even when `workspace-write` is requested. Keep planning and independent
reviews read-only with `never`, and keep controller-owned files protected by prompts plus
runtime snapshots.

## ADR-013 — Review verdict is authoritative
Use each independent role's schema-validated verdict as the gate result. The prompt asks roles
to cite acceptance evidence in `findings`, so nonempty findings are valid on a passing verdict.
A failing verdict remains a hard failure even if its findings are empty.

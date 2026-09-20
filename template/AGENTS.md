# {{PROJECT_NAME}} agent operating contract

Repository files are durable project memory. Read IDEA.md, docs/PRD.md,
docs/ARCHITECTURE.md, docs/UX.md, docs/DECISIONS.md, docs/ROADMAP.json and
docs/STATUS.json before acting. Uninitialized documents are placeholders, not approved plans.

The PowerShell runtime selects exactly one eligible task by numeric priority then ID.
Implement only that selected task and its acceptance criteria. Stop after reporting its result.
No unrelated refactoring, speculative features or unapproved dependencies.

Only the runtime may update ROADMAP.json, STATUS.json, approvals, agent-factory.json,
automation/ or .codex/. Agents must not change those files. Planning sessions return document
text as schema-conforming JSON; the runtime validates and writes it. Never claim to have
written planning files in a read-only session.

Existing tests must not be deleted, skipped or weakened to make a gate pass.
Implementer adds meaningful regression coverage for changed behavior. Tester, reviewer and
security use independent read-only sessions. Findings must name the affected acceptance
criterion and concrete evidence: file/line, reproduction or command output. Unknown evidence
is not a pass. Actual lint, typecheck, test and build exit codes gate completion.

No Git mutations, commits, pushes, PR creation or deployment by agents. PR preparation only
prints operator commands. No force push, reset, history rewrite or production secret changes.
Keep credentials, signing keys and personal data out of source and logs.

Human gates remain mandatory: product direction, actual MVP use and production release.
Agents cannot grant approvals or mark tasks done. A sandbox is not a substitute for scope
review. Report blockers honestly; the runtime permits at most three implementation attempts.

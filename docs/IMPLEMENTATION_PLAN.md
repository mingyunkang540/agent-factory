# Agent Factory v0.1 implementation plan

## Outcome and scope

Build the reusable Factory, not an application. Preserve the supplied DOCX unchanged.
Windows PowerShell 7.4+, Git, Node/npm and Codex CLI are the execution environment.
React Web and React + Capacitor are supported; Toss and Unity are explicit extension stubs.

## Sequence and ownership

1. Inspect the report, installed CLI and empty workspace (complete).
2. Record architecture and shared contracts before concurrent implementation.
3. Build common process/state helpers and quality gates; separately build templates and presets.
4. Integrate scaffolding, bounded orchestration, human approvals and safe PR/release preparation.
5. Exercise temporary projects and fake Codex responses without paid model calls.
6. Run real React/Capacitor lint, typecheck, tests and production builds.
7. Independently review correctness/security and publish usage and verification evidence.

## Acceptance checks

- Paths with Korean characters and spaces work; existing destinations are refused.
- Init creates planning documents only; product approval is required before implementation.
- Next selects one eligible todo by priority then ID, and never starts a second task.
- Run executes at most 1–5 cycles; each cycle has at most three implementation attempts.
- Missing/failed checks and rejected/malformed independent reviews never become done.
- Tester, reviewer and security use separate read-only Codex invocations.
- State and evidence survive sessions; stale source evidence cannot authorize PR/release.
- PR helper prepares commands only; no commits, push, deployment or profile editing occurs.
- Tests cover blocked/retry, schema validation, approval, task selection and safe scaffolding.

## Validation boundaries

No real Codex model call, remote write, production deployment or native mobile SDK build is
required for this setup. Record those gaps explicitly; fake responses validate orchestration,
not AI implementation quality. Generated apps still require a human to write IDEA.md.

## Completion evidence

Completed 2026-09-19: 47 self-tests passed; both generated React stack seeds passed actual
installation, lint, typecheck, tests and web build. Independent review findings were corrected
and covered by regressions. See VERIFICATION.md for evidence, known dependency findings and
the explicit live-model/native/remote-CI verification gaps.

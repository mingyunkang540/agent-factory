# Agent Factory repository rules

This repository produces reusable automation, not a particular application. Read
docs/ARCHITECTURE.md, docs/DECISIONS.md and docs/IMPLEMENTATION_PLAN.md before modifying it.
Preserve the supplied DOCX. Do not modify the user's global Codex config or PowerShell profile.

Keep PowerShell orchestration deterministic: one task per next, at most five tasks per run,
at most three attempts per task. Real command exit codes and three independent read-only
reviews are required for done. Product, MVP and release approvals are explicit human actions.

Never run production deployment, force push, reset, credential operations or automatic remote
writes. The PR helper prepares a body and operator commands only. Secrets are never test fixtures.

Use separate bounded agents for independent changes or reviews and respect file ownership.
Do not weaken tests or quality commands to obtain a pass. Validate changes with
`pwsh -NoProfile -File tests/self-test.ps1`, plus affected preset checks. Fake Codex tests prove
orchestration only; distinguish them from live model calls and native Android/iOS validation.

Document behavior and compatibility changes. Keep VERSION and CHANGELOG consistent.

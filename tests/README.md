# Factory self-test

Run from the Factory repository:

```powershell
pwsh -NoProfile -File tests/self-test.ps1
```

Requires PowerShell 7.4+ and Node. No Pester module, npm installation, remote write,
or model/API call is used. Every test creates an isolated project beneath a temporary
directory containing spaces and Korean characters. Successful runs remove that directory;
failed runs retain it and print its path. `-KeepArtifacts` retains successful runs too.

Use `-NameFilter '*review*'` to run matching tests while diagnosing a failure.

The fake Codex fixture accepts the actual runtime argument list and stdin prompt, then
writes a schema-shaped final message. `.agent-factory/fake-control.json` can set
`fail_role`, `malformed_role`, `exit_role`, `tamper_status`, `evidence_findings`, or an alternate `tasks` array. Separate trace
files avoid collisions between concurrent reviewer sessions. That local fixture directory
is excluded from source fingerprints.

These tests prove orchestration, state transitions, retry bounds, subprocess exit handling,
approval/evidence checks, journal recovery and review refresh after manual corrections.
The fixture writes an authored IDEA; a separate test verifies the unedited template is refused.
They do not prove AI implementation quality, sandbox enforcement,
real Codex service compatibility, native mobile builds, or production readiness.

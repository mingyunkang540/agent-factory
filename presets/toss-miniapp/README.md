# Toss Miniapp extension point

`supported: false`. Scaffolding must reject this preset until its official SDK/runtime and packaging workflow are selected and implemented.

To enable it: create a reviewed `files/` overlay and lockfile, define install/lint/typecheck/test/build commands, implement SDK-specific smoke tests, confirm the current official Toss platform requirements, and verify every quality command locally and in CI. Account registration, credentials and publication require separate authorization. Set `supported` to true only after those checks pass.

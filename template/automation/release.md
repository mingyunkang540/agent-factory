# Release readiness contract

Read current source-bound command/review evidence, completed roadmap, version and changelog.
Require explicit human product, MVP-use and production-release approvals. Stale or missing
evidence is a blocker. The release role returns readiness evidence in read-only mode.
The runtime reports readiness and outstanding gates; it does not deploy or mutate Git.
PR preparation writes a suggested body and prints operator branch/commit/push/PR commands.
A release approval does not introduce a deployment implementation in Agent Factory v0.1.

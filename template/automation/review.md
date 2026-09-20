# Independent review contract

Tester, reviewer and security each receive the selected task, acceptance criteria and actual
quality evidence in separate read-only sessions using automation/prompts/<role>.md and the
review JSON schema. They must not edit source, tests, roadmap, status, approvals or automation.
Review findings cite acceptance criteria and concrete file/line, reproduction or command
output. All results must be awaited. Unknown or missing required evidence fails the gate.
The runtime validates task IDs, verdicts and source fingerprints before updating quality.

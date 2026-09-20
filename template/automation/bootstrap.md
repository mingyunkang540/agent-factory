# Planning initialization contract

The runtime reads IDEA.md, preset constraints and project memory, then invokes product,
architect and UX in separate read-only Codex exec sessions. Each uses its matching role prompt
and JSON output schema. Product supplies PRD and roadmap; architect supplies architecture and
decisions; UX supplies UX text. Validate all outputs before writing planning documents.
No feature implementation occurs. Documents start uninitialized. Human product approval must
bind the generated planning fingerprint before next-task implementation is permitted.
The runtime controls STATUS.json and ROADMAP.json. Planning agents only return text.

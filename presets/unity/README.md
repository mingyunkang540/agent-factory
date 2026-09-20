# Unity extension point

`supported: false`. Scaffolding must reject this preset until a Unity editor version, project layout and executable quality gates are implemented.

To enable it: provide a reviewed project overlay, pin the editor/package versions, define install/lint/typecheck/test/build command slots using suitable Unity tooling, implement EditMode/PlayMode smoke tests, and validate license/editor availability in the intended CI environment. Native SDKs, license credentials and distribution are separate setup tasks. Set `supported` to true only after those checks pass.

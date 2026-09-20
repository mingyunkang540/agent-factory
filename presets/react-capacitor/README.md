# React Capacitor

Supported web seed inheriting `react-web`, then overriding package files and adding Capacitor configuration. Uses Capacitor core, CLI, Android and iOS packages 8.5.2; the CLI requires Node 22+. The web quality gate runs without native SDKs.

Replace `{{PROJECT_NAME}}` in both package files and configuration. The scaffold derives the native app identifier from the project name. `webDir` is `dist`.

Native platform creation, SDK installation, signing, store publication and native builds are separate approved tasks. Android requires the documented JDK/Android Studio tooling; iOS builds require macOS and Xcode. Configure native permissions and identifiers before platform addition.

Reference: [Capacitor environment setup](https://capacitorjs.com/docs/getting-started/environment-setup), [configuration](https://capacitorjs.com/docs/config).

Dependency audit on 2026-09-18: the web seed has no known npm audit findings. Capacitor 8.5.2 adds three moderate findings through the CLI's `xcode` → `uuid@7` dependency. No native platform commands are run by this seed. Review the upstream fix before implementing native platform generation; do not apply an unreviewed override or force downgrade.

The three entries are `@capacitor/cli`, `xcode`, and `uuid`, all tracing to [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq): uuid versions below 11.1.1 lack buffer bounds checks in v3/v5/v6 when a buffer is supplied. The locked CLI's xcode dependency uses uuid 7.0.3. `npm audit` proposes CLI 8.4.3, a downgrade from the latest verified 8.5.2 packages, rather than a patch of this graph. Forcing uuid 11 into xcode's declared uuid 7 range changes a major dependency contract without native integration validation. This task runs only web quality commands and does not validate xcode/native operations, so neither forced override nor downgrade is applied.

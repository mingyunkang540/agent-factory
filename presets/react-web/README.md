# React Web

Supported reusable React + TypeScript seed with a server-rendered smoke test, ESLint, TypeScript and Vite build gates. No product features are prebuilt.

Node 22.17.1 is used by CI; the seed requires Node 22.14+ within the 22.x line. Vite 8.3.0 supports Node 22.12+ and is selected to match the installed Node 22.17.1, with Vitest 5.0.1. The committed npm lock pins the complete dependency graph. Replace `{{PROJECT_NAME}}` in both package files when scaffolding.

Run `npm ci`, then `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build`. The generated quality script runs the same gates. `npm run dev` starts local development.

Reference: [Vite requirements](https://vite.dev/guide/), [Vitest](https://vitest.dev/guide/).

Official stack references: [React](https://react.dev/learn), [TypeScript configuration](https://www.typescriptlang.org/tsconfig/), [ESLint configuration](https://eslint.org/docs/latest/use/configure/configuration-files), [typescript-eslint](https://typescript-eslint.io/getting-started/). Exact package versions and integrity hashes are recorded in `files/package-lock.json`; these documentation pages track their respective current releases.

Only `files/` is copied as the overlay. `node_modules` and `dist` are verification outputs and must never be copied.

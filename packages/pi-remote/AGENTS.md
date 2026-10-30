# pi-remote Packaging

- Keep the source revision and `npmDepsHash` in sync with the committed root lockfile. Pi remains a host-provided peer; use `--legacy-peer-deps` so npm never installs a second SDK.
- Build all workspaces, then install only the CLI's production dependency graph. The extension needs `extensions/`, the runtime/server/protocol sources, and `packages/web/dist` at their original relative paths; the hub and browser build tools are not runtime dependencies.
- The Pi module lists `${pi-remote}/lib/pi-remote` as a local package so the extension and command always use the same revision. It requires the API v2 patch in `../pi-coding-agent`; extension mode replaces the terminal UI, while wrapper instance mode keeps terminal and browser together.
- Verify both packages with a real extension load, `/reload`, and `/new`; a successful TypeScript build does not catch loader identity or session-ownership failures. The source smoke test is `packages/runtime/test/extension-smoke.mjs`; use the installed SDK's `dist/index.js` and `dist/modes/host-mode.js` when testing Nix outputs.

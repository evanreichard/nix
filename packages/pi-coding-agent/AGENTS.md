# pi-coding-agent Packaging Notes

Built from the `earendil-works/pi-mono` monorepo with `buildNpmPackage`, pinned to the `v${version}` tag.

## Model Data Comes From the Published Tarball

`packages/ai`'s normal `build` script runs `generate-models`, which needs the network. `preBuild` extracts the published `@earendil-works/pi-ai` tarball into `packages/ai/src/providers/data` and rewrites that script to `build:offline`. On a version bump:

- point `aiModelData.url` at the new version and refresh its `hash`;
- keep `--strip-components=4` and the exact `package/dist/providers/data` member — that pairing is what lands the data where `packages/ai` looks for it;
- keep the `substituteInPlace --replace-fail` string byte-identical to upstream's `package.json`. `--replace-fail` is deliberate: a renamed script should fail the build rather than silently fall back to generating models online.

`aiModelData` is exposed through `passthru` for consumers that need the same data.

## Build Order

`buildPhase` follows upstream's workspace dependency order: `telemetry schema chord tui codemode mcp ai durable env agent coding-agent`. Keep newly imported workspace packages built before their consumers; otherwise TypeScript resolves their package exports to missing `dist` files.

## Runtime Layout

`installPhase` copies `node_modules` and `packages/` into `$out/lib/pi-coding-agent` and writes `$out/bin/pi` as a one-line ESM shim importing `packages/coding-agent/dist/cli.js`. npm links app workspaces into `node_modules` (`p2` from `apps/p2` since 1.5.2); those targets are not shipped, so the copy drops dangling top-level links or the fixup phase fails on them. The wrapper adds `nodejs_22` plus `firefox`/`geckodriver` for Firefox-based fetching. Camoufox downloads an upstream browser binary, so the wrapper must expose its runtime libraries with `LD_LIBRARY_PATH`; launch testing found `alsa-lib`, `gtk3`, and `libX11` sufficient on x86_64 Linux. The `pixman`/`cairo`/`pango`/`libjpeg`/`giflib`/`librsvg` build inputs serve the browser path too.

## Session Bridge Patch

`session-bridge.patch` adds `SESSION_BRIDGE_API_VERSION = 1` and `pi.registerSessionBridge()`, which lets a companion UI (pi-remote) attach to the interactive session Pi already owns: module-level bridge registration, the stock extension UI context, and live terminal components. Pi keeps session replacement and shutdown; the bridge only observes and wraps what extensions receive. `../pi-remote/patches/pi-<version>-session-bridge.patch` is a copy of the same file and must match it byte for byte.

Rebase against the pristine release tag on every bump, never against an installed bundle: `git clone --branch v<version>`, `git apply --reject`, resolve rejects, then regenerate with `git diff --src-prefix=i/ --dst-prefix=w/` so the `i/`/`w/` prefixes stay. Between 1.5.0 and 1.5.2 the rejected hunks were import-only (loader, extension types, interactive mode) plus the changelog header; the appended fields and methods applied with offsets. Verify with `git apply --check` on a fresh clone, `npm run build` in the checkout, and `vitest run test/session-bridge.test.ts`, since this derivation does not run that test.

## Backwards Compatibility

Add backwards-compatibility code only with explicit permission from the user in the current conversation. When a task looks like it calls for a compatibility layer, alias, re-export, fallback, or deprecated path, stop and ask for that permission first; the default is a clean cutover that updates every caller. Autonomous compatibility code is what makes these derivations and their patches hard to read.

## Lockfile

The derivation uses the tagged release's own `package-lock.json` plus `npmDepsHash`; refresh that hash from the FOD mismatch after a version bump.

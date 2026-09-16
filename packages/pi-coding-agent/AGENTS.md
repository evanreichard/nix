# pi-coding-agent Packaging Notes

Built from the `earendil-works/pi-mono` monorepo with `buildNpmPackage`, pinned to the `v${version}` tag.

## Model Data Comes From the Published Tarball

`packages/ai`'s normal `build` script runs `generate-models`, which needs the network. `preBuild` extracts the published `@earendil-works/pi-ai` tarball into `packages/ai/src/providers/data` and rewrites that script to `build:offline`. On a version bump:

- point `aiModelData.url` at the new version and refresh its `hash`;
- keep `--strip-components=4` and the exact `package/dist/providers/data` member — that pairing is what lands the data where `packages/ai` looks for it;
- keep the `substituteInPlace --replace-fail` string byte-identical to upstream's `package.json`. `--replace-fail` is deliberate: a renamed script should fail the build rather than silently fall back to generating models online.

`aiModelData` is exposed through `passthru` for consumers that need the same data.

## Build Order

`buildPhase` builds the workspace packages in dependency order — `telemetry protocol tui client ai agent coding-agent`. Replacing it with a single monorepo-wide build leaves `packages/*/dist` absent and the installed CLI fails to import.

## Runtime Layout

`installPhase` copies `node_modules` and `packages/` into `$out/lib/pi-coding-agent` and writes `$out/bin/pi` as a one-line ESM shim importing `packages/coding-agent/dist/cli.js`. The wrapper adds `nodejs_22` plus `firefox`/`geckodriver` for the browser automation behind web-fetch; the `pixman`/`cairo`/`pango`/`libjpeg`/`giflib`/`librsvg` inputs serve that same path.

## Lockfile

There is no package-local lockfile step: the derivation builds against the tagged release's own `package-lock.json` plus `npmDepsHash`, so refresh that hash from the FOD mismatch after a version bump. (The obsolete `update-lockfile.mjs` that used to enrich a package-local lockfile has been removed. `packages/pi-web/` keeps a live version of that workflow with its own `update-lockfile.sh`.)

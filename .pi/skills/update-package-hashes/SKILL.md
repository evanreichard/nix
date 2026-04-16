---
name: update-package-hashes
description: Update a package in packages/ to a new version and refresh its hashes (src, vendorHash, npmDepsHash, cargoHash, etc.) WITHOUT compiling the package. Use when the user asks to bump, update, or upgrade a specific package under packages/. Requires package name and target version/rev.
---

# Update Package Hashes (Without Building)

Require the user to supply the **package name** and **target version/rev/tag**. Ask if missing.

## Hard Rule

**Never run `nix build .#<pkg>`** — it compiles. Only realise FOD sub-attributes (`.src`, `.goModules`, `.npmDeps`, `.cargoDeps`) which are pure downloads.

## Flow

1. Edit `packages/<name>/default.nix` — bump `version` / `rev` / `tag`. Check for sibling `.nix` files (e.g. `ui.nix`).

2. **`src` hash** — use `nurl` (downloads source only, prints the fetcher expression):

   ```bash
   nix run nixpkgs#nurl -- https://github.com/<owner>/<repo> <tag-or-rev>
   ```

   Paste the new `hash = "sha256-..."` into the `src` block.

3. **Dependency hashes** (`vendorHash`, `npmDepsHash`, `cargoHash`, `cargoLock.outputHashes.<crate>`) — after the version bump the old hash is already wrong, so just trigger the mismatch:

   ```bash
   nix build .#<name>.goModules --no-link 2>&1 | tee /tmp/hash.log   # or .npmDeps / .cargoDeps
   grep -E '^[[:space:]]*got:' /tmp/hash.log | tail -1 | awk '{print $2}'
   ```

   Paste into the matching attribute.

4. **Custom fetchers** (`leaveDotGit`, `postFetch`, `fetchSubmodules`) — `nurl` will be wrong. Use the same mismatch trick on `.src`:

   ```bash
   nix build .#<name>.src --no-link 2>&1 | tee /tmp/hash.log
   ```

   Applies to `llama-cpp` and `llama-swap`.

5. **Opaque `outputHash` FODs** (e.g. opencode `node_modules` runs `bun install`) — do NOT attempt locally. Leave as-is and flag for CI in the summary.

6. Show `git diff -- packages/<name>/` and list any hashes left for CI.

## Notes

- Don't touch hashes whose inputs didn't change (e.g. `slack-cli`'s pinned `python-snappy`/`zstd-python`).
- Resolve a tag → rev without cloning: `git ls-remote <url> refs/tags/<tag>`.
- `nix-update --flake <name> --version <v>` can sometimes do all of this; try it first for simple packages.

---
name: update-package-hashes
description: Update a package in packages/ to a new version and refresh its hashes (src, vendorHash, npmDepsHash, cargoHash, etc.) WITHOUT compiling the package. Use when the user asks to bump, update, or upgrade a specific package under packages/. If version is provided, proceed directly. If not, look up the latest version and ask the user before proceeding.
---

# Update Package Hashes (Without Building)

If the user provides a **package name** and **target version/rev/tag**, proceed directly.

If the user provides only a **package name** (no version), look up the latest version and **ask the user** if they want to proceed before updating.

## Hard Rules — Read First

1. **Never run `nix build .#<pkg>`** or `.#packages.<system>.<pkg>`. That compiles the package. Only realise **FOD sub-attributes** (`.src`, `.goModules`, `.npmDeps`, `.cargoDeps`) — those are pure downloads, not builds.
2. **Never** use `nix-prefetch-git`, `nix-prefetch-url`, `nix hash path`, `git clone` + manual hashing, `builtins.fetchGit`, or any other ad-hoc method to compute hashes. They produce hashes in formats that don't match what `fetchgit`/`fetchFromGitHub`/etc. expect, and you will waste time chasing mismatches.
3. There are exactly **two** correct ways to get a hash, both listed below. If neither fits, stop and ask the user — don't improvise.

## The Only Two Methods

### Method A — `nurl` (preferred for `src` on any git forge)

`nurl` works for **any git URL**, not just GitHub: `gitea.va.reichard.io`, `gitlab`, `codeberg`, `sourcehut`, plain `https://...git`, all fine. It downloads the source and prints a complete fetcher expression with the correct hash.

```bash
nix run nixpkgs#nurl -- <git-url> <rev-or-tag>
```

Examples:
```bash
nix run nixpkgs#nurl -- https://github.com/owner/repo v1.2.3
nix run nixpkgs#nurl -- https://gitea.va.reichard.io/evan/slack-cli.git 0a9484257a2adc414aa4cdab4fb9539a37e04d1f
```

Copy the `hash = "sha256-..."` line into the package's `src` block.

### Method B — FOD mismatch trick (for everything else)

For `vendorHash`, `npmDepsHash`, `cargoHash`, `cargoLock.outputHashes.<crate>`, or any `src` using a custom fetcher (`leaveDotGit`, `postFetch`, `fetchSubmodules`, etc. — applies to `llama-cpp` and `llama-swap`), realise the **specific FOD sub-attribute** and read the `got:` line from the error.

```bash
nix build .#<name>.src --no-link 2>&1 | tee /tmp/hash.log         # for src
nix build .#<name>.goModules --no-link 2>&1 | tee /tmp/hash.log   # for vendorHash
nix build .#<name>.npmDeps --no-link 2>&1 | tee /tmp/hash.log     # for npmDepsHash
nix build .#<name>.cargoDeps --no-link 2>&1 | tee /tmp/hash.log   # for cargoHash
grep -E '^[[:space:]]*got:' /tmp/hash.log | tail -1 | awk '{print $2}'
```

Setting the hash to `sha256-AAAA...` (44 A's) or leaving the old one in place both work — the build will fail at the FOD with `got: sha256-...` which is the correct value.

**Note:** `.src`, `.goModules`, etc. are sub-attributes of the derivation. They download but do not compile. `nix build .#<name>` (without the `.src` suffix) compiles — never do that.

## Lookup Latest Version

When the user asks to update a package but doesn't specify a version, look it up and present it for confirmation.

1. Read `packages/<name>/default.nix` to find the git URL and current version/tag.
2. Determine the tag pattern from the current `tag` field (e.g. `"b${version}"` → tags like `b8815`; `"v${version}"` → tags like `v1.2.3`).
3. Fetch the newest matching tag:

   ```bash
   # Find the latest tag matching the package's pattern
   git ls-remote --tags https://github.com/ggml-org/llama.cpp.git 'b*' 2>&1 | tail -1
   ```

   For non-GitHub repos, use the appropriate remote URL from the package's `fetchFrom*` expression.
4. Present the result to the user and **ask for confirmation** before proceeding:

   ```
   Current: b8815 → Latest: b8914
   Proceed with update? (yes/no)
   ```

   If the user confirms, use the latest version. If they provide a different target, use that instead. If they say no, abort.

## Flow

1. **If no version was provided**, look up the latest version (see section above) and ask the user to confirm.
2. Edit `packages/<name>/default.nix` — bump `version` / `rev` / `tag`. Check for sibling `.nix` files (e.g. `ui.nix`) that may also need bumping.
3. Get the new `src` hash with **Method A** (`nurl`). If the package uses a custom fetcher, use **Method B** on `.src` instead.
4. For each dependency hash (`vendorHash` / `npmDepsHash` / `cargoHash` / etc.), use **Method B** on the matching sub-attribute.
5. **Opaque `outputHash` FODs** (e.g. opencode's `node_modules` which runs `bun install`) — do NOT attempt locally. Leave as-is and flag for CI in the summary.
6. Show `git diff -- packages/<name>/` and list any hashes left for CI.

## Resolving Tags Without Cloning

```bash
git ls-remote <url> refs/tags/<tag>
```

## Don't Touch What Didn't Change

Skip pinned sub-dependencies whose inputs didn't change — e.g. `slack-cli`'s `python-snappy` / `zstd-python` PyPI tarballs are pinned by the upstream `dfindexeddb`, not by the slack-cli rev.

## Optional Shortcut

`nix-update --flake <name> --version <v>` sometimes handles everything for simple packages. Try it first; fall back to the methods above if it fails.

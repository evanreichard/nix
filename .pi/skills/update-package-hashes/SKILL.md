---
name: update-package-hashes
description: Update a package in packages/ to a new version and refresh its hashes (src, vendorHash, npmDepsHash, cargoHash, etc.) WITHOUT compiling the package. Use when the user asks to bump, update, or upgrade a specific package under packages/. Requires package name and target version/rev.
---

# Update Package Hashes (Without Building)

Require the user to supply the **package name** and **target version/rev/tag**. Ask if missing.

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

## Flow

1. Edit `packages/<name>/default.nix` — bump `version` / `rev` / `tag`. Check for sibling `.nix` files (e.g. `ui.nix`) that may also need bumping.
2. Get the new `src` hash with **Method A** (`nurl`). If the package uses a custom fetcher, use **Method B** on `.src` instead.
3. For each dependency hash (`vendorHash` / `npmDepsHash` / `cargoHash` / etc.), use **Method B** on the matching sub-attribute.
4. **Opaque `outputHash` FODs** (e.g. opencode's `node_modules` which runs `bun install`) — do NOT attempt locally. Leave as-is and flag for CI in the summary.
5. Show `git diff -- packages/<name>/` and list any hashes left for CI.

## Resolving Tags Without Cloning

```bash
git ls-remote <url> refs/tags/<tag>
```

## Don't Touch What Didn't Change

Skip pinned sub-dependencies whose inputs didn't change — e.g. `slack-cli`'s `python-snappy` / `zstd-python` PyPI tarballs are pinned by the upstream `dfindexeddb`, not by the slack-cli rev.

## Optional Shortcut

`nix-update --flake <name> --version <v>` sometimes handles everything for simple packages. Try it first; fall back to the methods above if it fails.

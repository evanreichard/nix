# llama-cpp — Agent Notes

Override of `pkgs.llama-cpp` with CUDA + Vulkan + BLAS, custom CMake flags, and an optional fork pin.

## Pitfalls

### `version` must be numeric

Upstream `pkgs/by-name/ll/llama-cpp/package.nix` passes `version` straight through as a C integer via:

```nix
(cmakeFeature "LLAMA_BUILD_NUMBER" finalAttrs.version)
```

`build-info.cpp` then emits `int LLAMA_BUILD_NUMBER = <version>;`. A non-numeric `version` (e.g. `"mtp-clean-08b1474"`) breaks the build with:

```
error: '<value>' was not declared in this scope
    int LLAMA_BUILD_NUMBER = <value>;
```

**Convention:**
- Upstream tag pins: use the bare build number, e.g. `version = "9048";` with `tag = "b${version}";`.
- Fork / arbitrary commit pins: use a `YYYYMMDD` date derived from the commit's author/commit date (`gh api repos/<owner>/<repo>/commits/<sha>` → `.commit.committer.date`).

### `leaveDotGit` + `postFetch`

We keep `.git` only long enough to record the short SHA into `$out/COMMIT`, then strip it. Preserve this pattern when changing `src` so downstream tooling that reads `COMMIT` keeps working.

## Refreshing the pinned commit (fork)

1. `git ls-remote https://github.com/<owner>/llama.cpp refs/heads/<branch>` → get the full SHA.
2. `nix run nixpkgs#nix-prefetch-github -- <owner> llama.cpp --rev <sha> --leave-dot-git` → get the hash.
3. Look up the commit date: `curl -s https://api.github.com/repos/<owner>/llama.cpp/commits/<sha> | jq -r '.commit.committer.date'`.
4. Update `src.{owner,rev,hash}` and set `version = "YYYYMMDD"`.

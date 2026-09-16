# llama-cpp — Agent Notes

Override of `pkgs.llama-cpp` with CUDA + Vulkan + BLAS, custom CMake flags, and a pinned upstream commit. The fork of the same engine lives in `packages/ik-llama-cpp/`, which calls upstream's `.devops/nix/package.nix` directly and carries its own CUDA/Vulkan plumbing.

## `version` and `buildNumber` Are Separate Fields

Upstream nixpkgs passes `version` into `-DLLAMA_BUILD_NUMBER`, and `build-info.cpp` emits that as a C integer — so the semver `"0.4.0"` would break the build. The override decouples them:

- `version` — human-facing: the upstream `vX.Y.Z` tag. (`bN` tags are nightlies; HEAD builds use `YYYYMMDD`, per the comment in `default.nix`.)
- `buildNumber` — the b-tag shipped with that release; this is what reaches `LLAMA_BUILD_NUMBER`.
- The `cmakeFlags` override filters upstream's `-DLLAMA_BUILD_NUMBER` and re-adds it as `:STRING`. Keep the filter; deleting it puts the semver string back into `build-info.cpp` and the build dies on an undeclared identifier.

`npmDepsHash` pins the bundled webui's npm dependencies — it only moves when the pinned commit's webui dependencies do.

## `leaveDotGit` + `postFetch`

`.git` is kept only long enough to record the short SHA into `$out/COMMIT`, then stripped. Preserve the pattern when changing `src` so downstream tooling that reads `COMMIT` keeps working.

## Bumping the Pinned Commit

1. `git ls-remote https://github.com/ggml-org/llama.cpp refs/tags/<tag>` → full SHA.
2. `nix run nixpkgs#nix-prefetch-github -- ggml-org llama.cpp --rev <sha> --leave-dot-git` → hash. `--leave-dot-git` is required; the fetch keeps `.git`, so the hash differs from a plain fetch.
3. Set `src.rev` / `src.hash`, then `version` and `buildNumber` from the tag.
4. Refresh `npmDepsHash` (see the `update-package-hashes` skill).

## Benchmark Validity Depends on the CPU ISA Flags

The explicit `-DGGML_AVX2=ON`-style set is load-bearing, for the reason spelled out on `cmakeFlags` in `default.nix`: without it the build silently targets baseline x86-64. Any measurement taken against such a build is not comparable to the tuning tables in `modules/nixos/services/llama-swap/AGENTS.md`.

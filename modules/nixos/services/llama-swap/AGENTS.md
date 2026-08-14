# llama-swap Module — Agent Guide

## Model ID Convention

Use `<family>-<size>[-backend/variant][-context][-vl]-<placement>`. Omit `thinking` from IDs, use `vl` for vision-language models, and keep placement as the final suffix (`cuda0`, `cuda1`, or `dual`). Keep quantization and richer behavior details in the display `name` unless they are needed to distinguish two active configs for the same family/placement.

## Reasoning Metadata

Reasoning-capable models use `metadata.reasoning` profiles from `config.nix` as the client-neutral source of truth. Record only verified native modes, levels, defaults, and request controls; `location = "chat_template_kwargs"` denotes a nested template argument and `location = "request"` a top-level API field. Pi-specific level mapping belongs in `modules/home/programs/terminal/pi/lib.nix`.

## Syncing vLLM Configs from club-3090

The three vLLM model configs in `config.nix` (`qwen3.6-27b-vllm-180k-cuda0`, `qwen3.6-27b-vllm-145k-vl-cuda0`, `qwen3.6-27b-vllm-75k-cuda0`) are derived from the club-3090 repo's Docker Compose files. Each config block has a `Synced from:` comment with the commit hash it was last aligned to.

### Source Files

The upstream compose files live at https://github.com/noonghunna/club-3090 under `models/qwen3.6-27b/vllm/compose/`:

| config.nix model ID               | Compose file                        |
|------------------------------------|-------------------------------------|
| `qwen3.6-27b-vllm-180k-cuda0`    | `docker-compose.long-text.yml`      |
| `qwen3.6-27b-vllm-145k-vl-cuda0` | `docker-compose.long-vision.yml`    |
| `qwen3.6-27b-vllm-75k-cuda0`     | `docker-compose.tools-text.yml`     |

### Sync Process

1. **Fetch the latest compose files** from https://github.com/noonghunna/club-3090 (master branch) and note the HEAD commit hash.
2. **Diff each compose file** against the current config.nix block. The mapping is:
   - Compose `command:` args → Nix `vllmCmd` string (the `exec vllm serve ...` block)
   - Compose `environment:` → Nix docker `-e` flags
   - Compose `volumes:` → Nix docker `-v` flags
   - Compose `image:` → Nix docker image tag at the end of the `docker run` command
   - Compose `entrypoint:` → Nix `vllmCmd` preamble (the `set -e; pip install ...; python3 ...` lines before `exec vllm serve`)
3. **Apply changes** to `config.nix`. Key things to watch:
   - `--max-model-len` and `--gpu-memory-utilization` — these change across versions
   - Genesis env vars — the full set grows frequently; add new ones, remove deprecated ones
   - Sidecar patches — old patches get absorbed into Genesis; drop them from entrypoint + volume mounts
   - Docker image tag — update when the compose files move to a new nightly
4. **Keep `patch_timings_1acd67a.py`** — this is our own patch, not from club-3090. Always retain it in the entrypoint and volume mounts.
5. **Update the `Synced from:` comment** on each config block with the new commit hash and date.
6. **Update `setup-qwen36-vllm.sh`** if the upstream `patches/` directory changed (new patches added, old ones removed). The setup script downloads sidecar patches and creates cache directories.
7. **Verify syntax**: `nix-instantiate --parse config.nix`

### Structural Notes

- `config.nix` uses Nix string interpolation. Newlines in `vllmCmd` are flattened to spaces via `builtins.replaceStrings` before passing to `docker run -c`.
- We pin `CUDA_VISIBLE_DEVICES=0` and `CUDA_DEVICE_ORDER=PCI_BUS_ID` (not in compose files) because the host has multiple GPUs and llama-swap's concurrency matrix manages GPU assignment.
- Volume mounts use `/mnt/ssd/vLLM/` paths (Models, Patches, Cache) — these match what `setup-qwen36-vllm.sh` creates.
- The `patches/` subdirectory in this module contains our custom timings patch and its source `.patch` file — unrelated to club-3090's `patches/` dir.

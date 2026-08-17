# llama-swap Module — Agent Guide

## Model ID Convention

Use `<family>-<size>[-backend/variant][-context][-vl]-<placement>`. Omit `thinking` from IDs, use `vl` for vision-language models, and keep placement as the final suffix (`cuda0`, `cuda1`, or `dual`). Keep quantization and richer behavior details in the display `name` unless they are needed to distinguish two active configs for the same family/placement.

## Reasoning Metadata

Reasoning-capable models use `metadata.reasoning` profiles from `config.nix` as the client-neutral source of truth. Record only verified native modes, levels, defaults, and request controls; `location = "chat_template_kwargs"` denotes a nested template argument and `location = "request"` a top-level API field. Pi-specific level mapping belongs in `modules/home/programs/terminal/pi/lib.nix`.

## NInfer Configs

The `qwen3.8-27b-ninfer-*` entries run `pkgs.reichard.ninfer-3090` (`packages/ninfer-3090/`) against one 17 GiB artifact at `/mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer`, fetched by `setup-qwen38-ninfer.sh`. The 64K/C8/vision flags mirror upstream's launchers in `scripts/run-qwen38-{c1,c8,vision}.sh`; the 165K and 240K profiles are derived from upstream's measured allocation boundaries.

### Context Budget

Qwen3.6/3.8-27B is a hybrid: 16 of 64 layers are full attention, the other 48 are GDN with fixed-size state (`src/targets/qwen3_6_27b/impl/config.h`). With 4 KV heads at head_dim 256, KV costs ~33 KiB/token at INT8 and ~26 KiB/token at rk8v4 — that is what makes 165K+ fit alongside 17 GiB of weights.

Sizing is arithmetic, not trial and error. Reservation is linear in capacity and an oversized run fails in under a second printing required vs available bytes, so two failed probes recover both constants exactly (`scripts/ninfer-probe.sh`). Measured on our 3090 at C1/MTP3 with CUDA Graphs on:

| Profile | Fixed bytes | Bytes/token | Startup ceiling | Config value |
|---|---|---|---|---|
| `int8` | 600,945,920 | 35,904 | 181,312 | 177,152 (~217 MiB free) |
| `rk8v4` | 600,913,152 | 27,200 | 239,296 | 234,496 (~201 MiB free) |
| `int8 --vision` | 2,567,478,272 | 35,904 | 118,336 | 114,688 (~199 MiB free) |
| `rk8v4 --vision` | 2,567,441,408 | 27,200 | 156,224 | 151,552 (~195 MiB free) |

Every ceiling above leaves only ~75 MiB free, hence the ~200 MiB deployed margin. Two constants generalize to profiles we have not probed: vision is a flat ~1.83 GiB plus ~282 MiB of weights, and each `--max-concurrency` slot beyond the first costs ~409 MB (~11,390 int8 tokens or ~15,035 rk8v4). Both are independent of KV dtype. A separate artifact limit caps `--max-context` at 262,144 regardless of memory.

Available memory drifts ~1.5 MB between runs, so running at the ceiling is not reproducible; leave ~200 MiB. The CUDA Graph allowance is one 86 MiB class at C1/K3 (`graphs=8.00 MiB/86.00 MiB` in the startup ledger), worth ~2.5K INT8 or ~3.2K rk8v4 tokens — lower the context rather than passing `--no-cuda-graph`.

### NInfer Request Constraints

- `--model-id` must equal the llama-swap alias. NInfer rejects any request whose `model` field differs from its public model ID, and llama-swap forwards the body unchanged.
- `chat_template_kwargs` accepts only `preserve_thinking`; any other key is a 400. `enable_thinking`, `preserve_thinking`, and `reasoning_effort` are top-level request fields, so the `qwen38Ninfer` reasoning profile uses `location = "request"` throughout. Using `chat_template_kwargs` controls here would push pi onto its `thinkingFormat = "chat-template"` path and break every request.

The package pins the `feature/qwen38-rk8v4-paged-sm86` branch, not a release tag: `--kv-dtype rk8v4` does not exist in `release/v0.6.0-rtx3090`. Dropping the 240K entry would allow moving back to a release pin.

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

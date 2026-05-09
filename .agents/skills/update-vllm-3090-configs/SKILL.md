---
name: update-vllm-3090-configs
description: Update only the qwen3.6-27b vLLM 3090 llama-swap configs from club-3090 refs; compare diffs, present a plan, and require approval before editing.
---

# Update vLLM 3090 Configs

## Scope

Use only for Qwen3.6 27B vLLM 3090 configs in `modules/nixos/services/llama-swap/`.
Do not use this skill for other models, other Qwen sizes, non-vLLM configs, or package bumps.

Local files:
- `modules/nixos/services/llama-swap/config.nix`
- `modules/nixos/services/llama-swap/setup-qwen36-vllm.sh`

Local config keys:
- `vllm-qwen3.6-27b-tools-text`
- `vllm-qwen3.6-27b-long-text`
- `vllm-qwen3.6-27b-long-vision`

## Upstream References

Compare against `club-3090` master:
- `models/qwen3.6-27b/vllm/compose/single/tools-text.yml`
- `models/qwen3.6-27b/vllm/compose/single/long-text.yml`
- `models/qwen3.6-27b/vllm/compose/single/long-vision.yml`
- `scripts/setup.sh` for the current `GENESIS_PIN="${GENESIS_PIN:-...}"`

Use raw URLs or a temp clone under `_scratch/club-3090`. Prefer a temp clone when checking broad changes:

```bash
mkdir -p _scratch
git clone https://github.com/noonghunna/club-3090 _scratch/club-3090 2>/dev/null || git -C _scratch/club-3090 pull --ff-only
```

## Required Workflow

1. Fetch/update upstream refs under `_scratch/club-3090` or fetch the raw files.
2. Compare upstream compose files to the three local llama-swap entries. Translate docker-compose semantics into the existing `docker run`/llama-swap format.
3. Compare upstream `scripts/setup.sh` Genesis pin to local `GENESIS_PIN` in `setup-qwen36-vllm.sh`.
4. Check upstream compose volumes/entrypoint for sidecar patches. If patches are added, removed, renamed, or invoked differently, update both:
   - runtime mounts and `python3 /patches/...` calls in `config.nix`
   - download/install logic and summary in `setup-qwen36-vllm.sh`
5. Ignore these diffs unless the user explicitly asks otherwise:
   - `shm_size` / shm-related compose settings
   - local timing patch `patch_timings_07351e088.py` and its mount/invocation
   - model served-name differences caused by llama-swap `${MODEL_ID}`
   - `HUGGING_FACE_HUB_TOKEN`; keep local CUDA device/env choices
   - upstream relative paths vs local `/mnt/ssd/vLLM/...` paths
   - docker-compose format vs local llama-swap/Nix format
6. Before editing, present:
   - upstream files/commit checked
   - meaningful diffs found
   - ignored diffs
   - exact planned local changes
   Then wait for explicit user approval.
7. After approval, edit minimally and validate:
   - `bash -n modules/nixos/services/llama-swap/setup-qwen36-vllm.sh`
   - `nix-instantiate --parse modules/nixos/services/llama-swap/config.nix`
8. Summarize changed files and any remaining upstream differences.

# llama-swap Module — Agent Guide

## Layout

```
config.nix          aggregator: imports models/, derives the matrix, sets globals
lib.nix             helper entrypoint - NOT lib/default.nix, see below
lib/backends.nix    server binaries, docker scaffolding, the one cmd builder
lib/reasoning.nix   reasoning profiles
lib/matrix.nix      concurrency matrix, derived from placement
peers.nix           remote OpenAI-compatible backends
models/<id>.nix     one file per model; the filename IS the model ID
```

A model file returns an attrset from `{ pkgs, lib, backends, reasoning }` and adds two
attributes that are ours rather than llama-swap's: `backend` (`llama-cpp`, `ik-llama-cpp`,
`ninfer`, `vllm-club3090`, `vllm-syv`, `stable-diffusion`, `comfyui`) and `placement`
(`cuda0`, `cuda1`, `dual`). `config.nix` strips both before rendering. `backend` selects the
llama.cpp preset list in `default.nix`; `placement` generates the matrix, so a new model file
joins the concurrency matrix by existing rather than by being added to a table.

The helper entrypoint is `lib.nix`, not `lib/default.nix`: snowfall-lib treats every
`default.nix` under `modules/nixos` as a NixOS module and would call it with module
arguments instead of `{ pkgs }`.

`cmd` stays a literal command line in the model's own file. There is deliberately no
llama.cpp command generator - the flags are the tuning knowledge, and the variance between
entries (`-np 2 -kvu`, `-ncmoe 26`, `-lm none`, `-ot per_layer_token_embd.weight=CPU`) is
the point. `lib/backends.nix` holds only invariants: binaries, the `dockerModel` wrapper
that supplies `cmdStop`/`proxy`/`checkEndpoint`, `qwen38SyvCmd`, whose whole command is
environment variables, and the `comfyui*` helpers, where the command is invariant because
ComfyUI takes its configuration from workflows rather than flags.

Any change to model definitions can be proved by rendering the config before and after and
comparing - the module's output is a single JSON document:

```bash
nix eval --raw '/etc/nixos#nixosConfigurations.lin-va-desktop.config.sops.templates."llama-swap.json".content' | jq -S .
```

## Model ID Convention

Use `<family>-<size>[-backend/variant][-context][-vl]-<placement>`. Omit `thinking` from IDs, use `vl` for vision-language models, and keep placement as the final suffix (`cuda0`, `cuda1`, or `dual`). Keep quantization and richer behavior details in the display `name` unless they are needed to distinguish two active configs for the same family/placement.

`comfyui_auto` is the one exemption: llama-swap hardcodes that ID for its `/comfyui`
endpoint, so the file cannot carry a placement suffix.

## Reasoning Metadata

Reasoning-capable models use `metadata.reasoning` profiles from `lib/reasoning.nix` as the client-neutral source of truth. Record only verified native modes, levels, defaults, and request controls; `location = "chat_template_kwargs"` denotes a nested template argument and `location = "request"` a top-level API field. Pi-specific level mapping belongs in `modules/home/programs/terminal/pi/lib.nix`.

Two pi behaviors constrain what a profile must declare. pi forwards an unmapped level verbatim (`thinkingLevelMap[level] ?? level`), so every pi level must resolve to a native one or a strict backend answers 400; pi's `lib.nix` fills the gaps with the nearest native level. Separately, pi's default `openai` thinking format can only disable reasoning via a `thinkingLevelMap.off` string, so a profile whose `enabled` control is a top-level `enable_thinking` field gets `compat.thinkingFormat = "qwen"` instead — otherwise switching thinking off silently changes nothing.

## stable-diffusion Configs

`sd-server` holds every component resident at once, so a 24 GiB card is budgeted against weights *plus* one decode graph. Qwen Image weights already cost ~19.5 GiB (14.4 diffusion Q5_K + 4.8 Qwen2.5-VL TE + 0.24 VAE), and an untiled 1024x1024 `wan_vae` decode asks for 7.6 GiB against the ~5 GiB left — it fails at `decode_first_stage` after sampling has already succeeded, wasting the whole request. Both Qwen entries therefore pass `--vae-tiling`; sd.cpp's auto-fit retry does not rescue this. Chroma Radiance is exempt (pixel-space, no VAE), Z-Image-Turbo has headroom.

FLUX.2 Klein 9B is light on weights (14.1 GiB: 9.5 diffusion Q8_0 + 4.4 Qwen3-8B TE + 0.16 `flux2_ae`) and heavy on decode, so it needs `--vae-tiling` for reach rather than for fit. Measured on the 3090 at 4 steps:

| Resolution | Untiled | Tiled |
|---|---|---|
| 1024x1024 | 11.3 s, 6,658 MB decode buffer, 20.6 GiB peak | 12.5 s, 1,664 MB buffer, 14.9 GiB peak |
| 1536x1536 | fails: `vae decode compute failed while processing a tile` | 19.5 s, 16.2 GiB peak |
| 2048x2048 | same failure | 41.0 s, 18.4 GiB peak |

The decode buffer is flat under tiling, so 1.2 s at 1024x1024 buys every resolution up to klein's 4 MP ceiling. The `/v1/images/edits` path additionally encodes each reference image at ~3.4 GB untiled, which is why edits peak higher than generations at the same size.

Image edit on a vision-capable TE needs `--llm_vision` alongside `--llm`. Without the mmproj, sd.cpp logs `no vision weights detected, vision disabled` and silently drops reference images from LLM conditioning, leaving only the VAE ref latents — edits still run, so the loss shows up as weak prompt grounding rather than an error. FLUX.2 Klein is the exception by design: its TE is text-only Qwen3-8B, no mmproj exists, and reference images reach the model purely as VAE latents.

Distilled/Lightning merges are configured as `--cfg-scale 1.0 --steps 4 --sampling-method euler_a --scheduler simple`; sd.cpp has no `beta` scheduler, so upstream `euler_ancestral/beta` advice maps to `simple` or `sgm_uniform`. A GGUF carrying the `__index_timestep_zero__` marker turns `zero_cond_t` on by itself. FLUX.2 Klein 9B is distilled the same way but is a Flow model, so it takes `euler` with sd.cpp's automatic flow shift; the non-distilled sibling is `klein-base-9B` and would need `--cfg-scale 4.0 --steps 20` instead.

Model flags migrate: `--qwen-image-zero-cond-t` and `--chroma-disable-dit-mask` were replaced by `--model-args qwen_image_zero_cond_t=true` / `--model-args chroma_use_dit_mask=false`, and `--clip-on-cpu`/`--vae-on-cpu` are deprecated in favor of `--backend te=cpu`/`--backend vae=cpu`. Diff `examples/common/common.cpp` against the pinned rev when bumping `packages/stable-diffusion-cpp` — a removed flag is a startup failure, not a warning.

## ComfyUI Config

llama-swap proxies ComfyUI but does not translate for it: `/v1/images/generations` routes on
the body's `model` field and ComfyUI serves no such endpoint. So `comfyui_auto` is one
opaque model ID covering every workflow, driven through `/upstream/comfyui_auto/...`;
`/comfyui/` is the browser door and the only path that may cold-start it.

The queue drain in `comfyuiStop` is load-bearing — see the comment there. Its 200 s ceiling
must stay under both `healthCheckTimeout` (the graceful window during a swap) and
`unloadTimeout` (TTL and manual unloads). A cmdStop that fails does not merely delay the
swap: llama-swap force-kills the `docker run` client, and the container keeps the VRAM.

`placement = "cuda0"` gives exclusive use of the 3090 while still allowing a cuda1 model
beside it. Intra-card use is unbudgetable — the graph's loader nodes decide what is
resident and ComfyUI caches across prompts — so the per-weight arithmetic above has no
ComfyUI equivalent.

This module launches and swaps ComfyUI; it does not configure it. `/mnt/ssd/ComfyUI/storage`
holds the ComfyUI tree, custom_nodes, their pip installs, workflows, and models — nothing in
Nix reconstructs it, so back it up. `/mnt/ssd/StableDiffusion` is mounted read-only so a
workflow can reach the sd.cpp weights; wiring that up (`extra_model_paths.yaml`, plus
ComfyUI-GGUF for GGUF loaders) happens in ComfyUI.

Pull `comfyuiImage` before the first swap-in, and pull it with the same
`${pkgs.docker}/bin/docker` the config calls. An interactive `docker` on this host is
podman-docker on the *rootless* socket, so the wrong one silently stores a second ~11.8 GiB
copy that llama-swap cannot use.

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

The package pins the `v0.6.1-rtx3090` release tag. `--kv-dtype rk8v4` merged to master via PR #3 before that tag, so the long-context rk8v4 profiles no longer need a feature-branch pin.

## syv-ai vLLM Configs (Qwen3.8-27B)

The four `qwen3.8-27b-vllm-*` entries run one prebuilt image from
[syv-ai/qwen38-27b-rtx3090](https://github.com/syv-ai/qwen38-27b-rtx3090) against one
prepared model directory at `/mnt/ssd/vLLM/Models/Qwen3.8-27B-*`, fetched by
`setup-qwen38-vllm.sh`. The image carries patched vLLM 0.27.1, the DFlash2 block drafter
support and the KVarN KV cache; nothing is built from nixpkgs.

`qwen38SyvCmd` in `lib/backends.nix` renders the whole `docker run` from a model ID and a list of
environment variables. Profiles differ only by `CTX` and `VISION` — the container's
`single-user/start_qwen.sh` derives attention backend, KV dtype, pinned pool bytes, slot
count and max-model-len from those, so serving flags do not belong in the model file.

Pools below are what this 3090 resolved at boot, not upstream's published figures (they
agree except `CTX=fast`, where prefix caching costs a state page):

| Model ID | Env | KV | Pool | Slots | `macros.ctx` |
|---|---|---|---|---|---|
| `qwen3.8-27b-vllm-64k-cuda0` | `CTX=fast` | bf16 (FLASH_ATTN) | 68,605 tok / 5.2 GiB | 8 | 65536 |
| `qwen3.8-27b-vllm-128k-cuda0` | `CTX=long` | int8 per-token-head (TRITON_ATTN) | 136,429 tok / 5.2 GiB | 4 | 131072 |
| `qwen3.8-27b-vllm-240k-cuda0` | `CTX=huge` | KVarN 4/2-bit | 268,169 tok / 4.90 GiB | 2 | 245760 |
| `qwen3.8-27b-vllm-64k-vl-cuda0` | `CTX=fast VISION=1` | bf16 (FLASH_ATTN) | 68,605 tok / 5.2 GiB | 8 | 65536 |

All four set `SPEC=dflash2 PREFIX_CACHE=1`. DFlash2 is a one-stream mode: a resident request
reserves k+1 recurrent-state slots (~0.88 GiB) before it holds a token of context, so
`MAX_SEQS` is an admission limit and decode halves at two concurrent streams. `macros.ctx`
is not cosmetic — `modules/home/programs/terminal/pi/lib.nix` publishes it as pi's
`contextWindow`, so it must equal the launcher's `MAX_LEN` for the profile.

`qwen3.8-27b-uncensored-vllm-240k-cuda0` is the same image and profile pointed at an
abliterated body: `MODEL=/app/models/Qwen3.8-27B-Uncensored-W4A16-AutoRound`
(leminkozey, syv-ai issue #45 - already AutoRound W4A16 plus the repo's own head requant,
so no prepare steps and the pinned 4.90 GiB pool stays valid). `MODEL=` is required
because the launcher prefers the base model's `-fast` dir when `MODEL` is unset; the
DFlash2 drafter is a separate dir and is shared with the base profiles. Abliteration
quality is unmeasured on this stack (issue #45 reports ~100 tok/s warm, 45k needle
retrieved, coherent output); the author skipped `quant_mtp.py`/`build_draft_vocab.py`,
so `SPEC=mtp` on this checkpoint is slower (int8 lm_head path) - the profile uses
`SPEC=dflash2` regardless.

### Constraints

- **`useModelName = "qwen3.8-27b"`.** The launcher hardcodes `--served-model-name`, so
  llama-swap rewrites the request body instead of the server being told the alias.
- **`PREPARE=0`.** The image's entrypoint otherwise downloads and requantizes 19.5 GiB
  inside a model swap. `VERIFY` stays on: it fails in seconds on a missing or unpatched
  model directory. Run `setup-qwen38-vllm.sh` before the first switch.
- **`healthCheckTimeout = 900`** per model, against the global 500. Measured here: 360 s
  cold (empty `/mnt/ssd/vLLM/Cache/qwen38-syv`, paying torch.compile, CUDA graph capture
  and FlashInfer JIT), 65-108 s once that cache is warm.
- **One CDI device, not `CUDA_VISIBLE_DEVICES`.** vLLM reads compute capability through
  NVML, which enumerates in PCI order and ignores `CUDA_VISIBLE_DEVICES`, so `--device=
  nvidia.com/gpu=all -e CUDA_VISIBLE_DEVICES=0` makes it see the 1080 Ti and refuse with
  "quantization method compressed-tensors is not supported for the current GPU".
  `--device=nvidia.com/gpu=1` is the 3090 and leaves NVML and torch agreeing.
- **`/mnt/ssd` is exFAT, which has no hardlinks.** `prepare/fetch_fast_variant.py` shares
  the six unchanged shards by `os.link` and dies with `EPERM`, so `setup-qwen38-vllm.sh`
  runs `prepare` twice: once with `FAST_VARIANT=0`, then again after placing those shards
  itself (link where possible, copy otherwise — ~19 GiB of duplication here).
- **The image tag is pinned to a commit** (`sha-<7>`), in `lib/backends.nix` (`qwen38SyvImage`) and
  in `setup-qwen38-vllm.sh` (`IMAGE`). The pool constants are calibrated per commit against
  24 GiB, so both move together and the model directory is re-prepared after a bump.
- **`CTX=huge` is lossy** (GSM8K 95.2% against 96.5% for bf16). Take it for requests that
  would not otherwise fit, not for speed.

## Syncing vLLM Configs from club-3090

The three `vllm-club3090` model files under `models/` are derived from the club-3090 repo's Docker Compose files. Each carries a `Synced from:` comment with the commit hash it was last aligned to.

### Source Files

The upstream compose files live at https://github.com/noonghunna/club-3090 under `models/qwen3.6-27b/vllm/compose/`:

| Model file                              | Compose file                     |
|-----------------------------------------|----------------------------------|
| `qwen3.6-27b-vllm-180k-cuda0.nix`       | `docker-compose.long-text.yml`   |
| `qwen3.6-27b-vllm-145k-vl-cuda0.nix`    | `docker-compose.long-vision.yml` |
| `qwen3.6-27b-vllm-75k-cuda0.nix`        | `docker-compose.tools-text.yml`  |

### Sync Process

1. **Fetch the latest compose files** from https://github.com/noonghunna/club-3090 (master branch) and note the HEAD commit hash.
2. **Diff each compose file** against the model file. The mapping is:
   - Compose `command:` args → Nix `vllmCmd` string (the `exec vllm serve ...` block)
   - Compose `environment:` → Nix docker `-e` flags
   - Compose `volumes:` → Nix docker `-v` flags
   - Compose `image:` → Nix docker image tag at the end of the `docker run` command
   - Compose `entrypoint:` → Nix `vllmCmd` preamble (the `set -e; pip install ...; python3 ...` lines before `exec vllm serve`)
3. **Apply changes** to the model file. Key things to watch:
   - `--max-model-len` and `--gpu-memory-utilization` — these change across versions
   - Genesis env vars — the full set grows frequently; add new ones, remove deprecated ones
   - Sidecar patches — old patches get absorbed into Genesis; drop them from entrypoint + volume mounts
   - Docker image tag — update when the compose files move to a new nightly
4. **Keep `patch_timings_1acd67a.py`** — this is our own patch, not from club-3090. Always retain it in the entrypoint and volume mounts.
5. **Update the `Synced from:` comment** in each model file with the new commit hash and date.
6. **Update `setup-qwen36-vllm.sh`** if the upstream `patches/` directory changed (new patches added, old ones removed). The setup script downloads sidecar patches and creates cache directories.
7. **Verify**: `nix-instantiate --parse models/<id>.nix`, then confirm the rendered JSON changed only where you intended (see Layout).

### Structural Notes

- These model files use Nix string interpolation. Newlines in `vllmCmd` are flattened to spaces via `builtins.replaceStrings` before passing to `docker run -c`.
- These four pass `-e CUDA_VISIBLE_DEVICES=0` (not in the compose files) because the host has two GPUs and llama-swap's concurrency matrix manages the assignment. An earlier version of this note also claimed `CUDA_DEVICE_ORDER=PCI_BUS_ID` was pinned; it is not, and it would select the wrong card — PCI order puts the 1080 Ti first here. Note the constraint recorded under the syv-ai section: vLLM resolves compute capability through NVML, which ignores `CUDA_VISIBLE_DEVICES`, so this form works only as long as these containers do not hit that code path. Prefer `--device=nvidia.com/gpu=1` for anything new.
- Volume mounts use `/mnt/ssd/vLLM/` paths (Models, Patches, Cache) — these match what `setup-qwen36-vllm.sh` creates.
- The `patches/` subdirectory in this module contains our custom timings patch and its source `.patch` file — unrelated to club-3090's `patches/` dir.

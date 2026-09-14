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
`vllm-syv`, `stable-diffusion`, `comfyui`) and `placement`
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

## Qwen3.8-Flash-Next (llama.cpp, cuda0)

177B total / ~6B active, 48 layers, plus a 27 GB PLE n-gram table that `-ot ...=CPU` pins to
RAM. 76 GiB of weights against 24 GiB of VRAM, so the CPU owns the critical path and needs an
AVX2 backend - without it this model runs 3.1 tok/s instead of 14.5, and any tuning note
written on such a build is void. See the `llama-cpp-tuning` skill.

Context is the lever: KV competes with expert layers, so it is paid for in `-ncmoe`.
`llama-bench -d 4096 -lm none`, CUDA0 only, q8_0 KV, each row at the largest context fitting
24,576 MiB:

| context | `-ncmoe` | decode |
|---|---|---|
| 64K | 30 | ~25.7 tok/s |
| 164K | 32 | ~22.5 tok/s |
| 262K | 35 | ~19.7 tok/s (deployed; server 20.8 decode / 93 prefill, 23,313 MiB) |

The 1080 Ti loses here: its marginal layers are Pascal layers and the extra hop outweighs
them, so `-ncmoe 32` alone beat `-ncmoe 26 -ts 82,18` across both cards, and CUDA1 is free for
a second model. Sizing: the estimator undershoots ~390 MiB, KV is ~19 KiB/token at q8_0, one
CPU MoE layer is 962 MiB.

Prefill is PCIe-bound, not CPU-bound: it streams CPU-resident experts to the GPU each batch.
The 3090 sits on gen3 x4 and the 1080 Ti on x8 (B450-F, CPU root ports 00:03.2 / 00:03.1),
which caps pp512 at 115 here against 284 for the 35B on the wider slot. Swapping the cards
physically is the fix; `-ub` and `-nopo 1` are not (measured no effect and -30%).

UD-Q4_K_XL is the only variant with real k-quant experts and still loses (14.9 against 20.1)
on 35% more bytes; UD-Q3_K_XL and UD-Q2_K_XL ship IQ experts despite their names.

`-ctk q8_0` requires llama.cpp >= 0.4.0 - before #27967 the QSA graph asserted on quantized K
caches. Vision rides `--mmproj-device none`: no VRAM, no text-decode cost, ~17 s of CPU ViT
per image.

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

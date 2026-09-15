---
name: llama-cpp-tuning
description: Tune llama.cpp inference performance — placement across GPUs, CPU/RAM offload, KV and context sizing, speculative decoding, quant selection. Use when asked to make a llama.cpp/llama-server model faster, fit a model into limited VRAM, pick -ncmoe/-ts/-ot values, diagnose low tok/s, or benchmark a llama.cpp deployment.
---

# llama.cpp Performance Tuning

Measure the active bottleneck, then change only flags that can affect it.

## Target Host

Scripts accept `--host <user@host>`; omit it to run locally.

This repo's inference host is `10.0.20.100` (`lin-va-desktop`), with models under `/mnt/ssd/Models`. llama.cpp maps the RTX 3090 to `CUDA0` and the GTX 1080 Ti to `CUDA1`. `CUDA_VISIBLE_DEVICES=1` isolates the 1080 Ti and remaps it to `CUDA0`.

## Workflow

### 1. Match the requested deployment

| Shape | Primary constraint | Guidance |
| --- | --- | --- |
| Single GPU | VRAM capacity and bandwidth | `references/scenarios.md` §A |
| Multi-GPU | VRAM split and device hops | §B |
| GPU + CPU layers | CPU compute or RAM bandwidth | §C |

For a single-GPU run, pin that card with `--visible-devices`, then use `-ngl all -dev CUDA0 -fit off`.

### 2. Identify the bottleneck

Run `scripts/profile.sh`. Use only the matching flags from `references/diagnostics.md`.

### 3. Size candidates

```bash
scripts/fit.sh --host H --model /path/model.gguf --ctx 131072 --dev CUDA0
```

Keep at least 500 MiB free for CUDA workspace. Confirm actual VRAM after loading because the estimator runs low.

### 4. Benchmark

```bash
scripts/serve.sh start --host H --visible-devices N --model /path/model.gguf -- -c 131072 -ngl all -dev CUDA0 -fit off
scripts/bench.sh --host H --cases short,prefill,deep
```

Change one variable at a time and use sustained, like-for-like runs.

### 5. Verify

Load the selected settings, confirm at least 500 MiB free VRAM, and exercise the intended context depth. If changing weight quants, validate quality before committing the swap.

## References

- `references/scenarios.md` — levers by deployment shape
- `references/knobs.md` — flag semantics
- `references/diagnostics.md` — bottleneck signals and matching flags

## Scripts

- `scripts/fit.sh` — estimate context and placement memory
- `scripts/serve.sh` — start and stop an isolated benchmark server
- `scripts/bench.sh` — measure prompt and decode throughput
- `scripts/profile.sh` — identify the active bottleneck

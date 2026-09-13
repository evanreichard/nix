---
name: llama-cpp-tuning
description: Tune llama.cpp inference performance — placement across GPUs, CPU/RAM offload, KV and context sizing, speculative decoding, quant selection. Use when asked to make a llama.cpp/llama-server model faster, fit a model into limited VRAM, pick -ncmoe/-ts/-ot values, diagnose low tok/s, or benchmark a llama.cpp deployment.
---

# llama.cpp Performance Tuning

Scope: llama.cpp / `llama-server` only. Measure, classify the bottleneck, then turn the levers that bottleneck responds to.

## Target Host

Every script takes `--host <user@host>` and runs remotely over ssh; omit it to run locally.

**This repo's inference host is `10.0.20.100` (`lin-va-desktop`), ssh, no password.** llama-swap
runs there and models live under `/mnt/ssd/Models`: RTX 3090 (llama.cpp `CUDA0`, nvidia-smi
index 1), GTX 1080 Ti (`CUDA1`, index 0) — llama.cpp enumerates fastest-first, nvidia-smi by
PCI order — Ryzen 5 5600X 6c/12t, 94 GiB DDR4 at 28.6 GB/s. Tune elsewhere only when asked.

Confirm the hardware before sizing anything:

```bash
ssh 10.0.20.100 'nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader; nproc; free -g | sed -n 2p'
```

## Workflow

### 0. Verify the binary before believing any number

```bash
ssh H 'llama-bench -m /path/model.gguf -ngl 99 -ncmoe <all layers> -p 0 -n 128 -r 3 -t <cores>'
```

A CPU backend built without AVX2/FMA runs 4-5x slow and invalidates everything measured on
top of it (3.1 vs 14.5 tok/s here). Nix builds default every ISA option off — see
`references/diagnostics.md` "Rule minus-one" for the cause and the fix. Compare the
all-on-CPU figure against a published one for similar hardware; 3-5x under means the build.

### 1. Identify the deployment shape

| Shape | Test | Levers |
| --- | --- | --- |
| Single GPU | Weights + KV fit one card | `references/scenarios.md` §A |
| Multi-GPU | Weights fit across cards, none on CPU | §B |
| GPU + CPU offload | Weights exceed total VRAM | §C |

The shape determines which knobs exist. Speculative decoding, for instance, is a strong win in §A; in §C it depends on the build — measured a 3x loss on a CPU backend without AVX2 and a 17% win on the same model once the kernels were there.

### 2. Measure before turning anything

```bash
scripts/serve.sh start --host H --model /path/model.gguf -- -c 32768 -ngl all -fit off
scripts/profile.sh --host H
```

`profile.sh` reports CPU saturation, per-GPU utilization, iowait and decode rate, then prints the classification table. Low GPU utilization with pegged CPU cores is the CPU-offload signature and is normal — what matters is whether the CPU is compute-bound or bandwidth-bound. Do the bandwidth arithmetic in `references/diagnostics.md`; the answer selects opposite levers.

### 2b. Prove the hardware is thermally stable

```bash
scripts/thermal.sh --host H --rounds 5
```

Stable tok/s and SM clock across rounds means comparisons are trustworthy. Decaying tok/s with falling clocks means the card is thermally limited, and every A/B taken across that decay measures heat instead of flags — fix cooling before tuning. A throttled GPU still reports 99% utilization, so clocks are the signal, not utilization. See `references/diagnostics.md` "Rule zero".

### 3. Size placement without loading weights

```bash
scripts/fit.sh --host H --model /path/model.gguf --ctx 131072 --dev CUDA1 --ncmoe 24,26,28
```

`llama-fit-params` runs in seconds and loads nothing, so sweep widely. It needs the GPUs free — it aborts if a server already holds the VRAM. It **undershoots** real usage — measured ~390 MiB on a 3090 and ~250 MiB on a 1080 Ti, and ~950 MiB when the prefill compute buffer is large — so keep >=500 MiB free or the first decode aborts in `cublasCreate_v2`. Confirm against `nvidia-smi` once the server is up.

### 4. Benchmark candidates

```bash
scripts/bench.sh --host H --cases short,copy,prefill,deep
```

One variable per launch, and **put the sweep inside one `llama-bench` invocation**: values compared across separate invocations are not comparable. Under `-lm mmap` identical flags measured 20.3 and 25.0 tok/s in different invocations because page-cache residency differed; `-lm none` reproduced to ±0.1. Sustained runs only — short requests vary +/-25%. Judge speculative decoding on the `copy` case; prose says nothing about it.

### 5. Verify and record

Confirm VRAM, host RAM and a long-prefill run at the final settings before committing them. When the change swapped quants, validate quality (`llama-perplexity` or KL-divergence) rather than shipping on speed alone. Record *why* each non-obvious flag is set — the next reader cannot re-derive `-ncmoe 26` from the flag itself.

## Hard Rules

1. **Verify the build has AVX2 before tuning anything.** A baseline-ISA CPU backend is 4-5x slow and invalidates every placement, quant and threading conclusion you draw on top of it. Nix builds default every ISA option off; see Workflow step 0.
2. **Prove thermal stability before comparing anything.** A card that decays across back-to-back runs makes every A/B a measurement of heat. Utilization stays at 99% while clocks collapse, so read `clocks.sm` and the clock event reasons. Multi-fan boards report fan 0 only through `nvidia-smi`/nvtop — a dead fan 0 reads 0% while other fans work fine.
3. **Measure, then tune.** Placement guesses cost multi-minute reloads. One `profile.sh` run eliminates most of the search space.
4. **Keep >=500 MiB VRAM free.** A server that loads is not a server that decodes.
5. **`-lm none` whenever tensors land on the CPU.** Under mmap they stream from disk, the slowdown hides as ordinary mediocrity, and results stop being reproducible across runs.
6. **Quant family is a performance knob on the CPU, but check the tensors, not the filename.** IQ formats cost ~1.8x per byte against k-quants on an AVX2 build (measured 7.3 vs 12.9 GB/s), not the 4x a baseline build suggests. Unsloth "UD-Q3_K_XL" and "UD-Q2_K_XL" ship IQ experts despite the names — dump tensor types before downloading 90 GB to test a hypothesis.
7. **Draft length decides whether speculation helps.** Confirm the `mean len` in the server's `draft acceptance` log line; the per-request `speculative.n_max` field does not reach n-gram variants.

## References

| Doc | Use |
| --- | --- |
| `references/scenarios.md` | Ordered levers for each deployment shape |
| `references/knobs.md` | Flag semantics and quant-family table |
| `references/diagnostics.md` | Classification, bandwidth math, methodology, traps |

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/fit.sh` | Sweep `-ncmoe`/context candidates, report fit vs VRAM budget |
| `scripts/serve.sh` | `start` / `stop` / `status` a benchmark server; waits for readiness and for VRAM release |
| `scripts/bench.sh` | Prose, copy-heavy, long-prefill and deep-context cases with pp/tg |
| `scripts/profile.sh` | Sample CPU/GPU/iowait during decode and classify the bottleneck |
| `scripts/thermal.sh` | Repeat sustained generations, report tok/s with SM clock and throttle state |

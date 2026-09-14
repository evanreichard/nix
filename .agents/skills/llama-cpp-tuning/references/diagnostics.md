# Diagnostics, Methodology, and Traps

## Rule minus-one: prove the binary has its CPU kernels

ggml turns off every instruction-set extension when `GGML_NATIVE` is off *and*
`GGML_NATIVE_DEFAULT` is off — and the latter happens whenever `SOURCE_DATE_EPOCH` is
defined, which every Nix build does:

```cmake
if (CMAKE_CROSSCOMPILING OR DEFINED ENV{SOURCE_DATE_EPOCH})
    set(GGML_NATIVE_DEFAULT OFF)
if (GGML_NATIVE OR NOT GGML_NATIVE_DEFAULT)
    set(INS_ENB OFF)      # SSE42/AVX/AVX2/BMI2/FMA/F16C all default OFF
```

Cost: 3.1 vs 14.5 tok/s on the same model and host. The symptom looks exactly like slow
hardware — cores pegged, no iowait, no swap, GPUs idle. Fix with explicit
`-DGGML_AVX2=ON`-style flags, or `GGML_BACKEND_DL=ON GGML_CPU_ALL_VARIANTS=ON` for runtime
dispatch; `-march=native` is wrong under Nix because the builder is not always the target.

Any performance note predating a build change is void until re-run.

## Rule zero: prove the hardware is thermally stable

Run `scripts/thermal.sh` before any A/B. If decode decays across back-to-back
generations, every comparison taken across that decay measures heat rather than
configuration, and the whole sweep is worthless.

Observed on an RTX 3090 with one dead cooler fan: 50.4, 47.5, 46.4, 36.9, 30.2
tok/s across five identical-length generations, SM clock falling 1935 -> 825 MHz,
`SW Thermal Slowdown: Active`, while the core sat at 60-63 C and power fell from
290 W to 220 W. Cold-versus-warm sampling alone produced a 2.5x spread, which is
larger than any flag effect measured in this document.

Traps that made this hard to see:

- A throttled GPU still reports `utilization.gpu` of 99%. Utilization says the
  kernels are resident, not that they run at speed. Sample `clocks.sm` too.
- `nvidia-smi --query-gpu=fan.speed` and nvtop report **fan 0 only**. A card whose
  fan 0 is dead reads 0% while its other fans spin and auto-ramp correctly. Read
  every fan via NVML `nvmlDeviceGetNumFans` + `nvmlDeviceGetFanSpeed_v2`.
- NVML fan indices are control channels, not physical fans. Three-fan boards
  commonly expose two channels.
- Cool core plus clocks down plus power under the cap means the limiting sensor is
  not the core. On consumer cards `NVML_FI_DEV_MEMORY_TEMP` usually returns
  NOT_SUPPORTED, so memory heat can be inferred but not measured.
- Recovery during idle makes the first request after any pause look fast. Compare
  sustained series, never first requests.

## Classify the bottleneck

| Observation | Bottleneck | Levers that can help |
| --- | --- | --- |
| GPU util >80% | GPU compute | Quant, batch size, faster card |
| GPU util low, CPU cores pegged, bandwidth well under ceiling | CPU compute | Cheaper-to-decode quant, more GPU layers |
| GPU util low, CPU cores pegged, bandwidth near ceiling | RAM bandwidth | Fewer bytes/token: smaller quant, fewer CPU layers |
| iowait >5% | Disk streaming | `-lm none` / `--mlock` |
| Nothing saturated | Latency / sync / throttling | Fewer device hops, check clocks and thermals |

### Bandwidth arithmetic

```
bytes/token ~= active_params * (cpu_layers / total_layers) * bytes_per_weight
achieved     = bytes/token * decode_tok_s
```

Worked example (Qwen3.6-35B-A3B, 3B active, 48 layers, 24 on CPU, Q4_K_M ~4.8 bpw):
`3e9 * 0.5 * 0.6 B = 0.9 GB/token`; at 29 tok/s that is **~26 GB/s** against ~45 GB/s realistic for dual-channel DDR4-3200. Roughly 58% — still CPU-compute bound, which is why a cheaper kernel helped and a smaller file would not have.

Establish the ceiling from the platform's memory configuration, or measure it once with a STREAM-style benchmark. Peak theoretical is optimistic by 10-20%.

## Picking a quant for CPU-resident weights

IQ costs ~1.8x per byte against k-quants (7.3 vs 12.9 GB/s measured), so a k-quant wins only
when it is under ~1.8x the bytes. Measured on one 11 GB card, same model and context:
IQ4_NL (18 GB, 24 CPU layers) **36.6 t/s** against Q4_K_M (22 GB, 28 layers) 32.6 — the
smaller file wins by buying three GPU layers. A baseline-ISA build inverts this answer.

Two things to check first. Filenames lie: unsloth's UD-Q3_K_XL and UD-Q2_K_XL carry IQ
expert tensors, only UD-Q4_K_XL has real Q4_K ones — run `scripts/gguf-types.py`. And the
CPU path may not be dequant-bound at all: where it sustains far under the STREAM ceiling
(5 of 28.6 GB/s on one MoE), quant family buys ~13% while a GPU layer buys far more.

## Benchmark methodology

- Warm up once, then measure sustained runs of >=384 tokens. Single short requests vary +/-25% because reasoning length varies.
- Measure prefill and decode separately, and measure decode **at depth** — decode fell from 27.8 to 20.9 tok/s between an empty context and 40K tokens of KV.
- Compare like-for-like prompts across configurations. Prose and copy-heavy code exercise speculation completely differently.
- n-gram caches learn across repeats of an identical prompt; acceptance rose from 53% to 75% on re-runs. Vary the prompt or accept the inflation knowingly.
- Change one variable per server launch. Reloads are cheap once the page cache is warm.
- **Sweep inside one `llama-bench` invocation.** Across invocations under `-lm mmap`, identical flags gave 20.3 and 25.0 tok/s as page-cache residency varied; `-lm none` reproduced to ±0.1. When a sweep must span invocations, reverse the order to check for ordering bias.
- **`llama-bench` list syntax**: commas separate *sweep values*, so device lists and splits take slashes — `-dev CUDA0/CUDA1 -ts 82/18`. `-dev CUDA0,CUDA1` silently benchmarks each card in turn.
- Server decode runs ~1-2 tok/s below `llama-bench`. Compare server-to-server or bench-to-bench, never across.

## Traps

- **cuBLAS workspace OOM.** Filling VRAM to the brim loads fine, then aborts on the first decode with `cublasCreate_v2` / `the resource allocation failed`. Observed: 117 MiB free crashed, ~300 MiB survived. Keep >=500 MiB free.
- **Estimator undershoots.** `llama-fit-params` ran ~60-130 MiB low for dense/k-quant cases, ~250-390 MiB low for MoE offload, ~780 MiB with an MTP draft context, and ~950 MiB when a large prefill compute buffer dominated. Confirm with `nvidia-smi` after load.
- **The estimator needs the GPUs free.** It allocates while probing, so it aborts with a CUDA backtrace if a server already holds the VRAM. Stop the server first.
- **Estimator output columns** are model, context, compute per device — sum them for the real total.
- **mmap hides disk I/O.** Host "used" memory looks low and throughput looks merely mediocre. Check iowait and set `-lm none`.
- **Port and VRAM release lag process exit.** Wait for the pid to disappear before relaunching, or the next server dies on bind or on allocation.
- **Quantized KV can crash new architectures.** Qwen3.8-Flash-Next's QSA path asserted on Hadamard-rotated quantized KV; f16 was mandatory until upstream fixed it. Test `-ctk q8_0` explicitly on any new model family.
- **PCIe width bounds prefill under MoE offload.** Prefill op-offloads CPU-resident expert weights to the GPU each batch; decode does not. A 3090 on gen3 x4 measured pp512 115 while a 1080 Ti on x8 did 284 on a comparable model, and decode was unaffected on both. Check `pcie.link.width.current` **under load** (it idles at gen1), and put the fast card in the widest slot. `-nopo 1` stops the streaming but measured worse (80 vs 115), so the offload is worth its bandwidth even on a narrow link.
- **A slow second GPU may be a net loss.** Its marginal layers are slow layers and each hop adds latency: a 1080 Ti beside a 3090 was worth +25% on a baseline-ISA build and *lost* to the 3090 alone once the CPU kernels worked. Measure both at the `-ncmoe` each placement forces; a freed card can host a second model. Pascal also has no usable FP16.
- **Shell quoting for `--chat-template-kwargs`.** The JSON must survive intact; word-splitting produces a bare "must be a valid json object string" failure. Run it through a shell (as service managers do) or a script file, not a bare argv array over ssh.

## After changing quants, validate quality

Speed work that silently degrades output is not a win. Compare the candidate against the incumbent with `llama-perplexity` on a fixed corpus, or KL-divergence against the higher-precision file, before committing a quant swap to a service config.

# Diagnostics, Methodology, and Traps

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

## The counterintuitive result worth remembering

When weights sit on the CPU, **decode cost per byte varies by quant family more than total bytes varies by file size**. Measured on one 11 GB card with the same model and context:

| Weights | File | CPU layers | Decode | Prefill |
| --- | --- | --- | --- | --- |
| UD-IQ4_NL | 18 GB | 20/48 | 15.3 t/s | 20.3 t/s |
| UD-Q4_K_M | 22 GB | 24/48 | **29.0 t/s** | **46.5 t/s** |

The larger file, with *more* layers on the CPU and more bytes read per token, ran 89% faster. Reach for a bigger k-quant before assuming a smaller quant is the speed option.

## Benchmark methodology

- Warm up once, then measure sustained runs of >=384 tokens. Single short requests vary +/-25% because reasoning length varies.
- Measure prefill and decode separately, and measure decode **at depth** — decode fell from 27.8 to 20.9 tok/s between an empty context and 40K tokens of KV.
- Compare like-for-like prompts across configurations. Prose and copy-heavy code exercise speculation completely differently.
- n-gram caches learn across repeats of an identical prompt; acceptance rose from 53% to 75% on re-runs. Vary the prompt or accept the inflation knowingly.
- Change one variable per server launch. Reloads are cheap once the page cache is warm.

## Traps

- **cuBLAS workspace OOM.** Filling VRAM to the brim loads fine, then aborts on the first decode with `cublasCreate_v2` / `the resource allocation failed`. Observed: 117 MiB free crashed, ~300 MiB survived. Keep >=500 MiB free.
- **Estimator undershoots.** `llama-fit-params` ran ~60-130 MiB low for dense/k-quant cases and ~780 MiB low for an MoE model with an MTP draft context. Confirm with `nvidia-smi` after load.
- **Estimator output columns** are model, context, compute per device — sum them for the real total.
- **mmap hides disk I/O.** Host "used" memory looks low and throughput looks merely mediocre. Check iowait and set `-lm none`.
- **Port and VRAM release lag process exit.** Wait for the pid to disappear before relaunching, or the next server dies on bind or on allocation.
- **Quantized KV can crash new architectures.** Qwen3.8-Flash-Next's QSA path asserted on Hadamard-rotated quantized KV; f16 was mandatory until upstream fixed it. Test `-ctk q8_0` explicitly on any new model family.
- **Old GPUs.** Pascal has no usable FP16 throughput and IQ kernels are weak there too; validate flash attention and quant choice per card generation.
- **Shell quoting for `--chat-template-kwargs`.** The JSON must survive intact; word-splitting produces a bare "must be a valid json object string" failure. Run it through a shell (as service managers do) or a script file, not a bare argv array over ssh.

## After changing quants, validate quality

Speed work that silently degrades output is not a win. Compare the candidate against the incumbent with `llama-perplexity` on a fixed corpus, or KL-divergence against the higher-precision file, before committing a quant swap to a service config.

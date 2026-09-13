# Knob Reference

Flags as of llama.cpp b10600-era builds. Confirm against `llama-server --help` on the target; names churn (`--draft-max` became `--spec-draft-n-max`).

## Placement

| Flag | Effect | When to turn it |
| --- | --- | --- |
| `-ngl all` | Offload every layer | Default for any GPU deployment |
| `-dev CUDA0,CUDA1` | Restrict/order devices | Pin a model to specific cards |
| `CUDA_VISIBLE_DEVICES=1` (env) | Mask devices before the process starts | Service configs pinning a card; the visible card becomes `CUDA0`, so pass `-dev CUDA0` |
| `-sm layer\|row\|none` | Multi-GPU split strategy | `layer` default; `row` only to rescue a badly underused card |
| `-ts A,B` | Split ratio across devices | Tune so both cards land inside VRAM |
| `-mg N` | Main GPU for shared tensors | Put them on the faster card |
| `-ncmoe N` | MoE experts of first N layers to CPU | The primary VRAM/speed dial for MoE offload |
| `-ot REGEX=CPU` | Per-tensor placement | Pin gather-indexed or oversized tensors to RAM |
| `-fit on/off`, `-fitp on` | Auto-fit placement / print estimate | Keep `off` for reproducibility; `-fitp on` to size without loading |

## Memory

| Flag | Effect | When to turn it |
| --- | --- | --- |
| `-lm none` | Load weights into RAM instead of mmap | Any CPU offload; prevents per-token disk reads |
| `--mlock` | Pin pages | Alternative to `-lm none` under memory pressure |
| `-c N` | Context length | Costs KV; every MiB competes with weights |
| `-ctk`, `-ctv` | KV cache dtype | `q8_0` is the usual free win; verify per architecture |
| `-kvu` | Unified KV across slots | With `-np N`, avoids per-slot reservation |
| `-np N` | Parallel slots | Throughput for concurrent clients |
| `-nkvo` | Keep KV off GPU | Last resort to fit context |
| `--mmproj PATH` | Load a vision projector | Adds image input |
| `--mmproj-device none` | Keep the projector in RAM | Vision at no VRAM and no text-decode cost; images pay CPU ViT instead (~17 s vs ~6 s on a 3090) |
| `--image-min-tokens`, `--image-max-tokens` | Per-image token budget | 1024 is upstream's floor for Qwen-VL; image tokens consume context |

## Compute

| Flag | Effect | When to turn it |
| --- | --- | --- |
| `-fa on/off/auto` | Flash attention | Usually on; verify on pre-Volta and new architectures |
| `-t N`, `-tb N` | Decode / batch threads | Physical cores; SMT rarely helps decode |
| `-b`, `-ub` | Logical / physical batch | Raise for prefill throughput at the cost of buffer size |
| `--poll`, `--cpu-mask`, `--cpu-strict`, `--prio` | Thread scheduling | Only after confirming a scheduling problem |
| `--no-op-offload` | Stop shipping CPU-tensor matmuls to GPU | When PCIe transfer costs more than local compute |

## Speculative decoding

| Flag | Effect |
| --- | --- |
| `--spec-type` | `none`, `draft-simple`, `draft-eagle3`, `draft-mtp`, `draft-dflash`, `draft-dspark`, `ngram-simple`, `ngram-map-k`, `ngram-map-k4v`, `ngram-mod`, `ngram-cache` |
| `--spec-draft-n-max/-n-min` | Draft length for **draft-model** types (default 3) |
| `--spec-ngram-<variant>-size-m` | Draft length for **n-gram** types; defaults are long (~48) |
| `--spec-ngram-<variant>-size-n` | Lookup n-gram length |
| `--spec-ngram-<variant>-min-hits` | Confidence gate before drafting |
| `-md`, `-ngld` | Draft model path / its GPU layers |

Draft length is the knob that decides whether speculation helps or hurts. The per-request `speculative.n_max` body field does not affect n-gram variants — set the launch flag and confirm via the `mean len` value in the server's `draft acceptance` log line.

## Quant selection

Treat quant format as a performance knob wherever weights live on the CPU.

| Family | GPU decode | CPU decode | Use |
| --- | --- | --- | --- |
| IQ (`IQ4_XS`, `IQ4_NL`, `IQ2_*`) | fine | ~1.8x a k-quant per byte on an AVX2 build (7.3 vs 12.9 GB/s); far worse without it | Best quality per byte; wins on CPU too when it is >1.8x smaller |
| K (`Q4_K`, `Q5_K`, `Q6_K`) | fine | cheap | Default whenever layers land on CPU |
| Legacy (`Q4_0`, `Q8_0`) | fine | cheapest, repack-friendly | Maximum CPU throughput; lower quality per byte |

Bigger files are acceptable, and often faster, when bandwidth is spare and CPU cycles are not — but the crossover depends on the build's ISA, and the family in a filename is not the family in the tensors. Dump the GGUF tensor types before trusting either.

## Context as a lever

Under MoE offload, KV and expert layers compete for the same VRAM, so context is paid for in CPU layers. One 3090, Qwen3.8-Flash-Next: 64K/`-ncmoe 30`/25.7 tok/s, 164K/32/22.5, 262K/35/19.7. Choose a point on that curve instead of defaulting to the model's maximum.

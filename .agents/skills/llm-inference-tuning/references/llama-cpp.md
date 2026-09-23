# llama.cpp (llama-server)

Everything llama.cpp-specific: which levers exist for a given deployment shape, what the
flags do, and how to read the bottleneck. Confirm flag names against `llama-server --help`
on the target — they churn (`--draft-max` became `--spec-draft-n-max`). On this host,
llama.cpp reports `CUDA0` as the RTX 3090 and `CUDA1` as the GTX 1080 Ti; this is the
reverse of `nvidia-smi`/CDI indices. Confirm with `llama-server --list-devices`.

## Workflow

1. **Identify the shape** (below). It decides which levers exist at all — a single-GPU run
   has no `-ts` worth tuning and a CPU-offload run has no GPU bandwidth to chase.
2. **Measure the bottleneck** — `scripts/llama-cpp/profile.sh`, then the matching row of
   [Bottleneck guide](#bottleneck-guide). Change only flags that row names.
3. **Size candidates** — `scripts/llama-cpp/fit.sh` sweeps placement without loading
   weights. Estimators run low; confirm on the loaded server with `nvidia-smi`.
4. **Benchmark** — `scripts/bench.sh` (shared with vLLM). Start an isolated server first if
   none is running: `scripts/llama-cpp/serve.sh start --model PATH -- <flags>`. One variable
   at a time, and see [Benchmark comparisons](#benchmark-comparisons) for what makes two runs
   comparable.
5. **Verify** — load the selected settings, keep ≥500 MiB free, and exercise the context
   depth users actually reach. If weight quants changed, validate quality before committing.

## Deployment shapes

Three shapes, each with a different binding constraint. Identify the shape first; it
determines which levers exist.

### A. Weights fit on one GPU

Binding constraint: **VRAM bandwidth** during decode. The GPU streams every active weight
per token.

Levers, in order:

1. `-ngl all -dev CUDA0`. No `-ncmoe`, no `-ts`, no `-sm` — every extra placement flag only
   adds ways to be wrong.
2. Spend leftover VRAM on context, then on a better quant. Quantize KV (`-ctk q8_0 -ctv q8_0`)
   before dropping weight precision; KV quantization costs far less quality per MiB than
   weight quantization.
3. **Speculative decoding genuinely pays here.** Decode is bandwidth-bound with idle SMs, so
   verifying k drafted tokens costs nearly the same as decoding one. Use the model's own MTP
   head (`--spec-type draft-mtp`) when the GGUF ships one, otherwise a small draft model or
   `ngram-*` for copy-heavy work.
4. `-ub` / `-b` upward for prefill throughput if prompts are long; costs a larger compute
   buffer.
5. `-np N -kvu` for concurrent-request throughput. Raises aggregate tok/s, not single-stream
   latency.

### B. Weights fit across multiple GPUs

Binding constraint: **aggregate VRAM bandwidth plus pipeline serialization**. With `-sm layer`
a token traverses GPU0's layers, then GPU1's; per-token latency is additive across cards.

Levers, in order:

1. `-sm layer` (default) and tune `-ts` to the ratio that keeps both cards inside their VRAM
   budget. `-sm row` splits individual tensors and adds interconnect traffic each layer — try
   it only when one card is severely underused.
2. Size `-ts` by VRAM, then verify with `nvidia-smi`. The estimator's split does not account
   for the compute buffer landing on one card.
3. **Decide whether to keep the slow card; do not assume.** Measure both placements at the
   layer split each one permits; a slower card can add more device-hop latency than compute
   capacity, and a freed card can host a second model.
4. Watch per-GPU utilization. If both sit low, the CPU or the hops between devices dominate,
   not the GPUs.
5. `-mg` selects which card holds the shared/output tensors.

### C. GPUs plus CPU offload (MoE)

Binding constraint: **the CPU side**, almost always. GPU utilization of 5-25% during decode is
the normal signature. The GPUs wait while the CPU works through its layers.

Levers, in order:

1. `-lm none` so CPU-resident tensors are read into RAM once. Under mmap they stream from disk
   and every token pays SSD latency; that alone measured 5.4 vs 6.3 tok/s, and iowait is the tell.
2. `-ot` for tensors designed to live in RAM. Gather-indexed tables (e.g. Qwen3.8-Flash-Next's
   `per_layer_token_embd.weight`, ~46 GiB at IQ4) read only a few rows per token, so RAM
   residency is nearly free and the VRAM saved buys many real layers.
3. `-ncmoe N` to trade layers for VRAM. Sweep with `fit.sh`, then confirm against `nvidia-smi`.
4. **Choose the quant by CPU decode cost, and check tensor types rather than the filename.**
   IQ costs ~1.8x per byte against k-quants, so a k-quant wins only under ~1.8x the bytes.
5. KV quantization (`-ctk q8_0 -ctv q8_0`) buys VRAM that converts directly into GPU-resident
   layers.
6. Threads: physical cores. SMT measured neutral to -8%.
7. **Speculative decoding is build- and head-dependent.** Verification activates the union of
   experts across the draft, so it loses badly on a slow CPU backend (MTP 10.4 against 29.0
   tok/s) and wins with working kernels (39.0 against 33.4). Budget ~1.1 GiB of VRAM for the
   draft context, usually two `-ncmoe` steps. Cap n-gram draft length.

## Bottleneck guide

Measure decode throughput with `scripts/llama-cpp/profile.sh`, then follow the row matching
the observed saturation:

| Observation                                      | Bottleneck                        | Useful flags                                 |
| ------------------------------------------------ | --------------------------------- | -------------------------------------------- |
| GPU utilization above 80%                        | GPU compute                       | Smaller weight quant, `-fa`, batch size      |
| GPU low, CPU busy, RAM traffic below its ceiling | CPU compute                       | Cheaper CPU-resident quant, fewer CPU layers |
| GPU low, CPU busy, RAM traffic near its ceiling  | RAM bandwidth                     | Smaller quant, fewer CPU layers              |
| I/O wait above 5%                                | Disk streaming                    | `-lm none` or `--mlock`                      |
| Multiple GPUs underused                          | Device hops or synchronization    | Fewer devices, different `-ts`, `-sm layer`  |
| No resource saturated                            | Batch or synchronization overhead | Larger batch, fewer device boundaries        |

For CPU-resident weights, estimate memory traffic as:

```
bytes/token ~= active_params * (cpu_layers / total_layers) * bytes_per_weight
achieved     = bytes/token * decode_tok_s
```

Compare `achieved` with measured RAM bandwidth. Near the ceiling means bandwidth-bound; well
below it with busy CPU cores means compute-bound.

### Benchmark comparisons

- Warm up once, then measure at least 384 generated tokens.
- Measure prompt and decode throughput separately.
- Measure decode at the context depth users will reach.
- Keep prompts, context, and sampling settings identical.
- Change one variable per comparison.
- Keep at least 500 MiB VRAM free after loading.
- Compare server results with server results and `llama-bench` with `llama-bench`.

## Knobs

### Placement

| Flag                           | Effect                                 | When to turn it                                                                        |
| ------------------------------ | -------------------------------------- | -------------------------------------------------------------------------------------- |
| `-ngl all`                     | Offload every layer                    | Default for any GPU deployment                                                         |
| `-dev CUDA0,CUDA1`             | Restrict/order devices                 | Pin a model to specific cards                                                          |
| `CUDA_VISIBLE_DEVICES=1` (env) | Mask devices before the process starts | Service configs pinning a card; the visible card becomes `CUDA0`, so pass `-dev CUDA0` |
| `-sm layer\|row\|none`         | Multi-GPU split strategy               | `layer` default; `row` only to rescue a badly underused card                           |
| `-ts A,B`                      | Split ratio across devices             | Tune so both cards land inside VRAM                                                    |
| `-mg N`                        | Main GPU for shared tensors            | Put them on the faster card                                                            |
| `-ncmoe N`                     | MoE experts of first N layers to CPU   | The primary VRAM/speed dial for MoE offload                                            |
| `-ot REGEX=CPU`                | Per-tensor placement                   | Pin gather-indexed or oversized tensors to RAM                                         |
| `-fit on/off`, `-fitp on`      | Auto-fit placement / print estimate    | Keep `off` for reproducibility; `-fitp on` to size without loading                     |

### Memory

| Flag                                       | Effect                                | When to turn it                                                                                 |
| ------------------------------------------ | ------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `-lm none`                                 | Load weights into RAM instead of mmap | Any CPU offload; prevents per-token disk reads                                                  |
| `--mlock`                                  | Pin pages                             | Alternative to `-lm none` under memory pressure                                                 |
| `-c N`                                     | Context length                        | Costs KV; every MiB competes with weights                                                       |
| `-ctk`, `-ctv`                             | KV cache dtype                        | `q8_0` is the usual free win; verify per architecture                                           |
| `-kvu`                                     | Unified KV across slots               | With `-np N`, avoids per-slot reservation                                                       |
| `-np N`                                    | Parallel slots                        | Throughput for concurrent clients                                                               |
| `-nkvo`                                    | Keep KV off GPU                       | Last resort to fit context                                                                      |
| `--mmproj PATH`                            | Load a vision projector               | Adds image input                                                                                |
| `--mmproj-device none`                     | Keep the projector in RAM             | Vision at no VRAM and no text-decode cost; images pay CPU ViT instead (~17 s vs ~6 s on a 3090) |
| `--image-min-tokens`, `--image-max-tokens` | Per-image token budget                | 1024 is upstream's floor for Qwen-VL; image tokens consume context                              |

### Compute

| Flag                                             | Effect                                  | When to turn it                                         |
| ------------------------------------------------ | --------------------------------------- | ------------------------------------------------------- |
| `-fa on/off/auto`                                | Flash attention                         | Usually on; verify on pre-Volta and new architectures   |
| `-t N`, `-tb N`                                  | Decode / batch threads                  | Physical cores; SMT rarely helps decode                 |
| `-b`, `-ub`                                      | Logical / physical batch                | Raise for prefill throughput at the cost of buffer size |
| `--poll`, `--cpu-mask`, `--cpu-strict`, `--prio` | Thread scheduling                       | Only after confirming a scheduling problem              |
| `--no-op-offload`                                | Stop shipping CPU-tensor matmuls to GPU | When PCIe transfer costs more than local compute        |

### Speculative decoding

| Flag                              | Effect                                                                                                                                                          |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--spec-type`                     | `none`, `draft-simple`, `draft-eagle3`, `draft-mtp`, `draft-dflash`, `draft-dspark`, `ngram-simple`, `ngram-map-k`, `ngram-map-k4v`, `ngram-mod`, `ngram-cache` |
| `--spec-draft-n-max/-n-min`       | Draft length for **draft-model** types (default 3)                                                                                                              |
| `--spec-ngram-<variant>-size-m`   | Draft length for **n-gram** types; defaults are long (~48)                                                                                                      |
| `--spec-ngram-<variant>-size-n`   | Lookup n-gram length                                                                                                                                            |
| `--spec-ngram-<variant>-min-hits` | Confidence gate before drafting                                                                                                                                 |
| `-md`, `-ngld`                    | Draft model path / its GPU layers                                                                                                                               |

Draft length is the knob that decides whether speculation helps or hurts. The per-request
`speculative.n_max` body field does not affect n-gram variants — set the launch flag and
confirm via the `mean len` value in the server's `draft acceptance` log line.

### Quant selection

Treat quant format as a performance knob wherever weights live on the CPU.

| Family                           | GPU decode | CPU decode                                | Use                                                                                |
| -------------------------------- | ---------- | ----------------------------------------- | ---------------------------------------------------------------------------------- |
| IQ (`IQ4_XS`, `IQ4_NL`, `IQ2_*`) | fine       | higher decode cost per byte than k-quants | Best quality per byte; useful when the smaller file moves more layers onto the GPU |
| K (`Q4_K`, `Q5_K`, `Q6_K`)       | fine       | cheap                                     | Default whenever layers land on CPU                                                |
| Legacy (`Q4_0`, `Q8_0`)          | fine       | cheapest, repack-friendly                 | Maximum CPU throughput; lower quality per byte                                     |

Bigger files are acceptable, and often faster, when bandwidth is spare and CPU cycles are not
— but the crossover depends on the build's ISA, and the family in a filename is not the family
in the tensors. Dump the GGUF tensor types (`scripts/llama-cpp/gguf-types.py`) before trusting
either.

### Context as a lever

Under MoE offload, KV and expert layers compete for the same VRAM, so context is paid for in
CPU layers. One 3090, Qwen3.8-Flash-Next: 64K/`-ncmoe 30`/25.7 tok/s, 164K/32/22.5, 262K/35/19.7.
Choose a point on that curve instead of defaulting to the model's maximum.

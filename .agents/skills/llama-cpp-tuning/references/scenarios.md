# Deployment Shapes

Three shapes, each with a different binding constraint. Identify the shape first; it determines which levers exist.

---

## A. Weights fit on one GPU

Binding constraint: **VRAM bandwidth** during decode. The GPU streams every active weight per token.

Levers, in order:

1. `-ngl all -dev CUDA0`. No `-ncmoe`, no `-ts`, no `-sm` — every extra placement flag only adds ways to be wrong.
2. Spend leftover VRAM on context, then on a better quant. Quantize KV (`-ctk q8_0 -ctv q8_0`) before dropping weight precision; KV quantization costs far less quality per MiB than weight quantization.
3. **Speculative decoding genuinely pays here.** Decode is bandwidth-bound with idle SMs, so verifying k drafted tokens costs nearly the same as decoding one. Use the model's own MTP head (`--spec-type draft-mtp`) when the GGUF ships one, otherwise a small draft model or `ngram-*` for copy-heavy work.
4. `-ub` / `-b` upward for prefill throughput if prompts are long; costs a larger compute buffer.
5. `-np N -kvu` for concurrent-request throughput. Raises aggregate tok/s, not single-stream latency.

## B. Weights fit across multiple GPUs

Binding constraint: **aggregate VRAM bandwidth plus pipeline serialization**. With `-sm layer` a token traverses GPU0's layers, then GPU1's; per-token latency is additive across cards.

Levers, in order:

1. `-sm layer` (default) and tune `-ts` to the ratio that keeps both cards inside their VRAM budget. `-sm row` splits individual tensors and adds interconnect traffic each layer — try it only when one card is severely underused.
2. Size `-ts` by VRAM, then verify with `nvidia-smi`. The estimator's split does not account for the compute buffer landing on one card.
3. **Keep the slow card.** A much older GPU still beats host RAM by roughly 10x on bandwidth, and layers it holds cost the fast card nothing. Measured: dropping a 1080 Ti from a 3090+1080 Ti pair to force those layers onto the CPU cost 27% decode and 51% prefill.
4. Watch per-GPU utilization. If both sit low, the CPU or the hops between devices dominate, not the GPUs.
5. `-mg` selects which card holds the shared/output tensors.

## C. GPUs plus CPU offload (MoE)

Binding constraint: **the CPU side**, almost always. GPU utilization of 5-25% during decode is the normal signature. The GPUs wait while the CPU works through its layers.

Levers, in order:

1. `-lm none` so CPU-resident tensors are read into RAM once. Under mmap they stream from disk and every token pays SSD latency; that alone measured 5.4 vs 6.3 tok/s, and iowait is the tell.
2. `-ot` for tensors designed to live in RAM. Gather-indexed tables (e.g. Qwen3.8-Flash-Next's `per_layer_token_embd.weight`, ~46 GiB at IQ4) read only a few rows per token, so RAM residency is nearly free and the VRAM saved buys many real layers.
3. `-ncmoe N` to trade layers for VRAM. Sweep with `fit.sh`, then confirm against `nvidia-smi`.
4. **Choose the quant for CPU decode cost, not file size.** See `diagnostics.md`. When bandwidth headroom exists, a larger k-quant beats a smaller IQ quant decisively — measured 29.0 vs 15.3 tok/s for Q4_K_M against IQ4_NL on the same card, despite Q4_K_M pushing *more* layers to CPU and reading more bytes per token.
5. KV quantization (`-ctk q8_0 -ctv q8_0`) buys VRAM that converts directly into GPU-resident layers.
6. Threads: leave at physical cores. SMT measured neutral for decode (+5% prefill) because the kernels stall on memory, not on issue slots.
7. **Speculative decoding usually loses here.** Verification activates the union of experts across the whole draft batch, so drafted tokens multiply CPU-side expert reads instead of amortizing them. Measured against 29.0 tok/s plain: MTP 10.4, n-gram at default draft length 18.7, n-gram capped short a wash. Long drafts peg both GPU and CPU while throughput falls.

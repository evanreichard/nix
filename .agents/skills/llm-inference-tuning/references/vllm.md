# vLLM

Generic vLLM: the levers, what the boot log tells you, and how to measure it. This repo's own
vLLM deployment — image pin, profiles, launcher — is `syv-ai.md`, which assumes this doc.

## What you can change, in order of effect

1. **KV cache tier** — `--kv-cache-dtype`: `auto`/`bfloat16`, `fp8`, `int8_per_token_head`,
   int4 variants, `turboquant_*`. Each dtype needs a backend that can read it, and the
   pairing is a boot refusal rather than a slowdown when it is wrong: bf16 runs on
   FLASH_ATTN, TRITON_ATTN and FlashInfer; per-tensor fp8 needs FA3 (sm90+) or TRITON_ATTN
   (sm89+); per-token-head int8 needs TRITON_ATTN. A wider tier is what buys long context.
2. **Context versus pool** — `--max-model-len` sets what one request may hold; the pool is
   whatever is left after weights and activations, divided by bytes per token. Two doors
   into the same number: `--gpu-memory-utilization` (unpinned — the pool then moves with the
   profiled activation peak, which itself moves with compile-cache state) or
   `--kv-cache-memory` (pinned bytes — the boot either fits or refuses). Pin before comparing
   two arms; an unpinned pool is why "it booted at 146k yesterday and OOMs today".
3. **Speculative decoding** — `--speculative-config` JSON: `method` (`draft_model`, `mtp`,
   `eagle`, `ngram`, `dflash`, …), `model`, `num_speculative_tokens`. Draft length decides
   whether it helps: it is a win while verification is cheaper than decoding the same tokens
   one at a time, which is true for bandwidth-bound decode and false for CPU-bound decode.
   The body-level `speculative.n_max` does not retune a launcher-set config.
4. **Prefix caching** — `--enable-prefix-caching` reuses a shared prefix and pays for it in
   state pages. Hybrid/stateful models (mamba, GDN, sliding-window groups) hit a geometry
   lottery: a hit is the intersection of per-group hits, so hit rates swing between
   conversations.
5. **Batching** — `--max-num-batched-tokens` and `--max-num-seqs`. Bigger chunks help prefill
   but grow the per-request KV requirement, which next to a pinned pool shows up as a clean
   refusal at boot ("KV cache is needed, which is larger than the available KV cache memory").
6. **Parallelism** — `--tensor-parallel-size` needs the KV-head count divisible by the TP
   size, and pipeline parallelism needs the layer count to divide by its size; check the
   checkpoint's `config.json` before assuming a three-card split exists.

## Booting one to test

Either a container image that carries its vLLM, or `vllm serve <model>` in a venv — the
launcher details belong to whichever deployment you are testing (see `syv-ai.md` for ours).
What matters is keeping the log and reading the geometry back.

| Line in the boot log                                     | What it resolves                                                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `Initializing a V1 LLM engine (vX.Y.Z) with config: …`   | Version, model path, `speculative_config`, `max_seq_len`, quantization — the fastest way to see what actually launched   |
| `GPU KV cache size: N tokens`                            | The pool, in the unit that matters. Compare it, never the GiB                                                            |
| `Maximum concurrency for M tokens per request: Xx`       | Pool headroom against `max-model-len`                                                                                    |
| `Available KV cache memory: X GiB`                       | The pool _when it is not pinned_ — the number that moves between boots                                                   |
| `Warmed rejection-sampler kernels (k=N, draft_logits=…)` | Whether the speculator allocated its draft-logits buffer; a port that silently skips it loses ~17% and logs nothing else |
| attention-backend and dtype selection                    | What the tier resolved to — FLASH_ATTN / TRITON_ATTN / FlashInfer, and the KV dtype                                      |

## Endpoints and measurement

- OpenAI-compatible: `/v1/chat/completions`, `/v1/completions`, `/v1/models`, `/health`.
- `--enable-per-request-metrics` adds a `metrics` object per response (TTFT, mean ITL,
  generation tokens/s). `scripts/bench.sh` reads that when present and falls back to
  llama.cpp's fields otherwise; without the flag a vLLM body carries only `usage`.
- Reasoning models: thinking on/off and effort travel in `chat_template_kwargs` (or a
  top-level `reasoning_effort`), not as sampling fields. Decode tok/s with thinking on is
  mostly a measurement of how long the model reasons — pin it off for throughput work.
- Sampling: `temperature`, `top_p`, `top_k`, `min_p` are accepted; greedy is `temperature: 0`.
- The served model name is the launcher's `--served-model-name`; a proxy in front may rewrite
  it, so send the alias the endpoint actually answers to.

## Diagnosis

| Symptom                                                       | Check                                                                                                                                                  |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CUDA error: out of memory` at boot                           | Something else owns the card, or the pinned pool exceeds what is left after weights                                                                    |
| Boot refuses with "larger than the available KV cache memory" | `max-model-len` × bytes/token against the pin — shrink the context or the pin                                                                          |
| Decode below expectation                                      | Whether speculation is active and accepting (see the warmup line), the KV dtype's backend, batch size                                                  |
| The same pin gives a different pool on another boot           | Unpinned sizing: profiled activation peak moves with compile-cache state. Pin `--kv-cache-memory`                                                      |
| A streaming response is cut mid-prefill behind a proxy        | The proxy's idle read timeout; vLLM only emits SSE keep-alive comments when its tree carries the patch and the flag is set                             |
| TP/PP startup error                                           | KV heads (TP) or layers (PP) do not divide by the parallel size                                                                                        |
| A KV connector is rejected                                    | Connectors require `expandable_segments:False` in `PYTORCH_CUDA_ALLOC_CONF`                                                                            |
| Quality looks wrong with speculation on                       | The drafter must sample its own distribution — a port that pins the draft probability to 1 is stricter and reads as a quality problem, not a speed one |

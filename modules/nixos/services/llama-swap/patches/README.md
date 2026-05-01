# vLLM Timings Patch

This scratch directory contains two ways to patch vLLM so its OpenAI-compatible responses include llama.cpp-compatible `timings` data. llama-swap already parses this `timings` object to populate cached tokens, prompt processing speed, and generation speed.

## Files

- `patch_timings_07351e088.py` — disk-edit patch script for running inside the vLLM Docker container before `vllm serve`.
- `vllm-timings-07351e088.patch` — standard unified git patch against `vllm/vllm-openai:nightly-07351e0883470724dd5a7e9730ed10e01fc99d08`.

## What The Patch Adds

The patch adds a top-level `timings` object to:

- `/v1/chat/completions` non-streaming responses
- `/v1/chat/completions` streaming final usage chunk
- `/v1/completions` non-streaming responses
- `/v1/completions` streaming final usage chunk

The object matches llama.cpp's fields:

```json
{
  "prompt_n": 123,
  "prompt_ms": 456.7,
  "prompt_per_second": 269.3,
  "predicted_n": 50,
  "predicted_ms": 1000.0,
  "predicted_per_second": 50.0,
  "cache_n": 100
}
```

Data comes from vLLM's existing internal `RequestStateStats` and `RequestOutput.num_cached_tokens`:

- prompt/prefill time: `first_token_ts - scheduled_ts`
- generation/decode time: `last_token_ts - first_token_ts`
- cached tokens: `num_cached_tokens`

## Option 1: Runtime Docker Patch Script

Copy the script into the deployed patch directory:

```bash
cp _scratch/patch_timings_07351e088.py /mnt/ssd/vLLM/Patches/patch_timings_07351e088.py
```

Add the Docker mount in `/etc/nixos/modules/nixos/services/llama-swap/config.nix`:

```nix
-v /mnt/ssd/vLLM/Patches/patch_timings_07351e088.py:/patches/patch_timings_07351e088.py:ro \
```

Run it before `exec vllm serve` in `vllmCmd`:

```bash
python3 /patches/patch_timings_07351e088.py;
exec vllm serve ...
```

The script is idempotent. Re-running it skips files that already contain `# [patch_timings]`.

## Option 2: Standard Patch File

Use this for a source checkout or future vLLM updates where conflicts can be resolved normally.

From a vLLM checkout at commit `07351e0883470724dd5a7e9730ed10e01fc99d08`:

```bash
git apply /path/to/_scratch/vllm-timings-07351e088.patch
```

Or with `patch`:

```bash
patch -p1 < /path/to/_scratch/vllm-timings-07351e088.patch
```

For future vLLM versions, try:

```bash
git apply --check /path/to/_scratch/vllm-timings-07351e088.patch
```

If it fails, apply manually or with rejects and resolve conflicts around the changed response-construction code.

## Verification Performed

The patch was checked against the Docker tag's pinned commit:

```text
vllm/vllm-openai:nightly-07351e0883470724dd5a7e9730ed10e01fc99d08
```

Validation done locally:

```bash
git apply --check _scratch/vllm-timings-07351e088.patch
git apply _scratch/vllm-timings-07351e088.patch
nix run nixpkgs#python3 -- -m py_compile \
  vllm/entrypoints/openai/chat_completion/protocol.py \
  vllm/entrypoints/openai/chat_completion/serving.py \
  vllm/entrypoints/openai/completion/protocol.py \
  vllm/entrypoints/openai/completion/serving.py
```

The runtime `patch_timings_07351e088.py` script was also tested against files extracted from the pinned commit and confirmed idempotent.

## Caveats

- Normal chat completion usage should be correct.
- `/v1/completions` with multiple prompts returns aggregate token counts, but the timing values come from the last completed request. Single-prompt completions are the expected use case.
- Streaming timings are attached only to the final usage chunk, so clients must request/include usage for streaming if they want timings in the stream.

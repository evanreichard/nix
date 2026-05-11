# vLLM Timings Patch

This directory contains the custom timings patch for the current vLLM Docker image used by the llama-swap module:

```text
vllm/vllm-openai:nightly-1acd67a795ebccdf9b9db7697ae9082058301657
```

The patch adds a top-level llama.cpp-compatible `timings` object to OpenAI-compatible responses so llama-swap can populate cached tokens, prompt processing speed, and generation speed.

## Files

- `patch_timings_1acd67a.py` — idempotent boot-time disk-edit patch script for the vLLM Docker container.
- `vllm-timings-1acd67a.patch` — equivalent standard unified git patch against the current image's vLLM source.

## Runtime Script

Deploy the script under `/mnt/ssd/vLLM/Patches/` and mount it into the container:

```nix
-v /mnt/ssd/vLLM/Patches/patch_timings_1acd67a.py:/patches/patch_timings_1acd67a.py:ro \
```

Run it before `exec vllm serve`:

```bash
python3 /patches/patch_timings_1acd67a.py;
exec vllm serve ...
```

The script is idempotent. Re-running it skips files that already contain `# [patch_timings]`.

## Standard Patch

For a source checkout at commit `1acd67a795ebccdf9b9db7697ae9082058301657`:

```bash
git apply --check /path/to/vllm-timings-1acd67a.patch
git apply /path/to/vllm-timings-1acd67a.patch
```

At container runtime, applying the `.patch` directly is possible if the image has `patch` or `git` installed:

```bash
cd /usr/local/lib/python3.12/dist-packages
patch -p1 < /patches/vllm-timings-1acd67a.patch
```

The Python script remains the safer boot-time option because it is idempotent and does not depend on external patch tools being present in the Docker image.

## Timings Fields

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

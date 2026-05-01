"""
Disk-edit patch for vLLM nightly-07351e0883470724dd5a7e9730ed10e01fc99d08:
inject llama.cpp-compatible `timings` into chat/completion API responses.

Adds `timings` to:
  - /v1/chat/completions non-streaming responses
  - /v1/chat/completions streaming final usage chunk
  - /v1/completions non-streaming responses
  - /v1/completions streaming final usage chunk

The `timings` object matches llama.cpp fields consumed by llama-swap:
  prompt_n, prompt_ms, prompt_per_second,
  predicted_n, predicted_ms, predicted_per_second, cache_n

Usage, before `exec vllm serve`:
  python3 /patches/patch_timings.py
"""

import logging
import os
import sys

log = logging.getLogger("patch_timings")
log.setLevel(logging.INFO)
if not log.handlers:
    log.addHandler(logging.StreamHandler())

PATCH_TAG = "# [patch_timings]"

TIMINGS_HELPER = f'''
{PATCH_TAG}
def _compute_timings(metrics, num_prompt, num_gen, num_cached=None):
    """Compute llama.cpp-compatible timings from RequestStateStats."""
    t = {{
        "prompt_n": num_prompt,
        "prompt_ms": 0.0,
        "prompt_per_second": 0.0,
        "predicted_n": num_gen,
        "predicted_ms": 0.0,
        "predicted_per_second": 0.0,
        "cache_n": num_cached if num_cached is not None else -1,
    }}
    if metrics is None:
        return t
    if metrics.first_token_ts > 0 and metrics.scheduled_ts > 0:
        ps = metrics.first_token_ts - metrics.scheduled_ts
        if ps > 0:
            t["prompt_ms"] = ps * 1000.0
            t["prompt_per_second"] = num_prompt / ps
    if metrics.last_token_ts > 0 and metrics.first_token_ts > 0:
        ds = metrics.last_token_ts - metrics.first_token_ts
        if ds > 0:
            t["predicted_ms"] = ds * 1000.0
            t["predicted_per_second"] = num_gen / ds
    return t
'''


def _find_vllm_dir():
    """Auto-discover vLLM install directory."""
    try:
        import vllm
        return os.path.dirname(vllm.__file__)
    except ImportError:
        pass

    for path in [
        "/usr/local/lib/python3.12/dist-packages/vllm",
        "/usr/lib/python3.12/site-packages/vllm",
    ]:
        if os.path.isdir(path):
            return path
    return None


def _read(path):
    with open(path, "r") as f:
        return f.read()


def _write(path, content):
    with open(path, "w") as f:
        f.write(content)


def _replace_once(content, old, new, label):
    count = content.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: anchor matched {count} times")
    return content.replace(old, new, 1)


def _patch_protocol(path, label, replacements):
    if not os.path.exists(path):
        log.error("  %s: file not found: %s", label, path)
        return False

    content = _read(path)
    if PATCH_TAG in content:
        log.info("  %s: already patched, skipping", label)
        return True

    try:
        for old, new in replacements:
            content = _replace_once(content, old, new, label)
    except RuntimeError as e:
        log.error("  %s", e)
        return False

    _write(path, content)
    log.info("  %s: patched successfully", label)
    return True


def _patch_chat_protocol(vllm_dir):
    path = os.path.join(vllm_dir, "entrypoints/openai/chat_completion/protocol.py")
    return _patch_protocol(path, "chat_completion/protocol.py", [
        (
            '''    kv_transfer_params: dict[str, Any] | None = Field(\n        default=None, description="KVTransfer parameters."\n    )\n''',
            '''    kv_transfer_params: dict[str, Any] | None = Field(\n        default=None, description="KVTransfer parameters."\n    )\n\n    # llama.cpp-compatible per-request timings  # [patch_timings]\n    timings: dict[str, Any] | None = None\n''',
        ),
        (
            '''    # not part of the OpenAI spec but for tracing the tokens\n    prompt_token_ids: list[int] | None = None\n''',
            '''    # not part of the OpenAI spec but for tracing the tokens\n    prompt_token_ids: list[int] | None = None\n\n    # llama.cpp-compatible per-request timings  # [patch_timings]\n    timings: dict[str, Any] | None = None\n''',
        ),
    ])


def _patch_completion_protocol(vllm_dir):
    path = os.path.join(vllm_dir, "entrypoints/openai/completion/protocol.py")
    return _patch_protocol(path, "completion/protocol.py", [
        (
            '''    kv_transfer_params: dict[str, Any] | None = Field(\n        default=None, description="KVTransfer parameters."\n    )\n''',
            '''    kv_transfer_params: dict[str, Any] | None = Field(\n        default=None, description="KVTransfer parameters."\n    )\n\n    # llama.cpp-compatible per-request timings  # [patch_timings]\n    timings: dict[str, Any] | None = None\n''',
        ),
        (
            '''class CompletionStreamResponse(OpenAIBaseModel):\n    id: str = Field(default_factory=lambda: f"cmpl-{random_uuid()}")\n    object: str = "text_completion"\n    created: int = Field(default_factory=lambda: int(time.time()))\n    model: str\n    choices: list[CompletionResponseStreamChoice]\n    usage: UsageInfo | None = Field(default=None)\n''',
            '''class CompletionStreamResponse(OpenAIBaseModel):\n    id: str = Field(default_factory=lambda: f"cmpl-{random_uuid()}")\n    object: str = "text_completion"\n    created: int = Field(default_factory=lambda: int(time.time()))\n    model: str\n    choices: list[CompletionResponseStreamChoice]\n    usage: UsageInfo | None = Field(default=None)\n\n    # llama.cpp-compatible per-request timings  # [patch_timings]\n    timings: dict[str, Any] | None = None\n''',
        ),
    ])


def _patch_chat_serving(vllm_dir):
    path = os.path.join(vllm_dir, "entrypoints/openai/chat_completion/serving.py")
    label = "chat_completion/serving.py"
    if not os.path.exists(path):
        log.error("  %s: file not found: %s", label, path)
        return False

    content = _read(path)
    if PATCH_TAG in content:
        log.info("  %s: already patched, skipping", label)
        return True

    try:
        # Helper Function
        content = _replace_once(
            content,
            "class OpenAIServingChat(OpenAIServing):",
            TIMINGS_HELPER + "\n\nclass OpenAIServingChat(OpenAIServing):",
            label,
        )

        # Streaming Last Result Capture - first streaming loop only.
        content = _replace_once(
            content,
            "            async for res in result_generator:\n                if res.prompt_token_ids is not None:",
            f"            async for res in result_generator:\n                _last_stream_res = res  {PATCH_TAG}\n                if res.prompt_token_ids is not None:",
            label,
        )

        # Streaming Final Usage Chunk - pinned image has no system_fingerprint arg.
        content = _replace_once(
            content,
            '''                final_usage_chunk = ChatCompletionStreamResponse(\n                    id=request_id,\n                    object=chunk_object_type,\n                    created=created_time,\n                    choices=[],\n                    model=model_name,\n                    usage=final_usage,\n                )\n''',
            f'''                final_usage_chunk = ChatCompletionStreamResponse(\n                    id=request_id,\n                    object=chunk_object_type,\n                    created=created_time,\n                    choices=[],\n                    model=model_name,\n                    usage=final_usage,\n                )\n                # Inject Timings  {PATCH_TAG}\n                try:\n                    _s_cached = _last_stream_res.num_cached_tokens\n                    final_usage_chunk.timings = _compute_timings(\n                        _last_stream_res.metrics,\n                        num_prompt_tokens, completion_tokens, _s_cached,\n                    )\n                except NameError:\n                    pass\n''',
            label,
        )

        # Non-Streaming Response - pinned image has no system_fingerprint arg.
        content = _replace_once(
            content,
            '''        response = ChatCompletionResponse(\n            id=request_id,\n            created=created_time,\n            model=model_name,\n            choices=choices,\n            usage=usage,\n            prompt_logprobs=clamp_prompt_logprobs(final_res.prompt_logprobs),\n            prompt_token_ids=(\n                final_res.prompt_token_ids if request.return_token_ids else None\n            ),\n            kv_transfer_params=final_res.kv_transfer_params,\n        )\n''',
            f'''        response = ChatCompletionResponse(\n            id=request_id,\n            created=created_time,\n            model=model_name,\n            choices=choices,\n            usage=usage,\n            prompt_logprobs=clamp_prompt_logprobs(final_res.prompt_logprobs),\n            prompt_token_ids=(\n                final_res.prompt_token_ids if request.return_token_ids else None\n            ),\n            kv_transfer_params=final_res.kv_transfer_params,\n        )\n\n        # Inject Timings  {PATCH_TAG}\n        _cached = final_res.num_cached_tokens\n        response.timings = _compute_timings(\n            final_res.metrics, num_prompt_tokens, num_generated_tokens,\n            _cached,\n        )\n''',
            label,
        )
    except RuntimeError as e:
        log.error("  %s", e)
        return False

    _write(path, content)
    log.info("  %s: patched successfully", label)
    return True


def _patch_completion_serving(vllm_dir):
    path = os.path.join(vllm_dir, "entrypoints/openai/completion/serving.py")
    label = "completion/serving.py"
    if not os.path.exists(path):
        log.error("  %s: file not found: %s", label, path)
        return False

    content = _read(path)
    if PATCH_TAG in content:
        log.info("  %s: already patched, skipping", label)
        return True

    try:
        # Helper Function
        content = _replace_once(
            content,
            "class OpenAIServingCompletion(OpenAIServing):",
            TIMINGS_HELPER + "\n\nclass OpenAIServingCompletion(OpenAIServing):",
            label,
        )

        # Streaming Last Result Capture.
        content = _replace_once(
            content,
            "            async for prompt_idx, res in result_generator:\n                prompt_token_ids = res.prompt_token_ids",
            f"            async for prompt_idx, res in result_generator:\n                _last_comp_res = res  {PATCH_TAG}\n                prompt_token_ids = res.prompt_token_ids",
            label,
        )

        # Streaming Final Usage Chunk - pinned image has no system_fingerprint arg.
        content = _replace_once(
            content,
            '''                final_usage_chunk = CompletionStreamResponse(\n                    id=request_id,\n                    created=created_time,\n                    model=model_name,\n                    choices=[],\n                    usage=final_usage_info,\n                )\n''',
            f'''                final_usage_chunk = CompletionStreamResponse(\n                    id=request_id,\n                    created=created_time,\n                    model=model_name,\n                    choices=[],\n                    usage=final_usage_info,\n                )\n                # Inject Timings  {PATCH_TAG}\n                try:\n                    _sc_cached = _last_comp_res.num_cached_tokens\n                    final_usage_chunk.timings = _compute_timings(\n                        _last_comp_res.metrics,\n                        total_prompt_tokens, total_completion_tokens,\n                        _sc_cached,\n                    )\n                except NameError:\n                    pass\n''',
            label,
        )

        # Non-Streaming Response - pinned image has no system_fingerprint arg.
        content = _replace_once(
            content,
            '''        return CompletionResponse(\n            id=request_id,\n            created=created_time,\n            model=model_name,\n            choices=choices,\n            usage=usage,\n            kv_transfer_params=kv_transfer_params,\n        )\n''',
            f'''        _comp_response = CompletionResponse(  {PATCH_TAG}\n            id=request_id,\n            created=created_time,\n            model=model_name,\n            choices=choices,\n            usage=usage,\n            kv_transfer_params=kv_transfer_params,\n        )\n        # Inject Timings  {PATCH_TAG}\n        if last_final_res is not None:\n            _comp_cached = last_final_res.num_cached_tokens\n            _comp_response.timings = _compute_timings(\n                last_final_res.metrics, num_prompt_tokens,\n                num_generated_tokens, _comp_cached,\n            )\n        return _comp_response\n''',
            label,
        )
    except RuntimeError as e:
        log.error("  %s", e)
        return False

    _write(path, content)
    log.info("  %s: patched successfully", label)
    return True


def apply():
    vllm_dir = _find_vllm_dir()
    if vllm_dir is None:
        log.error("Could not find vLLM installation directory")
        return False

    log.info("Found vLLM at: %s", vllm_dir)
    ok = True
    ok &= _patch_chat_protocol(vllm_dir)
    ok &= _patch_chat_serving(vllm_dir)
    ok &= _patch_completion_protocol(vllm_dir)
    ok &= _patch_completion_serving(vllm_dir)
    return ok


if __name__ == "__main__":
    if apply():
        print("patch_timings: All patches applied successfully")
    else:
        print("patch_timings: Some patches failed!", file=sys.stderr)
        sys.exit(1)

# https://huggingface.co/Lorbus/Qwen3.6-27B-int4-AutoRound
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.6 27B (vLLM, 50K, CUDA0)";
  backend = "vllm-club3090";
  placement = "cuda0";
  checkEndpoint = "/v1/models";
  macros.ctx = "50000";
  cmd = ''
    ${backends.docker} run --rm --device=nvidia.com/gpu=all \
      --name ''${MODEL_ID} \
      -e CUDA_VISIBLE_DEVICES=0 \
      -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0 \
      -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
      -p ''${PORT}:8000 \
      vllm/vllm-openai:latest \
      /root/.cache/huggingface/qwen3.6-27b-autoround-int4 \
      --served-model-name ''${MODEL_ID} \
      --quantization auto_round \
      --dtype float16 \
      --tensor-parallel-size 1 \
      --gpu-memory-utilization 0.97 \
      --max-model-len ''${ctx} \
      --max-num-seqs 1 \
      --max-num-batched-tokens 4128 \
      --kv-cache-dtype fp8_e5m2 \
      --enable-chunked-prefill \
      --enable-prefix-caching \
      --speculative-config '{"method":"mtp","num_speculative_tokens":3}' \
      --enable-auto-tool-choice \
      --tool-call-parser qwen3_coder \
      --trust-remote-code \
      --default-chat-template-kwargs '{"enable_thinking": false}' \
      --host 0.0.0.0 \
      --port 8000
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
    ];
  };
}

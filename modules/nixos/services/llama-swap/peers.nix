# Remote OpenAI-compatible backends llama-swap proxies to. The API key is injected by
# default.nix from sops, not stored here.
{
  synthetic = {
    proxy = "https://api.synthetic.new/openai/";
    contextWindows = {
      "hf:Qwen/Qwen3.8-27B" = 262144;
      "hf:deepseek-ai/DeepSeek-V4.1-Flash" = 524288;
      "hf:moonshotai/Kimi-K3" = 524288;
      "hf:nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4" = 262144;
      "hf:openai/gpt-oss-120b" = 131072;
      "hf:zai-org/GLM-4.7-Flash" = 196608;
      "hf:zai-org/GLM-5.3-Flash" = 524288;
    };
    models = [
      "hf:Qwen/Qwen3.8-27B"
      "hf:deepseek-ai/DeepSeek-V4.1-Flash"
      "hf:moonshotai/Kimi-K3"
      "hf:nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4"
      "hf:openai/gpt-oss-120b"
      "hf:zai-org/GLM-4.7-Flash"
      "hf:zai-org/GLM-5.3-Flash"
    ];
  };
}

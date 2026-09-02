# Remote OpenAI-compatible backends llama-swap proxies to. The API key is injected by
# default.nix from sops, not stored here.
{
  synthetic = {
    proxy = "https://api.synthetic.new/openai/";
    contextWindows = {
      "hf:moonshotai/Kimi-K3" = 524288;
      "hf:Qwen/Qwen3.6-27B" = 262144;
      "hf:zai-org/GLM-4.7-Flash" = 196608;
      "hf:zai-org/GLM-5.2" = 524288;
    };
    models = [
      "hf:Qwen/Qwen3.6-27B"
      "hf:moonshotai/Kimi-K3"
      "hf:zai-org/GLM-4.7-Flash"
      "hf:zai-org/GLM-5.2"
    ];
  };
}

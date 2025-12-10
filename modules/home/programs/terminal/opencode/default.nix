{ lib
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.opencode;
in
{
  options.${namespace}.programs.terminal.opencode = {
    enable = lib.mkEnableOption "enable opencode";
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        theme = "catppuccin";
        provider = {
          "llama-swap" = {
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "https://llm-api.va.reichard.io/v1";
            };
            models = {
              "gpt-oss-20b-thinking" = {
                name = "GPT OSS (20B)";
              };
              qwen3-coder-30b-instruct = {
                name = "Qwen3 Coder (30B)";
              };
              qwen3-30b-2507-thinking = {
                name = "Qwen3 2507 (30B) Thinking";
              };
              qwen3-30b-2507-instruct = {
                name = "Qwen3 2507 (30B) Instruct";
              };
            };
          };
        };
        mcp = {
          gopls = {
            type = "local";
            command = [
              "gopls"
              "mcp"
            ];
            enabled = true;
          };
        };
      };
    };
  };
}

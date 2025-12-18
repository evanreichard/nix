{ lib
, pkgs
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
        permission = {
          edit = "allow";
          bash = "ask";
          webfetch = "ask";
          doom_loop = "ask";
          external_directory = "ask";
        };
        lsp = {
          nil = {
            command = [
              "${pkgs.nil}/bin/nil"
              "--stdio"
            ];
            extensions = [ ".nix" ];
          };
        };
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
              "${pkgs.gopls}/bin/gopls"
              "mcp"
            ];
            enabled = true;
          };
        };
      };
    };
  };
}

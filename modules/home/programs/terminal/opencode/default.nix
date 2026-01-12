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
    # Enable OpenCode
    programs.opencode = {
      enable = true;
      package = pkgs.reichard.opencode;
      enableMcpIntegration = true;
      agents = {
        orchestrator = ./config/agents/orchestrator.md;
        architect = ./config/agents/architect.md;
        developer = ./config/agents/developer.md;
        reviewer = ./config/agents/reviewer.md;
        agent-creator = ./config/agents/agent-creator.md;
      };
    };

    # Define OpenCode Configuration
    sops = {
      secrets.context7_apikey = {
        sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
      };
      templates."opencode.json" = {
        path = ".config/opencode/opencode.json";
        content = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          theme = "catppuccin";
          # model = "llama-swap/devstral-small-2-instruct";
          provider = {
            "llama-swap" = {
              npm = "@ai-sdk/openai-compatible";
              options = {
                baseURL = "https://llm-api.va.reichard.io/v1";
              };
              models = {
                "hf:Qwen/Qwen3-Coder-480B-A35B-Instruct" = {
                  name = "Qwen3 Coder (480B) Instruct";
                };
                "hf:zai-org/GLM-4.7" = {
                  name = "GLM 4.7";
                };
                "hf:MiniMaxAI/MiniMax-M2.1" = {
                  name = "MiniMax M2.1";
                };
                devstral-small-2-instruct = {
                  name = "Devstral Small 2 (24B)";
                };
                qwen3-coder-30b-instruct = {
                  name = "Qwen3 Coder (30B)";
                };
                nemotron-3-nano-30b-thinking = {
                  name = "Nemotron 3 Nano (30B) - Thinking";
                };
                gpt-oss-20b-thinking = {
                  name = "GPT OSS (20B)";
                };
                qwen3-next-80b-instruct = {
                  name = "Qwen3 Next (80B) - Instruct";
                };
                qwen3-30b-2507-thinking = {
                  name = "Qwen3 2507 (30B) Thinking";
                };
                qwen3-30b-2507-instruct = {
                  name = "Qwen3 2507 (30B) Instruct";
                };
                qwen3-4b-2507-instruct = {
                  name = "Qwen3 2507 (4B) - Instruct";
                };
              };
            };
          };
          lsp = {
            biome = {
              disabled = true;
            };
            starlark = {
              command = [
                "${pkgs.pyright}/bin/pyright-langserver"
                "--stdio"
              ];
              extensions = [ ".star" ];
            };
          };
          mcp = {
            context7 = {
              type = "remote";
              url = "https://mcp.context7.com/mcp";
              headers = {
                CONTEXT7_API_KEY = "${config.sops.placeholder.context7_apikey}";
              };
              enabled = true;
            };
          };
        };
      };
    };
  };
}

{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;

  helpers = import ./lib.nix { inherit lib; };
  llamaSwapConfig = import ./../../../../nixos/services/llama-swap/config.nix { inherit pkgs; };

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
        planner = ./config/agents/planner.md;
        developer = ./config/agents/developer.md;
        reviewer = ./config/agents/reviewer.md;
        agent-creator = ./config/agents/agent-creator.md;
      };
      commands = {
        commit = ./config/commands/commit.md;
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
          provider = {
            "llama-swap" = {
              npm = "@ai-sdk/openai-compatible";
              options = {
                baseURL = "https://llm-api.va.reichard.io/v1";
              };
              models = helpers.toOpencodeModels llamaSwapConfig;
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

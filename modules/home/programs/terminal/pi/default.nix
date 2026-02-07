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

  cfg = config.${namespace}.programs.terminal.pi;
in
{
  options.${namespace}.programs.terminal.pi = {
    enable = lib.mkEnableOption "enable pi";
  };

  config = mkIf cfg.enable {
    # Add Pi Coding Agent to Home Packages
    home.packages = with pkgs; [
      reichard.pi-coding-agent
    ];

    # Define Pi Configuration
    home.file = {
      ".pi/agent/models.json" = {
        text = builtins.toJSON {
          providers = {
            "llama-swap" = {
              baseUrl = "https://llm-api.va.reichard.io/v1";
              api = "openai-completions";
              apiKey = "none";
              models = helpers.toPiModels llamaSwapConfig;
            };
          };
        };
      };
      ".pi/agent/AGENTS.md" = {
        source = ./config/AGENTS.md;
      };
      ".pi/agent/skills" = {
        source = ./config/skills;
        recursive = true;
      };
      ".pi/agent/prompts" = {
        source = ./config/prompts;
        recursive = true;
      };
    };
  };
}

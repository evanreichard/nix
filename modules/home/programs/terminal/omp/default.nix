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

  cfg = config.${namespace}.programs.terminal.omp;

  homeDir = config.home.homeDirectory;

  # Sops Render Directory - `sops.templates.<name>.path` is a symlink into this directory, so
  # the sandbox has to bind the rendered file rather than the symlink target's declared path.
  sopsRendered = "${homeDir}/.config/sops-nix/secrets/rendered";

  # Sandbox Binds - $HOME is a tmpfs inside the sandbox, so every path omp genuinely needs has
  # to be listed. Missing paths are skipped at runtime.
  sandboxRoBinds = [
    "${sopsRendered}/omp-models.yml"
    "${sopsRendered}/omp-env"
    "${homeDir}/.gitconfig"
    "${homeDir}/.config/git"
  ]
  ++ cfg.sandbox.extraRoBinds;

  sandboxRwBinds = cfg.sandbox.extraRwBinds;

  ompSandbox = import ../agent-shared/sandbox.nix {
    inherit lib pkgs;
    name = "omp";
    package = pkgs.${namespace}.omp;
    roBinds = sandboxRoBinds;
    rwBinds = sandboxRwBinds;
    inherit (cfg.sandbox) shareNet bindSshAgent;
  };

  # Omp Environment - omp keeps credentials in `~/.omp/agent/agent.db`, which nothing but omp
  # itself may write, so declarative keys arrive through the `~/.omp/agent/.env` dotenv file it
  # loads on startup. Non-secret settings that pair with a key (the SearXNG endpoint behind the
  # built-in web_search) ride along so search config lives in one place.
  ompSecretEnv = [
    {
      envVar = "ZAI_API_KEY";
      secretName = "zai_apikey";
    }
    {
      envVar = "SYNTHETIC_API_KEY";
      secretName = "synthetic_apikey";
    }
    {
      envVar = "OPENCODE_API_KEY";
      secretName = "opencode_go_apikey";
    }
    {
      envVar = "KAGI_API_KEY";
      secretName = "kagi_token";
    }
    {
      envVar = "GITEA_TOKEN";
      secretName = "gitea_token";
    }
  ];

  ompPlainEnv = {
    SEARXNG_ENDPOINT = "https://search.va.reichard.io";
  };

  ompEnvFile = lib.concatStringsSep "\n" (
    map (entry: "${entry.envVar}=${config.sops.placeholder.${entry.secretName}}") ompSecretEnv
    ++ lib.mapAttrsToList (name: value: "${name}=${value}") ompPlainEnv
  );
in
{
  options.${namespace}.programs.terminal.omp = {
    enable = lib.mkEnableOption "enable omp";

    sandbox = {
      enable = lib.mkEnableOption "run omp inside a bubblewrap sandbox" // {
        default = true;
      };
      shareNet = lib.mkEnableOption "give the sandbox host network access" // {
        default = true;
      };
      bindSshAgent = lib.mkEnableOption "expose $SSH_AUTH_SOCK to the sandbox";
      extraRoBinds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths bind-mounted read-only into the omp sandbox.";
      };
      extraRwBinds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths bind-mounted read-write into the omp sandbox.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Add Omp to Home Packages - `omp` is the sandboxed wrapper when the sandbox is enabled;
    # `omp-dangerous` is always the unwrapped binary.
    home.packages = [
      (if cfg.sandbox.enable then ompSandbox.sandboxed else pkgs.${namespace}.omp)
      ompSandbox.dangerous
    ];

    # Define Omp Configuration - `config.yml` is deliberately absent: omp rewrites it at
    # runtime (theme, model roles, setup state), so it stays user-owned. The guidance, skills,
    # and prompts are agent-agnostic and shared with pi via `../agent-shared/config`.
    home.file = {
      ".omp/agent/AGENTS.md" = {
        source = ../agent-shared/config/AGENTS.md;
      };
      ".omp/agent/skills" = {
        source = ../agent-shared/config/skills;
        recursive = true;
      };
      ".omp/agent/prompts" = {
        source = ../agent-shared/config/prompts;
        recursive = true;
      };
    };

    sops = lib.mkIf config.${namespace}.security.sops.enable {
      secrets = {
        "llama_swap_api_keys/pi" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/common/llama-swap.yaml";
        };
      }
      // lib.listToAttrs (
        map
          (entry: {
            name = entry.secretName;
            value.sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
          })
          ompSecretEnv
      );

      templates."omp-env" = {
        path = "${homeDir}/.omp/agent/.env";
        content = ompEnvFile;
      };

      # Omp Models Config - JSON is a YAML subset, so the rendered template is a valid
      # `models.yml`; writing the canonical `.yml` name also skips omp's legacy
      # `models.json` -> `models.yml` migration.
      templates."omp-models.yml" = {
        path = "${homeDir}/.omp/agent/models.yml";
        content = builtins.toJSON {
          providers = {
            "llama-swap" = {
              baseUrl = "https://llm-api.va.reichard.io/v1";
              api = "openai-completions";
              apiKey = config.sops.placeholder."llama_swap_api_keys/pi";
              models = helpers.toOmpModels llamaSwapConfig;
            };
          };
        };
      };
    };
  };
}

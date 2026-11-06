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
  providerRegistry = builtins.fromJSON (
    builtins.readFile ./../../../../nixos/services/llama-swap/providers/providers.json
  );
  providerRoot = ./../../../../nixos/services/llama-swap/providers;

  cfg = config.${namespace}.programs.terminal.pi;

  homeDir = config.home.homeDirectory;

  # Sandbox Binds - $HOME is a tmpfs inside the sandbox, so every path pi
  # genuinely needs has to be listed. Missing paths are skipped at runtime.
  sandboxRoBinds = [
    "${homeDir}/.config/sops-nix/secrets/rendered/pi-models.json"
    "${homeDir}/.config/sops-nix/secrets/rendered/pi-web.json"
    "${homeDir}/.gitconfig"
    "${homeDir}/.config/git"
  ]
  ++ cfg.sandbox.extraRoBinds;

  sandboxRwBinds = cfg.sandbox.extraRwBinds;

  piSandboxed = import ../agent-shared/sandbox.nix {
    inherit lib pkgs;
    name = "pi";
    package = pkgs.${namespace}.pi-coding-agent;
    roBinds = sandboxRoBinds;
    rwBinds = sandboxRwBinds;
    inherit (cfg.sandbox) shareNet bindSshAgent;
  };

  # Pool Ladders - One floor per alias per account window, in percent *remaining*: pi-usage desugars
  # them into the per-entry suspendAt/resumeBelow rules it evaluates. Each row is "alias floor", and
  # row order is the priority statement (weakest alias first, floors strictly falling) so a weaker
  # alias yields before a stronger one can spend the same shared pool. Rows stay strings because the
  # order has to survive emission: mapping keys get sorted, list order does not.
  poolLadders = {
    "openai-codex:weekly" = [ "fast 60" "balanced 30" "deep 5" ];
    "opencode-go:weekly" = [ "fast 30" "deep 20" ];
    "synthetic:weekly" = [ "fast 20" "balanced 15" ];
    "zai:tokens" = [ "balanced 20" "deep 10" ];
  };

  # Ladders Are Emitted By Hand - The YAML generator sorts mapping keys, which would reorder a ladder
  # and fail pi-usage's falling-floor check, so the ordered rows are rendered here and concatenated
  # ahead of the generated modes.
  renderLadder = lib.concatMapStrings (
    row:
    let
      parts = lib.splitString " " row;
    in
    "          ${builtins.head parts}: ${builtins.elemAt parts 1}%\n"
  );
  renderPools = lib.concatStrings (
    lib.mapAttrsToList (key: rows: "      ${key}:\n        ladder:\n${renderLadder rows}") poolLadders
  );

  # Entry Rules - Uniform reserves and window opt-outs only; anything that differs per alias is a
  # pool above. `null` disables an inherited global rule for a provider that never reports the window
  # (Synthetic has no 5-hour allowance, Z.ai no rolling/weekly) instead of leaving a note behind.
  reserveHysteresis = 5;
  reserve = windows: {
    usage.windows = lib.mapAttrs
      (
        _: minRemaining:
          if minRemaining == null then
            false
          else
            {
              suspendAt = "${toString (100 - minRemaining)}%";
              resumeBelow = "${toString (100 - minRemaining - reserveHysteresis)}%";
            }
      )
      windows;
  };
  route =
    provider: model: thinking: policy:
    if policy == null then
      { inherit provider model thinking; }
    else
      {
        inherit
          provider
          model
          thinking
          policy
          ;
      };

  piUsageModes = {
    fast = [
      (route "opencode-go" "qwen3.7-plus" "low" null)
      (route "openai-codex" "gpt-6-luna" "medium" null)
      (route "synthetic" "hf:deepseek-ai/DeepSeek-V4.1-Flash-1017" "low" (reserve {
        rolling = null;
      }))
    ];
    balanced = [
      (route "synthetic" "hf:deepseek-ai/DeepSeek-V4.1-Flash-1017" "high" (reserve {
        rolling = null;
      }))
      (route "zai" "glm-5.3" "medium" (reserve {
        rolling = null;
        weekly = null;
        requests = 10;
      }))
      (route "openai-codex" "gpt-6.1-sol" "medium" null)
    ];
    deep = [
      (route "openai-codex" "gpt-6.1-sol" "high" null)
      (route "opencode-go" "kimi-k3.1-pro" "high" null)
      (route "zai" "glm-5.3" "high" (reserve {
        rolling = null;
        weekly = null;
        requests = 10;
      }))
    ];
  };

  piUsageConfigFile = pkgs.concatText "pi-usage.yaml" [
    (pkgs.writeText "pi-usage-head.yaml" ''
      version: 1
      provider: auto
      defaultMode: balanced
      monitoring:
        refreshInterval: 2m
      policy:
        usage:
          # One missed refresh still counts as fresh; reserves are advisory between reads.
          maxAge: 5m
          hysteresis: ${toString reserveHysteresis}%
          windows:
            rolling:
              suspendAt: 85%
              resumeBelow: 80%
            weekly:
              suspendAt: 90%
              resumeBelow: 85%
          pools:
      ${renderPools}'')
    ((pkgs.formats.yaml { }).generate "pi-usage-modes.yaml" { modes = piUsageModes; })
  ];

  # Nix-Owned Plugin List - Source of truth for `packages` in settings.json.
  # Merged into the (mutable) settings.json on activation so pi can keep
  # writing other fields (current model, etc.) without us clobbering them.
  piPackages = [
    "https://gitea.va.reichard.io/evan/pi-remote.git@main"
    "https://gitea.va.reichard.io/evan/pi-session-broker.git@main"
    "https://gitea.va.reichard.io/evan/pi-web.git@main"
    "https://gitea.va.reichard.io/evan/pi-subagents.git@main"
    "https://gitea.va.reichard.io/evan/pi-usage.git@main"
    "https://gitea.va.reichard.io/evan/pi-statusline.git@main"
    "https://gitea.va.reichard.io/evan/pi-daybreak.git@main"
    "https://github.com/sting8k/pi-vcc.git@v0.8.0"
    "npm:@juicesharp/rpiv-ask-user-question"
    "npm:pi-imagegen"
  ];

  piPackagesJson = pkgs.writeText "pi-packages.json" (builtins.toJSON piPackages);

  piSessionBrokerConfigScript = pkgs.writeShellScript "pi-session-broker-config" ''
    set -euo pipefail

    PI_CONFIG="$HOME/.pi/agent/pi-session-broker.json"
    SOPS_CONFIG="${config.sops.templates."pi-session-broker.json".path}"
    if [ ! -s "$SOPS_CONFIG" ]; then
      echo "Skipping pi-session-broker config merge; missing sops template: $SOPS_CONFIG" >&2
      exit 0
    fi

    mkdir -p "$(dirname "$PI_CONFIG")"
    if [ -L "$PI_CONFIG" ]; then
      rm "$PI_CONFIG"
    fi
    [ -s "$PI_CONFIG" ] || echo '{}' > "$PI_CONFIG"
    tmp=$(mktemp)
    ${pkgs.jq}/bin/jq --slurpfile broker "$SOPS_CONFIG" \
      '. * $broker[0]' "$PI_CONFIG" > "$tmp"
    mv "$tmp" "$PI_CONFIG"
    chmod 600 "$PI_CONFIG"
  '';

  # Pi Auth Api Keys - These are merged into mutable auth.json on activation.
  # Add another entry here to manage another top-level provider auth key.
  piAuthApiKeys = [
    {
      provider = "zai";
      secretName = "zai_apikey";
      jqVar = "zai";
      sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
    }
    {
      provider = "synthetic";
      secretName = "synthetic_apikey";
      jqVar = "synthetic";
      sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
    }
    {
      provider = "opencode-go";
      secretName = "opencode_go_apikey";
      jqVar = "opencode";
      sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
    }
  ];

  piAuthJqRawfiles = lib.concatStringsSep " \\\n          " (
    map
      (
        auth: ''--rawfile ${auth.jqVar} "${config.sops.secrets.${auth.secretName}.path}"''
      )
      piAuthApiKeys
  );

  piAuthJqFilter = lib.concatStringsSep " | " (
    map
      (
        auth: ''.["${auth.provider}"] = { type: "api_key", key: ($'' + auth.jqVar + ''| rtrimstr("\n")) }''
      )
      piAuthApiKeys
  );

  piAuthMergeScript = pkgs.writeShellScript "pi-auth-merge" ''
    set -euo pipefail

    PI_AUTH="$HOME/.pi/agent/auth.json"
    mkdir -p "$(dirname "$PI_AUTH")"

    if [ -L "$PI_AUTH" ]; then
      rm "$PI_AUTH"
    fi

    for secret in ${
      lib.concatStringsSep " " (
        map (auth: ''"${config.sops.secrets.${auth.secretName}.path}"'') piAuthApiKeys
      )
    }; do
      if [ ! -e "$secret" ]; then
        echo "Skipping pi auth merge; missing sops secret: $secret" >&2
        exit 0
      fi
    done

    [ -s "$PI_AUTH" ] || echo '{}' > "$PI_AUTH"
    tmp=$(mktemp)
    ${pkgs.jq}/bin/jq ${piAuthJqRawfiles} \
      '${piAuthJqFilter}' "$PI_AUTH" > "$tmp"
    mv "$tmp" "$PI_AUTH"
    chmod 600 "$PI_AUTH"
  '';
in
{
  options.${namespace}.programs.terminal.pi = {
    enable = lib.mkEnableOption "enable pi";

    sandbox = {
      # Linux Only - The wrapper is bubblewrap, which needs Linux user namespaces. Leaving this
      # off keeps `pkgs.bubblewrap` out of the closure entirely, so darwin evaluates and builds.
      enable = lib.mkEnableOption "install `pi-sandboxed`, a bubblewrap-confined pi" // {
        default = pkgs.stdenv.hostPlatform.isLinux;
      };
      shareNet = lib.mkEnableOption "give the sandbox host network access" // {
        default = true;
      };
      bindSshAgent = lib.mkEnableOption "expose $SSH_AUTH_SOCK to the sandbox";
      extraRoBinds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths bind-mounted read-only into the pi sandbox.";
      };
      extraRwBinds = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional paths bind-mounted read-write into the pi sandbox.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable Glimpse
    ${namespace}.programs.terminal.glimpse.enable = true;

    # Add Pi Coding Agent to Home Packages - `pi` is always the unwrapped binary; `pi-sandboxed`
    # is the bubblewrap-confined wrapper, installed when the sandbox is enabled.
    home.packages = [
      pkgs.${namespace}.pi-coding-agent
      pkgs.${namespace}.pi-remote
    ]
    ++ lib.optional cfg.sandbox.enable piSandboxed;

    # Define Pi Configuration - AGENTS.md, skills, and prompts are agent-agnostic and shared
    # with omp via `../agent-shared/config`; extensions are a pi-only format.
    home.file = {
      ".pi/agent/AGENTS.md" = {
        source = ../agent-shared/config/AGENTS.md;
      };

      ".pi/agent/usage.yaml" = {
        source = piUsageConfigFile;
      };
      ".pi/agent/skills" = {
        source = ../agent-shared/config/skills;
        recursive = true;
      };
      ".pi/agent/prompts" = {
        source = ../agent-shared/config/prompts;
        recursive = true;
      };
      ".pi/agent/extensions" = {
        source = ./config/extensions;
        recursive = true;
      };
    };

    # Pi Models Config - Provider metadata is read from the shared llama-swap registry and
    # converted into pi's models.json format during sops template evaluation.
    sops = lib.mkIf config.${namespace}.security.sops.enable {
      secrets = {
        "llama_swap_api_keys/pi" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/common/llama-swap.yaml";
        };
        pi_session_broker_token = { };
        pi_session_broker_endpoint = { };
        # Pairing replaces the shared token: this template carries only the hub address, and the extension writes
        # machine.json and hub.json beside it as ordinary mutable state.
        pi_remote_endpoint = { };
      }
      // lib.listToAttrs (
        map
          (auth: {
            name = auth.secretName;
            value.sopsFile = auth.sopsFile;
          })
          piAuthApiKeys
      );
      # This extension keeps its own directory, and sops-install-secrets creates the parent for a template path.
      templates."pi-remote-config" = {
        path = "${config.home.homeDirectory}/.pi/agent/pi-remote/config.json";
        content = builtins.toJSON {
          serverUrl = config.sops.placeholder.pi_remote_endpoint;
          allowSpawn = true;
        };
      };
      templates."pi-session-broker.json" = {
        content = builtins.toJSON {
          gatewayUrl = config.sops.placeholder.pi_session_broker_endpoint;
          agentApiKey = config.sops.placeholder.pi_session_broker_token;
        };
      };
      # Pi Web Config - Sops template so the kagi and synthetic keys
      # (declared by the glimpse module and pi auth, respectively) can be
      # embedded alongside the non-secret searxng base URL.
      templates."pi-web.json" = {
        path = "${config.home.homeDirectory}/.pi/pi-web/config.json";
        content = builtins.toJSON {
          webSearch = {
            providerPriority = [
              "synthetic"
              "kagi"
              "searxng"
              "parallel"
            ];
            synthetic.apiKey = "${config.sops.placeholder.synthetic_apikey}";
            kagi.token = "${config.sops.placeholder.kagi_token}";
            searxng.baseUrl = "https://search.va.reichard.io";
          };
          webFetch.providerPriority = [
            "camoufox"
            "firefox"
            "http"
          ];
        };
      };
      templates."pi-models.json" = {
        path = "${config.home.homeDirectory}/.pi/agent/models.json";
        content =
          let
            providerSources = lib.mapAttrs
              (_: provider: {
                file = (toString providerRoot) + "/${provider.modelsFile}";
                baseUrl = provider.baseUrl;
                api = provider.api;
                apiKey = config.sops.placeholder.${provider.sopsSecret};
                filter = if provider ? modelIds then model: builtins.elem model.id provider.modelIds else _: true;
              })
              providerRegistry;
            generatedProviders = lib.mapAttrs
              (_: provider: {
                inherit (provider) baseUrl api apiKey;
                models = helpers.toPiOpenAIModels {
                  catalogue = builtins.fromJSON (builtins.readFile provider.file);
                  inherit (provider) filter;
                };
              })
              providerSources;
          in
          builtins.toJSON {
            providers = generatedProviders // {
              "llama-swap" = {
                baseUrl = "https://llm-api.va.reichard.io/v1";
                api = "openai-completions";
                apiKey = config.sops.placeholder."llama_swap_api_keys/pi";
                models = helpers.toPiModels llamaSwapConfig;
              };
            };
          };
      };
    };

    # Merge Nix-Defined Plugins Into Mutable settings.json - We can't symlink
    # this file into the nix store because pi rewrites it at runtime (e.g. to
    # persist the last-used model). Instead, on every activation we use jq to
    # set `.packages` from Nix while preserving every other field.
    home.activation.piSettingsMerge = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      PI_SETTINGS="$HOME/.pi/agent/settings.json"
      mkdir -p "$(dirname "$PI_SETTINGS")"
      [ -s "$PI_SETTINGS" ] || echo '{}' > "$PI_SETTINGS"
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq --slurpfile pkgs ${piPackagesJson} \
        '.packages = $pkgs[0]' "$PI_SETTINGS" > "$tmp"
      mv "$tmp" "$PI_SETTINGS"
    '';

    # Writable Relay Config - Remote Pi's URL command rewrites this file, so merge rather than symlink it.
    home.activation.piRemoteConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      PI_REMOTE_CONFIG="$HOME/.pi/remote/config.json"
      mkdir -p "$(dirname "$PI_REMOTE_CONFIG")"
      [ -s "$PI_REMOTE_CONFIG" ] || echo '{}' > "$PI_REMOTE_CONFIG"
      tmp=$(mktemp "$PI_REMOTE_CONFIG.XXXXXX")
      if ${pkgs.jq}/bin/jq --arg relay "https://remote-pi.va.reichard.io" \
        '.relay = $relay' "$PI_REMOTE_CONFIG" > "$tmp"; then
        mv "$tmp" "$PI_REMOTE_CONFIG"
      else
        rm -f "$tmp"
        exit 1
      fi
    '';

    # Keep Machine Identity - The extension persists its ID, so merge SOPS values into a writable file.
    # A read-only template would prevent identity creation.
    home.activation.piSessionBrokerConfig = lib.mkIf config.${namespace}.security.sops.enable (
      config.lib.dag.entryAfter [ "sops-nix" "writeBoundary" ] ''
        ${piSessionBrokerConfigScript}
      ''
    );

    systemd.user.services.pi-session-broker-config = lib.mkIf config.${namespace}.security.sops.enable {
      Unit = {
        Description = "Merge sops-managed Pi Session Broker config";
        After = [ "sops-nix.service" ];
        Requires = [ "sops-nix.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = piSessionBrokerConfigScript;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Merge Api Key Auth Into Mutable auth.json - Pi needs auth.json to stay
    # writable, so merge sops-managed API keys instead of symlinking the whole
    # file. Existing provider auth entries are preserved.
    home.activation.piAuthMerge = lib.mkIf config.${namespace}.security.sops.enable (
      config.lib.dag.entryAfter [ "sops-nix" "writeBoundary" ] ''
        ${piAuthMergeScript}
      ''
    );

    # Run Pi Auth Merge After Sops - During NixOS system activation, sops-nix
    # can be restarted asynchronously and secrets may not exist yet. This user
    # service retries the merge in the normal user systemd graph after sops-nix.
    systemd.user.services.pi-auth-merge = lib.mkIf config.${namespace}.security.sops.enable {
      Unit = {
        Description = "Merge sops-managed Pi auth entries";
        After = [ "sops-nix.service" ];
        Requires = [ "sops-nix.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = piAuthMergeScript;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

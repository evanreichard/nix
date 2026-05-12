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

  # Nix-Owned Plugin List - Source of truth for `packages` in settings.json.
  # Merged into the (mutable) settings.json on activation so pi can keep
  # writing other fields (current model, etc.) without us clobbering them.
  piPackages = [
    "https://gitea.va.reichard.io/evan/pi-lsp.git@main"
    "https://gitea.va.reichard.io/evan/pi-subagents.git@main"
    "https://gitea.va.reichard.io/evan/pi-statusline.git@main"
  ];

  piPackagesJson = pkgs.writeText "pi-packages.json" (builtins.toJSON piPackages);

  # Pi Auth Api Keys - These are merged into mutable auth.json on activation.
  # Add another entry here to manage another top-level provider auth key.
  piAuthApiKeys = [
    {
      provider = "zai";
      secretName = "zai_apikey";
      jqVar = "zai";
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
  };

  config = mkIf cfg.enable {
    # Enable Glimpse
    ${namespace}.programs.terminal.glimpse.enable = true;

    # Add Pi Coding Agent to Home Packages
    home.packages = with pkgs; [ reichard.pi-coding-agent ];

    # Define Pi Configuration
    home.file = {

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
      ".pi/agent/extensions" = {
        source = ./config/extensions;
        recursive = true;
      };
    };

    # Pi Models Config - Inject llama-swap API key from sops into models.json
    # so pi can authenticate against the llm-api endpoint.
    sops = lib.mkIf config.${namespace}.security.sops.enable {
      secrets = {
        "llama_swap_api_keys/pi" = {
          sopsFile = lib.snowfall.fs.get-file "secrets/common/llama-swap.yaml";
        };
      }
      // lib.listToAttrs (
        map
          (auth: {
            name = auth.secretName;
            value.sopsFile = auth.sopsFile;
          })
          piAuthApiKeys
      );
      templates."pi-models.json" = {
        path = "${config.home.homeDirectory}/.pi/agent/models.json";
        content = builtins.toJSON {
          providers = {
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

{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    recursiveUpdate
    listToAttrs
    ;

  apiKeys = [
    "evan"
    "pi"
    "aethera"
  ];
  cfg = config.${namespace}.services.llama-swap;

  llama-swap = pkgs.reichard.llama-swap;
  llamaCppPresets =
    let
      definitions = (import ./lib.nix { inherit pkgs; }).importModels ./models;
      llamaCppModels = lib.filterAttrs
        (
          _: model:
            builtins.elem model.backend [
              "llama-cpp"
              "ik-llama-cpp"
            ]
        )
        definitions;
    in
    builtins.mapAttrs
      (_: model: {
        inherit (model) cmd;
        name = model.name or "";
        env = model.env or [ ];
      })
      llamaCppModels;
  llamaCppPresetFile = pkgs.writeText "llama-cpp-presets.json" (builtins.toJSON llamaCppPresets);
  llama-cpp-bisect-context = pkgs.writeShellApplication {
    name = "llama-cpp-bisect-context";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnused
      python3
      util-linux
    ];
    text = builtins.replaceStrings [ "__LLAMA_CPP_PRESETS__" ] [ "${llamaCppPresetFile}" ] (
      builtins.readFile ./scripts/llama-cpp-bisect-context
    );
  };
in
{
  options.${namespace}.services.llama-swap = {
    enable = mkEnableOption "enable llama-swap service";
    config = lib.mkOption {
      type = lib.types.unspecified;
      default = import ./config.nix { inherit pkgs; };
      readOnly = true;
      description = "The llama-swap configuration data";
    };
  };

  config = mkIf cfg.enable {
    # Create User
    users.groups.llama-swap = { };
    users.users.llama-swap = {
      isSystemUser = true;
      group = "llama-swap";
      extraGroups = [ "podman" ];
    };

    # Create Service
    systemd.services.llama-swap = {
      description = "Model swapping for LLaMA C++ Server (or any local OpenAPI compatible server)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe llama-swap} --listen :8080 --config ${
          config.sops.templates."llama-swap.json".path
        }";
        Restart = "on-failure";
        RestartSec = 3;

        # GPU Acceleration
        PrivateDevices = false;

        # Hardening
        User = "llama-swap";
        Group = "llama-swap";
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        NoNewPrivileges = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        MemoryDenyWriteExecute = true;
        LimitMEMLOCK = "infinity";
        LockPersonality = true;
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        SystemCallErrorNumber = "EPERM";
        ProtectProc = "invisible";
        ProtectHostname = true;
        ProcSubset = "pid";
      };
    };

    # Create Config
    sops = {
      secrets =
        (listToAttrs (
          map
            (name: {
              name = "llama_swap_api_keys/${name}";
              value = {
                sopsFile = lib.snowfall.fs.get-file "secrets/common/llama-swap.yaml";
              };
            })
            apiKeys
        ))
        // {
          synthetic_apikey = {
            sopsFile = lib.snowfall.fs.get-file "secrets/common/systems.yaml";
          };
        };
      templates."llama-swap.json" = {
        restartUnits = [ "llama-swap.service" ];
        owner = "llama-swap";
        group = "llama-swap";
        mode = "0400";
        content = builtins.toJSON (
          recursiveUpdate cfg.config {
            apiKeys = map (name: config.sops.placeholder."llama_swap_api_keys/${name}") apiKeys;
            peers.synthetic.apiKey = config.sops.placeholder.synthetic_apikey;
          }
        );
      };
    };

    environment.systemPackages = [ llama-cpp-bisect-context ];

    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}

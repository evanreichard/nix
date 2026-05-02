{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption recursiveUpdate listToAttrs;

  apiKeys = [ "evan" "pi" "aethera" ];
  cfg = config.${namespace}.services.llama-swap;

  llama-swap = pkgs.reichard.llama-swap;
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

        # for GPU acceleration
        PrivateDevices = false;

        # hardening
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
      secrets = listToAttrs (map (name: {
        name = "llama_swap_api_keys/${name}";
        value = {
          sopsFile = lib.snowfall.fs.get-file "secrets/common/llama-swap.yaml";
        };
      }) apiKeys);
      templates."llama-swap.json" = {
        owner = "llama-swap";
        group = "llama-swap";
        mode = "0400";
        content = builtins.toJSON (
          recursiveUpdate cfg.config {
            apiKeys = map (name: config.sops.placeholder."llama_swap_api_keys/${name}") apiKeys;
          }
        );
      };
    };

    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}

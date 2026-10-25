{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf mkOption types;
  cfg = config.${namespace}.services.backup;
  hostname = config.networking.hostName;
  destination = config.sops.placeholder;
in
{
  options.${namespace}.services.backup = {
    enable = mkEnableOption "Storage Box backups with Restic";
    sopsFile = mkOption {
      type = types.str;
      default = "secrets/systems/${hostname}.yaml";
      description = "Repository-relative SOPS file containing backups/<job>/password and backups/<job>/ssh_key.";
    };
    destinationSopsFile = mkOption {
      type = types.str;
      default = "secrets/common/backups.yaml";
      description = "Repository-relative SOPS file containing storagebox/host, storagebox/user, and storagebox/host_key.";
    };
    jobs = mkOption {
      default = { };
      description = "Named backup jobs; advanced settings use services.restic.backups.<name>.";
      type = types.attrsOf (types.submodule {
        options = {
          paths = mkOption {
            type = types.listOf (types.strMatching "/.+");
            description = "Absolute paths to back up. Stage live databases consistently before uploading.";
          };
          schedule = mkOption {
            type = types.str;
            default = "*-*-* 03:15:00";
            description = "Systemd OnCalendar expression, interpreted in the host time zone.";
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    assertions = lib.mapAttrsToList (name: job: {
      assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null && job.paths != [ ];
      message = "Backup jobs need a simple alphanumeric name (hyphens/underscores allowed) and at least one path.";
    }) cfg.jobs;

    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets = lib.mkMerge ([
      (lib.listToAttrs (map (field: lib.nameValuePair "backup-storagebox-${field}" {
        sopsFile = lib.snowfall.fs.get-file cfg.destinationSopsFile;
        key = "storagebox/${field}";
      }) [ "host" "user" "host_key" ]))
    ] ++ lib.mapAttrsToList (name: _: {
      "backup-${name}-password" = {
        sopsFile = lib.snowfall.fs.get-file cfg.sopsFile;
        key = "backups/${name}/password";
      };
      "backup-${name}-ssh-key" = {
        sopsFile = lib.snowfall.fs.get-file cfg.sopsFile;
        key = "backups/${name}/ssh_key";
      };
    }) cfg.jobs);

    sops.templates = lib.mkMerge ([
      {
        "backup-storagebox-known-hosts".content = ''
          [${destination."backup-storagebox-host"}]:23 ${destination."backup-storagebox-host_key"}
        '';
      }
    ] ++ lib.mapAttrsToList (name: _: {
      "backup-${name}-repository".content =
        "sftp://${destination."backup-storagebox-user"}@${destination."backup-storagebox-host"}:23/nixos/${hostname}/${name}";
      "backup-${name}-ssh-config".content = ''
        Host storagebox
          HostName ${destination."backup-storagebox-host"}
          User ${destination."backup-storagebox-user"}
          Port 23
          IdentityFile ${config.sops.secrets."backup-${name}-ssh-key".path}
          IdentitiesOnly yes
          BatchMode yes
          StrictHostKeyChecking yes
          UserKnownHostsFile ${config.sops.templates."backup-storagebox-known-hosts".path}
          GlobalKnownHostsFile /dev/null
          ServerAliveInterval 60
          ServerAliveCountMax 3
          ConnectTimeout 30
      '';
    }) cfg.jobs);

    services.restic.backups = lib.mapAttrs (name: job: {
      paths = mkDefault job.paths;
      repositoryFile = mkDefault config.sops.templates."backup-${name}-repository".path;
      passwordFile = mkDefault config.sops.secrets."backup-${name}-password".path;
      extraOptions = [
        "sftp.command=${lib.escapeShellArg "${pkgs.openssh}/bin/ssh -F ${config.sops.templates."backup-${name}-ssh-config".path} storagebox -s sftp"}"
      ];
      initialize = mkDefault true;
      timerConfig = {
        OnCalendar = mkDefault job.schedule;
        Persistent = mkDefault true;
        RandomizedDelaySec = mkDefault "15m";
      };
      pruneOpts = mkDefault [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];
      runCheck = mkDefault true;
      checkOpts = mkDefault [ "--read-data-subset=5%" ];
    }) cfg.jobs;
  };
}

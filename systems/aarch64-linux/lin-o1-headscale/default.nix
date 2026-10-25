{ config
, namespace
, pkgs
, lib
, modulesPath
, ...
}:
let
  inherit (lib.${namespace}) enabled;
  backupEnabled = config.${namespace}.services.backup.enable;
  backupDirectory = "/var/lib/headscale-backup";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "26.05";
  time.timeZone = "UTC";

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # Legacy Partion Name
  fileSystems."/boot".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-ESP";

  reichard = {
    nix = enabled;

    system = {
      disk = {
        enable = true;
        diskPath = "/dev/sda";
      };
      networking = enabled;
    };

    services = {
      openssh = enabled;
      backup = {
        enable = true;
        jobs.headscale = {
          paths = [ "${backupDirectory}/snapshot" ];
          schedule = "*-*-* 03:15:00";
        };
      };
      headscale = {
        enable = true;
        openFirewall = true;
        policy = ./acl.hujson;
      };
      tailscale = {
        enable = true;
        enableRouting = true;
      };
    };
  };

  services.headscale.settings = {
    server_url = "https://headscale.reichard.io";
    dns = {
      base_domain = "reichard.dev";
      nameservers = {
        global = [ "9.9.9.9" ];
        split = {
          "reichard.io" = [ "10.0.20.20" ];
        };
      };
    };
  };

  services.restic.backups.headscale = lib.mkIf backupEnabled {
    backupPrepareCommand = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}
      marker=${backupDirectory}/restart-headscale
      restart_headscale() {
        if [[ -e "$marker" ]]; then
          systemctl start headscale.service && rm "$marker"
        fi
      }
      # Restart Marker - ExecStopPost can recover the service even if preparation is killed before its trap runs.
      trap 'result=$?; trap - EXIT; restart_headscale || result=1; exit "$result"' EXIT
      restart_headscale
      rm -rf ${backupDirectory}/snapshot
      mkdir -m 700 ${backupDirectory}/snapshot
      if systemctl is-active --quiet headscale.service; then
        touch "$marker"
        systemctl stop headscale.service
      fi
      cp -a --reflink=auto /var/lib/headscale/. ${backupDirectory}/snapshot/
      restart_headscale
    '';
    backupCleanupCommand = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.systemd ]}
      if [[ -e ${backupDirectory}/restart-headscale ]]; then
        systemctl start headscale.service
        rm ${backupDirectory}/restart-headscale
      fi
      rm -rf ${backupDirectory}/snapshot
    '';
  };

  systemd.services.restic-backups-headscale = lib.mkIf backupEnabled {
    serviceConfig = {
      StateDirectory = "headscale-backup";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    tmux
    vim
  ];
}

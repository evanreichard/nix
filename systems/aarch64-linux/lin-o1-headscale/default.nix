{ namespace
, pkgs
, lib
, modulesPath
, ...
}:
let
  inherit (lib.${namespace}) enabled;
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

  environment.systemPackages = with pkgs; [
    btop
    tmux
    vim
  ];
}

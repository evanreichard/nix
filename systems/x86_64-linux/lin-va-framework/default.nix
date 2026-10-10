{ namespace
, inputs
, lib
, pkgs
, config
, utils
, ...
}:
let
  inherit (lib.${namespace}) enabled;

  passwordPresent = pkgs.writeShellScript "sddm-password-present" ''
    IFS= read -r -d "" password || true
    [[ -n "$password" ]]
  '';
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  system.stateVersion = "26.05";

  programs.firejail.enable = true;
  programs.nix-ld.enable = true;
  boot.zswap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 100;
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec = "1h";
    HibernateOnACPower = true;
  };
  security.pam.services = {
    hyprlock.fprintAuth = false;

    sddm-password = {
      useDefaultRules = false;
      rules.auth = lib.mapAttrs (_: rule: builtins.removeAttrs rule [ "name" "settings" ]) (
        lib.filterAttrs (name: _: name != "fprintd") config.security.pam.services.login.rules.auth
      );
    };

    # Empty Password Gate - SDDM runs PAM sequentially; a supplied password must skip the fingerprint wait.
    sddm.rules.auth = lib.mkForce (utils.pam.autoOrderRules [
      {
        name = "password-present";
        control = "[success=1 default=ignore]";
        modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
        args = [ "expose_authtok" "quiet" "${passwordPresent}" ];
      }
      {
        name = "fprintd";
        control = "sufficient";
        modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
      }
      {
        name = "password";
        control = "substack";
        modulePath = "sddm-password";
      }
    ]);
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    automatic-timezoned.enable = true;
    fstrim.enable = true;
    fwupd.enable = true;
    blueman.enable = true;
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
    };
  };

  reichard = {
    nix = enabled;
    user.extraGroups = [ "dialout" ];

    system = {
      boot = {
        enable = true;
        enableGrub = false;
        enableSystemd = true;
        silentBoot = true;
      };
      disk = {
        enable = true;
        diskPath = "/dev/nvme0n1";
        swapSize = "48G";
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware.opengl = {
      enable = true;
      enable32Bit = true;
    };

    services = {
      mounts.enableMedia = true;
      avahi = enabled;
      printing = enabled;
      tailscale = enabled;
      ydotool = enabled;
    };

    security.sops = enabled;

    virtualisation.podman = enabled;

    programs.graphical.wms.hyprland = enabled;
  };

  environment.systemPackages = with pkgs; [
    mosh
    rclone
    unzip
  ];
}

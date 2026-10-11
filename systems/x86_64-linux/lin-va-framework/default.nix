{ namespace
, inputs
, lib
, pkgs
, config
, ...
}:
let
  inherit (lib.${namespace}) enabled;

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
  systemd.tmpfiles.rules = [ "w /sys/power/pm_async - - - - 0" ];

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
      airplay = enabled;
      avahi = enabled;
      printing = enabled;
      tailscale = enabled;
      ydotool = enabled;
    };

    security.sops = enabled;

    virtualisation.podman = enabled;

    display-managers.greetd = {
      defaultUser = "evanreichard";
      uiScale = 2.0;
    };

    programs.graphical.wms.hyprland = enabled;
  };

  nixpkgs.overlays = [
    (_final: prev: {
      weston = prev.weston.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./weston-pointer-focus-serial.patch ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          export XDG_RUNTIME_DIR=$(mktemp -d)
          meson test --no-rebuild --print-errorlogs pointer-late-bind pointer
          # Pixman Fixture - GL and Vulkan fixtures need a rendering device unavailable in the sandbox.
          meson test --no-rebuild --print-errorlogs --test-args='--fixture 1' pointer-shot
          runHook postCheck
        '';
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    mosh
    rclone
    unzip
  ];
}

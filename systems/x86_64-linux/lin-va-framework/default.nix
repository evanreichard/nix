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

  greeterCursor = pkgs.catppuccin-cursors.macchiatoMauve;
  sddmSelected = config.reichard.programs.graphical.wms.hyprland.displayManager == "sddm";
  greetdSelected = config.reichard.programs.graphical.wms.hyprland.displayManager == "greetd";

  passwordPresent = pkgs.writeShellScript "login-password-present" ''
    IFS= read -r -d "" password || true
    [[ -n "$password" ]]
  '';
  passwordOnlyRules = lib.mapAttrs (_: rule: builtins.removeAttrs rule [ "name" "settings" ]) (
    lib.filterAttrs (name: _: name != "fprintd") config.security.pam.services.login.rules.auth
  );
  passwordOrFingerprint = passwordService: utils.pam.autoOrderRules [
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
      modulePath = passwordService;
    }
  ];
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
  security.pam.services = {
    hyprlock.fprintAuth = false;

    sddm-password = lib.mkIf sddmSelected {
      useDefaultRules = false;
      rules.auth = passwordOnlyRules;
    };
    greetd-password = lib.mkIf greetdSelected {
      useDefaultRules = false;
      rules.auth = passwordOnlyRules // {
        unix = passwordOnlyRules.unix // {
          args = lib.filter (arg: arg != "nullok") passwordOnlyRules.unix.args;
        };
      };
    };

    # Empty Password Gate - PAM runs serially; a supplied password must skip the fingerprint wait.
    sddm.rules.auth = lib.mkIf sddmSelected (lib.mkForce (passwordOrFingerprint "sddm-password"));
    greetd.rules.auth = lib.mkIf greetdSelected (lib.mkForce (passwordOrFingerprint "greetd-password"));
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

    display-managers.sddm.theme = lib.mkIf sddmSelected {
      name = "sddm-shan-shui";
      package = pkgs.reichard.sddm-shan-shui.override {
        themeConfig = {
          Palette = "catppuccin-mocha";
        };
      };
      extraPackages = [ pkgs.kdePackages.qtsvg ];
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

    services.shan-shui-lock = enabled;
    display-managers.greetd = {
      defaultUser = "evanreichard";
      uiScale = 2.0;
    };

    programs.graphical.wms.hyprland = {
      enable = true;
      displayManager = "greetd";
    };
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

  services.displayManager.sddm.settings.Theme = lib.mkIf sddmSelected {
    CursorTheme = "catppuccin-macchiato-mauve-cursors";
    CursorSize = 24;
  };

  # Greeter Environment - SDDM filters daemon variables; Qt needs the cursor search path in the greeter session.
  services.displayManager.sddm.settings.General.GreeterEnvironment = lib.mkIf sddmSelected "XCURSOR_PATH=${greeterCursor}/share/icons";

  environment.systemPackages = with pkgs; [
    greeterCursor
    mosh
    rclone
    unzip
  ];
}

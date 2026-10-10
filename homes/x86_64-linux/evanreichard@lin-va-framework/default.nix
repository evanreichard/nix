{ pkgs
, lib
, config
, namespace
, osConfig
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "26.05";

  services.hyprpolkitagent.enable = true;
  services.hypridle = {
    enable = true;
    settings.general = {
      lock_cmd = "pidof hyprlock || hyprlock";
      before_sleep_cmd = "loginctl lock-session";
      after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      inhibit_sleep = 3;
    };
  };
  programs.hyprlock = {
    enable = true;
    settings = {
      auth.fingerprint = {
        enabled = true;
        ready_message = "󰌾  |  󰈷";
        present_message = "󰈷  …";
      };
      animations = {
        enabled = true;
        bezier = [ "linear, 1, 1, 0, 0" ];
        animation = [
          "fadeIn, 1, 5, linear"
          "fadeOut, 1, 5, linear"
          "inputFieldDots, 1, 2, linear"
        ];
      };
      background = {
        monitor = "";
        path = "screenshot";
        blur_passes = 3;
      };
      input-field = {
        monitor = "";
        size = "20%, 5%";
        outline_thickness = 3;
        inner_color = "rgba(0, 0, 0, 0.0)";
        outer_color = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        check_color = "rgba(00ff99ee) rgba(ff6633ee) 120deg";
        fail_color = "rgba(ff6633ee) rgba(ff0066ee) 40deg";
        font_color = "rgb(143, 143, 143)";
        fade_on_empty = false;
        rounding = 15;
        font_family = "MesloLGS Nerd Font Mono";
        placeholder_text = "$FPRINTPROMPT";
        fail_text = "$PAMFAIL";
        dots_spacing = 0.3;
        position = "0, -20";
        halign = "center";
        valign = "center";
      };
      label = [
        {
          monitor = "";
          text = "$TIME";
          font_size = 90;
          font_family = "Monospace";
          position = "-30, 0";
          halign = "right";
          valign = "top";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] date +"%A, %d %B %Y"'';
          font_size = 25;
          font_family = "Monospace";
          position = "-30, -150";
          halign = "right";
          valign = "top";
        }
      ];
    };
  };

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      ssh-agent = enabled;
      fusuma = enabled;
      awww = enabled;
    };

    security.sops = enabled;

    programs = {
      graphical = {
        wms.hyprland = {
          enable = true;
          mainMod = "ALT";
          bluetooth = true;
          monitors = [ ",highres,auto,2" ];
        };
        ghostty = enabled;
        ghidra = enabled;
        gimp = enabled;
        browsers.firefox = {
          enable = true;
          gpuAcceleration = true;
          hardwareDecoding = true;
        };
      };

      terminal = {
        btop = enabled;
        direnv = enabled;
        conduit = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        opencode = enabled;
        pi = enabled;
        omp = enabled;
      };
    };
  };

  home.packages = with pkgs; [
    orca-slicer
    solvespace
  ];

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = "catppuccin-macchiato-mauve-cursors";
    cursor-size = 24;
  };

  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-macchiato-mauve-cursors";
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    size = 24;
  };

  sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/lin-va-kube";
    };
  };
}

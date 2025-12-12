{ namespace
, pkgs
, config
, lib
, ...
}:
let
  inherit (lib.${namespace}) enabled;
  cfg = config.${namespace}.user;
in
{
  system.stateVersion = "25.11";
  time.timeZone = "America/New_York";

  nixpkgs.config.allowUnfree = true;

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        silentBoot = true;
      };
      disk = {
        enable = true;
        diskPath = "/dev/sda";
      };
      networking = {
        enable = true;
        useStatic = {
          interface = "enp5s0";
          address = "10.0.50.120";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.20.20" ];
        };
      };
    };

    hardware = {
      opengl = {
        enable = true;
        enableNvidia = true;
      };
    };

    services = {
      openssh = enabled;
      llama-cpp = enabled;
      rtl-tcp = enabled;
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    btop
    git
    tmux
    vim
  ];
}

{ config
, inputs
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.virtualisation.podman;

  # Podman Desktop - 26.05 pins Electron 42, which nixpkgs now marks EOL/insecure; unstable tracks a current Electron.
  podmanDesktop = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.podman-desktop;
in
{
  options.${namespace}.virtualisation.podman = {
    enable = lib.mkEnableOption "podman";
    enableNvidia = lib.mkEnableOption "enable nvidia";
    desktop = {
      enable = lib.mkEnableOption "podman desktop GUI";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      podman-compose
    ] ++ lib.optional cfg.desktop.enable podmanDesktop;

    reichard = {
      user = {
        extraGroups = [
          "docker"
          "podman"
        ];
      };
    };

    hardware.nvidia-container-toolkit.enable = mkIf cfg.enableNvidia true;

    virtualisation = {
      podman = {
        inherit (cfg) enable;

        autoPrune = {
          enable = true;
          flags = [ "--all" ];
          dates = "weekly";
        };

        defaultNetwork.settings.dns_enabled = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
    };
  };
}

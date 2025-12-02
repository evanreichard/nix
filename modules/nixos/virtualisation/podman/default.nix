{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.virtualisation.podman;
in
{
  options.${namespace}.virtualisation.podman = {
    enable = lib.mkEnableOption "podman";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-desktop
    ];

    reichard = {
      user = {
        extraGroups = [
          "docker"
          "podman"
        ];
      };
    };

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

{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) types mkIf mkForce mkOption mkEnableOption;
  inherit (lib.${namespace}) mkBoolOpt enabled;

  cfg = config.${namespace}.system.networking;
in
{
  options.${namespace}.system.networking = {
    enable = mkEnableOption "Enable Networking";
    enableIWD = mkEnableOption "Enable IWD";
    useDHCP = mkBoolOpt true "Use DHCP";
    useNetworkd = mkBoolOpt false "Use networkd";
    useStatic = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          interface = mkOption {
            type = lib.types.str;
            description = "Network interface name";
            example = "enp0s3";
          };
          address = mkOption {
            type = types.str;
            description = "Static IP address";
            example = "10.0.20.200";
          };
          defaultGateway = mkOption {
            type = types.str;
            description = "Default gateway IP";
            example = "10.0.20.254";
          };
          nameservers = mkOption {
            type = types.listOf types.str;
            description = "List of DNS servers";
            example = [ "10.0.20.254" "8.8.8.8" ];
            default = [ "8.8.8.8" "8.8.4.4" ];
          };
        };
      });
      default = null;
      description = "Static Network Configuration";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      mtr
      tcpdump
      traceroute
    ];

    reichard.user.extraGroups = [ "network" ];

    networking = {
      firewall = enabled;
      useDHCP = mkForce (cfg.useDHCP && cfg.useStatic == null);
      useNetworkd = cfg.useNetworkd;
    } // (lib.optionalAttrs (cfg.enableIWD) {
      wireless.iwd = {
        enable = true;
        settings.General.EnableNetworkConfiguration = true;
      };
    }) // (lib.optionalAttrs (cfg.useStatic != null) {
      inherit (cfg.useStatic) defaultGateway nameservers;
      interfaces.${cfg.useStatic.interface}.ipv4.addresses = [{
        inherit (cfg.useStatic) address;
        prefixLength = 24;
      }];
    });
  };
}

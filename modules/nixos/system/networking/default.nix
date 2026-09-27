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
    wifi = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          interface = mkOption { type = types.str; };
          ssid = mkOption { type = types.str; };
          psk = mkOption { type = types.str; };
        };
      });
      default = null;
      description = "wpa_supplicant connection using caller-provided credentials";
    };
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

  config = lib.mkMerge [ (mkIf cfg.enable {
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
  }) (mkIf (cfg.enable && cfg.wifi != null) {
    networking.wireless = {
      enable = true;
      interfaces = [ cfg.wifi.interface ];
      secretsFile = config.sops.templates."wifi-secrets.conf".path;
      extraConfigFiles = [ config.sops.templates."wifi-network.conf".path ];
    };

    sops.templates."wifi-secrets.conf" = {
      content = ''
        wifi_psk=${cfg.wifi.psk}
      '';
      owner = "wpa_supplicant";
      group = "wpa_supplicant";
      mode = "0400";
      restartUnits = [ "wpa_supplicant-${cfg.wifi.interface}.service" ];
    };

    sops.templates."wifi-network.conf" = {
      content = ''
        ext_password_backend=file:${config.sops.templates."wifi-secrets.conf".path}
        network={
          ssid="${cfg.wifi.ssid}"
          psk=ext:wifi_psk
          key_mgmt=WPA-PSK SAE
        }
      '';
      owner = "wpa_supplicant";
      group = "wpa_supplicant";
      mode = "0400";
      restartUnits = [ "wpa_supplicant-${cfg.wifi.interface}.service" ];
    };
  }) ];
}

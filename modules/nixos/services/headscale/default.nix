{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption types;
  cfg = config.${namespace}.services.headscale;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;
in
{
  options.${namespace}.services.headscale = {
    enable = mkEnableOption "enable headscale service";
    openFirewall = mkBoolOpt false "Open firewall";
    policy = mkOpt (types.nullOr types.path) null "Path to a HuJSON ACL policy file (file mode).";
  };

  options.services.headscale.settings.dns.nameservers.split = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = ''
      Split DNS configuration mapping domains to specific nameservers.
      Each key is a domain suffix, and the value is a list of nameservers
      to use for that domain.
    '';
    example = {
      "internal.company.com" = [ "10.0.0.1" "10.0.0.2" ];
      "dev.local" = [ "192.168.1.1" ];
    };
  };

  config = mkIf cfg.enable {
    services.headscale = {
      enable = true;
      address = "0.0.0.0";
      settings = {
        server_url = "https://headscale.reichard.io";
        policy = mkIf (cfg.policy != null) {
          mode = "file";
          path = toString cfg.policy;
        };
        dns = {
          base_domain = "reichard.dev";
          nameservers = {
            global = [
              "9.9.9.9"
            ];
            split = {
              "va.reichard.io" = [ "10.0.20.20" ];
            };
          };
        };
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 8080 ];
    };
  };
}

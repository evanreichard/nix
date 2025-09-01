{ config, namespace, lib, ... }:
let
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.security.sops;
in
{
  options.${namespace}.services.openssh = with lib.types; {
    enable = lib.mkEnableOption "OpenSSH support";
    authorizedKeys = mkOpt (listOf str) [ ] "The public keys to apply.";
    extraConfig = mkOpt str "" "Extra configuration to apply.";
    port = mkOpt port 2222 "The port to listen on (in addition to 22).";
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
    };
  };
}

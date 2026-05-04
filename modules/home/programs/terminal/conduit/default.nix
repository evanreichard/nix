{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.conduit;
in
{
  options.${namespace}.programs.terminal.conduit = {
    enable = lib.mkEnableOption "conduit";
  };

  config = mkIf cfg.enable {
    # Add Conduit
    home.packages = with pkgs; [
      reichard.conduit
    ];

    # Define Conduit Configuration
    sops = {
      secrets.conduit_apikey = {
        sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
      };
      templates."conduit.json" = {
        path = "${config.xdg.configHome}/conduit/config.json";
        content = builtins.toJSON {
          server = "https://conduit.va.reichard.io";
          api_key = "${config.sops.placeholder.conduit_apikey}";
          log_level = "info";
          log_format = "text";
        };
      };
    };
  };
}

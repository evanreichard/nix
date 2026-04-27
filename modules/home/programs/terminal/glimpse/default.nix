{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.glimpse;
in
{
  options.${namespace}.programs.terminal.glimpse = {
    enable = lib.mkEnableOption "glimpse";
  };

  config = mkIf cfg.enable {
    # Add Glimpse
    home.packages = with pkgs; [
      reichard.glimpse
    ];

    # Define Glimpse Configuration
    sops = {
      secrets.kagi_token = {
        sopsFile = lib.snowfall.fs.get-file "secrets/common/evanreichard.yaml";
      };
      templates."glimpse.json" = {
        path = "${config.home.homeDirectory}/.config/glimpse/config.json";
        content = builtins.toJSON {
          search.provider = "kagi";
          providers.kagi.token = "${config.sops.placeholder.kagi_token}";
        };
      };
    };
  };
}

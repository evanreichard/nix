{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib)
    types
    mkIf
    mkDefault
    mkMerge
    mkEnableOption
    ;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.user;

  home-directory =
    if cfg.name == null then
      null
    else if pkgs.stdenv.hostPlatform.isDarwin then
      "/Users/${cfg.name}"
    else
      "/home/${cfg.name}";
in
{
  options.${namespace}.user = {
    enable = mkEnableOption "Whether to configure the user account.";
    email = mkOpt types.str "evan@reichard.io" "The email of the user.";
    fullName = mkOpt types.str "Evan Reichard" "The full name of the user.";
    home = mkOpt (types.nullOr types.str) home-directory "The user's home directory.";
    name = mkOpt (types.nullOr types.str) config.snowfallorg.user.name "The user account.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "${namespace}.user.name must be set";
        }
        {
          assertion = cfg.home != null;
          message = "${namespace}.user.home must be set";
        }
      ];

      home = {
        homeDirectory = mkDefault cfg.home;
        username = mkDefault cfg.name;
      };

      programs.home-manager.enable = true;
    }
  ]);
}

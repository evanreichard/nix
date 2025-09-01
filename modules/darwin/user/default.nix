{ config, lib, namespace, pkgs, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.user;
in
{
  options.${namespace}.user = with types; {
    name = mkOpt str "evanreichard" "The name to use for the user account.";
    email = mkOpt str "evan@reichard.io" "The email of the user.";
    fullName = mkOpt str "Evan Reichard" "The full name of the user.";
    uid = mkOpt (types.nullOr types.int) 501 "The uid for the user account.";
  };

  config = {
    users.users.${cfg.name} = {
      uid = mkIf (cfg.uid != null) cfg.uid;
      shell = pkgs.bashInteractive;
      home = "/Users/${cfg.name}";
    };
  };
}

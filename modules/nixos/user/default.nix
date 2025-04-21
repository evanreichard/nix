{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.user;
in
{
  options.${namespace}.user = with types; {
    email = mkOpt str "evan@reichard.io" "The email of the user.";
    extraGroups = mkOpt (listOf str) [ ] "Groups for the user to be assigned.";
    extraOptions = mkOpt attrs { } "Extra options passed to <option>users.users.<name></option>.";
    fullName = mkOpt str "Evan Reichard" "The full name of the user.";
    initialPassword = mkOpt str "changeMe2025!" "The initial password to use when the user is first created.";
    name = mkOpt str "evanreichard" "The name to use for the user account.";
  };

  config = {
    users.users.${cfg.name} = {
      inherit (cfg) name initialPassword;

      group = "users";
      home = "/home/${cfg.name}";
      extraGroups = [ "wheel" ] ++ cfg.extraGroups;
      isNormalUser = true;
      shell = pkgs.bashInteractive;
      uid = 1000;
    } // cfg.extraOptions;
  };
}

{ config
, lib
, namespace
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption types;
  inherit (lib.${namespace}) mkOpt;
  getFile = lib.snowfall.fs.get-file;

  cfg = config.${namespace}.security.sops;
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkEnableOption "Enable sops";
    defaultSopsFile = mkOpt str "secrets/common/evanreichard.yaml" "Default sops file.";
    sshKeyPaths = mkOpt (listOf path) [ ] "Additional SSH key paths to use.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      age
      sops
      ssh-to-age
    ];

    sops = {
      defaultSopsFile = getFile cfg.defaultSopsFile;

      age = {
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ] ++ cfg.sshKeyPaths;
      };
    };
  };
}

{ config
, lib
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption types;
  inherit (lib.${namespace}) mkOpt;
  getFile = lib.snowfall.fs.get-file;

  user = config.users.users.${config.${namespace}.user.name};
  cfg = config.${namespace}.security.sops;
in
{
  options.${namespace}.security.sops = with types; {
    enable = mkEnableOption "Enable sops";
    defaultSopsFile = mkOpt str "secrets/systems/${config.system.name}.yaml" "Default sops file.";
    sshKeyPaths = mkOpt (listOf path) [ ] "Additional SSH key paths to use.";
  };

  config = mkIf cfg.enable {
    sops = {
      defaultSopsFile = getFile cfg.defaultSopsFile;

      age = {
        keyFile = "${user.home}/.config/sops/age/keys.txt";
        sshKeyPaths = [
          "/etc/ssh/ssh_host_ed25519_key"
          "${user.home}/.ssh/id_ed25519"
        ]
        ++ cfg.sshKeyPaths;
      };
    };

    sops.secrets.builder_ssh_key = {
      sopsFile = getFile "secrets/common/systems.yaml";
    };
  };
}

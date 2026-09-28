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

    # Client Credential Only - This is the key clients use to reach the remote builder, and hosts
    # that do not offload builds have no use for it. The builder itself cannot decrypt the shared
    # file, so declaring it unconditionally would break activation there.
    sops.secrets.builder_ssh_key = mkIf config.${namespace}.nix.useRemoteBuilder {
      sopsFile = getFile "secrets/common/systems.yaml";
    };
  };
}

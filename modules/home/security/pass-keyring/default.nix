{ config
, lib
, namespace
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.security.pass-keyring;
in
{
  options.${namespace}.security.pass-keyring = {
    enable = mkEnableOption "Enable pass-backed keyring";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.pass ];

    # GPG + Pass Keyring - Provides credential storage for CLI
    # tools (e.g. python keyring) via pass (GPG-backed). The
    # keyringrc.cfg forces keyring to use the pass backend instead
    # of SecretService (which requires a working D-Bus provider).
    programs.gpg.enable = true;
    services.gpg-agent = {
      enable = true;
      enableBashIntegration = true;
      pinentry.package = pkgs.pinentry-curses;
      defaultCacheTtl = 86400; # 24 hours
      maxCacheTtl = 604800; # 7 days
    };

    # Keyring Backend Config - Forces keyring to use the pass
    # backend instead of SecretService (broken on headless Linux).
    xdg.configFile."python_keyring/keyringrc.cfg".text = ''
      [backend]
      default-keyring=keyring_pass.PasswordStoreBackend
    '';
  };
}

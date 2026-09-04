{ pkgs
, lib
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption types;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.programs.graphical.omniwm;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.${namespace}.programs.graphical.omniwm = {
    enable = mkEnableOption "OmniWM";

    package = mkOpt types.package pkgs.${namespace}.omniwm "OmniWM package to use.";

    autoStart = mkBoolOpt true "Whether to run OmniWM from a launchd agent at login.";

    settings = mkOpt (types.either types.path tomlFormat.type) { } ''
      Contents of `$XDG_CONFIG_HOME/omniwm/settings.toml`, either a TOML file path
      or an attrset serialized to TOML. Leave empty to let the GUI own the file.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.isDarwin;
      message = "${namespace}.programs.graphical.omniwm is only supported on darwin.";
    }];

    home.packages = [ cfg.package ];

    launchd.agents.omniwm = {
      enable = cfg.autoStart;
      config = {
        Program = "${cfg.package}/Applications/OmniWM.app/Contents/MacOS/OmniWM";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/omniwm.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/omniwm.err.log";
      };
    };

    # Force Relink - OmniWM's settings UI rewrites settings.toml in place, replacing this
    # symlink with a regular file. Without `force`, the next switch aborts on the clobber.
    # The declarative value stays the source of truth; GUI edits are overwritten.
    xdg.configFile."omniwm/settings.toml" = mkIf (cfg.settings != { }) {
      source =
        if builtins.isAttrs cfg.settings then
          tomlFormat.generate "omniwm-settings.toml" cfg.settings
        else
          cfg.settings;
      force = true;
    };
  };
}

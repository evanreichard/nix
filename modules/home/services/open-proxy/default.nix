{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.services.open-proxy;
  package = pkgs.reichard.open-proxy;
in
{
  options.${namespace}.services.open-proxy = {
    server.enable = mkEnableOption "open-proxy host server (opens forwarded URLs/files on this machine)";
    client.enable = mkEnableOption "open-proxy client (shadows open/xdg-open to forward to the host)";
  };

  config = lib.mkMerge [
    (mkIf cfg.server.enable {
      assertions = [
        {
          assertion = pkgs.stdenv.isDarwin;
          message = "reichard.services.open-proxy.server is only supported on macOS (Darwin).";
        }
      ];

      launchd.agents.open-proxy = {
        enable = true;
        config = {
          Label = "io.reichard.open-proxy";
          ProgramArguments = [ "${package}/bin/open-proxy" "serve" ];
          RunAtLoad = true;
          KeepAlive = true;
          # open(1) lives in /usr/bin; launchd agents don't inherit a login PATH.
          EnvironmentVariables.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/open-proxy/open-proxy.out.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/open-proxy/open-proxy.err.log";
        };
      };
    })

    (mkIf cfg.client.enable {
      assertions = [
        {
          assertion = pkgs.stdenv.isLinux;
          message = "reichard.services.open-proxy.client is only supported on Linux.";
        }
      ];

      # Shadow the openers via ~/.local/bin (prepended to PATH below). open-proxy
      # keys off argv[0], so these symlinks run in client mode and fall back to
      # any real opener further down PATH when the host is unreachable.
      home.file = {
        ".local/bin/open".source = "${package}/bin/open-proxy";
        ".local/bin/xdg-open".source = "${package}/bin/open-proxy";
      };

      home.sessionPath = [ "$HOME/.local/bin" ];
      home.sessionVariables.BROWSER = "open";
    })
  ];
}

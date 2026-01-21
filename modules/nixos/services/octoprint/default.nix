{ config
, pkgs
, lib
, namespace
, ...
}:
let
  inherit (lib) mkIf types mkEnableOption;
  inherit (lib.${namespace}) mkOpt;

  settingsFormat = pkgs.formats.yaml { };

  cfg = config.${namespace}.services.octoprint;
in
{
  options.${namespace}.services.octoprint = {
    enable = mkEnableOption "Enable OctoPrint service";
    openFirewall = mkEnableOption "Open firewall";
    port = mkOpt types.port 5000 "Port to listen on";
    settings = lib.mkOption {
      type = lib.types.submodule { freeformType = settingsFormat.type; };
      default = { };
      description = ''
        OctoPrint configuration. Refer to the [OctoPrint example configuration](https://docs.octoprint.org/en/main/configuration/config_yaml.html)
        for details on supported values.
      '';
    };
  };

  config = mkIf cfg.enable {
    # Create User
    users.groups.octoprint = { };
    users.users.octoprint = {
      isSystemUser = true;
      group = "octoprint";
      extraGroups = [ "dialout" ];
    };

    # Create Service
    systemd.services.octoprint =
      let
        # Merge Port
        finalSettings = lib.recursiveUpdate cfg.settings {
          server.port = cfg.port;
        };

        # Create Config
        configFile = settingsFormat.generate "config.yaml" finalSettings;
      in
      {
        description = "OctoPrint 3D Printing Service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "exec";
          ExecStartPre = pkgs.writeShellScript "setup-octoprint-config" ''
            if [ ! -f /var/lib/octoprint/config.yaml ]; then
              ${pkgs.coreutils}/bin/cp ${configFile} /var/lib/octoprint/config.yaml
            fi
          '';
          ExecStart = "${lib.getExe pkgs.octoprint} serve -b /var/lib/octoprint";
          Restart = "on-failure";
          RestartSec = 3;

          StateDirectory = "octoprint";
          WorkingDirectory = "/var/lib/octoprint";
          Environment = "HOME=/var/lib/octoprint";

          User = "octoprint";
          Group = "octoprint";
          SupplementaryGroups = [ "dialout" ];
          PrivateDevices = false;
        };
      };

    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };
  };
}

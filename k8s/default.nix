{ config, lib, pkgs, ... }:

{
  options.k8s = {
    diskPoolID = lib.mkOption {
      type = lib.types.str;
      description = "Disk Pool ID for OpenEBS";
    };

    manifestsDir = lib.mkOption {
      type = lib.types.path;
      description = "Directory for Kubernetes manifests";
    };
  };

  config = {
    system.activationScripts.k8s-manifests = {
      deps = [ ];
      text = ''
        mkdir -p ${config.k8s.manifestsDir}
        cp ${pkgs.substituteAll {
          src = ./config/openebs.yaml;
          nodeName = config.networking.hostName;
          diskPoolID = config.k8s.diskPoolID;
        }} ${config.k8s.manifestsDir}/openebs.yaml
      '';
    };
  };
}

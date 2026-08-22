{ lib
, config
, namespace
, osConfig
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "26.05";

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      ssh-agent = enabled;
    };

    security = {
      sops = enabled;
    };

    programs = {
      terminal = {
        bash = enabled;
        btop = enabled;
        conduit = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        omp = enabled;
        opencode = enabled;
        pi = enabled;
        tmux = enabled;
      };
    };
  };

  # Kubernetes Secrets
  sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/lin-va-kube";
    };
  };
}

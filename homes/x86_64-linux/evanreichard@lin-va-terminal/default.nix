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
  home.stateVersion = "25.11";

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
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
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

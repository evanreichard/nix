{ config, lib, pkgs, inputs, namespace, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  getFile = lib.snowfall.fs.get-file;

  # Server-Side Signing - atticd signs narinfo with a cache keypair it alone holds, so clients only
  # ever need the public half to keep `require-sigs` on.
  attic = {
    url = "https://attic.va.reichard.io/nix";
    publicKey = "nix:e27lP0uq+iTer5y/Sysiwy8IDhdJcOTu1W4CGZGL3z0=";
  };

  # The attic client Reads $XDG_CONFIG_HOME/attic/config.toml and nothing else, so the rendered
  # template has to be linked into that directory rather than pointed at directly.
  atticConfigHome = "/var/lib/attic-client";

  cfg = config.${namespace}.nix;
  sopsEnabled = config.${namespace}.security.sops.enable;
in
{
  options.${namespace}.nix = {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt types.package pkgs.nixVersions.latest "Which nix package to use.";
    builderSshKey = mkOpt types.str config.sops.secrets.builder_ssh_key.path "SSH key for the remote Nix builder.";
    useRemoteBuilder = mkBoolOpt true "Use the shared remote Nix builder.";
  };

  config = mkIf cfg.enable {
    nix =
      let
        mappedRegistry = lib.pipe inputs [
          (lib.filterAttrs (_: lib.isType "flake"))
          (lib.mapAttrs (_: flake: { inherit flake; }))
          (x: x // {
            nixpkgs.flake = if pkgs.stdenv.hostPlatform.isLinux then inputs.nixpkgs else inputs.nixpkgs-unstable;
          })
          (x: if pkgs.stdenv.hostPlatform.isDarwin then lib.removeAttrs x [ "nixpkgs-unstable" ] else x)
        ];
        users = [
          "root"
          "@wheel"
          "nix-builder"
          "evanreichard"
        ];
        builder = {
          hostName = "10.0.50.130";
          sshUser = "evanreichard";
          sshKey = cfg.builderSshKey;
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUdscEMwcm9yQVRLeks4bUxNS2dDWXFNNU4yTi9HZ1MydDRNMTNjd25BT1M=";
        };
      in
      {
        inherit (cfg) package;

        buildMachines = lib.optional (cfg.useRemoteBuilder && sopsEnabled) {
          inherit (builder) hostName sshUser sshKey publicHostKey;
          systems = [ "x86_64-linux" "aarch64-linux" ];
          maxJobs = 2;
          protocol = "ssh";
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "nixos-test"
            "kvm"
          ];
        };

        checkConfig = true;
        distributedBuilds = true;
        optimise.automatic = true;
        registry = mappedRegistry;

        gc = {
          automatic = true;
          options = "--delete-older-than 7d";
        };

        settings = {
          connect-timeout = 5;
          allowed-users = users;
          max-jobs = "auto";
          auto-optimise-store = pkgs.stdenv.hostPlatform.isLinux;
          builders-use-substitutes = true;
          experimental-features = [
            "nix-command"
            "flakes "
          ];
          flake-registry = "/etc/nix/registry.json";
          http-connections = 50;
          keep-derivations = true;
          keep-going = true;
          keep-outputs = true;
          log-lines = 50;
          sandbox = true;
          trusted-users = users;
          warn-dirty = false;
          use-xdg-base-directories = true;

          # Private Cache Credentials - Nix carries credentials for HTTP caches only through netrc,
          # and only the daemon reads it while substituting, so the file is sealed to system keys.
          netrc-file = lib.mkIf sopsEnabled (
            toString config.sops.secrets.nix_cache_netrc.path
          );

          substituters =
            [
              "https://anyrun.cachix.org"
              "https://cache.nixos.org"
              "https://hyprland.cachix.org"
              "https://nix-community.cachix.org"
              "https://nixpkgs-unfree.cachix.org"
              "https://nixpkgs-wayland.cachix.org"
              "https://numtide.cachix.org"
            ]
            ++ lib.optional sopsEnabled attic.url;

          trusted-public-keys = [
            "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ] ++ lib.optional sopsEnabled attic.publicKey;
        };
      };
    # Attic Is Private - Every substituting host needs the pull token, and a host without sops is
    # left out of the substituter list rather than failing every substitution with a 401.
    sops.secrets.nix_cache_netrc = mkIf sopsEnabled {
      sopsFile = getFile "secrets/common/nix-cache.yaml";
      mode = "0400";
    };

    sops.secrets.attic_push_token = mkIf sopsEnabled {
      sopsFile = getFile "secrets/common/nix-cache.yaml";
      mode = "0400";
    };

    sops.templates."attic-config.toml" = mkIf sopsEnabled {
      content = ''
        default-server = "attic"
        [servers.attic]
        endpoint = "https://attic.va.reichard.io/"
        token = "${config.sops.placeholder.attic_push_token}"
      '';
      mode = "0400";
    };

    systemd.tmpfiles.rules = mkIf sopsEnabled [
      "d ${atticConfigHome}/attic 0700 root root -"
      "L+ ${atticConfigHome}/attic/config.toml - - - - ${config.sops.templates."attic-config.toml".path}"
    ];
    # Store Watcher Is Asynchronous - Builds must not wait for cache uploads.
    systemd.services.attic-watch-store = mkIf sopsEnabled {
      description = "Publish new Nix store paths to Attic";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.attic-client} watch-store nix";
        Environment = "XDG_CONFIG_HOME=${atticConfigHome}";
        Restart = "always";
        RestartSec = "10s";
        User = "root";
        Group = "root";
      };
    };


  };
}

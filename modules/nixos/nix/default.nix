{ config, lib, pkgs, inputs, namespace, host, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt types.package pkgs.nixVersions.latest "Which nix package to use.";
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
      in
      {
        inherit (cfg) package;

        buildMachines = lib.optional (config.${namespace}.security.sops.enable && host != "nixos-builder") {
          hostName = "10.0.50.130";
          systems = [ "x86_64-linux" ];
          sshUser = "evanreichard";
          protocol = "ssh";
          sshKey = config.sops.secrets.builder_ssh_key.path;
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

          substituters = [
            "https://anyrun.cachix.org"
            "https://cache.nixos.org"
            "https://hyprland.cachix.org"
            "https://nix-community.cachix.org"
            "https://nixpkgs-unfree.cachix.org"
            "https://nixpkgs-wayland.cachix.org"
            "https://numtide.cachix.org"
          ];

          trusted-public-keys = [
            "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];
        };
      };
  };
}

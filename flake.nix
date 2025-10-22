{
  description = "NixOS Hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    apple-silicon = {
      url = "github:tpwrules/nixos-apple-silicon/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.snowfall-lib.mkFlake {
      inherit inputs;
      src = ./.;

      snowfall = {
        namespace = "reichard";
        meta = {
          title = "Reichard";
          name = "reichard";
        };
      };

      channels-config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "intel-ocl-5.0-63503"
        ];
      };

      outputs-builder = channels: {
        devShells = {
          default = import ./shells/default/default.nix { pkgs = channels.nixpkgs; };
        };
      };

      homes.modules = with inputs; [
        sops-nix.homeManagerModules.sops
      ];

      systems.modules = {
        nixos = with inputs; [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
        ];
        darwin = with inputs; [
          home-manager.darwinModules.home-manager
          sops-nix.darwinModules.sops
        ];
      };
    };
}

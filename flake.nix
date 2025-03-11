{
  description = "NixOS Hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, nixos-generators }:
    let
      mkSystem = { systemConfig ? { }, moduleConfig }: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./lib/disk-config.nix
          ./lib/common-system.nix
          systemConfig
          ({ ... }: moduleConfig)
        ];
      };
    in
    {
      packages.x86_64-linux = {
        rke2-image = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "vmware";
          modules = [
            ./hosts/rke2-image.nix
          ];
        };
      };

      nixosConfigurations = {
        # LLaMA C++ Server
        lin-va-llama1 = mkSystem {
          systemConfig = ./hosts/llama-server.nix;
          moduleConfig = {
            hostName = "lin-va-llama1";
            mainDiskID = "/dev/disk/by-id/ata-MTFDDAK512MBF-1AN1ZABHA_161212233628";
          };
        };

        # Nix Builder
        lin-va-nix-builder = mkSystem {
          moduleConfig = {
            hostName = "lin-va-nix-builder";
            mainDiskID = "/dev/xvda";
            enableXenGuest = true;
          };
        };
      };
    };
}

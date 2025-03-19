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
      # NixOS Generators
      packages.x86_64-linux = {
        # RKE2
        rke2-image = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "vmware";
          modules = [
            ./hosts/rke2-image.nix
          ];
        };

        usb-image = nixos-generators.nixosGenerate {
          system = "x86_64-linux";
          format = "raw-efi";
          modules = [
            ./hosts/usb-image.nix
          ];
        };
      };

      # NixOS Configurations
      nixosConfigurations = {
        # Office Server (LLaMA / ADS-B)
        lin-va-office = mkSystem {
          systemConfig = ./hosts/office-server.nix;
          moduleConfig = {
            hostName = "lin-va-office";
            mainDiskID = "/dev/disk/by-id/ata-MTFDDAK512MBF-1AN1ZABHA_161212233628";
            network = {
              interface = "enp5s0";
              address = "10.0.50.120";
              defaultGateway = "10.0.50.254";
              nameservers = [ "10.0.50.254" ];
            };
          };
        };

        # Nix Builder
        lin-va-nix-builder = mkSystem {
          systemConfig = ./hosts/builder.nix;
          moduleConfig = {
            hostName = "lin-va-nix-builder";
            mainDiskID = "/dev/xvda";
            enableXenGuest = true;
            network = {
              interface = "enX0";
              address = "10.0.50.130";
              defaultGateway = "10.0.50.254";
              nameservers = [ "10.0.50.254" ];
            };
          };
        };
      };
    };
}

{
  description = "NixOS Hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko";
  };

  outputs = { self, nixpkgs, disko }:
    let
      mkSystem = { systemConfig, moduleConfig }: nixpkgs.lib.nixosSystem {
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
      nixosConfigurations = {
        # LLaMA C++ Server
        lin-va-llama1 = mkSystem {
          systemConfig = ./hosts/llama-server.nix;
          moduleConfig = {
            hostName = "lin-va-llama1";
            mainDiskID = "/dev/disk/by-id/ata-MTFDDAK512MBF-1AN1ZABHA_161212233628";
          };
        };

        # RKE2 Primary Server
        lin-va-rke1 = mkSystem {
          systemConfig = ./hosts/rke2.nix;
          moduleConfig = {
            hostName = "lin-va-rke1";
            mainDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VB0af7d668-04b70404";
            dataDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBcd9425b8-d666f9b8";

            networkConfig = {
              interface = "enp0s3";
              address = "10.0.20.201";
              defaultGateway = "10.0.20.254";
              nameservers = [ "10.0.20.254" ];
            };
          };
        };

        # RKE2 Second Server
        lin-va-rke2 = mkSystem {
          systemConfig = ./hosts/rke2.nix;
          moduleConfig = {
            hostName = "lin-va-rke2";
            mainDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBf55aaccc-688cfd0d";
            dataDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBfd391256-6e368424";
            serverAddr = "https://10.0.20.201:9345";

            networkConfig = {
              interface = "enp0s3";
              address = "10.0.20.202";
              defaultGateway = "10.0.20.254";
              nameservers = [ "10.0.20.254" ];
            };
          };
        };

        # RKE2 Third Server
        lin-va-rke3 = mkSystem {
          systemConfig = ./hosts/rke2.nix;
          moduleConfig = {
            hostName = "lin-va-rke3";
            mainDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBe9edacd5-ac4ed4fa";
            dataDiskID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBa1fc46d0-19380495";
            serverAddr = "https://10.0.20.201:9345";

            networkConfig = {
              interface = "enp0s3";
              address = "10.0.20.203";
              defaultGateway = "10.0.20.254";
              nameservers = [ "10.0.20.254" ];
            };
          };
        };
      };
    };
}

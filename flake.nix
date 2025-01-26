{
  description = "NixOS Hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko.url = "github:nix-community/disko";
  };

  outputs = { self, nixpkgs, disko }: {
    nixosConfigurations.lin-va-llama1 = nixpkgs.lib.nixosSystem {
      # LLaMA C++ Server
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/llama-server.nix
        {
          networking.hostName = "lin-va-llama1";
          disko.devices.disk.main.device = "/dev/sda";
          k8s.diskPoolID = "/dev/disk/by-id/unknown";
        }
      ];
    };

    # K3s Server
    nixosConfigurations.lin-va-k3s1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/k3s.nix
        {
          networking.hostName = "lin-va-k3s1";
          disko.devices.disk.main.device = "/dev/sda";
        }
      ];
    };

    # RKE2 Primary Server
    nixosConfigurations.lin-va-rke1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/rke2.nix
        {
          networking.hostName = "lin-va-rke1";

          # Partitions
          disko.devices.disk.main.device = "/dev/disk/by-id/ata-VBOX_HARDDISK_VB0af7d668-04b70404";
          k8s.diskPoolID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBcd9425b8-d666f9b8";
        }
      ];
    };

    # RKE2 Second Server
    nixosConfigurations.lin-va-rke2 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/rke2.nix
        {
          networking.hostName = "lin-va-rke2";

          # Partitions
          disko.devices.disk.main.device = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBf55aaccc-688cfd0d";
          k8s.diskPoolID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBfd391256-6e368424";

          # Set RKE2 Join
          services.rke2.serverAddr = "https://10.0.20.147:9345";
          services.rke2.tokenFile = "/etc/rancher/rke2/node-token";
          environment.etc."rancher/rke2/node-token" = {
            source = ./k8s/rke2-token;
            mode = "0600";
            user = "root";
            group = "root";
          };
        }
      ];
    };

    # RKE2 Third Server
    nixosConfigurations.lin-va-rke3 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/rke2.nix
        {
          networking.hostName = "lin-va-rke3";

          # Partitions
          disko.devices.disk.main.device = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBe9edacd5-ac4ed4fa";
          k8s.diskPoolID = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBa1fc46d0-19380495";

          # Set RKE2 Join
          services.rke2.serverAddr = "https://10.0.20.147:9345";
          services.rke2.tokenFile = "/etc/rancher/rke2/node-token";
          environment.etc."rancher/rke2/node-token" = {
            source = ./k8s/rke2-token;
            mode = "0600";
            user = "root";
            group = "root";
          };
        }
      ];
    };
  };
}

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

    # RKE2 Server
    nixosConfigurations.lin-va-rke1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./hosts/rke2.nix
        {
          networking.hostName = "lin-va-rke1";
          disko.devices.disk.main.device = "/dev/nvme0n1";
          k8s.diskPoolID = "/dev/disk/by-id/ata-INTEL_SSDSC2BW240A4_CVDA418201Z42403GN";
        }
      ];
    };
  };
}

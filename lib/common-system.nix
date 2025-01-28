{ config, lib, ... }:
{
  # Node Nix Config
  options = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The node hostname";
    };
  };

  config = {
    # Basic System
    system.stateVersion = "24.11";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    networking.hostName = config.hostName;

    # Boot Loader Options
    boot.loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    # Enable SSH
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };

    # User Authorized Keys
    users.users.root = {
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA8P84lWL/p13ZBFNwITm/dLWWL8s9pVmdOImM5gaJAiTLY+DheUvG6YsveB2/5STseiJ34g7Na9TW1mtTLL8zDqPvj3NbprQiYlLJKMbCk6dtfdD4nLMHl8B48e1h699XiZDp2/c+jJb0MkLOFrps+FbPqt7pFt1Pj29tFy8BCg0LGndu6KO+HqYS+aM5tp5hZESo1RReiJ8aHsu5X7wW46brN4gfyyu+8X4etSZAB9raWqlln9NKK7G6as6X+uPypvSjYGSTC8TSePV1iTPwOxPk2+1xBsK7EBLg3jNrrYaiXLnZvBOOhm11JmHzqEJ6386FfQO+0r4iDVxmvi+ojw== rsa-key-20141114"
      ];
      hashedPassword = null;
    };
  };
}

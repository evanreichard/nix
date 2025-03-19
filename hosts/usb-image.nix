{ pkgs, ... }:

{
  # Basic System
  system.stateVersion = "24.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "UTC";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
    ];
  };

  # User Authorized Keys
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe1n9l9pVF5+kjWJCOt3AvBVf1HOSZkEDZxCWVPSIkr evan@reichard"
    ];
    hashedPassword = null;
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    htop
    tmux
    vim
  ];
}

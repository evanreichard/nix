{ pkgs, ... }:

{
  # User Authorized Keys
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe1n9l9pVF5+kjWJCOt3AvBVf1HOSZkEDZxCWVPSIkr evan@reichard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGGGpRpDQRstoqnCAQioSnh6PZRzNQL7lGJHksIkcoF builder"
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

{ pkgs, ... }:

let
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz";
    sha256 = "156hc11bb6xiypj65q6gzkhw1gw31dwv6dfh6rnv20hgig1sbfld";
  };
in
{
  imports = [
    "${home-manager}/nixos"
  ];

  # Enable Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ vaapiIntel intel-media-driver ];
  };

  # User Configuration
  users.users.evanreichard = {
    isNormalUser = true;
    home = "/home/evanreichard";
    group = "evanreichard";
    extraGroups = [ "wheel" "networkmanager" "video" ];
    shell = pkgs.bash;
  };
  users.groups.evanreichard = { };

  # Home Manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.evanreichard = import ../home-manager/home.nix;
  };

  # Enable HyprLand
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # Networking Configuration
  networking.firewall = {
    enable = true;
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    ghostty
    htop
    tmux
    vim
    wget
  ];
}

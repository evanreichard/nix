{
  config = {
    nix.enable = false;
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
    };
  };
}

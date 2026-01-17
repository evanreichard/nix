{
  system.stateVersion = 6;
  nix.enable = false;

  # System Config
  reichard = {
    nix = {
      enable = true;
      usingDeterminate = true;
    };
  };
}

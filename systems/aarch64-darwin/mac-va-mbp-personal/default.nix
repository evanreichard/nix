{
  system.stateVersion = 6;

  # System Config
  determinateNix = {
    enable = true;
    nixosVmBasedLinuxBuilder.enable = true;
  };

  system.primaryUser = "evanreichard";
  system.defaults = {
    NSGlobalDomain = {
      _HIHideMenuBar = true;
    };
  };

  # System Config
  reichard = {
  };
}

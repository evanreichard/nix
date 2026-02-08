{
  system.stateVersion = 6;

  # System Config
  determinateNix = {
    enable = true;
    nixosVmBasedLinuxBuilder.enable = true;
  };

  reichard = { };
}

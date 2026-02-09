{ lib, ... }:

{
  system.stateVersion = 6;

  # System Config
  determinateNix = {
    enable = true;
    nixosVmBasedLinuxBuilder = {
      enable = true;
      config.virtualisation.diskSize = lib.mkForce 61440;
    };
  };

  reichard = { };
}

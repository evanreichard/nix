{ lib, ... }:

{
  system.stateVersion = 6;

  # Determinate Config
  determinateNix = {
    enable = true;
    nixosVmBasedLinuxBuilder = {
      enable = true;
      config.virtualisation.diskSize = lib.mkForce 61440;
    };
  };

  system.primaryUser = "evanreichard";
  system.defaults = {
    trackpad = {
      TrackpadThreeFingerDrag = true;
    };
    dock = {
      autohide = true;
    };
    menuExtraClock = {
      Show24Hour = true;
      ShowSeconds = true;
    };
    NSGlobalDomain = {
      KeyRepeat = 2;
      NSWindowShouldDragOnGesture = true;
      AppleICUForce24HourTime = true;
    };
    WindowManager = {
      HideDesktop = true;
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  reichard = { };
}

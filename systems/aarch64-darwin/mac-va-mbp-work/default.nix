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
      _HIHideMenuBar = true;
    };
    WindowManager = {
      HideDesktop = true;
    };
    finder = {
      CreateDesktop = false;
    };
  };

  system.activationScripts.postActivation.text = ''
    sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool false
  '';

  security.pam.services.sudo_local.touchIdAuth = true;

  reichard = { };
}

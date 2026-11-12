# Logitech BRIO Ultra HD (046d:085e). The 4K modes need USB 3; on a USB 2.0 link the
# device is capped at 1080p30 MJPEG regardless of what the application requests.
{ config, lib, namespace, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption;

  cfg = config.${namespace}.hardware.webcam.brio;

  # uvcvideo publishes the node before its controls are always queryable, so retry
  # briefly. Each control is set on its own: the Brio's second video function rejects
  # controls the colour function accepts, and uvcvideo fails the whole --set-ctrl
  # call if any one name is unknown.
  applyControls = pkgs.writeShellScript "brio-apply-controls" ''
    dev="$1"
    for _ in 1 2 3 4 5; do
      ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$dev" --list-ctrls >/dev/null 2>&1 && break
      ${pkgs.coreutils}/bin/sleep 0.2
    done
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value: ''${pkgs.v4l-utils}/bin/v4l2-ctl -d "$dev" --set-ctrl=${name}=${toString value} >/dev/null 2>&1 || true''
      ) cfg.controls
    )}
  '';
in
{
  options.${namespace}.hardware.webcam.brio = {
    enable = mkEnableOption "Logitech Brio with a tuned UVC control profile applied on plug-in";

    controls = mkOption {
      type = with lib.types; attrsOf (oneOf [ bool int str ]);
      # Control names follow the kernel, not the UVC spec labels: auto_exposure,
      # white_balance_automatic, focus_automatic_continuous. A wrong name is silently
      # ignored by the applier, so a typo tunes nothing and reports no error.
      default = {
        # 60 Hz mains. At 50 Hz, LED and fluorescent fixtures band across the frame.
        power_line_frequency = 2;
        # Silhouetted face against a window; 0 leaves it black.
        backlight_compensation = 1;
        # Auto WB is required, not a shortcut: the room mixes a warm lamp with daylight
        # and any fixed temperature renders one side orange or blue.
        white_balance_automatic = 1;
        # Exposure stays auto for the same reason. Digital zoom and pan ship at 111/36000
        # after some app pokes the camera, which crops and upscales into mush.
        auto_exposure = 3;
        exposure_dynamic_framerate = 0;
        zoom_absolute = 100;
        pan_absolute = 0;
        tilt_absolute = 0;
        # Default 128 with auto exposure blows the wall behind into flat white haze; the
        # colour that reads as washed out is clipped highlights, not a WB error.
        brightness = 104;
        contrast = 132;
        saturation = 152;
        sharpness = 128;
        focus_automatic_continuous = 1;
      };
      description = ''
        v4l2 controls applied to every Brio capture node after enumeration.
        Unsupported controls are skipped silently, so this is safe across firmware.
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.v4l-utils ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="085e", ATTR{index}=="0", RUN+="${applyControls} /dev/%k"
    '';
  };
}

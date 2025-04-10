{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib)
    types
    mkIf
    mkMerge
    optionalAttrs
    ;
  inherit (lib.${namespace}) mkBoolOpt mkOpt;

  cfg = config.${namespace}.programs.graphical.browsers.firefox;
in
{
  imports = lib.snowfall.fs.get-non-default-nix-files ./.;

  options.${namespace}.programs.graphical.browsers.firefox = with types; {
    enable = lib.mkEnableOption "Firefox";

    extraConfig = mkOpt str "" "Extra configuration for the user profile JS file.";
    gpuAcceleration = mkBoolOpt false "Enable GPU acceleration.";
    hardwareDecoding = mkBoolOpt false "Enable hardware video decoding.";

    policies = mkOpt attrs
      {
        CaptivePortal = false;
        DisableFirefoxStudies = true;
        DisableFormHistory = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DisplayBookmarksToolbar = false;
        DontCheckDefaultBrowser = true;
        FirefoxHome = {
          Pocket = false;
          Snippets = false;
        };
        PasswordManagerEnabled = false;
        UserMessaging = {
          ExtensionRecommendations = false;
          SkipOnboarding = true;
        };
        ExtensionSettings = {
          # Block All
          # "*".installation_mode = "blocked";

          # Bypass Paywalls
          "magnolia@12.34" = {
            install_url = "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass_paywalls_clean-latest.xpi";
            installation_mode = "force_installed";
          };
        };
        Preferences = { };
      } "Policies to apply to firefox";

    settings = mkOpt attrs { } "Settings to apply to the profile.";

    extensions = mkOpt (with lib.types; listOf package)
      (with pkgs.firefox-addons; [
        bitwarden
        darkreader
        gruvbox-dark-theme
        kagi-search
        sponsorblock
        ublock-origin

        # bypass-paywalls-clean
      ]) "Extensions to install";
  };

  config = mkIf cfg.enable {
    programs.firefox = {
      enable = true;

      inherit (cfg) policies;

      profiles = {
        ${config.${namespace}.user.name} = {
          inherit (cfg) extraConfig extensions;
          inherit (config.${namespace}.user) name;

          id = 0;

          settings = mkMerge [
            cfg.settings
            {
              "browser.aboutConfig.showWarning" = false;
              "browser.aboutwelcome.enabled" = false;
              "browser.sessionstore.warnOnQuit" = true;
              "browser.shell.checkDefaultBrowser" = false;
              "general.smoothScroll.msdPhysics.enabled" = true;
              "intl.accept_languages" = "en-US,en";
              "ui.key.accelKey" = "224";

              # "devtools.chrome.enabled" = true;
              # "xpinstall.signatures.required" = false;
            }
            (optionalAttrs cfg.gpuAcceleration {
              "dom.webgpu.enabled" = true;
              "gfx.webrender.all" = true;
              "layers.gpu-process.enabled" = true;
              "layers.mlgpu.enabled" = true;
            })
            (optionalAttrs cfg.hardwareDecoding {
              "media.ffmpeg.vaapi.enabled" = true;
              "media.gpu-process-decoder" = true;
              "media.hardware-video-decoding.enabled" = true;
            })
          ];

          # userChrome = ./chrome/userChrome.css;
        };
      };
    };
  };
}

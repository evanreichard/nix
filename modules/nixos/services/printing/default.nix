{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (pkgs) writeTextDir;

  cfg = config.${namespace}.services.printing;
in
{
  options.${namespace}.services.printing = {
    enable = mkEnableOption "enable printing service";
  };

  config = mkIf cfg.enable {
    hardware.printers = {
      ensurePrinters = [
        {
          name = "Canon_PIXMA_iX6820";
          location = "Home";
          deviceUri = "ipp://954290000000.local:631/ipp/print";
          model = "Canon_PIXMA_iX6820.ppd";
          ppdOptions = {
            PageSize = "4x6.Fullbleed";
            ColorModel = "RGB";
            cupsPrintQuality = "High";
            MediaType = "photographic";
          };
        }
        {
          name = "Brother_HL-2270DW";
          location = "Home";
          deviceUri = "dnssd://Brother%20HL-2270DW%20series._pdl-datastream._tcp.local/";
          model = "drv:///brlaser.drv/br2270d.ppd";
          ppdOptions = {
            PageSize = "Letter";
            Resolution = "600dpi";
            InputSlot = "Auto";
            MediaType = "PLAIN";
            Duplex = "DuplexNoTumble";
            brlaserEconomode = "False";
            brlaserDensityAdjust = "100";
          };
        }
      ];
      ensureDefaultPrinter = "Canon_PIXMA_iX6820";
    };

    services.printing = {
      enable = true;
      drivers = [
        pkgs.brlaser
        (writeTextDir "share/cups/model/Canon_PIXMA_iX6820.ppd" (
          builtins.readFile ./Canon_PIXMA_iX6820_AirPrint.ppd
        ))
      ];
    };
  };
}

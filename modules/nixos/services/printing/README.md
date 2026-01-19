# Printing Service Module

This module configures a Canon PIXMA iX6820 printer for fullbleed/borderless printing on NixOS.

## PPD File

The `Canon_PIXMA_iX6820_AirPrint.ppd` file is essential for enabling fullbleed (borderless) printing on the Canon PIXMA iX6820.

The default IPP/PPD driver included with Linux claims to support borderless printing, but it never works in practice. This custom PPD was generated via macOS and manually converted to work with Linux/CUPS to actually enable fullbleed printing functionality. It provides CUPS with the necessary printer capabilities and configuration options, including the `4x6.Fullbleed` page size and media type options.

## Nix Module

The module (`default.nix`) provides a NixOS service that:

- Enables CUPS printing service
- Installs the custom PPD driver for the Canon PIXMA iX6820
- Configures the printer via `hardware.printers.ensurePrinters`
- Sets default print options for high-quality borderless photo printing:
  - Page size: 4x6 Fullbleed
  - Color model: RGB
  - Print quality: High
  - Media type: Photographic
- Sets the printer as the default system printer

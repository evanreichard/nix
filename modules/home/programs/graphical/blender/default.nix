{ lib
, pkgs
, config
, namespace
, ...
}:
let
  cfg = config.${namespace}.programs.graphical.blender;
  blenderVersion = lib.versions.majorMinor pkgs.blender.version;
  mcp = pkgs.${namespace}.mcp-for-blender;
in
{
  options.${namespace}.programs.graphical.blender = {
    enable = lib.mkEnableOption "Blender";

    mcp.enable = lib.mkEnableOption "MCP for Blender add-on and server";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.blender ] ++ lib.optional cfg.mcp.enable mcp;

    home.file = lib.mkIf cfg.mcp.enable {
      ".config/blender/${blenderVersion}/scripts/addons/blender_mcp.py".source =
        "${mcp}/${pkgs.python3.sitePackages}/blender_mcp/bundled/addon.py";
      # Blender preferences are mutable; enable the add-on on startup without owning userpref.blend.
      ".config/blender/${blenderVersion}/scripts/startup/enable_blender_mcp.py".source =
        ./enable_blender_mcp.py;
    };
  };
}

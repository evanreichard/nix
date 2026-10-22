import addon_utils

if not addon_utils.check("blender_mcp")[1]:
    addon_utils.enable("blender_mcp")

import addon_utils
import bpy


def enable_blender_mcp():
    if not addon_utils.check("blender_mcp")[1]:
        addon_utils.enable("blender_mcp")


def register():
    bpy.app.timers.register(enable_blender_mcp, first_interval=0.5)


def unregister():
    if bpy.app.timers.is_registered(enable_blender_mcp):
        bpy.app.timers.unregister(enable_blender_mcp)

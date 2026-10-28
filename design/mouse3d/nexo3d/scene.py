"""Scene reset, render settings and compute-device selection (Cycles)."""

import bpy

from . import params


def reset():
    """Start from an empty factory scene (no default cube, camera or light)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "MILLIMETERS"
    return scene


def update():
    """Refresh matrices after moving objects. Without it, world_to_camera_view and ray casts still
    see the old transforms (camera at the origin) and silently return wrong coordinates."""
    bpy.context.view_layer.update()


def setup_device(prefer="auto"):
    """Pick the fastest available device: OptiX, then CUDA, then CPU.

    Returns a dict describing the choice. 'prefer' may be 'auto' or 'cpu'.
    """
    scene = bpy.context.scene
    prefs = bpy.context.preferences.addons["cycles"].preferences
    if prefer != "cpu":
        for kind in ("OPTIX", "CUDA"):
            prefs.compute_device_type = kind
            prefs.refresh_devices()
            gpus = [d for d in prefs.get_devices_for_type(kind) if d.type == kind]
            if gpus:
                for device in prefs.devices:
                    device.use = device.type == kind
                scene.cycles.device = "GPU"
                scene.cycles.denoising_use_gpu = True
                return {"kind": kind, "devices": [d.name for d in gpus]}
    prefs.compute_device_type = "NONE"
    prefs.refresh_devices()
    scene.cycles.device = "CPU"
    scene.cycles.denoising_use_gpu = False
    cpus = [d.name for d in prefs.get_devices_for_type("CPU")]
    return {"kind": "CPU", "devices": cpus}


def configure_cycles(quality, transparent=True):
    """Cycles settings shared by every beauty render."""
    preset = params.QUALITY[quality]
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = preset["samples"]
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = preset["threshold"]
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.cycles.use_light_tree = True
    scene.cycles.caustics_reflective = False
    scene.cycles.caustics_refractive = False
    scene.cycles.blur_glossy = 0.5
    scene.cycles.seed = 7
    scene.cycles.use_animated_seed = False
    scene.render.film_transparent = transparent
    scene.render.resolution_percentage = preset["scale"]
    scene.render.use_persistent_data = True
    settings = scene.render.image_settings
    settings.file_format = "PNG"
    settings.color_mode = "RGBA"
    settings.color_depth = "8"
    settings.compression = preset["compression"]


def configure_color(view, look, exposure=0.0):
    view_settings = bpy.context.scene.view_settings
    view_settings.view_transform = view
    view_settings.look = look
    view_settings.exposure = exposure
    view_settings.gamma = 1.0


def set_resolution(width, height):
    bpy.context.scene.render.resolution_x = width
    bpy.context.scene.render.resolution_y = height


def render_still(path):
    """Render the active camera to 'path' (PNG, settings from configure_cycles)."""
    scene = bpy.context.scene
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path

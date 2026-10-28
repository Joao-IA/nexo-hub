"""Studio lighting, world and floor (shadow catcher for the app, cyclorama for the hero shot)."""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from . import geometry as g
from . import params
from .materials import plastic
from .units import hex_rgba, mm3


def target():
    return Vector(mm3(params.TARGET_MM))


def spherical(azimuth, elevation, distance):
    """Point around the mouse centre. Azimuth from +X (front) towards +Y (left side), degrees."""
    a, e = math.radians(azimuth), math.radians(elevation)
    return target() + Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e))) * distance


def _area(spec, color_hex):
    light = bpy.data.lights.new(spec["name"], "AREA")
    light.shape = "RECTANGLE"
    light.size, light.size_y = spec["size"]
    light.energy = spec["energy"]
    light.color = hex_rgba(color_hex)[:3]
    obj = bpy.data.objects.new(spec["name"], light)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = spherical(spec["az"], spec["el"], spec["dist"])
    obj.rotation_euler = (target() - obj.location).to_track_quat("-Z", "Y").to_euler()
    obj["nexo_light"] = True
    return obj


def _socket(sockets, identifier):
    return next(s for s in sockets if s.identifier == identifier)


def _world(spec):
    """Vertical gradient environment: gives the steel something to reflect even though the
    background itself is transparent in the app renders. Glossy rays see it 'glossy_boost' times
    brighter (a studio trick): the silver wheels read as silver without lifting the diffuse light
    on the graphite plastic."""
    scene = bpy.context.scene
    world = scene.world or bpy.data.worlds.new("world")
    scene.world = world
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputWorld")
    background = nodes.new("ShaderNodeBackground")
    coords = nodes.new("ShaderNodeTexCoord")
    split = nodes.new("ShaderNodeSeparateXYZ")
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = -1.0
    remap.inputs["From Max"].default_value = 1.0
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    _socket(mix.inputs, "A_Color").default_value = hex_rgba(spec["bottom"])
    _socket(mix.inputs, "B_Color").default_value = hex_rgba(spec["top"])
    path = nodes.new("ShaderNodeLightPath")
    strength = nodes.new("ShaderNodeMath")
    strength.operation = "MULTIPLY_ADD"  # is_glossy * (strength * boost) + strength
    _socket(strength.inputs, "Value_001").default_value = spec["strength"] * spec.get("glossy_boost", 0.0)
    _socket(strength.inputs, "Value_002").default_value = spec["strength"]
    links.new(path.outputs["Is Glossy Ray"], _socket(strength.inputs, "Value"))
    links.new(strength.outputs["Value"], background.inputs["Strength"])
    links.new(coords.outputs["Generated"], split.inputs["Vector"])
    links.new(split.outputs["Z"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], _socket(mix.inputs, "Factor_Float"))
    links.new(_socket(mix.outputs, "Result_Color"), background.inputs["Color"])
    links.new(background.outputs["Background"], output.inputs["Surface"])


def setup(theme, hero=False):
    """Replace the lights and world with the rig of 'theme' ('light' or 'dark')."""
    clear()
    spec = params.THEMES[theme]
    _world(spec["world"])
    lights = [_area(item, item["color"]) for item in spec["lights"]]
    if hero and theme == "dark":
        lights.append(_area(params.HERO_ACCENT_LIGHT, params.COLORS["accent"]))
    return lights


def clear():
    for obj in [o for o in bpy.data.objects if o.get("nexo_light")]:
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.lights.remove(data)


def add_shadow_catcher():
    """Invisible floor that only keeps the contact shadow (alpha) in transparent renders."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1.5)
    floor = g.object_from_bmesh("floor", bm)
    floor.is_shadow_catcher = True
    floor["nexo_floor"] = True
    return floor


def add_backdrop(theme, azimuth):
    """Cyclorama (floor curving into a wall) behind the mouse, facing a camera at 'azimuth'."""
    color = params.COLORS["backdrop_dark" if theme == "dark" else "backdrop_light"]
    material = plastic("backdrop_" + theme, color, 0.85)
    radius, back, front, height, half_width = 0.22, 0.18, 1.6, 1.4, 2.0
    profile = [(front, 0.0), (-back, 0.0)]
    for k in range(1, 17):
        a = 0.5 * math.pi * k / 16
        profile.append((-back - radius * math.sin(a), radius - radius * math.cos(a)))
    profile.append((-back - radius, height))
    bm = bmesh.new()
    rows = [[bm.verts.new((d, y, z)) for d, z in profile] for y in (-half_width, half_width)]
    for k in range(len(profile) - 1):
        bm.faces.new((rows[0][k], rows[0][k + 1], rows[1][k + 1], rows[1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    backdrop = g.object_from_bmesh("backdrop", bm, material)
    backdrop.matrix_world = Matrix.Rotation(math.radians(azimuth), 4, "Z")
    for polygon in backdrop.data.polygons:
        polygon.use_smooth = True
    backdrop["nexo_floor"] = True
    return backdrop


def remove_floors():
    for obj in [o for o in bpy.data.objects if o.get("nexo_floor")]:
        g.remove(obj)

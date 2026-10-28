"""Physically based materials (Principled BSDF, Blender 5.x socket names)."""

import bpy

from . import params
from .units import hex_rgba


def _principled(name):
    material = bpy.data.materials.new(name)
    nodes = material.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    return material, nodes, material.node_tree.links, bsdf


def plastic(name, color, roughness, sheen=0.0, grain_scale=0.0, grain_strength=0.0):
    """Soft-touch plastic: broad soft highlight (roughness + a little sheen) and a micro-grain bump
    of ~0.15 mm features. Bump distance is in metres (real scale)."""
    material, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = hex_rgba(color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Specular IOR Level"].default_value = 0.5
    bsdf.inputs["Sheen Weight"].default_value = sheen
    bsdf.inputs["Sheen Roughness"].default_value = 0.45
    if grain_scale > 0 and grain_strength > 0:
        coords = nodes.new("ShaderNodeTexCoord")
        noise = nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = grain_scale
        noise.inputs["Detail"].default_value = 3.0
        noise.inputs["Roughness"].default_value = 0.55
        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = grain_strength
        bump.inputs["Distance"].default_value = 0.00005
        links.new(coords.outputs["Object"], noise.inputs["Vector"])
        links.new(noise.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return material


def steel(name, color, roughness, anisotropic):
    """Machined steel. The tangent runs around the object's local Z axis, which is the wheel axle
    (wheels are built along local Z), giving concentric brushed highlights on the face."""
    material, nodes, links, bsdf = _principled(name)
    bsdf.inputs["Base Color"].default_value = hex_rgba(color)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Anisotropic"].default_value = anisotropic
    tangent = nodes.new("ShaderNodeTangent")
    tangent.direction_type = "RADIAL"
    tangent.axis = "Z"
    links.new(tangent.outputs["Tangent"], bsdf.inputs["Tangent"])
    return material


def emission(name, color, strength):
    material = bpy.data.materials.new(name)
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = hex_rgba(color)
    emit.inputs["Strength"].default_value = strength
    links.new(emit.outputs["Emission"], output.inputs["Surface"])
    return material


def create_all():
    """Every material the model uses, keyed by role."""
    c, m = params.COLORS, params.MATERIALS
    return {
        "shell": plastic("shell", c["shell"], **m["shell"]),
        "buttons": plastic("buttons", c["buttons"], **m["buttons"]),
        "base": plastic("base", c["base"], m["base"]["roughness"]),
        "interior": plastic("interior", c["interior"], m["interior"]["roughness"]),
        "steel": steel("steel", c["steel"], m["steel"]["roughness"], m["steel"]["anisotropic"]),
        "led": emission("led", c["led"], m["led"]["strength"]),
        "mask_white": emission("mask_white", "#ffffff", 1.0),
    }

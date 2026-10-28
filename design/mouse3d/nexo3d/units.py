"""Unit and colour conversions.

Geometry is authored in millimetres and stored in metres (real scale, so light falloff and depth of
field behave like a real product shot). Colours are authored as sRGB hex and converted to the
scene-linear values that shader sockets expect.
"""


def mm(value):
    """Millimetres to metres."""
    return value / 1000.0


def mm3(xyz):
    """Millimetre triple to metre triple."""
    return (mm(xyz[0]), mm(xyz[1]), mm(xyz[2]))


def to_mm(value):
    """Metres to millimetres."""
    return value * 1000.0


def srgb_to_linear(channel):
    """One sRGB-encoded channel (0..1) to scene-linear (IEC 61966-2-1)."""
    if channel <= 0.04045:
        return channel / 12.92
    return ((channel + 0.055) / 1.055) ** 2.4


def linear_to_srgb(channel):
    """One scene-linear channel (0..1) to sRGB encoding."""
    if channel <= 0.0031308:
        return channel * 12.92
    return 1.055 * channel ** (1.0 / 2.4) - 0.055


def hex_rgba(hex_color, alpha=1.0):
    """'#rrggbb' to a scene-linear RGBA tuple for shader sockets (Base Color, Emission Color…)."""
    value = hex_color.lstrip("#")
    if len(value) != 6:
        raise ValueError("expected #rrggbb, got " + hex_color)
    rgb = [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return (srgb_to_linear(rgb[0]), srgb_to_linear(rgb[1]), srgb_to_linear(rgb[2]), alpha)

"""Unit tests that run inside Blender: the maths and I/O the renders depend on."""

import pathlib

import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

from . import cameras, export, fit, params, scene
from . import geometry as g
from .units import hex_rgba, linear_to_srgb, srgb_to_linear


def run(tmp_dir):
    tmp_dir = pathlib.Path(tmp_dir)
    tmp_dir.mkdir(parents=True, exist_ok=True)
    results = []

    def check(name, condition, detail=""):
        results.append((name, bool(condition), detail))

    # Colour
    check("sRGB 0.5 -> linear 0.2140", abs(srgb_to_linear(0.5) - 0.214041) < 1e-5)
    check("sRGB round trip", all(abs(linear_to_srgb(srgb_to_linear(v)) - v) < 1e-9 for v in np.linspace(0, 1, 101)))
    check("hex #ffffff", hex_rgba("#ffffff") == (1.0, 1.0, 1.0, 1.0))

    # 2D geometry
    square = [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]
    for name, poly in (("ccw", square), ("cw", list(reversed(square)))):
        grown = g.offset_polygon(poly, 1.0)
        check("offset square (%s input)" % name,
              all(abs(abs(x) - 1.5) < 1e-9 and abs(abs(y) - 1.5) < 1e-9 for x, y in grown), grown)
    curve = g.monotone_cubic([0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 1.0, 0.0])
    values = [curve(3.0 * i / 300) for i in range(301)]
    check("monotone cubic has no overshoot", max(values) <= 1.0 + 1e-9 and min(values) >= -1e-9)
    spline = g.catmull_rom_closed([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)], 5)
    check("Catmull-Rom passes through its control points",
          len(spline) == 20 and spline[0] == (0.0, 0.0) and spline[5] == (1.0, 0.0))

    # Binary images used by the silhouette fit
    ring = np.zeros((50, 50), dtype=bool)
    ring[10:40, 10:40] = True
    ring[20:30, 20:30] = False
    filled = fit.fill_holes(ring)
    check("fill holes", filled[25, 25] and int(filled.sum()) == 900)
    two = np.zeros((20, 20), dtype=bool)
    two[2:5, 2:5] = True
    two[8:18, 8:18] = True
    check("largest component", int(fit.largest_component(two).sum()) == 100)
    check("IoU of identical masks", fit.iou(two, two) == 1.0)
    threshold = fit.otsu_threshold(np.concatenate([np.full(1000, 0.1), np.full(1000, 0.9)]))
    check("Otsu threshold separates two levels", 0.1 < threshold <= 0.9, threshold)
    shape = np.zeros((60, 100), dtype=bool)
    shape[10:50, 10:70] = True
    shape[10:25, 70:95] = True
    score, turns, _p, _m = fit.compare("left", np.rot90(shape, 1), shape)
    check("rotated photo is recovered", score > 0.97 and turns == 3, (score, turns))

    # Hotspot helpers
    l_shape = np.zeros((200, 200), dtype=np.float32)
    l_shape[20:180, 20:60] = 1.0
    l_shape[140:180, 20:180] = 1.0
    anchor = export.anchor_from_mask(l_shape)
    check("anchor lies inside an L-shaped mask",
          anchor is not None and l_shape[int(anchor[1] * 200), int(anchor[0] * 200)] == 1.0, anchor)
    check("no anchor for an invisible part", export.anchor_from_mask(np.zeros((40, 40))) is None)
    box = export.bbox_from_mask(l_shape)
    check("bbox of the L shape", box == [0.1, 0.1, 0.9, 0.9], box)

    # PNG round trip through Blender (8-bit, straight alpha, rows top-down)
    rgba = np.zeros((4, 6, 4), dtype=np.float32)
    rgba[..., 0] = 1.0
    rgba[..., 3] = 0.5
    rgba[0, 0] = (0.0, 0.0, 1.0, 1.0)
    path = tmp_dir / "roundtrip.png"
    export.write_png(path, rgba, compression=15)
    back = export.read_image(path)
    check("PNG round trip keeps values, alpha and row order", np.allclose(back, rgba, atol=1.0 / 255.0))
    half = export.downscale_half(np.ones((4, 4, 4), dtype=np.float32))
    check("2x downscale", half.shape == (2, 2, 4) and np.allclose(half, 1.0))

    # Camera maths (with lens shift, as the auto-framing uses it)
    scene.reset()
    scene.set_resolution(400, 250)
    camera = cameras._camera("selftest_camera")
    camera.location = (0.3, 0.4, 0.2)
    camera.rotation_euler = (-Vector((0.3, 0.4, 0.2))).to_track_quat("-Z", "Y").to_euler()
    camera.data.shift_x, camera.data.shift_y = 0.07, -0.04
    scene.update()
    worst = 0.0
    for u, v in ((0.1, 0.2), (0.5, 0.5), (0.9, 0.7), (0.02, 0.98)):
        origin, direction = cameras.pixel_ray(camera, u, v)
        projected = world_to_camera_view(bpy_scene(), camera, origin + direction * 0.37)
        worst = max(worst, abs(projected.x - u), abs((1.0 - projected.y) - v))
    check("pixel ray and projection agree (shifted camera)", worst < 1e-5, worst)

    sample = {
        "schema": 1, "device": "mx-master-3s", "view": "app", "image": {"width": 4, "height": 4},
        "coordinates": "x", "camera": {},
        "parts": [{"id": p[0], "cid": p[1], "label": p[2], "anchor": [0.5, 0.5], "bbox": [0.4, 0.4, 0.6, 0.6],
                   "mask": "m", "coverage": 0.1} for p in params.PARTS],
    }
    check("hotspot schema accepts a valid file", export.validate_hotspots(sample) == [])
    sample["parts"][0]["anchor"] = [0.9, 0.9]
    check("hotspot schema rejects an anchor outside its bbox", export.validate_hotspots(sample) != [])
    return results


def bpy_scene():
    import bpy

    return bpy.context.scene

"""Renders and the output contract: beauty images, per-part masks, hotspots.json and image metrics."""

import json
import pathlib

import bpy
import numpy as np

from . import cameras, lights, params, scene


# ---------------------------------------------------------------------------------------------
# PNG I/O through Blender (no extra Python packages needed)
# ---------------------------------------------------------------------------------------------
def read_image(path):
    """PNG or JPEG -> (H, W, 4) float array, rows top-down, sRGB-encoded RGB, straight alpha."""
    image = bpy.data.images.load(str(path), check_existing=False)
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(height, width, 4)[::-1].copy()


def write_png(path, rgba, compression=90):
    """Save a (H, W, 4) float array (rows top-down, sRGB-encoded, straight alpha) as 8-bit PNG."""
    height, width = rgba.shape[:2]
    image = bpy.data.images.new("tmp_write", width, height, alpha=True)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(np.ascontiguousarray(rgba[::-1], dtype=np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    scene_settings = bpy.context.scene.render.image_settings
    previous = scene_settings.compression
    scene_settings.compression = compression
    image.save()
    scene_settings.compression = previous
    bpy.data.images.remove(image)
    return path


def downscale_half(rgba):
    """Exact 2× box downscale with premultiplied averaging (no dark fringes on the alpha edge)."""
    height, width = rgba.shape[0] // 2 * 2, rgba.shape[1] // 2 * 2
    rgba = rgba[:height, :width]
    alpha = rgba[..., 3:4]
    premultiplied = np.concatenate([rgba[..., :3] * alpha, alpha], axis=2)
    small = premultiplied.reshape(height // 2, 2, width // 2, 2, 4).mean(axis=(1, 3))
    out_alpha = small[..., 3:4]
    rgb = np.where(out_alpha > 1e-6, small[..., :3] / np.maximum(out_alpha, 1e-6), 0.0)
    return np.concatenate([np.clip(rgb, 0.0, 1.0), out_alpha], axis=2)


# ---------------------------------------------------------------------------------------------
# Renders
# ---------------------------------------------------------------------------------------------
def render_beauty(theme, path, quality, transparent=True, hero=False, samples=None):
    lights.setup(theme, hero=hero)
    scene.configure_cycles(quality, transparent=transparent)
    if samples:
        bpy.context.scene.cycles.samples = samples
    spec = params.THEMES[theme]
    scene.configure_color(spec["view"], spec["look"], spec["exposure"])
    return scene.render_still(path)


def render_mask(objects, part, path, white, samples=None):
    """Coverage of 'part' as seen by the active camera (others are holdouts: they still hide it).
    part=None gives the coverage of the whole mouse. RGB is white, alpha is the coverage."""
    sc = bpy.context.scene
    saved = (sc.cycles.samples, sc.cycles.use_adaptive_sampling, sc.cycles.use_denoising,
             sc.view_settings.view_transform, sc.view_settings.look, sc.render.film_transparent,
             sc.render.resolution_percentage)
    floors = [o for o in bpy.data.objects if o.get("nexo_floor")]
    try:
        sc.cycles.samples = samples or params.MASK_SAMPLES
        sc.cycles.use_adaptive_sampling = False
        sc.cycles.use_denoising = False
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        sc.render.film_transparent = True
        sc.render.resolution_percentage = 100
        sc.view_layers[0].material_override = white
        for obj in floors:
            obj.hide_render = True
        for obj in objects:
            obj.is_holdout = part is not None and obj is not part
        scene.render_still(path)
    finally:
        for obj in objects:
            obj.is_holdout = False
        for obj in floors:
            obj.hide_render = False
        sc.view_layers[0].material_override = None
        (sc.cycles.samples, sc.cycles.use_adaptive_sampling, sc.cycles.use_denoising,
         sc.view_settings.view_transform, sc.view_settings.look, sc.render.film_transparent,
         sc.render.resolution_percentage) = saved
    return path


# ---------------------------------------------------------------------------------------------
# Hotspots
# ---------------------------------------------------------------------------------------------
def anchor_from_mask(alpha, factor=4):
    """Point deepest inside the visible part (last pixels to survive repeated erosion, the one
    closest to the centroid). Always inside the mask, even for L-shaped parts. Returns (u, v)
    normalised, origin top-left, or None if the part is not visible."""
    height, width = alpha.shape
    h, w = height // factor * factor, width // factor * factor
    small = alpha[:h, :w].reshape(h // factor, factor, w // factor, factor).mean(axis=(1, 3)) > 0.5
    if not small.any():
        return None
    current = small
    while True:
        eroded = current.copy()
        eroded[1:, :] &= current[:-1, :]
        eroded[:-1, :] &= current[1:, :]
        eroded[:, 1:] &= current[:, :-1]
        eroded[:, :-1] &= current[:, 1:]
        eroded[0, :] = eroded[-1, :] = False
        eroded[:, 0] = eroded[:, -1] = False
        if not eroded.any():
            break
        current = eroded
    rows, cols = np.nonzero(small)
    cy, cx = rows.mean(), cols.mean()
    rows, cols = np.nonzero(current)
    best = int(np.argmin((rows - cy) ** 2 + (cols - cx) ** 2))
    return ((cols[best] + 0.5) * factor / width, (rows[best] + 0.5) * factor / height)


def bbox_from_mask(alpha):
    rows, cols = np.nonzero(alpha > 0.5)
    if rows.size == 0:
        return None
    height, width = alpha.shape
    return [cols.min() / width, rows.min() / height, (cols.max() + 1) / width, (rows.max() + 1) / height]


def hit_object(camera, u, v_top):
    origin, direction = cameras.pixel_ray(camera, u, v_top)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    hit, _location, _normal, _index, obj, _matrix = bpy.context.scene.ray_cast(depsgraph, origin, direction)
    return obj.name if hit and obj is not None else None


def build_hotspots(camera, parts, masks_dir, view):
    """hotspots.json content for 'view'. Each anchor is checked by casting a ray from the camera
    through it: it must hit that very part (visible, not hidden behind another one)."""
    sc = bpy.context.scene
    width = sc.render.resolution_x * sc.render.resolution_percentage // 100
    height = sc.render.resolution_y * sc.render.resolution_percentage // 100
    spec = params.CAMERAS[view]
    entries, problems = [], []
    for part_id, cid, label in params.PARTS:
        alpha = read_image(masks_dir / (part_id + ".png"))[..., 3]
        anchor = anchor_from_mask(alpha)
        bbox = bbox_from_mask(alpha)
        if anchor is None:
            problems.append(part_id + ": not visible")
            continue
        hit = hit_object(camera, anchor[0], anchor[1])
        if hit != parts[part_id].name:
            problems.append("%s: ray through the anchor hits %r" % (part_id, hit))
        row = min(int(anchor[1] * height), height - 1)
        col = min(int(anchor[0] * width), width - 1)
        if alpha[row, col] <= 0.5:
            problems.append(part_id + ": anchor outside its mask")
        entries.append({
            "id": part_id, "cid": cid, "label": label,
            "anchor": [round(anchor[0], 5), round(anchor[1], 5)],
            "bbox": [round(v, 5) for v in bbox],
            "mask": "masks/%s.png" % part_id,
            "coverage": round(float((alpha > 0.5).mean()), 6),
        })
    data = {
        "schema": 1,
        "device": "mx-master-3s",
        "view": view,
        "image": {"width": width, "height": height},
        "coordinates": "normalised; origin at the top-left corner; u grows to the right, v grows downwards",
        "camera": {"azimuth_deg": spec["azimuth"], "elevation_deg": spec["elevation"], "lens_mm": spec["lens"]},
        "parts": entries,
    }
    return data, problems


def validate_hotspots(data):
    """Schema check used by the selftest and by export. Returns a list of problems."""
    problems = []
    for key in ("schema", "device", "view", "image", "coordinates", "camera", "parts"):
        if key not in data:
            problems.append("missing key " + key)
    ids = [p.get("id") for p in data.get("parts", [])]
    expected = [p[0] for p in params.PARTS]
    if sorted(ids) != sorted(expected):
        problems.append("parts %s != expected %s" % (ids, expected))
    for part in data.get("parts", []):
        u, v = part.get("anchor", (-1, -1))
        if not (0 <= u <= 1 and 0 <= v <= 1):
            problems.append(part.get("id", "?") + ": anchor out of range")
        x0, y0, x1, y1 = part.get("bbox", (0, 0, -1, -1))
        if not (0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1 and x0 <= u <= x1 and y0 <= v <= y1):
            problems.append(part.get("id", "?") + ": bbox invalid or does not contain the anchor")
    return problems


def write_json(path, data):
    pathlib.Path(path).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def hotspot_overlay(image_path, data, out_path, background=(0x11 / 255, 0x16 / 255, 0x1a / 255)):
    """Review aid: the render over the dark stage colour, each part's bbox and anchor in cyan."""
    image = read_image(image_path)
    alpha = image[..., 3:4]
    rgb = image[..., :3] * alpha + np.array(background) * (1.0 - alpha)
    height, width = rgb.shape[:2]
    cyan = np.array((0x3f / 255, 0xc9 / 255, 0xd6 / 255))
    rows, cols = np.mgrid[0:height, 0:width]
    for part in data["parts"]:
        x0, y0, x1, y1 = (int(round(v * size)) for v, size in zip(part["bbox"], (width, height, width, height)))
        x1, y1 = min(x1, width - 1), min(y1, height - 1)
        for t in range(2):
            rgb[y0 + t, x0:x1] = rgb[y1 - t, x0:x1] = cyan
            rgb[y0:y1, x0 + t] = rgb[y0:y1, x1 - t] = cyan
        u, v = part["anchor"]
        dist = (cols - u * width) ** 2 + (rows - v * height) ** 2
        rgb[dist <= 14 ** 2] = (1.0, 1.0, 1.0)
        rgb[dist <= 10 ** 2] = cyan
    write_png(out_path, np.concatenate([rgb, np.ones((height, width, 1))], axis=2).astype(np.float32), 15)
    return out_path


# ---------------------------------------------------------------------------------------------
# Image metrics (G4)
# ---------------------------------------------------------------------------------------------
def exposure_metrics(beauty_path, mouse_mask_path):
    """Mean sRGB value and clipped fraction over the pixels fully covered by the mouse."""
    beauty = read_image(beauty_path)
    coverage = read_image(mouse_mask_path)[..., 3]
    inside = (coverage > 0.99) & (beauty[..., 3] > 0.99)
    rgb = beauty[..., :3][inside]
    if rgb.size == 0:
        return {"mean_srgb": None, "clipped_fraction": None}
    return {
        "mean_srgb": round(float(rgb.mean()), 4),
        "clipped_fraction": round(float((rgb.max(axis=1) >= 254.0 / 255.0).mean()), 5),
    }

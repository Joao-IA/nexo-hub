"""Silhouette fitting: the owner's photos versus orthographic renders of the model.

Each silhouette is cropped to its bounding box and resampled to the official size of that view
(ORTHO_EXTENT_MM × FIT_PIXELS_PER_MM), so scale and framing of the photo do not matter — only the
shape does. Phone photos are tried in the four 90° rotations (EXIF orientation is ignored by
Blender), never mirrored. Output: IoU per view and a diff image (red = only in the photo, blue =
only in the model, white = both).
"""

import math
import pathlib

import bpy
import numpy as np

from . import cameras, params
from .export import read_image, write_png

PHOTO_SUFFIXES = (".jpg", ".jpeg", ".png")


# ---------------------------------------------------------------------------------------------
# Binary image helpers (numpy only)
# ---------------------------------------------------------------------------------------------
def otsu_threshold(values):
    histogram, _edges = np.histogram(values, bins=256, range=(0.0, 1.0))
    p = histogram / max(histogram.sum(), 1)
    omega = np.cumsum(p)
    mu = np.cumsum(p * np.arange(256))
    between = (mu[-1] * omega - mu) ** 2 / (omega * (1.0 - omega) + 1e-12)
    return (int(np.nanargmax(between)) + 1) / 256.0


def label_components(mask):
    """4-connected components via row runs + union-find. 0 = background."""
    height = mask.shape[0]
    labels = np.zeros(mask.shape, dtype=np.int32)
    parent = [0]

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    previous = []
    for row in range(height):
        edges = np.diff(np.concatenate(([0], mask[row].astype(np.int8), [0])))
        runs = []
        for start, end in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
            label = len(parent)
            parent.append(label)
            for p_start, p_end, p_label in previous:
                if p_start < end and start < p_end:
                    a, b = find(label), find(p_label)
                    if a != b:
                        parent[max(a, b)] = min(a, b)
            runs.append((start, end, label))
            labels[row, start:end] = label
        previous = runs
    roots = np.array([find(i) for i in range(len(parent))], dtype=np.int32)
    return roots[labels]


def largest_component(mask):
    labels = label_components(mask)
    counts = np.bincount(labels.ravel())
    if counts.size <= 1:
        return mask
    counts[0] = 0
    return labels == int(np.argmax(counts))


def fill_holes(mask):
    """Fill background regions that do not touch the border (bright reflections on the shell,
    the silver wheel…)."""
    labels = label_components(~mask)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]])).tolist())
    holes = (~mask) & ~np.isin(labels, list(border))
    return mask | holes


def normalise(mask, width, height):
    """Crop to the bounding box and resample (nearest) to width × height."""
    rows, cols = np.nonzero(mask)
    if rows.size == 0:
        return np.zeros((height, width), dtype=bool)
    crop = mask[rows.min():rows.max() + 1, cols.min():cols.max() + 1]
    r = ((np.arange(height) + 0.5) * crop.shape[0] / height).astype(int)
    c = ((np.arange(width) + 0.5) * crop.shape[1] / width).astype(int)
    return crop[r][:, c]


def iou(a, b):
    union = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum() / union) if union else 1.0


# ---------------------------------------------------------------------------------------------
# Photo and model silhouettes
# ---------------------------------------------------------------------------------------------
def photo_mask(path, max_side=1600):
    """Dark mouse on white paper -> boolean silhouette (largest dark blob, holes filled)."""
    rgba = read_image(path)
    height, width = rgba.shape[:2]
    factor = max(1, int(math.ceil(max(width, height) / max_side)))
    h, w = height // factor * factor, width // factor * factor
    small = rgba[:h, :w, :3].reshape(h // factor, factor, w // factor, factor, 3).mean(axis=(1, 3))
    luminance = small @ np.array([0.2126, 0.7152, 0.0722])
    threshold = otsu_threshold(luminance)
    mask = fill_holes(largest_component(luminance < threshold))
    return mask, threshold


def model_mask(view, objects, out_path):
    """Workbench (fast) orthographic silhouette of the model."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.light = "FLAT"
    sc.display.shading.color_type = "SINGLE"
    sc.display.shading.single_color = (0.05, 0.05, 0.05)
    sc.render.film_transparent = True
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    cameras.orthographic(view, objects, params.FIT_PIXELS_PER_MM * 2)
    sc.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)
    return read_image(out_path)[..., 3] > 0.5


def compare(view, photo, model):
    """Best IoU over the 4 rotations of the photo. Returns (iou, quarter_turns, photo_n, model_n)."""
    extent_w, extent_h = params.ORTHO_EXTENT_MM[view]
    width = int(round(extent_w * params.FIT_PIXELS_PER_MM))
    height = int(round(extent_h * params.FIT_PIXELS_PER_MM))
    model_n = normalise(model, width, height)
    best = None
    for turns in range(4):
        candidate = normalise(np.rot90(photo, turns), width, height)
        score = iou(candidate, model_n)
        if best is None or score > best[0]:
            best = (score, turns, candidate)
    return best[0], best[1], best[2], model_n


def diff_image(photo_n, model_n):
    rgba = np.zeros(photo_n.shape + (4,), dtype=np.float32)
    rgba[..., 3] = 1.0
    both = photo_n & model_n
    rgba[both, :3] = 1.0
    rgba[photo_n & ~model_n, 0] = 1.0
    rgba[model_n & ~photo_n, 2] = 1.0
    return rgba


def find_photo(folder, view):
    for suffix in PHOTO_SUFFIXES:
        candidate = pathlib.Path(folder) / (view + suffix)
        if candidate.exists():
            return candidate
    return None


def run(objects, photos_dir, out_dir):
    """Compare every view that has a photo. Returns {view: result} and writes diffs to out_dir."""
    out_dir = pathlib.Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    for view in params.ORTHO_VIEWS:
        photo_path = find_photo(photos_dir, view)
        if photo_path is None:
            results[view] = {"status": "no photo (expected %s/%s.jpg)" % (photos_dir, view)}
            continue
        photo, threshold = photo_mask(photo_path)
        model = model_mask(view, objects, out_dir / ("model-" + view + ".png"))
        score, turns, photo_n, model_n = compare(view, photo, model)
        write_png(out_dir / ("diff-" + view + ".png"), diff_image(photo_n, model_n), compression=15)
        minimum = params.FIT_MIN_IOU[view]
        results[view] = {"status": "ok" if score >= minimum else "below target", "iou": round(score, 4),
                         "min": minimum, "photo_quarter_turns": turns, "threshold": round(threshold, 3),
                         "photo": str(photo_path)}
    cameras.remove_cameras()
    return results

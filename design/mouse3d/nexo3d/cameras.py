"""Cameras: auto-framed perspective views (app, hero) and orthographic views for silhouette fitting.

Coordinates returned by world_to_camera_view are normalised with the origin at the BOTTOM-left;
everything this project writes (hotspots.json) uses the TOP-left, so v = 1 - y.
"""

import math

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

from . import geometry as g
from . import params
from .lights import target
from .scene import set_resolution, update


def _camera(name, kind="PERSP"):
    data = bpy.data.cameras.new(name)
    data.type = kind
    data.sensor_fit = "HORIZONTAL"
    data.sensor_width = 36.0
    data.clip_start = 0.005
    data.clip_end = 20.0
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _sample_points(objects, limit=6000):
    points = np.concatenate([g.world_vertices(obj) for obj in objects])
    step = max(1, len(points) // limit)
    return [Vector(p) for p in points[::step]]


def _projected_box(camera, points):
    scene = bpy.context.scene
    coords = [world_to_camera_view(scene, camera, p) for p in points]
    us = [c.x for c in coords]
    vs = [c.y for c in coords]
    return min(us), max(us), min(vs), max(vs)


def perspective(view, objects):
    """Camera for 'app' or 'hero' that frames 'objects' to the fill/centre in params.CAMERAS."""
    spec = params.CAMERAS[view]
    width, height = spec["resolution"]
    set_resolution(width, height)
    camera = _camera("camera_" + view)
    camera.data.lens = spec["lens"]
    a, e = math.radians(spec["azimuth"]), math.radians(spec["elevation"])
    direction = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    points = _sample_points(objects)

    distance = 0.5
    for _ in range(8):
        camera.location = target() + direction * distance
        camera.data.shift_x = camera.data.shift_y = 0.0
        update()
        u0, u1, _v0, _v1 = _projected_box(camera, points)
        ratio = (u1 - u0) / spec["fill"]
        distance *= ratio
        if abs(ratio - 1.0) < 0.002:
            break

    aspect = height / width
    target_u, target_v_top = spec["center"]
    for _ in range(3):
        u0, u1, v0, v1 = _projected_box(camera, points)
        camera.data.shift_x += (u0 + u1) / 2 - target_u
        camera.data.shift_y += ((v0 + v1) / 2 - (1.0 - target_v_top)) * aspect
        update()

    if spec["dof_fstop"]:
        camera.data.dof.use_dof = True
        camera.data.dof.aperture_fstop = spec["dof_fstop"]
        camera.data.dof.focus_distance = (camera.location - target()).length
    bpy.context.scene.camera = camera
    return camera


def orthographic(view, objects, pixels_per_mm):
    """Orthographic camera looking at the mouse from 'view' (top, left, right, front, rear)."""
    direction, up = (Vector(v) for v in params.ORTHO_VIEWS[view])
    extent_w, extent_h = params.ORTHO_EXTENT_MM[view]
    margin = 1.12
    set_resolution(int(round(extent_w * margin * pixels_per_mm)), int(round(extent_h * margin * pixels_per_mm)))
    camera = _camera("camera_" + view, "ORTHO")
    camera.data.ortho_scale = max(extent_w, extent_h) * margin / 1000.0
    camera.data.sensor_fit = "AUTO"
    lo, hi = g.world_bounds_mm(objects)
    centre = (lo + hi) / 2000.0
    x_axis = up.cross(direction)
    basis = Matrix((x_axis, up, direction)).transposed()
    camera.matrix_world = Matrix.Translation(centre + direction * 0.5) @ basis.to_4x4()
    bpy.context.scene.camera = camera
    update()
    return camera


def pixel_ray(camera, u, v_top):
    """World-space ray (origin, direction) through normalised pixel (u, v) with origin top-left.
    Camera.view_frame already includes lens shift."""
    frame = camera.data.view_frame(scene=bpy.context.scene)  # top-right, bottom-right, bottom-left, top-left
    top_right, bottom_right, bottom_left, top_left = frame
    x = bottom_left.x + (bottom_right.x - bottom_left.x) * u
    y = top_left.y + (bottom_left.y - top_left.y) * v_top
    point = camera.matrix_world @ Vector((x, y, top_left.z))
    origin = camera.matrix_world.translation
    return origin, (point - origin).normalized()


def remove_cameras():
    for obj in [o for o in bpy.data.objects if o.type == "CAMERA"]:
        data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.cameras.remove(data)

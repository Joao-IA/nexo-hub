"""Mesh helpers shared by the model: builders, booleans, bevels, smoothing and ray casts.

Shell, cutters and the parts carved from them are baked in world space (identity transform). Parts
that need their own axis (wheels, side buttons) keep a placement matrix so the anisotropic steel
can use a radial tangent around the local Z axis; world-space helpers below account for it.
"""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

from .units import mm, to_mm


# ---------------------------------------------------------------------------------------------
# Objects
# ---------------------------------------------------------------------------------------------
def link(obj, collection=None):
    (collection or bpy.context.scene.collection).objects.link(obj)
    return obj


def object_from_bmesh(name, bm, material=None, collection=None):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    if material is not None:
        mesh.materials.append(material)
    return link(obj, collection)


def duplicate(obj, name):
    copy = bpy.data.objects.new(name, obj.data.copy())
    copy.matrix_world = obj.matrix_world.copy()
    return link(copy)


def remove(obj):
    mesh = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if mesh is not None and mesh.users == 0:
        bpy.data.meshes.remove(mesh)


def apply_modifiers(obj):
    """Bake the evaluated mesh (all modifiers) into the object's data and drop the modifiers."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    old = obj.data
    obj.modifiers.clear()
    obj.data = mesh
    if old.users == 0:
        bpy.data.meshes.remove(old)
    mesh.name = obj.name
    return obj


def boolean(obj, operation, operand):
    """Exact boolean, applied immediately. Faces created by the cut take the operand's material
    (cutters carry the dark 'interior' material, so seams and pockets read as shadowed gaps)."""
    modifier = obj.modifiers.new("boolean", "BOOLEAN")
    modifier.operation = operation
    modifier.solver = "EXACT"
    modifier.material_mode = "TRANSFER"
    if isinstance(operand, bpy.types.Collection):
        modifier.operand_type = "COLLECTION"
        modifier.collection = operand
    else:
        modifier.operand_type = "OBJECT"
        modifier.object = operand
    return apply_modifiers(obj)


def bevel(obj, width_mm, segments=2, angle_deg=35.0):
    """Round every edge sharper than angle_deg (catches highlights like a moulded part)."""
    modifier = obj.modifiers.new("bevel", "BEVEL")
    modifier.width = mm(width_mm)
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle_deg)
    modifier.use_clamp_overlap = True
    modifier.harden_normals = False
    return apply_modifiers(obj)


def subdivide(obj, levels):
    modifier = obj.modifiers.new("subsurf", "SUBSURF")
    modifier.levels = levels
    modifier.render_levels = levels
    modifier.quality = 3
    return apply_modifiers(obj)


def shade(obj, sharp_angle_deg=40.0):
    """Smooth shading everywhere except edges sharper than sharp_angle_deg (no auto-smooth in 5.x)."""
    limit = math.radians(sharp_angle_deg)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for face in bm.faces:
        face.smooth = True
    for edge in bm.edges:
        edge.smooth = not (edge.is_manifold and edge.calc_face_angle(0.0) > limit)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return obj


def set_material(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.material_index = 0
    return obj


# ---------------------------------------------------------------------------------------------
# 2D helpers (millimetres)
# ---------------------------------------------------------------------------------------------
def signed_area(poly):
    return 0.5 * sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))


def ccw(poly):
    return list(poly) if signed_area(poly) > 0 else list(reversed(poly))


def offset_polygon(poly, distance):
    """Offset a counter-clockwise polygon outwards (miter joins, clamped)."""
    poly = ccw(poly)
    count = len(poly)
    result = []
    for i in range(count):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % count]
        n1 = _edge_normal(p0, p1)
        n2 = _edge_normal(p1, p2)
        nx, ny = n1[0] + n2[0], n1[1] + n2[1]
        length = math.hypot(nx, ny)
        if length < 1e-9:
            nx, ny, length = n1[0], n1[1], 1.0
        nx, ny = nx / length, ny / length
        cos_half = max(0.35, nx * n1[0] + ny * n1[1])
        result.append((p1[0] + nx * distance / cos_half, p1[1] + ny * distance / cos_half))
    return result


def _edge_normal(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1.0
    return (dy / length, -dx / length)  # right-hand normal = outward for CCW polygons


def catmull_rom_closed(points, samples_per_segment):
    """Closed Catmull-Rom spline through 'points' (tuples of any dimension), uniform per segment so
    that point k of one section corresponds to point k of every other section (no twisting)."""
    count = len(points)
    result = []
    for i in range(count):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % count], points[(i + 2) % count]
        for step in range(samples_per_segment):
            t = step / samples_per_segment
            t2, t3 = t * t, t * t * t
            result.append(tuple(
                0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
                for k in range(len(p1))))
    return result


def monotone_cubic(xs, ys):
    """Fritsch–Carlson monotone cubic interpolation (no overshoot between key sections)."""
    n = len(xs)
    deltas = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    tangents = [deltas[0]] + [
        0.0 if deltas[i - 1] * deltas[i] <= 0 else 0.5 * (deltas[i - 1] + deltas[i]) for i in range(1, n - 1)
    ] + [deltas[-1]]
    for i in range(n - 1):
        if deltas[i] == 0:
            tangents[i] = tangents[i + 1] = 0.0
            continue
        a, b = tangents[i] / deltas[i], tangents[i + 1] / deltas[i]
        s = a * a + b * b
        if s > 9:
            tau = 3 / math.sqrt(s)
            tangents[i], tangents[i + 1] = tau * a * deltas[i], tau * b * deltas[i]

    def evaluate(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = max(k for k in range(n - 1) if xs[k] <= x)
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        h00, h10 = 2 * t ** 3 - 3 * t ** 2 + 1, t ** 3 - 2 * t ** 2 + t
        h01, h11 = -2 * t ** 3 + 3 * t ** 2, t ** 3 - t ** 2
        return h00 * ys[i] + h10 * h * tangents[i] + h01 * ys[i + 1] + h11 * h * tangents[i + 1]

    return evaluate


# ---------------------------------------------------------------------------------------------
# Primitive builders (millimetre inputs, metre geometry)
# ---------------------------------------------------------------------------------------------
def prism(name, poly_mm, z_bottom_mm, z_top_mm, material=None):
    """Closed prism over a 2D polygon. Each z is a number or a callable (x, y) -> z, so the floor
    (or ceiling) of a cutter can follow a seam line instead of being flat."""
    poly = ccw(poly_mm)
    floor = z_bottom_mm if callable(z_bottom_mm) else (lambda x, y, z=z_bottom_mm: z)
    ceiling = z_top_mm if callable(z_top_mm) else (lambda x, y, z=z_top_mm: z)
    bm = bmesh.new()
    bottom = [bm.verts.new((mm(x), mm(y), mm(floor(x, y)))) for x, y in poly]
    top = [bm.verts.new((mm(x), mm(y), mm(ceiling(x, y)))) for x, y in poly]
    count = len(poly)
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return object_from_bmesh(name, bm, material)


def box(name, size_mm, material=None, radius_mm=0.0, segments=3):
    """Box centred on the origin, optionally with rounded edges."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((mm(size_mm[0]), mm(size_mm[1]), mm(size_mm[2]))), verts=bm.verts[:])
    obj = object_from_bmesh(name, bm, material)
    if radius_mm > 0:
        modifier = obj.modifiers.new("round", "BEVEL")
        modifier.width = mm(radius_mm)
        modifier.segments = segments
        modifier.limit_method = "NONE"
        modifier.use_clamp_overlap = True
        apply_modifiers(obj)
    return obj


def ribbed_cylinder(name, diameter_mm, width_mm, ribs, rib_depth_mm, chamfer_mm, material=None,
                    segments_per_rib=4):
    """Wheel along the local Z axis. Ribs are real geometry (narrow grooves, flat lands) on the rim;
    the two outer rings are chamfered and smooth, like a machined wheel."""
    radius = diameter_mm / 2.0
    half = width_mm / 2.0
    segments = ribs * segments_per_rib
    levels = [(-half, radius - chamfer_mm, False), (-half + chamfer_mm, radius, True),
              (half - chamfer_mm, radius, True), (half, radius - chamfer_mm, False)]
    bm = bmesh.new()
    rings = []
    for z, ring_radius, ribbed in levels:
        ring = []
        for k in range(segments):
            angle = 2.0 * math.pi * k / segments
            r = ring_radius
            if ribbed:
                phase = (k % segments_per_rib) / segments_per_rib
                r -= rib_depth_mm * (0.5 + 0.5 * math.cos(2.0 * math.pi * phase)) ** 3
            ring.append(bm.verts.new((mm(r * math.cos(angle)), mm(r * math.sin(angle)), mm(z))))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((a[k], a[j], b[j], b[k]))
    for ring, z in ((rings[0], -half), (rings[-1], half)):
        centre = bm.verts.new((0.0, 0.0, mm(z)))
        for k in range(segments):
            j = (k + 1) % segments
            bm.faces.new((ring[k], ring[j], centre) if z > 0 else (ring[j], ring[k], centre))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return object_from_bmesh(name, bm, material)


def cylinder(name, diameter_mm, width_mm, segments=64, material=None):
    return ribbed_cylinder(name, diameter_mm, width_mm, ribs=segments // 4, rib_depth_mm=0.0,
                           chamfer_mm=0.0, material=material)


# ---------------------------------------------------------------------------------------------
# Placement and ray casts
# ---------------------------------------------------------------------------------------------
def frame_from_normal(normal, along=Vector((1.0, 0.0, 0.0))):
    """Orthonormal basis with Z = normal and X as close as possible to 'along'."""
    z = Vector(normal).normalized()
    x = Vector(along) - z * Vector(along).dot(z)
    if x.length < 1e-6:
        x = Vector((0.0, 1.0, 0.0)) - z * z.y
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def place(obj, origin_mm, basis):
    """Set obj.matrix_world from a 3×3 basis and a millimetre origin."""
    matrix = basis.to_4x4()
    matrix.translation = Vector((mm(origin_mm[0]), mm(origin_mm[1]), mm(origin_mm[2])))
    obj.matrix_world = matrix
    return obj


def world_vertices(obj):
    """(N, 3) numpy array of the evaluated vertices of obj, in world space (metres)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    co = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
    mesh.vertices.foreach_get("co", co)
    evaluated.to_mesh_clear()
    matrix = np.array(obj.matrix_world)
    return co.reshape(-1, 3) @ matrix[:3, :3].T + matrix[:3, 3]


def world_bvh(objects):
    """BVH of the evaluated meshes of 'objects', in world space (metres)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    vertices, polygons = [], []
    for obj in objects:
        offset = len(vertices)
        vertices.extend(map(tuple, world_vertices(obj)))
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        polygons.extend([offset + i for i in p.vertices] for p in mesh.polygons)
        evaluated.to_mesh_clear()
    return BVHTree.FromPolygons(vertices, polygons)


def cast_mm(tree, origin_mm, direction):
    """First hit from origin (mm) along direction. Returns (point_mm, normal) or (None, None)."""
    origin = Vector((mm(origin_mm[0]), mm(origin_mm[1]), mm(origin_mm[2])))
    location, normal, _index, _distance = tree.ray_cast(origin, Vector(direction).normalized())
    if location is None:
        return None, None
    return Vector((to_mm(location.x), to_mm(location.y), to_mm(location.z))), normal.normalized()


def world_bounds_mm(objects):
    """(min, max) corners in millimetres of the evaluated objects."""
    points = np.concatenate([world_vertices(obj) for obj in objects])
    return Vector(points.min(axis=0) * 1000.0), Vector(points.max(axis=0) * 1000.0)

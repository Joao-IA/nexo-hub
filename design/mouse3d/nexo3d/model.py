"""MX Master 3S-like mouse, built procedurally from params.py (original geometry, no brand marks).

Pipeline
--------
1. Shell: closed loft of cross-sections. Every section has the same 14 *semantic* control points
   (bottom, right flank, crest, left overhang, thumb channel, thumb-rest wing…), so point k always
   means the same feature along the whole length and the surface never twists. Subdivision
   smooths it; then it is rescaled to the official size.
2. Parts: shell ∩ cutter (exact booleans). The body is the shell minus every cutter grown by the
   seam gap, so separate parts are divided by a real 0.45 mm gap whose walls take the dark
   'interior' material. Every gap must end against solid body: a gap that crosses the whole
   mouse shows the background through it (the base plate is therefore a ring along the outline,
   not a full slab).
3. Mechanical parts (wheels, side buttons, SmartShift button, LED) are placed on the surface found
   by ray casts, and sit in pockets cut into the body with clearance (no interpenetration).

To refine the model, change section_points() / params.SECTIONS for the shape and the part tables
in params.py for positions; keep part names and the 'nexo_part' property (export depends on them).
"""

import math

from mathutils import Vector

from . import geometry as g
from . import params
from .units import mm

SHAPE_KEYS = ("wr", "wl", "wing", "zt", "yc", "zw", "ch")


# ---------------------------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------------------------
def section_points(p):
    """14 semantic control points (y, z) of one cross-section, going from the bottom centre over
    the right side, the crest and down the left (thumb) side."""
    wr, wl, wing, zt, yc, zw, ch = (p[k] for k in SHAPE_KEYS)
    overhang_z = 0.76 * zt
    channel_z = zw + 0.45 * max(overhang_z - zw, 2.0)
    return [
        (0.0, 0.0),                                   # 0  bottom centre
        (-wr * 0.90, 0.0),                            # 1  bottom right
        (-wr, 0.10 * zt),                             # 2  right base flare
        (-wr * 0.97, 0.40 * zt),                      # 3  right flank
        (-wr * 0.78, 0.72 * zt),                      # 4  right upper flank
        (-wr * 0.40 + yc * 0.5, 0.94 * zt),           # 5  right shoulder
        (yc, zt),                                     # 6  crest
        (yc + wl * 0.45, 0.93 * zt),                  # 7  left shoulder
        (wl * 0.88, overhang_z),                      # 8  overhang above the thumb
        (wl * (0.88 - 0.09 * ch), channel_z),         # 9  thumb channel (concave)
        (wl * 0.90 + wing * 0.55, zw),                # 10 thumb-rest top
        (wl + wing, zw * 0.55),                       # 11 thumb-rest edge
        (wl * 0.96 + wing * 0.95, 0.0),               # 12 bottom left
        (wl * 0.40, 0.0),                             # 13 bottom left-centre
    ]


def shape_at():
    """s (0 rear .. 1 front) -> interpolated section parameters."""
    keys = params.SECTIONS
    s_values = [k["s"] for k in keys]
    curves = {name: g.monotone_cubic(s_values, [k[name] for k in keys]) for name in SHAPE_KEYS}
    return lambda s: {name: curve(s) for name, curve in curves.items()}


def _ring(x, section):
    points = g.catmull_rom_closed(section_points(section), params.SAMPLES_PER_SEGMENT)
    return x, [(y, max(0.0, z)) for y, z in points]


def _dome(ring, direction, length):
    """Close one end with rings shrinking towards the section centroid (rounded end cap)."""
    x, points = ring
    cy = sum(p[0] for p in points) / len(points)
    cz = sum(p[1] for p in points) / len(points)
    rings = []
    count = params.END_DOME_RINGS
    for k in range(1, count + 1):
        theta = 0.5 * math.pi * k / (count + 1)
        scale = math.cos(theta)
        rings.append((x + direction * length * math.sin(theta),
                      [(cy + (y - cy) * scale, cz + (z - cz) * scale) for y, z in points]))
    tip = (x + direction * length, cy, cz)
    return rings, tip


def build_shell(material):
    import bmesh

    length = params.SIZE_MM[0]
    at = shape_at()
    rings = [_ring(-length / 2 + length * s, at(s))
             for s in (i / (params.STATIONS - 1) for i in range(params.STATIONS))]
    rear_rings, rear_tip = _dome(rings[0], -1.0, params.END_DOME_MM["rear"])
    front_rings, front_tip = _dome(rings[-1], 1.0, params.END_DOME_MM["front"])
    ordered = list(reversed(rear_rings)) + rings + front_rings

    bm = bmesh.new()
    verts = [[bm.verts.new((mm(x), mm(y), mm(z))) for y, z in points] for x, points in ordered]
    count = len(verts[0])
    for a, b in zip(verts, verts[1:]):
        for k in range(count):
            j = (k + 1) % count
            bm.faces.new((a[k], a[j], b[j], b[k]))
    for ring, tip in ((verts[0], rear_tip), (verts[-1], front_tip)):
        centre = bm.verts.new(tuple(mm(v) for v in tip))
        for k in range(count):
            bm.faces.new((ring[k], ring[(k + 1) % count], centre))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    shell = g.object_from_bmesh("shell", bm, material)
    g.subdivide(shell, params.SUBSURF_LEVELS)
    _normalise(shell)
    return shell


def _normalise(obj):
    """Scale and move the shell so its bounding box is exactly SIZE_MM, centred on the origin in
    X/Y and standing on Z = 0."""
    from mathutils import Matrix

    lo, hi = g.world_bounds_mm([obj])
    size = params.SIZE_MM
    centre = Vector((mm((lo.x + hi.x) / 2), mm((lo.y + hi.y) / 2), mm(lo.z)))
    scale = [size[i] / (hi[i] - lo[i]) for i in range(3)]
    obj.data.transform(Matrix.Translation(-centre))
    obj.data.transform(Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))
    obj.data.update()


# ---------------------------------------------------------------------------------------------
# Surface queries on the untouched shell
# ---------------------------------------------------------------------------------------------
class Surface:
    def __init__(self, shell):
        self.tree = g.world_bvh([shell])
        half = params.SIZE_MM[0] / 2

        self.x_min, self.x_max = -half + 1.0, half - 1.0

    def top(self, x, y):
        """Height of the shell at (x, y), seen from above."""
        x = min(max(x, self.x_min), self.x_max)
        point, _normal = g.cast_mm(self.tree, (x, y, 200.0), (0.0, 0.0, -1.0))
        return point.z if point is not None else 0.0

    def down(self, x, y, z_start):
        """First surface below (x, y, z_start) — used for the thumb rest under the overhang."""
        point, normal = g.cast_mm(self.tree, (x, y, z_start), (0.0, 0.0, -1.0))
        return point, normal

    def left(self, x, z):
        """Point and normal on the left (thumb) side at (x, z), seen from +Y."""
        return g.cast_mm(self.tree, (x, 200.0, z), (0.0, -1.0, 0.0))


# ---------------------------------------------------------------------------------------------
# Cutters (millimetres; all carry the dark interior material)
# ---------------------------------------------------------------------------------------------
def _linspace(a, b, count):
    return [a + (b - a) * i / (count - 1) for i in range(count)]


def _top_button_polygons():
    cfg = params.TOP_BUTTONS
    seam = lambda y: cfg["palm_seam_x"] - cfg["palm_seam_curve"] * y * y  # noqa: E731
    half = cfg["channel_half"]
    left = [(90.0, half), (90.0, 90.0)] + [(seam(y), y) for y in _linspace(90.0, half, 40)]
    right = [(90.0, -90.0), (90.0, -half)] + [(seam(y), y) for y in _linspace(-half, -90.0, 40)]
    return left, right


def _seam(fractions, x):
    """Side seam height fraction at x: interpolates (palm seam, front end) linearly."""
    rear, front = fractions
    x0, x1 = params.TOP_BUTTONS["palm_seam_x"], params.SIZE_MM[0] / 2
    t = min(max((x - x0) / (x1 - x0), 0.0), 1.0)
    return rear + (front - rear) * t


def _make_cutters(surface, interior, gap=0.0):
    """All cutters. gap > 0 gives the grown versions subtracted from the body."""
    cfg = params.TOP_BUTTONS
    crest = lambda x: surface.top(x, 0.0)  # noqa: E731
    left, right = _top_button_polygons()
    if gap:
        left, right = g.offset_polygon(left, gap), g.offset_polygon(right, gap)
    cutters = {
        "base": _base_ring(surface, interior, gap),
        "left_button": g.prism("cut_left", left, lambda x, y: _seam(cfg["seam_left"], x) * crest(x) - gap,
                               120.0, interior),
        "right_button": g.prism("cut_right", right, lambda x, y: _seam(cfg["seam_right"], x) * crest(x) - gap,
                                120.0, interior),
        "gesture": _gesture_cutter(surface, interior, gap),
    }
    return cutters


def _footprint(surface, z=1.0, samples=144):
    """Outline of the shell at height z (mm), seen from outside, counter-clockwise."""
    outline = []
    for k in range(samples):
        angle = 2.0 * math.pi * k / samples
        direction = (math.cos(angle), math.sin(angle), 0.0)
        origin = (200.0 * direction[0], 200.0 * direction[1], z)
        point, _normal = g.cast_mm(surface.tree, origin, (-direction[0], -direction[1], 0.0))
        if point is not None:
            outline.append((point.x, point.y))
    return outline


def _base_ring(surface, interior, gap):
    """Base plate cutter: a band BASE_RING_MM wide along the outline, BASE_SLAB_MM tall. Inside the
    band the body goes down to the floor, so the seam is a groove, never a see-through slit."""
    outline = _footprint(surface)
    slab = g.prism("cut_base", [(-90, -90), (90, -90), (90, 90), (-90, 90)], -5.0,
                   params.BASE_SLAB_MM + gap, interior)
    hole = g.prism("cut_base_hole", g.offset_polygon(outline, -(params.BASE_RING_MM + gap)), -10.0, 10.0, interior)
    g.boolean(slab, "DIFFERENCE", hole)
    g.remove(hole)
    return slab


def _gesture_cutter(surface, interior, gap):
    """Front part of the thumb rest: from the channel wall outwards, a layer `depth` thick under
    the thumb-rest top."""
    cfg = params.GESTURE
    at = shape_at()
    length = params.SIZE_MM[0]
    xs = _linspace(cfg["x_rear"] - gap, cfg["x_front"] + gap, 14)
    inner, tops = [], {}
    for x in xs:
        zw = at((x + length / 2) / length)["zw"]
        wall, _n = surface.left(x, zw + 3.0)
        y_inner = (wall.y if wall is not None else 20.0) + 0.6 - gap
        top, _n = surface.down(x, y_inner + 2.5, zw + 6.0)
        tops[round(x, 4)] = top.z if top is not None else zw
        inner.append((x, y_inner))
    poly = inner + [(xs[-1], 90.0), (xs[0], 90.0)]

    def top_at(x, y):
        key = min(tops, key=lambda k: abs(k - x))
        return tops[key]

    return g.prism("cut_gesture", poly, lambda x, y: top_at(x, y) - cfg["depth"] - gap,
                   lambda x, y: top_at(x, y) + 2.5 + gap, interior)


def _make_pockets(surface, placements, interior):
    """Cavities for the mechanical parts (subtracted from the body and from every carved part)."""
    ch, cfg = params.CHANNEL, params.TOP_BUTTONS
    half = cfg["channel_half"]
    centre = lambda x, y: surface.top(x, 0.0)  # noqa: E731
    pockets = [
        g.prism("pocket_channel", [(ch["x_rear"], -half), (90.0, -half), (90.0, half), (ch["x_rear"], half)],
                lambda x, y: centre(x, y) - ch["depth"], 120.0, interior),
    ]
    w = params.WHEEL
    radius = w["diameter"] / 2 + ch["wheel_clearance"]
    wheel_z = placements["wheel"][0].z
    pockets.append(g.prism("pocket_wheel",
                           [(w["x"] - radius, -half), (w["x"] + radius, -half), (w["x"] + radius, half),
                            (w["x"] - radius, half)], wheel_z - radius, 120.0, interior))

    t = params.THUMBWHEEL
    pocket = g.cylinder("pocket_thumbwheel", t["diameter"] + 2 * t["clearance"], t["width"] + 2 * t["clearance"],
                        segments=96, material=interior)
    origin, basis = placements["thumbwheel"]
    g.place(pocket, origin, basis)
    pockets.append(pocket)

    s = params.SIDE_BUTTONS
    for name in ("back", "forward"):
        origin, basis = placements[name]
        c = s["clearance"]
        pocket = g.box("pocket_" + name, (s["length"] + 2 * c, s["height"] + 2 * c, s["depth"] + 2 * c + 4.0),
                       interior, radius_mm=s["radius"] + c)
        # Grow outwards only: the extra 4 mm stick out of the surface, never deeper into the body.
        g.place(pocket, origin + basis.col[2] * 2.0, basis)
        pockets.append(pocket)

    smart = params.SMARTSHIFT
    origin, basis = placements["smartshift"]
    c = s["clearance"]
    pocket = g.box("pocket_smartshift", (smart["length"] + 2 * c, smart["width"] + 2 * c, smart["height"] + 2 * c + 4.0),
                   interior, radius_mm=smart["radius"] + c)
    g.place(pocket, origin + basis.col[2] * 2.0, basis)
    pockets.append(pocket)

    origin, basis = placements["led"]
    pocket = g.cylinder("pocket_led", params.LED["diameter"] + 0.5, 3.0, segments=32, material=interior)
    g.place(pocket, origin, basis)
    pockets.append(pocket)

    u = params.USB
    usb = g.box("pocket_usb", (u["depth"] * 2, u["width"], u["height"]), interior, radius_mm=u["radius"])
    g.place(usb, Vector((params.SIZE_MM[0] / 2, 0.0, u["z"])), g.frame_from_normal((0.0, 0.0, 1.0)))
    pockets.append(usb)
    return pockets


# ---------------------------------------------------------------------------------------------
# Mechanical parts
# ---------------------------------------------------------------------------------------------
def _placements(surface):
    """Origin (mm, Vector) and basis (3×3, local Z = axle or outward normal) of each placed part."""
    w = params.WHEEL
    wheel_surface = surface.top(w["x"], 0.0)
    wheel_centre = Vector((w["x"], 0.0, wheel_surface + w["protrude"] - w["diameter"] / 2))
    placements = {"wheel": (wheel_centre, g.frame_from_normal((0.0, 1.0, 0.0)))}

    s = params.SMARTSHIFT
    top_z = surface.top(s["x"], 0.0)
    _point, normal = g.cast_mm(surface.tree, (s["x"], 0.0, 200.0), (0.0, 0.0, -1.0))
    basis = g.frame_from_normal(normal)
    placements["smartshift"] = (Vector((s["x"], 0.0, top_z - s["top_below_surface"] - s["height"] / 2)), basis)

    t = params.THUMBWHEEL
    point, normal = surface.left(t["x"], t["z"])
    axle = Vector((0.0, 0.0, 1.0)) - normal * normal.z
    axle.normalize()
    from mathutils import Matrix

    x_axis = normal.copy()
    basis = Matrix((x_axis, axle.cross(x_axis), axle)).transposed()
    placements["thumbwheel"] = (point - normal * (t["diameter"] / 2 - t["protrude"]), basis)

    b = params.SIDE_BUTTONS
    for name, x in (("back", b["back_x"]), ("forward", b["forward_x"])):
        point, normal = surface.left(x, b["z"])
        placements[name] = (point + normal * (b["protrude"] - b["depth"] / 2), g.frame_from_normal(normal))

    led = params.LED
    at = shape_at()
    length = params.SIZE_MM[0]
    zw = at((led["x"] + length / 2) / length)["zw"]
    point, normal = surface.left(led["x"], zw + led["z_above_wing"])
    placements["led"] = (point - normal * 1.2, g.frame_from_normal(normal))
    return placements


def _mechanical_parts(placements, mats):
    w = params.WHEEL
    wheel = g.ribbed_cylinder("wheel", w["diameter"], w["width"], w["ribs"], w["rib_depth"], w["chamfer"],
                              mats["steel"])
    t = params.THUMBWHEEL
    thumb = g.ribbed_cylinder("thumbwheel", t["diameter"], t["width"], t["ribs"], t["rib_depth"], t["chamfer"],
                              mats["steel"])
    s = params.SMARTSHIFT
    smart = g.box("smartshift", (s["length"], s["width"], s["height"]), mats["buttons"], radius_mm=s["radius"])
    b = params.SIDE_BUTTONS
    back = g.box("back", (b["length"], b["height"], b["depth"]), mats["buttons"], radius_mm=b["radius"])
    forward = g.box("forward", (b["length"], b["height"], b["depth"]), mats["buttons"], radius_mm=b["radius"])
    led = g.cylinder("led", params.LED["diameter"], 2.0, segments=32, material=mats["led"])
    parts = {"wheel": wheel, "thumbwheel": thumb, "smartshift": smart, "back": back, "forward": forward,
             "led": led}
    for name, obj in parts.items():
        origin, basis = placements[name]
        g.place(obj, origin, basis)
    return parts


# ---------------------------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------------------------
def build(mats):
    """Build the whole mouse. Returns {'objects': [...], 'parts': {part_id: obj}}."""
    import bpy

    from .scene import update

    shell = build_shell(mats["shell"])
    update()
    surface = Surface(shell)
    placements = _placements(surface)

    cutters = _make_cutters(surface, mats["interior"])
    grown = _make_cutters(surface, mats["interior"], gap=params.GAP_MM)
    pockets = _make_pockets(surface, placements, mats["interior"])
    update()

    pocket_set = bpy.data.collections.new("pockets")
    bpy.context.scene.collection.children.link(pocket_set)
    for pocket in pockets:
        bpy.context.scene.collection.objects.unlink(pocket)
        pocket_set.objects.link(pocket)
    body_cuts = bpy.data.collections.new("body_cuts")
    bpy.context.scene.collection.children.link(body_cuts)
    for obj in list(grown.values()) + pockets:
        body_cuts.objects.link(obj)

    carved = {}
    for name, cutter in cutters.items():
        part = g.duplicate(shell, name)
        g.boolean(part, "INTERSECT", cutter)
        g.boolean(part, "DIFFERENCE", pocket_set)
        carved[name] = part
    body = g.duplicate(shell, "body")
    g.boolean(body, "DIFFERENCE", body_cuts)

    for name in ("left_button", "right_button", "gesture"):
        _recolour(carved[name], mats["shell"], mats["buttons"])
    _recolour(carved["base"], mats["shell"], mats["base"])

    mechanical = _mechanical_parts(placements, mats)

    # Cutters and the untouched shell are construction-only.
    for obj in list(cutters.values()) + list(grown.values()) + pockets + [shell]:
        g.remove(obj)
    for collection in (pocket_set, body_cuts):
        bpy.data.collections.remove(collection)

    for obj in [body] + list(carved.values()):
        g.bevel(obj, 0.22, segments=2, angle_deg=40.0)
        g.shade(obj, 50.0)
    for obj in mechanical.values():
        g.shade(obj, 50.0)

    objects = [body] + list(carved.values()) + list(mechanical.values())
    for obj in objects:
        obj["nexo_part"] = obj.name
        obj["nexo_mouse"] = True
    parts = {pid: bpy.data.objects[pid] for pid, _cid, _label in params.PARTS}
    return {"objects": objects, "parts": parts}


def _recolour(obj, old, new):
    """Swap one material for another in obj (keeps the transferred 'interior' faces)."""
    for index, material in enumerate(obj.data.materials):
        if material == old:
            obj.data.materials[index] = new

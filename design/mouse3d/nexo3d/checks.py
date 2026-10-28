"""Automatic acceptance checks (G1 geometry; G4/G5 are computed by export)."""

import itertools

import bmesh
import bpy

from . import geometry as g
from . import params


def dimensions(objects):
    lo, hi = g.world_bounds_mm(objects)
    size = [round(hi[i] - lo[i], 3) for i in range(3)]
    ok = all(abs(size[i] - params.SIZE_MM[i]) <= params.SIZE_TOLERANCE_MM for i in range(3))
    return {"size_mm": size, "expected_mm": list(params.SIZE_MM), "min_z_mm": round(lo.z, 3), "ok": ok}


def non_manifold(objects):
    """Edges that are not shared by exactly two faces (holes or fins) per object."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    counts = {}
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        counts[obj.name] = sum(1 for edge in bm.edges if not edge.is_manifold)
        bm.free()
        evaluated.to_mesh_clear()
    return {"edges": counts, "ok": not any(counts.values())}


def interpenetration(objects):
    """Pairs of parts whose surfaces cross each other (they should only meet across a gap)."""
    trees = {obj.name: g.world_bvh([obj]) for obj in objects}
    crossings = {}
    for a, b in itertools.combinations(sorted(trees), 2):
        count = len(trees[a].overlap(trees[b]))
        if count:
            crossings[a + " × " + b] = count
    return {"pairs": crossings, "ok": not crossings}


def geometry(objects):
    result = {"dimensions": dimensions(objects), "manifold": non_manifold(objects),
              "interpenetration": interpenetration(objects)}
    result["ok"] = all(item["ok"] for item in result.values())
    return result

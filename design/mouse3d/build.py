"""Nexo device renders — single entry point.

    blender -b --factory-startup --python-exit-code 1 --python design/mouse3d/build.py -- <task> [options]

Tasks
    check-env   Blender version, compute device and the API names this pipeline relies on (G0)
    selftest    unit tests of the maths and I/O (G0)
    checks      build the model and run the geometry checks (G1)
    preview     quick renders of the app and hero views, both themes -> out/preview/
    fit         silhouettes of the model vs. the owner's photos -> out/fit/ (G2)
    final       final-quality beauty renders only -> out/final/ (look review)
    export      everything in the output contract -> export/mx-master-3s/ + all gates (G1, G4, G5)

Every task rebuilds the scene from code: nothing depends on a hand-edited .blend.
"""

import argparse
import pathlib
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
# Windows consoles may not be UTF-8: never crash on an accented log line.
sys.stdout.reconfigure(errors="replace")
sys.stderr.reconfigure(errors="replace")

import bpy  # noqa: E402

from nexo3d import cameras, checks, export, fit, lights, materials, model, params, scene, selftest  # noqa: E402

REQUIRED_VERSION = (5, 2, 3)
OUT = ROOT / "out"


def log(message):
    print("[nexo3d] " + message, flush=True)


def fail(message):
    log("FALHOU: " + message)
    raise SystemExit(1)


# ---------------------------------------------------------------------------------------------
def task_check_env(args):
    problems = []
    version = tuple(bpy.app.version)
    log("Blender %s (Python %s)" % (bpy.app.version_string, sys.version.split()[0]))
    if version != REQUIRED_VERSION:
        problems.append("Blender %s; o pipeline foi verificado no %s" % (version, REQUIRED_VERSION))
    scene.reset()
    sc = bpy.context.scene
    probes = [
        (sc.render, "engine", "CYCLES"),
        (sc.view_settings, "view_transform", "AgX"),
        (sc.view_settings, "look", "AgX - Base Contrast"),
        (sc.view_settings, "look", "AgX - Medium High Contrast"),
        (sc.view_settings, "view_transform", "Khronos PBR Neutral"),
        (sc.view_settings, "view_transform", "Standard"),
        (sc.cycles, "denoiser", "OPENIMAGEDENOISE"),
    ]
    for owner, attribute, value in probes:
        try:
            setattr(owner, attribute, value)
        except (TypeError, ValueError) as error:
            problems.append("%s=%r recusado: %s" % (attribute, value, error))
    device = scene.setup_device(args.device)
    log("dispositivo de render: %s %s" % (device["kind"], device["devices"]))
    if args.device == "auto" and device["kind"] == "CPU":
        log("aviso: nenhuma GPU OptiX/CUDA encontrada; renders vão rodar na CPU (lento)")
    for folder in (OUT, ROOT / params.EXPORT_DIR):
        folder.mkdir(parents=True, exist_ok=True)
        probe = folder / ".write-test"
        probe.write_text("ok")
        probe.unlink()
    if problems:
        fail("; ".join(problems))
    log("check-env OK")


def task_selftest(args):
    results = selftest.run(OUT / "selftest")
    for name, ok, detail in results:
        log(("ok    " if ok else "FALHA ") + name + ("" if ok else "  " + repr(detail)))
    failed = [r for r in results if not r[1]]
    if failed:
        fail("%d de %d testes falharam" % (len(failed), len(results)))
    log("selftest OK (%d testes)" % len(results))


# ---------------------------------------------------------------------------------------------
def build_mouse(args):
    started = time.time()
    scene.reset()
    device = scene.setup_device(args.device)
    mats = materials.create_all()
    built = model.build(mats)
    log("modelo montado em %.1f s (%d objetos); render em %s" % (time.time() - started, len(built["objects"]),
                                                                  device["kind"]))
    return built, mats


def run_geometry_checks(built):
    result = checks.geometry(built["objects"])
    log("G1 dimensões %s mm (esperado %s) -> %s" % (result["dimensions"]["size_mm"], list(params.SIZE_MM),
                                                     "ok" if result["dimensions"]["ok"] else "FORA"))
    bad = {k: v for k, v in result["manifold"]["edges"].items() if v}
    log("G1 arestas não-manifold: %s" % (bad or "nenhuma"))
    log("G1 interpenetração: %s" % (result["interpenetration"]["pairs"] or "nenhuma"))
    return result


def themes(args):
    return ("light", "dark") if args.theme == "both" else (args.theme,)


def render_views(built, args, quality, folder, hero=True):
    folder.mkdir(parents=True, exist_ok=True)
    objects = built["objects"]
    written = []
    hero = hero and args.views in ("app+hero", "hero")
    lights.add_shadow_catcher()
    cameras.perspective("app", objects)
    for theme in themes(args) if args.views != "hero" else ():
        path = folder / ("app-side-%s.png" % theme)
        export.render_beauty(theme, path, quality, transparent=True, samples=args.samples)
        written.append(path)
    if hero:
        lights.remove_floors()
        cameras.remove_cameras()
        camera = cameras.perspective("hero", objects)
        for theme in themes(args):
            backdrop = lights.add_backdrop(theme, params.CAMERAS["hero"]["azimuth"])
            path = folder / ("hero-%s.png" % theme)
            export.render_beauty(theme, path, quality, transparent=False, hero=True, samples=args.samples)
            written.append(path)
            lights.remove_floors()
        del camera
    for path in written:
        log("render: " + str(path.relative_to(ROOT)))
    return written


def task_checks(args):
    built, _mats = build_mouse(args)
    if not run_geometry_checks(built)["ok"]:
        fail("G1 não passou")
    log("checks OK")


def task_preview(args):
    built, _mats = build_mouse(args)
    render_views(built, args, "preview", OUT / "preview")
    save_blend(args)


def task_final(args):
    built, _mats = build_mouse(args)
    render_views(built, args, "final", OUT / "final")
    save_blend(args)


def task_fit(args):
    built, _mats = build_mouse(args)
    results = fit.run(built["objects"], pathlib.Path(args.photos), OUT / "fit")
    export.write_json(OUT / "fit" / "report.json", results)
    measured = 0
    below = []
    for view, result in results.items():
        if "iou" in result:
            measured += 1
            log("G2 %-5s IoU %.4f (mínimo %.2f, foto girada %d×90°) %s" % (
                view, result["iou"], result["min"], result["photo_quarter_turns"], result["status"]))
            if result["status"] != "ok":
                below.append(view)
        else:
            log("G2 %-5s %s" % (view, result["status"]))
    log("diferenças em out/fit/diff-<vista>.png (vermelho = só na foto, azul = só no modelo)")
    if measured == 0:
        fail("nenhuma foto encontrada em " + args.photos)
    if below:
        fail("G2 abaixo do mínimo em: " + ", ".join(below))
    log("fit OK")


def task_export(args):
    args.views = "app+hero"
    built, mats = build_mouse(args)
    geometry = run_geometry_checks(built)
    target = ROOT / params.EXPORT_DIR
    masks_dir = target / "masks"
    masks_dir.mkdir(parents=True, exist_ok=True)
    (target / "1x").mkdir(parents=True, exist_ok=True)
    work = OUT / "export"
    work.mkdir(parents=True, exist_ok=True)

    written = render_views(built, args, "final", target, hero=True)
    for path in written:
        if path.name.startswith("app-side-"):
            export.write_png(target / "1x" / path.name, export.downscale_half(export.read_image(path)))

    cameras.remove_cameras()
    lights.remove_floors()
    lights.add_shadow_catcher()
    camera = cameras.perspective("app", built["objects"])
    for part_id, _cid, _label in params.PARTS:
        export.render_mask(built["objects"], built["parts"][part_id], masks_dir / (part_id + ".png"),
                           mats["mask_white"], args.mask_samples)
    export.render_mask(built["objects"], None, work / "mouse.png", mats["mask_white"], args.mask_samples)
    hotspots, problems = export.build_hotspots(camera, built["parts"], masks_dir, "app")
    problems += export.validate_hotspots(hotspots)
    export.write_json(target / "hotspots.json", hotspots)
    if hotspots["parts"]:
        overlay = export.hotspot_overlay(target / "app-side-dark.png" if "dark" in themes(args)
                                         else target / "app-side-light.png", hotspots, work / "hotspots-overlay.png")
        log("conferência dos pontos clicáveis: " + str(overlay.relative_to(ROOT)))

    gates = {"G1": geometry["ok"], "G5": not problems}
    metrics = {}
    if "light" in themes(args):
        metrics = export.exposure_metrics(target / "app-side-light.png", work / "mouse.png")
        low, high = params.EXPOSURE_TARGET["mean_srgb"]
        gates["G4"] = (metrics["mean_srgb"] is not None and low <= metrics["mean_srgb"] <= high
                       and metrics["clipped_fraction"] <= params.EXPOSURE_TARGET["max_clipped_fraction"])
        log("G4 média sRGB %.3f (alvo %.2f–%.2f), estourados %.3f%%" % (
            metrics["mean_srgb"], low, high, 100 * metrics["clipped_fraction"]))
    for problem in problems:
        log("G5 problema: " + problem)
    report = {"gates": gates, "geometry": geometry, "exposure": metrics, "hotspot_problems": problems,
              "blender": bpy.app.version_string, "samples_override": args.samples}
    export.write_json(work / "report.json", report)
    log("portões: " + ", ".join("%s=%s" % (k, "ok" if v else "FALHOU") for k, v in gates.items()))
    save_blend(args)
    if not all(gates.values()):
        fail("algum portão não passou (detalhes em out/export/report.json)")
    log("export OK -> " + str(target.relative_to(ROOT)))


def save_blend(args):
    if args.save_blend:
        path = OUT / "mouse.blend"
        bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
        log("cena salva em " + str(path.relative_to(ROOT)))


# ---------------------------------------------------------------------------------------------
TASKS = {
    "check-env": task_check_env, "selftest": task_selftest, "checks": task_checks, "preview": task_preview,
    "fit": task_fit, "final": task_final, "export": task_export,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="build.py", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("task", choices=sorted(TASKS))
    parser.add_argument("--device", choices=("auto", "cpu"), default="auto")
    parser.add_argument("--theme", choices=("light", "dark", "both"), default="both")
    parser.add_argument("--views", choices=("app+hero", "app", "hero"), default="app+hero",
                        help="vistas do preview/final (o export sempre gera todas)")
    parser.add_argument("--samples", type=int, default=None, help="força o nº de amostras dos renders")
    parser.add_argument("--mask-samples", type=int, default=None, help="força o nº de amostras das máscaras")
    parser.add_argument("--photos", default=str(ROOT / "reference"), help="pasta com top/left/right/front/rear.jpg")
    parser.add_argument("--save-blend", action="store_true", help="salva out/mouse.blend para inspeção")
    args = parser.parse_args(argv)
    started = time.time()
    TASKS[args.task](args)
    log("tempo total %.1f s" % (time.time() - started))


main()

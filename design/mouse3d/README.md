# mouse3d — device renders for Nexo

Procedural Blender pipeline that builds an **original** 3D model of the MX Master 3S (no brand marks,
no manufacturer assets) and renders the images the app shows on the device stage, plus a mask and a
clickable anchor for every button.

Everything is generated from code: run `build.py`, never hand-edit a `.blend`.

## Requirements

* **Blender 5.2.3 LTS** (pinned; `check-env` refuses other versions). Official builds and SHA-256 sums:
  <https://download.blender.org/release/Blender5.2/>
  * Linux: `blender-5.2.3-linux-x64.tar.xz` — `78486c018b4443efe5e75ab54c290ed8c15abafd249b862c2c9ce2530a918eec`
  * Windows: `blender-5.2.3-windows-x64.zip` — `723f08a4401502561eb763cdeacf8745b31e5f3f154d287d3830d97cf75dc2fb`
* An NVIDIA RTX GPU is used automatically (OptiX, then CUDA); without one the renders fall back to the CPU
  (works, but a full export takes a long time).
* Nothing else: the pipeline only uses Blender's bundled Python 3.13 and numpy.

## Usage

```bash
design/mouse3d/run.sh <task> [options]                       # Linux / Git Bash
powershell -NoProfile -ExecutionPolicy Bypass -File design\mouse3d\run.ps1 <task> [options]   # Windows
# both expand to:
blender -b --factory-startup --python-exit-code 1 --python <abs>/design/mouse3d/build.py -- <task> [options]
```

Blender is looked up in `NEXO_BLENDER`, then in `~/.local/opt/blender-5.2.3/` (Linux) or
`%LOCALAPPDATA%\Programs\blender-5.2.3-windows-x64\` (Windows, see `install-blender.ps1`).

| Task | What it does | Output |
|---|---|---|
| `check-env` | Blender version, render device, every API name the pipeline relies on (gate G0) | log |
| `selftest` | unit tests of the maths and image I/O (G0) | log |
| `checks` | builds the model; size, closed meshes, no interpenetration (G1) | log |
| `preview` | quick renders, app and hero views, both themes | `out/preview/` |
| `fit` | silhouettes of the model vs. the owner's photos, IoU per view (G2) | `out/fit/` |
| `final` | final-quality beauty renders only, for look review | `out/final/` |
| `export` | the full output contract and gates G1, G4, G5 | `export/mx-master-3s/` |

Options: `--device auto|cpu`, `--theme light|dark|both`, `--views app+hero|app|hero`,
`--samples N`, `--mask-samples N`, `--photos DIR` (default `reference/`), `--save-blend`
(writes `out/mouse.blend` for inspection).

A failing gate exits with status 1 and prints `FALHOU: …`.

## Output contract (`export/mx-master-3s/`)

| File | Content |
|---|---|
| `app-side-light.png`, `app-side-dark.png` | 2048×1280 RGBA, transparent background with contact shadow; 3/4 view of the left (thumb) side, front of the mouse on the left |
| `1x/app-side-*.png` | the same at 1024×640 |
| `masks/<part>.png` | 2048×1280; RGB white, alpha = the *visible* coverage of that part |
| `hotspots.json` | per part: `id`, HID++ `cid`, label, `anchor` [u, v], `bbox`, mask path; coordinates normalised with the origin at the **top-left** |
| `hero-light.png`, `hero-dark.png` | 3840×2160 with a studio backdrop, for the README and portfolio |

Parts: `left_button` 0x50, `right_button` 0x51, `wheel` 0x52, `back` 0x53, `forward` 0x56,
`gesture` 0xc3, `smartshift` 0xc4, `thumbwheel`.

## Layout

```
build.py            entry point (tasks above)
run.sh / run.ps1    run build.py with the pinned Blender (Linux or Git Bash / Windows PowerShell)
install-blender.ps1 installs Blender 5.2.3 on Windows after checking its SHA-256
PROMPT-desktop.md   brief for the detailed modelling session on the GPU desktop (pt-BR)
nexo3d/params.py    every number: size, shell sections, parts, materials, lights, cameras, quality
nexo3d/model.py     shell (loft of semantic cross-sections) and parts (exact booleans, real seam gaps)
nexo3d/geometry.py  mesh builders, booleans, bevels, smoothing, ray casts
nexo3d/materials.py soft-touch plastic, machined steel, interior, LED
nexo3d/lights.py    studio rigs, gradient world, shadow catcher, cyclorama
nexo3d/cameras.py   auto-framed perspective cameras, orthographic views, pixel rays
nexo3d/export.py    renders, masks, hotspots.json, exposure metrics, PNG I/O
nexo3d/fit.py       photo silhouettes, IoU and diff images
nexo3d/checks.py    geometry gates
nexo3d/selftest.py  unit tests run inside Blender
reference/          the owner's photos (git-ignored: they show the brand)
out/                previews, diffs, reports (git-ignored)
```

## Shell sections

`params.SECTIONS` lists key cross-sections along the length (`s` 0 = rear end, 1 = front end), interpolated
with a monotone cubic. `model.section_points()` turns each one into the same 14 semantic control points, so
point *k* is always the same feature and the lofted surface never twists:

| Point | Feature | Driven by |
|---|---|---|
| 0 | bottom centre | — |
| 1–2 | bottom and base flare, right side | `wr` |
| 3–5 | right flank and shoulder | `wr`, `zt`, `yc` |
| 6 | crest | `zt`, `yc` |
| 7–8 | left shoulder and overhang above the thumb | `wl`, `zt` |
| 9 | thumb channel (concave) | `ch`, `zw`, `wl` |
| 10–11 | thumb-rest top and edge | `wing`, `zw` |
| 12–13 | bottom, left side | `wl`, `wing` |

The shell is always rescaled to the official size, so these values only shape it. New features need new key
sections or new semantic points — every section must keep the same number of points, in the same order.
Every seam gap must end against solid body (a gap crossing the whole mouse shows the background through it;
that is why the base plate is a ring along the outline).

## Coordinates and units

Millimetres in `params.py`, metres in the scene (real scale, so lights and depth of field behave
physically). +X is the front of the mouse, +Y its left (thumb) side, +Z up; the origin is the centre
of the base. Camera azimuth is measured from +X towards +Y.

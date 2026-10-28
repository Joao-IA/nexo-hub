"""Every number that shapes the render lives here: size, shell sections, parts, materials, lights,
cameras, quality presets and output contract.

Conventions
-----------
* Geometry in millimetres; +X = front of the mouse, +Y = left side (thumb), +Z = up; origin at the
  centre of the base footprint. The shell is rescaled to ``SIZE_MM`` after it is built, so the
  section table below only controls the *shape*.
* Colours are sRGB hex (converted to scene-linear by ``units.hex_rgba``).
* Angles in degrees. Camera azimuth is measured from +X (front) towards +Y (left side): 90 = pure
  left-side view; the app camera sits on the +Y side, so the front of the mouse is on the image left.

The values for the provisional model are estimates. The detailed model is calibrated against the
owner's photos (``fit`` task) — see PROMPT-desktop.md.
"""

# Official MX Master 3S dimensions (Logitech spec sheet): length (X) × width (Y) × height (Z).
SIZE_MM = (124.9, 84.3, 51.0)
SIZE_TOLERANCE_MM = 0.3

# ---------------------------------------------------------------------------------------------
# Shell: key cross-sections, interpolated along the length with a monotone cubic.
# s: 0 = rear end, 1 = front end. All widths/heights are relative (rescaled to SIZE_MM later).
#   wr / wl : right / left half-width of the body at the base
#   wing    : extra width of the thumb rest beyond wl
#   zt      : crest height;  yc: crest offset (+ = towards the left/thumb side)
#   zw      : thumb-rest (wing) top height;  ch: thumb-channel inset, 0 (flat) .. 1 (deep)
# ---------------------------------------------------------------------------------------------
SECTIONS = [
    dict(s=0.00, wr=24.0, wl=22.0, wing=0.0, zt=26.0, yc=1.0, zw=7.0, ch=0.00),
    dict(s=0.07, wr=31.0, wl=28.0, wing=0.0, zt=38.0, yc=2.5, zw=9.0, ch=0.05),
    dict(s=0.22, wr=35.5, wl=31.0, wing=2.5, zt=48.0, yc=4.0, zw=12.0, ch=0.30),
    dict(s=0.40, wr=36.5, wl=30.0, wing=8.5, zt=51.0, yc=4.5, zw=14.0, ch=0.70),
    dict(s=0.58, wr=35.5, wl=27.5, wing=12.5, zt=47.0, yc=3.0, zw=15.5, ch=0.95),
    dict(s=0.76, wr=33.0, wl=26.0, wing=11.0, zt=39.5, yc=1.5, zw=15.0, ch=0.80),
    dict(s=0.90, wr=30.5, wl=25.0, wing=5.0, zt=33.0, yc=0.5, zw=12.0, ch=0.35),
    dict(s=1.00, wr=27.0, wl=23.0, wing=0.0, zt=28.0, yc=0.0, zw=9.0, ch=0.00),
]
STATIONS = 56                    # cross-sections sampled along the length
SAMPLES_PER_SEGMENT = 5          # points between two semantic control points of a section
END_DOME_MM = {"rear": 7.0, "front": 3.5}   # rounding length of the closed ends
END_DOME_RINGS = 5
SUBSURF_LEVELS = 2

# ---------------------------------------------------------------------------------------------
# Parts (final millimetre coordinates, after the shell is rescaled)
# ---------------------------------------------------------------------------------------------
GAP_MM = 0.45                    # visible seam between separate plastic parts
BASE_SLAB_MM = 2.2               # dark base plate height
BASE_RING_MM = 3.0               # width of the visible base band along the outline

# Interactive parts: id, HID++ control id (None = not a button), label used in the app (pt-BR).
PARTS = [
    ("left_button", "0x50", "Clique esquerdo"),
    ("right_button", "0x51", "Clique direito"),
    ("wheel", "0x52", "Roda / clique do meio"),
    ("back", "0x53", "Voltar"),
    ("forward", "0x56", "Avançar"),
    ("gesture", "0xc3", "Botão de gestos"),
    ("smartshift", "0xc4", "Botão SmartShift"),
    ("thumbwheel", None, "Roda lateral"),
]

TOP_BUTTONS = dict(
    channel_half=4.7,            # half width of the channel between the buttons (wheel lives there)
    palm_seam_x=-7.0,            # where the buttons end, at the centre line
    palm_seam_curve=0.0018,      # the seam bends backwards towards the sides: x = x0 - c * y²
    # Side seam height as a fraction of the local crest height, (at the palm seam, at the front):
    # the seam slopes down towards the front like the real button edges.
    seam_left=(0.84, 0.66),
    seam_right=(0.80, 0.48),
)
WHEEL = dict(x=21.0, diameter=24.0, width=7.4, protrude=4.6, ribs=96, rib_depth=0.30, chamfer=0.6)
CHANNEL = dict(x_rear=-3.5, depth=3.2, wheel_clearance=0.9)
SMARTSHIFT = dict(x=2.5, length=7.0, width=5.8, height=3.2, top_below_surface=0.9, radius=1.2)
THUMBWHEEL = dict(x=5.5, z=29.5, diameter=21.0, width=7.2, protrude=2.6, ribs=60, rib_depth=0.32,
                  chamfer=0.6, clearance=0.7)
SIDE_BUTTONS = dict(z=21.5, length=13.5, height=4.6, depth=3.4, protrude=1.0, radius=1.6,
                    forward_x=12.5, back_x=-2.5, clearance=0.45)
GESTURE = dict(x_rear=9.0, x_front=37.0, depth=1.8)
USB = dict(z=11.0, width=9.2, height=3.4, depth=5.0, radius=1.2)
LED = dict(x=39.0, z_above_wing=3.5, diameter=1.6)

# ---------------------------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------------------------
COLORS = {
    "shell": "#3a3e42",          # graphite soft-touch
    "buttons": "#3c4044",
    "base": "#1c1e20",
    "interior": "#0b0c0d",       # walls of seams, channel and pockets
    "steel": "#c8ccd0",          # machined wheels (owner asked for silver on both wheels)
    "led": "#46e09a",
    "backdrop_dark": "#0e1316",
    "backdrop_light": "#e6eaed",
    "accent": "#3fc9d6",         # Nexo cyan (hero rim light in the dark theme)
}
MATERIALS = {
    "shell": dict(roughness=0.50, sheen=0.15, grain_scale=6500.0, grain_strength=0.06),
    "buttons": dict(roughness=0.44, sheen=0.10, grain_scale=6500.0, grain_strength=0.05),
    "base": dict(roughness=0.75),
    "interior": dict(roughness=0.90),
    "steel": dict(roughness=0.22, anisotropic=0.55),
    "led": dict(strength=3.0),
}

# ---------------------------------------------------------------------------------------------
# Lights and world. Positions are spherical around the mouse centre: (azimuth, elevation, metres).
# ---------------------------------------------------------------------------------------------
TARGET_MM = (0.0, 0.0, 22.0)
# Energies are physical (watts at real scale). Rule of thumb used to size them: an area light of P
# watts and area A at distance d gives irradiance E ≈ P / (π·A) · A / d² = P / (π·d²); graphite
# (albedo ≈ 0.04) then shows radiance ≈ 0.04·E/π. Target ≈ 0.04–0.05 linear (sRGB ≈ 0.2) for the
# key-lit side, i.e. E ≈ 3.5 W/m² ⇒ P ≈ 3.5 W at 0.55 m; fill/rim/world add the rest, so the key
# ends lower. The G4 gate measures the result.
THEMES = {
    "light": dict(
        view="AgX", look="AgX - Base Contrast", exposure=0.0,
        world=dict(top="#ffffff", bottom="#5b6066", strength=0.14, glossy_boost=4.0),
        lights=[
            dict(name="key", az=40, el=42, dist=0.55, size=(0.45, 0.30), energy=0.95, color="#fff8f0"),
            dict(name="fill", az=-70, el=25, dist=0.60, size=(0.70, 0.50), energy=0.34, color="#f0f6ff"),
            dict(name="rim", az=200, el=38, dist=0.50, size=(0.70, 0.06), energy=1.7, color="#ffffff"),
            dict(name="top", az=90, el=85, dist=0.55, size=(0.60, 0.60), energy=0.47, color="#ffffff"),
        ],
    ),
    "dark": dict(
        view="AgX", look="AgX - Medium High Contrast", exposure=0.0,
        world=dict(top="#cfd8de", bottom="#1a1f24", strength=0.10, glossy_boost=8.0),
        lights=[
            dict(name="key", az=40, el=42, dist=0.55, size=(0.45, 0.30), energy=1.05, color="#fff8f0"),
            dict(name="fill", az=-70, el=25, dist=0.60, size=(0.70, 0.50), energy=0.2, color="#e8f2ff"),
            dict(name="rim", az=200, el=38, dist=0.50, size=(0.70, 0.06), energy=3.5, color="#ffffff"),
            dict(name="top", az=90, el=85, dist=0.55, size=(0.60, 0.60), energy=0.4, color="#ffffff"),
        ],
    ),
}
HERO_ACCENT_LIGHT = dict(name="accent", az=150, el=20, dist=0.45, size=(0.50, 0.08), energy=3.0)

# ---------------------------------------------------------------------------------------------
# Cameras. fill = fraction of the image width taken by the mouse; center = where the mouse's
# bounding box centre lands, in normalised image coordinates (origin top-left).
# ---------------------------------------------------------------------------------------------
CAMERAS = {
    "app": dict(azimuth=72.0, elevation=27.0, lens=85.0, fill=0.80, center=(0.5, 0.47),
                resolution=(2048, 1280), dof_fstop=None),
    "hero": dict(azimuth=56.0, elevation=15.0, lens=70.0, fill=0.56, center=(0.5, 0.55),
                 resolution=(3840, 2160), dof_fstop=5.6),
}
# Orthographic views for silhouette fitting: camera direction (from the mouse towards the camera).
ORTHO_VIEWS = {
    "top": ((0.0, 0.0, 1.0), (0.0, 1.0, 0.0)),     # (direction, up)
    "left": ((0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),
    "right": ((0.0, -1.0, 0.0), (0.0, 0.0, 1.0)),
    "front": ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
    "rear": ((-1.0, 0.0, 0.0), (0.0, 0.0, 1.0)),
}
# Size of each silhouette in millimetres (image width, image height) for the normalised comparison.
ORTHO_EXTENT_MM = {
    "top": (SIZE_MM[0], SIZE_MM[1]),
    "left": (SIZE_MM[0], SIZE_MM[2]),
    "right": (SIZE_MM[0], SIZE_MM[2]),
    "front": (SIZE_MM[1], SIZE_MM[2]),
    "rear": (SIZE_MM[1], SIZE_MM[2]),
}
FIT_PIXELS_PER_MM = 4.0
FIT_MIN_IOU = {"top": 0.96, "left": 0.95, "right": 0.95, "front": 0.94, "rear": 0.94}

# ---------------------------------------------------------------------------------------------
# Quality presets and output contract
# ---------------------------------------------------------------------------------------------
QUALITY = {
    "preview": dict(samples=64, threshold=0.02, scale=50, compression=15),
    "final": dict(samples=768, threshold=0.004, scale=100, compression=90),
}
MASK_SAMPLES = 32
EXPORT_DIR = "export/mx-master-3s"
EXPOSURE_TARGET = dict(mean_srgb=(0.18, 0.30), max_clipped_fraction=0.005)

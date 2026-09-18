"""Deterministic sprite generator for the prototype's art (decision D99).

WHY THIS EXISTS
---------------
D99 originally set prototype art as AI-generated sprite sheets. That route was
unavailable - the configured image service requires a paid plan this account
does not hold, and zero generations were submitted. Rather than stall the
prototype, art is generated here instead, which turned out to suit this project
better than the original choice:

  * The master does not ask for pretty art. It asks for a readability
    hierarchy - a silhouette class, a reserved colour per entity type, and a
    minimum on-screen size - so that a Tower Seeker, a Player Hunter and an
    Opportunist stay tellable apart at a glance with three hundred of them on
    screen. That is a constraint a generator can satisfy by construction and a
    stock pack or an image model can only be steered toward.
  * The art is reproducible from source and reviewable as a diff, instead of
    being an opaque binary drop.
  * There is no third-party licence to track.

Every sprite is written to `assets/sprites/`. Nothing references these paths
from code: they are fields on the `.tres` data contracts, so replacing this art
with commissioned or purchased work later is a data edit, not a code change.

READABILITY, WHICH IS THE ACTUAL SPEC
-------------------------------------
Silhouette carries more than colour does under load, and colour-blind players
get no help from hue at all. So each entity gets a distinct *shape language*
first and a reserved hue second:

  Player          circle with shoulders, upright        cyan
  Tower           broad octagon, radial plates          steel blue
  Tower Seeker    broad blunt wedge, heavy and wide     amber
  Player Hunter   narrow sharp arrowhead, elongated     crimson
  Opportunist     round blob with trailing tendrils     violet

A silhouette test should be able to knock the colour out entirely and still
tell these apart. `--silhouette` renders exactly that, for checking.

Run:  python tools/art/generate_sprites.py
      python tools/art/generate_sprites.py --silhouette   (flat black shapes)
"""

from __future__ import annotations

import argparse
import math
import os
from typing import Sequence

from PIL import Image, ImageDraw, ImageFilter

# Supersample factor. Everything is drawn at SS times the target size and then
# reduced with LANCZOS, which is what gives clean edges without hand-rolling
# anti-aliasing.
SS = 4

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")

# Reserved colours. These are art constants, not gameplay numbers, so they live
# here rather than in the Provisional Values Register - the Register owns values
# that change how the game plays. If a colour ever becomes load-bearing for a
# rule (a hazard the player must identify by hue), it moves to the Register.
CYAN = (96, 222, 255)
STEEL = (122, 158, 196)
AMBER = (255, 168, 56)
CRIMSON = (232, 62, 74)
VIOLET = (178, 112, 255)
LIME = (150, 245, 96)
INK = (14, 17, 24)


def _shade(c: Sequence[int], f: float) -> tuple:
    """Scale a colour toward black (f<1) or white (f>1), clamped."""
    if f <= 1.0:
        return tuple(int(v * f) for v in c[:3])
    return tuple(int(v + (255 - v) * (f - 1.0)) for v in c[:3])


def _canvas(size: int) -> tuple:
    img = Image.new("RGBA", (size * SS, size * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _finish(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def _outlined(draw: ImageDraw.ImageDraw, pts, fill, outline_w: int) -> None:
    """Filled polygon with a dark keyline, which is what makes a sprite read
    against a busy floor."""
    draw.polygon(pts, fill=fill, outline=INK, width=outline_w)


def _rim(img: Image.Image, pts, colour, width: int) -> None:
    """A soft light along the top edge. Cheap, and it stops flat shapes looking
    like flat shapes."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.line(list(pts) + [pts[0]], fill=colour + (170,), width=width, joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(width * 0.6))
    # Keep the rim inside the silhouette.
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.alpha_composite(Image.composite(layer, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))


def _ngon(cx: float, cy: float, r: float, n: int, rot: float = 0.0, squash: float = 1.0):
    return [
        (cx + math.cos(rot + i * math.tau / n) * r,
         cy + math.sin(rot + i * math.tau / n) * r * squash)
        for i in range(n)
    ]


# --------------------------------------------------------------------------
# Entities. Each returns a finished RGBA image at `size`.
# --------------------------------------------------------------------------

def player(size: int = 64, flat: bool = False) -> Image.Image:
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    body = INK if flat else CYAN
    # Shoulders: a wide rounded mass, so the silhouette is not a bare circle.
    d.ellipse([c - s * 0.30, c - s * 0.20, c + s * 0.30, c + s * 0.30],
              fill=_shade(body, 0.78) if not flat else INK, outline=INK, width=int(s * 0.035))
    # Head / torso.
    d.ellipse([c - s * 0.19, c - s * 0.34, c + s * 0.19, c + s * 0.06],
              fill=body, outline=INK, width=int(s * 0.035))
    if not flat:
        # Visor, reading as a facing direction.
        d.ellipse([c - s * 0.11, c - s * 0.27, c + s * 0.11, c - s * 0.11],
                  fill=_shade(CYAN, 1.5))
        _rim(img, _ngon(c, c - s * 0.14, s * 0.19, 24), _shade(CYAN, 1.7), int(s * 0.02))
    return _finish(img, size)


def tower(size: int = 256, flat: bool = False) -> Image.Image:
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    base = INK if flat else STEEL
    # Wide octagonal footprint - the broadest silhouette in the game.
    _outlined(d, _ngon(c, c, s * 0.44, 8, math.pi / 8), _shade(base, 0.62) if not flat else INK, int(s * 0.016))
    _outlined(d, _ngon(c, c, s * 0.33, 8, math.pi / 8), _shade(base, 0.82) if not flat else INK, int(s * 0.014))
    _outlined(d, _ngon(c, c, s * 0.21, 8, math.pi / 8), base, int(s * 0.012))
    if not flat:
        # Energy core. The one saturated thing on an otherwise cool structure,
        # so damage flashes read against it.
        for r, a in ((0.15, 200), (0.10, 235), (0.06, 255)):
            d.ellipse([c - s * r, c - s * r, c + s * r, c + s * r],
                      fill=_shade(CYAN, 1.0 + (0.15 - r) * 3) + (a,))
        _rim(img, _ngon(c, c, s * 0.44, 8, math.pi / 8), _shade(STEEL, 1.6), int(s * 0.012))
    return _finish(img, size)


def tower_seeker(size: int = 64, flat: bool = False) -> Image.Image:
    """Broad blunt wedge. Heavy, wide, front-loaded - reads as a battering ram."""
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    body = INK if flat else AMBER
    pts = [(c, c - s * 0.36), (c + s * 0.38, c + s * 0.06),
           (c + s * 0.24, c + s * 0.34), (c - s * 0.24, c + s * 0.34),
           (c - s * 0.38, c + s * 0.06)]
    _outlined(d, pts, body, int(s * 0.04))
    if not flat:
        _outlined(d, [(c, c - s * 0.22), (c + s * 0.20, c + s * 0.04), (c - s * 0.20, c + s * 0.04)],
                  _shade(AMBER, 0.6), int(s * 0.03))
        _rim(img, pts, _shade(AMBER, 1.6), int(s * 0.022))
    return _finish(img, size)


def player_hunter(size: int = 56, flat: bool = False) -> Image.Image:
    """Narrow elongated arrowhead. Fast and pointed - the opposite silhouette
    to the Seeker's blunt width, on purpose."""
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    body = INK if flat else CRIMSON
    pts = [(c, c - s * 0.44), (c + s * 0.21, c + s * 0.10), (c + s * 0.10, c + s * 0.40),
           (c, c + s * 0.26), (c - s * 0.10, c + s * 0.40), (c - s * 0.21, c + s * 0.10)]
    _outlined(d, pts, body, int(s * 0.04))
    if not flat:
        d.polygon([(c, c - s * 0.30), (c + s * 0.09, c + s * 0.06), (c - s * 0.09, c + s * 0.06)],
                  fill=_shade(CRIMSON, 1.55))
        _rim(img, pts, _shade(CRIMSON, 1.7), int(s * 0.02))
    return _finish(img, size)


def opportunist(size: int = 64, flat: bool = False) -> Image.Image:
    """Round drifting blob with tendrils. No hard edges anywhere, so it reads as
    wandering rather than charging."""
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    body = INK if flat else VIOLET
    for i in range(6):
        a = -math.pi / 2 + (i - 2.5) * 0.30
        x = c + math.cos(a) * s * 0.10
        d.line([(x, c + s * 0.06), (x + math.sin(i) * s * 0.06, c + s * 0.42)],
               fill=INK if flat else _shade(VIOLET, 0.7), width=int(s * 0.055))
    dome = _ngon(c, c - s * 0.04, s * 0.32, 26, 0, 0.82)
    _outlined(d, dome, body, int(s * 0.038))
    if not flat:
        d.ellipse([c - s * 0.13, c - s * 0.15, c + s * 0.13, c + s * 0.08],
                  fill=_shade(VIOLET, 1.45))
        _rim(img, dome, _shade(VIOLET, 1.7), int(s * 0.022))
    return _finish(img, size)


def projectile(size: int = 16, flat: bool = False) -> Image.Image:
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    if flat:
        d.ellipse([c - s * 0.26, c - s * 0.26, c + s * 0.26, c + s * 0.26], fill=INK)
        return _finish(img, size)
    for r, col, a in ((0.34, _shade(CYAN, 0.8), 130), (0.22, CYAN, 220), (0.12, (255, 255, 255), 255)):
        d.ellipse([c - s * r, c - s * r, c + s * r, c + s * r], fill=col + (a,))
    return _finish(img, size)


def xp_shard(size: int = 20, flat: bool = False) -> Image.Image:
    img, d = _canvas(size)
    s = size * SS
    c = s / 2
    pts = [(c, c - s * 0.40), (c + s * 0.26, c), (c, c + s * 0.40), (c - s * 0.26, c)]
    _outlined(d, pts, INK if flat else LIME, int(s * 0.06))
    if not flat:
        d.polygon([(c, c - s * 0.40), (c + s * 0.26, c), (c, c)], fill=_shade(LIME, 1.45))
        _rim(img, pts, _shade(LIME, 1.7), int(s * 0.035))
    return _finish(img, size)


def floor_tile(size: int = 256, flat: bool = False) -> Image.Image:
    """Deliberately quiet. The floor's job is to not compete with anything on
    top of it; the readability hierarchy outranks visual density."""
    import numpy as np

    rng = np.random.default_rng(20260918)
    base = np.array([34, 38, 46], dtype=np.float32)
    n = rng.normal(0.0, 5.5, (size, size, 1)).astype(np.float32)
    # Low-frequency mottling so it does not look like TV static.
    coarse = rng.normal(0.0, 7.0, (size // 16, size // 16, 1)).astype(np.float32)
    coarse = np.array(Image.fromarray(
        np.clip(coarse + 128, 0, 255).astype(np.uint8).squeeze()
    ).resize((size, size), Image.BICUBIC), dtype=np.float32)[:, :, None] - 128.0
    arr = np.clip(base + n + coarse * 0.8, 0, 255).astype(np.uint8)
    arr = np.repeat(arr, 3, axis=2) if arr.shape[2] == 1 else arr
    img = Image.fromarray(arr, "RGB").convert("RGBA")
    return img


SPRITES = {
    "player": (player, 64),
    "tower": (tower, 256),
    "enemy_tower_seeker": (tower_seeker, 64),
    "enemy_player_hunter": (player_hunter, 56),
    "enemy_opportunist": (opportunist, 64),
    "projectile_player": (projectile, 16),
    "pickup_xp_shard": (xp_shard, 20),
    "floor_tile": (floor_tile, 256),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--silhouette", action="store_true",
                    help="Render flat black shapes, to check entities stay "
                         "distinguishable with colour removed.")
    args = ap.parse_args()

    out = os.path.abspath(OUT_DIR)
    os.makedirs(out, exist_ok=True)
    suffix = "_silhouette" if args.silhouette else ""

    for name, (fn, size) in SPRITES.items():
        img = fn(size, flat=args.silhouette)
        path = os.path.join(out, f"{name}{suffix}.png")
        img.save(path)
        print(f"{name}{suffix}.png  {img.size[0]}x{img.size[1]}")

    print(f"\n{len(SPRITES)} sprites -> {out}")


if __name__ == "__main__":
    main()

"""Generates the project-made pixel art that Tiny Swords (CC0) does not ship:
UI glyph tokens (triangle, square, heart, tower, recycle, crystal, core, coin,
arrow, boot, tent), the XP crystal pickup, the enemy "!" marker and the
telegraph ground-ring sheet. Art-consistency pass, decision D161.

Rules (matching the pack): 1 art pixel = 1 screen pixel at 1920x1080, a 2 px
dark ink outline in the pack's ink colour (22,28,46), a flat 3-tone fill
(highlight / base / shade) with no antialiasing and no partial alpha, except
the translucent ring fill. UI glyphs are baked in light grey and tinted at
draw time (modulate); the outline stays dark under any tint.

Run from the repository root:  python tools/art/make_pixel_icons.py
Writes assets/ui/icons/*.png, assets/ui/telegraph_exclaim.png,
assets/ui/telegraph_ring.png and assets/sprites/pickup_xp_crystal.png.
"""
import math
import os
from PIL import Image, ImageDraw

INK = (22, 28, 46, 255)
S = 32  # icon canvas; the shape box is 4..28 so a 2 px outline fits


def mask_from(draw_fn, size=(S, S)):
    im = Image.new("L", size, 0)
    d = ImageDraw.Draw(im)
    draw_fn(d)
    w, h = size
    return {(x, y) for y in range(h) for x in range(w) if im.getpixel((x, y)) > 127}


def dilate(cells, r=2):
    out = set(cells)
    for _ in range(r):
        nxt = set(out)
        for (x, y) in out:
            nxt.update([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
        out = nxt
    return out


def shift(cells, dx, dy):
    return {(x + dx, y + dy) for (x, y) in cells}


def render(cells, size, base, light, dark, extra=None):
    """3-tone fill + 2 px ink outline. `extra` maps (x,y)->rgba overrides."""
    w, h = size
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    outline = dilate(cells, 2) - cells
    hi = cells - shift(cells, 2, 2)
    sh = cells - shift(cells, -2, -2)
    for (x, y) in outline:
        if 0 <= x < w and 0 <= y < h:
            im.putpixel((x, y), INK)
    for (x, y) in cells:
        if 0 <= x < w and 0 <= y < h:
            c = base
            if (x, y) in hi:
                c = light
            elif (x, y) in sh:
                c = dark
            im.putpixel((x, y), c + (255,) if len(c) == 3 else c)
    if extra:
        for (x, y), c in extra.items():
            if 0 <= x < w and 0 <= y < h:
                im.putpixel((x, y), c)
    return im


def unit_poly(points, box=(4, 4, 28, 28)):
    x0, y0, x1, y1 = box
    return [(x0 + px * (x1 - x0), y0 + py * (y1 - y0)) for px, py in points]


GREY = ((222, 222, 222), (252, 252, 252), (160, 160, 160))  # base, light, dark


def poly_icon(points, box=(4, 4, 28, 28)):
    cells = mask_from(lambda d: d.polygon(unit_poly(points, box), fill=255))
    return render(cells, (S, S), *GREY)


def make_triangle():
    return poly_icon([(0.5, 0), (1, 1), (0, 1)])


def make_square():
    cells = mask_from(lambda d: d.rectangle([5, 5, 26, 26], fill=255))
    return render(cells, (S, S), *GREY)


def make_heart():
    pts = []
    for i in range(60):
        t = math.tau * i / 60
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, -y))
    minx = min(p[0] for p in pts); maxx = max(p[0] for p in pts)
    miny = min(p[1] for p in pts); maxy = max(p[1] for p in pts)
    unit = [((x - minx) / (maxx - minx), (y - miny) / (maxy - miny)) for x, y in pts]
    return poly_icon(unit, (4, 5, 28, 27))


def make_tower():
    pts = [(0.10, 1.00), (0.10, 0.40), (0.00, 0.40), (0.00, 0.20), (0.20, 0.20), (0.20, 0.34),
           (0.40, 0.34), (0.40, 0.20), (0.60, 0.20), (0.60, 0.34), (0.80, 0.34), (0.80, 0.20),
           (1.00, 0.20), (1.00, 0.40), (0.90, 0.40), (0.90, 1.00)]
    return poly_icon(pts, (4, 3, 28, 29))


def make_crystal_icon():
    pts = [(0.5, 0), (0.85, 0.30), (1, 0.55), (0.7, 1), (0.3, 1), (0, 0.55), (0.15, 0.30)]
    return poly_icon(pts)


def make_hex(inner=True):
    cx = cy = 16
    r = 12
    outer = [(cx + r * math.cos(math.tau * i / 6), cy + r * math.sin(math.tau * i / 6)) for i in range(6)]
    cells = mask_from(lambda d: d.polygon(outer, fill=255))
    im = render(cells, (S, S), *GREY)
    ring = [(cx + 7 * math.cos(math.tau * i / 6), cy + 7 * math.sin(math.tau * i / 6)) for i in range(6)]
    inner_cells = mask_from(lambda d: d.polygon(ring, fill=255))
    for (x, y) in inner_cells:
        im.putpixel((x, y), (160, 160, 160, 255))
    core = [(cx + 4 * math.cos(math.tau * i / 6), cy + 4 * math.sin(math.tau * i / 6)) for i in range(6)]
    for (x, y) in mask_from(lambda d: d.polygon(core, fill=255)):
        im.putpixel((x, y), (252, 252, 252, 255))
    return im


def make_coin():
    cells = mask_from(lambda d: d.ellipse([4, 4, 27, 27], fill=255))
    im = render(cells, (S, S), *GREY)
    ring = mask_from(lambda d: d.ellipse([9, 9, 22, 22], outline=255, width=2))
    for (x, y) in ring:
        im.putpixel((x, y), (160, 160, 160, 255))
    return im


def make_recycle():
    def draw(d):
        d.arc([6, 6, 25, 25], start=-70, end=60, fill=255, width=3)
        d.arc([6, 6, 25, 25], start=110, end=240, fill=255, width=3)
        d.polygon([(28, 14), (20, 14), (25, 21)], fill=255)
        d.polygon([(3, 17), (11, 17), (6, 10)], fill=255)
    cells = mask_from(draw)
    return render(cells, (S, S), *GREY)


def make_tent():
    def draw(d):
        d.polygon([(16, 11), (28, 28), (4, 28)], fill=255)
        d.line([(16, 3), (16, 11)], fill=255, width=2)
        d.polygon([(16, 3), (24, 5), (16, 8)], fill=255)
    return render(mask_from(draw), (S, S), *GREY)


def make_arrow():
    def draw(d):
        d.polygon([(27, 5), (17, 7), (24, 14)], fill=255)
        d.line([(22, 10), (7, 25)], fill=255, width=3)
        d.polygon([(4, 28), (11, 19), (8, 28)], fill=255)
        d.polygon([(4, 28), (13, 22), (4, 21)], fill=255)
    return render(mask_from(draw), (S, S), *GREY)


def make_pointer_east():
    """Cardinal off-screen-indicator arrow, pointing east. 28x28 (even, so a
    90-degree turn is lossless). The pack's own Pointers/01 is used for the
    four diagonals."""
    size = (28, 28)

    def draw(d):
        d.polygon([(25, 14), (14, 5), (14, 10), (4, 10), (4, 18), (14, 18), (14, 23)], fill=255)
    cells = mask_from(draw, size)
    return render(cells, size, *GREY)


def make_boot():
    pts = [(0.32, 0.00), (0.62, 0.00), (0.62, 0.52), (0.88, 0.62), (1.00, 0.80), (1.00, 1.00),
           (0.06, 1.00), (0.06, 0.86), (0.20, 0.86), (0.32, 0.72)]
    return poly_icon(pts)


# --- world / marker art -------------------------------------------------------

def make_exclaim():
    size = (22, 30)

    def draw(d):
        d.rectangle([7, 4, 14, 17], fill=255)
        d.polygon([(8, 18), (13, 18), (12, 20), (9, 20)], fill=255)
        d.rectangle([7, 22, 14, 26], fill=255)
    cells = mask_from(draw, size)
    return render(cells, size, *GREY)


def make_ring_sheet():
    """6 frames, 64x32: a hard ellipse ring with a fill that grows 0..100 %."""
    frames = 6
    fw, fh = 64, 32
    sheet = Image.new("RGBA", (fw * frames, fh), (0, 0, 0, 0))
    cx, cy = 32, 16
    rx, ry = 28, 13
    for k in range(frames):
        frac = k / (frames - 1)
        im = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        ring_outer = {(x, y) for y in range(fh) for x in range(fw)
                      if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}
        ring_inner = {(x, y) for y in range(fh) for x in range(fw)
                      if ((x + 0.5 - cx) / (rx - 4)) ** 2 + ((y + 0.5 - cy) / (ry - 4)) ** 2 <= 1.0}
        ring = ring_outer - ring_inner
        outline = dilate(ring_outer, 2) - ring_outer
        outline_in = (ring_inner - dilate(ring_inner - dilate(ring_inner, 0), 0))
        for (x, y) in outline:
            if 0 <= x < fw and 0 <= y < fh:
                im.putpixel((x, y), INK)
        for (x, y) in ring:
            im.putpixel((x, y), (235, 235, 235, 255))
        # inner ink edge of the ring (2 px) so the ring reads as a band
        inner_edge = dilate(ring_inner, 2) - ring_inner
        for (x, y) in inner_edge & ring:
            im.putpixel((x, y), INK)
        if frac > 0:
            fr = frac
            for (x, y) in ring_inner:
                u = ((x + 0.5 - cx) / ((rx - 6) * fr)) ** 2 + ((y + 0.5 - cy) / ((ry - 6) * fr)) ** 2
                if u <= 1.0:
                    im.putpixel((x, y), (255, 255, 255, 120))
        sheet.paste(im, (k * fw, 0))
    return sheet


def make_xp_crystal():
    size = (28, 36)
    pts = [(14, 3), (23, 14), (23, 24), (14, 33), (5, 24), (5, 14)]

    def draw(d):
        d.polygon(pts, fill=255)
    cells = mask_from(draw, size)
    base = (150, 120, 235)
    light = (196, 176, 255)
    dark = (104, 76, 190)
    im = render(cells, size, base, light, dark)
    # facet lines: a lighter left facet and darker right facet, 1 px grain
    for (x, y) in cells:
        if x < 14 and y > 9 and y < 28 and x >= 8:
            if (x, y) not in (cells - shift(cells, 2, 2)):
                im.putpixel((x, y), (172, 146, 246, 255))
    # sparkle
    for (x, y) in [(10, 10), (10, 11), (9, 11), (11, 11), (10, 12)]:
        im.putpixel((x, y), (255, 255, 255, 255))
    return im


# --- v1.0 coloured icons (decision D182) ---------------------------------------
# Same rules as above (2 px ink outline, flat 3-tone fills, no antialiasing) but
# coloured and multi-part. Pool cue (docs/31 section 4): player abilities carry a
# blue/green accent, Tower abilities stone grey with an orange accent. Colour is
# never the only cue: every silhouette is distinct.

def pal(base, light, dark):
    return (base, light, dark)


STONE = pal((150, 152, 164), (200, 202, 214), (100, 102, 118))
STEEL = pal((186, 194, 208), (238, 242, 250), (126, 134, 154))
IRON = pal((92, 98, 116), (140, 148, 168), (58, 62, 78))
ORANGE = pal((232, 140, 50), (255, 192, 104), (170, 92, 32))
BLUE = pal((76, 138, 224), (142, 192, 255), (44, 90, 172))
GREEN = pal((86, 178, 98), (150, 230, 150), (50, 124, 64))
RED = pal((208, 66, 58), (250, 122, 102), (138, 38, 40))
GOLD = pal((240, 200, 70), (255, 238, 140), (176, 134, 40))
WOOD = pal((160, 106, 60), (210, 156, 96), (108, 68, 36))
ICE = pal((150, 220, 240), (224, 252, 255), (84, 164, 200))
BONE = pal((232, 226, 210), (255, 254, 244), (168, 160, 144))
PURPLE = pal((150, 120, 235), (196, 176, 255), (104, 76, 190))
YELLOW = pal((250, 224, 70), (255, 250, 170), (200, 160, 30))
FLAME = pal((244, 120, 40), (255, 208, 80), (190, 60, 28))
CREAM = pal((238, 226, 190), (255, 250, 228), (190, 174, 136))


class Part:
    def __init__(self, fn, palette, t=2):
        self.fn, self.palette, self.t = fn, palette, t


def compose(parts, details=None, size=(S, S)):
    """parts: bottom to top. details: [(fn(d), rgba)] painted inside the silhouette."""
    w, h = size
    masks = [mask_from(p.fn, size) for p in parts]
    union = set().union(*masks)
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    for (x, y) in dilate(union, 2) - union:
        if 0 <= x < w and 0 <= y < h:
            im.putpixel((x, y), INK)
    for part, cells in zip(parts, masks):
        base, light, dark = part.palette
        t = part.t
        hi = cells - shift(cells, t, t)
        sh = cells - shift(cells, -t, -t)
        for (x, y) in cells:
            if 0 <= x < w and 0 <= y < h:
                c = light if (x, y) in hi else (dark if (x, y) in sh else base)
                im.putpixel((x, y), c + (255,))
    for fn, col in details or []:
        layer = Image.new("RGBA", size, (0, 0, 0, 0))
        fn(ImageDraw.Draw(layer), col)
        for y in range(h):
            for x in range(w):
                if layer.getpixel((x, y))[3] > 0 and (x, y) in union:
                    im.putpixel((x, y), layer.getpixel((x, y)))
    return im


def D(fn):
    """Detail wrapper: fn(d) draws with the colour passed in."""
    return fn


def vec_parts(tail, head, shaft_pal=WOOD, head_pal=STEEL, fletch_pal=None, head_len=9, head_w=5, sw=3):
    """An arrow from tail to head as parts (shaft, head, fletching)."""
    tx, ty = tail
    hx, hy = head
    dx, dy = hx - tx, hy - ty
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    px, py = -uy, ux
    bx, by = hx - ux * head_len, hy - uy * head_len
    parts = [Part(lambda d: d.line([(tx, ty), (bx, by)], fill=255, width=sw), shaft_pal, 1),
             Part(lambda d: d.polygon([(hx, hy), (bx + px * head_w, by + py * head_w),
                                       (bx - px * head_w, by - py * head_w)], fill=255), head_pal, 1)]
    if fletch_pal is not None:
        f1 = (tx + ux * 7, ty + uy * 7)
        parts.append(Part(lambda d: d.polygon([(tx, ty), (f1[0] + px * 4, f1[1] + py * 4), (f1[0] + ux * 2, f1[1] + uy * 2)], fill=255), fletch_pal, 1))
        parts.append(Part(lambda d: d.polygon([(tx, ty), (f1[0] - px * 4, f1[1] - py * 4), (f1[0] + ux * 2, f1[1] + uy * 2)], fill=255), fletch_pal, 1))
    return parts


def snowflake_lines(cx, cy, r, w=2):
    def fn(d):
        for k in range(4):
            a = math.pi * k / 4
            d.line([(cx - r * math.cos(a), cy - r * math.sin(a)), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=255, width=w)
    return fn


def flame_fn(cx, base_y, w, h):
    def fn(d):
        d.polygon([(cx, base_y - h), (cx + w * 0.55, base_y - h * 0.45), (cx + w * 0.5, base_y - h * 0.1),
                   (cx, base_y), (cx - w * 0.5, base_y - h * 0.1), (cx - w * 0.55, base_y - h * 0.5),
                   (cx - w * 0.15, base_y - h * 0.62)], fill=255)
    return fn


# --- battle skills ---

def ic_arrow_storm():
    parts = []
    for ox, oy in ((-7, 2), (0, -2), (7, 2)):
        parts += vec_parts((12 + ox + 4, 3 + oy), (12 + ox, 25 + oy), WOOD, STEEL, BLUE, 7, 4, 3)
    return compose(parts)


def ic_frost_nova():
    parts = [Part(snowflake_lines(16, 16, 12, 3), ICE, 1),
             Part(lambda d: d.ellipse([10, 10, 22, 22], fill=255), ICE),
             Part(lambda d: d.polygon([(16, 3), (19, 8), (13, 8)], fill=255), ICE, 1),
             Part(lambda d: d.polygon([(16, 29), (19, 24), (13, 24)], fill=255), ICE, 1),
             Part(lambda d: d.polygon([(3, 16), (8, 13), (8, 19)], fill=255), ICE, 1),
             Part(lambda d: d.polygon([(29, 16), (24, 13), (24, 19)], fill=255), ICE, 1)]
    return compose(parts, [(lambda d, c: d.ellipse([14, 14, 18, 18], fill=c), (255, 255, 255, 255))])


def ic_firebomb():
    parts = [Part(lambda d: d.ellipse([5, 12, 25, 30], fill=255), IRON),
             Part(lambda d: d.rectangle([13, 9, 17, 14], fill=255), STEEL, 1),
             Part(lambda d: d.line([(16, 9), (21, 5)], fill=255, width=2), WOOD, 1),
             Part(flame_fn(24, 11, 9, 11), FLAME, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([9, 16, 11, 18], fill=c), (200, 206, 224, 255))])


def ic_war_horn():
    def horn(d):
        pts_l, pts_r = [], []
        n = 24
        for i in range(n + 1):
            t = i / n
            x = (1 - t) ** 2 * 5 + 2 * t * (1 - t) * 4 + t * t * 26
            y = (1 - t) ** 2 * 5 + 2 * t * (1 - t) * 27 + t * t * 22
            tx = 2 * (1 - t) * (4 - 5) + 2 * t * (26 - 4)
            ty = 2 * (1 - t) * (27 - 5) + 2 * t * (22 - 27)
            L = math.hypot(tx, ty)
            w = 1.8 + 8.5 * t ** 2.2
            pts_l.append((x - ty / L * w, y + tx / L * w))
            pts_r.append((x + ty / L * w, y - tx / L * w))
        d.polygon(pts_l + pts_r[::-1], fill=255)
    parts = [Part(horn, BONE),
             Part(lambda d: d.rectangle([1, 2, 8, 6], fill=255), GOLD, 1),
             Part(lambda d: d.polygon([(21, 11), (28, 15), (30, 27), (24, 30)], fill=255), GOLD, 1)]
    return compose(parts)


# --- player abilities ---

def ic_flame_arrows():
    parts = vec_parts((3, 28), (22, 9), WOOD, STEEL, GREEN, 7, 4, 3)
    parts.append(Part(flame_fn(24, 12, 11, 14), FLAME, 1))
    return compose(parts)


def ic_frost_arrows():
    parts = vec_parts((3, 28), (21, 10), WOOD, STEEL, GREEN, 6, 4, 3)
    parts.append(Part(snowflake_lines(24, 8, 6, 2), ICE, 1))
    return compose(parts)


def ic_whirling_axes():
    parts = [Part(lambda d: d.arc([3, 3, 28, 28], start=100, end=330, fill=255, width=3), BLUE, 1),
             Part(lambda d: d.line([(10, 25), (21, 8)], fill=255, width=3), WOOD, 1),
             Part(lambda d: d.polygon([(14, 4), (27, 6), (27, 14), (20, 17), (20, 12), (15, 11)], fill=255), STEEL),
             Part(lambda d: d.polygon([(3, 22), (9, 20), (7, 28)], fill=255), BLUE, 1)]
    return compose(parts)


def ic_dynamite_satchel():
    parts = [Part(lambda d: d.rectangle([5, 12, 11, 28], fill=255), RED),
             Part(lambda d: d.rectangle([13, 12, 19, 28], fill=255), RED),
             Part(lambda d: d.rectangle([21, 12, 27, 28], fill=255), RED),
             Part(lambda d: d.rectangle([4, 17, 28, 21], fill=255), WOOD, 1),
             Part(lambda d: d.line([(16, 12), (16, 8), (21, 5)], fill=255, width=2), CREAM, 1),
             Part(lambda d: d.polygon([(22, 2), (26, 4), (23, 8), (20, 6)], fill=255), YELLOW, 1)]
    return compose(parts)


def ic_storm_bolt():
    parts = [Part(lambda d: d.polygon([(19, 2), (7, 17), (14, 17), (10, 30), (25, 12), (17, 12), (22, 2)], fill=255), YELLOW)]
    return compose(parts, [(lambda d, c: d.line([(17, 6), (12, 15)], fill=c, width=1), (255, 255, 255, 255))])


def ic_caltrops():
    parts = [Part(lambda d: d.polygon([(16, 3), (20, 17), (12, 17)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(4, 24), (16, 15), (17, 20)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(28, 24), (16, 15), (15, 20)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(16, 29), (12, 18), (20, 18)], fill=255), IRON, 1),
             Part(lambda d: d.ellipse([12, 13, 20, 21], fill=255), GREEN)]
    return compose(parts)


def ic_sacred_ground():
    parts = [Part(lambda d: d.ellipse([3, 3, 28, 28], outline=255, width=4), GOLD),
             Part(lambda d: d.rectangle([14, 8, 17, 23], fill=255), CREAM, 1),
             Part(lambda d: d.rectangle([9, 13, 22, 16], fill=255), CREAM, 1)]
    return compose(parts, [(lambda d, c: d.ellipse([5, 5, 26, 26], outline=c, width=1), (255, 244, 170, 255))])


# --- tower abilities ---

def ic_ballista():
    parts = [Part(lambda d: d.arc([-6, 3, 14, 29], start=-70, end=70, fill=255, width=4), WOOD),
             Part(lambda d: d.rectangle([4, 14, 27, 17], fill=255), STONE, 1),
             Part(lambda d: d.polygon([(30, 15.5), (22, 10), (22, 21)], fill=255), ORANGE, 1),
             Part(lambda d: d.rectangle([5, 12, 12, 19], fill=255), STONE)]
    return compose(parts, [(lambda d, c: d.line([(8, 4), (8, 27)], fill=c, width=1), CREAM[2])])


def ic_catapult():
    parts = [Part(lambda d: d.polygon([(4, 28), (28, 28), (22, 21), (10, 21)], fill=255), STONE),
             Part(lambda d: d.line([(10, 22), (24, 7)], fill=255, width=4), WOOD, 1),
             Part(lambda d: d.polygon([(21, 11), (29, 8), (28, 17)], fill=255), WOOD, 1),
             Part(lambda d: d.ellipse([15, 1, 25, 11], fill=255), ORANGE)]
    return compose(parts)


def ic_frost_ward():
    parts = [Part(lambda d: d.polygon([(5, 28), (27, 28), (23, 21), (9, 21)], fill=255), STONE),
             Part(lambda d: d.polygon([(16, 2), (24, 11), (16, 21), (8, 11)], fill=255), ICE),
             Part(lambda d: d.rectangle([5, 26, 27, 28], fill=255), ORANGE, 1)]
    return compose(parts, [(lambda d, c: d.line([(16, 5), (12, 11)], fill=c, width=1), (255, 255, 255, 255))])


def ic_spiked_palisade():
    parts = [Part(lambda d: d.polygon([(4, 28), (4, 11), (9, 3), (14, 11), (14, 28)], fill=255), WOOD),
             Part(lambda d: d.polygon([(16, 28), (16, 11), (21, 3), (26, 11), (26, 28)], fill=255), WOOD),
             Part(lambda d: d.rectangle([3, 18, 28, 22], fill=255), ORANGE, 1)]
    return compose(parts)


# --- passives ---

def ic_fleet_step():
    parts = [Part(lambda d: [d.line([(1, y), (9, y)], fill=255, width=2) for y in (10, 16, 22)], BLUE, 1),
             Part(lambda d: d.polygon([(14, 3), (22, 3), (22, 15), (29, 19), (29, 27), (12, 27), (12, 22), (14, 22)], fill=255), WOOD)]
    return compose(parts)


def ic_battle_focus():
    parts = [Part(lambda d: d.arc([3, 3, 28, 28], start=-60, end=250, fill=255, width=4), BLUE, 1),
             Part(lambda d: d.polygon([(26, 4), (29, 15), (18, 11)], fill=255), BLUE, 1),
             Part(lambda d: d.polygon([(16, 8), (20, 16), (16, 24), (12, 16)], fill=255), YELLOW)]
    return compose(parts)


def ic_blast_radius():
    parts = [Part(lambda d: d.ellipse([8, 8, 23, 23], outline=255, width=3), ORANGE, 1),
             Part(lambda d: d.polygon([(16, 1), (21, 7), (11, 7)], fill=255), FLAME, 1),
             Part(lambda d: d.polygon([(16, 30), (21, 24), (11, 24)], fill=255), FLAME, 1),
             Part(lambda d: d.polygon([(1, 16), (7, 11), (7, 21)], fill=255), FLAME, 1),
             Part(lambda d: d.polygon([(30, 16), (24, 11), (24, 21)], fill=255), FLAME, 1),
             Part(lambda d: d.ellipse([13, 13, 18, 18], fill=255), YELLOW, 1)]
    return compose(parts)


def ic_keen_eye():
    parts = [Part(lambda d: d.polygon([(2, 16), (9, 8), (16, 6), (23, 8), (30, 16), (23, 24), (16, 26), (9, 24)], fill=255), CREAM),
             Part(lambda d: d.ellipse([10, 9, 22, 23], fill=255), GREEN)]
    return compose(parts, [(lambda d, c: d.ellipse([14, 13, 18, 19], fill=c), INK),
                           (lambda d, c: d.rectangle([12, 11, 13, 12], fill=c), (255, 255, 255, 255))])


def ic_leather_armor():
    parts = [Part(lambda d: d.polygon([(10, 3), (16, 8), (22, 3), (29, 8), (26, 15), (23, 14), (23, 28), (9, 28), (9, 14), (6, 15), (3, 8)], fill=255), WOOD)]
    return compose(parts, [(lambda d, c: d.line([(16, 9), (16, 27)], fill=c, width=1), CREAM[1]),
                           (lambda d, c: [d.line([(13, y), (19, y)], fill=c, width=1) for y in (13, 18, 23)], CREAM[1])])


def ic_ability_power():
    parts = [Part(lambda d: d.rectangle([5, 4, 26, 28], fill=255), BLUE),
             Part(lambda d: d.rectangle([4, 4, 7, 28], fill=255), IRON, 1),
             Part(lambda d: d.polygon([(17, 8), (19, 13), (24, 13), (20, 17), (22, 22), (17, 19), (12, 22), (14, 17), (10, 13), (15, 13)], fill=255), GOLD, 1)]
    return compose(parts)


def ic_stone_mason():
    parts = [Part(lambda d: d.rectangle([3, 12, 21, 28], fill=255), STONE),
             Part(lambda d: d.polygon([(18, 3), (28, 8), (24, 16), (15, 12)], fill=255), ORANGE, 1),
             Part(lambda d: d.line([(24, 14), (27, 26)], fill=255, width=3), WOOD, 1)]
    return compose(parts, [(lambda d, c: d.line([(3, 20), (21, 20)], fill=c, width=1), STONE[2]),
                           (lambda d, c: d.line([(12, 12), (12, 20)], fill=c, width=1), STONE[2]),
                           (lambda d, c: d.line([(7, 20), (7, 28)], fill=c, width=1), STONE[2]),
                           (lambda d, c: d.line([(16, 20), (16, 28)], fill=c, width=1), STONE[2])])


# --- existing Draft cards ---

def ic_rapid_fire():
    parts = []
    for y in (3, 12, 21):
        parts.append(Part(lambda d, y=y: d.polygon([(16, y), (28, y + 9), (22, y + 9), (16, y + 5), (10, y + 9), (4, y + 9)], fill=255), RED, 1))
    return compose(parts)


def ic_heavy_rounds():
    parts = [Part(lambda d: d.ellipse([2, 15, 16, 29], fill=255), IRON),
             Part(lambda d: d.ellipse([16, 15, 30, 29], fill=255), IRON),
             Part(lambda d: d.ellipse([9, 2, 23, 16], fill=255), IRON)]
    return compose(parts, [(lambda d, c: d.rectangle([5, 19, 7, 21], fill=c), (180, 188, 210, 255)),
                           (lambda d, c: d.rectangle([19, 19, 21, 21], fill=c), (180, 188, 210, 255)),
                           (lambda d, c: d.rectangle([12, 6, 14, 8], fill=c), (180, 188, 210, 255))])


def ic_patch_kit():
    parts = [Part(lambda d: d.polygon([(5, 22), (21, 5), (28, 11), (12, 28)], fill=255), CREAM)]
    return compose(parts, [(lambda d, c: d.polygon([(12, 14), (18, 9), (21, 12), (15, 17)], fill=c), RED[0]),
                           (lambda d, c: [d.rectangle([x, y, x, y], fill=c) for x, y in ((9, 21), (11, 23), (19, 20), (21, 18))], CREAM[2])])


def ic_swift_feet():
    boot = Part(lambda d: d.polygon([(10, 5), (19, 5), (19, 17), (27, 21), (28, 28), (7, 28), (7, 23), (10, 23)], fill=255), GREEN)
    wing = Part(lambda d: d.polygon([(1, 4), (11, 8), (12, 14), (6, 12), (8, 17), (2, 13)], fill=255), CREAM, 1)
    return compose([boot, wing])


def ic_vitality():
    pts = []
    for i in range(60):
        t = math.tau * i / 60
        pts.append((16 * math.sin(t) ** 3, -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
    mnx = min(p[0] for p in pts); mxx = max(p[0] for p in pts); mny = min(p[1] for p in pts); mxy = max(p[1] for p in pts)
    poly = [(4 + (x - mnx) / (mxx - mnx) * 24, 5 + (y - mny) / (mxy - mny) * 22) for x, y in pts]
    return compose([Part(lambda d: d.polygon(poly, fill=255), RED)],
                   [(lambda d, c: (d.rectangle([15, 10, 16, 20], fill=c), d.rectangle([11, 14, 20, 15], fill=c)), (255, 236, 230, 255))])


def ic_magnet():
    parts = [Part(lambda d: d.arc([5, 4, 27, 28], start=180, end=360, fill=255, width=7), RED),
             Part(lambda d: d.rectangle([5, 14, 11, 22], fill=255), RED),
             Part(lambda d: d.rectangle([21, 14, 27, 22], fill=255), RED),
             Part(lambda d: d.rectangle([5, 23, 11, 29], fill=255), STEEL),
             Part(lambda d: d.rectangle([21, 23, 27, 29], fill=255), STEEL)]
    return compose(parts)


def ic_regeneration():
    parts = [Part(lambda d: d.line([(16, 29), (16, 12)], fill=255, width=3), GREEN, 1),
             Part(lambda d: d.polygon([(16, 17), (4, 14), (5, 5), (15, 9)], fill=255), GREEN),
             Part(lambda d: d.polygon([(16, 12), (28, 9), (27, 1), (17, 4)], fill=255), GREEN),
             Part(lambda d: d.rectangle([10, 26, 22, 29], fill=255), WOOD, 1)]
    return compose(parts)


def ic_piercing_arrows():
    parts = [Part(lambda d: d.rectangle([14, 3, 19, 29], fill=255), STONE),
             Part(lambda d: d.line([(1, 16), (21, 16)], fill=255, width=3), WOOD, 1),
             Part(lambda d: d.polygon([(30, 16), (21, 11), (21, 21)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(1, 16), (6, 11), (8, 16), (6, 21)], fill=255), RED, 1)]
    return compose(parts)


def ic_multishot():
    parts = []
    for tx in (4, 16, 28):
        parts += vec_parts((16, 29), (tx, 5), WOOD, STEEL, None, 7, 4, 3)
    return compose(parts)


def ic_caliber():
    parts = [Part(lambda d: d.polygon([(16, 2), (27, 17), (20, 17), (20, 29), (12, 29), (12, 17), (5, 17)], fill=255), STEEL)]
    return compose(parts, [(lambda d, c: d.line([(13, 20), (19, 20)], fill=c, width=1), STEEL[2]),
                           (lambda d, c: d.line([(13, 24), (19, 24)], fill=c, width=1), STEEL[2])])


def ic_optics():
    parts = [Part(lambda d: d.line([(21, 21), (28, 28)], fill=255, width=5), WOOD, 1),
             Part(lambda d: d.ellipse([3, 3, 23, 23], fill=255), STEEL),
             Part(lambda d: d.ellipse([7, 7, 19, 19], fill=255), ICE)]
    return compose(parts, [(lambda d, c: d.rectangle([9, 9, 11, 12], fill=c), (255, 255, 255, 255))])


def ic_shield_matrix():
    parts = [Part(lambda d: d.polygon([(4, 4), (28, 4), (28, 17), (16, 29), (4, 17)], fill=255), BLUE)]
    return compose(parts, [(lambda d, c: [d.line([(x, 4), (x, 29)], fill=c, width=1) for x in (11, 16, 21)], BLUE[1]),
                           (lambda d, c: [d.line([(4, y), (28, y)], fill=c, width=1) for y in (10, 16, 22)], BLUE[1])])


def ic_reinforced_plating():
    parts = [Part(lambda d: d.rectangle([3, 6, 28, 26], fill=255), STEEL),
             Part(lambda d: d.rectangle([3, 6, 28, 10], fill=255), ORANGE, 1)]
    return compose(parts, [(lambda d, c: [d.rectangle([x, y, x + 1, y + 1], fill=c) for x, y in ((6, 13), (23, 13), (6, 21), (23, 21))], IRON[2]),
                           (lambda d, c: d.line([(8, 24), (23, 12)], fill=c, width=1), STEEL[2])])


def ic_watchtower_upgrade():
    pts = [(0.15, 1.00), (0.15, 0.40), (0.05, 0.40), (0.05, 0.12), (0.30, 0.12), (0.30, 0.26), (0.40, 0.26), (0.40, 0.12),
           (0.60, 0.12), (0.60, 0.26), (0.70, 0.26), (0.70, 0.12), (0.95, 0.12), (0.95, 0.40), (0.85, 0.40), (0.85, 1.00)]
    poly = unit_poly(pts, (4, 3, 28, 29))
    return compose([Part(lambda d: d.polygon(poly, fill=255), STONE),
                    Part(lambda d: d.polygon([(16, 12), (22, 19), (18, 19), (18, 26), (14, 26), (14, 19), (10, 19)], fill=255), ORANGE, 1)])


def ic_tower_volley():
    parts = [Part(lambda d: d.polygon([(4, 29), (4, 22), (8, 22), (8, 24), (12, 24), (12, 22), (20, 22), (20, 24), (24, 24), (24, 22), (28, 22), (28, 29)], fill=255), STONE)]
    for tx in (7, 16, 25):
        parts += vec_parts((tx, 21), (tx, 3), WOOD, ORANGE, None, 6, 3, 2)
    return compose(parts)


def ic_repair_kit():
    parts = [Part(lambda d: d.rectangle([3, 12, 28, 28], fill=255), RED),
             Part(lambda d: d.arc([10, 3, 21, 16], start=180, end=360, fill=255, width=3), IRON, 1),
             Part(lambda d: d.rectangle([13, 17, 18, 22], fill=255), GOLD, 1)]
    return compose(parts, [(lambda d, c: d.line([(3, 18), (28, 18)], fill=c, width=1), RED[2])])


def ic_overdrive_fallback():
    parts = [Part(lambda d: d.ellipse([6, 6, 25, 25], fill=255), ORANGE)]
    for k in range(8):
        a = math.tau * k / 8
        cx, cy = 15.5 + 11 * math.cos(a), 15.5 + 11 * math.sin(a)
        parts.append(Part(lambda d, cx=cx, cy=cy: d.rectangle([cx - 2.5, cy - 2.5, cx + 2.5, cy + 2.5], fill=255), ORANGE, 1))
    return compose(parts, [(lambda d, c: d.ellipse([11, 11, 20, 20], fill=c), INK[:3] + (255,)),
                           (lambda d, c: d.ellipse([13, 13, 18, 18], fill=c), YELLOW[0] + (255,))])


def ic_reinforce_fallback():
    parts = [Part(lambda d: d.polygon([(3, 15), (28, 15), (28, 19), (24, 19), (24, 24), (28, 24), (28, 29), (3, 29), (3, 24), (7, 24), (7, 19), (3, 19)], fill=255), IRON),
             Part(lambda d: d.polygon([(5, 6), (22, 6), (29, 10), (29, 15), (5, 15)], fill=255), STEEL)]
    return compose(parts)


# --- difficulties ---

def ic_recruit():
    parts = [Part(lambda d: d.pieslice([5, 6, 27, 30], start=180, end=360, fill=255), WOOD),
             Part(lambda d: d.rectangle([5, 17, 27, 22], fill=255), WOOD, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([14, 8, 17, 12], fill=c), GREEN[0])])


def ic_soldier():
    parts = [Part(lambda d: d.pieslice([4, 4, 28, 30], start=180, end=360, fill=255), STEEL),
             Part(lambda d: d.rectangle([4, 16, 28, 28], fill=255), STEEL),
             Part(lambda d: d.rectangle([14, 17, 18, 29], fill=255), IRON, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([7, 19, 24, 21], fill=c), IRON[2])])


def ic_veteran():
    parts = [Part(lambda d: d.polygon([(14, 1), (21, 1), (27, 6), (24, 11), (16, 6)], fill=255), ORANGE, 1),
             Part(lambda d: d.pieslice([4, 4, 28, 30], start=180, end=360, fill=255), STEEL),
             Part(lambda d: d.rectangle([4, 16, 28, 28], fill=255), STEEL),
             Part(lambda d: d.rectangle([14, 17, 18, 29], fill=255), IRON, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([7, 19, 24, 21], fill=c), IRON[2])])


def ic_warlord():
    parts = [Part(lambda d: d.polygon([(7, 14), (1, 11), (2, 2), (7, 7), (11, 11)], fill=255), BONE, 1),
             Part(lambda d: d.polygon([(25, 14), (31, 11), (30, 2), (25, 7), (21, 11)], fill=255), BONE, 1),
             Part(lambda d: d.pieslice([6, 6, 26, 30], start=180, end=360, fill=255), RED),
             Part(lambda d: d.rectangle([6, 17, 26, 28], fill=255), RED),
             Part(lambda d: d.rectangle([14, 17, 18, 29], fill=255), IRON, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([8, 19, 23, 21], fill=c), INK)])


# --- misc glyphs ---

def ic_dash():
    parts = [Part(lambda d: [d.line([(1, y), (13, y)], fill=255, width=2) for y in (9, 22)], BLUE, 1),
             Part(lambda d: d.polygon([(30, 16), (17, 4), (17, 11), (6, 11), (6, 21), (17, 21), (17, 28)], fill=255), BLUE)]
    return compose(parts, [(lambda d, c: d.line([(8, 13), (18, 13)], fill=c, width=1), BLUE[1])])


def skull_parts(color=BONE):
    return [Part(lambda d: d.ellipse([5, 3, 27, 22], fill=255), color),
            Part(lambda d: d.rectangle([10, 17, 22, 28], fill=255), color)]


def ic_kills():
    return compose(skull_parts(), [(lambda d, c: (d.ellipse([9, 11, 14, 17], fill=c), d.ellipse([18, 11, 23, 17], fill=c)), INK),
                                   (lambda d, c: d.polygon([(16, 17), (14, 21), (18, 21)], fill=c), INK),
                                   (lambda d, c: [d.line([(x, 23), (x, 28)], fill=c, width=1) for x in (13, 16, 19)], BONE[2])])


def ic_boss():
    parts = [Part(lambda d: d.polygon([(7, 12), (1, 9), (2, 1), (8, 6), (11, 10)], fill=255), GOLD, 1),
             Part(lambda d: d.polygon([(25, 12), (31, 9), (30, 1), (24, 6), (21, 10)], fill=255), GOLD, 1)] + skull_parts(BONE)
    parts[2].fn = lambda d: d.ellipse([6, 6, 26, 23], fill=255)
    parts[3].fn = lambda d: d.rectangle([10, 18, 22, 29], fill=255)
    return compose(parts, [(lambda d, c: d.polygon([(9, 11), (14, 14), (14, 17), (9, 16)], fill=c), RED[0]),
                           (lambda d, c: d.polygon([(23, 11), (18, 14), (18, 17), (23, 16)], fill=c), RED[0]),
                           (lambda d, c: d.polygon([(16, 18), (14, 22), (18, 22)], fill=c), INK),
                           (lambda d, c: [d.line([(x, 24), (x, 29)], fill=c, width=1) for x in (13, 16, 19)], BONE[2])])


def ic_elite():
    parts = [Part(lambda d: d.polygon([(3, 8), (9, 15), (16, 4), (23, 15), (29, 8), (27, 25), (5, 25)], fill=255), GOLD),
             Part(lambda d: d.rectangle([5, 22, 27, 27], fill=255), ORANGE, 1)]
    return compose(parts, [(lambda d, c: [d.rectangle([x, 23, x + 1, 25], fill=c) for x in (9, 15, 21)], RED[0]),
                           (lambda d, c: [d.rectangle([x, y, x + 1, y + 1], fill=c) for x, y in ((3, 6), (15, 2), (28, 6))], YELLOW[1])])


def ic_burn():
    parts = [Part(flame_fn(16, 29, 24, 27), FLAME),
             Part(flame_fn(16, 29, 11, 13), YELLOW, 1)]
    return compose(parts)


def ic_slow():
    parts = [Part(lambda d: d.polygon([(2, 28), (24, 28), (28, 22), (28, 14), (25, 14), (25, 22), (4, 22)], fill=255), GREEN),
             Part(lambda d: d.ellipse([7, 4, 24, 24], fill=255), WOOD),
             Part(lambda d: [d.line([(26, 14), (26, 6)], fill=255, width=1), d.line([(29, 15), (30, 8)], fill=255, width=1)], GREEN, 1)]
    return compose(parts, [(lambda d, c: d.arc([11, 8, 20, 19], start=0, end=270, fill=c, width=1), WOOD[2]),
                           (lambda d, c: d.rectangle([26, 17, 27, 18], fill=c), INK)])


def ic_freeze():
    parts = [Part(lambda d: d.polygon([(16, 3), (28, 9), (28, 23), (16, 29), (4, 23), (4, 9)], fill=255), ICE)]
    return compose(parts, [(lambda d, c: d.polygon([(16, 3), (28, 9), (16, 15), (4, 9)], fill=c), ICE[1]),
                           (lambda d, c: d.line([(16, 15), (16, 29)], fill=c, width=1), ICE[2]),
                           (lambda d, c: d.rectangle([8, 10, 10, 12], fill=c), (255, 255, 255, 255))])


def ic_repair():
    parts = [Part(lambda d: d.line([(8, 27), (21, 12)], fill=255, width=4), WOOD, 1),
             Part(lambda d: d.polygon([(15, 3), (28, 8), (25, 16), (12, 11)], fill=255), STEEL)]
    return compose(parts)


def ic_chest():
    parts = [Part(lambda d: d.rectangle([3, 13, 28, 28], fill=255), WOOD),
             Part(lambda d: d.pieslice([3, 3, 28, 24], start=180, end=360, fill=255), WOOD),
             Part(lambda d: d.rectangle([3, 13, 28, 15], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([13, 5, 18, 28], fill=255), GOLD, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([14, 15, 17, 19], fill=c), INK)])


def ic_meat():
    parts = [Part(lambda d: d.polygon([(19, 20), (25, 26), (28, 25), (29, 28), (26, 30), (24, 28), (22, 29), (16, 24)], fill=255), BONE, 1),
             Part(lambda d: d.ellipse([3, 3, 22, 22], fill=255), RED)]
    return compose(parts, [(lambda d, c: d.ellipse([8, 8, 13, 12], fill=c), RED[1]),
                           (lambda d, c: d.arc([6, 6, 19, 19], start=20, end=110, fill=c, width=1), RED[2])])


def ic_timer():
    parts = [Part(lambda d: d.rectangle([5, 2, 26, 6], fill=255), WOOD, 1),
             Part(lambda d: d.rectangle([5, 26, 26, 30], fill=255), WOOD, 1),
             Part(lambda d: d.polygon([(7, 6), (25, 6), (25, 10), (18, 16), (25, 22), (25, 26), (7, 26), (7, 22), (14, 16), (7, 10)], fill=255), ICE)]
    return compose(parts, [(lambda d, c: d.polygon([(11, 22), (21, 22), (16, 18)], fill=c), GOLD[0]),
                           (lambda d, c: d.polygon([(10, 8), (22, 8), (16, 13)], fill=c), GOLD[0])])


V1_ICONS = {
    "arrow_storm": ic_arrow_storm, "frost_nova": ic_frost_nova, "firebomb": ic_firebomb, "war_horn": ic_war_horn,
    "flame_arrows": ic_flame_arrows, "frost_arrows": ic_frost_arrows, "whirling_axes": ic_whirling_axes,
    "dynamite_satchel": ic_dynamite_satchel, "storm_bolt": ic_storm_bolt, "caltrops": ic_caltrops,
    "sacred_ground": ic_sacred_ground,
    "ballista": ic_ballista, "catapult": ic_catapult, "frost_ward": ic_frost_ward, "spiked_palisade": ic_spiked_palisade,
    "fleet_step": ic_fleet_step, "battle_focus": ic_battle_focus, "blast_radius": ic_blast_radius, "keen_eye": ic_keen_eye,
    "leather_armor": ic_leather_armor, "ability_power": ic_ability_power, "stone_mason": ic_stone_mason,
    "rapid_fire": ic_rapid_fire, "heavy_rounds": ic_heavy_rounds, "patch_kit": ic_patch_kit, "swift_feet": ic_swift_feet,
    "vitality": ic_vitality, "magnet": ic_magnet, "regeneration": ic_regeneration, "piercing_arrows": ic_piercing_arrows,
    "multishot": ic_multishot, "caliber": ic_caliber, "optics": ic_optics, "shield_matrix": ic_shield_matrix,
    "reinforced_plating": ic_reinforced_plating, "watchtower_upgrade": ic_watchtower_upgrade, "tower_volley": ic_tower_volley,
    "repair_kit": ic_repair_kit, "overdrive_fallback": ic_overdrive_fallback, "reinforce_fallback": ic_reinforce_fallback,
    "recruit": ic_recruit, "soldier": ic_soldier, "veteran": ic_veteran, "warlord": ic_warlord,
    "dash": ic_dash, "kills": ic_kills, "elite": ic_elite, "boss": ic_boss, "burn": ic_burn, "slow": ic_slow,
    "freeze": ic_freeze, "repair": ic_repair, "chest": ic_chest, "meat": ic_meat, "timer": ic_timer,
}


# --- Arena boon icons (WP-ARENA, docs/32 section B) -------------------------------
# War: crossed blades over red; Haste: winged boot; Ward: kite shield; Bounty: coin stack.

def ic_boon_war():
    parts = [Part(lambda d: d.line([(6, 26), (24, 6)], fill=255, width=4), STEEL, 1),
             Part(lambda d: d.line([(26, 26), (8, 6)], fill=255, width=4), STEEL, 1),
             Part(lambda d: d.ellipse([10, 10, 22, 22], fill=255), RED)]
    return compose(parts, [(lambda d, c: d.polygon([(16, 12), (19, 17), (16, 21), (13, 17)], fill=c), RED[1])])


def ic_boon_haste():
    parts = [Part(lambda d: d.polygon([(10, 8), (18, 8), (18, 17), (27, 21), (27, 27), (8, 27), (8, 17)], fill=255), BLUE),
             Part(lambda d: d.polygon([(4, 12), (11, 9), (9, 16), (3, 17)], fill=255), BONE, 1),
             Part(lambda d: d.polygon([(2, 18), (9, 17), (8, 23), (1, 22)], fill=255), BONE, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([9, 24, 26, 26], fill=c), BLUE[2])])


def ic_boon_ward():
    parts = [Part(lambda d: d.polygon([(5, 5), (27, 5), (27, 17), (16, 29), (5, 17)], fill=255), BLUE),
             Part(lambda d: d.polygon([(9, 9), (23, 9), (23, 16), (16, 24), (9, 16)], fill=255), STEEL, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([15, 10, 17, 22], fill=c), BLUE[0]),
                           (lambda d, c: d.rectangle([10, 13, 22, 15], fill=c), BLUE[0])])


def ic_boon_bounty():
    parts = [Part(lambda d: d.ellipse([3, 17, 20, 29], fill=255), GOLD),
             Part(lambda d: d.ellipse([12, 14, 29, 26], fill=255), GOLD),
             Part(lambda d: d.ellipse([8, 4, 25, 16], fill=255), GOLD)]
    return compose(parts, [(lambda d, c: d.rectangle([15, 7, 17, 13], fill=c), GOLD[2]),
                           (lambda d, c: d.rectangle([13, 8, 19, 9], fill=c), GOLD[2])])


ARENA_ICONS = {"boon_war": ic_boon_war, "boon_haste": ic_boon_haste, "boon_ward": ic_boon_ward, "boon_bounty": ic_boon_bounty}

# --- WP-LOADOUT: Champion emblems and Relic icons (docs/32 section C) -----------------
# Champions are hooded bust portraits in the in-game palette shift (Ranger blue, Warden
# bronze, Skirmisher silver, Pactbound ash); the silhouette differs too (feather, crenel
# crown, swept hood tail, horns), so colour is never the only cue.

SKIN = pal((236, 190, 150), (255, 222, 190), (190, 140, 104))
SILVER = pal((226, 232, 242), (255, 255, 255), (156, 166, 186))
ASH = pal((92, 90, 104), (138, 136, 154), (54, 52, 66))
WARDEN_BRONZE = pal((176, 112, 52), (226, 162, 92), (118, 70, 32))


def hooded_bust(hood_pal):
    return [Part(lambda d: d.rectangle([5, 17, 27, 30], fill=255), hood_pal),
            Part(lambda d: d.ellipse([5, 3, 27, 26], fill=255), hood_pal)]


def face_details(eye=INK):
    return [(lambda d, c: d.ellipse([9, 10, 23, 24], fill=c), SKIN[0]),
            (lambda d, c: d.ellipse([9, 10, 23, 17], fill=c), SKIN[1]),
            (lambda d, c: [d.rectangle([12, 16, 13, 18], fill=c), d.rectangle([18, 16, 19, 18], fill=c)], eye)]


def ic_champion_ranger():
    parts = hooded_bust(BLUE) + [Part(lambda d: d.polygon([(20, 7), (30, 0), (28, 10), (23, 11)], fill=255), GREEN, 1)]
    return compose(parts, face_details())


def ic_champion_warden():
    parts = hooded_bust(WARDEN_BRONZE) + [
        Part(lambda d: [d.rectangle([x, 0, x + 3, 6], fill=255) for x in (6, 14, 22)], STONE, 1),
        Part(lambda d: d.rectangle([6, 5, 25, 8], fill=255), STONE, 1)]
    return compose(parts, face_details() + [(lambda d, c: d.polygon([(11, 25), (21, 25), (21, 29), (16, 31), (11, 29)], fill=c), STONE[1])])


def ic_champion_skirmisher():
    parts = [Part(lambda d: d.polygon([(8, 10), (0, 15), (8, 21)], fill=255), SILVER, 1)] + hooded_bust(SILVER) + [
        Part(lambda d: [d.line([(26, 12), (31, 12)], fill=255, width=2), d.line([(27, 19), (31, 19)], fill=255, width=2)], BLUE, 1)]
    return compose(parts, face_details())


def ic_champion_pactbound():
    parts = [Part(lambda d: d.polygon([(7, 11), (1, 9), (2, 1), (8, 6), (11, 10)], fill=255), BONE, 1),
             Part(lambda d: d.polygon([(25, 11), (31, 9), (30, 1), (24, 6), (21, 10)], fill=255), BONE, 1)] + hooded_bust(ASH)
    return compose(parts, face_details(GOLD[1]))


def ic_relic_quiver_of_echoes():
    parts = [Part(lambda d: d.line([(9, 6), (22, 27)], fill=255, width=11), WOOD),
             Part(lambda d: [d.line([(x, 7), (x + 6, 0)], fill=255, width=2) for x in (10, 14, 18)], STEEL, 1),
             Part(lambda d: d.line([(8, 12), (22, 22)], fill=255, width=2), GOLD, 1)]
    return compose(parts, [(lambda d, c: d.arc([20, 2, 31, 16], start=-60, end=60, fill=c, width=1), BLUE[1]),
                           (lambda d, c: d.arc([24, 0, 34, 18], start=-60, end=60, fill=c, width=1), BLUE[1])])


def ic_relic_masons_trowel():
    parts = [Part(lambda d: d.line([(6, 27), (15, 18)], fill=255, width=5), WOOD, 1),
             Part(lambda d: d.polygon([(13, 16), (20, 9), (29, 2), (27, 12), (21, 19)], fill=255), STEEL),
             Part(lambda d: d.rectangle([11, 17, 15, 20], fill=255), IRON, 1)]
    return compose(parts, [(lambda d, c: d.line([(15, 14), (26, 4)], fill=c, width=1), STEEL[1])])


def ic_relic_hunters_charm():
    parts = [Part(lambda d: d.ellipse([9, 1, 23, 13], outline=255, width=2), WOOD, 1),
             Part(lambda d: d.polygon([(16, 12), (24, 14), (22, 22), (16, 30), (11, 22), (9, 14)], fill=255), BONE)]
    return compose(parts, [(lambda d, c: d.line([(13, 16), (15, 24)], fill=c, width=1), BONE[2]),
                           (lambda d, c: d.ellipse([14, 13, 18, 17], fill=c), GREEN[0])])


def ic_relic_warchiefs_horn():
    def horn(d):
        pts_l, pts_r = [], []
        n = 24
        for i in range(n + 1):
            t = i / n
            x = (1 - t) ** 2 * 5 + 2 * t * (1 - t) * 4 + t * t * 26
            y = (1 - t) ** 2 * 5 + 2 * t * (1 - t) * 27 + t * t * 22
            tx = 2 * (1 - t) * (4 - 5) + 2 * t * (26 - 4)
            ty = 2 * (1 - t) * (27 - 5) + 2 * t * (22 - 27)
            L = math.hypot(tx, ty)
            w = 1.8 + 8.5 * t ** 2.2
            pts_l.append((x - ty / L * w, y + tx / L * w))
            pts_r.append((x + ty / L * w, y - tx / L * w))
        d.polygon(pts_l + pts_r[::-1], fill=255)
    parts = [Part(horn, IRON),
             Part(lambda d: d.rectangle([1, 2, 8, 6], fill=255), GREEN, 1),
             Part(lambda d: d.polygon([(21, 11), (28, 15), (30, 27), (24, 30)], fill=255), GREEN, 1),
             Part(lambda d: d.polygon([(10, 26), (13, 31), (16, 26)], fill=255), BONE, 1)]
    return compose(parts, [(lambda d, c: d.ellipse([16, 17, 19, 20], fill=c), RED[1])])


def ic_relic_kings_crown():
    parts = [Part(lambda d: d.polygon([(3, 9), (9, 15), (16, 3), (23, 15), (29, 9), (27, 26), (5, 26)], fill=255), GOLD),
             Part(lambda d: d.rectangle([5, 23, 27, 28], fill=255), RED, 1),
             Part(lambda d: d.ellipse([12, 13, 20, 21], fill=255), IRON)]
    return compose(parts, [(lambda d, c: d.line([(16, 13), (18, 10)], fill=c, width=1), BONE[0]),
                           (lambda d, c: d.rectangle([17, 8, 19, 10], fill=c), YELLOW[0]),
                           (lambda d, c: d.rectangle([13, 14, 14, 15], fill=c), IRON[1])])


def ic_relic_lucky_coin():
    parts = [Part(lambda d: d.ellipse([3, 3, 28, 28], fill=255), GOLD)]
    return compose(parts, [(lambda d, c: d.ellipse([7, 7, 24, 24], outline=c, width=2), GOLD[2]),
                           (lambda d, c: [d.ellipse(b, fill=c) for b in ([10, 10, 16, 16], [16, 10, 22, 16], [10, 16, 16, 22], [16, 16, 22, 22])], GREEN[0]),
                           (lambda d, c: d.rectangle([15, 15, 16, 16], fill=c), GOLD[1]),
                           (lambda d, c: d.line([(8, 6), (14, 4)], fill=c, width=1), GOLD[1])])


def ic_relic_iron_banner():
    parts = [Part(lambda d: d.rectangle([5, 2, 8, 30], fill=255), IRON, 1),
             Part(lambda d: d.polygon([(8, 4), (28, 4), (28, 21), (18, 17), (8, 21)], fill=255), RED),
             Part(lambda d: d.polygon([(2, 2), (11, 2), (6, -1)], fill=255), STEEL, 1)]
    return compose(parts, [(lambda d, c: d.rectangle([8, 4, 28, 6], fill=c), GOLD[0]),
                           (lambda d, c: d.polygon([(18, 9), (22, 12), (18, 15), (14, 12)], fill=c), GOLD[1])])


def ic_relic_ember_heart():
    pts = []
    for i in range(60):
        t = math.tau * i / 60
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, -y))
    minx = min(p[0] for p in pts); maxx = max(p[0] for p in pts)
    miny = min(p[1] for p in pts); maxy = max(p[1] for p in pts)
    unit = [((x - minx) / (maxx - minx), (y - miny) / (maxy - miny)) for x, y in pts]
    upts = unit_poly(unit, (3, 8, 29, 30))
    parts = [Part(lambda d: d.polygon(upts, fill=255), RED),
             Part(flame_fn(16, 14, 12, 13), FLAME, 1),
             Part(flame_fn(16, 14, 5, 7), YELLOW, 1)]
    return compose(parts, [(lambda d, c: [d.rectangle([x, y, x + 1, y + 1], fill=c) for x, y in ((6, 13), (24, 15), (20, 3))], YELLOW[1])])


LOADOUT_ICONS = {
    "champion_ranger": ic_champion_ranger, "champion_warden": ic_champion_warden,
    "champion_skirmisher": ic_champion_skirmisher, "champion_pactbound": ic_champion_pactbound,
    "relic_quiver_of_echoes": ic_relic_quiver_of_echoes, "relic_masons_trowel": ic_relic_masons_trowel,
    "relic_hunters_charm": ic_relic_hunters_charm, "relic_warchiefs_horn": ic_relic_warchiefs_horn,
    "relic_kings_crown": ic_relic_kings_crown, "relic_lucky_coin": ic_relic_lucky_coin,
    "relic_iron_banner": ic_relic_iron_banner, "relic_ember_heart": ic_relic_ember_heart,
}


def make_contact_sheet(icons, path, cols=8, zoom=4):
    from PIL import ImageFont
    cw, ch = S * zoom + 16, S * zoom + 38
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (96, 120, 84, 255))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for i, (name, im) in enumerate(icons.items()):
        x, y = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(im.resize((S * zoom, S * zoom), Image.NEAREST), (x + 8, y + 4))
        sheet.alpha_composite(im, (x + 8, y + 4 + S * zoom + 2))
        d.text((x + 44, y + 4 + S * zoom + 6), name, fill=(255, 255, 255, 255), font=font)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)
    print("wrote", path, sheet.size)


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("wrote", path, im.size)


if __name__ == "__main__":
    icons = {
        "triangle": make_triangle(), "square": make_square(), "heart": make_heart(),
        "tower": make_tower(), "recycle": make_recycle(), "crystal": make_crystal_icon(),
        "core": make_hex(), "coin": make_coin(), "arrow": make_arrow(), "boot": make_boot(),
        "tent": make_tent(),
    }
    for name, im in icons.items():
        save(im, "assets/ui/icons/icon_%s.png" % name)
    save(make_pointer_east(), "assets/ui/icons/pointer_east.png")
    save(make_exclaim(), "assets/ui/telegraph_exclaim.png")
    save(make_ring_sheet(), "assets/ui/telegraph_ring.png")
    save(make_xp_crystal(), "assets/sprites/pickup_xp_crystal.png")
    v1 = {}
    for name, fn in V1_ICONS.items():
        v1[name] = fn()
        save(v1[name], "assets/ui/icons/icon_%s.png" % name)
    make_contact_sheet(v1, "assets/ui/icons/_contact_sheet_v1.png")
    arena = {}
    for name, fn in ARENA_ICONS.items():
        arena[name] = fn()
        save(arena[name], "assets/ui/icons/icon_%s.png" % name)
    make_contact_sheet(arena, "assets/ui/icons/_contact_sheet_arena.png", cols=4)
    loadout = {}
    for name, fn in LOADOUT_ICONS.items():
        loadout[name] = fn()
        save(loadout[name], "assets/ui/icons/icon_%s.png" % name)
    make_contact_sheet(loadout, "assets/ui/icons/_contact_sheet_loadout.png", cols=6)

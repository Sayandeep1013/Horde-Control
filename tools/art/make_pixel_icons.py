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

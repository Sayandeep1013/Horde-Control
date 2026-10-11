"""Project-made v1.0 world sprites (decision D182, docs/31 section 9).

Pack style (Tiny Swords): 2 px ink outline (22,28,46), flat 3-tone fills, no
antialiasing, nearest filtering. Reuses the compose()/Part helpers from
make_pixel_icons.py.

Run from the repository root:  python tools/art/make_v1_sprites.py
Writes assets/sprites/v1/*.png and assets/sprites/v1/_contact_sheet.png.
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_pixel_icons import (  # noqa: E402
    Part, compose, INK, STEEL, IRON, WOOD, GOLD, ORANGE, ICE, STONE, RED, BONE, YELLOW, FLAME, pal,
)

OUT = "assets/sprites/v1"
DARKBLUE = (24, 54, 104, 255)


def make_axe():
    size = (28, 28)
    parts = [Part(lambda d: d.line([(8, 24), (19, 8)], fill=255, width=3), WOOD, 1),
             Part(lambda d: d.polygon([(11, 3), (24, 4), (25, 12), (19, 15), (19, 10), (12, 8)], fill=255), STEEL),
             Part(lambda d: d.rectangle([6, 22, 10, 25], fill=255), IRON, 1)]
    return compose(parts, size=size)


def make_caltrop():
    size = (16, 16)
    parts = [Part(lambda d: d.polygon([(8, 2), (10, 8), (6, 8)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(2, 12), (8, 7), (9, 10)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(14, 12), (8, 7), (7, 10)], fill=255), STEEL, 1),
             Part(lambda d: d.ellipse([6, 6, 10, 10], fill=255), IRON, 1)]
    return compose(parts, size=size)


def make_frost_shard():
    size = (20, 20)
    parts = [Part(lambda d: d.polygon([(10, 1), (15, 8), (12, 19), (8, 19), (5, 8)], fill=255), ICE),
             Part(lambda d: d.polygon([(10, 1), (15, 8), (10, 10), (5, 8)], fill=255), ICE, 1)]
    return compose(parts, [(lambda d, c: d.line([(9, 4), (9, 10)], fill=c, width=1), (255, 255, 255, 255))], size=size)


def make_lightning_segment():
    """32x12, tileable horizontally: the bolt leaves the left edge and enters
    the right edge at the same y, and the jag pattern has period 32."""
    w, h = 32, 12
    base_pts = [(0, 6), (7, 3.5), (13, 8.5), (21, 3.8), (27, 8), (32, 6)]
    pts = []
    for k in (-1, 0, 1):
        pts += [(x + k * w, y) for x, y in base_pts]
    big = Image.new("RGBA", (w * 3, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.line([(x + w, y) for x, y in pts], fill=DARKBLUE, width=7, joint="curve")
    d.line([(x + w, y) for x, y in pts], fill=(120, 220, 255, 255), width=5, joint="curve")
    d.line([(x + w, y) for x, y in pts], fill=(255, 255, 255, 255), width=2, joint="curve")
    return big.crop((w, 0, 2 * w, h))


def make_ballista_bolt():
    size = (40, 8)
    parts = [Part(lambda d: d.line([(3, 4), (28, 4)], fill=255, width=2), WOOD, 1),
             Part(lambda d: d.polygon([(37, 4), (28, 2), (28, 6)], fill=255), STEEL, 1),
             Part(lambda d: d.polygon([(2, 4), (7, 2), (9, 4), (7, 6)], fill=255), ORANGE, 1)]
    # a 2 px outline on an 8 px high canvas leaves 4 px: keep the shape inside rows 2..5
    return compose(parts, size=size)


def make_catapult_rock():
    size = (22, 22)
    pts = [(11, 2), (17, 4), (20, 10), (18, 17), (12, 20), (5, 18), (2, 11), (5, 5)]
    parts = [Part(lambda d: d.polygon(pts, fill=255), STONE)]
    return compose(parts, [(lambda d, c: d.line([(8, 7), (11, 12), (9, 16)], fill=c, width=1), STONE[2]),
                           (lambda d, c: d.rectangle([14, 6, 16, 8], fill=c), STONE[1])], size=size)


def chest_parts(open_lid):
    parts = [Part(lambda d: d.rectangle([4, 14, 35, 29], fill=255), WOOD),
             Part(lambda d: d.rectangle([4, 14, 35, 17], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([4, 25, 35, 28], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([17, 14, 22, 29], fill=255), GOLD, 1)]
    if open_lid:
        parts = [Part(lambda d: d.pieslice([6, 0, 33, 14], start=180, end=360, fill=255), WOOD, 1)] + parts[:1] + [
            Part(lambda d: d.rectangle([6, 12, 33, 15], fill=255), GOLD, 1)] + parts[1:]
    else:
        parts.insert(1, Part(lambda d: d.pieslice([4, 1, 35, 26], start=180, end=360, fill=255), WOOD))
        parts.insert(2, Part(lambda d: d.rectangle([4, 13, 35, 16], fill=255), GOLD, 1))
        parts.insert(3, Part(lambda d: d.rectangle([17, 3, 22, 16], fill=255), GOLD, 1))
    return parts


def make_war_chest():
    return compose(chest_parts(False), [(lambda d, c: d.rectangle([18, 19, 21, 23], fill=c), INK)], size=(40, 32))


def make_war_chest_open():
    dark = pal((70, 46, 28), (90, 62, 38), (50, 32, 20))
    parts = [Part(lambda d: d.rectangle([6, 8, 33, 14], fill=255), dark, 1),
             Part(lambda d: d.rectangle([4, 14, 35, 29], fill=255), WOOD),
             Part(lambda d: d.rectangle([4, 25, 35, 28], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([17, 14, 22, 29], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([4, 13, 35, 15], fill=255), GOLD, 1),
             Part(lambda d: d.rectangle([6, 3, 33, 8], fill=255), WOOD),   # raised lid, seen edge-on
             Part(lambda d: d.rectangle([6, 3, 33, 4], fill=255), GOLD, 1)]
    det = [(lambda d, c: [d.ellipse([x, 8, x + 5, 13], fill=c) for x in (8, 14, 20, 26)], GOLD[0] + (255,)),
           (lambda d, c: [d.rectangle([x, 9, x + 1, 10], fill=c) for x in (9, 15, 21, 27)], GOLD[1] + (255,))]
    return compose(parts, det, size=(40, 32))


def make_burn_ground():
    w, h = 64, 32
    rng = random.Random(7)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cx, cy = 32, 16
    for y in range(h):
        for x in range(w):
            u = ((x + 0.5 - cx) / 30) ** 2 + ((y + 0.5 - cy) / 14) ** 2
            jag = 1.0 + 0.12 * math.sin(math.atan2(y - cy, x - cx) * 7) + 0.08 * math.sin(math.atan2(y - cy, x - cx) * 13 + 1)
            if u <= jag ** 2:
                v = u / jag ** 2
                col = (34, 26, 28, 255) if v > 0.55 else (22, 18, 22, 255)
                im.putpixel((x, y), col)
    for _ in range(34):
        x, y = rng.randint(8, 55), rng.randint(6, 25)
        if im.getpixel((x, y))[3] > 0:
            im.putpixel((x, y), (255, 150, 50, 255) if rng.random() < 0.6 else (255, 210, 90, 255))
            if rng.random() < 0.4:
                im.putpixel((x + 1, y), (200, 80, 30, 255))
    return im


SPRITES = {
    "axe": make_axe, "caltrop": make_caltrop, "frost_shard": make_frost_shard,
    "lightning_segment": make_lightning_segment, "ballista_bolt": make_ballista_bolt,
    "catapult_rock": make_catapult_rock, "war_chest": make_war_chest,
    "war_chest_open": make_war_chest_open, "burn_ground": make_burn_ground,
}


def contact_sheet(sprites, path, zoom=4):
    font = ImageFont.load_default()
    pad = 12
    cells = []
    for name, im in sprites.items():
        z = im.resize((im.width * zoom, im.height * zoom), Image.NEAREST)
        cells.append((name, im, z))
    cols = 3
    cw = max(c[2].width for c in cells) + pad * 2
    rows = (len(cells) + cols - 1) // cols
    rh = max(c[2].height for c in cells) + 56
    sheet = Image.new("RGBA", (cols * cw, rows * rh), (96, 120, 84, 255))
    d = ImageDraw.Draw(sheet)
    for i, (name, im, z) in enumerate(cells):
        x, y = (i % cols) * cw + pad, (i // cols) * rh + pad
        sheet.alpha_composite(z, (x, y))
        sheet.alpha_composite(im, (x, y + z.height + 6))
        if name == "lightning_segment":  # tiling proof: three side by side at 1x
            for k in range(1, 3):
                sheet.alpha_composite(im, (x + k * im.width, y + z.height + 6))
        d.text((x, y + z.height + 24), "%s %dx%d" % (name, im.width, im.height), fill=(255, 255, 255, 255), font=font)
    sheet.save(path)
    print("wrote", path, sheet.size)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for name, fn in SPRITES.items():
        im = fn()
        im.save(os.path.join(OUT, name + ".png"))
        made[name] = im
        print("wrote", os.path.join(OUT, name + ".png"), im.size)
    contact_sheet(made, os.path.join(OUT, "_contact_sheet.png"))

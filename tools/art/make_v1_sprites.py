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


# ---------------------------------------------------------------------------
# Arena interactables (WP-ARENA, docs/32 section B): crate, powder keg, shrine,
# spike trap. Same compose() pipeline; drawn at native size, nearest filter.
# ---------------------------------------------------------------------------
KEG = pal((150, 52, 46), (212, 96, 78), (96, 30, 32))      # danger red wood
DARKWOOD = pal((120, 78, 44), (170, 120, 70), (78, 48, 28))
RUNE = pal((120, 214, 236), (214, 250, 255), (64, 150, 196))


def make_crate():
    parts = [Part(lambda d: d.rectangle([5, 9, 34, 34], fill=255), WOOD),
             Part(lambda d: d.rectangle([5, 9, 34, 13], fill=255), DARKWOOD, 1),      # lid rim
             Part(lambda d: d.rectangle([5, 30, 34, 34], fill=255), DARKWOOD, 1)]    # base rim
    det = [(lambda d, c: d.line([(8, 15), (31, 28)], fill=c, width=2), WOOD[2] + (255,)),
           (lambda d, c: d.line([(31, 15), (8, 28)], fill=c, width=2), WOOD[2] + (255,)),
           (lambda d, c: d.line([(20, 14), (20, 29)], fill=c, width=1), WOOD[2] + (255,)),
           (lambda d, c: [d.rectangle([x, y, x + 1, y + 1], fill=c) for x in (7, 31) for y in (11, 31)], GOLD[1] + (255,)),
           (lambda d, c: d.rectangle([17, 20, 22, 23], fill=c), GOLD[0] + (255,))]
    return compose(parts, det, size=(40, 40))


def make_crate_broken():
    parts = [Part(lambda d: d.polygon([(4, 26), (17, 22), (20, 28), (8, 33)], fill=255), WOOD, 1),
             Part(lambda d: d.polygon([(21, 24), (35, 27), (33, 33), (22, 31)], fill=255), DARKWOOD, 1),
             Part(lambda d: d.polygon([(12, 32), (28, 33), (27, 37), (13, 37)], fill=255), WOOD, 1),
             Part(lambda d: d.polygon([(15, 14), (19, 12), (21, 21), (17, 22)], fill=255), WOOD, 1),
             Part(lambda d: d.polygon([(26, 15), (30, 17), (27, 24), (24, 22)], fill=255), DARKWOOD, 1)]
    return compose(parts, [(lambda d, c: d.line([(6, 28), (17, 25)], fill=c, width=1), WOOD[2] + (255,)),
                           (lambda d, c: d.rectangle([14, 33, 16, 34], fill=c), GOLD[1] + (255,))], size=(40, 40))


def _keg_parts():
    return [Part(lambda d: d.rounded_rectangle([3, 12, 32, 40], radius=10, fill=255), KEG),
            Part(lambda d: d.rectangle([4, 18, 31, 21], fill=255), IRON, 1),
            Part(lambda d: d.rectangle([4, 31, 31, 34], fill=255), IRON, 1),
            Part(lambda d: d.rectangle([14, 6, 21, 13], fill=255), DARKWOOD, 1)]   # stopper


def make_powder_keg():
    det = [(lambda d, c: d.line([(17, 6), (19, 2), (23, 1)], fill=c, width=1), (230, 220, 190, 255)),     # unlit fuse
           (lambda d, c: d.ellipse([14, 22, 21, 29], fill=c), BONE[0] + (255,)),                           # skull plate
           (lambda d, c: [d.rectangle([x, 24, x + 1, 25], fill=c) for x in (15, 19)], INK),
           (lambda d, c: d.rectangle([16, 27, 19, 28], fill=c), INK)]
    return compose(_keg_parts(), det, size=(36, 44))


def make_powder_keg_lit():
    """Lit: white-hot body flash on the rim and a bright burning fuse spark."""
    im = make_powder_keg()
    hot = (255, 238, 170, 255)
    for (x, y) in [(6, 22), (7, 21), (28, 22), (29, 23), (8, 14), (27, 15), (6, 30), (29, 31)]:
        im.putpixel((x, y), hot)
    spark = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(spark)
    d.polygon([(23, 0), (26, 3), (23, 6), (20, 3)], fill=(255, 208, 80, 255))
    d.polygon([(23, 1), (25, 3), (23, 5), (21, 3)], fill=(255, 255, 220, 255))
    im.alpha_composite(spark)
    return im


def make_shrine():
    parts = [Part(lambda d: d.rectangle([4, 62, 43, 75], fill=255), STONE),                          # plinth
             Part(lambda d: d.rectangle([9, 54, 38, 62], fill=255), STONE, 1),
             Part(lambda d: d.polygon([(16, 54), (31, 54), (29, 14), (23, 2), (18, 14)], fill=255), IRON)]
    det = [(lambda d, c: d.polygon([(23, 22), (27, 30), (23, 40), (19, 30)], fill=c), RUNE[0] + (255,)),
           (lambda d, c: d.polygon([(23, 25), (25, 30), (23, 36), (21, 30)], fill=c), RUNE[1] + (255,)),
           (lambda d, c: d.line([(23, 43), (23, 52)], fill=c, width=1), RUNE[2] + (255,)),
           (lambda d, c: d.line([(11, 66), (36, 66)], fill=c, width=1), STONE[1] + (255,))]
    return compose(parts, det, size=(48, 80))


def _trap_base(tips, glow):
    """64x40 top-down plate. tips: 0 none, 1 peeking, 2 raised."""
    plate = STONE if not glow else pal((196, 70, 60), (250, 130, 106), (136, 40, 42))
    parts = [Part(lambda d: d.rounded_rectangle([4, 6, 59, 33], radius=5, fill=255), plate, 2)]
    pts = [(x, y) for x in (16, 32, 48) for y in (14, 25)]
    det = [(lambda d, c: [d.ellipse([x - 3, y - 2, x + 3, y + 2], fill=c) for (x, y) in pts], INK)]
    im = compose(parts, det, size=(64, 40))
    layer = Image.new("RGBA", (64, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    h = {0: 0, 1: 8, 2: 13}[tips]
    for (x, y) in pts:
        if h:
            d.polygon([(x - 3, y + 2), (x + 3, y + 2), (x, y + 2 - h)], fill=STEEL[1] if (tips == 2 or glow) else STEEL[0], outline=INK)
    im.alpha_composite(layer)
    return im


def make_spike_trap_0():
    return _trap_base(0, False)


def make_spike_trap_1():
    return _trap_base(1, False)


def make_spike_trap_2():
    return _trap_base(2, False)


def make_spike_trap_3():
    return _trap_base(1, True)


ARENA_SPRITES = {
    "crate": make_crate, "crate_broken": make_crate_broken, "powder_keg": make_powder_keg,
    "powder_keg_lit": make_powder_keg_lit, "shrine": make_shrine,
    "spike_trap_0": make_spike_trap_0, "spike_trap_1": make_spike_trap_1,
    "spike_trap_2": make_spike_trap_2, "spike_trap_3": make_spike_trap_3,
}


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
    # Arena interactables (WP-ARENA) are kept apart so the sprites above and their sheet stay byte-identical.
    arena = {}
    for name, fn in ARENA_SPRITES.items():
        im = fn()
        im.save(os.path.join(OUT, name + ".png"))
        arena[name] = im
        print("wrote", os.path.join(OUT, name + ".png"), im.size)
    contact_sheet(arena, os.path.join(OUT, "_contact_sheet_arena.png"))

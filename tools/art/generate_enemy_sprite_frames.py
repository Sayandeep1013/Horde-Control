"""Generates SpriteFrames .tres resources for the three prototype enemies and
the shared skull death effect, from the Tiny Swords CC0 sheets already in
`assets/third_party/tiny_swords/` (see that directory's own PROVENANCE.md for
the frame-size/row layout table this script transcribes below).

WHY A GENERATOR, NOT HAND-WRITTEN .tres FILES
----------------------------------------------
A Godot 4 SpriteFrames resource is one AtlasTexture sub-resource per frame,
region-cropped from the shared sheet, plus one "animations" entry per row.
Tower Seeker alone is 5 rows / 31 frames; doing that by hand across four
enemies is the exact kind of repetitive, error-prone transcription this
project's own tools/art/generate_sprites.py precedent already avoids for the
placeholder art. Regenerating from this script after any art swap is a single
command, and the diff is reviewable text, not an opaque binary edit.

Run:  python tools/art/generate_enemy_sprite_frames.py
"""

from __future__ import annotations

import os

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO_ROOT, "assets", "sprite_frames")

TS = "res://assets/third_party/tiny_swords"


def _res_path(rel: str) -> str:
    return f"{TS}/{rel}"


class SheetAnim:
    def __init__(self, name: str, row: int, frame_count: int, loop: bool, sheet: str | None = None) -> None:
        # `sheet` (optional) overrides the resource's default sheet for this
        # animation, so one SpriteFrames can mix sheets (meat: spawn + idle).
        self.sheet = sheet
        self.name = name
        self.row = row
        self.frame_count = frame_count
        self.loop = loop


def build_sprite_frames(out_name: str, sheet_res_path: str, frame_size: int, anims: list[SheetAnim], fps: float = 10.0) -> None:
    sheets: list[str] = [sheet_res_path]
    for a in anims:
        if a.sheet is not None and a.sheet not in sheets:
            sheets.append(a.sheet)

    def ext_for(a: "SheetAnim") -> str:
        return "%d_sheet" % (sheets.index(a.sheet or sheet_res_path) + 1)

    lines: list[str] = []
    sub_ids: dict[tuple[int, int], str] = {}

    load_steps = 1  # the main [resource] itself
    load_steps += len(sheets)  # the sheet ExtResource(s)
    total_frames = sum(a.frame_count for a in anims)
    load_steps += total_frames

    lines.append(f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]')
    lines.append("")
    for i, sp in enumerate(sheets):
        lines.append(f'[ext_resource type="Texture2D" path="{sp}" id="{i + 1}_sheet"]')
    lines.append("")

    for anim in anims:
        for col in range(anim.frame_count):
            sub_id = f"AtlasTexture_{anim.name}_{col}"
            sub_ids[(anim.row, col)] = sub_id
            x = col * frame_size
            y = anim.row * frame_size
            lines.append(f'[sub_resource type="AtlasTexture" id="{sub_id}"]')
            lines.append(f'atlas = ExtResource("{ext_for(anim)}")')
            lines.append(f'region = Rect2({x}, {y}, {frame_size}, {frame_size})')
            lines.append("")

    lines.append("[resource]")
    anim_entries: list[str] = []
    for anim in anims:
        frame_dicts = []
        for col in range(anim.frame_count):
            sub_id = sub_ids[(anim.row, col)]
            frame_dicts.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sub_id)
        frames_block = ", ".join(frame_dicts)
        loop_str = "true" if anim.loop else "false"
        entry = (
            "{\n"
            f'"frames": [{frames_block}],\n'
            f'"loop": {loop_str},\n'
            f'"name": &"{anim.name}",\n'
            f'"speed": {fps}\n'
            "}"
        )
        anim_entries.append(entry)
    lines.append("animations = [" + ", ".join(anim_entries) + "]")
    lines.append("")

    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, out_name)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"wrote {out_path} ({total_frames} frames, {len(anims)} animations)")


def main() -> None:
    # Tower Seeker (red, slow melee vs the Tower, 0.4s wind-up).
    # Torch_Red.png: 192x192 frames, 7 cols.
    # row0 idle (7), row1 run (6), row2 attack right (6), row3 attack down (6),
    # row4 attack up (6). Left-facing reuses attack-right, mirrored (flip_h)
    # by src/enemy/enemy_animator.gd -- not a separate row.
    build_sprite_frames(
        "tower_seeker.tres",
        _res_path("Factions/Goblins/Troops/Torch/Red/Torch_Red.png"),
        192,
        [
            SheetAnim("idle", 0, 7, True),
            SheetAnim("run", 1, 6, True),
            SheetAnim("strike_right", 2, 6, False),
            SheetAnim("strike_down", 3, 6, False),
            SheetAnim("strike_up", 4, 6, False),
        ],
    )

    # Player Hunter (yellow, fast, contact damage every 0.5s, no wind-up).
    # TNT_Yellow.png: 192x192 frames, 7 cols.
    # row0 idle (6), row1 run (6), row2 throw (7) -- used as this enemy's
    # single non-directional strike clip (src/enemy/enemy_controller.gd fires
    # attack_resolved with no windup for a Contact enemy; see that file's own
    # header, "Contact behaviour is exempt from windup minimums").
    build_sprite_frames(
        "player_hunter.tres",
        _res_path("Factions/Goblins/Troops/TNT/Yellow/TNT_Yellow.png"),
        192,
        [
            SheetAnim("idle", 0, 6, True),
            SheetAnim("run", 1, 6, True),
            SheetAnim("strike", 2, 7, False),
        ],
    )

    # Opportunist (purple, melee, 0.4s wind-up).
    # Barrel_Purple.png: 128x128 frames, 6 cols.
    # row0 closed (1) used as idle, row1 pop-out (6) used as strike,
    # row4 run (3), row5 explode (3) used as this enemy's own death clip,
    # played before the shared skull FX (see src/fx/death_fx.gd). row2 peek
    # (1) and row3 hide (6) are not used by this prototype's state set.
    build_sprite_frames(
        "opportunist.tres",
        _res_path("Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png"),
        128,
        [
            SheetAnim("idle", 0, 1, True),
            SheetAnim("strike", 1, 6, False),
            SheetAnim("run", 4, 3, True),
            SheetAnim("death", 5, 3, False),
        ],
    )

    # Shared death FX (all enemies): Dead.png, 128x128 frames, 7 cols.
    # row0 skull falls (7), row1 skull dissolves (7). Consumed by
    # scenes/fx/death_fx.tscn / src/fx/death_fx.gd, not by any enemy's own
    # SpriteFrames -- see that file's header for why this lives outside the
    # dying enemy's own pooled instance.
    build_sprite_frames(
        "death_skull.tres",
        _res_path("Factions/Knights/Troops/Dead/Dead.png"),
        128,
        [
            SheetAnim("skull_fall", 0, 7, False),
            SheetAnim("skull_dissolve", 1, 7, False),
        ],
    )

    # --- v1.0 additions (decision D183) -------------------------------------
    # Dynamite.png: 384x64 = 6 frames of 64x64, one row. Thrown dynamite spin.
    build_sprite_frames(
        "dynamite.tres",
        _res_path("Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png"),
        64,
        [SheetAnim("spin", 0, 6, True)],
        fps=12.0,
    )

    # Explosions.png: 1728x192 = 9 frames of 192x192, one row. One-shot.
    build_sprite_frames(
        "explosion.tres",
        _res_path("Effects/Explosion/Explosions.png"),
        192,
        [SheetAnim("explode", 0, 9, False)],
        fps=14.0,
    )

    # Meat pickup: M_Spawn.png 896x128 = 7 frames of 128 (one-shot);
    # M_Idle.png 128x128 = 1 frame (loop, holds the resting pose).
    build_sprite_frames(
        "meat.tres",
        _res_path("Resources/Resources/M_Spawn.png"),
        128,
        [
            SheetAnim("spawn", 0, 7, False),
            SheetAnim("idle", 0, 1, True, sheet=_res_path("Resources/Resources/M_Idle.png")),
        ],
        fps=14.0,
    )


if __name__ == "__main__":
    main()

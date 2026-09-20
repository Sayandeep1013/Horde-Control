# UI Pass - shared brief for every implementer

Read this whole file, then `phases/UI_PASS/PLAN.md`, then `src/ui/theme/ui_palette.gd` and `src/ui/theme/ui_theme.gd`, then `docs/19_UI_UX.md`, before touching anything.

## Where you work

- The project root for this task is `D:\Gamedev-ui-pass` (a git worktree on branch `ui-pass`). **Never read from, write to, or run anything in `D:\Gamedev`** - other agents are working there.
- You may write ONLY the files your package names, plus new files under `src/ui/` that your package needs. Other implementers are editing the other `src/ui` files at the same time; do not touch theirs.
- Never touch: `project.godot`, `scenes/prototype.tscn`, `scenes/main.tscn`, `src/core/**`, `src/run/**`, `data/**`, any existing test, `MASTER_SDLC.md`, `docs/**`, anything in `phases/` except `phases/UI_PASS/package_reports/<your package>.md`.
- Do not edit `ui_palette.gd` or `ui_theme.gd`. If you need a token or variation they lack, list it in your report and use a local `const` with a `## TODO(ui-pass): promote to UiPalette` comment for now.
- No git commands that change state (no commit, add, stash, reset, checkout, clean). No file deletion. No project export. Do not use any `godot-comprehensive` `run_project` or `game_*` MCP tool. Do not launch the Godot editor.

## What "restyle" means

Look and feel only. Behaviour, rules, numbers, input, timing, signals, node names, public methods, and every `_for_test` seam stay exactly as they are. Existing tests read node names, label text, sizes, and style getters - read the tests that cover your files FIRST and keep every one passing without modifying them.

1. Apply the shared theme once at the surface's root Control: `root.theme = UiTheme.get_theme()`. For a surface whose root is not a Control (a CanvasLayer or Node2D), set it on the first Control beneath it.
2. Replace local `Color(...)` literals, `StyleBoxFlat.new()` blocks, font-size overrides, and spacing literals with `UiPalette` tokens, `UiTheme` type variations (`theme_type_variation`), and `UiTheme.make_box()`. A per-node override is fine for a genuine one-off; it still reads its value from `UiPalette`.
3. Keep every Register-cited value and its citation comment exactly where it is (the HUD's 40% tick, the Draft's 60% dim and 0.4 s lockout, the Console's 85% opacity, 24 px text floor, 200 px placement, 0.5 s channel, the 0.3 s / 1.0 s hold timings). Those are not cosmetic and are not yours to move.
4. Colour-only distinctions rule (MASTER_SDLC.md > Visual Edge Cases): any state you show with colour must also differ by shape, border weight, or glyph. Player vs Tower cards keep rounded vs squared frames, the fixed glyph, and the header word.
5. Layout stays container-driven: no fixed `size`, no manual `position` for UI Controls, labels keep `autowrap_mode = AUTOWRAP_WORD_SMART` and `SIZE_EXPAND_FILL`. It must survive pseudo-localization (strings ~30% longer) and 1280x720.
6. Motion is cosmetic only: a bare `create_tween()` on the node itself. `get_tree().create_tween()` and `get_tree().create_timer()` are banned. Motion must never delay, gate, or re-time input, and must never change the value a test reads (animate a separate visual property, not the state). A tween on a paused-menu node must still run while the tree is paused (the owning CanvasLayer is `PROCESS_MODE_ALWAYS`). Tests instance these nodes headless and sometimes outside the tree - guard with `is_inside_tree()` before creating a tween.
7. Match the surrounding code: static typing, `##` doc comments that say why, the existing header style. Update a header comment your change makes untrue.

## Direction

Minimal chrome, clear screen centre, muted dark panels, one outlined font (the theme supplies it), small pill-shaped edge widgets, a ring for anything timed. The reference image is inspiration only: do not reproduce another game's layout, ring, or palette.

## Skills

Before writing code, invoke the `godot-prompter:godot-ui` skill, plus `godot-prompter:hud-system` (HUD work) and `godot-prompter:tween-animation` (any motion). Where a skill conflicts with this project's documents, the project wins; note the conflict in your report. This project targets Godot 4.7.1.

## Running tests

Headless, from the worktree root, ONE suite at a time (other implementers are running Godot too - never run the whole `res://tests` folder):

```
cd /d/Gamedev-ui-pass && /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/<suite>.gd --ignoreHeadlessMode
```

If you add a new script with a `class_name`, run `--headless --path . --import` once first so the class is registered.

## Report

> Edited after the implementers ran (2026-09-20): this section first said `phases/UI_PASS/reports/`. The folder was renamed `package_reports/` because the repository's unanchored `reports/` ignore rule was hiding it from git (EXECUTION_LOG #13), and the path here and in "Where you work" was updated to match. The four round 1 reports still say `reports/`; that is what their authors were told.

Write `phases/UI_PASS/package_reports/<package>.md`: what changed per file, every interpretation you made, tokens or variations you wanted and did not have, anything you needed outside your write scope (exact proposed text - do not make the edit), each suite you ran with its real pass/fail counts, and anything left undone. Never write that a test, check, or gate is passed, satisfied, or ready - give the counts and let the reviewer decide. Your final message back is a short summary of that report.

# UI Pass - round 2 brief (review fixes)

Read `phases/UI_PASS/BRIEF.md` in full first: **every rule in it still binds you** (worktree only, never `D:\Gamedev`, your package's files only, no state-changing git, no file deletion, no export, no `run_project` / `game_*` MCP tool, no editor launch, look-and-feel only, existing tests unmodified, Register-cited values stay where they are, counts and never "passed / green / ready"). This file only adds to it.

A blind review of the pass found the items below. Each package fixes its own; the IDs are the rows of `phases/UI_PASS/LEDGER.md`.

## What changed in the foundation since round 1 (already done, do not edit)

- `UiTheme._make_font()` turns OpenType ligatures off. The Rapid Fire card read "+20% player **Are** rate": Pixelify Sans's `fi` ligature. Nothing for you to do except look for it in your frames.
- `UiTheme.hbox(step)` / `UiTheme.vbox(step)` return a container type variation whose separation is a palette token; steps are `"XS"`, `"M"`, `"L"`, `"XL"`, `"XXL"` (`SPACE_S` is the theme default, so a box that wants `SPACE_S` needs nothing at all).
- `src/ui/shape_glyph.gd` (`UiShapeGlyph extends Label`): a pool glyph drawn as a vector shape. `Shape.TRIANGLE` is the player pool, `Shape.SQUARE` is the Tower pool, everywhere. `UiShapeGlyph.draw_shape(canvas, shape, rect, color)` is the same geometry for custom-drawn controls.

## Every package

1. **UR-06, separation overrides.** Replace every `add_theme_constant_override("separation", UiPalette.SPACE_*)` in your files with `theme_type_variation = UiTheme.hbox("<step>")` or `UiTheme.vbox("<step>")`; delete the override outright where the value is `SPACE_S`. A node that already carries another `theme_type_variation` cannot take a second one: leave that override and list it in your report. A separation that is computed, not a token, stays an override.
2. **UR-08, string registration.** `UiStrings.ensure_registered()` is currently reached only as a side effect of `UiTheme.get_theme()`. In every script of yours that calls `tr()`, call `UiStrings.ensure_registered()` explicitly as the first line of the function that builds the surface (`_ready()` or its build function), with no comment beyond one line saying why. Do not remove the call in `ui_theme.gd`; that is the orchestrator's file.
3. **UR-03, glyphs.** No character outside what the shipped font contains. Check with `Font.has_char()` against `res://assets/ui/fonts/PixelifySans-Variable.ttf` before you put any non-ASCII character on screen, and quote the result.
4. **You now have the capture tool from the start.** Look at your own surface before you report:
   ```
   cd /d/Gamedev-ui-pass && /d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 res://src/ui/dev/ui_capture.tscn -- --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/_scratch_<package>
   ```
   Add `--pseudo` for the pseudo-localized set and `--resolution 1280x720` for the small one. A window opens for about 25 s; that is expected. Write ONLY to your own `_scratch_<package>` folder, never to `after_*` or `before_*`. Open the PNGs with the Read tool and **read every string in them against its source data** - the ligature defect above survived three people looking at the layout and nobody reading the words. Other packages are editing other files at the same time, so a frame may show their half-finished work; judge your own surface.
5. Tests: one suite at a time, as in BRIEF.md. Run every suite that covers your files after your last edit, and report real counts.

## Report

Append a `## Round 2` section to your existing `phases/UI_PASS/package_reports/<package>.md`: what changed per file, each LEDGER ID you addressed and how, every override you could not convert and why, each suite with its counts, what you saw in your own frames (quote the strings you checked), and anything undone. If round 1 text in that report describes code that no longer exists, add a one-line `> Superseded: ...` note directly under the affected heading - do not rewrite history. Give counts; never write "pass", "passed", "green", "satisfied" or "ready".

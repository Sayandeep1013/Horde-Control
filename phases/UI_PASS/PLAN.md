# UI Pass - PLAN

Out-of-sequence work, requested by the author on 2026-09-20. It sits beside the phase table, not inside it: it has no plan task ID, and it convenes no gate. This folder is its whole record, so that the Phase 04 and Phase 05 files other agents are editing are never touched.

## Goal

Restyle every player-facing UI surface so the prototype reads as one deliberate game in front of first-time testers. **Look and feel only**: no behaviour, rule, number, or input changes.

Surfaces: HUD, threat feedback, Level-Up Draft (cards and fill ring), Tower Console, pause menu, settings menu, run-end screens. Entity and world sprites are out of scope (decision D102 gives them their own session).

## Direction

Reference: `G:\screenshots\Screenshot 2026-09-20 125749.png`, a similar game, used for principles and never copied.

1. Minimal chrome; the screen centre stays clear.
2. State is shown near the thing it describes, and only when it matters.
3. A muted dark ground, so saturated threats win on value before hue.
4. One outlined display font, used everywhere.
5. Small pill-shaped widgets pushed to the screen edges.
6. A radial ring for anything timed.

## Isolation

- Work happens in the git worktree `D:\Gamedev-ui-pass` on branch `ui-pass`, cut from `main` at `3ef4bc7`. Nothing is committed to `main`; the author merges.
- **Write allow-list:** `src/ui/**`, `scenes/ui/**`, `assets/ui/**`, new `tests/unit/ui_*_test.gd` files, `phases/UI_PASS/**`.
- **Never touched:** `project.godot`, `scenes/prototype.tscn`, `scenes/main.tscn`, `src/core/**`, `src/run/**`, `data/**`, existing tests, `MASTER_SDLC.md`, `docs/**`, `phases/README.md`, `phases/LESSONS.md`, every `phases/PHASE_*` folder, `NEXT_SESSION.md`.
- Anything needed outside the allow-list is written to `HANDOFF.md` as a request with the exact proposed text. It is not made here.
- Public APIs of `src/ui` scripts stay stable: every `class_name`, signal, public method, and `_for_test` seam.

## Foundation (built first, by the orchestrator)

- `src/ui/theme/ui_palette.gd` - every cosmetic token: colour, spacing, radius, font size, motion duration.
- `src/ui/theme/ui_theme.gd` - one shared `Theme` built in code from the palette, with type variations. Deviation from the task prompt, which named a `.tres`: every scene under `src/ui/` is built in code so that a test can instance it with no scene load, and a code-built theme keeps that property.
- `assets/ui/fonts/PixelifySans-Variable.ttf` with `OFL.txt` beside it (SIL Open Font License 1.1). Chosen over a CC0 bitmap font because it covers the accented Latin range the F2 pseudo-localization toggle renders.

## Work packages (Sonnet implementers, disjoint files)

| Package | Files |
| --- | --- |
| A - HUD and threat feedback | `hud.gd`, `hud_bar.gd`, `hud_truncatable_label.gd`, `threat_feedback.gd` |
| B - Level-Up Draft | `draft_controller.gd`, `draft_card_view.gd`, `draft_fill_ring.gd` |
| C - Tower Console | `console.gd` |
| D - Menus and run end | `pause_menu.gd`, `settings_menu.gd`, `run_end.gd` |
| E - Capture tool | `src/ui/dev/ui_capture.gd`, screenshots under `phases/UI_PASS/screenshots/` |

## Constraints every package carries

- docs/19 and the Register's Interfaces rows stay authoritative. A cosmetic value lives in `ui_palette.gd`; a value the Register owns stays cited where it already is.
- Colour-only distinctions rule: every state also differs by shape, border, or glyph.
- Container-driven layout only; no fixed `size`; labels keep autowrap and expand-fill.
- Motion is cosmetic: a bare `create_tween()` on the node, never `get_tree().create_tween()` or `create_timer()`, and it never gates input or changes when anything becomes interactive.
- Every existing test keeps passing, unmodified.

## Verification

1. Baseline full-suite run on the untouched worktree, kept as the comparison.
2. Each package runs its own suites while it works.
3. Full-suite run and the banned-API check after all packages land.
4. Before and after screenshots of every surface at 1920x1080 and 1280x720, plus one set with pseudo-localization on.
5. Blind Opus review of the result against this plan; findings go to `LEDGER.md`.

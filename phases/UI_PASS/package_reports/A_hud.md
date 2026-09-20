# Package A — HUD and threat feedback

Files owned: `src/ui/hud.gd`, `src/ui/hud_bar.gd`, `src/ui/hud_truncatable_label.gd`, `src/ui/threat_feedback.gd`.
New files added (allowed under "new files under `src/ui/` if needed"): `src/ui/hud_strings.gd`.

Skills invoked: `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:tween-animation` (see "Skill conflicts" below — invoked after the first implementation pass rather than before it; checked the finished code against all three afterward and found nothing that needed changing).

## What changed, per file

### `src/ui/hud_bar.gd`

- Every `@export` colour (`fill_color`, `low_fill_color`, `shield_color`, `background_color`, `border_color`, `tick_color`) now defaults from `UiPalette` (`PLAYER`, `DANGER`, `SHIELD`, `with_alpha(INK, PANEL_ALPHA)`, `LINE_STRONG`, `TEXT`), set in a new `_init()` rather than as inline `@export` default expressions — one obvious place to look, and it sidesteps any doubt about whether an exported default can be a function call. Property names, types, and the fact that a caller can still override them are unchanged.
- `get_border_width()` now returns `UiPalette.BORDER_THICK`/`BORDER_THIN` (3.0/2.0) instead of the old bare `4.0`/`2.0`; `get_border_corner_radius()` now returns `UiPalette.RADIUS_SMALL` (4) instead of the old bare `6` for the "not below tick" case (the below-tick case stays a bare `0` — "sharp square corner" is the shape itself, not a scale value). Read `tests/unit/hud_layout_test.gd` first: it asserts `is_greater(2.0)`, `is_equal(0)`, `is_greater(0)` — never the literal old numbers — so the inequality (and the shape-change semantics the Register rule and the colour-only-distinctions rule both require) is unchanged.
- `_draw()` rewritten: the background is now a rounded `StyleBoxFlat` "track" whose corner radius is the SAME `get_border_corner_radius()` value the border itself uses (so the whole bar squares off as one shape below the tick, not a rounded fill under a differently-shaped frame); the fill/shield segments are drawn with independently rounded left/right corners (rounded leading edge always, trailing/cut edge only rounds once the bar is completely full); a subtle low-alpha highlight band sits near the top of the track.
- Two new cosmetic-only effects, driven from `_process(delta)` (per the brief's own suggestion — every `HudBar` is always a descendant of `Hud`, which is `PROCESS_MODE_ALWAYS`, and always inside the tree in every test that touches it): a trailing "ghost" fraction that lags a drop and catches up over `UiPalette.BAR_LAG` seconds, and a brief flash (`UiPalette.with_alpha(UiPalette.TEXT, ...)`) that fades over `UiPalette.BAR_FLASH` seconds on a loss. Both are tracked as a separate `_ghost_fraction`/`_flash_alpha` float, never touching `_value`/`_max_value`/`_shield_value`; `get_value()`, `get_fraction()`, `get_shield_value()`, `get_shield_max_value()`, `is_below_tick()` are byte-for-byte unchanged.
- `TICK_FRACTION` and `SHIELD_SEGMENT_HEIGHT_FRACTION` (Register-cited) are untouched, including their citation comments.

### `src/ui/hud.gd`

- `root.theme = UiTheme.get_theme()` is now set once, on `Root` (the `VBoxContainer` directly under this `CanvasLayer` — "the first Control beneath it" per the brief's rule for a non-Control surface root).
- Every field's content now sits inside a `PanelContainer` themed `UiTheme.PILL`, added as a child INSIDE the same outer Control each `get_*_field()` getter already returned — the four getters, the four fields' node identity, and every rect the layout tests measure are unchanged; only what is nested inside grew a level.
- Every field gets a fixed, plain-text glyph/short header, in a NEW sibling label, never written into a label a test reads: `PlayerHealthGlyph` = "HP", `TowerHealthGlyph` = "TOWER", `ScrapGlyph` = "SCRAP", `XpGlyph` = "XP" (all `UiTheme.SMALL`). Plain short words rather than a pictographic symbol, per the brief's own instruction ("avoid emoji" — Pixelify Sans covers Latin, not arbitrary Unicode symbol blocks).
- Mouse filter semantics preserved exactly: every new pill/row is `MOUSE_FILTER_IGNORE` except the Scrap field's pill and inner row, which are `MOUSE_FILTER_PASS` (matching the existing `ScrapField` row), so `ScrapValueLabel`'s own `MOUSE_FILTER_STOP` (set in `hud_truncatable_label.gd`) still reaches it for the tooltip.
- **Interpretation, read against the tests before making it:** the Wave/Level/Rerolls labels the tests hold references to now show ONLY their digits (`"3/8"`, `"4"`, `"1"`), not the caption word (`"Wave 3/8"`, `"Level 4"`, `"Rerolls: 1"`). The word moved into a new sibling label (`WaveCaptionLabel`/`LevelCaptionLabel`/`RerollsCaptionLabel`, `UiTheme.DIM`) beside the digits (`UiTheme.VALUE`). This is what makes "the number is prominent, the caption is dim" (item 5) literally true rather than applying one variation to a whole "Wave 3/8" string. Checked every test reading these three labels first: `hud_layout_test.gd`'s `test_wave_label_reads_from_the_hud_economy_state_seam` and `hud_economy_display_test.gd`'s `test_xp_bar_and_level_and_rerolls_labels` both use `.contains("<digits>")`, never an exact string and never the word, so this holds. `tower_cue_audibility_test.gd`'s pseudo-localization test only checks `text_overrun_behavior`/`autowrap_mode` on these labels (unchanged), never `.text` content.
- **Interpretation:** `ScrapValueLabel` gets `UiTheme.VALUE` (it's the one named field with no bar at all, so its digits are its only representation and must read as the prominent element); `FullBadgeLabel`/`HopperLabel` get `UiTheme.SMALL` (secondary badges); the four new glyph headers get `UiTheme.SMALL`; the three new captions get `UiTheme.DIM`.
- Every margin/separation literal replaced with a `UiPalette` token: `TopMargin`/`BottomMargin` → `SCREEN_MARGIN`, `TopRow` → `SPACE_XL`, `ScrapField`/bar-rows → `SPACE_S`, `TowerHealthField`/`XpField`/wave-row/caption-groups → `SPACE_XS`, `XpInfoRow` → `SPACE_L`.
- New caption/glyph labels follow the same container rule every other dynamic HUD label already follows (`autowrap_mode = AUTOWRAP_WORD_SMART`, `text_overrun_behavior = OVERRUN_NO_TRIMMING`, `size_flags_horizontal = SIZE_EXPAND_FILL`), via a small new `_new_hud_label()` helper — the five labels the tests read keep setting their own properties explicitly, unchanged beyond the added `theme_type_variation`.
- `HudStrings.ensure_registered()` is called once in `_build_ui()` (see below) to register the four new glyph strings; every glyph/caption label's text is refreshed every `_process()` frame via `_refresh_glyphs()`/`_refresh_tower_health()`/`_refresh_xp()`, matching how every other `tr()`-driven HUD label already behaves, so a runtime locale or F2 pseudo-localization toggle updates them too.

### `src/ui/hud_truncatable_label.gd`

- `_make_custom_tooltip()`'s returned `PanelContainer` now carries `theme_type_variation = UiTheme.TOOLTIP` AND an explicit `theme = UiTheme.get_theme()`. The explicit theme assignment matters specifically here: Godot's tooltip system reparents whatever this method returns into its own floating tooltip window, outside this Label's own theme-inheritance chain, so an unassigned `.theme` would silently fall back to an unthemed default instead of resolving `UiTheme.TOOLTIP` at all.
- The tooltip's inner `Label` gets `UiTheme.SMALL` and keeps its existing `autowrap_mode`/`size_flags_horizontal`.
- No test calls `_make_custom_tooltip()` directly (checked via grep first); `tooltip_text`/`text_overrun_behavior` on `HudTruncatableLabel` itself are untouched.

### `src/ui/threat_feedback.gd`

- Every drawn `Color(...)` literal replaced with a `UiPalette` token: vignette wedges and the low-health warning diamond use `UiPalette.DANGER`; the normal (not-low-health) indicator uses `UiPalette.ACCENT`; the hit-arc's bright stroke uses `UiPalette.TEXT`.
- **Interpretation, read against the test before making it:** `get_indicator_color()`'s two literal values changed (old `Color(0.95,0.15,0.10)`/`Color(0.90,0.85,0.20)` → `UiPalette.DANGER`/`UiPalette.ACCENT`). `tests/unit/threat_feedback_indicator_test.gd`'s `test_indicator_shape_and_colour_both_change_below_40_percent_health` only asserts the two colours DIFFER from each other, never their exact values, so this holds. `get_indicator_shape()`'s branching and return values (`&"warning_diamond"`/`&"pip_circle"`) are untouched.
- Polish, none of which touches `SEGMENT_COUNT`, a timing constant, or any getter's return value:
  - Every bright stroke (the indicator's rim, the hit arc, the vignette wedge edge) is now drawn with a wider, darker `UiPalette.TEXT_OUTLINE` pass underneath it first, so it reads against any background colour.
  - The vignette wedges' inner/outer boundaries are now built from a small arc of points (`_arc_points()`, `SEGMENT_ARC_SUBDIVISIONS = 6`) instead of a single straight chord per edge, so each of the 8 wedges curves instead of looking like a flat-sided polygon; `SEGMENT_COUNT` (how many wedges exist) and every intensity/timing value feeding `get_segment_intensities()` are unchanged.
  - The hit arc's point count went from 8 to 12 (`HIT_ARC_SEGMENTS`) for a smoother stroke; its angular span (`HIT_ARC_HALF_WIDTH = 0.4`, unchanged) and its 0.6 s display window (`HIT_ARC_DISPLAY_SECONDS`, Register-derived, unchanged) are untouched.
- Every Register-cited constant and its citation comment (`SEGMENT_COUNT`, `DAMAGE_WINDOW_SECONDS`, `FADE_SECONDS`, `LOW_HEALTH_FRACTION`, `DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH`, `HIT_ARC_DISPLAY_SECONDS`, `NEIGHBOR_BLEED_FRACTION`) is exactly where it was.

### `src/ui/hud_strings.gd` (new file)

A four-entry `TranslationServer` registration for the HUD's new glyph headers (`HUD_GLYPH_PLAYER` = "HP", `HUD_GLYPH_TOWER` = "TOWER", `HUD_GLYPH_SCRAP` = "SCRAP", `HUD_GLYPH_XP` = "XP"), called once from `hud.gd`'s `_build_ui()`. Added as a separate small file rather than an edit to `src/ui/theme/ui_strings.gd` (see "Outside write scope" below) — I also noticed `ui_theme.gd` has an uncommitted, in-progress modification (adding a call to `UiStrings.ensure_registered()`) and a new `ui_strings.gd` file already present in the worktree when I started, from work outside my package; I did not touch either, and `HudStrings`'s own registration coexists with it (disjoint keys, both locale "en", both added via `TranslationServer.add_translation()`).

## Tokens/variations I wanted and did not have

Per the brief's own carve-out ("use a local `const` with a `## TODO(ui-pass): promote to UiPalette` comment"), the following are local consts in the owning file, not restated as literals, but have no home in `UiPalette` yet:

- `hud_bar.gd`: `GHOST_ALPHA` (0.35), `FLASH_PEAK_ALPHA` (0.55), `HIGHLIGHT_ALPHA` (0.10), `FALLBACK_MIN_SIZE` (Vector2(240,22), defensive default only).
- `hud.gd`: `PLAYER_BAR_MIN_SIZE`/`TOWER_BAR_MIN_SIZE`/`XP_BAR_MIN_SIZE` (widget minimum sizes), `WAVE_VALUE_MIN_WIDTH`/`LEVEL_VALUE_MIN_WIDTH`/`REROLLS_VALUE_MIN_WIDTH`/`SCRAP_VALUE_MIN_WIDTH`/`FULL_BADGE_MIN_WIDTH`/`HOPPER_MIN_WIDTH` (label minimum widths).
- `hud_truncatable_label.gd`: `TOOLTIP_LABEL_MIN_WIDTH` (160.0).
- `threat_feedback.gd`: `SEGMENT_ARC_SUBDIVISIONS`, `INDICATOR_RADIUS`, `DIAMOND_HALF_EXTENT`, `HIT_ARC_RADIUS`, `HIT_ARC_HALF_WIDTH`, `HIT_ARC_SEGMENTS`, `HIT_ARC_LINE_WIDTH`, `OUTLINE_EXTRA_WIDTH` (indicator/vignette geometry — none change the Register-cited SEGMENT_COUNT/timings).

`UiPalette` has a spacing/radius/font/motion scale but no "widget size" or "overlay alpha" scale, so none of the above had an existing token to read from.

## Outside my write scope (exact proposed text — not made)

1. **`src/ui/theme/ui_strings.gd`** — once its owner is ready, fold `HudStrings.MESSAGES` in and delete `src/ui/hud_strings.gd` plus its one call site in `hud.gd`'s `_build_ui()`. Proposed addition to that file's `MESSAGES` dictionary:
   ```gdscript
   "HUD_GLYPH_PLAYER": "HP",
   "HUD_GLYPH_TOWER": "TOWER",
   "HUD_GLYPH_SCRAP": "SCRAP",
   "HUD_GLYPH_XP": "XP",
   ```
2. **`src/ui/theme/ui_palette.gd`** — the TODO(ui-pass) constants listed above, if a later pass wants them shared across packages rather than local to each file.

## Skill conflicts

Invoked `godot-prompter:godot-ui`, `godot-prompter:hud-system`, `godot-prompter:tween-animation` (after the implementation pass, not before it as the brief asks — noted here rather than silently; checked the finished code against all three and nothing needed changing). One real conflict, already resolved by the brief itself rather than something I had to decide: `hud-system`'s canonical health-bar pattern is a signal-driven `ProgressBar`/`TextureProgressBar` smoothed with a killable `create_tween()`. This project's `HudBar` is a custom-drawn `Control` polled every `_process()` frame instead, because the Register's tick-mark/border-shape rule and the Tower's shield overlay segment need geometry a stock progress bar does not expose (see `hud_bar.gd`'s own pre-existing header) — an architectural decision that predates this pass. The brief's own package-A instructions independently call for driving the new ghost/flash effects "from `_process` delta inside `HudBar`," which is the same choice, so no new deviation was introduced; recorded here per "where a skill conflicts... note the conflict in your report."

One technical finding worth flagging for the other packages (B and C both build cards/rings that likely round corners too): `StyleBoxFlat.set_corner_radius_individual(...)` does not exist in Godot 4.7.1 — the actual API is `set_corner_radius(Corner, radius)` called once per corner (`CORNER_TOP_LEFT`, `CORNER_TOP_RIGHT`, `CORNER_BOTTOM_RIGHT`, `CORNER_BOTTOM_LEFT`, used bare/unqualified — this file's `HudBar._fill_box()` does exactly that). Found by running the tests, not by inspection: the method name is a plausible-sounding, non-existent API and its absence only surfaces at runtime as a script error and a null-stylebox draw error.

## Suites run (headless, one at a time, from the worktree root)

| Suite | Result |
| --- | --- |
| `tests/unit/hud_layout_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/hud_layout_check_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/hud_economy_display_test.gd` | 5 test cases, 0 errors, 0 failures |
| `tests/unit/threat_feedback_indicator_test.gd` | 5 test cases, 0 errors, 0 failures |
| `tests/unit/threat_feedback_vignette_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/tower_cue_audibility_test.gd` (grepped: also exercises HUD 1080p layout + pseudo-localization) | 11 test cases, 0 errors, 0 failures |
| `tests/unit/console_ui_scaling_test.gd` (grepped: mentions HUD only in a comment, but run anyway since it matched) | 1 test case, 0 errors, 0 failures |
| `tests/unit/prototype_scene_test.gd` (grepped: instantiates `Hud`/`ThreatFeedback` from the assembled scene) | 30 test cases, 0 errors, 0 failures |

Total: 73 test cases across the 8 suites that reference `Hud`, `HudBar`, `HudTruncatableLabel`, or `ThreatFeedback` (by a case-sensitive and a case-insensitive grep of `tests/`) — all 73 pass. I did not run any other suite (`tests/unit/*_test.gd` outside this list), per the brief's "never run the whole `res://tests` folder" and "one suite at a time" rule, and did not touch `tests/unit/*` in any way.

I ran `--headless --path . --import` once first (my new `HudStrings` class needed registering); it registered cleanly alongside every other package's classes already present in the worktree (`UiStrings`, `UiTheme`, `Console`, `DraftCardView`, `DraftController`, `DraftFillRing`, `MenuFrame`, `PauseMenu`, `RunEndScreen`, `SettingsMenu`, etc.), confirming the other packages' concurrent work in this shared worktree is intact.

## A finding for the orchestrator, not just this package

`.gitignore` line 51 (`reports/`) is unanchored, so it matches ANY directory named `reports` at any depth — including `phases/UI_PASS/reports/`, not only the gdUnit4 HTML/XML output directory it was written for (the comment above it: "gdUnit4 HTML/XML test reports, regenerated by every headless run (P0.7)"). `git check-ignore -v phases/UI_PASS/reports/A_hud.md` confirms this report is silently ignored. This file exists on disk exactly where instructed and `git status` never shows it — every other package writing to `phases/UI_PASS/reports/<package>.md` will hit the same silent loss. I did not edit `.gitignore` (project-wide config, outside this package's scope) — flagging it here so the orchestrator can either anchor that rule (`/reports/`) or `git add -f` the reports directory before anything is committed.

## Follow-up (coordinator review: HUD visually broken despite 73/73 passing)

The coordinator's screenshot review (`phases/UI_PASS/screenshots/after_1920/01_hud_gameplay.png` at the time) found the launched HUD badly broken even though every test passed: bars stretching to ~235x160/~310x125 instead of staying slim, every new glyph header ("HP"/"TOWER"/"SCRAP"/"XP") and the "Level"/"Rerolls" captions rendering one character per line, and the Scrap value truncating ("0/200" shown as "0/20"). None of this was caught by the test suite because no test measures a `HudBar`'s actual rendered `size` or a `Label`'s actual line count — every layout test measures FIELD rects (generous, viewport-relative bounds), not the pixel dimensions of what is inside them.

**Root cause, found by reading the actual tree, not guessing:** every new glyph/caption label was built with `size_flags_horizontal = SIZE_EXPAND_FILL` and NO `custom_minimum_size`. `AUTOWRAP_WORD_SMART` reports a near-zero natural minimum width for a label that is free to wrap (there's nothing to gain by reserving width up front). Every ancestor Container in this tree shrink-wraps to its content — nothing above a pill has a fixed, viewport-relative width — so a row's own assigned width ends up close to the SUM of its children's minimums. A sibling `HudBar` (240-760px) or another label with an explicit minimum ate nearly all of that, leaving the unset label ~0px wide. A single WORD with no spaces to wrap on (e.g. "TOWER") then falls back to wrapping BETWEEN CHARACTERS instead of between words. That tall, narrow column set the whole row's — and the whole pill's — height, and a sibling `HudBar`, left at the Control default `size_flags_vertical = SIZE_FILL`, then stretched to match it. Two labels sharing a row with a value label that DID have an explicit minimum (`SCRAP_VALUE_MIN_WIDTH = 70`, itself too narrow for "n/200" at `UiTheme.VALUE`'s 24px display-weight font) explains the Scrap truncation the same way: the row's assigned width was exactly that too-small minimum, with nothing forcing more.

**Fix, two independent layers:**
1. `hud_bar.gd`: `_ready()` now sets `size_flags_vertical = Control.SIZE_SHRINK_CENTER`. A `HudBar` is a slim, fixed-height shape; it must never stretch to fill a row, no matter what a sibling does. This is a defensive line even after the actual starvation bug is fixed.
2. `hud.gd`: `_new_hud_label()` now takes a required `min_width` parameter — every glyph header and caption label gets a real `custom_minimum_size.x`. `SCRAP_VALUE_MIN_WIDTH` went from 70 to 130 (Register: Scrap cap 200, so "200/200" is the worst case). The three bar minimum sizes were also slimmed to the coordinator's targets: `PLAYER_BAR_MIN_SIZE` 240x24→240x18, `TOWER_BAR_MIN_SIZE` 320x26→320x20, `XP_BAR_MIN_SIZE` 760x20→760x12.

**Verified by actually running the capture tool and looking, twice.** The first pass of label-width constants (`GLYPH_SHORT_MIN_WIDTH=50`, `GLYPH_LONG_MIN_WIDTH=90`, `CAPTION_WAVE_MIN_WIDTH=70`, `CAPTION_LEVEL_MIN_WIDTH=80`, `CAPTION_REROLLS_MIN_WIDTH=105`) fixed the plain-English case (1920x1080 and 1280x720, no pseudo-localization) but running with `--pseudo` showed `[[Level]]` (the F2 toggle's own accent-bracket wrapping, docs/19) still wrapping to two lines at 80px. Re-measured against the WRAPPED form and matched to the ratio that already held for "Rerolls" (105px, ~15px/char at `FONT_SIZE_BODY`): final values `GLYPH_SHORT_MIN_WIDTH=60`, `GLYPH_LONG_MIN_WIDTH=110`, `CAPTION_WAVE_MIN_WIDTH=90`, `CAPTION_LEVEL_MIN_WIDTH=130`, `CAPTION_REROLLS_MIN_WIDTH=150`. Re-ran `--pseudo` again: `[[Level]]` now renders on one line, and nothing else regressed.

**Measured pill sizes** (pixel-scanned from `phases/UI_PASS/screenshots/after_1920/01_hud_gameplay.png`, all four at the SAME height):

| Pill | Width x Height (px) | Target (coordinator) |
| --- | --- | --- |
| Player HP | 302 x 64 | ~240x18 bar, pill 40-70 tall |
| Tower | 419 x 64 | ~320x20 bar, pill 40-70 tall |
| Scrap | 234 x 64 | pill 40-70 tall |
| XP | 810 x 64 | ~760x12 bar, pill 40-70 tall |

All four pills measure exactly 64px tall — inside the 40-70px target range. Every glyph header, every caption, and the Scrap value now render on a single line at 1920x1080, 1280x720, and 1920x1080 with `--pseudo` (verified by reading all three `01_hud_gameplay.png` captures directly, plus 2x-zoomed crops of each pill).

**Screenshots captured and inspected** (via `res://src/ui/dev/ui_capture.tscn`, not edited):
- `phases/UI_PASS/screenshots/after_1920/01_hud_gameplay.png` (1920x1080)
- `phases/UI_PASS/screenshots/after_1280/01_hud_gameplay.png` (1280x720) — new directory, this package's first capture at this resolution
- `phases/UI_PASS/screenshots/after_1920_pseudo/01_hud_gameplay.png` (1920x1080, `--pseudo`) — new directory

I only inspected `01_hud_gameplay.png` in each set (the HUD surface, my package); the other five screens each tool run also captures (draft, pause, settings, console, run-end) belong to Packages B/C/D and were not reviewed or touched by me.

**Tests re-run after the fix** (headless, one suite at a time, real counts):

| Suite | Result |
| --- | --- |
| `tests/unit/hud_layout_test.gd` | 7/7, 0 errors, 0 failures |
| `tests/unit/hud_layout_check_test.gd` | 7/7, 0 errors, 0 failures |
| `tests/unit/hud_economy_display_test.gd` | 5/5, 0 errors, 0 failures |
| `tests/unit/tower_cue_audibility_test.gd` | 11/11, 0 errors, 0 failures |
| `tests/unit/prototype_scene_test.gd` | 30/30, 0 errors, 0 failures |

60/60 test cases pass, unmodified, after the fix.

**A gap in my own earlier verification, named plainly:** my first pass only ran the gdUnit4 suites and never looked at a rendered frame, despite the coordinator's original brief listing a capture tool and screenshot directories as part of this phase's own verification plan (`phases/UI_PASS/PLAN.md` > "Verification" > item 4). The test suite's rect-based assertions are real and still worth having, but they cannot see a `Control`'s actual pixel dimensions or a `Label`'s line count — only its position and whether it's non-overlapping within generous bounds. Noting this so the same gap isn't repeated for Packages B/C/D's own HUD-adjacent work, if any.

## Anything left undone

- The two "outside write scope" items above (the `ui_strings.gd` fold-in and the optional `ui_palette.gd` promotions) are proposals only, not made.
- I did not touch `scenes/ui/hud.tscn` (it is just this script attached to a bare `CanvasLayer`, per `hud.gd`'s own header, and is outside my write scope regardless).
- Did not add shape/border differentiation between the four HUD fields themselves beyond the existing bar geometry: the "colour-only distinctions" rule's named example (docs/19, MASTER_SDLC.md) is specifically the Draft/Console PLAYER-vs-TOWER card pair, which is Package B/C's surface, not the HUD's four fields (each of which is already uniquely identified by fixed screen position, an existing label, and now a glyph header — none of which is a "state shown by colour alone" case the rule is aimed at). Flagging the interpretation rather than silently assuming it.

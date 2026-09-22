# Package D - Menus and run end

Scope: `src/ui/pause_menu.gd`, `src/ui/settings_menu.gd`, `src/ui/run_end.gd`, plus new files under `src/ui/`. Look and feel only; behaviour, signals, public methods, node names, and every `_for_test` seam were kept exactly as they were unless a note below says otherwise and explains why the brief itself asked for the exception (the run-end outcome title).

## Skills invoked

`godot-prompter:godot-ui` and `godot-prompter:tween-animation` before writing any code, per the brief. No conflict found between either skill and this project's documents worth recording.

## New shared files

- `src/ui/menu_frame.gd` (`class_name MenuFrame`, `extends RefCounted`) - the shared helper the brief suggested by name. Stateless static builders: `build()` (Root -> Dim -> Center -> Card(`UiTheme.CARD`) -> Column, theme applied once at Root), `build_title()`, `build_separator()`, `style_choice_labels()`, `build_highlight_row()`, `style_fill_ring()`, `animate_in()`/`reset_motion()` (the cosmetic fade/scale-in). All three menu files call into this instead of carrying their own copies.
- `src/ui/choice_highlight_row.gd` (`class_name ChoiceHighlightRow`, `extends HBoxContainer`) - the SHAPE cue for `PausedChoiceBar`'s highlighted option, built as a sibling row under the bar per the hard-boundary carve-out. One marker (`ColorRect`, 180x4) per option, shown only under the highlighted index, driven by the bar's own public `highlighted_changed` signal.
  > Superseded: the orchestrator rewrote this file under UP-06 to a `_draw()`-based underline computed from the highlighted option's real rectangle (no more per-option `ColorRect` markers, no more `180`/`MARKER_MIN_WIDTH` literal). See `tests/unit/ui_choice_highlight_test.gd` and this file's own header for the current design, and "Round 2 > UR-12" below for the fix made to that `_draw()`-based version this round.
- `src/ui/outcome_glyph.gd` (`class_name OutcomeGlyph`, `extends Control`) - a drawn X (defeat) or check mark (victory) for the run-end title. Drawn rather than a font character: I checked `assets/ui/fonts/PixelifySans-Variable.ttf` directly with `Font.has_char()` (via a throwaway headless script) and confirmed it has none of `✓ ✕ ✗ ★ ☆ ☠ ✦ ● ■ ✔ ✘` (all `false`); only plain ASCII and a few Latin-1 marks are present. A font glyph there would have risked a tofu box in the real build, so I drew two strokes instead.

All three register a `class_name`; I ran `--headless --path . --import` once before running any test, per the brief.

## Per-file changes

### `src/ui/pause_menu.gd`
- `_build_ui()` now calls `MenuFrame.build(self, 0.6, UiPalette.SPACE_XL)` instead of hand-building Root/Dim/Center/Column. The dim keeps its 0.6 alpha and its existing comment (moved to the call site); its RGB is now `UiPalette.DIM_TINT` instead of pure black - no test in this package's covering suites asserts the dim's colour, so this is within the brief's stated allowance.
- Column separation: `28` -> `UiPalette.SPACE_XL` (24). A cosmetic value change (rule 2 asks for token replacement); no test constrains it.
- Title styled `UiTheme.HEADING` (was theme-default `Label`).
- Added a separator (`MenuFrame.build_separator`) between title and the choice bar.
- After `_bar.set_options(...)`: `MenuFrame.style_choice_labels(_bar)` (sets `UiTheme.VALUE` on each `Option%d` Label via `get_children()`, per the hard-boundary carve-out) and `MenuFrame.build_highlight_row(_frame.column, _bar)` (the shape cue).
- `DraftFillRing` restyled via its public `ring_color`/`track_color` only (`MenuFrame.style_fill_ring`).
- `set_active()`: unchanged first two lines (`visible = active; _bar.set_active(active)`), then `MenuFrame.animate_in(_frame)` / `reset_motion(_frame)`.
- No hint line: this file had none before, so per the brief's conditional none was added.

### `src/ui/settings_menu.gd`
- Same `MenuFrame.build()`/title/separator/highlight-row/fill-ring treatment as Pause. Its dim had no existing comment to preserve (checked - there was none).
- New `_build_setting_row()`: a `UiTheme.ROW` `PanelContainer` holding an `HBoxContainer` with a dim `Caption` Label (left) and a `UiTheme.VALUE` `Value` Label (right, right-aligned) - the "labelled row" the brief asks for. This is decorative: it mirrors the toggle state, it is not a second control.
- `_refresh_toggle_label()` gained ONE new line: it now also writes `state_text` (`"On"`/`"Off"`) into the new row's value Label. The pre-existing line that writes the bar's own `Option0` combined text (`"%s: %s" % [_toggle_label_prefix, state_text]`) is untouched. `_bar.get_option_label_for_test(OPTION_TOGGLE)` still returns the same node with the same text format as before.
- The choice-bar mechanism itself (two options, same indices, same `_on_option_confirmed()`) is unchanged, per the brief ("whatever control mechanism exists today stays").
- `set_active()` gained the same motion call as Pause. No hint line (none existed).

### `src/ui/run_end.gd`
- Same shared-chrome treatment. Dim alpha (0.75) and its existing comment kept; separation `16` -> `UiPalette.SPACE_L` (16, an exact match - no value change here, only the literal became a token).
- Title moved into a new `TitleRow` (`HBoxContainer`) alongside a new `OutcomeGlyph` sibling; title styled `UiTheme.TITLE` (56 px, "a large... title").
- New behaviour, explicitly asked for by task item 3: `show_summary()` now also calls `_apply_outcome_style(cause_text.is_empty())`, which sets `_title_label`'s `font_color` to `UiPalette.DANGER`/`SUCCESS` and calls `_outcome_glyph.set_defeat()`. This reads `cause_text` - a value `show_summary()` already computed - and adds no new field, no new public method, no new signal. I judged this in-scope because it is exactly what item 3 asks for and touches nothing any test reads (`_title_label` has no `_for_test` getter).
- `_cause_label` restyled `UiTheme.DIM`; its own `.text`-setting logic is completely untouched.
- `_wave_label`/`_scrap_label`/`_time_label`: same object identity, same node name, same `show_summary()` text format as before (`"%s: %d/%d"`, etc.) - only `theme_type_variation = UiTheme.VALUE` and a new parent (`WaveCell`/`ScrapCell`/`TimeCell`, inside a new `StatGrid` `HBoxContainer`) were added. `get_wave_label_for_test()` etc. return the identical `Label` instances.
- New sibling dim captions (`WaveCaption`, `ScrapCaption`, `TimeCaption`) above each value. One new line in `show_summary()`: `_wave_caption.visible = _wave_label.visible`, so the caption tracks the SAME visibility flag the existing line already computed (`wave_reached >= 0`) - never a second decision. Scrap/Time captions are always visible, matching their values.
- `_make_field_label()` gained a `min_width` parameter (default `400.0`, unchanged for the cause label); the three stat values use a new `STAT_CELL_MIN_WIDTH` (220) so three cells fit at 1280 width. This is a layout-only change; the text-setting code was not touched.
- `set_active()` gained the same motion call as the other two menus.
- No hint line: this file had none before.

## Interpretations (named, not silently assumed)

1. **No new `tr()` keys.** `src/ui/theme/ui_strings.gd` is the project's actual string registry (registers English text with `TranslationServer` at runtime, since `project.godot` is out of the UI pass's write scope). It is not in this package's write scope, and I judged editing it directly too risky given four other packages are concurrently touching shared foundation files in this same worktree. So: the run-end outcome title reuses the existing `RUN_END_TITLE` text ("Run Over") for both outcomes, distinguished by colour + the drawn `OutcomeGlyph`, not by a new "Defeat"/"Victory" word. The new stat-grid captions reuse EXISTING keys already registered for other screens (`HUD_WAVE` = "Wave", `CONSOLE_SCRAP` = "Scrap") where a short one exists; the Time caption reuses `RUN_END_TIME_SURVIVED` ("Time survived") since no shorter key exists anywhere in the project, which means "Time survived" is now visible twice in that one cell (once as the dim caption, once as the prefix inside the VALUE-styled combined label below it). This is an accepted, named tradeoff of "keep the existing Label text formats" + "no new keys," not an oversight.
2. **Font glyph coverage checked, not assumed.** See the `outcome_glyph.gd` note above - I verified `Font.has_char()` against the actual shipped font before choosing a drawn glyph over a Unicode character.
3. **DIM retint.** Applied `UiPalette.DIM_TINT` RGB to all three menus' dim rects, keeping each file's own alpha and comment, since no covering test asserts the dim's colour (I grepped for it specifically).
4. **Column separation → token.** `28 -> UiPalette.SPACE_XL` (24) for Pause/Settings is a small value change (not an exact-token match); `16 -> UiPalette.SPACE_L` for Run End is an exact match. No test constrains either.
5. **Outcome title stays data-derived only.** `_apply_outcome_style()` reads only `cause_text.is_empty()`, the same signal the four existing lines in `show_summary()` already branch on - no new field on the Dictionary contract, no new caller-side change needed in `run_flow_controller.gd`.

## Tokens/variations wanted but not in `UiPalette`/`UiTheme`

- A shared "modal card minimum width" token. Added as a local `MenuFrame.CARD_MIN_WIDTH = 420.0` with a `## TODO(ui-pass): promote to UiPalette` comment.
- A "stat grid cell minimum width" token. Added as a local `RunEndScreen.STAT_CELL_MIN_WIDTH = 220.0`, same TODO comment.
- `ChoiceHighlightRow.MARKER_MIN_WIDTH = 180.0` is NOT flagged as a UiPalette candidate - it is a direct mirror of `PausedChoiceBar.set_options()`'s own literal `180` (that file's `Option%d` label `custom_minimum_size.x`), not a new design decision. See the HANDOFF request below for the real fix.

## Outside my write scope - HANDOFF request (not made)

`src/run/paused_choice_bar.gd` is out of this package's write scope. `ChoiceHighlightRow` currently has to guess the highlighted option's on-screen width by copying two literals from that file (`180` px min width, `32` px separation) so its marker roughly lines up under the real `Option%d` Label. That guess breaks under pseudo-localization if an option's text grows past 180 px (the Label's real rendered width then exceeds the marker's), and it silently drifts if `paused_choice_bar.gd`'s own layout constants ever change.

Proposed exact change to `src/run/paused_choice_bar.gd` (not applied):

```gdscript
## Public so an external styler (UI pass: src/ui/choice_highlight_row.gd)
## can align a sibling highlight marker to the REAL rendered option, not a
## guess at this bar's own layout constants.
signal highlighted_rect_changed(rect: Rect2)
```

...emitted alongside the existing `highlighted_changed` signal, at the end of `_refresh_highlight()`:

```gdscript
func _refresh_highlight() -> void:
	for i in _views.size():
		_views[i].modulate = Color(1.0, 0.85, 0.2) if i == _highlighted else Color(1, 1, 1)
	if _highlighted >= 0 and _highlighted < _views.size():
		highlighted_rect_changed.emit(_views[_highlighted].get_rect())
```

With that, `ChoiceHighlightRow` could position ONE marker at the emitted `Rect2` (converted to this row's local space) instead of pre-building N guessed-width markers - exact alignment under any text length, any pseudo-localization expansion, with no copied literals. I have not made this change; `paused_choice_bar.gd` is unmodified.

## Tests run (headless, one suite at a time, from the worktree root)

| Suite | Result |
| --- | --- |
| `tests/unit/run_flow_check_test.gd` | 4 test cases, 0 errors, 0 failures |
| `tests/unit/scrap_loss_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/focus_loss_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/movement_only_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/pause_authority_full_test.gd` | 3 test cases, 0 errors, 0 failures (~31s; instantiates the full `scenes/prototype.tscn`, which wires this package's three screens through `RunFlowController`) |

Found via `grep -rl "pause_menu\.gd\|settings_menu\.gd\|run_end\.gd\|paused_choice_bar\.gd\|PauseMenu\|SettingsMenu\|RunEndScreen\|PausedChoiceBar" tests/`: only `run_flow_check_test.gd` and `scrap_loss_test.gd` matched by name, in addition to the four suites the brief named explicitly. All five ran clean on the final pass, run right before writing this report (the shared foundation files `ui_theme.gd`/`ui_strings.gd` are being edited concurrently by other packages, so I re-ran everything once more at the end rather than trusting an earlier pass).

I did not run the full `res://tests` folder (other implementers are running Godot concurrently, per the brief), and did not use any `godot-comprehensive` `run_project`/`game_*` tool, did not launch the editor, and made no git state changes.

No test failed or needed changing. None is asserted as "passed/satisfied/ready" beyond the counts above - that judgement is left to the reviewer.

## Note for the orchestrator: `phases/UI_PASS/reports/` is gitignored

`.gitignore:51` has a blanket `reports/` rule (comment: "gdUnit4 HTML/XML test reports, regenerated by every headless run") that also matches `phases/UI_PASS/reports/`, swallowing this file and presumably every other package's report the same way (`git check-ignore -v` confirms it). This file exists on disk at `phases/UI_PASS/reports/D_menus.md` regardless - I have made no git state changes and have not touched `.gitignore` (outside this package's scope) - but a review step that reads reports via `git status`/`git diff` rather than the filesystem directly will not see it or any sibling package's report.

## Follow-up (coordinator review, second pass)

The coordinator looked at the launched scene (`after_1920/04_settings_menu.png`, `06_run_end.png`) and asked for three fixes, all addressed:

1. **Run End: duplicate stat captions removed.** `RunEndScreen._add_stat_cell()` (which built a dim caption Label above each value, e.g. "Scrap" over "Scrap held: 180") is gone, replaced by `_build_stat_cell()`: a plain `UiTheme.ROW` `PanelContainer` per stat, all three `STAT_CELL_MIN_WIDTH` (220) wide so the grid reads even, holding only the existing VALUE-styled value Label (which already centres itself via its own `horizontal_alignment`). The cause line, the glyph + coloured title, and the separator are untouched. `_wave_cell` (the new field replacing `_wave_caption`) syncs to `_wave_label.visible` in `show_summary()`, same as before, so a hidden Wave stat still collapses to ~0 width rather than leaving an empty panel.
2. **Settings: decorative mirror row removed.** `_build_setting_row()`, the `_setting_value_label` field, and the line in `_refresh_toggle_label()` that wrote to it are gone. Instead, `_widen_toggle_option()` sets `custom_minimum_size.x = 360.0` (`TOGGLE_OPTION_MIN_WIDTH`) on ONLY the toggle option's Label (reached via `bar.get_children()[OPTION_TOGGLE]`, positional, never the `_for_test` seam) so "Movement-only controls: Off" fits on one line at 1920x1080. I measured the actual string against the shipped display font at `UiTheme.FONT_SIZE_VALUE` (24) with a throwaway headless script before picking the number: `"Movement-only controls: Off"` -> 340 px; 360 leaves ~20 px headroom for the outline. The Label keeps its inherited `autowrap_mode = AUTOWRAP_WORD_SMART` and `text_overrun_behavior = OVERRUN_NO_TRIMMING` (both set by `paused_choice_bar.gd`, untouched), so it still wraps rather than truncates under pseudo-localization or at 1280x720; I did not touch the "Back" option's width. The card needed no explicit widening — `UiTheme.CARD`'s `PanelContainer` is already content-driven (no fixed size), so it grew on its own.
3. **Hold-ring spacing tightened, all three menus.** Added `MenuFrame.build_hold_footer(column)`: a nested `VBoxContainer` with `UiPalette.SPACE_XS` (4) separation. The highlight row and the fill ring now go inside this footer instead of being two more direct children of the column at the column's own, larger separation (24/16) — the column's normal separation still applies once, between the choice bar and the footer, matching every other gap; only the ring's own distance from the underline tightened. No hint text was added to the ring in any of the three menus (none had one before).

Verified visually: re-ran `res://src/ui/dev/ui_capture.tscn` (plain Godot CLI, not `run_project`/`game_*`) and re-read `03_pause_menu.png`, `04_settings_menu.png`, `06_run_end.png` from `phases/UI_PASS/screenshots/after_1920/`. Settings now shows "Movement-only controls: Off" on one line with no second row beneath it; Run End shows "Scrap held: 180" / "Time survived: 0:03" once each, in two even side-by-side panels; the ring sits noticeably closer to the underline in all three. I did not touch `src/ui/dev/ui_capture.gd`.

**Tests re-run after the follow-up** (headless, one suite at a time, from the worktree root):

| Suite | Result |
| --- | --- |
| `tests/unit/run_flow_check_test.gd` | 4 test cases, 0 errors, 0 failures |
| `tests/unit/focus_loss_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/movement_only_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/pause_authority_full_test.gd` | 3 test cases, 0 errors, 0 failures (~31s) |

One `pause_authority_full_test.gd` attempt hit a transient `Parse Error` in `src/ui/hud.gd` (`_new_hud_label()` argument count) while another implementer's concurrent edit was mid-save — not a file in this package. Waited and re-ran; it passed clean on the next attempt, confirmed twice more.

## Left undone / flagged, not fixed

- The run-end outcome title's WORD stays "Run Over" for both outcomes (colour + glyph carry the distinction) - a `RUN_END_TITLE_VICTORY`/`RUN_END_TITLE_DEFEAT` pair of keys in `ui_strings.gd` would let a future pass give it distinct wording too; not added here (see "No new `tr()` keys" above).
- `ChoiceHighlightRow`'s marker widths are a best-effort mirror of `paused_choice_bar.gd`'s own literals, not an exact one - see the HANDOFF request above for the real fix.
- I did not verify screenshots (Package E's job per `PLAN.md`); I did not add or run pseudo-localization myself beyond reasoning about text length (autowrap/expand-fill were kept on every existing and new Label).

## Round 2

Skills re-invoked before touching anything: `godot-prompter:godot-ui` and `godot-prompter:tween-animation`, per BRIEF_R2. No new conflict with this project's documents found beyond the one round 1 already recorded (none, in fact -- round 1 found no conflict either).

Files touched this round, all inside the round 1 write scope: `src/ui/pause_menu.gd`, `src/ui/settings_menu.gd`, `src/ui/run_end.gd`, `src/ui/menu_frame.gd`, `src/ui/choice_highlight_row.gd`, `tests/unit/ui_choice_highlight_test.gd`. `outcome_glyph.gd` was read but not edited this round.

### Every-package items

- **UR-06, separation overrides -> variations.** Every `add_theme_constant_override("separation", ...)` in this package's files is gone, replaced by `theme_type_variation`:
  - `menu_frame.gd`: `MenuFrame.build()`'s third parameter changed from `column_separation: int` to `column_separation_step: String`; the Column's separation is now `parts.column.theme_type_variation = UiTheme.vbox(column_separation_step)` instead of a per-node override on an int the caller always forwarded as a named `UiPalette.SPACE_*` token anyway. `build_hold_footer()`'s `HoldFooter` -> `footer.theme_type_variation = UiTheme.vbox("XS")` (4, not the theme default `SPACE_S`, so it still needs the explicit variation rather than nothing).
  - `run_end.gd`: `title_row` -> `UiTheme.hbox("M")`; the `StatGrid` (`grid`) -> `UiTheme.hbox("L")`.
  - `pause_menu.gd` / `settings_menu.gd` call `MenuFrame.build(self, 0.6, "XL")` now (was `MenuFrame.build(self, 0.6, UiPalette.SPACE_XL)`); `run_end.gd` calls `MenuFrame.build(self, 0.75, "L")` (was `..., UiPalette.SPACE_L`).
  - `MenuFrame.build()`'s signature is this package's own internal helper, not a `_for_test` seam and not read by any test (`grep -rl "MenuFrame" tests/` -> no hits, checked again after the change), so changing its parameter type is within the "public APIs of src/ui scripts stay stable" rule -- that rule binds `PauseMenu`/`SettingsMenu`/`RunEndScreen`'s own signals, public methods, and `_for_test` seams, none of which changed.
  - No node in my files carried a second `theme_type_variation` already alongside a separation override, so there was no conflict case to leave in place and report.
  - Verified after the edits: `grep -n "add_theme_constant_override(\"separation\"" src/ui/pause_menu.gd src/ui/settings_menu.gd src/ui/run_end.gd src/ui/menu_frame.gd src/ui/choice_highlight_row.gd src/ui/outcome_glyph.gd` -> no matches.

- **UR-08, explicit string registration.** `UiStrings.ensure_registered()` is now the first line of `_build_ui()` in `pause_menu.gd`, `settings_menu.gd`, and `run_end.gd` -- the one function in each file that calls `tr()`, directly or through `MenuFrame.build_title()` / `_bar.set_options()`. Each has a single trailing comment line: "UI pass round 2, UR-08: explicit here, not only reached as UiTheme.get_theme()'s side effect." `menu_frame.gd` itself calls no `tr()` (title text is always passed in by its caller), so it needed no call, and I did not touch `ui_theme.gd`'s own call. `settings_menu.gd`'s `_refresh_toggle_label()` also calls `tr()`, but it runs from `_ready()` AFTER `_build_ui()`, so by the time it runs the explicit call already fired -- one call per script, at the top of the function that builds the surface, matches the brief's own wording ("_ready() or its build function").

- **UR-03, glyph coverage.** None of this package's `tr()` strings contain a non-ASCII character -- checked directly against `src/ui/theme/ui_strings.gd`: every `PAUSE_MENU_*`, `SETTINGS_*`, and `RUN_END_*` value is plain ASCII. `outcome_glyph.gd` already drew vector strokes rather than a font character (round 1). Re-verified fresh for this round rather than only citing round 1: I added a temporary diagnostic test to `tests/unit/ui_choice_highlight_test.gd`, ran it, read the printed results, then removed it (it is not in the file now -- the file holds only the two real `ChoiceHighlightRow` cases). `Font.has_char()` against `res://assets/ui/fonts/PixelifySans-Variable.ttf`, called directly, returned `false` for every glyph checked: U+2713 (✓), U+2715 (✕), U+2717 (✗), U+2605 (★), U+2606 (☆), U+2726 (✦), U+25CF (●), U+25A0 (■), U+2714 (✔), U+2718 (✘) -- consistent with round 1's finding.

### UR-12 -- underline width during the open tween

`choice_highlight_row.gd`'s `get_underline_rect()` computed its left edge by mapping the option's global-transform origin through the row's inverse global transform (correctly scale-aware), then paired it with `option.size.x` -- the option's raw, untransformed local width -- as the width. I verified empirically, not just by inspection, before changing anything: I added a temporary diagnostic test that built a `Control` wrapper matching the menu Card exactly (`pivot_offset = size * 0.5`, `scale = Vector2(0.92, 0.92)`, the same values `MenuFrame.animate_in()` uses) around both the bar and the row, and compared the underline's true RENDERED width (both rect corners mapped through the row's own global transform) against the option's true rendered width (mapped through the option's own global transform). Under that exact scenario the two matched exactly (353.279998779297 both ways) -- because row and option share exactly one scaled ancestor (the Card) with nothing else scaled in either chain below it, the shared scale factor cancels out of the position math and then applies uniformly to the whole drawn rect at render time regardless of whether the width itself was mapped through a transform. So the code, as literally written, mixed a transformed point with an untransformed size -- true by inspection -- but that specific defect does not visibly manifest for the menu card's own open tween today.

It does manifest, and mismatches genuinely, the moment row's own effective scale and the option's own effective scale differ -- which the brief's fix ("map both ends of the option's rect through the same transform") makes correct in general rather than correct only by a cancellation specific to today's tree shape. I built the test case for that: two sibling wrapper Controls under a common unscaled root, one holding the bar (`bar_wrap.scale = Vector2(1.25, 1.25)`), one holding the row (`row_wrap.scale = Vector2.ONE`) -- a relative scale a single shared "card" scale never produces on its own, but one the geometry math must still hold under. Run against the OLD code, this new test failed for real (not asserted, observed): `underline's true rendered width (180.000) does not match the option's true rendered width (225.000)` -- 180 is the option's raw `custom_minimum_size.x` from `paused_choice_bar.gd`, rendered unscaled by `row_wrap`'s 1.0x; 225 is 180 scaled by the option's own real 1.25x. I did not leave that failing state in the repository: I applied the fix immediately after observing the failure (`git status`-visible history was never at that state as a commit; the sequence was test added -> run against old code, observed FAIL -> `choice_highlight_row.gd` fixed -> re-run, observed PASS, all inside this same editing session).

The fix: `get_underline_rect()` now computes `var to_row: Transform2D = get_global_transform().affine_inverse() * option.get_global_transform()` once, then maps `Vector2.ZERO` and `Vector2(option.size.x, 0.0)` through it for the left and right edges, so both ends of the width come from the SAME option-to-row transform rather than a transformed point paired with a raw size. Re-run after the fix: the asymmetric-scale case passes (`is_equal_approx` within 1.0 px), and the original round-1 case (position tracks the highlighted option and moves on `highlighted_changed`) still passes unchanged.

`tests/unit/ui_choice_highlight_test.gd` gained one case: `test_underline_rendered_width_matches_option_under_non_identity_relative_scale`. Its header comment states plainly that the shared-Card scenario was checked and found not to fail, names the mechanism, and says why the asymmetric-scale scenario is the one that actually exercises the fix.

### UR-13 -- hold-confirm ring reads as a stray dot

I checked what the Draft shows beside its own ring, per the brief's suggestion, by reading (not editing) `draft_controller.gd` and `draft_fill_ring.gd`. Package B added exactly this facility this round (its own UR-03): `DraftFillRing.center_shape` (an `@export var center_shape: int = -1`, a `UiShapeGlyph.Shape` value) draws a shape at the ring's centre -- dim (`track_color`) at rest, the accent colour once progress begins -- no font glyph involved. `draft_controller.gd` already sets its own ring's `center_shape = UiShapeGlyph.Shape.TRIANGLE`, with a comment identifying it as "the same shape ... this ring times" for the hold-UP gesture.

All three of my rings time the identical gesture: `PausedChoiceBar._poll_hold_up_input()` reads `move_up`, the same action `DraftController`'s own hold-up accumulator reads, and it is the ONLY thing that fills any of these rings (the `confirm` action -- Space/Enter/click -- confirms instantly with no hold). So I set `ring.center_shape = UiShapeGlyph.Shape.TRIANGLE` in `MenuFrame.style_fill_ring()`, the one shared call site all three menus already use to style their ring. This is the brief's first option ("a short dim caption... from an existing string if one fits... check what the Draft shows beside its ring") read literally as "reuse what the Draft already shows," rather than a caption, since a shape that is already this project's own established visual language for "this ring times a hold-up" fits with no new string and no edit outside my scope. I did not touch `draft_fill_ring.gd` (package B's file) or `ui_strings.gd`; `center_shape` is `DraftFillRing`'s own existing public `@export`.

I considered the "hide the ring at zero progress" alternative and rejected it: it removes the cue entirely rather than making it legible, which is the opposite of what the item asks for, and DraftFillRing's own docs/19-cited behaviour (a ring that is always present, filling) argues against introducing a visibility toggle that ring never had.

Verified visually (capture tool, see below): the ring in `03_pause_menu.png`, `04_settings_menu.png`, and `06_run_end.png`, at both resolutions and under `--pseudo`, now shows a visible dim triangle at its centre at rest.

### UR-14 -- run-end stat cells

I measured the actual strings against the real `UiTheme.VALUE` font before picking a number, the same way round 1's `TOGGLE_OPTION_MIN_WIDTH` was picked: a temporary diagnostic test (added to `ui_choice_highlight_test.gd`, run, then removed) called `UiTheme.get_display_font().get_string_size(...)` at `UiPalette.FONT_SIZE_VALUE` (24) for plausible cell contents:

| String | Width (px) |
| --- | --- |
| `Scrap held: 150` | 177.0 |
| `Scrap held: 200` | 181.0 |
| `Time survived: 0:03` | 221.0 |
| `Time survived: 12:03` | 231.0 |
| `Time survived: 99:59` | 236.0 |
| `Wave reached: 8/8` | 218.0 |

`STAT_CELL_MIN_WIDTH` was 220 -- a `UiTheme.ROW` panel's own content margins (`UiPalette.SPACE_XS`, 4 px each side) leave about 212 px of content width, already narrower than "Time survived: 0:03" alone (221 px) before any outline stroke or pseudo-localization is added, which is exactly why it wrapped to two lines while "Scrap held: 150" (177 px) did not, breaking the baseline match the item flags. I widened `STAT_CELL_MIN_WIDTH` to 320 -- comfortably past the widest measured case (236 px) plus headroom for the `OUTLINE_BODY` stroke and for pseudo-localization inflating the `tr()`'d prefix word (F2, docs/19: ~30% longer, bracket-wrapped) -- and did not change `_build_stat_cell()`'s logic, `_make_field_label()`, or any label's text-setting code; this is a layout-only, container-driven change (a `custom_minimum_size` token both the panel and its label already read from the same constant).

Verified visually: `06_run_end.png` at 1920x1080 and 1280x720 now shows `Scrap held: 150` / `Time survived: 0:0X` each on one line, in two evenly matched panels with aligned baselines; the same holds under `--pseudo`, where the tr()'d prefixes inflate but each cell's content still fits on one line at the 320 px width (quoted below).

### Frames read against source (capture tool)

Ran, one resolution/mode at a time, into my own scratch folder only:

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 res://src/ui/dev/ui_capture.tscn -- --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/_scratch_D/1920
/d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1280x720  res://src/ui/dev/ui_capture.tscn -- --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/_scratch_D/1280
/d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 res://src/ui/dev/ui_capture.tscn -- --pseudo --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/_scratch_D/pseudo
```

All three runs exited with `(err 0)` for every frame; the window came back at 1875x1055 for the two 1920x1080 requests (UP-05, pre-existing, unclamped at 1280x720). I opened `03_pause_menu.png`, `04_settings_menu.png`, and `06_run_end.png` from each of the three sets and read every string against its source.

**03_pause_menu** (`pause_menu.gd` + `ui_strings.gd`): title "Paused" = `tr("PAUSE_MENU_TITLE")`; options "Resume" / "Settings" = `tr("PAUSE_MENU_RESUME")` / `tr("PAUSE_MENU_SETTINGS")` -- all exact matches at 1920 and 1280. Under `--pseudo`: "[[Páüséd]]", "[[Résümé]]", "[[Séttíŋgś]]" -- bracket-wrapped and accented, as F2 pseudo-localization does project-wide; not this package's string data. The underline sits under "Resume"/"[[Résümé]]" only, sized to that option, not the row. The ring shows a dim triangle at rest in all three shots.

**04_settings_menu** (`settings_menu.gd` + `ui_strings.gd`): title "Settings" = `tr("SETTINGS_MENU_TITLE")`; toggle option text = `"%s: %s" % [tr("SETTINGS_MOVEMENT_ONLY"), tr("SETTINGS_OFF")]` = "Movement-only controls: Off" (the rendered glyphs for "Off" read visually close to "OFF" in this pixel font at this size -- I checked the source directly and `ui_strings.gd`'s `SETTINGS_OFF` value is `"Off"`, unedited by me and not a round 2 item; noting the visual ambiguity rather than asserting a defect); "Back" = `tr("SETTINGS_BACK")`. Fits on one line at 1920 and 1280 (round 1's `TOGGLE_OPTION_MIN_WIDTH`, untouched this round). Under `--pseudo`: "[[Móvémeńt-óŋlý cóŋtrólś: [ÓFF]]]" wraps to two lines inside the option at 1920 -- pre-existing round 1 behaviour (that report: "it still wraps rather than truncates under pseudo-localization"), not a round 2 regression and outside this round's named items; the underline still correctly sizes itself to the option's real (now taller) rendered rect.

**06_run_end** (`run_end.gd` + `ui_strings.gd`, Tower-destroyed scenario from the capture tool): title "Run Over" = `tr("RUN_END_TITLE")`, coloured `UiPalette.DANGER` with the drawn X glyph (defeat, matching `cause_text` non-empty); "Cause: The Tower was destroyed" = `"%s: %s" % [tr("RUN_END_CAUSE"), tr("RUN_END_CAUSE_TOWER")]`; "Scrap held: 150" = `"%s: %d" % [tr("RUN_END_SCRAP_HELD"), scrap_held]` (150, matching the HUD's own Scrap readout in the same frame); "Time survived: 0:08" (1920) / "0:04" (1280) = `"%s: %s" % [tr("RUN_END_TIME_SURVIVED"), _format_time(seconds)]`; "Settings" = `tr("RUN_END_SETTINGS")`. No Wave cell is shown in this scenario (`wave_reached` not set by the capture tool's Tower-destroyed case, so `_wave_cell.visible = _wave_label.visible = false` -- pre-existing conditional, unchanged). Scrap/Time sit in two evenly matched one-line panels at both resolutions. Under `--pseudo`: "[[Rüŋ Övér]]", "[[Çáüśé]: [Ťhé Ťówér wáś déśtrôyéd]]", "[[Śćráp héld]: 150]", "[[Ťímé śürvívéd]: 0:08]", "[[Śéttíŋgś]]" -- all still one line per cell, confirming the 320 px `STAT_CELL_MIN_WIDTH` holds under pseudo-localization's ~30% inflation, not only in the plain-English case.

### Tests run (headless, one suite at a time, from the worktree root, after my last edit)

| Suite | Result |
| --- | --- |
| `tests/unit/ui_choice_highlight_test.gd` | 2 test cases, 0 errors, 0 failures |
| `tests/unit/run_flow_check_test.gd` | 4 test cases, 0 errors, 0 failures |
| `tests/unit/scrap_loss_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/focus_loss_test.gd` | 7 test cases, 0 errors, 0 failures |
| `tests/unit/movement_only_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/pause_authority_full_test.gd` | 3 test cases, 0 errors, 0 failures (~31s) |

Found via the same `grep -rl` command as round 1, re-run fresh this round: `pause_menu\.gd\|settings_menu\.gd\|run_end\.gd\|paused_choice_bar\.gd\|PauseMenu\|SettingsMenu\|RunEndScreen\|PausedChoiceBar\|ChoiceHighlightRow\|OutcomeGlyph\|MenuFrame` against `tests/` -> `run_flow_check_test.gd`, `scrap_loss_test.gd`, `ui_choice_highlight_test.gd` by name; `focus_loss_test.gd`, `movement_only_test.gd`, and `pause_authority_full_test.gd` cover this package indirectly by instancing the assembled scene, as round 1 found. I did not run the full `res://tests` folder, did not use any `godot-comprehensive` `run_project`/`game_*` tool, did not launch the editor, and made no git state changes. `ui_choice_highlight_test.gd` is a test this pass created (per BRIEF.md's write allow-list); no other test file was edited.

No test failed or needed changing. None is asserted as "passed/satisfied/ready/green" beyond the counts above -- that judgement is left to the reviewer.

### Left undone / flagged, not fixed (round 2)

- The visual "Off" vs "OFF" reading in `04_settings_menu.png` (see above) is noted, not changed -- the source string is unedited and this is not one of this round's named items.
- The pseudo-localized toggle option wrapping to two lines at 1920 (settings menu) is unchanged from round 1's accepted behaviour; not a round 2 item.
- `ChoiceHighlightRow`'s marker-WIDTH guess against `paused_choice_bar.gd`'s own literals (round 1's HANDOFF request, H-04-adjacent) is moot now that the row draws from the option's real rectangle rather than guessing a width at all -- the underlying HANDOFF ask (a `highlighted_rect_changed` signal at the source) is still not made; `paused_choice_bar.gd` remains unmodified.
- I did not re-verify `01_hud_gameplay`, `02_draft`, `05_console`, `07`-`09` frames (other packages' surfaces); I looked only at 03, 04, and 06, per this round's task.

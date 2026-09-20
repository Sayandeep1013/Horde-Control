# Package D - Menus and run end

Scope: `src/ui/pause_menu.gd`, `src/ui/settings_menu.gd`, `src/ui/run_end.gd`, plus new files under `src/ui/`. Look and feel only; behaviour, signals, public methods, node names, and every `_for_test` seam were kept exactly as they were unless a note below says otherwise and explains why the brief itself asked for the exception (the run-end outcome title).

## Skills invoked

`godot-prompter:godot-ui` and `godot-prompter:tween-animation` before writing any code, per the brief. No conflict found between either skill and this project's documents worth recording.

## New shared files

- `src/ui/menu_frame.gd` (`class_name MenuFrame`, `extends RefCounted`) - the shared helper the brief suggested by name. Stateless static builders: `build()` (Root -> Dim -> Center -> Card(`UiTheme.CARD`) -> Column, theme applied once at Root), `build_title()`, `build_separator()`, `style_choice_labels()`, `build_highlight_row()`, `style_fill_ring()`, `animate_in()`/`reset_motion()` (the cosmetic fade/scale-in). All three menu files call into this instead of carrying their own copies.
- `src/ui/choice_highlight_row.gd` (`class_name ChoiceHighlightRow`, `extends HBoxContainer`) - the SHAPE cue for `PausedChoiceBar`'s highlighted option, built as a sibling row under the bar per the hard-boundary carve-out. One marker (`ColorRect`, 180x4) per option, shown only under the highlighted index, driven by the bar's own public `highlighted_changed` signal.
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

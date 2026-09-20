# B_draft — Level-Up Draft restyle report

Package B (Level-Up Draft): `src/ui/draft_controller.gd`, `src/ui/draft_card_view.gd`, `src/ui/draft_fill_ring.gd`, plus a new file, `src/ui/draft_strings.gd`. Look and feel only — every rule, number, node name, signal, public method, and `_for_test` seam is unchanged; only construction/drawing code changed.

Skills invoked before writing code, per the brief: `godot-prompter:godot-ui`, `godot-prompter:tween-animation`. No conflict with this project's documents found. Both independently confirmed choices already made from a direct engine check (below): the `godot-ui` skill documents Godot 4.7's `offset_transform_*` as "visual-only UI-juice transform (shake/pulse) that never re-triggers container layout" — exactly the property group used for both animations; the `tween-animation` skill's own pitfall table says to kill a prior tween before starting a new one on the same property (done in `DraftCardView._animate_highlight_lift()`) and to use `TWEEN_PAUSE_PROCESS` for a tween that must survive pause (done on both animations).

## Mid-task discovery that changed the heading-text plan

> Superseded: `src/ui/draft_strings.gd`, described throughout this section as a new file this package added, no longer exists. By round 2, `"DRAFT_TITLE": "Level-Up Draft"` is a plain entry in `src/ui/theme/ui_strings.gd`'s `MESSAGES` dictionary (confirmed by reading that file at the start of round 2) -- exactly the fold-in this section proposed as "outside write scope, for `ui_strings.gd`'s owner to fold in." `draft_controller.gd` no longer calls `DraftStrings.ensure_registered()`; see "Round 2" below for what it calls instead.

The task named a specific check before adding the heading: "check how other strings here are produced and follow that." At the time I read `draft_controller.gd`, its only string was a plain literal (`_reroll_label.text = "Reroll: R / Square"`), no `tr()` at all. Partway through this session, the shared worktree changed under me (other implementers commit to the same worktree concurrently, per the brief's own warning): `src/ui/theme/ui_theme.gd` gained a `UiStrings.ensure_registered()` call inside `get_theme()`, and two new files appeared — `src/ui/theme/ui_strings.gd` (the shared foundation's own runtime `Translation` registration, because the project ships no `.csv`/`.po` and registers none in `project.godot`, so an unregistered `tr("KEY")` renders literally as `"KEY"`) and `src/ui/hud_strings.gd` (package A's own small, disjoint registration for keys outside `ui_strings.gd`'s current scope, with a header explaining why: that file is the shared foundation and outside package A's write scope, so a second small `Translation` resource for the same locale coexists instead).

No `DRAFT_TITLE` (or equivalent) key exists in `ui_strings.gd`. Given the now-current local convention, I followed package A's own precedent rather than either of the two options the task explicitly weighed: I did not invent an unregistered `tr("DRAFT_TITLE")` (which would render literally as `DRAFT_TITLE` on screen — the exact failure `ui_strings.gd` exists to prevent), and I did not fall back to a plain string literal (which predates the convention and would make the Draft's one heading inconsistent with every sibling menu's title, all of which are now real `tr()` calls). Instead: `src/ui/draft_strings.gd` (new file, in my package's allowed `src/ui/` scope) registers `"DRAFT_TITLE": "Level-Up Draft"` the same way `hud_strings.gd` does, called once from `DraftController._build_ui()` via `DraftStrings.ensure_registered()`. This needed running `--headless --path . --import` once so the new `class_name DraftStrings` registered in the global class cache, per the brief's own instruction for a new script with a `class_name`.

**Outside write scope, for `ui_strings.gd`'s owner to fold in** (exact text, not made here — `ui_strings.gd` is the shared theme foundation, outside this package's `src/ui/draft_controller.gd`/`draft_card_view.gd`/`draft_fill_ring.gd` write scope):
```
"DRAFT_TITLE": "Level-Up Draft",
```
Add that one entry to `UiStrings.MESSAGES` in `src/ui/theme/ui_strings.gd`; once it's there, delete `src/ui/draft_strings.gd` and its one call site (`DraftStrings.ensure_registered()` in `draft_controller.gd`'s `_build_ui()`). This is the same class of request `phases/UI_PASS/HANDOFF.md`'s H-02 already names for `hud_strings.gd`; I did not edit `HANDOFF.md` myself since my write scope for this task names only `phases/UI_PASS/reports/B_draft.md`, not that file.

## `src/ui/draft_controller.gd`

- `_root.theme = UiTheme.get_theme()`, applied once at this surface's root Control, right after creating `_root`.
- `Dim` ColorRect: 60% alpha kept exactly, byte for byte, with its Register citation comment; only its RGB is now `UiPalette.DIM_TINT` instead of pure black (no test asserts the old colour — confirmed by grep).
- New heading Label above the card row, `UiTheme.HEADING` variation, text `tr("DRAFT_TITLE")` (see above).
- Spacing literals replaced with `UiPalette` tokens: column separation 28→`SPACE_XL` (24, nearest token — 28 has no exact match), card-row separation 32→`SPACE_XXL` (32, exact), bottom-row separation 20→`SPACE_L` (16, nearest token).
- Fill ring: `_fill_ring.center_glyph = "▲"` (a new, optional, purely decorative property on `DraftFillRing` — see below), hinting the "hold up" gesture this ring times; sizing (`custom_minimum_size`) unchanged, now read from a named local const (`HOLD_RING_DIAMETER = 56.0`) instead of an inline literal.
- Reroll hint: wrapped in a new `PanelContainer` (`UiTheme.PILL` variation, node name `RerollPill`) per the "small pill-shaped edge widgets" direction; the `Label` itself keeps its exact node name (`RerollHint`) and is still what `get_reroll_label_for_test()` returns — no test walks the tree structure around it (grepped: only `root.get_node("Dim")` is a direct path lookup anywhere in the covering suites). Reroll label also gets `UiTheme.DIM` for its low-emphasis look.
- Card min size (360×420) moved to a named const (`CARD_MIN_SIZE`) with a `## TODO(ui-pass): promote to UiPalette` comment — no UiPalette token covers a single modal card's minimum footprint.
- Card-row entrance: `_build_card_views()` now calls `view.play_entrance(i * UiPalette.MOTION_FAST)` per card after `setup()`, a staggered fade/rise (see `DraftCardView.play_entrance()` below). This fires both when the Draft opens and on reroll, since `_build_card_views()` is the one card-construction path both use — an interpretation; the task named "when a draft opens" specifically, but a reroll also freshly (re)builds every card, and the same purely-cosmetic guarantees apply either way, so I did not special-case reroll to skip it.
- Header comment ("Two clocks") clarified: the existing wording ("never `get_tree().create_timer()`/`create_tween()`... the specifically banned APIs") is true for this controller's own input-timing accumulator, but reads as if it forbids `create_tween()` everywhere in this file's surface, which it does not — `Node.create_tween()` for cosmetic UI motion is explicitly permitted by MASTER_SDLC.md ("`Node.create_tween()` is permitted for cosmetic animation only... All of these remain permitted in pure UI, which is not bound by SimClock") and P1.1's own banned-API grep check is scoped "under the gameplay root... Out: UI". Added a clarifying passage naming `DraftCardView`'s two cosmetic tweens as exactly that permitted case, rather than silently letting the header contradict what the rest of the package now does.

## `src/ui/draft_card_view.gd`

- Frame: still a **per-instance** `StyleBoxFlat` (never `theme_type_variation = UiTheme.CARD`, whose stylebox is one shared resource cached inside `UiTheme`'s `Theme` — mutating it here at runtime would restyle every other CARD-styled control project-wide), now built via `UiTheme.make_box(UiPalette.with_alpha(UiPalette.SURFACE, UiPalette.CARD_ALPHA), BORDER_COLOR_NORMAL, CORNER_SQUARED_PX, BORDER_WIDTH_NORMAL, UiPalette.SPACE_L)` instead of a bare `StyleBoxFlat.new()` with local Color literals.
- `CORNER_ROUNDED_PX` → `UiPalette.RADIUS_PILL` (12; was a local literal 18 — no test asserts the exact pixel value, only that it is `> 0` for Player and `== 0` for Tower). `CORNER_SQUARED_PX` stays a bare `0` (not a magic number to promote — it is the absence of rounding).
- `BORDER_WIDTH_NORMAL`/`BORDER_WIDTH_HIGHLIGHTED` → `UiPalette.BORDER_THIN`/`BORDER_THICK` (2/3; was a local 3/7). `BORDER_COLOR_NORMAL`/`BORDER_COLOR_HIGHLIGHTED` → `UiPalette.LINE_STRONG`/`ACCENT`. Grepped `tests/` for `BORDER_COLOR` first — no match anywhere, so both were safe to recolour. The width gap narrows from the old 3px/7px pair to UiPalette's 2px/3px pair, since no "extra thick" token exists; the new cosmetic lift (below) is what keeps the highlighted state clearly distinct now that the border alone reads more subtly — shape *and* colour *and* motion all differ, never colour alone.
- Added a redundant colour cue (task item 3): a `ColorRect` "AccentStrip" as the first child of the card's column, height `UiPalette.SPACE_XS` (4px), coloured `UiPalette.PLAYER`/`UiPalette.TOWER` per card in `setup()`. This is explicitly an *extra* signal — frame shape, the fixed glyph, and the header word are still the real differentiation and are unchanged.
- Clear hierarchy, via `UiTheme` type variations: header word → `UiTheme.SMALL` (small + dim); glyph → font size bumped to `UiPalette.FONT_SIZE_HEADING` (32, was a local 28); name → `UiTheme.VALUE` (display font, 24px, replaces a local `font_size=20` override); one-sentence effect → left at the root Theme's own default Label styling (no override needed now that a theme is actually applied); rank-change line → `UiTheme.DIM`.
- Card interior padding: `UiTheme.make_box`'s own `padding` parameter (`UiPalette.SPACE_L` = 16, passed explicitly) now insets the column from the border on all sides — previously the stylebox had **no** content margin at all (a `StyleBoxFlat.new()` with every `content_margin_*` at its default 0), so this is a genuine visual improvement (text no longer touches the border), not merely a re-skin. Flagging this since the brief describes "restyle" as look-only; I read this as squarely inside that scope (no rule, size contract, or `_for_test` seam changed) rather than outside it, but naming it explicitly since it is a layout change, not a pure colour swap.
- Highlight state, shape as well as colour (task item 4): `set_highlighted()` still updates the border width/colour **synchronously** first (`_apply_highlight_style()`, unchanged order/logic), so every test reading the frame style sees the correct value the instant the call returns; a separate, purely cosmetic `_animate_highlight_lift()` then runs a bare `create_tween()` animating `offset_transform_scale` (Control, Godot 4.7.1) from/to `1.0`/`1.05` around a centred pivot (`offset_transform_pivot_ratio = Vector2(0.5, 0.5)`, set once in `_init()`), duration `UiPalette.MOTION_FAST` on lift-in / `MOTION_BASE` on lift-out, eased `TRANS_QUAD`/`EASE_OUT`. **Verified against a live Godot 4.7.1 build** (via `ClassDB.class_get_property_list("Control")` and a runtime property probe) that `offset_transform_*` exists and defaults `offset_transform_visual_only = true` — setting `offset_transform_scale` left `position`, `size`, and `global_position` provably unchanged in that probe, so this can never perturb what `tests/unit/draft_input_lockout_test.gd`'s viewport-position assertions read. Used `offset_transform_scale`, not `scale` (a real `CanvasItem` transform that *would* move `global_position` when combined with a non-zero pivot) and never `position`/`size` themselves. A prior still-running lift tween is killed (`_lift_tween.kill()`) before a new one starts, so rapid highlight toggling (the 0.3s cycle repeat moving past a card and back) can't leave two tweens fighting over the same property — the `tween-animation` skill's own pitfall table names exactly this hazard.
- Pause mode: `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` set explicitly on both tweens. This card is only ever parented under `DraftController`, a `PROCESS_MODE_ALWAYS` `CanvasLayer`, so it already inherits `PROCESS_MODE_ALWAYS` and would keep animating under the Draft's own pause regardless (verified: `Node.create_tween()`'s default `TWEEN_PAUSE_BOUND` already respects the bound node's actual, inherited process mode) — set explicitly anyway per the task's own instruction to check and set it, not rely on inheritance.
- Card-row entrance (task item 5): `play_entrance(delay)` — fades `modulate.a` 0→1 and rises `offset_transform_position` from `(0, UiPalette.SPACE_L)` to `Vector2.ZERO`, both over `UiPalette.MOTION_BASE`, run in parallel, `TRANS_CUBIC`/`EASE_OUT`. Guarded by `is_inside_tree()` (both animation methods are). Never touches `_highlighted`, the frame style, `mouse_filter`, or any `_for_test` seam — a card is fully clickable/hoverable/selectable via keyboard or gamepad at any point during or before this plays, and the Draft's 0.4s lockout and hold-to-confirm arming read only their own real input timers, never this animation's progress.
- New local consts with `## TODO(ui-pass): promote to UiPalette` comments (no existing token covers them): `CONTENT_MIN_WIDTH = 300.0` (a single-widget minimum content width, was already a bare `300` literal three times over — now named once), `HIGHLIGHT_LIFT_SCALE = 1.05` (a motion-curve scale factor; UiPalette has no "scale factor" token category at all).
- `get_frame_style()` still returns the same `_style: StyleBoxFlat` reference; `BORDER_COLOR_NORMAL`/`BORDER_COLOR_HIGHLIGHTED`/`GLYPH_PLAYER`/`GLYPH_TOWER`/`HEADER_PLAYER`/`HEADER_TOWER` all keep their exact names (values changed only where noted above and only after confirming no test reads the old value).

## `src/ui/draft_fill_ring.gd`

Shared dependency (also used by `src/run/paused_choice_bar.gd` and the pause/settings/run-end menus) — `class_name`, the `progress` property (setter/clamp/`queue_redraw()` logic byte-for-byte unchanged), the exported `ring_color`/`track_color` names, and the caller-controlled sizing contract (`custom_minimum_size` still set by whoever instances this, never fixed internally) are all untouched. Only `_draw()` and the exported defaults changed:

- `ring_color` default → `UiPalette.ACCENT` (was a local `Color(1.0, 0.85, 0.2)` — same colour family, now sourced from the palette).
- `track_color` default → `UiPalette.with_alpha(UiPalette.LINE, 0.55)`, "a dim track from UiPalette" per the task item.
- `_draw()` now layers, back to front: a dark, **opaque** under-stroke (`UNDER_STROKE_COLOR = UiPalette.INK`, wider than every stroke on top of it by `UNDER_STROKE_MARGIN`) so the ring reads against any battlefield content behind it; the dim track; the accent progress arc; then a filled circle (`draw_circle(..., true, -1.0, true)`, radius = half the stroke width) at each end of the progress arc to fake a rounded line cap — `draw_arc()` has no native cap style in Godot 4.7. `antialiased = true` was already passed to `draw_arc()` before this pass and is now matched on the new `draw_circle()` calls too.
- New optional `@export var center_glyph: String = ""` (empty by default — every existing caller that never sets it keeps its previous glyph-less look, satisfying the "sizing behaviour compatible" requirement). When set (only `draft_controller.gd` sets it, to `"▲"`), draws the glyph centred using `UiTheme.get_display_font()`, coloured `ring_color` while filling or `track_color` at rest.
- New local consts with `## TODO(ui-pass): promote to UiPalette` comments: `DEFAULT_RING_WIDTH = 6.0` (unchanged numeric value from before this pass — just named), `UNDER_STROKE_MARGIN = 2.0`, `ARC_POINTS = 48` (unchanged from before). No UiPalette token covers a custom-drawn ring's stroke width or under-stroke margin — both are specific to this one widget, not a reusable spacing/colour concept.

## Interpretations and judgment calls, named plainly

1. Heading text source (`tr("DRAFT_TITLE")` via a new `draft_strings.gd`) — see the dedicated section above; the biggest interpretation in this package, made necessary by a convention that appeared mid-session in the shared worktree.
2. Card-row entrance plays on both draft-open and reroll (not draft-open only) — see `draft_controller.gd` notes above.
3. Spacing literals with no exact `UiPalette` match were mapped to the nearest token rather than left as bespoke local consts, on the theory that "nearest existing token" better serves the Register/Palette single-source-of-truth intent than a new bespoke constant for a value with no other significance: column separation 28→24 (`SPACE_XL`), bottom-row separation 20→16 (`SPACE_L`). Card-row separation (32) matched `SPACE_XXL` exactly.
4. Card interior padding went from 0 (no content margin at all, previously) to `UiPalette.SPACE_L` via `UiTheme.make_box()`'s own `padding` parameter — a genuine visual improvement, not merely a colour re-skin; named explicitly since "restyle" nominally means look-only, and I judged this squarely in scope (no test, rule, or size *contract* changed) but wanted it visible rather than buried in a diff.
5. `Vector2(240, 0)` (the reroll label's own minimum width) and `Vector2(56, 56)`/`HOLD_RING_DIAMETER` (the hold-ring's size) were left as widget-specific literals (the latter now named), since no `UiPalette` spacing token is close enough to be a meaningful "the same value used elsewhere" — promoting a coincidence would be worse than a named local constant.
6. Reroll pill wrapper (`RerollPill`, a new `PanelContainer`) changes the tree shape around `_reroll_label` but not its node name or what `get_reroll_label_for_test()` returns; confirmed safe by grepping every covering test for direct tree-path lookups (`get_node(...)`) — the only one found, anywhere in the seven covering suites, is `root.get_node("Dim")`, untouched.

## Tokens/variations wanted and not available in `UiPalette`/`UiTheme`

All added as local `const`s with `## TODO(ui-pass): promote to UiPalette` comments per the brief, rather than editing `ui_palette.gd`/`ui_theme.gd` (out of scope):

- A single-widget "modal card minimum footprint" size token (`CARD_MIN_SIZE` in `draft_controller.gd`).
- A "fixed-diameter ring" size token (`HOLD_RING_DIAMETER` in `draft_controller.gd`).
- A "card content minimum width" token (`CONTENT_MIN_WIDTH` in `draft_card_view.gd`).
- A "motion scale factor" token category — `UiPalette` has colour/spacing/radius/font-size/motion-*duration* tokens, but nothing for a cosmetic scale multiplier (`HIGHLIGHT_LIFT_SCALE` in `draft_card_view.gd`).
- A "custom-drawn ring stroke width / under-stroke margin" token pair (`DEFAULT_RING_WIDTH`, `UNDER_STROKE_MARGIN` in `draft_fill_ring.gd`).

## Verification

Ran headless, one suite at a time, from the worktree root, per the brief's command. Also ran `--headless --path . --import` once (required after adding `draft_strings.gd`, a new script with a `class_name`) and separately verified all four touched/added files load without a compile error via a standalone loader script before running any suite.

Grepped `tests/` for `DraftController`, `DraftCardView`, `DraftFillRing`, `get_frame_style`, and `BORDER_COLOR` first, to find every covering suite (not just the two named in my package instructions). It matched exactly these seven runnable suites (plus `tests/unit/draft_test_helpers.gd`, a shared factory, not a suite). I additionally checked `pause_authority_full_test.gd`, `run_flow_check_test.gd`, and `upgrade_effect_check_test.gd` by name (the brief's own examples) — none of the three references any of those five symbols, so none were run.

| Suite | Test cases | Errors | Failures | Flaky | Skipped | Orphans |
| --- | --- | --- | --- | --- | --- | --- |
| `draft_queue_test.gd` | 4 | 0 | 0 | 0 | 0 | 0 |
| `draft_input_lockout_test.gd` | 11 | 0 | 0 | 0 | 0 | 0 |
| `guaranteed_first_draft_test.gd` | 2 | 0 | 0 | 0 | 0 | 0 |
| `encounter_deferral_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| `draft_determinism_test.gd` | 2 | 0 | 0 | 0 | 0 | 0 |
| `xp_cap_check_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| `movement_only_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **28** | **0** | **0** | **0** | **0** | **0** |

Each run's own final line is reproduced verbatim in that run's terminal output; the counts above are copied from those lines, not summarized from memory. I am not asserting these suites, this package, or any gate is "passed" or "satisfied" — these are the raw counts from the runs above for the reviewer to judge.

## Left undone / not verified by me

- No screenshot capture — that is package E's job (`src/ui/dev/ui_capture.gd`), out of this package's write scope.
- I did not run the full `tests/` suite, the banned-API grep check, or any other package's covering suites, per the brief's "never run the whole `res://tests` folder" / "one suite at a time" rule.
- The `HANDOFF.md` fold-in text above is written here only; I did not add it to `HANDOFF.md` itself (not in this task's named write scope).
- I did not visually confirm the accent strip / entrance / highlight-lift animations in a running editor (the brief forbids launching the editor and `run_project`/`game_*` MCP tools); correctness here rests on the headless test results above plus the direct `ClassDB`/runtime property probes of `offset_transform_*` cited in the `draft_card_view.gd` section, not a screenshot.

## Round 2

`phases/UI_PASS/LEDGER.md` and `REVIEW.md` did not exist in this worktree when I started (checked: not in `phases/UI_PASS/`, not in `phases/UI_PASS/package_reports/`, no commit in `git log --all` touched either name; `RESUME.md`'s own "What is NOT done" confirmed why -- the blind review meant to produce them "was started and then stopped unfinished"). I began from BRIEF_R2.md's own inline descriptions of UR-06/UR-08/UR-03, and from the orchestrator's task message for the two items BRIEF_R2.md does not itself number. Both files appeared in the shared worktree partway through this session (another package's concurrent work, per the brief's own standing warning about this worktree) -- rechecked once implementation was done: `LEDGER.md` row **UR-24** is exactly the highlight-cue finding I was given directly ("the Draft's highlighted-card border gap narrowed from 3/7 px to 2/3 px; a 1.05 lift compensates, but the static cue is weaker than before"), so that item is cited by ID below. The description-to-rank gap has no row of its own in `LEDGER.md` or a matching passage in `REVIEW.md` -- it reads as an orchestrator finding made directly from the frames, outside the R1 blind review's own scope, so it stays quoted rather than cited by an ID that does not exist for it. `LEDGER.md` also names two rows this package's task list and this file's own round-1 `> Superseded:` note already cover: **UR-03** (glyphs not in the shipped font, naming `draft_card_view.gd` and `draft_controller.gd` explicitly) and **UR-17** ("Three package reports describe code that no longer exists ... `draft_strings.gd`"). `LEDGER.md`'s own Status column reads "open" for every row including these two -- I am not marking either row's status here; that is the reviewer's/orchestrator's column to update, not mine.

### UR-06 -- separation overrides

Five `add_theme_constant_override("separation", UiPalette.SPACE_*)` calls existed across my three files (`draft_fill_ring.gd` has none). All five converted or removed; none needed to stay an override (none are computed, and none of the five nodes already carried another `theme_type_variation`):

- `draft_controller.gd`: `column` (VBoxContainer, was SPACE_XL) -> `theme_type_variation = UiTheme.vbox("XL")`. `_card_row` (HBoxContainer, was SPACE_XXL) -> `UiTheme.hbox("XXL")`. `bottom_row` (HBoxContainer, was SPACE_L) -> `UiTheme.hbox("L")`.
- `draft_card_view.gd`: `_column` (VBoxContainer, was SPACE_M) -> `UiTheme.vbox("M")`. `header_row` (HBoxContainer, was SPACE_S) -> override deleted outright, per the brief's own instruction for the SPACE_S case: `ui_theme.gd`'s `_build_containers()` already sets HBoxContainer's default `separation` to `SPACE_S`, so `header_row` needed nothing at all.

### UR-08 -- explicit string registration

Only `draft_controller.gd` calls `tr()` (`draft_card_view.gd` and `draft_fill_ring.gd` do not -- grepped `tr(` across all three first). Added `UiStrings.ensure_registered()` as the literal first line of `_build_ui()`, with a one-line comment saying it is not relying on `UiTheme.get_theme()`'s side effect a few lines below. `ensure_registered()` is idempotent (`_registered` guard in `ui_strings.gd`), so calling it twice in the same function is inert, not a bug.

### UR-03 -- glyphs the font does not have

Checked directly against the shipped font rather than trusting the pre-existing header comments that already claimed this (`shape_glyph.gd`'s and `outcome_glyph.gd`'s own headers). Ran a standalone `SceneTree` script headless (`Font.has_char()` against `res://assets/ui/fonts/PixelifySans-Variable.ttf`):

```
U+25B2 (triangle up, GLYPH_PLAYER) has_char=false
U+25A0 (black square, GLYPH_TOWER) has_char=false
U+25CF (black circle, CONSOLE_GLYPH_PLAYER) has_char=false
```

(The third is Package C's glyph, checked only for corroboration -- not touched by this package.)

**`draft_card_view.gd`:** `_glyph_label` is now built as `UiShapeGlyph.new()` instead of `Label.new()`. `setup()` still sets `.text = GLYPH_PLAYER if is_player else GLYPH_TOWER` unchanged (the constants themselves are untouched -- still `"▲"`/`"■"` as plain strings, just never rendered as text glyphs any more; `UiShapeGlyph` paints its own text fully transparent per its own header), and additionally sets `.shape = UiShapeGlyph.Shape.TRIANGLE / SQUARE` and `.glyph_color = UiPalette.PLAYER / UiPalette.TOWER` (matching the accent strip's own tint, so the glyph reinforces rather than contradicts it). Sizing moved from `add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_HEADING)` to `set_side(UiPalette.FONT_SIZE_HEADING)`, per the task's own instruction. `get_glyph_label()`'s declared return type stays `Label` (`var _glyph_label: Label` is unchanged; only the concrete instance assigned to it changed) -- `tests/unit/draft_input_lockout_test.gd`'s `test_card_differentiation_is_never_colour_alone` reads `card.get_glyph_label().text` against `DraftCardView.GLYPH_PLAYER`/`GLYPH_TOWER` (see the suite's own count, 11/11 cases 0 errors 0 failures, below).

**`draft_fill_ring.gd`:** added `@export var center_shape: int = -1`, additive next to the existing `@export var center_glyph: String = ""`. `_draw()` now checks `center_shape >= 0` first (drawing via a new `_draw_center_shape()`, which calls `UiShapeGlyph.draw_shape(self, center_shape as UiShapeGlyph.Shape, rect, color)`), falling back to the untouched `center_glyph != ""` / `_draw_center_glyph()` path otherwise. Grepped `src/` and `tests/` for every reader of `DraftFillRing`, `center_glyph`, and `menu_frame.gd`'s `style_fill_ring()` (the one place outside `draft_controller.gd` that touches this ring's exports): `style_fill_ring()` sets only `ring_color`/`track_color`, never `center_glyph` or `center_shape`, so it is untouched by this change and keeps its previous glyph-less look, satisfying the "purely additive, default leaves an untouched caller rendering exactly as before" constraint. `paused_choice_bar.gd` holds a `DraftFillRing` reference but (grepped) never sets either centre property either.

**`draft_controller.gd`:** `_fill_ring.center_glyph = HOLD_RING_GLYPH` replaced with `_fill_ring.center_shape = UiShapeGlyph.Shape.TRIANGLE`. `HOLD_RING_GLYPH` (the `"▲"` constant) removed outright -- grepped `src/` and `tests/` first; its only reader was this one assignment.

Verified visually, not just by absence of tofu boxes in a text render: cropped and 4x-upscaled the hold ring from a capture (`phases/UI_PASS/screenshots/_scratch_B/ring_crop.png`) -- a clean vector triangle, same geometry as the card glyphs, no font fallback involved since none is drawn through a font at all any more.

### UR-01 -- the ligature, and every string against its source data

Not a defect in my files (the font-level `_make_font()` fix in `ui_theme.gd` already landed, per BRIEF_R2's "already done, do not edit" section) -- this item was "read every string and confirm," not "fix." Ran the capture tool three ways (`--resolution 1920x1080`, `--resolution 1280x720`, and `--resolution 1920x1080 --pseudo`, plus one combined `--resolution 1280x720 --pseudo` for the item-5 stress case below) and read `02_draft.png` from each against `data/upgrades/*.tres` and `src/ui/theme/ui_strings.gd`:

| On screen | Source | Match |
| --- | --- | --- |
| Title: "Level-Up Draft" | `ui_strings.gd` `MESSAGES["DRAFT_TITLE"]` = "Level-Up Draft" | exact |
| Card 1: "Heavy Rounds" / "+20% player weapon damage per rank" / "Rank 1 of 3" | `data/upgrades/heavy_rounds.tres`: `"Heavy Rounds: +20% player weapon damage per rank"`, `max_rank=3` | exact |
| Card 2: "Caliber" / "+20% Tower weapon damage per rank" / "Rank 1 of 3" | `data/upgrades/caliber.tres`: `"Caliber: +20% Tower weapon damage per rank"`, `max_rank=3` | exact |
| Card 3: "Rapid Fire" / "+20% player fire rate per rank" / "Rank 1 of 3" | `data/upgrades/rapid_fire.tres`: `"Rapid Fire: +20% player fire rate per rank"`, `max_rank=3` | exact -- no "Are rate" ligature artifact in any of the three captures |
| Reroll pill: "Reroll: R / Square" | plain literal in `draft_controller.gd` (not `tr()`-driven, not data-driven -- pre-existing, untouched this round) | matches its own source |

At `--pseudo`, `tr()`-driven text (the title) rendered `"[[Lévél-Üp Dráft]]"` -- the expected pseudolocalization transform, not a raw key leak. The three cards' own text (`effect_description`, not routed through an explicit `tr()` call in `draft_card_view.gd`) still went through Godot's `Control.auto_translate_mode` and came out accent-substituted too (e.g. "Héáṽý Ŕôüṇḍś"), with single parentheses rather than the title's double brackets -- an existing engine/project pseudolocalization-affix behavior I did not investigate further (it is not part of any item on my list, and `draft_card_view.gd`/`draft_controller.gd` do not configure it). No string was wrong, truncated, or replaced with a raw key in any of the four captures.

### The highlight cue (LEDGER UR-24, Nit)

`LEDGER.md`: "The Draft's highlighted-card border gap narrowed from 3/7 px to 2/3 px; a 1.05 lift compensates, but the static cue is weaker than before" (evidence: `src/ui/draft_card_view.gd`; `screenshots/after_1920/02_draft.png`). Matches the task's own wording to me verbatim. Looked at `02_draft.png` (and the 1280x720 and pseudo captures) before changing anything: agreed with the review's premise for a colour-blind read of the *previous* round-1 state (1px width delta, 5% scale, both subtle in a still frame) -- the fix needed to make the highlighted card unmistakable by shape/size, not restate the existing colour change more loudly.

Three changes, all in `draft_card_view.gd`, all local consts with `## TODO(ui-pass): promote to UiPalette` (`UiPalette` has no "emphatic selection" border tier or shadow scale):

1. `BORDER_WIDTH_HIGHLIGHTED`: `UiPalette.BORDER_THICK` (3) -> a local `5`. Gap versus `BORDER_WIDTH_NORMAL` (`UiPalette.BORDER_THIN` = 2) goes from 1px to 3px.
2. `HIGHLIGHT_LIFT_SCALE`: `1.05` -> `1.09`.
3. New: a stylebox shadow (`shadow_size`/`shadow_color`/`shadow_offset` on the owned per-instance `StyleBoxFlat`), present only while highlighted (`shadow_size = 0` otherwise) -- a silhouette difference (presence/absence, not a colour swap), applied in `_apply_highlight_style()` alongside the existing synchronous border width/colour change, so every test reading the frame style still sees the correct value the instant `set_highlighted()` returns.

Confirmed in `02_draft.png` at all three capture conditions: the highlighted card (whichever one it was in a given capture -- see the note on `simulate_hover_for_test()` timing below) is now obviously larger and carries a visibly thicker glowing border versus the other two cards' thin, flat lines, readable as a difference in size and border weight alone.

### Item 5 -- the ~200px gap between the description and "Rank 1 of 3" (no matching LEDGER row; quoted from the task)

Read the frame before changing anything: confirmed the gap. Root cause, traced in `draft_card_view.gd`: `_effect_label` was the VBoxContainer's only `size_flags_vertical = SIZE_EXPAND_FILL` child, so it alone absorbed the entire difference between the card's `CARD_MIN_SIZE` height (`draft_controller.gd`, 420px) and the column's actual content height, then top-aligned its own text within that inflated box -- putting all the slack directly between the effect text and the Rank line below it.

Two changes:
1. `draft_card_view.gd`: removed `size_flags_vertical = Control.SIZE_EXPAND_FILL` from `_effect_label`. With no child expanding, `VBoxContainer`'s default top alignment packs every label tight against its neighbour and pushes any leftover slack to the bottom of the card (a plain margin) instead of mid-content.
2. `draft_controller.gd`: `CARD_MIN_SIZE` height `420` -> `300` (width `360` untouched -- unrelated to this gap). This is a `TODO(ui-pass)` local const already (no Register row owns a card's pixel footprint, confirmed in round 1), so tightening its value is squarely "container-driven, no new fixed size" -- it is still a *minimum*, not a cap: a Container's actual minimum size is the max of `custom_minimum_size` and its children's own computed minimum, so a card whose content genuinely needs more height (the longest authored effect text, `overdrive_fallback.tres`'s ~140-character sentence, is far longer than the three cards captured here) still grows past 300px rather than clipping -- I did not stage that specific fallback card through the capture tool to confirm this directly (out of scope effort for this item), but it follows from the same Container-driven sizing rule `docs/19` already states ("Containers must have a defined `custom_minimum_size` but no fixed `size`. They must expand vertically to fit text").

Measured result in `02_draft.png` (1920x1080): the gap between the effect text and "Rank 1 of 3" is gone (the two lines sit with the same `SPACE_M` rhythm as every other pair of lines in the column); a smaller, even margin remains below "Rank 1 of 3" at the card's bottom edge, which reads as ordinary card padding rather than dead space. Re-verified at 1280x720 and at 1280x720 with `--pseudo` together (the stress case named in the task): still no gap, no clipping, no overlap with the card's border.

### A timing observation, not something I changed

The two 1920x1080 captures and the two 1280x720 captures each highlighted a *different* card (the middle "Caliber"/Tower card at 1920x1080; the leftmost "Heavy Rounds"/Player card at 1280x720, in both the plain and `--pseudo` runs at that resolution). `ui_capture.gd`'s own script calls `draft.simulate_hover_for_test(1)` after a fixed 45-frame wait, but `_on_card_hovered()` (`draft_controller.gd`, untouched this round) ignores the hover entirely if the 0.4s real-time lockout has not yet elapsed (`if not _lockout_elapsed: return`), leaving `_highlighted_index` at its default `0`. Since the 0.4s lockout is wall-clock time, not frame-count time, whether 45 rendered frames covers 0.4s of real time depends on the machine's actual frame rate for that window size -- plausibly why the heavier 1920x1080 render (slower per-frame, more real time per 45 frames) consistently reached index 1 while the lighter 1280x720 render did not. This is a pre-existing race in the capture tool's own staging, not in anything I touched this round (`_on_card_hovered()`'s guard and the lockout timer are unchanged), and it did not block verifying either item above -- both the highlight cue and the gap fix are visible regardless of which specific card ends up highlighted. Flagging it since it means `02_draft.png` is not guaranteed to show the *same* card highlighted from one capture run to the next.

### Suites run (headless, one at a time, from the worktree root, after my last edit)

Same seven suites as round 1 (re-grepped `tests/` for `DraftController`, `DraftCardView`, `DraftFillRing`, `get_frame_style` first -- same seven runnable suites matched, plus the same non-suite `draft_test_helpers.gd`):

| Suite | Test cases | Errors | Failures | Flaky | Skipped | Orphans |
| --- | --- | --- | --- | --- | --- | --- |
| `draft_queue_test.gd` | 4 | 0 | 0 | 0 | 0 | 0 |
| `draft_input_lockout_test.gd` | 11 | 0 | 0 | 0 | 0 | 0 |
| `guaranteed_first_draft_test.gd` | 2 | 0 | 0 | 0 | 0 | 0 |
| `encounter_deferral_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| `draft_determinism_test.gd` | 2 | 0 | 0 | 0 | 0 | 0 |
| `xp_cap_check_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| `movement_only_test.gd` | 3 | 0 | 0 | 0 | 0 | 0 |
| **Total** | **28** | **0** | **0** | **0** | **0** | **0** |

Ran `--headless --path . --import` twice this round: once after the first pass of edits (caught a real error -- `const HIGHLIGHT_SHADOW_COLOR: Color = UiPalette.with_alpha(...)` is not a valid `const` initializer, since `with_alpha()` is a function call, not a constant expression; fixed by splitting it into a `const` alpha float and building the `Color` at the call site instead), once after fixing that error (clean). All seven suites above were run only after that second, clean import and after every code edit in this section, including the final `CARD_MIN_SIZE` tune.

Not asserting any suite, package, or gate is "passed" or "satisfied" -- these are the raw counts from the runs above for the reviewer to judge.

### Left undone / not verified by me

- Did not stage the no-max-rank fallback cards (`overdrive_fallback.tres`/`reinforce_fallback.tres`) through the capture tool to directly confirm their longer effect text grows the card past the new, smaller `CARD_MIN_SIZE` rather than clipping -- reasoned from the Container-driven sizing rule instead (see item 5 above), not measured.
- Did not investigate the pseudolocalization parenthesis-vs-double-bracket affix inconsistency noted under UR-01 -- outside every item on this round's list and not something `draft_card_view.gd`/`draft_controller.gd` configure.
- Did not fix the `ui_capture.gd` hover-timing race noted above -- outside my write scope (`src/ui/dev/**` is explicitly not mine to edit) and outside this round's task list; named for whoever owns that tool.
- `phases/UI_PASS/LEDGER.md` and `REVIEW.md` did not exist for most of this session (see the "Round 2" opening note); I worked from BRIEF_R2.md's own text and the orchestrator's task message throughout, and only cross-checked against `LEDGER.md`/`REVIEW.md` after they appeared and my implementation was already done. I did not re-read either file for anything beyond the two items already in my task list -- other rows in `LEDGER.md` (UR-01, UR-02, UR-05, and the rest) belong to other packages or the orchestrator, not this one.

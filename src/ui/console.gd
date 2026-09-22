extends Node2D
class_name Console

## Console (P2.13 - Tower Console). docs/19_UI_UX.md > "Tower Console UI" in
## full (Presentation, Contents, Input, Lifecycle, Placement,
## Differentiation); MASTER_SDLC.md > Provisional Values Register >
## "Interfaces" > "Tower Console rules" (C-CONSOLE-NODE, C-REPAIR,
## C-AUTOFIRE) and > "Movement-only controls setting" (C-SECTORS); >
## "Progression & Upgrades" > "Console price", "Fallback cards"
## (C-FALLBACK-CONSOLE); > "Tower Overview" > "Health Recovery Rules"
## (Repair formula); > "Economy & Pickups" > "Scrap". Every number below is
## cited to one of those rows in a comment beside its constant, never
## restated as a bare literal in logic.
##
## ## The one hard rule this whole file exists to protect
## "The Console is the Draft's opposite in every operational respect: it
## never pauses the simulation." (task brief; MASTER_SDLC.md > Global
## Simulation Authority: "The Tower Console is the one exception to
## pausing... it never adds a pause reason and is never itself frozen by
## another reason's effect on the tree -- instead it manually hides itself
## and stops accepting input whenever PauseAuthority's reason set is
## non-empty"). Consequences this file draws from that one sentence:
##   1. This node's own `process_mode` is PROCESS_MODE_ALWAYS, NOT the
##      PROCESS_MODE_PAUSABLE every other gameplay entity in this codebase
##      uses -- the one deliberate exception in the project, named here so a
##      future reviewer does not "fix" it back to PAUSABLE. Everything this
##      node reads through SimClock.now still freezes correctly during a
##      pause (SimClock itself is PAUSABLE), so a frozen dwell/channel
##      deadline simply stops advancing and resumes exactly where it left
##      off with no drift -- this file never needs to compensate for a
##      pause duration itself.
##   2. Nowhere in this file calls `PauseAuthority.push_reason()` /
##      `pop_reason()` / `push_reason_immediate()` / `pop_reason_immediate()`
##      -- grep confirms it. The Console only ever LISTENS to
##      `PauseAuthority.reasons_changed` (via `_on_pause_reasons_changed()`)
##      to hide itself and go input-dead; it never writes pause state.
##   3. `_paused` (mirrors "the reason set is non-empty") gates both
##      `_process()`'s visibility and `_unhandled_input()`'s handling
##      explicitly, rather than relying on the engine's automatic
##      PROCESS_MODE_PAUSABLE gating -- because this node is ALWAYS mode, the
##      engine would otherwise keep showing/accepting input on a stale
##      Console during, say, the pause menu. The one exception that gets
##      MORE than "hidden": the `draft` reason specifically also forces a
##      real close (`_close_console()`), per the Lifecycle rule's explicit
##      "closes on ... a Level-Up Draft opening" -- distinct from a mere
##      pause-menu/focus-loss freeze, which preserves `_is_open` underneath
##      the hide so it reappears open (not re-dwelled) once that OTHER
##      reason clears. Named as an interpretation, not restated Register
##      text -- see the evidence report, "Interpretations."
##
## ## SimLoop registration (task instruction: "Register at SimLoop step 12
## ... rather than polling in _process")
## Every gameplay deadline below (`_dwell_started_at`, `_channel_started_at`)
## is an ABSOLUTE SimClock.now snapshot compared with `>=`, never a `_process`
## delta accumulator -- matching src/tower/tower_health.gd's shield-regen
## convention and src/player/player.gd's input-buffer convention exactly.
## `physics_step(delta)` is the public per-tick entry point docs/20's SimLoop
## order names as step 12 (CONSOLE_CHANNEL_COMPLETION); `driven_externally`
## (default false) mirrors every other `driven_externally`-capable file in
## this codebase (auto_weapon.gd, player.gd, wave_director.gd) -- this file
## self-drives via its own `_physics_process()` until a future integration
## task calls `SimLoop.register(SimLoop.Step.CONSOLE_CHANNEL_COMPLETION,
## console)` and sets `driven_externally = true` in the assembled scene
## (scenes/prototype.tscn is outside this task's write scope, per its hard
## constraints -- named as a required seam in the evidence report, exactly
## the same shape as wave_director.gd's and auto_weapon.gd's own unresolved
## SimLoop seams). `_process(delta)` (visual placement/scale/text refresh
## only, never a gameplay decision) mirrors src/camera/game_camera.gd's own
## precedent of running purely-visual work in `_process` rather than
## `_physics_process` (that file's own header cites "the godot-prompter
## camera-system skill's own implementation checklist").
##
## ## Cross-task seams this file could not close itself (hard constraints:
## src/economy/**, src/tower/**, src/upgrade/** are off limits this session)
## - RunInventory (src/economy/run_inventory.gd) exposes `credit_scrap()`
##   (adds only; `amount <= 0` is a no-op) but no debit/spend command. This
##   file charges a purchase by writing `_run_inventory.scrap_current`
##   directly, clamped at 0 -- the SAME direct-public-field-write pattern
##   this codebase already uses for exactly this class of gap (src/player/
##   player.gd's own `heal()`, and src/tower/tower_health.gd's own
##   `configure()` writing `_death_state.current_hp` directly). A proper
##   `RunInventory.spend_scrap(amount)` command is the correct home for this
##   and is named as a required seam in the evidence report.
## - TowerHealth (src/tower/tower_health.gd) exposes no heal()/restore()
##   command either. Repair writes `tower.death_state.current_hp` directly,
##   mirroring TowerHealth's OWN `configure()` doing exactly that to the same
##   field. Named as a required seam (`TowerHealth.repair(amount)`) in the
##   evidence report.
## - UpgradeSystem.apply_rank() (src/upgrade/upgrade_system.gd) "has no cost
##   concept" (F05-08, anticipated in that task's own ledger) -- this file
##   charges Scrap itself, BEFORE calling apply_rank() would be wrong (a
##   channel that completes must charge exactly once even if apply_rank()
##   somehow failed after a successful afford-check, which it cannot in the
##   single-player, single-writer case) -- so this file charges AFTER
##   apply_rank() returns true, never before, and never if apply_rank()
##   returns false.
##
## ## Wiring seams the orchestrator must complete (this file cannot touch
## scenes/prototype.tscn, src/tower/**, src/player/**, src/economy/**,
## src/upgrade/** this session)
## `tower_path`, `player_path`, `player_weapon_path` (falls back to
## `_player.get_node_or_null("AutoWeapon")` if unset -- matches
## scenes/player.tscn's fixed child name), `upgrade_system_path`,
## `camera_path` are all `@export`ed NodePaths resolved in `_ready()`,
## exactly like every other P2.x component in this codebase
## (Tower/Player/Hud's own `*_path` + `get_node_or_null()` convention).
## `set_run_inventory(RunInventory)` is a typed COMMAND (not merely a test
## seam) the orchestrator must call once, because RunInventory is a
## RefCounted (P2.10), not a scene node a NodePath can find.
##
## ## Presentation simplification, named rather than silently shipped
## docs/19 describes each purchase channel "with a fill ring." UI PASS
## UPDATE: this file now uses the real ring (`DraftFillRing`, src/ui/
## draft_fill_ring.gd -- owned by the Draft package this session; used here
## only through its existing public surface: `progress`, `ring_color`,
## `track_color`) instead of the linear `ProgressBar` this comment used to
## describe as a deliberate simplification. Functionally identical to the
## old bar (0..1 progress, visible only while a channel is active,
## `get_channel_progress_for_test()` unchanged) -- the substitution is look
## only, named here rather than silently done.
##
## ## GodotPrompter skill conflict, recorded per CLAUDE.md
## The `godot-ui` skill's own guidance: "Place UI nodes inside a
## `CanvasLayer` ... so they render on top of the 3D/2D world, unaffected by
## Camera transforms." docs/19 > "Tower Console UI" > "Placement" and the
## Register's C-CONSOLE-NODE row are explicit and binding the other way: the
## Console is "a world-space Node2D under the gameplay root," deliberately
## AFFECTED by the camera (its own `scale` is set every frame from
## `GameCamera.get_view_scale()` so its text keeps a constant on-screen
## size as the camera zooms) so it can sit anchored beside the Tower rather
## than pinned to the screen. This project's document wins; recorded here
## and in the evidence report/LEDGER per CLAUDE.md's GodotPrompter section.
##
## ## UI pass restyle (phases/UI_PASS/PLAN.md, package C) -- look and feel
## only; every rule/number/timer/node-name/`_for_test` seam above is
## UNCHANGED.
## - `UiTheme.get_theme()` is applied once, at `_panel` (the first Control
##   under this Node2D root -- see ui_theme.gd's own "apply ONCE, at its
##   root Control" contract). Every StyleBoxFlat/Color/font-size literal
##   this file used to hardcode now reads `UiPalette`/`UiTheme.make_box()`,
##   EXCEPT `ENTRY_FONT_SIZE_PX` (the Register's 24 px floor), which stays a
##   per-node `add_theme_font_size_override()` so the theme can never touch
##   it, exactly as before.
## - A compact header (title + the player's current Scrap, both already
##   shown/read by this file -- no new data) and, per entry row: a dim
##   number-key-hint chip (1-7, matching `SELECT_ACTIONS`), a leading caret
##   glyph shown only while highlighted, and a right-aligned price chip
##   (struck through and greyed when unaffordable, replaced by a MAX badge
##   when maxed) are all NEW SIBLING nodes. The pre-existing `Frame`,
##   `Glyph`, `Header`, `Text` nodes keep their exact names, types, and (for
##   `Text`) content format -- `get_entry_label_for_test(i)` reads the same
##   node with the same string it always did; only its font COLOUR (via
##   `add_theme_color_override`, not the old `modulate` multiply) changed
##   from a bare `Color(0.55,0.55,0.55,1)` to `UiPalette.TEXT_DISABLED`.
## - Layout-collapse fix (evidence: a windowed capture of the assembled
##   scene, phases/UI_PASS/screenshots/before_1920/05_console.png, showed
##   the panel as a narrow column with every entry wrapped one character
##   per line down its full height). Root cause #1: `Text`'s
##   `size_flags_horizontal = SIZE_EXPAND_FILL` + `autowrap_mode =
##   AUTOWRAP_WORD_SMART` has NO minimum width of its own, so its natural
##   minimum size collapses toward zero and the whole panel follows it down
##   to a sliver, wrapping every word (then every character) onto its own
##   line. Fixed with two `custom_minimum_size` floors -- `ROW_TEXT_MIN_
##   WIDTH_PX` on every row's `Text` label and `PANEL_MIN_WIDTH_PX` on
##   `_panel` itself -- neither of which is a fixed `size` (both stay
##   `custom_minimum_size`, so the panel/labels still expand freely beyond
##   the floor: docs/19 > "UI Layout & Dynamic Container Rules" > "Max
##   Dimensions": "Containers must have a defined custom_minimum_size but no
##   fixed size"). Root cause #2, found while verifying the fix (tests/
##   unit/ui_console_layout_test.gd's pseudo-localization case): every
##   Control auto-translates its own text by default, and Godot's
##   pseudo-localization runs on top of THAT -- fine for a plain Label, but
##   `PriceTag` (a RichTextLabel holding hand-built BBCode markup, never a
##   translatable message) had its `[right]`/`[color]`/`[s]` tags
##   themselves mangled into unrecognisable garbage, so RichTextLabel
##   stopped parsing them as tags and rendered the whole garbled string as
##   one unbreakable literal line -- a 64 px floor ballooning to ~590 px per
##   row. Fixed with `price_tag.auto_translate_mode =
##   Node.AUTO_TRANSLATE_MODE_DISABLED` (see `_build_row()`).
##   Measured, with the real 7-entry catalogue (tests/unit/
##   ui_console_layout_test.gd, base resolution / view_scale 1.0): panel
##   672x773 px normal, 759x997 px pseudo-localized (+30%, width bounded,
##   height grows via wrapping -- neither collapses nor explodes). The
##   residual tension neither fix resolves: several `UpgradeDefinition.
##   effect_description` strings (data/upgrades/*.tres) are long enough
##   that even this sensible row width wraps them to 2-3 lines, so the real
##   catalogue's height (773-997 px) exceeds docs/19's own "Provisional
##   Default 30% of screen height" guidance (324 px at 1080p) by roughly
##   2-3x. This file's entry TEXT stays byte-for-byte unchanged per this
##   task's scope, and adding the scrolling docs/19 prescribes for that
##   case is a new interactive affordance, not a restyle -- both named as
##   follow-ups in the evidence report, not resolved here.
##   > Superseded (both the compaction follow-up below and UI pass round 2
##   > below): the compaction follow-up brought this down to 512x377 (later
##   > 528x377, round 2), and the author's 2026-09-20 decision (UR-25) gives
##   > the Console its own 35% allowance (378 px at 1080p) rather than
##   > docs/19's general 30%. The "roughly 2-3x" figure above describes the
##   > FIRST restyle pass only and no longer applies.
## - Open animation only (never close, per the task's own "hides
##   immediately" rule): a bare `create_tween()` on this node fades/scales
##   `_panel`'s own `modulate.a`/`scale` in from 0 whenever `_process()`
##   sees `visible` flip from false to true. `Console.modulate.a`
##   (`CONSOLE_OPACITY`) and `Console.scale` (the camera view-scale
##   compensation) are never touched by it -- both stay exactly the values
##   the rest of this file (and its tests) already depend on.
##
## ## UI pass follow-up: compaction (orchestrator decision, after seeing the
## first restyle rendered in the assembled scene: panel ~650x750 px, top
## clipped off-screen, every row 3-4 lines because it carried the FULL
## `effect_description` sentence plus rank plus price)
## The "entry text formats stay exactly as they are" constraint is LIFTED
## for the ROW LABEL's composition only, an explicit orchestrator decision,
## not a decision this file made itself: `get_entry_for_test(i)`'s own
## dictionary (its "name" field in particular, still the full
## `effect_description`) is byte-for-byte unchanged; only how
## `_refresh_one_row()` builds the VISIBLE `Text` string from it changes --
## checked against every covering test first (none asserts the row label's
## exact content; see the follow-up evidence report).
##   1. Row label shrinks to "<short name> <rank status>" (Repair: "Repair
##      +<heal> HP") -- the price moves OUT of this label entirely, into
##      `PriceTag` alone. `<short name>` is derived by splitting
##      `effect_description` on its first ':', the EXACT interpretation
##      src/ui/draft_card_view.gd's own `setup()` already uses and
##      documents (that file's header, "Name/icon derivation") -- read
##      here, not re-invented, via a new static `_split_name_and_effect()`.
##   2. A new `Footer` label (bottom of the panel, `UiTheme.DIM`) shows the
##      HIGHLIGHTED entry's effect sentence (the text after that same
##      first ':') -- the one place that full sentence now lives on
##      screen. `custom_minimum_size.y` reserves `FOOTER_MIN_LINES` worth
##      of height so the panel does not resize as the highlight moves
##      between a short and a long description.
##   3. Row chrome tightened for a one-line row: the pool differentiation
##      element (`Frame`) shrinks from a 24x24 swatch to a 4 px colour
##      strip (`UiPalette.SPACE_XS` wide) at the row's left edge; the
##      PRIMARY shape signal (rounded = Player, squared = Tower) moves to
##      the row's OWN corner radius instead, since a radius on a 4 px-wide
##      strip barely reads. This needed a per-row OWNED `StyleBoxFlat`
##      (`_row_styles[i]`, built via `UiTheme.make_box()`) rather than
##      `theme_type_variation = UiTheme.ROW`/`ROW_HIGHLIGHTED`, because a
##      type variation resolves to the Theme's ONE shared, cached
##      StyleBox -- mutating it per row would restyle every row (and every
##      other ROW-styled control project-wide) at once. This is
##      src/ui/draft_card_view.gd's own established pattern for the exact
##      same reason (that file's header: "never `theme_type_variation =
##      UiTheme.CARD` ... mutating it here would restyle every other
##      CARD-styled control project-wide"), applied here rather than
##      invented fresh. The number-key chip becomes a small
##      `RADIUS_SMALL`, `SIZE_SHRINK_CENTER`-on-both-axes square instead of
##      a `UiTheme.PILL` capsule that stretched to the row's full height.
## `tests/unit/ui_console_layout_test.gd` (this package's own file) gained
## a one-line-in-English assertion and a tightened height bound; measured
## panel sizes are in the follow-up section of the evidence report.
##
## ## UI pass round 2 (review fixes, phases/UI_PASS/BRIEF_R2.md) -- every
## rule/number/timer/node-name/`_for_test` seam above stays UNCHANGED except
## where named below.
## - **UR-06** (separation overrides): the three bare `add_theme_constant_
##   override("separation", ...)` calls (`Rows`, `HeaderRow`, `RowContent`)
##   are now `theme_type_variation = UiTheme.vbox("XS")` / `hbox("M")` /
##   `hbox("XS")`. None of the three nodes carried another type variation, so
##   none needed to stay an override.
## - **UR-08** (string registration): `UiStrings.ensure_registered()` is now
##   also called explicitly as `_build_ui()`'s first line, not reached only
##   as `UiTheme.get_theme()`'s own side effect a few lines later.
## - **UR-03** (glyphs): the row `Glyph` node is now a `UiShapeGlyph`
##   (`Shape.TRIANGLE` for a Player entry, `Shape.SQUARE` for a Tower entry,
##   `text` left empty, `set_side(UiPalette.FONT_SIZE_VALUE)`) instead of a
##   plain `Label` showing `tr("CONSOLE_GLYPH_PLAYER")`/`tr("CONSOLE_GLYPH_
##   TOWER")` -- neither key's character (U+25CF/U+25A0) exists in the
##   shipped font (tests/unit/ui_console_layout_test.gd checks `Font.
##   has_char()` directly). Both `tr()` keys are now unused by this file.
## - **UR-05** (price/MAX text floor): built as the conservative reading
##   pending an author decision -- that decision arrived 2026-09-20 (UI pass
##   LEDGER UR-25) and CONFIRMS it: the Register's 24 px floor covers the
##   row label AND the price/MAX badge (the header title, footer, key number
##   and pool word may stay smaller). No further code change needed.
##   `PriceTag`'s `normal_font_size` and `MaxBadgeLabel`'s `font_size` are
##   both raised to `ENTRY_FONT_SIZE_PX`, the SAME constant `Text` uses, so
##   all three sit under the identical floor and the identical per-frame
##   Node2D `scale` compensation. `PRICE_TAG_MIN_WIDTH_PX` widened 40 -> 48
##   to match. Nothing else was shrunk to pay for this.
## - **UR-10** (empty footer): Repair's footer was always empty (its "name"
##   has no ':' to split), leaving `FOOTER_MIN_LINES`' worth of blank space
##   reserved on every open, since Repair is the default highlighted entry.
##   `_refresh_footer()` now builds a one-line sentence from the SAME heal/
##   cost values the row and `PriceTag` already show
##   (the `CONSOLE_REPAIR_FOOTER` string) instead of leaving it blank. The
##   alternative BRIEF_R2 also offered -- reserving the footer's height only
##   while a ranked entry is highlighted -- was rejected because it resizes
##   the panel as the highlight moves onto/off Repair, which is the jump
##   this fix exists to remove.
## - **UR-11** (regression bound): `tests/unit/ui_console_layout_test.gd`
##   keeps its tight, current-measurement regression bound, and gains a
##   SEPARATE, clearly named assertion against a height requirement -- this
##   started as docs/19's general 30% screen-height cap (324 px at 1080p),
##   deliberately left FAILING (a known, named gap, not loosened or
##   skipped). Author decision 2026-09-20 (UI pass LEDGER UR-25) then gave
##   the Console its own allowance of ~35% of screen height (378 px at
##   1080p) instead, with docs/19 itself to be updated by its owner through
##   HANDOFF H-05 -- not this package's file to change. The assertion is now
##   a real, passing requirement check against that 378 px figure, not a
##   "known gap" placeholder; see that test file's own comment and the
##   report, "UR-11."
##
## ## CHANGE 1 (author decision D107, 2026-09-23): the Console opens on a
## key, not automatically
## Old rule: the Console auto-opened after the player had been nearly
## stopped (speed < 10% base) for `OPEN_DWELL_SECONDS` inside the
## Interaction Radius with >= 1 affordable entry -- players experienced that
## as a random pop-up (task brief). New rule for the DEFAULT control
## scheme: while the player is inside the radius and the Console is closed,
## a small prompt shows (`CONSOLE_PROMPT` when >= 1 entry is affordable,
## greyed `CONSOLE_PROMPT_UNAVAILABLE` otherwise -- ui_strings.gd; see
## `_build_prompt()`/`_refresh_prompt()`); pressing the new `console_open`
## action (keyboard E, gamepad Y / button index 3 -- both free in the
## existing Input Map, added to project.godot and recorded in docs/19)
## opens it immediately, AT ANY SPEED (`request_open()` below carries no
## speed gate at all, unlike the old dwell). Every other close condition is
## UNCHANGED (leaving the radius, Cancel, death, a Draft opening); after a
## Cancel, pressing `console_open` reopens the Console immediately --
## `request_open()` deliberately never consults `_requires_reentry`, so the
## player never again has to leave and re-enter the radius the way the OLD
## dwell-based lifecycle required for that one case.
##
## INTERPRETATION, named rather than silently resolved (docs/19's Input Map:
## "every menu has a movement-only path ... the Console's movement-only
## sector path ... require[s] none of the keys or buttons listed above"): a
## button press is, definitionally, a key or button, so it cannot become the
## ONLY way to open the Console without breaking that stated guarantee for
## Movement-only mode. The OLD 0.3 s dwell (`OPEN_DWELL_SECONDS`, the speed
## gate, `_requires_reentry`'s post-Cancel lock -- all UNCHANGED in
## substance) is therefore KEPT exactly as it always worked, but now scoped
## EXCLUSIVELY to `movement_only_controls_enabled == true` (`physics_step()`
## below short-circuits its own dwell branch on that flag first, added
## first in the condition so nothing else about the branch's logic moved).
## This is the smallest change that keeps
## `tests/unit/movement_only_test.gd`'s own named acceptance test
## ("completes a Console purchase from position and standing still alone,"
## no discrete input of any kind) true without inventing a second,
## undocumented opening mechanism -- a button-capable player may still call
## `request_open()` even with Movement-only enabled (it is never gated on
## the setting), so nobody loses capability; only the DEFAULT scheme loses
## the automatic pop-up. Recorded here, in the LEDGER, and in the Review
## Decision Log's D107 row rather than resolved unilaterally without a
## trace. This also reads D3's own "sector selection in the live Tower
## Console behind a default-off accessibility setting" as still satisfied:
## the setting still exists, still defaults off, and still needs no button.
##
## `_requires_reentry` therefore now has exactly ONE remaining consumer: the
## Movement-only dwell branch, so standing still right after a Cancel does
## not silently re-dwell-and-reopen a moment later. It is otherwise inert
## under the default scheme; `request_cancel()` itself is UNCHANGED (still
## sets it) since the Movement-only path still needs it set regardless of
## which scheme most recently closed the Console.
##
## C-AUTOFIRE re-examined, per the task brief's own instruction ("check
## whether auto-fire disabling inside the radius still makes sense"): YES,
## unchanged. `physics_step()`'s auto-fire suppression is driven purely by
## `inside` (body overlap), never by `_is_open` or the opening mechanism --
## it already fires "at ANY speed while overlapping the Interaction Radius"
## regardless of whether the Console ever opens at all (Register >
## Interfaces > "Tower Console dwell / auto-fire", C-AUTOFIRE). Nothing
## about WHEN or HOW the Console opens touches that rule's own premise (the
## Vulnerability Window is about entering the radius, not about shopping),
## so it is kept exactly as the Register states it, per the task brief.

# --- Provisional Values Register > Interfaces > "Tower Console rules" ------
## CHANGE 1 (D107): scope narrowed. This is now Movement-only mode's OWN
## no-button open path only (see class doc, "CHANGE 1"); the default scheme
## opens via `request_open()` (console_open: E / gamepad Y) instead, with no
## dwell and no speed gate at all.
const OPEN_DWELL_SECONDS: float = 0.3 # "Opens after 0.3 s inside the radius..."
const SPEED_GATE_FRACTION: float = 0.10 # "...while player speed < 10% base..."
const CHANNEL_DURATION_SECONDS: float = 0.5 # "...every purchase is a 0.5 s channel..."
const PLACEMENT_DISTANCE_PX: float = 200.0 # "...nearest edge 200 px from the Tower's centre..."
const PLACEMENT_FLIP_THRESHOLD_DEG: float = 30.0 # "...flipping only after a 30 degree change."
const CONSOLE_OPACITY: float = 0.85 # "...85% opacity..."
const CONSOLE_Z_INDEX: int = 38 # "...z_index 38 (above enemies, below telegraphs)..."
const ENTRY_FONT_SIZE_PX: int = 24 # "...text stays >= 24 px tall on screen..."

# --- Provisional Values Register > Interfaces > "Movement-only controls
# setting" (C-SECTORS) ------------------------------------------------------
const SECTOR_COUNT: int = 7 # "seven fixed 51.4 degree sectors clockwise from north"
## INTERPRETATION, named rather than silently resolved: the Register states
## 51.4 degrees, a value rounded to one decimal for display; 7 x 51.4 =
## 359.8, which would leave a 0.2 degree dead zone belonging to no sector.
## 360.0/7.0 (51.428571...) is used here so the seven sectors exactly tile a
## full circle with no gap a player could stand in and trigger nothing.
## Recorded in the evidence report, "Interpretations."
const SECTOR_WIDTH_DEG: float = 360.0 / float(SECTOR_COUNT)
const SECTOR_DWELL_SECONDS: float = 1.0 # docs/19 > Tower Console UI > Input: "Standing still ... inside a sector for 1.0 second buys one rank"

## Register > Tower Overview > "Health Recovery Rules": "One purchase
## restores min(50, missing health rounded down to an even number, 2 x Scrap
## held) health at 1 Scrap per 2 health." The 1:2 ratio itself is read live
## from `TowerDefinition.repair_price` (data/tower/base.tres), never
## hardcoded here; the "50" ceiling has no dedicated contract field to carry
## it (same pattern as this file's own CONSOLE_Z_INDEX above), so it is
## cited here as a named constant instead of a bare literal.
const REPAIR_MAX_HEAL: float = 50.0

const PLAYER_IDS: Array[String] = ["rapid_fire", "heavy_rounds", "patch_kit"]
const TOWER_IDS: Array[String] = ["caliber", "optics", "shield_matrix"]

## Sector order clockwise from north, index 0 held for Repair (handled by a
## dedicated branch, never looked up here). docs/19 > Tower Console UI >
## Input: "Repair, Rapid Fire, Heavy Rounds, Patch Kit, Caliber, Optics,
## Shield Matrix" -- the SAME order as `console_select_1..7` (below) and the
## catalogue's own first seven entries.
const SECTOR_IDS: Array[String] = ["", "rapid_fire", "heavy_rounds", "patch_kit", "caliber", "optics", "shield_matrix"]

const SELECT_ACTIONS: Array[StringName] = [
	&"console_select_1", &"console_select_2", &"console_select_3", &"console_select_4",
	&"console_select_5", &"console_select_6", &"console_select_7",
]

const MAX_LIST_ENTRIES: int = 9 # 7 fixed + Overdrive + Reinforce (C-FALLBACK-CONSOLE)

# --- UI pass: cosmetic-only layout tokens. NOT Register/docs-19 numbers --
# nothing above this line moved, and nothing below changes a rule, a price,
# or the 24 px text floor. UiPalette has no "how wide is a Console row"
# concept yet; these stay local consts with a promotion TODO rather than
# bare literals scattered through _build_ui(), per phases/UI_PASS/BRIEF.md's
# "list it in your report and use a local const ... for now."
## TODO(ui-pass): promote to UiPalette. Base-resolution (view_scale = 1.0)
## minimum width for an entry row's Text label. Without an explicit
## minimum, a SIZE_EXPAND_FILL + AUTOWRAP_WORD_SMART Label reports a
## near-zero natural minimum width, so the row -- and with it the whole
## panel, since _panel_half_extent() sizes _panel from its children's
## combined minimum -- collapses toward zero width and wraps every entry
## one character per line (reproduced in the assembled scene: phases/
## UI_PASS/screenshots/before_1920/05_console.png). This is a FLOOR
## (custom_minimum_size), not a fixed size: text still wraps and grows past
## it under pseudo-localization exactly as docs/19 requires. UI PASS
## FOLLOW-UP: narrowed from 360 -> 300 alongside the row-label shortening
## (class doc, "UI pass follow-up: compaction") -- the shortened row label
## ("<name> Rank n of 3") fits one line well under this floor in English;
## sized against the real catalogue's longest such label, not guessed.
const ROW_TEXT_MIN_WIDTH_PX: float = 300.0
## TODO(ui-pass): promote to UiPalette. Overall panel width floor so the
## Console reads as one deliberate compact panel at every entry count (7
## fixed, up to 9 once a pool's fallback card appears) rather than hugging
## whatever its narrowest visible row happens to need that frame. UI PASS
## FOLLOW-UP: narrowed from 480 -> 420 -- a floor only; the real catalogue's
## natural width (driven by row content, not this floor) is what the
## follow-up report measures.
const PANEL_MIN_WIDTH_PX: float = 420.0
## TODO(ui-pass): promote to UiPalette. Minimum width for the right-aligned
## price chip (a RichTextLabel; see _refresh_price_and_badge()) -- the same
## zero-minimum risk as ROW_TEXT_MIN_WIDTH_PX above, at a much smaller
## scale (a 2-3 digit number), so it gets the same explicit floor. UI PASS
## FOLLOW-UP: narrowed from 64 -> 40 (compaction; still fits "999"). UI PASS
## ROUND 2 (UR-05): widened 40 -> 48 (40 * ENTRY_FONT_SIZE_PX/FONT_SIZE_BODY,
## i.e. 40 * 24/20) alongside the price tag's own font-size floor raise, so
## "999" still fits at the larger size without the row wrapping the price.
const PRICE_TAG_MIN_WIDTH_PX: float = 48.0
## TODO(ui-pass): promote to UiPalette (as a motion token) if another
## surface ever wants the same pop-in. The fraction of full size _panel
## starts at when the Console's open animation begins (see
## _play_open_animation()) -- purely cosmetic, never read by a test.
const OPEN_ANIM_START_SCALE: float = 0.92
## Leading highlight marker (item 4, "a leading caret glyph"). Plain ASCII
## so it renders regardless of the shipped font's exact glyph coverage (the
## font's own header cites covering "the accented Latin range", not
## necessarily general Unicode arrows/carets).
const CARET_GLYPH: String = ">"
## UI PASS FOLLOW-UP tokens (compaction pass, see class doc). None of these
## is a Register/docs-19 number -- all cosmetic layout, same TODO-promote
## reasoning as the block above.
## Width of the pool-colour strip ("a thin 4 px bar at the row's left
## edge", the coordinator's own follow-up wording) -- reads UiPalette.SPACE_XS
## directly rather than a new const, since that token IS already 4.
## Fixed square footprint for the number-key chip ("a small rounded square
## with the digit centred").
const NUMBER_CHIP_SIZE_PX: float = 22.0
## Reserved height for the highlighted entry's effect-sentence footer, in
## whole lines -- "reserve a minimum height for two lines so the panel does
## not jump when the highlight moves between short and long descriptions."
## One line since the font change: every ranked upgrade's sentence fits one
## line at the panel's width, and two reserved lines put the panel 18 px over
## the author's 35% allowance (UR-25). Only the two pool-exhausted fallback
## entries run longer, and the panel grows for those.
const FOOTER_MIN_LINES: int = 1

## UI PASS ROUND 2 (UR-10). Repair's own "name" is the plain word "Repair"
## (tr("CONSOLE_REPAIR")), never an "<name>: <effect>" sentence the way every
## upgrade's effect_description is, so splitting it on ':' in
## _refresh_footer() always produced an EMPTY footer for Repair -- the entry
## highlighted by default on open (_open_console() resets _highlighted_index
## to 0) -- leaving FOOTER_MIN_LINES' worth of reserved blank space every
## time the Console opens (the defect this item fixes). The sentence is
## the `CONSOLE_REPAIR_FOOTER` string (ui_strings.gd), filled with the same
## heal and cost values the row already shows.

# --- Wiring (orchestrator completes; scenes/prototype.tscn is out of this
# task's write scope) --------------------------------------------------------
@export var tower_path: NodePath
@export var player_path: NodePath
@export var player_weapon_path: NodePath
@export var upgrade_system_path: NodePath
@export var camera_path: NodePath

## C-SECTORS: "Default off; offered as a hold-to-confirm choice on run-end
## screens and pause/settings menus." A plain exported property so the
## pause/settings menu (P2.14, not this task) can toggle it directly:
## `console.movement_only_controls_enabled = true`.
@export var movement_only_controls_enabled: bool = false

## See class doc, "SimLoop registration."
@export var driven_externally: bool = false

var _tower: Tower = null
var _player: Player = null
var _player_weapon: AutoWeapon = null
var _upgrade_system: UpgradeSystem = null
var _camera: GameCamera = null
## Untyped deliberately: production wiring assigns the Tower's real
## TowerInteractionRadius (an Area2D), but tests inject a lightweight double
## exposing only `is_player_inside() -> bool` (this file's own only call on
## it) so the non-pause/rules tests do not depend on a real Area2D physics
## overlap tick -- that overlap detection itself is P2.4's own scope, not
## re-tested here.
var _interaction_radius: Object = null
var _run_inventory: RunInventory = null

var _clock: Node = null
var _pause_authority: Node = null
var _event_bus: Node = null

var _paused: bool = true # updated the instant PauseAuthority's real state is known, in _ready()
var _player_is_dead: bool = false
var _was_inside_last_tick: bool = false

var _is_open: bool = false
var _requires_reentry: bool = false # Lifecycle: "After a Cancel, stays closed until the player leaves the radius and re-enters"
var _dwell_started_at: float = -1.0 # SimClock.now snapshot; -1 = not currently dwelling

var _channel_active: bool = false
var _channel_is_sector: bool = false
var _channel_list_index: int = -1
var _channel_sector_index: int = -1
var _channel_started_at: float = 0.0

var _sector_armed: Array = [true, true, true, true, true, true, true]

var _highlighted_index: int = 0
var _committed_bearing_deg: float = NAN # unset sentinel; see _update_placement()
var _panel_size_override: Vector2 = Vector2(-1.0, -1.0) # (-1,-1) = "no override, use the built panel's own size"

# --- Built UI (code-built, matching src/ui/hud.gd's own precedent) ---------
var _panel: PanelContainer = null
var _rows: Array = []
var _row_frames: Array = []
var _row_glyphs: Array = []
var _row_headers: Array = []
var _row_texts: Array = []
## UI pass additions -- decoration only, none of them is read by a test.
var _row_carets: Array = []
var _row_price_tags: Array = []
var _row_max_badges: Array = []
## UI pass follow-up (compaction): one owned StyleBoxFlat per row, built via
## UiTheme.make_box() and mutated per refresh (pool-based corner radius,
## highlight-based border) -- DraftCardView's own established pattern
## (src/ui/draft_card_view.gd's `_style`) for exactly this reason: a
## `theme_type_variation` resolves to the Theme's ONE shared, cached
## StyleBox instance, so mutating IT per row would restyle every row (and
## every other ROW/ROW_HIGHLIGHTED-styled control project-wide) at once.
var _row_styles: Array = []
var _scrap_label: Label = null
## UI pass follow-up: the highlighted entry's effect sentence (the part of
## effect_description after its first ":"), shown once at the panel's foot
## instead of inside every row.
var _footer_label: Label = null
## UI pass: circular fill ring (DraftFillRing, another package's file --
## used only through its public `progress`/`ring_color`/`track_color`
## surface) replacing the old linear ProgressBar; see class doc,
## "Presentation simplification."
var _fill_bar: DraftFillRing = null
## UI pass: the open-animation tween, killed before a fresh one starts so a
## rapid close-then-reopen never leaves two tweens fighting over the same
## `_panel.modulate`/`scale` properties (mirrors this codebase's own
## hit-flash-tween-kill precedent, tests/unit/player_animation_test.gd).
var _open_tween: Tween = null

## CHANGE 1 (D107): the pre-open prompt ("[console_open] Tower Console" /
## greyed "nothing affordable"), a SIBLING of `_panel`, not a child of it --
## the two are mutually exclusive (`_refresh_prompt()`/`_process()`) so
## exactly one of "the purchase list" or "the prompt" is visible at once,
## never both, never neither while inside the radius and alive/unpaused.
var _prompt_panel: PanelContainer = null
var _prompt_label: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # see class doc, "never itself frozen"
	z_index = CONSOLE_Z_INDEX
	modulate.a = CONSOLE_OPACITY
	visible = false

	if _clock == null:
		_clock = SimClock
	if _pause_authority == null:
		_pause_authority = PauseAuthority
	if _event_bus == null:
		_event_bus = EventBus

	if _tower == null and tower_path != NodePath():
		_tower = get_node_or_null(tower_path) as Tower
	if _player == null and player_path != NodePath():
		_player = get_node_or_null(player_path) as Player
	if _player_weapon == null:
		if player_weapon_path != NodePath():
			_player_weapon = get_node_or_null(player_weapon_path) as AutoWeapon
		elif _player != null:
			_player_weapon = _player.get_node_or_null("AutoWeapon") as AutoWeapon
	if _upgrade_system == null and upgrade_system_path != NodePath():
		_upgrade_system = get_node_or_null(upgrade_system_path) as UpgradeSystem
	if _camera == null and camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as GameCamera
	if _interaction_radius == null and _tower != null:
		_interaction_radius = _tower.interaction_radius

	if _pause_authority != null and _pause_authority.has_signal("reasons_changed"):
		_pause_authority.reasons_changed.connect(_on_pause_reasons_changed)
		if _pause_authority.has_method("get_active_reasons"):
			_paused = not _pause_authority.get_active_reasons().is_empty()
		else:
			_paused = false
	else:
		_paused = false

	if _event_bus != null and _event_bus.has_signal("player_died"):
		_event_bus.player_died.connect(_on_player_died)

	_build_ui()


# --- Test / orchestrator seams ----------------------------------------------

func set_tower_for_test(tower: Tower) -> void:
	_tower = tower
	if _interaction_radius == null and tower != null:
		_interaction_radius = tower.interaction_radius


func set_player_for_test(player: Player) -> void:
	_player = player


func set_player_weapon_for_test(weapon: AutoWeapon) -> void:
	_player_weapon = weapon


func set_interaction_radius_for_test(radius: Object) -> void:
	_interaction_radius = radius


func set_upgrade_system_for_test(system: UpgradeSystem) -> void:
	_upgrade_system = system


func set_camera_for_test(camera: GameCamera) -> void:
	_camera = camera


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_pause_authority_for_test(pa: Node) -> void:
	_pause_authority = pa


func set_event_bus_for_test(bus: Node) -> void:
	_event_bus = bus


## Typed COMMAND, not merely a test seam -- see class doc, "Wiring seams."
## RunInventory (P2.10) is a RefCounted, not a scene node, so no NodePath can
## find it; the orchestrator calls this once with the run's live inventory.
func set_run_inventory(inventory: RunInventory) -> void:
	_run_inventory = inventory


func set_panel_size_override_for_test(size: Vector2) -> void:
	_panel_size_override = size


func force_refresh_for_test() -> void:
	_refresh_entries_ui()
	_update_placement()
	_refresh_prompt() # CHANGE 1 (D107): drives the pre-open prompt without waiting for a real _process() frame


func _now() -> float:
	return _clock.now if _clock != null else 0.0


# --- Per-tick game logic (SimLoop step 12) ----------------------------------

func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


func physics_step(_delta: float) -> void:
	if _paused:
		return
	if _tower == null or _player == null or _interaction_radius == null:
		return

	var inside: bool = _interaction_radius.is_player_inside()

	# C-AUTOFIRE: "player auto-fire disabled at ANY speed while overlapping
	# the Interaction Radius ... Tower keeps firing" -- independent of
	# whether the Console itself has opened.
	if _player_weapon != null:
		_player_weapon.set_auto_fire_suppressed(inside)

	if inside and not _was_inside_last_tick:
		_requires_reentry = false # Lifecycle: "leaves the radius and re-enters" clears the post-Cancel lock
	_was_inside_last_tick = inside

	if _player_is_dead:
		if _is_open:
			_close_console(false)
		return

	if not inside:
		if _is_open:
			_close_console(false) # Lifecycle: "Closes on leaving the radius"
		_dwell_started_at = -1.0
		return

	var speed: float = _player.velocity.length()
	var base_speed: float = _player.definition.base_speed_px_per_second if _player.definition != null else 0.0
	var slow_enough: bool = base_speed <= 0.0 or speed < base_speed * SPEED_GATE_FRACTION

	# CHANGE 1 (D107): the automatic dwell-open below is Movement-only mode's
	# OWN no-button path now, not the default control scheme's -- see class
	# doc, "CHANGE 1." Outside Movement-only mode the Console opens only
	# through request_open() (console_open: E / gamepad Y), called from
	# _unhandled_input() below.
	if not _is_open:
		if not movement_only_controls_enabled or _requires_reentry or not slow_enough or not _has_any_affordable_entry():
			_dwell_started_at = -1.0
		else:
			if _dwell_started_at < 0.0:
				_dwell_started_at = _now()
			elif _now() - _dwell_started_at >= OPEN_DWELL_SECONDS:
				_open_console()

	if _is_open:
		_process_channel(speed, base_speed)
		if movement_only_controls_enabled and not _channel_active:
			_process_sectors(slow_enough)


func _open_console() -> void:
	_is_open = true
	_dwell_started_at = -1.0
	_highlighted_index = 0
	if _event_bus != null and _event_bus.has_method("emit_console_opened"):
		_event_bus.emit_console_opened()


func _close_console(require_reentry: bool) -> void:
	_is_open = false
	_dwell_started_at = -1.0
	if require_reentry:
		_requires_reentry = true
	_reset_channel_state() # any in-progress channel is abandoned, uncharged
	if _event_bus != null and _event_bus.has_method("emit_console_closed"):
		_event_bus.emit_console_closed()


# --- Pause / death reactions (Console never WRITES pause state; it only
# reacts to it -- see class doc, point 2) ------------------------------------

func _on_pause_reasons_changed(reasons: Array) -> void:
	var has_draft: bool = false
	for r in reasons:
		if r == PauseAuthority.REASON_DRAFT:
			has_draft = true
			break
	_paused = not reasons.is_empty()
	if has_draft and _is_open:
		_close_console(false) # Lifecycle: "closes ... when a Level-Up Draft opens" -- no re-entry lock, unlike Cancel


func _on_player_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_player_is_dead = true
	_close_console(false)


# --- Input (discrete actions only; movement always drives the player
# independently -- docs/19 > Input Map: "the left stick always moves the
# player") -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _paused or _player_is_dead:
		return
	# CHANGE 1 (D107): while closed, the ONLY action this file handles is
	# console_open -- every other branch below assumes _is_open already.
	if not _is_open:
		if event.is_action_pressed(&"console_open"):
			if request_open():
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"console_cancel"):
		request_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"confirm"):
		start_channel_for_highlighted()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"console_cycle_next"):
		cycle(1)
		return
	if event.is_action_pressed(&"console_cycle_prev"):
		cycle(-1)
		return
	for i in range(SELECT_ACTIONS.size()):
		if event.is_action_pressed(SELECT_ACTIONS[i]):
			select_and_start_channel(i)
			return


## Typed command (console_open: E / gamepad Y button index 3, docs/19 >
## Input Map). CHANGE 1 (D107, author decision 2026-09-23): replaces the
## old automatic 0.3 s dwell-open for the DEFAULT control scheme -- opens
## the Console immediately, at any speed (no speed gate at all), and
## ignores `_requires_reentry` entirely (per the new Lifecycle rule:
## pressing console_open after a Cancel reopens the Console with no need to
## leave the radius). Still requires: not paused, the player alive, not
## already open, inside the Interaction Radius, and >= 1 affordable entry
## (C-REPAIR's own "does not count toward opening the Console" rule still
## applies -- an unaffordable Console does not open just because a button
## was pressed). Works under Movement-only mode too, unconditionally -- see
## class doc, "CHANGE 1."
func request_open() -> bool:
	if _paused or _player_is_dead or _is_open:
		return false
	if _tower == null or _player == null or _interaction_radius == null:
		return false
	if not _interaction_radius.is_player_inside():
		return false
	if not _has_any_affordable_entry():
		return false
	_open_console()
	return true


## Typed command (Cancel: Q / B-Circle, docs/19 > Input Map).
func request_cancel() -> void:
	if not _is_open:
		return
	_close_console(true) # Lifecycle: "After a Cancel, stays closed until the player leaves the radius and re-enters"


func cycle(step_dir: int) -> void:
	if not _is_open:
		return
	var count: int = _catalogue_entries_for_list().size()
	if count <= 0:
		return
	_highlighted_index = wrapi(_highlighted_index + step_dir, 0, count)


## Number-key style: "highlight an entry and start its purchase channel
## directly" (docs/19 > Tower Console UI > Input).
func select_and_start_channel(index_in_list: int) -> bool:
	_highlighted_index = index_in_list
	return _start_channel(index_in_list)


func start_channel_for_highlighted() -> bool:
	return _start_channel(_highlighted_index)


func _start_channel(index_in_list: int) -> bool:
	if not _is_open or _channel_active:
		return false
	var entries: Array = _catalogue_entries_for_list()
	if index_in_list < 0 or index_in_list >= entries.size():
		return false
	var entry: Dictionary = entries[index_in_list]
	if not bool(entry.get("affordable", false)):
		return false
	_channel_active = true
	_channel_is_sector = false
	_channel_list_index = index_in_list
	_channel_started_at = _now()
	return true


func _process_channel(speed: float, base_speed: float) -> void:
	if not _channel_active:
		return
	if base_speed > 0.0 and speed > base_speed * SPEED_GATE_FRACTION:
		_reset_channel_state() # "moving faster than 10% of base speed before it completes cancels it without charge"
		return
	var duration: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	if _now() - _channel_started_at >= duration:
		_complete_channel()


func _complete_channel() -> void:
	if _channel_is_sector:
		var idx: int = _channel_sector_index
		var ctx: Dictionary = _sector_context(idx)
		if bool(ctx.get("affordable", false)):
			_apply_purchase(ctx)
		if idx >= 0 and idx < _sector_armed.size():
			_sector_armed[idx] = false # "a sector only re-arms after the player moves ... or leaves it"
	else:
		var entries: Array = _catalogue_entries_for_list()
		if _channel_list_index >= 0 and _channel_list_index < entries.size():
			var entry: Dictionary = entries[_channel_list_index]
			if bool(entry.get("affordable", false)):
				_apply_purchase(entry)
	_reset_channel_state()


func _reset_channel_state() -> void:
	_channel_active = false
	_channel_is_sector = false
	_channel_list_index = -1
	_channel_sector_index = -1
	_channel_started_at = 0.0


func _apply_purchase(ctx: Dictionary) -> void:
	var kind: String = String(ctx.get("kind", ""))
	var cost: int = int(ctx.get("cost", 0))
	var channel_seconds: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	if kind == "repair":
		var heal: float = float(ctx.get("heal", 0.0))
		if heal <= 0.0 or _tower == null or _tower.death_state == null:
			return
		# See class doc, "Cross-task seams": no TowerHealth.repair() command
		# exists; mirrors TowerHealth's own configure() writing this same
		# field directly.
		_tower.death_state.current_hp = minf(_tower.death_state.max_hp, _tower.death_state.current_hp + heal)
		_charge_scrap(cost)
		_emit_console_purchase("repair", channel_seconds, cost)
	elif kind == "upgrade" or kind == "fallback":
		var id: String = String(ctx.get("id", ""))
		if _upgrade_system != null and _upgrade_system.apply_rank(id):
			_charge_scrap(cost) # charged only once apply_rank() actually succeeded -- never before, never twice
			_emit_console_purchase(id, channel_seconds, cost)


## Integration task (C-TELEMETRY). Called only from the two branches above,
## only once `_charge_scrap()` has actually run for that purchase.
func _emit_console_purchase(entry_id: String, channel_seconds: float, cost: int) -> void:
	if _event_bus != null and _event_bus.has_method("emit_console_purchase"):
		_event_bus.emit_console_purchase(entry_id, channel_seconds, cost)


func _charge_scrap(cost: int) -> void:
	if _run_inventory == null or cost <= 0:
		return
	_run_inventory.scrap_current = maxi(0, _run_inventory.scrap_current - cost)


# --- Movement-only sectors (C-SECTORS) --------------------------------------

func _process_sectors(slow_enough: bool) -> void:
	var current: int = _current_sector_index()
	for i in range(SECTOR_COUNT):
		if i != current or not slow_enough:
			_sector_armed[i] = true # re-arms once the player moves fast or is not in that sector
	if current < 0 or not slow_enough or not bool(_sector_armed[current]):
		return
	var ctx: Dictionary = _sector_context(current)
	if not bool(ctx.get("affordable", false)):
		return
	_channel_active = true
	_channel_is_sector = true
	_channel_sector_index = current
	_channel_started_at = _now()


func _current_sector_index() -> int:
	if _tower == null or _player == null:
		return -1
	var bearing: float = _bearing_deg_from_north(_player.global_position - _tower.global_position)
	return clampi(int(floor(bearing / SECTOR_WIDTH_DEG)), 0, SECTOR_COUNT - 1)


func _sector_context(i: int) -> Dictionary:
	if i == 0:
		return _compute_repair()
	var pool: int = ContractEnums.PoolOwnership.Player if i <= 3 else ContractEnums.PoolOwnership.Tower
	if _upgrade_system != null and _upgrade_system.is_pool_exhausted(pool):
		var fc: UpgradeDefinition = _upgrade_system.get_fallback_card(pool)
		if fc != null:
			return _entry_for_upgrade(fc.unique_id)
	if i < 0 or i >= SECTOR_IDS.size():
		return {"kind": "none", "affordable": false}
	return _entry_for_upgrade(SECTOR_IDS[i])


func is_sector_armed_for_test(i: int) -> bool:
	return bool(_sector_armed[i]) if i >= 0 and i < _sector_armed.size() else false


func get_current_sector_index_for_test() -> int:
	return _current_sector_index()


# --- Catalogue / entries -----------------------------------------------------

func _compute_repair() -> Dictionary:
	var base: Dictionary = {
		"kind": "repair", "id": "repair", "name": "Repair",
		"pool": ContractEnums.PoolOwnership.Tower, "is_max": false,
		"heal": 0.0, "cost": 0, "affordable": false,
	}
	if _tower == null or _tower.health == null or _tower.definition == null or _tower.definition.repair_price == null:
		return base
	var rp: RepairPrice = _tower.definition.repair_price
	if rp.scrap_cost <= 0:
		return base
	var per_scrap_health: float = float(rp.health_restored) / float(rp.scrap_cost)
	var max_health: float = _tower.health.max_health
	var current_health: float = _tower.health.get_current_health()
	var missing: float = max_health - current_health
	var missing_even: float = floor(missing / 2.0) * 2.0 # "rounded down to an even number"
	var scrap_held: int = _run_inventory.scrap_current if _run_inventory != null else 0
	var max_afford_heal: float = float(scrap_held) * per_scrap_health
	var heal: float = minf(REPAIR_MAX_HEAL, minf(missing_even, max_afford_heal))
	var cost: int = int(round(heal / per_scrap_health)) if heal > 0.0 else 0
	var affordable: bool = missing >= 2.0 and scrap_held >= 1 and heal > 0.0 # C-REPAIR
	base["heal"] = heal
	base["cost"] = cost
	base["affordable"] = affordable
	return base


func _entry_for_upgrade(id: String) -> Dictionary:
	var unknown: Dictionary = {"kind": "upgrade", "id": id, "name": id, "pool": ContractEnums.PoolOwnership.Player, "is_max": false, "cost": -1, "affordable": false, "rank": 0, "max_rank": 3, "has_max_rank": true}
	if _upgrade_system == null:
		return unknown
	var def: UpgradeDefinition = _upgrade_system.get_definition(id)
	if def == null:
		# UpgradeSystem.get_console_cost() push_error()s on an unknown id
		# (by design, for a real gameplay caller); never call it for one --
		# an id absent from a deliberately-restricted test pool (or a
		# not-yet-authored id) must not spam the engine error channel every
		# tick this file's own dwell/afford checks run.
		return unknown
	var maxed: bool = _upgrade_system.is_maxed(id)
	var cost: int = _upgrade_system.get_console_cost(id)
	var scrap: int = _run_inventory.scrap_current if _run_inventory != null else 0
	var affordable: bool = (not maxed) and cost >= 0 and scrap >= cost
	return {
		"kind": "fallback" if (def != null and not def.has_max_rank) else "upgrade",
		"id": id,
		"name": (def.effect_description if def != null else id),
		"pool": (def.pool_ownership if def != null else ContractEnums.PoolOwnership.Player),
		"is_max": maxed,
		"cost": cost,
		"affordable": affordable,
		"rank": _upgrade_system.get_current_rank(id),
		"max_rank": (def.max_rank if def != null else 0),
		"has_max_rank": (def.has_max_rank if def != null else true),
	}


## The Tab/wheel/D-pad/number-key CATALOGUE: the fixed 7 (Repair + six
## upgrades) always present, PLUS a fallback entry APPENDED once its pool is
## exhausted (docs/19 > Tower Console UI > Contents: fallback cards "appear
## here" -- an addition, never a replacement of the six real entries, which
## keep showing "MAX" individually. Distinct from _sector_context(), where a
## maxed POOL repurposes its three fixed sector slots instead -- see class
## doc's sibling note and the evidence report, "Interpretations.")
func _catalogue_entries_for_list() -> Array:
	var out: Array = []
	out.append(_compute_repair())
	for id in PLAYER_IDS:
		out.append(_entry_for_upgrade(id))
	for id in TOWER_IDS:
		out.append(_entry_for_upgrade(id))
	if _upgrade_system != null:
		if _upgrade_system.is_pool_exhausted(ContractEnums.PoolOwnership.Player):
			var fc: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Player)
			if fc != null:
				out.append(_entry_for_upgrade(fc.unique_id))
		if _upgrade_system.is_pool_exhausted(ContractEnums.PoolOwnership.Tower):
			var fc2: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Tower)
			if fc2 != null:
				out.append(_entry_for_upgrade(fc2.unique_id))
	return out


func _has_any_affordable_entry() -> bool:
	for e in _catalogue_entries_for_list():
		if bool(e.get("affordable", false)):
			return true
	return false


# --- Public queries ----------------------------------------------------------

func is_open() -> bool:
	return _is_open


func get_paused_for_test() -> bool:
	return _paused


func get_requires_reentry_for_test() -> bool:
	return _requires_reentry


func is_channel_active() -> bool:
	return _channel_active


func get_channel_progress_for_test() -> float:
	if not _channel_active:
		return 0.0
	var duration: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	return clampf((_now() - _channel_started_at) / duration, 0.0, 1.0)


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func set_highlighted_index_for_test(i: int) -> void:
	_highlighted_index = i


func get_catalogue_size_for_test() -> int:
	return _catalogue_entries_for_list().size()


func get_entry_for_test(i: int) -> Dictionary:
	var entries: Array = _catalogue_entries_for_list()
	return entries[i] if i >= 0 and i < entries.size() else {}


func get_placement_position_for_test() -> Vector2:
	return global_position


func get_committed_bearing_for_test() -> float:
	return _committed_bearing_deg


func get_scrap_current_for_test() -> int:
	return _run_inventory.scrap_current if _run_inventory != null else -1


func get_entry_label_for_test(i: int) -> Label:
	return _row_texts[i] if i >= 0 and i < _row_texts.size() else null


## UI pass round 2 (UR-03): new test seam, same shape as get_entry_label_for_test() above -- no existing test read the old Glyph Label, so nothing else changes shape.
func get_entry_glyph_for_test(i: int) -> UiShapeGlyph:
	return _row_glyphs[i] if i >= 0 and i < _row_glyphs.size() else null


## UI pass round 2 (UR-05): new test seam for the price/MAX floor regression.
func get_entry_price_tag_for_test(i: int) -> RichTextLabel:
	return _row_price_tags[i] if i >= 0 and i < _row_price_tags.size() else null


## UI pass round 2 (UR-05): new test seam for the price/MAX floor regression.
func get_entry_max_badge_label_for_test(i: int) -> Label:
	if i < 0 or i >= _row_max_badges.size():
		return null
	var badge: PanelContainer = _row_max_badges[i]
	return badge.get_node("MaxBadgeLabel") as Label


func get_panel_control_for_test() -> Control:
	return _panel


## UI pass follow-up (compaction): the highlighted entry's effect-sentence
## footer -- new this follow-up, so no existing test reads it; added for
## this package's own regression coverage.
func get_footer_label_for_test() -> Label:
	return _footer_label


# --- Placement (docs/19 > Tower Console UI > "Placement") -------------------

## CHANGE 1 (D107): this Console-level Node2D is now visible whenever
## unpaused, REGARDLESS of `_is_open` -- the pre-open prompt (`_prompt_panel`)
## must be able to render while the purchase list (`_panel`) is closed. The
## two are mutually exclusive siblings, each toggled independently below;
## Console's OWN visibility only ever needs to hide EVERYTHING at once,
## which is exactly the pause case (task brief, item 6: "hides itself
## IMMEDIATELY, no animation" -- this branch never touches a tween).
func _process(_delta: float) -> void:
	if _paused:
		visible = false
		return
	visible = true
	_update_placement()
	var was_open: bool = _panel.visible # read BEFORE mutating, so this frame's own open transition is detected correctly
	_panel.visible = _is_open
	if _is_open:
		if not was_open:
			_play_open_animation()
		_refresh_entries_ui()
	_refresh_prompt()


## Cosmetic open-only fade+scale (task brief, item 6: "If you cannot
## guarantee that for close, animate open only" -- the close path above
## sets `visible = false` synchronously and never creates a tween, so this
## is the one animated transition). Targets `_panel`'s own `modulate.a` /
## `scale`, never this node's (Console.modulate.a is CONSOLE_OPACITY, read
## by nothing here but resting exactly where the class doc says it must;
## Console.scale is the per-frame camera view-scale compensation
## _update_placement() sets right after this returns -- animating it here
## would fight that assignment and corrupt the 24 px on-screen text floor).
func _play_open_animation() -> void:
	if _panel == null or not is_inside_tree():
		return
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill() # a rapid close-then-reopen must not stack two tweens on the same properties
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * OPEN_ANIM_START_SCALE
	_open_tween = create_tween() # bare create_tween() on this node, never get_tree().create_tween()
	_open_tween.set_parallel(true)
	_open_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # godot-prompter:tween-animation's own "most common combo" for a natural-feeling UI transition
	_open_tween.tween_property(_panel, "modulate:a", 1.0, UiPalette.MOTION_BASE)
	_open_tween.tween_property(_panel, "scale", Vector2.ONE, UiPalette.MOTION_BASE)


func _update_placement() -> void:
	if _tower == null or _player == null:
		return
	var tower_pos: Vector2 = _tower.global_position
	var player_pos: Vector2 = _player.global_position
	var raw_bearing: float = _bearing_deg_from_north(player_pos - tower_pos)
	if is_nan(_committed_bearing_deg):
		_committed_bearing_deg = raw_bearing
	else:
		var diff: float = _angle_diff_deg(raw_bearing, _committed_bearing_deg)
		if absf(diff) > PLACEMENT_FLIP_THRESHOLD_DEG:
			_committed_bearing_deg = raw_bearing

	var opposite_deg: float = fposmod(_committed_bearing_deg + 180.0, 360.0)
	var dir: Vector2 = _direction_from_bearing(opposite_deg)
	var half_extent: Vector2 = _panel_half_extent()
	var denom: float = maxf(absf(dir.x) / maxf(0.0001, half_extent.x), absf(dir.y) / maxf(0.0001, half_extent.y))
	var edge_offset: float = 1.0 / maxf(0.0001, denom)
	global_position = tower_pos + dir * (PLACEMENT_DISTANCE_PX + edge_offset)

	var view_scale: float = _camera.get_view_scale() if _camera != null else 1.0
	scale = Vector2.ONE * view_scale


func _panel_half_extent() -> Vector2:
	if _panel_size_override != Vector2(-1.0, -1.0):
		return _panel_size_override / 2.0
	if _panel == null:
		return Vector2(100.0, 60.0)
	var sz: Vector2 = _panel.get_combined_minimum_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2(100.0, 60.0)
	_panel.size = sz
	_panel.position = -sz / 2.0
	_panel.pivot_offset = sz / 2.0 # UI pass: centres the open-animation's scale-in, cosmetic only
	return sz / 2.0


static func _bearing_deg_from_north(v: Vector2) -> float:
	if v.length_squared() < 0.0001:
		return 0.0
	return fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)


static func _direction_from_bearing(deg: float) -> Vector2:
	var rad: float = deg_to_rad(deg)
	return Vector2(sin(rad), -cos(rad))


static func _angle_diff_deg(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


# --- Presentation (docs/19 > UI Layout & Dynamic Container Rules: "Tower
# Console entry rows" are named explicitly as a container that must use
# Label/RichTextLabel with autowrap_mode = AUTOWRAP_WORD_SMART and
# size_flags_horizontal = SIZE_EXPAND_FILL) ----------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered() # UI pass round 2 (UR-08): explicit at this surface's own build entry point, not only as a side effect of UiTheme.get_theme() below
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.theme = UiTheme.get_theme() # applied ONCE, at the root Control (ui_theme.gd's own contract) -- every descendant inherits it
	# UI pass follow-up (compaction): an OWNED StyleBoxFlat, not
	# `theme_type_variation = UiTheme.PANEL` (which would still work, but
	# resolves to the Theme's ONE shared, cached PANEL StyleBox -- every
	# other UiTheme.PANEL surface, e.g. the pause/settings menus, uses the
	# SAME instance; tightening ITS padding for this one compact panel
	# would tighten theirs too). Same reasoning, same fix shape, as
	# `_row_styles` above and src/ui/draft_card_view.gd's own `_style`.
	# Padding SPACE_L -> SPACE_S: "tighten the row chrome ... tighter
	# padding, UiPalette.SPACE_XS/SPACE_S" (follow-up item 4).
	_panel.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.with_alpha(UiPalette.INK, UiPalette.PANEL_ALPHA), UiPalette.LINE, UiPalette.RADIUS_PANEL, UiPalette.BORDER_THIN, UiPalette.SPACE_S))
	# Layout-collapse fix floor (class doc, "UI pass restyle"): a
	# custom_minimum_size, never a fixed size -- the panel still grows past
	# this under pseudo-localization exactly as before.
	_panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH_PX, 0)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.theme_type_variation = UiTheme.vbox("XS") # UI pass round 2 (UR-06): was a bare "separation" override
	_panel.add_child(vbox)

	_build_header(vbox)

	for i in range(MAX_LIST_ENTRIES):
		_build_row(vbox, i)

	_fill_bar = DraftFillRing.new() # UI pass: real ring, replacing the old linear ProgressBar (class doc, "Presentation simplification")
	_fill_bar.name = "ChannelFill"
	_fill_bar.custom_minimum_size = Vector2(UiPalette.SPACE_XXL * 1.5, UiPalette.SPACE_XXL * 1.5)
	_fill_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_bar.ring_color = UiPalette.ACCENT
	_fill_bar.track_color = UiPalette.with_alpha(UiPalette.LINE, 0.6) # "a dim track" (task brief, item 5)
	_fill_bar.visible = false
	vbox.add_child(_fill_bar)

	_build_footer(vbox)

	_build_prompt() # CHANGE 1 (D107): a SIBLING of _panel, not inside it -- see class doc, "CHANGE 1," and the `_prompt_panel` field comment


## CHANGE 1 (D107): the pre-open prompt shown while inside the Interaction
## Radius with the Console closed. A separate small chip, not a row inside
## `_panel` (which stays hidden the whole time this is visible) -- built the
## same way `_build_row()`'s own chips are (PanelContainer + UiTheme.make_box
## + a themed Label), reusing `_make_label()` so it gets the same
## autowrap/overrun-safety this file already requires of every text
## container (docs/19 > "UI Layout & Dynamic Container Rules").
func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "Prompt"
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.theme = UiTheme.get_theme()
	_prompt_panel.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.with_alpha(UiPalette.INK, UiPalette.PANEL_ALPHA), UiPalette.LINE, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_S))
	_prompt_panel.visible = false
	add_child(_prompt_panel)

	_prompt_label = _make_label("", UiPalette.FONT_SIZE_SMALL)
	_prompt_label.name = "PromptLabel"
	_prompt_label.theme_type_variation = UiTheme.SMALL
	# Same zero-minimum-width risk _build_row()'s own Text label has (any
	# autowrap + SIZE_EXPAND_FILL Label), at a much smaller scale (one short
	# phrase, not a data-sourced sentence) -- a modest defensive floor, not a
	# Register number.
	_prompt_label.custom_minimum_size = Vector2(UiPalette.SPACE_XXL * 3.0, 0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)


## Mutually exclusive with `_panel` (see `_prompt_panel`'s own field
## comment): visible only while inside the Interaction Radius, the Console
## is closed, the player is alive, and the Console is not paused/hidden
## (the `_paused` case is handled by `_process()`'s own early return before
## this is ever called). Text and colour follow C-REPAIR's own "greyed,
## never hidden" precedent -- shown greyed with CONSOLE_PROMPT_UNAVAILABLE
## when nothing is affordable, never simply absent, so the player always
## knows the Console exists here even when there is nothing to buy yet.
func _refresh_prompt() -> void:
	if _prompt_panel == null:
		return
	if _is_open or _player_is_dead or _tower == null or _player == null or _interaction_radius == null:
		_prompt_panel.visible = false
		return
	if not _interaction_radius.is_player_inside():
		_prompt_panel.visible = false
		return
	_prompt_panel.visible = true
	var affordable: bool = _has_any_affordable_entry()
	_prompt_label.text = tr("CONSOLE_PROMPT") if affordable else tr("CONSOLE_PROMPT_UNAVAILABLE")
	_prompt_label.add_theme_color_override("font_color", UiPalette.TEXT if affordable else UiPalette.TEXT_DISABLED)
	# Presentation simplification, named rather than silently done: the
	# prompt is centred on the SAME anchor point _update_placement() already
	# computes for the purchase-list panel (Console's own global_position),
	# rather than a second, independently-specified geometry rule -- docs/19
	# states the 200 px/30 degree placement rule for the purchase-list panel
	# only, never for this prompt, so no Register citation is owed here.
	var sz: Vector2 = _prompt_panel.get_combined_minimum_size()
	_prompt_panel.size = sz
	_prompt_panel.position = -sz / 2.0


func get_prompt_visible_for_test() -> bool:
	return _prompt_panel != null and _prompt_panel.visible


func get_prompt_text_for_test() -> String:
	return _prompt_label.text if _prompt_label != null else ""


## UI pass follow-up (compaction, item 2): the effect sentence of the
## HIGHLIGHTED entry only, shown once at the panel's foot instead of inside
## every row -- this is what let the row label shrink to "<name> Rank n of
## 3" in the first place. `custom_minimum_size.y` reserves FOOTER_MIN_LINES
## worth of height so the panel does not resize/jump as the highlight moves
## between a short and a long effect_description.
func _build_footer(vbox: VBoxContainer) -> void:
	# UiTheme.SMALL, not UiTheme.DIM -- item 2's own wording ("dim,
	# UiTheme.DIM/SMALL"), and ui_theme.gd's SMALL variation IS a dim
	# colour (UiPalette.TEXT_DIM) at the smaller FONT_SIZE_SMALL, so one
	# variation satisfies both "dim" and "small" instead of stacking two.
	_footer_label = _make_label("", UiPalette.FONT_SIZE_SMALL)
	_footer_label.name = "Footer"
	_footer_label.theme_type_variation = UiTheme.SMALL
	var line_height: float = float(UiPalette.FONT_SIZE_SMALL) * 1.2 + 2.0 # small font size * a typical leading factor + the theme's own Label line_spacing (ui_theme.gd: 2)
	_footer_label.custom_minimum_size = Vector2(ROW_TEXT_MIN_WIDTH_PX, line_height * float(FOOTER_MIN_LINES))
	vbox.add_child(_footer_label)


## Compact header: title + the player's current Scrap (task brief, item 2)
## -- both already read elsewhere in this file (tr("CONSOLE_TITLE") below;
## _run_inventory.scrap_current, e.g. get_scrap_current_for_test()), so
## nothing here is new data.
func _build_header(vbox: VBoxContainer) -> void:
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.theme_type_variation = UiTheme.hbox("M") # UI pass round 2 (UR-06): was a bare "separation" override
	vbox.add_child(header_row)

	# UI pass follow-up (compaction): FONT_SIZE_BODY -> FONT_SIZE_SMALL, one
	# more contributor to the panel height target (follow-up item 4) --
	# still comfortably above the 24 px floor, which only ever governs
	# `ENTRY_FONT_SIZE_PX` (the entry rows' own Text label), never the
	# header.
	var title := _make_label(tr("CONSOLE_TITLE"), UiPalette.FONT_SIZE_SMALL)
	title.name = "Title"
	# Same zero-minimum risk as ROW_TEXT_MIN_WIDTH_PX below (any autowrap +
	# SIZE_EXPAND_FILL Label has it) -- a small defensive floor, well short
	# of ROW_TEXT_MIN_WIDTH_PX since the title is one short phrase, not a
	# data-sourced sentence.
	title.custom_minimum_size = Vector2(UiPalette.SPACE_XXL * 4.0, 0)
	header_row.add_child(title)

	_scrap_label = _make_label("", UiPalette.FONT_SIZE_SMALL)
	_scrap_label.name = "ScrapValue"
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrap_label.custom_minimum_size = Vector2(UiPalette.SPACE_XXL * 3.0, 0)
	_scrap_label.add_theme_color_override("font_color", UiPalette.SCRAP)
	header_row.add_child(_scrap_label)


func _build_row(vbox: VBoxContainer, i: int) -> void:
	var row := PanelContainer.new() # UI pass: was HBoxContainer, then a UiTheme.ROW/ROW_HIGHLIGHTED PanelContainer; see class doc, "UI pass follow-up" for why it now owns a per-instance StyleBoxFlat instead
	row.name = "Row%d" % i
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Owned per-row box (see `_row_styles`'s own doc comment): base values
	# match what UiTheme.ROW used to supply; _refresh_one_row() mutates
	# corner radius (pool shape) and border (highlight) on THIS instance.
	var row_style := UiTheme.make_box(UiPalette.with_alpha(UiPalette.SURFACE, 0.55), UiPalette.LINE, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_XS)
	row.add_theme_stylebox_override("panel", row_style)
	_row_styles.append(row_style)

	var content := HBoxContainer.new()
	content.name = "RowContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# UI pass follow-up (compaction): SPACE_S -> SPACE_XS between the extra
	# decoration columns a one-line row has no room to spare on.
	# UI pass round 2 (UR-06): was a bare "separation" override.
	content.theme_type_variation = UiTheme.hbox("XS")
	row.add_child(content)

	# Highlight marker (item 4: "a leading caret glyph"). Always present
	# (text toggles "" / CARET_GLYPH) so the row's own width never jitters
	# when the highlight moves.
	var caret := Label.new()
	caret.name = "Caret"
	caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caret.custom_minimum_size = Vector2(UiPalette.SPACE_M, 0)
	caret.add_theme_color_override("font_color", UiPalette.ACCENT)
	content.add_child(caret)

	# Number-key hint chip (item 3: "1-7 in a small dim chip"; follow-up
	# item 3: "a small rounded square with the digit centred"). Static once
	# built -- SELECT_ACTIONS never changes at runtime -- so no per-frame
	# refresh or stored reference is needed beyond building it here. A
	# RADIUS_SMALL box (not UiTheme.PILL's own RADIUS_PILL), and
	# SIZE_SHRINK_CENTER on both axes, so it reads as a compact square chip
	# rather than stretching to the row's own (now much shorter) height.
	var number_hint := PanelContainer.new()
	number_hint.name = "NumberHint"
	number_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_hint.custom_minimum_size = Vector2(NUMBER_CHIP_SIZE_PX, NUMBER_CHIP_SIZE_PX)
	number_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number_hint.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.INK, UiPalette.LINE, UiPalette.RADIUS_SMALL, UiPalette.BORDER_THIN, UiPalette.SPACE_XS))
	var number_label := _make_pill_label(str(i + 1) if i < SELECT_ACTIONS.size() else "")
	number_label.name = "NumberHintLabel"
	number_hint.add_child(number_label)
	content.add_child(number_hint)

	# Pool-colour strip (follow-up item 3: "the strip a thin 4 px bar at the
	# row's left edge") -- a REDUNDANT colour cue now, same role as
	# DraftCardView's own `_accent_strip` (that file's header: "a redundant
	# colour cue, never the only one"): the PRIMARY shape signal moved to
	# the row's own corner radius (_row_styles[i], mutated in
	# _refresh_one_row()) so it stays visible even at a 4 px strip width,
	# where a corner radius would barely read. Colour set per-refresh.
	var frame := Panel.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(UiPalette.SPACE_XS, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(frame)

	# UI pass round 2 (UR-03): a vector shape, not a font character. The
	# shipped font contains neither the old text glyphs ("CONSOLE_GLYPH_
	# PLAYER"/"CONSOLE_GLYPH_TOWER", U+25CF/U+25A0) nor any other geometric
	# shape codepoint (tests/unit/ui_console_layout_test.gd checks
	# Font.has_char() directly and quotes the result). docs/19 > Tower
	# Console UI > "Differentiation": "The same frame-shape and glyph rules
	# as the Draft apply to its entries" -- the Draft's own player glyph
	# (draft_card_view.gd's GLYPH_PLAYER) is a triangle, not a circle, so
	# Shape.TRIANGLE/Shape.SQUARE below match it exactly, set per-refresh
	# from each entry's pool. `text` stays empty (UiShapeGlyph's own
	# contract, shape_glyph.gd's header); mouse_filter is already
	# MOUSE_FILTER_IGNORE from UiShapeGlyph._init(), not re-set here.
	var glyph := UiShapeGlyph.new()
	glyph.name = "Glyph"
	# Sized to the number chip beside it, not to a font-size token: the row's
	# height is what the 35% panel allowance is spent on, and a token tuned
	# for another font's metrics once made every row 6 px taller (UR-25).
	glyph.set_side(int(NUMBER_CHIP_SIZE_PX))
	content.add_child(glyph)

	var header := Label.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(UiPalette.SPACE_XXL + UiPalette.SPACE_S, 0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.theme_type_variation = UiTheme.DIM
	content.add_child(header)

	var text := _make_label("", ENTRY_FONT_SIZE_PX)
	text.name = "Text"
	# Layout-collapse fix floor (class doc, "UI pass restyle") -- the exact
	# defect the coordinator's evidence caught: without this, this Label's
	# own natural minimum width collapses toward zero and every entry wraps
	# one character per line. custom_minimum_size, not size: still expands
	# under pseudo-localization.
	text.custom_minimum_size = Vector2(ROW_TEXT_MIN_WIDTH_PX, 0)
	content.add_child(text)

	# Price (item 3: "price right-aligned in UiPalette.SCRAP") and the MAX
	# badge (item 4: "MAX = a distinct badge") are mutually exclusive per
	# row (_refresh_price_and_badge() toggles `.visible`) and are NEW
	# sibling nodes -- Text above keeps its own full "name -- suffix"
	# content unchanged, per the task brief's "add new decoration as
	# sibling nodes rather than changing what that label contains."
	var price_tag := RichTextLabel.new()
	price_tag.name = "PriceTag"
	price_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_tag.bbcode_enabled = true
	price_tag.fit_content = true
	price_tag.scroll_active = false
	price_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	price_tag.custom_minimum_size = Vector2(PRICE_TAG_MIN_WIDTH_PX, 0)
	# Every Control auto-translates its text by default, and pseudo-
	# localization runs on top of THAT -- for a Label that is exactly what
	# docs/19's pseudo-localization testing wants (Text/Title/etc. all
	# benefit from it). PriceTag's `bbcode_text` is generated MARKUP
	# ([right][color=#...][s]...[/s][/color][/right]), never a translatable
	# message; pseudo-localized markup mangles the tag names themselves, so
	# RichTextLabel stops recognising them as tags and renders the whole
	# garbled tag soup as one unbreakable literal line -- reproduced while
	# building this fix (a 64 px floor ballooning to ~590 px per row with
	# pseudo-localization on, nothing else in the row changed). Disabling
	# auto-translate on this one node is the documented way to opt
	# programmatic markup out of the translation/pseudo-localization
	# pipeline without touching TranslationServer or any other label.
	price_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# UI pass round 2 (UR-05). Author decision 2026-09-20 (UI pass LEDGER
	# UR-25) confirms the Register's "text stays >= 24 px tall on screen"
	# covers the price, not just the row label -- the conservative reading
	# this was built with is now the settled answer, not a placeholder.
	# Raised from the theme's default 20 px (FONT_SIZE_BODY, RichTextLabel's
	# own fallback with no "normal_font_size" override) to
	# ENTRY_FONT_SIZE_PX -- the SAME constant `Text` uses -- so PriceTag
	# sits under the identical 24 px floor and the identical per-frame
	# Node2D `scale` compensation (_update_placement()) that keeps `Text`
	# >= 24 px tall; "normal_font_size" is the correct RichTextLabel theme
	# property (RichTextLabel has no single "font_size" property the way
	# Label does).
	price_tag.add_theme_font_size_override("normal_font_size", ENTRY_FONT_SIZE_PX)
	content.add_child(price_tag)

	var max_badge := PanelContainer.new()
	max_badge.name = "MaxBadge"
	max_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	max_badge.theme_type_variation = UiTheme.PILL
	max_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER # compaction follow-up: a badge, not a full-row-height pill
	max_badge.visible = false
	var max_label := _make_pill_label(tr("CONSOLE_MAX"))
	max_label.name = "MaxBadgeLabel"
	max_label.add_theme_color_override("font_color", UiPalette.ACCENT)
	# UI pass round 2 (UR-05): same author-confirmed floor as PriceTag
	# above (Author decision 2026-09-20, UR-25) -- raised from
	# UiTheme.SMALL's 16 px to ENTRY_FONT_SIZE_PX, overriding the
	# variation's own font size on this one label.
	max_label.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE_PX)
	max_badge.add_child(max_label)
	content.add_child(max_badge)

	vbox.add_child(row)
	_rows.append(row)
	_row_frames.append(frame)
	_row_glyphs.append(glyph)
	_row_headers.append(header)
	_row_texts.append(text)
	_row_carets.append(caret)
	_row_price_tags.append(price_tag)
	_row_max_badges.append(max_badge)


## Small dim label for a chip's interior (number-key hint / MAX badge).
## Deliberately NOT autowrapping -- both callers pass a single short token
## ("1".."7" or the MAX word), never free-form/pseudo-localized prose, so
## the truncation-ban this file's docs/19 citation targets does not apply.
func _make_pill_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.theme_type_variation = UiTheme.SMALL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## docs/19 > UI Layout & Dynamic Container Rules: "must use Label or
## RichTextLabel with autowrap_mode = TextServer.AUTOWRAP_WORD_SMART and
## size_flags_horizontal = Control.SIZE_EXPAND_FILL" -- applied here so
## pseudo-localization's 30% expansion wraps and grows instead of silently
## truncating (the UI scaling test's own falsification target).
func _make_label(txt: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size) # the Register's 24 px floor stays a per-node override the theme never touches (ENTRY_FONT_SIZE_PX callers) -- also reused for the header title at UiPalette.FONT_SIZE_BODY
	return l


func _refresh_entries_ui() -> void:
	var entries: Array = _catalogue_entries_for_list()
	for i in range(MAX_LIST_ENTRIES):
		var row_visible: bool = i < entries.size()
		_rows[i].visible = row_visible
		if not row_visible:
			continue
		var e: Dictionary = entries[i]
		_refresh_one_row(i, e)

	_refresh_header()
	_refresh_footer(entries)

	if _channel_active:
		_fill_bar.visible = true
		_fill_bar.progress = get_channel_progress_for_test()
	else:
		_fill_bar.visible = false


func _refresh_header() -> void:
	if _scrap_label == null:
		return
	var scrap: int = _run_inventory.scrap_current if _run_inventory != null else 0
	_scrap_label.text = "%d %s" % [scrap, tr("CONSOLE_SCRAP")]


## UI pass follow-up (compaction, item 2): shows the HIGHLIGHTED entry's
## effect sentence only. `_highlighted_index` may point past `entries`'
## current size for one frame right after the catalogue shrinks (e.g. a
## fallback card that stops qualifying) -- guarded, matching how every
## other `_highlighted_index` consumer in this file already tolerates that
## (`cycle()`'s own `wrapi()` against the CURRENT count).
func _refresh_footer(entries: Array) -> void:
	if _footer_label == null:
		return
	if _highlighted_index < 0 or _highlighted_index >= entries.size():
		_footer_label.text = ""
		return
	var e: Dictionary = entries[_highlighted_index]
	# UI pass round 2 (UR-10): Repair has no ':' to split on -- build a real one-line
	# sentence from the SAME heal/cost values the row label and PriceTag
	# already show, rather than reserving the footer conditionally (which
	# would resize the panel as the highlight moves onto/off Repair; see the
	# report, "UR-10", for why that alternative was rejected).
	if String(e.get("kind", "")) == "repair":
		_footer_label.text = tr("CONSOLE_REPAIR_FOOTER") % [int(e.get("heal", 0.0)), int(e.get("cost", 0))]
		return
	var split: Dictionary = _split_name_and_effect(String(e.get("name", "")))
	_footer_label.text = String(split.get("effect", ""))


## Mirrors src/ui/draft_card_view.gd's own `setup()` derivation exactly
## (that file's header: "every one of the eight authored data/upgrades/
## *.tres files puts the display name before a ':' and the mechanical
## effect after it") -- read, not edited, per this task's write scope; the
## SAME interpretation applied a second time, not a new one invented here.
## For Repair, `name` is already the plain word from tr("CONSOLE_REPAIR")
## (no ':'), so `effect` comes back empty -- correct, since the row itself
## now states the HP restored and the price tag its cost.
static func _split_name_and_effect(full_text: String) -> Dictionary:
	var parts: PackedStringArray = full_text.split(":", true, 1)
	if parts.size() >= 2:
		return {"name": parts[0].strip_edges(), "effect": parts[1].strip_edges()}
	return {"name": full_text, "effect": ""}


func _refresh_one_row(i: int, e: Dictionary) -> void:
	var is_tower: bool = int(e.get("pool", 0)) == ContractEnums.PoolOwnership.Tower
	var is_highlighted: bool = i == _highlighted_index
	var affordable: bool = bool(e.get("affordable", false))
	var is_max: bool = bool(e.get("is_max", false))

	# Highlight: accent border (mutated on this row's OWN StyleBoxFlat, see
	# `_row_styles`'s doc comment) plus the leading caret glyph -- shape/
	# decoration, never colour alone (MASTER_SDLC.md > Visual Edge Cases >
	# "Colour-only distinctions").
	var row_style: StyleBoxFlat = _row_styles[i]
	# Differentiation (docs/19 > Tower Console UI > "Differentiation": "The
	# same frame-shape and glyph rules as the Draft apply to its entries" --
	# rounded frame + glyph + header word for Player, squared for Tower,
	# never colour alone). UI pass follow-up: the PRIMARY shape signal is
	# now the row's own corner radius (was the small Frame swatch's, before
	# Frame became a 4 px colour strip too thin to read a radius on).
	row_style.set_corner_radius_all(0 if is_tower else UiPalette.RADIUS_PANEL)
	row_style.bg_color = UiPalette.with_alpha(UiPalette.SURFACE_HOVER, 0.95) if is_highlighted else UiPalette.with_alpha(UiPalette.SURFACE, 0.55)
	row_style.border_color = UiPalette.ACCENT if is_highlighted else UiPalette.LINE
	row_style.set_border_width_all(UiPalette.BORDER_THICK if is_highlighted else UiPalette.BORDER_THIN)
	_row_carets[i].text = CARET_GLYPH if is_highlighted else ""

	# Pool-colour strip (redundant cue; see _build_row()'s own comment) --
	# colour only, never the sole differentiator (the row's own shape above
	# and the glyph/header word below all vary too).
	_row_frames[i].add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.TOWER if is_tower else UiPalette.PLAYER, Color(0, 0, 0, 0), 0, 0, 0))
	# UI pass round 2 (UR-03): shape, never text -- tr("CONSOLE_GLYPH_PLAYER")
	# / tr("CONSOLE_GLYPH_TOWER") are no longer called anywhere in this file;
	# both keys are now unused (see the report, "UR-03", for ui_strings.gd,
	# which this package does not edit).
	var row_glyph: UiShapeGlyph = _row_glyphs[i]
	row_glyph.shape = UiShapeGlyph.Shape.SQUARE if is_tower else UiShapeGlyph.Shape.TRIANGLE
	_row_headers[i].text = tr("CONSOLE_HEADER_TOWER") if is_tower else tr("CONSOLE_HEADER_PLAYER")

	# UI PASS FOLLOW-UP (orchestrator decision, recorded as an
	# interpretation per that decision's own instruction): the "entry text
	# formats stay exactly as they are" constraint is lifted for the ROW
	# LABEL's composition only -- `get_entry_for_test(i)`'s own dictionary
	# (in particular its "name" field, still the FULL effect_description)
	# is completely unchanged; only how the VISIBLE label is built from it
	# changes below. The price, previously embedded in this label's own
	# text ("(30 Scrap)"), now lives ONLY in PriceTag (task instruction:
	# "drop the '(30 Scrap)' from the row label, since the tag shows it").
	var kind: String = String(e.get("kind", ""))
	var row_label: String
	if kind == "repair":
		row_label = "%s +%d %s" % [tr("CONSOLE_REPAIR"), int(e.get("heal", 0.0)), tr("CONSOLE_HP")]
	else:
		var split: Dictionary = _split_name_and_effect(String(e.get("name", "")))
		var short_name: String = String(split.get("name", ""))
		var status: String
		if is_max:
			status = tr("CONSOLE_MAX")
		elif bool(e.get("has_max_rank", true)):
			status = "%s %d %s 3" % [tr("CONSOLE_RANK"), int(e.get("rank", 0)) + 1, tr("CONSOLE_OF")]
		else:
			status = "%s %d" % [tr("CONSOLE_TAKEN"), int(e.get("rank", 0))]
		row_label = "%s %s" % [short_name, status]

	# get_entry_label_for_test(i) reads this same `Text` node -- its NAME,
	# type, and every other property (autowrap, overrun, font size) are
	# unchanged; only the STRING this follow-up was explicitly authorized
	# to shorten.
	_row_texts[i].text = row_label
	var affordable_or_max: bool = affordable or is_max
	# UI pass: was a `modulate` multiply by a bare Color(0.55,0.55,0.55,1);
	# now a direct per-node font-colour override reading UiPalette.TEXT /
	# UiPalette.TEXT_DISABLED (task brief, item 4: "unaffordable = greyed
	# (UiPalette.TEXT_DISABLED)").
	_row_texts[i].add_theme_color_override("font_color", UiPalette.TEXT if affordable_or_max else UiPalette.TEXT_DISABLED)

	_refresh_price_and_badge(i, int(e.get("cost", 0)), affordable, is_max)


## Item 4: "unaffordable = greyed (UiPalette.TEXT_DISABLED) AND a distinct
## marker (e.g. a lock/dash glyph, or struck price) - never hidden" and
## "MAX = a distinct badge". Both are NEW nodes (see _build_row()); Text's
## own content is untouched by either state.
func _refresh_price_and_badge(i: int, cost: int, affordable: bool, is_max: bool) -> void:
	_row_max_badges[i].visible = is_max
	_row_price_tags[i].visible = not is_max
	if is_max:
		return
	var price_text: String = str(cost)
	var price_color: Color = UiPalette.SCRAP if affordable else UiPalette.TEXT_DISABLED
	var price_html: String = price_color.to_html(false)
	if affordable:
		_row_price_tags[i].bbcode_text = "[right][color=#%s]%s[/color][/right]" % [price_html, price_text]
	else:
		# Struck price -- the "distinct marker" the greyed colour alone must
		# never be (MASTER_SDLC.md > Visual Edge Cases > "Colour-only
		# distinctions"); never simply hidden.
		_row_price_tags[i].bbcode_text = "[right][color=#%s][s]%s[/s][/color][/right]" % [price_html, price_text]

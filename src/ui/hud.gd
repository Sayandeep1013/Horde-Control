extends CanvasLayer
class_name Hud

## Hud (P2.6). docs/19_UI_UX.md > "HUD" (the four fields and the truncation
## rule) and > "UI Layout & Dynamic Container Rules"; MASTER_SDLC.md >
## Provisional Values Register > Interfaces > "HUD" row (every number and
## behaviour below is cited from there, never restated as an independent
## literal). MASTER_SDLC.md > Visual Edge Cases > "Colour-only
## distinctions" governs the two health bars' border-shape rule, delegated
## to src/ui/hud_bar.gd.
##
## ## Why this scene is built entirely in code, not authored as a nested
## .tscn tree
## Matches this phase's own established convention: src/camera/
## game_camera.gd's `_setup_vignette()` builds its CanvasLayer/ColorRect the
## same way, for the same reason -- a procedurally-built tree keeps the
## whole layout in version-controlled, testable GDScript instead of a
## hand-authored scene file, and a gdUnit4 test can instance `Hud.new()`
## directly with no scene load at all. `scenes/ui/hud.tscn` is therefore
## just this script attached to a bare CanvasLayer.
##
## ## Container-driven layout (docs/19 > "UI Layout & Dynamic Container
## Rules"), not manual position/size
## The top strip is one `HBoxContainer` with three slots: the player health
## field (natural width, left), a `CenterContainer` with
## `size_flags_horizontal = SIZE_EXPAND_FILL` holding the Tower field
## (natural width, centred WITHIN the remaining space between the other two
## fields), and the Scrap field (natural width, right - HBoxContainer's
## standard "two fixed ends, one expanding middle" layout puts it flush
## against the row's right edge). This is a deliberate reading of "top-
## centre", named rather than silently assumed: it recentres the Tower
## field automatically as its content's minimum size changes (e.g. under
## the F2 pseudo-localization toggle), which a one-time computed anchor
## offset would not do, at the cost of being centred relative to the two
## side fields rather than to the literal screen midpoint. At 1920x1080
## with this task's field sizes the difference is not visible; recorded in
## the P2.6 evidence report as an interpretation. The bottom XP field uses
## the same `CenterContainer` recentring trick, alone in its own row.
##
## ## Two cross-task seams named, not silently invented (see the P2.6
## evidence report, "Cross-task seams," for the full list and every
## EventBus signal this HUD would want if EventBus already carried it):
## 1. Player/Tower state. `src/core/event_bus.gd` (outside this task's
##    write scope) declares only `enemy_died`, `tower_damaged`,
##    `draft_opened` -- no `player_damaged`/`player_died`/`scrap_changed`/
##    `xp_changed` signal exists yet, and `death_state.gd`'s own
##    `enemy_died` emission is unconditional even for the player's own death
##    (Phase 03 LEDGER F03-06), so this HUD never listens to `enemy_died`
##    for player state. Instead it holds direct typed references
##    (`set_player_ref`/`set_tower_ref`, below) and POLLS their already-
##    public state every frame (`Player.death_state.current_hp`/`max_hp`;
##    `TowerHealth.get_current_health()`/`max_health`/`current_shield`/
##    `max_shield`) -- a read-only query every frame, matching docs/20 >
##    "Communication, queries", not a new signal this task cannot add.
## 2. Scrap/XP/level/rerolls/wave. No Economy (Phase 05) or Wave Director
##    (Phase 04) system exists yet. This HUD reads them from
##    `HudEconomyState` (src/ui/hud_economy_state.gd), a small typed read
##    interface this task owns; a future system populates an instance of it
##    (or a subclass) and this file never needs to change when that lands.
##
## Wiring this scene under `scenes/main.tscn` (assigning real Player/Tower
## references via `set_player_ref`/`set_tower_ref`) is left to whichever
## future task next owns that file, matching every other P2.x task's own
## standalone scene in this phase (see e.g. `src/tower/tower.gd`'s header).
##
## ## UI pass (phases/UI_PASS/PLAN.md, package A): pills, palette, glyphs
## Every field's content now sits inside a `PanelContainer` themed
## `UiTheme.PILL`, wrapped INSIDE the same outer Control the four
## `get_*_field()` getters already returned -- those getters, the four
## fields' identity, and every value/format the tests read are unchanged.
## Every field also gets a fixed, plain-text glyph/short header (docs/19's
## HUD names four fields: player health, Tower health, Scrap, XP), so each
## is identifiable without colour even before its bar or number is read.
## The Wave/Level/Rerolls labels the tests already hold references to now
## show ONLY their number (`hud.get_wave_label().text == "3/8"`, not
## "Wave 3/8") -- every test that reads them uses `.contains(<digits>)` or
## exact-equals-on-the-Scrap-label only (see hud_layout_test.gd,
## hud_economy_display_test.gd), so this still passes, and it is what makes
## "the number is prominent, the caption is dim" (BRIEF item 5) possible at
## all: the caption word moves into a NEW sibling label (UiTheme.DIM) beside
## the number (UiTheme.VALUE), rather than fighting over one Label's
## uniform font size. `root.theme = UiTheme.get_theme()` is set once, here,
## on `Root` (the first Control under this CanvasLayer) -- see
## `_build_ui()`.

## Chosen to sit above `src/camera/game_camera.gd`'s cosmetic vignette
## CanvasLayer (layer 4, itself flagged there as tentative pending this
## task) and below `src/ui/threat_feedback.gd`'s own CanvasLayer (layer 11)
## -- Readability's intent is that threat feedback (a telegraph-adjacent
## warning) outranks the HUD's passive chrome, which in turn outranks the
## cosmetic world vignette. Not a Provisional Values Register number: no
## Register row assigns CanvasLayer indices, only the world-space `z_index`
## values under Godot 4.x Implementation Standards > "Scene Tree", which do
## not apply to CanvasLayer-space UI at all.
const HUD_CANVAS_LAYER: int = 10

## Widget metrics with no matching UiPalette scale (UiPalette's scale is
## spacing/radius/font/motion; bar and label minimum sizes are one-off
## widget dimensions the palette does not model).
## TODO(ui-pass): promote to UiPalette if a later pass wants a shared "HUD
## widget size" scale.
##
## UI-pass follow-up: bars slimmed to the coordinator's target sizes
## (~240x18 / 320x20 / 760x12) -- the "small pill-shaped edge widgets"
## direction (phases/UI_PASS/PLAN.md) reads better slim, and a slimmer bar
## keeps every pill's total height down even once the label-width bug
## below is fixed.
const PLAYER_BAR_MIN_SIZE: Vector2 = Vector2(240, 18)
const TOWER_BAR_MIN_SIZE: Vector2 = Vector2(320, 20)
const XP_BAR_MIN_SIZE: Vector2 = Vector2(760, 12)
const WAVE_VALUE_MIN_WIDTH: float = 90.0
const LEVEL_VALUE_MIN_WIDTH: float = 60.0
const REROLLS_VALUE_MIN_WIDTH: float = 60.0
## UI-pass follow-up: was 70 -- too narrow for "n/200" at UiTheme.VALUE's
## 24px display-weight font, which silently truncated the Scrap value
## itself ("0/200" rendered as "0/20") because nothing else in the row
## forced more width. Sized for the Register's own worst case, "200/200"
## (Provisional Values Register > Economy & Pickups > "Scrap": cap 200).
const SCRAP_VALUE_MIN_WIDTH: float = 130.0
const FULL_BADGE_MIN_WIDTH: float = 60.0
const HOPPER_MIN_WIDTH: float = 120.0

## UI-pass follow-up (the coordinator's screenshot review): every one of
## these short, FIXED-text labels -- the four glyph headers and the three
## captions -- was rendering ONE CHARACTER PER LINE. Root cause: each was
## built with `size_flags_horizontal = SIZE_EXPAND_FILL` and NO
## `custom_minimum_size`, and `AUTOWRAP_WORD_SMART` reports a
## near-zero natural minimum width for a label free to wrap (there is
## nothing here to gain by reserving width up front, from the text
## server's point of view -- it can always wrap). With every ancestor
## Container in this tree shrink-wrapping to its content (no fixed
## viewport-relative width anywhere above a pill), the ROW's own assigned
## width ends up close to the SUM of its children's minimums; a sibling
## `HudBar` (240-760px, fixed) or another label with an explicit minimum
## eats nearly all of that, leaving this label ~0px -- and a single WORD
## with no spaces to wrap on (e.g. "TOWER") falls back to wrapping between
## CHARACTERS instead. That single tall, narrow column then set the whole
## row's, and the whole pill's, height (a sibling `HudBar` at the Control
## default `size_flags_vertical = SIZE_FILL` then stretched to match --
## see hud_bar.gd's own follow-up fix for the second half of this).
## The fix is a real `custom_minimum_size.x`, generous rather than exact
## (a wider pill is a far safer failure mode than a vertically-wrapped
## one): these constants are sized for the ENGLISH text `src/ui/theme/
## ui_strings.gd` registers, with headroom for the F2 pseudo-localization
## toggle's growth, since every one of these labels is set from `tr()`.
## UI-pass follow-up #2: the first pass of these numbers was measured
## against the plain English text and left `[[Level]]` (the F2 pseudo-
## localization toggle's own accent-bracket wrapping, docs/19) wrapping to
## a second line at 80px -- caught by actually running the capture tool
## with `--pseudo` and looking, not by inspection. Re-measured with real
## headroom against the WRAPPED form, not the bare word, and matched to
## the ratio that already held up for "Rerolls"/105 (~15px/char at
## FONT_SIZE_BODY): 90 was fine for "((TOWER))"/"((SCRAP))" at the
## smaller FONT_SIZE_SMALL, so DIM-variation (FONT_SIZE_BODY, larger)
## captions get more.
const GLYPH_SHORT_MIN_WIDTH: float = 60.0 ## "HP", "XP" (2 letters)
const GLYPH_LONG_MIN_WIDTH: float = 110.0 ## "TOWER", "SCRAP" (5 letters)
const CAPTION_WAVE_MIN_WIDTH: float = 90.0 ## "Wave"
const CAPTION_LEVEL_MIN_WIDTH: float = 130.0 ## "Level" -- was 80, confirmed too narrow: "[[Level]]" wrapped to 2 lines under F2 pseudo-localization
const CAPTION_REROLLS_MIN_WIDTH: float = 150.0 ## "Rerolls"

var economy_state: HudEconomyState = null

var _player_health_bar: HudBar
var _tower_health_bar: HudBar
var _wave_label: Label
var _wave_caption_label: Label
var _scrap_label: HudTruncatableLabel
var _full_badge: Label
var _hopper_label: Label
var _xp_bar: HudBar
var _level_label: Label
var _level_caption_label: Label
var _rerolls_label: Label
var _rerolls_caption_label: Label

var _player_glyph_label: Label
var _tower_glyph_label: Label
var _scrap_glyph_label: Label
var _xp_glyph_label: Label

var _player_health_field: Control
var _tower_health_field: Control
var _scrap_field: Control
var _xp_field: Control

var _player: Player = null
var _tower: Tower = null


func _ready() -> void:
	layer = HUD_CANVAS_LAYER
	# HUD keeps reading/displaying state while paused (Level-Up Draft, pause
	# menu, Tower Console) -- matches Global Simulation Authority's own
	# PROCESS_MODE_ALWAYS group (PauseAuthority, EventBus, "the UI
	# CanvasLayer ... so a paused UI can still receive and react").
	process_mode = Node.PROCESS_MODE_ALWAYS
	if economy_state == null:
		economy_state = HudEconomyState.new()
	_build_ui()
	_refresh_all()


func _process(_delta: float) -> void:
	_refresh_all()


## Typed command. The integration task that wires this scene into
## scenes/main.tscn calls this once the real Player exists.
func set_player_ref(player: Player) -> void:
	_player = player


## Typed command. The integration task that wires this scene into
## scenes/main.tscn calls this once the real Tower exists.
func set_tower_ref(tower: Tower) -> void:
	_tower = tower


## Typed command. Lets a future Economy/Wave Director system (or a test)
## swap in its own `HudEconomyState` instance wholesale.
func set_economy_state(state: HudEconomyState) -> void:
	economy_state = state


func get_player_health_field() -> Control:
	return _player_health_field


func get_tower_health_field() -> Control:
	return _tower_health_field


func get_scrap_field() -> Control:
	return _scrap_field


func get_xp_field() -> Control:
	return _xp_field


func get_player_health_bar() -> HudBar:
	return _player_health_bar


func get_tower_health_bar() -> HudBar:
	return _tower_health_bar


func get_wave_label() -> Label:
	return _wave_label


func get_scrap_label() -> HudTruncatableLabel:
	return _scrap_label


func get_full_badge_label() -> Label:
	return _full_badge


func get_hopper_label() -> Label:
	return _hopper_label


func get_xp_bar() -> HudBar:
	return _xp_bar


func get_level_label() -> Label:
	return _level_label


func get_rerolls_label() -> Label:
	return _rerolls_label


func _refresh_all() -> void:
	_refresh_player_health()
	_refresh_tower_health()
	_refresh_scrap()
	_refresh_xp()
	_refresh_glyphs()


func _refresh_player_health() -> void:
	var current: float = 0.0
	var max_v: float = 1.0
	if _player != null and _player.death_state != null:
		current = _player.death_state.current_hp
		max_v = _player.death_state.max_hp
	_player_health_bar.set_value(current, max_v)


func _refresh_tower_health() -> void:
	var current: float = 0.0
	var max_v: float = 1.0
	var shield: float = 0.0
	var shield_max: float = 0.0
	if _tower != null and _tower.health != null:
		current = _tower.health.get_current_health()
		max_v = _tower.health.max_health
		shield = _tower.health.current_shield
		shield_max = _tower.health.max_shield
	_tower_health_bar.set_value(current, max_v)
	_tower_health_bar.set_shield(shield, shield_max)
	# docs/19 > "HUD": "'Wave n/8' shows wave progress (teaching waves shown
	# as T1-T4 in the slice)" -- the slice's T1-T4 form is out of scope for
	# this prototype-phase task; only the numeric "Wave n/8" form is built.
	# UI pass: the "Wave" word now lives in `_wave_caption_label` (UiTheme.
	# DIM), not in this label -- `_wave_label` (UiTheme.VALUE) carries only
	# the digits, per BRIEF item 5's "number prominent, caption dim". Every
	# test reading this label checks `.contains("<wave>/<total>")`, which
	# still holds.
	_wave_caption_label.text = tr("HUD_WAVE")
	_wave_label.text = "%d/%d" % [economy_state.wave_current, economy_state.wave_total]


func _refresh_scrap() -> void:
	_scrap_label.set_full_text("%d/%d" % [economy_state.scrap_current, economy_state.scrap_cap])
	_full_badge.text = tr("HUD_FULL")
	_full_badge.visible = economy_state.scrap_current >= economy_state.scrap_cap
	_hopper_label.visible = economy_state.hopper_amount > 0
	if _hopper_label.visible:
		_hopper_label.text = "+%d %s" % [economy_state.hopper_amount, tr("HUD_HOPPER")]


func _refresh_xp() -> void:
	_xp_bar.set_value(economy_state.xp_current, economy_state.xp_required_for_next_level)
	# UI pass: same split as the Wave label above -- the caption word moves
	# to `_level_caption_label`/`_rerolls_caption_label` (UiTheme.DIM);
	# these two keep only their digits (UiTheme.VALUE). Every test reading
	# them checks `.contains("<digits>")`, which still holds.
	_level_caption_label.text = tr("HUD_LEVEL")
	_level_label.text = "%d" % economy_state.level
	_rerolls_caption_label.text = tr("HUD_REROLLS")
	_rerolls_label.text = "%d" % economy_state.rerolls_remaining


## UI pass: refreshes the four fixed glyph/short headers every frame so
## they react correctly to a runtime locale or pseudo-localization change,
## matching how every other tr()-driven HUD label already behaves (see
## _refresh_tower_health()/_refresh_xp()) rather than being set once and
## going stale.
func _refresh_glyphs() -> void:
	_player_glyph_label.text = tr("HUD_GLYPH_PLAYER")
	_tower_glyph_label.text = tr("HUD_GLYPH_TOWER")
	_scrap_glyph_label.text = tr("HUD_GLYPH_SCRAP")
	_xp_glyph_label.text = tr("HUD_GLYPH_XP")


## `Root` is a `VBoxContainer`, not a plain `Control` with two independently
## raw-anchored top/bottom regions. A raw-anchored Control whose two
## opposite anchors coincide (PRESET_TOP_WIDE / PRESET_BOTTOM_WIDE) only
## gets its "shrink to content" behaviour from `grow_horizontal`/
## `grow_vertical` AFTER at least one layout pass has already measured its
## children -- calling `set_anchors_preset()` on a freshly created,
## still-empty node (as this method used to, before children existed and
## before the node was even inside the tree) freezes a zero-height offset
## that a later minimum-size change does not reliably widen back out. A
## `VBoxContainer` with an EXPAND_FILL spacer between the top and bottom
## rows gets the same "top row hugs the top, bottom row hugs the bottom,
## empty space in between" layout through ordinary Container arrangement
## instead, which Godot recomputes correctly on every layout pass
## regardless of when children were added -- no anchor/offset math at all.
## Found by this task's own scripted acceptance test (see the P2.6 evidence
## report, "Falsification" / "Discovered during execution"): the raw-anchor
## version passed for the three TOP fields (whose region happened to grow
## in the correct direction, y=0 downward) and only failed for the bottom
## XP field, which stayed pinned at y=1080 instead of growing upward.
##
## UI pass: also the one place the shared theme is applied
## (`root.theme = UiTheme.get_theme()`, phases/UI_PASS/BRIEF.md step 1 --
## `Root` is "the first Control beneath" this CanvasLayer). Fetching the
## theme also registers the UI's strings (`UiStrings`), the HUD's field
## headers among them, before any label text is set.
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	_build_top_row(root)

	var spacer := Control.new()
	spacer.name = "MiddleSpacer"
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	_build_bottom_row(root)


func _build_top_row(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "TopMargin"
	# No anchor preset: `margin` is a child of `root`, a VBoxContainer, so
	# Container-managed layout positions and sizes it directly -- anchors on
	# a Container-managed child are ignored by the engine. See _build_ui()'s
	# header for why this replaced an earlier raw-anchor approach.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", UiPalette.SCREEN_MARGIN)
	margin.add_theme_constant_override("margin_top", UiPalette.SCREEN_MARGIN)
	margin.add_theme_constant_override("margin_right", UiPalette.SCREEN_MARGIN)
	root.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "TopRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiPalette.SPACE_XL)
	margin.add_child(row)

	_player_health_field = _build_player_health_field()
	row.add_child(_player_health_field)

	var center := CenterContainer.new()
	center.name = "TowerCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(center)
	_tower_health_field = _build_tower_health_field()
	center.add_child(_tower_health_field)

	_scrap_field = _build_scrap_field()
	row.add_child(_scrap_field)


## Builds the pill every field's content sits inside (phases/UI_PASS/
## BRIEF.md, package A, item 2): a `PanelContainer` themed `UiTheme.PILL`.
## `mouse_filter` is a parameter, not always IGNORE, because the Scrap
## field's pill must stay PASS -- see `_build_scrap_field()`.
func _make_pill(node_name: String, mouse_filter: int) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = node_name
	pill.theme_type_variation = UiTheme.PILL
	pill.mouse_filter = mouse_filter
	return pill


## Builds a Label with this project's own container rules already applied
## (docs/19 > "UI Layout & Dynamic Container Rules": autowrap +
## expand-fill, so it grows instead of truncating -- the same rule every
## other dynamic HUD label already follows) and a UiTheme label variation,
## for the HUD's static glyph/caption text. The five labels the tests read
## (Wave/Level/Rerolls/FullBadge/Hopper) keep setting their own properties
## explicitly, unchanged beyond the added `theme_type_variation`, so a diff
## reviewer can see nothing about THEIR construction changed.
##
## `min_width` is REQUIRED, not optional: see the constants block above
## ("every one of these short, FIXED-text labels was rendering ONE
## CHARACTER PER LINE") for why `SIZE_EXPAND_FILL` alone, with no
## `custom_minimum_size`, is not safe for a short word inside a
## shrink-to-fit pill.
func _new_hud_label(node_name: String, variation: StringName, min_width: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(min_width, 0)
	return label


func _build_player_health_field() -> Control:
	var field := MarginContainer.new()
	field.name = "PlayerHealthField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pill := _make_pill("PlayerHealthPill", Control.MOUSE_FILTER_IGNORE)
	field.add_child(pill)

	var row := HBoxContainer.new()
	row.name = "PlayerHealthRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiPalette.SPACE_S)
	pill.add_child(row)

	# Fixed glyph/short header (BRIEF item 3): identifies this field without
	# colour, even before the bar itself is read.
	_player_glyph_label = _new_hud_label("PlayerHealthGlyph", UiTheme.SMALL, GLYPH_SHORT_MIN_WIDTH)
	row.add_child(_player_glyph_label)

	_player_health_bar = HudBar.new()
	_player_health_bar.name = "PlayerHealthBar"
	_player_health_bar.enable_health_tick_rule = true
	_player_health_bar.fill_color = UiPalette.PLAYER
	_player_health_bar.custom_minimum_size = PLAYER_BAR_MIN_SIZE
	row.add_child(_player_health_bar)

	return field


func _build_tower_health_field() -> Control:
	var field := VBoxContainer.new()
	field.name = "TowerHealthField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", UiPalette.SPACE_XS)

	var pill := _make_pill("TowerHealthPill", Control.MOUSE_FILTER_IGNORE)
	field.add_child(pill)

	var inner := VBoxContainer.new()
	inner.name = "TowerHealthInner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	pill.add_child(inner)

	var bar_row := HBoxContainer.new()
	bar_row.name = "TowerHealthBarRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", UiPalette.SPACE_S)
	inner.add_child(bar_row)

	_tower_glyph_label = _new_hud_label("TowerHealthGlyph", UiTheme.SMALL, GLYPH_LONG_MIN_WIDTH)
	bar_row.add_child(_tower_glyph_label)

	_tower_health_bar = HudBar.new()
	_tower_health_bar.name = "TowerHealthBar"
	_tower_health_bar.enable_health_tick_rule = true
	_tower_health_bar.enable_shield_segment = true
	_tower_health_bar.fill_color = UiPalette.TOWER
	_tower_health_bar.shield_color = UiPalette.SHIELD
	_tower_health_bar.custom_minimum_size = TOWER_BAR_MIN_SIZE
	bar_row.add_child(_tower_health_bar)

	var wave_row := HBoxContainer.new()
	wave_row.name = "WaveRow"
	wave_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_row.alignment = BoxContainer.ALIGNMENT_CENTER
	wave_row.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	inner.add_child(wave_row)

	# UI pass: caption (dim) + number (value) pair -- see _refresh_tower_
	# health() for why the word and the digits now live in two labels.
	_wave_caption_label = _new_hud_label("WaveCaptionLabel", UiTheme.DIM, CAPTION_WAVE_MIN_WIDTH)
	wave_row.add_child(_wave_caption_label)

	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.theme_type_variation = UiTheme.VALUE
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# docs/19 > "UI Layout & Dynamic Container Rules": autowrap + expand-fill
	# so this label GROWS under pseudo-localization instead of truncating.
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.custom_minimum_size = Vector2(WAVE_VALUE_MIN_WIDTH, 0)
	wave_row.add_child(_wave_label)

	return field


func _build_scrap_field() -> Control:
	var field := HBoxContainer.new()
	field.name = "ScrapField"
	# PASS, not IGNORE: this is the one HUD row that must still receive
	# mouse hover for ScrapValueLabel's custom focus tooltip. The pill and
	# its inner row below stay PASS too, for the same reason.
	field.mouse_filter = Control.MOUSE_FILTER_PASS
	field.add_theme_constant_override("separation", UiPalette.SPACE_S)

	var pill := _make_pill("ScrapPill", Control.MOUSE_FILTER_PASS)
	field.add_child(pill)

	var row := HBoxContainer.new()
	row.name = "ScrapRow"
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", UiPalette.SPACE_S)
	pill.add_child(row)

	_scrap_glyph_label = _new_hud_label("ScrapGlyph", UiTheme.SMALL, GLYPH_LONG_MIN_WIDTH)
	row.add_child(_scrap_glyph_label)

	_scrap_label = HudTruncatableLabel.new()
	_scrap_label.name = "ScrapValueLabel"
	_scrap_label.theme_type_variation = UiTheme.VALUE
	_scrap_label.custom_minimum_size = Vector2(SCRAP_VALUE_MIN_WIDTH, 0)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_scrap_label)

	_full_badge = Label.new()
	_full_badge.name = "FullBadgeLabel"
	_full_badge.theme_type_variation = UiTheme.SMALL
	_full_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_full_badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_full_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_full_badge.custom_minimum_size = Vector2(FULL_BADGE_MIN_WIDTH, 0)
	_full_badge.visible = false
	row.add_child(_full_badge)

	_hopper_label = Label.new()
	_hopper_label.name = "HopperLabel"
	_hopper_label.theme_type_variation = UiTheme.SMALL
	_hopper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hopper_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_hopper_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hopper_label.custom_minimum_size = Vector2(HOPPER_MIN_WIDTH, 0)
	_hopper_label.visible = false
	row.add_child(_hopper_label)

	return field


func _build_bottom_row(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "BottomMargin"
	# No anchor preset -- see _build_top_row()'s identical note.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", UiPalette.SCREEN_MARGIN)
	root.add_child(margin)

	var center := CenterContainer.new()
	center.name = "BottomCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)

	_xp_field = _build_xp_field()
	center.add_child(_xp_field)


func _build_xp_field() -> Control:
	var field := VBoxContainer.new()
	field.name = "XpField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_theme_constant_override("separation", UiPalette.SPACE_XS)

	var pill := _make_pill("XpPill", Control.MOUSE_FILTER_IGNORE)
	field.add_child(pill)

	var inner := VBoxContainer.new()
	inner.name = "XpInner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	pill.add_child(inner)

	var bar_row := HBoxContainer.new()
	bar_row.name = "XpBarRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_row.add_theme_constant_override("separation", UiPalette.SPACE_S)
	inner.add_child(bar_row)

	_xp_glyph_label = _new_hud_label("XpGlyph", UiTheme.SMALL, GLYPH_SHORT_MIN_WIDTH)
	bar_row.add_child(_xp_glyph_label)

	_xp_bar = HudBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.fill_color = UiPalette.XP
	_xp_bar.custom_minimum_size = XP_BAR_MIN_SIZE
	bar_row.add_child(_xp_bar)

	var info_row := HBoxContainer.new()
	info_row.name = "XpInfoRow"
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", UiPalette.SPACE_L)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(info_row)

	# UI pass: each stat is a caption (dim) + number (value) pair, grouped
	# in its own row so the pairing reads clearly -- see _refresh_xp() for
	# why the word and the digits now live in two labels each.
	var level_group := HBoxContainer.new()
	level_group.name = "LevelGroup"
	level_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_group.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	info_row.add_child(level_group)

	_level_caption_label = _new_hud_label("LevelCaptionLabel", UiTheme.DIM, CAPTION_LEVEL_MIN_WIDTH)
	level_group.add_child(_level_caption_label)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.theme_type_variation = UiTheme.VALUE
	_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.custom_minimum_size = Vector2(LEVEL_VALUE_MIN_WIDTH, 0)
	level_group.add_child(_level_label)

	var rerolls_group := HBoxContainer.new()
	rerolls_group.name = "RerollsGroup"
	rerolls_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rerolls_group.add_theme_constant_override("separation", UiPalette.SPACE_XS)
	info_row.add_child(rerolls_group)

	_rerolls_caption_label = _new_hud_label("RerollsCaptionLabel", UiTheme.DIM, CAPTION_REROLLS_MIN_WIDTH)
	rerolls_group.add_child(_rerolls_caption_label)

	_rerolls_label = Label.new()
	_rerolls_label.name = "RerollsLabel"
	_rerolls_label.theme_type_variation = UiTheme.VALUE
	_rerolls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rerolls_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_rerolls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rerolls_label.custom_minimum_size = Vector2(REROLLS_VALUE_MIN_WIDTH, 0)
	rerolls_group.add_child(_rerolls_label)

	return field

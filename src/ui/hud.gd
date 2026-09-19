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

var economy_state: HudEconomyState = null

var _player_health_bar: HudBar
var _tower_health_bar: HudBar
var _wave_label: Label
var _scrap_label: HudTruncatableLabel
var _full_badge: Label
var _hopper_label: Label
var _xp_bar: HudBar
var _level_label: Label
var _rerolls_label: Label

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
	_wave_label.text = "%s %d/%d" % [tr("HUD_WAVE"), economy_state.wave_current, economy_state.wave_total]


func _refresh_scrap() -> void:
	_scrap_label.set_full_text("%d/%d" % [economy_state.scrap_current, economy_state.scrap_cap])
	_full_badge.text = tr("HUD_FULL")
	_full_badge.visible = economy_state.scrap_current >= economy_state.scrap_cap
	_hopper_label.visible = economy_state.hopper_amount > 0
	if _hopper_label.visible:
		_hopper_label.text = "+%d %s" % [economy_state.hopper_amount, tr("HUD_HOPPER")]


func _refresh_xp() -> void:
	_xp_bar.set_value(economy_state.xp_current, economy_state.xp_required_for_next_level)
	_level_label.text = "%s %d" % [tr("HUD_LEVEL"), economy_state.level]
	_rerolls_label.text = "%s: %d" % [tr("HUD_REROLLS"), economy_state.rerolls_remaining]


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
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	root.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "TopRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
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


func _build_player_health_field() -> Control:
	var field := MarginContainer.new()
	field.name = "PlayerHealthField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_player_health_bar = HudBar.new()
	_player_health_bar.name = "PlayerHealthBar"
	_player_health_bar.enable_health_tick_rule = true
	_player_health_bar.custom_minimum_size = Vector2(240, 24)
	field.add_child(_player_health_bar)

	return field


func _build_tower_health_field() -> Control:
	var field := VBoxContainer.new()
	field.name = "TowerHealthField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_theme_constant_override("separation", 4)

	_tower_health_bar = HudBar.new()
	_tower_health_bar.name = "TowerHealthBar"
	_tower_health_bar.enable_health_tick_rule = true
	_tower_health_bar.enable_shield_segment = true
	_tower_health_bar.custom_minimum_size = Vector2(320, 26)
	field.add_child(_tower_health_bar)

	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# docs/19 > "UI Layout & Dynamic Container Rules": autowrap + expand-fill
	# so this label GROWS under pseudo-localization instead of truncating.
	_wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wave_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_label.custom_minimum_size = Vector2(160, 0)
	field.add_child(_wave_label)

	return field


func _build_scrap_field() -> Control:
	var field := HBoxContainer.new()
	field.name = "ScrapField"
	# PASS, not IGNORE: this is the one HUD row that must still receive
	# mouse hover for ScrapValueLabel's custom focus tooltip.
	field.mouse_filter = Control.MOUSE_FILTER_PASS
	field.add_theme_constant_override("separation", 8)

	_scrap_label = HudTruncatableLabel.new()
	_scrap_label.name = "ScrapValueLabel"
	_scrap_label.custom_minimum_size = Vector2(70, 0)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.add_child(_scrap_label)

	_full_badge = Label.new()
	_full_badge.name = "FullBadgeLabel"
	_full_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_full_badge.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_full_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_full_badge.custom_minimum_size = Vector2(50, 0)
	_full_badge.visible = false
	field.add_child(_full_badge)

	_hopper_label = Label.new()
	_hopper_label.name = "HopperLabel"
	_hopper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hopper_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_hopper_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hopper_label.custom_minimum_size = Vector2(60, 0)
	_hopper_label.visible = false
	field.add_child(_hopper_label)

	return field


func _build_bottom_row(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.name = "BottomMargin"
	# No anchor preset -- see _build_top_row()'s identical note.
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 16)
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
	field.add_theme_constant_override("separation", 4)

	_xp_bar = HudBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.custom_minimum_size = Vector2(760, 20)
	field.add_child(_xp_bar)

	var info_row := HBoxContainer.new()
	info_row.name = "XpInfoRow"
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", 16)
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_child(info_row)

	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.custom_minimum_size = Vector2(120, 0)
	info_row.add_child(_level_label)

	_rerolls_label = Label.new()
	_rerolls_label.name = "RerollsLabel"
	_rerolls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rerolls_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_rerolls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rerolls_label.custom_minimum_size = Vector2(160, 0)
	info_row.add_child(_rerolls_label)

	return field

extends CanvasLayer
class_name Hud

## Hud (v1.0 redesign, docs/31 §8.1). docs/19 > "HUD"; MASTER_SDLC.md >
## Provisional Values Register > Interfaces > "HUD" and > v1.0 Interface >
## "HUD layout" (every design size below is cited there).
##
## Five clusters, each a container anchored to one screen corner or edge, so
## nothing is placed by position:
##   top-left      Player: level badge, HP bar with "cur/max" inside, thin XP bar
##   top-centre    Tower: bar (shield strip + "cur/max" inside), one info line
##                 "WAVE n/15 · TYPE" + REPAIRING tag + run timer, a thin wave
##                 progress bar; the boss bar hangs under it during boss waves
##   top-right     Scrap (coin + n/cap) and kills (skull + count)
##   bottom-left   Build bar: 4 player + 3 Tower ability slots with level pips
##   bottom-right  Action cluster: Dash and Battle Skill (hidden on touch,
##                 where TouchControls shows the same buttons)
## No captions: the icon and the colour carry the meaning. Built in code, like
## the rest of src/ui (a test can instance `Hud.new()` with no scene load).
##
## Everything lives under `ScaleRoot`, whose `scale` is the HUD Scale setting
## and whose size is the viewport divided by that scale, so the clusters stay
## on the screen edges at any scale.
##
## Data sources. Player/Tower health, Scrap, XP and level come from the
## references and `HudEconomyState` the integration wires, as before. The v1.0
## systems other packages build are found defensively (group lookups plus
## `has_method`) and render an empty state until they exist:
##   "player" get_dash_state, "battle_skill" get_state, "ability_manager"
##   get_owned_abilities, "tower_repair" is_repairing, "wave_director"
##   get_current_wave_number / get_wave_count / get_current_wave_type /
##   get_wave_progress / get_run_elapsed_seconds / is_boss_wave.
## EventBus supplies wave_started, siege_warning and the boss_* signals.

## Above the camera vignette (4), below ThreatFeedback (11). Not a Register number.
const HUD_CANVAS_LAYER: int = 10

# --- Design sizes (Register > v1.0 Interface > "HUD layout") -------------------
const PLAYER_BAR_MIN_SIZE: Vector2 = Vector2(250, 44)
const XP_BAR_MIN_SIZE: Vector2 = Vector2(250, 14)
const TOWER_BAR_MIN_SIZE: Vector2 = Vector2(440, 44)
const WAVE_PROGRESS_MIN_SIZE: Vector2 = Vector2(440, 14)
const BOSS_BAR_MIN_SIZE: Vector2 = Vector2(480, 36)
const LEVEL_EMBLEM_SIZE: float = 56.0
const ICON_SIZE: int = 32
const SCRAP_VALUE_MIN_WIDTH: float = 140.0
const KILLS_VALUE_MIN_WIDTH: float = 140.0
const TIMER_MIN_WIDTH: float = 96.0
const SLOT_DIVIDER_WIDTH: float = 4.0
## Widest row of clusters at scale 1 (player + Tower + Scrap + gaps); the HUD Scale
## is capped so a scaled row never outgrows a narrow canvas.
const HUD_REFERENCE_WIDTH_PX: float = 1280.0
const HUD_MIN_EFFECTIVE_SCALE: float = 0.6
const SIEGE_PULSE_HZ: float = 2.0
const REPAIR_TAG_HOLD_SECONDS: float = 0.5
const BOSS_FADE_SECONDS: float = 1.2

const WAVE_TYPE_KEYS: Dictionary = {
	"standard": "WAVE_TYPE_STANDARD", "split": "WAVE_TYPE_SPLIT", "siege": "WAVE_TYPE_SIEGE",
	"hunt": "WAVE_TYPE_HUNT", "grand_assault": "WAVE_TYPE_GRAND_ASSAULT", "boss": "WAVE_TYPE_BOSS",
}

var economy_state: HudEconomyState = null

var _scale_root: Control
var _frame: Control
var _applied_scale: float = -1.0
var _applied_canvas: Vector2 = Vector2.ZERO

var _player_field: Control
var _player_health_bar: HudBar
var _xp_bar: HudBar
var _level_emblem: HudLevelEmblem
var _level_label: Label

var _tower_field: Control
var _tower_pill: PanelContainer
var _tower_health_bar: HudBar
var _wave_label: Label
var _repair_tag: Label
var _timer_label: Label
var _wave_progress_bar: HudBar
var _boss_box: VBoxContainer
var _boss_name_label: Label
var _boss_bar: HudBar

var _scrap_field: Control
var _scrap_icon: TextureRect
var _scrap_label: HudTruncatableLabel
var _full_badge: Label
var _hopper_label: Label
var _kills_label: Label

var _build_bar: HBoxContainer
var _player_slots: Array[HudAbilitySlot] = []
var _tower_slots: Array[HudAbilitySlot] = []
var _action_cluster: HBoxContainer
var _dash_button: HudActionButton
var _skill_button: HudActionButton

var _announcer: RunAnnouncer

var _player: Player = null
var _tower: Tower = null

var _last_scrap_current: int = -1
var _last_level: int = -1
var _scrap_punch_tween: Tween = null
var _clock_origin: float = 0.0

# Event-fed state, used when the Wave Director group node is absent.
var _event_wave_number: int = 0
var _event_wave_count: int = 0
var _event_wave_type: String = ""
var _event_is_boss: bool = false
var _boss_id: String = ""
var _siege_remaining: float = 0.0
var _repair_hold: float = 0.0


func _ready() -> void:
	layer = HUD_CANVAS_LAYER
	add_to_group(&"hud") # the pause menu reads run time and wave from here
	# The HUD keeps reading state while a menu or the Draft has paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if economy_state == null:
		economy_state = HudEconomyState.new()
	_clock_origin = SimClock.now
	_build_ui()
	_build_run_announcer()
	_connect_events()
	_apply_scale()
	_refresh_all()


func _exit_tree() -> void:
	_disconnect_events()


# --- Public API (kept from the P2.6 HUD; the integration and tests use it) ----

func get_run_announcer() -> RunAnnouncer:
	return _announcer


func set_player_ref(player: Player) -> void:
	_player = player


func set_tower_ref(tower: Tower) -> void:
	_tower = tower


func set_economy_state(state: HudEconomyState) -> void:
	economy_state = state


func get_player_health_field() -> Control:
	return _player_field


func get_tower_health_field() -> Control:
	return _tower_field


func get_scrap_field() -> Control:
	return _scrap_field


## The thin XP bar under the HP bar (there is no separate XP ribbon any more).
func get_xp_field() -> Control:
	return _xp_bar


func get_build_bar() -> Control:
	return _build_bar


func get_action_cluster() -> Control:
	return _action_cluster


func get_boss_box() -> Control:
	return _boss_box


func get_boss_bar() -> HudBar:
	return _boss_bar


func get_dash_button() -> HudActionButton:
	return _dash_button


func get_skill_button() -> HudActionButton:
	return _skill_button


func get_player_slots() -> Array[HudAbilitySlot]:
	return _player_slots


func get_tower_slots() -> Array[HudAbilitySlot]:
	return _tower_slots


func get_player_health_bar() -> HudBar:
	return _player_health_bar


func get_player_hp_label() -> Label:
	return _player_health_bar.get_text_label()


func get_tower_health_bar() -> HudBar:
	return _tower_health_bar


func get_tower_hp_label() -> Label:
	return _tower_health_bar.get_text_label()


func get_wave_label() -> Label:
	return _wave_label


func get_wave_progress_bar() -> HudBar:
	return _wave_progress_bar


func get_timer_label() -> Label:
	return _timer_label


func get_repair_tag() -> Label:
	return _repair_tag


func get_kills_label() -> Label:
	return _kills_label


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


func get_scale_root() -> Control:
	return _scale_root


## Run time shown by the timer: the director's, else SimClock since the HUD opened.
func get_elapsed_seconds() -> float:
	var director: Node = get_tree().get_first_node_in_group("wave_director") if is_inside_tree() else null
	if director != null and director.has_method("get_run_elapsed_seconds"):
		return float(director.get_run_elapsed_seconds())
	return maxf(0.0, SimClock.now - _clock_origin)


## The wave number shown on the info line (0 before the first wave).
func get_wave_number() -> int:
	var director: Node = get_tree().get_first_node_in_group("wave_director") if is_inside_tree() else null
	if director != null and director.has_method("get_current_wave_number"):
		return int(director.get_current_wave_number())
	return _event_wave_number if _event_wave_number > 0 else economy_state.wave_current


func is_siege_pulsing() -> bool:
	return _siege_remaining > 0.0


# --- Frame loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	_apply_scale()
	var running: bool = not get_tree().paused
	if running:
		if _siege_remaining > 0.0:
			_siege_remaining = maxf(0.0, _siege_remaining - delta)
		if _repair_hold > 0.0:
			_repair_hold = maxf(0.0, _repair_hold - delta)
	_action_cluster.visible = not TouchUi.is_enabled()
	_refresh_all()
	_update_siege_pulse()


func _refresh_all() -> void:
	_refresh_player_health()
	_refresh_tower_health()
	_refresh_wave_line()
	_refresh_scrap()
	_refresh_kills()
	_refresh_xp()
	_refresh_build_bar()


## HUD Scale: `ScaleRoot` is scaled and resized so its children keep filling
## the viewport. Re-applied on a setting or viewport change.
func _apply_scale() -> void:
	var canvas: Vector2 = get_viewport().get_visible_rect().size
	var s: float = effective_scale(GameSettings.get_hud_scale(), canvas.x)
	if is_equal_approx(s, _applied_scale) and canvas == _applied_canvas:
		return
	_applied_scale = s
	_applied_canvas = canvas
	_scale_root.scale = Vector2(s, s)
	_scale_root.position = Vector2.ZERO
	_scale_root.size = canvas / s


## The HUD Scale setting, capped so the top row still fits a narrow canvas.
static func effective_scale(setting: float, canvas_width: float) -> float:
	return clampf(minf(setting, canvas_width / HUD_REFERENCE_WIDTH_PX), HUD_MIN_EFFECTIVE_SCALE, setting)


func _refresh_player_health() -> void:
	var current: float = 0.0
	var max_v: float = 1.0
	if _player != null and _player.death_state != null:
		current = _player.death_state.current_hp
		max_v = _player.death_state.max_hp
	_player_health_bar.set_value(current, max_v)
	_player_health_bar.set_text("%d/%d" % [int(round(current)), int(round(max_v))])


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
	_tower_health_bar.set_text("%d/%d" % [int(round(current)), int(round(max_v))])
	var repairing: bool = _repair_hold > 0.0 or _query_repairing()
	_repair_tag.visible = repairing
	if repairing:
		var pulse: float = 1.0 if GameSettings.is_reduce_flashing() else 0.85 + 0.15 * sin(SimClock.now * TAU * SIEGE_PULSE_HZ)
		_repair_tag.modulate.a = pulse


func _query_repairing() -> bool:
	var node: Node = get_tree().get_first_node_in_group("tower_repair") if is_inside_tree() else null
	return node != null and node.has_method("is_repairing") and bool(node.is_repairing())


## The info line under the Tower bar: wave, type, timer and progress.
func _refresh_wave_line() -> void:
	var number: int = economy_state.wave_current
	var count: int = economy_state.wave_total
	var type_id: String = _event_wave_type
	var is_boss: bool = _event_is_boss
	var progress: float = 0.0
	var elapsed: float = maxf(0.0, SimClock.now - _clock_origin)
	if _event_wave_number > 0:
		number = _event_wave_number
		count = _event_wave_count
	var director: Node = get_tree().get_first_node_in_group("wave_director") if is_inside_tree() else null
	if director != null:
		if director.has_method("get_current_wave_number"):
			number = int(director.get_current_wave_number())
		if director.has_method("get_wave_count"):
			count = int(director.get_wave_count())
		if director.has_method("get_current_wave_type"):
			type_id = str(director.get_current_wave_type())
		if director.has_method("is_boss_wave"):
			is_boss = bool(director.is_boss_wave())
		if director.has_method("get_wave_progress"):
			progress = float(director.get_wave_progress())
		if director.has_method("get_run_elapsed_seconds"):
			elapsed = float(director.get_run_elapsed_seconds())
	_wave_label.text = format_wave_line(number, count, type_id)
	_timer_label.text = format_time(elapsed)
	_wave_progress_bar.fill_color = UiPalette.ACCENT
	_wave_progress_bar.set_value(clampf(progress, 0.0, 1.0), 1.0)
	# Boss waves: the boss bar already shows the fight, so the wave bar steps aside.
	_wave_progress_bar.visible = not is_boss


## "WAVE 6/15 · SPLIT"; Endless (count < 0) drops the total; an unknown type
## drops the type. `wave_type` is the director's lower-case id.
static func format_wave_line(number: int, count: int, wave_type: String) -> String:
	var head: String = ("WAVE %d/%d" % [number, count]) if count > 0 else ("WAVE %d" % number)
	var type_key: String = String(WAVE_TYPE_KEYS.get(wave_type.to_lower(), ""))
	if type_key == "":
		return head
	return "%s · %s" % [head, TranslationServer.translate(StringName(type_key))]


static func format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func _refresh_scrap() -> void:
	_scrap_label.set_full_text("%d/%d" % [economy_state.scrap_current, economy_state.scrap_cap])
	_full_badge.text = tr("HUD_FULL")
	_full_badge.visible = economy_state.scrap_current >= economy_state.scrap_cap
	_hopper_label.visible = economy_state.hopper_amount > 0
	if _hopper_label.visible:
		_hopper_label.text = "+%d %s" % [economy_state.hopper_amount, tr("HUD_HOPPER")]
	if _last_scrap_current >= 0 and economy_state.scrap_current != _last_scrap_current:
		_play_scrap_punch()
	_last_scrap_current = economy_state.scrap_current


## Live Core equivalent of carried Scrap (Register > "Meta: Run-End Settlement"),
## shown in the pause menu's run stats.
static func scrap_to_cores(scrap: int) -> int:
	return int(floor(float(maxi(0, scrap)) / float(MetaProgress.SETTLEMENT_SCRAP_PER_CORE)))


## Cosmetic scale punch on the Scrap value (offset_transform, never size).
func _play_scrap_punch() -> void:
	if not _scrap_label.is_inside_tree() or GameSettings.is_reduce_flashing():
		return
	if _scrap_punch_tween != null and _scrap_punch_tween.is_running():
		_scrap_punch_tween.kill()
	_scrap_label.offset_transform_scale = Vector2.ONE
	var tween: Tween = _scrap_label.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_scrap_label, "offset_transform_scale", Vector2(UiPalette.VALUE_PUNCH_SCALE, UiPalette.VALUE_PUNCH_SCALE), UiPalette.VALUE_PUNCH * 0.4)
	tween.tween_property(_scrap_label, "offset_transform_scale", Vector2.ONE, UiPalette.VALUE_PUNCH * 0.6)
	_scrap_punch_tween = tween


func _refresh_kills() -> void:
	_kills_label.text = str(int(CombatStats.get_run_counter("kills")))


func _refresh_xp() -> void:
	_xp_bar.set_value(economy_state.xp_current, economy_state.xp_required_for_next_level)
	_level_label.text = "%d" % displayed_level(economy_state.level)
	if _last_level >= 0 and economy_state.level > _last_level:
		_level_emblem.trigger_burst()
	_last_level = economy_state.level


## UX review item 6 (D133): runs start at internal level 0; the player is shown "Lv 1".
static func displayed_level(internal_level: int) -> int:
	return internal_level + 1


func _refresh_build_bar() -> void:
	var manager: Node = get_tree().get_first_node_in_group("ability_manager") if is_inside_tree() else null
	_fill_slots(_player_slots, manager, "player")
	_fill_slots(_tower_slots, manager, "tower")


func _fill_slots(slots: Array[HudAbilitySlot], manager: Node, slot_kind: String) -> void:
	var owned: Array = []
	if manager != null and manager.has_method("get_owned_abilities"):
		owned = manager.get_owned_abilities(slot_kind)
	for i: int in slots.size():
		if i < owned.size():
			var entry: Dictionary = owned[i]
			slots[i].set_ability(str(entry.get("id", "")), int(entry.get("level", 1)))
		else:
			slots[i].set_ability("", 0)


# --- Events ----------------------------------------------------------------------

func _connect_events() -> void:
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.siege_warning.connect(_on_siege_warning)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_health_changed.connect(_on_boss_health_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.ability_leveled.connect(_on_ability_leveled)
	EventBus.tower_repaired.connect(_on_tower_repaired)


func _disconnect_events() -> void:
	if not is_instance_valid(EventBus):
		return
	for pair: Array in [
		[EventBus.wave_started, _on_wave_started], [EventBus.siege_warning, _on_siege_warning],
		[EventBus.boss_spawned, _on_boss_spawned], [EventBus.boss_health_changed, _on_boss_health_changed],
		[EventBus.boss_defeated, _on_boss_defeated], [EventBus.ability_leveled, _on_ability_leveled],
		[EventBus.tower_repaired, _on_tower_repaired],
	]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _on_wave_started(wave_number: int, wave_count: int, wave_type: String, is_boss: bool, _timestamp: float) -> void:
	_event_wave_number = wave_number
	_event_wave_count = wave_count
	_event_wave_type = wave_type
	_event_is_boss = is_boss


## The warning seconds pulse the Tower bar (docs/31 §5.4).
func _on_siege_warning(seconds: float, _timestamp: float) -> void:
	_siege_remaining = maxf(_siege_remaining, seconds)


func _on_boss_spawned(boss: Node2D, boss_id: String, display_name: String, max_health: float, _timestamp: float) -> void:
	_boss_id = boss_id
	_boss_name_label.text = display_name.to_upper()
	_boss_bar.marker_fraction = boss_phase_fraction(boss)
	_boss_bar.set_value(max_health, max_health)
	_boss_bar.set_text("")
	_boss_box.modulate.a = 1.0
	_boss_box.visible = true


## The boss's own phase threshold (BossBehavior.phase_two_fraction, set by the
## Warchief and King scripts from the Register), read off the spawned node so a
## retuned boss moves its mark with it. -1 (no mark) when the node has none.
static func boss_phase_fraction(boss: Object) -> float:
	if boss == null or not is_instance_valid(boss):
		return -1.0
	var behavior: Variant = boss.get("behavior")
	if behavior is Object and (behavior as Object).get("phase_two_fraction") != null:
		return float((behavior as Object).get("phase_two_fraction"))
	return -1.0


func _on_boss_health_changed(boss_id: String, current_health: float, max_health: float, _timestamp: float) -> void:
	if boss_id != _boss_id and _boss_box.visible:
		return
	_boss_bar.set_value(current_health, maxf(max_health, 1.0))


func _on_boss_defeated(boss_id: String, _position: Vector2, _timestamp: float) -> void:
	if boss_id != _boss_id:
		return
	_boss_bar.set_value(0.0, maxf(_boss_bar.get_max_value(), 1.0))
	if not is_inside_tree():
		_boss_box.visible = false
		return
	var tween: Tween = _boss_box.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(0.4)
	tween.tween_property(_boss_box, "modulate:a", 0.0, BOSS_FADE_SECONDS)
	tween.tween_callback(func() -> void: _boss_box.visible = false)


func _on_ability_leveled(ability_id: String, _level: int, slot_kind: String, _timestamp: float) -> void:
	if GameSettings.is_reduce_flashing():
		return
	_refresh_build_bar()
	var slots: Array[HudAbilitySlot] = _player_slots if slot_kind == "player" else _tower_slots
	for slot: HudAbilitySlot in slots:
		if slot.ability_id == ability_id and slot.is_inside_tree():
			slot.offset_transform_scale = Vector2.ONE
			var tween: Tween = slot.create_tween()
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(slot, "offset_transform_scale", Vector2(1.18, 1.18), 0.08)
			tween.tween_property(slot, "offset_transform_scale", Vector2.ONE, 0.16)
			return


func _on_tower_repaired(_restored: float, _scrap_spent: int, _timestamp: float) -> void:
	_repair_hold = REPAIR_TAG_HOLD_SECONDS


## During the warning the Tower pill is tinted danger-red; it pulses unless
## Reduce flashing is on, which holds a steady tint.
func _update_siege_pulse() -> void:
	if _siege_remaining <= 0.0:
		_tower_pill.self_modulate = Color.WHITE
		return
	var strength: float = 0.55 if GameSettings.is_reduce_flashing() else 0.3 + 0.35 * (0.5 + 0.5 * sin(SimClock.now * TAU * SIEGE_PULSE_HZ))
	_tower_pill.self_modulate = Color.WHITE.lerp(UiPalette.DANGER, strength)


# --- Assembly --------------------------------------------------------------------

func _build_run_announcer() -> void:
	_announcer = RunAnnouncer.new()
	_announcer.name = "RunAnnouncer"
	_frame.add_child(_announcer)
	var parent: Node = get_parent()
	if parent != null:
		_announcer.bind_wave_director(parent.get_node_or_null("Main/WaveDirector"))
	if _announcer.get_hints_for_test() != null:
		_announcer.get_hints_for_test().scrap_source = func() -> int: return economy_state.scrap_current


func _build_ui() -> void:
	UiStrings.ensure_registered()
	_scale_root = Control.new()
	_scale_root.name = "ScaleRoot"
	_scale_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scale_root)

	_frame = Control.new()
	_frame.name = "Root"
	_frame.theme = UiTheme.get_theme()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scale_root.add_child(_frame)

	_build_player_cluster()
	_build_tower_cluster()
	_build_scrap_cluster()
	_build_build_bar()
	_build_action_cluster()


## Pins `control` to a screen corner or edge: `h` -1 left / 0 centre / 1 right,
## `v` 0 top / 1 bottom. Anchors plus grow direction, so the cluster keeps its
## edge as its content changes size (a layout preset alone does not set growth).
func _anchor(control: Control, h: int, v: int) -> void:
	_frame.add_child(control)
	var margin: float = float(UiPalette.SCREEN_MARGIN)
	control.anchor_left = float(h + 1) * 0.5
	control.anchor_right = control.anchor_left
	control.anchor_top = float(v)
	control.anchor_bottom = control.anchor_top
	control.offset_left = -margin * float(h)
	control.offset_right = control.offset_left
	control.offset_top = margin if v == 0 else -margin
	control.offset_bottom = control.offset_top
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN if h > 0 else (Control.GROW_DIRECTION_END if h < 0 else Control.GROW_DIRECTION_BOTH)
	control.grow_vertical = Control.GROW_DIRECTION_END if v == 0 else Control.GROW_DIRECTION_BEGIN


func _make_pill(node_name: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = node_name
	pill.theme_type_variation = UiTheme.PILL
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill


func _make_value_label(node_name: String, min_width: float) -> Label:
	var label := Label.new()
	label.name = node_name
	label.theme_type_variation = UiTheme.HUD_VALUE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(min_width, 0)
	return label


func _build_player_cluster() -> void:
	var pill := _make_pill("PlayerHealthPill")
	pill.name = "PlayerHealthField"
	_player_field = pill
	_anchor(pill, -1, 0)

	var row := HBoxContainer.new()
	row.name = "PlayerRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = UiTheme.hbox("M")
	pill.add_child(row)

	_level_emblem = HudLevelEmblem.new()
	_level_emblem.name = "LevelEmblem"
	_level_emblem.custom_minimum_size = Vector2(LEVEL_EMBLEM_SIZE, LEVEL_EMBLEM_SIZE)
	_level_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_emblem)
	_level_label = Label.new()
	_level_label.name = "LevelLabel"
	_level_label.theme_type_variation = UiTheme.HUD_VALUE
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level_emblem.add_child(_level_label)

	var bars := VBoxContainer.new()
	bars.name = "PlayerBars"
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	bars.theme_type_variation = UiTheme.vbox("XS")
	row.add_child(bars)

	_player_health_bar = HudBar.new()
	_player_health_bar.name = "PlayerHealthBar"
	_player_health_bar.enable_health_tick_rule = true
	_player_health_bar.fill_color = UiPalette.PLAYER
	_player_health_bar.custom_minimum_size = PLAYER_BAR_MIN_SIZE
	bars.add_child(_player_health_bar)
	_player_health_bar.set_text("0/0")

	_xp_bar = HudBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.fill_color = UiPalette.XP
	_xp_bar.background_color = UiPalette.with_alpha(UiPalette.SURFACE_HOVER, 0.92) # a visible empty track
	_xp_bar.custom_minimum_size = XP_BAR_MIN_SIZE
	bars.add_child(_xp_bar)


func _build_tower_cluster() -> void:
	var field := VBoxContainer.new()
	field.name = "TowerHealthField"
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.theme_type_variation = UiTheme.vbox("XS")
	_tower_field = field
	_anchor(field, 0, 0)

	_tower_pill = _make_pill("TowerHealthPill")
	field.add_child(_tower_pill)

	var inner := VBoxContainer.new()
	inner.name = "TowerHealthInner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.theme_type_variation = UiTheme.vbox("XS")
	_tower_pill.add_child(inner)

	var bar_row := HBoxContainer.new()
	bar_row.name = "TowerHealthBarRow"
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(bar_row)

	var tower_icon := UiShapeGlyph.new()
	tower_icon.name = "TowerIcon"
	tower_icon.shape = UiShapeGlyph.Shape.TOWER
	tower_icon.glyph_color = UiPalette.TOWER
	tower_icon.set_side(ICON_SIZE)
	tower_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(tower_icon)

	_tower_health_bar = HudBar.new()
	_tower_health_bar.name = "TowerHealthBar"
	_tower_health_bar.enable_health_tick_rule = true
	_tower_health_bar.enable_shield_segment = true
	_tower_health_bar.fill_color = UiPalette.TOWER
	_tower_health_bar.shield_color = UiPalette.SHIELD
	_tower_health_bar.custom_minimum_size = TOWER_BAR_MIN_SIZE
	bar_row.add_child(_tower_health_bar)
	_tower_health_bar.set_text("0/0")

	var info_row := HBoxContainer.new()
	info_row.name = "WaveRow"
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(info_row)

	_wave_label = _make_value_label("WaveLabel", 0.0)
	_wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(_wave_label)

	_repair_tag = _make_value_label("RepairTag", 0.0)
	_repair_tag.text = tr("HUD_REPAIRING")
	_repair_tag.add_theme_color_override("font_color", UiPalette.SUCCESS)
	_repair_tag.add_theme_constant_override("outline_size", UiPalette.OUTLINE_DISPLAY)
	_repair_tag.visible = false
	info_row.add_child(_repair_tag)

	_timer_label = _make_value_label("TimerLabel", TIMER_MIN_WIDTH)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_row.add_child(_timer_label)

	_wave_progress_bar = HudBar.new()
	_wave_progress_bar.name = "WaveProgressBar"
	_wave_progress_bar.fill_color = UiPalette.ACCENT
	_wave_progress_bar.custom_minimum_size = WAVE_PROGRESS_MIN_SIZE
	_wave_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_wave_progress_bar)

	_boss_box = VBoxContainer.new()
	_boss_box.name = "BossBox"
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.theme_type_variation = UiTheme.vbox("XS")
	_boss_box.visible = false
	field.add_child(_boss_box)

	_boss_name_label = _make_value_label("BossNameLabel", 0.0)
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_constant_override("outline_size", UiPalette.OUTLINE_DISPLAY)
	_boss_box.add_child(_boss_name_label)

	_boss_bar = HudBar.new()
	_boss_bar.name = "BossBar"
	_boss_bar.fill_color = UiPalette.DANGER
	_boss_bar.low_fill_color = UiPalette.DANGER
	_boss_bar.custom_minimum_size = BOSS_BAR_MIN_SIZE
	_boss_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_box.add_child(_boss_bar)


func _build_scrap_cluster() -> void:
	var pill := _make_pill("ScrapPill")
	pill.name = "ScrapField"
	# PASS: the Scrap value keeps its hover tooltip (full value when truncated).
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	_scrap_field = pill
	_anchor(pill, 1, 0)

	var column := VBoxContainer.new()
	column.name = "ScrapColumn"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.theme_type_variation = UiTheme.vbox("XS")
	pill.add_child(column)

	var scrap_row := HBoxContainer.new()
	scrap_row.name = "ScrapRow"
	scrap_row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scrap_row)

	_scrap_icon = TextureRect.new()
	_scrap_icon.name = "ScrapIcon"
	var atlas := AtlasTexture.new()
	atlas.atlas = load(UiPalette.TEX_SCRAP_ICON)
	atlas.region = Rect2(47, 50, 45, 47) # the pouch's own alpha bounds
	_scrap_icon.texture = atlas
	_scrap_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_scrap_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrap_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scrap_icon.custom_minimum_size = Vector2(45, 47)
	_scrap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrap_row.add_child(_scrap_icon)

	_scrap_label = HudTruncatableLabel.new()
	_scrap_label.name = "ScrapValueLabel"
	_scrap_label.theme_type_variation = UiTheme.HUD_VALUE
	_scrap_label.custom_minimum_size = Vector2(SCRAP_VALUE_MIN_WIDTH, 0)
	_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.offset_transform_enabled = true
	_scrap_label.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	scrap_row.add_child(_scrap_label)

	_full_badge = _make_value_label("FullBadgeLabel", 0.0)
	_full_badge.add_theme_color_override("font_color", UiPalette.GOLD)
	_full_badge.visible = false
	scrap_row.add_child(_full_badge)

	_hopper_label = _make_value_label("HopperLabel", 0.0)
	_hopper_label.visible = false
	scrap_row.add_child(_hopper_label)

	var kills_row := HBoxContainer.new()
	kills_row.name = "KillsRow"
	kills_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(kills_row)

	var skull := HudKillsGlyph.new()
	skull.name = "KillsIcon"
	skull.custom_minimum_size = Vector2(45, 40)
	kills_row.add_child(skull)

	_kills_label = _make_value_label("KillsLabel", KILLS_VALUE_MIN_WIDTH)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_row.add_child(_kills_label)


func _build_build_bar() -> void:
	_build_bar = HBoxContainer.new()
	_build_bar.name = "BuildBar"
	_build_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_build_bar, -1, 1)

	for i: int in AbilityIds.MAX_PLAYER_ABILITIES:
		var slot := HudAbilitySlot.new()
		slot.name = "PlayerSlot%d" % (i + 1)
		slot.slot_owner = HudAbilitySlot.Owner.PLAYER
		slot.offset_transform_enabled = true
		slot.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		_build_bar.add_child(slot)
		_player_slots.append(slot)

	var divider := ColorRect.new()
	divider.name = "SlotDivider"
	divider.color = UiPalette.with_alpha(UiPalette.LINE_STRONG, 0.9)
	divider.custom_minimum_size = Vector2(SLOT_DIVIDER_WIDTH, HudAbilitySlot.SLOT_SIZE_PX)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_bar.add_child(divider)

	for i: int in AbilityIds.MAX_TOWER_ABILITIES:
		var slot := HudAbilitySlot.new()
		slot.name = "TowerSlot%d" % (i + 1)
		slot.slot_owner = HudAbilitySlot.Owner.TOWER
		slot.offset_transform_enabled = true
		slot.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
		_build_bar.add_child(slot)
		_tower_slots.append(slot)


func _build_action_cluster() -> void:
	_action_cluster = HBoxContainer.new()
	_action_cluster.name = "ActionCluster"
	_action_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_cluster.alignment = BoxContainer.ALIGNMENT_END
	_action_cluster.theme_type_variation = UiTheme.hbox("M")
	_anchor(_action_cluster, 1, 1)

	_dash_button = HudActionButton.new(HudActionButton.Kind.DASH)
	_dash_button.name = "DashButton"
	_dash_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_action_cluster.add_child(_dash_button)

	_skill_button = HudActionButton.new(HudActionButton.Kind.SKILL)
	_skill_button.name = "SkillButton"
	_skill_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_action_cluster.add_child(_skill_button)

extends Control
class_name RunAnnouncer

## RunAnnouncer (UX review items 4 and 9; Review Decision Log D129/D130).
## Non-pausing, non-interactive text in the run HUD:
##   - a centred wave banner at every wave start ("WAVE 6 - SIEGE"), from
##     `EventBus.wave_started` only: exactly one banner per wave number (review
##     fix, D240: the legacy `wave_opened` banner is gone; it double-fired at
##     wave 1 whichever signal came first);
##   - a red "SIEGE INCOMING" line on `siege_warning`, the boss's name on
##     `boss_spawned` and a short callout on `elite_spawned`;
##   - a one-line objective at run start and the contextual teaching hints, both
##     through `RunHints` (one at a time, each hint once per profile).
## It never writes gameplay state. Timings are Provisional Values Register >
## "HUD" > "Run announcements" and > "v1.0 Interface" > "Contextual hints".

const BANNER_SECONDS: float = 1.6
const OBJECTIVE_SECONDS: float = 5.0
const FADE_SECONDS: float = 0.3
## D145 (Register "Run announcement band" row): screen px at the 1920x1080 canvas.
const BANNER_TOP_PX: float = 236.0 ## v1.0: below the taller Tower cluster and the boss bar
const TOAST_BOTTOM_PX: float = 190.0 ## v1.0: toasts sit at the bottom centre, above the build bar and the action cluster
const BOSS_BANNER_SECONDS: float = 2.0
const ELITE_CALLOUT_SECONDS: float = 1.4
const ELITE_CALLOUT_MIN_GAP_MSEC: int = 2500

var _banner_box: VBoxContainer
var _toast_box: VBoxContainer
var _director: Node = null
var _hints: RunHints = null
var _first_wave_seen: bool = false
var _last_banner_wave: int = -1
var _last_elite_msec: int = -100000


func _ready() -> void:
	UiStrings.ensure_registered()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_PAUSABLE # hints/banner run on pausable time (D140)

	_banner_box = VBoxContainer.new()
	_banner_box.name = "BannerBox"
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_banner_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_box.offset_top = BANNER_TOP_PX # below the HUD top row and the Wave ribbon, above the Tower
	add_child(_banner_box)

	_toast_box = VBoxContainer.new()
	_toast_box.name = "ToastBox"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast_box.offset_top = -(TOAST_BOTTOM_PX + 300.0)
	_toast_box.offset_bottom = -TOAST_BOTTOM_PX
	add_child(_toast_box)

	_hints = RunHints.new()
	_hints.name = "RunHints"
	_hints.show_callback = show_toast
	add_child(_hints)

	EventBus.wave_started.connect(_on_wave_started)
	EventBus.siege_warning.connect(_on_siege_warning)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.elite_spawned.connect(_on_elite_spawned)


func _exit_tree() -> void:
	for pair: Array in [[EventBus.wave_started, _on_wave_started], [EventBus.siege_warning, _on_siege_warning], [EventBus.boss_spawned, _on_boss_spawned], [EventBus.elite_spawned, _on_elite_spawned]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _notification(what: int) -> void:
	# Toasts and banners are hidden behind the Draft / pause menu rather than shown frozen.
	if what == NOTIFICATION_PAUSED:
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true


## Kept for the HUD's wiring and tests; the director is no longer a banner source
## (the banner follows `EventBus.wave_started`, which the director always emits).
func bind_wave_director(director: Node) -> void:
	_director = director


## "WAVE n - TYPE" from the EventBus; exactly one banner per wave number.
func _on_wave_started(wave_number: int, wave_count: int, wave_type: String, is_boss: bool, _timestamp: float) -> void:
	if wave_number == _last_banner_wave:
		return
	show_wave_banner(wave_number, wave_type, is_boss)
	Sfx.play_ui("wave_horn")
	_first_wave_objective(wave_number == 1, wave_count)


func show_wave_banner(wave_number: int, wave_type: String = "", is_boss: bool = false) -> void:
	_last_banner_wave = wave_number
	var type_key: String = String(Hud.WAVE_TYPE_KEYS.get("boss" if is_boss else wave_type.to_lower(), ""))
	var text: String = (tr("BANNER_WAVE_TYPED") % [wave_number, tr(type_key)]) if type_key != "" else (tr("BANNER_WAVE") % wave_number)
	_add_transient(_make_panel(text, UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER if is_boss else Color(0, 0, 0, 0)), _banner_box, BANNER_SECONDS)


func _first_wave_objective(is_first_wave: bool, total: int) -> void:
	if not is_first_wave or _first_wave_seen:
		return
	_first_wave_seen = true
	_hints.request_line(tr("HINT_OBJECTIVE") % total if total > 0 else tr("HINT_OBJECTIVE_NO_COUNT"))
	_hints.on_run_started()


func _on_siege_warning(_seconds: float, _timestamp: float) -> void:
	_add_transient(_make_panel(tr("BANNER_SIEGE_WARNING"), UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER), _banner_box, BANNER_SECONDS)
	Sfx.play_ui("siege_warning")


func _on_boss_spawned(_boss: Node2D, _boss_id: String, display_name: String, _max_health: float, _timestamp: float) -> void:
	_add_transient(_make_panel(display_name.to_upper(), UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER), _banner_box, BOSS_BANNER_SECONDS)
	Sfx.play_ui("boss_roar")


func _on_elite_spawned(_entity: Node2D, affix: String, _timestamp: float) -> void:
	if _hints.wants(RunHints.ID_ELITE) or _hints.is_showing():
		return # the first elite gets the teaching hint instead of a stacked callout
	var now: int = Time.get_ticks_msec()
	if now - _last_elite_msec < ELITE_CALLOUT_MIN_GAP_MSEC:
		return # a burst of elites gets one callout, not a stack
	_last_elite_msec = now
	var affix_text: String = tr("ELITE_AFFIX_" + affix.to_upper())
	_add_transient(_make_panel(tr("ELITE_CALLOUT") % affix_text, UiTheme.HUD_VALUE, UiTheme.PILL, UiPalette.GOLD), _toast_box, ELITE_CALLOUT_SECONDS)


func show_toast(text: String, seconds: float) -> void:
	_add_transient(_make_panel(text, &"", UiTheme.PILL, Color(0, 0, 0, 0), 1100.0), _toast_box, seconds)


func _make_panel(text: String, label_variation: StringName, panel_variation: StringName, tint: Color = Color(0, 0, 0, 0), min_width: float = 0.0) -> Control:
	var wrap := CenterContainer.new() # keeps the panel at its own width, centred
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.theme_type_variation = panel_variation
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(panel)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = label_variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0.0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if tint.a > 0.0:
		label.add_theme_color_override("font_color", tint)
	panel.add_child(label)
	return wrap


func _add_transient(node: Control, parent: Control, seconds: float) -> void:
	node.modulate.a = 0.0
	parent.add_child(node)
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(maxf(0.0, seconds - FADE_SECONDS * 2.0))
	tween.tween_property(node, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(node.queue_free)


func get_banner_box_for_test() -> Control:
	return _banner_box


func get_toast_box_for_test() -> Control:
	return _toast_box


func get_hints_for_test() -> RunHints:
	return _hints


func get_last_banner_wave_for_test() -> int:
	return _last_banner_wave

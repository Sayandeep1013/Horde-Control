extends Control
class_name RunAnnouncer

## RunAnnouncer (UX review items 4 and 9; Review Decision Log D129/D130).
## Non-pausing, non-interactive text in the run HUD:
##   - a centred wave banner at every wave start ("Wave N"), plus
##     "Siege incoming" when the wave contains a Siege encounter (docs/11 >
##     "Siege warning": the first Seeker spawns 3 s after open, so the
##     warning is the banner itself);
##   - a one-line objective at run start;
##   - three first-run hint toasts during wave 1, shown only until seen (the
##     flag lives in MetaProgress: `first_run_hints_seen`).
## Reads the Wave Director's `wave_opened` signal; it never writes gameplay
## state. Timings are Provisional Values Register > "HUD" > "Run announcements".
##
## v1.0 (docs/31 section 5.3-5.4): the banner now reads "WAVE 6 · SIEGE" /
## "WAVE 8 · BOSS" from `EventBus.wave_started` and plays the wave horn; a
## `siege_warning` adds a red "SIEGE INCOMING" line; `boss_spawned` shows the
## boss's name for 2 s with the roar; `elite_spawned` shows a short "ELITE -
## SWIFT" callout. The old `wave_opened` path still works for a director that
## does not emit `wave_started`; the two are de-duplicated per wave number.

const BANNER_SECONDS: float = 1.6
const OBJECTIVE_SECONDS: float = 5.0
const HINT_SECONDS: float = 6.0
const HINT_FIRST_DELAY_SECONDS: float = 6.0 ## after wave 1 opens (the objective line is up first)
const HINT_GAP_SECONDS: float = 1.0 ## between one hint fading and the next appearing
const FADE_SECONDS: float = 0.3
## D145 (Register "Run announcement band" row): screen px at the 1920x1080 canvas.
const BANNER_TOP_PX: float = 236.0 ## v1.0: below the taller Tower cluster and the boss bar
const TOAST_BOTTOM_PX: float = 190.0 ## v1.0: toasts sit at the bottom centre, above the build bar and the action cluster
const BOSS_BANNER_SECONDS: float = 2.0
const ELITE_CALLOUT_SECONDS: float = 1.4
const ELITE_CALLOUT_MIN_GAP_MSEC: int = 2500
const DEDUPE_WINDOW_MSEC: int = 500

const HINT_KEYS: Array[String] = ["HINT_AUTOFIRE", "HINT_PICKUPS", "HINT_ENEMIES"]

var _banner_box: VBoxContainer
var _toast_box: VBoxContainer
var _director: Node = null
var _hint_index: int = 0
var _hints_running: bool = false
var _first_wave_seen: bool = false
var _hint_timer: SceneTreeTimer = null
var _last_banner_wave: int = -1
var _last_banner_msec: int = -100000
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


## Typed command. Production wiring finds the director beside the HUD (see
## Hud._bind_run_announcer()); tests pass a stand-in with the same signal.
func bind_wave_director(director: Node) -> void:
	if director == null or not director.has_signal(&"wave_opened"):
		return
	_director = director
	director.wave_opened.connect(_on_wave_opened)


func _on_wave_opened(_wave_id: String, wave_index: int) -> void:
	var total: int = 0
	var is_siege: bool = false
	if _director != null:
		if _director.has_method(&"get_wave_total_count"):
			total = int(_director.get_wave_total_count())
		if _director.has_method(&"is_current_wave_siege"):
			is_siege = bool(_director.is_current_wave_siege())
	if not _already_bannered(wave_index + 1):
		show_wave_banner(wave_index + 1, is_siege)
	_first_wave_objective(wave_index == 0, total)


## v1.0 path: "WAVE n · TYPE" from the EventBus.
func _on_wave_started(wave_number: int, wave_count: int, wave_type: String, is_boss: bool, _timestamp: float) -> void:
	if _already_bannered(wave_number):
		_clear_banners() # wave_opened got there first with the plain banner; replace it
	_last_banner_wave = wave_number
	_last_banner_msec = Time.get_ticks_msec()
	var type_key: String = String(Hud.WAVE_TYPE_KEYS.get("boss" if is_boss else wave_type.to_lower(), ""))
	var text: String = (tr("BANNER_WAVE_TYPED") % [wave_number, tr(type_key)]) if type_key != "" else (tr("BANNER_WAVE") % wave_number)
	_add_transient(_make_panel(text, UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER if is_boss else Color(0, 0, 0, 0)), _banner_box, BANNER_SECONDS)
	Sfx.play_ui("wave_horn")
	_first_wave_objective(wave_number == 1, wave_count)


func _already_bannered(wave_number: int) -> bool:
	return _last_banner_wave == wave_number and Time.get_ticks_msec() - _last_banner_msec < DEDUPE_WINDOW_MSEC


func _clear_banners() -> void:
	for child: Node in _banner_box.get_children():
		child.queue_free()
		_banner_box.remove_child(child)


func _first_wave_objective(is_first_wave: bool, total: int) -> void:
	if not is_first_wave or _first_wave_seen:
		return
	_first_wave_seen = true
	show_toast(tr("HINT_OBJECTIVE") % total if total > 0 else tr("HINT_OBJECTIVE_NO_COUNT"), OBJECTIVE_SECONDS)
	if not MetaProgress.is_first_run_hints_seen():
		_hints_running = true
		_hint_index = 0
		_hint_timer = get_tree().create_timer(HINT_FIRST_DELAY_SECONDS, false)
		_hint_timer.timeout.connect(_show_next_hint)


func _on_siege_warning(_seconds: float, _timestamp: float) -> void:
	_add_transient(_make_panel(tr("BANNER_SIEGE_WARNING"), UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER), _banner_box, BANNER_SECONDS)
	Sfx.play_ui("siege_warning")


func _on_boss_spawned(_boss: Node2D, _boss_id: String, display_name: String, _max_health: float, _timestamp: float) -> void:
	_add_transient(_make_panel(display_name.to_upper(), UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER), _banner_box, BOSS_BANNER_SECONDS)
	Sfx.play_ui("boss_roar")


func _on_elite_spawned(_entity: Node2D, affix: String, _timestamp: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_elite_msec < ELITE_CALLOUT_MIN_GAP_MSEC:
		return # a burst of elites gets one callout, not a stack
	_last_elite_msec = now
	var affix_text: String = tr("ELITE_AFFIX_" + affix.to_upper())
	_add_transient(_make_panel(tr("ELITE_CALLOUT") % affix_text, UiTheme.HUD_VALUE, UiTheme.PILL, UiPalette.GOLD), _toast_box, ELITE_CALLOUT_SECONDS)


func show_wave_banner(wave_number: int, is_siege: bool) -> void:
	_add_transient(_make_panel(tr("BANNER_WAVE") % wave_number, UiTheme.HEADING, UiTheme.RIBBON), _banner_box, BANNER_SECONDS)
	if is_siege:
		_add_transient(_make_panel(tr("BANNER_SIEGE"), UiTheme.HEADING, UiTheme.RIBBON, UiPalette.DANGER), _banner_box, BANNER_SECONDS)


func show_toast(text: String, seconds: float) -> void:
	_add_transient(_make_panel(text, &"", UiTheme.PILL, Color(0, 0, 0, 0), 1100.0), _toast_box, seconds)


func _show_next_hint() -> void:
	if not _hints_running or _hint_index >= HINT_KEYS.size() or not is_inside_tree():
		return
	show_toast(tr(HINT_KEYS[_hint_index]), HINT_SECONDS)
	_hint_index += 1
	if _hint_index >= HINT_KEYS.size():
		_hints_running = false
		MetaProgress.mark_first_run_hints_seen() # seen only once the whole set was shown
	else:
		_hint_timer = get_tree().create_timer(HINT_SECONDS + HINT_GAP_SECONDS, false)
		_hint_timer.timeout.connect(_show_next_hint)


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


func is_hint_sequence_running_for_test() -> bool:
	return _hints_running


func get_hint_time_left_for_test() -> float:
	return _hint_timer.time_left if _hint_timer != null else -1.0

extends CanvasLayer
class_name SettingsMenu

## Settings Menu. MASTER_SDLC.md > Provisional Values Register > "Interfaces" >
## "Settings" and > "v1.0 Interface" > "Settings tabs"; Review Decision Log
## D121 (vertical row list) and the v1.0 tab decision; docs/19_UI_UX.md >
## "Settings". Reachable from the pause menu, the run-end screens (via
## `RunFlowController`), the title screen and the Hub (War Camp); each of the
## latter two instantiates its own `SettingsMenu` and reacts to `closed`. Every
## instance reads and writes the same `GameSettings` static state.
##
## ## Tabs (docs/31 section 8.4)
## Audio / Video / Gameplay / Controls / Accessibility. Only the active tab's
## rows are shown; "Reset to Defaults" and "Back" sit under every tab. All rows
## exist for the life of the menu; `_row_order` lists the ones currently shown
## (the active tab plus the footer), and every highlight index is into it.
## Q / E (or LB / RB, or a click) switches tab. The tab strip is a convenience
## on top of the movement-only contract, not part of it: a player who never
## touches a tab key still reaches Audio, and leaves with the Back hold.
##
## ## Input shape (the docs/19 movement-only contract, unchanged)
## - Up/Down (`move_up`/`move_down`) move the highlighted row, 0.3 s press-then-
##   repeat (the Register's Draft cadence, reused).
## - Left/Right (`move_left`/`move_right`) change the highlighted row's value,
##   applied and saved at once; only the slider-like rows (volumes, Screen
##   Shake, HUD Scale) repeat while held, toggles and cycles change once per
##   press.
## - Back and Reset to Defaults are confirmed by holding Left or Right for
##   `HOLD_CONFIRM_SECONDS`, or by the `confirm` press / a click. Reset asks
##   twice on a press ("Press again") and not at all on the hold, which is
##   already a deliberate gesture. The neutral-return arming rule applies (a
##   direction already held cannot auto-confirm).
## - A Controls row is rebound with `confirm` (or a click): the next key press
##   becomes the binding, Esc cancels. Left/Right on a binding row picks which
##   of its two key slots the rebind targets.
## - Opens with the 0.4 s input lockout (Register "Draft input"), always on the
##   first tab and row, with held keys seeded so they do not read as presses.
##
## `GameSettings.load_from_disk()` is deliberately not called here (see
## game_settings.gd: only the title screen loads at boot).

signal closed()

## Above src/ui/hud.gd (10), threat_feedback.gd (11) and pause_menu.gd (18):
## this screen opens on top of those, or of the title/Hub. Not a Register number.
const SETTINGS_MENU_CANVAS_LAYER: int = 21

# --- Row ids -------------------------------------------------------------------
const ROW_MASTER_VOLUME: String = "master_volume"
const ROW_MUSIC_VOLUME: String = "music_volume"
const ROW_EFFECTS_VOLUME: String = "effects_volume"
const ROW_INTERFACE_VOLUME: String = "interface_volume"
const ROW_MUTE_ALL: String = "mute_all"
const ROW_DISPLAY_MODE: String = "display_mode"
const ROW_WINDOW_SIZE: String = "window_size"
const ROW_VSYNC: String = "vsync"
const ROW_FPS_LIMIT: String = "fps_limit"
const ROW_SHOW_FPS: String = "show_fps"
const ROW_AUTO_CAST: String = "auto_cast"
const ROW_DAMAGE_NUMBERS: String = "damage_numbers"
const ROW_SCREEN_SHAKE: String = "screen_shake"
const ROW_SHOW_OVERHEAD_BARS: String = "show_overhead_bars"
const ROW_PAUSE_UNFOCUSED: String = "pause_unfocused"
const ROW_MOVEMENT_ONLY: String = "movement_only"
const ROW_FIRST_TIME_TIPS: String = "first_time_tips" # PT-UI (docs/33 A4)
const ROW_BIND_PREFIX: String = "bind_"
const ROW_RESET_CONTROLS: String = "reset_controls"
const ROW_HUD_SCALE: String = "hud_scale"
const ROW_REDUCE_FLASHING: String = "reduce_flashing"
const ROW_ENEMY_OUTLINES: String = "enemy_outlines"
const ROW_RESET_DEFAULTS: String = "reset_defaults"
const ROW_BACK: String = "back"

enum Tab { AUDIO, VIDEO, GAMEPLAY, CONTROLS, ACCESSIBILITY }
const TAB_KEYS: Array[String] = ["SETTINGS_TAB_AUDIO", "SETTINGS_TAB_VIDEO", "SETTINGS_TAB_GAMEPLAY", "SETTINGS_TAB_CONTROLS", "SETTINGS_TAB_ACCESSIBILITY"]

const TAB_ROWS: Array = [
	[ROW_MASTER_VOLUME, ROW_MUSIC_VOLUME, ROW_EFFECTS_VOLUME, ROW_INTERFACE_VOLUME, ROW_MUTE_ALL],
	[ROW_DISPLAY_MODE, ROW_WINDOW_SIZE, ROW_VSYNC, ROW_FPS_LIMIT, ROW_SHOW_FPS],
	[ROW_AUTO_CAST, ROW_DAMAGE_NUMBERS, ROW_SCREEN_SHAKE, ROW_SHOW_OVERHEAD_BARS, ROW_PAUSE_UNFOCUSED, ROW_MOVEMENT_ONLY, ROW_FIRST_TIME_TIPS],
	["bind_move_up", "bind_move_down", "bind_move_left", "bind_move_right", "bind_dash", "bind_battle_skill", "bind_pause", ROW_RESET_CONTROLS],
	[ROW_HUD_SCALE, ROW_REDUCE_FLASHING, ROW_ENEMY_OUTLINES],
]
const FOOTER_ROWS: Array[String] = [ROW_RESET_DEFAULTS, ROW_BACK]

## Every row, in tab order then footer.
const ROW_ORDER: Array[String] = [
	ROW_MASTER_VOLUME, ROW_MUSIC_VOLUME, ROW_EFFECTS_VOLUME, ROW_INTERFACE_VOLUME, ROW_MUTE_ALL,
	ROW_DISPLAY_MODE, ROW_WINDOW_SIZE, ROW_VSYNC, ROW_FPS_LIMIT, ROW_SHOW_FPS,
	ROW_AUTO_CAST, ROW_DAMAGE_NUMBERS, ROW_SCREEN_SHAKE, ROW_SHOW_OVERHEAD_BARS, ROW_PAUSE_UNFOCUSED, ROW_MOVEMENT_ONLY, ROW_FIRST_TIME_TIPS,
	"bind_move_up", "bind_move_down", "bind_move_left", "bind_move_right", "bind_dash", "bind_battle_skill", "bind_pause", ROW_RESET_CONTROLS,
	ROW_HUD_SCALE, ROW_REDUCE_FLASHING, ROW_ENEMY_OUTLINES,
	ROW_RESET_DEFAULTS, ROW_BACK,
]

## The rebindable actions' row ids, in display order.
const BIND_ACTIONS: Array[StringName] = [&"move_up", &"move_down", &"move_left", &"move_right", &"dash", &"battle_skill", &"pause"]

## Reused from src/run/paused_choice_bar.gd (the Register's one hold-to-confirm
## timing, Draft input row).
const CYCLE_REPEAT_SECONDS: float = 0.3
const HOLD_CONFIRM_SECONDS: float = 1.0
## MASTER_SDLC.md line 242 / Author decision D3: "every paused menu" opens with this lockout.
const OPEN_LOCKOUT_SECONDS: float = 0.4
## Register > v1.0 Interface > "Settings tabs": "Press again" lasts this long.
const RESET_CONFIRM_SECONDS: float = 3.0
## Frames after a rebind during which `confirm` is ignored (the bound key may be a confirm key).
const POST_CAPTURE_IGNORE_FRAMES: int = 3
const CARD_MIN_WIDTH_PX: float = 980.0

## Rows whose value keeps changing while held; every other row changes once per press.
const REPEATING_ROWS: Array[String] = [ROW_MASTER_VOLUME, ROW_MUSIC_VOLUME, ROW_EFFECTS_VOLUME, ROW_INTERFACE_VOLUME, ROW_SCREEN_SHAKE, ROW_HUD_SCALE]
## D146: rows hidden on a phone (no window, V-Sync or keyboard there).
const DESKTOP_ONLY_ROWS: Array[String] = [ROW_DISPLAY_MODE, ROW_WINDOW_SIZE, ROW_VSYNC]

var _root: Control
var _frame: MenuFrame.Parts
var _fill_ring: DraftFillRing
var _tab_strip: HBoxContainer
var _tab_panels: Array[VBoxContainer] = []
var _tab_labels: Array[Label] = []
var _scroll: ScrollContainer
var _row_list: VBoxContainer
var _footer_list: BoxContainer
var _hint_label: Label

## Tabs shown (the Controls tab is keyboard-only, so a phone has four).
var _tabs: Array[int] = []
var _tab: int = Tab.AUDIO
## The rows currently shown, in order (active tab + footer). Highlight indices are into this.
var _row_order: Array[String] = []
var _rows: Dictionary = {} # String id -> SettingsRow

var _active: bool = false
var _highlighted_index: int = 0
var _lockout_remaining: float = 0.0

var _up_held: bool = false
var _up_repeat_timer: float = 0.0
var _down_held: bool = false
var _down_repeat_timer: float = 0.0
var _left_held: bool = false
var _left_repeat_timer: float = 0.0
var _right_held: bool = false
var _right_repeat_timer: float = 0.0

var _hold_armed: bool = false
var _hold_progress: float = 0.0

var _reset_pending: bool = false
var _reset_pending_timer: float = 0.0

var _capturing: bool = false
var _capture_action: StringName = &""
var _capture_slot: int = 0
var _slot_cursor: int = 0
var _ignore_confirm_frames: int = 0

var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}


func _ready() -> void:
	layer = SETTINGS_MENU_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_tabs = [Tab.AUDIO, Tab.VIDEO, Tab.GAMEPLAY, Tab.CONTROLS, Tab.ACCESSIBILITY]
	if TouchUi.is_mobile_layout():
		_tabs.erase(Tab.CONTROLS)
	_build_ui()
	_rebuild_row_order()
	_refresh_all_rows()
	_refresh_highlight()
	_refresh_tabs()


## The card's fade/scale-in is cosmetic and runs after these lines, never
## instead of them. Every activation resets to the first tab, first row, and a
## fresh lockout (a stale highlight on Back plus the confirm that opened this
## screen used to close it again the same frame).
func set_active(active: bool) -> void:
	visible = active
	_active = active
	if active:
		_tab = _tabs[0]
		_cancel_capture()
		_clear_reset_pending()
		_rebuild_row_order()
		_highlighted_index = 0
		_lockout_remaining = OPEN_LOCKOUT_SECONDS
		_seed_input_state()
		_refresh_all_rows()
		_refresh_highlight()
		_refresh_tabs()
		MenuFrame.animate_in(_frame)
		_fit_scroll.call_deferred()
	else:
		_cancel_capture()
		MenuFrame.reset_motion(_frame)


func skip_lockout_for_test() -> void:
	_lockout_remaining = 0.0


func get_lockout_remaining_for_test() -> float:
	return _lockout_remaining


func is_active_for_test() -> bool:
	return visible


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func get_highlighted_row_id_for_test() -> String:
	return _row_order[_highlighted_index]


func get_row_for_test(id: String) -> SettingsRow:
	return _rows.get(id) as SettingsRow


func get_visible_row_ids_for_test() -> Array[String]:
	return _row_order.duplicate()


func get_tab_for_test() -> int:
	return _tab


func get_tabs_for_test() -> Array[int]:
	return _tabs.duplicate()


func get_back_hold_progress_for_test() -> float:
	return _hold_progress


func get_fill_ring_for_test() -> DraftFillRing:
	return _fill_ring


func is_capturing_for_test() -> bool:
	return _capturing


func is_reset_pending_for_test() -> bool:
	return _reset_pending


func get_slot_cursor_for_test() -> int:
	return _slot_cursor


func get_scroll_for_test() -> ScrollContainer:
	return _scroll


## Jumps to the tab holding `id` (if it is shown) and highlights the row.
func highlight_row_for_test(id: String) -> void:
	for tab_index: int in TAB_ROWS.size():
		if (TAB_ROWS[tab_index] as Array).has(id) and _tabs.has(tab_index):
			_set_tab(tab_index)
			break
	var idx: int = _row_order.find(id)
	if idx != -1:
		_highlighted_index = idx
		_refresh_highlight()


## Capture harness only (title screen `--settings-tab=N`).
func show_tab_for_debug(tab_index: int) -> void:
	_set_tab(tab_index)


func switch_tab_for_test(direction: int) -> void:
	_switch_tab(direction)


## Feeds a key into the rebind capture the way `_input` would.
func capture_key_for_test(physical_keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	ev.pressed = true
	_handle_capture_event(ev)


static func get_movement_only_controls_enabled() -> bool:
	return GameSettings.get_movement_only_controls_enabled()


## Test seam kept for tests/unit/skill_tree_screen_test.gd (memory-only).
static func set_movement_only_controls_enabled_for_test(enabled: bool) -> void:
	GameSettings.set_movement_only_controls_enabled_for_test(enabled)


# --- test input seams (mirror paused_choice_bar.gd's convention) ---------------

func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true
	_test_pressed[action] = true


func release_action_for_test(action: StringName) -> void:
	_test_pressed[action] = false


func tick_for_test(delta: float) -> void:
	_process(delta)


# --- Build ----------------------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.6, "M")
	_root = _frame.root
	_frame.card.custom_minimum_size = Vector2(CARD_MIN_WIDTH_PX, 0.0)

	MenuFrame.build_title(_frame.column, tr("SETTINGS_MENU_TITLE"), UiTheme.HEADING, 460.0)
	_build_tab_strip()
	MenuFrame.build_separator(_frame.column)

	_scroll = ScrollContainer.new()
	_scroll.name = "RowScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_frame.column.add_child(_scroll)

	_row_list = VBoxContainer.new()
	_row_list.name = "RowList"
	_row_list.theme_type_variation = UiTheme.vbox("XS")
	_row_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_row_list)

	_hint_label = Label.new()
	_hint_label.name = "ControlsHint"
	_hint_label.theme_type_variation = UiTheme.DIM_PARCHMENT
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.text = tr("SETTINGS_REBIND_HINT") + "\n" + tr("SETTINGS_GAMEPAD_NOTE")
	_hint_label.visible = false
	_frame.column.add_child(_hint_label)

	MenuFrame.build_separator(_frame.column) # Review fix (D246): the buttons sit apart from the settings list
	if TouchUi.is_mobile_layout():
		# D370: Reset to Defaults and Back sit side by side on a phone, which gives the setting rows a
		# whole plate more of the 864 px canvas (the last row of a five-row tab no longer scrolls away).
		_footer_list = HBoxContainer.new()
		_footer_list.theme_type_variation = UiTheme.hbox("M")
	else:
		_footer_list = VBoxContainer.new()
		_footer_list.theme_type_variation = UiTheme.vbox("M")
	_footer_list.name = "FooterList"
	_frame.column.add_child(_footer_list)

	for tab_index: int in TAB_ROWS.size():
		for id: String in TAB_ROWS[tab_index]:
			_add_row(_row_list, id, _row_label(id), id != ROW_RESET_CONTROLS)
	_add_footer_button(ROW_RESET_DEFAULTS, tr("SETTINGS_RESET_DEFAULTS"))
	_add_footer_button(ROW_BACK, tr("SETTINGS_BACK"))

	var hold_footer: VBoxContainer = MenuFrame.build_hold_footer(_frame.column)
	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.custom_minimum_size = Vector2(40, 40)
	MenuFrame.style_fill_ring(_fill_ring)
	hold_footer.add_child(_fill_ring)


func _build_tab_strip() -> void:
	_tab_strip = HBoxContainer.new()
	_tab_strip.name = "TabStrip"
	_tab_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_strip.theme_type_variation = UiTheme.hbox("L")
	_frame.column.add_child(_tab_strip)
	# Q / E keycaps flank the strip on a keyboard (switching also works by LB / RB and by a click or tap).
	_tab_strip.add_child(_make_keycap("Q"))
	for tab_index: int in TAB_KEYS.size():
		var tab := VBoxContainer.new()
		tab.name = "Tab_%d" % tab_index
		tab.theme_type_variation = UiTheme.vbox("XS")
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.custom_minimum_size = Vector2(0.0, TouchUi.touch_height(0.0))
		tab.gui_input.connect(_on_tab_gui_input.bind(tab_index))
		var label := Label.new()
		label.theme_type_variation = UiTheme.HUD_VALUE
		label.text = tr(TAB_KEYS[tab_index])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_constant_override("outline_size", 0)
		tab.add_child(label)
		var underline := ColorRect.new()
		underline.name = "Underline"
		underline.custom_minimum_size = Vector2(0.0, 4.0)
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(underline)
		_tab_strip.add_child(tab)
		_tab_panels.append(tab)
		_tab_labels.append(label)
	_tab_strip.add_child(_make_keycap("E"))
	if TouchUi.is_mobile_layout():
		_tab_strip.get_child(0).visible = false
		_tab_strip.get_child(_tab_strip.get_child_count() - 1).visible = false


func _make_keycap(text: String) -> Label:
	var cap := Label.new()
	cap.name = "Keycap" + text
	cap.text = text
	cap.theme_type_variation = UiTheme.DIM_PARCHMENT
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return cap


func _row_label(id: String) -> String:
	if id.begins_with(ROW_BIND_PREFIX):
		return tr("SETTINGS_ACTION_" + id.trim_prefix(ROW_BIND_PREFIX).to_upper())
	match id:
		ROW_MASTER_VOLUME: return tr("SETTINGS_MASTER_VOLUME")
		ROW_MUSIC_VOLUME: return tr("SETTINGS_MUSIC_VOLUME")
		ROW_EFFECTS_VOLUME: return tr("SETTINGS_EFFECTS_VOLUME")
		ROW_INTERFACE_VOLUME: return tr("SETTINGS_INTERFACE_VOLUME")
		ROW_MUTE_ALL: return tr("SETTINGS_MUTE_ALL")
		ROW_DISPLAY_MODE: return tr("SETTINGS_DISPLAY_MODE")
		ROW_WINDOW_SIZE: return tr("SETTINGS_WINDOW_SIZE")
		ROW_VSYNC: return tr("SETTINGS_VSYNC")
		ROW_FPS_LIMIT: return tr("SETTINGS_FPS_LIMIT")
		ROW_SHOW_FPS: return tr("SETTINGS_SHOW_FPS")
		ROW_AUTO_CAST: return tr("SETTINGS_AUTO_CAST")
		ROW_DAMAGE_NUMBERS: return tr("SETTINGS_DAMAGE_NUMBERS")
		ROW_SCREEN_SHAKE: return tr("SETTINGS_SCREEN_SHAKE")
		ROW_SHOW_OVERHEAD_BARS: return tr("SETTINGS_SHOW_OVERHEAD_BARS")
		ROW_PAUSE_UNFOCUSED: return tr("SETTINGS_PAUSE_UNFOCUSED")
		ROW_MOVEMENT_ONLY: return tr("SETTINGS_MOVEMENT_ONLY")
		ROW_FIRST_TIME_TIPS: return tr("SETTINGS_FIRST_TIME_TIPS")
		ROW_RESET_CONTROLS: return tr("SETTINGS_RESET_CONTROLS")
		ROW_HUD_SCALE: return tr("SETTINGS_HUD_SCALE")
		ROW_REDUCE_FLASHING: return tr("SETTINGS_REDUCE_FLASHING")
		ROW_ENEMY_OUTLINES: return tr("SETTINGS_ENEMY_OUTLINES")
	return id


## A footer row on its own plate (a bordered, darker parchment button face), so
## Reset and Back read as buttons and not as two more settings.
func _add_footer_button(id: String, label_text: String) -> void:
	var plate := PanelContainer.new()
	plate.name = "Plate_" + id
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL # side by side on a phone (D370), full width in the column
	plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.PARCHMENT.darkened(0.12), UiPalette.INK_PIXEL, 0, UiPalette.BORDER_THICK, UiPalette.SPACE_S))
	_footer_list.add_child(plate)
	_add_row(plate, id, label_text, false)
	(_rows[id] as SettingsRow).set_button_style(true)


func _add_row(parent: Container, id: String, label_text: String, has_value: bool) -> void:
	var row := SettingsRow.new()
	row.name = "Row_" + id
	parent.add_child(row)
	row.configure(label_text, has_value)
	row.visible = false
	row.hovered.connect(_on_row_hovered.bind(id))
	row.clicked.connect(_on_row_clicked.bind(id))
	row.left_pressed.connect(_on_row_left_pressed.bind(id))
	row.right_pressed.connect(_on_row_right_pressed.bind(id))
	_rows[id] = row


# --- Tabs -------------------------------------------------------------------------

func _rebuild_row_order() -> void:
	_row_order.clear()
	for id: String in TAB_ROWS[_tab]:
		if TouchUi.is_mobile_layout() and (DESKTOP_ONLY_ROWS.has(id)):
			continue
		_row_order.append(id)
	_row_order.append_array(FOOTER_ROWS)
	for id: String in _rows:
		(_rows[id] as SettingsRow).visible = _row_order.has(id)
	_hint_label.visible = _tab == Tab.CONTROLS and not TouchUi.is_mobile_layout()


func _set_tab(tab_index: int) -> void:
	if not _tabs.has(tab_index) or tab_index == _tab:
		return
	_cancel_capture()
	_clear_reset_pending()
	_tab = tab_index
	_rebuild_row_order()
	_highlighted_index = 0
	_scroll.scroll_vertical = 0
	_refresh_all_rows()
	_refresh_highlight()
	_refresh_tabs()
	_fit_scroll.call_deferred()


func _switch_tab(direction: int) -> void:
	var pos: int = _tabs.find(_tab)
	_set_tab(_tabs[wrapi(pos + direction, 0, _tabs.size())])


func _refresh_tabs() -> void:
	for tab_index: int in _tab_panels.size():
		var shown: bool = _tabs.has(tab_index)
		var active: bool = tab_index == _tab
		_tab_panels[tab_index].visible = shown
		# The label's white base takes its colour from `modulate`, like SettingsRow; the
		# underline is the shape cue, so the active tab is never marked by colour alone.
		_tab_labels[tab_index].modulate = UiPalette.HIGHLIGHT_ON_PARCHMENT if active else UiPalette.TEXT_ON_PARCHMENT
		_tab_labels[tab_index].text = tr(TAB_KEYS[tab_index])
		(_tab_panels[tab_index].get_node("Underline") as ColorRect).color = UiPalette.ACCENT if active else Color(0, 0, 0, 0)


func _fit_scroll() -> void:
	if not is_inside_tree() or _scroll == null:
		return
	MenuFrame.fit_scroll(_frame, _scroll, get_viewport().get_visible_rect().size.y)


func _on_tab_gui_input(event: InputEvent, tab_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_tab(tab_index)
	elif event is InputEventScreenTouch and event.pressed:
		_set_tab(tab_index)


# --- Mouse handlers ----------------------------------------------------------------

func _on_row_hovered(id: String) -> void:
	_highlight_row(id)


func _on_row_clicked(id: String) -> void:
	_highlight_row(id)
	_activate(id)


func _on_row_left_pressed(id: String) -> void:
	_highlight_row(id)
	_apply_direction(-1)


func _on_row_right_pressed(id: String) -> void:
	_highlight_row(id)
	_apply_direction(1)


func _highlight_row(id: String) -> void:
	var idx: int = _row_order.find(id)
	if idx != -1 and idx != _highlighted_index:
		_highlighted_index = idx
		_clear_reset_pending()
		_refresh_highlight()


# --- Real-key input (tab switch, rebind capture) ------------------------------------

func _input(event: InputEvent) -> void:
	if not _active or _use_test_input:
		return
	if _capturing:
		_handle_capture_event(event)
		return
	if _lockout_remaining > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if code == KEY_Q:
			_switch_tab(-1)
		elif code == KEY_E:
			_switch_tab(1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_switch_tab(-1)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_switch_tab(1)


func _handle_capture_event(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if code == KEY_ESCAPE:
		_cancel_capture()
		return
	GameSettings.set_key_binding(_capture_action, _capture_slot, code)
	_cancel_capture()
	_ignore_confirm_frames = POST_CAPTURE_IGNORE_FRAMES
	_refresh_all_rows()


func _begin_capture(action: StringName) -> void:
	_capturing = true
	_capture_action = action
	_capture_slot = _slot_cursor
	_refresh_row("bind_" + String(action))


func _cancel_capture() -> void:
	if not _capturing:
		return
	_capturing = false
	var prior: StringName = _capture_action
	_capture_action = &""
	if _rows.has("bind_" + String(prior)):
		_refresh_row("bind_" + String(prior))


# --- Polling ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _active:
		return
	if _lockout_remaining > 0.0:
		_lockout_remaining = maxf(_lockout_remaining - delta, 0.0)
		_clear_test_edges_for_frame()
		return
	if _reset_pending:
		_reset_pending_timer -= delta
		if _reset_pending_timer <= 0.0:
			_clear_reset_pending()
	if _capturing:
		_clear_test_edges_for_frame()
		return
	if _ignore_confirm_frames > 0:
		_ignore_confirm_frames -= 1
		_seed_input_state()
		_clear_test_edges_for_frame()
		return
	_poll_tab_input()
	_poll_vertical_input(delta)
	_poll_horizontal_input(delta)
	_poll_confirm_input()
	_poll_hold(delta)
	_update_fill_ring_visual()
	_clear_test_edges_for_frame()


## Real tab keys arrive through `_input`; the test seam feeds synthetic edges.
func _poll_tab_input() -> void:
	if not _use_test_input:
		return
	if _is_just_pressed(&"tab_prev"):
		_switch_tab(-1)
	if _is_just_pressed(&"tab_next"):
		_switch_tab(1)


func _poll_vertical_input(delta: float) -> void:
	var up_now: bool = _is_pressed(&"move_up")
	var down_now: bool = _is_pressed(&"move_down")

	if up_now and not _up_held:
		_move_highlight(-1)
		_up_repeat_timer = CYCLE_REPEAT_SECONDS
	elif up_now and _up_held:
		_up_repeat_timer -= delta
		if _up_repeat_timer <= 0.0:
			_move_highlight(-1)
			_up_repeat_timer = CYCLE_REPEAT_SECONDS
	_up_held = up_now

	if down_now and not _down_held:
		_move_highlight(1)
		_down_repeat_timer = CYCLE_REPEAT_SECONDS
	elif down_now and _down_held:
		_down_repeat_timer -= delta
		if _down_repeat_timer <= 0.0:
			_move_highlight(1)
			_down_repeat_timer = CYCLE_REPEAT_SECONDS
	_down_held = down_now


func _poll_horizontal_input(delta: float) -> void:
	var left_now: bool = _is_pressed(&"move_left")
	var right_now: bool = _is_pressed(&"move_right")
	var repeats: bool = REPEATING_ROWS.has(_row_order[_highlighted_index])

	if left_now and not _left_held:
		_apply_direction(-1)
		_left_repeat_timer = CYCLE_REPEAT_SECONDS
	elif left_now and _left_held and repeats:
		_left_repeat_timer -= delta
		if _left_repeat_timer <= 0.0:
			_apply_direction(-1)
			_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_held = left_now

	if right_now and not _right_held:
		_apply_direction(1)
		_right_repeat_timer = CYCLE_REPEAT_SECONDS
	elif right_now and _right_held and repeats:
		_right_repeat_timer -= delta
		if _right_repeat_timer <= 0.0:
			_apply_direction(1)
			_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_held = right_now


func _poll_confirm_input() -> void:
	if _is_just_pressed(&"confirm"):
		_activate(_row_order[_highlighted_index])


## Hold Left or Right on Back (close) or Reset to Defaults (reset now). Armed
## only after the key has been up once, so a direction held on arrival cannot
## fire it.
func _poll_hold(delta: float) -> void:
	var id: String = _row_order[_highlighted_index]
	var holdable: bool = id == ROW_BACK or id == ROW_RESET_DEFAULTS
	var held: bool = _is_pressed(&"move_left") or _is_pressed(&"move_right")
	if not holdable:
		_hold_progress = 0.0
		_hold_armed = not held
		return
	if not _hold_armed:
		if not held:
			_hold_armed = true
		return
	if held:
		_hold_progress += delta
		if _hold_progress >= HOLD_CONFIRM_SECONDS:
			_hold_progress = 0.0
			if id == ROW_BACK:
				closed.emit()
			else:
				_perform_reset_defaults()
				_hold_armed = false
	else:
		_hold_progress = 0.0


func _move_highlight(step: int) -> void:
	_highlighted_index = wrapi(_highlighted_index + step, 0, _row_order.size())
	_clear_reset_pending()
	_refresh_highlight()
	var row: SettingsRow = _rows.get(_row_order[_highlighted_index]) as SettingsRow
	if row != null and row.get_parent() == _row_list and is_inside_tree():
		_scroll.ensure_control_visible(row)


## Confirm press / click on a row: Back closes, Reset asks (then does), a
## binding row starts listening. Value rows ignore it (they use Left/Right).
func _activate(id: String) -> void:
	if id == ROW_BACK:
		closed.emit()
	elif id == ROW_RESET_DEFAULTS:
		if _reset_pending:
			_perform_reset_defaults()
		else:
			_reset_pending = true
			_reset_pending_timer = RESET_CONFIRM_SECONDS
			_refresh_row(ROW_RESET_DEFAULTS)
	elif id == ROW_RESET_CONTROLS:
		GameSettings.reset_controls()
		_refresh_all_rows()
	elif id.begins_with(ROW_BIND_PREFIX) and not _capturing:
		_begin_capture(StringName(id.trim_prefix(ROW_BIND_PREFIX)))


func _perform_reset_defaults() -> void:
	_clear_reset_pending()
	GameSettings.reset_to_defaults()
	_refresh_all_rows()


func _clear_reset_pending() -> void:
	if not _reset_pending:
		return
	_reset_pending = false
	_reset_pending_timer = 0.0
	if _rows.has(ROW_RESET_DEFAULTS):
		_refresh_row(ROW_RESET_DEFAULTS)


func _apply_direction(direction: int) -> void:
	var id: String = _row_order[_highlighted_index]
	if id.begins_with(ROW_BIND_PREFIX):
		_slot_cursor = wrapi(_slot_cursor + direction, 0, GameSettings.BINDING_SLOTS)
		_refresh_row(id)
		return
	match id:
		ROW_MASTER_VOLUME:
			GameSettings.adjust_master_volume(direction)
		ROW_MUSIC_VOLUME:
			GameSettings.adjust_music_volume(direction)
		ROW_EFFECTS_VOLUME:
			GameSettings.adjust_effects_volume(direction)
		ROW_INTERFACE_VOLUME:
			GameSettings.adjust_interface_volume(direction)
		ROW_MUTE_ALL:
			GameSettings.set_mute_all(not GameSettings.is_mute_all())
		ROW_DISPLAY_MODE:
			GameSettings.cycle_display_mode(direction)
			_refresh_row(ROW_WINDOW_SIZE)
		ROW_WINDOW_SIZE:
			if GameSettings.get_display_mode() == GameSettings.DisplayMode.WINDOWED:
				GameSettings.cycle_window_size(direction)
		ROW_VSYNC:
			GameSettings.set_vsync_enabled(not GameSettings.is_vsync_enabled())
		ROW_FPS_LIMIT:
			GameSettings.cycle_fps_limit(direction)
		ROW_SHOW_FPS:
			GameSettings.set_show_fps(not GameSettings.is_show_fps())
		ROW_AUTO_CAST:
			GameSettings.set_auto_cast_enabled(not GameSettings.is_auto_cast_enabled())
		ROW_DAMAGE_NUMBERS:
			GameSettings.set_damage_numbers_enabled(not GameSettings.are_damage_numbers_enabled())
		ROW_SCREEN_SHAKE:
			GameSettings.adjust_screen_shake(direction)
		ROW_SHOW_OVERHEAD_BARS:
			GameSettings.set_show_overhead_bars(not GameSettings.is_show_overhead_bars())
		ROW_PAUSE_UNFOCUSED:
			GameSettings.set_pause_when_unfocused(not GameSettings.is_pause_when_unfocused())
		ROW_MOVEMENT_ONLY:
			GameSettings.set_movement_only_controls_enabled(not GameSettings.get_movement_only_controls_enabled())
			_refresh_row(ROW_AUTO_CAST) # Movement-only forces auto-cast on
		ROW_FIRST_TIME_TIPS:
			GameSettings.set_show_first_time_tips(not GameSettings.is_show_first_time_tips())
		ROW_HUD_SCALE:
			GameSettings.adjust_hud_scale(direction)
		ROW_REDUCE_FLASHING:
			GameSettings.set_reduce_flashing(not GameSettings.is_reduce_flashing())
		ROW_ENEMY_OUTLINES:
			GameSettings.set_enemy_outlines(not GameSettings.is_enemy_outlines())
		_:
			return # Back, Reset: no value
	_refresh_row(id)


# --- Row refresh -----------------------------------------------------------------------

func _refresh_all_rows() -> void:
	for id: String in _rows:
		_refresh_row(id)


func _refresh_row(id: String) -> void:
	var row: SettingsRow = _rows.get(id) as SettingsRow
	if row == null:
		return
	if id.begins_with(ROW_BIND_PREFIX):
		row.set_value_text(_binding_text(StringName(id.trim_prefix(ROW_BIND_PREFIX))))
		return
	match id:
		ROW_MASTER_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_master_volume_pct()))
		ROW_MUSIC_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_music_volume_pct()))
		ROW_EFFECTS_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_effects_volume_pct()))
		ROW_INTERFACE_VOLUME:
			row.set_value_text(_pct_text(GameSettings.get_interface_volume_pct()))
		ROW_MUTE_ALL:
			row.set_value_text(_on_off_text(GameSettings.is_mute_all()))
		ROW_DISPLAY_MODE:
			row.set_value_text(_display_mode_text(GameSettings.get_display_mode()))
		ROW_WINDOW_SIZE:
			if GameSettings.get_display_mode() == GameSettings.DisplayMode.WINDOWED:
				var ws: Vector2i = GameSettings.get_window_size()
				row.set_value_text("%dx%d" % [ws.x, ws.y])
			else:
				row.set_value_text(tr("SETTINGS_WINDOW_SIZE_LOCKED"))
		ROW_VSYNC:
			row.set_value_text(_on_off_text(GameSettings.is_vsync_enabled()))
		ROW_FPS_LIMIT:
			var fps: int = GameSettings.get_fps_limit()
			row.set_value_text(tr("SETTINGS_FPS_UNLIMITED") if fps == 0 else str(fps))
		ROW_SHOW_FPS:
			row.set_value_text(_on_off_text(GameSettings.is_show_fps()))
		ROW_AUTO_CAST:
			row.set_value_text(_on_off_text(GameSettings.is_auto_cast_enabled()))
		ROW_DAMAGE_NUMBERS:
			row.set_value_text(_on_off_text(GameSettings.are_damage_numbers_enabled()))
		ROW_SCREEN_SHAKE:
			var shake: int = GameSettings.get_screen_shake_pct()
			row.set_value_text(tr("SETTINGS_OFF") if shake == 0 else _pct_text(shake))
		ROW_SHOW_OVERHEAD_BARS:
			row.set_value_text(_on_off_text(GameSettings.is_show_overhead_bars()))
		ROW_PAUSE_UNFOCUSED:
			row.set_value_text(_on_off_text(GameSettings.is_pause_when_unfocused()))
		ROW_MOVEMENT_ONLY:
			row.set_value_text(_on_off_text(GameSettings.get_movement_only_controls_enabled()))
		ROW_FIRST_TIME_TIPS:
			row.set_value_text(_on_off_text(GameSettings.is_show_first_time_tips()))
		ROW_HUD_SCALE:
			row.set_value_text(_pct_text(GameSettings.get_hud_scale_pct()))
		ROW_REDUCE_FLASHING:
			row.set_value_text(_on_off_text(GameSettings.is_reduce_flashing()))
		ROW_ENEMY_OUTLINES:
			row.set_value_text(_on_off_text(GameSettings.is_enemy_outlines()))
		ROW_RESET_DEFAULTS:
			row.set_note(tr("SETTINGS_RESET_CONFIRM") if _reset_pending else "")


## "[W] / Up" with the targeted slot in brackets on the highlighted row.
func _binding_text(action: StringName) -> String:
	if _capturing and _capture_action == action:
		return tr("SETTINGS_REBIND_PROMPT")
	var parts: Array[String] = []
	var is_current: bool = _row_order.size() > 0 and _row_order[_highlighted_index] == ROW_BIND_PREFIX + String(action)
	for slot: int in GameSettings.BINDING_SLOTS:
		var label: String = GameSettings.key_label(GameSettings.get_key_binding(action, slot))
		parts.append("[%s]" % label if is_current and slot == _slot_cursor else label)
	return " / ".join(parts)


func _refresh_highlight() -> void:
	for i: int in _row_order.size():
		var row: SettingsRow = _rows.get(_row_order[i]) as SettingsRow
		if row != null:
			row.set_highlighted(i == _highlighted_index)
	for id: String in _rows:
		if id.begins_with(ROW_BIND_PREFIX):
			_refresh_row(id) # the bracketed slot follows the highlight


func _update_fill_ring_visual() -> void:
	if _fill_ring == null:
		return
	var id: String = _row_order[_highlighted_index]
	var on_hold_row: bool = id == ROW_BACK or id == ROW_RESET_DEFAULTS
	_fill_ring.progress = clampf(_hold_progress / HOLD_CONFIRM_SECONDS, 0.0, 1.0) if on_hold_row else 0.0


func _pct_text(pct: int) -> String:
	return "%d%%" % pct


func _on_off_text(enabled: bool) -> String:
	return tr("SETTINGS_ON") if enabled else tr("SETTINGS_OFF")


func _display_mode_text(mode: int) -> String:
	match mode:
		GameSettings.DisplayMode.FULLSCREEN:
			return tr("SETTINGS_DISPLAY_FULLSCREEN")
		GameSettings.DisplayMode.BORDERLESS:
			return tr("SETTINGS_DISPLAY_BORDERLESS")
		_:
			return tr("SETTINGS_DISPLAY_WINDOWED")


## A key already held at open must not read as a fresh press once the lockout ends.
func _seed_input_state() -> void:
	_up_held = _is_pressed(&"move_up")
	_down_held = _is_pressed(&"move_down")
	_left_held = _is_pressed(&"move_left")
	_right_held = _is_pressed(&"move_right")
	_up_repeat_timer = CYCLE_REPEAT_SECONDS
	_down_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_hold_progress = 0.0
	_hold_armed = not (_is_pressed(&"move_left") or _is_pressed(&"move_right"))


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _clear_test_edges_for_frame() -> void:
	if _use_test_input:
		_test_just_pressed.clear()

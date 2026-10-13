extends CanvasLayer
class_name FieldGuideScreen

## The Field Guide (PT-UI, docs/33 A3; decision D322): what every ability, passive, Battle
## Skill, pact, enemy, boss, arena object, Champion and Relic is, with its exact numbers.
## Opened from the War Camp and from the Pause menu (`FieldGuideScreen.new()`, add it as a
## child, `open()`); `closed` fires when the player leaves. Entries come from
## `FieldGuideCatalog` (live data); one the player has not met reads "???" with a hint, and
## the profile's `discovered_ids` decide which those are.
##
## Layout: a tab strip, a grid of symbol tiles on the left (focus or hover shows the entry,
## a press pins it as SELECTED), the entry's page on the right. Every tile and tab uses the
## shared selection language (`SelectableState`). PROCESS_MODE_ALWAYS so it works under the
## pause menu; it never touches PauseAuthority (its host owns the pause).
## Input: arrows / WASD / D-pad move between tiles, Q / E (or LB / RB) switch tab, Esc or the
## Back button leaves, clicks and touch taps work (the Hub's native-focus convention).

signal closed()

const FIELD_GUIDE_CANVAS_LAYER: int = 22 ## above the pause menu (18) and Settings (21)
const CARD_WIDTH_PX: float = 1700.0
const TILE_SIZE: Vector2 = Vector2(188.0, 150.0)
const TILE_ICON_PX: int = 72
const GRID_COLUMNS: int = 4
const DETAIL_ICON_PX: int = 128
const DETAIL_WIDTH_PX: float = 780.0
const BODY_HEIGHT_PX: float = 560.0
const BODY_HEIGHT_COMPACT_PX: float = 330.0

var _frame: MenuFrame.Parts
var _found_label: Label
var _tab_row: HFlowContainer
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _detail_scroll: ScrollContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_tab_name: Label
var _helps_row: HBoxContainer
var _helps_text: Label
var _hurts_row: HBoxContainer
var _hurts_text: Label
var _effect_text: Label
var _tip_row: HBoxContainer
var _tip_text: Label
var _back_button: Button

var _tab: int = FieldGuideCatalog.Tab.ABILITIES
var _entries: Array[Dictionary] = []
var _tiles: Dictionary = {} # entry id -> Button
var _selected_id: String = ""
var _shown_id: String = ""
var _open: bool = false


func _ready() -> void:
	layer = FIELD_GUIDE_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


## Shows the Guide on `tab` (and entry `entry_id` when given). Idempotent.
func open(tab: int = FieldGuideCatalog.Tab.ABILITIES, entry_id: String = "") -> void:
	_open = true
	visible = true
	_tab = clampi(tab, 0, FieldGuideCatalog.Tab.size() - 1)
	_selected_id = ""
	_refresh_tabs()
	_rebuild_grid()
	if entry_id != "":
		select_entry(entry_id)
	_update_found_label()
	_fit_card()
	_refit_after_layout.call_deferred()
	MenuFrame.animate_in(_frame)
	_focus_first_tile.call_deferred()


## The tab row wraps to a second line once the card has its real width, which adds height the first
## measurement could not see; measure again a frame later.
func _refit_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if _open:
		_fit_card()


## D370: the card and its two scroll areas take the room the safe area leaves (the fixed 1700 x
## 560 design did not fit a phone: it ran past the right edge and the bottom of the canvas).
func _fit_card() -> void:
	if not is_inside_tree():
		return
	var safe: Rect2 = SafeArea.rect(get_window())
	var card: PanelContainer = _frame.card
	card.custom_minimum_size.x = minf(CARD_WIDTH_PX, safe.size.x)
	var tiles_w: float = _scroll.custom_minimum_size.x
	_detail_scroll.custom_minimum_size.x = clampf(safe.size.x - tiles_w - 150.0, 360.0, DETAIL_WIDTH_PX)
	_scroll.custom_minimum_size.y = 0.0
	_detail_scroll.custom_minimum_size.y = 0.0
	var fixed: float = card.get_combined_minimum_size().y
	var body_h: float = clampf(safe.size.y - fixed, 200.0, BODY_HEIGHT_PX)
	_scroll.custom_minimum_size.y = body_h
	_detail_scroll.custom_minimum_size.y = body_h


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	MenuFrame.reset_motion(_frame)
	closed.emit()


func is_open() -> bool:
	return _open


func get_tab() -> int:
	return _tab


func set_tab(tab: int) -> void:
	_tab = clampi(tab, 0, FieldGuideCatalog.Tab.size() - 1)
	_selected_id = ""
	_refresh_tabs()
	_rebuild_grid()


## Pins `entry_id` (SELECTED) on the current tab and shows its page. False when it is not here.
func select_entry(entry_id: String) -> bool:
	if not _tiles.has(entry_id):
		return false
	_pin(entry_id)
	return true


func get_selected_id() -> String:
	return _selected_id


func get_shown_id() -> String:
	return _shown_id


func get_tile(entry_id: String) -> Button:
	return _tiles.get(entry_id) as Button


func get_tile_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _tiles:
		out.append(id)
	return out


func get_tab_button(tab: int) -> Button:
	return _tab_buttons[tab]


func get_detail_name() -> String:
	return _detail_name.text


func get_detail_effect() -> String:
	return _effect_text.text


func get_detail_helps() -> String:
	return _helps_text.text if _helps_row.visible else ""


func get_detail_hurts() -> String:
	return _hurts_text.text if _hurts_row.visible else ""


func get_detail_tip() -> String:
	return _tip_text.text if _tip_row.visible else ""


func get_found_text() -> String:
	return _found_label.text


func get_back_button() -> Button:
	return _back_button


# --- Input -------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void: # _input, not _unhandled_input: it must beat the pause key handler beneath it
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	var step: int = 0
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var code: int = (event as InputEventKey).physical_keycode
		if code == KEY_Q:
			step = -1
		elif code == KEY_E:
			step = 1
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		var button: int = (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif button == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
	if step != 0:
		set_tab(wrapi(_tab + step, 0, FieldGuideCatalog.Tab.size()))
		_focus_first_tile()
		get_viewport().set_input_as_handled()
		return
	# The movement keys (WASD) walk the focus like the arrow keys do.
	for pair: Array in [[&"move_left", SIDE_LEFT], [&"move_right", SIDE_RIGHT], [&"move_up", SIDE_TOP], [&"move_down", SIDE_BOTTOM]]:
		if event.is_action_pressed(pair[0] as StringName):
			_move_focus(int(pair[1]))
			get_viewport().set_input_as_handled()
			return


func _move_focus(side: int) -> void:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	if owner_control == null:
		_focus_first_tile()
		return
	var next: Control = owner_control.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()


func _focus_first_tile() -> void:
	if not _open:
		return
	var preferred: Button = _tiles.get(_selected_id) as Button
	if preferred == null and not _entries.is_empty():
		preferred = _tiles.get(String(_entries[0]["id"])) as Button
	if preferred != null:
		preferred.grab_focus()
	elif _tab_buttons.size() > _tab:
		_tab_buttons[_tab].grab_focus()


# --- Build ---------------------------------------------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	_frame = MenuFrame.build(self, 0.85, "M")
	_frame.card.custom_minimum_size = Vector2(CARD_WIDTH_PX, 0.0)
	_frame.dim.mouse_filter = Control.MOUSE_FILTER_STOP # a click outside the card must not reach the screen beneath

	var head := HBoxContainer.new()
	head.name = "Head"
	head.theme_type_variation = UiTheme.hbox("L")
	_frame.column.add_child(head)
	var title: Label = MenuFrame.build_title(head, tr("FG_TITLE"), UiTheme.HEADING, 480.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_found_label = Label.new()
	_found_label.name = "Found"
	_found_label.theme_type_variation = UiTheme.DIM_PARCHMENT
	_found_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_found_label)
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = tr("FG_BACK")
	_back_button.focus_mode = Control.FOCUS_ALL
	_back_button.custom_minimum_size = TouchUi.button_size(Vector2(200.0, 60.0))
	_back_button.pressed.connect(close)
	head.add_child(_back_button)
	SelectableState.attach(_back_button, SelectableState.Layout.ROW)

	_tab_row = HFlowContainer.new()
	_tab_row.name = "Tabs"
	_tab_row.add_theme_constant_override("h_separation", UiPalette.SPACE_M)
	_tab_row.add_theme_constant_override("v_separation", UiPalette.SPACE_S)
	_frame.column.add_child(_tab_row)
	var group := ButtonGroup.new()
	for tab in FieldGuideCatalog.Tab.values():
		var button := Button.new()
		button.name = "Tab%d" % tab
		button.text = tr(FieldGuideCatalog.TAB_KEYS[tab])
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = TouchUi.touch_size(Vector2(0.0, 60.0))
		button.pressed.connect(_on_tab_pressed.bind(tab))
		_tab_row.add_child(button)
		_tab_buttons.append(button)
		var overlay: SelectableState = SelectableState.attach(button, SelectableState.Layout.TAB)
		button.toggled.connect(overlay.set_selected)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.theme_type_variation = UiTheme.hbox("XL")
	_frame.column.add_child(body)
	var body_h: float = BODY_HEIGHT_COMPACT_PX if TouchUi.is_mobile_layout() else BODY_HEIGHT_PX

	_scroll = ScrollContainer.new()
	_scroll.name = "TileScroll"
	_scroll.custom_minimum_size = Vector2(float(GRID_COLUMNS) * (TILE_SIZE.x + 12.0) + 24.0, body_h)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 16)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.name = "Tiles"
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	pad.add_child(_grid)

	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.custom_minimum_size = Vector2(DETAIL_WIDTH_PX, body_h)
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_detail_scroll)
	var detail := VBoxContainer.new()
	detail.name = "Detail"
	detail.theme_type_variation = UiTheme.vbox("M")
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_scroll.add_child(detail)

	var top := HBoxContainer.new()
	top.theme_type_variation = UiTheme.hbox("L")
	detail.add_child(top)
	var plate := PanelContainer.new()
	plate.name = "IconPlate"
	plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.SURFACE, UiPalette.WOOD_BORDER, UiPalette.RADIUS_PANEL, UiPalette.BORDER_THICK, UiPalette.SPACE_S))
	plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(plate)
	_detail_icon = AbilityDisplay.make_icon_rect("", DETAIL_ICON_PX)
	plate.add_child(_detail_icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	_detail_name = _make_text(UiTheme.HEADING)
	_detail_name.name = "Name"
	names.add_child(_detail_name)
	_detail_tab_name = _make_text(UiTheme.DIM_PARCHMENT)
	_detail_tab_name.name = "Kind"
	names.add_child(_detail_tab_name)

	_helps_row = _make_labelled_row(detail, "Helps", tr("FG_HELPS_LABEL"), UiPalette.SUCCESS_ON_PARCHMENT)
	_helps_text = _helps_row.get_child(1) as Label
	_hurts_row = _make_labelled_row(detail, "Hurts", tr("FG_HURTS_LABEL"), UiPalette.DANGER_ON_PARCHMENT)
	_hurts_text = _hurts_row.get_child(1) as Label
	_effect_text = _make_text(&"")
	_effect_text.name = "Effect"
	detail.add_child(_effect_text)
	_tip_row = _make_labelled_row(detail, "Tip", tr("FG_TIP_LABEL"), UiPalette.HIGHLIGHT_ON_PARCHMENT)
	_tip_text = _tip_row.get_child(1) as Label
	_show_empty_detail()


func _make_text(variation: StringName) -> Label:
	var label := Label.new()
	if variation != &"":
		label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## "Helps:" / "Hurts:" / "Tip:" in a coloured bold word (the word itself is the signal) + a wrapping text.
func _make_labelled_row(parent: Container, row_name: String, word: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.theme_type_variation = UiTheme.hbox("M")
	parent.add_child(row)
	var key := Label.new()
	key.text = word
	key.theme_type_variation = UiTheme.VALUE
	key.add_theme_color_override("font_color", color)
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(key)
	var text: Label = _make_text(&"")
	text.name = "Text"
	row.add_child(text)
	return row


# --- State ----------------------------------------------------------------------------------------------

func _on_tab_pressed(tab: int) -> void:
	if tab == _tab:
		return
	set_tab(tab)


func _refresh_tabs() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
		var overlay: SelectableState = SelectableState.of(_tab_buttons[i])
		if overlay != null:
			overlay.set_selected(i == _tab)
		var counts: Vector2i = FieldGuideCatalog.discovered_count(i)
		_tab_buttons[i].tooltip_text = tr("FG_FOUND") % [counts.x, counts.y]


func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.hide() # a hidden control takes no room while it waits to be freed
		child.queue_free() # queue_free alone, never remove_child first (the orphan monitor)
	_tiles.clear()
	_entries = FieldGuideCatalog.entries(_tab)
	for entry: Dictionary in _entries:
		var tile: Button = _make_tile(entry)
		_grid.add_child(tile)
		_tiles[String(entry["id"])] = tile
	_scroll.scroll_vertical = 0
	_show_empty_detail()
	_update_found_label()


func _make_tile(entry: Dictionary) -> Button:
	var id: String = String(entry["id"])
	var known: bool = FieldGuideCatalog.is_known(entry)
	var tile := Button.new()
	tile.name = "Tile_%s" % id
	tile.toggle_mode = true
	tile.focus_mode = Control.FOCUS_ALL
	tile.custom_minimum_size = TILE_SIZE
	tile.tooltip_text = String(entry["name"]) if known else tr("FG_UNKNOWN_NAME")
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_theme_constant_override("icon_max_width", TILE_ICON_PX)
	tile.icon = AbilityDisplay.icon(String(entry["icon"]))
	if not known:
		tile.add_theme_color_override("icon_normal_color", Color(0.0, 0.0, 0.0, 0.85))
		tile.add_theme_color_override("icon_hover_color", Color(0.0, 0.0, 0.0, 0.85))
		tile.add_theme_color_override("icon_pressed_color", Color(0.0, 0.0, 0.0, 0.85))
		tile.add_theme_color_override("icon_focus_color", Color(0.0, 0.0, 0.0, 0.85))
		tile.add_theme_color_override("icon_hover_pressed_color", Color(0.0, 0.0, 0.0, 0.85))
	var overlay: SelectableState = SelectableState.attach(tile, SelectableState.Layout.TILE)
	overlay.set_locked(not known, "")
	tile.focus_entered.connect(_show_entry.bind(id))
	tile.mouse_entered.connect(_show_entry.bind(id))
	tile.pressed.connect(_on_tile_pressed.bind(id))
	return tile


func _on_tile_pressed(id: String) -> void:
	var tile: Button = _tiles.get(id) as Button
	var overlay: SelectableState = SelectableState.of(tile)
	if overlay != null and overlay.is_locked():
		tile.set_pressed_no_signal(false)
		overlay.press_locked() # shakes; the page below explains why
		_show_entry(id)
		return
	_pin(id)


func _pin(id: String) -> void:
	_selected_id = id
	for tile_id: String in _tiles:
		var tile: Button = _tiles[tile_id]
		var is_selected: bool = tile_id == id
		tile.set_pressed_no_signal(is_selected)
		var overlay: SelectableState = SelectableState.of(tile)
		if overlay != null and not overlay.is_locked():
			overlay.set_selected(is_selected)
	_show_entry(id)


## Focus / hover previews an entry; with nothing in focus the pinned one shows again.
func _show_entry(id: String) -> void:
	var entry: Dictionary = _entry_of(id)
	if entry.is_empty():
		_show_empty_detail()
		return
	_shown_id = id
	var known: bool = FieldGuideCatalog.is_known(entry)
	_detail_tab_name.text = FieldGuideCatalog.tab_name(int(entry["tab"]))
	if known:
		_detail_name.text = String(entry["name"])
		_detail_icon.texture = AbilityDisplay.icon(String(entry["icon"]))
		_detail_icon.modulate = Color.WHITE
		_set_row(_helps_row, _helps_text, String(entry["helps"]))
		_set_row(_hurts_row, _hurts_text, String(entry["hurts"]))
		_effect_text.text = String(entry["effect"])
		_set_row(_tip_row, _tip_text, String(entry["tip"]))
	else:
		_detail_name.text = tr("FG_UNKNOWN_NAME")
		_detail_icon.texture = AbilityDisplay.icon(String(entry["icon"]))
		_detail_icon.modulate = Color(0.0, 0.0, 0.0, 0.85)
		_set_row(_helps_row, _helps_text, "")
		_set_row(_hurts_row, _hurts_text, "")
		_effect_text.text = "%s\n%s" % [tr("FG_NOT_FOUND_HELP"), String(entry["hint"])]
		_set_row(_tip_row, _tip_text, "")
	_detail_scroll.scroll_vertical = 0


func _set_row(row: Control, text_label: Label, text: String) -> void:
	row.visible = text != ""
	text_label.text = text


func _show_empty_detail() -> void:
	_shown_id = ""
	_detail_name.text = tr("FG_SELECT_HINT")
	_detail_tab_name.text = FieldGuideCatalog.tab_name(_tab)
	_detail_icon.texture = AbilityDisplay.icon("")
	_detail_icon.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_set_row(_helps_row, _helps_text, "")
	_set_row(_hurts_row, _hurts_text, "")
	_effect_text.text = ""
	_set_row(_tip_row, _tip_text, "")


func _entry_of(id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if String(entry["id"]) == id:
			return entry
	return {}


func _update_found_label() -> void:
	var found: int = 0
	var total: int = 0
	for tab in FieldGuideCatalog.Tab.values():
		var counts: Vector2i = FieldGuideCatalog.discovered_count(tab)
		found += counts.x
		total += counts.y
	_found_label.text = tr("FG_FOUND") % [found, total]

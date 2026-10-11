extends CanvasLayer
class_name ExplainerController

## First-encounter explainers (PT-UI, docs/33 A4; decision D323). The first time the player meets
## something (each event screen, shrine, keg, crate, spike trap, bridge, each enemy type, each
## boss, the first elite) a small card pauses the game: the icon, the name, "Helps you:" /
## "Hurts you:", the exact effect, and a "Got it" button, with a "Don't show tips again" check
## box that mirrors Settings > Gameplay > "Show first-time tips" (`GameSettings`). Each
## explainer is shown once per profile (`MetaProgress.explainers_seen`) and replaces the
## contextual hint toast for the same thing (`RunHints` keeps the control hints). The card's
## text is the thing's Field Guide entry (`FieldGuideCatalog`), so a number is never typed twice.
##
## ## Queue, never a stack
## Requests queue. A card opens only when nothing else holds the pause, never while a Level-Up
## or War Chest Draft is showing or queued (`DraftController.is_busy()`), and only one is up at
## a time; the next one follows at once, still paused. The one exception is the card for an
## event screen (Opening Pick, Patron's Boon, Sanctuary, Blood Pact): it opens over that screen,
## which waits for it (`EventDraftController` gates its input while `is_showing()`).
## Pausing goes through PauseAuthority (reason "explainer"), like the Draft.
##
## ## Input contract (docs/19 > "Upgrade Draft UI & Navigation", reused)
## 0.4 s lockout on open; Left / Right (or A / D) move the highlight between "Don't show tips
## again" and "Got it"; `confirm` (Space) presses the highlighted one; holding Up for 1.0 s
## confirms "Got it" (armed only once input has been neutral after the lockout); a click or a
## touch tap on either works too. PROCESS_MODE_ALWAYS; input is timed with its own `delta`.
##
## Off in a headless process (the balance bot and scene tests) unless `forced_for_test`.

signal explainer_shown(id: String)
signal explainer_closed(id: String)

const EXPLAINER_CANVAS_LAYER: int = 23 ## above the Field Guide (22), Settings (21) and the Draft (20)
const REASON_EXPLAINER: StringName = &"explainer"
const POLL_SECONDS: float = 0.4
const SIGHT_RADIUS_PX: float = 1100.0 ## about the half-diagonal of the play view (RunHints' figure)
const ENVIRONMENT_SCAN_SECONDS: float = 1.6
const CARD_WIDTH_PX: float = 1000.0
const ICON_PX: int = 128
const BODY_MAX_HEIGHT_PX: float = 380.0
const BODY_MAX_HEIGHT_COMPACT_PX: float = 270.0
const DIM_ALPHA: float = 0.75
const HOLD_RING_RADIUS_PX: float = 26.0
const EVENT_IDS: Array[String] = ["opening_pick", "patrons_boon", "sanctuary", "blood_pact"]
const ENEMY_IDS: Array[String] = ["tower_seeker", "player_hunter", "opportunist", "bomber", "brute", "goblin_shaman"]
## Arena groups (set by src/arena/*) -> the explainer each one triggers.
const ARENA_GROUPS: Dictionary = {
	&"arena_crate": "supply_crate", &"arena_keg": "powder_keg",
	&"arena_shrine": "shrine", &"arena_spike_trap": "spike_trap",
}

var draft_controller: DraftController = null
var event_controller: EventDraftController = null
var forced_for_test: bool = false

var _pause_authority: Node = PauseAuthority
var _queue: Array[String] = []
var _current: String = ""
var _owns_pause: bool = false
var _time_since_open: float = 0.0
var _lockout_elapsed: bool = false
var _hold_armed: bool = false
var _hold_progress: float = 0.0
var _highlight: int = 1 ## 0 = the check box, 1 = Got it
var _left_held: bool = false
var _right_held: bool = false
var _mouse_confirm_this_frame: bool = false
var _poll_left: float = POLL_SECONDS
var _scan_left: float = 0.0
var _environment_nodes: Array[Node2D] = []
var _water_nodes: Array[Node2D] = []
var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}

var _root: Control
var _card: PanelContainer
var _icon_rect: TextureRect
var _name_label: Label
var _kind_label: Label
var _helps_row: HBoxContainer
var _helps_text: Label
var _hurts_row: HBoxContainer
var _hurts_text: Label
var _effect_label: Label
var _body_scroll: ScrollContainer
var _check: CheckBox
var _got_it: Button
var _prompt_label: Label


static func is_enabled_by_default() -> bool:
	return DisplayServer.get_name() != "headless"


func _ready() -> void:
	layer = EXPLAINER_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	if not EventBus.elite_spawned.is_connected(_on_elite_spawned):
		EventBus.elite_spawned.connect(_on_elite_spawned)
	if not EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.connect(_on_boss_spawned)


func _exit_tree() -> void:
	if EventBus.elite_spawned.is_connected(_on_elite_spawned):
		EventBus.elite_spawned.disconnect(_on_elite_spawned)
	if EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.disconnect(_on_boss_spawned)
	if is_showing() and _owns_pause and _pause_authority != null:
		_pause_authority.pop_reason_immediate(REASON_EXPLAINER)


func setup(drafts: DraftController, events: EventDraftController) -> void:
	draft_controller = drafts
	event_controller = events


# --- Requests ------------------------------------------------------------------------------------------

## True when `id` could still be shown: tips on, not yet shown on this profile, not waiting.
func wants(id: String) -> bool:
	if not _enabled() or not GameSettings.is_show_first_time_tips():
		return false
	if MetaProgress.is_explainer_seen(id) or id == _current or _queue.has(id):
		return false
	return not FieldGuideCatalog.find_entry(id).is_empty()


## Queues the explainer for `id` (a Field Guide entry id) when `wants(id)`. Returns whether it queued.
func request(id: String) -> bool:
	var resolved: String = String(FieldGuideCatalog.BOSS_ID_ALIASES.get(id, id))
	if not wants(resolved):
		return false
	_queue.append(resolved)
	return true


## Records the sighting in the Field Guide, then queues the explainer.
func note_sighting(id: String) -> void:
	FieldGuideCatalog.note_seen(id)
	request(id)


func is_showing() -> bool:
	return _current != ""


func get_current_id() -> String:
	return _current


func get_queue() -> Array[String]:
	return _queue.duplicate()


func is_busy() -> bool:
	return is_showing() or not _queue.is_empty()


func _enabled() -> bool:
	return forced_for_test or is_enabled_by_default()


# --- Per-frame -------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_showing():
		_poll_world(delta)
		_try_open()
		return
	_time_since_open += delta
	if not _lockout_elapsed:
		if _time_since_open >= DraftController.LOCKOUT_SECONDS:
			_lockout_elapsed = true
			if not _is_pressed(&"move_up"):
				_hold_armed = true
		_update_ring()
		_clear_edges()
		_mouse_confirm_this_frame = false
		return # input is locked out for the whole 0.4 s window
	_poll_cycle()
	if is_showing() and _is_just_pressed(&"confirm") and not _mouse_confirm_this_frame:
		_press_highlighted()
	_poll_hold_up(delta)
	_update_ring()
	_clear_edges()
	_mouse_confirm_this_frame = false


func _input(event: InputEvent) -> void:
	if is_showing() and event is InputEventMouseButton and event.is_action_pressed(&"confirm"):
		_mouse_confirm_this_frame = true # a click acts on the button under it, not the highlighted one


func _poll_cycle() -> void:
	var left_now: bool = _is_pressed(&"move_left") or _is_pressed(&"draft_cycle_left")
	var right_now: bool = _is_pressed(&"move_right") or _is_pressed(&"draft_cycle_right")
	if (left_now and not _left_held) or (right_now and not _right_held):
		_highlight = 0 if left_now and not _left_held else 1
		_refresh_highlight()
		Sfx.play_ui("ui_hover")
	_left_held = left_now
	_right_held = right_now


func _poll_hold_up(delta: float) -> void:
	var pressed: bool = _is_pressed(&"move_up")
	if not _hold_armed:
		if not pressed:
			_hold_armed = true # neutral observed after the lockout
		return
	if pressed:
		_hold_progress += delta
		if _hold_progress >= DraftController.HOLD_CONFIRM_SECONDS:
			_hold_progress = 0.0
			_confirm()
	else:
		_hold_progress = 0.0


func _press_highlighted() -> void:
	if _highlight == 0:
		_check.button_pressed = not _check.button_pressed
	else:
		_confirm()


## "Got it": records the choice and closes (or chains to the next queued card).
func _confirm() -> void:
	if not is_showing():
		return
	if _check.button_pressed:
		GameSettings.set_show_first_time_tips(false)
		_queue.clear()
	Sfx.play_ui("ui_confirm")
	var id: String = _current
	_current = ""
	explainer_closed.emit(id)
	if not _queue.is_empty() and GameSettings.is_show_first_time_tips() and _can_chain():
		_open(_queue.pop_front(), _owns_pause, false) # still paused: no flicker of unpaused gameplay
		return
	_hide()
	if _owns_pause and _pause_authority != null:
		_pause_authority.pop_reason_immediate(REASON_EXPLAINER)
	_owns_pause = false


func _can_chain() -> bool:
	return draft_controller == null or not draft_controller.is_busy()


func _on_got_it_pressed() -> void:
	if is_showing() and _lockout_elapsed:
		_highlight = 1
		_confirm()


func _on_check_toggled(_on: bool) -> void:
	var overlay: SelectableState = SelectableState.of(_check)
	if overlay != null:
		overlay.set_selected(_check.button_pressed, tr("EXPL_ON"))


# --- Opening ----------------------------------------------------------------------------------------------

func _try_open() -> void:
	if _queue.is_empty() or not _enabled():
		return
	if not GameSettings.is_show_first_time_tips():
		_queue.clear()
		return
	if draft_controller != null and draft_controller.is_busy():
		return # never on top of a Draft: wait until it closes
	var reasons: Array[StringName] = _pause_authority.get_active_reasons() if _pause_authority != null else []
	var over_event: bool = event_controller != null and event_controller.is_showing()
	var pick: int = 0
	if not reasons.is_empty():
		if not over_event:
			return # the pause menu, results, a focus loss or a hand-off holds the pause
		for r in reasons:
			if r != &"draft":
				return
		pick = -1
		for i in _queue.size():
			if EVENT_IDS.has(_queue[i]):
				pick = i
				break
		if pick < 0:
			return # only an event screen's own card opens over it
	elif over_event:
		return
	var id: String = _queue[pick]
	_queue.remove_at(pick)
	_open(id, reasons.is_empty())


func _open(id: String, owns_pause: bool, push_pause: bool = true) -> void:
	var entry: Dictionary = FieldGuideCatalog.find_entry(id)
	if entry.is_empty():
		return
	_current = id
	_owns_pause = owns_pause
	if owns_pause and push_pause and _pause_authority != null:
		_pause_authority.push_reason_immediate(REASON_EXPLAINER)
	MetaProgress.mark_explainer_seen(id)
	FieldGuideCatalog.note_seen(id)
	_fill(entry)
	_time_since_open = 0.0
	_lockout_elapsed = false
	_hold_armed = false
	_hold_progress = 0.0
	_highlight = 1
	_left_held = false
	_right_held = false
	_mouse_confirm_this_frame = false
	_check.set_pressed_no_signal(false)
	_on_check_toggled(false)
	_refresh_highlight()
	_update_ring()
	_root.visible = true
	explainer_shown.emit(id)


func _hide() -> void:
	_root.visible = false


# --- World triggers ----------------------------------------------------------------------------------------

func _poll_world(delta: float) -> void:
	if not _enabled() or get_tree() == null or get_tree().paused:
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = POLL_SECONDS
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_poll_enemies(player)
	_poll_arena(player)
	_scan_left -= POLL_SECONDS
	if _scan_left <= 0.0:
		_scan_left = ENVIRONMENT_SCAN_SECONDS
		_poll_environment(player)


func _poll_enemies(player: Node2D) -> void:
	var all_met: bool = true
	for id in ENEMY_IDS:
		all_met = all_met and MetaProgress.is_discovered(id)
	if all_met:
		return # nothing left to find: skip scanning the horde
	for enemy: Node2D in EntityRegistry.get_enemies_in_radius(player.global_position, SIGHT_RADIUS_PX):
		var kind: String = RunHints.enemy_kind(enemy)
		if ENEMY_IDS.has(kind):
			note_sighting(kind)


func _poll_arena(player: Node2D) -> void:
	for group: StringName in ARENA_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			var n2: Node2D = node as Node2D
			if n2 != null and n2.is_visible_in_tree() and n2.global_position.distance_to(player.global_position) <= SIGHT_RADIUS_PX:
				note_sighting(String(ARENA_GROUPS[group]))
				break


## Bridges and ponds are plain scene nodes (no group); they are looked up by class every
## ENVIRONMENT_SCAN_SECONDS and kept, so the cost stops once both are met.
func _poll_environment(player: Node2D) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if _environment_nodes.is_empty():
		for n: Node in scene.find_children("*", "BridgeSpan", true, false):
			if n is Node2D:
				_environment_nodes.append(n as Node2D)
	if _water_nodes.is_empty():
		for n: Node in scene.find_children("*", "PondField", true, false):
			if n is Node2D:
				_water_nodes.append(n as Node2D)
	for n2: Node2D in _environment_nodes:
		if is_instance_valid(n2) and n2.global_position.distance_to(player.global_position) <= SIGHT_RADIUS_PX:
			note_sighting("bridge")
			FieldGuideCatalog.note_seen("water")
			return
	for n3: Node2D in _water_nodes:
		if is_instance_valid(n3) and n3.global_position.distance_to(player.global_position) <= SIGHT_RADIUS_PX:
			FieldGuideCatalog.note_seen("water")
			return


func _on_elite_spawned(_entity: Node2D, _affix: String, _timestamp: float) -> void:
	note_sighting("elite")


func _on_boss_spawned(_boss: Node2D, boss_id: String, _display_name: String, _max_health: float, _timestamp: float) -> void:
	note_sighting(String(FieldGuideCatalog.BOSS_ID_ALIASES.get(boss_id, boss_id)))


# --- UI ------------------------------------------------------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_parchment_theme() # dark ink on parchment (D166)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = UiPalette.with_alpha(UiPalette.DIM_TINT, DIM_ALPHA)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # nothing beneath may be clicked while a card is up
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.theme_type_variation = UiTheme.CARD
	_card.custom_minimum_size = Vector2(minf(CARD_WIDTH_PX, 760.0) if TouchUi.is_mobile_layout() else CARD_WIDTH_PX, 0.0)
	center.add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = UiTheme.vbox("M")
	_card.add_child(column)

	var ribbon := PanelContainer.new()
	ribbon.name = "NewRibbon"
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.add_theme_stylebox_override("panel", UiTheme.make_ribbon_box_from(DraftCardView.RIBBON_TEXTURES[ContractEnums.Rarity.Common], 0, 6))
	column.add_child(ribbon)
	var ribbon_label := Label.new()
	ribbon_label.text = tr("EXPL_NEW")
	ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon_label.custom_minimum_size = Vector2(240.0, 0.0)
	ribbon_label.add_theme_color_override("font_color", UiPalette.INK_PIXEL)
	ribbon_label.add_theme_constant_override("outline_size", 0)
	ribbon.add_child(ribbon_label)

	var top := HBoxContainer.new()
	top.theme_type_variation = UiTheme.hbox("L")
	column.add_child(top)
	var plate := PanelContainer.new()
	plate.name = "IconPlate"
	plate.add_theme_stylebox_override("panel", UiTheme.make_box(UiPalette.SURFACE, UiPalette.WOOD_BORDER, UiPalette.RADIUS_PANEL, UiPalette.BORDER_THICK, UiPalette.SPACE_S))
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(plate)
	_icon_rect = AbilityDisplay.make_icon_rect("", 96 if TouchUi.is_mobile_layout() else ICON_PX)
	plate.add_child(_icon_rect)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(names)
	_name_label = _make_text(UiTheme.HEADING)
	_name_label.name = "Name"
	names.add_child(_name_label)
	_kind_label = _make_text(UiTheme.DIM_PARCHMENT)
	_kind_label.name = "Kind"
	names.add_child(_kind_label)

	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.custom_minimum_size = Vector2(0.0, 0.0)
	column.add_child(_body_scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(body)
	_helps_row = _make_row(body, "Helps", tr("EXPL_HELPS"), UiPalette.SUCCESS_ON_PARCHMENT)
	_helps_text = _helps_row.get_node("Text") as Label
	_hurts_row = _make_row(body, "Hurts", tr("EXPL_HURTS"), UiPalette.DANGER_ON_PARCHMENT)
	_hurts_text = _hurts_row.get_node("Text") as Label
	_effect_label = _make_text(UiTheme.DIM_PARCHMENT)
	_effect_label.name = "Effect"
	body.add_child(_effect_label)

	var foot := HBoxContainer.new()
	foot.name = "Foot"
	foot.theme_type_variation = UiTheme.hbox("L")
	column.add_child(foot)
	_check = CheckBox.new()
	_check.name = "DontShowAgain"
	_check.text = tr("EXPL_DONT_SHOW")
	_check.focus_mode = Control.FOCUS_NONE # the highlight is driven by the movement-only contract
	_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_check.custom_minimum_size = TouchUi.touch_size(Vector2(0.0, 72.0))
	_check.toggled.connect(_on_check_toggled)
	for icon_name in ["checked", "checked_disabled"]:
		_check.add_theme_icon_override(icon_name, _check_icon(true))
	for icon_name in ["unchecked", "unchecked_disabled"]:
		_check.add_theme_icon_override(icon_name, _check_icon(false))
	foot.add_child(_check)
	var check_overlay: SelectableState = SelectableState.attach(_check, SelectableState.RibbonSide.RIGHT)
	check_overlay.externally_driven = true
	check_overlay.arrow_outside = false
	_got_it = Button.new()
	_got_it.name = "GotIt"
	_got_it.text = tr("EXPL_GOT_IT")
	_got_it.focus_mode = Control.FOCUS_NONE
	_got_it.custom_minimum_size = TouchUi.button_size(Vector2(280.0, 80.0))
	_got_it.add_theme_font_size_override("font_size", UiPalette.FONT_SIZE_VALUE)
	_got_it.pressed.connect(_on_got_it_pressed)
	foot.add_child(_got_it)
	var got_overlay: SelectableState = SelectableState.attach(_got_it, SelectableState.RibbonSide.RIGHT)
	got_overlay.externally_driven = true
	got_overlay.arrow_outside = false
	got_overlay.ring_anchor = Vector2(0.14, 0.5)
	got_overlay.ring_radius = HOLD_RING_RADIUS_PX
	got_overlay.set_show_word(false)

	_prompt_label = _make_text(UiTheme.DIM_PARCHMENT)
	_prompt_label.name = "Prompt"
	_prompt_label.text = tr("EXPL_PROMPT")
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_prompt_label)
	var guide_label := _make_text(UiTheme.DIM_PARCHMENT)
	guide_label.name = "GuideNote"
	guide_label.text = tr("EXPL_FIELD_GUIDE")
	guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(guide_label)


## A 36 px pixel check box (the theme's own is a few pixels wide): ink border, light fill; the
## checked one is green with a tick.
static func _check_icon(checked: bool) -> ImageTexture:
	var side: int = 36
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(UiPalette.INK_PIXEL)
	img.fill_rect(Rect2i(3, 3, side - 6, side - 6), UiPalette.SUCCESS if checked else UiPalette.PARCHMENT)
	if checked:
		for i in 7: # the tick: down-right then up-right, 5 px thick
			img.fill_rect(Rect2i(8 + i, 17 + i, 5, 5), UiPalette.INK_PIXEL)
		for i in 13:
			img.fill_rect(Rect2i(14 + i, 23 - i, 5, 5), UiPalette.INK_PIXEL)
	return ImageTexture.create_from_image(img)


func _make_text(variation: StringName) -> Label:
	var label := Label.new()
	if variation != &"":
		label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_row(parent: Container, row_name: String, word: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.theme_type_variation = UiTheme.hbox("M")
	parent.add_child(row)
	var key := Label.new()
	key.text = word
	key.theme_type_variation = UiTheme.VALUE
	key.add_theme_color_override("font_color", color)
	key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	key.custom_minimum_size = Vector2(230.0, 0.0)
	row.add_child(key)
	var text := _make_text(&"")
	text.name = "Text"
	row.add_child(text)
	return row


func _fill(entry: Dictionary) -> void:
	_name_label.text = String(entry["name"])
	_kind_label.text = FieldGuideCatalog.tab_name(int(entry["tab"]))
	_icon_rect.texture = AbilityDisplay.icon(String(entry["icon"]))
	_set_row(_helps_row, _helps_text, String(entry["helps"]))
	_set_row(_hurts_row, _hurts_text, String(entry["hurts"]))
	_effect_label.text = String(entry["effect"])
	_effect_label.visible = _effect_label.text != ""
	var cap: float = BODY_MAX_HEIGHT_COMPACT_PX if TouchUi.is_mobile_layout() else BODY_MAX_HEIGHT_PX
	_body_scroll.scroll_vertical = 0
	# Wrapped labels only know their height once laid out at the card's width: settle the scroll then.
	_body_scroll.custom_minimum_size.y = 0.0
	_fit_body(cap)


func _fit_body(cap: float) -> void:
	await get_tree().process_frame
	if _body_scroll == null or not is_instance_valid(_body_scroll):
		return
	_body_scroll.custom_minimum_size.y = minf((_body_scroll.get_child(0) as Control).get_combined_minimum_size().y, cap)


func _set_row(row: Control, text_label: Label, text: String) -> void:
	row.visible = text != ""
	text_label.text = text


func _refresh_highlight() -> void:
	var check_overlay: SelectableState = SelectableState.of(_check)
	var got_overlay: SelectableState = SelectableState.of(_got_it)
	if check_overlay != null:
		check_overlay.set_focused(_highlight == 0)
	if got_overlay != null:
		got_overlay.set_focused(_highlight == 1)


func _update_ring() -> void:
	var got_overlay: SelectableState = SelectableState.of(_got_it)
	if got_overlay != null:
		got_overlay.set_confirm_progress(clampf(_hold_progress / DraftController.HOLD_CONFIRM_SECONDS, 0.0, 1.0))


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _clear_edges() -> void:
	if _use_test_input:
		_test_just_pressed.clear()


# --- Test seams ------------------------------------------------------------------------------------------------

func get_check_box_for_test() -> CheckBox:
	return _check


func get_got_it_for_test() -> Button:
	return _got_it


func get_name_label_for_test() -> Label:
	return _name_label


func get_helps_text_for_test() -> String:
	return _helps_text.text if _helps_row.visible else ""


func get_hurts_text_for_test() -> String:
	return _hurts_text.text if _hurts_row.visible else ""


func get_effect_text_for_test() -> String:
	return _effect_label.text


func get_highlight_for_test() -> int:
	return _highlight


func is_lockout_elapsed_for_test() -> bool:
	return _lockout_elapsed


func get_hold_progress_for_test() -> float:
	return _hold_progress


func get_root_for_test() -> Control:
	return _root


func set_pause_authority_for_test(pa: Node) -> void:
	_pause_authority = pa


func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true


func tick_for_test(delta: float) -> void:
	_process(delta)


func skip_lockout_for_test() -> void:
	_time_since_open = DraftController.LOCKOUT_SECONDS
	_lockout_elapsed = true
	_hold_armed = true


func click_got_it_for_test() -> void:
	_on_got_it_pressed()

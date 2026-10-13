extends CanvasLayer
class_name EventDraftController
## UI half of the v1.0 run events (docs/32 §A; Register "v1.0 Run Events"):
## Opening Pick, Patron's Boon, Sanctuary and Blood Pact. It pops the next due
## event from `RunEvents`, shows it as a full-screen choice on the Draft's own
## card widget (`DraftCardView`), and hands the picked card back to `RunEvents`.
##
## ## Same input contract as the Level-Up Draft (docs/19 > "Upgrade Draft UI &
## Navigation")
## 0.4 s input lockout on open; left/right cycle on press with a 0.3 s repeat (wrap);
## hold up 1.0 s confirms, armed only once input has been neutral after the lockout;
## keys 1/2/3, the `confirm` action, a click on a card (a bare click elsewhere does
## nothing), and a touch tap (touch emulates the mouse). There is no Cancel and no
## Reroll. The constants are the Draft's own (`DraftController`), not a second
## copy; the polling below mirrors `DraftController._poll_*` because that
## controller's input code is private to its Level-Up state machine. Like it, this
## node is PROCESS_MODE_ALWAYS and times input with its own per-frame `delta`
## (SimClock is frozen under the pause it causes).
##
## ## Never on top of a Draft
## An event opens only while no Level-Up or War Chest Draft is showing or queued
## (`DraftController.is_busy()`) and nothing else (pause menu, results) holds the
## pause; it queues behind them. Pausing goes through PauseAuthority with the
## Draft's own reason, so the pause key is ignored while an event is up.

signal event_opened(kind: String)
signal event_closed(kind: String)

const REASON_EVENT: StringName = &"draft"
const DRAFT_CANVAS_LAYER: int = 20
const CARD_MIN_SIZE: Vector2 = Vector2(460, 440)
const CARD_MIN_SIZE_COMPACT: Vector2 = Vector2(460, 320)
const COMPACT_TOP_PX: float = 0.0 # D370: see DraftController.COMPACT_TOP_PX
const DESKTOP_TOP_PX: float = 80.0
const HOLD_RING_DIAMETER: float = 56.0
const DIM_ALPHA: float = 0.7 ## a touch above the Draft's 60%: the tint carries the mode
const FADE_SECONDS: float = 0.15

## Per-mode look: ribbon colour (DraftCardView ribbon rarity), dim tint behind the
## cards, and the title / subtitle accent colour. Distinct from a Level-Up Draft
## (which has no title plate and a neutral dim).
const MODE_STYLE: Dictionary = {
	RunEvents.KIND_OPENING: {"ribbon": ContractEnums.Rarity.Rare, "dim": Color(0.0, 0.07, 0.26), "accent": Color("8fd3ff"), "title": "EVENT_OPENING_TITLE"},
	RunEvents.KIND_PATRON: {"ribbon": ContractEnums.Rarity.Common, "dim": Color(0.17, 0.02, 0.30), "accent": Color("c9a7ff"), "title": "EVENT_PATRON_TITLE"},
	RunEvents.KIND_SANCTUARY: {"ribbon": ContractEnums.Rarity.Common, "dim": Color(0.24, 0.16, 0.0), "accent": Color("ffe28a"), "title": "EVENT_SANCTUARY_TITLE"},
	RunEvents.KIND_PACT: {"ribbon": ContractEnums.Rarity.Epic, "dim": Color(0.32, 0.0, 0.02), "accent": Color("ff7a7e"), "title": "EVENT_PACT_TITLE"},
}

@export var run_seed: int = 0

var run_events: RunEvents = null
var draft_controller: DraftController = null
var upgrade_system: UpgradeSystem = null
var wave_director: Object = null
## PT-UI (docs/33 A4): the first-encounter explainer shown over an event screen the first time it opens.
var explainers: ExplainerController = null:
	set(value):
		if explainers != null and explainers.explainer_closed.is_connected(_on_explainer_closed):
			explainers.explainer_closed.disconnect(_on_explainer_closed)
		explainers = value
		if explainers != null:
			explainers.explainer_closed.connect(_on_explainer_closed)
var _pause_authority: Node = PauseAuthority
var _sim_clock: Node = SimClock

var _offer: Dictionary = {}
var _kind: String = ""
var _showing: bool = false
var _highlighted_index: int = 0
var _cards_count: int = 0

var _time_since_open: float = 0.0
var _lockout_elapsed: bool = false
var _hold_up_armed: bool = false
var _hold_up_progress: float = 0.0
var _left_held: bool = false
var _left_repeat_timer: float = 0.0
var _right_held: bool = false
var _right_repeat_timer: float = 0.0
var _mouse_confirm_this_frame: bool = false

var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}

var _root: Control
var _dim: ColorRect
var _title_plate: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _badge_label: Label
var _card_row: HBoxContainer
var _fill_ring: DraftFillRing
var _how_to_pick_label: Label
var _card_views: Array[DraftCardView] = []
var _fade_tween: Tween = null


func _ready() -> void:
	layer = DRAFT_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


## Wires the collaborators (the integration calls this once; tests call it with fakes).
func setup(events: RunEvents, drafts: DraftController, upgrades: UpgradeSystem, director: Object = null) -> void:
	run_events = events
	draft_controller = drafts
	upgrade_system = upgrades
	wave_director = director


# --- Opening ------------------------------------------------------------------------

## Opens the next due event if nothing blocks it. Called every frame while idle, and
## once by the integration right after `RunEvents.begin_run()` so the Opening Pick
## pauses the run before the first tick.
func poll_open() -> bool:
	if _showing or run_events == null or not run_events.has_pending():
		return false
	if draft_controller != null and draft_controller.is_busy():
		return false
	if _pause_authority != null and not _pause_authority.get_active_reasons().is_empty():
		return false # the pause menu, results or a focus loss holds the pause
	return _open_next(false)


func _open_next(already_paused: bool) -> bool:
	while true:
		var event: Dictionary = run_events.pop_next(_sim_clock.now if _sim_clock != null else 0.0)
		if event.is_empty():
			return false
		var offer: Dictionary = run_events.build_offer(event)
		if (offer.get("cards", []) as Array).is_empty():
			continue # nothing to offer (every ability owned, pact pool empty): skip it
		_show(offer, already_paused)
		return true
	return false


func _show(offer: Dictionary, already_paused: bool) -> void:
	_offer = offer
	_kind = String(offer["kind"])
	_cards_count = (offer["cards"] as Array).size()
	_showing = true
	if not already_paused and _pause_authority != null:
		_pause_authority.push_reason_immediate(REASON_EVENT)
	_reset_input_state()
	_apply_mode_style()
	_build_cards()
	_kill_fade()
	_root.visible = true
	if DisplayServer.get_name() != "headless" and is_inside_tree():
		_root.modulate.a = 0.0
		_fade_tween = _root.create_tween()
		_fade_tween.tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
	else:
		_root.modulate.a = 1.0
	Sfx.play_ui.call_deferred("chest_open") # deferred: the Opening Pick opens inside the scene's own _ready
	event_opened.emit(_kind)
	if explainers != null:
		explainers.request(_kind) # the card opens over this screen, which waits for it (see _process)


func _close_and_resolve(index: int) -> void:
	var kind: String = _kind
	Sfx.play_ui("ui_confirm")
	if index >= 0 and index < _card_views.size():
		_card_views[index].flash_chosen() # PT-UI: the CHOSEN stamp, held while the screen fades
	run_events.resolve(_offer, index)
	_showing = false
	_offer = {}
	_hide_ui(SelectableState.CHOSEN_SECONDS)
	event_closed.emit(kind)
	# A further due event opens at once, still paused; otherwise the run resumes.
	if run_events.has_pending() and (draft_controller == null or not draft_controller.is_busy()) and _open_next(true):
		return
	if _pause_authority != null:
		_pause_authority.pop_reason_immediate(REASON_EVENT)
	if wave_director != null and wave_director.has_method(&"notify_draft_closed"):
		wave_director.notify_draft_closed(_sim_clock.now if _sim_clock != null else 0.0) # the Draft's 1.5 s grace period


# --- Per-frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _showing:
		poll_open()
		return
	if explainers != null and (explainers.is_showing() or explainers.get_queue().has(_kind)):
		_clear_edges()
		return # an explainer card is up (or about to be) over this screen: its input comes first
	_time_since_open += delta
	if not _lockout_elapsed:
		if _time_since_open >= DraftController.LOCKOUT_SECONDS:
			_lockout_elapsed = true
			if not _is_pressed(&"move_up"):
				_hold_up_armed = true
		_update_ring()
		_clear_edges()
		_mouse_confirm_this_frame = false
		return # input is locked out for the whole 0.4 s window
	_poll_cycle(delta)
	_poll_numbers()
	if _showing and _is_just_pressed(&"confirm") and not _mouse_confirm_this_frame:
		_confirm_highlighted()
	_poll_hold_up(delta)
	_update_ring()
	_clear_edges()
	_mouse_confirm_this_frame = false


func _input(event: InputEvent) -> void:
	if _showing and event is InputEventMouseButton and event.is_action_pressed(&"confirm"):
		_mouse_confirm_this_frame = true # a click confirms the card under it, not the highlighted one


## The explainer over this screen closed: the screen's own 0.4 s lockout starts now.
func _on_explainer_closed(_id: String) -> void:
	if _showing:
		_reset_input_state()
		_refresh_highlight()


func _confirm_highlighted() -> void:
	if not _showing or _highlighted_index < 0 or _highlighted_index >= _cards_count:
		return
	_close_and_resolve(_highlighted_index)


func _poll_hold_up(delta: float) -> void:
	if not _showing:
		return
	var pressed: bool = _is_pressed(&"move_up")
	if not _hold_up_armed:
		if not pressed:
			_hold_up_armed = true # neutral observed after the lockout
		return
	if pressed:
		_hold_up_progress += delta
		if _hold_up_progress >= DraftController.HOLD_CONFIRM_SECONDS:
			_hold_up_progress = 0.0
			_confirm_highlighted()
	else:
		_hold_up_progress = 0.0


func _poll_cycle(delta: float) -> void:
	var left_now: bool = _is_pressed(&"draft_cycle_left") or _is_pressed(&"move_left")
	var right_now: bool = _is_pressed(&"draft_cycle_right") or _is_pressed(&"move_right")
	if left_now and not _left_held:
		_cycle(-1)
		_left_repeat_timer = DraftController.CYCLE_REPEAT_SECONDS
	elif left_now and _left_held:
		_left_repeat_timer -= delta
		if _left_repeat_timer <= 0.0:
			_cycle(-1)
			_left_repeat_timer = DraftController.CYCLE_REPEAT_SECONDS
	_left_held = left_now
	if right_now and not _right_held:
		_cycle(1)
		_right_repeat_timer = DraftController.CYCLE_REPEAT_SECONDS
	elif right_now and _right_held:
		_right_repeat_timer -= delta
		if _right_repeat_timer <= 0.0:
			_cycle(1)
			_right_repeat_timer = DraftController.CYCLE_REPEAT_SECONDS
	_right_held = right_now


func _cycle(step: int) -> void:
	if _cards_count <= 0:
		return
	_highlighted_index = wrapi(_highlighted_index + step, 0, _cards_count)
	_refresh_highlight()
	Sfx.play_ui("ui_hover")


func _poll_numbers() -> void:
	for i in mini(_cards_count, 3):
		if _showing and _is_just_pressed(StringName("draft_select_%d" % (i + 1))):
			_highlighted_index = i
			_confirm_highlighted()
			return


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if not _lockout_elapsed or not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and index >= 0 and index < _cards_count:
		_highlighted_index = index
		_confirm_highlighted()


func _on_card_hovered(index: int) -> void:
	if _lockout_elapsed:
		_highlighted_index = index
		_refresh_highlight()


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


func _reset_input_state() -> void:
	_time_since_open = 0.0
	_lockout_elapsed = false
	_hold_up_armed = false
	_hold_up_progress = 0.0
	_left_held = false
	_right_held = false
	_left_repeat_timer = 0.0
	_right_repeat_timer = 0.0
	_highlighted_index = 0
	_mouse_confirm_this_frame = false


# --- UI ---------------------------------------------------------------------------------------

func _build_ui() -> void:
	UiStrings.ensure_registered()
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	# Below the HUD's top panels (the pact's badge line makes the column taller than a Draft's).
	_root.add_child(center)
	SafeArea.fit(center, Vector4(0.0, COMPACT_TOP_PX if TouchUi.is_mobile_layout() else DESKTOP_TOP_PX, 0.0, 0.0)) # D370: inside the safe area

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.theme_type_variation = UiTheme.vbox("XL")
	center.add_child(column)

	# Title plate: the mode's name on a ribbon, so an event never reads as a Level-Up.
	var plate_wrap := CenterContainer.new()
	plate_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate_wrap)
	_title_plate = PanelContainer.new()
	_title_plate.name = "TitlePlate"
	_title_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_wrap.add_child(_title_plate)
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.theme_type_variation = UiTheme.HUD_VALUE if TouchUi.is_mobile_layout() else UiTheme.HEADING # a phone has less height
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_plate.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.theme_type_variation = UiTheme.HUD_VALUE
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(1200.0 if not TouchUi.is_mobile_layout() else 900.0, 0.0)
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_subtitle_label)

	_badge_label = Label.new()
	_badge_label.name = "Badge"
	_badge_label.theme_type_variation = UiTheme.HUD_VALUE
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_badge_label)

	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.theme_type_variation = UiTheme.hbox("XXL")
	column.add_child(_card_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.theme_type_variation = UiTheme.hbox("L")
	column.add_child(bottom_row)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	_fill_ring.center_shape = UiShapeGlyph.Shape.TRIANGLE
	_fill_ring.custom_minimum_size = Vector2(HOLD_RING_DIAMETER, HOLD_RING_DIAMETER)
	bottom_row.add_child(_fill_ring)

	var hold_caption := Label.new()
	hold_caption.name = "HoldCaption"
	hold_caption.text = tr("DRAFT_HOLD_CAPTION")
	hold_caption.theme_type_variation = UiTheme.HUD_VALUE
	hold_caption.visible = not TouchUi.is_mobile_layout()
	hold_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(hold_caption)

	_how_to_pick_label = Label.new()
	_how_to_pick_label.name = "HowToPick"
	_how_to_pick_label.text = tr("DRAFT_HOW_TO_PICK")
	_how_to_pick_label.theme_type_variation = UiTheme.HUD_VALUE
	_how_to_pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_how_to_pick_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_how_to_pick_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if TouchUi.is_mobile_layout():
		_how_to_pick_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		bottom_row.add_child(_how_to_pick_label)
		bottom_row.move_child(_how_to_pick_label, 1)
	else:
		column.add_child(_how_to_pick_label)


func _apply_mode_style() -> void:
	var style: Dictionary = MODE_STYLE.get(_kind, MODE_STYLE[RunEvents.KIND_OPENING])
	var accent: Color = style["accent"]
	_dim.color = Color(style["dim"].r, style["dim"].g, style["dim"].b, DIM_ALPHA)
	_title_label.text = tr(String(style["title"]))
	var tex: Texture2D = DraftCardView.RIBBON_TEXTURES.get(int(style["ribbon"]), DraftCardView.RIBBON_TEXTURES[ContractEnums.Rarity.Common])
	_title_plate.add_theme_stylebox_override("panel", UiTheme.make_ribbon_box_from(tex, 64, 2 if TouchUi.is_mobile_layout() else 8))
	_subtitle_label.add_theme_color_override("font_color", accent)
	_subtitle_label.text = _subtitle_text()
	_subtitle_label.visible = not TouchUi.is_mobile_layout() # a phone has no height for it; the cards say it all
	_badge_label.text = _badge_text()
	_badge_label.visible = _badge_label.text != ""
	_badge_label.add_theme_color_override("font_color", UiPalette.ACCENT)


func _subtitle_text() -> String:
	match _kind:
		RunEvents.KIND_OPENING:
			return tr("EVENT_OPENING_SUB_ARMORY") if bool(_offer.get("armory", false)) else tr("EVENT_OPENING_SUB")
		RunEvents.KIND_PATRON:
			return tr("EVENT_PATRON_SUB")
		RunEvents.KIND_SANCTUARY:
			return tr("EVENT_SANCTUARY_SUB")
		RunEvents.KIND_PACT:
			var id: String = String(_offer.get("pact_id", ""))
			return tr("EVENT_PACT_SUB") % [pact_name(id), pact_effect(id)]
	return ""


func _badge_text() -> String:
	if _kind != RunEvents.KIND_PACT:
		return ""
	var parts: Array[String] = []
	if bool(_offer.get("flawless", false)):
		parts.append(tr("EVENT_PACT_FLAWLESS"))
	if bool(_offer.get("pactbound", false)):
		parts.append(tr("EVENT_PACT_PACTBOUND"))
	return "   ".join(parts)


func _build_cards() -> void:
	for child in _card_row.get_children():
		child.queue_free()
	_card_views.clear()
	var cards: Array = _offer["cards"]
	for i in cards.size():
		var card: Dictionary = cards[i]
		var view := DraftCardView.new()
		view.name = "Card%d" % i
		view.custom_minimum_size = DraftCardView.compact_card_size(get_window(), CARD_MIN_SIZE_COMPACT, cards.size()) if TouchUi.is_mobile_layout() else CARD_MIN_SIZE
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_card_row.add_child(view)
		_setup_card(view, card)
		view.mouse_entered.connect(_on_card_hovered.bind(i))
		view.gui_input.connect(_on_card_gui_input.bind(i))
		view.set_key_badge(i + 1)
		view.play_entrance(i * UiPalette.MOTION_FAST)
		_card_views.append(view)
	_refresh_highlight()


func _setup_card(view: DraftCardView, card: Dictionary) -> void:
	match String(card["type"]):
		"upgrade":
			var id: String = String(card["id"])
			var def: UpgradeDefinition = upgrade_system.get_definition(id) if upgrade_system != null else null
			if def == null:
				return
			var mult: float = float(card["multiplier"])
			view.setup(def, upgrade_system.get_current_rank(id), int(card["rarity"]), upgrade_system.get_honest_card_value(id, mult))
		"blessing":
			view.setup_event(_blessing_card_data(String(card["id"])))
		"pact":
			view.setup_event(_pact_card_data(card))


func _blessing_card_data(id: String) -> Dictionary:
	var data: Dictionary = {"ribbon_text": tr("EVENT_BLESSING"), "ribbon_rarity": ContractEnums.Rarity.Common}
	match id:
		RunEvents.SANCTUARY_MEND:
			data.merge({"header": tr("EVENT_HEADER_PLAYER"), "name": tr("SANCT_MEND_NAME"), "effect": tr("SANCT_MEND_DESC") % int(round(RunEvents.MEND_HEAL_FRACTION * 100.0)), "shape": UiShapeGlyph.Shape.HEART, "glyph_color": UiPalette.PLAYER, "player_frame": true, "icon": "mend"})
		RunEvents.SANCTUARY_RESTORE:
			data.merge({"header": tr("EVENT_HEADER_TOWER"), "name": tr("SANCT_RESTORE_NAME"), "effect": tr("SANCT_RESTORE_DESC") % int(round(RunEvents.RESTORE_HEAL_FRACTION * 100.0)), "shape": UiShapeGlyph.Shape.TOWER, "glyph_color": UiPalette.TOWER, "player_frame": false, "icon": "restore"})
		_:
			data.merge({"header": tr("EVENT_HEADER_BOTH"), "name": tr("SANCT_VALOR_NAME"), "effect": tr("SANCT_VALOR_DESC") % int(round(RunEvents.VALOR_DAMAGE_BONUS * 100.0)), "shape": UiShapeGlyph.Shape.ARROW, "glyph_color": UiPalette.GOLD, "player_frame": true, "icon": "valor"})
	return data


func _pact_card_data(card: Dictionary) -> Dictionary:
	var id: String = String(card["pact_id"])
	var option: String = String(card["option"])
	var data: Dictionary = {"ribbon_rarity": ContractEnums.Rarity.Epic, "ribbon_text": tr("EVENT_PACT_RIBBON"), "effect": "%s: %s" % [pact_name(id), pact_effect(id)], "icon": id}
	match option:
		RunEvents.OPTION_BLOOD:
			data.merge({"header": tr("PACT_HEADER_BLOOD"), "name": tr("PACT_OPT_BLOOD"), "cost": tr("PACT_COST_BLOOD") % int(card["amount"]), "shape": UiShapeGlyph.Shape.HEART, "glyph_color": UiPalette.DANGER, "player_frame": true})
		RunEvents.OPTION_TOWER:
			data.merge({"header": tr("PACT_HEADER_TOWER"), "name": tr("PACT_OPT_TOWER"), "cost": tr("PACT_COST_TOWER") % int(card["amount"]), "shape": UiShapeGlyph.Shape.TOWER, "glyph_color": UiPalette.TOWER, "player_frame": false})
		_:
			data.merge({"header": tr("PACT_HEADER_REFUSE"), "name": tr("PACT_OPT_REFUSE"), "effect": tr("PACT_REFUSE_DESC"), "cost": tr("PACT_COST_NONE"), "cost_color": UiPalette.TEXT_ON_PARCHMENT, "shape": UiShapeGlyph.Shape.LOCK, "glyph_color": UiPalette.TEXT_DIM, "player_frame": true, "ribbon_text": tr("EVENT_PACT_REFUSE_RIBBON"), "ribbon_rarity": ContractEnums.Rarity.Rare, "icon": "blood_pact", "dim_icon": true}, true)
	return data


static func pact_name(id: String) -> String:
	return TranslationServer.translate(StringName("PACT_%s_NAME" % id.to_upper()))


## The pact's effect sentence, with its numbers filled from the RunEvents constants.
static func pact_effect(id: String) -> String:
	var t: String = TranslationServer.translate(StringName("PACT_%s_DESC" % id.to_upper()))
	match id:
		RunEvents.PACT_SECOND_LIFE:
			return t % int(round(Player.SECOND_LIFE_SURVIVE_FRACTION * 100.0))
		RunEvents.PACT_TWIN_STRING:
			return t % RunEvents.TWIN_STRING_EXTRA_ARROWS
		RunEvents.PACT_BLOODLUST:
			return t % int(RunEvents.BLOODLUST_HEAL_PER_KILL)
		RunEvents.PACT_SIEGE_BREAKER:
			return t % int(round(RunEvents.SIEGE_BREAKER_TOWER_DAMAGE_BONUS * 100.0))
		RunEvents.PACT_ETERNAL_FLAME:
			return t % [int(RunEvents.ETERNAL_FLAME_BURN_DPS_FACTOR), int(round((RunEvents.ETERNAL_FLAME_BURN_DURATION_FACTOR - 1.0) * 100.0))]
	return t


func _refresh_highlight() -> void:
	for i in _card_views.size():
		_card_views[i].set_highlighted(i == _highlighted_index)


func _update_ring() -> void:
	var progress: float = clampf(_hold_up_progress / DraftController.HOLD_CONFIRM_SECONDS, 0.0, 1.0)
	if _fill_ring != null:
		_fill_ring.progress = progress
	for i in _card_views.size(): # PT-UI: the ring also draws ON the card being confirmed
		_card_views[i].set_confirm_progress(progress if i == _highlighted_index else 0.0)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _hide_ui(hold_seconds: float = 0.0) -> void:
	_kill_fade()
	if DisplayServer.get_name() != "headless" and is_inside_tree() and _root.visible:
		_fade_tween = _root.create_tween()
		_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if hold_seconds > 0.0:
			_fade_tween.tween_interval(hold_seconds)
		_fade_tween.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
		_fade_tween.tween_callback(_finish_hide)
	else:
		_root.visible = false


func _finish_hide() -> void:
	if not _showing:
		_root.visible = false


# --- Queries and test seams ------------------------------------------------------------

func is_showing() -> bool:
	return _showing


func get_kind() -> String:
	return _kind


func get_offer() -> Dictionary:
	return _offer


func get_card_views_for_test() -> Array[DraftCardView]:
	return _card_views


func get_title_text_for_test() -> String:
	return _title_label.text if _title_label != null else ""


func get_subtitle_text_for_test() -> String:
	return _subtitle_label.text if _subtitle_label != null else ""


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func is_lockout_elapsed_for_test() -> bool:
	return _lockout_elapsed


func is_hold_up_armed_for_test() -> bool:
	return _hold_up_armed


func get_hold_progress_for_test() -> float:
	return _hold_up_progress


func set_pause_authority_for_test(pa: Node) -> void:
	_pause_authority = pa


func set_sim_clock_for_test(clock: Node) -> void:
	_sim_clock = clock


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


func simulate_card_click_for_test(index: int) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	_on_card_gui_input(mb, index)


func confirm_choice_for_test(index: int) -> void:
	_highlighted_index = index
	_confirm_highlighted()


func skip_lockout_for_test() -> void:
	_lockout_elapsed = true
	_hold_up_armed = true

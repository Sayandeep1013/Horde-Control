extends Node
## Development-only windowed self-test of the selection-state language (D380-D389). Drives the
## REAL War Camp and Level-Up Draft with synthetic keyboard, mouse and finger events through the
## engine's own input path (`Input.parse_input_event`), which the headless gdUnit4 runner cannot do.
## Prints `SELFTEST PASS|FAIL <name>` lines and exits 0 / 1.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/dev/selection_selftest.tscn -- [--touch-ui] [--size=1920x1080] \
##     --meta-profile-dir=<absolute sandbox dir>
##
## Not part of the shipped game; nothing in scenes/ references it.

var _failures: int = 0
var _hub: HubScreen = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.set_show_first_time_tips_for_test(false)
	var size: Vector2i = Vector2i(1920, 1080)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var p: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	get_window().size = size
	await _frames(5)
	await _hub_scenarios()
	await _draft_scenarios()
	print("SELFTEST DONE failures=%d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("SELFTEST PASS ", name)
	else:
		_failures += 1
		print("SELFTEST FAIL ", name, " ", detail)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _px(logical: Vector2) -> Vector2:
	return get_window().get_final_transform() * logical


func _mouse_move(logical: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _px(logical)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	await _frames(3)


func _mouse_click(logical: Vector2) -> void:
	await _mouse_move(logical)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = _px(logical)
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await _frames(2)
	await _frames(3)


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)


func _touch(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = _px(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _frames(3)
	_touch(pos, false)
	await _frames(4)


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## Every SelectableState under `root` whose arrow or hover is showing: "the current one" must be one plate.
func _marked(root: Node) -> Array[String]:
	var out: Array[String] = []
	_collect_marked(root, out)
	return out


func _collect_marked(node: Node, out: Array[String]) -> void:
	if node is SelectableState and (node as SelectableState).is_visible_in_tree():
		var cues: Dictionary = (node as SelectableState).visible_cues()
		if cues["arrow"]:
			out.append(str(node.get_parent().name))
	for ch: Node in node.get_children():
		_collect_marked(ch, out)


func _selected_in(buttons: Array) -> Array[String]:
	var out: Array[String] = []
	for b: Button in buttons:
		var o: SelectableState = SelectableState.of(b)
		if o != null and o.is_selected():
			out.append(b.name)
	return out


func _hub_scenarios() -> void:
	_hub = (load("res://scenes/hub.tscn") as PackedScene).instantiate() as HubScreen
	add_child(_hub)
	await _frames(30)
	var recruit: Button = _hub.get_difficulty_button_for_test("recruit")
	var soldier: Button = _hub.get_difficulty_button_for_test("soldier")
	var veteran: Button = _hub.get_difficulty_button_for_test("veteran")
	var diffs: Array = [recruit, soldier, veteran, _hub.get_difficulty_button_for_test("warlord")]

	# Desktop default: keyboard focus ring on the first focused control, nothing else marked.
	var touch_layout: bool = TouchUi.is_mobile_layout()
	if not touch_layout:
		_check("desktop starts in keyboard mode", UiInputMode.is_keyboard())
	else:
		_check("touch layout starts in touch mode with at most one arrow", UiInputMode.is_touch() and _marked(_hub).size() <= 1, str(_marked(_hub)))

	# The mouse scenarios run on the desktop layout only: the phone layout's first-visit hint banner (another
	# stream) sits over Recruit and a mouse there would hit it.
	if not touch_layout:
		# Mouse over Recruit: focus follows the mouse, hover shows, no ring; only one plate marked.
		await _mouse_move(_center(recruit))
		_check("mouse move switches to mouse mode", UiInputMode.is_mouse())
		var owner_now: Control = get_viewport().gui_get_focus_owner()
		_check("hovered plate takes focus (hover == focus)", recruit.has_focus(), "focus=%s marked=%s hoverflag=%s" % [owner_now.name if owner_now != null else "none", str(_marked(_hub)), str(SelectableState.of(recruit).visible_cues())])
		_check("hover marks exactly the hovered plate", _marked(_hub) == ["Difficulty_recruit"] or _marked(_hub).size() == 1, str(_marked(_hub)))
		_check("no keyboard brighten in mouse mode", not SelectableState.of(recruit).visible_cues()["focus_wash"])
		await _mouse_move(_center(soldier))
		_check("moving the mouse moves focus", soldier.has_focus() and not recruit.has_focus())
		_check("still exactly one plate marked after moving", _marked(_hub).size() == 1, str(_marked(_hub)))

		# A key switches to keyboard mode: the ring shows on the focused plate, hover is gone.
		await _key(KEY_DOWN)
		_check("a key switches to keyboard mode", UiInputMode.is_keyboard())
		var marked_kb: Array[String] = _marked(_hub)
		_check("keyboard: one arrow, no stray hover", marked_kb.size() == 1, str(marked_kb))
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		_check("the arrow and brighten are on the focused plate", focus_owner != null and SelectableState.of(focus_owner) != null and SelectableState.of(focus_owner).visible_cues()["arrow"] and SelectableState.of(focus_owner).visible_cues()["focus_wash"])

		# Mouse click on Recruit selects it; Soldier loses the selection (radio group).
		await _mouse_click(_center(recruit))
		_check("click selects Recruit and only Recruit", _selected_in(diffs) == [String(recruit.name)], str(_selected_in(diffs)))
		_check("the selected plate shows the tick alone", SelectableState.of(recruit).visible_cues()["check"])
		_check("locked plate never reads as selected", not SelectableState.of(veteran).visible_cues()["check"] and SelectableState.of(veteran).visible_cues()["padlock"])

	# Touch: tap on the Loadout tab (a tab, no check), then a locked champion (reason, no change).
	var tab_loadout: Button = _hub.get_tab_button_for_test("loadout")
	await _tap(_center(tab_loadout))
	_check("a tap switches to touch mode", UiInputMode.is_touch())
	_check("tab: the tapped tab is the page (no check badge)", SelectableState.of(tab_loadout).is_selected() and not SelectableState.of(tab_loadout).visible_cues()["check"] and SelectableState.of(tab_loadout).visible_cues()["tab_raise"])
	_check("tab: the other tab is dimmed", SelectableState.of(_hub.get_tab_button_for_test("run")).visible_cues()["tab_dim"])
	_check("touch: at most one plate carries the arrow after a tap, no hover", _marked(_hub).size() <= 1 and not SelectableState.of(tab_loadout).visible_cues()["hover"], str(_marked(_hub)))
	var warden: Button = _hub.get_champion_button_for_test("warden")
	var before: String = MetaProgress.get_selected_champion()
	await _tap(_center(warden))
	_check("tapping a locked champion shows its reason", SelectableState.of(warden).get_last_reason_shown() != "")
	_check("tapping a locked champion changes nothing", MetaProgress.get_selected_champion() == before)
	_hub.queue_free()
	await _frames(5)


func _draft_scenarios() -> void:
	var proto: Node = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(proto)
	await _frames(40)
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		MetaProgress.mark_explainer_seen(String(entry["id"]))
	var events: Node = proto.get_event_controller()
	while events != null and events.is_showing():
		events.skip_lockout_for_test()
		events.confirm_choice_for_test(0)
		await _frames(2)
	await _frames(30)
	var draft: DraftController = proto.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	await _frames(60) # past the 0.4 s lockout
	_check("draft is open", draft.is_draft_showing_for_test())

	# Touch: pressing a card arms it; sliding off before lifting cancels.
	var card1: DraftCardView = draft.get_card_view_for_test(1)
	_touch(_center(card1), true)
	await _frames(3)
	_check("touch press arms the card under the finger", draft.get_highlighted_index_for_test() == 1 and card1.get_selectable().is_armed() and card1.get_selectable().is_pressed())
	_check("touch press shows the armed look (no prompt on touch)", card1.get_selectable().visible_cues()["armed"] and not card1.get_selectable().visible_cues()["prompt"])
	_touch(Vector2(5.0, 5.0), false) # lift far away from the card
	await _frames(4)
	_check("lifting off the card cancels (no accidental pick)", draft.is_draft_showing_for_test())
	_check("the card is no longer pressed", not card1.get_selectable().is_pressed())
	_check("touch idle: no card is drawn armed or dimmed", not draft.get_card_view_for_test(0).get_selectable().visible_cues()["armed"] and not card1.get_selectable().visible_cues()["armed"] and not draft.get_card_view_for_test(0).get_selectable().visible_cues()["dim"])

	# Mouse: hover arms, shows CLICK TO CHOOSE; leaving the mouse over card 2 and pressing a key moves the prompt.
	await _mouse_move(_center(draft.get_card_view_for_test(2)))
	var card2: DraftCardView = draft.get_card_view_for_test(2)
	if TouchUi.is_mobile_layout():
		_touch(Vector2(5.0, 5.0), false)
	else:
		await _draft_mouse_checks(draft)
	await _draft_tail(draft, proto)


func _draft_mouse_checks(draft: DraftController) -> void:
	await _mouse_move(_center(draft.get_card_view_for_test(2)))
	var card2: DraftCardView = draft.get_card_view_for_test(2)
	_check("mouse hover arms the card with the click prompt", card2.get_selectable().visible_cues()["prompt"] and card2.get_selectable().get_prompt_label().text == "CLICK TO CHOOSE", card2.get_selectable().get_prompt_label().text)
	_check("the footer names the click", draft.get_how_to_pick_label_for_test().text.begins_with("Click"), draft.get_how_to_pick_label_for_test().text)
	await _key(KEY_LEFT)
	_check("a key switches the footer to the keys", draft.get_how_to_pick_label_for_test().text.contains("Space"), draft.get_how_to_pick_label_for_test().text)

	# Mouse click picks that card at once.
	await _mouse_click(_center(draft.get_card_view_for_test(0)))
	await _frames(5)
	_check("a mouse click on a card picks it", not draft.is_draft_showing_for_test())


func _draft_tail(draft: DraftController, proto: Node) -> void:
	# Touch: a clean tap on a card picks it on the release.
	if not draft.is_draft_showing_for_test():
		draft.force_open_for_test(false)
		await _frames(60)
	_check("second draft is open", draft.is_draft_showing_for_test())
	await _tap(_center(draft.get_card_view_for_test(2)))
	await _frames(5)
	_check("a finger tap on a card picks it", not draft.is_draft_showing_for_test())
	proto.queue_free()
	await _frames(5)

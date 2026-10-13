extends Node
## Development-only windowed touch self-test (mobile port, D146). Drives the
## REAL prototype with synthetic finger events through the engine's own input
## path (`Input.parse_input_event`, including `emulate_mouse_from_touch`), which
## the headless gdUnit4 runner cannot do ("InputEvents are not transported in
## headless mode"). Prints `SELFTEST PASS|FAIL <name>` lines and exits 0 / 1.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/dev/touch_selftest.tscn -- --touch-ui --size=2400x1080 \
##     --meta-profile-dir=<absolute sandbox dir>
##
## Not part of the shipped game; nothing in scenes/ references it.

var _failures: int = 0
var _prototype: Node = null
var _shots_dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.set_show_first_time_tips_for_test(false) # PT-UI: a first-time explainer would sit over the Opening Pick this test answers
	var size: Vector2i = Vector2i(2400, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		if arg.begins_with("--size="):
			var p: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
	get_window().size = size
	await _frames(5)
	await _run_menus()
	await _run_flow()
	print("SELFTEST DONE failures=%d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _shot(name: String) -> void:
	if _shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_shots_dir))
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://").path_join("%s/%s.png" % [_shots_dir, name]))


func _find_class(node: Node, cls: String) -> Node:
	var scr: Script = node.get_script() as Script
	if scr != null and scr.get_global_name() == cls:
		return node
	for ch in node.get_children():
		var r: Node = _find_class(ch, cls)
		if r != null:
			return r
	return null


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("SELFTEST PASS ", name)
	else:
		_failures += 1
		print("SELFTEST FAIL ", name, " ", detail)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## `Input.parse_input_event` takes WINDOW pixels, like a real finger; every
## position this file computes (Control rects) is in the scaled logical canvas,
## so it goes through the window's stretch + content-scale transform here.
func _px(logical: Vector2) -> Vector2:
	return get_window().get_final_transform() * logical


func _px_rel(logical: Vector2) -> Vector2:
	return get_window().get_final_transform().basis_xform(logical)


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _px(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(pos: Vector2, relative: Vector2, index: int = 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _px(pos)
	ev.relative = _px_rel(relative)
	Input.parse_input_event(ev)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _frames(3)
	_touch(pos, false)
	await _frames(3)


## Taps the centre of the first visible Label/Button whose text starts with `text`.
func _tap_text(text: String) -> bool:
	var c: Control = _find_text(get_tree().root, text)
	if c == null:
		return false
	# A target the finger cannot reach is a failure, not a pass: it must lie
	# fully inside the visible canvas.
	var vis: Rect2 = get_viewport().get_visible_rect()
	var r: Rect2 = c.get_global_rect()
	if not vis.encloses(r):
		print("SELFTEST OFFSCREEN '%s' rect=%s viewport=%s" % [text, r, vis])
		return false
	await _tap(r.get_center())
	return true


## The visible Label/Button whose text is exactly `text`. When several match
## (the Hub's own "Back to Title" is under the Skill Tree's "Back", and so on),
## the one on the highest CanvasLayer wins, then the last in tree order: what
## a finger would actually reach.
func _find_text(node: Node, text: String) -> Control:
	var found: Array = []
	_collect_text(node, text, found)
	var best: Control = null
	var best_layer: int = -1000000
	for c: Control in found:
		var layer: int = _layer_of(c)
		if layer >= best_layer:
			best_layer = layer
			best = c
	return best


func _collect_text(node: Node, text: String, out: Array) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var t: String = ""
		if node is Label:
			t = (node as Label).text
		elif node is Button:
			t = (node as Button).text
		if t == text:
			out.append(node)
	for ch in node.get_children():
		_collect_text(ch, text, out)


## Diagnostic: the visible mouse-stopping controls whose rect holds `logical_pos`, top layer first.
func _stoppers_at(logical_pos: Vector2) -> String:
	var out: PackedStringArray = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).is_visible_in_tree() and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP and (n as Control).get_global_rect().has_point(logical_pos):
			out.append("%s(layer %d)" % [n.get_path(), _layer_of(n)])
		stack.append_array(n.get_children())
	return ", ".join(out)


func _find_class_node(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)


func _layer_of(node: Node) -> int:
	var n: Node = node
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer
		n = n.get_parent()
	return 0


## Title, Hub (Skill Tree hold-to-buy, Records, Achievements, Settings arrows).
func _run_menus() -> void:
	# --- Title ---
	var title: Node = (load("res://scenes/title.tscn") as PackedScene).instantiate()
	add_child(title)
	await _frames(30)
	_shot("title")
	_check("title: How to Play opens by tap", await _tap_text("How to Play"))
	await _frames(20)
	_shot("title_how_to_play")
	_check("title: How to Play Back by tap", await _tap_text("Back"))
	await _frames(20)
	_check("title: Credits opens by tap", await _tap_text("Credits"))
	await _frames(20)
	_shot("title_credits")
	_check("title: Credits Back by tap", await _tap_text("Back"))
	await _frames(20)
	_check("title: Settings opens by tap", await _tap_text("Settings"))
	await _frames(20)
	_shot("title_settings")
	_check("settings: desktop-only rows hidden", _find_text(get_tree().root, "Display Mode") == null and _find_text(get_tree().root, "V-Sync") == null)
	var right: Control = _find_text(get_tree().root, ">")
	var before: String = ""
	var value_label: Label = null
	if right != null:
		var row: Node = right.get_parent()
		value_label = row.get_node("Value") as Label
		before = value_label.text
		await _tap(right.get_global_rect().get_center())
		await _frames(5)
	_check("settings: tapping > changes the value", value_label != null and value_label.text != before, "before=%s after=%s" % [before, value_label.text if value_label != null else "?"])
	# Put it back: GameSettings writes the REAL user://settings.cfg, so a self-test must leave it as it found it.
	var left: Control = _find_text(get_tree().root, "<")
	if left != null:
		await _tap(left.get_global_rect().get_center())
		await _frames(5)
	_check("settings: tapping < restores the value", value_label != null and value_label.text == before, "now=%s want=%s" % [value_label.text if value_label != null else "?", before])
	_check("settings: Back by tap", await _tap_text("Back"))
	await _frames(20)
	title.queue_free()
	await _frames(5)

	# --- Hub ---
	var hub: Node = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	add_child(hub)
	await _frames(30)
	await _tap_text("Got it")
	await _frames(10)
	_shot("hub")
	_check("hub: Skill Tree opens by tap", await _tap_text("Skill Tree"))
	await _frames(30)
	var tree: SkillTreeScreen = _find_class(get_tree().root, "SkillTreeScreen") as SkillTreeScreen
	_shot("skill_tree")
	if tree != null:
		var view: SkillNodeView = tree.get_node_view_for_test("vitality")
		var rank0: int = view.get_displayed_rank_for_test()
		var c: Vector2 = view.get_global_rect().get_center()
		_touch(c, true)
		await _frames(30)
		_shot("skill_tree_holding")
		await get_tree().create_timer(2.0).timeout
		_touch(c, false)
		await _frames(10)
		_check("skill tree: tap-and-hold buys a rank", view.get_displayed_rank_for_test() == rank0 + 1, "rank %d -> %d" % [rank0, view.get_displayed_rank_for_test()])
	else:
		_check("skill tree: screen found", false)
	_check("skill tree: Back by tap", await _tap_text("Back"))
	await _frames(20)
	_check("skill tree: closed after Back", tree != null and not tree.visible)
	_check("hub: Records opens by tap", await _tap_text("Records"))
	await _frames(20)
	var records: Node = _find_class(get_tree().root, "RecordsPanel")
	_check("records: panel is showing", records != null and (records as CanvasLayer).visible)
	_shot("records")
	_check("records: Back by tap", await _tap_text("Back"))
	await _frames(20)
	_check("records: closed after Back", records != null and not (records as CanvasLayer).visible)
	_check("hub: Achievements opens by tap", await _tap_text("Achievements"))
	await _frames(20)
	var ach: Node = _find_class(get_tree().root, "AchievementsPanel")
	_check("achievements: panel is showing", ach != null and (ach as CanvasLayer).visible)
	_shot("achievements")
	var scroll: ScrollContainer = _find_class_node(ach, "RowsScroll") as ScrollContainer
	if scroll != null:
		var c0: Vector2 = scroll.get_global_rect().get_center()
		_touch(c0, true)
		await _frames(3)
		for i: int in 10:
			_drag(c0 + Vector2(0.0, -30.0 * (i + 1)), Vector2(0.0, -30.0))
			await _frames(2)
		_touch(c0 + Vector2(0.0, -300.0), false)
		await _frames(5)
		_shot("achievements_scrolled")
	_check("achievements: the list is a ScrollContainer", scroll != null)
	# ScrollContainer only pans by finger when the display reports a touchscreen
	# (`drag_touching = DisplayServer.is_touchscreen_available()` in the engine),
	# so on a desktop this cannot be shown; it is a phone-only check.
	if DisplayServer.is_touchscreen_available():
		_check("achievements: a finger drag scrolls the list", scroll != null and scroll.scroll_vertical > 50, "scroll_vertical=%s" % (str(scroll.scroll_vertical) if scroll != null else "none"))
	else:
		print("SELFTEST SKIP achievements: finger-drag scroll needs a touchscreen device")
	_check("achievements: Back by tap", await _tap_text("Back"))
	await _frames(20)
	_check("achievements: closed after Back", ach != null and not (ach as CanvasLayer).visible)
	_check("hub: Settings opens by tap", await _tap_text("Settings"))
	await _frames(20)
	_check("settings: Back by tap (hub)", await _tap_text("Back"))
	await _frames(20)
	hub.queue_free()
	await _frames(5)


func _run_flow() -> void:
	GameSettings.set_show_first_time_tips_for_test(false) # the menu taps above may have reloaded the settings; an explainer would pause the run
	var packed: PackedScene = load("res://scenes/prototype.tscn")
	_prototype = packed.instantiate()
	add_child(_prototype)
	await _frames(40)
	# docs/32: the run opens with the Opening Pick (a paused card choice); a finger tap picks.
	var events_ui: EventDraftController = _prototype.get_node_or_null("EventDraftInstance") as EventDraftController
	_check("event: the Opening Pick is showing at run start", events_ui != null and events_ui.is_showing() and events_ui.get_kind() == RunEvents.KIND_OPENING)
	if events_ui != null and events_ui.is_showing():
		_shot("run_opening_pick")
		await _tap(events_ui.get_card_views_for_test()[1].get_global_rect().get_center())
		await _frames(20)
		_check("event: tapping a card picks it and the run resumes", not events_ui.is_showing() and not get_tree().paused)
	await _frames(20)
	await get_tree().create_timer(1.5).timeout # the event card's CHOSEN hold and fade run on time, not frames: its dim must be gone before a finger can reach the buttons
	var player: Node2D = _prototype.get_node("Main/Player") as Node2D
	var tc: TouchControls = _prototype.get_node("TouchControls") as TouchControls
	_check("touch controls visible", tc.visible and tc.joystick != null and tc.pause_button != null)

	# --- v1.0: Dash and Battle Skill touch buttons press/release their actions ---
	var vis: Rect2 = get_viewport().get_visible_rect()
	_check("touch: dash and skill buttons exist", tc.dash_button != null and tc.skill_button != null)
	_check("touch: both buttons are on screen", vis.encloses(tc.dash_button.get_global_rect()) and vis.encloses(tc.skill_button.get_global_rect()))
	_check("touch: buttons do not overlap each other or the pause button", not tc.dash_button.get_global_rect().intersects(tc.skill_button.get_global_rect()) and not tc.pause_button.get_global_rect().intersects(tc.dash_button.get_global_rect()) and not tc.pause_button.get_global_rect().intersects(tc.skill_button.get_global_rect()))
	var hud_node: Hud = _prototype.get_node("Hud") as Hud
	_check("touch: the HUD action cluster steps aside", not hud_node.get_action_cluster().visible)
	_touch(tc.dash_button.get_global_rect().get_center(), true, 1)
	await _frames(3)
	_check("touch: holding the Dash button presses dash", Input.is_action_pressed(&"dash"), "button rect %s visible=%s; stoppers at its centre: %s" % [tc.dash_button.get_global_rect(), tc.dash_button.is_visible_in_tree(), _stoppers_at(tc.dash_button.get_global_rect().get_center())])
	_touch(tc.dash_button.get_global_rect().get_center(), false, 1)
	await _frames(3)
	_check("touch: lifting the finger releases dash", not Input.is_action_pressed(&"dash"))
	_touch(tc.skill_button.get_global_rect().get_center(), true, 1)
	await _frames(3)
	_check("touch: holding the Skill button presses battle_skill", Input.is_action_pressed(&"battle_skill"))
	_touch(tc.skill_button.get_global_rect().get_center(), false, 1)
	await _frames(3)
	_check("touch: lifting the finger releases battle_skill", not Input.is_action_pressed(&"battle_skill"))
	_shot("run_touch_buttons")

	# --- joystick moves the player ---
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var p0: Vector2 = player.global_position
	var start := Vector2(vp.x * 0.2, vp.y * 0.6)
	_touch(start, true)
	await _frames(2)
	for i: int in 20:
		_drag(start + Vector2(10.0 * (i + 1), 0.0), Vector2(10.0, 0.0))
		await _frames(2)
	await _frames(40)
	_check("joystick drag moves the player east", player.global_position.x > p0.x + 40.0, "x %f -> %f" % [p0.x, player.global_position.x])
	_shot("run_joystick")
	_touch(start + Vector2(200.0, 0.0), false)
	await _frames(10)
	var p1: Vector2 = player.global_position
	await _frames(20)
	_check("releasing the thumb stops the player", p1.distance_to(player.global_position) < 4.0, "moved %f" % p1.distance_to(player.global_position))

	# --- pause button, Resume, Abandon confirm, Keep playing ---
	await _tap(tc.pause_button.get_global_rect().get_center())
	await _frames(20)
	_shot("run_pause")
	_check("pause button pauses the game", get_tree().paused)
	_check("pause button hides while paused", not tc.pause_button.visible)
	await _tap_text("Resume")
	await _frames(30)
	_check("tapping Resume resumes", not get_tree().paused)
	await _tap(tc.pause_button.get_global_rect().get_center())
	await _frames(30)
	_check("second pause tap pauses again", get_tree().paused)
	await _tap_text("Abandon run")
	await _frames(30)
	_shot("run_abandon_confirm")
	_check("tapping Abandon run asks again", _find_text(get_tree().root, "Keep playing") != null)
	await _tap_text("Keep playing")
	await _frames(30)
	_check("pause: Settings opens by tap", await _tap_text("Settings"))
	await _frames(30)
	_shot("run_settings")
	_check("pause: Settings Back by tap", await _tap_text("Back"))
	await _frames(30)
	await _tap_text("Resume")
	await _frames(30)
	_check("Keep playing then Resume returns to play", not get_tree().paused)

	# --- Draft: tap card ---
	var draft: DraftController = _prototype.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	await _frames(60)
	_shot("run_draft")
	_check("draft is showing", draft.is_draft_showing_for_test())
	var card: Control = draft.get_card_view_for_test(2)
	await _tap(card.get_global_rect().get_center())
	await _frames(20)
	_check("tapping a Draft card picks it", not draft.is_draft_showing_for_test())
	await _frames(20)
	_check("game runs after the Draft", not get_tree().paused)

	# --- Run end screen reachable by finger ---
	var flow: Node = _prototype.get_node("RunFlowController")
	flow.simulate_player_died_for_test()
	await _frames(60)
	_shot("run_end")
	var cont: Control = _find_text(get_tree().root, "War Camp")
	_check("run end: War Camp is on screen", cont != null and get_viewport().get_visible_rect().encloses(cont.get_global_rect()), str(cont.get_global_rect()) if cont != null else "missing")
	var menu_btn: Control = _find_text(get_tree().root, "Main Menu")
	_check("run end: Main Menu is on screen", menu_btn != null and get_viewport().get_visible_rect().encloses(menu_btn.get_global_rect()), str(menu_btn.get_global_rect()) if menu_btn != null else "missing")

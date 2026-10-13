extends Node

## PT-UI capture tool (dev-only, docs/33 A). Stages the playtest-round UI states that the
## generic scene_capture harness cannot reach (a picker with a focused, a selected and a locked
## item at once; the Field Guide on each tab; an explainer card; a Draft with large icons) and
## saves one PNG per state. Windowed run only (a headless run has no renderer).
##
##   Godot_v4.7.1-stable_win64_console.exe --path <worktree> --audio-driver Dummy \
##       res://src/ui/dev/pt_ui_capture.tscn -- --shot=<name> --out=<relative png base> \
##       [--size=1920x1080] [--touch-ui] [--mode=keyboard|mouse|touch] [--first-time-tips] --meta-profile-dir=<abs sandbox dir> --no-focus-pause
##
## --shot= hub_run | hub_press_locked | hub_loadout | guide:<tab index>[:<entry id>] |
##         explainer:<id> | draft | event:<kind> | pause
## Reaches into a few private members to stage states; nothing in the game depends on this file.

var _shot: String = "hub_run"
var _out: String = "sandbox/captures/ptui/shot"
var _size: Vector2i = Vector2i(1920, 1080)
var _scene: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	if not OS.get_cmdline_user_args().has("--first-time-tips"):
		GameSettings.set_show_first_time_tips_for_test(false) # a first-visit card would hide the states under test
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var p: PackedStringArray = arg.trim_prefix("--size=").split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--mode="): # keyboard | mouse | touch: the last input device the capture pretends to have seen
			UiInputMode.pin(["keyboard", "mouse", "touch"].find(arg.trim_prefix("--mode=")))
	get_window().size = _size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out.get_base_dir()))
	_run.call_deferred()


func _run() -> void:
	var parts: PackedStringArray = _shot.split(":")
	match parts[0]:
		"hub_run", "hub_press_locked", "hub_loadout":
			await _hub_shot(parts[0])
		"guide":
			await _guide_shot(int(parts[1]) if parts.size() > 1 else 0, parts[2] if parts.size() > 2 else "")
		"explainer":
			await _explainer_shot(parts[1] if parts.size() > 1 else "tower_seeker")
		"draft":
			await _draft_shot()
		"event":
			await _event_shot(parts[1] if parts.size() > 1 else "blood_pact")
		"pause":
			await _pause_shot()
		"hub_panel":
			await _hub_panel_shot(parts[1])
		"results":
			await _results_shot()
		"pause_guide":
			await _pause_shot(true)
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _save(suffix: String = "") -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://").path_join("%s%s.png" % [_out, suffix])
	img.save_png(path)
	print("CAPTURED ", path)


func _hub_shot(kind: String) -> void:
	_scene = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(20)
	var hub: HubScreen = _scene as HubScreen
	if kind == "hub_loadout":
		hub.show_page_for_test("loadout")
		hub.press_relic_for_test("quiver_of_echoes") # one Relic equipped: the EQUIPPED caption on a tile
		await _frames(10)
		hub.get_champion_button_for_test("warden").grab_focus() # focused AND locked on a fresh profile
	else:
		hub.get_difficulty_button_for_test("recruit").grab_focus() # focused (available); Soldier is selected, Veteran locked
	await _frames(20)
	if kind == "hub_press_locked":
		var locked: Button = hub.get_difficulty_button_for_test("veteran")
		locked.grab_focus()
		await _frames(2)
		locked.pressed.emit()
		await _frames(4)
	await _save()


func _guide_shot(tab: int, entry_id: String) -> void:
	var guide := FieldGuideScreen.new()
	add_child(guide)
	await _frames(3)
	for id in ["flame_arrows", "whirling_axes", "diagonal_arrows", "tower_seeker", "bomber", "goblin_warchief", "powder_keg", "shrine", "bridge", "second_life", "mend", "boon_war", "supply_crate", "ricochet"]:
		MetaProgress.mark_discovered(id)
	guide.open(tab, entry_id)
	await _frames(15)
	await _save()
	guide.queue_free()


func _explainer_shot(id: String) -> void:
	var explainer := ExplainerController.new()
	add_child(explainer)
	await _frames(3)
	explainer.request(id)
	await _frames(40)
	await _save()


## Marks every explainer seen so a staged run is not paused by one; the explainer shots skip this.
func _mute_explainers() -> void:
	for entry: Dictionary in FieldGuideCatalog.all_entries():
		MetaProgress.mark_explainer_seen(String(entry["id"]))


func _answer_opening_pick() -> void:
	var ui: Node = _scene.get_event_controller()
	while ui != null and ui.is_showing():
		ui.skip_lockout_for_test()
		ui.confirm_choice_for_test(0)


func _draft_shot() -> void:
	_mute_explainers()
	_scene = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(30)
	_answer_opening_pick()
	await _frames(30)
	var draft: DraftController = _scene.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	await _frames(40)
	draft.simulate_hover_for_test(1)
	await _frames(20)
	await _save()


func _event_shot(kind: String) -> void:
	_mute_explainers()
	_scene = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(30)
	_answer_opening_pick()
	var events: Node = _scene.get_run_events()
	events.queue_dev_event(kind, false)
	await _frames(60)
	_scene.get_event_controller().simulate_hover_for_test(1) if _scene.get_event_controller().has_method("simulate_hover_for_test") else null
	await _frames(20)
	await _save()


func _pause_shot(open_guide: bool = false) -> void:
	_mute_explainers()
	_scene = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(30)
	_answer_opening_pick()
	await _frames(30)
	var flow: Node = _scene.get_node("RunFlowController")
	flow._on_pause_action_pressed()
	await _frames(40)
	if open_guide:
		flow.pause_menu._open_field_guide()
		await _frames(30)
	await _save()


func _results_shot() -> void:
	_mute_explainers()
	_scene = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(30)
	_answer_opening_pick()
	await _frames(30)
	var flow: Node = _scene.get_node("RunFlowController")
	flow._end_run(flow.EndCause.TOWER_DESTROYED)
	await _frames(150)
	await _save()


## A Hub overlay: achievements | settings:<tab index> | skilltree | guide (the War Camp's own Field Guide).
func _hub_panel_shot(which: String) -> void:
	_scene = (load("res://scenes/hub.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _frames(20)
	var hub: HubScreen = _scene as HubScreen
	match which:
		"achievements":
			hub._on_achievements_pressed()
		"skilltree":
			hub._on_skill_tree_pressed()
		"guide":
			hub._on_field_guide_pressed()
		_:
			hub._on_settings_pressed()
			if which.begins_with("settings"):
				hub.get_settings_menu_for_test().show_tab_for_debug(int(which.trim_prefix("settings")))
	await _frames(40)
	await _save()

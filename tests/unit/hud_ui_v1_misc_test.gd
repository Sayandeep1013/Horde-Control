extends GdUnitTestSuite

## v1.0 pause build panel, How to Play, spawn markers, elite/wave callouts and
## the Dash / Battle Skill touch buttons (docs/31 §5.4, §8.2, §8.5).

var _dir: String
var _fakes: Dictionary


func before_test() -> void:
	_dir = "user://__hud_ui_v1_misc_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	CombatStats.reset_run_stats()
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test(_dir)
	TouchUi.set_override_for_test(0)


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	CombatStats.reset_run_stats()
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")
	TouchUi.set_override_for_test(-1)
	for node: Node in _fakes.values():
		if is_instance_valid(node):
			node.get_parent().remove_child(node) # leave the groups at once; queue_free would let the next test see them
			node.free()
	_fakes = {}


func _texts(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


# --- pause build panel ---------------------------------------------------------------

func _pause_with_fakes() -> PauseMenu:
	_fakes = HudFakes.install(self)
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	menu.set_active(true)
	return menu


func test_pause_options_are_resume_settings_how_to_play_abandon() -> void:
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	var bar: PausedChoiceBar = menu.get_bar_for_test()
	assert_int(bar.get_option_count()).is_equal(4)
	assert_str(bar.get_option_label_for_test(PauseMenu.OPTION_RESUME).text).is_equal("Resume")
	assert_str(bar.get_option_label_for_test(PauseMenu.OPTION_SETTINGS).text).is_equal("Settings")
	assert_str(bar.get_option_label_for_test(PauseMenu.OPTION_HOW_TO_PLAY).text).is_equal("How to Play")
	assert_str(bar.get_option_label_for_test(PauseMenu.OPTION_MAIN_MENU).text).is_equal("Abandon run")


func test_build_panel_lists_skill_difficulty_abilities_and_passives() -> void:
	RunConfig.difficulty_id = "veteran"
	var menu: PauseMenu = _pause_with_fakes()
	var build: Array[String] = _texts(menu.get_build_column_for_test())
	assert_array(build).contains(["Arrow Storm", "Veteran", "Flame Arrows", "Lv 3", "Storm Bolt", "Lv 5", "Ballista", "Lv 2"])
	var passives: Array[String] = _texts(menu.get_passives_column_for_test())
	assert_array(passives).contains(["Fleet Step", "2/3", "Stone Mason", "1/2"])


func test_build_panel_has_empty_states_without_the_manager() -> void:
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	menu.set_active(true)
	assert_array(_texts(menu.get_build_column_for_test())).contains(["None yet"])
	assert_array(_texts(menu.get_passives_column_for_test())).contains(["None yet"])


func test_run_stats_show_time_kills_elites_damage_repair_and_estimated_cores() -> void:
	CombatStats.add_run_counter("kills", 60)
	CombatStats.add_run_counter("elite_kills", 3)
	CombatStats.add_run_counter("damage_taken", 120.0)
	CombatStats.add_run_counter("scrap_repaired", 90)
	var menu: PauseMenu = _pause_with_fakes()
	var stats: Array[String] = _texts(menu.get_stats_column_for_test())
	assert_array(stats).contains(["04:32", "60", "3", "120", "90"])
	# 4 min = 4, wave 6 -> 5 cleared = 10, 60 kills = 2, 3 elites = 3, scrap 0 -> 19.
	assert_int(menu.estimated_cores()).is_equal(19)
	assert_array(stats).contains(["~19"])


func test_estimated_cores_apply_the_difficulty_multiplier() -> void:
	RunConfig.difficulty_id = "recruit"
	var menu: PauseMenu = _pause_with_fakes()
	assert_int(menu.estimated_cores()).is_equal(int(floor(14.0 * RunConfig.get_difficulty().cores_multiplier)))


func test_how_to_play_opens_closes_and_hides_the_choices() -> void:
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	menu.set_active(true)
	menu._on_option_confirmed(PauseMenu.OPTION_HOW_TO_PLAY)
	assert_bool(menu.is_how_to_play_open_for_test()).is_true()
	assert_bool(menu.get_bar_for_test().is_active()).is_false()
	assert_bool(menu.get_howto_bar_for_test().is_active()).is_true()
	menu._on_howto_confirmed(0)
	assert_bool(menu.is_how_to_play_open_for_test()).is_false()
	assert_bool(menu.get_bar_for_test().is_active()).is_true()
	menu._on_option_confirmed(PauseMenu.OPTION_HOW_TO_PLAY)
	menu.set_active(false)
	assert_bool(menu.is_how_to_play_open_for_test()).append_failure_message("closing the pause menu closes the page").is_false()


# --- How to Play ----------------------------------------------------------------------------

func test_how_to_play_has_four_sections_naming_the_live_keys() -> void:
	assert_str(HowToPlay.body(2)).contains("Space or Shift").contains("E or Q")
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	assert_str(HowToPlay.body(2)).contains("G or Shift")
	assert_str(HowToPlay.body(1)).contains("W A S D")
	var holder: VBoxContainer = auto_free(VBoxContainer.new())
	add_child(holder)
	HowToPlay.build_content(holder, 400.0)
	for i: int in range(1, 5):
		assert_object(holder.find_child("Head%d" % i, true, false)).is_not_null()
		assert_object(holder.find_child("Body%d" % i, true, false)).is_not_null()
	assert_str(HowToPlay.heading(4)).is_equal("Repair with Scrap")


func test_the_title_screen_has_the_how_to_play_page_and_it_closes() -> void:
	var title: TitleScreen = auto_free(TitleScreen.new())
	add_child(title)
	assert_object(title.get_how_to_play_button_for_test()).is_not_null()
	title.get_how_to_play_button_for_test().pressed.emit()
	assert_bool(title.is_how_to_play_panel_active_for_test()).is_true()
	title.simulate_ui_cancel_for_test()
	assert_bool(title.is_how_to_play_panel_active_for_test()).is_false()


func test_the_title_card_does_not_overlap_the_castle_at_1920x1080() -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	vp.size = Vector2i(1920, 1080)
	add_child(vp)
	var title: TitleScreen = TitleScreen.new()
	vp.add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	var card: Control = title.find_child("MenuCard", true, false)
	var castle: Control = title.find_child("Castle", true, false)
	assert_bool(card.get_global_rect().intersects(castle.get_global_rect())).append_failure_message("card %s overlaps castle %s" % [card.get_global_rect(), castle.get_global_rect()]).is_false()
	assert_bool(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(card.get_global_rect())).is_true()


# --- spawn markers ----------------------------------------------------------------------------

func _overlay() -> ThreatFeedback:
	var cam: GameCamera = auto_free(GameCamera.new())
	add_child(cam)
	var overlay: ThreatFeedback = auto_free(ThreatFeedback.new())
	add_child(overlay)
	overlay.set_camera_ref(cam)
	return overlay


func test_an_offscreen_spawn_gets_one_intent_coloured_marker_per_30_degree_sector() -> void:
	var overlay: ThreatFeedback = _overlay()
	overlay._on_spawn_warning(Vector2(3000, 0), ContractEnums.TargetIntent.TowerSeeker, 0.75, 0.0)
	overlay._on_spawn_warning(Vector2(3100, 20), ContractEnums.TargetIntent.PlayerHunter, 0.75, 0.0) # same sector
	overlay._on_spawn_warning(Vector2(0, 3000), ContractEnums.TargetIntent.Opportunist, 0.75, 0.0)
	var markers: Dictionary = overlay.get_spawn_markers_for_test()
	assert_int(markers.size()).is_equal(2)
	assert_bool((markers[0]["color"] as Color).is_equal_approx(UiPalette.INTENT_TOWER)).append_failure_message("the first spawn in a sector keeps its colour").is_true()
	assert_bool((markers[3]["color"] as Color).is_equal_approx(UiPalette.INTENT_OPPORTUNIST)).is_true()


func test_an_onscreen_spawn_gets_no_marker_and_markers_expire() -> void:
	var overlay: ThreatFeedback = _overlay()
	overlay._on_spawn_warning(Vector2(50, 50), ContractEnums.TargetIntent.TowerSeeker, 0.75, 0.0)
	assert_int(overlay.get_spawn_markers_for_test().size()).is_equal(0)
	overlay._on_spawn_warning(Vector2(3000, 0), ContractEnums.TargetIntent.TowerSeeker, 0.75, 0.0)
	overlay._prune_spawn_markers(overlay._now() + 0.8)
	assert_int(overlay.get_spawn_markers_for_test().size()).is_equal(0)


func test_marker_sectors_cover_the_circle_in_twelve_steps() -> void:
	var seen: Dictionary = {}
	for i: int in 36:
		seen[ThreatFeedback.marker_sector(Vector2.from_angle(deg_to_rad(float(i) * 10.0 + 1.0)))] = true
	assert_int(seen.size()).is_equal(12)


func test_the_spawn_warning_signal_reaches_the_overlay() -> void:
	var overlay: ThreatFeedback = _overlay()
	EventBus.emit_spawn_warning(Vector2(0, -3000), ContractEnums.TargetIntent.PlayerHunter, 0.75)
	assert_int(overlay.get_spawn_markers_for_test().size()).is_equal(1)


# --- wave banner, boss, elite --------------------------------------------------------------------

func test_wave_started_shows_the_typed_banner_and_boss_waves_say_boss() -> void:
	var announcer: RunAnnouncer = auto_free(RunAnnouncer.new())
	add_child(announcer)
	EventBus.emit_wave_started(6, 15, "siege", false)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["WAVE 6 · SIEGE"])
	EventBus.emit_wave_started(8, 15, "boss", true)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["WAVE 8 · BOSS"])


func test_siege_warning_boss_entrance_and_elite_callout_are_announced_once_each() -> void:
	var announcer: RunAnnouncer = auto_free(RunAnnouncer.new())
	add_child(announcer)
	EventBus.emit_siege_warning(3.0)
	EventBus.emit_boss_spawned(null, "warchief", "Goblin Warchief", 2600.0)
	assert_array(_texts(announcer.get_banner_box_for_test())).contains(["SIEGE INCOMING", "GOBLIN WARCHIEF"])
	EventBus.emit_elite_spawned(null, "swift")
	EventBus.emit_elite_spawned(null, "armored") # inside the gap: no second callout
	var elite: Array[String] = _texts(announcer.get_toast_box_for_test()).filter(func(t: String) -> bool: return t.begins_with("ELITE"))
	assert_array(elite).is_equal(["ELITE · SWIFT"])


# --- action buttons and touch ----------------------------------------------------------------------

func test_the_interactive_action_button_presses_and_releases_its_action() -> void:
	var button: HudActionButton = auto_free(HudActionButton.new(HudActionButton.Kind.DASH))
	button.make_interactive(96.0)
	add_child(button)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	button._gui_input(touch)
	# Input.parse_input_event is not transported in headless mode (src/dev/touch_selftest.gd checks
	# the real action state in a windowed run), so this asserts the held edge the press is built on.
	assert_bool(button.is_held_for_test()).is_true()
	var mouse := InputEventMouseButton.new() # the emulated mouse press of the same touch
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	button._gui_input(mouse)
	assert_bool(button.is_held_for_test()).is_true()
	touch.pressed = false
	button._gui_input(touch)
	assert_bool(button.is_held_for_test()).is_false()


func test_a_hud_action_button_is_display_only() -> void:
	var button: HudActionButton = auto_free(HudActionButton.new(HudActionButton.Kind.SKILL))
	add_child(button)
	assert_int(button.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	button._gui_input(touch)
	assert_bool(button.is_held_for_test()).is_false()


func test_touch_controls_add_dash_and_skill_buttons_that_do_not_overlap() -> void:
	TouchUi.set_override_for_test(1)
	var vp: SubViewport = auto_free(SubViewport.new())
	vp.size = Vector2i(1560, 720)
	add_child(vp)
	var tc: TouchControls = TouchControls.new()
	vp.add_child(tc)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(tc.dash_button).is_not_null()
	assert_object(tc.skill_button).is_not_null()
	var bounds := Rect2(Vector2.ZERO, Vector2(1560, 720))
	var rects: Array[Rect2] = [tc.dash_button.get_global_rect(), tc.skill_button.get_global_rect(), tc.pause_button.get_global_rect()]
	for r: Rect2 in rects:
		assert_bool(bounds.encloses(r)).is_true()
	assert_bool(rects[0].intersects(rects[1])).is_false()
	assert_bool(rects[2].intersects(rects[0]) or rects[2].intersects(rects[1])).is_false()
	assert_float(tc.skill_button.size.x).is_greater_equal(TouchUi.BUTTON_TOUCH_MIN_PX)
	assert_float(tc.dash_button.size.x).is_greater_equal(TouchUi.BUTTON_TOUCH_MIN_PX)
	assert_bool(rects[1].position.x > float(bounds.size.x) * 0.5).append_failure_message("thumb buttons belong on the right half").is_true()


func test_the_cooldown_wedge_covers_exactly_the_remaining_fraction() -> void:
	var rect := Rect2(0, 0, 100, 100)
	var full: PackedVector2Array = HudGlyphs.wedge_points(rect, -PI * 0.5, PI * 1.5)
	var area_full: float = _polygon_area(full)
	assert_float(area_full).is_equal_approx(10000.0, 60.0)
	var half: PackedVector2Array = HudGlyphs.wedge_points(rect, PI * 0.5, PI * 1.5)
	assert_float(_polygon_area(half)).is_equal_approx(5000.0, 60.0)


func _polygon_area(points: PackedVector2Array) -> float:
	var a: float = 0.0
	for i: int in points.size():
		var p: Vector2 = points[i]
		var q: Vector2 = points[(i + 1) % points.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5

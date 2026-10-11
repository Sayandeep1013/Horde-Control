extends GdUnitTestSuite

## v1.0 Settings (docs/31 §8.4): persistence of every new key, the legacy
## screen-shake migration, rebinding (swap rule, persistence, Input Map),
## keyboard-only tab navigation, the rebind capture, Reset controls and Reset to
## defaults with its confirm, and the Interface bus separate from Effects.

const STEP: float = 1.0 / 60.0

var _dir: String
var _menu: SettingsMenu


func before_test() -> void:
	_dir = "user://__settings_v1_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	_menu = auto_free(SettingsMenu.new())
	add_child(_menu)
	_menu.set_test_input_mode_for_test(true)
	_menu.set_active(true)
	_menu.skip_lockout_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.apply()
	GameSettings.reset_path_for_test()
	Engine.max_fps = 0
	var overlay: Node = get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)
	if overlay != null:
		overlay.queue_free()
	var dir: DirAccess = DirAccess.open(_dir)
	if dir != null:
		for f: String in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(_dir)


func _reload() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.load_from_disk()


func _press(action: StringName) -> void:
	_menu.press_action_once_for_test(action)
	_menu.tick_for_test(STEP)
	_menu.release_action_for_test(action)
	_menu.tick_for_test(STEP) # a fresh edge needs the key seen up in between


# --- persistence of every new key ------------------------------------------------

func test_every_new_key_round_trips_through_the_file() -> void:
	GameSettings.set_interface_volume_pct(30)
	GameSettings.set_window_size_index(1)
	GameSettings.set_fps_limit(144)
	GameSettings.set_show_fps(true)
	GameSettings.set_screen_shake_pct(40)
	GameSettings.set_pause_when_unfocused(false)
	GameSettings.set_auto_cast_enabled(true)
	GameSettings.set_show_overhead_bars(false)
	GameSettings.set_hud_scale_pct(125)
	GameSettings.set_reduce_flashing(true)
	GameSettings.set_enemy_outlines(true)
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	_reload()
	assert_int(GameSettings.get_interface_volume_pct()).is_equal(30)
	assert_int(GameSettings.get_window_size_index()).is_equal(1)
	assert_int(GameSettings.get_fps_limit()).is_equal(144)
	assert_bool(GameSettings.is_show_fps()).is_true()
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(40)
	assert_bool(GameSettings.is_pause_when_unfocused()).is_false()
	assert_bool(GameSettings.is_auto_cast_enabled()).is_true()
	assert_bool(GameSettings.is_show_overhead_bars()).is_false()
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(125)
	assert_bool(GameSettings.is_reduce_flashing()).is_true()
	assert_bool(GameSettings.is_enemy_outlines()).is_true()
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_G)
	assert_int(GameSettings.get_key_binding(&"dash", 1)).is_equal(KEY_SHIFT)


func test_defaults_of_the_new_keys() -> void:
	assert_int(GameSettings.get_interface_volume_pct()).is_equal(80)
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(100)
	assert_bool(GameSettings.is_pause_when_unfocused()).is_true()
	assert_bool(GameSettings.is_show_fps()).is_false()
	assert_int(GameSettings.get_fps_limit()).is_equal(0)
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(100)
	assert_bool(GameSettings.is_controls_customised()).is_false()


func test_the_old_screen_shake_toggle_migrates() -> void:
	var cfg := ConfigFile.new()
	DirAccess.make_dir_recursive_absolute(_dir)
	cfg.set_value("gameplay", "screen_shake_enabled", false)
	cfg.save(_dir.path_join("settings.cfg"))
	_reload()
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(0)
	assert_bool(GameSettings.is_screen_shake_enabled()).is_false()
	cfg.set_value("gameplay", "screen_shake_enabled", true)
	cfg.save(_dir.path_join("settings.cfg"))
	_reload()
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(100)


func test_the_new_value_wins_over_a_stale_legacy_toggle() -> void:
	var cfg := ConfigFile.new()
	DirAccess.make_dir_recursive_absolute(_dir)
	cfg.set_value("gameplay", "screen_shake_enabled", false)
	cfg.set_value("gameplay", "screen_shake_pct", 60)
	cfg.save(_dir.path_join("settings.cfg"))
	_reload()
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(60)


func test_screen_shake_percent_scales_the_camera_trauma() -> void:
	GameSettings.set_screen_shake_pct(50)
	var camera: GameCamera = auto_free(GameCamera.new())
	add_child(camera)
	camera.add_trauma(0.6)
	assert_float(camera.get_trauma_for_test()).is_equal_approx(0.3, 0.001)


func test_interface_volume_drives_the_ui_bus_and_not_effects() -> void:
	GameSettings.set_effects_volume_pct(80)
	GameSettings.set_interface_volume_pct(20)
	var ui: int = AudioServer.get_bus_index("UI")
	var sfx: int = AudioServer.get_bus_index("SFX")
	assert_float(AudioServer.get_bus_volume_db(ui)).is_equal_approx(linear_to_db(0.2), 0.01)
	assert_float(AudioServer.get_bus_volume_db(sfx)).is_equal_approx(linear_to_db(0.8), 0.01)
	GameSettings.set_interface_volume_pct(0)
	assert_bool(AudioServer.is_bus_mute(ui)).is_true()
	assert_bool(AudioServer.is_bus_mute(sfx)).is_false()


func test_fps_limit_applies_to_the_engine() -> void:
	GameSettings.set_fps_limit(60)
	assert_int(Engine.max_fps).is_equal(60)
	GameSettings.cycle_fps_limit(1)
	assert_int(Engine.max_fps).is_equal(120)
	GameSettings.set_fps_limit(0)
	assert_int(Engine.max_fps).is_equal(0)


func test_show_fps_creates_and_frees_the_overlay() -> void:
	GameSettings.set_show_fps(true)
	await get_tree().process_frame
	assert_object(get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)).is_not_null()
	GameSettings.set_show_fps(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)).is_null()


func test_focus_loss_pause_respects_the_setting() -> void:
	GameSettings.set_pause_when_unfocused(false)
	var flow: RunFlowController = auto_free(RunFlowController.new())
	add_child(flow)
	flow.simulate_focus_out_for_test()
	assert_bool(PauseAuthority.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).is_false()
	GameSettings.set_pause_when_unfocused(true)
	flow.simulate_focus_out_for_test()
	assert_bool(PauseAuthority.has_reason(PauseAuthority.REASON_FOCUS_LOSS)).is_true()
	PauseAuthority.pop_reason_immediate(PauseAuthority.REASON_FOCUS_LOSS)


# --- rebinding -----------------------------------------------------------------

func test_rebinding_updates_the_input_map_and_persists() -> void:
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	var keys: Array[int] = []
	for ev: InputEvent in InputMap.action_get_events(&"dash"):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
	assert_array(keys).contains([KEY_G, KEY_SHIFT])
	assert_array(keys).not_contains([KEY_SPACE])
	var joypad_kept: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"dash"):
		joypad_kept = joypad_kept or ev is InputEventJoypadButton
	assert_bool(joypad_kept).append_failure_message("gamepad events must survive a keyboard rebind").is_true()
	_reload()
	GameSettings.apply() # boot: the saved bindings reach the Input Map
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_G)
	var after_boot: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"dash"):
		after_boot = after_boot or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_G)
	assert_bool(after_boot).is_true()


func test_binding_a_key_in_use_swaps_so_no_action_loses_its_key() -> void:
	# W is move_up slot 0. Bind it to dash slot 0 (old key Space).
	GameSettings.set_key_binding(&"dash", 0, KEY_W)
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_W)
	assert_int(GameSettings.get_key_binding(&"move_up", 0)).append_failure_message("move_up must receive the displaced key").is_equal(KEY_SPACE)
	assert_int(GameSettings.get_key_binding(&"move_up", 1)).is_equal(KEY_UP)


func test_reset_controls_restores_the_project_keys() -> void:
	GameSettings.set_key_binding(&"battle_skill", 1, KEY_F)
	assert_bool(GameSettings.is_controls_customised()).is_true()
	GameSettings.reset_controls()
	assert_int(GameSettings.get_key_binding(&"battle_skill", 1)).is_equal(KEY_Q)
	assert_bool(GameSettings.is_controls_customised()).is_false()


func test_an_invalid_rebind_is_ignored() -> void:
	GameSettings.set_key_binding(&"jump", 0, KEY_G)
	GameSettings.set_key_binding(&"dash", 5, KEY_G)
	GameSettings.set_key_binding(&"dash", 0, 0)
	assert_bool(GameSettings.is_controls_customised()).is_false()


# --- tabs, keyboard only ------------------------------------------------------------

func test_tabs_switch_by_the_tab_keys_and_wrap() -> void:
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.AUDIO)
	_press(&"tab_next")
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.VIDEO)
	_press(&"tab_prev")
	_press(&"tab_prev")
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.ACCESSIBILITY)
	_press(&"tab_next")
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.AUDIO)


func test_a_real_q_or_e_key_switches_tabs() -> void:
	_menu.set_test_input_mode_for_test(false)
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	_menu._input(e)
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.VIDEO)
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	q.pressed = true
	_menu._input(q)
	assert_int(_menu.get_tab_for_test()).is_equal(SettingsMenu.Tab.AUDIO)


func test_each_tab_shows_its_own_rows_plus_the_footer() -> void:
	for tab: int in SettingsMenu.TAB_ROWS.size():
		_menu.switch_tab_for_test(1 if tab > 0 else 0)
		var ids: Array[String] = _menu.get_visible_row_ids_for_test()
		for id: String in SettingsMenu.TAB_ROWS[tab]:
			assert_bool(ids.has(id)).append_failure_message("tab %d is missing row %s" % [tab, id]).is_true()
		assert_str(ids[ids.size() - 1]).is_equal(SettingsMenu.ROW_BACK)
		assert_str(ids[ids.size() - 2]).is_equal(SettingsMenu.ROW_RESET_DEFAULTS)


func test_every_listed_option_exists_as_a_row() -> void:
	var needed: Array[String] = [
		"master_volume", "music_volume", "effects_volume", "interface_volume", "mute_all",
		"display_mode", "window_size", "vsync", "fps_limit", "show_fps",
		"auto_cast", "damage_numbers", "screen_shake", "show_overhead_bars", "pause_unfocused", "movement_only",
		"bind_move_up", "bind_move_down", "bind_move_left", "bind_move_right", "bind_dash", "bind_battle_skill", "bind_pause", "reset_controls",
		"hud_scale", "reduce_flashing", "enemy_outlines", "reset_defaults", "back"]
	for id: String in needed:
		assert_object(_menu.get_row_for_test(id)).append_failure_message("no row %s" % id).is_not_null()
		assert_bool(SettingsMenu.ROW_ORDER.has(id)).is_true()


func test_a_whole_run_through_every_tab_needs_only_movement_keys() -> void:
	# Up/down/left/right change values on each tab; Back closes by holding right.
	var closed: Array = []
	_menu.closed.connect(func() -> void: closed.append(1))
	_menu.highlight_row_for_test(SettingsMenu.ROW_HUD_SCALE)
	_press(&"move_right")
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(105)
	_menu.highlight_row_for_test(SettingsMenu.ROW_FPS_LIMIT)
	_press(&"move_left")
	assert_int(GameSettings.get_fps_limit()).is_equal(240)
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK)
	_menu.set_action_pressed_for_test(&"move_right", true)
	var held: float = 0.0
	while held < 1.2:
		_menu.tick_for_test(STEP)
		held += STEP
	assert_int(closed.size()).is_equal(1)


func test_value_rows_change_with_left_right_and_persist() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_INTERFACE_VOLUME)
	_press(&"move_left")
	assert_int(GameSettings.get_interface_volume_pct()).is_equal(70)
	_menu.highlight_row_for_test(SettingsMenu.ROW_PAUSE_UNFOCUSED)
	_press(&"move_right")
	assert_bool(GameSettings.is_pause_when_unfocused()).is_false()
	_menu.highlight_row_for_test(SettingsMenu.ROW_REDUCE_FLASHING)
	_press(&"move_right")
	assert_bool(GameSettings.is_reduce_flashing()).is_true()
	_menu.highlight_row_for_test(SettingsMenu.ROW_SHOW_OVERHEAD_BARS)
	_press(&"move_right")
	assert_bool(GameSettings.is_show_overhead_bars()).is_false()
	_menu.highlight_row_for_test(SettingsMenu.ROW_SCREEN_SHAKE)
	_press(&"move_left")
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(90)
	_menu.highlight_row_for_test(SettingsMenu.ROW_ENEMY_OUTLINES)
	_press(&"move_right")
	assert_bool(GameSettings.is_enemy_outlines()).is_true()
	_reload()
	assert_int(GameSettings.get_interface_volume_pct()).is_equal(70)
	assert_int(GameSettings.get_screen_shake_pct()).is_equal(90)


func test_movement_only_forces_auto_cast_on_and_the_row_says_so() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_MOVEMENT_ONLY)
	_press(&"move_right")
	assert_bool(GameSettings.is_auto_cast_enabled()).is_true()
	assert_str(_menu.get_row_for_test(SettingsMenu.ROW_AUTO_CAST).get_value_label_for_test().text).is_equal("On")


# --- rebind capture in the menu --------------------------------------------------------

func test_confirm_on_a_binding_row_listens_and_the_next_key_binds_it() -> void:
	_menu.highlight_row_for_test("bind_dash")
	_press(&"confirm")
	assert_bool(_menu.is_capturing_for_test()).is_true()
	assert_str(_menu.get_row_for_test("bind_dash").get_value_label_for_test().text).is_equal("Press a key...")
	_menu.capture_key_for_test(KEY_G)
	assert_bool(_menu.is_capturing_for_test()).is_false()
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_G)
	assert_str(_menu.get_row_for_test("bind_dash").get_value_label_for_test().text).contains("G")


func test_left_right_picks_the_slot_that_the_rebind_targets() -> void:
	_menu.highlight_row_for_test("bind_battle_skill")
	_press(&"move_right")
	assert_int(_menu.get_slot_cursor_for_test()).is_equal(1)
	_press(&"confirm")
	_menu.capture_key_for_test(KEY_F)
	assert_int(GameSettings.get_key_binding(&"battle_skill", 1)).is_equal(KEY_F)
	assert_int(GameSettings.get_key_binding(&"battle_skill", 0)).is_equal(KEY_E)


func test_escape_cancels_a_rebind_without_changing_anything() -> void:
	_menu.highlight_row_for_test("bind_dash")
	_press(&"confirm")
	_menu.capture_key_for_test(KEY_ESCAPE)
	assert_bool(_menu.is_capturing_for_test()).is_false()
	assert_bool(GameSettings.is_controls_customised()).is_false()


func test_the_bound_key_does_not_also_confirm_the_row_again() -> void:
	_menu.highlight_row_for_test("bind_dash")
	_press(&"confirm")
	_menu.capture_key_for_test(KEY_SPACE)
	_press(&"confirm") # Space is a confirm key too; this frame must be ignored
	assert_bool(_menu.is_capturing_for_test()).append_failure_message("binding Space must not re-enter capture").is_false()


func test_reset_controls_row_restores_defaults() -> void:
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	_menu.highlight_row_for_test(SettingsMenu.ROW_RESET_CONTROLS)
	_press(&"confirm")
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_SPACE)


# --- Reset to defaults, with a confirm -------------------------------------------------

func test_reset_to_defaults_needs_a_second_press() -> void:
	GameSettings.set_hud_scale_pct(140)
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	_menu.highlight_row_for_test(SettingsMenu.ROW_RESET_DEFAULTS)
	_press(&"confirm")
	assert_bool(_menu.is_reset_pending_for_test()).is_true()
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(140)
	assert_str(_menu.get_row_for_test(SettingsMenu.ROW_RESET_DEFAULTS).get_value_label_for_test().text).is_equal("Press again")
	_press(&"confirm")
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(100)
	assert_int(GameSettings.get_key_binding(&"dash", 0)).is_equal(KEY_SPACE)
	_reload()
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(100)


func test_the_reset_confirm_lapses_when_the_highlight_moves_away() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_RESET_DEFAULTS)
	_press(&"confirm")
	_press(&"move_up")
	assert_bool(_menu.is_reset_pending_for_test()).is_false()


func test_the_reset_confirm_lapses_with_time() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_RESET_DEFAULTS)
	_press(&"confirm")
	var t: float = 0.0
	while t < SettingsMenu.RESET_CONFIRM_SECONDS + 0.2:
		_menu.tick_for_test(0.1)
		t += 0.1
	assert_bool(_menu.is_reset_pending_for_test()).is_false()


func test_holding_a_direction_on_reset_is_itself_the_confirm() -> void:
	GameSettings.set_hud_scale_pct(140)
	_menu.highlight_row_for_test(SettingsMenu.ROW_RESET_DEFAULTS)
	_menu.tick_for_test(STEP)
	_menu.set_action_pressed_for_test(&"move_right", true)
	var held: float = 0.0
	while held < 1.2:
		_menu.tick_for_test(STEP)
		held += STEP
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(100)

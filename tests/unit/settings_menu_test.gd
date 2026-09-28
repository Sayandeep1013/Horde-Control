extends GdUnitTestSuite

## Settings Menu tests (Settings screen task, rebuild). Drives `SettingsMenu`
## through its test-input double (`set_test_input_mode_for_test` /
## `set_action_pressed_for_test` / `press_action_once_for_test` +
## `tick_for_test()`), mirroring this project's established convention for
## input-timing suites (tests/unit/draft_input_lockout_test.gd's own header;
## src/run/paused_choice_bar.gd's identical seams). Every test redirects
## `GameSettings` to a throwaway path FIRST (hard constraint).

const STEP: float = 1.0 / 60.0
const HOLD: float = 1.0 # SettingsMenu.HOLD_CONFIRM_SECONDS

var _dir: String
var _menu: SettingsMenu


func before_test() -> void:
	_dir = "user://__settings_menu_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	_menu = auto_free(SettingsMenu.new())
	add_child(_menu)
	_menu.set_test_input_mode_for_test(true)
	_menu.set_active(true)


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.apply() # restores the real AudioServer buses for whichever suite runs next
	GameSettings.reset_path_for_test()
	# SettingsMenu's own static wrapper is process-lifetime (see that file's
	# header) -- reset it exactly like tests/unit/skill_tree_screen_test.gd's
	# own after_test() does, so it never leaks into another suite.
	SettingsMenu.set_movement_only_controls_enabled_for_test(false)


func _hold_direction(action: StringName, seconds: float) -> void:
	_menu.set_action_pressed_for_test(action, true)
	var elapsed: float = 0.0
	while elapsed < seconds:
		_menu.tick_for_test(STEP)
		elapsed += STEP


# --- Row navigation (Up/Down) -------------------------------------------------

func test_opens_with_master_volume_highlighted() -> void:
	assert_int(_menu.get_highlighted_index_for_test()).is_equal(0)
	assert_str(SettingsMenu.ROW_ORDER[_menu.get_highlighted_index_for_test()]).is_equal(SettingsMenu.ROW_MASTER_VOLUME)


func test_down_moves_to_the_next_row() -> void:
	_menu.press_action_once_for_test(&"move_down")
	_menu.tick_for_test(STEP)
	assert_str(SettingsMenu.ROW_ORDER[_menu.get_highlighted_index_for_test()]).is_equal(SettingsMenu.ROW_MUSIC_VOLUME)


func test_up_from_the_first_row_wraps_to_back() -> void:
	_menu.press_action_once_for_test(&"move_up")
	_menu.tick_for_test(STEP)
	assert_str(SettingsMenu.ROW_ORDER[_menu.get_highlighted_index_for_test()]).is_equal(SettingsMenu.ROW_BACK)


# --- Left/Right changes the highlighted row's value, immediately -------------

func test_right_increases_master_volume_by_one_step() -> void:
	GameSettings.set_master_volume_pct(50)
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(60)
	assert_str(_menu.get_row_for_test(SettingsMenu.ROW_MASTER_VOLUME).get_value_label_for_test().text).is_equal("60%")


func test_left_decreases_master_volume_by_one_step() -> void:
	GameSettings.set_master_volume_pct(50)
	_menu.press_action_once_for_test(&"move_left")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(40)


func test_master_volume_clamps_at_zero_via_left() -> void:
	GameSettings.set_master_volume_pct(0)
	_menu.press_action_once_for_test(&"move_left")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(0)


func test_master_volume_clamps_at_one_hundred_via_right() -> void:
	GameSettings.set_master_volume_pct(100)
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_master_volume_pct()).is_equal(100)


func test_navigating_to_music_volume_then_right_changes_music_not_master() -> void:
	GameSettings.set_master_volume_pct(50)
	GameSettings.set_music_volume_pct(50)
	_menu.press_action_once_for_test(&"move_down") # -> music_volume
	_menu.tick_for_test(STEP)
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_music_volume_pct()).is_equal(60)
	assert_int(GameSettings.get_master_volume_pct()).append_failure_message("changing Music Volume must not touch Master Volume").is_equal(50)


func test_mute_all_row_toggles_on_right_press() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_MUTE_ALL)
	assert_bool(GameSettings.is_mute_all()).is_false()
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_bool(GameSettings.is_mute_all()).is_true()
	assert_str(_menu.get_row_for_test(SettingsMenu.ROW_MUTE_ALL).get_value_label_for_test().text).is_equal(tr("SETTINGS_ON"))


func test_display_mode_row_cycles_forward() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_DISPLAY_MODE)
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.WINDOWED)
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_int(GameSettings.get_display_mode()).is_equal(GameSettings.DisplayMode.FULLSCREEN)


func test_screen_shake_row_toggles() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_SCREEN_SHAKE)
	_menu.press_action_once_for_test(&"move_left")
	_menu.tick_for_test(STEP)
	assert_bool(GameSettings.is_screen_shake_enabled()).is_false()


func test_damage_numbers_row_toggles() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_DAMAGE_NUMBERS)
	_menu.press_action_once_for_test(&"move_left")
	_menu.tick_for_test(STEP)
	assert_bool(GameSettings.are_damage_numbers_enabled()).is_false()


func test_vsync_row_toggles_without_erroring_headless() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_VSYNC)
	_menu.press_action_once_for_test(&"move_left")
	_menu.tick_for_test(STEP)
	assert_bool(GameSettings.is_vsync_enabled()).is_false()


# --- Movement-only controls (task brief: "the EXISTING setting; now
# persisted"): SettingsMenu's own static wrapper must still work ------------

func test_movement_only_row_routes_through_the_settings_menu_static_getter() -> void:
	_menu.highlight_row_for_test(SettingsMenu.ROW_MOVEMENT_ONLY)
	assert_bool(SettingsMenu.get_movement_only_controls_enabled()).is_false()
	_menu.press_action_once_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_bool(SettingsMenu.get_movement_only_controls_enabled()).append_failure_message("SettingsMenu.get_movement_only_controls_enabled() must reflect the row's own change").is_true()


## Kept for tests/unit/skill_tree_screen_test.gd's own precedent -- proves the
## `_for_test` seam still exists and still works with no `GameSettings` path
## redirection of its own.
func test_set_movement_only_controls_enabled_for_test_seam_still_works() -> void:
	SettingsMenu.set_movement_only_controls_enabled_for_test(true)
	assert_bool(SettingsMenu.get_movement_only_controls_enabled()).is_true()
	SettingsMenu.set_movement_only_controls_enabled_for_test(false)
	assert_bool(SettingsMenu.get_movement_only_controls_enabled()).is_false()


# --- Back row: instant confirm, hold-to-confirm, and mouse click -------------

func test_back_row_confirms_instantly_on_the_confirm_action() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK)
	_menu.press_action_once_for_test(&"confirm")
	_menu.tick_for_test(STEP)
	assert_int(closed_calls.size()).is_equal(1)


func test_confirm_action_does_nothing_on_a_non_back_row() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_MASTER_VOLUME)
	_menu.press_action_once_for_test(&"confirm")
	_menu.tick_for_test(STEP)
	assert_int(closed_calls.size()).is_equal(0)


## Movement-only path (task brief; class header): holding a movement key
## alone, with no button, must be able to leave the screen.
func test_back_row_confirms_by_holding_move_right_for_the_full_duration() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK)
	_hold_direction(&"move_right", HOLD + STEP)
	assert_int(closed_calls.size()).append_failure_message("holding move_right on the Back row for %.2fs must confirm it" % HOLD).is_equal(1)


func test_back_row_confirms_by_holding_move_left_too() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK)
	_hold_direction(&"move_left", HOLD + STEP)
	assert_int(closed_calls.size()).is_equal(1)


func test_back_row_hold_released_early_does_not_confirm() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK)
	_hold_direction(&"move_right", HOLD * 0.5)
	_menu.release_action_for_test(&"move_right")
	_menu.tick_for_test(STEP)
	assert_int(closed_calls.size()).is_equal(0)
	assert_float(_menu.get_back_hold_progress_for_test()).is_equal_approx(0.0, 0.001)


## Neutral-return arming (mirrors paused_choice_bar.gd's own rule): a
## direction already held the INSTANT Back becomes highlighted (or the menu
## opens) must not instantly confirm.
func test_back_row_hold_already_held_when_reached_does_not_instantly_confirm() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.highlight_row_for_test(SettingsMenu.ROW_MASTER_VOLUME)
	_menu.set_action_pressed_for_test(&"move_right", true) # held BEFORE Back is ever reached
	_menu.tick_for_test(STEP)
	_menu.highlight_row_for_test(SettingsMenu.ROW_BACK) # jump straight to Back while still held
	_menu.tick_for_test(STEP)
	assert_int(closed_calls.size()).append_failure_message("a direction already held before Back was highlighted must not instantly confirm it").is_equal(0)


func test_back_row_confirms_on_a_mouse_click() -> void:
	var closed_calls: Array = []
	_menu.closed.connect(func() -> void: closed_calls.append(true))
	_menu.get_row_for_test(SettingsMenu.ROW_BACK).clicked.emit()
	assert_int(closed_calls.size()).is_equal(1)


func test_clicking_a_value_rows_right_arrow_changes_its_value() -> void:
	GameSettings.set_master_volume_pct(50)
	_menu.get_row_for_test(SettingsMenu.ROW_MASTER_VOLUME).right_pressed.emit()
	assert_int(GameSettings.get_master_volume_pct()).is_equal(60)


func test_hovering_a_row_highlights_it() -> void:
	_menu.get_row_for_test(SettingsMenu.ROW_VSYNC).hovered.emit()
	assert_str(SettingsMenu.ROW_ORDER[_menu.get_highlighted_index_for_test()]).is_equal(SettingsMenu.ROW_VSYNC)


# --- set_active() / closed API kept for RunFlowController --------------------

func test_set_active_false_hides_the_screen() -> void:
	_menu.set_active(false)
	assert_bool(_menu.is_active_for_test()).is_false()


func test_set_active_true_shows_the_screen() -> void:
	_menu.set_active(false)
	_menu.set_active(true)
	assert_bool(_menu.is_active_for_test()).is_true()

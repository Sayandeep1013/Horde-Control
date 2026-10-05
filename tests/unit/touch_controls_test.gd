extends GdUnitTestSuite

## Mobile port (D146, D147): the touch controls.
##  - the joystick turns synthetic finger events into the existing move actions;
##  - the pause button makes the same `pause` action Esc makes;
##  - the controls are hidden on desktop and shown with the touch-UI gate;
##  - tapping a Draft card picks that card.
##
## The headless runner does not transport InputEvents into the GUI (gdUnit4's
## own warning), so the finger-through-the-engine cases -- the joystick moving
## the real player, a tap on the pause button, Resume, Abandon, a Draft card --
## live in the windowed self-test `src/dev/touch_selftest.tscn`, which prints
## SELFTEST PASS/FAIL lines and exits non-zero on a failure.

const STEP: float = 1.0 / 60.0

var _pause_events: int = 0
var _catcher: Node = null


func before_test() -> void:
	_pause_events = 0
	TouchUi.set_override_for_test(-1)


func after_test() -> void:
	TouchUi.set_override_for_test(-1)
	TouchUi.set_scale_suspended(null, false)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func _make_controls(enabled: bool) -> TouchControls:
	TouchUi.set_override_for_test(1 if enabled else 0)
	var tc := TouchControls.new()
	add_child(tc)
	auto_free(tc)
	return tc


# --- gate ---------------------------------------------------------------------

func test_touch_controls_are_hidden_on_desktop() -> void:
	var tc: TouchControls = _make_controls(false)
	assert_bool(tc.visible).is_false()
	assert_object(tc.joystick).is_null()
	assert_object(tc.pause_button).is_null()


func test_touch_controls_are_shown_when_the_gate_is_on() -> void:
	var tc: TouchControls = _make_controls(true)
	assert_bool(tc.visible).is_true()
	assert_object(tc.joystick).is_not_null()
	assert_object(tc.pause_button).is_not_null()
	assert_float(tc.pause_button.custom_minimum_size.x).is_greater_equal(TouchControls.PAUSE_BUTTON_SIZE_PX)


func test_touch_ui_flag_forces_the_gate_on_for_desktop() -> void:
	# The real command-line path: `--touch-ui` is read from the user args, and
	# `--no-touch-ui` always wins. Neither is present in a test run.
	assert_bool(OS.get_cmdline_user_args().has(TouchUi.FLAG_FORCE_ON)).is_false()
	assert_bool(TouchUi.is_enabled()).is_equal(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))
	TouchUi.set_override_for_test(1)
	assert_bool(TouchUi.is_enabled()).is_true()
	assert_bool(TouchUi.is_mobile_layout()).is_true()
	TouchUi.set_override_for_test(0)
	assert_bool(TouchUi.is_enabled()).is_false()


func test_joystick_is_configured_from_the_register_and_drives_the_move_actions() -> void:
	var tc: TouchControls = _make_controls(true)
	var j: VirtualJoystick = tc.joystick
	assert_int(j.joystick_mode).is_equal(VirtualJoystick.JOYSTICK_DYNAMIC)
	assert_float(j.joystick_size).is_equal_approx(TouchControls.JOYSTICK_SIZE_PX, 0.01)
	assert_float(j.deadzone_ratio).is_equal_approx(TouchControls.JOYSTICK_DEADZONE_RATIO, 0.001)
	assert_str(String(j.action_left)).is_equal("move_left")
	assert_str(String(j.action_right)).is_equal("move_right")
	assert_str(String(j.action_up)).is_equal("move_up")
	assert_str(String(j.action_down)).is_equal("move_down")


# --- pause button -------------------------------------------------------------

class PauseCatcher extends Node:
	var count: int = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"pause"):
			count += 1


func test_the_pause_button_makes_the_same_pause_action_as_escape() -> void:
	var tc: TouchControls = _make_controls(true)
	var catcher := PauseCatcher.new()
	add_child(catcher)
	auto_free(catcher)
	tc.pause_button.pressed.emit()
	await get_tree().process_frame
	assert_int(catcher.count).is_equal(1)


func test_the_pause_button_hides_while_the_game_is_paused_by_something_else() -> void:
	var tc: TouchControls = _make_controls(true)
	assert_bool(tc.pause_button.visible).is_true()
	PauseAuthority.push_reason_immediate(&"draft")
	assert_bool(tc.pause_button.visible).is_false()
	PauseAuthority.pop_reason_immediate(&"draft")
	assert_bool(tc.pause_button.visible).is_true()


func test_the_pause_button_does_not_overlap_the_hud_panels() -> void:
	# The Scrap panel (two lines) ends about 112 logical px from the top; the
	# button's top edge starts below it.
	var tc: TouchControls = _make_controls(true)
	assert_float(tc.pause_button.offset_top).is_greater_equal(120.0)


# --- Draft tap ----------------------------------------------------------------

func test_tapping_a_draft_card_picks_that_card() -> void:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var pause: Node = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(pause)
	var clock: Node = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(clock)
	var draft: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(draft)
	draft.set_run_inventory_for_test(run_inventory)
	draft.set_upgrade_system_for_test(upgrade_system)
	draft.set_pause_authority_for_test(pause)
	draft.set_sim_clock_for_test(clock)
	draft.set_test_input_mode_for_test(true)
	draft.force_open_for_test(false)
	for i: int in 30:
		draft.tick_for_test(STEP)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(draft.is_draft_showing_for_test()).is_true()
	assert_bool(draft.is_lockout_elapsed_for_test()).is_true()

	var view: DraftCardView = draft.get_card_view_for_test(1)
	assert_int(view.mouse_filter).append_failure_message("a Draft card must take taps").is_equal(Control.MOUSE_FILTER_STOP)
	draft.simulate_card_click_for_test(1) # what the engine's emulated mouse press on the card calls
	assert_int(draft.get_highlighted_index_for_test()).append_failure_message("the tapped card was not the highlighted one").is_equal(1)
	assert_bool(draft.is_draft_showing_for_test()).append_failure_message("tapping a card did not close the Draft").is_false()


# --- mobile layout ------------------------------------------------------------

func test_the_mobile_layout_hides_the_desktop_only_settings_rows() -> void:
	TouchUi.set_override_for_test(1)
	var menu: SettingsMenu = auto_free(SettingsMenu.new())
	add_child(menu)
	assert_object(menu.get_row_for_test(SettingsMenu.ROW_DISPLAY_MODE)).is_null()
	assert_object(menu.get_row_for_test(SettingsMenu.ROW_VSYNC)).is_null()
	assert_object(menu.get_row_for_test(SettingsMenu.ROW_MASTER_VOLUME)).is_not_null()
	assert_object(menu.get_row_for_test(SettingsMenu.ROW_BACK)).is_not_null()


func test_the_desktop_layout_keeps_every_settings_row() -> void:
	TouchUi.set_override_for_test(0)
	var menu: SettingsMenu = auto_free(SettingsMenu.new())
	add_child(menu)
	for id: String in SettingsMenu.ROW_ORDER:
		assert_object(menu.get_row_for_test(id)).append_failure_message("row %s missing on desktop" % id).is_not_null()


func test_touch_height_raises_small_targets_on_mobile_only() -> void:
	TouchUi.set_override_for_test(0)
	assert_float(TouchUi.touch_height(20.0)).is_equal_approx(20.0, 0.001)
	TouchUi.set_override_for_test(1)
	assert_float(TouchUi.touch_height(20.0)).is_equal_approx(TouchUi.MENU_TOUCH_MIN_PX, 0.001)
	assert_float(TouchUi.touch_height(200.0)).is_equal_approx(200.0, 0.001)
	assert_float(TouchUi.button_size(Vector2(360.0, 56.0)).y).is_equal_approx(TouchUi.BUTTON_TOUCH_MIN_PX, 0.001)


func test_ui_scale_is_1_5_on_a_20_9_phone_less_on_16_9_and_1_on_desktop() -> void:
	var wide := Vector2(2400.0, 1080.0)
	var sixteen_nine := Vector2(1920.0, 1080.0)
	TouchUi.set_override_for_test(0)
	assert_float(TouchUi.ui_scale_for(wide)).is_equal_approx(1.0, 0.001)
	TouchUi.set_override_for_test(1)
	assert_float(TouchUi.ui_scale_for(wide)).is_equal_approx(1.5, 0.001)
	# 16:9: the logical canvas must stay at least 1400 px wide.
	assert_float(1920.0 / TouchUi.ui_scale_for(sixteen_nine)).is_greater_equal(TouchUi.UI_MIN_LOGICAL_WIDTH_PX - 1.0)
	assert_float(TouchUi.ui_scale_for(Vector2(1000.0, 1000.0))).is_equal_approx(1.0, 0.001) # never shrinks the UI
	TouchUi.set_scale_suspended(null, true) # the Skill Tree board runs unscaled
	assert_float(TouchUi.ui_scale_for(wide)).is_equal_approx(1.0, 0.001)
	TouchUi.set_scale_suspended(null, false)


func test_the_camera_divides_the_ui_scale_out_so_the_world_view_does_not_change() -> void:
	var cam: Camera2D = auto_free(GameCamera.new())
	add_child(cam)
	var base: Vector2 = (cam as GameCamera).get_visible_world_size()
	get_window().content_scale_factor = 1.5
	(cam as GameCamera)._process(0.016)
	var scaled: Vector2 = (cam as GameCamera).get_visible_world_size()
	get_window().content_scale_factor = 1.0
	(cam as GameCamera)._process(0.016)
	assert_vector(scaled).is_equal_approx(base, Vector2(0.5, 0.5))
	assert_float((cam as GameCamera).get_view_scale()).is_equal_approx(1.0, 0.001)
	assert_vector(cam.zoom).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))

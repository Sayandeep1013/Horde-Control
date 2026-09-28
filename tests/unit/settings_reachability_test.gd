extends GdUnitTestSuite

## Settings screen reachability (task brief item 4: "the pause menu and
## run-end screens already open it via RunFlowController - keep that
## working. ADD a Settings button to the title screen ... and to the
## Hub / War Camp"). One file covering all three reachability points, since
## each is a short, independent wiring check rather than a full suite of its
## own.
##
## `GameSettings` is redirected to a throwaway path in every test (hard
## constraint) even though none of these tests change a row's value -- both
## `TitleScreen._ready()` and `HubScreen`'s own SettingsMenu child are built
## unconditionally, and a future change to either must not regain a real-disk
## touch silently.

const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

var _dir: String


func before_test() -> void:
	_dir = "user://__settings_reachability_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	MetaProgress.set_base_path_for_test("user://")
	get_tree().paused = false # safety net, matching run_flow_check_test.gd's own after_test()


# --- Title screen -------------------------------------------------------------

func test_title_screen_has_a_settings_button_that_opens_settings() -> void:
	var title: TitleScreen = auto_free(TitleScreen.new())
	add_child(title)
	assert_object(title.get_settings_button_for_test()).is_not_null()
	assert_bool(title.get_settings_menu_for_test().is_active_for_test()).is_false()

	title.get_settings_button_for_test().pressed.emit()
	assert_bool(title.get_settings_menu_for_test().is_active_for_test()).append_failure_message("pressing Title's Settings button must open its SettingsMenu").is_true()


func test_title_screen_settings_closes_and_returns() -> void:
	var title: TitleScreen = auto_free(TitleScreen.new())
	add_child(title)
	title.get_settings_button_for_test().pressed.emit()
	title.get_settings_menu_for_test().closed.emit()
	assert_bool(title.get_settings_menu_for_test().is_active_for_test()).is_false()


# --- Hub (War Camp) -------------------------------------------------------------

func test_hub_screen_has_a_settings_button_that_opens_settings() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	assert_object(hub.get_settings_button_for_test()).is_not_null()
	assert_bool(hub.get_settings_menu_for_test().is_active_for_test()).is_false()

	hub.get_settings_button_for_test().pressed.emit()
	assert_bool(hub.get_settings_menu_for_test().is_active_for_test()).append_failure_message("pressing the Hub's Settings button must open its SettingsMenu").is_true()


func test_hub_screen_settings_closes_and_returns() -> void:
	var hub: HubScreen = auto_free(HubScreen.new())
	add_child(hub)
	hub.get_settings_button_for_test().pressed.emit()
	hub.get_settings_menu_for_test().closed.emit()
	assert_bool(hub.get_settings_menu_for_test().is_active_for_test()).is_false()


# --- Pause menu (RunFlowController, unchanged wiring) ------------------------

func _make_controller() -> RunFlowController:
	var controller: RunFlowController = RunFlowControllerScript.new() as RunFlowController
	var pause: Node = auto_free(PauseAuthorityScript.new())
	add_child(pause)
	controller.set_pause_authority_for_test(pause)
	var clock: Node = SimClockScript.new()
	auto_free(clock)
	controller.set_sim_clock_for_test(clock)
	auto_free(controller)
	add_child(controller)
	return controller


func test_pause_menu_settings_option_still_opens_settings() -> void:
	var controller: RunFlowController = _make_controller()
	controller.pause_menu.settings_requested.emit()
	assert_int(controller.get_ui_mode_for_test()).is_equal(RunFlowController.UiMode.SETTINGS_FROM_PAUSE)
	assert_bool(controller.settings_menu.is_active_for_test()).is_true()


func test_pause_menu_settings_closed_returns_to_pause() -> void:
	var controller: RunFlowController = _make_controller()
	controller.pause_menu.settings_requested.emit()
	controller.settings_menu.closed.emit()
	assert_int(controller.get_ui_mode_for_test()).is_equal(RunFlowController.UiMode.PAUSE)
	assert_bool(controller.settings_menu.is_active_for_test()).is_false()

extends GdUnitTestSuite

## RunFlowController <-> MetaProgress settlement integration (Meta layer
## core, build brief item 6: "window-close path settles"; docs/18 section 6:
## "Player and Tower die on the same tick -> one settlement", "Abandon from
## the pause menu -> Failure settlement, committed, then the results
## screen", "Window closed mid-run -> Treated as an abandon: settle, save,
## quit"). Every test redirects the REAL `MetaProgress` autoload to a
## throwaway directory FIRST (hard constraint: never touch the real
## `user://profile.json`) -- `RunFlowController._end_run()`/
## `_on_close_requested()` call the real Autoload directly (it is a
## singleton, like `EventBus`/`SimClock`), so this suite cannot inject a
## fake the way it injects a fake clock/wave-director/pause-authority.
##
## Mirrors tests/unit/run_flow_check_test.gd's own fixture shape
## (`_make_controller`/`_make_clock`/`_make_fake_wave_director`) rather than
## duplicating a second one; extended here with `set_event_bus_for_test()`
## (kill counting) and `MetaProgress` redirection.
##
## Deliberately does NOT exercise `_on_main_menu_requested()`'s "already
## ended -> title" branch or `_on_continue_requested()`'s own scene change
## -- both call `get_tree().change_scene_to_file()`, which is unchanged,
## pre-existing behaviour this task did not touch the mechanics of (only
## the BRANCHING that decides whether to take it), and swapping the actual
## running scene mid-unit-test risks destabilising the rest of this suite
## for no coverage this task's brief asks for. The ABANDON branch tested
## below never reaches that line.

const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_run_flow_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")
	get_tree().paused = false # run_flow_check_test.gd's own safety net -- see that file's after_test()


func _make_fake_wave_director(wave_index: int, wave_count: int) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nsignal sequence_completed()\nsignal wave_ended(wave_id: String, wave_index: int)\nvar waves: Array = []\nvar wave_index_for_test: int = 0\nfunc get_current_wave_index_for_test() -> int:\n\treturn wave_index_for_test\n"
	script.reload()
	var n: Node = Node.new()
	n.set_script(script)
	var waves_array: Array = n.get("waves")
	for _i in wave_count:
		waves_array.append(null)
	n.set("waves", waves_array)
	n.set("wave_index_for_test", wave_index)
	add_child(n)
	auto_free(n)
	return n


func _make_fake_event_bus() -> Node:
	var bus := Node.new()
	bus.add_user_signal("player_died", [
		{"name": "entity", "type": TYPE_OBJECT}, {"name": "position", "type": TYPE_VECTOR2}, {"name": "timestamp", "type": TYPE_FLOAT},
	])
	bus.add_user_signal("enemy_died", [
		{"name": "entity", "type": TYPE_OBJECT}, {"name": "position", "type": TYPE_VECTOR2}, {"name": "timestamp", "type": TYPE_FLOAT},
	])
	add_child(bus)
	auto_free(bus)
	return bus


func _make_controller(clock: Node, wd: Node) -> RunFlowController:
	var controller: RunFlowController = RunFlowControllerScript.new() as RunFlowController
	var pause: Node = auto_free(PauseAuthorityScript.new())
	add_child(pause)
	controller.set_pause_authority_for_test(pause)
	controller.set_sim_clock_for_test(clock)
	controller.set_wave_director_for_test(wd)
	controller.set_event_bus_for_test(_make_fake_event_bus())
	controller.set_suppress_quit_for_test(true) # never actually quit the test runner
	auto_free(controller)
	add_child(controller)
	controller.set_run_inventory(RunInventoryScript.new() as RunInventory)
	return controller


func _make_clock(start_now: float) -> Node:
	var clock: Node = SimClockScript.new()
	clock.now = start_now
	auto_free(clock)
	return clock


# --- Window close mid-run (D113) ---------------------------------------------

## FALSIFICATION (named in the report): temporarily gating
## `RunFlowController._on_close_requested()`'s settle_run() call behind
## `if false and ...` made this test fail (Cores stayed at 0 instead of
## increasing). Reverted after confirming the failure.
func test_window_close_during_a_run_settles_as_abandon_and_saves() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(1, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	clock.now = 120.0 # 2 minutes survived -> 2 Cores by the settlement formula alone

	var cores_before: int = MetaProgress.get_cores()
	controller.simulate_close_requested_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("closing the window mid-run must settle (Register: 1 Core/minute)").is_greater(cores_before)
	assert_int(controller.get_state_for_test()).append_failure_message("a window-close settles quietly -- it does not transition through the normal end-of-run UI state").is_equal(RunFlowController.State.RUNNING)

	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).append_failure_message("the window-close settlement must be committed to disk, not left in memory only").is_greater(cores_before)


func test_window_close_after_the_run_already_ended_does_not_settle_twice() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(1, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	clock.now = 60.0
	controller.simulate_player_died_for_test()
	await get_tree().process_frame
	var cores_after_death: int = MetaProgress.get_cores()

	controller.simulate_close_requested_for_test()

	assert_int(MetaProgress.get_cores()).append_failure_message("a close after the run already settled must not pay again").is_equal(cores_after_death)


# --- Abandon via the pause menu (D109/D113) -----------------------------------

func test_abandon_via_pause_menu_settles_and_shows_the_run_end_screen_not_the_title() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(2, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	clock.now = 60.0

	var cores_before: int = MetaProgress.get_cores()
	controller.simulate_main_menu_requested_for_test() # pause menu's "Main Menu", run still live

	assert_int(controller.get_state_for_test()).is_equal(RunFlowController.State.ENDED)
	assert_int(controller.get_end_cause_for_test()).append_failure_message("the pause menu's Main Menu while live must settle as EndCause.ABANDONED, not go straight to the title").is_equal(RunFlowController.EndCause.ABANDONED)
	assert_int(controller.get_ui_mode_for_test()).append_failure_message("build brief: abandon shows the run-end screen, not the title").is_equal(RunFlowController.UiMode.RUN_END)
	assert_bool(controller.run_end_screen.is_active_for_test()).is_true()
	assert_int(MetaProgress.get_cores()).append_failure_message("an abandon must still settle (as a failure)").is_greater(cores_before)


func test_abandoned_run_end_summary_shows_a_cause_line_styled_as_a_defeat() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(0, 8)
	var controller: RunFlowController = _make_controller(clock, wd)

	controller.simulate_main_menu_requested_for_test()

	var run_end: RunEndScreen = controller.run_end_screen
	assert_bool(run_end.get_cause_label_for_test().visible).append_failure_message("an abandoned run must show a cause line (it is a failure, not a victory)").is_true()


# --- Same-tick double death (docs/18 section 6) -------------------------------

## Both `simulate_player_died_for_test()` and `simulate_tower_destroyed_for_test()`
## queue their real `_end_run()` call via `call_deferred()` (unchanged,
## pre-existing behaviour) -- both fire in the SAME frame here, exactly
## modelling "Player and Tower die on the same tick." `_end_run()`'s own
## `_state == State.ENDED` guard must let only the FIRST one through.
func test_player_and_tower_dying_the_same_tick_settles_exactly_once() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(1, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	clock.now = 90.0

	var cores_before: int = MetaProgress.get_cores()
	controller.simulate_player_died_for_test()
	controller.simulate_tower_destroyed_for_test()
	await get_tree().process_frame

	assert_int(controller.get_end_cause_for_test()).append_failure_message("the FIRST death to actually run _end_run() must win; the second must be a no-op").is_equal(RunFlowController.EndCause.PLAYER_DEFEATED)

	var cores_after_first_settlement: int = MetaProgress.get_cores()
	assert_int(cores_after_first_settlement).is_greater(cores_before)

	# A further close/abandon attempt after this must not pay again either.
	controller.simulate_close_requested_for_test()
	assert_int(MetaProgress.get_cores()).is_equal(cores_after_first_settlement)


# --- Kills / waves feed the settlement formula (Meta: Run-End Settlement) ----

func test_kills_and_waves_cleared_during_the_run_feed_the_settlement_formula() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(2, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	assert_int(controller.get_kill_count_for_test()).is_equal(0)
	assert_int(controller.get_waves_cleared_for_test()).is_equal(0)

	var bus: Object = controller.get("_event_bus")
	for i in 30:
		bus.emit_signal("enemy_died", null, Vector2.ZERO, 0.0)
	wd.emit_signal("wave_ended", "wave_1", 0)
	wd.emit_signal("wave_ended", "wave_2", 1)

	assert_int(controller.get_kill_count_for_test()).is_equal(30)
	assert_int(controller.get_waves_cleared_for_test()).is_equal(2)

	clock.now = 0.0 # isolate the kills/waves terms: 0 minutes, no victory
	controller.simulate_close_requested_for_test()

	# floor(30/25)=1 Core (kills) + 2*2=4 Cores (waves) + 0 (time) = 5
	MetaProgress.reload_for_test()
	assert_int(MetaProgress.get_cores()).is_equal(5)

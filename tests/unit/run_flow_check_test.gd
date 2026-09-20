extends GdUnitTestSuite

## Run flow check (P2.14 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Technical Tests > "Run flow check": "The
## run-end screens show the death cause or the final wave reached, the
## Scrap held, and the time survived." Exercises the REAL
## src/run/run_flow_controller.gd and src/ui/run_end.gd this task built.
##
## Three end paths, matching run_flow_controller.gd's own `EndCause`
## interpretation (class header, "The death cause or the final wave
## reached"): player death and Tower destruction both show a cause line
## (plus wave reached, Scrap held, time survived); the wave sequence
## completing with nobody dead shows wave reached alone, with NO cause
## line, since there is no cause to report.

const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")


func after_test() -> void:
	# Safety net (pause_clock_test.gd's own precedent): every test below
	# ends a run, which pushes REASON_RUN_ENDED and never pops it. Every
	# test injects a FRESH PauseAuthority (never the real autoload), but a
	# failed assertion mid-test must still never leak a stuck pause into the
	# SHARED tree for a suite that runs after this one.
	get_tree().paused = false


## `wave_index` is the RAW, 0-based array index src/director/wave_director.gd's
## own `_current_wave_index` field actually holds (confirmed by reading that
## file directly: -1 before any wave opens, 0 for the first) --
## run_flow_controller.gd's own `_capture_final_wave()` converts this to the
## 1-based "wave n/total" display number this file's assertions check
## against, so a caller here passes `n - 1` for a desired display of "n".
func _make_fake_wave_director(wave_index: int, wave_count: int) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nsignal sequence_completed()\nvar waves: Array = []\nvar wave_index_for_test: int = 0\nfunc get_current_wave_index_for_test() -> int:\n\treturn wave_index_for_test\n"
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


func _make_controller(clock: Node, wd: Node) -> RunFlowController:
	var controller: RunFlowController = RunFlowControllerScript.new() as RunFlowController
	var pause: Node = auto_free(PauseAuthorityScript.new()) # never the real autoload -- see this file's after_test() note
	add_child(pause)
	controller.set_pause_authority_for_test(pause) # must be set BEFORE add_child(), matching set_sim_clock_for_test() below
	controller.set_sim_clock_for_test(clock) # must be set BEFORE add_child(), since _ready() snapshots the run start time -- see run_flow_controller.gd's own set_*_for_test convention
	controller.set_wave_director_for_test(wd)
	auto_free(controller)
	add_child(controller)
	return controller


func _make_clock(start_now: float) -> Node:
	var clock: Node = SimClockScript.new()
	clock.now = start_now
	auto_free(clock)
	return clock


func test_player_death_shows_cause_wave_scrap_and_time() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(2, 4) # raw index 2 -> displays "3/4"
	var controller: RunFlowController = _make_controller(clock, wd)
	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.scrap_current = 0 # already zeroed by RunInventory's own player_died handler in a real run -- scrap_loss_test.gd proves that path; this test only proves the SCREEN reads it
	controller.set_run_inventory(inventory)

	clock.now = 95.0 # 1:35 survived
	controller.simulate_player_died_for_test()
	await get_tree().process_frame

	var run_end: RunEndScreen = controller.run_end_screen
	assert_int(controller.get_state_for_test()).is_equal(RunFlowController.State.ENDED)
	assert_bool(run_end.get_cause_label_for_test().visible).append_failure_message("player-death run-end screen must show a cause line").is_true()
	assert_str(run_end.get_cause_label_for_test().text).contains(tr("RUN_END_CAUSE_PLAYER"))
	assert_bool(run_end.get_wave_label_for_test().visible).is_true()
	assert_str(run_end.get_wave_label_for_test().text).contains("3/4")
	assert_str(run_end.get_scrap_label_for_test().text).contains(": 0")
	assert_str(run_end.get_time_label_for_test().text).append_failure_message("expected 1:35, got '%s'" % run_end.get_time_label_for_test().text).contains("1:35")


func test_tower_destroyed_shows_cause_wave_scrap_and_time() -> void:
	var clock: Node = _make_clock(10.0)
	var wd: Node = _make_fake_wave_director(4, 8) # raw index 4 -> displays "5/8"
	var controller: RunFlowController = _make_controller(clock, wd)
	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.scrap_current = 42
	controller.set_run_inventory(inventory)

	clock.now = 70.0 # 60 s survived
	controller.simulate_tower_destroyed_for_test()
	await get_tree().process_frame

	var run_end: RunEndScreen = controller.run_end_screen
	assert_int(controller.get_end_cause_for_test()).is_equal(RunFlowController.EndCause.TOWER_DESTROYED)
	assert_bool(run_end.get_cause_label_for_test().visible).is_true()
	assert_str(run_end.get_cause_label_for_test().text).contains(tr("RUN_END_CAUSE_TOWER"))
	assert_str(run_end.get_wave_label_for_test().text).contains("5/8")
	assert_str(run_end.get_scrap_label_for_test().text).contains(": 42")
	assert_str(run_end.get_time_label_for_test().text).contains("1:00")


func test_sequence_completed_shows_wave_reached_with_no_cause_line() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(7, 8) # raw index 7 -> displays "8/8"
	var controller: RunFlowController = _make_controller(clock, wd)
	var inventory: RunInventory = RunInventoryScript.new() as RunInventory
	inventory.scrap_current = 17
	controller.set_run_inventory(inventory)

	clock.now = 480.0 # 8:00 survived
	controller.simulate_sequence_completed_for_test()
	await get_tree().process_frame

	var run_end: RunEndScreen = controller.run_end_screen
	assert_int(controller.get_end_cause_for_test()).is_equal(RunFlowController.EndCause.SEQUENCE_COMPLETED)
	assert_bool(run_end.get_cause_label_for_test().visible).append_failure_message("a run that ends by clearing the sequence (no death) must show no cause line").is_false()
	assert_bool(run_end.get_wave_label_for_test().visible).is_true()
	assert_str(run_end.get_wave_label_for_test().text).contains("8/8")
	assert_str(run_end.get_scrap_label_for_test().text).contains(": 17")
	assert_str(run_end.get_time_label_for_test().text).contains("8:00")


## The run-end screen must actually be the visible one once the run ends --
## not merely populated with the right text while some other UI mode stays
## on screen (the class of bug this project's HUD layout lesson warns
## against: content correct, presentation wrong).
func test_run_end_screen_becomes_the_active_ui_once_the_run_ends() -> void:
	var clock: Node = _make_clock(0.0)
	var wd: Node = _make_fake_wave_director(1, 8)
	var controller: RunFlowController = _make_controller(clock, wd)
	controller.set_run_inventory(RunInventoryScript.new() as RunInventory)

	assert_bool(controller.run_end_screen.is_active_for_test()).is_false()
	controller.simulate_player_died_for_test()
	await get_tree().process_frame

	assert_int(controller.get_ui_mode_for_test()).is_equal(RunFlowController.UiMode.RUN_END)
	assert_bool(controller.run_end_screen.is_active_for_test()).append_failure_message("run-end fields were populated but the screen itself was never made active").is_true()
	assert_bool(controller.pause_menu.is_active_for_test()).is_false()
	assert_bool(controller.settings_menu.is_active_for_test()).is_false()

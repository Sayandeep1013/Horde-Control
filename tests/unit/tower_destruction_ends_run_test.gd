extends GdUnitTestSuite

## D139 (balance pass 2026-10-05) hang investigation. A previous agent
## reported that destroying the Tower (1000 damage through
## `TowerHealth._on_hurtbox_damage_received`) in a headless test of the
## assembled prototype scene "hangs the run". Finding, by experiment: the
## real game does not hang. The run ends one frame later with cause
## TOWER_DESTROYED and the run-end panel up (headless SceneTree probe; the
## balance bot's losing runs end the same way). The test itself also passes in
## ~120 ms. What stalls is the gdUnit4 PROCESS AT EXIT: `_end_run()` pushes the
## run-ended pause reason on the global PauseAuthority autoload, the autoload
## outlives the test scene, and the runner then never exits while the tree is
## still paused (reproduced: exit code 124 from `timeout`, test PASSED; with
## the cleanup in `after_test()` below the process exits 0). So the fix is test
## hygiene, not game code. This test drives the destruction with a bounded
## frame loop (never a timer) and a gdUnit4 timeout guard.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")
const MAX_FRAMES: int = 120

var _dir: String
var _proto: Node


func before_test() -> void:
	_dir = "user://__tower_destruction_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir) # the run-end settlement must not touch the real profile
	_proto = auto_free(PrototypeScene.instantiate())
	_proto.run_seed = 1
	add_child(_proto)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")
	# `_end_run()` leaves the run-ended pause reason pushed on the global
	# PauseAuthority autoload; the autoload outlives the test, and a tree that
	# is still paused at process exit is what stalls the runner.
	for reason in PauseAuthority.get_active_reasons():
		PauseAuthority.pop_reason_immediate(reason)


func _wait_for_run_end(rfc: Node) -> int:
	var frames: int = 0
	while rfc.get_state_for_test() != RunFlowController.State.ENDED and frames < MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	return frames


func test_destroying_the_tower_ends_the_run_with_the_run_end_screen(timeout: int = 20000) -> void:
	var tower: Tower = _proto.get_node("Main/Tower") as Tower
	var rfc: RunFlowController = _proto.get_node("RunFlowController") as RunFlowController
	await get_tree().process_frame

	tower.health._on_hurtbox_damage_received(1000.0, null, null)
	var frames: int = await _wait_for_run_end(rfc)

	assert_bool(tower.health.is_destroyed()).is_true()
	assert_int(rfc.get_state_for_test()).append_failure_message("run did not end within %d frames of the Tower being destroyed" % MAX_FRAMES).is_equal(RunFlowController.State.ENDED)
	assert_int(frames).is_less(MAX_FRAMES)
	assert_int(rfc.get_end_cause_for_test()).is_equal(RunFlowController.EndCause.TOWER_DESTROYED)
	assert_int(rfc.get_ui_mode_for_test()).append_failure_message("the run-end screen is not showing").is_equal(RunFlowController.UiMode.RUN_END)

extends GdUnitTestSuite

## Pause authority test, full (P2.14 named acceptance test). MASTER_SDLC.md
## > Acceptance Test Matrix > Technical Tests > "Pause authority test":
## "With the Level-Up Draft open, the pause menu open, or focus lost, no
## enemy, projectile, pickup, timer, or telegraph changes state for 10
## seconds (the prototype has no hazards)."
##
## Runs the REAL, fully assembled `scenes/prototype.tscn` (matching
## tests/unit/prototype_wave_integration_test.gd's own precedent for
## exactly this reason: a component-level suite proving PauseAuthority
## correct in isolation is not the same claim as "the assembled game
## actually freezes when paused" -- this project has already been bitten by
## that exact gap twice, F03-27 and F03-32, both wiring defects invisible
## to every component-level suite). Pushes each of the three named reasons
## on the REAL `PauseAuthority` autoload (the same singleton every node in
## the assembled scene already reads) and asserts, over a full REAL
## 10-second window (600 physics ticks, not a shortcut), that:
## `SimClock.now` does not advance; every live enemy's position is
## bit-identical; live enemy/projectile/pickup counts never change; and at
## least one enemy's own wind-up/telegraph state never changes either.
##
## This is one process-wide singleton test: `PauseAuthority` and
## `SimClock` are real Autoloads, shared with every other suite in this
## same gdUnit4 run. Every reason pushed here is popped again before this
## function returns, and `after_test()` carries an unconditional safety
## net (mirroring tests/unit/pause_clock_test.gd's own precedent) so a
## failed assertion mid-test can never leak a stuck pause into a suite that
## runs afterward.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")
const TICKS_FOR_TEN_SECONDS: int = 600 # 10 s at the pinned 60 Hz physics rate (docs/20 > Version; SimClock.PHYSICS_STEP)

var _root: Node


func before_test() -> void:
	_root = auto_free(PrototypeScene.instantiate())
	add_child(_root)
	# Several unpaused settle frames: EntitySpawner/WaveDirector/enemy
	# deferred SimLoop registration all resolve on a LATER frame than
	# _ready() (see sim_loop.gd's own header, "Reaching this instance from
	# elsewhere"), and this suite's own snapshot must be taken against a
	# scene that has already finished settling, not mid-wire-up.
	for _i in 5:
		await get_tree().physics_frame


func after_test() -> void:
	for reason in [PauseAuthority.REASON_DRAFT, PauseAuthority.REASON_PAUSE_MENU, PauseAuthority.REASON_FOCUS_LOSS]:
		PauseAuthority.pop_reason_immediate(reason)
	# Safety net (pause_clock_test.gd's own precedent): never leave the
	# REAL, process-wide singleton's shared tree paused for a suite that
	# runs after this one.
	get_tree().paused = false
	if is_instance_valid(_root):
		var spawner: Node = _root.get_node_or_null("Main/EntitySpawner")
		if spawner != null and spawner.has_method("clear_all_for_test"):
			spawner.clear_all_for_test()


func _spawner() -> Node:
	return _root.get_node_or_null("Main/EntitySpawner")


func _live_enemies() -> Array[Node2D]:
	return EntityRegistry.get_entities_with_tag(&"enemy")


func _snapshot() -> Dictionary:
	var enemies: Array[Node2D] = _live_enemies()
	var positions: Dictionary = {}
	var windups: Dictionary = {}
	for e in enemies:
		positions[e.get_instance_id()] = e.global_position
		if e.has_method(&"is_windup_active"):
			windups[e.get_instance_id()] = e.is_windup_active()
	var spawner: Node = _spawner()
	return {
		"sim_time": SimClock.now,
		"enemy_count": enemies.size(),
		"positions": positions,
		"windups": windups,
		"projectile_count": spawner.get_projectile_count() if spawner != null else -1,
		"pickup_count": spawner.get_pickup_count() if spawner != null else -1,
	}


func _assert_snapshot_unchanged(before: Dictionary, after: Dictionary, reason_name: String) -> void:
	assert_float(after["sim_time"]).append_failure_message("[%s] SimClock.now advanced while paused: %f -> %f" % [reason_name, before["sim_time"], after["sim_time"]]).is_equal(before["sim_time"])
	assert_int(after["enemy_count"]).append_failure_message("[%s] live enemy count changed while paused" % reason_name).is_equal(before["enemy_count"])
	assert_int(after["projectile_count"]).append_failure_message("[%s] live projectile count changed while paused" % reason_name).is_equal(before["projectile_count"])
	assert_int(after["pickup_count"]).append_failure_message("[%s] live pickup count changed while paused" % reason_name).is_equal(before["pickup_count"])

	var before_positions: Dictionary = before["positions"]
	var after_positions: Dictionary = after["positions"]
	for id in before_positions.keys():
		assert_bool(after_positions.has(id)).append_failure_message("[%s] an enemy present before the pause is gone after it" % reason_name).is_true()
		if after_positions.has(id):
			assert_vector(after_positions[id]).append_failure_message("[%s] enemy %s moved while paused: %s -> %s" % [reason_name, id, before_positions[id], after_positions[id]]).is_equal(before_positions[id])

	var before_windups: Dictionary = before["windups"]
	var after_windups: Dictionary = after["windups"]
	for id in before_windups.keys():
		if after_windups.has(id):
			assert_bool(after_windups[id]).append_failure_message("[%s] enemy %s's wind-up/telegraph state changed while paused" % [reason_name, id]).is_equal(before_windups[id])


func _run_one_reason(reason: StringName, reason_name: String) -> void:
	assert_bool(get_tree().paused).append_failure_message("test setup: the tree was already paused before %s was pushed" % reason_name).is_false()
	var before: Dictionary = _snapshot()

	PauseAuthority.push_reason_immediate(reason)
	assert_bool(get_tree().paused).append_failure_message("[%s] PauseAuthority did not actually pause the tree" % reason_name).is_true()

	for _i in TICKS_FOR_TEN_SECONDS:
		await get_tree().physics_frame

	var after: Dictionary = _snapshot()
	_assert_snapshot_unchanged(before, after, reason_name)

	PauseAuthority.pop_reason_immediate(reason)
	assert_bool(get_tree().paused).append_failure_message("[%s] PauseAuthority did not unpause once its reason was popped" % reason_name).is_false()

	# Complementary check: SimClock genuinely resumes once unpaused (proves
	# the freeze above was PauseAuthority's doing, not some unrelated stall).
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(SimClock.now).append_failure_message("[%s] SimClock.now did not resume advancing after the pause reason was popped" % reason_name).is_greater(after["sim_time"])


func test_draft_open_freezes_every_enemy_projectile_pickup_and_telegraph_for_ten_seconds() -> void:
	await _run_one_reason(PauseAuthority.REASON_DRAFT, "draft")


func test_pause_menu_open_freezes_every_enemy_projectile_pickup_and_telegraph_for_ten_seconds() -> void:
	await _run_one_reason(PauseAuthority.REASON_PAUSE_MENU, "pause_menu")


func test_focus_lost_freezes_every_enemy_projectile_pickup_and_telegraph_for_ten_seconds() -> void:
	await _run_one_reason(PauseAuthority.REASON_FOCUS_LOSS, "focus_loss")

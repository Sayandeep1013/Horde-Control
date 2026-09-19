extends GdUnitTestSuite

## Player movement check (P2.1; MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests > "Player movement check"; PLAN.md P2.1 exit criterion:
## "Movement-only run through an empty arena at reference speed and
## acceleration"). Values asserted against come from data/player/
## prototype.tres (PlayerDefinition, Register > Player & Weapons >
## "Player health / speed / accel / stop": 320 px/s, full speed in 0.08 s,
## stop in 0.05 s), read back through the same resource the controller
## itself reads, never restated as bare literals.
##
## Asserts the CURVE, not just the top speed (task brief: "a controller
## that snaps instantly to full speed would pass a top-speed-only
## assertion"): every ramp test samples multiple intermediate ticks and
## checks each one against the exact value move_toward() at a constant rate
## produces for that many elapsed physics ticks, not only the final value.
##
## Drives the REAL `_physics_process()` via `await get_tree().physics_frame`
## (this suite's own tree, not scenes/main.tscn -- see player.gd's header
## for why SimLoop cannot be wired into this task), matching the warm-up-
## tick idiom pause_clock_test.gd and sim_loop_order_test.gd already use: a
## freshly add_child()-ed node is not guaranteed to receive its first
## _physics_process on the very next awaited physics_frame.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const TOLERANCE: float = 0.5 # px/s -- generous enough for one tick's floating point drift, tight enough that a snap-to-target bug (hundreds of px/s off) still fails

var _player: Player
var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)

	_player = auto_free(PlayerScene.instantiate()) as Player
	_player.set_registry_for_test(_registry) # BEFORE add_child -- see player.gd's _ready() guard comment
	add_child(_player)
	await get_tree().physics_frame # warm-up tick, uncounted (see file header)


func after_test() -> void:
	_player.clear_input_direction_override_for_test()
	SimClock.time_scale = SimClock.TIME_SCALE_MAX # safety net: never leave the shared autoload's time_scale altered for suites that run after this one
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")


func _expected_ramp_speed(rate: float, ticks: int, reference_speed: float) -> float:
	return minf(reference_speed, rate * ticks * SimClock.PHYSICS_STEP)


# --- Acceleration curve, not just top speed --------------------------------

func test_accelerates_along_a_linear_curve_not_an_instant_snap() -> void:
	var reference_speed: float = _player.definition.base_speed_px_per_second
	var rate: float = _player.get_acceleration_rate_for_test()
	assert_float(rate).append_failure_message("acceleration rate must be derived from base_speed / acceleration_time_seconds, both Register-sourced").is_equal_approx(reference_speed / _player.definition.acceleration_time_seconds, 0.001)

	_player.set_input_direction_for_test(Vector2.RIGHT)

	var samples: Array[float] = []
	for tick in range(1, 6): # ticks 1..5; accel_time_seconds (0.08s) = 4.8 ticks at 60Hz, so tick 5 is the first fully-clamped sample
		await get_tree().physics_frame
		samples.append(_player.velocity.x)

	# Tick 1 must be a SMALL fraction of top speed, not the whole thing --
	# this is what a "snaps instantly to full speed" bug would fail.
	assert_float(samples[0]).append_failure_message("tick 1 velocity.x=%f reached (or nearly reached) top speed %f -- movement is snapping instantly instead of ramping" % [samples[0], reference_speed]).is_less(reference_speed * 0.5)

	for tick in range(1, 6):
		var expected: float = _expected_ramp_speed(rate, tick, reference_speed)
		assert_float(samples[tick - 1]).append_failure_message("tick %d: expected velocity.x ~= %f (linear ramp at rate %f px/s^2), got %f" % [tick, expected, rate, samples[tick - 1]]).is_equal_approx(expected, TOLERANCE)

	# By tick 5 the ramp must have reached EXACTLY the reference speed
	# ("reaches exactly the Register's reference speed" -- move_toward()
	# clamps to the target rather than only approaching it asymptotically).
	assert_float(samples[4]).append_failure_message("expected exactly the Register reference speed %f by tick 5, got %f" % [reference_speed, samples[4]]).is_equal_approx(reference_speed, TOLERANCE)

	# One more tick must stay clamped, not overshoot.
	await get_tree().physics_frame
	assert_float(_player.velocity.x).is_equal_approx(reference_speed, TOLERANCE)


# --- Deceleration ("stop") curve, not just "eventually zero" --------------

func test_decelerates_along_a_linear_curve_to_exactly_zero_in_register_stop_time() -> void:
	var reference_speed: float = _player.definition.base_speed_px_per_second
	var decel_rate: float = _player.get_deceleration_rate_for_test()
	assert_float(decel_rate).is_equal_approx(reference_speed / _player.definition.deceleration_time_seconds, 0.001)

	# Reach full speed first (bypassing the accel ramp so this test measures
	# ONLY deceleration) via the test-only velocity seam.
	_player.set_local_velocity_for_test(Vector2(reference_speed, 0.0))
	_player.set_input_direction_for_test(Vector2.ZERO)

	var samples: Array[float] = []
	for tick in range(1, 4): # deceleration_time_seconds (0.05s) = exactly 3 ticks at 60Hz
		await get_tree().physics_frame
		samples.append(_player.velocity.x)

	assert_float(samples[0]).append_failure_message("tick 1 velocity.x=%f dropped straight to (or near) zero -- stopping is snapping instantly instead of ramping down" % samples[0]).is_greater(reference_speed * 0.5)

	for tick in range(1, 4):
		var expected_drop: float = minf(reference_speed, decel_rate * tick * SimClock.PHYSICS_STEP)
		var expected: float = reference_speed - expected_drop
		assert_float(samples[tick - 1]).append_failure_message("tick %d: expected velocity.x ~= %f while stopping, got %f" % [tick, expected, samples[tick - 1]]).is_equal_approx(expected, TOLERANCE)

	# Exactly zero at tick 3 (0.05 s == deceleration_time_seconds exactly).
	assert_float(samples[2]).append_failure_message("expected exactly 0 velocity.x after the Register's 0.05s stop time, got %f" % samples[2]).is_equal_approx(0.0, TOLERANCE)


# --- Eight-direction movement: diagonals do not exceed reference speed -----

func test_diagonal_input_caps_at_reference_speed_not_faster() -> void:
	var reference_speed: float = _player.definition.base_speed_px_per_second
	var diagonal: Vector2 = Vector2(1.0, 1.0).normalized() # what Input.get_vector() itself produces for two simultaneous full-strength axes
	_player.set_input_direction_for_test(diagonal)

	for _i in range(8): # generous -- well past the 4.8-tick accel ramp
		await get_tree().physics_frame

	assert_float(_player.velocity.length()).append_failure_message("diagonal movement reached speed %f, expected exactly the reference speed %f (un-normalized diagonal input would over-speed by sqrt(2))" % [_player.velocity.length(), reference_speed]).is_equal_approx(reference_speed, TOLERANCE)
	assert_vector(_player.velocity.normalized()).is_equal_approx(diagonal, Vector2(0.01, 0.01))


# --- Global Simulation Authority: velocity scaled by SimClock.time_scale --

func test_velocity_handed_to_move_and_slide_is_scaled_by_sim_clock_time_scale() -> void:
	var reference_speed: float = _player.definition.base_speed_px_per_second
	# Already at the target for the held direction, so move_toward() cannot
	# change the unscaled accumulator this tick -- isolates the time_scale
	# multiply from the acceleration ramp.
	_player.set_local_velocity_for_test(Vector2(reference_speed, 0.0))
	_player.set_input_direction_for_test(Vector2.RIGHT)

	SimClock.time_scale = 0.5
	await get_tree().physics_frame
	var scaled_velocity_x: float = _player.velocity.x
	var unscaled_after: float = _player.get_local_velocity_for_test().x
	SimClock.time_scale = SimClock.TIME_SCALE_MAX

	assert_float(scaled_velocity_x).append_failure_message("velocity.x=%f while SimClock.time_scale=0.5 and unscaled velocity=%f -- expected ~%f (half), per Global Simulation Authority: movers multiply velocity by SimClock.time_scale before moving" % [scaled_velocity_x, reference_speed, reference_speed * 0.5]).is_equal_approx(reference_speed * 0.5, TOLERANCE)
	# The PERSISTENT accumulator must stay unscaled, or the next tick's ramp
	# would integrate from an already-halved base and compound the scale.
	assert_float(unscaled_after).append_failure_message("the unscaled _local_velocity accumulator changed to %f under time_scale=0.5 -- it must stay at the pre-scale reference speed %f so scaling never compounds tick over tick" % [unscaled_after, reference_speed]).is_equal_approx(reference_speed, TOLERANCE)


# --- Positive control: the real Input Map action path actually works ------

func test_real_input_action_drives_movement_without_the_test_override() -> void:
	_player.clear_input_direction_override_for_test()
	Input.action_press(&"move_right")

	for _i in range(8):
		await get_tree().physics_frame

	Input.action_release(&"move_right")

	assert_float(_player.velocity.x).append_failure_message("holding the real move_right InputMap action (no test override) produced velocity.x=%f -- the production Input.get_vector() path is not driving movement at all, which would make every override-based test above meaningless" % _player.velocity.x).is_equal_approx(_player.definition.base_speed_px_per_second, TOLERANCE)


# --- EntityRegistry wiring (task brief: "register the player") ------------

func test_player_is_registered_with_the_player_tag_on_ready() -> void:
	assert_bool(_registry.is_registered(_player)).is_true()
	var found: Array = _registry.get_entities_with_tag(&"player")
	assert_array(found).append_failure_message("expected the player instance itself in get_entities_with_tag(&\"player\")").contains([_player])


func test_registry_position_tracks_the_player_as_it_moves() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	for _i in range(10):
		await get_tree().physics_frame

	var nearby: Array = _registry.get_entities_in_radius(_player.global_position, 1.0, &"player")
	assert_array(nearby).append_failure_message("EntityRegistry's cached position for the player was not updated to match global_position=%s after 10 ticks of movement -- update_position() is not being called every tick" % str(_player.global_position)).contains([_player])

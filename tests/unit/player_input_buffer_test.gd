extends GdUnitTestSuite

## Input buffer coverage for src/player/player.gd (P2.1; MASTER_SDLC.md >
## Provisional Values Register > Player & Weapons > "Input buffer": "100 ms
## (6 ticks), cleared on pause"; > Movement Design & Input Buffering >
## "Input Buffering Rules").
##
## Player.gd's own header/`_movement_step()` comment documents the
## interpretation this suite tests against: the buffer is real, running,
## Register-timed, pause-cleared state (a typed query,
## `get_buffered_movement_direction()`, for a future Dash system -- Dash is
## explicitly out of this task's scope, PLAN.md P2.1 row), but it does NOT
## feed back into THIS task's own acceleration/deceleration curve, since
## plain directional polling has no cooldown/gate for a press to queue
## against and re-injecting a released direction would read as unwanted
## coasting (contradicting "Base movement must feel responsive with minimal
## acceleration ramp"). `test_buffer_does_not_reintroduce_movement_after_
## release` below is the test that would fail if that interpretation were
## wrong in the other direction (buffer silently driving movement).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _player: Player
var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)

	_player = auto_free(PlayerScene.instantiate()) as Player
	_player.set_registry_for_test(_registry)
	add_child(_player)
	await get_tree().physics_frame # warm-up tick (see player_movement_test.gd's file header)


func after_test() -> void:
	_player.clear_input_direction_override_for_test()
	# Safety net, same pattern pause_clock_test.gd uses: an interrupted test
	# must never leave the SHARED scene tree paused, or PauseAuthority's own
	# reason bookkeeping desynced, for suites that run after this one.
	PauseAuthority.pop_reason(&"debug")
	PauseAuthority.flush()


# --- Register values, read from the resource, not restated -----------------

func test_buffer_duration_matches_register_row() -> void:
	# Register > Player & Weapons > "Input buffer": "100 ms (6 ticks)".
	assert_float(_player.definition.input_buffer.duration_ms).is_equal(100.0)
	assert_int(_player.definition.input_buffer.ticks).is_equal(6)
	assert_float(_player.get_buffer_duration_seconds_for_test()).append_failure_message("controller's internal buffer duration was not derived from definition.input_buffer.duration_ms").is_equal_approx(0.1, 0.0001)


# --- Held-and-released behaviour --------------------------------------------

func test_buffer_holds_the_last_direction_immediately_after_release() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame

	_player.set_input_direction_for_test(Vector2.ZERO) # released THIS tick
	await get_tree().physics_frame

	assert_vector(_player.get_buffered_movement_direction()).append_failure_message("buffer must still hold the last live direction immediately after release, within the Register's 100 ms window").is_equal(Vector2.RIGHT)


func test_buffer_expires_after_the_register_duration() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame
	_player.set_input_direction_for_test(Vector2.ZERO)

	# 6 ticks at 60 Hz == 100 ms exactly; run 8 (2 ticks of margin) so this
	# assertion cannot be a timing coin-flip against exact-boundary rounding.
	for _i in range(8):
		await get_tree().physics_frame

	assert_vector(_player.get_buffered_movement_direction()).append_failure_message("buffer still returned a non-zero direction after 8 ticks (>133 ms), past the Register's 100 ms / 6-tick window").is_equal(Vector2.ZERO)


func test_buffer_refreshes_on_each_new_live_press() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame
	_player.set_input_direction_for_test(Vector2.UP)
	await get_tree().physics_frame
	assert_vector(_player.get_buffered_movement_direction()).append_failure_message("buffer must reflect the MOST RECENT live direction, not the first one pressed").is_equal(Vector2.UP)


# --- The buffer must not silently re-drive movement after release ---------

func test_buffer_does_not_reintroduce_movement_after_release() -> void:
	_player.set_local_velocity_for_test(Vector2(_player.definition.base_speed_px_per_second, 0.0))
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame

	_player.set_input_direction_for_test(Vector2.ZERO) # release
	await get_tree().physics_frame
	var speed_one_tick_after_release: float = _player.velocity.length()

	# The buffer is still holding RIGHT (well within its 100ms window) --
	# confirms this test is exercising the actual overlap case, not a
	# buffer that already expired for an unrelated reason.
	assert_vector(_player.get_buffered_movement_direction()).is_not_equal(Vector2.ZERO)

	assert_float(speed_one_tick_after_release).append_failure_message("speed stayed at reference speed (%f) one tick after release while the input buffer was still holding a direction -- the buffer is incorrectly feeding back into the movement curve instead of only decelerating on a real release" % _player.definition.base_speed_px_per_second).is_less(_player.definition.base_speed_px_per_second - 1.0)


# --- Cleared on pause (Register: "cleared on pause") -----------------------

func test_notification_paused_clears_the_buffer_directly() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame
	assert_vector(_player.get_buffered_movement_direction()).is_not_equal(Vector2.ZERO)

	_player._notification(NOTIFICATION_PAUSED)

	assert_vector(_player.get_buffered_movement_direction()).append_failure_message("NOTIFICATION_PAUSED must clear the input buffer immediately, even though it has not yet expired on its own timer").is_equal(Vector2.ZERO)


func test_real_engine_pause_clears_the_buffer_end_to_end() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame
	assert_vector(_player.get_buffered_movement_direction()).is_not_equal(Vector2.ZERO)

	PauseAuthority.push_reason(&"debug")
	PauseAuthority.flush()
	assert_bool(get_tree().paused).is_true()

	assert_vector(_player.get_buffered_movement_direction()).append_failure_message("pausing the real SceneTree via PauseAuthority did not clear the player's input buffer -- NOTIFICATION_PAUSED is not reaching player.gd's _notification() in a real pause, only in the direct-call test above").is_equal(Vector2.ZERO)

	PauseAuthority.pop_reason(&"debug")
	PauseAuthority.flush()
	assert_bool(get_tree().paused).is_false()


func test_clear_input_buffer_is_a_public_typed_command() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	await get_tree().physics_frame
	_player.clear_input_buffer()
	assert_vector(_player.get_buffered_movement_direction()).is_equal(Vector2.ZERO)

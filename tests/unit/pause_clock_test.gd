extends GdUnitTestSuite

## Pause clock unit check (MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests, P1.1). Verifies SimClock.now stops advancing under
## pause and resumes exactly -- no drift, no lost or double-counted tick
## across a pause/resume boundary -- and that PauseAuthority applies a
## pause request only at flush() (SimLoop step 14 / "end of the tick it
## was requested on"), never immediately on push_reason() (Global
## Simulation Authority > Pause Rules: "Every pause and unpause request is
## applied by PauseAuthority at the end of the tick it was requested on,
## never mid-tick.").
##
## Uses fresh SimClock/PauseAuthority instances per test (not the project's
## autoload singletons), added to this suite's own tree, so one test's
## pause state can never leak into the next.

const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

const TOLERANCE: float = 0.000001

var _clock: Node
var _pause: Node


func before_test() -> void:
	_clock = auto_free(SimClockScript.new()) as Node
	_pause = auto_free(PauseAuthorityScript.new()) as Node
	add_child(_pause)
	add_child(_clock)
	# A freshly add_child()-ed node is not guaranteed to receive its first
	# _physics_process call on the very next awaited physics_frame (Godot
	# builds the per-frame processing list before mid-frame additions are
	# included). One untested warm-up tick settles both nodes into that
	# list before any test starts counting ticks, so tests assert on
	# SimClock's own behaviour, not on scene-tree node-admission timing.
	await get_tree().physics_frame


func after_test() -> void:
	# Safety net: an interrupted/failed test must never leave the SHARED
	# scene tree paused for suites that run after it.
	get_tree().paused = false


func test_now_advances_each_unpaused_physics_tick() -> void:
	var before_now: float = _clock.now
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_clock.now).is_equal_approx(before_now + 3.0 * _clock.PHYSICS_STEP, TOLERANCE)


func test_now_stops_under_pause_and_resumes_exactly() -> void:
	# Two ticks unpaused, to establish a nonzero baseline.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var now_at_pause: float = _clock.now

	_pause.push_reason(&"debug")
	_pause.flush()
	assert_bool(get_tree().paused).is_true()

	# Several ticks pass while paused: now must not move by even one step --
	# SimClock is PROCESS_MODE_PAUSABLE, so the engine itself must skip its
	# _physics_process entirely while the tree is paused.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_clock.now).is_equal(now_at_pause)

	_pause.pop_reason(&"debug")
	_pause.flush()
	assert_bool(get_tree().paused).is_false()

	# Resume exactly: two more ticks add exactly 2 * PHYSICS_STEP -- no
	# drift, no lost tick, no double-counted tick across the boundary.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_clock.now).is_equal_approx(now_at_pause + 2.0 * _clock.PHYSICS_STEP, TOLERANCE)


func test_push_reason_does_not_pause_until_flush() -> void:
	assert_bool(get_tree().paused).is_false()
	var now_before: float = _clock.now

	_pause.push_reason(&"draft")

	# Requested mid-tick: must NOT have taken effect yet.
	assert_bool(get_tree().paused).is_false()
	assert_bool(_pause.has_reason(&"draft")).is_false()

	# A tick that happens before flush() is the tick the request was made
	# on; it must resolve exactly as if unpaused -- the request must not
	# interrupt it.
	await get_tree().physics_frame
	assert_bool(get_tree().paused).is_false()
	assert_float(_clock.now).is_greater(now_before)

	# End of tick: SimLoop step 14 calls flush(). Only now does it apply.
	_pause.flush()
	assert_bool(_pause.has_reason(&"draft")).is_true()
	assert_bool(get_tree().paused).is_true()


func test_unpauses_only_when_reason_set_is_empty() -> void:
	_pause.push_reason(&"pause_menu")
	_pause.push_reason(&"focus_loss")
	_pause.flush()
	assert_bool(get_tree().paused).is_true()

	_pause.pop_reason(&"pause_menu")
	_pause.flush()
	# One reason remains: must still be paused.
	assert_bool(get_tree().paused).is_true()
	assert_bool(_pause.has_reason(&"focus_loss")).is_true()

	_pause.pop_reason(&"focus_loss")
	_pause.flush()
	assert_bool(get_tree().paused).is_false()


func test_flush_emits_reasons_changed_only_on_actual_change() -> void:
	var received: Array = []
	_pause.reasons_changed.connect(func(reasons: Array) -> void: received.append(reasons.duplicate()))

	_pause.push_reason(&"debug")
	_pause.flush()
	assert_int(received.size()).is_equal(1)

	# Flushing again with nothing queued must not re-emit.
	_pause.flush()
	assert_int(received.size()).is_equal(1)

	_pause.pop_reason(&"debug")
	_pause.flush()
	assert_int(received.size()).is_equal(2)

extends GdUnitTestSuite

## Every SimLoop step dispatches its registrants (findings F03-51 and F04-10).
##
## Why this suite exists, and why it is written as a loop over the enum rather
## than as one test per step: `sim_loop.gd` shipped with six of its fifteen
## steps calling `_run_step()` and the other nine only appending their own name
## to the step log. Systems registered against steps 9, 10 and 11 were
## therefore registered and silently never called, and nothing went red --
## `sim_loop_order_test.gd` asserts the fifteen *method* names run in order,
## which stayed true, and `sim_loop_registration_test.gd` asserts the
## registration API itself, which it exercises through one step that happened
## to be one of the six that worked.
##
## The orchestrator's first fix added the five missing dispatch calls, then
## falsified it by removing the step-10 call again: every pickup suite, both
## hit-queue suites, the registration suite and the order suite all stayed
## green. The fix had no coverage at all, which is the same defect class this
## project has now recorded four times (F01-15, F02-16, F03-28, F03-49).
##
## So the assertion here is deliberately not "step 10 dispatches". It is
## "EVERY value in SimLoop.Step dispatches, once per tick", which is a rule a
## future step cannot quietly fall out of: adding a sixteenth step that forgets
## its `_run_step()` call fails this suite the day it is written, without
## anyone remembering to extend a list.
##
## `SimLoop.Step` is the authority for what the steps are; this file never
## restates them. A count is asserted too, so that a step deleted from the
## enum is noticed rather than silently reducing this suite's coverage.

const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")

## The fifteen-step order is structure, not tuning (CLAUDE.md's D91 carve-out:
## a count the master itself states as structure is not a gameplay number).
## MASTER_SDLC.md > Determinism where it matters, C-SIMLOOP, and
## docs/20_Technical_Architecture.md > "SimLoop order" both state fifteen.
const EXPECTED_STEP_COUNT: int = 15

## Minimal Node satisfying the only contract `register()` requires.
class StepCounter:
	extends Node
	var call_count: int = 0
	var last_delta: float = -1.0

	func physics_step(delta: float) -> void:
		call_count += 1
		last_delta = delta


var _loop: Node


func before_test() -> void:
	_loop = auto_free(SimLoopScript.new()) as Node
	add_child(_loop)
	# One untested warm-up tick, matching sim_loop_order_test.gd's and
	# sim_loop_registration_test.gd's own precedent: settles the freshly
	# added node into the physics processing list before counting starts.
	await get_tree().physics_frame


func after_test() -> void:
	get_tree().paused = false


func test_the_step_enum_still_has_the_documented_fifteen_steps() -> void:
	assert_int(SimLoop.Step.size()).append_failure_message(
		"SimLoop.Step no longer has fifteen values. Either a step was added (extend docs/20's SimLoop order and this constant together) or one was removed (which silently shrinks every other assertion in this suite)."
	).is_equal(EXPECTED_STEP_COUNT)


func test_every_step_dispatches_its_registrants_exactly_once_per_tick() -> void:
	var counters: Dictionary = {} # step value -> StepCounter
	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = auto_free(StepCounter.new()) as StepCounter
		add_child(counter)
		assert_bool(_loop.register(step, counter)).append_failure_message(
			"register() refused a valid node at step %s (%d)" % [step_name, step]
		).is_true()
		counters[step] = counter

	await get_tree().physics_frame

	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = counters[step]
		assert_int(counter.call_count).append_failure_message(
			"step %s (%d) did not call its registrant. That step logs its own name but never calls _run_step(), so anything registered against it is registered and never run -- findings F03-51 and F04-10, which is exactly how the pickup system's three adapters went unexecuted." % [step_name, step]
		).is_equal(1)


func test_every_step_passes_the_real_delta_through_to_its_registrants() -> void:
	# A step that dispatches with a hardcoded or zero delta would satisfy the
	# call-count assertion above while breaking every system that integrates
	# over time, so the delta is asserted separately rather than assumed.
	var counters: Dictionary = {}
	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = auto_free(StepCounter.new()) as StepCounter
		add_child(counter)
		_loop.register(step, counter)
		counters[step] = counter

	await get_tree().physics_frame

	var expected_delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = counters[step]
		assert_float(counter.last_delta).append_failure_message(
			"step %s (%d) dispatched with delta %f rather than the physics tick delta" % [step_name, step, counter.last_delta]
		).is_equal_approx(expected_delta, 0.0001)


func test_a_second_tick_steps_every_registrant_again() -> void:
	# Guards the opposite mistake from the one this suite was written for: a
	# dispatch that runs once (for example from _ready() or a one-shot guard)
	# rather than every tick would pass the single-tick assertion above.
	var counters: Dictionary = {}
	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = auto_free(StepCounter.new()) as StepCounter
		add_child(counter)
		_loop.register(step, counter)
		counters[step] = counter

	await get_tree().physics_frame
	await get_tree().physics_frame

	for step_name in SimLoop.Step:
		var step: int = SimLoop.Step[step_name]
		var counter: StepCounter = counters[step]
		assert_int(counter.call_count).append_failure_message(
			"step %s (%d) stepped its registrant on the first tick but not the second" % [step_name, step]
		).is_equal(2)

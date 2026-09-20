extends GdUnitTestSuite

## SimLoop registration API tests (F03-09; src/core/sim_loop.gd's own class
## doc, "Registration API"). Proves the properties the task brief requires:
##   (a) a registered node is stepped exactly once per tick;
##   (b) same-step nodes run in the documented deterministic order --
##       registration order by default, or the injected EntityRegistry
##       serial when one is available (see sim_loop.gd's own
##       `_ordering_key_for()`);
##   (c) a node is never stepped again once unregistered, or once freed --
##       checked via `is_instance_valid()` inside `_run_step()`;
##   (d) register()/unregister() calls made mid-tick (from inside another
##       node's own physics_step()) never mutate the array `_run_step()`
##       is currently iterating.
## Not sim_loop_order_test.gd's replacement -- that file already covers the
## fixed fifteen-step *method* order and the hit-queue sort in isolation;
## this file is new coverage for the registration API this task adds.

const SimLoopScript: GDScript = preload("res://src/core/sim_loop.gd")

## Minimal Node exposing physics_step(delta), the only contract register()
## requires. `shared_log`, when non-null, records this counter's `id` on
## every call, so a test can assert ORDER across several counters, not
## just per-counter call counts.
class StepCounter:
	extends Node
	var call_count: int = 0
	var last_delta: float = -1.0
	var id: int = -1
	var shared_log: Array = []
	var on_step: Callable = Callable()

	func physics_step(delta: float) -> void:
		call_count += 1
		last_delta = delta
		if shared_log != null:
			shared_log.append(id)
		if on_step.is_valid():
			on_step.call()

## Test double for the "prefer ascending EntityRegistry serial where the
## node has one" branch (sim_loop.gd's own header names this unreachable
## against the REAL EntityRegistry today, since entity_registry.gd exposes
## no such accessor -- out of this task's write scope). Injected via
## SimLoop.set_entity_registry_for_test() to prove the branch is real code,
## not dead code, even though nothing in the shipped build can reach it yet.
class FakeSerialRegistry:
	extends Node
	var serials: Dictionary = {} # Node -> int

	## A genuine script method -- Object.has_method() (called by sim_loop.gd's
	## own _ordering_key_for()) reflects this natively; no override needed.
	func get_registration_serial(node: Node) -> int:
		return serials.get(node, -1)


var _loop: Node


func before_test() -> void:
	_loop = auto_free(SimLoopScript.new()) as Node
	add_child(_loop)
	# One untested warm-up tick, matching sim_loop_order_test.gd's and
	# pause_clock_test.gd's own precedent: settles the freshly-added node
	# into the physics processing list before a test starts counting.
	await get_tree().physics_frame


func after_test() -> void:
	get_tree().paused = false


func _make_counter(id: int = -1, log: Array = []) -> StepCounter:
	var c: StepCounter = auto_free(StepCounter.new()) as StepCounter
	c.id = id
	c.shared_log = log
	add_child(c)
	return c


# --- (a) stepped exactly once per tick --------------------------------------

func test_registered_node_is_stepped_exactly_once_per_tick() -> void:
	var a: StepCounter = _make_counter()
	assert_bool(_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)).append_failure_message("register() refused a valid node/step pair").is_true()

	await get_tree().physics_frame
	assert_int(a.call_count).append_failure_message("registered node was not stepped exactly once on the first tick after registering").is_equal(1)

	await get_tree().physics_frame
	assert_int(a.call_count).append_failure_message("registered node was not stepped exactly once on the SECOND tick -- it should be called once per tick, not once total").is_equal(2)


func test_register_refuses_the_same_node_twice_at_the_same_step() -> void:
	var a: StepCounter = _make_counter()
	assert_bool(_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)).is_true()
	assert_bool(_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)).append_failure_message("register() accepted the same node twice at the same step -- it would be stepped twice per tick").is_false()

	await get_tree().physics_frame
	assert_int(a.call_count).is_equal(1)


func test_register_allows_the_same_node_at_two_different_steps() -> void:
	var a: StepCounter = _make_counter()
	assert_bool(_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)).is_true()
	assert_bool(_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, a)).is_true()

	await get_tree().physics_frame
	assert_int(a.call_count).append_failure_message("a node registered at two different steps must be called once per step it is registered at").is_equal(2)


# --- (b) deterministic same-step order --------------------------------------

func test_same_step_nodes_run_in_registration_order_by_default() -> void:
	var log: Array = []
	var a: StepCounter = _make_counter(1, log)
	var b: StepCounter = _make_counter(2, log)
	var c: StepCounter = _make_counter(3, log)

	# Registered in a DELIBERATELY different order than creation, so a pass
	# proves the order is REGISTRATION order, not creation order, tree
	# order, or node id.
	_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, c)
	_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, a)
	_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, b)

	await get_tree().physics_frame
	assert_array(log).append_failure_message("same-step nodes did not run in the order they were register()'d: %s" % str(log)).is_equal([3, 1, 2])


func test_same_step_order_prefers_an_injected_entity_registry_serial_over_registration_order() -> void:
	# See sim_loop.gd's own class doc, "Ordering rule inside one step",
	# point 1: EntityRegistry does not expose get_registration_serial()
	# today, so this branch is unreachable against the real Autoload -- this
	# test proves the CODE PATH is real by injecting a fake that does expose
	# it, not that the real EntityRegistry currently drives it.
	var log: Array = []
	var a: StepCounter = _make_counter(1, log)
	var b: StepCounter = _make_counter(2, log)

	var fake_registry: FakeSerialRegistry = auto_free(FakeSerialRegistry.new())
	add_child(fake_registry)
	# a registers FIRST (registration order would put it first), but the
	# fake registry's serial says a should sort LAST.
	fake_registry.serials[a] = 50
	fake_registry.serials[b] = 10
	_loop.set_entity_registry_for_test(fake_registry)

	_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, a)
	_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, b)

	await get_tree().physics_frame
	assert_array(log).append_failure_message(
		"registration order (%s) was used instead of the injected EntityRegistry serial, which demands [2, 1]" % str(log)
	).is_equal([2, 1])


# --- (c) never stepped again once unregistered or freed ---------------------

func test_unregistered_node_is_not_stepped_again() -> void:
	var a: StepCounter = _make_counter()
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)
	await get_tree().physics_frame
	assert_int(a.call_count).is_equal(1)

	assert_bool(_loop.unregister(SimLoop.Step.PLAYER_MOVEMENT, a)).append_failure_message("unregister() refused a node that was actually registered").is_true()
	assert_bool(_loop.is_registered(SimLoop.Step.PLAYER_MOVEMENT, a)).is_false()

	await get_tree().physics_frame
	assert_int(a.call_count).append_failure_message("an unregistered node was stepped again").is_equal(1)


func test_unregister_refuses_a_node_that_was_never_registered() -> void:
	var a: StepCounter = _make_counter()
	assert_bool(_loop.unregister(SimLoop.Step.PLAYER_MOVEMENT, a)).is_false()


## The falsification target this test is written against: `_run_step()`
## must check `is_instance_valid()` before calling `physics_step()` on a
## registered entry. `a` is registered FIRST (so it is first in call
## order); if the freed-node check is removed, `_run_step()` would call
## `physics_step()` on `a`'s freed instance before ever reaching `b`, which
## either errors (an ENGINE ERROR this project's run_tests.ps1 guard
## catches even if gdUnit4 itself does not) or leaves `b.call_count` at 0
## because iteration never reaches it -- either way this assertion goes
## red. `a` itself cannot be asserted on after `free()` (touching a freed
## object errors), so its liveness is proven only indirectly, through `b`.
func test_a_node_freed_mid_tree_is_never_stepped_and_does_not_break_the_step() -> void:
	var a: StepCounter = _make_counter()
	var b: StepCounter = _make_counter()
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, b)

	await get_tree().physics_frame
	assert_int(b.call_count).is_equal(1)

	a.free() # immediate free (not queue_free) -- see file header

	await get_tree().physics_frame
	assert_int(b.call_count).append_failure_message(
		"the tick did not complete cleanly (or stopped at the freed entry) after a registered node was freed -- b should still have been stepped a second time"
	).is_equal(2)


# --- (d) register()/unregister() mid-tick never corrupts the in-progress pass --

## A node that unregisters ITSELF from inside its own physics_step() call
## (an enemy dying mid-step, the exact real-world case) must not skip or
## double-call any OTHER entry in that same pass. `b` and `c` are
## registered after `a`; if `_run_step()` iterated the SAME array object
## `unregister()` mutates (instead of a snapshot), removing `a` mid-
## iteration could reflow the array and skip whichever entry slid into
## `a`'s old index.
func test_a_node_unregistering_itself_mid_step_does_not_skip_or_duplicate_others() -> void:
	var log: Array = []
	var a: StepCounter = _make_counter(1, log)
	var b: StepCounter = _make_counter(2, log)
	var c: StepCounter = _make_counter(3, log)
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, b)
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, c)
	a.on_step = func() -> void: _loop.unregister(SimLoop.Step.PLAYER_MOVEMENT, a)

	await get_tree().physics_frame
	assert_array(log).append_failure_message("self-unregistering mid-step corrupted the in-progress pass: %s" % str(log)).is_equal([1, 2, 3])

	log.clear()
	await get_tree().physics_frame
	assert_array(log).append_failure_message("a self-unregistered from step 1's own callback but was still stepped on the NEXT tick: %s" % str(log)).is_equal([2, 3])


## A node registered from INSIDE another node's physics_step() this same
## tick must not be called until the FOLLOWING tick -- it was not part of
## the snapshot _run_step() took at the top of this pass.
func test_a_node_registered_mid_step_is_not_called_until_the_next_tick() -> void:
	var log: Array = []
	var a: StepCounter = _make_counter(1, log)
	var late: StepCounter = _make_counter(99, log)
	_loop.register(SimLoop.Step.PLAYER_MOVEMENT, a)
	a.on_step = func() -> void: _loop.register(SimLoop.Step.PLAYER_MOVEMENT, late)

	await get_tree().physics_frame
	assert_array(log).append_failure_message("a node registered mid-step was called in the SAME pass that registered it: %s" % str(log)).is_equal([1])

	log.clear()
	await get_tree().physics_frame
	assert_array(log).append_failure_message("a node registered on the previous tick was not called on the following tick: %s" % str(log)).is_equal([1, 99])

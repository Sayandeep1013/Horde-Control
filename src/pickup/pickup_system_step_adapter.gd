extends Node
class_name PickupSystemStepAdapter

## Generic SimLoop registration adapter (P2.10; src/core/sim_loop.gd's
## Registration API, F03-09: "A system or entity that wants to be driven by
## the correct step ... calls register(step, node) once ... where node
## exposes a public physics_step(delta) method"). Discovered mid-task: this
## API did not exist when this task's brief was written and was added
## concurrently by whoever is building src/core/sim_loop.gd/src/director/
## wave_director.gd this session -- src/director/wave_director.gd (step 13)
## is the one other registrant using it as of this writing.
##
## PickupSystem does three functionally distinct things at three different
## SimLoop steps (drops, step 9; pickup movement and collection, step 10;
## XP and level-up requests, step 11), but `register()` calls one fixed
## method name (`physics_step`) per node, so a single PickupSystem instance
## cannot itself be registered at all three steps and still tell them
## apart. This tiny adapter is what PickupSystem constructs once per step
## (see pickup_system.gd's own `_register_adapters()`), each one forwarding
## `physics_step(delta)` to whichever Callable it was configured with.

var _callback: Callable = Callable()


func configure(callback: Callable) -> void:
	_callback = callback


func physics_step(delta: float) -> void:
	if _callback.is_valid():
		_callback.call(delta)

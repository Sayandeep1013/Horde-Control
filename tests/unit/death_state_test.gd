extends GdUnitTestSuite

## Correctness coverage for src/combat/death_state.gd (P1.5), separate from
## the named acceptance test in ghost_hit_test.gd. Exercises the Logical
## Death sequence step by step (death_state.gd's own header comment),
## including the EntityRegistry.set_entity_alive() seam (LEDGER F02-11/
## F02-12 ruling) and EventBus.emit_enemy_died(), and the Visual Death timer
## driven by SimClock.now rather than a raw per-frame countdown.
##
## Fresh EntityRegistry/EventBus instances per test (not the project's
## autoload singletons), matching entity_registry_test.gd's and
## event_bus_test.gd's own isolation pattern.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const EventBusScript: GDScript = preload("res://src/core/event_bus.gd")

var _registry: Node
var _bus: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	_bus = auto_free(EventBusScript.new()) as Node
	add_child(_registry)
	add_child(_bus)


func _build_entity() -> Dictionary:
	var body: CharacterBody2D = CharacterBody2D.new()
	body.add_to_group(&"pool_body")
	body.collision_layer = CollisionLayers.LAYER_ENEMY_BODY
	body.collision_mask = CollisionLayers.MASK_ENEMY_BODY_GROUND

	var hitbox: Hitbox = Hitbox.new()
	var hitbox_shape: CollisionShape2D = CollisionShape2D.new()
	var hitbox_circle: CircleShape2D = CircleShape2D.new()
	hitbox_circle.radius = 20.0
	hitbox_shape.shape = hitbox_circle
	hitbox.add_child(hitbox_shape)
	body.add_child(hitbox)

	var hurtbox: Hurtbox = Hurtbox.new()
	var hurtbox_shape: CollisionShape2D = CollisionShape2D.new()
	var hurtbox_circle: CircleShape2D = CircleShape2D.new()
	hurtbox_circle.radius = 14.0
	hurtbox_shape.shape = hurtbox_circle
	hurtbox.add_child(hurtbox_shape)
	body.add_child(hurtbox)

	var death_state: DeathState = DeathState.new()
	death_state.hitbox_paths = [NodePath("../Hitbox")]
	death_state.hurtbox_paths = [NodePath("../Hurtbox")]
	death_state.body_path = NodePath("..")
	death_state.registry_entity_path = NodePath("..")
	hitbox.name = "Hitbox"
	hurtbox.name = "Hurtbox"
	body.add_child(death_state)

	add_child(body)
	auto_free(body)

	death_state.set_registry_for_test(_registry)
	death_state.set_event_bus_for_test(_bus)

	return {"body": body, "hitbox": hitbox, "hurtbox": hurtbox, "death_state": death_state}


# --- HP tracking and the checked-first dead flag --------------------------

func test_apply_damage_reduces_hp_without_killing_above_zero() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var accepted: bool = ds.apply_damage(10.0, "test")
	assert_bool(accepted).is_true()
	assert_float(ds.current_hp).is_equal(ds.max_hp - 10.0)
	assert_bool(ds.is_dead).is_false()


func test_apply_damage_at_or_below_zero_hp_triggers_logical_death() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	ds.apply_damage(ds.max_hp + 500.0, "test")
	assert_bool(ds.is_dead).is_true()
	assert_float(ds.current_hp).is_equal(0.0)


func test_apply_damage_is_discarded_once_already_dead() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	ds.apply_damage(ds.max_hp + 500.0, "first_kill")
	var second: bool = ds.apply_damage(9999.0, "second_kill")
	assert_bool(second).append_failure_message("apply_damage() accepted a second hit after Logical Death -- 'checked first by every damage handler'").is_false()
	assert_float(ds.current_hp).is_equal(0.0)


func test_apply_damage_ignores_non_positive_amounts() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	assert_bool(ds.apply_damage(0.0, "test")).is_false()
	assert_bool(ds.apply_damage(-5.0, "test")).is_false()
	assert_float(ds.current_hp).is_equal(ds.max_hp)


# --- Logical Death mutations, one per flag Pool.acquire() restores -------

func test_logical_death_deactivates_every_hitbox_synchronously_and_deferred() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var hitbox: Hitbox = f["hitbox"]
	hitbox.activate_window()
	await get_tree().physics_frame
	assert_bool(hitbox.monitoring).is_true()

	ds.apply_damage(ds.max_hp + 500.0, "test")
	# Synchronous flag flips in the SAME call, before any frame passes.
	assert_bool(hitbox.is_window_active()).append_failure_message("hitbox window still reports active immediately after Logical Death").is_false()

	await get_tree().physics_frame
	assert_bool(hitbox.monitoring).append_failure_message("hitbox.monitoring not restored to false after Logical Death").is_false()


func test_logical_death_clears_hurtbox_monitorable_and_layer_deferred() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var hurtbox: Hurtbox = f["hurtbox"]
	assert_bool(hurtbox.monitorable).is_true()

	ds.apply_damage(ds.max_hp + 500.0, "test")
	# Synchronous dead flag also flips immediately.
	assert_bool(hurtbox.is_dead).is_true()

	await get_tree().physics_frame
	assert_bool(hurtbox.monitorable).append_failure_message("hurtbox.monitorable not cleared after Logical Death").is_false()
	assert_int(hurtbox.collision_layer).append_failure_message("hurtbox.collision_layer not cleared after Logical Death").is_equal(0)


func test_logical_death_clears_body_layer_and_restricts_mask_to_world_and_arena_bounds_deferred() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	var original_layer: int = body.collision_layer

	ds.apply_damage(ds.max_hp + 500.0, "test")
	# Deferred -- must not have changed synchronously.
	assert_int(body.collision_layer).append_failure_message("body.collision_layer changed synchronously instead of via set_deferred").is_equal(original_layer)

	await get_tree().physics_frame
	assert_int(body.collision_layer).append_failure_message("body.collision_layer not cleared to 0 after Logical Death").is_equal(0)
	assert_int(body.collision_mask).append_failure_message("body.collision_mask not restricted to World+ArenaBounds after Logical Death").is_equal(CollisionLayers.DYING_BODY_MASK)


# --- The set_entity_alive() seam and EventBus.emit_enemy_died() ----------

func test_logical_death_marks_the_registered_entity_not_alive() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	_registry.register_entity(body, body.global_position, [&"enemy"])
	assert_int(_registry.get_entity_count(&"enemy")).is_equal(1)

	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(_registry.get_entity_count(&"enemy")).append_failure_message("set_entity_alive(false) was not called at Logical Death -- the corpse still counts toward the live-enemy total").is_equal(0)
	assert_bool(_registry.is_registered(body)).append_failure_message("Logical Death deregistered the entity instead of only marking it not-alive -- LEDGER F02-11/F02-12 ruling: deregistration happens at despawn, not Logical Death").is_true()


func test_logical_death_does_not_touch_the_registry_for_an_unregistered_entity() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	# Never registered -- must not error.
	ds.apply_damage(ds.max_hp + 500.0, "test")
	assert_bool(ds.is_dead).is_true()


func test_logical_death_emits_event_bus_enemy_died_with_sim_time() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	body.global_position = Vector2(42, 7)

	var received: Array = []
	_bus.enemy_died.connect(func(entity: Node2D, position: Vector2, timestamp: float) -> void:
		received.append([entity, position, timestamp])
	)

	var before_now: float = SimClock.now
	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(received.size()).is_equal(1)
	assert_object(received[0][0]).is_same(body)
	assert_vector(received[0][1]).is_equal(Vector2(42, 7))
	assert_float(received[0][2]).is_equal_approx(before_now, 0.001)


func test_logical_death_signal_fires_with_entity_and_position() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var body: CharacterBody2D = f["body"]
	body.global_position = Vector2(10, 20)

	var received: Array = []
	ds.logical_death.connect(func(entity: Node2D, position: Vector2) -> void:
		received.append([entity, position])
	)
	ds.apply_damage(ds.max_hp + 500.0, "test")

	assert_int(received.size()).is_equal(1)
	assert_object(received[0][0]).is_same(body)
	assert_vector(received[0][1]).is_equal(Vector2(10, 20))


# --- Visual Death timing: SimClock.now, not a raw per-frame countdown ----

func test_visual_death_finished_fires_only_after_the_configured_duration_of_sim_time() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	ds.visual_death_duration = 3.0 * SimClock.PHYSICS_STEP # exactly 3 ticks

	# A Dictionary, not a plain int local, because this signal fires later
	# from inside the engine's own _physics_process dispatch, across several
	# `await get_tree().physics_frame` suspend/resume boundaries -- a plain
	# captured int local was observed NOT to propagate a lambda's mutation
	# back to the outer scope across that gap (GdUnit4's own suite-level
	# coroutine handling), even though it works when the signal is emitted
	# synchronously within the same call (see event_bus_test.gd's own
	# `call_count`, which never crosses an `await`). pool_test.gd's
	# `counting_factory` uses the same Dictionary pattern for the same
	# reason. Named here as a real, reproduced GDScript/GdUnit4 pitfall, not
	# assumed.
	var finished: Dictionary = {"count": 0}
	ds.visual_death_finished.connect(func(_e: Node2D) -> void: finished["count"] += 1)

	var deadline: float = SimClock.now + ds.visual_death_duration
	ds.apply_damage(ds.max_hp + 500.0, "test")

	# Poll physics frames until SimClock.now itself reports the deadline has
	# passed, rather than assuming a fixed frame count -- robust to this
	# suite running after many other suites' worth of ticks (where a fixed
	## small frame count was observed to be too tight; see the P1.5 evidence
	# report). Checked BEFORE the deadline too, each iteration, so an early
	# fire is still caught.
	var saw_early_fire: bool = false
	var iterations: int = 0
	while SimClock.now < deadline and iterations < 60:
		if finished["count"] > 0:
			saw_early_fire = true
			break
		await get_tree().physics_frame
		iterations += 1
	assert_bool(saw_early_fire).append_failure_message("visual_death_finished fired before visual_death_duration of SIMULATION time had passed").is_false()

	for _settle in 5: # generous settle frames past the deadline
		await get_tree().physics_frame
	assert_int(finished["count"]).append_failure_message("visual_death_finished did not fire once visual_death_duration of simulation time had passed").is_equal(1)


# --- reset_for_reuse: the pooled-instance seam this file's header names --

func test_reset_for_reuse_clears_is_dead_and_restores_hp_and_child_flags() -> void:
	var f: Dictionary = _build_entity()
	var ds: DeathState = f["death_state"]
	var hitbox: Hitbox = f["hitbox"]
	var hurtbox: Hurtbox = f["hurtbox"]

	hitbox.activate_window()
	ds.apply_damage(ds.max_hp + 500.0, "test")
	assert_bool(ds.is_dead).is_true()

	ds.reset_for_reuse()

	assert_bool(ds.is_dead).append_failure_message("reset_for_reuse() did not clear is_dead").is_false()
	assert_float(ds.current_hp).append_failure_message("reset_for_reuse() did not restore current_hp to max_hp").is_equal(ds.max_hp)
	assert_bool(hurtbox.is_dead).append_failure_message("reset_for_reuse() did not clear the hurtbox's own is_dead flag").is_false()
	assert_bool(hitbox.is_window_active()).append_failure_message("reset_for_reuse() did not clear the hitbox's own window flag").is_false()

	# A reused instance must be able to take damage again -- the sharpest
	# edge this file's header names: an instance whose engine flags Pool
	# restored but whose is_dead flag was never reset would still refuse
	# every apply_damage() call.
	var accepted_again: bool = ds.apply_damage(1.0, "post_reuse")
	assert_bool(accepted_again).append_failure_message("a reused (reset_for_reuse()'d) instance still refused damage").is_true()

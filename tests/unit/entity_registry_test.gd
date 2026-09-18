extends GdUnitTestSuite

## Correctness coverage for src/core/entity_registry.gd (P1.2), separate from
## the timing-and-falsification acceptance test in
## entity_registry_query_perf_test.gd. Exists specifically so that a query
## which is FAST but returns the WRONG set -- the "check that cannot fail"
## shape this project keeps hitting (Phase 02 carried lesson 1) -- is caught
## here even if it were somehow missed by the perf suite's own correctness
## assertions.
##
## Fresh EntityRegistry instance per test (not the project's autoload
## singleton), so one test's registrations can never leak into the next.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _spawn(pos: Vector2) -> Node2D:
	var n: Node2D = auto_free(Node2D.new()) as Node2D
	n.global_position = pos
	return n


func test_process_mode_is_pausable() -> void:
	# MASTER_SDLC.md > Global Simulation Authority: "SimClock, EntityRegistry,
	# and CombatStats are PROCESS_MODE_PAUSABLE, so they stop with the
	# simulation."
	assert_int(_registry.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_register_refuses_null_and_duplicate() -> void:
	var e: Node2D = _spawn(Vector2.ZERO)
	assert_bool(_registry.register_entity(null, Vector2.ZERO, [])).is_false()
	assert_bool(_registry.register_entity(e, Vector2.ZERO, [&"enemy"])).is_true()
	# Second registration of the same entity is refused, not a silent
	# duplicate slot (docs/20 > Communication, commands: "the owning system
	# validates the request and may refuse it").
	assert_bool(_registry.register_entity(e, Vector2.ZERO, [&"enemy"])).is_false()
	assert_int(_registry.get_entity_count(&"enemy")).is_equal(1)


func test_deregister_refuses_unknown_entity() -> void:
	var stranger: Node2D = _spawn(Vector2.ZERO)
	assert_bool(_registry.deregister_entity(stranger)).is_false()
	assert_bool(_registry.deregister_entity(null)).is_false()


func test_update_position_refuses_unregistered_entity() -> void:
	var stranger: Node2D = _spawn(Vector2.ZERO)
	assert_bool(_registry.update_position(stranger, Vector2(50, 50))).is_false()


func test_set_entity_alive_refuses_unregistered_entity() -> void:
	var stranger: Node2D = _spawn(Vector2.ZERO)
	assert_bool(_registry.set_entity_alive(stranger, false)).is_false()


func test_radius_query_returns_exactly_the_entities_inside_the_circle() -> void:
	var inside_a: Node2D = _spawn(Vector2(10, 0))
	var inside_b: Node2D = _spawn(Vector2(0, 40))
	var on_boundary: Node2D = _spawn(Vector2(100, 0)) # exactly at radius
	var outside: Node2D = _spawn(Vector2(101, 0)) # 1px beyond radius
	for e in [inside_a, inside_b, on_boundary, outside]:
		_registry.register_entity(e, e.global_position, [&"enemy"])

	var result: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 100.0)

	assert_int(result.size()).is_equal(3)
	assert_bool(result.has(inside_a)).is_true()
	assert_bool(result.has(inside_b)).is_true()
	assert_bool(result.has(on_boundary)).is_true()
	assert_bool(result.has(outside)).is_false()


func test_radius_query_excludes_dead_entities_by_default() -> void:
	var alive_one: Node2D = _spawn(Vector2(5, 0))
	var dead_one: Node2D = _spawn(Vector2(6, 0))
	_registry.register_entity(alive_one, alive_one.global_position, [&"enemy"])
	_registry.register_entity(dead_one, dead_one.global_position, [&"enemy"])
	_registry.set_entity_alive(dead_one, false)

	var result: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 50.0)
	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(alive_one)).is_true()

	# include_dead=true (the escape hatch) brings it back.
	var with_dead: Array[Node2D] = _registry.get_entities_in_radius(Vector2.ZERO, 50.0, &"enemy", true)
	assert_int(with_dead.size()).is_equal(2)


func test_radius_query_filters_by_tag() -> void:
	var enemy: Node2D = _spawn(Vector2(5, 0))
	var pickup: Node2D = _spawn(Vector2(6, 0))
	_registry.register_entity(enemy, enemy.global_position, [&"enemy"])
	_registry.register_entity(pickup, pickup.global_position, [&"pickup"])

	var enemies: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 50.0)
	assert_int(enemies.size()).is_equal(1)
	assert_bool(enemies.has(enemy)).is_true()

	var pickups: Array[Node2D] = _registry.get_entities_in_radius(Vector2.ZERO, 50.0, &"pickup")
	assert_int(pickups.size()).is_equal(1)
	assert_bool(pickups.has(pickup)).is_true()


func test_update_position_moves_entity_between_grid_cells() -> void:
	var e: Node2D = _spawn(Vector2(500, 500)) # far outside a small query radius
	_registry.register_entity(e, e.global_position, [&"enemy"])
	assert_int(_registry.get_enemies_in_radius(Vector2.ZERO, 50.0).size()).is_equal(0)

	_registry.update_position(e, Vector2(10, 10))
	var result: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 50.0)
	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(e)).is_true()


func test_deregister_removes_entity_from_query_results() -> void:
	var e: Node2D = _spawn(Vector2(10, 10))
	_registry.register_entity(e, e.global_position, [&"enemy"])
	assert_int(_registry.get_enemies_in_radius(Vector2.ZERO, 50.0).size()).is_equal(1)

	assert_bool(_registry.deregister_entity(e)).is_true()
	assert_int(_registry.get_enemies_in_radius(Vector2.ZERO, 50.0).size()).is_equal(0)
	assert_int(_registry.get_entity_count()).is_equal(0)


func test_deregistered_slot_is_recycled_by_the_next_registration() -> void:
	var first: Node2D = _spawn(Vector2(1, 1))
	_registry.register_entity(first, first.global_position, [&"enemy"])
	_registry.deregister_entity(first)

	var second: Node2D = _spawn(Vector2(2, 2))
	assert_bool(_registry.register_entity(second, second.global_position, [&"enemy"])).is_true()
	assert_int(_registry.get_entity_count()).is_equal(1)
	assert_bool(_registry.is_registered(first)).is_false()
	assert_bool(_registry.is_registered(second)).is_true()


func test_get_live_enemy_count_matches_wave_completion_semantics() -> void:
	# docs/11_Wave_Director.md: "ends only when the EntityRegistry live-enemy
	# count is zero."
	var a: Node2D = _spawn(Vector2(1, 1))
	var b: Node2D = _spawn(Vector2(2, 2))
	_registry.register_entity(a, a.global_position, [&"enemy"])
	_registry.register_entity(b, b.global_position, [&"enemy"])
	assert_int(_registry.get_live_enemy_count()).is_equal(2)

	_registry.set_entity_alive(a, false)
	assert_int(_registry.get_live_enemy_count()).is_equal(1)

	_registry.set_entity_alive(b, false)
	assert_int(_registry.get_live_enemy_count()).is_equal(0)


func test_get_entities_with_tag_returns_only_live_matches() -> void:
	var enemy_alive: Node2D = _spawn(Vector2(1, 1))
	var enemy_dead: Node2D = _spawn(Vector2(2, 2))
	var pickup: Node2D = _spawn(Vector2(3, 3))
	_registry.register_entity(enemy_alive, enemy_alive.global_position, [&"enemy"])
	_registry.register_entity(enemy_dead, enemy_dead.global_position, [&"enemy"])
	_registry.register_entity(pickup, pickup.global_position, [&"pickup"])
	_registry.set_entity_alive(enemy_dead, false)

	var result: Array[Node2D] = _registry.get_entities_with_tag(&"enemy")
	assert_int(result.size()).is_equal(1)
	assert_bool(result.has(enemy_alive)).is_true()


func test_radius_query_with_zero_or_negative_radius_returns_empty() -> void:
	var e: Node2D = _spawn(Vector2.ZERO)
	_registry.register_entity(e, e.global_position, [&"enemy"])
	assert_int(_registry.get_enemies_in_radius(Vector2.ZERO, 0.0).size()).is_equal(0)
	assert_int(_registry.get_enemies_in_radius(Vector2.ZERO, -10.0).size()).is_equal(0)


func test_radius_query_works_across_multiple_grid_cells() -> void:
	# Cell size defaults to 200px; place entities spanning several cells so a
	# correct implementation must gather more than one bucket, not just the
	# origin's own cell.
	var near: Node2D = _spawn(Vector2(50, 0))
	var far_but_in_range: Node2D = _spawn(Vector2(390, 0)) # crosses two 200px cell boundaries
	var out_of_range: Node2D = _spawn(Vector2(1000, 0))
	for e in [near, far_but_in_range, out_of_range]:
		_registry.register_entity(e, e.global_position, [&"enemy"])

	var result: Array[Node2D] = _registry.get_enemies_in_radius(Vector2.ZERO, 400.0)
	assert_int(result.size()).is_equal(2)
	assert_bool(result.has(near)).is_true()
	assert_bool(result.has(far_but_in_range)).is_true()
	assert_bool(result.has(out_of_range)).is_false()

extends GdUnitTestSuite

## PT-PHONE (D396): plain swarm enemies are parked when they die and reset when the next enemy
## of the same scene spawns, instead of freeing a 14-node scene and instantiating a new one. The
## guarantee that matters: a reused enemy is indistinguishable from a freshly built one, so the
## suite compares every per-life script variable of the two and then plays the reused one
## through a hit, a kill and a second reuse.

const SeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const HunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const BomberScene: PackedScene = preload("res://scenes/entities/bomber.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const SpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")

const STEP: float = 1.0 / 60.0

var _registry: Node
var _clock: Node
var _brain: SwarmBrain
var _renderer: SwarmRenderer
var _tower: Node2D
var _loop: SimLoop
var _spawner: Node
var _entities: Node2D


func before_test() -> void:
	SwarmState.reset()
	EnemyController.reset_flow_field_cache()
	AttackSlotManager.clear_all_for_test()
	StatusEffects.reset()
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	_renderer = auto_free(SwarmRenderer.new()) as SwarmRenderer
	add_child(_renderer)
	_brain = auto_free(SwarmBrain.new()) as SwarmBrain
	add_child(_brain)
	_tower = auto_free(TowerScene.instantiate()) as Node2D
	add_child(_tower)
	_tower.weapon.set_registry_for_test(_registry)
	_registry.register_entity(_tower, Vector2.ZERO, [&"tower"])
	_loop = auto_free(SimLoop.new()) as SimLoop
	_entities = auto_free(Node2D.new()) as Node2D
	_entities.name = "Entities"
	add_child(_entities)
	_spawner = auto_free(SpawnerScript.new())
	_spawner.entities_container_path = NodePath("../Entities")
	add_child(_spawner)
	_spawner.set_registry_for_test(_registry)


func after_test() -> void:
	SwarmState.reset()
	EnemyController.reset_flow_field_cache()
	AttackSlotManager.clear_all_for_test()
	StatusEffects.reset()


func _factory(scene: PackedScene) -> Callable:
	return func() -> Node2D:
		var e: EnemyController = scene.instantiate() as EnemyController
		e.set_registry_for_test(_registry)
		e.set_sim_clock_for_test(_clock)
		e.driven_externally = true
		e.set_sim_loop_for_test(_loop)
		e.set_tower_reference(_tower)
		return e


## Spawns the way the Wave Director does and lets the deferred swarm join run.
func _spawn(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = _spawner.spawn_enemy(pos, _factory(scene), scene.resource_path) as EnemyController
	e.global_position = pos
	_registry.update_position(e, pos)
	e.set_wave_scaling(1.5, 1.2, 1.2)
	await await_idle_frame()
	return e


func _kill(e: EnemyController) -> void:
	e.death_state.apply_damage(e.death_state.max_hp * 2.0, "test")
	await await_idle_frame() # Logical Death's deferred Area2D flags land (the visual death lasts longer than a frame)
	e.death_state.visual_death_finished.emit(e) # the visual death timer runs on SimClock; the signal is what matters


## Every non-export script variable of a node, by name.
static func _state_of(node: Object) -> Dictionary:
	var out: Dictionary = {}
	for prop: Dictionary in node.get_property_list():
		var usage: int = int(prop["usage"])
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (usage & PROPERTY_USAGE_STORAGE) != 0:
			continue
		out[prop["name"]] = node.get(prop["name"])
	return out


func test_a_dead_plain_enemy_is_parked_and_the_next_spawn_reuses_it() -> void:
	var a: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	assert_bool(a.can_pool()).is_true()
	assert_int(_spawner.get_enemy_count()).is_equal(1)
	await _kill(a)
	assert_int(_spawner.get_parked_enemy_count()).is_equal(1)
	assert_int(_spawner.get_enemy_count()).is_equal(0) # the cap slot is free again
	assert_bool(_registry.is_registered(a)).is_false()
	assert_bool(is_instance_valid(a)).is_true() # parked, not freed
	var b: EnemyController = await _spawn(SeekerScene, Vector2(700, 50))
	assert_object(b).is_same(a)
	assert_bool(b.was_pooled()).is_true()
	assert_int(_spawner.get_parked_enemy_count()).is_equal(0)
	assert_int(_spawner.get_enemy_count()).is_equal(1)
	assert_int(_spawner.enemies_reused).is_equal(1)


func test_a_reused_enemy_is_back_in_the_swarm_with_a_full_health_pool() -> void:
	var a: EnemyController = await _spawn(HunterScene, Vector2(600, 0))
	await _kill(a)
	var b: EnemyController = await _spawn(HunterScene, Vector2(650, 80))
	assert_bool(b.death_state.is_dead).is_false()
	assert_float(b.death_state.current_hp).is_equal_approx(b.death_state.max_hp, 0.001)
	assert_bool(b.is_swarm_member()).is_true()
	assert_bool(b.is_swarm_drawn()).is_true()
	assert_int(_renderer.get_active_count()).is_equal(1)
	assert_int(b.collision_layer).is_equal(0) # the swarm member has no body, like a fresh one
	assert_bool(b.hurtbox.monitorable).is_true()
	assert_bool(_registry.is_registered(b)).is_true()
	assert_int(_registry.get_live_enemy_count()).is_equal(1)
	assert_bool(b.hurtbox.is_dead).is_false()
	assert_bool(b.hitbox._window_active).is_false()


func test_a_reused_enemy_has_the_script_state_of_a_fresh_one() -> void:
	var fresh: EnemyController = await _spawn(SeekerScene, Vector2(500, 0))
	var fresh_state: Dictionary = _state_of(fresh)
	var fresh_hp: float = fresh.death_state.max_hp
	var fresh_damage: float = fresh.hitbox.damage
	# Live a life: walk, take a hit, attack, die.
	var old: EnemyController = await _spawn(SeekerScene, Vector2(500, 0))
	for _i in 120:
		_clock.now += STEP
		_brain.physics_step(STEP)
	old.death_state.apply_damage(3.0, "test")
	old.set_wave_scaling(3.0, 2.5, 2.5) # a late wave: scaled health and damage
	await _kill(old)
	var reused: EnemyController = await _spawn(SeekerScene, Vector2(500, 0))
	assert_object(reused).is_same(old)
	var reused_state: Dictionary = _state_of(reused)
	var volatile: Array = ["_swarm_slot", "_pool_reused", "_think_phase"]
	for key: String in fresh_state:
		if volatile.has(key):
			continue
		var a: Variant = fresh_state[key]
		var b: Variant = reused_state.get(key)
		if a is Object or b is Object:
			continue # references: node identity differs between two instances by design
		assert_bool(a == b).append_failure_message("%s differs: fresh %s, reused %s" % [key, str(a), str(b)]).is_true()
	assert_float(reused.death_state.max_hp).is_equal_approx(fresh_hp, 0.001)
	assert_float(reused.hitbox.damage).is_equal_approx(fresh_damage, 0.001) # not the late wave's damage compounded


func test_scaling_does_not_compound_across_lives() -> void:
	var a: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	var first_hp: float = a.death_state.max_hp
	var first_damage: float = a.hitbox.damage
	await _kill(a)
	var b: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	assert_float(b.death_state.max_hp).is_equal_approx(first_hp, 0.001)
	assert_float(b.hitbox.damage).is_equal_approx(first_damage, 0.001)
	await _kill(b)
	var c: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	assert_float(c.death_state.max_hp).is_equal_approx(first_hp, 0.001)
	assert_float(c.hitbox.damage).is_equal_approx(first_damage, 0.001)


func test_only_plain_unmodified_enemies_are_parked() -> void:
	var bomber: EnemyController = _spawner.spawn_enemy(Vector2(600, 0), _factory(BomberScene), BomberScene.resource_path) as EnemyController
	await await_idle_frame()
	assert_bool(bomber.can_pool()).append_failure_message("a Behavior enemy keeps its own life").is_false()
	var elite: EnemyController = await _spawn(SeekerScene, Vector2(600, 100))
	elite.apply_elite("swift")
	assert_bool(elite.can_pool()).is_false()
	await _kill(elite)
	assert_int(_spawner.get_parked_enemy_count()).is_equal(0) # discarded as before
	assert_bool(is_instance_valid(elite) and not elite.is_queued_for_deletion()).is_false()


func test_the_parked_list_is_bounded() -> void:
	var cap: int = _spawner.MAX_PARKED_PER_KEY
	var made: Array[EnemyController] = []
	for i in cap + 4:
		made.append(await _spawn(SeekerScene, Vector2(600, float(i))))
	for e in made:
		await _kill(e)
	assert_int(_spawner.get_parked_enemy_count()).is_equal(cap)


func test_a_reused_enemy_walks_and_dies_like_a_new_one() -> void:
	var a: EnemyController = await _spawn(SeekerScene, Vector2(900, 0))
	await _kill(a)
	var b: EnemyController = await _spawn(SeekerScene, Vector2(900, 0))
	var start_x: float = b.global_position.x
	for _i in 60:
		_clock.now += STEP
		_brain.physics_step(STEP)
	assert_float(b.global_position.x).is_less(start_x - 20.0) # it heads for the Tower
	await _kill(b)
	assert_bool(b.death_state.is_dead).is_true()
	assert_int(_renderer.get_active_count()).is_equal(0)
	assert_int(_spawner.get_parked_enemy_count()).is_equal(1)

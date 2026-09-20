extends GdUnitTestSuite

## Drop Table application (P2.10; MASTER_SDLC.md > Provisional Values
## Register > "Economy & Pickups" > "Drop Table": "Standard enemy 1 XP + 1
## Scrap"; "Overtime finisher 1 XP, no Scrap"; "stuck-despawned enemy drops
## placed"; > "Pickup Physics & Magnet Rules" > "Unreachable drops"). Proves
## PickupSystem listens to the EXISTING EventBus.enemy_died signal (task
## brief) rather than polling enemies, using a fake EventBus double so the
## real Autoload singleton is never touched by this suite, and proves the
## `removed_while_stuck` seam using a REAL EnemyController instance so the
## signal's actual declared shape (position, drop_table) is what gets
## exercised, not an assumed one.

const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PickupSystemScript: GDScript = preload("res://src/pickup/pickup_system.gd")
const EnemyControllerScript: GDScript = preload("res://src/enemy/enemy_controller.gd")

var _spawner: Node
var _registry: Node
var _clock: Node
var _system: PickupSystem
var _fake_bus: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)
	_spawner = auto_free(EntitySpawnerScript.new()) as Node
	add_child(_spawner)
	_spawner.set_registry_for_test(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	add_child(_clock)

	_fake_bus = auto_free(Node.new())
	_fake_bus.add_user_signal("enemy_died", [
		{"name": "entity", "type": TYPE_OBJECT},
		{"name": "position", "type": TYPE_VECTOR2},
		{"name": "timestamp", "type": TYPE_FLOAT},
	])
	add_child(_fake_bus)

	_system = auto_free(PickupSystemScript.new()) as PickupSystem
	add_child(_system)
	_system.set_entity_spawner_for_test(_spawner)
	_system.set_registry_for_test(_registry)
	_system.set_sim_clock_for_test(_clock)
	_system.set_event_bus_for_test(_fake_bus)


func after_test() -> void:
	if _system != null:
		_system.clear_all_for_test()
	if _spawner != null:
		_spawner.clear_all_for_test()


func _make_enemy(xp: int, scrap: int, is_finisher: bool = false) -> EnemyController:
	var enemy: EnemyController = auto_free(EnemyControllerScript.new()) as EnemyController
	# definition/is_finisher are set BEFORE add_child() so _ready()'s own
	# _apply_definition() sees a real definition immediately, instead of
	# push_error()-ing on a temporarily-null one -- that push_error would
	# surface as an engine ERROR line, which tests/run_tests.ps1's own
	# guard treats as a failed run even if every gdUnit4 assertion passes.
	var definition := EnemyDefinition.new()
	var drop_table := DropTable.new()
	drop_table.xp_shards = xp
	drop_table.scrap = scrap
	definition.drop_table = drop_table
	enemy.definition = definition
	enemy.is_finisher = is_finisher
	add_child(enemy)
	return enemy


func _pickup_types_spawned() -> Array[int]:
	var out: Array[int] = []
	for p in _system.get_active_pickups_for_test():
		out.append(int(p.get_pickup_type()))
	return out


# --- Standard enemy: 1 XP + 1 Scrap, via the real EventBus.enemy_died shape --

func test_standard_enemy_death_drops_one_xp_and_one_scrap() -> void:
	var enemy: EnemyController = _make_enemy(1, 1)
	_fake_bus.emit_signal("enemy_died", enemy, Vector2(100, 200), 0.0)
	_system.step_drops()

	var types: Array[int] = _pickup_types_spawned()
	assert_int(types.size()).append_failure_message("expected exactly 2 pickups (1 XP + 1 Scrap) for a standard enemy death, got %d" % types.size()).is_equal(2)
	assert_bool(types.has(int(ContractEnums.PickupType.XP))).is_true()
	assert_bool(types.has(int(ContractEnums.PickupType.Scrap))).is_true()


func test_a_kill_with_zero_scrap_in_its_drop_table_spawns_no_scrap_pickup() -> void:
	var enemy: EnemyController = _make_enemy(1, 0)
	_fake_bus.emit_signal("enemy_died", enemy, Vector2.ZERO, 0.0)
	_system.step_drops()
	var types: Array[int] = _pickup_types_spawned()
	assert_int(types.size()).is_equal(1)
	assert_int(types[0]).is_equal(int(ContractEnums.PickupType.XP))


# --- Overtime finisher: 1 XP, no Scrap, even though its own EnemyDefinition
# authors 1 Scrap (the finisher flag overrides it) ----------------------------

func test_finisher_flag_suppresses_scrap_even_though_its_definition_authors_some() -> void:
	var enemy: EnemyController = _make_enemy(1, 1, true) # is_finisher = true
	_fake_bus.emit_signal("enemy_died", enemy, Vector2.ZERO, 0.0)
	_system.step_drops()

	var types: Array[int] = _pickup_types_spawned()
	assert_int(types.size()).append_failure_message("Register > Spawning & Waves > 'Overtime finishers': drop 1 XP and no Scrap -- got %d pickups" % types.size()).is_equal(1)
	assert_int(types[0]).is_equal(int(ContractEnums.PickupType.XP))


# --- Stuck-despawned enemy: still drops, placed, via the REAL signal shape ---

func test_stuck_despawned_enemy_still_drops_via_the_real_removed_while_stuck_signal() -> void:
	var enemy: EnemyController = _make_enemy(1, 1)
	enemy.removed_while_stuck.connect(_system.handle_enemy_removed_while_stuck)

	var drop_table := DropTable.new()
	drop_table.xp_shards = 1
	drop_table.scrap = 1
	enemy.removed_while_stuck.emit(Vector2(50, 60), drop_table)
	_system.step_drops()

	var types: Array[int] = _pickup_types_spawned()
	assert_int(types.size()).append_failure_message("a stuck-despawned enemy must still drop (docs/09 'Stuck rules'; task brief)").is_equal(2)


func test_a_null_drop_table_from_removed_while_stuck_drops_nothing() -> void:
	_system.handle_enemy_removed_while_stuck(Vector2.ZERO, null)
	_system.step_drops()
	assert_int(_system.get_active_pickup_count()).is_equal(0)


# --- Unreachable drops: nearest open point ------------------------------------

func test_a_drop_inside_terrain_is_placed_at_the_nearest_open_point() -> void:
	var terrain: StaticBody2D = auto_free(StaticBody2D.new())
	add_child(terrain)
	terrain.collision_layer = CollisionLayers.LAYER_WORLD
	terrain.global_position = Vector2(500, 500)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	terrain.add_child(shape)

	await get_tree().physics_frame

	var enemy: EnemyController = _make_enemy(1, 0)
	_fake_bus.emit_signal("enemy_died", enemy, Vector2(500, 500), 0.0) # dead centre of the terrain body
	_system.step_drops()

	var pickups: Array[Pickup] = _system.get_active_pickups_for_test()
	assert_int(pickups.size()).is_equal(1)
	var distance_from_terrain_centre: float = pickups[0].global_position.distance_to(Vector2(500, 500))
	assert_float(distance_from_terrain_centre).append_failure_message("MASTER_SDLC.md > 'Unreachable drops': a drop inside terrain must be placed at the nearest OPEN point, not left at its original (blocked) position").is_greater(0.5)

extends GdUnitTestSuite

## D139 (balance pass 2026-10-05) regression: a dead enemy used to keep its
## C-SLOTS attack-slot claim until the Pool reclaimed it (`_exit_tree()` never
## runs for a pooled corpse), so after a few waves every one of the Tower's
## 27 slots was leaked, no Seeker could ever attack the Tower again, and the
## Tower took zero damage in combat waves. The claim is now released at
## Logical Death.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	AttackSlotManager.clear_all_for_test()


func after_test() -> void:
	AttackSlotManager.clear_all_for_test()


func _build_tower() -> Node:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = Vector2.ZERO
	tower.weapon.set_registry_for_test(_registry)
	return tower


func _build_seeker(position: Vector2, tower: Node) -> EnemyController:
	var enemy: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.set_sim_clock_for_test(_clock)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	enemy.global_position = position
	enemy.set_tower_reference(tower)
	return enemy


func test_a_seeker_that_dies_holding_a_slot_releases_it() -> void:
	var tower: Node = _build_tower()
	var ring_radius: float = AttackSlotManager.ring_radius(106.0, 14.0, 20.0)
	var enemy: EnemyController = _build_seeker(Vector2(ring_radius + 10.0, 0), tower)
	for _i in 10:
		_clock.now += 0.05
		enemy.physics_step(0.05)
	assert_int(enemy.get_claimed_slot_for_test()).append_failure_message("fixture: the Seeker never claimed a slot").is_greater_equal(0)
	assert_int(AttackSlotManager.claimed_slot_count(tower)).is_equal(1)

	enemy.death_state.apply_damage(999999.0, "test_lethal") # logical death; the node stays in the tree like a pooled corpse

	assert_bool(enemy.is_inside_tree()).append_failure_message("fixture: the corpse must still be in the tree for this to reproduce the pooled case").is_true()
	assert_int(AttackSlotManager.claimed_slot_count(tower)).append_failure_message("a dead Seeker still holds its attack slot").is_equal(0)

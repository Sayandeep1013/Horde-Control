extends GdUnitTestSuite

## Enemy EntityRegistry tag registration (P2.5). This task's own brief,
## "The seam that will silently break if you get it wrong": src/tower/
## tower_weapon.gd targets by EntityRegistry tag, `SEEKER_TAG =
## &"tower_seeker"` and `ENEMY_TAG = &"enemy"` -- read from TowerWeapon's
## own constants here, never retyped (LEDGER F03-15). Every enemy must
## register as `enemy`; Tower Seekers additionally as `tower_seeker`.
##
## Includes the test this task's brief explicitly asks for: "add a test
## that the real Tower weapon actually acquires a real Tower Seeker" --
## using the real scenes/tower.tscn and a real scenes/entities/
## tower_seeker.tscn instance, not a placeholder or a hand-tagged stand-in.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const PlayerHunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const OpportunistScene: PackedScene = preload("res://scenes/entities/opportunist.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	AttackSlotManager.clear_all_for_test()


func _spawn(scene: PackedScene) -> EnemyController:
	var enemy: EnemyController = scene.instantiate() as EnemyController
	enemy.set_registry_for_test(_registry)
	enemy.driven_externally = true
	add_child(enemy)
	auto_free(enemy)
	return enemy


func test_tower_seeker_registers_under_both_enemy_and_tower_seeker_tags() -> void:
	var enemy: EnemyController = _spawn(TowerSeekerScene)
	var tags: Array[StringName] = _registry.get_tags(enemy)
	assert_bool(tags.has(TowerWeapon.ENEMY_TAG)).append_failure_message("Tower Seeker did not register under TowerWeapon.ENEMY_TAG").is_true()
	assert_bool(tags.has(TowerWeapon.SEEKER_TAG)).append_failure_message("Tower Seeker did not register under TowerWeapon.SEEKER_TAG").is_true()


func test_player_hunter_registers_under_enemy_only() -> void:
	var enemy: EnemyController = _spawn(PlayerHunterScene)
	var tags: Array[StringName] = _registry.get_tags(enemy)
	assert_bool(tags.has(TowerWeapon.ENEMY_TAG)).is_true()
	assert_bool(tags.has(TowerWeapon.SEEKER_TAG)).append_failure_message("a Player Hunter must never register as tower_seeker before converting").is_false()


func test_opportunist_registers_under_enemy_only() -> void:
	var enemy: EnemyController = _spawn(OpportunistScene)
	var tags: Array[StringName] = _registry.get_tags(enemy)
	assert_bool(tags.has(TowerWeapon.ENEMY_TAG)).is_true()
	assert_bool(tags.has(TowerWeapon.SEEKER_TAG)).is_false()


## The named cross-task-seam test: a REAL Tower's REAL TowerWeapon must
## actually acquire a REAL Tower Seeker as its target (C-TOWERTARGET:
## "targets the nearest Tower Seeker in range, else the nearest enemy in
## range"), end to end through real Area2D/EntityRegistry wiring -- not
## tower_weapon_test.gd's own placeholder-enemy-with-a-hand-assigned-tag
## fixture (which only proves the RULE works against a tagged stand-in, not
## that P2.5's own Seeker actually carries the tag it needs).
func test_a_real_tower_weapon_acquires_a_real_tower_seeker() -> void:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = Vector2.ZERO
	tower.weapon.set_registry_for_test(_registry)

	var seeker: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	seeker.set_registry_for_test(_registry)
	seeker.driven_externally = true # this test only needs the Tower's own targeting tick, not the Seeker's AI
	add_child(seeker)
	auto_free(seeker)
	seeker.global_position = Vector2(200, 0) # inside the Tower's 480px weapon range

	var iterations: int = 0
	while tower.weapon.get_current_target() != seeker and iterations < 60:
		await get_tree().physics_frame
		iterations += 1

	assert_object(tower.weapon.get_current_target()).append_failure_message("the real Tower's real weapon did not acquire the real Tower Seeker within the timeout -- the tagging seam (LEDGER F03-15) is broken").is_same(seeker)


## The same seam, exercised across a leash conversion: a Hunter that
## converts must become newly acquirable by the Tower's weapon under
## exactly the same real end-to-end path.
func test_a_hunter_that_converts_becomes_acquirable_by_the_real_tower_weapon() -> void:
	var tower: Node = auto_free(TowerScene.instantiate())
	add_child(tower)
	tower.global_position = Vector2.ZERO
	tower.weapon.set_registry_for_test(_registry)

	var hunter: EnemyController = PlayerHunterScene.instantiate() as EnemyController
	hunter.set_registry_for_test(_registry)
	# A fresh, injected clock (not the real SimClock Autoload) for the
	# leash-forcing arithmetic just below: `SimClock.now - 1.0` would go
	# NEGATIVE this early in a test process (no real physics frame has
	# necessarily advanced it past 1.0 yet), colliding with `_leash_deadline
	# < 0.0`, EnemyController's own "leash not tracked" sentinel -- a real
	# bug this task's own falsification pass found. A fresh clock started
	# well clear of zero sidesteps it entirely; the Tower's weapon below
	# still runs on the real SimClock/engine ticks, which is fine since the
	# two components are independent.
	var hunter_clock: Node = auto_free(SimClockScript.new()) as Node
	hunter_clock.now = 100.0
	hunter.set_sim_clock_for_test(hunter_clock)
	hunter.driven_externally = true
	add_child(hunter)
	auto_free(hunter)
	hunter.global_position = Vector2(200, 0)

	# Force the conversion without waiting 20 real seconds -- this test is
	# about the tag seam, not the leash timer, which leash_test.gd already
	# covers.
	hunter.set_leash_deadline_for_test(hunter_clock.now - 1.0)
	hunter.physics_step(0.016) # crosses into the telegraph
	hunter.set_leash_deadline_for_test(hunter_clock.now - 10.0) # force the telegraph to also already be overdue
	hunter.physics_step(0.016) # completes the conversion

	assert_int(hunter.get_current_intent()).append_failure_message("did not actually convert -- test setup is invalid").is_equal(ContractEnums.TargetIntent.TowerSeeker)

	var iterations: int = 0
	while tower.weapon.get_current_target() != hunter and iterations < 60:
		await get_tree().physics_frame
		iterations += 1

	assert_object(tower.weapon.get_current_target()).append_failure_message("a converted Hunter was not acquired by the real Tower weapon -- its tags did not change with it").is_same(hunter)

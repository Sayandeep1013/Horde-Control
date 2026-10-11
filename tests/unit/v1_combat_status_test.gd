extends GdUnitTestSuite

## v1.0 WP-COMBAT: status effects (docs/31 §4.5) and damage-source tagging
## (§4.6). Real enemy scenes, real EntityRegistry / CombatStats autoloads;
## SimClock.now is only ever advanced, never reset (sim_clock.gd header).

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")

var _runner: StatusEffectsRunner


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	_runner = auto_free(StatusEffectsRunner.new())
	add_child(_runner)


func after_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func _spawn_enemy(pos: Vector2 = Vector2(100, 0)) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	EntityRegistry.update_position(e, pos)
	return e


func test_speed_multiplier_is_one_with_no_status() -> void:
	var e := _spawn_enemy()
	assert_float(StatusEffects.speed_multiplier_for(e)).is_equal(1.0)
	assert_bool(StatusEffects.is_frozen(e)).is_false()


func test_strongest_slow_wins_and_is_capped_at_seventy_percent() -> void:
	var e := _spawn_enemy()
	StatusEffects.apply_slow(e, 0.3, 2.0)
	StatusEffects.apply_slow(e, 0.2, 2.0)
	assert_float(StatusEffects.speed_multiplier_for(e)).is_equal_approx(0.7, 0.0001)
	StatusEffects.apply_slow(e, 0.95, 2.0)
	assert_float(StatusEffects.speed_multiplier_for(e)).is_equal_approx(0.3, 0.0001)


func test_slow_expires_with_sim_time() -> void:
	var e := _spawn_enemy()
	StatusEffects.apply_slow(e, 0.5, 1.0)
	SimClock.now += 1.1
	assert_float(StatusEffects.speed_multiplier_for(e)).is_equal(1.0)


func test_freeze_stops_the_enemy_and_expires() -> void:
	var e := _spawn_enemy()
	StatusEffects.apply_freeze(e, 1.0)
	assert_bool(StatusEffects.is_frozen(e)).is_true()
	SimClock.now += 1.05
	assert_bool(StatusEffects.is_frozen(e)).is_false()


func test_frozen_enemy_does_not_move_in_physics_step() -> void:
	var e := _spawn_enemy(Vector2(400, 0))
	e.driven_externally = false
	StatusEffects.apply_freeze(e, 5.0)
	var before: Vector2 = e.global_position
	for i in 10:
		e.physics_step(1.0 / 60.0)
	assert_vector(e.global_position).is_equal(before)


func test_boss_immunity_blocks_freeze_and_brute_freeze_becomes_a_slow() -> void:
	var boss := _spawn_enemy()
	StatusEffects.set_immunities(boss, true, false)
	StatusEffects.apply_freeze(boss, 2.0)
	assert_bool(StatusEffects.is_frozen(boss)).is_false()
	var brute := _spawn_enemy(Vector2(200, 0))
	StatusEffects.set_immunities(brute, false, true)
	StatusEffects.apply_freeze(brute, 2.0)
	assert_bool(StatusEffects.is_frozen(brute)).is_false()
	assert_float(StatusEffects.speed_multiplier_for(brute)).is_less(1.0)


func test_burn_ticks_through_the_hit_path_and_is_recorded_under_its_source() -> void:
	var e := _spawn_enemy()
	var hp0: float = e.death_state.current_hp
	StatusEffects.apply_burn(e, 10.0, 2.0, "flame_arrows")
	for i in 5:
		SimClock.now += StatusEffects.BURN_TICK_SECONDS
		_runner.tick()
	# 4 or 5 ticks of 5 damage depending on edge timing; at least 4 must have landed.
	var recorded: float = 0.0
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == "flame_arrows":
			recorded = row["damage"]
	assert_float(recorded).is_greater_equal(20.0)
	assert_float(hp0 - e.death_state.current_hp).is_equal_approx(recorded, 0.01)


func test_burn_refreshes_rather_than_stacking() -> void:
	var e := _spawn_enemy()
	StatusEffects.apply_burn(e, 6.0, 3.0, "flame_arrows")
	StatusEffects.apply_burn(e, 6.0, 3.0, "flame_arrows")
	assert_float(float(StatusEffects.get_burn_info(e)["dps"])).is_equal(6.0)


func test_hit_records_damage_once_with_crit_doubling() -> void:
	var e := _spawn_enemy()
	AbilityDamage.forced_crit = 1
	AbilityDamage.hit(e, 10.0, "storm_bolt", &"player", true)
	assert_float(float(CombatStats.get_damage_by_source()[0]["damage"])).is_equal(20.0)
	AbilityDamage.forced_crit = 0
	AbilityDamage.hit(e, 10.0, "storm_bolt", &"player", true)
	assert_float(float(CombatStats.get_damage_by_source()[0]["damage"])).is_equal(30.0)


func test_overkill_is_not_recorded() -> void:
	var e := _spawn_enemy()
	var hp: float = e.death_state.current_hp
	AbilityDamage.hit(e, hp + 500.0, "ballista", &"tower", false)
	assert_float(float(CombatStats.get_damage_by_source()[0]["damage"])).is_equal_approx(hp, 0.01)


func test_player_arrow_hit_records_under_bow() -> void:
	var e := _spawn_enemy()
	var proj := PlayerProjectile.new()
	add_child(proj)
	auto_free(proj)
	proj.launch(Vector2.ZERO, Vector2.RIGHT, 7.0, &"player", 1.0)
	proj._deliver_hit(e.hurtbox)
	assert_float(float(CombatStats.get_damage_by_source()[0]["damage"])).is_equal(7.0)
	assert_str(String(CombatStats.get_damage_by_source()[0]["source_id"])).is_equal("bow")


func test_leather_armor_reduces_player_damage_and_counts_damage_taken() -> void:
	var player: Player = auto_free(preload("res://scenes/player.tscn").instantiate())
	add_child(player)
	var hp0: float = player.death_state.current_hp
	player.set_damage_taken_multiplier(0.5)
	player.apply_damage(10.0)
	assert_float(hp0 - player.death_state.current_hp).is_equal_approx(5.0, 0.001)
	assert_float(CombatStats.get_run_counter("damage_taken")).is_equal_approx(5.0, 0.001)


func test_spiked_palisade_reduces_tower_damage_and_reflects_to_the_attacker() -> void:
	var tower: Tower = auto_free(preload("res://scenes/tower.tscn").instantiate())
	add_child(tower)
	var e := _spawn_enemy()
	var hitbox := Hitbox.new()
	add_child(hitbox)
	auto_free(hitbox)
	hitbox.owner_entity = e
	tower.health.set_palisade(0.2, 20.0)
	var hp0: float = tower.health.get_current_health() + tower.health.current_shield
	tower.hurtbox.receive_hit(hitbox, 50.0, e)
	var lost: float = hp0 - (tower.health.get_current_health() + tower.health.current_shield)
	assert_float(lost).is_equal_approx(40.0, 0.01)
	assert_float(CombatStats.get_run_counter("tower_damage_taken")).is_equal_approx(40.0, 0.01)
	var reflected: float = 0.0
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == "spiked_palisade":
			reflected = row["damage"]
	assert_float(reflected).is_equal_approx(20.0, 0.01)

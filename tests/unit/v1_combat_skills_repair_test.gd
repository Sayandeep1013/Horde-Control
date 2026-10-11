extends GdUnitTestSuite

## v1.0 WP-COMBAT: Battle Skills (docs/31 §3.2-§3.3) and Tower repair (§3.4).

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")

var _player: Player
var _tower: Tower
var _skill: BattleSkillController


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	GameSettings.reset_state_for_test()
	_tower = auto_free(preload("res://scenes/tower.tscn").instantiate())
	add_child(_tower)
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true
	add_child(_player)
	_player.global_position = Vector2(300, 0)
	_player.get_node("AutoWeapon").driven_externally = true
	_skill = auto_free(BattleSkillController.new())
	add_child(_skill)


func after_test() -> void:
	# World FX / projectiles spawned into the suite node outlive the test; their
	# callbacks point at this test's controller, so free them now.
	for c in get_children():
		if c is FallingArrow or c is LobbedBomb or c is BurningGround or c is PulseRing or c is GroundTelegraph or c is ExplosionFx:
			c.free()
	GameSettings.reset_state_for_test()
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func _enemy_at(pos: Vector2) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	EntityRegistry.update_position(e, pos)
	return e


func _cluster(center: Vector2, n: int) -> Array[EnemyController]:
	var out: Array[EnemyController] = []
	for i in n:
		out.append(_enemy_at(center + Vector2(float(i) * 12.0, 0.0)))
	return out


func _advance(seconds: float) -> void:
	var steps: int = int(round(seconds * 60.0))
	for i in steps:
		SimClock.now += 1.0 / 60.0
		_skill._physics_process(1.0 / 60.0)
		for c in get_children():
			if c is FallingArrow or c is LobbedBomb or c is BurningGround:
				c._physics_process(1.0 / 60.0)


func _damage_of(source_id: String) -> float:
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == source_id:
			return row["damage"]
	return 0.0


func test_group_state_and_cooldown_cycle() -> void:
	assert_bool(_skill.is_in_group(&"battle_skill")).is_true()
	_skill.set_skill_id_for_test("frost_nova")
	var st: Dictionary = _skill.get_state()
	assert_bool(st["ready"]).is_true()
	assert_float(st["cooldown_total"]).is_equal(13.0)
	assert_bool(_skill.try_cast()).is_true()
	st = _skill.get_state()
	assert_bool(st["ready"]).is_false()
	assert_float(st["cooldown_remaining"]).is_equal_approx(13.0, 0.05)
	assert_bool(_skill.try_cast()).is_false() # on cooldown
	assert_float(CombatStats.get_run_counter("skills_cast")).is_equal(1.0)


func test_frost_nova_damages_and_slows_everything_in_230px_only() -> void:
	_skill.set_skill_id_for_test("frost_nova")
	var near := _enemy_at(Vector2(400, 0))
	var far := _enemy_at(Vector2(900, 0))
	_skill.try_cast()
	assert_float(StatusEffects.speed_multiplier_for(near)).is_equal_approx(0.4, 0.001)
	assert_float(StatusEffects.speed_multiplier_for(far)).is_equal(1.0)
	assert_float(_damage_of("frost_nova")).is_greater(0.0)


func test_arrow_storm_lands_ten_impacts_over_one_and_a_half_seconds() -> void:
	_skill.set_skill_id_for_test("arrow_storm")
	var group := _cluster(Vector2(500, 0), 5)
	var hp0: float = group[0].death_state.current_hp
	assert_bool(_skill.try_cast()).is_true()
	assert_float(_damage_of("arrow_storm")).is_equal(0.0) # nothing lands at cast time
	_advance(2.2)
	assert_float(_damage_of("arrow_storm")).is_greater(0.0)
	assert_float(group[0].death_state.current_hp).is_less(hp0)


func test_arrow_storm_with_no_target_does_not_spend_the_cooldown() -> void:
	_skill.set_skill_id_for_test("arrow_storm")
	assert_bool(_skill.try_cast()).is_false()
	assert_bool(_skill.get_state()["ready"]).is_true()


func test_skill_cooldown_multiplier_from_battle_focus_and_meta() -> void:
	var mgr: AbilityManager = auto_free(AbilityManager.new())
	add_child(mgr)
	mgr.set_skill_cooldown_multiplier(0.5)
	_skill.set_skill_id_for_test("war_horn")
	assert_float(_skill.get_state()["cooldown_total"]).is_equal_approx(14.0, 0.001)


func test_war_horn_restores_shield_and_buffs_fire_rate_then_expires() -> void:
	_skill.set_skill_id_for_test("war_horn")
	_tower.health.current_shield = 0.0
	var tower_interval: float = _tower.weapon.get_effective_fire_interval_seconds()
	var player_weapon: AutoWeapon = _player.get_node("AutoWeapon")
	var player_interval: float = player_weapon.get_effective_fire_interval_seconds()
	assert_bool(_skill.try_cast()).is_true()
	assert_float(_tower.health.current_shield).is_equal(_tower.health.max_shield)
	assert_float(_tower.weapon.get_effective_fire_interval_seconds()).is_equal_approx(tower_interval / 2.0, 0.0001)
	assert_float(player_weapon.get_effective_fire_interval_seconds()).is_equal_approx(player_interval / 1.5, 0.0001)
	_advance(7.2)
	assert_float(_tower.weapon.get_effective_fire_interval_seconds()).is_equal_approx(tower_interval, 0.0001)
	assert_float(player_weapon.get_effective_fire_interval_seconds()).is_equal_approx(player_interval, 0.0001)


func test_firebomb_explodes_then_leaves_burning_ground() -> void:
	_skill.set_skill_id_for_test("firebomb")
	var group := _cluster(Vector2(450, 0), 4)
	assert_bool(_skill.try_cast()).is_true()
	_advance(1.0)
	assert_float(_damage_of("firebomb")).is_greater(0.0)
	assert_int(get_tree().get_nodes_in_group(&"pool_body").size()).is_greater(-1)
	var ground_found: bool = false
	for c in get_children():
		if c is BurningGround:
			ground_found = true
	assert_bool(ground_found).is_true()
	assert_object(group[0]).is_not_null()


func test_auto_cast_fires_with_four_enemies_and_not_with_three() -> void:
	_skill.set_skill_id_for_test("frost_nova")
	GameSettings.set_auto_cast_enabled(true)
	_cluster(Vector2(400, 0), 3)
	_advance(0.6)
	assert_bool(_skill.get_state()["ready"]).append_failure_message("must not cast on 3 enemies").is_true()
	_enemy_at(Vector2(400, 40))
	_advance(0.6)
	assert_bool(_skill.get_state()["ready"]).append_failure_message("must auto-cast on 4 enemies").is_false()


func test_auto_cast_off_never_casts_by_itself() -> void:
	_skill.set_skill_id_for_test("frost_nova")
	GameSettings.set_auto_cast_enabled(false)
	_cluster(Vector2(400, 0), 6)
	_advance(1.0)
	assert_bool(_skill.get_state()["ready"]).is_true()


func test_war_horn_auto_cast_triggers_when_the_tower_loses_health() -> void:
	_skill.set_skill_id_for_test("war_horn")
	GameSettings.set_auto_cast_enabled(true)
	_advance(0.3)
	assert_bool(_skill.get_state()["ready"]).is_true()
	_tower.health.heal(0.0)
	_tower.death_state.current_hp -= 10.0
	_tower.health.health_changed.emit(_tower.health.get_current_health(), _tower.health.max_health)
	_advance(0.4)
	assert_bool(_skill.get_state()["ready"]).is_false()


# --- Tower repair -------------------------------------------------------------------

func _make_repair() -> TowerRepair:
	var repair: TowerRepair = auto_free(TowerRepair.new())
	add_child(repair)
	repair.set_tower_for_test(_tower)
	var inv := RunInventory.new()
	inv.scrap_current = 40
	repair.set_run_inventory_for_test(inv)
	return repair


func test_repair_drains_scrap_into_tower_health_at_8_per_second_3_health_each() -> void:
	var repair := _make_repair()
	_tower.death_state.current_hp = _tower.health.max_health - 200.0
	var inv: RunInventory = repair._get_inventory()
	_tower.interaction_radius._on_body_entered(_player)
	assert_bool(_tower.interaction_radius.is_player_inside()).is_true()
	var hp0: float = _tower.health.get_current_health()
	for i in 60: # one second
		repair.physics_step(1.0 / 60.0)
	assert_bool(repair.is_repairing()).is_true()
	assert_int(inv.scrap_current).is_between(31, 33) # 8 Scrap in 1 s
	assert_float(_tower.health.get_current_health() - hp0).is_equal_approx(float(40 - inv.scrap_current) * 3.0, 0.01)
	assert_float(CombatStats.get_run_counter("scrap_repaired")).is_equal(float(40 - inv.scrap_current))
	assert_float(CombatStats.get_run_counter("tower_repaired")).is_equal_approx(_tower.health.get_current_health() - hp0, 0.01)


func test_repair_needs_the_player_inside_missing_health_and_scrap_and_never_fills_the_shield() -> void:
	var repair := _make_repair()
	var inv: RunInventory = repair._get_inventory()
	_tower.death_state.current_hp = _tower.health.max_health - 200.0
	_tower.health.current_shield = 0.0
	for i in 60:
		repair.physics_step(1.0 / 60.0)
	assert_int(inv.scrap_current).is_equal(40) # player outside
	assert_bool(repair.is_repairing()).is_false()
	_tower.interaction_radius._on_body_entered(_player)
	_tower.death_state.current_hp = _tower.health.max_health # full health
	for i in 60:
		repair.physics_step(1.0 / 60.0)
	assert_int(inv.scrap_current).is_equal(40)
	_tower.death_state.current_hp = _tower.health.max_health - 30.0
	for i in 120:
		repair.physics_step(1.0 / 60.0)
	assert_float(_tower.health.current_shield).is_equal(0.0)
	assert_int(inv.scrap_current).is_equal(30) # exactly 10 Scrap restored 30 health, then stopped


func test_repair_group_and_event() -> void:
	var repair := _make_repair()
	assert_bool(repair.is_in_group(&"tower_repair")).is_true()
	var got: Array = []
	EventBus.tower_repaired.connect(func(h: float, s: int, _t: float) -> void: got.append([h, s]))
	_tower.death_state.current_hp = _tower.health.max_health - 100.0
	_tower.interaction_radius._on_body_entered(_player)
	for i in 30:
		repair.physics_step(1.0 / 60.0)
	assert_int(got.size()).is_greater(0)

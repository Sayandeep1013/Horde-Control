extends GdUnitTestSuite

## v1.0 WP-COMBAT: Dash (docs/31 §3.1). Drives Player.physics_step() directly
## with SimClock.now advanced by hand (never reset).

const DT: float = 1.0 / 60.0

var _player: Player


func before_test() -> void:
	CombatStats.reset_run_stats()
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true # only this test's _tick() drives the player
	add_child(_player)
	_player.global_position = Vector2.ZERO


func after_test() -> void:
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func _tick(seconds: float) -> void:
	var steps: int = int(round(seconds / DT))
	for i in steps:
		SimClock.now += DT
		_player.physics_step(DT)


func test_player_is_in_group_player_and_reports_a_dash_state() -> void:
	assert_bool(_player.is_in_group(&"player")).is_true()
	var st: Dictionary = _player.get_dash_state()
	assert_int(st["charges"]).is_equal(2) # PT-POWER D350: 2 charges (was 1)
	assert_int(st["max_charges"]).is_equal(2)
	assert_float(st["cooldown_remaining"]).is_equal(0.0)
	assert_float(st["cooldown_total"]).is_equal_approx(1.5, 0.0001) # was 2.8


## Distance = velocity x duration. Asserted on those two numbers because
## move_and_slide() outside a real physics frame integrates with the render
## delta, so the resulting position is not deterministic in a unit test.
func test_dash_runs_at_220px_over_0_16s_in_the_input_direction_and_spends_the_charge() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(DT)
	assert_bool(_player.is_dashing()).is_true()
	assert_float(_player.velocity.x).is_equal_approx(220.0 / 0.16, 0.5)
	assert_float(absf(_player.velocity.y)).is_less(0.01)
	_tick(0.12)
	assert_bool(_player.is_dashing()).is_true()
	_tick(0.06)
	assert_bool(_player.is_dashing()).is_false()
	assert_int(_player.get_dash_state()["charges"]).is_equal(1) # one of two spent
	assert_float(CombatStats.get_run_counter("dashes")).is_equal(1.0)


func test_dash_grants_invulnerability_through_the_tail_then_expires() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(DT * 2.0)
	assert_bool(_player.hurtbox.receive_hit(null, 10.0, &"enemy")).is_false() # i-frames: the hit is discarded
	var hp: float = _player.death_state.current_hp
	_tick(0.16 + 0.12 + 0.05)
	assert_float(_player.death_state.current_hp).is_equal(hp)
	assert_bool(_player.hurtbox.receive_hit(null, 10.0, &"enemy")).is_true()


func test_dash_passes_through_enemy_bodies_only_while_dashing() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(DT * 2.0)
	assert_int(_player.collision_mask & CollisionLayers.LAYER_ENEMY_BODY).is_equal(0)
	_tick(0.3)
	assert_int(_player.collision_mask & CollisionLayers.LAYER_ENEMY_BODY).is_equal(CollisionLayers.LAYER_ENEMY_BODY)


func test_charge_recharges_after_the_cooldown_and_extra_charges_hook_works() -> void:
	_player.press_dash_for_test()
	_tick(0.4)
	_player.press_dash_for_test()
	_tick(0.4)
	assert_int(_player.get_dash_state()["charges"]).is_equal(0)
	assert_float(_player.get_dash_state()["cooldown_remaining"]).is_greater(0.2)
	_tick(1.3)
	assert_int(_player.get_dash_state()["charges"]).is_equal(1) # one charge per 1.5 s
	_tick(1.6)
	assert_int(_player.get_dash_state()["charges"]).is_equal(2)
	_player.set_dash_extra_charges(1)
	assert_int(_player.get_dash_state()["max_charges"]).is_equal(3)
	assert_int(_player.get_dash_state()["charges"]).is_equal(3)
	_player.set_dash_extra_charges(1) # the meta hook is absolute: repeating it changes nothing
	assert_int(_player.get_dash_state()["max_charges"]).is_equal(3)
	_player.set_dash_extra_charges(0)
	assert_int(_player.get_dash_state()["charges"]).is_equal(2) # never above the maximum


func test_cooldown_multiplier_scales_the_recharge() -> void:
	_player.set_dash_cooldown_multiplier(0.5)
	assert_float(_player.get_dash_state()["cooldown_total"]).is_equal_approx(0.75, 0.0001)


func test_a_dash_with_no_charge_does_nothing() -> void:
	_player.press_dash_for_test()
	_tick(0.4)
	_player.press_dash_for_test()
	_tick(0.4)
	_player.press_dash_for_test()
	_tick(0.3)
	assert_float(CombatStats.get_run_counter("dashes")).is_equal(2.0) # the third press found no charge


func test_idle_dash_uses_the_facing_direction() -> void:
	_player.set_input_direction_for_test(Vector2.LEFT)
	_tick(0.1)
	_player.set_input_direction_for_test(Vector2.ZERO)
	_tick(0.3)
	_player.press_dash_for_test()
	_tick(DT)
	assert_bool(_player.is_dashing()).is_true()
	assert_float(_player.velocity.x).is_less(-1000.0)


# --- PT-POWER D350: Shadow Step ---------------------------------------------------

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")


func _enemy_at(pos: Vector2) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	EntityRegistry.update_position(e, pos)
	return e


func _damage_of(source: String) -> float:
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == source:
			return row["damage"]
	return 0.0


func test_shadow_step_damages_an_enemy_once_per_dash_and_tags_the_source() -> void:
	AbilityDamage.forced_crit = 0
	_player.set_shadow_step(AbilityCatalog.shadow_step_damage(1), AbilityCatalog.shadow_step_invuln(1))
	var e: EnemyController = _enemy_at(Vector2(20.0, 0.0))
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(0.12)
	assert_float(_damage_of("shadow_step")).is_equal_approx(30.0, 0.01) # rank 1: 30, hit once only across several ticks
	assert_bool(is_instance_valid(e)).is_true()


func test_shadow_step_ranks_scale_damage_30_to_70_and_invulnerability_by_a_tenth() -> void:
	assert_float(AbilityCatalog.shadow_step_damage(1)).is_equal(30.0)
	assert_float(AbilityCatalog.shadow_step_damage(2)).is_equal(50.0)
	assert_float(AbilityCatalog.shadow_step_damage(3)).is_equal(70.0)
	assert_float(AbilityCatalog.shadow_step_invuln(3)).is_equal_approx(0.3, 0.0001)
	assert_float(AbilityCatalog.shadow_step_damage(0)).is_equal(0.0)


func test_shadow_step_extends_the_invulnerability_tail() -> void:
	_player.set_shadow_step(30.0, 0.3)
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(DT * 2.0)
	_tick(0.16 + 0.12 + 0.2) # past the old tail (0.28 s), inside the new one (0.58 s)
	assert_bool(_player.is_invulnerable()).is_true()
	_tick(0.3)
	assert_bool(_player.is_invulnerable()).is_false()


func test_a_dash_without_the_card_deals_no_damage() -> void:
	var e: EnemyController = _enemy_at(Vector2(20.0, 0.0))
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(0.2)
	assert_float(_damage_of("shadow_step")).is_equal(0.0)
	assert_bool(is_instance_valid(e)).is_true()


## PT-PHONE (D395): the dash lasts 10 ticks at 60 Hz and 5 at 30 Hz (0.16 s rounds up to 0.1667 s
## either way), so the phone dashes exactly as far as the desktop.
func test_dash_distance_is_the_same_at_60_and_at_30_hz() -> void:
	var saved_hz: int = Engine.physics_ticks_per_second
	var travelled_at: Array[float] = []
	for hz: int in [60, 30]:
		Engine.physics_ticks_per_second = hz
		var dt: float = 1.0 / float(hz)
		SimClock.now += 5.0 # past the previous run's recharge and buffers
		_player.set_input_direction_for_test(Vector2.RIGHT)
		_player.press_dash_for_test()
		var travelled: float = 0.0
		for i in int(0.4 / dt):
			SimClock.now += dt
			_player.physics_step(dt)
			if _player.is_dashing():
				travelled += absf(_player.velocity.x) * dt
		travelled_at.append(travelled)
		_player.set_input_direction_for_test(Vector2.ZERO)
		SimClock.now += 3.0
		_player.physics_step(dt)
	Engine.physics_ticks_per_second = saved_hz
	assert_float(travelled_at[1]).is_equal_approx(travelled_at[0], 1.0)
	assert_float(travelled_at[0]).is_equal_approx(220.0, 12.0) # the Register's 220 px within one tick of overshoot

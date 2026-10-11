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
	CombatStats.reset_run_stats()


func _tick(seconds: float) -> void:
	var steps: int = int(round(seconds / DT))
	for i in steps:
		SimClock.now += DT
		_player.physics_step(DT)


func test_player_is_in_group_player_and_reports_a_dash_state() -> void:
	assert_bool(_player.is_in_group(&"player")).is_true()
	var st: Dictionary = _player.get_dash_state()
	assert_int(st["charges"]).is_equal(1)
	assert_int(st["max_charges"]).is_equal(1)
	assert_float(st["cooldown_remaining"]).is_equal(0.0)
	assert_float(st["cooldown_total"]).is_equal_approx(2.8, 0.0001)


## Distance = velocity x duration. Asserted on those two numbers because
## move_and_slide() outside a real physics frame integrates with the render
## delta, so the resulting position is not deterministic in a unit test.
func test_dash_runs_at_190px_over_0_16s_in_the_input_direction_and_spends_the_charge() -> void:
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	_tick(DT)
	assert_bool(_player.is_dashing()).is_true()
	assert_float(_player.velocity.x).is_equal_approx(190.0 / 0.16, 0.5)
	assert_float(absf(_player.velocity.y)).is_less(0.01)
	_tick(0.12)
	assert_bool(_player.is_dashing()).is_true()
	_tick(0.06)
	assert_bool(_player.is_dashing()).is_false()
	assert_int(_player.get_dash_state()["charges"]).is_equal(0)
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
	assert_int(_player.get_dash_state()["charges"]).is_equal(0)
	assert_float(_player.get_dash_state()["cooldown_remaining"]).is_greater(2.0)
	_tick(2.6)
	assert_int(_player.get_dash_state()["charges"]).is_equal(1)
	_player.set_dash_extra_charges(1)
	assert_int(_player.get_dash_state()["max_charges"]).is_equal(2)
	assert_int(_player.get_dash_state()["charges"]).is_equal(2)


func test_cooldown_multiplier_scales_the_recharge() -> void:
	_player.set_dash_cooldown_multiplier(0.5)
	assert_float(_player.get_dash_state()["cooldown_total"]).is_equal_approx(1.4, 0.0001)


func test_a_dash_with_no_charge_does_nothing() -> void:
	_player.press_dash_for_test()
	_tick(0.4)
	_player.press_dash_for_test()
	_tick(0.3)
	assert_float(CombatStats.get_run_counter("dashes")).is_equal(1.0)


func test_idle_dash_uses_the_facing_direction() -> void:
	_player.set_input_direction_for_test(Vector2.LEFT)
	_tick(0.1)
	_player.set_input_direction_for_test(Vector2.ZERO)
	_tick(0.3)
	_player.press_dash_for_test()
	_tick(DT)
	assert_bool(_player.is_dashing()).is_true()
	assert_float(_player.velocity.x).is_less(-1000.0)

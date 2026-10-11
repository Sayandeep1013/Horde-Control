extends GdUnitTestSuite
## Focus (docs/32 §A2; Register "v1.0 Run Events" > Focus): standing still charges
## it, full Focus fires the bow 30% faster, moving drains it, a dash resets it,
## the Skirmisher champion has none. Drives Player.physics_step() by hand.

const DT: float = 1.0 / 60.0

var _player: Player
var _weapon: AutoWeapon


func before_test() -> void:
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_weapon = _player.get_node("AutoWeapon")


func after_test() -> void:
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()


func _tick(seconds: float, direction: Vector2 = Vector2.ZERO) -> void:
	_player.set_input_direction_for_test(direction)
	var steps: int = int(round(seconds / DT))
	for i in steps:
		SimClock.now += DT
		_player.physics_step(DT)


func test_focus_does_not_start_charging_until_the_player_has_been_still_for_a_quarter_second() -> void:
	_tick(0.2)
	assert_float(_player.get_focus()).is_equal(0.0)
	_tick(0.25) # 0.45 s still: 0.2 s of charge
	assert_float(_player.get_focus()).is_equal_approx(0.2 / 1.5, 0.02)


func test_focus_reaches_full_after_the_delay_plus_one_and_a_half_seconds() -> void:
	_tick(0.25 + 0.75)
	assert_float(_player.get_focus()).is_equal_approx(0.5, 0.03)
	_tick(0.8)
	assert_float(_player.get_focus()).is_equal(1.0)
	_tick(2.0)
	assert_float(_player.get_focus()).append_failure_message("Focus never exceeds 1").is_equal(1.0)


func test_full_focus_fires_30_percent_faster_and_composes_with_rapid_fire() -> void:
	var base_interval: float = _weapon.get_effective_fire_interval_seconds()
	_tick(0.5)
	assert_float(_weapon.get_effective_fire_interval_seconds()).append_failure_message("a partial charge has no effect").is_equal_approx(base_interval, 0.0001)
	_tick(1.5)
	assert_float(_player.get_focus()).is_equal(1.0)
	assert_float(_weapon.get_effective_fire_interval_seconds()).is_equal_approx(base_interval / 1.3, 0.0001)
	_weapon.set_fire_rate_multiplier(1.2) # Rapid Fire: absolute, must not erase Focus
	assert_float(_weapon.get_effective_fire_interval_seconds()).is_equal_approx(base_interval / (1.2 * 1.3), 0.0001)
	_tick(0.5, Vector2.RIGHT)
	assert_float(_weapon.get_effective_fire_interval_seconds()).append_failure_message("the bonus ends when Focus drops below full").is_equal_approx(base_interval / 1.2, 0.0001)


func test_moving_drains_focus_to_zero_over_0_4_seconds() -> void:
	_tick(2.0)
	assert_float(_player.get_focus()).is_equal(1.0)
	_tick(0.2, Vector2.RIGHT)
	assert_float(_player.get_focus()).is_equal_approx(0.5, 0.06)
	_tick(0.3, Vector2.RIGHT)
	assert_float(_player.get_focus()).is_equal(0.0)


func test_a_dash_resets_focus_to_zero_at_once() -> void:
	_tick(2.0)
	assert_float(_player.get_focus()).is_equal(1.0)
	_player.press_dash_for_test()
	_tick(DT * 2.0, Vector2.RIGHT)
	assert_float(_player.get_focus()).is_equal(0.0)
	assert_float(_weapon.get_focus_fire_rate_multiplier()).is_equal(1.0)


func test_coasting_faster_than_8_px_per_second_counts_as_moving() -> void:
	_tick(2.0)
	assert_float(_player.get_focus()).is_equal(1.0)
	# No input, but still coasting fast (the stop ramp takes 0.05 s): not standing still.
	_player.set_local_velocity_for_test(Vector2(300.0, 0.0))
	_player.set_input_direction_for_test(Vector2.ZERO)
	SimClock.now += DT
	_player.physics_step(DT)
	assert_float(_player.get_focus()).is_less(1.0)


func test_skirmisher_has_no_focus() -> void:
	assert_bool(Player.champion_has_focus("skirmisher")).is_false()
	_player.set_focus_enabled(Player.champion_has_focus("skirmisher")) # what PrototypeIntegration does for the chosen champion
	assert_bool(_player.is_focus_enabled()).is_false()
	_tick(3.0)
	assert_float(_player.get_focus()).is_equal(0.0)
	assert_float(_weapon.get_effective_fire_interval_seconds()).is_equal_approx(0.5, 0.0001)


func test_other_champions_keep_focus() -> void:
	for id in ["ranger", "warden", "pactbound"]:
		assert_bool(Player.champion_has_focus(id)).is_true()


func test_focus_stops_charging_while_the_game_is_paused() -> void:
	# physics_step is not called under pause (the Player is PROCESS_MODE_PAUSABLE), so Focus holds.
	_tick(0.5)
	var held: float = _player.get_focus()
	assert_float(held).is_greater(0.0)
	assert_int(_player.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


func test_how_to_play_has_one_line_each_for_focus_and_run_events() -> void:
	UiStrings.ensure_registered()
	assert_str(HowToPlay.focus_line()).contains("Focus").contains("30%")
	assert_str(HowToPlay.events_line()).contains("Opening Pick").contains("Blood Pact")


func test_the_prototype_disables_focus_for_the_skirmisher_champion() -> void:
	RunConfig.champion_id = "skirmisher"
	var proto: Node = auto_free(preload("res://scenes/prototype.tscn").instantiate())
	add_child(proto)
	assert_bool((proto.get_node("Main/Player") as Player).is_focus_enabled()).is_false()

extends GdUnitTestSuite

## v1.0 shared contracts (WP0; docs/31; decisions D171-D176). Checks the
## pieces every v1.0 work package builds on: difficulty profiles load with
## their Register values, RunConfig defaults and reset, CombatStats damage by
## source, the new settings keys, the two new input actions, and the new
## EventBus signals.

var _dir: String


func before_test() -> void:
	_dir = "user://__v1_contracts_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()
	var cfg_path: String = _dir.path_join("settings.cfg")
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(cfg_path)
	DirAccess.remove_absolute(_dir)


func test_four_difficulties_load_in_order_with_register_values() -> void:
	var all: Array[DifficultyProfile] = RunConfig.get_all_difficulties()
	assert_int(all.size()).is_equal(4)
	assert_str(all[0].id).is_equal("recruit")
	assert_str(all[3].id).is_equal("warlord")
	var soldier: DifficultyProfile = RunConfig.get_difficulty_by_id("soldier")
	assert_float(soldier.enemy_hp_multiplier).is_equal(1.0)
	assert_str(soldier.unlocked_by_victory_on).is_equal("")
	var warlord: DifficultyProfile = RunConfig.get_difficulty_by_id("warlord")
	assert_float(warlord.enemy_damage_multiplier).is_equal_approx(1.9, 0.0001)
	assert_str(warlord.unlocked_by_victory_on).is_equal("veteran")


func test_run_config_defaults_and_unknown_id_falls_back_to_soldier() -> void:
	assert_str(RunConfig.get_difficulty().id).is_equal("soldier")
	assert_str(RunConfig.battle_skill_id).is_equal(AbilityIds.ARROW_STORM)
	assert_str(RunConfig.get_difficulty_by_id("nonsense").id).is_equal("soldier")
	RunConfig.difficulty_id = "veteran"
	RunConfig.endless = true
	RunConfig.reset_for_test()
	assert_str(RunConfig.difficulty_id).is_equal("soldier")
	assert_bool(RunConfig.endless).is_false()


func test_damage_by_source_sums_and_sorts_descending() -> void:
	CombatStats.record_damage("bow", 10.0)
	CombatStats.record_damage("ballista", 30.0)
	CombatStats.record_damage("bow", 25.0)
	CombatStats.record_damage("ignored", 0.0)
	var rows: Array[Dictionary] = CombatStats.get_damage_by_source()
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[0]["source_id"]).is_equal("bow")
	assert_float(rows[0]["damage"]).is_equal(35.0)
	CombatStats.add_run_counter("kills")
	CombatStats.add_run_counter("kills", 2.0)
	assert_float(CombatStats.get_run_counter("kills")).is_equal(3.0)
	CombatStats.reset_run_stats()
	assert_int(CombatStats.get_damage_by_source().size()).is_equal(0)


func test_movement_only_forces_auto_cast_on() -> void:
	GameSettings.set_auto_cast_enabled(false)
	assert_bool(GameSettings.is_auto_cast_enabled()).is_false()
	GameSettings.set_movement_only_controls_enabled(true)
	assert_bool(GameSettings.is_auto_cast_enabled()).is_true()


func test_hud_scale_clamps_and_snaps_and_round_trips() -> void:
	GameSettings.set_hud_scale_pct(500)
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(GameSettings.HUD_SCALE_MAX_PCT)
	GameSettings.set_hud_scale_pct(87)
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(85)
	GameSettings.set_reduce_flashing(true)
	GameSettings.reset_state_for_test()
	GameSettings.load_from_disk()
	assert_int(GameSettings.get_hud_scale_pct()).is_equal(85)
	assert_bool(GameSettings.is_reduce_flashing()).is_true()


func test_dash_and_battle_skill_actions_exist() -> void:
	assert_bool(InputMap.has_action("dash")).is_true()
	assert_bool(InputMap.has_action("battle_skill")).is_true()
	assert_int(InputMap.action_get_events("dash").size()).is_greater_equal(2)


func test_event_bus_declares_v1_signals() -> void:
	for sig in ["wave_started", "siege_warning", "spawn_warning", "boss_spawned", "boss_health_changed", "boss_defeated", "elite_spawned", "elite_killed", "ability_leveled", "dash_used", "battle_skill_cast", "tower_repaired", "war_chest_opened"]:
		assert_bool(EventBus.has_signal(sig)).override_failure_message("missing signal " + sig).is_true()

extends GdUnitTestSuite

## v1.0 HUD data wiring (docs/31 §8.1, §5.3, §5.4): the build bar, the action
## cluster, the wave line, the boss bar, the Siege pulse, REPAIRING, and the
## Reduce flashing gate. The combat and enemy packages are replaced by the
## stand-ins in src/ui/dev/hud_fakes.gd, which register in the same groups.

var _dir: String
var _hud: Hud
var _fakes: Dictionary
var _clock_before: float = 0.0


func before_test() -> void:
	_dir = "user://__hud_v1_data_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()
	CombatStats.reset_run_stats()
	_clock_before = SimClock.now
	_hud = auto_free(Hud.new())
	add_child(_hud)
	_fakes = HudFakes.install(self)
	await get_tree().process_frame


func after_test() -> void:
	SimClock.now = _clock_before
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	CombatStats.reset_run_stats()
	for node: Node in _fakes.values():
		if is_instance_valid(node):
			node.get_parent().remove_child(node) # leave the groups at once; queue_free would let the next test see them
			node.free()


func test_build_bar_shows_owned_abilities_with_levels_and_dims_empty_slots() -> void:
	_hud._refresh_build_bar()
	var p: Array[HudAbilitySlot] = _hud.get_player_slots()
	assert_int(p.size()).is_equal(AbilityIds.MAX_PLAYER_ABILITIES)
	assert_int(_hud.get_tower_slots().size()).is_equal(AbilityIds.MAX_TOWER_ABILITIES)
	assert_str(p[0].ability_id).is_equal("flame_arrows")
	assert_int(p[0].level).is_equal(3)
	assert_int(p[2].level).is_equal(5)
	assert_bool(p[3].is_empty()).is_true()
	assert_str(_hud.get_tower_slots()[0].ability_id).is_equal("ballista")
	assert_bool(_hud.get_tower_slots()[1].is_empty()).is_true()


func test_build_bar_follows_the_manager_live() -> void:
	(_fakes["abilities"] as HudFakes.FakeAbilityManager).player_abilities = []
	_hud._refresh_build_bar()
	for slot: HudAbilitySlot in _hud.get_player_slots():
		assert_bool(slot.is_empty()).is_true()


func test_empty_state_without_any_system_nodes() -> void:
	for node: Node in _fakes.values():
		node.remove_from_group(&"player")
		node.remove_from_group(&"ability_manager")
		node.remove_from_group(&"wave_director")
		node.remove_from_group(&"battle_skill")
		node.remove_from_group(&"tower_repair")
	_hud._refresh_all()
	_hud.get_dash_button()._pull_sources()
	assert_bool(_hud.get_player_slots()[0].is_empty()).is_true()
	assert_bool(_hud.get_repair_tag().visible).is_false()
	assert_str(_hud.get_timer_label().text).is_equal("00:00")


func test_dash_and_skill_buttons_read_their_state_nodes() -> void:
	var dash: HudFakes.FakePlayer = _fakes["player"]
	dash.charges = 0
	dash.cooldown_remaining = 1.4
	var skill: HudFakes.FakeBattleSkill = _fakes["skill"]
	skill.skill_id = "frost_nova"
	skill.cooldown_remaining = 9.0
	skill.is_ready = false
	_hud.get_dash_button()._pull_sources()
	_hud.get_skill_button()._pull_sources()
	assert_int(_hud.get_dash_button().charges).is_equal(0)
	assert_float(_hud.get_dash_button().cooldown_remaining).is_equal_approx(1.4, 0.001)
	assert_str(_hud.get_skill_button().skill_id).is_equal("frost_nova")
	assert_bool(_hud.get_skill_button().skill_ready).is_false()


func test_key_hints_follow_a_rebinding() -> void:
	assert_str(InputHints.key_text(&"dash")).is_equal("Space")
	GameSettings.set_key_binding(&"dash", 0, KEY_G)
	assert_str(InputHints.key_text(&"dash")).is_equal("G")
	GameSettings.reset_controls()
	assert_str(InputHints.key_text(&"dash")).is_equal("Space")


func test_wave_line_formats_campaign_endless_and_unknown_type() -> void:
	assert_str(Hud.format_wave_line(6, 15, "split")).is_equal("WAVE 6/15 · SPLIT")
	assert_str(Hud.format_wave_line(8, 15, "boss")).is_equal("WAVE 8/15 · BOSS")
	assert_str(Hud.format_wave_line(18, -1, "grand_assault")).is_equal("WAVE 18 · GRAND ASSAULT")
	assert_str(Hud.format_wave_line(2, 15, "")).is_equal("WAVE 2/15")
	assert_str(Hud.format_time(272.0)).is_equal("04:32")


func test_wave_line_and_timer_come_from_the_director_group() -> void:
	_hud._refresh_wave_line()
	assert_str(_hud.get_wave_label().text).is_equal("WAVE 6/15 · SPLIT")
	assert_str(_hud.get_timer_label().text).is_equal("04:32")
	assert_float(_hud.get_wave_progress_bar().get_fraction()).is_equal_approx(0.4, 0.001)


func test_wave_started_event_feeds_the_line_when_no_director_exists() -> void:
	_fakes["director"].remove_from_group(&"wave_director")
	EventBus.emit_wave_started(4, 15, "siege", false)
	_hud._refresh_wave_line()
	assert_str(_hud.get_wave_label().text).is_equal("WAVE 4/15 · SIEGE")


func test_kills_counter_reads_combat_stats() -> void:
	CombatStats.add_run_counter("kills", 312)
	_hud._refresh_kills()
	assert_str(_hud.get_kills_label().text).is_equal("312")


class FakeBehavior extends Node:
	var phase_two_fraction: float = 0.4


class FakeBoss extends Node2D:
	var behavior: Node = null


func _boss(fraction: float) -> FakeBoss:
	var boss: FakeBoss = auto_free(FakeBoss.new())
	boss.behavior = auto_free(FakeBehavior.new())
	(boss.behavior as FakeBehavior).phase_two_fraction = fraction
	return boss


func test_boss_bar_follows_boss_events_and_marks_the_phase_the_boss_reports() -> void:
	assert_bool(_hud.get_boss_box().visible).is_false()
	EventBus.emit_boss_spawned(_boss(0.4), "warchief", "Goblin Warchief", 2600.0)
	assert_bool(_hud.get_boss_box().visible).is_true()
	assert_float(_hud.get_boss_bar().marker_fraction).is_equal_approx(0.4, 0.001)
	EventBus.emit_boss_health_changed("warchief", 1300.0, 2600.0)
	assert_float(_hud.get_boss_bar().get_fraction()).is_equal_approx(0.5, 0.001)
	# A retuned boss moves its own mark: the HUD holds no table of fractions.
	EventBus.emit_boss_spawned(_boss(0.65), "king", "Bombardier King", 7000.0)
	assert_float(_hud.get_boss_bar().marker_fraction).is_equal_approx(0.65, 0.001)
	EventBus.emit_boss_spawned(null, "king", "Bombardier King", 7000.0)
	assert_float(_hud.get_boss_bar().marker_fraction).append_failure_message("no boss node, no mark").is_less(0.0)


func test_the_real_boss_scripts_expose_the_fraction_the_hud_reads() -> void:
	# PT-SWARM (D340): Warchief enrages below 50%, the King's first phase mark is 60%.
	assert_float(Hud.boss_phase_fraction(_holder_with(WarchiefBehavior.new()))).is_equal_approx(0.5, 0.001)
	assert_float(Hud.boss_phase_fraction(_holder_with(KingBehavior.new()))).is_equal_approx(0.6, 0.001)
	assert_float(Hud.boss_phase_fraction(_holder_with(JuggernautBehavior.new()))).is_equal_approx(0.5, 0.001)


func _holder_with(behavior: BossBehavior) -> FakeBoss:
	var boss: FakeBoss = auto_free(FakeBoss.new())
	boss.behavior = auto_free(behavior)
	return boss


func test_the_wave_progress_bar_hides_on_boss_waves_and_returns_after() -> void:
	EventBus.emit_wave_started(8, 15, "boss", true)
	_fakes["director"].remove_from_group(&"wave_director")
	_hud._refresh_wave_line()
	assert_bool(_hud.get_wave_progress_bar().visible).append_failure_message("the boss bar already shows the fight").is_false()
	EventBus.emit_wave_started(9, 15, "standard", false)
	_hud._refresh_wave_line()
	assert_bool(_hud.get_wave_progress_bar().visible).is_true()


func test_siege_warning_pulses_the_tower_pill_for_its_seconds_only() -> void:
	EventBus.emit_siege_warning(3.0)
	assert_bool(_hud.is_siege_pulsing()).is_true()
	_hud._update_siege_pulse()
	var pill: PanelContainer = _hud.find_child("TowerHealthPill", true, false)
	assert_bool(pill.self_modulate.is_equal_approx(Color.WHITE)).append_failure_message("the pill must be tinted while the warning runs").is_false()
	_hud._siege_remaining = 0.0
	_hud._update_siege_pulse()
	assert_bool(pill.self_modulate.is_equal_approx(Color.WHITE)).is_true()


func test_reduce_flashing_holds_the_siege_tint_steady() -> void:
	GameSettings.set_reduce_flashing_for_test(true)
	EventBus.emit_siege_warning(5.0)
	var pill: PanelContainer = _hud.find_child("TowerHealthPill", true, false)
	var samples: Array[Color] = []
	for t: float in [0.0, 0.1, 0.2, 0.3]:
		SimClock.now = t
		_hud._update_siege_pulse()
		samples.append(pill.self_modulate)
	for c: Color in samples:
		assert_bool(c.is_equal_approx(samples[0])).append_failure_message("the tint pulsed with Reduce flashing on").is_true()


func test_siege_tint_pulses_when_reduce_flashing_is_off() -> void:
	EventBus.emit_siege_warning(5.0)
	var pill: PanelContainer = _hud.find_child("TowerHealthPill", true, false)
	var seen: Dictionary = {}
	for t: float in [0.0, 0.125, 0.25, 0.375]:
		SimClock.now = t
		_hud._update_siege_pulse()
		seen[snappedf(pill.self_modulate.r, 0.01)] = true
	assert_int(seen.size()).append_failure_message("expected a pulse").is_greater(1)


func test_repairing_tag_shows_from_the_group_and_from_the_event() -> void:
	assert_bool(_hud.get_repair_tag().visible).is_false()
	(_fakes["repair"] as HudFakes.FakeTowerRepair).repairing = true
	_hud._refresh_tower_health()
	assert_bool(_hud.get_repair_tag().visible).is_true()
	(_fakes["repair"] as HudFakes.FakeTowerRepair).repairing = false
	_hud._refresh_tower_health()
	assert_bool(_hud.get_repair_tag().visible).is_false()
	EventBus.emit_tower_repaired(3.0, 1)
	_hud._refresh_tower_health()
	assert_bool(_hud.get_repair_tag().visible).is_true()


func test_bar_flash_and_shake_are_gated_by_reduce_flashing() -> void:
	var bar := HudBar.new()
	add_child(bar)
	auto_free(bar)
	bar.set_value(100.0, 100.0)
	bar.set_value(50.0, 100.0)
	assert_float(bar._flash_alpha).is_greater(0.0)
	var quiet := HudBar.new()
	add_child(quiet)
	auto_free(quiet)
	GameSettings.set_reduce_flashing_for_test(true)
	quiet.set_value(100.0, 100.0)
	quiet.set_value(50.0, 100.0)
	assert_float(quiet._flash_alpha).is_equal(0.0)
	assert_float(quiet._shake_remaining).is_equal(0.0)
	assert_float(quiet._ghost_fraction).append_failure_message("the lagging ghost segment is smooth, not a strobe, and stays").is_greater(0.5)


func test_overhead_bars_obey_the_setting() -> void:
	var bar: PlayerOverheadBar = auto_free(PlayerOverheadBar.new())
	add_child(bar)
	GameSettings.set_show_overhead_bars_for_test(false)
	bar._draw() # must early-out without error
	assert_bool(bar._drawn_visible).is_false()

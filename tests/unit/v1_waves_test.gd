extends GdUnitTestSuite

## v1.0 Wave Director suite (WP-ENEMIES; docs/31 Â§2, Â§5.2, Â§6; Register
## "v1.0 Enemies, Bosses & Waves"). Expectations are independent literals
## transcribed from docs/31, never read back from the code under test.
##
## Covers: the authored 15-wave table, the sequence advancing with gaps of
## 8 s / 12 s before a boss, boss waves ending on the boss's death, victory on
## the final boss, the Endless loop, the query API and EventBus emissions, the
## difficulty multipliers, the elite roll, spawn markers and the Siege warning.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const DummyEnemy: GDScript = preload("res://tests/unit/v1_dummy_enemy.gd")
const DummyBoss: GDScript = preload("res://tests/unit/v1_dummy_boss.gd")

## Register "Wave sequence" (D221, retuned by WP-BALANCE with the kite bot,
## docs/reviews/2026-10-11_V1_BALANCE_PASS.md): HP and damage multipliers are the
## authored ramp, below docs/31 6.1's starting values from wave 6 on. Transcribed
## as literals on purpose: they must not follow the data files.
## PT-SWARM (docs/33 C1-C3, D344-D346): ~10x counts with low fodder HP, a boss
## every 5th wave (5 Warchief, 10 Juggernaut, 15 King). Literals, not data reads.
const TABLE: Array = [
	["wave_01", 0.45, 0.35, 35.0], ["wave_02", 0.5, 0.4, 40.0], ["wave_03", 0.5, 0.45, 45.0], ["wave_04", 0.45, 0.55, 50.0],
	["wave_05", 0.55, 0.6, 0.0], ["wave_06", 0.6, 0.36, 60.0], ["wave_07", 0.6, 0.36, 65.0], ["wave_08", 0.7, 0.42, 70.0],
	["wave_09", 0.75, 0.45, 70.0], ["wave_10", 0.8, 0.8, 0.0], ["wave_11", 0.85, 0.51, 75.0], ["wave_12", 0.9, 0.54, 80.0],
	["wave_13", 0.95, 0.57, 80.0], ["wave_14", 1.0, 0.6, 85.0], ["wave_15", 1.0, 1.0, 0.0],
]
const BEFORE_BOSS_INDICES: Array[int] = [3, 8, 13]

var _registry: Node
var _clock: Node
var _spawner: Node
var _director: WaveDirector
var _pending_kills: Array = []
var _spawned: Array = []


func before_test() -> void:
	RunConfig.reset_for_test()
	RunConfig._cache.clear()
	_pending_kills = []
	_spawned = []
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new())
	_spawner = auto_free(EntitySpawnerScript.new())
	add_child(_spawner)
	_spawner.set_registry_for_test(_registry)
	_director = auto_free(WaveDirectorScript.new()) as WaveDirector
	_director.driven_externally = true
	_director.run_seed = 42
	add_child(_director)
	_director.set_registry_for_test(_registry)
	_director.set_sim_clock_for_test(_clock)
	_director.set_entity_spawner_for_test(_spawner)
	var dummy: PackedScene = _build_scene(DummyEnemy)
	var boss: PackedScene = _build_scene(DummyBoss)
	_director.tower_seeker_scene = dummy
	_director.player_hunter_scene = dummy
	_director.opportunist_scene = dummy
	_director.bomber_scene = dummy
	_director.brute_scene = dummy
	_director.warchief_scene = boss
	_director.king_scene = boss
	_director.juggernaut_scene = boss
	_director.shaman_scene = dummy
	_director.rebuild_lookups_for_test()
	_director.enemy_spawned.connect(func(instance: Node2D, _id: String, _p: Vector2) -> void:
		_pending_kills.append({"instance": instance, "at": _clock.now})
		_spawned.append(instance))


func after_test() -> void:
	RunConfig.reset_for_test()
	RunConfig._cache.clear()
	if _spawner != null:
		_spawner.clear_all_for_test()


func _build_scene(script: GDScript) -> PackedScene:
	var packed := PackedScene.new()
	var n := Node2D.new()
	n.set_script(script)
	n.name = "Dummy"
	packed.pack(n)
	n.free()
	return packed


func _kill_due(delay: float = 2.0) -> void:
	var still: Array = []
	for entry in _pending_kills:
		var instance: Node2D = entry["instance"]
		if not is_instance_valid(instance):
			continue
		if _clock.now - float(entry["at"]) < delay:
			still.append(entry)
			continue
		var position: Vector2 = instance.global_position
		_spawner.discard_enemy(instance)
		EventBus.emit_enemy_died(instance, position)
	_pending_kills = still


func _step(seconds: float, step: float = 0.1, kill_delay: float = 2.0, kill: bool = true) -> void:
	var n: int = int(round(seconds / step))
	for _i in n:
		_clock.now += step
		_director.physics_step(step)
		if kill:
			_kill_due(kill_delay)


func _group(enemy_id: String, count: int, start: float = 0.0, interval: float = 0.5, burst: int = 1) -> SpawnGroup:
	var g := SpawnGroup.new()
	g.enemy_definition_id = enemy_id
	g.count = count
	g.start_offset_seconds = start
	g.spawn_interval_seconds = interval
	g.burst_size = burst
	return g


func _encounter(id: String, groups: Array, type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault) -> EncounterDefinition:
	var e := EncounterDefinition.new()
	e.unique_id = id
	e.encounter_type = type
	var typed: Array[SpawnGroup] = []
	for g in groups:
		typed.append(g)
	e.spawn_groups = typed
	e.minimum_recovery_gap_seconds = 1.0
	return e


func _wave(id: String, enc: EncounterDefinition, boss: bool = false, max_dur: float = 1000.0, hp: float = 1.0, dmg: float = 1.0) -> WaveDefinition:
	var w := WaveDefinition.new()
	w.unique_id = id
	w.encounter_sequence = [enc.unique_id]
	w.has_maximum_duration = not boss
	w.maximum_duration_seconds = 0.0 if boss else max_dur
	w.inter_wave_gap_seconds = 1.0
	w.enemy_hp_multiplier = hp
	w.enemy_damage_multiplier = dmg
	w.hunter_damage_multiplier = dmg
	return w


func _install(waves: Array, encounters: Array) -> void:
	var w: Array[WaveDefinition] = []
	for x in waves:
		w.append(x)
	var e: Array[EncounterDefinition] = []
	for x in encounters:
		e.append(x)
	_director.waves = w
	_director.encounter_definitions = e
	_director.teaching_wave_unique_ids = []
	_director.siege_multiplier_by_encounter_id = {}
	_director.rebuild_lookups_for_test()


## normal, boss, normal, final boss: the smallest sequence with an Endless loop
## of [boss wave, one wave].
func _install_four_wave_campaign() -> void:
	var ea: EncounterDefinition = _encounter("e_a", [_group("tower_seeker", 1)])
	var eb: EncounterDefinition = _encounter("e_b", [_group("goblin_warchief", 1)])
	var ec: EncounterDefinition = _encounter("e_c", [_group("player_hunter", 1)])
	var ed: EncounterDefinition = _encounter("e_d", [_group("bombardier_king", 1)])
	_install([_wave("a", ea), _wave("b", eb, true), _wave("c", ec), _wave("d", ed, true)], [ea, eb, ec, ed])


# --- The authored sequence ----------------------------------------------------

func test_default_sequence_matches_the_docs_31_table() -> void:
	var waves: Array[WaveDefinition] = _director.waves
	assert_int(waves.size()).append_failure_message("the v1.0 campaign is 15 waves").is_equal(15)
	for i in TABLE.size():
		var row: Array = TABLE[i]
		var w: WaveDefinition = waves[i]
		assert_str(w.unique_id).is_equal(row[0])
		assert_float(w.enemy_hp_multiplier).append_failure_message("%s hp multiplier" % row[0]).is_equal_approx(row[1], 0.0001)
		assert_float(w.enemy_damage_multiplier).append_failure_message("%s damage multiplier" % row[0]).is_equal_approx(row[2], 0.0001)
		var is_boss: bool = row[3] == 0.0
		assert_bool(w.has_maximum_duration).append_failure_message("%s: boss waves have no maximum duration" % row[0]).is_equal(not is_boss)
		assert_float(w.maximum_duration_seconds).append_failure_message("%s max duration" % row[0]).is_equal_approx(row[3], 0.0001)
		# Every wave's effective gap = max(wave gap, closing encounter gap): 12 s before a boss, else 8 s.
		var enc: EncounterDefinition = null
		for e in _director.encounter_definitions:
			if e.unique_id == w.encounter_sequence[0]:
				enc = e
		var gap: float = maxf(w.inter_wave_gap_seconds, enc.minimum_recovery_gap_seconds)
		var before_boss: bool = BEFORE_BOSS_INDICES.has(i)
		assert_float(gap).append_failure_message("%s gap" % row[0]).is_equal_approx(12.0 if before_boss else 8.0, 0.0001)
	assert_str(waves[4].encounter_sequence[0]).is_equal("w05_boss")
	assert_str(waves[9].encounter_sequence[0]).is_equal("w10_boss")
	assert_str(waves[14].encounter_sequence[0]).is_equal("w15_boss")
	assert_str(_director.get_current_wave_type()).is_equal("")


func test_wave_types_follow_the_encounter_types() -> void:
	var expected: Array[String] = ["standard", "standard", "split", "siege", "boss", "split", "siege", "standard", "hunt", "boss", "split", "hunt", "siege", "grand_assault", "boss"]
	for i in expected.size():
		_director.open_wave_for_test(i + 1)
		assert_str(_director.get_current_wave_type()).append_failure_message("wave %d" % (i + 1)).is_equal(expected[i])
		assert_bool(_director.is_boss_wave()).is_equal(expected[i] == "boss")


func test_full_sequence_runs_with_correct_gaps_and_completes_when_the_king_dies() -> void:
	var opened: Array = []
	var ended: Array = []
	var completed: Array = [false]
	_director.wave_opened.connect(func(id: String, _i: int) -> void: opened.append({"id": id, "t": _clock.now}))
	_director.wave_ended.connect(func(id: String, _i: int) -> void: ended.append({"id": id, "t": _clock.now}))
	_director.sequence_completed.connect(func() -> void: completed[0] = true)
	var guard: int = 0
	while not completed[0] and guard < 5000:
		_step(0.5, 0.5)
		guard += 1
	assert_bool(completed[0]).append_failure_message("the 15-wave sequence never completed (stalled at %s state=%s boss=%s spawned=%d live=%d)" % [_director.get_current_wave_id(), _director.get_state_name(), _director.get_boss_instance_for_test(), _spawned.size(), _registry.get_live_enemy_count()]).is_true()
	assert_int(opened.size()).is_equal(15)
	assert_int(ended.size()).is_equal(15)
	if opened.size() < 15 or ended.size() < 15:
		return
	for i in 14:
		var gap: float = float(opened[i + 1]["t"]) - float(ended[i]["t"])
		var want: float = 12.0 if BEFORE_BOSS_INDICES.has(i) else 8.0
		assert_float(gap).append_failure_message("gap after wave %d" % (i + 1)).is_equal_approx(want, 0.6)


# --- Boss waves, victory, Endless ----------------------------------------------

func test_boss_wave_does_not_end_on_a_clock_only_when_the_boss_dies() -> void:
	_install_four_wave_campaign()
	_director.open_wave_for_test(2)
	_step(30.0, 0.5, 2.0, false) # nothing is killed for 30 s
	assert_str(_director.get_state_name()).append_failure_message("a boss wave must not end on time").is_equal("WAVE_ACTIVE")
	assert_object(_director.get_boss_instance_for_test()).is_not_null()
	assert_bool(_director.get_boss_instance_for_test().behavior.announced).append_failure_message("boss_spawned announce was never made").is_true()
	_spawner.discard_enemy(_director.get_boss_instance_for_test()) # the boss dies
	_step(0.5, 0.5, 2.0, false)
	assert_str(_director.get_state_name()).is_equal("GAP")


func test_killing_the_final_boss_completes_the_sequence_and_overtime_is_skipped_on_boss_waves() -> void:
	_install_four_wave_campaign()
	var completed: Array = [false]
	_director.sequence_completed.connect(func() -> void: completed[0] = true)
	_director.open_wave_for_test(4)
	_step(60.0, 0.5, 2.0, false)
	assert_bool(_director.is_overtime_active_for_test()).append_failure_message("the finisher rule must not apply to boss waves").is_false()
	assert_bool(completed[0]).is_false()
	_spawner.discard_enemy(_director.get_boss_instance_for_test())
	_step(0.5, 0.5, 2.0, false)
	assert_bool(completed[0]).append_failure_message("victory: killing the final boss ends the campaign").is_true()


func test_endless_loops_the_boss_wave_and_the_waves_after_it_with_scaling_per_loop() -> void:
	_install_four_wave_campaign()
	_director.endless = true
	var started: Array = []
	var completed: Array = [false]
	_director.sequence_completed.connect(func() -> void: completed[0] = true)
	EventBus.wave_started.connect(func(n: int, count: int, type: String, boss: bool, _t: float) -> void: started.append([n, count, type, boss]))
	_director.open_wave_for_test(4)
	_step(1.0, 0.5, 2.0, false)
	_spawner.discard_enemy(_director.get_boss_instance_for_test())
	var guard: int = 0
	while _director.get_current_wave_number() < 7 and guard < 400:
		_step(0.5, 0.5)
		guard += 1
	assert_bool(completed[0]).append_failure_message("Endless never completes the sequence").is_false()
	assert_int(_director.get_wave_count()).is_equal(-1)
	# PT-SWARM (D346): the loop is every wave after the first boss wave up to and
	# including the final one, so here it alternates a wave and a boss wave.
	assert_array(_director.get_loop_wave_indices_for_test()).is_equal([2, 3])
	# Waves 5, 6, 7 are the loop: wave "c", boss wave "d", wave "c" again.
	var numbers: Array = started.map(func(e: Array) -> int: return e[0])
	assert_array(numbers).contains([5, 6, 7])
	assert_array(started.filter(func(e: Array) -> bool: return e[0] == 5)[0]).is_equal([5, -1, "standard", false])
	assert_array(started.filter(func(e: Array) -> bool: return e[0] == 6)[0]).is_equal([6, -1, "boss", true])
	# Loop 1 scaling: +15% HP and +10% damage on what the loop spawns.
	var applied: Array = []
	for inst in _spawned:
		if is_instance_valid(inst) and inst.scaling.size() > 0:
			applied.append(inst.scaling[0])
	assert_bool(applied.any(func(s: Array) -> bool: return is_equal_approx(s[0], 1.15) and is_equal_approx(s[1], 1.1))).append_failure_message("no loop-1 spawn carried x1.15 HP / x1.10 damage; got %s" % [applied]).is_true()


# --- Queries and signals --------------------------------------------------------

func test_query_api_reports_wave_number_count_type_progress_and_elapsed_time() -> void:
	var enc: EncounterDefinition = _encounter("q_e", [_group("tower_seeker", 1)])
	_install([_wave("q", enc, false, 10.0)], [enc])
	assert_int(_director.get_current_wave_number()).is_equal(0)
	_step(5.0, 0.1, 2.0, false)
	assert_int(_director.get_current_wave_number()).is_equal(1)
	assert_int(_director.get_wave_count()).is_equal(1)
	assert_str(_director.get_current_wave_type()).is_equal("standard")
	assert_bool(_director.is_boss_wave()).is_false()
	assert_float(_director.get_wave_progress()).append_failure_message("5 s into a 10 s wave").is_equal_approx(0.5, 0.06)
	assert_float(_director.get_run_elapsed_seconds()).is_equal_approx(5.0, 0.2)
	assert_bool(_director.is_in_group(&"wave_director")).is_true()


func test_boss_wave_progress_follows_boss_health() -> void:
	var enc: EncounterDefinition = _encounter("pb_e", [_group("goblin_warchief", 1)])
	_install([_wave("pb", enc, true)], [enc])
	_step(1.0, 0.5, 2.0, false)
	var boss: Node2D = _director.get_boss_instance_for_test()
	assert_float(_director.get_wave_progress()).append_failure_message("boss at full health").is_equal(0.0)
	var ds := DeathState.new()
	ds.max_hp = 200.0
	ds.current_hp = 50.0
	boss.death_state = ds
	assert_float(_director.get_wave_progress()).append_failure_message("boss at 25% health -> 75% progress").is_equal_approx(0.75, 0.0001)
	ds.free()
	boss.death_state = null


func test_wave_started_signal_carries_number_count_type_and_boss_flag() -> void:
	_install_four_wave_campaign()
	var got: Array = []
	EventBus.wave_started.connect(func(n: int, count: int, type: String, boss: bool, _t: float) -> void: got.append([n, count, type, boss]))
	_director.open_wave_for_test(2)
	assert_array(got).is_equal([[2, 4, "boss", true]])


func test_siege_warning_fires_three_seconds_before_the_first_seeker() -> void:
	var enc: EncounterDefinition = _encounter("s_e", [_group("tower_seeker", 3, 8.0, 1.0)], ContractEnums.EncounterType.Siege)
	_install([_wave("s", enc)], [enc])
	var fired: Array = []
	EventBus.siege_warning.connect(func(seconds: float, _t: float) -> void: fired.append({"seconds": seconds, "t": _clock.now}))
	_step(4.0, 0.1, 2.0, false)
	assert_int(fired.size()).append_failure_message("no warning yet at t=4 (first Seeker at 8 s)").is_equal(0)
	_step(2.0, 0.1, 2.0, false)
	assert_int(fired.size()).is_equal(1)
	assert_float(float(fired[0]["t"])).is_equal_approx(5.0, 0.25)
	assert_float(float(fired[0]["seconds"])).is_equal_approx(3.0, 0.0001)


func test_spawn_warning_precedes_a_group_by_0_75_s_at_most_one_per_30_degree_sector() -> void:
	var enc: EncounterDefinition = _encounter("w_e", [_group("player_hunter", 6, 5.0, 0.0)])
	_install([_wave("w", enc)], [enc])
	_director.teaching_wave_unique_ids = ["w"] # no Pressure escalation pulling the group forward
	var warned: Array = []
	var first_spawn: Array = [-1.0]
	EventBus.spawn_warning.connect(func(pos: Vector2, intent: int, lead: float, _t: float) -> void: warned.append({"pos": pos, "intent": intent, "lead": lead, "t": _clock.now}))
	_director.enemy_spawned.connect(func(_i: Node2D, _id: String, _p: Vector2) -> void:
		if first_spawn[0] < 0.0:
			first_spawn[0] = _clock.now)
	_step(6.0, 0.05, 2.0, false)
	assert_bool(warned.size() >= 1).append_failure_message("no spawn_warning emitted").is_true()
	assert_float(float(warned[0]["t"])).append_failure_message("first warning at t=%s" % warned[0]["t"]).is_between(4.2, 4.3 + 0.1)
	assert_float(float(warned[0]["lead"])).is_equal_approx(0.75, 0.0001)
	assert_int(int(warned[0]["intent"])).is_equal(ContractEnums.TargetIntent.PlayerHunter)
	var sectors: Dictionary = {}
	for w in warned:
		var bearing: float = wrapf((w["pos"] - _director.arena_center).angle(), 0.0, TAU)
		var sector: int = int(floor(bearing / deg_to_rad(30.0)))
		assert_bool(sectors.has(sector)).append_failure_message("two warnings landed in sector %d inside one 0.75 s window" % sector).is_false()
		sectors[sector] = true
	assert_float(first_spawn[0]).is_equal_approx(5.0, 0.15)


# --- Difficulty ----------------------------------------------------------------------

func test_difficulty_scales_spawn_count_hp_damage_and_boss_hp() -> void:
	RunConfig.difficulty_id = "veteran"
	_director.open_wave_for_test(1) # wave_01: first group 12 Hunters; hp 0.45, hunter damage 0.3
	assert_int(_director.get_effective_group_count_for_test(_director.encounter_definitions[0], 0)).append_failure_message("12 x 1.2 = 14.4 rounds to 14").is_equal(14)
	_step(2.0, 0.1, 2.0, false)
	var first: Node2D = _spawned[0]
	assert_float(first.scaling[0][0]).append_failure_message("hp 0.45 x 1.25").is_equal_approx(0.5625, 0.0001)
	assert_float(first.scaling[0][2]).append_failure_message("hunter damage 0.3 x 1.3").is_equal_approx(0.39, 0.0001)
	_spawned.clear()
	_director.open_wave_for_test(5)
	_step(1.0, 0.5, 2.0, false)
	var boss: Node2D = _director.get_boss_instance_for_test()
	assert_float(boss.scaling[0][0]).append_failure_message("boss hp uses the boss multiplier (1.3), not the enemy one (1.25)").is_equal_approx(1.3, 0.0001)
	assert_int(_director.get_effective_group_count_for_test(_director.encounter_definitions[4], 0)).append_failure_message("a boss is never multiplied").is_equal(1)


func test_soldier_leaves_counts_and_scaling_at_the_wave_values() -> void:
	_director.open_wave_for_test(1)
	assert_int(_director.get_effective_group_count_for_test(_director.encounter_definitions[0], 0)).is_equal(12)
	_step(1.0, 0.1, 2.0, false)
	assert_float(_spawned[0].scaling[0][2]).is_equal_approx(0.3, 0.0001)


# --- Elites ------------------------------------------------------------------------------

func test_elite_chance_curve_is_8_percent_at_wave_5_rising_2_points_per_wave_to_24() -> void:
	# PT-SWARM (D348): doubled from 4% + 1 point per wave, capped at 12%.
	assert_float(_director.get_elite_chance_for_test(4)).is_equal(0.0)
	assert_float(_director.get_elite_chance_for_test(5)).is_equal_approx(0.08, 0.00001)
	assert_float(_director.get_elite_chance_for_test(9)).is_equal_approx(0.16, 0.00001)
	assert_float(_director.get_elite_chance_for_test(13)).is_equal_approx(0.24, 0.00001)
	assert_float(_director.get_elite_chance_for_test(40)).is_equal_approx(0.24, 0.00001)
	assert_float(_director.get_elite_chance_for_test(12, 0.12, 0.04)).is_equal_approx(0.22 + 0.12 + 0.04, 0.00001)
	assert_float(_director.get_elite_chance_for_test(3, 0.5, 0.5)).append_failure_message("nothing before wave 5").is_equal(0.0)


func test_every_spawn_rolls_an_elite_with_a_valid_affix_from_wave_5_and_none_before() -> void:
	var prof := DifficultyProfile.new()
	prof.elite_chance_add = 1.0
	RunConfig._cache["soldier"] = prof
	var elites: Array = []
	EventBus.elite_spawned.connect(func(e: Node2D, affix: String, _t: float) -> void: elites.append([e, affix]))
	_director.open_wave_for_test(4)
	_step(3.0, 0.1, 2.0, false)
	for inst in _spawned:
		assert_str(inst.elite_affix).append_failure_message("wave 4 is before the first elite wave").is_equal("")
	assert_int(elites.size()).is_equal(0)
	_director.open_wave_for_test(6) # wave 5 is a boss wave and bosses never roll
	_spawned.clear()
	_step(8.0, 0.1, 2.0, false)
	assert_bool(_spawned.size() > 0).is_true()
	for inst in _spawned:
		assert_array(["swift", "armored", "volatile", "vampiric"]).append_failure_message("affix '%s'" % inst.elite_affix).contains([inst.elite_affix])
	assert_int(elites.size()).append_failure_message("one elite_spawned per elite").is_equal(_spawned.size())


# --- Legacy fixture still reachable --------------------------------------------------------

func test_legacy_prototype_sequence_remains_available_for_the_mechanism_suites() -> void:
	_director.use_legacy_prototype_sequence_for_test()
	assert_int(_director.waves.size()).is_equal(8)
	assert_str(_director.waves[3].unique_id).is_equal("wave_t4")

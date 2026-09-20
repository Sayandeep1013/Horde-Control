extends GdUnitTestSuite

## Pressure test (P2.9 -- MASTER_SDLC.md > Acceptance Test Matrix > Encounter
## Tests > "Pressure test"). Covers docs/11_Wave_Director.md > "Pacing &
## Escalation Algorithm" in full: Pressure Calculation, Escalation Trigger,
## De-escalation (bounded), Health quadrant, Overtime.
##
## Three layers, cheapest/most-precise first:
## 1. Pure static math (PressureMetric.compute_pressure/compute_threat/
##    compute_health_quadrant) -- no fixture at all.
## 2. The PressureMetric state machine directly, using the REAL authored
##    timers from data/encounters/director_configuration.tres (so mutating
##    that .tres, per this task's falsification requirement, actually turns
##    the relevant test red) -- no scene tree, matching src/director/
##    pressure_metric.gd's own "pure RefCounted" design.
## 3. src/director/wave_director.gd end to end: a fresh EntityRegistry/
##    SimClock/EntitySpawner/CombatStats/WaveDirector fixture per test,
##    matching tests/unit/wave_sequence_test.gd's own established pattern,
##    proving the Escalation Trigger actually pulls a real spawn group
##    forward and de-escalation actually doubles real spawn cadence.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const CombatStatsScript: GDScript = preload("res://src/core/combat_stats.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

const TowerSeekerDef: EnemyDefinition = preload("res://data/enemies/tower_seeker.tres")
const PlayerHunterDef: EnemyDefinition = preload("res://data/enemies/player_hunter.tres")
const OpportunistDef: EnemyDefinition = preload("res://data/enemies/opportunist.tres")

## The REAL authored resource (MASTER_SDLC.md > Provisional Values Register
## > "Pressure & Overtime"). Falsification target for four of this suite's
## mutations -- see the P2.9 evidence report's falsification table.
const RealDirectorConfig: DirectorConfiguration = preload("res://data/encounters/director_configuration.tres")

const STEP: float = 0.1

## A bare Node2D standing in for a player or enemy: exactly the two
## properties src/director/wave_director.gd's `_compute_current_threat()` /
## `_compute_health_quadrant()` duck-type off a real EnemyController/Player
## (`.definition`, `.death_state`) -- `death_state` is a REAL
## src/combat/death_state.gd instance (the production code does `is
## DeathState`, a hard type check, not duck typing), constructed without
## ever being added to the scene tree so its `_ready()` autoload wiring
## never runs and current_hp/max_hp hold exactly whatever this suite sets.
class _FakeActor:
	extends Node2D
	var definition: EnemyDefinition
	var death_state: DeathState


## Tower stand-in: only `.health` needs to exist, and only duck-typed
## (`has_method("get_current_health")` / `.max_health`) -- see
## wave_director.gd's `_compute_health_quadrant()` header for why the Tower
## side is duck-typed rather than a hard `is TowerHealth` check.
class _FakeTowerHealth:
	extends RefCounted
	var max_health: float = 0.0
	var current_health: float = 0.0
	func get_current_health() -> float:
		return current_health


class _FakeTower:
	extends Node2D
	var health: _FakeTowerHealth


## Records every call, for the overlay-push test.
class _FakeOverlay:
	extends Node
	var pressure_calls: Array = []
	var quadrant_calls: Array = []
	func set_pressure(value: float, state: String) -> void:
		pressure_calls.append({"value": value, "state": state})
	func set_health_quadrant(quadrant: String) -> void:
		quadrant_calls.append(quadrant)


var _registry: Node
var _clock: Node
var _spawner: Node
var _stats: Node
var _director: WaveDirector
var _free_later: Array = [] # untracked Node2Ds (never add_child'ed) -- freed in after_test()


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new())
	_spawner = auto_free(EntitySpawnerScript.new())
	add_child(_spawner)
	_spawner.set_registry_for_test(_registry)
	_stats = auto_free(CombatStatsScript.new())
	add_child(_stats)

	_director = auto_free(WaveDirectorScript.new()) as WaveDirector
	_director.driven_externally = true
	_director.run_seed = 7
	add_child(_director)
	_director.set_registry_for_test(_registry)
	_director.set_sim_clock_for_test(_clock)
	_director.set_entity_spawner_for_test(_spawner)
	_director.set_combat_stats_for_test(_stats)

	var dummy: PackedScene = _build_dummy_scene()
	_director.tower_seeker_scene = dummy
	_director.player_hunter_scene = dummy
	_director.opportunist_scene = dummy
	_director.rebuild_lookups_for_test()
	_free_later = []


func after_test() -> void:
	if _spawner != null:
		_spawner.clear_all_for_test()
	for n in _free_later:
		if is_instance_valid(n):
			n.free() # never add_child'ed -- plain free(), matching CLAUDE.md's "free the root instead of remove_child()" guidance (these have no descendants to orphan)


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free()
	return packed


## group.enemy_definition_id defaults to "tower_seeker" so the default dummy
## scene/enemy lookup resolves without extra wiring.
func _make_group(count: int, start_offset: float, interval: float) -> SpawnGroup:
	var g: SpawnGroup = SpawnGroup.new()
	g.enemy_definition_id = "tower_seeker"
	g.count = count
	g.start_offset_seconds = start_offset
	g.spawn_interval_seconds = interval
	return g


## A single non-teaching wave/encounter with the given spawn groups, wired
## as this fixture's only wave (index 0) -- "non-teaching" because its
## unique_id is not in WaveDirector's default `teaching_wave_unique_ids`.
func _install_single_wave(groups: Array[SpawnGroup], encounter_type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault) -> void:
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "pressure_test_encounter"
	encounter.encounter_type = encounter_type
	encounter.spawn_groups = groups
	encounter.minimum_recovery_gap_seconds = 5.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "pressure_test_wave" # NOT in teaching_wave_unique_ids
	wave.encounter_sequence = ["pressure_test_encounter"]
	wave.maximum_duration_seconds = 10000.0 # long enough that no test in this suite ever ends the wave
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0
	_director.waves = [wave]
	_director.encounter_definitions = [encounter]
	_director.rebuild_lookups_for_test()


## Registers one live "enemy" whose Threat contribution is fully controlled
## by `hp` (tower_seeker: intent_weight 1.25, sheet DPS 10 -> dps/10 = 1.0,
## so threat = 1.25 * hp -- see PressureMetric.compute_threat()).
func _register_threat_enemy(hp: float) -> _FakeActor:
	var actor: _FakeActor = _FakeActor.new()
	actor.definition = TowerSeekerDef
	var ds: DeathState = DeathState.new()
	ds.max_hp = 100.0
	ds.current_hp = hp
	actor.death_state = ds
	_registry.register_entity(actor, Vector2.ZERO, [&"enemy"])
	_free_later.append(actor)
	_free_later.append(ds) # DeathState extends Node -- a plain field reference, not a child, so freeing `actor` does not free it; must be tracked separately or it orphans
	return actor


func _fix_capacity(player_dps: float, tower_dps: float) -> void:
	_director.set_player_capacity_provider(func() -> float: return player_dps)
	_director.set_tower_capacity_provider(func() -> float: return tower_dps)


func _tick(seconds: float) -> void:
	var steps: int = int(round(seconds / STEP))
	for _i in steps:
		_clock.now += STEP
		_director.physics_step(STEP)


# =============================================================================
# 1. Pure static math -- no fixture
# =============================================================================

func test_compute_pressure_matches_threat_over_capacity_times_20s() -> void:
	# Named acceptance test: "Pressure = Threat / (Capacity x 20 s)".
	assert_float(PressureMetric.compute_pressure(200.0, 10.0)).append_failure_message("200/(10*20) should be 1.0").is_equal_approx(1.0, 0.0001)
	assert_float(PressureMetric.compute_pressure(120.0, 10.0)).append_failure_message("120/(10*20) should be 0.6").is_equal_approx(0.6, 0.0001)
	assert_float(PressureMetric.compute_pressure(360.0, 10.0)).append_failure_message("360/(10*20) should be 1.8").is_equal_approx(1.8, 0.0001)
	assert_float(PressureMetric.compute_pressure(50.0, 25.0)).append_failure_message("50/(25*20) should be 0.1").is_equal_approx(0.1, 0.0001)


func test_compute_pressure_is_zero_with_no_threat() -> void:
	# Register: "0 with no enemies" -- threat <= 0 always yields 0, whatever capacity is.
	assert_float(PressureMetric.compute_pressure(0.0, 45.0)).is_equal(0.0)
	assert_float(PressureMetric.compute_pressure(-5.0, 45.0)).is_equal(0.0) # never produced by compute_threat(), but must not crash or go negative


func test_compute_pressure_with_non_positive_capacity_and_positive_threat_is_the_documented_zero_fallback() -> void:
	# NO REGISTER ROW for this edge case -- escalated (see pressure_metric.gd
	# and the P2.9 evidence report). Documents the chosen behaviour: 0.0, not
	# a divide-by-zero crash or an INF that could force a spurious escalation
	# decision.
	assert_float(PressureMetric.compute_pressure(100.0, 0.0)).is_equal(0.0)
	assert_float(PressureMetric.compute_pressure(100.0, -1.0)).is_equal(0.0)


func test_compute_threat_sums_hp_times_intent_weight_times_sheet_dps_over_10() -> void:
	# Register > "Threat formula", using the REAL authored Attack profiles
	# (tower_seeker.tres: 15 dmg / 1.5 s = 10 DPS; player_hunter.tres: 8 dmg
	# / 0.5 s = 16 DPS; opportunist.tres: 10 dmg / 1.2 s ~= 8.333 DPS) and the
	# REAL authored intent weights (1.25 / 1.0 / 1.1).
	var seeker_dps: float = _stats.sheet_dps_from_attack_profile(TowerSeekerDef.attack_profile)
	var hunter_dps: float = _stats.sheet_dps_from_attack_profile(PlayerHunterDef.attack_profile)
	var opportunist_dps: float = _stats.sheet_dps_from_attack_profile(OpportunistDef.attack_profile)
	assert_float(seeker_dps).is_equal_approx(10.0, 0.001)
	assert_float(hunter_dps).is_equal_approx(16.0, 0.001)
	assert_float(opportunist_dps).is_equal_approx(8.3333, 0.001)

	var entries: Array = [
		{"current_hp": 60.0, "intent_weight": 1.25, "dps": seeker_dps}, # threat = 60 * 1.25 * 1.0 = 75
		{"current_hp": 30.0, "intent_weight": 1.0, "dps": hunter_dps}, # threat = 30 * 1.0 * 1.6 = 48
		{"current_hp": 45.0, "intent_weight": 1.1, "dps": opportunist_dps}, # threat = 45 * 1.1 * 0.8333.. = 41.25
	]
	var expected: float = 75.0 + 48.0 + 41.25
	assert_float(PressureMetric.compute_threat(entries)).append_failure_message("expected %.4f" % expected).is_equal_approx(expected, 0.01)


func test_compute_threat_is_zero_for_an_empty_or_all_dead_enemy_list() -> void:
	assert_float(PressureMetric.compute_threat([])).is_equal(0.0)


func test_intent_weights_in_director_configuration_match_the_register() -> void:
	# Falsification target: "changing an intent weight."
	var weight_by_intent: Dictionary = {}
	for entry in RealDirectorConfig.pressure_metric_intent_weights:
		weight_by_intent[(entry as PressureIntentWeightEntry).target_intent] = (entry as PressureIntentWeightEntry).weight
	assert_float(float(weight_by_intent.get(ContractEnums.TargetIntent.TowerSeeker, -1.0))).append_failure_message("Register > Threat formula: Tower Seeker intent weight must be 1.25").is_equal_approx(1.25, 0.0001)
	assert_float(float(weight_by_intent.get(ContractEnums.TargetIntent.PlayerHunter, -1.0))).append_failure_message("Register > Threat formula: Player Hunter intent weight must be 1.0").is_equal_approx(1.0, 0.0001)
	assert_float(float(weight_by_intent.get(ContractEnums.TargetIntent.Opportunist, -1.0))).append_failure_message("Register > Threat formula: Opportunist intent weight must be 1.1").is_equal_approx(1.1, 0.0001)


func test_compute_health_quadrant_boundary_and_nan_handling() -> void:
	# Register > "Health quadrant": "Low is below 40% of maximum health."
	assert_int(PressureMetric.compute_health_quadrant(0.5, 0.5, 0.4)).is_equal(PressureMetric.HealthQuadrant.BOTH_NORMAL)
	assert_int(PressureMetric.compute_health_quadrant(0.39, 0.5, 0.4)).is_equal(PressureMetric.HealthQuadrant.PLAYER_LOW)
	assert_int(PressureMetric.compute_health_quadrant(0.5, 0.39, 0.4)).is_equal(PressureMetric.HealthQuadrant.TOWER_LOW)
	assert_int(PressureMetric.compute_health_quadrant(0.1, 0.1, 0.4)).is_equal(PressureMetric.HealthQuadrant.BOTH_LOW)
	# Exactly at the threshold is NOT low ("below 40%", strict less-than).
	assert_int(PressureMetric.compute_health_quadrant(0.4, 0.4, 0.4)).append_failure_message("exactly at the threshold must not be Low ('below 40%' is a strict comparison)").is_equal(PressureMetric.HealthQuadrant.BOTH_NORMAL)
	# NAN (unresolved player/Tower) is treated as Normal, never fabricated as Low.
	assert_int(PressureMetric.compute_health_quadrant(NAN, NAN, 0.4)).is_equal(PressureMetric.HealthQuadrant.BOTH_NORMAL)
	assert_str(PressureMetric.quadrant_label(PressureMetric.HealthQuadrant.BOTH_LOW)).is_equal("BothLow")


# =============================================================================
# 2. PressureMetric state machine, direct -- REAL authored timers, no scene tree
# =============================================================================

func _real_timers() -> PressureMetricConstants:
	return RealDirectorConfig.pressure_metric_timers


func test_escalation_requires_3_seconds_continuously_below_threshold() -> void:
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	# Below threshold for only 2.9 s -- must not escalate yet.
	while t < 2.9:
		var result: Dictionary = pm.update(t, 0.3, false, false, c)
		assert_bool(result["escalate"]).append_failure_message("escalated too early at t=%.2f (held < hold_time)" % t).is_false()
		t += 0.5
	# Cross 3.0 s -- must now escalate.
	t = 3.5
	var result2: Dictionary = pm.update(t, 0.3, false, false, c)
	assert_bool(result2["escalate"]).append_failure_message("did not escalate once held past the 3 s hold time").is_true()


func test_escalation_resets_the_hold_timer_if_pressure_recovers_above_threshold() -> void:
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	pm.update(0.0, 0.3, false, false, c)
	pm.update(2.0, 0.3, false, false, c) # 2 s held so far
	pm.update(2.1, 0.9, false, false, c) # pressure recovers -- hold resets
	pm.update(4.0, 0.3, false, false, c) # only ~1.9 s held since the reset
	var result: Dictionary = pm.update(4.5, 0.3, false, false, c) # ~2.4 s -- still short of 3 s
	assert_bool(result["escalate"]).append_failure_message("hold timer did not reset when pressure recovered above threshold").is_false()


func test_escalation_enforces_4_second_minimum_gap_between_escalations() -> void:
	# Falsification target: "removing the 4-second minimum between escalations."
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	pm.update(0.0, 0.3, false, false, c) # primes the hold timer at t=0
	var first_time: float = 3.1 # >= 3.0 s held since t=0
	var first: Dictionary = pm.update(first_time, 0.3, false, false, c)
	assert_bool(first["escalate"]).append_failure_message("test setup invalid: the first escalation never fired").is_true()
	pm.notify_escalated(first_time) # matches WaveDirector's real contract: only call this once a group actually started

	# Pressure stays continuously below threshold, so the ONLY thing gating
	# a repeat is the minimum gap -- probe every 0.5 s up to just under 4 s
	# after the first escalation.
	var t: float = first_time
	while t < first_time + 4.0 - 0.5:
		t += 0.5
		var r: Dictionary = pm.update(t, 0.3, false, false, c)
		assert_bool(r["escalate"]).append_failure_message("re-escalated at t=%.2f, only %.2f s after the first escalation -- less than the 4 s minimum" % [t, t - first_time]).is_false()

	# Past 4 s, it may fire again.
	var r2: Dictionary = pm.update(first_time + 4.1, 0.3, false, false, c)
	assert_bool(r2["escalate"]).append_failure_message("did not re-escalate once the 4 s minimum gap had elapsed").is_true()


func test_escalation_does_nothing_in_a_siege() -> void:
	# docs/11 > "Wave Runtime Model": "In a Siege the Escalation Trigger does nothing."
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	while t < 6.0:
		var r: Dictionary = pm.update(t, 0.2, true, false, c) # is_siege = true throughout
		assert_bool(r["escalate"]).append_failure_message("escalated during a Siege at t=%.2f" % t).is_false()
		t += 0.5


func test_de_escalation_activates_above_1_8_and_lifts_below_1_2() -> void:
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var r1: Dictionary = pm.update(0.0, 2.0, false, false, c)
	assert_bool(r1["de_escalating"]).append_failure_message("did not activate above 1.8").is_true()
	assert_bool(pm.is_de_escalation_active()).is_true()

	var r2: Dictionary = pm.update(1.0, 1.5, false, false, c) # still above the 1.2 lift threshold -- stays active
	assert_bool(r2["de_escalating"]).append_failure_message("lifted before pressure fell below 1.2").is_true()

	var r3: Dictionary = pm.update(2.0, 1.1, false, false, c) # below 1.2 -- must lift now
	assert_bool(r3["de_escalating"]).append_failure_message("did not lift once pressure fell below 1.2").is_false()
	assert_bool(pm.is_de_escalation_active()).is_false()


func test_de_escalation_expires_after_10_seconds_even_if_pressure_stays_high() -> void:
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	pm.update(0.0, 2.0, false, false, c)
	assert_bool(pm.is_de_escalation_active()).is_true()
	# Pressure never drops -- only the 10 s expiry can end this.
	pm.update(9.9, 2.0, false, false, c)
	assert_bool(pm.is_de_escalation_active()).append_failure_message("expired before 10 s had elapsed").is_true()
	pm.update(10.1, 2.0, false, false, c)
	assert_bool(pm.is_de_escalation_active()).append_failure_message("did not expire after 10 s of sustained high pressure").is_false()


func test_de_escalation_re_arm_lockout_blocks_immediate_retrigger() -> void:
	# Falsification target: "removing the 6-second re-arm lockout."
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var lift_time: float = 1.0
	pm.update(0.0, 2.0, false, false, c) # activates
	pm.update(lift_time, 1.0, false, false, c) # lifts (below 1.2) -- lockout now runs lift_time .. lift_time + 6.0

	# Probe at fixed offsets safely INSIDE the 6 s lockout (up to 5.5 s after
	# lifting -- a clear 0.5 s margin below the 6 s boundary).
	for i in 11:
		var probe_t: float = lift_time + 0.5 * float(i + 1)
		var r: Dictionary = pm.update(probe_t, 2.0, false, false, c) # pressure immediately back above 1.8
		assert_bool(r["de_escalating"]).append_failure_message("re-armed at t=%.2f, only %.2f s after lifting -- less than the 6 s lockout" % [probe_t, probe_t - lift_time]).is_false()

	# Comfortably past the 6 s lockout (0.5 s margin above the boundary).
	var r2: Dictionary = pm.update(lift_time + 6.5, 2.0, false, false, c)
	assert_bool(r2["de_escalating"]).append_failure_message("did not re-arm once the 6 s lockout had elapsed").is_true()


func test_de_escalation_never_applies_during_a_siege() -> void:
	# Task instruction item 5 + falsification target: "allowing de-escalation
	# during a Siege." Register: "De-escalation ... never applies during a
	# Siege or Overtime."
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	while t < 15.0: # well past the 10 s expiry window, to prove it never even starts
		var r: Dictionary = pm.update(t, 2.0, true, false, c) # is_siege = true, pressure sustained at 2.0
		assert_bool(r["de_escalating"]).append_failure_message("de-escalation was active during a Siege at t=%.2f" % t).is_false()
		assert_bool(pm.is_de_escalation_active()).is_false()
		t += 0.5


func test_de_escalation_never_applies_during_overtime() -> void:
	# Register: same clause, "... or Overtime." WaveDirector never passes
	# is_overtime = true today (P2.8 deferred Overtime -- see wave_director.gd
	# header), so this is exercised directly against PressureMetric, which is
	# exactly what its pure-RefCounted design is for.
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	while t < 15.0:
		var r: Dictionary = pm.update(t, 2.0, false, true, c) # is_overtime = true
		assert_bool(r["de_escalating"]).append_failure_message("de-escalation was active during Overtime at t=%.2f" % t).is_false()
		t += 0.5


func test_boundary_oscillation_cannot_retrigger_escalation_inside_its_own_gap() -> void:
	# Predetermined risk (PLAN.md): "escalation and de-escalation triggers sit
	# close enough ... unless both cooldowns are enforced independently."
	# Pressure wobbles near the 0.6 threshold: 3.5 s below it (long enough to
	# satisfy the 3 s hold), then a single 0.5 s "boundary noise" blip back
	# above it, repeating -- rather than resetting every tick (which would
	# never let the hold timer accumulate at all and make this test
	# vacuously pass with zero escalations, the exact defect the falsely-
	# oscillating first draft of this test had).
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	var tick_index: int = 0
	var fire_times: Array[float] = []
	while t < 30.0:
		var in_blip: bool = (tick_index % 8) == 7 # one blip every 4 s (8 ticks of 0.5 s)
		var pressure: float = 0.9 if in_blip else 0.3
		var r: Dictionary = pm.update(t, pressure, false, false, c)
		if bool(r["escalate"]):
			if not fire_times.is_empty():
				var gap: float = t - fire_times[-1]
				assert_float(gap).append_failure_message("escalation re-fired only %.2f s after the previous one (must be >= 4 s) -- boundary oscillation defeated the minimum-gap lockout" % gap).is_greater_equal(4.0)
			fire_times.append(t)
			pm.notify_escalated(t)
		tick_index += 1
		t += 0.5
	assert_int(fire_times.size()).append_failure_message("oscillation escalated fewer than twice -- test fixture invalid (cannot prove the gap held across a repeat)").is_greater(1)


func test_boundary_oscillation_cannot_retrigger_de_escalation_inside_its_own_lockout() -> void:
	var pm: PressureMetric = PressureMetric.new()
	var c: PressureMetricConstants = _real_timers()
	var t: float = 0.0
	var activation_times: Array[float] = []
	var was_active: bool = false
	var high: bool = true
	while t < 40.0:
		var pressure: float = 2.0 if high else 1.0 # oscillates across both 1.8 and 1.2
		high = not high
		var r: Dictionary = pm.update(t, pressure, false, false, c)
		var now_active: bool = bool(r["de_escalating"])
		if now_active and not was_active:
			if not activation_times.is_empty():
				var gap: float = t - activation_times[-1]
				assert_float(gap).append_failure_message("de-escalation re-activated only %.2f s after its own previous activation -- expected the activation-to-activation spacing to respect both the state's own minimum lifetime and the 6 s re-arm lockout after it lifts" % gap).is_greater_equal(6.0)
			activation_times.append(t)
		was_active = now_active
		t += 0.5
	assert_int(activation_times.size()).append_failure_message("oscillation never activated de-escalation at all -- test fixture invalid").is_greater(0)


# =============================================================================
# 3. src/director/wave_director.gd end to end
# =============================================================================

func test_pressure_reproduces_the_formula_end_to_end_with_a_scripted_enemy_and_capacity() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_fix_capacity(1.0, 0.0) # total Capacity = 1.0
	_register_threat_enemy(32.0) # Threat = 32 * 1.25 * 1.0 = 40 -> Pressure = 40 / (1.0 * 20) = 2.0
	_tick(0.6) # past the first 0.5 s evaluation cadence
	assert_float(_director.get_pressure_value_for_test()).append_failure_message("scripted Threat=40, Capacity=1.0 should reproduce Pressure=2.0").is_equal_approx(2.0, 0.01)


func test_pressure_is_zero_with_no_enemies_end_to_end() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_fix_capacity(20.0, 25.0)
	_tick(0.6)
	assert_float(_director.get_pressure_value_for_test()).is_equal(0.0)


func test_escalation_starts_the_next_pending_spawn_group_before_its_authored_offset() -> void:
	# Group 0 emits its single spawn immediately (start_offset 0), so it is
	# no longer "pending." Group 1's authored start_offset (100 s) is far
	# beyond this test's window -- if it fires at all, it can only be the
	# Escalation Trigger. No enemy is registered, so Threat = 0 -> Pressure =
	# 0 continuously, satisfying "stays below 0.6" trivially.
	_install_single_wave([_make_group(1, 0.0, 1.0), _make_group(1, 100.0, 1.0)])
	_tick(0.2) # let group 0's immediate spawn land
	assert_int(_director.get_emitted_count_for_test(0)).is_equal(1)
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("group 1 must not have spawned yet").is_equal(0)

	_tick(4.0) # past the 3 s hold time, comfortably before the 100 s authored offset
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("Escalation Trigger did not start the next pending spawn group").is_equal(1)
	assert_float(_director.get_group_start_offset_override_for_test(1)).append_failure_message("no start-offset override was recorded for the escalated group").is_greater_equal(0.0)
	assert_float(_director.get_pressure_metric_for_test().get_last_escalation_time_for_test()).append_failure_message("notify_escalated() was never recorded").is_greater(-1.0)


func test_escalation_does_nothing_when_no_spawn_group_remains() -> void:
	# A single group that already emitted its one spawn -- nothing left to escalate.
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_tick(6.0) # comfortably past the hold time
	assert_int(_director.get_emitted_count_for_test(0)).is_equal(1) # its one authored spawn, nothing extra
	assert_str(_director.get_pressure_state_for_test()).append_failure_message("state read 'Escalated' with no pending group to escalate").is_not_equal("Escalated")


func test_escalation_respects_the_minimum_gap_across_two_pending_groups() -> void:
	_install_single_wave([
		_make_group(1, 0.0, 1.0),
		_make_group(1, 100.0, 1.0),
		_make_group(1, 200.0, 1.0),
	])
	_tick(6.0) # generous margin past the 3 s hold time -- group 1 must have escalated by now
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("setup invalid: group 1 should have escalated by now").is_equal(1)
	var escalate_time_1: float = _director.get_pressure_metric_for_test().get_last_escalation_time_for_test()
	var elapsed_since_escalation_1: float = _clock.now - escalate_time_1

	# Advance to land solidly INSIDE the 4 s minimum-gap window (computed
	# relative to escalate_time_1, not a fixed offset, so this does not
	# depend on exactly which tick the first escalation landed on).
	_tick(maxf(0.1, 3.4 - elapsed_since_escalation_1))
	assert_int(_director.get_emitted_count_for_test(2)).append_failure_message("group 2 escalated less than 4 s after group 1 (now - escalate_time_1 = %.2f s) -- the minimum-gap cooldown was not honoured" % (_clock.now - escalate_time_1)).is_equal(0)

	# Advance past the 4 s minimum gap.
	_tick(1.0)
	assert_int(_director.get_emitted_count_for_test(2)).append_failure_message("group 2 never escalated once the 4 s minimum gap had elapsed (now - escalate_time_1 = %.2f s)" % (_clock.now - escalate_time_1)).is_equal(1)
	var escalate_time_2: float = _director.get_pressure_metric_for_test().get_last_escalation_time_for_test()
	assert_float(escalate_time_2 - escalate_time_1).is_greater_equal(4.0)


## A second, independent WaveDirector fixture (its own fresh registry/clock/
## spawner/CombatStats, matching before_test()'s own construction), used only
## by test_de_escalation_doubles_spawn_intervals_while_active() as a
## no-de-escalation baseline to compare against. Everything it creates is
## auto_free()'d, matching this suite's own convention.
func _run_baseline_fixture_and_get_emitted_count(window_seconds: float) -> int:
	var registry_b: Node = auto_free(EntityRegistryScript.new())
	add_child(registry_b)
	var clock_b: Node = auto_free(SimClockScript.new())
	var spawner_b: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner_b)
	spawner_b.set_registry_for_test(registry_b)
	var stats_b: Node = auto_free(CombatStatsScript.new())
	add_child(stats_b)

	var director_b: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director_b.driven_externally = true
	add_child(director_b)
	director_b.set_registry_for_test(registry_b)
	director_b.set_sim_clock_for_test(clock_b)
	director_b.set_entity_spawner_for_test(spawner_b)
	director_b.set_combat_stats_for_test(stats_b)
	var dummy: PackedScene = _build_dummy_scene()
	director_b.tower_seeker_scene = dummy
	director_b.player_hunter_scene = dummy
	director_b.opportunist_scene = dummy
	director_b.rebuild_lookups_for_test()

	var encounter_b: EncounterDefinition = EncounterDefinition.new()
	encounter_b.unique_id = "pressure_test_encounter_b"
	encounter_b.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter_b.spawn_groups = [_make_group(30, 0.0, 1.0)]
	encounter_b.minimum_recovery_gap_seconds = 5.0
	var wave_b: WaveDefinition = WaveDefinition.new()
	wave_b.unique_id = "pressure_test_wave_b"
	wave_b.encounter_sequence = ["pressure_test_encounter_b"]
	wave_b.maximum_duration_seconds = 10000.0
	wave_b.has_maximum_duration = true
	wave_b.inter_wave_gap_seconds = 8.0
	director_b.waves = [wave_b]
	director_b.encounter_definitions = [encounter_b]
	director_b.rebuild_lookups_for_test()

	var steps: int = int(round(window_seconds / STEP))
	for _i in steps:
		clock_b.now += STEP
		director_b.physics_step(STEP)
	var emitted: int = director_b.get_emitted_count_for_test(0)
	spawner_b.clear_all_for_test()
	return emitted


func test_de_escalation_doubles_spawn_intervals_while_active() -> void:
	# Comparative check (robust to cadence/off-by-one edge effects): the same
	# window of simulated time produces roughly half as many spawns when
	# Pressure is sustained above 1.8 throughout, versus a matched fixture
	# with no enemy alive (Pressure pinned at 0, de-escalation never active).
	var window_seconds: float = 9.0

	_install_single_wave([_make_group(30, 0.0, 1.0)])
	_fix_capacity(1.0, 0.0)
	_register_threat_enemy(32.0) # Pressure = 2.0, as in the formula test above
	_tick(window_seconds)
	var emitted_de_escalated: int = _director.get_emitted_count_for_test(0)
	assert_bool(_director.is_de_escalation_active_for_test()).append_failure_message("test fixture invalid: de-escalation never activated").is_true()

	var emitted_baseline: int = _run_baseline_fixture_and_get_emitted_count(window_seconds)

	assert_int(emitted_baseline).append_failure_message("baseline fixture spawned nothing -- test invalid").is_greater(0)
	assert_int(emitted_de_escalated).append_failure_message("de-escalated run (%d spawns) was not fewer than the baseline (%d spawns) over the same %0.1f s window" % [emitted_de_escalated, emitted_baseline, window_seconds]).is_less(emitted_baseline)
	# Roughly half, generous tolerance for the ramp-up before de-escalation first engages.
	assert_int(emitted_de_escalated).append_failure_message("de-escalated count (%d) was not close to half the baseline (%d)" % [emitted_de_escalated, emitted_baseline]).is_greater_equal(int(emitted_baseline / 2) - 2)
	assert_int(emitted_de_escalated).append_failure_message("de-escalated count (%d) was not close to half the baseline (%d)" % [emitted_de_escalated, emitted_baseline]).is_less_equal(int(emitted_baseline / 2) + 2)


func test_pressure_is_not_evaluated_during_a_teaching_wave() -> void:
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "teaching_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [_make_group(1, 0.0, 1.0)]
	encounter.minimum_recovery_gap_seconds = 5.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "wave_t1" # IS a teaching wave -- default teaching_wave_unique_ids
	wave.encounter_sequence = ["teaching_encounter"]
	wave.maximum_duration_seconds = 10000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 5.0
	_director.waves = [wave]
	_director.encounter_definitions = [encounter]
	_director.rebuild_lookups_for_test()
	_fix_capacity(1.0, 0.0)
	_register_threat_enemy(32.0) # would read Pressure = 2.0 if evaluated

	_tick(5.0)
	assert_float(_director.get_pressure_value_for_test()).append_failure_message("Pressure was evaluated during a teaching wave").is_equal(0.0)
	assert_str(_director.get_pressure_state_for_test()).is_equal("Normal")


func test_pressure_is_not_evaluated_during_the_grace_period() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0), _make_group(1, 100.0, 1.0)])
	_tick(0.2)
	_director.notify_draft_closed(_clock.now) # grace period now runs for post_draft_grace_period_seconds (1.5 s, director_configuration.tres)
	_tick(1.3) # inside the grace period
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("Escalation Trigger fired during the post-draft grace period").is_equal(0)
	_tick(6.0) # past the grace period, then past the hold time
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("Escalation Trigger never fired once the grace period ended").is_equal(1)


func test_health_quadrant_reports_low_for_either_pool_and_has_no_effect_on_spawn_selection() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0), _make_group(1, 100.0, 1.0)])
	var fake_tower: _FakeTower = _FakeTower.new()
	var fake_health: _FakeTowerHealth = _FakeTowerHealth.new()
	fake_health.max_health = 500.0
	fake_health.current_health = 100.0 # 20% -- Low
	fake_tower.health = fake_health
	_director.set_tower_reference(fake_tower)
	_free_later.append(fake_tower)

	var fake_player: _FakeActor = _FakeActor.new()
	var player_ds: DeathState = DeathState.new()
	player_ds.max_hp = 100.0
	player_ds.current_hp = 80.0 # 80% -- Normal
	fake_player.death_state = player_ds
	_registry.register_entity(fake_player, Vector2.ZERO, [&"player"])
	_free_later.append(fake_player)
	_free_later.append(player_ds) # see _register_threat_enemy()'s own comment -- DeathState is a field reference, not a child

	_tick(0.6)
	assert_str(_director.get_health_quadrant_for_test()).append_failure_message("expected TowerLow (Tower at 20%%, player at 80%%)").is_equal("TowerLow")

	# No effect on spawn selection: with the quadrant Low, the next pending
	# group (group 1, far offset) still only starts through the ordinary
	# Escalation Trigger path, exactly as in the quadrant-agnostic escalation
	# test above -- nothing here special-cases TowerLow to change WHICH group
	# or WHICH enemy type spawns next.
	_tick(4.0)
	assert_int(_director.get_emitted_count_for_test(1)).append_failure_message("escalation behaviour changed under a Low quadrant -- quadrant-aware selection must remain out of scope").is_equal(1)


func test_overlay_receives_pressure_state_and_quadrant_pushed_by_the_wave_director() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_fix_capacity(1.0, 0.0)
	_register_threat_enemy(32.0)
	var overlay: _FakeOverlay = auto_free(_FakeOverlay.new())
	add_child(overlay)
	_director.set_debug_overlay_reference(overlay)

	_tick(0.6)
	assert_int(overlay.pressure_calls.size()).append_failure_message("set_pressure() was never called on the overlay").is_greater(0)
	var last_call: Dictionary = overlay.pressure_calls[-1]
	assert_float(float(last_call["value"])).is_equal_approx(_director.get_pressure_value_for_test(), 0.0001)
	assert_str(String(last_call["state"])).is_equal(_director.get_pressure_state_for_test())
	assert_int(overlay.quadrant_calls.size()).append_failure_message("set_health_quadrant() was never called on the overlay").is_greater(0)
	assert_str(String(overlay.quadrant_calls[-1])).is_equal(_director.get_health_quadrant_for_test())


func test_capacity_falls_back_through_provider_then_combat_stats_then_base_weapon() -> void:
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_register_threat_enemy(20.0) # Threat = 20 * 1.25 = 25, fixed for this whole test

	# (3) Nothing wired at all -- base weapon fallback: handgun.tres (20 DPS)
	# + base_weapon.tres (25 DPS) = 45 total Capacity.
	_tick(0.6)
	var expected_base: float = 25.0 / (45.0 * 20.0)
	assert_float(_director.get_pressure_value_for_test()).append_failure_message("base-weapon Capacity fallback did not apply").is_equal_approx(expected_base, 0.01)

	# (2) CombatStats has reported a value -- it must now win over the base fallback.
	_stats.report_sheet_dps(&"player", 100.0)
	_stats.report_sheet_dps(&"tower", 0.0)
	_tick(0.6)
	var expected_stats: float = 25.0 / (100.0 * 20.0)
	assert_float(_director.get_pressure_value_for_test()).append_failure_message("CombatStats-reported Capacity was not used once available").is_equal_approx(expected_stats, 0.01)

	# (1) An explicit provider -- must win over both of the above.
	_director.set_player_capacity_provider(func() -> float: return 5.0)
	_director.set_tower_capacity_provider(func() -> float: return 0.0)
	_tick(0.6)
	var expected_provider: float = 25.0 / (5.0 * 20.0)
	assert_float(_director.get_pressure_value_for_test()).append_failure_message("explicit capacity provider did not take priority").is_equal_approx(expected_provider, 0.01)


func test_capacity_is_not_affected_by_an_unrelated_pause_reason() -> void:
	# Register: "the player's term is not zeroed while the Console is open."
	# No Console exists yet, so this proves the more general property the
	# task requires of this code: capacity reading has no branch on
	# PauseAuthority state at all.
	_install_single_wave([_make_group(1, 0.0, 1.0)])
	_fix_capacity(20.0, 25.0)
	_register_threat_enemy(20.0)
	_tick(0.6)
	var before: float = _director.get_pressure_value_for_test()

	PauseAuthority.push_reason(&"pressure_test_unrelated_reason")
	_tick(0.6)
	var during: float = _director.get_pressure_value_for_test()
	PauseAuthority.pop_reason(&"pressure_test_unrelated_reason")

	assert_float(during).append_failure_message("Pressure/Capacity changed while an unrelated pause reason was active -- capacity reading must not special-case pause state").is_equal_approx(before, 0.0001)

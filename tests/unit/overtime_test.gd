extends GdUnitTestSuite

## Overtime test (P2.8b named acceptance test; MASTER_SDLC.md > Acceptance
## Test Matrix > Encounter Tests > "Overtime test": "P2.8 result for the
## finisher spawn-or-not decision at the stall threshold"). docs/11 > "Wave
## Runtime Model" ("During Overtime..."); MASTER_SDLC.md > Provisional
## Values Register > Spawning & Waves > "Overtime finishers".
##
## Scope split from tests/unit/wave_runtime_test.gd: that suite proves the
## STALL DECISION and wave-level consequences; this suite proves the
## SPAWN-OR-NOT decision precisely at the threshold boundary, the finisher's
## own stats/flag, its spawn rate, and -- the Phase 04 PLAN.md predetermined
## risk this task exists to close -- that finisher spawning is throttled by
## the SAME cap mechanism as an ordinary spawn group, not around it.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

var _spawners: Array[Node] = []


func before_test() -> void:
	_spawners.clear()


func after_test() -> void:
	for s in _spawners:
		if s != null:
			s.clear_all_for_test()


## A bare Node2D dummy (spawn_ring_test.gd's own convention) has no
## `is_finisher`/`definition` properties, so `entity.get("is_finisher")`
## always reads null on it -- fine for suites that only count spawns, but
## this suite must actually READ those two fields back (the stats test, and
## wave_director.gd's own `_all_non_finisher_enemies_dead()` internally).
## A small script attached at runtime (never written to disk, so this stays
## a test-only fixture, not a new src/ file) gives the dummy real,
## settable/gettable fields shaped exactly like EnemyController's own,
## without depending on the real scene tree EnemyController needs.
func _build_dummy_scene() -> PackedScene:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node2D\nvar is_finisher: bool = false\nvar definition: EnemyDefinition = null\n"
	script.reload()
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	n.set_script(script)
	packed.pack(n)
	n.free()
	return packed


func _build_director(waves: Array[WaveDefinition], encounters: Array[EncounterDefinition]) -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = 909
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)

	var bus: Node = auto_free(Node.new())
	bus.add_user_signal("enemy_died", [
		{"name": "entity", "type": TYPE_OBJECT},
		{"name": "position", "type": TYPE_VECTOR2},
		{"name": "timestamp", "type": TYPE_FLOAT},
	])
	add_child(bus)
	director.set_event_bus_for_test(bus)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	director.waves = waves
	director.encounter_definitions = encounters
	director.rebuild_lookups_for_test()

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director, "bus": bus}


func _advance(director: WaveDirector, clock: Node, seconds: float, step: float = 0.1) -> void:
	var steps: int = int(round(seconds / step))
	for _i in steps:
		clock.now += step
		director.physics_step(step)


func _emit_kills(bus: Node, clock: Node, count: int) -> void:
	for i in count:
		bus.emit_signal("enemy_died", auto_free(Node.new()), Vector2.ZERO, clock.now)


func _make_wave(id: String, max_duration: float, stall_threshold: int) -> WaveDefinition:
	var overtime: OvertimeCondition = OvertimeCondition.new()
	overtime.stall_threshold = stall_threshold
	overtime.finisher_enemy_id = "player_hunter_finisher"
	var rate: FinisherSpawnRate = FinisherSpawnRate.new()
	rate.count = 2 # Register: "2 per 5 s"
	rate.interval_seconds = 5.0
	overtime.finisher_spawn_rate = rate
	var drop: DropTable = DropTable.new()
	drop.xp_shards = 1
	overtime.finisher_drop_override = drop

	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = id
	wave.encounter_sequence = [id + "_encounter"]
	wave.maximum_duration_seconds = max_duration
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0
	wave.overtime_condition = overtime
	return wave


func _make_encounter(id: String, alive_cap: int = 0) -> EncounterDefinition:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = id + "_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 8.0
	encounter.encounter_alive_cap = alive_cap
	return encounter


# --- The spawn-or-not decision, exactly at the threshold boundary -----------

func test_kills_at_the_threshold_do_not_stall_and_no_finisher_ever_spawns() -> void:
	var w1: WaveDefinition = _make_wave("ot_boundary_w1", 5.0, 5)
	var e1: EncounterDefinition = _make_encounter("ot_boundary_w1")
	var w2: WaveDefinition = _make_wave("ot_boundary_w2", 5.0, 5)
	var e2: EncounterDefinition = _make_encounter("ot_boundary_w2")
	var ctx: Dictionary = _build_director([w1, w2], [e1, e2])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	_emit_kills(ctx["bus"], clock, 5) # exactly the threshold -- "below" is strict, so this must NOT stall
	_advance(director, clock, 20.0, 0.1) # well past two finisher intervals, if Overtime were (wrongly) active

	assert_bool(director.is_overtime_active_for_test()).append_failure_message("5 kills meets the stall threshold of 5 -- Overtime must not start").is_false()
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("no finisher may spawn when Overtime never started").is_equal(0)


func test_kills_one_below_the_threshold_stalls_and_finishers_spawn() -> void:
	var w: WaveDefinition = _make_wave("ot_below", 5.0, 5)
	var e: EncounterDefinition = _make_encounter("ot_below")
	var ctx: Dictionary = _build_director([w], [e]) # final wave -- keeps Overtime running for the whole observation window
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	_emit_kills(ctx["bus"], clock, 4) # one below the threshold of 5 -- must stall
	_advance(director, clock, 6.0, 0.1) # cross maximum duration, with margin (see wave_runtime_test.gd's own note on _wave_open_time's real boundary)

	assert_bool(director.is_overtime_active_for_test()).append_failure_message("4 kills is below the stall threshold of 5 -- Overtime must start").is_true()
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("Overtime is active; at least the first finisher burst must have spawned").is_greater(0)


# --- Finisher stats and flag (Register: "25% Hunter health, 160% Hunter
# speed ... the finisher flag survives any conversion") -------------------

func test_finisher_carries_the_reduced_stat_definition_and_the_is_finisher_flag() -> void:
	var w: WaveDefinition = _make_wave("ot_stats", 3.0, 5)
	var e: EncounterDefinition = _make_encounter("ot_stats")
	var ctx: Dictionary = _build_director([w], [e])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	_advance(director, clock, 4.0, 0.1) # zero kills throughout -- guarantees a stall

	assert_bool(director.is_overtime_active_for_test()).is_true()
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("no finisher spawned to inspect").is_greater(0)

	var finisher_definition: EnemyDefinition = preload("res://data/encounters/player_hunter_finisher.tres")
	var normal_hunter_definition: EnemyDefinition = preload("res://data/enemies/player_hunter.tres")
	var live: Array[Node2D] = registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	var found_finisher: bool = false
	for entity in live:
		var v: Variant = entity.get("is_finisher")
		if v is bool and v:
			found_finisher = true
			assert_object(entity.get("definition")).append_failure_message("a finisher must carry player_hunter_finisher.tres, not the normal Hunter definition").is_same(finisher_definition)

	assert_bool(found_finisher).append_failure_message("no live entity carried is_finisher = true").is_true()

	# Register percentages, checked against the AUTHORED normal Hunter (not
	# restated as literals here): 25% health, 160% speed.
	assert_int(finisher_definition.health_band.value).append_failure_message("finisher health should be 25%% of the normal Hunter's %d (rounded)" % normal_hunter_definition.health_band.value).is_equal(int(round(0.25 * float(normal_hunter_definition.health_band.value))))
	assert_float(finisher_definition.movement_profile.speed_multiplier).append_failure_message("finisher speed multiplier should be 160%% of the normal Hunter's %.2f" % normal_hunter_definition.movement_profile.speed_multiplier).is_equal_approx(1.6 * normal_hunter_definition.movement_profile.speed_multiplier, 0.001)


## Register: "2 per 5 s" -- a second burst must land only after a full
## interval, not immediately alongside the first.
func test_finishers_spawn_at_two_per_five_seconds() -> void:
	var w: WaveDefinition = _make_wave("ot_rate", 3.0, 5)
	var e: EncounterDefinition = _make_encounter("ot_rate")
	var ctx: Dictionary = _build_director([w], [e])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	_advance(director, clock, 3.5, 0.1) # cross into Overtime, with margin (see wave_runtime_test.gd's own note on _wave_open_time's real boundary)
	assert_bool(director.is_overtime_active_for_test()).is_true()
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("the first burst (2) should have spawned immediately on entering Overtime").is_equal(2)

	_advance(director, clock, 2.0, 0.1) # short of the 5 s interval
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("a second burst spawned before its 5 s interval elapsed").is_equal(2)

	_advance(director, clock, 3.5, 0.1) # crosses the 5 s interval (2.0 + 3.5 = 5.5 since the first burst)
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("the second burst of 2 did not land after its 5 s interval elapsed").is_equal(4)


# --- Predetermined Phase 04 risk: finishers must respect the SAME cap ------

## PLAN.md > "Predetermined failure points and risks" > "The entity cap
## being exceeded by Overtime finishers": "Implement finisher spawning as a
## spawn group like any other, subject to the same global entity cap and
## ring validation/throttle logic." Proven here via the encounter-level
## alive cap (test-controllable, unlike the fixed 300 global constant):
## with the cap already saturated by the encounter's own ordinary (never-
## dying) spawn, EVERY finisher attempt must be throttled -- zero finishers
## ever spawn, even though Overtime genuinely runs for several intervals.
func test_finishers_are_throttled_by_the_same_alive_cap_as_an_ordinary_spawn() -> void:
	var w: WaveDefinition = _make_wave("ot_cap", 3.0, 5)
	var e: EncounterDefinition = _make_encounter("ot_cap", 1) # cap of 1, already met by the encounter's own 1 (never-dying) spawn
	var ctx: Dictionary = _build_director([w], [e])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	_advance(director, clock, 3.1, 0.1)
	assert_int(registry.get_live_enemy_count()).append_failure_message("test setup: the encounter's own spawn must have landed, saturating the cap of 1").is_equal(1)

	_advance(director, clock, 15.0, 0.1) # several finisher intervals' worth of time

	assert_bool(director.is_overtime_active_for_test()).append_failure_message("test setup: Overtime must genuinely be running for this to prove anything").is_true()
	assert_int(director.get_finisher_spawned_count_for_test()).append_failure_message("the encounter alive cap (1, already saturated) did not throttle finisher spawning -- Phase 04's own predetermined risk").is_equal(0)
	assert_int(registry.get_live_enemy_count()).append_failure_message("the alive cap (1) was exceeded").is_less_equal(1)

extends GdUnitTestSuite

## Wave runtime test (P2.8b named acceptance test; MASTER_SDLC.md >
## Acceptance Test Matrix > Encounter Tests > "Wave runtime test": "P2.8
## result for stall/no-stall, carry-over, and the never-times-out final
## wave"). docs/11_Wave_Director.md > "Wave Runtime Model" in full;
## MASTER_SDLC.md > Provisional Values Register > Spawning & Waves >
## "Wave end / STALLED", "NOT STALLED carry-over", "Final combat wave rule
## (C-FINAL)".
##
## This is the STALL half of the two-branch rule P2.8 deliberately left as
## one branch (phases/PHASE_03_.../evidence/p28_report.md, Deferred item 2).
## The Overtime/finisher SPAWNING half has its own suite
## (tests/unit/overtime_test.gd); this file's own scope is the STALL
## DECISION itself, carry-over, and the final wave's own re-check cadence.
##
## Fresh EntityRegistry/SimClock/EntitySpawner/WaveDirector per test, plus a
## fake EventBus double (matching tests/unit/drop_table_test.gd's own
## `add_user_signal` pattern) so "kills" can be scripted precisely without
## needing real combat plumbing -- this suite is about wave/encounter STATE,
## not damage resolution, which is already covered elsewhere (P1.5's Ghost
## hit test, P2.5's leash/opportunist suites).

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

var _spawners: Array[Node] = [] # released in after_test(), matching spawn_ring_test.gd's own convention (no pool container wired -> spawns never auto_free)


func before_test() -> void:
	_spawners.clear()


func after_test() -> void:
	for s in _spawners:
		if s != null:
			s.clear_all_for_test()


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free() # pack() does not take ownership of n -- see spawn_ring_test.gd's own identical note
	return packed


## `waves`/`encounters` supplied fully built by the caller (this suite needs
## fine control over `overtime_condition` per scenario). Returns a Dictionary
## the caller drives directly.
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
	director.run_seed = 4242
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


## Fires `count` non-finisher kills, evenly spread across the last few
## seconds before `now`, all comfortably inside the Register's 30 s stall
## window. A bare Node has no `is_finisher` property, so
## `wave_director.gd`'s own duck-typed `entity.get("is_finisher")` reads
## null -- correctly counted as a real (non-finisher) kill.
func _emit_kills(bus: Node, clock: Node, count: int) -> void:
	for i in count:
		bus.emit_signal("enemy_died", auto_free(Node.new()), Vector2.ZERO, clock.now)


func _make_wave(id: String, max_duration: float, stall_threshold: int, inter_wave_gap: float = 8.0) -> WaveDefinition:
	var overtime: OvertimeCondition = OvertimeCondition.new()
	overtime.stall_threshold = stall_threshold
	overtime.finisher_enemy_id = "player_hunter" # dummy scene stands in; not spawned by this suite's own scenarios unless Overtime actually fires
	var rate: FinisherSpawnRate = FinisherSpawnRate.new()
	rate.count = 2
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
	wave.inter_wave_gap_seconds = inter_wave_gap
	wave.overtime_condition = overtime
	return wave


## A single spawn group of dummy enemies that never die (matching P2.8's own
## wave_sequence_test.gd convention): enough to keep `_all_own_spawned_dead_
## or_removed()` false for the whole test, so the wave can only end via the
## max-duration/stall path this suite is about, never natural completion.
func _make_encounter(id: String, recovery_gap: float = 8.0) -> EncounterDefinition:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = id + "_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = recovery_gap
	return encounter


# --- STALLED: kills below the threshold at maximum duration -----------------

func test_non_final_wave_stalls_into_overtime_when_kills_are_below_the_threshold() -> void:
	var w1: WaveDefinition = _make_wave("wr_stall_w1", 10.0, 5)
	var e1: EncounterDefinition = _make_encounter("wr_stall_w1")
	var w2: WaveDefinition = _make_wave("wr_stall_w2", 10.0, 5)
	var e2: EncounterDefinition = _make_encounter("wr_stall_w2")
	var ctx: Dictionary = _build_director([w1, w2], [e1, e2])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	_emit_kills(ctx["bus"], clock, 3) # below the threshold of 5
	_advance(director, clock, 10.5, 0.1) # crosses maximum_duration_seconds (10.0) with a generous margin -- _wave_open_time is captured on the FIRST physics_step() call, AFTER clock.now has already been incremented once by _advance()'s own loop, so the real boundary is slightly past 10.0, not exactly 10.0

	assert_bool(director.is_overtime_active_for_test()).append_failure_message("kills (3) were below the stall threshold (5); Overtime should have started").is_true()
	assert_str(director.get_state_name()).append_failure_message("a stalled wave must stay WAVE_ACTIVE (in Overtime), not transition to GAP").is_equal("WAVE_ACTIVE")
	assert_str(director.get_current_wave_id()).append_failure_message("Overtime must not silently advance to the next wave").is_equal("wr_stall_w1")


# --- NOT STALLED: kills meet the threshold; carry-over -----------------------

func test_non_final_wave_does_not_stall_and_survivors_carry_over_when_kills_meet_the_threshold() -> void:
	var w1: WaveDefinition = _make_wave("wr_nostall_w1", 10.0, 5)
	var e1: EncounterDefinition = _make_encounter("wr_nostall_w1")
	var w2: WaveDefinition = _make_wave("wr_nostall_w2", 10.0, 5)
	var e2: EncounterDefinition = _make_encounter("wr_nostall_w2")
	var ctx: Dictionary = _build_director([w1, w2], [e1, e2])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	_emit_kills(ctx["bus"], clock, 5) # meets the threshold exactly -- NOT stalled (the boundary case is overtime_test.gd's own job)
	_advance(director, clock, 10.5, 0.1) # see the margin note above

	assert_bool(director.is_overtime_active_for_test()).append_failure_message("kills (5) met the stall threshold (5); Overtime must not start").is_false()
	assert_str(director.get_state_name()).append_failure_message("a not-stalled wave at maximum duration must end (enter GAP, or open the next wave once the gap elapses)").is_not_equal("WAVE_ACTIVE")

	# Carry-over (Register: "Survivors carry over, count against the enemy
	# cap, not against the next wave's spawn budget"): the dummy enemy this
	# wave spawned and never killed must still be a live registry entry --
	# the NOT-STALLED path must never force-remove it.
	var live: Array[Node2D] = registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	assert_int(live.size()).append_failure_message("the wave's own surviving spawn was not carried over -- NOT-STALLED must never clear living enemies").is_equal(1)

	# The carried-over survivor must not count against wave 2's own spawn
	# list (Register: "not against the next wave's spawn budget") -- open
	# wave 2 and confirm its own tracked spawn count starts at 0, not 1.
	_advance(director, clock, w1.inter_wave_gap_seconds + 1.0, 0.1)
	assert_str(director.get_current_wave_id()).is_equal("wr_nostall_w2")


# --- Final wave never times out ----------------------------------------------

func test_final_wave_never_ends_on_maximum_duration_even_under_a_real_stall_condition() -> void:
	var w: WaveDefinition = _make_wave("wr_final", 2.0, 5) # deliberately tiny max duration
	var e: EncounterDefinition = _make_encounter("wr_final")
	var ctx: Dictionary = _build_director([w], [e]) # single wave -- index 0 is, by construction, the final wave
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	# Zero kills -- a real stall condition, deliberately, so this proves the
	# final wave does not "end" even while genuinely stalled; it enters
	# Overtime instead of timing out, matching C-FINAL's own "ends only when
	# the EntityRegistry live-enemy count is zero" (never on max duration,
	# stalled or not).
	_advance(director, clock, 3.0, 0.1) # past the 2.0 s maximum duration

	assert_str(director.get_state_name()).append_failure_message("the final wave ended on its maximum duration -- C-FINAL forbids this unconditionally").is_equal("WAVE_ACTIVE")
	assert_bool(director.is_overtime_active_for_test()).append_failure_message("a genuinely stalled final wave must enter Overtime, not silently end").is_true()

	# Now clear every living enemy (including whatever finishers Overtime
	# has spawned by now) and confirm the wave finally closes.
	var iterations: int = 0
	while registry.get_live_enemy_count() > 0 and iterations < 500:
		var live: Array[Node2D] = registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
		for entity in live:
			registry.deregister_entity(entity)
		clock.now += 0.1
		director.physics_step(0.1)
		iterations += 1

	assert_int(registry.get_live_enemy_count()).append_failure_message("test setup could not clear the field within the iteration budget").is_equal(0)
	assert_str(director.get_state_name()).append_failure_message("the final wave did not close once the live-enemy count reached zero, even in Overtime").is_equal("SEQUENCE_COMPLETE")


## Register > C-FINAL: "After its maximum duration the stall check re-runs
## every 0.5 seconds until Overtime starts" -- DISTINCT from the non-final
## rule ("the stall check runs once"). Proven by a case the non-final rule
## could never pass: kills are SUFFICIENT the instant maximum duration is
## first reached (so the FIRST check says NOT STALLED, same as a non-final
## wave would), then the 30 s kill window is left to drain completely with
## no further kills -- only a check that keeps RE-RUNNING can ever notice
## that and start Overtime; a check that ran once and was done (the
## non-final behaviour) would stay NOT-STALLED forever.
func test_final_wave_stall_check_keeps_re_running_after_maximum_duration() -> void:
	var w: WaveDefinition = _make_wave("wr_final_recheck", 2.0, 5)
	var e: EncounterDefinition = _make_encounter("wr_final_recheck")
	var ctx: Dictionary = _build_director([w], [e])
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	_emit_kills(ctx["bus"], clock, 5) # sufficient -- the FIRST check (at maximum duration) must say NOT STALLED
	_advance(director, clock, 2.5, 0.1) # margin against the "boundary is slightly past maximum_duration_seconds" note above
	assert_bool(director.is_overtime_active_for_test()).append_failure_message("test setup: the first stall check should not have stalled with 5 recent kills").is_false()

	_advance(director, clock, 31.0, 0.1) # drain the 30 s kill window completely, with zero further kills
	assert_bool(director.is_overtime_active_for_test()).append_failure_message("Register C-FINAL: the stall check must keep re-running every 0.5 s after maximum duration -- once the kill window empties out, a LATER re-check must still catch it and start Overtime").is_true()

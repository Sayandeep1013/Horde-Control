extends GdUnitTestSuite

## Encounter recovery test (P2.8b named acceptance test; MASTER_SDLC.md >
## Acceptance Test Matrix > Encounter Tests > "Encounter recovery test":
## "P2.8 result over 10 of 10 scripted double-schedules (priority open,
## deferred recovery gap)"). docs/11_Wave_Director.md > "Wave Runtime
## Model": "When two encounters are due at the same moment, the
## higher-priority one opens and the lower-priority one waits until the
## higher-priority one completes plus its recovery gap." MASTER_SDLC.md >
## Provisional Values Register > Spawning & Waves > "Priorities & recovery
## gaps".
##
## Deliberately built against SCRIPTED double-schedules (per this task's
## own brief), not the real 8-wave prototype: every prototype wave carries
## exactly one encounter (P2.8 report), so two encounters are never due at
## once in real data -- this mechanism (src/director/wave_director.gd's
## `_build_priority_sorted_encounter_queue()` / `_wave_encounter_position` /
## `_encounter_gap_deadline`) is otherwise completely unexercised by any
## other suite in this project.

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


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free()
	return packed


func _build_director() -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = 555
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director}


func _advance(director: WaveDirector, clock: Node, seconds: float, step: float = 0.05) -> void:
	var steps: int = int(round(seconds / step))
	for _i in steps:
		clock.now += step
		director.physics_step(step)


func _make_encounter(id: String, priority: int, recovery_gap: float) -> EncounterDefinition:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = id
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = recovery_gap
	encounter.priority = priority
	return encounter


## Kills whatever THIS encounter's own single spawn is (deregistering
## directly, matching wave_sequence_test.gd's own "nothing fights on its
## own" convention -- identical effect on EntityRegistry to a real death for
## completion-check purposes).
func _kill_the_one_live_enemy(registry: Node) -> void:
	var live: Array[Node2D] = registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	assert_int(live.size()).append_failure_message("test setup: expected exactly one live enemy to kill").is_equal(1)
	registry.deregister_entity(live[0])


## Runs one double-schedule scenario end to end: two encounters, both named
## in the SAME wave's `encounter_sequence` (both "due" the instant the wave
## opens), with the given priorities and the HIGH-priority encounter's own
## recovery gap. Returns the observed facts the caller asserts against, so
## failure messages can name which of the 10 scenarios broke.
func _run_double_schedule(scenario: String, high_priority: int, low_priority: int, high_recovery_gap: float) -> void:
	var high: EncounterDefinition = _make_encounter("%s_high" % scenario, high_priority, high_recovery_gap)
	var low: EncounterDefinition = _make_encounter("%s_low" % scenario, low_priority, 1.0)

	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "%s_wave" % scenario
	wave.encounter_sequence = [low.unique_id, high.unique_id] # authored in the "wrong" order deliberately -- priority, not authoring order, must decide
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	# A trivial second (never-reached) wave: wave_director.gd detects "the
	# final wave" (C-FINAL: "ends only when the EntityRegistry live-enemy
	# count is zero", an entirely different ending rule from the ordinary
	# encounter-completion one this test is about) STRUCTURALLY, as the last
	# element of `waves` -- with only ONE wave, this double-schedule's own
	# wave would incorrectly BE that final wave, and the high encounter's
	# completion (which, with the low encounter not yet spawned, briefly
	# leaves the live-enemy count at zero) would end the WHOLE wave via
	# C-FINAL instead of deferring to the low-priority encounter. A second
	# wave keeps this one honestly non-final, exactly like
	# wave_runtime_test.gd's own non-final scenarios.
	var filler_group: SpawnGroup = SpawnGroup.new()
	filler_group.enemy_definition_id = "tower_seeker"
	filler_group.count = 1
	filler_group.start_offset_seconds = 0.0
	filler_group.spawn_interval_seconds = 1.0
	var filler_encounter: EncounterDefinition = EncounterDefinition.new()
	filler_encounter.unique_id = "%s_filler_encounter" % scenario
	filler_encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	filler_encounter.spawn_groups = [filler_group]
	filler_encounter.minimum_recovery_gap_seconds = 1.0
	var filler_wave: WaveDefinition = WaveDefinition.new()
	filler_wave.unique_id = "%s_filler_wave" % scenario
	filler_wave.encounter_sequence = [filler_encounter.unique_id]
	filler_wave.maximum_duration_seconds = 1000.0
	filler_wave.has_maximum_duration = true
	filler_wave.inter_wave_gap_seconds = 8.0

	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	director.waves = [wave, filler_wave]
	director.encounter_definitions = [low, high, filler_encounter]
	director.rebuild_lookups_for_test()

	# Both encounters are due the instant the wave opens; the queue is
	# resolved once, at open, so a single tick is enough to observe which
	# one is CURRENT.
	_advance(director, clock, 0.05, 0.05)
	assert_str(director.get_current_encounter_id_for_test()).append_failure_message("[%s] the higher-priority encounter (%d) did not open first; the lower one (%d) or something else did" % [scenario, high_priority, low_priority]).is_equal(high.unique_id)

	# Complete the high-priority encounter and confirm the low-priority one
	# is DEFERRED, not opened immediately.
	_kill_the_one_live_enemy(registry)
	_advance(director, clock, 0.05, 0.05)
	assert_str(director.get_current_encounter_id_for_test()).append_failure_message("[%s] the lower-priority encounter opened the instant the higher-priority one completed -- the recovery gap was not honoured" % scenario).is_not_equal(low.unique_id)

	# Still short of the gap: the low-priority encounter must still be
	# withheld.
	if high_recovery_gap > 0.2:
		_advance(director, clock, high_recovery_gap - 0.1, 0.05)
		assert_str(director.get_current_encounter_id_for_test()).append_failure_message("[%s] the low-priority encounter opened before its %.2fs deferred recovery gap elapsed" % [scenario, high_recovery_gap]).is_not_equal(low.unique_id)
		_advance(director, clock, 0.2, 0.05)
	else:
		_advance(director, clock, high_recovery_gap + 0.1, 0.05)

	# Past the gap: the low-priority encounter must now be open.
	assert_str(director.get_current_encounter_id_for_test()).append_failure_message("[%s] the low-priority encounter did not open once its deferred recovery gap elapsed" % scenario).is_equal(low.unique_id)


## 10 of 10 scripted double-schedules, varying priority separation (large,
## small, and a genuine TIE broken by Unique ID ascending -- Encounter
## Definition Contract's own documented tie rule) and the deferring
## encounter's own recovery gap (Siege 10s, Split Assault 8s, Hunt 8s,
## Standard Assault 5s per the Register's "Priorities & recovery gaps" row,
## plus a couple of arbitrary scripted values to prove this is not
## special-cased to the four canonical ones).
func test_ten_of_ten_scripted_double_schedules_open_by_priority_and_defer_by_recovery_gap() -> void:
	var scenarios: Array = [
		{"name": "siege_vs_standard", "high": 80, "low": 20, "gap": 10.0},
		{"name": "split_vs_hunt", "high": 60, "low": 40, "gap": 8.0},
		{"name": "hunt_vs_standard", "high": 40, "low": 20, "gap": 8.0},
		{"name": "siege_vs_split", "high": 80, "low": 60, "gap": 10.0},
		{"name": "siege_vs_hunt", "high": 80, "low": 40, "gap": 10.0},
		{"name": "wide_separation", "high": 100, "low": 0, "gap": 5.0},
		{"name": "narrow_separation", "high": 51, "low": 50, "gap": 6.0},
		{"name": "small_gap", "high": 33, "low": 10, "gap": 1.0},
		{"name": "large_gap", "high": 90, "low": 5, "gap": 15.0},
		{"name": "tie_broken_by_unique_id", "high": 50, "low": 50, "gap": 8.0}, # equal priority -- ties broken by Unique ID ascending; "..._high" < "..._low" alphabetically, so "_high" is expected to win the tie
	]
	assert_int(scenarios.size()).is_equal(10)
	for s in scenarios:
		_run_double_schedule(s["name"], s["high"], s["low"], s["gap"])


## Discovered while writing the suite above (first version of this test used
## a single-wave director, making that wave structurally "final" by
## wave_director.gd's own detection -- Register > C-FINAL: "ends only when
## the EntityRegistry live-enemy count is zero"): the moment the
## higher-priority encounter's own last enemy dies, the live-enemy count
## reads zero for an instant BEFORE the lower-priority encounter has spawned
## anything -- and a naive C-FINAL check would read that as "the run is
## over" and skip the deferred encounter entirely. `_evaluate_wave_state()`
## was fixed (this task) to also check whether another encounter is still
## queued before letting a final wave's live-count-zero moment end the whole
## wave. This test pins that fix directly, on a GENUINELY final wave (a
## single-wave director), rather than only through the filler-wave
## workaround `_run_double_schedule()` uses to isolate the ordinary
## (non-final) case.
func test_a_genuinely_final_wave_defers_to_a_queued_encounter_instead_of_ending_early() -> void:
	var high: EncounterDefinition = _make_encounter("cfinal_multi_high", 80, 3.0)
	var low: EncounterDefinition = _make_encounter("cfinal_multi_low", 20, 1.0)
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "cfinal_multi_wave"
	wave.encounter_sequence = [low.unique_id, high.unique_id]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	director.waves = [wave] # a single wave -- genuinely final, unlike _run_double_schedule()'s own two-wave fixture
	director.encounter_definitions = [low, high]
	director.rebuild_lookups_for_test()

	_advance(director, clock, 0.05, 0.05)
	assert_str(director.get_current_encounter_id_for_test()).is_equal(high.unique_id)

	_kill_the_one_live_enemy(registry)
	_advance(director, clock, 0.05, 0.05)
	# The live-enemy count is genuinely zero right here (high's enemy just
	# died, low has not spawned yet) -- the sequence must NOT report done.
	assert_int(registry.get_live_enemy_count()).is_equal(0)
	assert_str(director.get_state_name()).append_failure_message("a final wave ended the instant live count hit zero, even though a lower-priority encounter was still queued behind its recovery gap").is_equal("WAVE_ACTIVE")

	_advance(director, clock, 3.2, 0.05) # cross high's 3.0 s recovery gap
	assert_str(director.get_current_encounter_id_for_test()).append_failure_message("the queued low-priority encounter never opened on a genuinely final wave").is_equal(low.unique_id)
	assert_str(director.get_state_name()).append_failure_message("the sequence completed even though the deferred low-priority encounter's own enemy is still alive").is_equal("WAVE_ACTIVE")

	# Now clear the low encounter's own enemy too -- only NOW should the
	# sequence actually complete.
	_kill_the_one_live_enemy(registry)
	_advance(director, clock, 0.05, 0.05)
	assert_str(director.get_state_name()).append_failure_message("the sequence did not complete once every queued encounter's enemies were gone").is_equal("SEQUENCE_COMPLETE")

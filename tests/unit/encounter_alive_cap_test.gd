extends GdUnitTestSuite

## Encounter-level alive cap (P2.8b, deferral item 8 named in
## phases/PHASE_03_.../evidence/p28_report.md: "The encounter-level alive
## cap (`combat_4_siege.tres`'s `encounter_alive_cap = 120`) ... not
## separately enforced -- only the global 300-enemy cap ... throttles
## spawning"). docs/11_Wave_Director.md > "Wave Runtime Model": "An
## encounter may also declare its own alive cap ... which counts all living
## enemies, not just its own spawns, and throttles spawning exactly like the
## global entity cap." MASTER_SDLC.md > Provisional Values Register >
## Spawning & Waves > "Encounter-level alive cap".
##
## tests/unit/overtime_test.gd's own
## `test_finishers_are_throttled_by_the_same_alive_cap_as_an_ordinary_spawn`
## proves the SAME mechanism gates FINISHER spawning; this suite proves it
## for an ORDINARY spawn group, and specifically that it counts ALL living
## enemies (including ones spawned by a DIFFERENT source), not only the
## encounter's own.

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
	director.run_seed = 123
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director}


func _advance(director: WaveDirector, clock: Node, seconds: float, step: float = 0.1) -> void:
	var steps: int = int(round(seconds / step))
	for _i in steps:
		clock.now += step
		director.physics_step(step)


## A single encounter with a group of 5 Seekers (interval 0.5 s, so all 5
## would ordinarily emit within 2.5 s) but an alive cap of 2 -- if the cap
## is enforced, at most 2 may ever be alive/emitted; if it is NOT (P2.8's
## own original gap this task closes), all 5 land, since none of them ever
## die to make room and the global 300 cap is nowhere near reached.
func test_an_ordinary_spawn_group_is_throttled_by_the_encounters_own_alive_cap() -> void:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 5
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 0.5
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "cap_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 5.0
	encounter.encounter_alive_cap = 2

	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "cap_wave"
	wave.encounter_sequence = ["cap_encounter"]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.rebuild_lookups_for_test()

	_advance(director, clock, 10.0, 0.1) # well past the whole group's own 2.5 s schedule

	assert_int(registry.get_live_enemy_count()).append_failure_message("the encounter's own alive cap (2) was exceeded -- Register: 'throttles spawning exactly like the global entity cap'").is_less_equal(2)
	assert_int(director.get_emitted_count_for_test(0)).append_failure_message("all 5 of the group's spawns emitted despite an alive cap of 2 -- the cap did not throttle at all").is_less(5)


## Register: "counts all living enemies, not just its own spawns" -- an
## enemy from an UNRELATED source (here, simply pre-registered directly with
## EntityRegistry, standing in for "some other encounter's carried-over
## survivor") must count against the cap too.
func test_the_alive_cap_counts_every_living_enemy_not_only_this_encounters_own() -> void:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "cap_foreign_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 5.0
	encounter.encounter_alive_cap = 1 # already met by a foreign enemy below

	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "cap_foreign_wave"
	wave.encounter_sequence = ["cap_foreign_encounter"]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var registry: Node = ctx["registry"]

	# A "foreign" enemy the cap must still count -- registered directly, not
	# spawned by this encounter, matching "carried-over survivor" or "a
	# sibling encounter's own spawn" in shape (this director never
	# distinguishes source; only EntityRegistry's own live count matters).
	var foreign: Node2D = auto_free(Node2D.new())
	add_child(foreign)
	registry.register_entity(foreign, Vector2.ZERO, [&"enemy"])

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.rebuild_lookups_for_test()

	_advance(director, clock, 3.0, 0.1)

	assert_int(director.get_emitted_count_for_test(0)).append_failure_message("the encounter's own group emitted despite the cap already being met by a foreign (non-own) enemy").is_equal(0)

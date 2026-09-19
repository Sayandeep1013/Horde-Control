extends GdUnitTestSuite

## Determinism check (P2.8 task brief: "a determinism check that the same
## seed produces the same spawn positions"). MASTER_SDLC.md > Provisional
## Values Register > "Keyed RNG": "spawn position = hash([run_seed, "spawn",
## spawn_serial])"; > Acceptance Test Matrix > "Determinism test": "With the
## same run seed ... produces identical results in 10 of 10 repetitions."
##
## Two independent WaveDirector pipelines (separate EntityRegistry,
## SimClock, EntitySpawner instances -- nothing shared) driven through an
## identical tick sequence. Same run_seed must produce byte-identical
## spawn positions in the same order; a different run_seed must produce at
## least one different position, so the check can fail (a director that
## ignored run_seed entirely, or one whose "randomness" secretly depended on
## engine RNG state, would pass the first assertion trivially and only the
## second assertion would catch it).

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

const TICK_STEP: float = 0.5
const TICK_COUNT: int = 60 # 30 simulated seconds -- enough for every group in the scenario below to fully emit


var _spawners: Array[Node] = [] # every EntitySpawner _build_pipeline() creates, freed in after_test()


## Pool-acquired dummy enemy instances are never parented (no pool
## container is wired here) and are not tracked by `auto_free()`, so they
## orphan at test teardown unless released -- matching tests/unit/
## entity_cap_test.gd's own `after_test()` pattern.
func after_test() -> void:
	for spawner in _spawners:
		if spawner != null:
			spawner.clear_all_for_test()


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free() # pack() copies the subtree into the resource; it does not take ownership of `n` itself, which would otherwise orphan
	return packed


## A deliberately varied scenario -- Siege (uniform Tower ring), Split
## Assault (lane-biased Tower ring), and Hunt (arc-biased view ring) all in
## one wave's encounter sequence's worth of groups, so the determinism
## check exercises every directional-weighting branch, not just the
## uniform case.
func _build_pipeline(run_seed: int) -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = run_seed
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)
	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	var camera: Node2D = auto_free(Node2D.new())
	add_child(camera)
	camera.global_position = Vector2(700.0, 0.0) # see spawn_ring_test.gd for why this offset is safe
	director.set_camera_reference(camera)

	var siege_group: SpawnGroup = SpawnGroup.new()
	siege_group.enemy_definition_id = "tower_seeker"
	siege_group.count = 6
	siege_group.start_offset_seconds = 0.0
	siege_group.spawn_interval_seconds = 1.0
	var siege: EncounterDefinition = EncounterDefinition.new()
	siege.unique_id = "det_test_siege"
	siege.encounter_type = ContractEnums.EncounterType.Siege
	siege.spawn_groups = [siege_group]
	siege.minimum_recovery_gap_seconds = 10.0
	var wave_siege: WaveDefinition = WaveDefinition.new()
	wave_siege.unique_id = "det_test_wave_siege"
	wave_siege.encounter_sequence = ["det_test_siege"]
	wave_siege.maximum_duration_seconds = 1000.0
	wave_siege.has_maximum_duration = true
	wave_siege.inter_wave_gap_seconds = 8.0

	var split_group: SpawnGroup = SpawnGroup.new()
	split_group.enemy_definition_id = "opportunist"
	split_group.count = 6
	split_group.start_offset_seconds = 0.0
	split_group.spawn_interval_seconds = 1.0
	var split: EncounterDefinition = EncounterDefinition.new()
	split.unique_id = "det_test_split"
	split.encounter_type = ContractEnums.EncounterType.SplitAssault
	split.spawn_groups = [split_group]
	split.minimum_recovery_gap_seconds = 8.0
	var wave_split: WaveDefinition = WaveDefinition.new()
	wave_split.unique_id = "det_test_wave_split"
	wave_split.encounter_sequence = ["det_test_split"]
	wave_split.maximum_duration_seconds = 1000.0
	wave_split.has_maximum_duration = true
	wave_split.inter_wave_gap_seconds = 8.0

	var hunt_group: SpawnGroup = SpawnGroup.new()
	hunt_group.enemy_definition_id = "player_hunter"
	hunt_group.count = 6
	hunt_group.start_offset_seconds = 0.0
	hunt_group.spawn_interval_seconds = 1.0
	var hunt: EncounterDefinition = EncounterDefinition.new()
	hunt.unique_id = "det_test_hunt"
	hunt.encounter_type = ContractEnums.EncounterType.Hunt
	hunt.spawn_groups = [hunt_group]
	hunt.minimum_recovery_gap_seconds = 8.0
	var wave_hunt: WaveDefinition = WaveDefinition.new()
	wave_hunt.unique_id = "det_test_wave_hunt"
	wave_hunt.encounter_sequence = ["det_test_hunt"]
	wave_hunt.maximum_duration_seconds = 1000.0
	wave_hunt.has_maximum_duration = true
	wave_hunt.inter_wave_gap_seconds = 8.0

	director.waves = [wave_siege, wave_split, wave_hunt]
	director.encounter_definitions = [siege, split, hunt]
	director.rebuild_lookups_for_test()

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director, "camera": camera}


## Runs one pipeline for TICK_COUNT ticks (only the Siege wave's 6 spawns
## will land in this window -- see header, "30 simulated seconds") and
## returns the recorded spawn positions in emission order.
func _run_and_record(run_seed: int) -> Array:
	var ctx: Dictionary = _build_pipeline(run_seed)
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]
	var positions: Array = []
	director.enemy_spawned.connect(func(_i: Node2D, _id: String, position: Vector2) -> void: positions.append(position))
	for _i in TICK_COUNT:
		clock.now += TICK_STEP
		director.physics_step(TICK_STEP)
	return positions


func test_same_seed_produces_identical_spawn_positions_in_order() -> void:
	var positions_a: Array = _run_and_record(2026)
	var positions_b: Array = _run_and_record(2026)

	assert_int(positions_a.size()).append_failure_message("test setup invalid: no spawns were recorded at all").is_greater(0)
	assert_int(positions_b.size()).append_failure_message("run B produced a different number of spawns (%d) than run A (%d) for the SAME seed" % [positions_b.size(), positions_a.size()]).is_equal(positions_a.size())

	for i in positions_a.size():
		var a: Vector2 = positions_a[i]
		var b: Vector2 = positions_b[i]
		assert_vector(b).append_failure_message("spawn #%d differs between two runs of the SAME seed: run A=%s, run B=%s" % [i, a, b]).is_equal_approx(a, Vector2(0.001, 0.001))


## Falsification-style check, per this project's own rule that a check must
## be able to fail: if the director secretly ignored run_seed (or drew from
## Godot's own unseeded global RNG instead of KeyedRng), the test above
## would pass VACUOUSLY -- two runs would "agree" regardless of seed. A
## different seed must change at least one position.
func test_a_different_seed_changes_at_least_one_spawn_position() -> void:
	var positions_a: Array = _run_and_record(2026)
	var positions_c: Array = _run_and_record(999999)

	assert_int(positions_c.size()).is_equal(positions_a.size())
	var any_different: bool = false
	for i in positions_a.size():
		var a: Vector2 = positions_a[i]
		var c: Vector2 = positions_c[i]
		if not a.is_equal_approx(c):
			any_different = true
			break
	assert_bool(any_different).append_failure_message("every spawn position was identical across two DIFFERENT seeds -- run_seed is not actually influencing spawn placement, which means the first test's 'determinism' is vacuous").is_true()

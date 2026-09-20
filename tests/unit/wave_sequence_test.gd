extends GdUnitTestSuite

## Wave runtime suite (P2.8 task brief: "a wave-runtime suite covering the
## sequence advancing T1->T4->combat 1-4 with the right gaps").
## docs/11_Wave_Director.md > "Wave Runtime Model"; MASTER_SDLC.md >
## Provisional Values Register > Spawning & Waves > "Inter-wave gap",
## "Final combat wave rule (C-FINAL)".
##
## Runs against the REAL, preloaded 8-wave prototype sequence
## (src/director/wave_director.gd's own default `waves`/
## `encounter_definitions` exports), not a throwaway scenario -- this suite
## exists specifically to prove THAT sequence, with its authored durations
## and gaps, actually advances correctly end to end. A lightweight dummy
## PackedScene (a bare Node2D, no EnemyController) stands in for every
## enemy scene, so nothing fights or dies on its own.
##
## AMENDED 2026-09-20, when P2.8b built the stall check this suite predates.
## As first written, this suite let every non-final wave run to its MAXIMUM
## DURATION with nothing ever dying, relying on the NOT-STALLED branch that
## wave_director.gd took unconditionally while Overtime was deferred. Once
## the real rule existed, a wave with zero kills at its maximum duration was
## correctly read as STALLED, the sequence entered Overtime at T1, and this
## suite failed.
##
## The failure was true and the suite was wrong: a wave in which nothing
## ever dies IS stalled, and that is the rule the Register states. The fix
## is therefore at the fixture, not at the rule - weakening the stall check
## so this suite could pass again would have produced the defect this
## project has recorded five times, a rule that cannot fire. The fixture now
## kills each spawned dummy KILL_DELAY_SECONDS after it spawns, the way a
## real wave's enemies die: waves complete naturally (every group emitted
## and every own-spawned enemy dead), the trailing kill window is non-empty,
## and the GAP arithmetic this suite exists to verify is measured from each
## wave's real end. See Phase 04 ledger finding F04-15.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")

## The prototype sequence's own wave IDs, in order (data/waves/*.tres).
const EXPECTED_WAVE_ORDER: Array[String] = ["wave_t1", "wave_t2", "wave_t3", "wave_t4", "wave_combat_1", "wave_combat_2", "wave_combat_3", "wave_combat_4"]

## Register > "Inter-wave gap": max(8 s default (5 s after T1, T2, T3), the
## closing encounter's own recovery gap). Encounter recovery gaps: Standard
## Assault 5 s (T1, T2), Split Assault 8 s (T3), Siege 10 s (T4, combat 2),
## Hunt 8 s (combat 1), Split Assault 8 s (combat 3) -- see data/encounters/
## *.tres and MASTER_SDLC.md > Provisional Values Register > "Priorities &
## recovery gaps". The gap after combat_3 (index 6) is what precedes
## combat_4 opening; there is no gap after combat_4 in this task's scope.
const EXPECTED_GAPS_SECONDS: Array[float] = [5.0, 5.0, 8.0, 10.0, 8.0, 10.0, 8.0]

## How long a spawned dummy survives before this fixture kills it. Not a
## gameplay number and not a Register value: a test-fixture stand-in for
## combat resolution, long enough that a wave's later spawn groups still
## emit while its earlier enemies die, and short enough that the trailing
## 30 s kill window never empties mid-wave.
const KILL_DELAY_SECONDS: float = 2.0

const STEP: float = 0.25
const MAX_ITERATIONS: int = 2400 # >> (439s total sequenced time) / STEP, with margin

var _registry: Node
var _clock: Node
var _spawner: Node
var _director: WaveDirector

## [{instance, spawned_at}] for dummies this fixture has yet to kill.
var _pending_kills: Array = []


func before_test() -> void:
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

	var dummy: PackedScene = _build_dummy_scene()
	_director.tower_seeker_scene = dummy
	_director.player_hunter_scene = dummy
	_director.opportunist_scene = dummy
	# _ready() already ran (via add_child() above) and snapshotted the enemy
	# lookup while these three exports were still null -- rebuild it now
	# that they are assigned, matching wave_director.gd's own documented
	# seam for exactly this ordering (set exports, then rebuild).
	_director.rebuild_lookups_for_test()

	# Every spawned dummy is queued for a delayed kill (KILL_DELAY_SECONDS).
	# Connected here rather than per test so any scenario that steps the real
	# sequence gets enemies that actually die; tests building their own
	# throwaway waves simply never call _kill_due().
	_director.enemy_spawned.connect(func(instance: Node2D, _id: String, _p: Vector2) -> void:
		_pending_kills.append({"instance": instance, "spawned_at": _clock.now}))


## Pool-acquired dummy enemy instances are never parented (no pool
## container is wired here) and are not tracked by `auto_free()`, so they
## orphan at test teardown unless released -- matching tests/unit/
## entity_cap_test.gd's own `after_test()` pattern. This suite spawns up to
## ~207 of them (the full 8-wave sequence, nothing ever dies), so this
## matters more here than anywhere else in this task's suites.
func after_test() -> void:
	if _spawner != null:
		_spawner.clear_all_for_test()


func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free() # pack() copies the subtree into the resource; it does not take ownership of `n` itself, which would otherwise orphan
	return packed


## Kills every dummy that has outlived KILL_DELAY_SECONDS: despawns it
## through the real EntitySpawner (which deregisters it, so the director's
## own `_all_own_spawned_dead_or_removed()` registry query sees it gone) and
## emits the real `EventBus.enemy_died`, which is what the stall check
## counts. Both halves matter: deregistering alone would end waves while the
## kill window stayed empty, and emitting alone would leave enemies alive.
func _kill_due() -> void:
	var now: float = _clock.now
	var still_pending: Array = []
	for entry in _pending_kills:
		var instance: Node2D = entry["instance"]
		if not is_instance_valid(instance):
			continue
		if now - float(entry["spawned_at"]) < KILL_DELAY_SECONDS:
			still_pending.append(entry)
			continue
		var position: Vector2 = instance.global_position
		_spawner.despawn_enemy(instance)
		EventBus.emit_enemy_died(instance, position)
	_pending_kills = still_pending


func test_sequence_advances_t1_through_combat_4_in_order_with_the_correct_gaps() -> void:
	var opened: Array = []
	var ended: Array = []
	_director.wave_opened.connect(func(wave_id: String, _idx: int) -> void: opened.append({"id": wave_id, "t": _clock.now}))
	_director.wave_ended.connect(func(wave_id: String, _idx: int) -> void: ended.append({"id": wave_id, "t": _clock.now}))

	var iterations: int = 0
	while _director.get_current_wave_index_for_test() < EXPECTED_WAVE_ORDER.size() - 1 and iterations < MAX_ITERATIONS:
		_clock.now += STEP
		_director.physics_step(STEP)
		_kill_due()
		iterations += 1

	assert_int(iterations).append_failure_message("hit the safety iteration cap (%d) before combat_4 ever opened -- the sequence stalled somewhere before the end" % MAX_ITERATIONS).is_less(MAX_ITERATIONS)

	var opened_ids: Array = opened.map(func(e: Dictionary) -> String: return e["id"])
	assert_array(opened_ids).append_failure_message("wave open order was %s, expected %s" % [opened_ids, EXPECTED_WAVE_ORDER]).is_equal(EXPECTED_WAVE_ORDER)

	assert_int(ended.size()).append_failure_message("expected the first 7 waves to have ended by the time combat_4 opened (combat_4 itself must still be open, not ended)").is_equal(7)

	for i in EXPECTED_GAPS_SECONDS.size():
		var wave_end_time: float = ended[i]["t"]
		var next_open_time: float = opened[i + 1]["t"]
		var actual_gap: float = next_open_time - wave_end_time
		assert_float(actual_gap).append_failure_message("gap after %s was %.3f s, expected %.1f s" % [EXPECTED_WAVE_ORDER[i], actual_gap, EXPECTED_GAPS_SECONDS[i]]).is_equal_approx(EXPECTED_GAPS_SECONDS[i], STEP * 3.0)


## Register > "No spawn group starts during a gap." Built as its own
## throwaway two-wave scenario (not the real 8-wave sequence) so the first
## wave's own single enemy can be killed immediately, isolating the GAP
## window from the 90+ second waits the real sequence's own waves require.
func test_no_spawn_group_starts_during_the_inter_wave_gap() -> void:
	var group1: SpawnGroup = SpawnGroup.new()
	group1.enemy_definition_id = "tower_seeker"
	group1.count = 1
	group1.start_offset_seconds = 0.0
	group1.spawn_interval_seconds = 1.0
	var encounter1: EncounterDefinition = EncounterDefinition.new()
	encounter1.unique_id = "gap_test_encounter_1"
	encounter1.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter1.spawn_groups = [group1]
	encounter1.minimum_recovery_gap_seconds = 6.0
	var wave1: WaveDefinition = WaveDefinition.new()
	wave1.unique_id = "gap_test_wave_1"
	wave1.encounter_sequence = ["gap_test_encounter_1"]
	wave1.maximum_duration_seconds = 1000.0
	wave1.has_maximum_duration = true
	wave1.inter_wave_gap_seconds = 6.0

	var group2: SpawnGroup = SpawnGroup.new()
	group2.enemy_definition_id = "tower_seeker"
	group2.count = 1
	group2.start_offset_seconds = 0.0
	group2.spawn_interval_seconds = 1.0
	var encounter2: EncounterDefinition = EncounterDefinition.new()
	encounter2.unique_id = "gap_test_encounter_2"
	encounter2.encounter_type = ContractEnums.EncounterType.StandardAssault
	encounter2.spawn_groups = [group2]
	encounter2.minimum_recovery_gap_seconds = 6.0
	var wave2: WaveDefinition = WaveDefinition.new()
	wave2.unique_id = "gap_test_wave_2"
	wave2.encounter_sequence = ["gap_test_encounter_2"]
	wave2.maximum_duration_seconds = 1000.0
	wave2.has_maximum_duration = true
	wave2.inter_wave_gap_seconds = 6.0

	_director.waves = [wave1, wave2]
	_director.encounter_definitions = [encounter1, encounter2]
	_director.rebuild_lookups_for_test()

	# `get_spawned_count_for_test()` reflects the CURRENT wave's own spawn
	# list, which is not cleared until the NEXT wave actually opens -- so it
	# stays at wave 1's count (1) for the whole gap, not 0. A running total
	# across the `enemy_spawned` signal is what actually proves "nothing new
	# spawned during the gap". Wrapped in a one-element Array rather than a
	# bare int: GDScript lambdas capture an outer local by VALUE, so
	# `total_spawns += 1` inside the closure below would silently mutate an
	# unconnected copy if `total_spawns` were a plain int -- an Array (or
	# any Object) is captured by reference, so `.append()`/index-assignment
	# is visible to the rest of this test function.
	var total_spawns: Array = [0]
	_director.enemy_spawned.connect(func(_i: Node2D, _id: String, _p: Vector2) -> void: total_spawns[0] += 1)

	# Open wave 1 and let its one spawn land.
	_clock.now += 0.1
	_director.physics_step(0.1)
	assert_int(_director.get_spawned_count_for_test()).append_failure_message("wave 1's own spawn did not land").is_equal(1)
	assert_int(total_spawns[0]).is_equal(1)

	# Kill it (deregistering directly, matching this suite's "nothing fights
	# on its own" convention -- the effect on EntityRegistry is identical to
	# a real despawn for the purposes of the completion check under test).
	var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	assert_int(live.size()).is_equal(1)
	_registry.deregister_entity(live[0])

	# One more tick: wave 1's encounter is now complete (group emitted, no
	# live spawns of its own), so it must enter the GAP state.
	_clock.now += 0.1
	_director.physics_step(0.1)
	assert_str(_director.get_state_name()).append_failure_message("wave 1 did not enter the GAP state once its encounter completed").is_equal("GAP")

	# Advance through most of the 6 s gap -- no spawn group may start yet.
	for _i in 50: # 5.0 s at 0.1 s steps
		_clock.now += 0.1
		_director.physics_step(0.1)
	assert_str(_director.get_state_name()).append_failure_message("gap ended too early").is_equal("GAP")
	assert_int(total_spawns[0]).append_failure_message("a spawn group started DURING the inter-wave gap -- the Register forbids this unconditionally").is_equal(1)

	# Cross the 6 s gap boundary -- wave 2 must now open and spawn.
	for _i in 15: # another 1.5 s, safely past the 6.0 s total
		_clock.now += 0.1
		_director.physics_step(0.1)
	assert_str(_director.get_current_wave_id()).append_failure_message("wave 2 did not open after its gap elapsed").is_equal("gap_test_wave_2")
	assert_int(_director.get_spawned_count_for_test()).append_failure_message("wave 2's own spawn did not land after the gap").is_equal(1)
	assert_int(total_spawns[0]).append_failure_message("expected exactly 2 spawns total across the whole test (1 per wave)").is_equal(2)


## Register > "Final combat wave rule (C-FINAL)": "Ends only when the
## EntityRegistry live-enemy count is zero" -- never on maximum duration.
## A throwaway single-wave scenario: index 0 is, by construction, the last
## element of `waves`, so wave_director.gd treats it as the final wave.
func test_final_wave_never_ends_on_maximum_duration_but_ends_when_live_count_reaches_zero() -> void:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "tower_seeker"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "final_test_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.Siege
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 10.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "final_test_wave"
	wave.encounter_sequence = ["final_test_encounter"]
	wave.maximum_duration_seconds = 1.0 # deliberately tiny -- proves C-FINAL ignores it
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	_director.waves = [wave]
	_director.encounter_definitions = [encounter]
	_director.rebuild_lookups_for_test()

	var completed: Array = [false] # see the gap test above for why a bare bool cannot be mutated from inside a connected lambda
	_director.sequence_completed.connect(func() -> void: completed[0] = true)

	# Run well past the 1.0 s maximum duration.
	for _i in 100: # 5.0 s at 0.05 s steps
		_clock.now += 0.05
		_director.physics_step(0.05)

	assert_str(_director.get_state_name()).append_failure_message("the final wave ended on its maximum duration -- C-FINAL forbids this").is_equal("WAVE_ACTIVE")
	assert_bool(completed[0]).append_failure_message("sequence_completed fired before the final wave's own enemy was gone").is_false()

	var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	assert_int(live.size()).append_failure_message("test setup invalid: the final wave's own spawn never landed").is_equal(1)
	_registry.deregister_entity(live[0])

	_clock.now += 0.05
	_director.physics_step(0.05)

	assert_str(_director.get_state_name()).append_failure_message("the final wave did not close once the live-enemy count reached zero").is_equal("SEQUENCE_COMPLETE")
	assert_bool(completed[0]).append_failure_message("sequence_completed did not fire").is_true()

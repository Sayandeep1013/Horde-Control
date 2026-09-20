extends GdUnitTestSuite

## Siege volume formula, computed (P2.8b, deferral item 6 named in
## phases/PHASE_03_.../evidence/p28_report.md: "the formula's own worked
## results (43/57 Seekers at x1.5/x2.0) are authored literals ...
## `SiegeVolumeConstants` is transcribed ... for a later phase that makes
## Siege size scale with live Tower DPS/upgrades"). MASTER_SDLC.md >
## Provisional Values Register > "Encounter Budgets" > "Siege volume
## formula": "Seeker count = ceil(multiplier x Tower DPS at Siege open
## (upgrades counted) x 0.75 x wave maximum duration / 60) ... Hunters =
## round(0.15 x Seeker count at Siege open)."
##
## Uses the REAL preloaded data/waves/combat_2.tres + data/encounters/
## combat_2_siege.tres (never mutated -- Resources are process-wide cached
## by preload() path, so mutating one in place would leak into every other
## suite that also preloads it) to prove: (1) at exactly base Tower DPS
## (this build's own actual current state -- no upgrade system wired), the
## AUTHORED LITERAL counts (43 Seekers / 7 Hunters) are used, byte-for-byte
## unchanged; (2) once a live Tower DPS provider reports something ABOVE
## base, the counts are recomputed live per the formula.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const CombatStatsScript: GDScript = preload("res://src/core/combat_stats.gd")

const CombatTwoWave: WaveDefinition = preload("res://data/waves/combat_2.tres")
const CombatTwoSiege: EncounterDefinition = preload("res://data/encounters/combat_2_siege.tres")
const TowerBaseWeapon: WeaponDefinition = preload("res://data/tower/base_weapon.tres")

var _spawners: Array[Node] = []


func before_test() -> void:
	_spawners.clear()


func after_test() -> void:
	for s in _spawners:
		if s != null:
			s.clear_all_for_test()


func _build_director() -> Dictionary:
	var registry: Node = auto_free(EntityRegistryScript.new())
	add_child(registry)
	var clock: Node = auto_free(SimClockScript.new())
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(registry)
	_spawners.append(spawner)
	var stats: Node = auto_free(CombatStatsScript.new())
	add_child(stats)

	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = 7
	add_child(director)
	director.set_registry_for_test(registry)
	director.set_sim_clock_for_test(clock)
	director.set_entity_spawner_for_test(spawner)
	director.set_combat_stats_for_test(stats)

	var dummy: PackedScene = _build_dummy_scene()
	director.tower_seeker_scene = dummy
	director.player_hunter_scene = dummy
	director.opportunist_scene = dummy

	return {"registry": registry, "clock": clock, "spawner": spawner, "director": director}


func _seeker_group_index(encounter: EncounterDefinition) -> int:
	for i in encounter.spawn_groups.size():
		if encounter.spawn_groups[i].enemy_definition_id == "tower_seeker":
			return i
	return -1


func _hunter_group_index(encounter: EncounterDefinition) -> int:
	for i in encounter.spawn_groups.size():
		if encounter.spawn_groups[i].enemy_definition_id == "player_hunter":
			return i
	return -1


## This suite only ever inspects `get_effective_group_count_for_test()`
## (computed at encounter-open time, before any actual spawning happens),
## but a single `physics_step()` call still runs `_process_spawn_groups()`
## the same tick, which would otherwise `push_error()` loudly (and trip the
## F02-14 engine-error guard) over unwired scenes -- a dummy PackedScene per
## enemy type, matching every other suite's own convention, silences that
## without this suite needing to care whether anything actually spawns.
func _build_dummy_scene() -> PackedScene:
	var packed: PackedScene = PackedScene.new()
	var n: Node2D = Node2D.new()
	n.name = "DummyEnemy"
	packed.pack(n)
	n.free()
	return packed


## At exactly base Tower DPS (the fallback CombatStats reports when nothing
## else has ever wired a provider or a live report -- this build's own real
## current state), the AUTHORED LITERAL counts from combat_2_siege.tres
## (43 Seekers / 7 Hunters) must be used unchanged.
func test_at_base_tower_dps_the_authored_literal_counts_are_used_unchanged() -> void:
	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	director.waves = [CombatTwoWave]
	director.encounter_definitions = [CombatTwoSiege]
	director.rebuild_lookups_for_test()

	clock.now += 0.05
	director.physics_step(0.05) # opens the wave/encounter -- _maybe_scale_siege_spawn_groups() runs here

	var seeker_i: int = _seeker_group_index(CombatTwoSiege)
	var hunter_i: int = _hunter_group_index(CombatTwoSiege)
	assert_int(director.get_effective_group_count_for_test(CombatTwoSiege, seeker_i)).append_failure_message("at base Tower DPS, the Seeker count must stay at the authored literal (43)").is_equal(43)
	assert_int(director.get_effective_group_count_for_test(CombatTwoSiege, hunter_i)).append_failure_message("at base Tower DPS, the Hunter count must stay at the authored literal (7)").is_equal(7)

	# The shared .tres Resource itself must never have been mutated (other
	# suites preload the SAME cached instance).
	assert_int(CombatTwoSiege.spawn_groups[seeker_i].count).is_equal(43)
	assert_int(CombatTwoSiege.spawn_groups[hunter_i].count).is_equal(7)


## Above base Tower DPS: recompute live per the formula. multiplier = 1.5
## (combat_2_siege's own entry in `siege_multiplier_by_encounter_id`),
## live DPS = 50.0 (double base), wave max duration = 90 s (combat_2.tres,
## read directly, not restated), window fraction 0.75, hunter percentage
## 0.15 (director_configuration.tres's own `siege_volume_constants`, read
## directly, not restated): Seekers = ceil(1.5*50*0.75*90/60) = ceil(84.375)
## = 85; Hunters = round(0.15*85) = round(12.75) = 13.
func test_above_base_tower_dps_the_formula_is_recomputed_live() -> void:
	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	director.set_tower_capacity_provider(func() -> float: return 50.0) # double the base 25 DPS
	director.waves = [CombatTwoWave]
	director.encounter_definitions = [CombatTwoSiege]
	director.rebuild_lookups_for_test()

	clock.now += 0.05
	director.physics_step(0.05)

	var seeker_i: int = _seeker_group_index(CombatTwoSiege)
	var hunter_i: int = _hunter_group_index(CombatTwoSiege)
	assert_int(director.get_effective_group_count_for_test(CombatTwoSiege, seeker_i)).append_failure_message("Seeker count did not scale to the formula's own result at 50 Tower DPS (expected 85)").is_equal(85)
	assert_int(director.get_effective_group_count_for_test(CombatTwoSiege, hunter_i)).append_failure_message("Hunter count did not scale to the formula's own result at 50 Tower DPS (expected 13)").is_equal(13)

	# Still never mutates the shared Resource.
	assert_int(CombatTwoSiege.spawn_groups[seeker_i].count).append_failure_message("the shared .tres Resource's own authored count was mutated -- this must go through _group_count_override only").is_equal(43)

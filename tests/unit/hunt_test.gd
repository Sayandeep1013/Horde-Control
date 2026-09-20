extends GdUnitTestSuite

## Hunt test (P2.8 named acceptance test, never built as its own dedicated
## suite -- phases/PHASE_03_.../evidence/p28_report.md, Deferred item 11).
## MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests > "Hunt test":
## "P2.8 result for every scripted Hunt (at least one landed hit; spawned
## mix matches the data-defined intent mix)". docs/11_Wave_Director.md >
## "Directional Weighting" > "Hunt"; MASTER_SDLC.md > Provisional Values
## Register > Spawning & Waves > "Encounter completion" (Hunt is one of the
## four encounter types whose objective IS full emission + all dead).
##
## Two parts, matching the acceptance criterion's own two clauses:
## 1. "spawned mix matches the data-defined intent mix" -- for every
##    scripted Hunt (the real combat_1_hunt.tres/combat_1.tres, PLUS two
##    additional generated Hunts with different ratios, so this is not
##    special-cased to the one real prototype encounter), the counts
##    spawned per Enemy ID match the encounter's OWN authored spawn groups
##    exactly (the wave's `enemy_intent_mix` field is deliberately
##    unauthored for every prototype wave -- see data/waves/t1.tres's own
##    comment -- so "the data-defined intent mix" is the encounter's spawn
##    groups themselves, not that field).
## 2. "at least one landed hit" -- a REAL Hunt-spawned Hunter (the actual
##    scenes/entities/player_hunter.tscn, not a dummy), self-driven, lands a
##    genuine Hitbox/Hurtbox contact hit on a fake player, matching
##    tests/unit/leash_test.gd's own established "real physics, instant
##    contact" fixture pattern.

const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const PlayerHunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")

const CombatOneWave: WaveDefinition = preload("res://data/waves/combat_1.tres")
const CombatOneHunt: EncounterDefinition = preload("res://data/encounters/combat_1_hunt.tres")

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
	director.run_seed = 4747
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


## Runs `encounter`/`wave` to full emission and asserts the spawned counts
## per Enemy ID exactly match the encounter's OWN authored spawn groups
## (summed by ID, since Hunt's own three Hunter groups in the real data
## share one ID across different start offsets).
func _assert_spawned_mix_matches_data(label: String, wave: WaveDefinition, encounter: EncounterDefinition) -> void:
	var expected_by_id: Dictionary = {}
	for group in encounter.spawn_groups:
		expected_by_id[group.enemy_definition_id] = int(expected_by_id.get(group.enemy_definition_id, 0)) + group.count
	var expected_total: int = 0
	for v in expected_by_id.values():
		expected_total += v

	var ctx: Dictionary = _build_director()
	var director: WaveDirector = ctx["director"]
	var clock: Node = ctx["clock"]

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.rebuild_lookups_for_test()

	var spawned_by_id: Dictionary = {}
	director.enemy_spawned.connect(func(_i: Node2D, id: String, _p: Vector2) -> void: spawned_by_id[id] = int(spawned_by_id.get(id, 0)) + 1)

	var iterations: int = 0
	var total_spawned: Callable = func() -> int:
		var t: int = 0
		for v in spawned_by_id.values():
			t += v
		return t
	while total_spawned.call() < expected_total and iterations < 4000:
		clock.now += 0.05
		director.physics_step(0.05)
		iterations += 1

	assert_int(total_spawned.call()).append_failure_message("[%s] only %d of %d expected spawns landed within the iteration budget" % [label, total_spawned.call(), expected_total]).is_equal(expected_total)
	for id in expected_by_id.keys():
		assert_int(int(spawned_by_id.get(id, 0))).append_failure_message("[%s] enemy id '%s': spawned %d, data-defined mix says %d" % [label, id, int(spawned_by_id.get(id, 0)), expected_by_id[id]]).is_equal(expected_by_id[id])


# --- Part 1: spawned mix matches the data-defined intent mix ----------------

func test_the_real_combat_1_hunt_spawns_exactly_its_own_data_defined_mix() -> void:
	# Register > Encounter Budgets > "Combat wave 1 Hunt": "Hunters 5 @0, 5
	# @15, 6 @30 s interval 0.5 s; Opportunists 4 @45 s" -- 16 Hunters + 4
	# Opportunists, summed here from the REAL encounter resource, not
	# restated as literals.
	_assert_spawned_mix_matches_data("combat_1_hunt (real)", CombatOneWave, CombatOneHunt)


func _make_generated_hunt(id: String, hunters: int, opportunists: int) -> Dictionary:
	var hunter_group: SpawnGroup = SpawnGroup.new()
	hunter_group.enemy_definition_id = "player_hunter"
	hunter_group.count = hunters
	hunter_group.start_offset_seconds = 0.0
	hunter_group.spawn_interval_seconds = 0.05
	var opp_group: SpawnGroup = SpawnGroup.new()
	opp_group.enemy_definition_id = "opportunist"
	opp_group.count = opportunists
	opp_group.start_offset_seconds = 0.5
	opp_group.spawn_interval_seconds = 0.05
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = id
	encounter.encounter_type = ContractEnums.EncounterType.Hunt
	encounter.spawn_groups = [hunter_group, opp_group]
	encounter.minimum_recovery_gap_seconds = 8.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = id + "_wave"
	wave.encounter_sequence = [id]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0
	return {"wave": wave, "encounter": encounter}


## Two additional GENERATED Hunts with different ratios, proving the mix
## check is not special-cased to the one real 80:20 (16:4) prototype
## encounter.
func test_generated_hunts_with_different_ratios_also_spawn_their_own_data_defined_mix() -> void:
	var scenarios: Array = [
		{"id": "hunt_gen_a", "hunters": 10, "opportunists": 2},
		{"id": "hunt_gen_b", "hunters": 3, "opportunists": 7},
	]
	for s in scenarios:
		var built: Dictionary = _make_generated_hunt(s["id"], s["hunters"], s["opportunists"])
		_assert_spawned_mix_matches_data(s["id"], built["wave"], built["encounter"])


# --- Part 2: at least one landed hit, via REAL combat plumbing --------------

## A Hunt-spawned Player Hunter (the real scene, self-driven) must be able
## to land a genuine contact hit -- proven the same way
## tests/unit/leash_test.gd's own "Mechanism 2" does: real Autoloads, a
## real Area2D overlap, the enemy and a fake player forced to the same
## position for an immediate, deterministic contact (this test is about
## combat capability existing at all for a Hunt spawn, not about travel/
## pursuit time, which src/enemy/enemy_controller.gd's own suites already
## cover).
func test_a_hunt_spawned_hunter_lands_a_real_hit_on_the_player() -> void:
	var group: SpawnGroup = SpawnGroup.new()
	group.enemy_definition_id = "player_hunter"
	group.count = 1
	group.start_offset_seconds = 0.0
	group.spawn_interval_seconds = 1.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.unique_id = "hunt_hit_encounter"
	encounter.encounter_type = ContractEnums.EncounterType.Hunt
	encounter.spawn_groups = [group]
	encounter.minimum_recovery_gap_seconds = 8.0
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "hunt_hit_wave"
	wave.encounter_sequence = ["hunt_hit_encounter"]
	wave.maximum_duration_seconds = 1000.0
	wave.has_maximum_duration = true
	wave.inter_wave_gap_seconds = 8.0

	# Real Autoloads for this sub-test (matching leash_test.gd's own
	# Mechanism 2): the director still needs its OWN registry/spawner so it
	# can be driven manually and cheaply, but the SPAWNED Hunter must
	# register itself with the REAL EntityRegistry so a fake player
	# registered there too can actually be found and hit.
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	director.run_seed = 99
	add_child(director)
	var clock: Node = auto_free(SimClockScript.new())
	director.set_sim_clock_for_test(clock)
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	_spawners.append(spawner)
	director.set_entity_spawner_for_test(spawner)
	# Deliberately NOT set_registry_for_test() here, on the director OR the
	# spawner -- the real
	# EntityRegistry autoload is what the spawned EnemyController itself
	# registers with (and what it queries for the player), so this
	# director must read/write the SAME registry.

	director.waves = [wave]
	director.encounter_definitions = [encounter]
	director.player_hunter_scene = PlayerHunterScene
	director.tower_seeker_scene = _build_dummy_scene()
	director.opportunist_scene = _build_dummy_scene()
	director.rebuild_lookups_for_test()

	var spawned: Array[Node2D] = []
	director.enemy_spawned.connect(func(instance: Node2D, _id: String, _p: Vector2) -> void: spawned.append(instance))

	clock.now += 0.1
	director.physics_step(0.1)
	assert_int(spawned.size()).append_failure_message("the Hunt's own Hunter never spawned").is_equal(1)
	var hunter: EnemyController = spawned[0] as EnemyController
	assert_object(hunter).append_failure_message("the spawned instance is not a real EnemyController").is_not_null()
	# EntitySpawner/Pool never add_child()s an acquired instance when no
	# pool container is wired (this director's own convention, matching
	# every other suite's) -- so _ready() has not run yet, and this
	# controller has neither registered with EntityRegistry nor built its
	# hitbox/hurtbox references. Parenting it here is an ordinary, valid
	# Godot lifecycle event (this test simply plays the part the real
	# scene's own pool container would), not a workaround.
	add_child(hunter)
	auto_free(hunter)

	var fake_player: Node2D = auto_free(Node2D.new())
	add_child(fake_player)
	var player_hurtbox: Hurtbox = Hurtbox.new()
	player_hurtbox.faction = Hurtbox.Faction.PLAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	player_hurtbox.add_child(shape)
	fake_player.add_child(player_hurtbox)
	EntityRegistry.register_entity(fake_player, fake_player.global_position, [&"player"])

	# Force immediate contact (this test proves a Hunt-spawned Hunter CAN
	# hit, not that it can path/pursue across the arena -- travel behaviour
	# is src/enemy/enemy_controller.gd's own suites' job).
	hunter.global_position = Vector2(700.0, 700.0)
	fake_player.global_position = hunter.global_position

	var hit_landed: Dictionary = {"count": 0}
	hunter.hitbox.hit_landed.connect(func(_hb, _dmg, _src) -> void: hit_landed["count"] += 1)

	var frames: int = 0
	while hit_landed["count"] < 1 and frames < 200:
		await get_tree().physics_frame
		frames += 1

	assert_int(hit_landed["count"]).append_failure_message("no contact hit landed from a Hunt-spawned Hunter within the timeout").is_greater(0)

	EntityRegistry.deregister_entity(fake_player)

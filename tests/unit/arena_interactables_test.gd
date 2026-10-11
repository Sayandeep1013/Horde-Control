extends GdUnitTestSuite

## v1.0 WP-ARENA (docs/32 section B; Register "v1.0 Arena Interactables"): Supply Crate, Powder Keg,
## Shrine and Spike Trap behaviour, spawn rules, placement validity and determinism.
## Expectations are literals transcribed from the Register, not imported from the
## code under test. SimClock.now is only ever advanced by hand.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const ArenaScene: PackedScene = preload("res://scenes/arena.tscn")
const DT: float = 1.0 / 60.0

var _player: Player
var _tower: Tower
var _mgr: ArenaInteractables
var _arena: Node2D


class FakePickups extends Node:
	var drops: Array = []

	func spawn_crate_drop(kind: String, amount: int, pos: Vector2) -> void:
		drops.append([kind, amount, pos])


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	_tower = auto_free(preload("res://scenes/tower.tscn").instantiate())
	add_child(_tower)
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true
	add_child(_player)
	_player.global_position = Vector2(900, 700)
	_mgr = auto_free(ArenaInteractables.new())
	_mgr.spike_layout = null # the four plates are tested in their own cases
	add_child(_mgr)


func after_test() -> void:
	for c in get_children():
		if c is GroundTelegraph or c is ExplosionFx or c is ArenaDustPuff or c is ArenaCrate or c is ArenaKeg or c is ArenaShrine:
			c.free()
	AbilityDamage.reset()
	StatusEffects.reset()
	CombatStats.reset_run_stats()


func _advance(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		SimClock.now += DT


func _enemy_at(pos: Vector2, hp: float = 1000.0) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	EntityRegistry.update_position(e, pos)
	e.death_state.max_hp = hp
	e.death_state.current_hp = hp
	return e


func _use_real_map() -> void:
	_arena = auto_free(ArenaScene.instantiate()) as Node2D
	add_child(_arena)
	_mgr.set_map_for_test(ArenaSpawnMap.from_arena(_arena))


# --- Supply Crate ----------------------------------------------------------------

func test_crate_breaks_when_the_player_walks_into_it() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	_player.global_position = Vector2(500 + 33 + 14 + 2, 500) # one reach plus 2 px: not touching
	assert_bool(crate.check_player(_player, _player.global_position)).is_false()
	_player.global_position = Vector2(500 + 33 + 14 - 2, 500) # inside the reach (crate 33 + body 14)
	assert_bool(crate.check_player(_player, Vector2(600, 500))).is_true()
	assert_bool(crate.is_broken).is_true()
	assert_float(CombatStats.get_run_counter("crates_broken")).is_equal(1.0)


func test_crate_breaks_when_a_dash_passes_through_it_even_between_ticks() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	# One dash tick is about 20 px: the player ends far past the crate, the swept path crosses it.
	_player.global_position = Vector2(560, 500)
	assert_bool(crate.check_player(_player, Vector2(440, 500))).is_true()
	var other: ArenaCrate = _mgr.add_crate(Vector2(500, 600))
	assert_bool(other.check_player(_player, Vector2(440, 500))).is_false() # path misses it by 100 px


func test_crate_breaks_on_player_side_area_damage_only_within_radius() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	AbilityDamage.hit_area(Vector2(500 + 100, 500), 60.0, 20.0, "dynamite_satchel", &"player", false)
	assert_bool(crate.is_broken).is_false() # 100 px away, radius 60 + crate 33 = 93
	AbilityDamage.hit_area(Vector2(500 + 70, 500), 60.0, 20.0, "dynamite_satchel", &"player", false)
	assert_bool(crate.is_broken).is_true()


func test_crate_take_area_damage_contract() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	crate.take_area_damage(0.0, "x")
	assert_bool(crate.is_broken).is_false()
	crate.take_area_damage(5.0, "x")
	assert_bool(crate.is_broken).is_true()
	crate.take_area_damage(5.0, "x") # idempotent
	assert_float(CombatStats.get_run_counter("crates_broken")).is_equal(1.0)


func test_enemy_blast_does_not_break_a_crate() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	EnemyBlast.detonate(EntityRegistry, Vector2(500, 500), 200.0, 10.0, true, true)
	assert_bool(crate.is_broken).is_false()


func test_auto_bow_cannot_see_a_crate() -> void:
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	EntityRegistry.update_position(_player, _player.global_position)
	assert_bool(EntityRegistry.is_registered(crate)).is_false()
	assert_int(EntityRegistry.get_entities_in_radius(Vector2(500, 500), 500.0, &"enemy").size()).is_equal(0)
	assert_bool(crate.is_in_group(&"breakable")).is_true()


func test_crate_drop_split_is_55_25_20_and_deterministic_per_seed() -> void:
	_mgr.run_seed = 4242
	var counts: Dictionary = {"scrap": 0, "meat": 0, "xp": 0}
	for i in 2000:
		counts[_mgr.drop_kind_for(i)] += 1
	assert_float(float(counts["scrap"]) / 2000.0).is_equal_approx(0.55, 0.04)
	assert_float(float(counts["meat"]) / 2000.0).is_equal_approx(0.25, 0.04)
	assert_float(float(counts["xp"]) / 2000.0).is_equal_approx(0.20, 0.04)
	var first: Array[String] = []
	for i in 30:
		first.append(_mgr.drop_kind_for(i))
	_mgr.run_seed = 4242
	for i in 30:
		assert_str(_mgr.drop_kind_for(i)).is_equal(first[i])
	_mgr.run_seed = 99
	var differs: bool = false
	for i in 30:
		if _mgr.drop_kind_for(i) != first[i]:
			differs = true
	assert_bool(differs).is_true()


func test_a_broken_crate_asks_the_pickup_system_for_the_keyed_drop_amounts() -> void:
	var fake: FakePickups = auto_free(FakePickups.new())
	add_child(fake)
	_mgr.set_pickup_system_for_test(fake)
	_mgr.run_seed = 7
	var expected_kind: String = _mgr.drop_kind_for(0)
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 500))
	crate.break_crate("test")
	assert_int(fake.drops.size()).is_equal(1)
	assert_str(fake.drops[0][0]).is_equal(expected_kind)
	var amount: int = {"scrap": 8, "meat": 0, "xp": 5}[expected_kind]
	assert_int(fake.drops[0][1]).is_equal(amount)
	assert_vector(fake.drops[0][2]).is_equal(Vector2(500, 500))


# --- Powder Keg ------------------------------------------------------------------

func test_keg_is_not_lit_by_walking_but_is_lit_by_a_dash() -> void:
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	_player.global_position = Vector2(500, 500 + 20)
	assert_bool(keg.check_player(_player, Vector2(500, 560))).is_false()
	assert_bool(keg.is_lit).is_false()
	_player.set_input_direction_for_test(Vector2.RIGHT)
	_player.press_dash_for_test()
	SimClock.now += DT
	_player.physics_step(DT)
	assert_bool(_player.is_dashing()).is_true()
	_player.global_position = Vector2(540, 500)
	assert_bool(keg.check_player(_player, Vector2(460, 500))).is_true()
	assert_bool(keg.is_lit).is_true()


func test_keg_is_lit_by_player_side_area_damage_but_not_by_an_enemy_blast() -> void:
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	EnemyBlast.detonate(EntityRegistry, Vector2(500, 500), 200.0, 10.0, true, true)
	assert_bool(keg.is_lit).is_false()
	AbilityDamage.hit_area(Vector2(500, 500), 50.0, 14.0, "firebomb", &"player", false)
	assert_bool(keg.is_lit).is_true()


func test_keg_fuse_is_0_8_seconds_then_explodes() -> void:
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	keg.light("test")
	assert_float(keg.fuse_time_left()).is_equal_approx(0.8, 0.02)
	_advance(0.75)
	keg._physics_process(DT)
	assert_bool(keg.has_exploded).is_false()
	_advance(0.1)
	keg._physics_process(DT)
	assert_bool(keg.has_exploded).is_true()
	assert_float(CombatStats.get_run_counter("kegs_detonated")).is_equal(1.0)


func test_keg_blast_hits_enemies_within_170_px_for_260_boss_half_and_never_the_tower() -> void:
	_tower.global_position = Vector2(500, 500) # the keg sits on the Tower footprint: no Tower damage
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	var inside: EnemyController = _enemy_at(Vector2(500 + 150, 500))
	var outside: EnemyController = _enemy_at(Vector2(500 + 200, 500))
	var boss: EnemyController = _enemy_at(Vector2(500, 500 + 60))
	boss.boss_id = "warchief"
	var tower_hp: float = _tower.health.get_current_health()
	var tower_shield: float = _tower.health.current_shield
	keg.detonate()
	assert_float(1000.0 - inside.death_state.current_hp).is_equal_approx(260.0, 0.01)
	assert_float(outside.death_state.current_hp).is_equal(1000.0)
	assert_float(1000.0 - boss.death_state.current_hp).is_equal_approx(130.0, 0.01)
	assert_float(_tower.health.get_current_health()).is_equal(tower_hp)
	assert_float(_tower.health.current_shield).is_equal(tower_shield)
	assert_float(_damage_of("keg")).is_equal_approx(390.0, 0.01)


func test_keg_blast_hurts_the_player_for_15_only_when_inside() -> void:
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	_player.global_position = Vector2(500 + 150, 500)
	var hp: float = _player.death_state.current_hp
	keg.detonate()
	assert_float(hp - _player.death_state.current_hp).is_equal_approx(15.0, 0.01)
	var keg2: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	_player.global_position = Vector2(500 + 220, 500)
	hp = _player.death_state.current_hp
	keg2.detonate()
	assert_float(_player.death_state.current_hp).is_equal(hp)


func test_keg_chain_lights_a_neighbouring_keg_and_breaks_a_crate() -> void:
	var a: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	var b: ArenaKeg = _mgr.add_keg(Vector2(580, 500))
	var far: ArenaKeg = _mgr.add_keg(Vector2(900, 500))
	var crate: ArenaCrate = _mgr.add_crate(Vector2(500, 580))
	a.detonate()
	assert_bool(b.is_lit).is_true()
	assert_bool(far.is_lit).is_false()
	assert_bool(crate.is_broken).is_true()
	assert_bool(a.has_exploded).is_true()
	_advance(0.85)
	b._physics_process(DT)
	assert_bool(b.has_exploded).is_true() # the chain completes after the second fuse
	assert_float(CombatStats.get_run_counter("kegs_detonated")).is_equal(2.0)


func _damage_of(source_id: String) -> float:
	for entry in CombatStats.get_damage_by_source():
		if entry["source_id"] == source_id:
			return float(entry["damage"])
	return 0.0


# --- Shrine ----------------------------------------------------------------------

func test_shrine_fills_in_2_5_seconds_of_standing_and_claims() -> void:
	var s: ArenaShrine = _mgr.add_shrine(Vector2(500, 500), "haste")
	var got: Array = []
	s.claimed.connect(func(_n: ArenaShrine, id: String) -> void: got.append(id))
	_player.global_position = Vector2(500 + 51, 500)
	for i in 149: # 2.483 s
		_advance(DT)
		s.check_player(_player)
	assert_bool(s.is_claimed).is_false()
	for i in 3:
		_advance(DT)
		s.check_player(_player)
	assert_bool(s.is_claimed).is_true()
	assert_array(got).is_equal(["haste"])
	assert_float(CombatStats.get_run_counter("shrines_claimed")).is_equal(1.0)


func test_shrine_progress_pauses_outside_78_px_and_is_kept() -> void:
	var s: ArenaShrine = _mgr.add_shrine(Vector2(500, 500), "war")
	s.check_player(_player) # prime the clock at the current sim time
	_player.global_position = Vector2(500, 500 + 40)
	_advance(1.0)
	s.check_player(_player)
	assert_float(s.progress_seconds).is_equal_approx(1.0, 0.02)
	_player.global_position = Vector2(500, 500 + 80) # just outside
	_advance(3.0)
	s.check_player(_player)
	assert_float(s.progress_seconds).is_equal_approx(1.0, 0.02) # kept, not drained, not reset
	_player.global_position = Vector2(500, 500 + 40)
	_advance(1.0)
	s.check_player(_player)
	assert_float(s.progress_seconds).is_equal_approx(2.0, 0.03)
	assert_bool(s.is_claimed).is_false()


func test_shrine_does_not_fill_while_the_sim_clock_is_stopped() -> void:
	var s: ArenaShrine = _mgr.add_shrine(Vector2(500, 500), "war")
	_player.global_position = Vector2(500, 500)
	s.check_player(_player)
	for i in 600: # ten seconds of wall-clock calls with the clock frozen (pause)
		s.check_player(_player)
	assert_float(s.progress_seconds).is_equal(0.0)


func test_shrine_expires_after_25_seconds_and_blinks_in_the_last_5() -> void:
	var s: ArenaShrine = _mgr.add_shrine(Vector2(500, 500), "ward")
	var expired: Array = []
	s.expired.connect(func(_n: ArenaShrine) -> void: expired.append(true))
	_advance(20.0)
	s.check_player(_player)
	assert_bool(s.is_expired).is_false()
	assert_float(s.time_left()).is_less(5.1)
	_advance(5.1)
	s.check_player(_player)
	assert_bool(s.is_expired).is_true()
	assert_int(expired.size()).is_equal(1)


# --- Spike Trap ------------------------------------------------------------------

func _trap_at(pos: Vector2) -> ArenaSpikeTrap:
	var t: ArenaSpikeTrap = auto_free(ArenaSpikeTrap.new())
	t.phase_offset = -SimClock.now # cycle time 0 right now
	add_child(t)
	t.global_position = pos
	return t


func test_spike_cycle_is_2_2_retracted_0_6_telegraph_0_5_raised() -> void:
	var t: ArenaSpikeTrap = _trap_at(Vector2(2000, 0))
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.RETRACTED)
	_advance(2.1)
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.RETRACTED)
	_advance(0.2) # 2.3 s
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.TELEGRAPH)
	_advance(0.45) # 2.75 s
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.TELEGRAPH)
	_advance(0.1) # 2.85 s
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.RAISED)
	_advance(0.5) # 3.35 s: the next cycle has begun
	assert_int(t.current_phase()).is_equal(ArenaSpikeTrap.Phase.RETRACTED)


func _to_phase_time(t: ArenaSpikeTrap, cycle_seconds: float) -> void:
	var now_in_cycle: float = fposmod(SimClock.now + t.phase_offset, 3.3)
	var delta: float = fposmod(cycle_seconds - now_in_cycle, 3.3)
	SimClock.now += delta


func test_spikes_hit_an_enemy_and_the_player_once_per_cycle_for_30() -> void:
	var t: ArenaSpikeTrap = _trap_at(Vector2(500, 500))
	var enemy: EnemyController = _enemy_at(Vector2(510, 505))
	_player.global_position = Vector2(490, 495)
	var p_hp: float = _player.death_state.current_hp
	_to_phase_time(t, 2.0)
	t.step() # retracted: nothing
	_to_phase_time(t, 2.5)
	t.step() # telegraph: nothing
	assert_float(enemy.death_state.current_hp).is_equal(1000.0)
	assert_float(_player.death_state.current_hp).is_equal(p_hp)
	_to_phase_time(t, 2.85)
	for i in 20: # many ticks while raised
		t.step()
		SimClock.now += DT * 0.5
	assert_float(1000.0 - enemy.death_state.current_hp).is_equal_approx(30.0, 0.01)
	assert_float(p_hp - _player.death_state.current_hp).is_equal_approx(30.0, 0.01)
	assert_float(_damage_of("spikes")).is_equal_approx(30.0, 0.01)
	# The next cycle raises again and hits again.
	_to_phase_time(t, 2.0)
	t.step()
	_to_phase_time(t, 2.85)
	t.step()
	assert_float(1000.0 - enemy.death_state.current_hp).is_equal_approx(60.0, 0.01)


func test_spikes_ignore_an_entity_outside_the_plate_and_halve_boss_damage() -> void:
	var t: ArenaSpikeTrap = _trap_at(Vector2(500, 500))
	var off_plate: EnemyController = _enemy_at(Vector2(500 + 80, 500)) # plate half-width 72 (2x)
	var boss: EnemyController = _enemy_at(Vector2(500, 500 + 10))
	boss.boss_id = "king"
	_to_phase_time(t, 2.9)
	t.step()
	assert_float(off_plate.death_state.current_hp).is_equal(1000.0)
	assert_float(1000.0 - boss.death_state.current_hp).is_equal_approx(15.0, 0.01)


func test_spikes_never_hurt_the_tower() -> void:
	_tower.global_position = Vector2(500, 500)
	var t: ArenaSpikeTrap = _trap_at(Vector2(500, 500))
	var hp: float = _tower.health.get_current_health()
	var shield: float = _tower.health.current_shield
	_to_phase_time(t, 2.9)
	t.step()
	assert_float(_tower.health.get_current_health()).is_equal(hp)
	assert_float(_tower.health.current_shield).is_equal(shield)


# --- Placement, caps and determinism -----------------------------------------------

func test_the_eight_spike_plates_sit_at_the_bridges() -> void:
	var mgr: ArenaInteractables = auto_free(ArenaInteractables.new())
	add_child(mgr)
	var arena: Node2D = auto_free(ArenaScene.instantiate()) as Node2D
	add_child(arena)
	var field: FlowField = arena.get_node("FlowField") as FlowField
	var traps: Array[ArenaSpikeTrap] = mgr.get_traps()
	assert_int(traps.size()).is_equal(8)
	# Literal positions: a deck plate at each bridge centre (north, east, south, west) and a road
	# plate 140 px towards the Tower from it.
	var expected: Array[Vector2] = [Vector2(-384, -576), Vector2(896, -128), Vector2(384, 576), Vector2(-896, 128), Vector2(-384, -436), Vector2(756, -128), Vector2(384, 436), Vector2(-756, 128)]
	for i in 8:
		assert_vector(traps[i].global_position).is_equal(expected[i])
		assert_bool(field.is_walkable(traps[i].global_position)).append_failure_message("plate %d at %s is not on walkable ground" % [i, traps[i].global_position]).is_true()
		assert_float(traps[i].global_position.length()).is_greater(106.0 + 72.0) # clear of the Tower footprint
	for i in traps.size():
		for j in range(i + 1, traps.size()):
			assert_bool(traps[i].global_position.distance_to(traps[j].global_position) >= 120.0).is_true()


func test_interactable_sizes_match_the_register() -> void:
	# Register "v1.0 Arena Interactables": keg 1.6x, radius 170, 260 damage; spike plate 2x; shrine 1.5x; crate 1.5x.
	var keg: ArenaKeg = _mgr.add_keg(Vector2(500, 500))
	var crate: ArenaCrate = _mgr.add_crate(Vector2(700, 500))
	var shrine: ArenaShrine = _mgr.add_shrine(Vector2(900, 500), "war")
	var trap: ArenaSpikeTrap = _trap_at(Vector2(1100, 500))
	await get_tree().process_frame
	assert_float(keg._sprite.scale.x).is_equal_approx(1.6, 0.001)
	assert_float(ArenaKeg.BLAST_RADIUS_PX).is_equal(170.0)
	assert_float(ArenaKeg.ENEMY_DAMAGE).is_equal(260.0)
	assert_float(crate._sprite.scale.x).is_equal_approx(1.5, 0.001)
	assert_float(shrine._sprite.scale.x).is_equal_approx(1.5, 0.001)
	assert_float(ArenaShrine.CLAIM_RADIUS_PX).is_equal(78.0)
	assert_float(trap._sprite.scale.x).is_equal_approx(2.0, 0.001)
	assert_float(ArenaSpikeTrap.HIT_RADIUS_X_PX).is_equal(72.0)
	assert_float(ArenaSpikeTrap.HIT_RADIUS_Y_PX).is_equal(48.0)


func test_wave_start_spawns_by_the_register_rules() -> void:
	_use_real_map()
	_mgr.run_seed = 11
	_mgr.spawn_for_wave(1)
	assert_int(_mgr.get_crates().size()).is_equal(0)
	assert_object(_mgr.get_shrine()).is_null()
	_mgr.spawn_for_wave(2)
	var after_2: int = _mgr.get_crates().size()
	assert_bool(after_2 >= 4 and after_2 <= 6).append_failure_message("wave 2 spawned %d crates, expected 4-6" % after_2).is_true()
	assert_int(_mgr.get_kegs().size()).is_equal(0)
	assert_object(_mgr.get_shrine()).is_not_null()
	_mgr.spawn_for_wave(3)
	var after_3: int = _mgr.get_crates().size()
	assert_bool(after_3 - after_2 >= 4 and after_3 - after_2 <= 6).append_failure_message("wave 3 added %d crates" % (after_3 - after_2)).is_true()
	assert_int(_mgr.get_kegs().size()).is_equal(1)
	_mgr.spawn_for_wave(4)
	assert_int(_mgr.get_crates().size()).is_equal(12) # cap 12
	assert_int(_mgr.get_kegs().size()).is_equal(2)
	_mgr.spawn_for_wave(5)
	_mgr.spawn_for_wave(6)
	assert_int(_mgr.get_kegs().size()).is_equal(4) # cap 4
	for k in _mgr.get_kegs():
		k.free()
	_mgr.get_kegs() # prune
	_mgr.spawn_for_wave(9)
	assert_int(_mgr.get_kegs().size()).is_equal(2) # two per wave from wave 9


func test_wave_started_signal_drives_spawning() -> void:
	_use_real_map()
	EventBus.emit_wave_started(2, 15, "standard", false)
	assert_int(_mgr.get_crates().size()).is_greater_equal(4)


func test_spawned_positions_are_walkable_and_obey_the_distance_rules() -> void:
	_use_real_map()
	var map: ArenaSpawnMap = ArenaSpawnMap.from_arena(_arena)
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var mgr: ArenaInteractables = auto_free(ArenaInteractables.new())
		mgr.spike_layout = load("res://data/arena/spike_traps.tres")
		mgr.run_seed = seed_value
		add_child(mgr)
		mgr.set_map_for_test(map)
		for wave in range(2, 10):
			mgr.spawn_for_wave(wave)
		var placed: Array[Vector2] = []
		for c in mgr.get_crates():
			placed.append(c.global_position)
		for k in mgr.get_kegs():
			placed.append(k.global_position)
		for p in placed:
			assert_bool(map.is_walkable(p)).append_failure_message("seed %d: %s is not walkable" % [seed_value, p]).is_true()
			assert_bool(p.length() >= 180.0).is_true()
			assert_bool(p.distance_to(_player.global_position) >= 120.0).is_true()
		var everything: Array[Vector2] = placed.duplicate()
		for t in mgr.get_traps():
			everything.append(t.global_position)
		var shrine: ArenaShrine = mgr.get_shrine()
		assert_object(shrine).is_not_null()
		var d: float = shrine.global_position.length()
		assert_bool(d >= 400.0 and d <= 850.0).append_failure_message("shrine at %.0f px" % d).is_true()
		everything.append(shrine.global_position)
		for i in everything.size():
			for j in range(i + 1, everything.size()):
				assert_bool(everything[i].distance_to(everything[j]) >= 120.0).append_failure_message("seed %d: two objects %.0f px apart" % [seed_value, everything[i].distance_to(everything[j])]).is_true()
		mgr.free()


func _positions_for(seed_value: int) -> Array[Vector2]:
	var mgr: ArenaInteractables = auto_free(ArenaInteractables.new())
	mgr.spike_layout = null
	mgr.run_seed = seed_value
	add_child(mgr)
	mgr.set_map_for_test(ArenaSpawnMap.from_arena(_arena))
	for wave in range(2, 6):
		mgr.spawn_for_wave(wave)
	var out: Array[Vector2] = []
	for c in mgr.get_crates():
		out.append(c.global_position)
	for k in mgr.get_kegs():
		out.append(k.global_position)
	out.append(mgr.get_shrine().global_position)
	var boon: String = mgr.get_shrine().boon_id
	out.append(Vector2(float(ArenaBoon.IDS.find(boon)), 0.0))
	for c in mgr.get_crates():
		c.free()
	for k in mgr.get_kegs():
		k.free()
	mgr.get_shrine().free()
	mgr.free()
	return out


func test_placement_and_boon_roll_are_deterministic_by_run_seed() -> void:
	_use_real_map()
	var a: Array[Vector2] = _positions_for(777)
	var b: Array[Vector2] = _positions_for(777)
	var c: Array[Vector2] = _positions_for(778)
	assert_int(a.size()).is_greater(12)
	assert_array(a).is_equal(b)
	assert_bool(a == c).is_false()

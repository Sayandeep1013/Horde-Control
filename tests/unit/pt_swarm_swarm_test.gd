extends GdUnitTestSuite

## PT-SWARM swarm suite (docs/33 §C1-C3, §C5-C6; Register "v1.0 Enemies,
## Bosses & Waves" and "Technical Caps & Performance", D341-D348): BulletPattern
## geometry, enemy bullets hitting / passing / being blocked, the speed ramp, the
## alive caps, FlowField consumption through a fake service, and the 15-wave
## sequence with bosses at 5/10/15 plus Endless. Expectations are literals.

const SeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const WarchiefScene: PackedScene = preload("res://scenes/entities/goblin_warchief.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const Target: GDScript = preload("res://tests/unit/v1_test_target.gd")


## Stands in for PT-ARENA's FlowField (group "flow_field", docs/33 §B4 contract).
class FakeFlowField extends Node:
	var dir: Vector2 = Vector2.DOWN
	var calls: int = 0

	func _ready() -> void:
		add_to_group(&"flow_field")

	func direction_to(_kind: StringName, _pos: Vector2) -> Vector2:
		calls += 1
		return dir

	func is_walkable(_pos: Vector2) -> bool:
		return true

	func random_walkable_point(_rng: RandomNumberGenerator, from: Vector2, min_dist: float, _max_dist: float) -> Vector2:
		return from + Vector2(min_dist, 0.0)


var _registry: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new())
	AttackSlotManager.clear_all_for_test()
	EnemyController.reset_flow_field_cache()
	SwarmState.alive_count = 0
	EntityCaps.mobile_override = -1


func after_test() -> void:
	EnemyController.reset_flow_field_cache()
	SwarmState.alive_count = 0
	EntityCaps.mobile_override = -1
	for c in get_children():
		if c is EnemyBulletField or c is FakeFlowField:
			remove_child(c)
			c.free()


func _target(pos: Vector2, tag: StringName, faction: Hurtbox.Faction = Hurtbox.Faction.PLAYER) -> Node2D:
	var t: Node2D = Target.new()
	t.set("faction", faction)
	t.position = pos
	add_child(t)
	auto_free(t)
	_registry.register_entity(t, pos, [tag])
	return t


func _enemy(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = scene.instantiate() as EnemyController
	e.set_registry_for_test(_registry)
	e.set_sim_clock_for_test(_clock)
	e.driven_externally = true
	e.position = pos
	add_child(e)
	auto_free(e)
	return e


func _field() -> EnemyBulletField:
	var f: EnemyBulletField = EnemyBulletField.get_or_create(self, _registry)
	f.check_obstacles = false
	return f


# --- BulletPattern geometry ----------------------------------------------------------

func test_radial_spaces_shots_evenly_and_leaves_its_gaps_empty() -> void:
	var ring: PackedFloat32Array = BulletPattern.radial(12, 0.0)
	assert_int(ring.size()).is_equal(12)
	for i in 12:
		assert_float(absf(angle_difference(ring[i], deg_to_rad(30.0 * i)))).is_less(0.0001)
	var gaps: Array[float] = [0.0, PI]
	var gapped: PackedFloat32Array = BulletPattern.radial(24, 0.0, gaps, deg_to_rad(20.0))
	# 15 degree spacing: 0 and +-15 fall in the gap at 0, 180 and 180+-15 in the gap at PI.
	assert_int(gapped.size()).is_equal(18)
	for a in gapped:
		assert_float(absf(angle_difference(0.0, a))).append_failure_message("a shot inside the gap at 0").is_greater(deg_to_rad(20.0))
		assert_float(absf(angle_difference(PI, a))).append_failure_message("a shot inside the gap at 180").is_greater(deg_to_rad(20.0))


func test_fan_spreads_symmetrically_and_aimed_centres_on_the_target() -> void:
	var fan: PackedFloat32Array = BulletPattern.fan(5, 0.0, deg_to_rad(40.0))
	assert_int(fan.size()).is_equal(5)
	assert_float(fan[0]).is_equal_approx(deg_to_rad(-20.0), 0.0001)
	assert_float(fan[2]).is_equal_approx(0.0, 0.0001)
	assert_float(fan[4]).is_equal_approx(deg_to_rad(20.0), 0.0001)
	var aimed: PackedFloat32Array = BulletPattern.aimed(Vector2.ZERO, Vector2(0, 300), 3, deg_to_rad(28.0))
	assert_float(aimed[1]).append_failure_message("the middle shot points at the target").is_equal_approx(PI / 2.0, 0.0001)
	assert_float(BulletPattern.fan(1, 1.0, 2.0)[0]).is_equal_approx(1.0, 0.0001)


func test_spiral_rotates_by_its_step_every_volley() -> void:
	var spiral := BulletPattern.Spiral.new(3, deg_to_rad(13.0), 0.0)
	var v1: PackedFloat32Array = spiral.next()
	var v2: PackedFloat32Array = spiral.next()
	var v3: PackedFloat32Array = spiral.next()
	assert_int(v1.size()).is_equal(3)
	assert_float(v1[1] - v1[0]).is_equal_approx(deg_to_rad(120.0), 0.0001)
	assert_float(angle_difference(v1[0], v2[0])).is_equal_approx(deg_to_rad(13.0), 0.0001)
	assert_float(angle_difference(v1[0], v3[0])).is_equal_approx(deg_to_rad(26.0), 0.0001)


# --- Enemy bullets ---------------------------------------------------------------------

func test_a_bullet_hits_the_player_once_and_is_consumed() -> void:
	var player: Node2D = _target(Vector2(200, 0), &"player")
	var f: EnemyBulletField = _field()
	f.fire(Vector2.ZERO, Vector2(400, 0), 12.0, 15.0, true, false)
	for _i in 30:
		f.step(1.0 / 60.0)
	assert_array(player.damage_log).is_equal([15.0])
	assert_int(f.get_count()).is_equal(0)


func test_a_dashing_player_is_passed_through_and_the_tower_only_takes_flagged_shots() -> void:
	var player: Node2D = _target(Vector2(200, 0), &"player")
	var tower: Node2D = _target(Vector2(0, 200), &"tower", Hurtbox.Faction.TOWER)
	player.hurtbox.invulnerable = true
	var f: EnemyBulletField = _field()
	f.fire(Vector2.ZERO, Vector2(400, 0), 12.0, 15.0, true, false)
	f.fire(Vector2.ZERO, Vector2(0, 400), 12.0, 15.0, true, false) # not flagged for the Tower
	f.fire(Vector2(10, 0), Vector2(0, 400), 12.0, 20.0, true, true)
	for _i in 40:
		f.step(1.0 / 60.0)
	assert_array(player.damage_log).append_failure_message("i-frames: the orb flies on").is_empty()
	assert_int(f.hits_player).append_failure_message("an invulnerable player must not consume the orb").is_equal(0)
	assert_array(tower.damage_log).is_equal([20.0])
	assert_int(f.hits_tower).is_equal(1)


func test_a_rock_on_the_world_layer_blocks_a_bullet_but_open_ground_does_not() -> void:
	var player: Node2D = _target(Vector2(300, 0), &"player")
	var wall := StaticBody2D.new()
	wall.collision_layer = CollisionLayers.LAYER_WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 60)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(150, 0)
	add_child(wall)
	auto_free(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var f: EnemyBulletField = _field()
	f.check_obstacles = true
	f.fire(Vector2.ZERO, Vector2(500, 0), 10.0, 15.0, true, false) # through the rock
	f.fire(Vector2(0, 200), Vector2(500, -333), 10.0, 15.0, true, false) # around it
	for _i in 60:
		f.step(1.0 / 60.0)
	assert_int(f.blocked_total).append_failure_message("the rock stops the straight shot").is_equal(1)
	assert_array(player.damage_log).append_failure_message("the open shot still lands").is_equal([15.0])


# --- Speed ramp (D343) ---------------------------------------------------------------

func test_speed_ramp_is_4_percent_per_wave_capped_at_double() -> void:
	assert_float(WaveDirector.speed_ramp_for_wave(1)).is_equal_approx(1.0, 0.0001)
	assert_float(WaveDirector.speed_ramp_for_wave(7)).is_equal_approx(1.24, 0.0001)
	assert_float(WaveDirector.speed_ramp_for_wave(15)).is_equal_approx(1.56, 0.0001)
	assert_float(WaveDirector.speed_ramp_for_wave(60)).is_equal_approx(2.0, 0.0001)


func test_the_director_ramps_every_spawn_elites_included_but_not_bosses() -> void:
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.driven_externally = true
	add_child(director)
	director.set_registry_for_test(_registry)
	director.set_sim_clock_for_test(_clock)
	director.open_wave_for_test(7)
	var seeker: EnemyController = _enemy(SeekerScene, Vector2(5000, 0))
	var base: float = seeker.get_base_speed()
	director._apply_wave_scaling(seeker, seeker.definition)
	assert_float(seeker.get_base_speed() / base).append_failure_message("wave 7: x1.24").is_equal_approx(1.24, 0.0001)
	seeker.apply_elite("swift")
	assert_float(seeker.get_base_speed() / base).append_failure_message("swift elite keeps the ramp").is_equal_approx(1.24 * 1.45, 0.0001)
	var boss: EnemyController = _enemy(WarchiefScene, Vector2(-5000, 0))
	var boss_base: float = boss.get_base_speed()
	director._apply_wave_scaling(boss, boss.definition)
	assert_float(boss.get_base_speed()).append_failure_message("bosses are exempt").is_equal_approx(boss_base, 0.0001)


func test_hunters_outrun_the_players_base_speed_around_wave_6_to_7() -> void:
	# docs/33 C2: Hunter 0.85 x 320 = 272 px/s; the player is 320 px/s.
	assert_float(0.85 * 320.0 * WaveDirector.speed_ramp_for_wave(5)).is_less(320.0) # 315.5: still slower at wave 5 (326 at wave 6)
	assert_float(0.85 * 320.0 * WaveDirector.speed_ramp_for_wave(7)).is_greater(320.0)


# --- Alive caps (D345) ----------------------------------------------------------------

func test_the_enemy_cap_is_400_on_desktop_and_180_on_mobile() -> void:
	EntityCaps.mobile_override = 0
	assert_int(EntityCaps.max_enemies()).is_equal(400)
	EntityCaps.mobile_override = 1
	assert_int(EntityCaps.max_enemies()).is_equal(180)
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner) # pools are built in _ready, after the override
	spawner.set_registry_for_test(_registry)
	for i in 220:
		spawner.spawn_enemy(Vector2(i, 0))
	assert_int(spawner.get_enemy_count()).is_equal(180)
	spawner.clear_all_for_test()


# --- FlowField consumption ---------------------------------------------------------------

func test_an_enemy_steers_by_the_flow_field_and_falls_back_to_a_straight_line_on_zero() -> void:
	var ff := FakeFlowField.new()
	add_child(ff)
	_target(Vector2(2000, 0), &"tower", Hurtbox.Faction.TOWER)
	var seeker: EnemyController = _enemy(SeekerScene, Vector2.ZERO)
	_clock.now += 0.05
	seeker.physics_step(0.05)
	assert_int(ff.calls).append_failure_message("the controller never asked the flow field").is_greater(0)
	assert_float(seeker.velocity.normalized().dot(Vector2.DOWN)).append_failure_message("velocity %s should follow the field (down)" % seeker.velocity).is_greater(0.95)
	ff.dir = Vector2.ZERO # off-grid / unreachable
	_clock.now += 0.05
	seeker.physics_step(0.05)
	assert_float(seeker.velocity.normalized().dot(Vector2.RIGHT)).append_failure_message("ZERO = straight at the Tower (+x)").is_greater(0.95)


func test_without_a_flow_field_the_enemy_seeks_straight() -> void:
	_target(Vector2(0, -2000), &"tower", Hurtbox.Faction.TOWER)
	var seeker: EnemyController = _enemy(SeekerScene, Vector2.ZERO)
	_clock.now += 0.05
	seeker.physics_step(0.05)
	assert_float(seeker.velocity.normalized().dot(Vector2.UP)).is_greater(0.95)


# --- The 15-wave sequence ---------------------------------------------------------------

func _boss_of(director: WaveDirector, index: int) -> String:
	var w: WaveDefinition = director.waves[index]
	for e in director.encounter_definitions:
		if e.unique_id == w.encounter_sequence[0]:
			return (e.spawn_groups[0] as SpawnGroup).enemy_definition_id
	return ""


func _total(director: WaveDirector, index: int) -> int:
	var w: WaveDefinition = director.waves[index]
	for e in director.encounter_definitions:
		if e.unique_id == w.encounter_sequence[0]:
			var t: int = 0
			for g in e.spawn_groups:
				t += (g as SpawnGroup).count
			return t
	return 0


func test_bosses_close_waves_5_10_and_15_and_every_other_wave_is_timed() -> void:
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	add_child(director)
	assert_int(director.waves.size()).is_equal(15)
	for i in 15:
		var boss: bool = (i + 1) % 5 == 0
		assert_bool(director.waves[i].has_maximum_duration).append_failure_message("wave %d" % (i + 1)).is_equal(not boss)
	assert_str(_boss_of(director, 4)).is_equal("goblin_warchief")
	assert_str(_boss_of(director, 9)).is_equal("gutbarrel_juggernaut")
	assert_str(_boss_of(director, 14)).is_equal("bombardier_king")


func test_swarm_counts_are_about_ten_times_the_v1_waves_from_wave_6() -> void:
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	add_child(director)
	# v1.0 totals (Register "Wave sequence" before PT-SWARM), by wave number.
	var v1: Dictionary = {6: 35, 7: 38, 9: 34, 11: 46, 12: 34, 13: 60, 14: 81}
	for n in v1.keys():
		assert_int(_total(director, n - 1)).append_failure_message("wave %d" % n).is_greater_equal(int(v1[n]) * 7)
	assert_int(_total(director, 13)).append_failure_message("wave 14 feeds a 350+ swarm").is_greater_equal(700)


func test_endless_loops_waves_6_to_15_so_a_boss_lands_on_every_fifth_wave() -> void:
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.endless = true
	add_child(director)
	assert_array(director.get_loop_wave_indices_for_test()).is_equal([5, 6, 7, 8, 9, 10, 11, 12, 13, 14])
	for n in [20, 25, 30, 35]:
		var idx: int = director._array_index_for(n - 1)
		assert_bool(director.waves[idx].has_maximum_duration).append_failure_message("Endless wave %d should be a boss wave" % n).is_false()
	for n in [16, 19, 21, 24]:
		assert_bool(director.waves[director._array_index_for(n - 1)].has_maximum_duration).append_failure_message("Endless wave %d" % n).is_true()

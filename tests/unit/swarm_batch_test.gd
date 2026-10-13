extends GdUnitTestSuite

## PT-PERF (D390-D399): the batched swarm. SwarmBrain steps every plain enemy at one
## SimLoop registrant (no collision bodies, a spatial hash for separation, the FlowField
## byte mask for walkability), SwarmRenderer draws them from MultiMesh buffers. These
## tests pin the behaviour the old per-node enemy had and the new data layout; the
## behaviour rules themselves (slots, leash, stuck, attack cycle, status effects) keep
## their own suites, which run on the per-node path (no brain in their tree).

const SeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const HunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const OpportunistScene: PackedScene = preload("res://scenes/entities/opportunist.tscn")
const BruteScene: PackedScene = preload("res://scenes/entities/brute.tscn")
const BomberScene: PackedScene = preload("res://scenes/entities/bomber.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const Target: GDScript = preload("res://tests/unit/v1_test_target.gd")

const STEP: float = 1.0 / 60.0

var _registry: Node
var _clock: Node
var _brain: SwarmBrain
var _renderer: SwarmRenderer
var _tower: Node2D
var _flow: FlowField = null
var _loop: SimLoop


func before_test() -> void:
	SwarmState.reset()
	EnemyController.reset_flow_field_cache()
	AttackSlotManager.clear_all_for_test()
	StatusEffects.reset()
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new()) as Node
	_renderer = auto_free(SwarmRenderer.new()) as SwarmRenderer
	add_child(_renderer)
	_brain = auto_free(SwarmBrain.new()) as SwarmBrain
	add_child(_brain)
	_tower = auto_free(TowerScene.instantiate()) as Node2D
	add_child(_tower)
	_tower.global_position = Vector2.ZERO
	_tower.weapon.set_registry_for_test(_registry)
	_registry.register_entity(_tower, Vector2.ZERO, [&"tower"]) # the brain finds the Tower through its registry
	_loop = auto_free(SimLoop.new()) as SimLoop # not in the tree: only `register()` is used


func after_test() -> void:
	SwarmState.reset()
	EnemyController.reset_flow_field_cache()
	AttackSlotManager.clear_all_for_test()
	StatusEffects.reset()


func _enemy(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = scene.instantiate() as EnemyController
	e.set_registry_for_test(_registry)
	e.set_sim_clock_for_test(_clock)
	e.driven_externally = true
	e.set_sim_loop_for_test(_loop) # a non-null loop: the deferred registration then runs
	add_child(e)
	auto_free(e)
	e.global_position = pos
	e.set_tower_reference(_tower)
	_registry.update_position(e, pos)
	return e


## The deferred registration (end of the frame the enemy entered the tree) joins the brain.
func _spawn(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = _enemy(scene, pos)
	await await_idle_frame()
	return e


func _tick(count: int = 1) -> void:
	for _i in count:
		_clock.now += STEP
		_brain.physics_step(STEP)


func _add_flow_field(blocked: Array[Rect2]) -> void:
	_flow = auto_free(FlowField.new()) as FlowField
	add_child(_flow)
	_flow.build(blocked, Vector2.ZERO, 106.0)
	EnemyController.reset_flow_field_cache()


# --- membership ---------------------------------------------------------------

func test_plain_enemies_join_the_brain_lose_their_body_and_node_visuals() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	assert_bool(seeker.is_swarm_member()).is_true()
	assert_bool(seeker.is_swarm_drawn()).is_true()
	assert_int(seeker.collision_layer).is_equal(0)
	assert_int(seeker.collision_mask).is_equal(0)
	assert_bool(seeker.body_shape.disabled).is_true()
	for gone in ["Visuals", "TelegraphVisual", "HealthBar"]:
		assert_object(seeker.get_node_or_null(gone)).append_failure_message("%s should be freed" % gone).is_null()
	assert_object(seeker.get_node_or_null("Hurtbox")).is_not_null() # projectiles and the hit path still need it
	assert_object(seeker.get_node_or_null("Hitbox")).is_not_null()
	assert_int(_renderer.get_active_count()).is_equal(1)


func test_every_plain_scene_is_drawn_by_the_renderer_and_behaviour_enemies_are_not() -> void:
	var hunter: EnemyController = await _spawn(HunterScene, Vector2(600, 100))
	var opportunist: EnemyController = await _spawn(OpportunistScene, Vector2(600, 200))
	var brute: EnemyController = await _spawn(BruteScene, Vector2(600, 300))
	var bomber: EnemyController = await _spawn(BomberScene, Vector2(600, 400))
	assert_bool(hunter.is_swarm_drawn()).is_true()
	assert_bool(opportunist.is_swarm_drawn()).is_true()
	assert_bool(brute.is_swarm_drawn()).is_true()
	assert_bool(bomber.is_swarm_member()).append_failure_message("a Bomber has a Behavior: it keeps its own step").is_false()
	assert_bool(bomber.collision_layer != 0).is_true()
	assert_object(bomber.get_node_or_null("Visuals")).is_not_null()
	assert_int(_renderer.get_active_count()).is_equal(3)


func test_without_a_brain_an_enemy_keeps_its_body_and_its_node_visuals() -> void:
	SwarmState.reset()
	var e: EnemyController = SeekerScene.instantiate() as EnemyController
	e.set_registry_for_test(_registry)
	e.set_sim_clock_for_test(_clock)
	add_child(e)
	auto_free(e)
	await await_idle_frame()
	assert_bool(e.is_swarm_member()).is_false()
	assert_bool(e.collision_layer != 0).is_true()
	assert_object(e.get_node_or_null("Visuals/AnimatedSprite2D")).is_not_null()


func test_leaving_the_tree_frees_the_slot_for_the_next_enemy() -> void:
	var a: EnemyController = await _spawn(SeekerScene, Vector2(600, 0))
	var slot_a: int = a.get_swarm_slot()
	remove_child(a)
	assert_int(_renderer.get_active_count()).is_equal(0)
	var b: EnemyController = await _spawn(SeekerScene, Vector2(600, 50))
	assert_int(b.get_swarm_slot()).is_equal(slot_a)
	assert_int(_renderer.get_active_count()).is_equal(1)
	a.free()


# --- the hit path -------------------------------------------------------------------

func test_a_brain_driven_seeker_in_reach_still_damages_the_tower() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(150, 0)) # walks the last 10 px into its attack ring
	var before: float = _tower.health.current_shield + _tower.health.get_current_health() # the shield soaks the first hits
	for _i in 140: # 2.3 s: the wind-up, the hit, the Hitbox pulse
		await get_tree().physics_frame
		_tick(1)
	assert_float(_tower.health.current_shield + _tower.health.get_current_health()).append_failure_message("the swarm seeker never landed a hit on the Tower").is_less(before)
	assert_bool(seeker.hitbox.top_level).is_true() # parked between pulses


func test_a_brain_driven_hunter_in_reach_damages_the_player() -> void:
	var player: Player = auto_free((load("res://scenes/player.tscn") as PackedScene).instantiate()) as Player
	player.set_registry_for_test(_registry)
	add_child(player)
	player.global_position = Vector2(900, 0)
	_registry.update_position(player, player.global_position)
	var hunter: EnemyController = await _spawn(HunterScene, Vector2(930, 0))
	var before: float = player.death_state.current_hp
	for _i in 120:
		await get_tree().physics_frame
		_tick(1)
		hunter.set_player_for_test(player)
	assert_float(player.death_state.current_hp).append_failure_message("the swarm hunter never hurt the player").is_less(before)


# --- movement -------------------------------------------------------------------

func test_a_seeker_walks_toward_the_tower_without_a_physics_body() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var before: float = seeker.global_position.distance_to(_tower.global_position)
	_tick(60)
	var after: float = seeker.global_position.distance_to(_tower.global_position)
	assert_float(after).append_failure_message("moved %f px closer in a second" % (before - after)).is_less(before - 100.0)
	assert_vector(seeker.velocity).is_not_equal(Vector2.ZERO)


func test_the_registry_position_follows_the_node() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	_tick(30)
	var found: Array[Node2D] = _registry.get_entities_in_radius(seeker.global_position, 4.0, &"enemy")
	assert_bool(found.has(seeker)).is_true()


func test_enemies_never_enter_blocked_cells_and_slide_along_a_wall() -> void:
	var blocked: Array[Rect2] = [Rect2(-1100, -300, 2200, 200)] # a wall north of the Tower
	_add_flow_field(blocked)
	# Straight line to the Tower would cross the wall; the enemy starts north of it and has to stay out.
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(40, -500))
	for _i in 300:
		_tick(1)
		assert_bool(_flow.is_walkable(seeker.global_position)).append_failure_message("entered a blocked cell at %s" % str(seeker.global_position)).is_true()
	# It slid along the wall instead of freezing at it: it moved sideways or around.
	assert_float(seeker.global_position.distance_to(Vector2(40, -500))).is_greater(60.0)


func test_enemies_are_pushed_out_of_the_tower_footprint() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(60, 0)) # inside the 106 px footprint
	_tick(2)
	var d: float = seeker.global_position.distance_to(_tower.global_position)
	assert_float(d).append_failure_message("distance %f" % d).is_greater_equal(106.0 + 14.0 - 0.5)


func test_overlapping_enemies_are_separated_by_the_hash() -> void:
	var a: EnemyController = await _spawn(SeekerScene, Vector2(900, -3)) # side by side across the line to the Tower
	var b: EnemyController = await _spawn(SeekerScene, Vector2(900, 3))
	var start: float = a.global_position.distance_to(b.global_position)
	_tick(20)
	assert_float(a.global_position.distance_to(b.global_position)).is_greater(start + 4.0)


func test_a_frozen_enemy_stands_still() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	_tick(5)
	var p: Vector2 = seeker.global_position
	_clock.now = 10.0
	StatusEffects.apply_freeze(seeker, 5.0)
	_tick(30)
	assert_vector(seeker.global_position).is_equal(p)


func test_a_held_enemy_stands_still() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	seeker.swarm_hold_for_test(true)
	var p: Vector2 = seeker.global_position
	_tick(30)
	assert_vector(seeker.global_position).is_equal(p)


func test_the_step_order_is_deterministic() -> void:
	var first: PackedVector2Array = await _run_scenario()
	for c in get_children():
		if c is EnemyController:
			remove_child(c)
			c.free()
	SwarmState.brain = _brain
	AttackSlotManager.clear_all_for_test()
	var second: PackedVector2Array = await _run_scenario()
	assert_int(first.size()).is_equal(second.size())
	for i in first.size():
		assert_vector(second[i]).is_equal(first[i])


func _run_scenario() -> PackedVector2Array:
	_clock.now = 0.0
	var list: Array[EnemyController] = []
	for i in 12:
		list.append(await _spawn(SeekerScene, Vector2(500.0 + 7.0 * i, -300.0 + 40.0 * i)))
	_tick(90)
	var out := PackedVector2Array()
	for e in list:
		out.append(e.global_position)
	return out


func test_the_think_interval_spreads_plans_over_ticks_when_the_swarm_is_large() -> void:
	var list: Array[EnemyController] = []
	for i in 30:
		list.append(await _spawn(SeekerScene, Vector2(800.0, -450.0 + 30.0 * i)))
	_tick(2) # everybody plans once (first think)
	SwarmState.alive_count = 100 # >= 60: plan every 3rd tick
	var planned: int = 0
	for _i in 6:
		await get_tree().physics_frame # a new physics frame number each time: the think phase rotates
		_tick(1)
		planned += _brain.last_plan_count
	assert_int(planned).append_failure_message("30 enemies over 6 ticks at interval 3 -> 60 plans, got %d" % planned).is_equal(60)
	SwarmState.alive_count = 0


# --- presentation ----------------------------------------------------------------

func test_the_run_animation_plays_while_moving_and_idle_when_in_reach() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var profile: Variant = seeker._sv_profile
	_tick(3)
	assert_int(_renderer.get_slot_row(seeker.get_swarm_slot())).is_equal(int(profile.rows[&"run"]))
	# Stand in reach of the Tower: no velocity, idle.
	seeker.global_position = Vector2(140, 0)
	_brain.pos[seeker.get_swarm_slot()] = Vector2(140, 0)
	_registry.update_position(seeker, Vector2(140, 0))
	_tick(3)
	assert_int(_renderer.get_slot_row(seeker.get_swarm_slot())).is_equal(int(profile.rows[&"idle"]))


func test_a_hit_flashes_shows_the_bar_and_a_kill_frees_the_instance() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var slot: int = seeker.get_swarm_slot()
	_clock.now = 3.0
	seeker.death_state.apply_damage(10.0, null)
	assert_int(_renderer.s_hit[slot]).is_equal(SwarmRenderer.tick_of(3.0))
	assert_int(_renderer.b_on[slot]).is_equal(1)
	seeker.death_state.apply_damage(100000.0, null)
	assert_int(_renderer.b_on[slot]).is_equal(0)
	assert_bool(_renderer.is_attached(slot)).is_false()
	assert_bool(seeker.is_swarm_member()).is_false()


func test_a_burst_of_kills_never_spawns_more_skull_effects_than_the_cap() -> void:
	var list: Array[EnemyController] = []
	for i in 40:
		list.append(await _spawn(SeekerScene, Vector2(800.0 + 10.0 * (i % 5), -400.0 + 20.0 * i)))
	for e in list:
		e.death_state.apply_damage(100000.0, null)
	assert_int(_renderer.get_fx_pool_size()).is_less_equal(SwarmRenderer.FX_CAP)
	assert_int(_renderer.get_busy_fx_count()).is_less_equal(SwarmRenderer.FX_CAP)


func test_elites_use_the_outline_and_the_elite_scale() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var slot: int = seeker.get_swarm_slot()
	seeker.apply_elite("swift")
	assert_int(_renderer.get_slot_flags(slot) & 3).is_equal(SwarmRenderer.OUTLINE_GOLD)
	assert_float(_renderer.s_scale[slot]).is_equal_approx(1.18, 0.0001)
	var vamp: EnemyController = await _spawn(SeekerScene, Vector2(700, 100))
	vamp.apply_elite("vampiric")
	assert_int(_renderer.get_slot_flags(vamp.get_swarm_slot()) & 3).is_equal(SwarmRenderer.OUTLINE_RED)


func test_status_tints_reach_the_instance_flags() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var slot: int = seeker.get_swarm_slot()
	seeker.set_swarm_tint(SwarmRenderer.TINT_FREEZE)
	assert_int((_renderer.get_slot_flags(slot) >> 2) & 3).is_equal(SwarmRenderer.TINT_FREEZE)
	seeker.set_swarm_tint(SwarmRenderer.TINT_NONE)
	assert_int((_renderer.get_slot_flags(slot) >> 2) & 3).is_equal(0)


func test_a_converted_hunter_switches_to_the_seeker_art() -> void:
	var hunter: EnemyController = await _spawn(HunterScene, Vector2(700, 0))
	var slot: int = hunter.get_swarm_slot()
	var before: Variant = hunter._sv_profile
	hunter._convert_to_tower_seeker()
	var after: Variant = hunter._sv_profile
	assert_object(after).is_not_null()
	assert_bool(after != before).is_true()
	assert_bool(after.rows.has(&"strike_down")).is_true() # the Seeker's directional strike clips
	assert_int(_renderer.get_slot_row(slot)).is_equal(int(after.rows[&"run"]))


func test_the_atlas_rows_follow_the_sprite_frames() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	var profile: Variant = seeker._sv_profile
	var frames: SpriteFrames = load("res://assets/sprite_frames/tower_seeker.tres") as SpriteFrames
	for anim in frames.get_animation_names():
		assert_bool(profile.rows.has(StringName(anim))).append_failure_message("no row for %s" % anim).is_true()
		var row: int = profile.rows[StringName(anim)]
		var seconds: float = float(profile.row_seconds[row])
		var expect: float = float(frames.get_frame_count(anim)) / frames.get_animation_speed(anim)
		assert_float(seconds).is_equal_approx(expect, 0.0001)


# --- draw order -------------------------------------------------------------------

func test_instances_are_banded_around_the_player_and_the_tower_and_sorted_by_y() -> void:
	var player: Node2D = Target.new()
	player.set("faction", Hurtbox.Faction.PLAYER)
	player.position = Vector2(0, 200)
	add_child(player)
	auto_free(player)
	_registry.register_entity(player, player.position, [&"player"])
	_tower.global_position = Vector2(0, 0)
	var north: EnemyController = await _spawn(SeekerScene, Vector2(600, -300)) # behind the Tower and the player
	var middle: EnemyController = await _spawn(SeekerScene, Vector2(600, 100)) # in front of the Tower, behind the player
	var south1: EnemyController = await _spawn(SeekerScene, Vector2(600, 500))
	var south2: EnemyController = await _spawn(SeekerScene, Vector2(600, 400))
	for e in [north, middle, south1, south2]:
		(e as EnemyController).swarm_hold_for_test(true)
	_tick(2)
	_renderer.force_fill_for_test()
	var counts: PackedInt32Array = _renderer.get_band_instance_counts()
	assert_int(counts[0]).append_failure_message(str(counts)).is_equal(1)
	assert_int(counts[1]).append_failure_message(str(counts)).is_equal(1)
	assert_int(counts[2]).append_failure_message(str(counts)).is_equal(2)
	# Band parking: strictly between the separators it sits behind and in front of.
	var bands: Array[MultiMeshInstance2D] = _renderer.get_band_nodes()
	assert_float(bands[0].position.y).is_less(0.0)
	assert_float(bands[1].position.y).is_between(0.0, 200.0)
	assert_float(bands[2].position.y).is_greater(200.0)


func test_the_first_buffer_row_of_a_band_is_its_northernmost_enemy() -> void:
	var low: EnemyController = await _spawn(SeekerScene, Vector2(600, 480))
	var high: EnemyController = await _spawn(SeekerScene, Vector2(600, 420))
	low.swarm_hold_for_test(true)
	high.swarm_hold_for_test(true)
	_tick(2)
	_renderer.force_fill_for_test()
	# `_order` is y-ascending: the northern enemy is drawn first, so the southern one covers it.
	var order: PackedInt32Array = _renderer._order
	assert_int(order.size()).is_equal(2)
	assert_int(order[0]).is_equal(high.get_swarm_slot())
	assert_int(order[1]).is_equal(low.get_swarm_slot())


# --- spawn budget and caps ------------------------------------------------------------

func test_the_wave_director_spawn_budget_is_per_tick_and_halves_on_mobile() -> void:
	var director: WaveDirector = auto_free(WaveDirector.new()) as WaveDirector
	assert_int(director._spawn_tick_budget()).is_equal(WaveDirector.MAX_SPAWNS_PER_TICK)
	EntityCaps.mobile_override = 1
	assert_int(director._spawn_tick_budget()).is_equal(WaveDirector.MAX_SPAWNS_PER_TICK_MOBILE)
	EntityCaps.mobile_override = -1
	assert_int(director._spawn_tick_budget_used()).is_equal(0)
	director._note_spawn_this_tick()
	director._note_spawn_this_tick()
	assert_int(director._spawn_tick_budget_used()).is_equal(2)
	await get_tree().physics_frame # a new tick starts with a fresh budget
	assert_int(director._spawn_tick_budget_used()).is_equal(0)


func test_mobile_think_intervals_are_sparser_than_desktop() -> void:
	SwarmState.alive_count = 160
	var desktop: int = EnemyController.swarm_think_interval()
	EntityCaps.mobile_override = 1
	var mobile: int = EnemyController.swarm_think_interval()
	EntityCaps.mobile_override = -1
	SwarmState.alive_count = 0
	assert_int(desktop).is_equal(EnemyController.SWARM_THINK_INTERVAL_MID_TICKS)
	assert_int(mobile).is_equal(EnemyController.SWARM_THINK_MOBILE_HIGH_TICKS)
	assert_int(mobile).is_greater(desktop)


func test_hit_effects_per_tick_are_budgeted() -> void:
	var seeker: EnemyController = await _spawn(SeekerScene, Vector2(700, 0))
	SwarmState.fx_budget = 0
	var numbers_before: int = DamageNumberFx._pool.size()
	seeker.death_state.apply_damage(5.0, null) # no budget: it flashes and shows its bar, no blood or number
	assert_int(DamageNumberFx._pool.size()).is_equal(numbers_before)
	assert_int(_renderer.b_on[seeker.get_swarm_slot()]).is_equal(1)
	SwarmState.fx_budget = 1000000

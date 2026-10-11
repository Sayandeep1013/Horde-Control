extends GdUnitTestSuite

## v1.0 enemy roster suite (WP-ENEMIES; docs/31 §5; Register "v1.0 Enemies,
## Bosses & Waves"): Bomber, Brute, elite affixes, the two bosses, Meat and the
## War Chest. Expectations are literals transcribed from docs/31.

const BomberScene: PackedScene = preload("res://scenes/entities/bomber.tscn")
const BruteScene: PackedScene = preload("res://scenes/entities/brute.tscn")
const WarchiefScene: PackedScene = preload("res://scenes/entities/goblin_warchief.tscn")
const KingScene: PackedScene = preload("res://scenes/entities/bombardier_king.tscn")
const HunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")
const EntitySpawnerScript: GDScript = preload("res://src/core/entity_spawner.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PickupSystemScript: GDScript = preload("res://src/pickup/pickup_system.gd")
const Target: GDScript = preload("res://tests/unit/v1_test_target.gd")
const SummonRecorder: GDScript = preload("res://tests/unit/v1_summon_recorder.gd")

var _registry: Node
var _clock: Node
var _systems: Array = []
var _spawners: Array = []


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new())
	add_child(_registry)
	_clock = auto_free(SimClockScript.new())
	AttackSlotManager.clear_all_for_test()
	CombatStats.reset_run_stats()


func after_test() -> void:
	for sys in _systems:
		if is_instance_valid(sys):
			sys.clear_all_for_test()
	for sp in _spawners:
		if is_instance_valid(sp):
			sp.clear_all_for_test()
	_systems.clear()
	_spawners.clear()
	# The suite node outlives each test, so bombs, telegraphs and explosions
	# a test left behind would leak into the next one's `_bombs()`.
	for c in get_children():
		if c is EnemyBomb or c is GroundTelegraph or c is ExplosionFx:
			remove_child(c)
			c.free()


func _enemy(scene: PackedScene, pos: Vector2) -> EnemyController:
	var e: EnemyController = scene.instantiate() as EnemyController
	e.set_registry_for_test(_registry)
	e.set_sim_clock_for_test(_clock)
	e.driven_externally = true
	e.position = pos
	add_child(e)
	auto_free(e)
	return e


func _target(pos: Vector2, tag: StringName, faction: Hurtbox.Faction = Hurtbox.Faction.PLAYER) -> Node2D:
	var t: Node2D = Target.new()
	t.set("faction", faction)
	t.position = pos
	add_child(t)
	auto_free(t)
	_registry.register_entity(t, pos, [tag])
	return t


func _advance(e: EnemyController, seconds: float, step: float = 0.05, bombs: bool = false) -> void:
	for _i in int(round(seconds / step)):
		_clock.now += step
		e.physics_step(step)
		if bombs:
			for b in _bombs():
				b._physics_process(step)


func _bombs() -> Array:
	var out: Array = []
	for c in get_children():
		if c is EnemyBomb:
			out.append(c)
	return out


# --- Bomber -----------------------------------------------------------------------

func test_bomber_holds_240_to_300_px_and_its_dynamite_damages_a_player_who_stays() -> void:
	var player: Node2D = _target(Vector2.ZERO, &"player")
	var bomber: EnemyController = _enemy(BomberScene, Vector2(500, 0))
	assert_float(bomber.death_state.max_hp).is_equal_approx(40.0, 0.01)
	_advance(bomber, 2.5)
	var dist: float = bomber.global_position.distance_to(player.global_position)
	assert_float(dist).append_failure_message("Bomber should hold 240-300 px from the player, was %.1f" % dist).is_between(235.0, 305.0)
	var guard: int = 0
	while _bombs().is_empty() and guard < 100:
		_advance(bomber, 0.1)
		guard += 1
	assert_bool(_bombs().is_empty()).append_failure_message("the Bomber never threw").is_false()
	var bomb: EnemyBomb = _bombs()[0]
	assert_float(bomb.blast_radius).is_equal(56.0)
	assert_float(bomb.flight_seconds).is_equal(1.0)
	assert_vector(bomb.target_position).append_failure_message("lands on the player's position").is_equal_approx(player.global_position, Vector2(1, 1))
	_advance(bomber, 1.05, 0.05, true)
	assert_array(player.damage_log).append_failure_message("22 damage when the ring resolves").is_equal([22.0])


func test_a_player_who_leaves_the_ring_takes_no_damage() -> void:
	var player: Node2D = _target(Vector2.ZERO, &"player")
	var bomber: EnemyController = _enemy(BomberScene, Vector2(270, 0))
	var guard: int = 0
	while _bombs().is_empty() and guard < 120:
		_advance(bomber, 0.1)
		guard += 1
	var landing: Vector2 = _bombs()[0].target_position
	player.global_position = landing + Vector2(0, 160) # outside the 56 px ring
	_registry.update_position(player, player.global_position)
	_advance(bomber, 1.05, 0.05, true)
	assert_array(player.damage_log).is_empty()


func test_bomber_damage_scales_with_the_wave_damage_multiplier() -> void:
	var player: Node2D = _target(Vector2.ZERO, &"player")
	var bomber: EnemyController = _enemy(BomberScene, Vector2(270, 0))
	bomber.set_wave_scaling(1.0, 1.0, 1.5) # a Bomber has Hunter intent, so the hunter share applies
	var guard: int = 0
	while _bombs().is_empty() and guard < 120:
		_advance(bomber, 0.1)
		guard += 1
	assert_bool(_bombs().is_empty()).append_failure_message("no bomb thrown; bomber at %s" % bomber.global_position).is_false()
	_advance(bomber, 1.05, 0.05, true)
	assert_array(player.damage_log).is_equal([33.0])


# --- Brute --------------------------------------------------------------------------

func test_brute_is_a_slow_320_hp_tower_breaker_whose_freeze_becomes_a_slow() -> void:
	var brute: EnemyController = _enemy(BruteScene, Vector2(300, 0))
	assert_float(brute.death_state.max_hp).is_equal_approx(320.0, 0.01)
	assert_float(brute.get_base_speed()).is_equal_approx(0.42 * 320.0, 0.01)
	assert_bool(brute.freeze_becomes_slow).is_true()
	assert_bool(brute.freeze_immune).is_false()
	assert_float((brute.get_node("Visuals") as Node2D).scale.x).is_equal_approx(1.55, 0.001)
	assert_int(brute.definition.target_intent).is_equal(ContractEnums.TargetIntent.TowerSeeker)
	assert_int(brute.definition.attack_profile.damage_per_hit_or_tick).is_equal(34)
	assert_float(brute.definition.attack_profile.cycle_or_tick_interval_seconds).is_equal(1.8)
	assert_float(brute.definition.telegraph_data.windup_duration_seconds).is_equal(0.7)


# --- Elites ---------------------------------------------------------------------------

func test_armored_elite_has_3_2x_hp_and_takes_40_percent_less_damage() -> void:
	var e: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	e.apply_elite("armored")
	assert_float(e.death_state.max_hp).is_equal_approx(30.0 * 3.2, 0.01)
	assert_bool(e.is_elite()).is_true()
	e.hurtbox.receive_hit(null, 10.0, "test")
	assert_float(e.death_state.current_hp).append_failure_message("10 damage x 0.6 = 6").is_equal_approx(96.0 - 6.0, 0.01)


func test_swift_elite_is_45_percent_faster_and_scaled_up() -> void:
	var e: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	e.apply_elite("swift")
	assert_float(e.get_base_speed()).is_equal_approx(0.85 * 320.0 * 1.45, 0.01)
	assert_float((e.get_node("Visuals") as Node2D).scale.x).is_equal_approx(1.18, 0.001)
	assert_float(e.hitbox.damage).append_failure_message("x1.3 damage").is_equal_approx(8.0 * 1.3, 0.01)
	var sprite: AnimatedSprite2D = e.get_node("Visuals/AnimatedSprite2D")
	assert_object(sprite.material).append_failure_message("elites carry the outline shader").is_not_null()
	assert_that((sprite.material as ShaderMaterial).get_shader_parameter("outline_color")).is_equal(Color(1.0, 0.82, 0.2, 1.0))


func test_vampiric_elite_heals_a_quarter_of_the_damage_it_deals_and_pulses_red() -> void:
	var e: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	e.apply_elite("vampiric")
	e.death_state.current_hp = 50.0
	e._on_hitbox_hit_landed(null, 20.0, null)
	assert_float(e.death_state.current_hp).is_equal_approx(55.0, 0.01)
	var sprite: AnimatedSprite2D = e.get_node("Visuals/AnimatedSprite2D")
	assert_that((sprite.material as ShaderMaterial).get_shader_parameter("outline_color")).is_equal(Color(1.0, 0.2, 0.15, 1.0))


func test_volatile_elite_death_leaves_a_0_7_s_90_px_blast_and_elite_events_and_counters() -> void:
	var killed: Array = []
	EventBus.elite_killed.connect(func(_e: Node2D, affix: String, _t: float) -> void: killed.append(affix))
	var e: EnemyController = _enemy(HunterScene, Vector2(100, 50))
	e.apply_elite("volatile")
	e.death_state.kill("test")
	assert_array(killed).is_equal(["volatile"])
	assert_float(CombatStats.get_run_counter("elite_kills")).is_equal(1.0)
	assert_float(CombatStats.get_run_counter("kills")).is_equal(1.0)
	assert_float(CombatStats.get_run_counter("field_cores")).append_failure_message("1 Core, banked at once").is_equal(1.0)
	var bombs: Array = _bombs()
	assert_int(bombs.size()).is_equal(1)
	assert_float(bombs[0].blast_radius).is_equal(90.0)
	assert_float(bombs[0].flight_seconds).is_equal_approx(0.7, 0.0001)
	assert_float(bombs[0].blast_damage).append_failure_message("35 x the elite 1.3").is_equal_approx(45.5, 0.01)


func test_non_elite_has_no_outline_unless_the_accessibility_setting_is_on() -> void:
	GameSettings.set_enemy_outlines(false)
	var plain: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	assert_object((plain.get_node("Visuals/AnimatedSprite2D") as AnimatedSprite2D).material).is_null()
	GameSettings.set_enemy_outlines(true)
	var outlined: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	var mat: ShaderMaterial = (outlined.get_node("Visuals/AnimatedSprite2D") as AnimatedSprite2D).material as ShaderMaterial
	GameSettings.set_enemy_outlines(false)
	assert_object(mat).is_not_null()
	assert_float(float(mat.get_shader_parameter("outline_width"))).is_equal(1.0)
	assert_that(mat.get_shader_parameter("outline_color")).is_equal(outlined.definition.readability_profile.reserved_colour)


# --- Bosses ------------------------------------------------------------------------------

func test_warchief_announces_reports_health_enrages_below_40_percent_and_drops_on_death() -> void:
	var spawned: Array = []
	var health: Array = []
	var defeated: Array = []
	EventBus.boss_spawned.connect(func(_b: Node2D, id: String, name: String, hp: float, _t: float) -> void: spawned.append([id, name, hp]))
	EventBus.boss_health_changed.connect(func(id: String, cur: float, mx: float, _t: float) -> void: health.append([id, cur, mx]))
	EventBus.boss_defeated.connect(func(id: String, _p: Vector2, _t: float) -> void: defeated.append(id))
	var boss: EnemyController = _enemy(WarchiefScene, Vector2(400, 0))
	var b: WarchiefBehavior = boss.behavior as WarchiefBehavior
	assert_float(boss.death_state.max_hp).is_equal_approx(2600.0, 0.01)
	assert_float(boss.get_base_speed()).is_equal_approx(0.5 * 320.0, 0.01)
	assert_bool(boss.freeze_immune).append_failure_message("bosses are freeze-immune").is_true()
	b.announce_spawn()
	assert_array(spawned).is_equal([["warchief", "Goblin Warchief", 2600.0]])
	boss.death_state.apply_damage(100.0, "test")
	assert_array(health.back()).is_equal(["warchief", 2500.0, 2600.0])
	assert_float(b.cooldown_scale()).is_equal(1.0)
	boss.death_state.apply_damage(1500.0, "test") # 1000 left = 38.5%
	assert_int(b.phase).is_equal(2)
	assert_float(b.cooldown_scale()).append_failure_message("enrage: cooldowns x0.7").is_equal(0.7)
	boss.death_state.kill("test")
	assert_array(defeated).is_equal(["warchief"])
	assert_float(CombatStats.get_run_counter("boss_kills")).is_equal(1.0)
	assert_float(CombatStats.get_run_counter("field_cores")).is_equal(8.0)


func test_warchief_stays_in_phase_one_at_exactly_40_percent() -> void:
	var boss: EnemyController = _enemy(WarchiefScene, Vector2(400, 0))
	boss.death_state.apply_damage(2600.0 * 0.6, "test")
	assert_int((boss.behavior as WarchiefBehavior).phase).is_equal(1)


func test_warchief_slams_a_150_px_ring_for_38_after_a_1_s_telegraph() -> void:
	var player: Node2D = _target(Vector2(60, 0), &"player")
	var boss: EnemyController = _enemy(WarchiefScene, Vector2.ZERO)
	_advance(boss, 4.5)
	assert_array(player.damage_log).append_failure_message("the telegraph is still running at 4.5 s").is_empty()
	_advance(boss, 0.8)
	assert_array(player.damage_log).is_equal([38.0])


func test_warchief_rallies_six_hunters_through_the_wave_director() -> void:
	var recorder: Node = SummonRecorder.new()
	add_child(recorder)
	auto_free(recorder)
	var boss: EnemyController = _enemy(WarchiefScene, Vector2(2000, 2000)) # far from everything: only the Rally timer fires
	_target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	_advance(boss, 8.2)
	assert_array(recorder.calls).is_equal([["player_hunter", 6]])


func test_king_barrages_five_dynamite_around_the_player_then_siege_bombs_the_tower_for_110() -> void:
	var player: Node2D = _target(Vector2(0, 600), &"player")
	var tower: Node2D = _target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	var king: EnemyController = _enemy(KingScene, Vector2(360, 0))
	assert_float(king.death_state.max_hp).is_equal_approx(7000.0, 0.01)
	_advance(king, 3.2)
	var barrage: Array = _bombs().filter(func(b: EnemyBomb) -> bool: return b.blast_damage == 26.0)
	assert_int(barrage.size()).append_failure_message("Barrage is 5 dynamite").is_equal(5)
	assert_bool(barrage.any(func(b: EnemyBomb) -> bool: return b.target_position.distance_to(player.global_position) < 1.0)).append_failure_message("one lands on the player").is_true()
	_advance(king, 4.0)
	var siege: Array = _bombs().filter(func(b: EnemyBomb) -> bool: return b.blast_damage == 110.0)
	assert_int(siege.size()).is_equal(1)
	assert_float(siege[0].flight_seconds).is_equal(1.6)
	assert_bool(siege[0].hit_player).is_false()
	_advance(king, 1.7, 0.05, true)
	assert_float(tower.total_damage()).is_equal(110.0)


func test_king_goes_to_eight_dynamite_and_a_7_s_siege_bomb_below_50_percent() -> void:
	var king: EnemyController = _enemy(KingScene, Vector2(360, 0))
	_target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	_target(Vector2(0, 600), &"player")
	var kb: KingBehavior = king.behavior as KingBehavior
	king.death_state.apply_damage(3500.0, "test")
	assert_int(kb.phase).append_failure_message("exactly 50% is still phase 1").is_equal(1)
	king.death_state.apply_damage(1.0, "test")
	assert_int(kb.phase).is_equal(2)
	_advance(king, 3.2)
	var barrage: Array = _bombs().filter(func(b: EnemyBomb) -> bool: return b.blast_damage == 26.0)
	assert_int(barrage.size()).is_equal(8)


func test_king_calls_the_horde_of_8_seekers_and_2_bombers() -> void:
	var recorder: Node = SummonRecorder.new()
	add_child(recorder)
	auto_free(recorder)
	var king: EnemyController = _enemy(KingScene, Vector2(360, 0))
	_target(Vector2.ZERO, &"tower", Hurtbox.Faction.TOWER)
	_advance(king, 10.2)
	assert_array(recorder.calls).is_equal([["tower_seeker", 8], ["bomber", 2]])


# --- Meat and the War Chest -----------------------------------------------------------------

func _pickup_system() -> PickupSystem:
	var spawner: Node = auto_free(EntitySpawnerScript.new())
	add_child(spawner)
	spawner.set_registry_for_test(_registry)
	var system: PickupSystem = auto_free(PickupSystemScript.new()) as PickupSystem
	_systems.append(system)
	_spawners.append(spawner)
	add_child(system)
	system.set_entity_spawner_for_test(spawner)
	system.set_registry_for_test(_registry)
	system.set_sim_clock_for_test(_clock)
	return system


func test_elite_drop_table_is_4_xp_and_4_scrap_with_no_core_pickup() -> void:
	var system: PickupSystem = _pickup_system()
	var e: EnemyController = _enemy(HunterScene, Vector2.ZERO)
	e.apply_elite("swift")
	var table: DropTable = system._resolve_drop_table_for(e)
	assert_int(table.xp_shards).is_equal(4)
	assert_int(table.scrap).is_equal(4)
	assert_int(table.cores).is_equal(0)


func test_meat_drops_from_about_35_percent_of_elites_and_is_deterministic_per_seed() -> void:
	var system: PickupSystem = _pickup_system()
	system.run_seed = 99
	var hits: int = 0
	var first: Array = []
	for i in 400:
		var r: bool = system._roll_meat()
		hits += 1 if r else 0
		if i < 10:
			first.append(r)
	assert_float(float(hits) / 400.0).append_failure_message("%d/400" % hits).is_between(0.28, 0.42)
	var again: PickupSystem = _pickup_system()
	again.run_seed = 99
	var replay: Array = []
	for i in 10:
		replay.append(again._roll_meat())
	assert_array(replay).is_equal(first)


func test_collecting_meat_heals_12_percent_of_max_hp_and_it_is_not_magnetised() -> void:
	var system: PickupSystem = _pickup_system()
	var player: Player = auto_free(preload("res://scenes/player.tscn").instantiate()) as Player
	add_child(player)
	system.configure_player_for_test(player)
	player.death_state.current_hp = 50.0
	var pickup: Pickup = system._spawn_one_pickup(system.meat_definition, system.meat_definition.value, Vector2(2000, 0))
	assert_int(system.meat_definition.magnet_behaviour).is_equal(ContractEnums.MagnetBehaviour.Static)
	assert_float(system.meat_definition.lifetime_seconds).is_equal(20.0)
	assert_bool(pickup.is_attracted()).is_false()
	system._on_pickup_entered_collector(pickup)
	assert_float(player.death_state.current_hp).append_failure_message("12% of 100 = 12").is_equal_approx(62.0, 0.01)


func test_a_boss_death_drops_a_war_chest_and_collecting_it_opens_the_draft() -> void:
	var system: PickupSystem = _pickup_system()
	system.set_event_bus_for_test(EventBus)
	var opened: Array = [0]
	EventBus.war_chest_opened.connect(func(_t: float) -> void: opened[0] += 1)
	EventBus.emit_boss_defeated("warchief", Vector2(300, 300))
	system.step_drops()
	var chests: Array = system.get_active_pickups_for_test().filter(func(p: Pickup) -> bool: return p.get_pickup_type() == ContractEnums.PickupType.WarChest)
	assert_int(chests.size()).is_equal(1)
	assert_int(opened[0]).is_equal(0)
	system._on_pickup_entered_collector(chests[0])
	assert_int(opened[0]).append_failure_message("collecting the chest emits war_chest_opened").is_equal(1)

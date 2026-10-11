extends GdUnitTestSuite

## Review fix round, gameplay half (D204-D209): absolute meta hooks, the Frost
## Arrows freeze gate, keyed random streams, the four synergies, the repair ring
## and the Bomber's cue. Real enemy scenes, a real AbilityManager.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const BomberScene: PackedScene = preload("res://scenes/entities/bomber.tscn")

var _mgr: AbilityManager
var _dir: String


func before_test() -> void:
	_dir = "user://__review_fix_gp_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	StatusEffects.reset()
	AbilityDamage.reset()
	AbilityDamage.forced_crit = 0
	CombatStats.reset_run_stats()
	_mgr = auto_free(AbilityManager.new())
	add_child(_mgr)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	for c in get_children():
		if c is CaltropPatch or c is BallistaBolt or c is LobbedBomb or c is GroundTelegraph or c is ExplosionFx or c is LightningBolt or c is PulseRing:
			c.free()


func _enemy_at(pos: Vector2) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	EntityRegistry.update_position(e, pos)
	return e


func _hp(e: EnemyController) -> float:
	return e.death_state.current_hp


func _full_loadout() -> MetaLoadout:
	for node in MetaProgress.skill_tree.nodes:
		if node.tier > 0:
			MetaProgress.set_rank_for_test(node.id, node.max_rank)
	return MetaProgress.build_run_loadout()


# --- 1. hooks are absolute -------------------------------------------------------------

## FALSIFICATION: with `set_crit_chance_bonus` made additive (`_meta_crit += f`)
## the second application gave 0.24 and this test failed.
func test_applying_the_meta_hooks_twice_leaves_every_derived_value_at_the_loadout_value() -> void:
	var loadout: MetaLoadout = _full_loadout()
	var first: Dictionary = MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), true)
	MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), not bool(first["armory_granted"])) # the integration's deferred repeat
	assert_float(_mgr.get_crit_chance()).append_failure_message("crit applied once").is_equal_approx(loadout.player_crit_chance_bonus, 0.0001)
	assert_float(_mgr.get_skill_cooldown_multiplier()).is_equal_approx(1.0 - loadout.skill_cooldown_reduction, 0.0001)
	assert_float(_mgr.get_skill_damage_multiplier()).is_equal_approx(1.0 + loadout.skill_damage_bonus, 0.0001)
	assert_float(_mgr.get_tower_ability_damage_multiplier()).is_equal_approx(1.0 + loadout.tower_ability_damage_bonus, 0.0001)
	assert_float(_mgr.get_repair_multiplier()).is_equal_approx(1.0 + loadout.tower_repair_bonus, 0.0001)
	assert_float(_mgr.get_damage_taken_multiplier()).is_equal_approx(1.0 - loadout.damage_taken_reduction, 0.0001)
	assert_float(_mgr.get_dash_cooldown_multiplier()).is_equal_approx(1.0 - loadout.dash_cooldown_reduction, 0.0001)
	assert_int(_mgr._meta_dash_extra).is_equal(loadout.dash_extra_charges)
	assert_int(_mgr.owned_count(AbilityManager.SLOT_PLAYER)).append_failure_message("D281: the Armory grants no ability at run start (the Opening Pick offers 4 Epic)").is_equal(0)


func test_set_crit_chance_bonus_assigns_and_never_accumulates() -> void:
	_mgr.set_crit_chance_bonus(0.06)
	_mgr.set_crit_chance_bonus(0.06)
	assert_float(_mgr.get_crit_chance()).is_equal_approx(0.06, 0.0001)
	_mgr.set_crit_chance_bonus(0.0)
	assert_float(_mgr.get_crit_chance()).is_equal(0.0)


# --- 2. Frost Arrows freeze gate -------------------------------------------------------

func test_freeze_chance_follows_the_register_curve_and_is_zero_below_level_three() -> void:
	var expected: Array[float] = [0.0, 0.0, 0.05, 0.085, 0.12]
	for lvl in range(1, 6):
		assert_float(AbilityCatalog.value("frost_arrows", "freeze_chance", lvl)).append_failure_message("level %d" % lvl).is_equal_approx(expected[lvl - 1], 0.0001)
	assert_str(AbilityCatalog.describe("frost_arrows", 4)).contains("8.5% chance to freeze")
	assert_str(AbilityCatalog.describe("frost_arrows", 2)).not_contains("freeze")


## FALSIFICATION: with the `level < FREEZE_FIRST_LEVEL` gate removed (plain lerp
## from level 1) level 2 froze enemies and this test failed.
func test_level_two_frost_arrows_never_freeze_but_level_five_does() -> void:
	AbilityDamage.begin_run(11)
	_mgr.grant_ability("frost_arrows")
	_mgr.grant_ability("frost_arrows")
	var node: FrostArrowsAbility = _mgr.get_ability_node("frost_arrows") as FrostArrowsAbility
	var e: EnemyController = _enemy_at(Vector2(100, 0))
	for i in 400:
		node._on_arrow_hit(e, 1.0)
	assert_bool(StatusEffects.is_frozen(e)).append_failure_message("level 2 must never freeze").is_false()
	assert_bool(StatusEffects.is_slowed(e)).is_true()
	for i in 3:
		_mgr.grant_ability("frost_arrows")
	for i in 400:
		node._on_arrow_hit(e, 1.0)
	assert_bool(StatusEffects.is_frozen(e)).is_true()


# --- 3. keyed streams ------------------------------------------------------------------

func _crit_sequence(n: int) -> Array[bool]:
	AbilityDamage.forced_crit = -1
	var out: Array[bool] = []
	for i in n:
		out.append(AbilityDamage._crit_roll(0.5))
	return out


func test_crit_stream_is_keyed_on_the_run_seed_and_a_new_run_restarts_it() -> void:
	AbilityDamage.begin_run(7)
	var a: Array[bool] = _crit_sequence(40)
	AbilityDamage.begin_run(7) # Retry: same seed, state must not carry over
	var b: Array[bool] = _crit_sequence(40)
	AbilityDamage.begin_run(8)
	var c: Array[bool] = _crit_sequence(40)
	assert_array(b).is_equal(a)
	assert_array(c).is_not_equal(a)


func test_keyed_purpose_streams_are_reproducible_per_run_and_distinct_per_serial() -> void:
	AbilityDamage.begin_run(5)
	var f1: float = AbilityDamage.keyed_rng("freeze").randf()
	var f2: float = AbilityDamage.keyed_rng("freeze").randf()
	AbilityDamage.begin_run(5)
	assert_float(AbilityDamage.keyed_rng("freeze").randf()).is_equal(f1)
	assert_float(AbilityDamage.keyed_rng("freeze").randf()).is_equal(f2)
	assert_float(f1).is_not_equal(f2)
	assert_float(AbilityDamage.keyed_rng("armory").randf()).is_not_equal(f1)


func test_the_armory_pick_is_keyed_on_the_run_seed() -> void:
	AbilityDamage.begin_run(21)
	var first: String = _mgr.grant_free_random_ability()
	var other: AbilityManager = auto_free(AbilityManager.new())
	add_child(other)
	AbilityDamage.begin_run(21)
	assert_str(other.grant_free_random_ability()).is_equal(first)


# --- 4. synergies ----------------------------------------------------------------------

func _line(n: int) -> Array[EnemyController]:
	var out: Array[EnemyController] = []
	for i in n:
		out.append(_enemy_at(Vector2(60.0 * float(i + 1), 0.0)))
	return out


func test_conduction_adds_two_chains_when_frost_ward_is_owned() -> void:
	var enemies: Array[EnemyController] = _line(6)
	_mgr.grant_ability("storm_bolt")
	var bolt: StormBoltAbility = _mgr.get_ability_node("storm_bolt") as StormBoltAbility
	assert_int(bolt.strike(enemies[0]).size()).is_equal(3)
	_mgr.grant_ability("frost_ward")
	assert_int(bolt.strike(enemies[0]).size()).append_failure_message("1 + 2 chains + 2 Conduction").is_equal(5)


## FALSIFICATION: with `conduction_mult` returning 1.0 the Slowed enemy took the
## same damage as the plain one and this test failed.
func test_conduction_deals_half_again_to_a_slowed_or_frozen_enemy() -> void:
	_mgr.grant_ability("storm_bolt")
	_mgr.grant_ability("frost_ward")
	var bolt: StormBoltAbility = _mgr.get_ability_node("storm_bolt") as StormBoltAbility
	var plain: EnemyController = _enemy_at(Vector2(100, 0))
	var slowed: EnemyController = _enemy_at(Vector2(100, 600))
	var frozen: EnemyController = _enemy_at(Vector2(100, 1200))
	StatusEffects.apply_slow(slowed, 0.3, 5.0)
	StatusEffects.apply_freeze(frozen, 5.0)
	var hp_p: float = _hp(plain)
	var hp_s: float = _hp(slowed)
	var hp_f: float = _hp(frozen)
	bolt.strike(plain)
	bolt.strike(slowed)
	bolt.strike(frozen)
	var d_p: float = hp_p - _hp(plain)
	assert_float(d_p).is_greater(0.0)
	assert_float(hp_s - _hp(slowed)).is_equal_approx(d_p * 1.5, 0.01)
	assert_float(hp_f - _hp(frozen)).is_equal_approx(d_p * 1.5, 0.01)


func test_conduction_needs_the_partner() -> void:
	_mgr.grant_ability("storm_bolt")
	var bolt: StormBoltAbility = _mgr.get_ability_node("storm_bolt") as StormBoltAbility
	var plain: EnemyController = _enemy_at(Vector2(100, 0))
	var slowed: EnemyController = _enemy_at(Vector2(100, 600))
	StatusEffects.apply_slow(slowed, 0.3, 5.0)
	var hp_p: float = _hp(plain)
	var hp_s: float = _hp(slowed)
	bolt.strike(plain)
	bolt.strike(slowed)
	assert_float(hp_s - _hp(slowed)).is_equal_approx(hp_p - _hp(plain), 0.01)


func _patch_tick(pos: Vector2) -> CaltropPatch:
	var patch: CaltropPatch = CaltropPatch.spawn(self, pos, 10.0, 0.5, 0.25, 4.0)
	SimClock.now += 0.6
	patch._physics_process(0.016)
	return patch


func test_kindling_caltrops_ignite_and_hit_burning_enemies_for_a_quarter_more() -> void:
	_mgr.grant_ability("caltrops")
	_mgr.grant_ability("flame_arrows")
	var burning: EnemyController = _enemy_at(Vector2(100, 0))
	var fresh: EnemyController = _enemy_at(Vector2(100, 600))
	StatusEffects.apply_burn(burning, 1.0, 5.0, "flame_arrows")
	var hp_b: float = _hp(burning)
	var hp_f: float = _hp(fresh)
	_patch_tick(burning.global_position)
	_patch_tick(fresh.global_position)
	assert_float(hp_b - _hp(burning)).is_equal_approx(12.5, 0.01)
	assert_float(hp_f - _hp(fresh)).is_equal_approx(10.0, 0.01)
	assert_bool(StatusEffects.is_burning(fresh)).append_failure_message("the patch ignites the enemy standing in it").is_true()
	assert_str(String(StatusEffects.get_burn_info(fresh)["source"])).is_equal("caltrops")


func test_kindling_does_nothing_without_flame_arrows() -> void:
	_mgr.grant_ability("caltrops")
	var e: EnemyController = _enemy_at(Vector2(100, 0))
	StatusEffects.apply_burn(e, 1.0, 5.0, "other")
	var hp0: float = _hp(e)
	_patch_tick(e.global_position)
	assert_float(hp0 - _hp(e)).is_equal_approx(10.0, 0.01)
	var cold: EnemyController = _enemy_at(Vector2(100, 600))
	_patch_tick(cold.global_position)
	assert_bool(StatusEffects.is_burning(cold)).is_false()


func test_shatter_doubles_catapult_and_ballista_damage_on_a_frozen_enemy() -> void:
	_mgr.grant_ability("catapult")
	_mgr.grant_ability("frost_arrows")
	var cat: CatapultAbility = _mgr.get_ability_node("catapult") as CatapultAbility
	var frozen: EnemyController = _enemy_at(Vector2(100, 0))
	var plain: EnemyController = _enemy_at(Vector2(100, 600))
	StatusEffects.apply_freeze(frozen, 5.0)
	var hp_f: float = _hp(frozen)
	var hp_p: float = _hp(plain)
	cat.blast(frozen.global_position, 90.0, 20.0)
	cat.blast(plain.global_position, 90.0, 20.0)
	assert_float(hp_p - _hp(plain)).is_equal_approx(20.0, 0.01)
	assert_float(hp_f - _hp(frozen)).append_failure_message("Shatter x2").is_equal_approx(40.0, 0.01)
	# Ballista: a bolt along +x through the frozen enemy.
	var f2: EnemyController = _enemy_at(Vector2(120, 2000))
	StatusEffects.apply_freeze(f2, 5.0)
	var hp2: float = _hp(f2)
	var bolt: BallistaBolt = BallistaBolt.spawn(self, Vector2(0, 2000), Vector2.RIGHT, 400.0, 20.0)
	for i in 12:
		bolt._physics_process(1.0 / 60.0)
	assert_float(hp2 - _hp(f2)).is_equal_approx(40.0, 0.01)


func test_shatter_needs_frost_arrows_owned() -> void:
	_mgr.grant_ability("catapult")
	var cat: CatapultAbility = _mgr.get_ability_node("catapult") as CatapultAbility
	var frozen: EnemyController = _enemy_at(Vector2(100, 0))
	StatusEffects.apply_freeze(frozen, 5.0)
	var hp0: float = _hp(frozen)
	cat.blast(frozen.global_position, 90.0, 20.0)
	assert_float(hp0 - _hp(frozen)).is_equal_approx(20.0, 0.01)


func _player_with_sacred_ground() -> Array:
	var player: Player = auto_free(preload("res://scenes/player.tscn").instantiate())
	player.driven_externally = true
	add_child(player)
	player.global_position = Vector2(300, 0)
	_mgr.set_player_for_test(player)
	_mgr.grant_ability("sacred_ground")
	return [player, _mgr.get_ability_node("sacred_ground")]


func test_hallowed_heals_one_percent_per_burning_kill_inside_with_flame_arrows() -> void:
	var pair: Array = _player_with_sacred_ground()
	var player: Player = pair[0]
	var sacred: SacredGroundAbility = pair[1]
	sacred.global_position = player.global_position
	player.death_state.current_hp = 50.0
	sacred._on_burn_victim_died(player.global_position + Vector2(20, 0), 5.0, 1.0, "x")
	assert_float(player.death_state.current_hp).append_failure_message("no Flame Arrows, no heal").is_equal(50.0)
	_mgr.grant_ability("flame_arrows")
	sacred._on_burn_victim_died(player.global_position + Vector2(20, 0), 5.0, 1.0, "x")
	assert_float(player.death_state.current_hp).is_equal_approx(50.0 + player.death_state.max_hp * 0.01, 0.001)
	var hp1: float = player.death_state.current_hp
	sacred._on_burn_victim_died(player.global_position + Vector2(900, 0), 5.0, 1.0, "x")
	assert_float(player.death_state.current_hp).append_failure_message("outside the aura").is_equal(hp1)


func test_hallowed_aura_slows_by_fifteen_percent_with_frost_ward() -> void:
	var pair: Array = _player_with_sacred_ground()
	var player: Player = pair[0]
	var sacred: SacredGroundAbility = pair[1]
	var e: EnemyController = _enemy_at(player.global_position + Vector2(30, 0))
	SimClock.now += 1.0
	sacred._physics_process(0.016)
	assert_float(StatusEffects.speed_multiplier_for(e)).append_failure_message("no Frost Ward, no slow").is_equal(1.0)
	_mgr.grant_ability("frost_ward")
	SimClock.now += 0.5
	sacred._physics_process(0.016)
	assert_float(StatusEffects.speed_multiplier_for(e)).is_equal_approx(0.85, 0.0001)


func test_card_text_lists_a_synergy_only_once_its_partner_is_owned() -> void:
	assert_str(_mgr.describe_next("storm_bolt")["effect_text"]).not_contains("Conduction")
	_mgr.grant_ability("frost_ward")
	assert_str(_mgr.describe_next("storm_bolt")["effect_text"]).contains("Conduction (Frost Ward)")
	assert_str(_mgr.describe_next("frost_ward")["effect_text"]).not_contains("Conduction") # Storm Bolt not owned yet
	_mgr.grant_ability("storm_bolt")
	assert_str(_mgr.describe_next("frost_ward")["effect_text"]).contains("Conduction (Storm Bolt)")
	assert_array(_mgr.get_active_synergies("storm_bolt")).has_size(1)
	_mgr.grant_ability("frost_arrows")
	_mgr.grant_ability("ballista")
	assert_str(_mgr.describe_next("ballista")["effect_text"]).contains("Shatter (Frost Arrows)")
	assert_str(_mgr.describe_next("frost_arrows")["effect_text"]).contains("Shatter (Ballista)")


func test_every_synergy_table_entry_has_a_mirror_on_its_partner() -> void:
	for id in AbilitySynergy.TABLE.keys():
		for pair in AbilitySynergy.TABLE[id]:
			var back: bool = false
			for p2 in AbilitySynergy.TABLE.get(pair[0], []):
				if p2[0] == id:
					back = true
			assert_bool(back).append_failure_message("%s -> %s has no mirror" % [id, pair[0]]).is_true()
			assert_bool(AbilityCatalog.has(id) and AbilityCatalog.has(pair[0])).is_true()


# --- 5. repair ring --------------------------------------------------------------------

func _repair_setup() -> Array:
	var tower: Tower = auto_free(preload("res://scenes/tower.tscn").instantiate())
	add_child(tower)
	var repair: TowerRepair = auto_free(TowerRepair.new())
	add_child(repair)
	repair.set_tower_for_test(tower)
	var inv := RunInventory.new()
	inv.scrap_current = 10
	repair.set_run_inventory_for_test(inv)
	return [tower, repair, inv]


func test_the_repair_ring_is_possible_only_when_hurt_and_carrying_scrap() -> void:
	var parts: Array = _repair_setup()
	var tower: Tower = parts[0]
	var repair: TowerRepair = parts[1]
	var inv: RunInventory = parts[2]
	assert_bool(repair.can_repair()).append_failure_message("full health").is_false()
	tower.death_state.current_hp = tower.health.max_health - 50.0
	assert_bool(repair.can_repair()).is_true()
	inv.scrap_current = 0
	assert_bool(repair.can_repair()).append_failure_message("no Scrap").is_false()


func test_the_repair_ring_pulses_for_one_and_a_half_seconds_after_the_tower_loses_health() -> void:
	var parts: Array = _repair_setup()
	var tower: Tower = parts[0]
	var repair: TowerRepair = parts[1]
	var hp: float = tower.health.get_current_health()
	EventBus.emit_tower_damaged(0.0, hp, 0.0) # seeds the last-seen health
	assert_bool(repair.is_pulsing()).is_false()
	EventBus.emit_tower_damaged(30.0, hp - 30.0, 0.0)
	assert_bool(repair.is_pulsing()).is_true()
	SimClock.now += TowerRepair.PULSE_SECONDS + 0.1
	assert_bool(repair.is_pulsing()).is_false()


# --- 7. Bomber cue ---------------------------------------------------------------------

func test_the_bomber_is_palette_swapped_not_purple_and_shows_a_lit_stick_until_it_throws() -> void:
	var b: EnemyController = BomberScene.instantiate() as EnemyController
	b.driven_externally = true
	add_child(b)
	auto_free(b)
	var sprite: AnimatedSprite2D = b.get_node("Visuals/AnimatedSprite2D") as AnimatedSprite2D
	assert_object(sprite.material).is_not_null()
	assert_float(float((sprite.material as ShaderMaterial).get_shader_parameter("swap_hue"))).is_equal_approx(0.58, 0.0001)
	assert_object(sprite.modulate).is_equal(Color.WHITE)
	var rp: Color = b.definition.readability_profile.reserved_colour
	assert_bool(rp.b > rp.r and rp.b > 0.85).append_failure_message("steel blue, not the Opportunist purple").is_true()
	var behavior: BomberBehavior = b.behavior as BomberBehavior
	var cue: BomberThrowCue = b.get_node("ThrowCue") as BomberThrowCue
	assert_object(cue).is_not_null()
	assert_bool(behavior.is_armed()).is_true()
	behavior._last_throw_time = SimClock.now
	assert_bool(behavior.is_armed()).append_failure_message("hidden while the dynamite is in the air").is_false()
	SimClock.now += BomberBehavior.RELOAD_HIDE_SECONDS + 0.01
	assert_bool(behavior.is_armed()).is_true()

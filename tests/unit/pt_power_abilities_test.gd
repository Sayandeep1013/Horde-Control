extends GdUnitTestSuite

## PT-POWER (docs/33 §D, decisions D350-D359): the five Archero-style abilities (Diagonal
## Arrows, Ricochet, Lightning Sprite, Meteor Shower, Blade Circle), Rear Arrow, the bigger
## Whirling Axes (boomerang), damage-source tagging, scaling with the existing damage terms
## and the cluster search that must stay cheap against a swarm. Real Player / AutoWeapon /
## enemy scenes; SimClock.now is only ever advanced, never reset.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const DT: float = 1.0 / 60.0
const BIG_HP: float = 1000000.0

var _mgr: AbilityManager
var _us: UpgradeSystem
var _player: Player
var _weapon: AutoWeapon


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	_player = auto_free(preload("res://scenes/player.tscn").instantiate())
	_player.driven_externally = true
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_weapon = _player.get_node("AutoWeapon") as AutoWeapon
	_weapon.driven_externally = true
	_mgr = auto_free(AbilityManager.new())
	add_child(_mgr)
	_mgr.set_player_for_test(_player)
	_us = auto_free(UpgradeSystem.new())
	add_child(_us)
	_us.set_ability_manager_for_test(_mgr)
	_us.set_player_weapon_for_test(_weapon)
	_us.set_player_for_test(_player)
	_mgr.set_upgrade_system_for_test(_us)


func after_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func _enemy(pos: Vector2, hp: float = BIG_HP) -> EnemyController:
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = pos
	e.death_state.max_hp = hp
	e.death_state.current_hp = hp
	EntityRegistry.update_position(e, pos)
	return e


func _damage_of(source: String) -> float:
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == source:
			return row["damage"]
	return 0.0


func _grant(id: String, level: int, rarity: float = 1.0) -> void:
	for i in level:
		_mgr.grant_ability(id, rarity)


func _live_arrows() -> Array:
	return _weapon.get_pool_for_test()._active.duplicate()


func _fire_volley() -> void:
	SimClock.now += 1.0
	_weapon.physics_step(DT)


func _angles_deg(arrows: Array) -> Array[float]:
	var out: Array[float] = []
	for a in arrows:
		out.append(snappedf(rad_to_deg((a as PlayerProjectile)._velocity.angle()), 0.1))
	out.sort()
	return out


# --- Diagonal Arrows -------------------------------------------------------------

func test_diagonal_arrows_level_one_adds_two_arrows_at_plus_minus_45() -> void:
	_enemy(Vector2(100, 0))
	_grant("diagonal_arrows", 1)
	_fire_volley()
	var arrows: Array = _live_arrows()
	assert_int(arrows.size()).is_equal(3) # the aimed arrow + 2
	assert_array(_angles_deg(arrows)).is_equal([-45.0, 0.0, 45.0])
	var tagged: int = 0
	for a in arrows:
		if (a as PlayerProjectile).source_id == "diagonal_arrows":
			tagged += 1
			assert_float((a as PlayerProjectile)._damage).is_equal_approx(7.0, 0.001) # 70% of the 10-damage arrow
	assert_int(tagged).is_equal(2)


func test_diagonal_arrows_level_three_adds_four_more_at_30_and_60() -> void:
	_enemy(Vector2(100, 0))
	_grant("diagonal_arrows", 3)
	_fire_volley()
	var arrows: Array = _live_arrows()
	assert_int(arrows.size()).is_equal(7)
	assert_array(_angles_deg(arrows)).is_equal([-60.0, -45.0, -30.0, 0.0, 30.0, 45.0, 60.0])


func test_diagonal_arrows_stop_when_the_ability_is_removed() -> void:
	_grant("diagonal_arrows", 1)
	assert_int(_weapon.get_volley_extras("diagonal_arrows").size()).is_equal(2)
	(_mgr.get_ability_node("diagonal_arrows") as Node).free()
	assert_int(_weapon.get_volley_extras("diagonal_arrows").size()).is_equal(0)


# --- Rear Arrow ------------------------------------------------------------------

func test_rear_arrow_rank_one_fires_one_arrow_behind_and_rank_two_a_pair() -> void:
	_enemy(Vector2(100, 0))
	_us.apply_rank("rear_arrow", 1.0)
	_fire_volley()
	var arrows: Array = _live_arrows()
	assert_int(arrows.size()).is_equal(2)
	var rear: PlayerProjectile = null
	for a in arrows:
		if (a as PlayerProjectile).source_id == "rear_arrow":
			rear = a
	assert_object(rear).is_not_null()
	assert_float(absf(rad_to_deg(rear._velocity.angle()))).is_equal_approx(180.0, 0.01)
	assert_bool(rear._velocity.x < 0.0).is_true()
	_us.apply_rank("rear_arrow", 1.0)
	var before: int = _live_arrows().size()
	_fire_volley()
	assert_int(_live_arrows().size() - before).is_equal(3) # aimed + 2 behind
	assert_bool(_us.is_maxed("rear_arrow")).is_true() # max rank 2


func test_rear_arrow_card_text_is_honest_and_it_starts_unlocked() -> void:
	var honest: Dictionary = _us.get_honest_card_value("rear_arrow", 2.2)
	assert_str(honest["kind"]).is_equal("count")
	assert_bool(honest["rarity_scaled"]).is_false() # a count: rarity must not rewrite "+1 arrow"
	assert_bool(_us.get_definition("rear_arrow").is_unlock).is_false()


# --- Ricochet --------------------------------------------------------------------

func _line_of_enemies(n: int, gap: float = 100.0) -> Array[EnemyController]:
	var out: Array[EnemyController] = []
	for i in n:
		out.append(_enemy(Vector2(100.0 + gap * float(i), 0.0)))
	return out


func test_ricochet_level_one_bounces_to_two_enemies_at_70_percent() -> void:
	var line: Array[EnemyController] = _line_of_enemies(5)
	_grant("ricochet", 1)
	var node: RicochetAbility = _mgr.get_ability_node("ricochet") as RicochetAbility
	node._on_arrow_hit(line[0], 10.0)
	assert_float(_damage_of("ricochet")).is_equal_approx(14.0, 0.001) # 2 bounces x 7
	assert_float(line[0].death_state.current_hp).is_equal(BIG_HP) # the struck enemy itself is not hit again
	assert_float(line[1].death_state.current_hp).is_equal_approx(BIG_HP - 7.0, 0.001)
	assert_float(line[2].death_state.current_hp).is_equal_approx(BIG_HP - 7.0, 0.001)
	assert_float(line[3].death_state.current_hp).is_equal(BIG_HP) # only two bounces at level 1


func test_ricochet_level_five_bounces_to_five() -> void:
	var line: Array[EnemyController] = _line_of_enemies(8)
	_grant("ricochet", 5)
	(_mgr.get_ability_node("ricochet") as RicochetAbility)._on_arrow_hit(line[0], 10.0)
	assert_float(_damage_of("ricochet")).is_equal_approx(35.0, 0.001)
	assert_float(line[5].death_state.current_hp).is_equal_approx(BIG_HP - 7.0, 0.001)
	assert_float(line[6].death_state.current_hp).is_equal(BIG_HP)


func test_ricochet_never_bounces_beyond_its_range() -> void:
	var a: EnemyController = _enemy(Vector2(100, 0))
	var far: EnemyController = _enemy(Vector2(100.0 + 400.0, 0.0)) # 400 px: out of the 220 px level-1 range
	_grant("ricochet", 1)
	(_mgr.get_ability_node("ricochet") as RicochetAbility)._on_arrow_hit(a, 10.0)
	assert_float(far.death_state.current_hp).is_equal(BIG_HP)
	assert_float(_damage_of("ricochet")).is_equal(0.0)


func test_ricochet_applies_frost_arrows_slow_on_the_bounce_and_without_frost_there_is_none() -> void:
	var line: Array[EnemyController] = _line_of_enemies(3)
	_grant("ricochet", 1)
	(_mgr.get_ability_node("ricochet") as RicochetAbility)._on_arrow_hit(line[0], 10.0)
	assert_bool(StatusEffects.is_slowed(line[1])).is_false() # falsification: no Frost Arrows, no slow
	_grant("frost_arrows", 1)
	(_mgr.get_ability_node("ricochet") as RicochetAbility)._on_arrow_hit(line[0], 10.0)
	assert_bool(StatusEffects.is_slowed(line[1])).is_true()
	assert_bool(StatusEffects.is_slowed(line[2])).is_true()
	assert_bool(StatusEffects.is_slowed(line[0])).is_false() # the arrow's own target is Frost Arrows' job, not the bounce's


func test_ricochet_chain_reaction_text_appears_once_the_partner_is_owned() -> void:
	_grant("frost_arrows", 1)
	assert_str(_mgr.describe_next("ricochet")["effect_text"]).contains("Chain Reaction (Frost Arrows)")
	assert_str(_mgr.describe_next("flame_arrows")["effect_text"]).not_contains("Chain Reaction") # Ricochet not owned


# --- Lightning Sprite ------------------------------------------------------------

func _run_sprite(seconds: float) -> void:
	var steps: int = int(round(seconds / DT))
	for i in steps:
		SimClock.now += DT
		for n in _mgr.get_children():
			n._physics_process(DT)


func test_lightning_sprite_fires_a_chain_bolt_every_1_2_seconds_at_level_one() -> void:
	_enemy(Vector2(200, 0))
	_grant("lightning_sprite", 1)
	_run_sprite(2.5) # fires at 0.4 s and 1.6 s; the next at 2.8 s
	assert_float(_damage_of("lightning_sprite")).is_equal_approx(52.0, 0.01) # two bolts of 26 on the lone enemy


func test_lightning_sprite_level_five_fires_twice_as_often_and_hits_harder() -> void:
	_enemy(Vector2(200, 0))
	_grant("lightning_sprite", 5)
	_run_sprite(2.5) # 0.4, 1.0, 1.6, 2.2: four bolts of 52
	assert_float(_damage_of("lightning_sprite")).is_equal_approx(208.0, 0.01)


func test_lightning_sprite_chain_reaches_the_configured_number_of_enemies() -> void:
	var line: Array[EnemyController] = _line_of_enemies(8, 60.0)
	_grant("lightning_sprite", 1)
	var node: LightningSpriteAbility = _mgr.get_ability_node("lightning_sprite") as LightningSpriteAbility
	var struck: Array[Node2D] = node.fire_at(line[0], Vector2.ZERO)
	assert_int(struck.size()).is_equal(3) # first + 2 chains
	_grant("lightning_sprite", 4)
	struck = node.fire_at(line[0], Vector2.ZERO)
	assert_int(struck.size()).is_equal(5) # first + 4 chains at level 5


func test_lightning_sprite_holds_fire_with_no_enemy_in_range() -> void:
	_enemy(Vector2(2000, 0))
	_grant("lightning_sprite", 1)
	_run_sprite(2.0)
	assert_float(_damage_of("lightning_sprite")).is_equal(0.0)


# --- Meteor Shower ---------------------------------------------------------------

func _telegraphs() -> Array[GroundTelegraph]:
	var out: Array[GroundTelegraph] = []
	for c in _player.get_parent().get_children():
		if c is GroundTelegraph and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _meteors() -> Array[MeteorStrike]:
	var out: Array[MeteorStrike] = []
	for c in _player.get_parent().get_children():
		if c is MeteorStrike and not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_meteor_shower_telegraphs_three_meteors_then_lands_180_damage_in_120_px() -> void:
	var cluster: Array[EnemyController] = []
	for i in 5:
		cluster.append(_enemy(Vector2(250.0 + 10.0 * float(i), 20.0 * float(i))))
	var outside: EnemyController = _enemy(Vector2(700.0, 0.0)) # beyond the 520 px search range: untouched
	_grant("meteor_shower", 1)
	var node: MeteorShowerAbility = _mgr.get_ability_node("meteor_shower") as MeteorShowerAbility
	assert_int(node.cast()).is_equal(3)
	assert_int(_telegraphs().size()).is_equal(3) # every meteor is telegraphed before it lands
	assert_float(_damage_of("meteor_shower")).is_equal(0.0) # nothing yet: telegraph first
	assert_float(_telegraphs()[0].radius).is_equal_approx(120.0, 0.001)
	SimClock.now += 0.95
	for m in _meteors():
		m._physics_process(DT)
	assert_float(cluster[0].death_state.current_hp).is_equal_approx(BIG_HP - 180.0, 0.01) # the first meteor, 180
	assert_float(outside.death_state.current_hp).is_equal(BIG_HP)
	SimClock.now += 0.6 # the staggered rest land too
	for m in _meteors():
		m._physics_process(DT)
	assert_int(_meteors().size()).is_equal(0)
	assert_float(_damage_of("meteor_shower")).is_greater(180.0 * 5.0 - 0.01)


func test_meteor_shower_level_five_drops_six_and_spreads_over_separate_clusters() -> void:
	var left: EnemyController = _enemy(Vector2(-250, 0))
	var right: EnemyController = _enemy(Vector2(250, 0))
	_enemy(Vector2(255, 10))
	_grant("meteor_shower", 5)
	var node: MeteorShowerAbility = _mgr.get_ability_node("meteor_shower") as MeteorShowerAbility
	assert_int(node.cast()).is_equal(6)
	SimClock.now += 2.5
	for m in _meteors():
		m._physics_process(DT)
	assert_float(left.death_state.current_hp).is_less(BIG_HP) # the lone left enemy still gets a meteor: covered clusters are skipped
	assert_float(right.death_state.current_hp).is_less(BIG_HP)


func test_meteor_shower_waits_for_an_enemy_and_for_its_interval() -> void:
	_grant("meteor_shower", 1)
	var node: MeteorShowerAbility = _mgr.get_ability_node("meteor_shower") as MeteorShowerAbility
	assert_int(node.cast()).is_equal(0) # nobody in range
	assert_int(_meteors().size()).is_equal(0)


# --- Blade Circle ----------------------------------------------------------------

func test_blade_circle_ring_is_220_px_with_four_to_eight_blades() -> void:
	_grant("blade_circle", 1)
	var node: BladeCircleAbility = _mgr.get_ability_node("blade_circle") as BladeCircleAbility
	node.global_position = Vector2.ZERO
	var pos: Array[Vector2] = node.blade_positions()
	assert_int(pos.size()).is_equal(4)
	for p in pos:
		assert_float(p.length()).is_equal_approx(220.0, 0.01)
	_grant("blade_circle", 4)
	assert_int(node.blade_positions().size()).is_equal(8)


func test_blade_circle_hits_an_enemy_on_the_ring_once_per_0_4_seconds_and_spares_the_inside() -> void:
	_grant("blade_circle", 1)
	var node: BladeCircleAbility = _mgr.get_ability_node("blade_circle") as BladeCircleAbility
	node.global_position = Vector2.ZERO
	var blade: Vector2 = node.blade_positions()[0]
	var on_ring: EnemyController = _enemy(blade + Vector2(10, 0))
	var inside: EnemyController = _enemy(Vector2(60, 0)) # well inside the 220 px ring, away from every blade
	SimClock.now += 1.0
	node._physics_process(0.0)
	assert_float(on_ring.death_state.current_hp).is_equal_approx(BIG_HP - 28.0, 0.01)
	assert_float(inside.death_state.current_hp).is_equal(BIG_HP)
	node._physics_process(0.0) # same instant: the 0.4 s re-hit gate holds
	assert_float(on_ring.death_state.current_hp).is_equal_approx(BIG_HP - 28.0, 0.01)
	SimClock.now += 0.5
	node._physics_process(0.0)
	assert_float(on_ring.death_state.current_hp).is_equal_approx(BIG_HP - 56.0, 0.01)
	assert_bool(_damage_of("blade_circle") > 0.0).is_true()


# --- Whirling Axes: bigger, wider, boomerang ---------------------------------------

func test_whirling_axes_are_bigger_wider_and_start_at_two() -> void:
	_grant("whirling_axes", 1)
	var node: WhirlingAxesAbility = _mgr.get_ability_node("whirling_axes") as WhirlingAxesAbility
	assert_float(WhirlingAxesAbility.SPRITE_SCALE).is_equal(2.0)
	assert_int(node.axe_count()).is_equal(2)
	assert_float(node._orbit_radius()).is_equal_approx(110.0, 0.001) # level 1: 110 px (was 72)
	assert_float(node.v("hit_radius")).is_equal(44.0) # was 22
	_grant("whirling_axes", 4)
	assert_float(node._orbit_radius()).is_equal_approx(160.0, 0.001)


func test_whirling_axes_fly_out_to_280_and_back_only_from_level_three() -> void:
	_grant("whirling_axes", 2)
	var node: WhirlingAxesAbility = _mgr.get_ability_node("whirling_axes") as WhirlingAxesAbility
	assert_bool(node.boomerang_enabled()).is_false()
	assert_float(node.axe_reach(0, 0.5)).is_equal_approx(node._orbit_radius(), 0.001) # level 2: orbit only
	_grant("whirling_axes", 1)
	assert_bool(node.boomerang_enabled()).is_true()
	var r0: float = node._orbit_radius()
	assert_float(node.axe_reach(0, 0.5)).is_equal_approx(280.0, 0.01) # mid-throw: out at 280 px
	assert_float(node.axe_reach(0, 0.0)).is_equal_approx(r0, 0.01) # leaving
	assert_float(node.axe_reach(0, 1.0)).is_equal_approx(r0, 0.01) # back home
	assert_float(node.axe_reach(0, 1.7)).is_equal_approx(r0, 0.01) # idle until the next throw
	assert_float(node.axe_reach(0, 2.5 + 0.5)).is_equal_approx(280.0, 0.01) # every 2.5 s
	# the axes leave one after another, not together
	assert_float(node.axe_reach(1, 0.5)).is_less(280.0)


func test_whirling_axes_hit_an_enemy_at_boomerang_range_that_the_orbit_alone_misses() -> void:
	_grant("whirling_axes", 2) # no boomerang yet
	var node: WhirlingAxesAbility = _mgr.get_ability_node("whirling_axes") as WhirlingAxesAbility
	node.global_position = Vector2.ZERO
	var e: EnemyController = _enemy(Vector2(270, 0))
	var base: float = ceilf(SimClock.now / 2.5) * 2.5 # an instant where axe 0 starts a throw
	node._angle = 0.0
	SimClock.now = base + 0.5
	node._physics_process(0.0)
	assert_float(e.death_state.current_hp).is_equal(BIG_HP) # level 2: the 122 px orbit cannot reach it
	_grant("whirling_axes", 1)
	node._angle = 0.0
	SimClock.now = base + 2.5 + 0.5 # axe 0 is at the far end of its throw: 280 px along +x
	node._physics_process(0.0)
	assert_float(e.death_state.current_hp).is_less(BIG_HP)


# --- Scaling with the existing damage terms ----------------------------------------

func test_player_abilities_scale_with_heavy_rounds_valor_and_the_meta_term() -> void:
	_grant("blade_circle", 1)
	var node: BladeCircleAbility = _mgr.get_ability_node("blade_circle") as BladeCircleAbility
	node.global_position = Vector2.ZERO
	assert_float(node.dmg()).is_equal_approx(28.0, 0.001)
	_weapon.set_damage_multiplier(1.4) # Heavy Rounds
	_weapon.set_damage_term("valor", 1.1) # Sanctuary Valor
	_mgr.set_ability_damage_multiplier(1.15) # meta
	assert_float(node.dmg()).is_equal_approx(28.0 * 1.4 * 1.1 * 1.15, 0.001)


func test_crit_doubles_a_new_ability_hit() -> void:
	var e: EnemyController = _enemy(Vector2(300, 0))
	_grant("lightning_sprite", 1)
	AbilityDamage.forced_crit = 1
	(_mgr.get_ability_node("lightning_sprite") as LightningSpriteAbility).fire_at(e, Vector2.ZERO)
	assert_float(BIG_HP - e.death_state.current_hp).is_equal_approx(52.0, 0.001) # 26 x 2


func test_rarity_scales_the_new_abilities_damage_but_not_their_counts_or_cooldowns() -> void:
	assert_float(AbilityCatalog.value("meteor_shower", "damage", 1, 2.2)).is_equal_approx(180.0 * 2.2, 0.001)
	assert_float(AbilityCatalog.value("meteor_shower", "meteors", 1, 2.2)).is_equal(3.0)
	assert_float(AbilityCatalog.value("meteor_shower", "interval", 1, 2.2)).is_equal(6.0)
	assert_float(AbilityCatalog.value("ricochet", "fraction", 1, 2.2)).is_equal(0.7) # "70%" is not rewritten by rarity
	assert_float(AbilityCatalog.value("blade_circle", "count", 5, 2.2)).is_equal(8.0)


# --- Slots, ids and card text --------------------------------------------------------

func test_new_ids_are_player_abilities_with_icon_paths_and_unlock_flags() -> void:
	for id in ["diagonal_arrows", "ricochet", "lightning_sprite", "meteor_shower", "blade_circle"]:
		assert_bool(AbilityIds.is_player_ability(id)).append_failure_message(id).is_true()
		assert_str(AbilityIds.icon_path(id)).is_equal("res://assets/ui/icons/icon_%s.png" % id)
		assert_bool(AbilityCatalog.has(id)).is_true()
		assert_bool(_us.get_definition(id).is_ability_card()).is_true()
	var unlocked: int = 0
	for id in ["diagonal_arrows", "ricochet", "lightning_sprite", "meteor_shower", "blade_circle", "rear_arrow"]:
		if not _us.get_definition(id).is_unlock:
			unlocked += 1
	assert_int(unlocked).is_equal(3) # D357: Diagonal Arrows, Blade Circle and Rear Arrow start unlocked


func test_the_six_player_slots_can_hold_the_new_abilities_and_a_seventh_is_refused() -> void:
	for id in ["diagonal_arrows", "ricochet", "lightning_sprite", "meteor_shower", "blade_circle", "flame_arrows"]:
		assert_int(_mgr.grant_ability(id)).is_equal(1)
	assert_int(_mgr.grant_ability("caltrops")).is_equal(0)
	assert_int(_mgr.get_owned_abilities("player").size()).is_equal(6)


func test_card_text_states_the_real_numbers() -> void:
	assert_str(AbilityCatalog.describe("diagonal_arrows", 1)).contains("2 arrows").contains("45")
	assert_str(AbilityCatalog.describe("diagonal_arrows", 3)).contains("6 arrows")
	assert_str(AbilityCatalog.describe("ricochet", 5)).contains("5 nearby enemies").contains("70%")
	assert_str(AbilityCatalog.describe("lightning_sprite", 1)).contains("1.2s").contains("26").contains("2 more")
	assert_str(AbilityCatalog.describe("meteor_shower", 5)).contains("6 meteors").contains("180 damage").contains("120 px").contains("3.5s")
	assert_str(AbilityCatalog.describe("blade_circle", 5)).contains("8 blades").contains("220 px")
	assert_str(AbilityCatalog.describe("whirling_axes", 3)).contains("fly out 280 px")
	assert_str(AbilityCatalog.describe("whirling_axes", 2)).not_contains("fly out")
	assert_int(AbilityCatalog.dynamite_count(1)).is_equal(2)
	assert_int(AbilityCatalog.dynamite_count(3)).is_equal(3)
	assert_int(AbilityCatalog.dynamite_count(5)).is_equal(4)


func test_shadow_step_card_routes_to_the_player_and_is_a_count_card() -> void:
	_us.apply_rank("shadow_step", 1.0)
	assert_float(_player._shadow_step_damage).is_equal(30.0)
	assert_float(_player._shadow_step_invuln).is_equal_approx(0.1, 0.0001)
	_us.apply_rank("shadow_step", 1.0)
	_us.apply_rank("shadow_step", 1.0)
	assert_float(_player._shadow_step_damage).is_equal(70.0)
	assert_float(_player._shadow_step_invuln).is_equal_approx(0.3, 0.0001)
	assert_str(_us.get_honest_card_value("shadow_step", 2.2)["kind"]).is_equal("count")


# --- Swarm cost ----------------------------------------------------------------------

func test_densest_in_finds_the_dense_cluster_in_a_big_crowd_with_bounded_work() -> void:
	var crowd: Array[Node2D] = []
	for i in 400: # a thin, wide spread ...
		var n: Node2D = auto_free(Node2D.new())
		add_child(n)
		n.global_position = Vector2(float(i % 40) * 90.0, float(i / 40) * 90.0)
		crowd.append(n)
	for i in 60: # ... and a 60-strong knot at one corner
		var k: Node2D = auto_free(Node2D.new())
		add_child(k)
		k.global_position = Vector2(5000.0, 5000.0) + Vector2(float(i % 8) * 10.0, float(i / 8) * 10.0)
		crowd.append(k)
	var best: Dictionary = AbilityDamage.densest_in(crowd, 120.0)
	assert_bool(best.is_empty()).is_false()
	assert_float((best["position"] as Vector2).x).is_greater(4900.0) # the knot, not the sparse field
	assert_int(int(best["count"])).is_greater_equal(40)
	assert_int(AbilityDamage.CLUSTER_CENTER_SAMPLES).is_less_equal(40)


func test_densest_in_is_exact_for_a_small_group() -> void:
	var pts: Array[Node2D] = []
	for p in [Vector2(0, 0), Vector2(30, 0), Vector2(60, 0), Vector2(1000, 0)]:
		var n: Node2D = auto_free(Node2D.new())
		add_child(n)
		n.global_position = p
		pts.append(n)
	var best: Dictionary = AbilityDamage.densest_in(pts, 70.0)
	assert_int(int(best["count"])).is_equal(3)

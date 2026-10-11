extends GdUnitTestSuite

## v1.0 WP-COMBAT: ability framework (docs/31 §4.1-§4.4): levels 1-5, slot
## limits, card text, UpgradeSystem routing, passives, the 45% Draft weighting
## and the War Chest rarity floor.

const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")

var _mgr: AbilityManager
var _us: UpgradeSystem


func before_test() -> void:
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	_mgr = auto_free(AbilityManager.new())
	add_child(_mgr)
	_us = auto_free(UpgradeSystem.new())
	add_child(_us)
	_us.set_ability_manager_for_test(_mgr)
	_mgr.set_upgrade_system_for_test(_us)


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false
	StatusEffects.reset()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()


func test_new_ability_starts_at_level_one_and_levels_to_five_then_refuses() -> void:
	assert_int(_mgr.grant_ability("flame_arrows")).is_equal(1)
	for i in 4:
		_mgr.grant_ability("flame_arrows")
	assert_int(_mgr.get_level("flame_arrows")).is_equal(5)
	assert_int(_mgr.grant_ability("flame_arrows")).is_equal(0)
	assert_int(_mgr.get_level("flame_arrows")).is_equal(5)


func test_player_slot_limit_is_four_and_tower_limit_is_three_and_independent() -> void:
	for id in ["flame_arrows", "frost_arrows", "whirling_axes", "dynamite_satchel"]:
		assert_int(_mgr.grant_ability(id)).is_equal(1)
	assert_bool(_mgr.can_grant("caltrops")).is_false()
	assert_int(_mgr.grant_ability("caltrops")).is_equal(0)
	assert_bool(_mgr.can_grant("flame_arrows")).is_true() # owned abilities still level
	for id in ["ballista", "catapult", "frost_ward"]:
		assert_int(_mgr.grant_ability(id)).is_equal(1)
	assert_bool(_mgr.can_grant("spiked_palisade")).is_false()
	assert_int(_mgr.get_owned_abilities("player").size()).is_equal(4)
	assert_int(_mgr.get_owned_abilities("tower").size()).is_equal(3)


func test_get_owned_abilities_reports_id_and_level() -> void:
	_mgr.grant_ability("whirling_axes")
	_mgr.grant_ability("whirling_axes")
	var owned: Array[Dictionary] = _mgr.get_owned_abilities("player")
	assert_int(owned.size()).is_equal(1)
	assert_str(String(owned[0]["id"])).is_equal("whirling_axes")
	assert_int(owned[0]["level"]).is_equal(2)
	assert_int(_mgr.get_owned_abilities("tower").size()).is_equal(0)


func test_leveling_emits_ability_changed() -> void:
	var got: Array = []
	_mgr.ability_changed.connect(func(id: String, lvl: int) -> void: got.append([id, lvl]))
	_mgr.grant_ability("ballista")
	_mgr.grant_ability("ballista")
	assert_array(got).is_equal([["ballista", 1], ["ballista", 2]])


func test_describe_next_says_new_ability_then_level_arrow_and_honest_values() -> void:
	var first: Dictionary = _mgr.describe_next("whirling_axes")
	assert_str(first["level_text"]).is_equal("NEW ABILITY")
	assert_str(first["effect_text"]).contains("14 damage")
	_mgr.grant_ability("whirling_axes")
	var second: Dictionary = _mgr.describe_next("whirling_axes")
	assert_str(second["level_text"]).is_equal("Lv 1 → 2")
	assert_str(second["effect_text"]).contains("2 orbiting axes")


func test_rarity_scales_ability_damage_but_not_cooldown() -> void:
	var common_dmg: float = AbilityCatalog.value("dynamite_satchel", "damage", 1, 1.0)
	var epic_dmg: float = AbilityCatalog.value("dynamite_satchel", "damage", 1, 2.2)
	assert_float(epic_dmg).is_equal_approx(common_dmg * 2.2, 0.001)
	assert_float(AbilityCatalog.value("dynamite_satchel", "interval", 1, 2.2)).is_equal(AbilityCatalog.value("dynamite_satchel", "interval", 1, 1.0))
	_mgr.grant_ability("dynamite_satchel", 2.2)
	var node: AbilityNode = _mgr.get_ability_node("dynamite_satchel")
	assert_float(node.v("damage")).is_equal_approx(common_dmg * 2.2, 0.001)


func test_upgrade_system_levels_abilities_through_cards_and_text_is_honest() -> void:
	assert_bool(_us.apply_rank("ballista", 1.0)).is_true()
	assert_int(_mgr.get_level("ballista")).is_equal(1)
	assert_int(_us.get_current_rank("ballista")).is_equal(1)
	var honest: Dictionary = _us.get_honest_card_value("ballista", 1.5)
	assert_str(honest["level_text"]).is_equal("Lv 1 → 2")
	assert_str(honest["effect_text"]).contains("67") # Ballista level 2 = 44.5 (34 to 76 over five levels, WP-BALANCE), x1.5 rarity = 66.75: the text must show the scaled value
	assert_bool(_us.apply_rank("ballista", 1.5)).is_true()
	assert_int(_mgr.get_level("ballista")).is_equal(2)


func test_full_slots_hide_unowned_ability_cards_from_the_draft_pool() -> void:
	for id in ["flame_arrows", "whirling_axes", "dynamite_satchel", "caltrops"]:
		_us.apply_rank(id, 1.0)
	var ids: Array[String] = []
	for d in _us.get_offerable_upgrades(ContractEnums.PoolOwnership.Player):
		ids.append(d.unique_id)
	assert_array(ids).contains(["flame_arrows"]) # owned: can level
	assert_array(ids).not_contains(["frost_arrows"]) # gated anyway
	for d in _us.get_offerable_upgrades(ContractEnums.PoolOwnership.Player):
		if d.is_ability_card():
			assert_int(_us.get_current_rank(d.unique_id)).is_greater(0)
	assert_bool(_us.apply_rank("storm_bolt", 1.0)).is_false() # refused: no slot (and still locked)


func test_unlock_gating_flags() -> void:
	for id in ["frost_arrows", "storm_bolt", "sacred_ground", "catapult", "spiked_palisade", "tower_volley"]:
		assert_bool(_us.get_definition(id).is_unlock).append_failure_message(id).is_true()
	for id in ["multishot", "piercing_arrows", "flame_arrows", "whirling_axes", "dynamite_satchel", "caltrops", "ballista", "frost_ward"]:
		assert_bool(_us.get_definition(id).is_unlock).append_failure_message(id).is_false()


func test_passives_sum_into_manager_multipliers_with_floors() -> void:
	_us.apply_rank("keen_eye", 1.0)
	_us.apply_rank("keen_eye", 1.0)
	assert_float(_mgr.get_crit_chance()).is_equal_approx(0.12, 0.0001)
	_us.apply_rank("blast_radius", 1.0)
	assert_float(_mgr.get_area_multiplier()).is_equal_approx(1.12, 0.0001)
	_us.apply_rank("battle_focus", 1.0)
	assert_float(_mgr.get_skill_cooldown_multiplier()).is_equal_approx(0.9, 0.0001)
	_us.apply_rank("ability_power", 1.0)
	assert_float(_mgr.get_player_ability_damage_multiplier()).is_equal_approx(1.1, 0.0001)
	_us.apply_rank("stone_mason", 1.0)
	assert_float(_mgr.get_repair_multiplier()).is_equal_approx(1.3, 0.0001)
	for i in 3:
		_us.apply_rank("leather_armor", 2.2) # epic x3 would be -46%: floor holds at the Register minimum
	assert_float(_mgr.get_damage_taken_multiplier()).is_greater_equal(AbilityManager.DAMAGE_TAKEN_FLOOR)


func test_passive_summary_lists_held_passives_with_ranks() -> void:
	_us.apply_rank("fleet_step", 1.0)
	_us.apply_rank("fleet_step", 1.0)
	var rows: Array[Dictionary] = _mgr.get_passive_summary()
	var found: Dictionary = {}
	for r in rows:
		if r["id"] == "fleet_step":
			found = r
	assert_int(found["rank"]).is_equal(2)
	assert_int(found["max_rank"]).is_equal(3)
	assert_str(found["pool"]).is_equal("player")
	assert_str(found["display_name"]).is_equal("Fleet Step")


func test_meta_hooks_feed_the_derived_multipliers() -> void:
	_mgr.set_skill_cooldown_multiplier(0.8)
	_mgr.set_skill_damage_multiplier(1.3)
	_mgr.set_ability_damage_multiplier(1.15)
	_mgr.set_tower_ability_damage_multiplier(1.3)
	_mgr.set_repair_multiplier(1.2)
	_mgr.add_crit_chance(0.04)
	assert_float(_mgr.get_skill_cooldown_multiplier()).is_equal_approx(0.8, 0.0001)
	assert_float(_mgr.get_skill_damage_multiplier()).is_equal_approx(1.3, 0.0001)
	assert_float(_mgr.get_player_ability_damage_multiplier()).is_equal_approx(1.15, 0.0001)
	assert_float(_mgr.get_tower_ability_damage_multiplier()).is_equal_approx(1.3, 0.0001)
	assert_float(_mgr.get_repair_multiplier()).is_equal_approx(1.2, 0.0001)
	assert_float(_mgr.get_crit_chance()).is_equal_approx(0.04, 0.0001)


func test_grant_free_random_ability_picks_an_unlocked_player_ability() -> void:
	var picked: String = _mgr.grant_free_random_ability(5)
	assert_bool(AbilityIds.PLAYER_ABILITIES.has(picked)).is_true()
	assert_bool(_us.get_definition(picked).is_unlock).is_false() # locked pool abilities are not eligible
	assert_int(_mgr.get_level(picked)).is_equal(1)


func test_storm_bolt_chains_to_the_requested_number_of_enemies() -> void:
	var enemies: Array[EnemyController] = []
	for i in 5:
		var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
		e.driven_externally = true
		add_child(e)
		auto_free(e)
		e.global_position = Vector2(60.0 * float(i + 1), 0.0)
		EntityRegistry.update_position(e, e.global_position)
		enemies.append(e)
	_mgr.grant_ability("storm_bolt") # tolerated here: the manager does not check unlocks, the Draft does
	var bolt: StormBoltAbility = _mgr.get_ability_node("storm_bolt") as StormBoltAbility
	var struck: Array[Node2D] = bolt.strike(enemies[0])
	assert_int(struck.size()).is_equal(3) # first target + 2 chains at level 1
	var total: float = 0.0
	for row in CombatStats.get_damage_by_source():
		if row["source_id"] == "storm_bolt":
			total = row["damage"]
	assert_float(total).is_greater(0.0)


# --- Draft: weighting and War Chest -----------------------------------------------

func _make_draft() -> DraftController:
	var inv: RunInventory = DraftTestHelpers.build_run_inventory()
	var pause: Node = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(pause)
	var clock: Node = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(clock)
	var wd: DraftFakeWaveDirector = auto_free(DraftFakeWaveDirector.new())
	add_child(wd)
	var draft: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(draft)
	draft.set_run_inventory_for_test(inv)
	draft.set_upgrade_system_for_test(_us)
	draft.set_wave_director_for_test(wd)
	draft.set_pause_authority_for_test(pause)
	draft.set_sim_clock_for_test(clock)
	return draft


func test_ability_cards_are_picked_about_45_percent_of_the_time_while_a_slot_is_free() -> void:
	var draft: DraftController = _make_draft()
	var pool: Array[UpgradeDefinition] = _us.get_offerable_upgrades(ContractEnums.PoolOwnership.Player)
	var abilities: int = 0
	for d in pool:
		if d.is_ability_card():
			abilities += 1
	assert_int(abilities).is_greater(0)
	var hits: int = 0
	var n: int = 600
	for i in n:
		if draft._pick_with_ability_weight(pool).is_ability_card():
			hits += 1
	var frac: float = float(hits) / float(n)
	assert_float(frac).append_failure_message("ability fraction %s" % frac).is_between(0.36, 0.54)


func test_with_full_slots_the_pick_is_uniform_over_the_pool_again() -> void:
	for id in ["flame_arrows", "whirling_axes", "dynamite_satchel", "caltrops"]:
		_us.apply_rank(id, 1.0)
	var draft: DraftController = _make_draft()
	var pool: Array[UpgradeDefinition] = _us.get_offerable_upgrades(ContractEnums.PoolOwnership.Player)
	var abilities: int = 0
	for d in pool:
		if d.is_ability_card():
			abilities += 1
	var expected: float = float(abilities) / float(pool.size())
	var hits: int = 0
	var n: int = 600
	for i in n:
		if draft._pick_with_ability_weight(pool).is_ability_card():
			hits += 1
	assert_float(float(hits) / float(n)).is_between(expected - 0.08, expected + 0.08)


func test_war_chest_opens_a_draft_with_every_card_at_least_rare() -> void:
	var draft: DraftController = _make_draft()
	draft.skip_lockout_for_test()
	EventBus.emit_war_chest_opened()
	assert_bool(draft.is_draft_showing_for_test()).is_true()
	var rarities: Array[int] = draft.get_current_card_rarities_for_test()
	assert_int(rarities.size()).is_greater(0)
	for r in rarities:
		assert_int(r).is_greater_equal(ContractEnums.Rarity.Rare)

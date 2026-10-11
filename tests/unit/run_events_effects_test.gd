extends GdUnitTestSuite
## Run events: the OFFERS (counts, rarity floors, pools) and the EFFECTS of every
## choice (docs/32 §A; Register "v1.0 Run Events"): Opening Pick and Armory,
## Patron's Boon, Sanctuary, Blood Pact costs and the five pacts.

const HandgunResource: WeaponDefinition = preload("res://data/weapons/handgun.tres")

var _w: Dictionary
var _events: RunEvents
var _player: Player
var _tower: Tower
var _us: UpgradeSystem
var _mgr: AbilityManager


func before_test() -> void:
	_w = RunEventsTestHelpers.build_world(self)
	_events = _w["events"]
	_player = _w["player"]
	_tower = _w["tower"]
	_us = _w["us"]
	_mgr = _w["mgr"]


func after_test() -> void:
	RunEventsTestHelpers.cleanup()


func _pact_offer(flawless: bool = false) -> Dictionary:
	return _events.build_offer({"kind": "blood_pact", "flawless": flawless})


func _pick_option(offer: Dictionary, option: String) -> int:
	var cards: Array = offer["cards"]
	for i in cards.size():
		if String(cards[i]["option"]) == option:
			return i
	return -1


# --- Opening Pick -------------------------------------------------------------------

func test_opening_pick_offers_three_unlocked_player_abilities_at_rare() -> void:
	_us.set_unlocked_card_ids(["frost_arrows", "storm_bolt", "sacred_ground"])
	var offer: Dictionary = _events.build_offer({"kind": "opening_pick"})
	var cards: Array = offer["cards"]
	assert_int(cards.size()).is_equal(3)
	var seen: Array[String] = []
	for c in cards:
		assert_int(int(c["rarity"])).is_equal(ContractEnums.Rarity.Rare)
		assert_float(float(c["multiplier"])).is_equal(1.5)
		assert_bool(AbilityIds.PLAYER_ABILITIES.has(String(c["id"]))).is_true()
		assert_bool(seen.has(String(c["id"]))).append_failure_message("a duplicate card in one offer").is_false()
		seen.append(String(c["id"]))


func test_opening_pick_never_offers_a_locked_ability() -> void:
	# Fresh profile: Frost Arrows, Storm Bolt and Sacred Ground are is_unlock cards.
	for s in range(1, 25):
		_events.run_seed = s
		_events._serials.clear()
		for id in RunEventsTestHelpers.card_ids(_events.build_offer({"kind": "opening_pick"})):
			assert_bool(["frost_arrows", "storm_bolt", "sacred_ground"].has(id)).append_failure_message("seed %d offered locked %s" % [s, id]).is_false()


func test_armory_makes_the_opening_pick_four_epic_cards() -> void:
	_us.set_unlocked_card_ids(["frost_arrows", "storm_bolt"])
	_events.armory_enabled = true
	var offer: Dictionary = _events.build_offer({"kind": "opening_pick"})
	var cards: Array = offer["cards"]
	assert_int(cards.size()).is_equal(4)
	for c in cards:
		assert_int(int(c["rarity"])).is_equal(ContractEnums.Rarity.Epic)
		assert_float(float(c["multiplier"])).is_equal(2.2)


func test_picking_an_opening_card_grants_that_ability_at_level_one() -> void:
	var offer: Dictionary = _events.build_offer({"kind": "opening_pick"})
	var id: String = String(offer["cards"][0]["id"])
	_events.resolve(offer, 0)
	assert_int(_mgr.get_level(id)).is_equal(1)
	assert_int(_mgr.owned_count(AbilityManager.SLOT_PLAYER)).append_failure_message("exactly one ability is granted").is_equal(1)
	assert_str(_events.opening_pick_id).is_equal(id)


func test_the_armory_no_longer_grants_a_free_ability_at_run_start() -> void:
	var loadout := MetaLoadout.new()
	loadout.armory_enabled = true
	var result: Dictionary = MetaLoadoutApplier.apply_group_hooks(loadout, get_tree(), true)
	assert_bool(bool(result["armory_granted"])).is_false()
	assert_int(_mgr.owned_count(AbilityManager.SLOT_PLAYER)).append_failure_message("Armory must not grant an ability outside the Opening Pick").is_equal(0)


# --- Patron's Boon -------------------------------------------------------------------

func test_patrons_boon_offers_two_epic_cards_and_lucky_coin_makes_it_three() -> void:
	var offer: Dictionary = _events.build_offer({"kind": "patrons_boon"})
	assert_int((offer["cards"] as Array).size()).is_equal(2)
	for c in offer["cards"]:
		assert_int(int(c["rarity"])).is_equal(ContractEnums.Rarity.Epic)
	_events.set_rules_for_test(false, false, true)
	assert_int((_events.build_offer({"kind": "patrons_boon"})["cards"] as Array).size()).is_equal(3)


func test_patrons_boon_draws_from_the_full_pool_abilities_included() -> void:
	var saw_ability: bool = false
	var saw_tower_card: bool = false
	for s in range(1, 40):
		_events.run_seed = s
		_events._serials.clear()
		for id in RunEventsTestHelpers.card_ids(_events.build_offer({"kind": "patrons_boon"})):
			saw_ability = saw_ability or AbilityIds.PLAYER_ABILITIES.has(id) or AbilityIds.TOWER_ABILITIES.has(id)
			saw_tower_card = saw_tower_card or _us.get_definition(id).pool_ownership == ContractEnums.PoolOwnership.Tower
	assert_bool(saw_ability).append_failure_message("40 seeds never offered an ability").is_true()
	assert_bool(saw_tower_card).append_failure_message("40 seeds never offered a Tower card").is_true()


func test_patrons_boon_applies_the_epic_value() -> void:
	var offer: Dictionary = {"kind": "patrons_boon", "cards": [{"type": "upgrade", "id": "heavy_rounds", "rarity": ContractEnums.Rarity.Epic, "multiplier": 2.2}]}
	_events.resolve(offer, 0)
	var weapon: AutoWeapon = _player.get_node("AutoWeapon")
	assert_float(weapon.get_damage_multiplier()).is_equal_approx(1.0 + 0.10 * 2.2, 0.0001)


# --- Sanctuary ----------------------------------------------------------------------------

func test_sanctuary_cards_are_fixed_mend_restore_valor() -> void:
	var offer: Dictionary = _events.build_offer({"kind": "sanctuary"})
	assert_array(RunEventsTestHelpers.card_ids(offer)).is_equal(["mend", "restore", "valor"])


func test_mend_heals_the_player_half_of_max_hp() -> void:
	_player.death_state.current_hp = 10.0
	_events.apply_blessing("mend")
	assert_float(_player.death_state.current_hp).is_equal_approx(10.0 + _player.death_state.max_hp * 0.5, 0.01)
	_events.apply_blessing("mend")
	assert_float(_player.death_state.current_hp).append_failure_message("overheal is discarded").is_equal(_player.death_state.max_hp)


func test_restore_repairs_the_tower_30_percent_and_refills_the_shield() -> void:
	_tower.death_state.current_hp = 100.0
	_tower.health.current_shield = 0.0
	_events.apply_blessing("restore")
	assert_float(_tower.health.get_current_health()).is_equal_approx(100.0 + _tower.health.max_health * 0.3, 0.01)
	assert_float(_tower.health.current_shield).is_equal(_tower.health.max_shield)


func test_valor_adds_ten_percent_damage_to_player_tower_and_abilities_and_composes() -> void:
	var weapon: AutoWeapon = _player.get_node("AutoWeapon")
	_us.apply_rank("heavy_rounds") # +10%
	_us.apply_rank("caliber") # Tower +10%
	_events.apply_blessing("valor")
	assert_float(weapon.get_effective_damage_per_shot()).is_equal_approx(10.0 * 1.1 * 1.1, 0.001)
	assert_float(_tower.weapon.get_damage_multiplier()).is_equal_approx(1.1 * 1.1, 0.001)
	assert_float(_mgr.get_player_ability_damage_multiplier()).append_failure_message("abilities scale with Valor").is_equal_approx(1.1 * 1.1, 0.001)
	assert_float(_mgr.get_tower_ability_damage_multiplier()).is_equal_approx(1.1 * 1.1, 0.001)
	_us.apply_rank("heavy_rounds") # the absolute Draft setter must not erase Valor
	assert_float(weapon.get_damage_multiplier()).is_equal_approx(1.2 * 1.1, 0.001)


func test_sanctuary_choice_is_recorded_for_the_build_panel() -> void:
	var offer: Dictionary = _events.build_offer({"kind": "sanctuary"})
	_events.resolve(offer, 2)
	assert_array(_events.get_summary()).is_equal([{"type": "sanctuary", "id": "valor"}])


# --- Blood Pact costs -----------------------------------------------------------------------

func test_pact_offer_shows_both_costs_in_numbers_and_a_refuse() -> void:
	var offer: Dictionary = _pact_offer()
	var cards: Array = offer["cards"]
	assert_int(cards.size()).is_equal(3)
	assert_int(int(cards[_pick_option(offer, "blood")]["amount"])).is_equal(int(round(_player.death_state.max_hp * 0.2)))
	assert_int(int(cards[_pick_option(offer, "tower")]["amount"])).is_equal(int(round(_tower.health.max_health * 0.2)))
	assert_int(_pick_option(offer, "refuse")).is_equal(2)
	assert_int(int(cards[2]["amount"])).is_equal(0)


func test_flawless_halves_the_cost_and_pactbound_stacks_to_a_quarter() -> void:
	var base: float = RunEvents.PACT_COST_FRACTION
	assert_float(RunEvents.pact_cost_fraction(false, false)).is_equal_approx(base, 0.0001)
	assert_float(RunEvents.pact_cost_fraction(true, false)).is_equal_approx(base * 0.5, 0.0001)
	assert_float(RunEvents.pact_cost_fraction(false, true)).is_equal_approx(base * 0.5, 0.0001)
	assert_float(RunEvents.pact_cost_fraction(true, true)).is_equal_approx(base * 0.25, 0.0001)
	var offer: Dictionary = _pact_offer(true)
	assert_int(int(offer["cards"][0]["amount"])).is_equal(int(round(_player.death_state.max_hp * base * 0.5)))
	_events.set_rules_for_test(false, true, false)
	var both: Dictionary = _pact_offer(true)
	assert_int(int(both["cards"][1]["amount"])).append_failure_message("Flawless + Pactbound = a quarter").is_equal(int(round(_tower.health.max_health * base * 0.25)))
	assert_bool(bool(both["pactbound"])).is_true()


func test_paying_with_blood_cuts_player_max_hp_and_composes_with_vitality() -> void:
	var before: float = _player.death_state.max_hp
	var offer: Dictionary = _pact_offer()
	_events.resolve(offer, _pick_option(offer, "blood"))
	assert_float(_player.death_state.max_hp).is_equal_approx(before * 0.8, 0.01)
	assert_float(_tower.health.max_health).append_failure_message("the Tower is untouched").is_equal(500.0)
	_us.apply_rank("vitality") # absolute setter: +15% of the BASE, then the pact term again
	assert_float(_player.death_state.max_hp).is_equal_approx(before * 1.15 * 0.8, 0.05)
	assert_float(_player.death_state.current_hp).is_less_equal(_player.death_state.max_hp)


func test_paying_with_the_tower_cuts_tower_max_hp_and_composes_with_reinforced_plating() -> void:
	var offer: Dictionary = _pact_offer()
	_events.resolve(offer, _pick_option(offer, "tower"))
	assert_float(_tower.health.max_health).is_equal_approx(400.0, 0.01)
	assert_float(_tower.death_state.max_hp).is_equal_approx(400.0, 0.01)
	assert_float(_tower.health.get_current_health()).is_less_equal(400.0)
	_us.apply_rank("reinforced_plating") # +15%
	assert_float(_tower.health.max_health).is_equal_approx(500.0 * 1.15 * 0.8, 0.05)
	assert_float(_player.death_state.max_hp).append_failure_message("the player is untouched").is_equal(float(_player.definition.max_health))


func test_two_pacts_paid_by_the_same_pool_multiply() -> void:
	for pact in ["twin_string", "bloodlust"]:
		var fraction: float = RunEvents.pact_cost_fraction(false, false)
		_events.apply_pact(pact, "blood", fraction)
	assert_float(_player.get_pact_max_health_multiplier()).is_equal_approx(0.8 * 0.8, 0.0001)


func test_refusing_costs_nothing_changes_nothing_and_leaves_the_pact_in_the_pool() -> void:
	var offer: Dictionary = _pact_offer()
	var pact_id: String = String(offer["pact_id"])
	_events.resolve(offer, _pick_option(offer, "refuse"))
	assert_array(_events.taken_pacts).is_empty()
	assert_float(_player.death_state.max_hp).is_equal(float(_player.definition.max_health))
	assert_float(_tower.health.max_health).is_equal(500.0)
	assert_int(_events.pact_events_resolved).is_equal(1)
	# Refused pacts stay in the pool: with the other four taken, only this one can be offered.
	for other in RunEvents.PACT_IDS:
		if other != pact_id:
			_events.taken_pacts.append(other)
	assert_str(String(_pact_offer()["pact_id"])).is_equal(pact_id)


func test_each_pact_can_be_taken_once_and_an_empty_pool_offers_nothing() -> void:
	for id in RunEvents.PACT_IDS:
		_events.apply_pact(id, "refuse", 0.0)
		_events.apply_pact(id, "refuse", 0.0) # a second take is ignored
	assert_int(_events.taken_pacts.size()).is_equal(RunEvents.PACT_IDS.size())
	assert_bool((_pact_offer()["cards"] as Array).is_empty()).is_true()


func test_the_pact_a_seed_offers_is_deterministic() -> void:
	var a: String = String(_pact_offer()["pact_id"])
	_events._serials.clear()
	assert_str(String(_pact_offer()["pact_id"])).is_equal(a)


# --- The five pact effects ---------------------------------------------------------------------

func test_second_life_leaves_the_player_at_half_and_is_used_up() -> void:
	_events.apply_pact("second_life", "refuse", 0.0)
	_player.death_state.current_hp = 5.0
	_player.apply_damage(9999.0)
	assert_bool(_player.is_dead()).is_false()
	assert_float(_player.death_state.current_hp).is_equal_approx(_player.death_state.max_hp * 0.5, 0.01)
	assert_bool(_player.is_second_life_available()).is_false()
	_player.apply_damage(9999.0)
	assert_bool(_player.is_dead()).append_failure_message("the second lethal hit must kill").is_true()


func test_second_life_and_second_wind_each_absorb_one_lethal_hit_weaker_first() -> void:
	_player.set_second_wind_available(true)
	_events.apply_pact("second_life", "refuse", 0.0)
	_player.apply_damage(9999.0)
	assert_float(_player.death_state.current_hp).append_failure_message("Second Wind (30%) is spent first").is_equal_approx(_player.death_state.max_hp * 0.3, 0.01)
	assert_bool(_player.is_second_wind_available_for_test()).is_false()
	assert_bool(_player.is_second_life_available()).is_true()
	_player.apply_damage(9999.0)
	assert_float(_player.death_state.current_hp).is_equal_approx(_player.death_state.max_hp * 0.5, 0.01)
	_player.apply_damage(9999.0)
	assert_bool(_player.is_dead()).is_true()


func test_twin_string_fires_one_extra_arrow_at_full_damage() -> void:
	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	var container := Node2D.new()
	container.name = "Projectiles"
	shooter.add_child(container)
	var weapon: AutoWeapon = AutoWeapon.new()
	weapon.definition = HandgunResource
	weapon.projectiles_container_path = NodePath("../Projectiles")
	shooter.add_child(weapon)
	var registry: Node = _w["registry"]
	weapon.set_registry_for_test(registry)
	var enemy: Node2D = auto_free(preload("res://scenes/entities/placeholder_enemy.tscn").instantiate()) as Node2D
	add_child(enemy)
	enemy.global_position = Vector2(100, 0)
	registry.register_entity(enemy, enemy.global_position, [&"enemy"])
	weapon.physics_step(0.0)
	assert_int(container.get_child_count()).is_equal(1)
	var plain_damage: float = (container.get_child(0) as PlayerProjectile)._damage
	for c in container.get_children():
		c.queue_free()
	weapon.set_full_extra_arrows(1)
	weapon._next_fire_allowed_at = 0.0
	weapon.physics_step(0.0)
	var arrows: Array = []
	for c in container.get_children():
		if not c.is_queued_for_deletion():
			arrows.append(c)
	assert_int(arrows.size()).append_failure_message("Twin String: two arrows per volley").is_equal(2)
	for a in arrows:
		assert_float((a as PlayerProjectile)._damage).append_failure_message("both arrows at full damage").is_equal_approx(plain_damage, 0.001)


func test_bloodlust_heals_one_hp_per_kill_only_after_it_is_taken() -> void:
	_player.death_state.current_hp = 50.0
	EventBus.emit_enemy_died(_player, Vector2.ZERO)
	assert_float(_player.death_state.current_hp).is_equal(50.0)
	_events.apply_pact("bloodlust", "refuse", 0.0)
	EventBus.emit_enemy_died(_player, Vector2.ZERO)
	EventBus.emit_enemy_died(_player, Vector2.ZERO)
	assert_float(_player.death_state.current_hp).is_equal(52.0)


func test_siege_breaker_adds_forty_percent_tower_damage_and_composes() -> void:
	_us.apply_rank("caliber") # +10%
	_events.apply_pact("siege_breaker", "refuse", 0.0)
	assert_float(_tower.weapon.get_damage_multiplier()).is_equal_approx(1.1 * 1.4, 0.0001)
	_events.apply_blessing("valor")
	assert_float(_tower.weapon.get_damage_multiplier()).is_equal_approx(1.1 * 1.4 * 1.1, 0.0001)
	var player_weapon: AutoWeapon = _player.get_node("AutoWeapon")
	assert_float(player_weapon.get_damage_term("siege_breaker")).append_failure_message("the player's bow is not a Tower weapon").is_equal(1.0)


func test_eternal_flame_doubles_burn_and_lengthens_it_by_half() -> void:
	var enemy: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(enemy)
	StatusEffects.apply_burn(enemy, 10.0, 3.0, "flame_arrows")
	var plain: Dictionary = StatusEffects.get_burn_info(enemy)
	StatusEffects.clear(enemy)
	_events.apply_pact("eternal_flame", "refuse", 0.0)
	StatusEffects.apply_burn(enemy, 10.0, 3.0, "flame_arrows")
	var boosted: Dictionary = StatusEffects.get_burn_info(enemy)
	assert_float(float(boosted["dps"])).is_equal_approx(float(plain["dps"]) * 2.0, 0.001)
	assert_float(float(boosted["remaining"])).is_equal_approx(float(plain["remaining"]) * 1.5, 0.01)
	# A spread carries the already-boosted burn and must not be boosted a second time.
	var other: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(other)
	StatusEffects.apply_burn(other, float(boosted["dps"]), 2.0, "flame_arrows", false)
	assert_float(float(StatusEffects.get_burn_info(other)["dps"])).is_equal_approx(20.0, 0.001)

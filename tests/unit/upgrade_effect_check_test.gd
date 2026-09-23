extends GdUnitTestSuite

## Upgrade effect check (P2.11 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Technical Tests > "Upgrade effect check": "Each
## of the six prototype upgrades and both fallback cards applies its
## documented per-rank effect exactly, with no drift after 3 ranks." Exit
## criterion (PLAN.md P2.11 row): "Ranks apply from either channel and cap
## correctly at rank 3."
##
## Every expected number below is COMPUTED from the same base values the
## live components read from their own authored .tres resources (data/
## weapons/handgun.tres, data/tower/base.tres, data/tower/base_weapon.tres,
## data/player/prototype.tres) combined with the Register's own per-rank
## percentages (MASTER_SDLC.md > Provisional Values Register > "Progression
## & Upgrades"), never read back from whatever src/upgrade/upgrade_system.gd
## happens to produce -- per this task's own instruction, "assert against a
## computed expectation with a stated tolerance, not against whatever the
## code produces."
##
## Stacking is additive-then-apply-once (MASTER_SDLC.md > Progression Edge
## Cases > "Percentage bonuses to the same stat stack", C-STACK): rank 3 of
## a +10%/rank upgrade is base x 1.3, NEVER base x 1.1^3 (= 1.331) -- the
## "drift after 3 ranks" this suite's own name calls out, and the specific
## defect a naive per-call-compounding implementation would produce.
##
## D115/D117 UPDATE: the Register's own per-rank percentages for the three
## cards that used to be +20%/rank (Rapid Fire, Heavy Rounds, Caliber) are
## now +10%/rank (D117's Common base value), and Shield Matrix moved from
## +10% to +15%/rank -- falsifications 1, 2, 3, 5 below are rewritten for
## the new values, never left asserting the old ones. Falsification 11 is
## rewritten for the D115/D117 pool expansion (ten new cards).
##
## Falsifications, each with its own test below:
##   1. Rapid Fire: +10% player fire rate/rank, additive to rank 3, exact.
##   2. Heavy Rounds: +10% player weapon damage/rank, additive to rank 3.
##   3. Caliber: +10% Tower weapon damage/rank, additive to rank 3.
##   4. Optics: +15% Tower weapon range/rank, additive to rank 3.
##   5. Shield Matrix: +15% of Tower max health as extra shield/rank,
##      additive to rank 3, granted already filled (not just capacity).
##   6. Patch Kit: flat 30-health heal per rank TAKEN (not a stacking
##      percentage), clamped to max_health (no overheal).
##   7. Shared-rank rule: two independent "channels" (both calling the same
##      apply_rank(), matching the Register's "no separate code path")
##      advance the SAME counter, and a 4th application past rank 3 is
##      refused and changes nothing live.
##   8. Fallback cards (Overdrive, Reinforce): no max rank, stack the same
##      additive +10%/take rule, and price flat at 90 Scrap regardless of
##      how many times taken.
##   9. Console cost formula: 30 x rank being bought for ranked upgrades,
##      flat for fallback cards, -1 once maxed.
##  10. Pool exhaustion unlocks exactly the matching fallback card, and a
##      pool with nothing authored is never reported exhausted.
##  11. Schema sanity: all eighteen authored .tres load with the expected
##      pool ownership / max-rank / is_unlock shape.
##  12. D117: a rarity_multiplier passed to apply_rank() scales the SAME
##      percentage card's live effect by exactly Rare (1.5x)/Epic (2.2x),
##      never compounding across repeat calls at different rarities.
##  13. D118: an is_unlock card (Piercing Arrows) is absent from
##      get_offerable_upgrades()/never offerable until
##      set_unlocked_card_ids() names it, then behaves like any other card.
##  14. Pool expansion, new mechanics: Swift Feet (move speed), Vitality
##      (max health + heal), Magnet (pickup radius), Regeneration
##      (per-second heal), Piercing Arrows (pierce count), Multishot (extra
##      arrows), Reinforced Plating (Tower max health + heal), Watchtower
##      upgrade card (Tower range), Tower Volley (Tower fire rate), Repair
##      Kit (flat Tower heal, repeatable).

const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const AutoWeaponScript: GDScript = preload("res://src/combat/auto_weapon.gd")
const HandgunResource: WeaponDefinition = preload("res://data/weapons/handgun.tres")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const RapidFireDef: UpgradeDefinition = preload("res://data/upgrades/rapid_fire.tres")
const HeavyRoundsDef: UpgradeDefinition = preload("res://data/upgrades/heavy_rounds.tres")
const PatchKitDef: UpgradeDefinition = preload("res://data/upgrades/patch_kit.tres")
const CaliberDef: UpgradeDefinition = preload("res://data/upgrades/caliber.tres")
const OpticsDef: UpgradeDefinition = preload("res://data/upgrades/optics.tres")
const ShieldMatrixDef: UpgradeDefinition = preload("res://data/upgrades/shield_matrix.tres")
const OverdriveDef: UpgradeDefinition = preload("res://data/upgrades/overdrive_fallback.tres")
const ReinforceDef: UpgradeDefinition = preload("res://data/upgrades/reinforce_fallback.tres")

# --- D115/D117 pool expansion -------------------------------------------------
const SwiftFeetDef: UpgradeDefinition = preload("res://data/upgrades/swift_feet.tres")
const VitalityDef: UpgradeDefinition = preload("res://data/upgrades/vitality.tres")
const MagnetDef: UpgradeDefinition = preload("res://data/upgrades/magnet.tres")
const RegenerationDef: UpgradeDefinition = preload("res://data/upgrades/regeneration.tres")
const PiercingArrowsDef: UpgradeDefinition = preload("res://data/upgrades/piercing_arrows.tres")
const MultishotDef: UpgradeDefinition = preload("res://data/upgrades/multishot.tres")
const ReinforcedPlatingDef: UpgradeDefinition = preload("res://data/upgrades/reinforced_plating.tres")
const WatchtowerUpgradeDef: UpgradeDefinition = preload("res://data/upgrades/watchtower_upgrade.tres")
const TowerVolleyDef: UpgradeDefinition = preload("res://data/upgrades/tower_volley.tres")
const RepairKitDef: UpgradeDefinition = preload("res://data/upgrades/repair_kit.tres")

# --- Register-derived base values (never read back from the system under test)
const HANDGUN_BASE_DAMAGE: float = 10.0
const HANDGUN_BASE_FIRE_RATE: float = 2.0
const HANDGUN_BASE_FIRE_INTERVAL: float = 1.0 / HANDGUN_BASE_FIRE_RATE
const TOWER_BASE_DAMAGE: float = 20.0
const TOWER_BASE_RANGE: float = 480.0
const TOWER_MAX_HEALTH: float = 500.0
const TOWER_BASE_SHIELD_FRACTION: float = 0.25
const TOWER_BASE_MAX_SHIELD: float = TOWER_MAX_HEALTH * TOWER_BASE_SHIELD_FRACTION # 125.0
const PLAYER_MAX_HEALTH: float = 100.0

const TOLERANCE: float = 0.0005

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _build_upgrade_system() -> UpgradeSystem:
	var system: UpgradeSystem = UpgradeSystemScript.new() as UpgradeSystem
	add_child(system)
	auto_free(system)
	return system


## Mirrors tests/unit/weapon_check_test.gd's own _build_weapon() exactly --
## a standalone AutoWeapon under a plain Node2D "shooter."
func _build_player_weapon() -> AutoWeapon:
	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	var projectiles_container: Node2D = Node2D.new()
	projectiles_container.name = "Projectiles"
	shooter.add_child(projectiles_container)
	var weapon: AutoWeapon = AutoWeaponScript.new() as AutoWeapon
	weapon.definition = HandgunResource
	weapon.projectiles_container_path = NodePath("../Projectiles")
	shooter.add_child(weapon)
	weapon.set_registry_for_test(_registry)
	return weapon


## Mirrors tests/unit/tower_weapon_test.gd's own _build_tower(): a real
## scenes/tower.tscn instance, already configure()d by Tower._ready() from
## its own assigned data/tower/base.tres + data/tower/base_weapon.tres.
func _build_tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	tower.weapon.set_registry_for_test(_registry)
	return tower


## Mirrors tests/unit/player_movement_test.gd's own fixture: a real
## scenes/player.tscn instance.
func _build_player() -> Player:
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	player.set_registry_for_test(_registry) # BEFORE add_child -- see player.gd's _ready() guard comment
	add_child(player)
	return player


# --- Falsification 1: Rapid Fire, +10% fire rate/rank (D117), additive to rank 3 --

func test_rapid_fire_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	var expected_rank1: float = HANDGUN_BASE_FIRE_INTERVAL / 1.1
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 1 fire interval wrong").is_equal_approx(expected_rank1, TOLERANCE)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	var expected_rank2: float = HANDGUN_BASE_FIRE_INTERVAL / 1.2
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 2 fire interval wrong").is_equal_approx(expected_rank2, TOLERANCE)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	# C-STACK: (1 + 0.1 + 0.1 + 0.1) = 1.3, NEVER 1.1^3 (= 1.331).
	var expected_rank3: float = HANDGUN_BASE_FIRE_INTERVAL / 1.3
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 3 fire interval drifted from the additive-stack expectation (possible multiplicative-compounding defect)").is_equal_approx(expected_rank3, TOLERANCE)
	assert_int(system.get_current_rank("rapid_fire")).is_equal(3)
	assert_bool(system.is_maxed("rapid_fire")).is_true()


# --- Falsification 2: Heavy Rounds, +10% damage/rank (D117), additive to rank 3 --

func test_heavy_rounds_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")

	var expected: float = HANDGUN_BASE_DAMAGE * 1.3 # (1 + 0.1*3), never 1.1^3
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("Heavy Rounds rank 3 damage drifted from the additive-stack expectation").is_equal_approx(expected, TOLERANCE)
	assert_int(system.get_current_rank("heavy_rounds")).is_equal(3)


# --- Falsification 3: Caliber, +10% Tower damage/rank (D117), additive to rank 3 -

func test_caliber_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_weapon_for_test(tower.weapon)

	system.apply_rank("caliber")
	system.apply_rank("caliber")
	system.apply_rank("caliber")

	var expected: float = TOWER_BASE_DAMAGE * 1.3
	assert_float(tower.weapon.get_effective_damage_per_shot()).append_failure_message("Caliber rank 3 damage drifted from the additive-stack expectation").is_equal_approx(expected, TOLERANCE)
	assert_int(system.get_current_rank("caliber")).is_equal(3)


# --- Falsification 4: Optics, +15% Tower range/rank, additive to rank 3 ---

func test_optics_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_weapon_for_test(tower.weapon)

	system.apply_rank("optics")
	system.apply_rank("optics")
	system.apply_rank("optics")

	var expected: float = TOWER_BASE_RANGE * 1.45 # (1 + 0.15*3), never 1.15^3
	assert_float(tower.weapon.get_effective_range_px()).append_failure_message("Optics rank 3 range drifted from the additive-stack expectation").is_equal_approx(expected, TOLERANCE)
	assert_int(system.get_current_rank("optics")).is_equal(3)


# --- Falsification 5: Shield Matrix, +15% max health as extra shield/rank
# (D117), additive to rank 3, granted already filled (not just extra capacity) --

func test_shield_matrix_stacks_additively_and_tops_up_current_shield_by_exactly_the_delta() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_health_for_test(tower.health)

	# Partial shield damage BEFORE any rank, so a bug that RESETS current_
	# shield to max (instead of adding the capacity delta) is distinguishable
	# from the correct "add exactly the new capacity" behaviour.
	tower.hurtbox.receive_hit(auto_free(Node.new()), 50.0, "test")
	assert_float(tower.health.current_shield).is_equal_approx(TOWER_BASE_MAX_SHIELD - 50.0, 0.01) # 75.0

	system.apply_rank("shield_matrix") # +15% of 500 = 75 extra capacity
	assert_float(tower.health.max_shield).append_failure_message("rank 1 max_shield wrong").is_equal_approx(TOWER_BASE_MAX_SHIELD + 75.0, TOLERANCE) # 200
	assert_float(tower.health.current_shield).append_failure_message("rank 1 did not top up current_shield by exactly the new capacity delta").is_equal_approx(150.0, TOLERANCE) # 75 + 75

	system.apply_rank("shield_matrix") # total 30% = 150 extra capacity (delta +75)
	assert_float(tower.health.max_shield).append_failure_message("rank 2 max_shield wrong").is_equal_approx(TOWER_BASE_MAX_SHIELD + 150.0, TOLERANCE) # 275
	assert_float(tower.health.current_shield).append_failure_message("rank 2 did not top up current_shield by exactly the new capacity delta").is_equal_approx(225.0, TOLERANCE) # 150 + 75

	system.apply_rank("shield_matrix") # total 45% = 225 extra capacity (delta +75), NEVER 1.15^3-style compounding
	var expected_max_shield: float = TOWER_BASE_MAX_SHIELD + TOWER_MAX_HEALTH * 0.45
	assert_float(tower.health.max_shield).append_failure_message("rank 3 max_shield drifted from the additive-stack expectation").is_equal_approx(expected_max_shield, TOLERANCE) # 350
	assert_float(tower.health.current_shield).append_failure_message("rank 3 did not top up current_shield by exactly the new capacity delta").is_equal_approx(300.0, TOLERANCE) # 225 + 75


# --- Falsification 6: Patch Kit, flat 30-health heal per rank TAKEN -------

func test_patch_kit_heals_a_flat_30_per_rank_taken_not_a_stacking_percentage() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)

	player.apply_damage(90.0) # 100 -> 10
	assert_float(player.death_state.current_hp).is_equal_approx(10.0, 0.01)

	system.apply_rank("patch_kit")
	assert_float(player.death_state.current_hp).append_failure_message("rank 1 heal was not a flat 30").is_equal_approx(40.0, TOLERANCE)

	system.apply_rank("patch_kit")
	assert_float(player.death_state.current_hp).append_failure_message("rank 2 heal was not a flat 30 (Patch Kit must not compound like a percentage upgrade)").is_equal_approx(70.0, TOLERANCE)

	system.apply_rank("patch_kit")
	assert_float(player.death_state.current_hp).append_failure_message("rank 3 heal wrong").is_equal_approx(PLAYER_MAX_HEALTH, TOLERANCE) # exactly 100, coincides with max_health


func test_patch_kit_heal_clamps_to_max_health_and_never_overheals() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)

	player.apply_damage(10.0) # 100 -> 90
	system.apply_rank("patch_kit") # 90 + 30 = 120, must clamp to 100
	assert_float(player.death_state.current_hp).append_failure_message("Patch Kit overhealed past max_health (Register: overheal is discarded)").is_equal_approx(PLAYER_MAX_HEALTH, TOLERANCE)


# --- Falsification 7: shared-rank rule + rank-3 cap -----------------------

func test_ranks_apply_from_either_channel_and_cap_correctly_at_rank_3() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	# Two "channels" -- the Level-Up Draft and the Tower Console -- both
	# call the exact same apply_rank(), matching MASTER_SDLC.md > Player
	# Overview > "Upgrade Channels": "An upgrade rank purchased in one
	# channel counts in the other." There is no channel argument anywhere
	# in this system's API for a caller to even get this wrong.
	var draft_take: Callable = func(id: String) -> bool: return system.apply_rank(id)
	var console_buy: Callable = func(id: String) -> bool: return system.apply_rank(id)

	assert_bool(draft_take.call("heavy_rounds")).is_true() # rank 1, from the Draft
	assert_int(system.get_current_rank("heavy_rounds")).is_equal(1)

	assert_bool(console_buy.call("heavy_rounds")).is_true() # rank 2, from the Console
	assert_int(system.get_current_rank("heavy_rounds")).append_failure_message("a rank purchased at the Console did not count toward the Draft's own counter -- ranks must be SHARED, not per-channel").is_equal(2)

	assert_bool(draft_take.call("heavy_rounds")).is_true() # rank 3, from the Draft again
	assert_int(system.get_current_rank("heavy_rounds")).is_equal(3)
	assert_bool(system.is_maxed("heavy_rounds")).is_true()

	var rank3_damage: float = weapon.get_effective_damage_per_shot()
	assert_float(rank3_damage).is_equal_approx(HANDGUN_BASE_DAMAGE * 1.3, TOLERANCE)

	# A 4th application, from EITHER channel, must be refused outright and
	# change nothing live -- the cap is enforced inside apply_rank() itself,
	# not only by whichever caller checks is_maxed() first.
	assert_bool(console_buy.call("heavy_rounds")).append_failure_message("a 4th application of an already-maxed upgrade was accepted instead of refused").is_false()
	assert_int(system.get_current_rank("heavy_rounds")).append_failure_message("rank exceeded the Register's max_rank of 3").is_equal(3)
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("live damage changed even though the 4th application was refused").is_equal_approx(rank3_damage, TOLERANCE)


# --- Falsification 8: fallback cards (C-FALLBACK-CONSOLE) ------------------

func test_fallback_cards_have_no_max_rank_and_stack_the_same_additive_10_percent() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)
	system.set_tower_weapon_for_test(tower.weapon)

	assert_bool(OverdriveDef.has_max_rank).is_false()
	assert_bool(ReinforceDef.has_max_rank).is_false()

	for _i in 5: # comfortably more than the ranked upgrades' cap of 3
		system.apply_rank("overdrive_fallback")
		system.apply_rank("reinforce_fallback")

	assert_bool(system.is_maxed("overdrive_fallback")).append_failure_message("a no-max-rank fallback card reported itself maxed").is_false()
	assert_bool(system.is_maxed("reinforce_fallback")).append_failure_message("a no-max-rank fallback card reported itself maxed").is_false()

	var expected_multiplier: float = 1.0 + 0.1 * 5.0
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("Overdrive did not stack additively across 5 takes").is_equal_approx(HANDGUN_BASE_DAMAGE * expected_multiplier, TOLERANCE)
	assert_float(tower.weapon.get_effective_damage_per_shot()).append_failure_message("Reinforce did not stack additively across 5 takes").is_equal_approx(TOWER_BASE_DAMAGE * expected_multiplier, TOLERANCE)


# --- Falsification 9: Console cost formula ---------------------------------

func test_console_cost_scales_per_rank_for_ranked_upgrades_and_is_flat_for_fallback_cards() -> void:
	var system: UpgradeSystem = _build_upgrade_system()

	assert_int(system.get_console_cost("caliber")).append_failure_message("rank-1 Console price wrong").is_equal(30)
	system.apply_rank("caliber")
	assert_int(system.get_console_cost("caliber")).append_failure_message("rank-2 Console price wrong").is_equal(60)
	system.apply_rank("caliber")
	assert_int(system.get_console_cost("caliber")).append_failure_message("rank-3 Console price wrong").is_equal(90)
	system.apply_rank("caliber")
	assert_int(system.get_console_cost("caliber")).append_failure_message("a maxed upgrade must never report a valid Scrap cost").is_equal(-1)

	assert_int(system.get_console_cost("reinforce_fallback")).append_failure_message("fallback Console price must be the flat C-FALLBACK-CONSOLE price, not a per-rank formula").is_equal(90)
	system.apply_rank("reinforce_fallback")
	system.apply_rank("reinforce_fallback")
	assert_int(system.get_console_cost("reinforce_fallback")).append_failure_message("fallback Console price changed after being taken -- it must stay flat at 90 regardless of how many times taken").is_equal(90)


# --- Falsification 10: pool exhaustion unlocks the matching fallback card -

func test_pool_exhaustion_unlocks_exactly_the_matching_fallback_card() -> void:
	var system: UpgradeSystem = _build_upgrade_system()
	var player_only: Array[UpgradeDefinition] = [HeavyRoundsDef, OverdriveDef]
	system.set_upgrade_definitions_for_test(player_only)

	assert_bool(system.is_pool_exhausted(ContractEnums.PoolOwnership.Player)).is_false()
	assert_int(system.get_offerable_upgrades(ContractEnums.PoolOwnership.Player).size()).is_equal(1)

	# A pool with nothing authored for it (Tower, in this restricted set)
	# must never be reported "exhausted" -- that would wrongly unlock a
	# fallback card for a pool that was simply never populated.
	assert_bool(system.is_pool_exhausted(ContractEnums.PoolOwnership.Tower)).append_failure_message("an empty, never-populated pool was reported exhausted").is_false()

	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")

	assert_bool(system.is_pool_exhausted(ContractEnums.PoolOwnership.Player)).append_failure_message("the Player pool did not report exhausted once its only ranked upgrade was maxed").is_true()
	assert_int(system.get_offerable_upgrades(ContractEnums.PoolOwnership.Player).size()).is_equal(0)

	var fallback: UpgradeDefinition = system.get_fallback_card(ContractEnums.PoolOwnership.Player)
	assert_object(fallback).is_not_null()
	assert_str(fallback.unique_id).is_equal("overdrive_fallback")


# --- Falsification 11: schema sanity across all eighteen authored .tres ---

func test_all_eighteen_upgrade_definitions_load_with_the_expected_pool_and_rank_shape() -> void:
	var ranked: Array[UpgradeDefinition] = [
		RapidFireDef, HeavyRoundsDef, PatchKitDef, SwiftFeetDef, VitalityDef, MagnetDef, RegenerationDef, PiercingArrowsDef, MultishotDef,
		CaliberDef, OpticsDef, ShieldMatrixDef, ReinforcedPlatingDef, WatchtowerUpgradeDef, TowerVolleyDef, RepairKitDef,
	]
	for def in ranked:
		assert_bool(def.has_max_rank).append_failure_message("%s should have a max rank" % def.unique_id).is_true()

	var fallbacks: Array[UpgradeDefinition] = [OverdriveDef, ReinforceDef]
	for def in fallbacks:
		assert_bool(def.has_max_rank).append_failure_message("%s (fallback) must have no max rank (C-FALLBACK-CONSOLE)" % def.unique_id).is_false()

	var player_pool: Array[UpgradeDefinition] = [RapidFireDef, HeavyRoundsDef, PatchKitDef, SwiftFeetDef, VitalityDef, MagnetDef, RegenerationDef, PiercingArrowsDef, MultishotDef, OverdriveDef]
	for def in player_pool:
		assert_int(def.pool_ownership).append_failure_message("%s should be Player-owned" % def.unique_id).is_equal(ContractEnums.PoolOwnership.Player)

	var tower_pool: Array[UpgradeDefinition] = [CaliberDef, OpticsDef, ShieldMatrixDef, ReinforcedPlatingDef, WatchtowerUpgradeDef, TowerVolleyDef, RepairKitDef, ReinforceDef]
	for def in tower_pool:
		assert_int(def.pool_ownership).append_failure_message("%s should be Tower-owned" % def.unique_id).is_equal(ContractEnums.PoolOwnership.Tower)

	# D118: exactly three cards are is_unlock (achievement-gated); every
	# other card in the pool expansion (plus the original eight) is
	# offerable from a fresh profile's first run.
	var unlock_cards: Array[UpgradeDefinition] = [PiercingArrowsDef, MultishotDef, TowerVolleyDef]
	for def in unlock_cards:
		assert_bool(def.is_unlock).append_failure_message("%s should be is_unlock (D118 achievement-gated)" % def.unique_id).is_true()
	var non_unlock_cards: Array[UpgradeDefinition] = [RapidFireDef, HeavyRoundsDef, PatchKitDef, SwiftFeetDef, VitalityDef, MagnetDef, RegenerationDef, CaliberDef, OpticsDef, ShieldMatrixDef, ReinforcedPlatingDef, WatchtowerUpgradeDef, RepairKitDef, OverdriveDef, ReinforceDef]
	for def in non_unlock_cards:
		assert_bool(def.is_unlock).append_failure_message("%s should NOT be is_unlock -- offerable from the first run" % def.unique_id).is_false()

	assert_int(ReinforceDef.evolution_stage_contribution).append_failure_message("fallback cards must add 0 evolution ranks (C-FALLBACK-CONSOLE)").is_equal(0)
	assert_int(CaliberDef.evolution_stage_contribution).is_equal(1)

	var system: UpgradeSystem = _build_upgrade_system()
	for def in ranked:
		assert_object(system.get_definition(def.unique_id)).append_failure_message("%s missing from the system's default definition set" % def.unique_id).is_not_null()
	for def in fallbacks:
		assert_object(system.get_definition(def.unique_id)).append_failure_message("%s missing from the system's default definition set" % def.unique_id).is_not_null()


# --- Falsification 12: D117 rarity_multiplier scales the live effect ------

func test_rarity_multiplier_scales_the_live_effect_by_exactly_the_rolled_rarity() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	# Rank 1, rolled Rare (1.5x): +10% * 1.5 = +15%.
	system.apply_rank("heavy_rounds", 1.5)
	var expected_rank1: float = HANDGUN_BASE_DAMAGE * 1.15
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("a Rare (1.5x) card did not raise damage by exactly 15 percent").is_equal_approx(expected_rank1, TOLERANCE)

	# Rank 2, rolled Epic (2.2x): total_fraction = 0.1 * 2 * 2.2 = 0.44 (this
	# file's own named simplification -- the MOST RECENT purchase's rarity
	# governs the whole accumulated stack, see apply_rank()'s own header).
	system.apply_rank("heavy_rounds", 2.2)
	var expected_rank2: float = HANDGUN_BASE_DAMAGE * 1.44
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("an Epic (2.2x) card did not scale the accumulated 2-rank stack to exactly 44 percent").is_equal_approx(expected_rank2, TOLERANCE)

	# A default (Common, 1.0x) call is unaffected -- every pre-D117 call
	# site (this whole file's other falsifications) keeps working exactly
	# as before.
	var system2: UpgradeSystem = _build_upgrade_system()
	var weapon2: AutoWeapon = _build_player_weapon()
	system2.set_player_weapon_for_test(weapon2)
	system2.apply_rank("heavy_rounds")
	assert_float(weapon2.get_effective_damage_per_shot()).append_failure_message("apply_rank() with no rarity argument must default to Common (1.0x), unchanged from before D117").is_equal_approx(HANDGUN_BASE_DAMAGE * 1.1, TOLERANCE)


# --- Falsification 13: D118 is_unlock gating ------------------------------

func test_an_is_unlock_card_is_absent_from_the_pool_until_unlocked() -> void:
	var system: UpgradeSystem = _build_upgrade_system()

	var offered: Array[UpgradeDefinition] = system.get_offerable_upgrades(ContractEnums.PoolOwnership.Player)
	var offered_ids: Array[String] = []
	for def in offered:
		offered_ids.append(def.unique_id)
	assert_bool(offered_ids.has("piercing_arrows")).append_failure_message("Piercing Arrows (is_unlock) must be absent from a fresh profile's pool").is_false()
	assert_bool(system.is_card_unlocked_for_test("piercing_arrows")).is_false()

	system.set_unlocked_card_ids(["piercing_arrows"])
	assert_bool(system.is_card_unlocked_for_test("piercing_arrows")).is_true()
	var offered_after: Array[UpgradeDefinition] = system.get_offerable_upgrades(ContractEnums.PoolOwnership.Player)
	var offered_after_ids: Array[String] = []
	for def in offered_after:
		offered_after_ids.append(def.unique_id)
	assert_bool(offered_after_ids.has("piercing_arrows")).append_failure_message("Piercing Arrows must become offerable once unlocked").is_true()

	# Maxing every OTHER Player card must not report the Player pool
	# exhausted while Piercing Arrows/Multishot are still locked -- a locked
	# card must not silently block or fake the exhaustion check.
	var system2: UpgradeSystem = _build_upgrade_system()
	for id in ["rapid_fire", "heavy_rounds", "patch_kit", "swift_feet", "vitality", "magnet", "regeneration"]:
		for _i in 5:
			system2.apply_rank(id)
	assert_bool(system2.is_pool_exhausted(ContractEnums.PoolOwnership.Player)).append_failure_message("locked is_unlock cards (Piercing Arrows, Multishot) must not block exhaustion once every OTHER card is maxed").is_true()


# --- Falsification 14: pool expansion, new mechanics -----------------------

func test_swift_feet_raises_player_move_speed() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)
	system.apply_rank("swift_feet")
	assert_float(player.get_speed_multiplier_for_test()).is_equal_approx(1.08, TOLERANCE)


func test_vitality_raises_max_health_and_heals_the_increase() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)
	player.apply_damage(50.0) # 100 -> 50
	system.apply_rank("vitality") # +15% of 100 = 15 extra max health, healed
	assert_float(player.death_state.max_hp).is_equal_approx(115.0, TOLERANCE)
	assert_float(player.death_state.current_hp).append_failure_message("Vitality must heal exactly the max-health increase").is_equal_approx(65.0, TOLERANCE)


func test_magnet_raises_effective_pickup_radius() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)
	var base_radius: float = player.get_effective_magnet_radius_px()
	system.apply_rank("magnet")
	assert_float(player.get_effective_magnet_radius_px()).is_equal_approx(base_radius * 1.25, TOLERANCE)


func test_regeneration_heals_a_fraction_of_max_health_per_second() -> void:
	var player: Player = _build_player()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_for_test(player)
	player.apply_damage(50.0) # 100 -> 50
	system.apply_rank("regeneration") # 1% max health/s
	player.physics_step(1.0) # 1 simulated second
	assert_float(player.death_state.current_hp).append_failure_message("Regeneration did not heal 1 percent of max health over 1 second").is_equal_approx(51.0, 0.05)


func test_piercing_arrows_sets_the_live_pierce_bonus() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)
	system.set_unlocked_card_ids(["piercing_arrows"])
	system.apply_rank("piercing_arrows")
	system.apply_rank("piercing_arrows")
	assert_int(weapon.get_pierce_bonus_for_test()).is_equal(2)


func test_multishot_sets_the_live_extra_arrow_count() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)
	system.set_unlocked_card_ids(["multishot"])
	system.apply_rank("multishot")
	assert_int(weapon.get_multishot_extra_count_for_test()).is_equal(1)


func test_reinforced_plating_raises_tower_max_health_and_heals_the_increase() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_health_for_test(tower.health)
	tower.hurtbox.receive_hit(auto_free(Node.new()), TOWER_BASE_MAX_SHIELD + 50.0, "test") # exhaust the shield, then damage health by 50
	var health_before: float = tower.health.get_current_health()
	system.apply_rank("reinforced_plating") # +15% of 500 = 75 extra max health, healed
	assert_float(tower.health.max_health).is_equal_approx(TOWER_MAX_HEALTH * 1.15, TOLERANCE)
	assert_float(tower.health.get_current_health()).append_failure_message("Reinforced Plating must heal exactly the max-health increase").is_equal_approx(health_before + 75.0, TOLERANCE)


func test_watchtower_upgrade_card_raises_tower_range() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_weapon_for_test(tower.weapon)
	system.apply_rank("watchtower_upgrade")
	assert_float(tower.weapon.get_effective_range_px()).is_equal_approx(TOWER_BASE_RANGE * 1.1, TOLERANCE)


func test_tower_volley_raises_tower_fire_rate() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_weapon_for_test(tower.weapon)
	system.set_unlocked_card_ids(["tower_volley"])
	var base_interval: float = tower.weapon.get_effective_fire_interval_seconds()
	system.apply_rank("tower_volley")
	assert_float(tower.weapon.get_effective_fire_interval_seconds()).is_equal_approx(base_interval / 1.1, TOLERANCE)


func test_repair_kit_instantly_heals_a_flat_fraction_and_is_repeatable() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_health_for_test(tower.health)
	tower.hurtbox.receive_hit(auto_free(Node.new()), TOWER_BASE_MAX_SHIELD + 300.0, "test") # exhaust shield, drop health to 200/500
	var health_before: float = tower.health.get_current_health()
	system.apply_rank("repair_kit") # 25% of 500 = 125
	assert_float(tower.health.get_current_health()).is_equal_approx(health_before + 125.0, TOLERANCE)
	system.apply_rank("repair_kit") # repeatable -- a second use heals again
	assert_float(tower.health.get_current_health()).append_failure_message("Repair Kit must be repeatable, not a one-shot").is_equal_approx(health_before + 250.0, TOLERANCE)

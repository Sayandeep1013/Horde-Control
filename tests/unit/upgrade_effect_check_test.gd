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
## a +20%/rank upgrade is base x 1.6, NEVER base x 1.2^3 (= 1.728) -- the
## "drift after 3 ranks" this suite's own name calls out, and the specific
## defect a naive per-call-compounding implementation would produce.
##
## Falsifications, each with its own test below:
##   1. Rapid Fire: +20% player fire rate/rank, additive to rank 3, exact.
##   2. Heavy Rounds: +20% player weapon damage/rank, additive to rank 3.
##   3. Caliber: +20% Tower weapon damage/rank, additive to rank 3.
##   4. Optics: +15% Tower weapon range/rank, additive to rank 3.
##   5. Shield Matrix: +10% of Tower max health as extra shield/rank,
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
##  11. Schema sanity: all eight authored .tres load with the expected pool
##      ownership / max-rank shape.

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


# --- Falsification 1: Rapid Fire, +20% fire rate/rank, additive to rank 3 --

func test_rapid_fire_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	var expected_rank1: float = HANDGUN_BASE_FIRE_INTERVAL / 1.2
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 1 fire interval wrong").is_equal_approx(expected_rank1, TOLERANCE)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	var expected_rank2: float = HANDGUN_BASE_FIRE_INTERVAL / 1.4
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 2 fire interval wrong").is_equal_approx(expected_rank2, TOLERANCE)

	assert_bool(system.apply_rank("rapid_fire")).is_true()
	# C-STACK: (1 + 0.2 + 0.2 + 0.2) = 1.6, NEVER 1.2^3 (= 1.728).
	var expected_rank3: float = HANDGUN_BASE_FIRE_INTERVAL / 1.6
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("rank 3 fire interval drifted from the additive-stack expectation (possible multiplicative-compounding defect)").is_equal_approx(expected_rank3, TOLERANCE)
	assert_int(system.get_current_rank("rapid_fire")).is_equal(3)
	assert_bool(system.is_maxed("rapid_fire")).is_true()


# --- Falsification 2: Heavy Rounds, +20% damage/rank, additive to rank 3 --

func test_heavy_rounds_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var weapon: AutoWeapon = _build_player_weapon()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_player_weapon_for_test(weapon)

	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")
	system.apply_rank("heavy_rounds")

	var expected: float = HANDGUN_BASE_DAMAGE * 1.6 # (1 + 0.2*3), never 1.2^3
	assert_float(weapon.get_effective_damage_per_shot()).append_failure_message("Heavy Rounds rank 3 damage drifted from the additive-stack expectation").is_equal_approx(expected, TOLERANCE)
	assert_int(system.get_current_rank("heavy_rounds")).is_equal(3)


# --- Falsification 3: Caliber, +20% Tower damage/rank, additive to rank 3 -

func test_caliber_stacks_additively_to_exactly_rank_3_with_no_drift() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_weapon_for_test(tower.weapon)

	system.apply_rank("caliber")
	system.apply_rank("caliber")
	system.apply_rank("caliber")

	var expected: float = TOWER_BASE_DAMAGE * 1.6
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


# --- Falsification 5: Shield Matrix, +10% max health as extra shield/rank,
# additive to rank 3, granted already filled (not just extra capacity) -----

func test_shield_matrix_stacks_additively_and_tops_up_current_shield_by_exactly_the_delta() -> void:
	var tower: Tower = _build_tower()
	var system: UpgradeSystem = _build_upgrade_system()
	system.set_tower_health_for_test(tower.health)

	# Partial shield damage BEFORE any rank, so a bug that RESETS current_
	# shield to max (instead of adding the capacity delta) is distinguishable
	# from the correct "add exactly the new capacity" behaviour.
	tower.hurtbox.receive_hit(auto_free(Node.new()), 50.0, "test")
	assert_float(tower.health.current_shield).is_equal_approx(TOWER_BASE_MAX_SHIELD - 50.0, 0.01) # 75.0

	system.apply_rank("shield_matrix") # +10% of 500 = 50 extra capacity
	assert_float(tower.health.max_shield).append_failure_message("rank 1 max_shield wrong").is_equal_approx(TOWER_BASE_MAX_SHIELD + 50.0, TOLERANCE) # 175
	assert_float(tower.health.current_shield).append_failure_message("rank 1 did not top up current_shield by exactly the new capacity delta").is_equal_approx(125.0, TOLERANCE) # 75 + 50

	system.apply_rank("shield_matrix") # total 20% = 100 extra capacity (delta +50)
	assert_float(tower.health.max_shield).append_failure_message("rank 2 max_shield wrong").is_equal_approx(TOWER_BASE_MAX_SHIELD + 100.0, TOLERANCE) # 225
	assert_float(tower.health.current_shield).append_failure_message("rank 2 did not top up current_shield by exactly the new capacity delta").is_equal_approx(175.0, TOLERANCE) # 125 + 50

	system.apply_rank("shield_matrix") # total 30% = 150 extra capacity (delta +50), NEVER 1.1^3-style compounding
	var expected_max_shield: float = TOWER_BASE_MAX_SHIELD + TOWER_MAX_HEALTH * 0.30
	assert_float(tower.health.max_shield).append_failure_message("rank 3 max_shield drifted from the additive-stack expectation").is_equal_approx(expected_max_shield, TOLERANCE) # 275
	assert_float(tower.health.current_shield).append_failure_message("rank 3 did not top up current_shield by exactly the new capacity delta").is_equal_approx(225.0, TOLERANCE) # 175 + 50


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
	assert_float(rank3_damage).is_equal_approx(HANDGUN_BASE_DAMAGE * 1.6, TOLERANCE)

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


# --- Falsification 11: schema sanity across all eight authored .tres ------

func test_all_eight_upgrade_definitions_load_with_the_expected_pool_and_rank_shape() -> void:
	var ranked: Array[UpgradeDefinition] = [RapidFireDef, HeavyRoundsDef, PatchKitDef, CaliberDef, OpticsDef, ShieldMatrixDef]
	for def in ranked:
		assert_bool(def.has_max_rank).append_failure_message("%s should have a max rank" % def.unique_id).is_true()
		assert_int(def.max_rank).append_failure_message("%s max rank should be 3 (Register: 'Max rank 3 each, shared ranks')" % def.unique_id).is_equal(3)

	var fallbacks: Array[UpgradeDefinition] = [OverdriveDef, ReinforceDef]
	for def in fallbacks:
		assert_bool(def.has_max_rank).append_failure_message("%s (fallback) must have no max rank (C-FALLBACK-CONSOLE)" % def.unique_id).is_false()

	assert_int(RapidFireDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Player)
	assert_int(HeavyRoundsDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Player)
	assert_int(PatchKitDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Player)
	assert_int(OverdriveDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Player)
	assert_int(CaliberDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Tower)
	assert_int(OpticsDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Tower)
	assert_int(ShieldMatrixDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Tower)
	assert_int(ReinforceDef.pool_ownership).is_equal(ContractEnums.PoolOwnership.Tower)

	assert_int(ReinforceDef.evolution_stage_contribution).append_failure_message("fallback cards must add 0 evolution ranks (C-FALLBACK-CONSOLE)").is_equal(0)
	assert_int(CaliberDef.evolution_stage_contribution).is_equal(1)
	assert_int(OpticsDef.evolution_stage_contribution).is_equal(1)
	assert_int(ShieldMatrixDef.evolution_stage_contribution).is_equal(1)

	var system: UpgradeSystem = _build_upgrade_system()
	for def in ranked:
		assert_object(system.get_definition(def.unique_id)).append_failure_message("%s missing from the system's default definition set" % def.unique_id).is_not_null()
	for def in fallbacks:
		assert_object(system.get_definition(def.unique_id)).append_failure_message("%s missing from the system's default definition set" % def.unique_id).is_not_null()

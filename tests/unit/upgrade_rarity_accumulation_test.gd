extends GdUnitTestSuite

## D123 (review P1-1/P1-2): per-rank rarity accumulation, shared-stat
## combination (Optics + Watchtower etc.) and the honest-card-value query.

const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const AutoWeaponScript: GDScript = preload("res://src/combat/auto_weapon.gd")
const HandgunResource: WeaponDefinition = preload("res://data/weapons/handgun.tres")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

const EPIC: float = 2.2
const RARE: float = 1.5
const COMMON: float = 1.0
const TOL: float = 0.0005

var _registry: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)


func _system() -> UpgradeSystem:
	var system: UpgradeSystem = UpgradeSystemScript.new() as UpgradeSystem
	add_child(system)
	return auto_free(system)


func _weapon() -> AutoWeapon:
	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	var projectiles: Node2D = Node2D.new()
	projectiles.name = "Projectiles"
	shooter.add_child(projectiles)
	var weapon: AutoWeapon = AutoWeaponScript.new() as AutoWeapon
	weapon.definition = HandgunResource
	weapon.projectiles_container_path = NodePath("../Projectiles")
	shooter.add_child(weapon)
	weapon.set_registry_for_test(_registry)
	return weapon


func _tower() -> Tower:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	tower.weapon.set_registry_for_test(_registry)
	return tower


func test_epic_then_common_never_lowers_the_stat() -> void:
	var weapon: AutoWeapon = _weapon()
	var system: UpgradeSystem = _system()
	system.set_player_weapon_for_test(weapon)
	system.apply_rank("heavy_rounds", EPIC)
	var after_epic: float = weapon.get_effective_damage_per_shot()
	system.apply_rank("heavy_rounds", COMMON)
	var after_common: float = weapon.get_effective_damage_per_shot()
	assert_float(after_common).append_failure_message("taking a second rank lowered the stat").is_greater(after_epic)
	assert_float(after_common).is_equal_approx(10.0 * (1.0 + 0.1 * EPIC + 0.1 * COMMON), TOL)


func test_common_then_epic_does_not_retroactively_upgrade_rank_one() -> void:
	var weapon: AutoWeapon = _weapon()
	var system: UpgradeSystem = _system()
	system.set_player_weapon_for_test(weapon)
	system.apply_rank("heavy_rounds", COMMON)
	system.apply_rank("heavy_rounds", EPIC)
	assert_float(weapon.get_effective_damage_per_shot()).is_equal_approx(10.0 * (1.0 + 0.1 + 0.1 * EPIC), TOL)


func test_optics_and_watchtower_combine_instead_of_overwriting() -> void:
	var tower: Tower = _tower()
	var system: UpgradeSystem = _system()
	system.set_tower_weapon_for_test(tower.weapon)
	var base_range: float = tower.weapon.get_effective_range_px()
	system.apply_rank("optics", EPIC)
	system.apply_rank("optics", RARE)
	system.apply_rank("watchtower_upgrade", COMMON)
	var expected: float = base_range * (1.0 + 0.15 * EPIC + 0.15 * RARE + 0.10 * COMMON)
	assert_float(tower.weapon.get_effective_range_px()).is_equal_approx(expected, 0.01)


func test_caliber_and_reinforce_fallback_combine() -> void:
	var tower: Tower = _tower()
	var system: UpgradeSystem = _system()
	system.set_tower_weapon_for_test(tower.weapon)
	var base: float = tower.weapon.get_effective_damage_per_shot()
	system.apply_rank("caliber", COMMON)
	system.apply_rank("reinforce_fallback", COMMON)
	var def_c: UpgradeDefinition = system.get_definition("caliber")
	var def_r: UpgradeDefinition = system.get_definition("reinforce_fallback")
	assert_float(tower.weapon.get_effective_damage_per_shot()).is_equal_approx(base * (1.0 + def_c.effect_per_rank + def_r.effect_per_rank), 0.01)


func test_honest_value_matches_what_is_actually_applied() -> void:
	var weapon: AutoWeapon = _weapon()
	var system: UpgradeSystem = _system()
	system.set_player_weapon_for_test(weapon)
	var preview: Dictionary = system.get_honest_card_value("heavy_rounds", EPIC)
	assert_str(preview["kind"]).is_equal("fraction")
	assert_float(preview["grant"]).is_equal_approx(0.1 * EPIC, TOL)
	system.apply_rank("heavy_rounds", EPIC)
	assert_float(weapon.get_effective_damage_per_shot()).is_equal_approx(10.0 * (1.0 + preview["total_after"]), TOL)


func test_honest_value_does_not_scale_heals_or_counts_by_rarity() -> void:
	var system: UpgradeSystem = _system()
	for id in ["patch_kit", "repair_kit", "piercing_arrows", "multishot"]:
		var common: Dictionary = system.get_honest_card_value(id, COMMON)
		var epic: Dictionary = system.get_honest_card_value(id, EPIC)
		assert_dict(common).append_failure_message(id + " unknown").is_not_empty()
		assert_float(epic["grant"]).append_failure_message(id + " must not be rarity scaled").is_equal(common["grant"])
		assert_bool(epic["rarity_scaled"]).is_false()


func test_honest_value_unknown_id_is_empty() -> void:
	assert_dict(_system().get_honest_card_value("nope")).is_empty()

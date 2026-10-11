class_name RunEventsTestHelpers
extends RefCounted
## Shared world builder for the run-event suites (docs/32 §A): a real Player, Tower,
## AbilityManager and UpgradeSystem wired together, plus a RunEvents on a fixed seed.
## Not a gdUnit4 suite itself.

const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")


## Returns {player, tower, mgr, us, events, registry}. Every node is auto_free()d by `suite`.
static func build_world(suite: GdUnitTestSuite, seed_value: int = 7) -> Dictionary:
	RunConfig.reset_for_test()
	StatusEffects.reset()
	StatusEffects.clear_burn_modifiers()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	var registry: Node = suite.auto_free(EntityRegistryScript.new()) as Node
	suite.add_child(registry)
	var mgr: AbilityManager = suite.auto_free(AbilityManager.new()) as AbilityManager
	suite.add_child(mgr)
	var us: UpgradeSystem = suite.auto_free(UpgradeSystem.new()) as UpgradeSystem
	suite.add_child(us)
	us.set_ability_manager_for_test(mgr)
	mgr.set_upgrade_system_for_test(us)
	var tower: Tower = suite.auto_free(TowerScene.instantiate()) as Tower
	suite.add_child(tower)
	var player: Player = suite.auto_free(PlayerScene.instantiate()) as Player
	player.driven_externally = true
	player.set_registry_for_test(registry)
	suite.add_child(player)
	us.set_player_for_test(player)
	us.set_player_weapon_for_test(player.get_node("AutoWeapon") as AutoWeapon)
	us.set_tower_weapon_for_test(tower.weapon)
	us.set_tower_health_for_test(tower.health)
	mgr.set_player_for_test(player)
	mgr.set_tower_for_test(tower)
	var events: RunEvents = suite.auto_free(RunEvents.new()) as RunEvents
	events.run_seed = seed_value
	suite.add_child(events)
	events.set_upgrade_system_for_test(us)
	events.set_player_for_test(player)
	events.set_tower_for_test(tower)
	events.set_ability_manager_for_test(mgr)
	return {"player": player, "tower": tower, "mgr": mgr, "us": us, "events": events, "registry": registry}


static func card_ids(offer: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for c in offer.get("cards", []):
		out.append(String(c.get("id", c.get("pact_id", ""))))
	return out


static func cleanup() -> void:
	RunConfig.reset_for_test()
	StatusEffects.reset()
	StatusEffects.clear_burn_modifiers()
	AbilityDamage.reset()
	CombatStats.reset_run_stats()
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	Engine.get_main_loop().paused = false

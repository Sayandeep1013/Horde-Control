extends GdUnitTestSuite

## D144 (review GD P1-7): the Level-Up Draft does not offer a one-shot heal
## that would be wasted (Patch Kit at full player health, Repair Kit at full
## Tower health) while another card is available.

const UpgradeSystemScript: GDScript = preload("res://src/upgrade/upgrade_system.gd")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EntityRegistryScript: GDScript = preload("res://src/core/entity_registry.gd")

var _registry: Node
var _pause: Node
var _clock: Node


func before_test() -> void:
	_registry = auto_free(EntityRegistryScript.new()) as Node
	add_child(_registry)
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func _build_world() -> Dictionary:
	var tower: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(tower)
	var player: Player = auto_free(PlayerScene.instantiate()) as Player
	player.set_registry_for_test(_registry)
	add_child(player)
	var system: UpgradeSystem = auto_free(UpgradeSystemScript.new()) as UpgradeSystem
	add_child(system)
	system.set_player_for_test(player)
	system.set_tower_health_for_test(tower.health)
	return {"tower": tower, "player": player, "system": system}


func test_heals_are_wasted_only_at_full_health() -> void:
	var w: Dictionary = _build_world()
	var system: UpgradeSystem = w["system"]
	var player: Player = w["player"]
	var tower: Tower = w["tower"]
	assert_bool(system.is_card_wasted_now("patch_kit")).is_true()
	assert_bool(system.is_card_wasted_now("repair_kit")).is_true()
	assert_bool(system.is_card_wasted_now("rapid_fire")).is_false()
	player.apply_damage(10.0)
	tower.hurtbox.receive_hit(auto_free(Node.new()), tower.health.max_shield + 50.0, "test")
	assert_bool(system.is_card_wasted_now("patch_kit")).is_false()
	assert_bool(system.is_card_wasted_now("repair_kit")).is_false()


func _open_draft_ids(w: Dictionary, seed_value: int) -> Array[String]:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var wave_director: DraftFakeWaveDirector = auto_free(DraftFakeWaveDirector.new())
	add_child(wave_director)
	wave_director.set_current_wave_id_for_test("wave_combat_1")
	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	controller.run_seed = seed_value
	add_child(controller)
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(w["system"])
	controller.set_wave_director_for_test(wave_director)
	controller.set_pause_authority_for_test(_pause)
	controller.set_sim_clock_for_test(_clock)
	controller.skip_lockout_for_test()
	controller.force_open_for_test()
	var ids: Array[String] = controller.get_current_card_ids_for_test()
	controller.confirm_choice_for_test(0)
	return ids


func test_full_health_drafts_never_offer_either_heal() -> void:
	for seed_value in range(1, 25):
		var w: Dictionary = _build_world() # fresh each time: a shared pool would run out of alternatives
		var ids: Array[String] = _open_draft_ids(w, seed_value)
		assert_array(ids).append_failure_message("seed %d offered a wasted heal: %s" % [seed_value, ids]).not_contains(["patch_kit"])
		assert_array(ids).not_contains(["repair_kit"])

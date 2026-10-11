extends GdUnitTestSuite

## v1.0 WP-ARENA, the assembled scene (Register "v1.0 Arena Interactables"): the ArenaInteractables manager
## and the boon tray exist in scenes/prototype.tscn, find their collaborators,
## receive the one run seed, spawn from the real EventBus.wave_started, and the
## Bounty hook reaches the real PickupSystem. Component behaviour is covered by
## arena_interactables_test.gd and arena_boons_test.gd.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

var _root: Node


func before_test() -> void:
	CombatStats.reset_run_stats()
	_root = auto_free(PrototypeScene.instantiate())
	_root.run_seed = 4321
	add_child(_root)


func after_test() -> void:
	get_tree().paused = false
	CombatStats.reset_run_stats()
	if is_instance_valid(_root):
		var ps: Node = _root.get_node_or_null("Main/PickupSystem")
		if ps != null:
			ps.clear_all_for_test()


func _mgr() -> ArenaInteractables:
	return _root.get_node("Main/ArenaInteractables") as ArenaInteractables


func test_manager_and_tray_exist_and_resolve_their_paths() -> void:
	var mgr: ArenaInteractables = _mgr()
	assert_object(mgr).is_not_null()
	assert_bool(mgr.is_in_group(&"arena_interactables")).is_true()
	assert_object(mgr.get_node_or_null(mgr.entities_path)).is_same(_root.get_node("Main/Entities"))
	assert_object(mgr.get_node_or_null(mgr.pickup_system_path)).is_same(_root.get_node("Main/PickupSystem"))
	assert_object(mgr.get_node_or_null(mgr.arena_path)).is_not_null()
	assert_object(mgr.get_map()).is_not_null()
	assert_object(_root.get_node_or_null("Hud/BoonTray") as BoonTray).is_not_null()


func test_the_one_run_seed_reaches_the_manager() -> void:
	assert_int(_mgr().run_seed).is_equal(4321)
	assert_int(_root.get_run_seed()).is_equal(4321)


func test_the_eight_spike_traps_are_built_under_the_manager_below_pickups() -> void:
	var mgr: ArenaInteractables = _mgr()
	assert_int(mgr.get_traps().size()).is_equal(8)
	assert_int(mgr.z_index).is_less(_root.get_node("Main/Pickups").z_index)
	assert_int(mgr.z_index).is_greater(0)


func test_a_real_wave_started_spawns_crates_a_shrine_and_a_keg_under_the_entities() -> void:
	EventBus.emit_wave_started(3, 15, "standard", false)
	var mgr: ArenaInteractables = _mgr()
	assert_int(mgr.get_crates().size()).is_between(4, 6) # docs/33 B5: 4-6 per wave
	assert_int(mgr.get_kegs().size()).is_equal(1)
	assert_object(mgr.get_shrine()).is_not_null()
	var entities: Node = _root.get_node("Main/Entities")
	for c in mgr.get_crates():
		assert_object(c.get_parent()).is_same(entities) # y-sorted with the units
	assert_object(mgr.get_shrine().get_parent()).is_same(entities)


func test_the_bounty_hook_reaches_the_real_pickup_system() -> void:
	var ps: PickupSystem = _root.get_node("Main/PickupSystem") as PickupSystem
	assert_bool(ps.scrap_multiplier_provider.is_valid()).is_true()
	assert_object(ps.scrap_multiplier_provider.get_object()).is_same(_mgr())
	_mgr().claim_boon("bounty")
	assert_int(ps.scrap_multiplier_provider.call()).is_equal(2)


func test_the_new_cues_and_icons_exist() -> void:
	assert_bool(Sfx.has_cue("wood_break")).is_true()
	assert_bool(Sfx.has_cue("shrine_claim")).is_true()
	for id in ArenaBoon.IDS:
		assert_bool(ResourceLoader.exists(ArenaBoon.icon_path(id))).is_true()


func test_results_names_the_new_damage_sources() -> void:
	assert_str(AbilityDisplay.display_name("keg")).is_equal("Powder Keg")
	assert_str(AbilityDisplay.display_name("spikes")).is_equal("Spike Traps")
	assert_object(AbilityDisplay.icon("keg")).is_not_null()
	assert_object(AbilityDisplay.icon("spikes")).is_not_null()

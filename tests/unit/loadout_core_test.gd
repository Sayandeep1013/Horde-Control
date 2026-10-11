extends GdUnitTestSuite

## WP-LOADOUT core (docs/32 section C; Register "v1.0 Loadout"): unlock derivation,
## slots, selection validation, the RunConfig hand-off and every Champion / Relic
## effect on real nodes. Expectations are independent literals transcribed from the
## Register, not read back from LoadoutCatalog.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const TowerScene: PackedScene = preload("res://scenes/tower.tscn")
const TowerSeekerScene: PackedScene = preload("res://scenes/entities/tower_seeker.tscn")
const PlaceholderEnemyScene: PackedScene = preload("res://scenes/entities/placeholder_enemy.tscn")

var _dir: String


func before_test() -> void:
	_dir = "user://__loadout_core_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	RunConfig.reset_for_test()
	StatusEffects.reset()
	CombatStats.reset_run_stats()


func after_test() -> void:
	RunConfig.reset_for_test()
	StatusEffects.reset()
	CombatStats.reset_run_stats()
	MetaProgress.set_base_path_for_test("user://")


func _write_profile(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir + "profile.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	MetaProgress.reload_for_test()


func _folded(champion: String, relics: Array = []) -> MetaLoadout:
	var l: MetaLoadout = MetaProgress.build_run_loadout()
	LoadoutEffects.fold_into(l, champion, relics)
	return l


# --- Unlock derivation ------------------------------------------------------------

func test_a_fresh_profile_opens_only_ranger_quiver_and_trowel() -> void:
	assert_array(MetaProgress.get_unlocked_champions()).contains_exactly(["ranger"])
	assert_array(MetaProgress.get_unlocked_relics()).contains_exactly(["quiver_of_echoes", "masons_trowel"])
	assert_int(MetaProgress.get_relic_slot_count()).is_equal(1)


func test_every_champion_unlocks_with_its_own_achievement_and_nothing_else() -> void:
	var table: Dictionary = {"warden": "keeper_of_the_keep", "skirmisher": "untouchable", "pactbound": "warchief_slayer"}
	for champion in table.keys():
		assert_bool(MetaProgress.is_champion_unlocked(champion)).is_false()
		MetaProgress.set_achievement_unlocked_for_test(table[champion])
		assert_bool(MetaProgress.is_champion_unlocked(champion)).append_failure_message(champion).is_true()
	assert_bool(MetaProgress.is_champion_unlocked("nobody")).is_false()


func test_each_champion_needs_exactly_its_own_achievement() -> void:
	MetaProgress.set_achievement_unlocked_for_test("keeper_of_the_keep")
	assert_bool(MetaProgress.is_champion_unlocked("warden")).is_true()
	assert_bool(MetaProgress.is_champion_unlocked("skirmisher")).is_false()
	assert_bool(MetaProgress.is_champion_unlocked("pactbound")).is_false()


func test_every_relic_unlocks_from_its_achievement_or_boss_kill() -> void:
	var by_achievement: Dictionary = {"hunters_charm": "goblin_slayer", "lucky_coin": "hoarder", "iron_banner": "mason", "ember_heart": "elite_hunter"}
	for relic in by_achievement.keys():
		assert_bool(MetaProgress.is_relic_unlocked(relic)).append_failure_message("%s starts locked" % relic).is_false()
		MetaProgress.set_achievement_unlocked_for_test(by_achievement[relic])
		assert_bool(MetaProgress.is_relic_unlocked(relic)).append_failure_message(relic).is_true()
	assert_bool(MetaProgress.is_relic_unlocked("warchiefs_horn")).is_false()
	assert_bool(MetaProgress.is_relic_unlocked("kings_crown")).is_false()
	MetaProgress.set_boss_kills_for_test("warchief", 1)
	assert_bool(MetaProgress.is_relic_unlocked("warchiefs_horn")).is_true()
	assert_bool(MetaProgress.is_relic_unlocked("kings_crown")).append_failure_message("the King is a separate kill").is_false()
	MetaProgress.set_boss_kills_for_test("king", 1)
	assert_bool(MetaProgress.is_relic_unlocked("kings_crown")).is_true()


func test_a_real_settlement_unlocks_the_champion_through_the_achievement() -> void:
	# Untouchable is evaluated by settle_run from the run summary; the Champion follows with no second store.
	assert_bool(MetaProgress.is_champion_unlocked("skirmisher")).is_false()
	MetaProgress.settle_run({"run_id": "u1", "sim_time_seconds": 60.0, "untouchable_wave": true})
	assert_bool(MetaProgress.is_champion_unlocked("skirmisher")).is_true()
	assert_bool(MetaProgress.get_profile_for_test().has("unlocked_champions")).append_failure_message("derived, never stored twice").is_false()


# --- Slots and selection ------------------------------------------------------------

func test_slot_two_needs_a_first_victory() -> void:
	assert_bool(MetaProgress.set_selected_relic(1, "quiver_of_echoes")).is_false()
	assert_bool(MetaProgress.set_selected_relic(0, "quiver_of_echoes")).is_true()
	assert_bool(MetaProgress.set_selected_relic(1, "masons_trowel")).append_failure_message("slot 2 is closed before a win").is_false()
	MetaProgress.settle_run({"run_id": "win1", "sim_time_seconds": 60.0, "victory": true, "difficulty_id": "soldier"})
	assert_int(MetaProgress.get_relic_slot_count()).is_equal(2)
	assert_bool(MetaProgress.set_selected_relic(1, "masons_trowel")).is_true()
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["quiver_of_echoes", "masons_trowel"])


func test_a_relic_cannot_fill_both_slots_and_slots_stay_packed() -> void:
	MetaProgress.set_difficulty_victories_for_test("soldier", 1)
	MetaProgress.set_selected_relic(0, "quiver_of_echoes")
	MetaProgress.set_selected_relic(1, "masons_trowel")
	MetaProgress.set_selected_relic(0, "masons_trowel") # moves it
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["masons_trowel"])
	MetaProgress.set_selected_relic(1, "quiver_of_echoes")
	MetaProgress.set_selected_relic(0, "")
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["quiver_of_echoes"])


func test_toggle_replaces_the_oldest_when_every_open_slot_is_taken() -> void:
	assert_bool(MetaProgress.toggle_selected_relic("quiver_of_echoes")).is_true()
	MetaProgress.toggle_selected_relic("masons_trowel") # one slot: replaces
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["masons_trowel"])
	MetaProgress.toggle_selected_relic("masons_trowel") # off
	assert_array(MetaProgress.get_selected_relics()).is_empty()
	assert_bool(MetaProgress.toggle_selected_relic("kings_crown")).append_failure_message("locked").is_false()


func test_locked_choices_are_refused_and_fall_back() -> void:
	assert_bool(MetaProgress.set_selected_champion("warden")).is_false()
	assert_str(MetaProgress.get_selected_champion()).is_equal("ranger")
	MetaProgress.set_achievement_unlocked_for_test("keeper_of_the_keep")
	assert_bool(MetaProgress.set_selected_champion("warden")).is_true()
	assert_str(MetaProgress.get_selected_champion()).is_equal("warden")


func test_a_hand_edited_profile_is_validated_at_load_time() -> void:
	_write_profile({
		"schema_version": 3, "selected_champion": "warden",
		"selected_relics": ["hunters_charm", "bogus", "quiver_of_echoes", "quiver_of_echoes", "masons_trowel"],
	})
	assert_str(MetaProgress.get_selected_champion()).append_failure_message("locked Champion falls back to Ranger").is_equal("ranger")
	assert_array(MetaProgress.get_selected_relics()).append_failure_message("locked, unknown, duplicate and slot-2 relics are dropped").contains_exactly(["quiver_of_echoes"])
	var stored: Dictionary = MetaProgress.get_profile_for_test()
	assert_str(String(stored["selected_champion"])).is_equal("ranger")
	assert_array(stored["selected_relics"]).contains_exactly(["quiver_of_echoes"])


func test_valid_unlocked_choices_survive_a_load() -> void:
	_write_profile({
		"schema_version": 3, "selected_champion": "warden", "unlocked_achievement_ids": ["keeper_of_the_keep"],
		"difficulty_victories": {"soldier": 1}, "selected_relics": ["masons_trowel", "quiver_of_echoes"],
	})
	assert_str(MetaProgress.get_selected_champion()).is_equal("warden")
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["masons_trowel", "quiver_of_echoes"])


func test_a_selection_whose_unlock_is_gone_resets_on_reload() -> void:
	_write_profile({"schema_version": 3, "selected_relics": ["lucky_coin"], "unlocked_achievement_ids": []})
	assert_array(MetaProgress.get_selected_relics()).is_empty()


func test_start_run_writes_the_validated_selection_into_run_config() -> void:
	MetaProgress.set_achievement_unlocked_for_test("keeper_of_the_keep")
	MetaProgress.set_selected_champion("warden")
	MetaProgress.set_selected_relic(0, "masons_trowel")
	MetaProgress.apply_selection_to_run_config()
	assert_str(RunConfig.champion_id).is_equal("warden")
	assert_array(RunConfig.relic_ids).contains_exactly(["masons_trowel"])
	assert_bool(RunConfig.has_relic("masons_trowel")).is_true()
	RunConfig.reset_for_test()
	assert_str(RunConfig.champion_id).is_equal("ranger")
	assert_array(RunConfig.relic_ids).is_empty()


# --- Effects: folding into the loadout (composition with the tree) -----------------------

func test_champion_numbers_match_the_register() -> void:
	var w: MetaLoadout = _folded("warden")
	assert_float(w.player_max_health_bonus).is_equal_approx(-0.10, 0.0001)
	assert_float(w.tower_ability_damage_bonus).is_equal_approx(0.15, 0.0001)
	assert_float(w.tower_regen_in_radius_hp).is_equal_approx(1.0, 0.0001)
	var s: MetaLoadout = _folded("skirmisher")
	assert_float(s.moving_fire_rate_bonus).is_equal_approx(0.15, 0.0001)
	assert_int(s.dash_extra_charges).is_equal(1)
	assert_float(_folded("pactbound").player_max_health_bonus).is_equal_approx(-0.15, 0.0001)
	var r: MetaLoadout = _folded("ranger")
	assert_float(r.player_max_health_bonus).is_equal(0.0)
	assert_int(r.dash_extra_charges).is_equal(0)


func test_relic_numbers_match_the_register() -> void:
	assert_int(_folded("ranger", ["quiver_of_echoes"]).echo_every_shots).is_equal(8)
	assert_float(_folded("ranger", ["masons_trowel"]).tower_repair_bonus).is_equal_approx(0.50, 0.0001)
	assert_float(_folded("ranger", ["hunters_charm"]).xp_gain_bonus).is_equal_approx(0.20, 0.0001)
	assert_float(_folded("ranger", ["warchiefs_horn"]).skill_cooldown_reduction).is_equal_approx(0.15, 0.0001)
	assert_int(_folded("ranger", ["lucky_coin"]).bonus_draft_rerolls).is_equal(1)
	var banner: MetaLoadout = _folded("ranger", ["iron_banner"])
	assert_float(banner.tower_shield_capacity_bonus).is_equal_approx(0.25, 0.0001)
	assert_float(banner.tower_in_wave_shield_regen_fraction).is_equal_approx(0.25, 0.0001)
	assert_float(_folded("ranger", ["ember_heart"]).burn_damage_bonus).is_equal_approx(0.40, 0.0001)
	RunConfig.relic_ids = ["kings_crown"]
	assert_float(RunConfig.elite_chance_add()).is_equal_approx(0.03, 0.0001)
	RunConfig.relic_ids = []
	assert_float(RunConfig.elite_chance_add()).is_equal(0.0)


func test_champion_and_relic_terms_add_to_the_tree_values_instead_of_replacing_them() -> void:
	MetaProgress.set_rank_for_test("vitality", 2) # +20% max HP (Register)
	MetaProgress.set_rank_for_test("masons_kit", 2) # +40% repair
	var l: MetaLoadout = _folded("warden", ["masons_trowel", "hunters_charm"])
	assert_float(l.player_max_health_bonus).append_failure_message("+20% Vitality and -10% Warden").is_equal_approx(0.10, 0.0001)
	assert_float(l.tower_repair_bonus).is_equal_approx(0.90, 0.0001)


func test_the_hooks_receive_one_combined_value_and_repeating_them_changes_nothing() -> void:
	MetaProgress.set_rank_for_test("engineers", 2)
	MetaProgress.set_rank_for_test("skill_focus", 1)
	var mgr: AbilityManager = auto_free(AbilityManager.new())
	add_child(mgr)
	var l: MetaLoadout = _folded("warden", ["masons_trowel", "warchiefs_horn"])
	var before_tower: float = l.tower_ability_damage_bonus
	MetaLoadoutApplier.apply_group_hooks(l, get_tree(), false)
	var tower_mult: float = mgr.get_tower_ability_damage_multiplier()
	var repair: float = mgr.get_repair_multiplier()
	var skill_cd: float = mgr.get_skill_cooldown_multiplier()
	assert_float(tower_mult).is_equal_approx(1.0 + before_tower, 0.0001)
	assert_float(tower_mult).append_failure_message("Engineers x2 (+30%) plus Warden (+15%)").is_equal_approx(1.45, 0.0001)
	assert_float(repair).is_equal_approx(1.50, 0.0001) # Trowel; Mason's Kit is not owned here
	assert_float(skill_cd).append_failure_message("Skill Focus -8% plus Horn -15%").is_equal_approx(1.0 - (0.08 + 0.15), 0.0001)
	MetaLoadoutApplier.apply_group_hooks(l, get_tree(), false)
	MetaLoadoutApplier.apply_group_hooks(l, get_tree(), false)
	assert_float(mgr.get_tower_ability_damage_multiplier()).is_equal_approx(tower_mult, 0.0001)
	assert_float(mgr.get_repair_multiplier()).is_equal_approx(repair, 0.0001)
	assert_float(mgr.get_skill_cooldown_multiplier()).is_equal_approx(skill_cd, 0.0001)


# --- Effects on real nodes -----------------------------------------------------------------

func _player() -> Player:
	var p: Player = auto_free(PlayerScene.instantiate()) as Player
	add_child(p)
	return p


func _tower() -> Tower:
	var t: Tower = auto_free(TowerScene.instantiate()) as Tower
	add_child(t)
	return t


func test_warden_and_pactbound_lower_player_max_health_on_a_runtime_copy() -> void:
	var original: int = preload("res://data/player/prototype.tres").max_health
	var p: Player = _player()
	MetaLoadoutApplier.apply(_folded("warden"), p, null, null, null, null, null)
	assert_float(p.death_state.max_hp).is_equal_approx(float(original) * 0.90, 0.51)
	var p2: Player = _player()
	MetaLoadoutApplier.apply(_folded("pactbound"), p2, null, null, null, null, null)
	assert_float(p2.death_state.max_hp).is_equal_approx(float(original) * 0.85, 0.51)
	assert_int(preload("res://data/player/prototype.tres").max_health).append_failure_message("the authored .tres stays untouched").is_equal(original)


func test_every_non_ranger_champion_gets_a_distinct_palette_and_ranger_keeps_the_pack_blue() -> void:
	var looks: Array = []
	for id in ["warden", "skirmisher", "pactbound"]:
		var p: Player = _player()
		MetaLoadoutApplier.apply(_folded(id), p, null, null, null, null, null)
		var sprite: CanvasItem = p.get_node("Visuals/Sprite2D") as CanvasItem
		assert_object(sprite.material).append_failure_message("%s has a palette material" % id).is_not_null()
		var m: ShaderMaterial = sprite.material as ShaderMaterial
		looks.append(str([m.get_shader_parameter("target_hue"), m.get_shader_parameter("saturation"), m.get_shader_parameter("brightness")]))
	assert_int(looks.size()).is_equal(3)
	assert_bool(looks[0] == looks[1] or looks[1] == looks[2] or looks[0] == looks[2]).append_failure_message("palettes differ").is_false()
	var ranger: Player = _player()
	MetaLoadoutApplier.apply(_folded("ranger"), ranger, null, null, null, null, null)
	assert_object((ranger.get_node("Visuals/Sprite2D") as CanvasItem).material).is_null()


func test_skirmisher_fires_faster_only_while_moving() -> void:
	var p: Player = _player()
	var weapon: AutoWeapon = p.get_node("AutoWeapon") as AutoWeapon
	MetaLoadoutApplier.apply(_folded("skirmisher"), p, null, weapon, null, null, null)
	p.set_local_velocity_for_test(Vector2.ZERO)
	var base: float = weapon.get_effective_fire_interval_seconds()
	p.set_local_velocity_for_test(Vector2(150.0, 0.0))
	assert_bool(p.is_moving()).is_true()
	assert_float(weapon.get_effective_fire_interval_seconds()).is_equal_approx(base / 1.15, 0.0001)
	p.set_local_velocity_for_test(Vector2(3.0, 0.0))
	assert_float(weapon.get_effective_fire_interval_seconds()).append_failure_message("below 8 px/s counts as standing").is_equal_approx(base, 0.0001)


func test_skirmisher_dash_charge_adds_to_the_tree_and_the_hook_is_idempotent() -> void:
	MetaProgress.set_rank_for_test("second_dash", 1)
	var p: Player = _player()
	var mgr: AbilityManager = auto_free(AbilityManager.new())
	add_child(mgr)
	mgr.set_player_for_test(p)
	var combined: MetaLoadout = _folded("skirmisher")
	MetaLoadoutApplier.apply_group_hooks(combined, get_tree(), false)
	var charges: int = int(p.get_dash_state()["max_charges"])
	MetaLoadoutApplier.apply_group_hooks(combined, get_tree(), false)
	assert_int(int(p.get_dash_state()["max_charges"])).is_equal(charges)
	var without: MetaLoadout = _folded("ranger")
	MetaLoadoutApplier.apply_group_hooks(without, get_tree(), false)
	assert_int(int(p.get_dash_state()["max_charges"])).append_failure_message("Skirmisher adds exactly one over the tree").is_equal(charges - 1)


func test_a_ranger_loadout_leaves_the_bow_alone() -> void:
	var p: Player = _player()
	var weapon: AutoWeapon = p.get_node("AutoWeapon") as AutoWeapon
	var base: float = weapon.get_effective_fire_interval_seconds()
	MetaLoadoutApplier.apply(_folded("ranger"), p, null, weapon, null, null, null)
	p.set_local_velocity_for_test(Vector2(150.0, 0.0))
	assert_float(weapon.get_effective_fire_interval_seconds()).is_equal(base)


func _hits_after_nine_shots(echo_every: int) -> int:
	var shooter: Node2D = auto_free(Node2D.new()) as Node2D
	add_child(shooter)
	var container := Node2D.new()
	container.name = "Projectiles"
	shooter.add_child(container)
	var weapon: AutoWeapon = AutoWeapon.new()
	weapon.definition = preload("res://data/weapons/handgun.tres")
	weapon.projectiles_container_path = NodePath("../Projectiles")
	weapon.driven_externally = true
	shooter.add_child(weapon)
	weapon.set_fire_rate_multiplier(20.0)
	weapon.set_echo_every_shots(echo_every)
	var enemy: Node = auto_free(PlaceholderEnemyScene.instantiate())
	(enemy.get_node("DeathState") as DeathState).max_hp = 1000000.0
	add_child(enemy)
	enemy.global_position = Vector2(60, 0)
	EntityRegistry.register_entity(enemy, Vector2(60, 0), [&"enemy"])
	var counters: Dictionary = {"hits": 0, "shots": 0}
	(enemy.get_node("DeathState") as DeathState).damage_applied.connect(func(_a: float, _s: Variant, _r: float) -> void: counters["hits"] += 1)
	weapon.fired.connect(func(_t: float) -> void: counters["shots"] += 1)
	var guard: int = 0
	while int(counters["shots"]) < 9 and guard < 4000:
		weapon.physics_step(1.0 / 60.0)
		await get_tree().physics_frame
		guard += 1
	for i in 40:
		await get_tree().physics_frame
	EntityRegistry.deregister_entity(enemy)
	return int(counters["hits"])


## One run per test: a second weapon and enemy in the same test inherit the first
## one's still-flying arrows and registry slot, which skews the count.
func test_without_the_quiver_nine_shots_land_nine_arrows() -> void:
	assert_int(await _hits_after_nine_shots(0)).is_equal(9)


func test_quiver_of_echoes_adds_exactly_one_arrow_on_the_eighth_shot() -> void:
	assert_int(await _hits_after_nine_shots(8)).append_failure_message("nine shots land nine arrows plus one echo").is_equal(10)


func _repair_rig() -> Dictionary:
	var tower: Tower = _tower()
	var player: Player = _player()
	var repair: TowerRepair = auto_free(TowerRepair.new())
	add_child(repair)
	repair.set_tower_for_test(tower)
	var inv := RunInventory.new()
	inv.configure(preload("res://data/economy/prototype.tres"), null)
	repair.set_run_inventory_for_test(inv)
	tower.death_state.current_hp = tower.health.max_health - 100.0
	return {"tower": tower, "player": player, "repair": repair, "inv": inv}


func test_warden_regen_heals_one_hp_per_second_inside_the_radius_even_without_scrap() -> void:
	var rig: Dictionary = _repair_rig()
	var tower: Tower = rig["tower"]
	var repair: TowerRepair = rig["repair"]
	repair.set_passive_regen_hp_per_second(1.0)
	var hp0: float = tower.health.get_current_health()
	for i in 120:
		repair.physics_step(1.0 / 60.0)
	assert_float(tower.health.get_current_health()).append_failure_message("outside the radius nothing heals").is_equal(hp0)
	tower.interaction_radius._on_body_entered(rig["player"])
	for i in 120: # two seconds
		repair.physics_step(1.0 / 60.0)
	assert_float(tower.health.get_current_health() - hp0).is_equal_approx(2.0, 0.01)
	assert_float(CombatStats.get_run_counter("tower_repaired")).append_failure_message("the trickle is not Scrap repair").is_equal(0.0)
	assert_bool(repair.is_repairing()).is_false()


func test_warden_regen_never_stacks_with_scrap_repair() -> void:
	var rig: Dictionary = _repair_rig()
	var tower: Tower = rig["tower"]
	var repair: TowerRepair = rig["repair"]
	var inv: RunInventory = rig["inv"]
	inv.credit_scrap(40)
	repair.set_passive_regen_hp_per_second(1.0)
	tower.interaction_radius._on_body_entered(rig["player"])
	var hp0: float = tower.health.get_current_health()
	for i in 60:
		repair.physics_step(1.0 / 60.0)
	var spent: int = 40 - inv.scrap_current
	assert_int(spent).is_greater(0)
	assert_float(tower.health.get_current_health() - hp0).append_failure_message("a Scrap-repair second heals exactly 3 per Scrap, with no extra trickle").is_equal_approx(float(spent) * 3.0, 0.01)


func test_warden_regen_stops_at_full_health_and_without_the_hook_does_nothing() -> void:
	var rig: Dictionary = _repair_rig()
	var tower: Tower = rig["tower"]
	var repair: TowerRepair = rig["repair"]
	tower.interaction_radius._on_body_entered(rig["player"])
	var hp0: float = tower.health.get_current_health()
	for i in 60:
		repair.physics_step(1.0 / 60.0)
	assert_float(tower.health.get_current_health()).append_failure_message("no Warden: no trickle").is_equal(hp0)
	repair.set_passive_regen_hp_per_second(1.0)
	tower.death_state.current_hp = tower.health.max_health - 0.5
	for i in 120:
		repair.physics_step(1.0 / 60.0)
	assert_float(tower.health.get_current_health()).is_equal(tower.health.max_health)


func test_the_regen_hook_reaches_the_tower_repair_node_by_group() -> void:
	var rig: Dictionary = _repair_rig()
	var repair: TowerRepair = rig["repair"]
	var l: MetaLoadout = _folded("warden")
	var result: Dictionary = MetaLoadoutApplier.apply_group_hooks(l, get_tree(), false)
	assert_array(result["called"]).contains(["set_passive_regen_hp_per_second"])
	assert_float(repair.get_passive_regen_hp_per_second()).is_equal(1.0)
	MetaLoadoutApplier.apply_group_hooks(l, get_tree(), false)
	assert_float(repair.get_passive_regen_hp_per_second()).append_failure_message("absolute, not additive").is_equal(1.0)


func test_iron_banner_raises_the_shield_and_regenerates_it_during_waves() -> void:
	var t0: Tower = _tower()
	var base_shield: float = t0.health.max_shield
	assert_float(t0.health.in_wave_rate_fraction).append_failure_message("the base Tower does not regenerate its shield in waves").is_equal(0.0)
	var t: Tower = _tower()
	MetaLoadoutApplier.apply(_folded("ranger", ["iron_banner"]), null, t, null, null, null, null)
	assert_float(t.health.max_shield).is_equal_approx(base_shield * 1.25, 0.01)
	assert_float(t.health.in_wave_rate_fraction).is_equal_approx(0.25, 0.0001)
	# And it actually regenerates mid-wave at a quarter of the between-waves rate.
	t.health.set_wave_open(true)
	t.health.current_shield = 0.0
	t.health._last_damage_sim_time = -INF
	t.health._last_regen_sim_time = SimClock.now
	SimClock.now += 2.0
	t.health._try_regenerate_shield()
	var per_second_full: float = t.health.max_shield * (t.health.regen_rate_percent_per_second / 100.0)
	assert_float(t.health.current_shield).is_equal_approx(per_second_full * 0.25 * 2.0, 0.05)
	assert_float(base_shield).is_greater(0.0)


func test_a_loadout_without_the_banner_leaves_the_tower_definition_alone() -> void:
	var t: Tower = _tower()
	var shield: float = t.health.max_shield
	MetaLoadoutApplier.apply(_folded("warden"), null, t, null, null, null, null)
	assert_float(t.health.max_shield).is_equal(shield)
	assert_float(t.health.in_wave_rate_fraction).is_equal(0.0)


func _burn_damage(relics: Array) -> float:
	StatusEffects.reset()
	CombatStats.reset_run_stats()
	MetaLoadoutApplier.apply(_folded("ranger", relics), null, null, null, null, null, null)
	var runner: StatusEffectsRunner = auto_free(StatusEffectsRunner.new())
	add_child(runner)
	var e: EnemyController = TowerSeekerScene.instantiate() as EnemyController
	e.driven_externally = true
	add_child(e)
	auto_free(e)
	e.global_position = Vector2(100, 0)
	EntityRegistry.update_position(e, Vector2(100, 0))
	var hp0: float = e.death_state.current_hp
	StatusEffects.apply_burn(e, 10.0, 2.0, "flame_arrows")
	for i in 5:
		SimClock.now += StatusEffects.BURN_TICK_SECONDS
		runner.tick()
	return hp0 - e.death_state.current_hp


func test_ember_heart_raises_burn_damage_by_forty_percent_and_resets_next_run() -> void:
	var plain: float = _burn_damage([])
	var ember: float = _burn_damage(["ember_heart"])
	assert_float(plain).is_greater(0.0)
	assert_float(ember / plain).is_equal_approx(1.4, 0.001)
	var again: float = _burn_damage([])
	assert_float(again).append_failure_message("an absolute set: the next run without the relic is neutral").is_equal_approx(plain, 0.001)


func test_ember_heart_also_scales_the_firebomb_ground() -> void:
	MetaLoadoutApplier.apply(_folded("ranger", ["ember_heart"]), null, null, null, null, null, null)
	assert_float(StatusEffects.get_burn_damage_multiplier()).is_equal_approx(1.4, 0.0001)


func test_hunters_charm_and_lucky_coin_reach_xp_and_rerolls() -> void:
	var inv := RunInventory.new()
	inv.configure(preload("res://data/economy/prototype.tres"), null)
	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	var base_rerolls: int = controller.get_rerolls_remaining()
	var l: MetaLoadout = _folded("ranger", ["hunters_charm", "lucky_coin"])
	MetaLoadoutApplier.apply(l, null, null, null, inv, controller, null)
	var xp0: float = inv.xp_current
	inv.credit_xp(2.0)
	assert_float(inv.xp_current - xp0).is_equal_approx(2.4, 0.01)
	assert_int(controller.get_rerolls_remaining()).is_equal(base_rerolls + 1)


func test_kings_crown_adds_a_core_per_elite_at_settlement() -> void:
	var plain: Dictionary = MetaProgress.preview_settlement({"elite_kills": 5})
	var crown: Dictionary = MetaProgress.preview_settlement({"elite_kills": 5, "relic_ids": ["kings_crown"]})
	assert_int(int(crown["total_cores"]) - int(plain["total_cores"])).is_equal(5)
	var other: Dictionary = MetaProgress.preview_settlement({"elite_kills": 5, "relic_ids": ["lucky_coin"]})
	assert_int(int(other["total_cores"])).is_equal(int(plain["total_cores"]))


func test_kings_crown_raises_the_elite_chance_term_the_director_uses() -> void:
	var director: WaveDirector = auto_free(WaveDirector.new())
	var base: float = director.get_elite_chance_for_test(7, 0.0, RunConfig.elite_chance_add())
	RunConfig.relic_ids = ["kings_crown"]
	var crowned: float = director.get_elite_chance_for_test(7, 0.0, RunConfig.elite_chance_add())
	assert_float(crowned - base).is_equal_approx(0.03, 0.0001)

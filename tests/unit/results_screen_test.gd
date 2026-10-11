extends GdUnitTestSuite

## v1.0 Results screen and the run flow behind it (WP-META, D254; docs/31
## section 8.3): outcome, difficulty, kills, elites, the top-6 damage report,
## the Retry / War Camp / Main Menu choices, and RunFlowController's tallies
## (elites, bosses, repair, abilities, an untouched wave) reaching settlement.

const RunFlowControllerScript: GDScript = preload("res://src/run/run_flow_controller.gd")
const RunInventoryScript: GDScript = preload("res://src/economy/run_inventory.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")

var _dir: String
var _fired: Array[String] = []


func before_test() -> void:
	_dir = "user://__results_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()
	_fired = []


func after_test() -> void:
	RunConfig.reset_for_test()
	CombatStats.reset_run_stats()
	MetaProgress.set_base_path_for_test("user://")
	get_tree().paused = false


func _screen() -> RunEndScreen:
	var screen: RunEndScreen = auto_free(RunEndScreen.new())
	add_child(screen)
	return screen


func _report(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append({"source_id": ["bow", "tower_bow", "flame_arrows", "burn", "ballista", "whirling_axes", "caltrops", "frost_ward"][i % 8], "damage": float(1000 - i * 100)})
	return out


# --- The screen ---------------------------------------------------------------------

func test_the_damage_report_lists_at_most_six_sources_largest_first() -> void:
	var screen: RunEndScreen = _screen()
	screen.show_summary({"damage_report": _report(8)})
	var box: VBoxContainer = screen.get_damage_box_for_test()
	assert_int(box.get_child_count()).append_failure_message("top 6 only").is_equal(6)
	var first: HBoxContainer = box.get_child(0) as HBoxContainer
	assert_str((first.get_node("Name") as Label).text).is_equal("Bow")
	assert_str((first.get_node("Value") as Label).text).is_equal("1000")
	assert_float((first.get_node("Bar") as ProgressBar).value).is_equal(1.0)
	var last: HBoxContainer = box.get_child(5) as HBoxContainer
	assert_str((last.get_node("Value") as Label).text).is_equal("500")
	assert_float((last.get_node("Bar") as ProgressBar).value).append_failure_message("bars scale to the biggest source").is_equal_approx(0.5, 0.001)


func test_every_damage_source_has_a_display_name_and_an_icon() -> void:
	var ids: Array[String] = ["bow", "tower_bow", "burn", "spiked_palisade"]
	ids.append_array(AbilityIds.PLAYER_ABILITIES)
	ids.append_array(AbilityIds.TOWER_ABILITIES)
	ids.append_array(AbilityIds.BATTLE_SKILLS)
	for id in ids:
		assert_str(TranslationServer.translate("ABILITY_NAME_%s" % id.to_upper())).is_not_equal("ABILITY_NAME_%s" % id.to_upper())
		assert_object(AbilityDisplay.icon(id)).append_failure_message("'%s' has no icon" % id).is_not_null()
	assert_object(AbilityDisplay.icon("not_an_ability")).append_failure_message("unknown ids fall back to a plain square").is_not_null()


func test_an_empty_report_says_so_instead_of_drawing_nothing() -> void:
	var screen: RunEndScreen = _screen()
	screen.show_summary({"damage_report": []})
	assert_int(screen.get_damage_box_for_test().get_child_count()).is_equal(1)
	assert_str((screen.get_damage_box_for_test().get_child(0) as Label).text).is_equal(tr("RESULTS_NO_DAMAGE"))


func test_stats_difficulty_and_endless_wave_are_shown() -> void:
	var screen: RunEndScreen = _screen()
	screen.show_summary({"wave_reached": 17, "wave_total": 15, "kills": 412, "elite_kills": 9, "difficulty_name": "Veteran", "endless": true, "scrap_held": 5, "time_survived_seconds": 905.0})
	assert_str(screen.get_kills_label_for_test().text).is_equal("Kills: 412")
	assert_str(screen.get_elites_label_for_test().text).is_equal("Elites: 9")
	assert_str(screen.get_difficulty_label_for_test().text).contains("Veteran")
	assert_str(screen.get_difficulty_label_for_test().text).contains("Endless")
	assert_str(screen.get_wave_label_for_test().text).append_failure_message("Endless has no final wave to divide by").is_equal("Wave reached: 17")
	assert_str(screen.get_time_label_for_test().text).contains("15:05")
	screen.show_summary({"wave_reached": 15, "wave_total": 15, "difficulty_name": "Soldier"})
	assert_str(screen.get_wave_label_for_test().text).is_equal("Wave reached: 15/15")


func test_the_three_choices_emit_their_own_signals() -> void:
	var screen: RunEndScreen = _screen()
	screen.show_summary({})
	screen.retry_requested.connect(func() -> void: _fired.append("retry"))
	screen.war_camp_requested.connect(func() -> void: _fired.append("war_camp"))
	screen.main_menu_requested.connect(func() -> void: _fired.append("main_menu"))
	screen._on_option_confirmed(RunEndScreen.OPTION_RETRY)
	screen._on_option_confirmed(RunEndScreen.OPTION_WAR_CAMP)
	screen._on_option_confirmed(RunEndScreen.OPTION_MAIN_MENU)
	assert_array(_fired).contains_exactly(["retry", "war_camp", "main_menu"])
	assert_int(screen.get_bar_for_test().get_option_count()).is_equal(3)


func test_settlement_ribbons_cover_unlocks_and_the_endless_best() -> void:
	var screen: RunEndScreen = _screen()
	screen.set_settlement({
		"lines": [{"label": "Victory", "amount": 10}], "total_cores": 10, "saved": true,
		"new_best_endless_wave": true, "unlocked_difficulty": "veteran", "unlocked_endless": true,
		"newly_unlocked_achievements": [{"id": "founder", "display_name": "Founder"}],
	})
	var ribbons: int = 0
	for child in screen.get_ribbons_box_for_test().get_children():
		if child is PanelContainer and (child as PanelContainer).theme_type_variation == UiTheme.RIBBON:
			ribbons += 1
	assert_int(ribbons).append_failure_message("endless best + Veteran + Endless + Founder").is_equal(4)


## The card is capped to the visible canvas and its body scrolls, so the choice
## bar can never be pushed off the screen however many rows the report has (the
## 1080 and 720 captures confirm it on a real window).
func test_the_card_is_capped_to_the_canvas_so_the_choices_stay_reachable() -> void:
	var screen: RunEndScreen = _screen()
	screen.show_summary({"wave_reached": 15, "wave_total": 15, "kills": 500, "elite_kills": 12, "difficulty_name": "Warlord", "damage_report": _report(8), "scrap_held": 100, "time_survived_seconds": 900.0, "run_seed": 7})
	screen.set_settlement({"lines": [{"label": "Time survived (15 min)", "amount": 15}, {"label": "Waves cleared (15)", "amount": 30}, {"label": "Enemies defeated (500)", "amount": 20}, {"label": "Victory", "amount": 10}], "total_cores": 75, "saved": true})
	screen.set_active(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var card: PanelContainer = screen._frame.card
	var canvas_height: float = screen.get_viewport().get_visible_rect().size.y
	assert_float(card.custom_maximum_size.y).append_failure_message("the card must be capped to the canvas").is_less_equal(canvas_height)
	assert_float(card.size.y).is_less_equal(canvas_height)
	assert_bool(screen.get_bar_for_test().is_visible_in_tree()).is_true()


# --- RunFlowController ------------------------------------------------------------------

func _bus() -> Node:
	var bus := Node.new()
	for name in ["player_died", "enemy_died"]:
		bus.add_user_signal(name, [{"name": "entity", "type": TYPE_OBJECT}, {"name": "position", "type": TYPE_VECTOR2}, {"name": "timestamp", "type": TYPE_FLOAT}])
	bus.add_user_signal("elite_killed", [{"name": "entity", "type": TYPE_OBJECT}, {"name": "affix", "type": TYPE_STRING}, {"name": "timestamp", "type": TYPE_FLOAT}])
	bus.add_user_signal("boss_defeated", [{"name": "boss_id", "type": TYPE_STRING}, {"name": "position", "type": TYPE_VECTOR2}, {"name": "timestamp", "type": TYPE_FLOAT}])
	bus.add_user_signal("tower_repaired", [{"name": "health_restored", "type": TYPE_FLOAT}, {"name": "scrap_spent", "type": TYPE_INT}, {"name": "timestamp", "type": TYPE_FLOAT}])
	bus.add_user_signal("ability_leveled", [{"name": "ability_id", "type": TYPE_STRING}, {"name": "level", "type": TYPE_INT}, {"name": "slot_kind", "type": TYPE_STRING}, {"name": "timestamp", "type": TYPE_FLOAT}])
	bus.add_user_signal("wave_started", [{"name": "wave_number", "type": TYPE_INT}, {"name": "wave_count", "type": TYPE_INT}, {"name": "wave_type", "type": TYPE_STRING}, {"name": "is_boss", "type": TYPE_BOOL}, {"name": "timestamp", "type": TYPE_FLOAT}])
	add_child(bus)
	auto_free(bus)
	return bus


func _director() -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nsignal sequence_completed()\nsignal wave_opened(wave_id: String, wave_index: int)\nsignal wave_ended(wave_id: String, wave_index: int)\nvar waves: Array = []\nvar idx: int = 0\nfunc get_current_wave_index_for_test() -> int:\n\treturn idx\n"
	script.reload()
	var n := Node.new()
	n.set_script(script)
	var arr: Array = n.get("waves")
	for _i in 15:
		arr.append(null)
	n.set("waves", arr)
	add_child(n)
	auto_free(n)
	return n


func _controller(clock: Node, wd: Node, bus: Node) -> RunFlowController:
	var c: RunFlowController = RunFlowControllerScript.new() as RunFlowController
	var pause: Node = auto_free(PauseAuthorityScript.new())
	add_child(pause)
	c.set_pause_authority_for_test(pause)
	c.set_sim_clock_for_test(clock)
	c.set_wave_director_for_test(wd)
	c.set_event_bus_for_test(bus)
	c.set_suppress_quit_for_test(true)
	c.set_suppress_scene_change_for_test(true)
	auto_free(c)
	add_child(c)
	c.set_run_inventory(RunInventoryScript.new() as RunInventory)
	return c


func _clock() -> Node:
	var clock: Node = SimClockScript.new()
	clock.now = 0.0
	auto_free(clock)
	return clock


## Retry keeps the SAME RunConfig and loads the run scene; nothing resets it.
func test_retry_keeps_run_config_and_requests_the_run_scene() -> void:
	RunConfig.difficulty_id = "veteran"
	RunConfig.battle_skill_id = "firebomb"
	RunConfig.endless = true
	var wd: Node = _director()
	var c: RunFlowController = _controller(_clock(), wd, _bus())
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	c.run_end_screen._on_option_confirmed(RunEndScreen.OPTION_RETRY)
	assert_str(c.get_last_scene_change_for_test()).is_equal("res://scenes/prototype.tscn")
	assert_str(RunConfig.difficulty_id).is_equal("veteran")
	assert_str(RunConfig.battle_skill_id).is_equal("firebomb")
	assert_bool(RunConfig.endless).is_true()
	assert_array(c.get("_pause_authority").get_active_reasons()).append_failure_message("the run-end pause is released before the scene changes").is_empty()


func test_war_camp_choice_goes_to_the_hub() -> void:
	var c: RunFlowController = _controller(_clock(), _director(), _bus())
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	c.run_end_screen._on_option_confirmed(RunEndScreen.OPTION_WAR_CAMP)
	assert_str(c.get_last_scene_change_for_test()).is_equal("res://scenes/hub.tscn")


func test_killing_the_king_wins_the_run_and_the_summary_carries_the_report() -> void:
	RunConfig.difficulty_id = "veteran"
	CombatStats.record_damage("bow", 900.0)
	CombatStats.record_damage("ballista", 300.0)
	var bus: Node = _bus()
	var wd: Node = _director()
	var c: RunFlowController = _controller(_clock(), wd, bus)
	bus.emit_signal("enemy_died", null, Vector2.ZERO, 0.0)
	bus.emit_signal("elite_killed", null, "swift", 0.0)
	bus.emit_signal("elite_killed", null, "armored", 0.0)
	bus.emit_signal("boss_defeated", "king", Vector2.ZERO, 0.0)
	await get_tree().process_frame
	assert_int(c.get_end_cause_for_test()).is_equal(RunFlowController.EndCause.SEQUENCE_COMPLETED)
	var summary: Dictionary = c.get_summary_for_test()
	assert_bool(bool(summary["victory"])).is_true()
	assert_str(String(summary["difficulty_name"])).is_equal("Veteran")
	assert_int(int(summary["elite_kills"])).is_equal(2)
	assert_int((summary["damage_report"] as Array).size()).is_equal(2)
	assert_str(String(((summary["damage_report"] as Array)[0] as Dictionary)["source_id"])).is_equal("bow")
	# The tallies reached settlement: the Veteran win unlocked Warlord and the King kill earned Regicide.
	assert_bool(MetaProgress.is_difficulty_unlocked("warlord")).is_true()
	assert_bool(MetaProgress.is_achievement_unlocked("regicide")).is_true()
	assert_int(MetaProgress.get_lifetime_elite_kills()).is_equal(2)
	assert_int(MetaProgress.get_lifetime_boss_kills("king")).is_equal(1)
	assert_bool(MetaProgress.is_endless_unlocked()).is_true()


func test_in_endless_the_king_does_not_end_the_run_and_the_wave_count_passes_the_sequence() -> void:
	RunConfig.endless = true
	var bus: Node = _bus()
	var c: RunFlowController = _controller(_clock(), _director(), bus)
	bus.emit_signal("boss_defeated", "king", Vector2.ZERO, 0.0)
	c.get_node(".")._on_sequence_completed() # a director that still announces the sequence must be ignored in Endless
	await get_tree().process_frame
	assert_int(c.get_state_for_test()).append_failure_message("Endless ends only on defeat").is_equal(RunFlowController.State.RUNNING)
	bus.emit_signal("wave_started", 21, 15, "standard", false, 0.0)
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	assert_int(MetaProgress.get_best_endless_wave()).append_failure_message("the signal's wave number is the Endless wave").is_equal(21)
	assert_array(MetaProgress.get_unlocked_achievement_ids()).contains(["endless_20"])


func test_a_wave_five_or_later_cleared_without_player_damage_is_untouchable() -> void:
	var bus: Node = _bus()
	var wd: Node = _director()
	var c: RunFlowController = _controller(_clock(), wd, bus)
	# Wave 5 (index 4): damage taken during it, so not untouchable.
	wd.emit_signal("wave_opened", "w5", 4)
	CombatStats.add_run_counter("damage_taken", 12.0)
	wd.emit_signal("wave_ended", "w5", 4)
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	assert_bool(MetaProgress.is_achievement_unlocked("untouchable")).append_failure_message("damage taken in the wave").is_false()

	MetaProgress.set_base_path_for_test("user://__results_test_b_%d/" % randi())
	var wd2: Node = _director()
	var c2: RunFlowController = _controller(_clock(), wd2, _bus())
	wd2.emit_signal("wave_opened", "w2", 1)
	wd2.emit_signal("wave_ended", "w2", 1) # wave 2 does not count
	wd2.emit_signal("wave_opened", "w6", 5)
	wd2.emit_signal("wave_ended", "w6", 5) # untouched wave 6
	c2.simulate_player_died_for_test()
	await get_tree().process_frame
	assert_bool(MetaProgress.is_achievement_unlocked("untouchable")).is_true()


func test_repair_and_player_ability_tallies_reach_the_profile() -> void:
	var bus: Node = _bus()
	var c: RunFlowController = _controller(_clock(), _director(), bus)
	bus.emit_signal("tower_repaired", 300.0, 100, 0.0)
	bus.emit_signal("tower_repaired", 450.0, 150, 0.0)
	for id in ["flame_arrows", "whirling_axes", "caltrops", "storm_bolt", "blade_circle", "diagonal_arrows"]: # D360: Full Arsenal = 6
		bus.emit_signal("ability_leveled", id, 1, "player", 0.0)
	bus.emit_signal("ability_leveled", "ballista", 1, "tower", 0.0)
	bus.emit_signal("ability_leveled", "flame_arrows", 2, "player", 0.0) # a level-up, not a new ability
	c.simulate_tower_destroyed_for_test()
	await get_tree().process_frame
	assert_int(MetaProgress.get_lifetime_repair()).is_equal(750)
	assert_bool(MetaProgress.is_achievement_unlocked("full_arsenal")).append_failure_message("six distinct player abilities; the Tower one does not count").is_true()


func test_a_defeat_unlocks_nothing_and_settles_at_the_difficulty_multiplier() -> void:
	RunConfig.difficulty_id = "warlord"
	var clock: Node = _clock()
	var c: RunFlowController = _controller(clock, _director(), _bus())
	clock.now = 600.0
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	# 10 minutes = 10 Cores, x1.85 = 18
	assert_int(MetaProgress.get_cores()).is_equal(18)
	assert_bool(MetaProgress.is_difficulty_unlocked("veteran")).is_false()


# --- The cause line names the killer (D247) ---------------------------------------------

func _enemy(kind: String, affix: String = "") -> EnemyController:
	var e: EnemyController = auto_free(EnemyController.new())
	e.definition = load("res://data/enemies/%s.tres" % kind) as EnemyDefinition
	e.elite_affix = affix
	return e


func _cause_after(target: String, enemy: Variant, hitbox: Variant = null) -> String:
	var c: RunFlowController = _controller(_clock(), _director(), _bus())
	if enemy != null:
		c.record_damager_for_test(target, enemy, hitbox)
	if target == "player":
		c.simulate_player_died_for_test()
	else:
		c.simulate_tower_destroyed_for_test()
	await get_tree().process_frame
	return String(c.get_summary_for_test()["cause_text"])


func test_the_player_cause_line_names_the_last_enemy_that_hit_them() -> void:
	assert_str(await _cause_after("player", _enemy("bomber"))).is_equal("Slain by a Bomber")
	assert_str(await _cause_after("player", _enemy("tower_seeker"))).is_equal("Slain by a Torch Goblin")


func test_the_tower_cause_line_names_the_last_enemy_that_hit_the_tower() -> void:
	assert_str(await _cause_after("tower", _enemy("brute"))).is_equal("The Tower fell to a Brute")


func test_elites_and_bosses_are_named_and_a_blast_resolves_through_its_attacker() -> void:
	assert_str(await _cause_after("player", _enemy("brute", "armored"))).is_equal("Slain by an elite Brute")
	assert_str(await _cause_after("tower", _enemy("goblin_warchief"))).is_equal("The Tower fell to the Goblin Warchief")
	# EnemyBlast reports the hit with a tag as `source` and the attacker as the hitbox argument.
	assert_str(await _cause_after("player", &"enemy_blast", _enemy("bomber"))).is_equal("Slain by a Bomber")


func test_an_unknown_killer_keeps_the_generic_line_and_never_repeats_the_title() -> void:
	assert_str(await _cause_after("player", null)).is_equal("You were defeated")
	assert_str(await _cause_after("tower", null)).is_equal("The Tower was destroyed")
	var c: RunFlowController = _controller(_clock(), _director(), _bus())
	c.record_damager_for_test("player", _enemy("bomber"))
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	var summary: Dictionary = c.get_summary_for_test()
	assert_str(String(summary["cause_text"])).is_not_equal(String(summary["outcome_title"]))


# --- WP-LOADOUT: the Champion and Relics through the run flow ---------------------------

func test_retry_keeps_the_champion_and_relics() -> void:
	RunConfig.champion_id = "pactbound"
	RunConfig.relic_ids = ["warchiefs_horn", "ember_heart"]
	var c: RunFlowController = _controller(_clock(), _director(), _bus())
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	c.run_end_screen._on_option_confirmed(RunEndScreen.OPTION_RETRY)
	assert_str(RunConfig.champion_id).is_equal("pactbound")
	assert_array(RunConfig.relic_ids).contains_exactly(["warchiefs_horn", "ember_heart"])


func test_the_end_summary_carries_the_loadout_and_the_results_screen_lists_it() -> void:
	RunConfig.champion_id = "skirmisher"
	RunConfig.relic_ids = ["lucky_coin", "iron_banner"]
	var c: RunFlowController = _controller(_clock(), _director(), _bus())
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	var summary: Dictionary = c.get_summary_for_test()
	assert_str(String(summary["champion_id"])).is_equal("skirmisher")
	assert_array(summary["relic_ids"]).contains_exactly(["lucky_coin", "iron_banner"])
	var box: HFlowContainer = c.run_end_screen.get_loadout_box_for_test()
	assert_int(box.get_child_count()).append_failure_message("a Champion chip and two Relic chips").is_equal(3)
	assert_str((box.get_child(0).get_node("Name") as Label).text).is_equal("Skirmisher")
	assert_str((box.get_child(1).get_node("Name") as Label).text).is_equal("Lucky Coin")
	assert_object((box.get_child(2).get_node("Icon") as TextureRect).texture).is_not_null()


func test_the_run_summary_hands_the_relics_to_settlement_so_the_crown_pays_per_elite() -> void:
	RunConfig.relic_ids = ["kings_crown"]
	var bus: Node = _bus()
	var c: RunFlowController = _controller(_clock(), _director(), bus)
	bus.emit_signal("elite_killed", null, "swift", 0.0)
	bus.emit_signal("elite_killed", null, "armored", 0.0)
	c.simulate_player_died_for_test()
	await get_tree().process_frame
	# 0 minutes, 0 waves, 0 kills; two elites at 1 + 1 (the Crown) = 4 Cores.
	assert_int(MetaProgress.get_cores()).is_equal(4)

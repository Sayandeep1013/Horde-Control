extends GdUnitTestSuite

## WP-LOADOUT screens (docs/32 C3): the War Camp Loadout tab, the pause listing, the
## Achievements reward lines and the Start Run hand-off. (The Results listing and Retry
## live in results_screen_test.gd, beside the run-flow fixtures they need.) Every test
## redirects MetaProgress to a throwaway directory first.

var _dir: String


func before_test() -> void:
	_dir = "user://__loadout_ui_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	RunConfig.reset_for_test()


func after_test() -> void:
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")


func _save() -> void:
	MetaProgress.settle_run({"run_id": "prep_%d" % randi(), "sim_time_seconds": 0.0}) # persists the in-memory grants


func _make_hub() -> HubScreen:
	var hub: HubScreen = auto_free(HubScreen.new())
	hub.set_suppress_scene_change_for_test(true)
	add_child(hub)
	return hub


func test_the_loadout_tab_lists_four_champions_and_eight_relics_with_locks_greyed() -> void:
	var hub: HubScreen = _make_hub()
	for id in ["ranger", "warden", "skirmisher", "pactbound"]:
		assert_object(hub.get_champion_button_for_test(id)).append_failure_message(id).is_not_null()
	for id in ["quiver_of_echoes", "masons_trowel", "hunters_charm", "warchiefs_horn", "kings_crown", "lucky_coin", "iron_banner", "ember_heart"]:
		assert_object(hub.get_relic_button_for_test(id)).append_failure_message(id).is_not_null()
	assert_float(hub.get_champion_button_for_test("ranger").modulate.a).is_equal(1.0)
	assert_float(hub.get_champion_button_for_test("warden").modulate.a).append_failure_message("locked is dimmed").is_less(1.0)
	assert_float(hub.get_relic_button_for_test("masons_trowel").modulate.a).is_equal(1.0)
	assert_float(hub.get_relic_button_for_test("kings_crown").modulate.a).is_less(1.0)
	assert_bool(hub.get_champion_button_for_test("ranger").button_pressed).is_true()


func test_the_run_and_loadout_pages_swap_and_the_hint_follows() -> void:
	var hub: HubScreen = _make_hub()
	assert_bool(hub.get_run_page_for_test().visible).is_true()
	assert_bool(hub.get_loadout_page_for_test().visible).is_false()
	hub.get_tab_button_for_test("loadout").pressed.emit()
	assert_bool(hub.get_run_page_for_test().visible).is_false()
	assert_bool(hub.get_loadout_page_for_test().visible).is_true()
	assert_str(hub.get_picker_hint_for_test().text).contains("Ranger")
	hub.get_tab_button_for_test("run").pressed.emit()
	assert_bool(hub.get_run_page_for_test().visible).is_true()


func test_locked_items_say_how_to_earn_them() -> void:
	var hub: HubScreen = _make_hub()
	hub.press_champion_for_test("warden")
	assert_str(hub.get_picker_hint_for_test().text).contains("Locked").contains("Tower above 50% health")
	assert_str(MetaProgress.get_selected_champion()).append_failure_message("a locked press selects nothing").is_equal("ranger")
	assert_bool(hub.get_champion_button_for_test("warden").button_pressed).is_false()
	hub.press_relic_for_test("kings_crown")
	assert_str(hub.get_picker_hint_for_test().text).contains("Bombardier King")
	hub.press_relic_for_test("warchiefs_horn")
	assert_str(hub.get_picker_hint_for_test().text).contains("Goblin Warchief")
	hub.press_relic_for_test("lucky_coin")
	assert_str(hub.get_picker_hint_for_test().text).contains("1000 Scrap")
	assert_array(MetaProgress.get_selected_relics()).is_empty()


func test_the_hint_shows_the_twist_and_the_downside_of_an_unlocked_champion() -> void:
	MetaProgress.set_achievement_unlocked_for_test("keeper_of_the_keep")
	_save()
	var hub: HubScreen = _make_hub()
	hub.press_champion_for_test("warden")
	var text: String = hub.get_picker_hint_for_test().text
	assert_str(text).contains("Warden").contains("1 HP/s").contains("+15%").contains("Downside: -10% max HP")
	assert_str(MetaProgress.get_selected_champion()).is_equal("warden")
	assert_bool(hub.get_champion_button_for_test("warden").button_pressed).is_true()
	assert_bool(hub.get_champion_button_for_test("ranger").button_pressed).is_false()


func test_relic_slots_one_before_a_win_two_after_and_the_second_says_how_to_open() -> void:
	var hub: HubScreen = _make_hub()
	assert_str(hub.get_relics_heading_for_test().text).is_equal("Relics 0/1")
	hub.press_relic_for_test("quiver_of_echoes")
	hub.press_relic_for_test("masons_trowel")
	assert_array(MetaProgress.get_selected_relics()).append_failure_message("one slot: the newer relic replaces").contains_exactly(["masons_trowel"])
	assert_str(hub.get_picker_hint_for_test().text).contains("second Relic slot opens after your first victory")
	assert_str(hub.get_relics_heading_for_test().text).is_equal("Relics 1/1")
	MetaProgress.set_difficulty_victories_for_test("soldier", 1)
	_save()
	var hub2: HubScreen = _make_hub()
	assert_str(hub2.get_relics_heading_for_test().text).is_equal("Relics 1/2")
	hub2.press_relic_for_test("quiver_of_echoes")
	assert_array(MetaProgress.get_selected_relics()).contains_exactly(["masons_trowel", "quiver_of_echoes"])
	assert_bool(hub2.get_relic_button_for_test("quiver_of_echoes").button_pressed).is_true()
	assert_str(hub2.get_picker_hint_for_test().text).not_contains("second Relic slot")


func test_start_run_writes_the_champion_and_relics_into_run_config() -> void:
	MetaProgress.set_achievement_unlocked_for_test("untouchable")
	_save()
	var hub: HubScreen = _make_hub()
	hub.press_champion_for_test("skirmisher")
	hub.press_relic_for_test("masons_trowel")
	hub.get_start_run_button_for_test().pressed.emit()
	assert_str(RunConfig.champion_id).is_equal("skirmisher")
	assert_array(RunConfig.relic_ids).contains_exactly(["masons_trowel"])
	assert_str(hub.get_last_scene_change_for_test()).is_equal("res://scenes/prototype.tscn")


func test_every_loadout_control_stays_inside_the_1920x1080_canvas() -> void:
	var hub: HubScreen = _make_hub()
	hub.show_page_for_test("loadout")
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	var controls: Array = [hub.get_start_run_button_for_test(), hub.get_setup_card_for_test(), hub.get_champion_button_for_test("pactbound"), hub.get_relic_button_for_test("ember_heart"), hub.get_relic_button_for_test("quiver_of_echoes"), hub.get_tab_button_for_test("loadout")]
	for control in controls:
		var rect: Rect2 = (control as Control).get_global_rect()
		assert_bool(canvas.encloses(rect)).append_failure_message("%s %s leaves the canvas" % [(control as Control).name, rect]).is_true()
	# The picker hint's longest case (Warden twist + downside) must not push Start Run off the canvas.
	MetaProgress.set_achievement_unlocked_for_test("keeper_of_the_keep")
	hub.press_champion_for_test("warden")
	await get_tree().process_frame
	assert_bool(canvas.encloses(hub.get_start_run_button_for_test().get_global_rect())).is_true()


func test_a_picker_button_is_at_least_the_touch_floor_tall() -> void:
	var hub: HubScreen = _make_hub()
	await get_tree().process_frame
	assert_float(hub.get_relic_button_for_test("ember_heart").custom_minimum_size.y).is_greater_equal(64.0)
	assert_float(hub.get_champion_button_for_test("ranger").custom_minimum_size.y).is_greater_equal(64.0)


# --- Pause menu ------------------------------------------------------------------------

func test_the_pause_build_panel_lists_the_champion_and_relics_with_icons() -> void:
	RunConfig.champion_id = "warden"
	RunConfig.relic_ids = ["quiver_of_echoes", "iron_banner"]
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	menu.set_active(true)
	var column: VBoxContainer = menu.get_build_column_for_test()
	var champion: Node = column.find_child("Loadout_warden", true, false)
	assert_object(champion).append_failure_message("the Champion row").is_not_null()
	assert_str((champion.get_node("Name") as Label).text).is_equal("Warden")
	assert_object((champion.get_node("Icon") as TextureRect).texture).is_not_null()
	for id in ["quiver_of_echoes", "iron_banner"]:
		var row: Node = column.find_child("Loadout_%s" % id, true, false)
		assert_object(row).append_failure_message(id).is_not_null()
		assert_object((row.get_node("Icon") as TextureRect).texture).is_not_null()
	assert_str((column.find_child("Loadout_iron_banner", true, false).get_node("Name") as Label).text).is_equal("Iron Banner")


func test_a_default_run_lists_the_ranger_and_no_relics() -> void:
	var menu: PauseMenu = auto_free(PauseMenu.new())
	add_child(menu)
	menu.set_active(true)
	var column: VBoxContainer = menu.get_build_column_for_test()
	assert_object(column.find_child("Loadout_ranger", true, false)).is_not_null()
	for id in LoadoutCatalog.RELIC_IDS:
		assert_object(column.find_child("Loadout_%s" % id, true, false)).is_null()


# --- Achievements ------------------------------------------------------------------------

func test_each_achievement_that_opens_a_champion_or_relic_says_so_in_its_reward() -> void:
	var list: AchievementList = MetaProgress.achievement_list
	var expected: Dictionary = {
		"keeper_of_the_keep": "Champion: Warden", "untouchable": "Champion: Skirmisher", "warchief_slayer": "Champion: Pactbound",
		"goblin_slayer": "Relic: Hunter's Charm", "hoarder": "Relic: Lucky Coin", "mason": "Relic: Iron Banner", "elite_hunter": "Relic: Ember Heart",
	}
	for id in expected.keys():
		var text: String = AchievementsPanel.reward_text(list.get_achievement(id))
		assert_str(text).append_failure_message("%s: %s" % [id, text]).contains(expected[id])
	assert_str(AchievementsPanel.reward_text(list.get_achievement("founder"))).append_failure_message("no loadout reward").not_contains("Champion").not_contains("Relic")
	assert_str(AchievementsPanel.reward_text(list.get_achievement("hoarder"))).append_failure_message("the old perk line stays").contains("Reward")


func test_the_catalog_and_the_achievement_table_agree() -> void:
	# Every achievement id a Champion or Relic names must exist; every item has a name, a twist and an icon.
	for id in LoadoutCatalog.CHAMPION_IDS + LoadoutCatalog.RELIC_IDS:
		var ach: String = LoadoutCatalog.unlocking_achievement(id)
		if ach != "":
			assert_object(MetaProgress.achievement_list.get_achievement(ach)).append_failure_message("%s names a missing achievement %s" % [id, ach]).is_not_null()
		assert_str(LoadoutCatalog.display_name(id)).append_failure_message(id).is_not_empty()
		assert_bool(LoadoutCatalog.display_name(id).begins_with("LOADOUT_")).append_failure_message("%s name untranslated" % id).is_false()
		assert_str(LoadoutCatalog.twist_text(id)).is_not_empty()
		assert_bool(LoadoutCatalog.twist_text(id).begins_with("LOADOUT_")).append_failure_message("%s twist untranslated" % id).is_false()
		assert_bool(ResourceLoader.exists(LoadoutCatalog.icon_path(id))).append_failure_message("icon for %s" % id).is_true()

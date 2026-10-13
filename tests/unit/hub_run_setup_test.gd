extends GdUnitTestSuite

## War Camp run setup (WP-META, D254; docs/31 section 2): the Difficulty and
## Battle Skill pickers, the Endless toggle, persistence, the RunConfig hand-off,
## the one-time "Skill Tree was rebuilt" banner and the calm Hub music.
## Every test redirects MetaProgress to a throwaway directory first.

var _dir: String


var _window_before: Vector2i = Vector2i.ZERO


func before_test() -> void:
	_window_before = get_window().size
	get_window().size = Vector2i(1920, 1080) # D370: the Hub bands are anchored to the canvas, so the 1920x1080 canvas asserted below needs a 1920x1080 window
	_dir = "user://__hub_setup_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	RunConfig.reset_for_test()


func after_test() -> void:
	get_window().size = _window_before
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")


## The Hub reloads the profile from disk, so a test's setup must be SAVED: load
## first, set the state, then settle a run (which saves; a victory also records the Soldier win).
func _save_state(skill_nodes: Array[String] = [], soldier_win: bool = false) -> void:
	MetaProgress.ensure_loaded()
	for id in skill_nodes:
		MetaProgress.set_rank_for_test(id, 1)
	MetaProgress.settle_run({"run_id": "prep_%d" % randi(), "sim_time_seconds": 0.0, "victory": soldier_win, "difficulty_id": "soldier"})


func _make_hub() -> HubScreen:
	var hub: HubScreen = auto_free(HubScreen.new())
	hub.set_suppress_scene_change_for_test(true)
	add_child(hub)
	return hub


func test_a_fresh_profile_shows_all_pickers_with_locked_options_greyed() -> void:
	var hub: HubScreen = _make_hub()
	for id in ["recruit", "soldier", "veteran", "warlord"]:
		assert_object(hub.get_difficulty_button_for_test(id)).append_failure_message("no button for %s" % id).is_not_null()
	for id in ["arrow_storm", "frost_nova", "firebomb", "war_horn"]:
		assert_object(hub.get_skill_button_for_test(id)).is_not_null()
	assert_bool(hub.get_difficulty_button_for_test("soldier").button_pressed).append_failure_message("Soldier is the default").is_true()
	assert_bool(hub.get_skill_button_for_test("arrow_storm").button_pressed).is_true()
	assert_float(hub.get_difficulty_button_for_test("veteran").modulate.a).append_failure_message("a locked option is dimmed").is_less(1.0)
	assert_float(hub.get_difficulty_button_for_test("soldier").modulate.a).is_equal(1.0)
	assert_bool(hub.get_endless_button_for_test().visible).append_failure_message("Endless is hidden until a win").is_false()


func test_locked_options_say_what_unlocks_them() -> void:
	var hub: HubScreen = _make_hub()
	hub.press_difficulty_for_test("veteran")
	assert_str(hub.get_picker_hint_for_test().text).contains("Soldier")
	assert_str(MetaProgress.get_selected_difficulty()).append_failure_message("a locked press selects nothing").is_equal("soldier")
	assert_bool(hub.get_difficulty_button_for_test("veteran").button_pressed).append_failure_message("and the refused toggle snaps back").is_false()
	hub.press_difficulty_for_test("warlord")
	assert_str(hub.get_picker_hint_for_test().text).contains("Veteran")
	hub.press_skill_for_test("war_horn")
	assert_str(hub.get_picker_hint_for_test().text).append_failure_message("names the tree node that opens it").contains("War Horn")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("arrow_storm")


func test_a_win_opens_veteran_and_endless_and_choices_persist() -> void:
	_save_state(["skill_focus", "frost_nova_unlock"], true)
	var hub: HubScreen = _make_hub()
	assert_bool(hub.get_endless_button_for_test().visible).is_true()
	hub.press_difficulty_for_test("veteran")
	hub.press_skill_for_test("frost_nova")
	hub.get_endless_button_for_test().button_pressed = true # toggled() fires
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("veteran")
	assert_str(MetaProgress.get_selected_battle_skill()).is_equal("frost_nova")
	assert_bool(MetaProgress.get_selected_endless()).is_true()
	assert_str(hub.get_endless_button_for_test().text).is_equal(tr("HUB_ENDLESS_ON"))

	# A second visit (new Hub, profile reloaded from disk) shows the same choices.
	MetaProgress.reload_for_test()
	var hub2: HubScreen = _make_hub()
	assert_bool(hub2.get_difficulty_button_for_test("veteran").button_pressed).is_true()
	assert_bool(hub2.get_skill_button_for_test("frost_nova").button_pressed).is_true()
	assert_bool(hub2.get_endless_button_for_test().button_pressed).is_true()


func test_start_run_writes_the_choices_into_run_config_before_changing_scene() -> void:
	_save_state([], true)
	var hub: HubScreen = _make_hub()
	hub.press_difficulty_for_test("recruit")
	RunConfig.difficulty_id = "warlord" # stale value from a previous run: Start Run must overwrite it
	hub.get_start_run_button_for_test().pressed.emit()
	assert_str(RunConfig.difficulty_id).is_equal("recruit")
	assert_str(RunConfig.battle_skill_id).is_equal("arrow_storm")
	assert_bool(RunConfig.endless).is_false()
	assert_str(hub.get_last_scene_change_for_test()).is_equal("res://scenes/prototype.tscn")


func test_pickers_are_ordinary_focusable_buttons_for_keyboard_pad_and_touch() -> void:
	var hub: HubScreen = _make_hub()
	var buttons: Array[Button] = [hub.get_start_run_button_for_test()]
	for id in ["recruit", "soldier", "veteran", "warlord"]:
		buttons.append(hub.get_difficulty_button_for_test(id))
	for id in ["arrow_storm", "frost_nova", "firebomb", "war_horn"]:
		buttons.append(hub.get_skill_button_for_test(id))
	for b in buttons:
		assert_int(b.focus_mode).append_failure_message("%s must be focusable" % b.name).is_equal(Control.FOCUS_ALL)
		assert_float(b.custom_minimum_size.y).append_failure_message("%s is too short to tap" % b.name).is_greater_equal(56.0)


func test_the_rebuilt_tree_banner_shows_once_after_migration_and_its_dismissal_is_saved() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var f: FileAccess = FileAccess.open(_dir.path_join("profile.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version": 2, "cores": 0, "tree_ranks": {"vitality": 2}, "records": {}, "settled_run_ids": [], "flags": {}, "first_hub_seen": true}))
	f.close()
	var hub: HubScreen = _make_hub() # the Hub loads the profile, migrating it
	assert_bool(hub.get_v3_banner_for_test().visible).is_true()
	var label: Label = hub.get_v3_banner_for_test().get_node("Row/Label") as Label
	assert_str(label.text).contains("The Skill Tree was rebuilt. Your Cores were refunded.")
	assert_str(label.text).append_failure_message("the refund amount is shown").contains("13")
	(hub.get_v3_banner_for_test().get_node("Row/DismissButton") as Button).pressed.emit()
	assert_bool(hub.get_v3_banner_for_test().visible).is_false()
	MetaProgress.reload_for_test()
	var hub2: HubScreen = _make_hub()
	assert_bool(hub2.get_v3_banner_for_test().visible).append_failure_message("never again once dismissed").is_false()


func test_no_rebuilt_tree_banner_on_a_fresh_profile() -> void:
	assert_bool(_make_hub().get_v3_banner_for_test().visible).is_false()


func test_the_hub_plays_the_calm_town_theme_on_the_music_bus_looping() -> void:
	var player: AudioStreamPlayer = _make_hub().get_music_player_for_test()
	assert_str(player.stream.resource_path).ends_with("town_theme_rpg.ogg")
	assert_str(String(player.bus)).is_equal("Music")
	assert_bool((player.stream as AudioStreamOggVorbis).loop).is_true()
	assert_bool(player.playing).is_true()


func test_every_hub_control_stays_inside_the_1920x1080_canvas() -> void:
	var hub: HubScreen = _make_hub()
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	for control in [hub.get_start_run_button_for_test(), hub.get_setup_card_for_test(), hub.get_menu_card_for_test(), hub.get_skill_button_for_test("war_horn"), hub.get_difficulty_button_for_test("warlord")]:
		var rect: Rect2 = (control as Control).get_global_rect()
		assert_bool(canvas.encloses(rect)).append_failure_message("%s %s leaves the %s canvas" % [(control as Control).name, rect, canvas]).is_true()

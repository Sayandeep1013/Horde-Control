extends GdUnitTestSuite

## The shared selection-state language (PT-UI, docs/33 A1; D320): Available, Focused,
## Selected and Locked are four distinct looks, readable without colour (a shape and a word
## each); a selection survives focus moving away; a locked press shows its reason.
## Every test redirects MetaProgress to a throwaway directory first (the Hub tests).

var _dir: String


func before_test() -> void:
	_dir = "user://__selectable_state_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	RunConfig.reset_for_test()


func after_test() -> void:
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")


func _plate() -> Button:
	var button: Button = auto_free(Button.new())
	button.custom_minimum_size = Vector2(440.0, 72.0)
	add_child(button)
	return button


func _cue_names(cues: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in cues:
		if bool(cues[key]):
			out.append(key)
	out.sort()
	return out


func test_the_four_states_have_four_different_cue_sets() -> void:
	var sets: Dictionary = {}
	for state in [SelectableState.State.AVAILABLE, SelectableState.State.FOCUSED, SelectableState.State.SELECTED, SelectableState.State.LOCKED]:
		sets[state] = _cue_names(SelectableState.cues_for(state))
	assert_array(sets[SelectableState.State.AVAILABLE]).append_failure_message("Available draws nothing").is_empty()
	var seen: Array = []
	for state in sets:
		assert_bool(seen.has(sets[state])).append_failure_message("two states share one cue set: %s" % str(sets[state])).is_false()
		seen.append(sets[state])
	# Each non-trivial state carries a shape AND a word, so none depends on colour.
	assert_array(sets[SelectableState.State.FOCUSED]).contains(["outline", "arrow", "scale"])
	assert_array(sets[SelectableState.State.SELECTED]).contains(["check", "ribbon_word", "tint"])
	assert_array(sets[SelectableState.State.LOCKED]).contains(["padlock", "reason_line", "veil"])


func test_a_live_plate_shows_exactly_its_state_cues() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	assert_int(overlay.get_state()).is_equal(SelectableState.State.AVAILABLE)
	overlay.set_focused(true)
	assert_int(overlay.get_state()).is_equal(SelectableState.State.FOCUSED)
	var cues: Dictionary = overlay.visible_cues()
	assert_bool(cues["outline"]).is_true()
	assert_bool(cues["arrow"]).is_true()
	assert_bool(cues["check"]).is_false()
	assert_bool(cues["padlock"]).is_false()
	assert_float(overlay.get_target_scale()).append_failure_message("a focused plate lifts 1.05x").is_equal_approx(SelectableState.FOCUS_SCALE, 0.001)
	overlay.set_focused(false)
	assert_float(overlay.get_target_scale()).is_equal_approx(1.0, 0.001)


func test_a_selection_stays_when_focus_moves_away() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true, "EQUIPPED")
	overlay.set_focused(true)
	overlay.set_focused(false)
	assert_bool(overlay.is_selected()).is_true()
	assert_int(overlay.get_state()).is_equal(SelectableState.State.SELECTED)
	var cues: Dictionary = overlay.visible_cues()
	assert_bool(cues["check"]).append_failure_message("the check badge stays with focus gone").is_true()
	assert_bool(cues["ribbon_word"]).is_true()
	assert_bool(cues["outline"]).append_failure_message("focus and selection never look alike: no outline once focus has left").is_false()
	assert_str(overlay.get_ribbon_label().text).is_equal("EQUIPPED")


func test_a_focused_selected_plate_shows_both_groups() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true)
	overlay.set_focused(true)
	var cues: Dictionary = overlay.visible_cues()
	assert_bool(cues["outline"] and cues["check"]).append_failure_message("the plate you are on AND already hold shows the outline and the check").is_true()


func test_a_locked_press_shows_its_reason_and_is_never_silent() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	var heard: Array[String] = []
	overlay.locked_pressed.connect(func(reason: String) -> void: heard.append(reason))
	assert_str(overlay.press_locked()).append_failure_message("an unlocked plate has no reason to show").is_equal("")
	overlay.set_locked(true, "Win on Soldier")
	assert_bool(overlay.visible_cues()["padlock"]).is_true()
	assert_bool(overlay.visible_cues()["reason_line"]).is_true()
	assert_str(overlay.press_locked()).is_equal("Win on Soldier")
	assert_str(overlay.get_last_reason_shown()).is_equal("Win on Soldier")
	assert_array(heard).is_equal(["Win on Soldier"])


func test_locked_wins_over_selected() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true)
	overlay.set_locked(true, "Need 45 Cores")
	assert_int(overlay.get_state()).is_equal(SelectableState.State.LOCKED)
	assert_bool(overlay.visible_cues()["check"]).is_false()


func test_confirming_ring_and_chosen_stamp() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_confirm_progress(0.5)
	assert_bool(overlay.visible_cues()["ring"]).is_true()
	overlay.set_confirm_progress(0.0)
	assert_bool(overlay.visible_cues()["ring"]).is_false()
	overlay.flash_chosen()
	assert_bool(overlay.is_chosen_visible()).is_true()
	assert_float(SelectableState.CHOSEN_SECONDS).append_failure_message("Register: the CHOSEN stamp flashes 0.35 s").is_equal(0.35)


# --- the War Camp pickers use it -------------------------------------------------------------------

func _make_hub() -> HubScreen:
	var hub: HubScreen = auto_free(HubScreen.new())
	hub.set_suppress_scene_change_for_test(true)
	add_child(hub)
	return hub


func test_the_war_camp_shows_selected_locked_and_focused_at_once() -> void:
	var hub: HubScreen = _make_hub()
	var soldier: SelectableState = SelectableState.of(hub.get_difficulty_button_for_test("soldier"))
	var veteran: SelectableState = SelectableState.of(hub.get_difficulty_button_for_test("veteran"))
	var recruit_button: Button = hub.get_difficulty_button_for_test("recruit")
	assert_object(soldier).is_not_null()
	assert_int(soldier.get_state()).append_failure_message("Soldier is the chosen difficulty").is_equal(SelectableState.State.SELECTED)
	assert_int(veteran.get_state()).is_equal(SelectableState.State.LOCKED)
	assert_str(veteran.get_reason()).append_failure_message("the reason names the win that opens it").is_equal("Win on Soldier")
	recruit_button.grab_focus()
	var recruit: SelectableState = SelectableState.of(recruit_button)
	assert_int(recruit.get_state()).is_equal(SelectableState.State.FOCUSED)
	# The focused plate is not the selected one: they never look alike.
	assert_bool(recruit.visible_cues()["check"]).is_false()
	assert_bool(soldier.visible_cues()["outline"]).is_false()


func test_pressing_a_locked_war_camp_option_shows_why_and_changes_nothing() -> void:
	var hub: HubScreen = _make_hub()
	hub.press_difficulty_for_test("veteran")
	var overlay: SelectableState = SelectableState.of(hub.get_difficulty_button_for_test("veteran"))
	assert_str(overlay.get_last_reason_shown()).is_equal("Win on Soldier")
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("soldier")


func test_a_relic_reads_equipped_not_selected() -> void:
	MetaProgress.ensure_loaded()
	var hub: HubScreen = _make_hub()
	hub.show_page_for_test("loadout")
	hub.press_relic_for_test("quiver_of_echoes")
	var overlay: SelectableState = SelectableState.of(hub.get_relic_button_for_test("quiver_of_echoes"))
	assert_int(overlay.get_state()).is_equal(SelectableState.State.SELECTED)
	assert_str(overlay.get_ribbon_label().text).is_equal("EQUIPPED")

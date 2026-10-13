extends GdUnitTestSuite

## The shared selection-state language (D320, redone by D380-D389): Available, Focused,
## Selected, Locked (and a tab's raised state) are distinct looks that sit INSIDE the plate (a tick,
## a padlock, the yellow pointer arrow), readable without colour. Selected is the tick alone (no
## word, no border); a focused plate shows the arrow on every device and a brighten after keyboard
## or gamepad input; a selection survives focus moving away; a locked press shows its reason.
## Every test redirects MetaProgress to a throwaway directory first (the Hub tests).

var _dir: String


func before_test() -> void:
	_dir = "user://__selectable_state_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	RunConfig.reset_for_test()
	UiInputMode.reset_for_test()
	UiInputMode.set_mode(UiInputMode.Mode.KEYBOARD)


func after_test() -> void:
	RunConfig.reset_for_test()
	MetaProgress.set_base_path_for_test("user://")
	UiInputMode.reset_for_test()


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


func test_the_states_have_different_cue_sets() -> void:
	var sets: Dictionary = {}
	for state in [SelectableState.State.AVAILABLE, SelectableState.State.FOCUSED, SelectableState.State.SELECTED, SelectableState.State.LOCKED]:
		sets[state] = _cue_names(SelectableState.cues_for(state))
	assert_array(sets[SelectableState.State.AVAILABLE]).append_failure_message("Available draws nothing").is_empty()
	var seen: Array = []
	for state in sets:
		assert_bool(seen.has(sets[state])).append_failure_message("two states share one cue set: %s" % str(sets[state])).is_false()
		seen.append(sets[state])
	assert_array(sets[SelectableState.State.FOCUSED]).is_equal(["arrow"])
	assert_array(sets[SelectableState.State.SELECTED]).is_equal(["check"]) # the tick alone
	assert_array(sets[SelectableState.State.LOCKED]).contains(["padlock", "reason_line"])
	# No word, border, tint, veil or ring any more (D380, D381, and the author's "just show the tick").
	for state in sets:
		for old: String in ["ribbon_word", "caption", "gold_border", "tint", "veil", "outline", "focus_ring", "scale"]:
			assert_array(sets[state]).append_failure_message("old cue '%s' is gone" % old).not_contains([old])


func test_a_tab_is_raised_not_ticked() -> void:
	var cues: Dictionary = SelectableState.cues_for(SelectableState.State.SELECTED, SelectableState.Layout.TAB)
	assert_bool(cues["tab_raise"]).is_true()
	assert_bool(cues["check"]).append_failure_message("a tab is the current page, not a selection: no tick").is_false()


func test_a_focused_plate_shows_the_arrow_and_never_scales() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	assert_int(overlay.get_state()).is_equal(SelectableState.State.AVAILABLE)
	overlay.set_focused(true)
	assert_int(overlay.get_state()).is_equal(SelectableState.State.FOCUSED)
	assert_bool(overlay.visible_cues()["arrow"]).is_true()
	assert_float(overlay.get_target_scale()).append_failure_message("focus never scales the plate").is_equal_approx(1.0, 0.001)
	assert_bool(overlay.visible_cues()["focus_wash"]).append_failure_message("keyboard: a subtle brighten too").is_true()
	UiInputMode.set_mode(UiInputMode.Mode.MOUSE)
	assert_bool(overlay.visible_cues()["focus_wash"]).append_failure_message("after the mouse moved the brighten is the hover's job").is_false()
	assert_bool(overlay.visible_cues()["arrow"]).append_failure_message("the arrow follows the focus (the mouse moves the focus to the hovered plate)").is_true()
	overlay.set_focused(false)
	assert_bool(overlay.visible_cues()["arrow"]).is_false()


func test_the_arrow_goes_inside_when_neither_side_has_room() -> void:
	var plate: Button = _plate()
	plate.position = Vector2.ZERO # flush with the top-left of the viewport: no room on the left
	plate.size = Vector2(440.0, 72.0)
	var overlay: SelectableState = SelectableState.attach(plate)
	var wide := Button.new()
	wide.custom_minimum_size = Vector2(300.0, 72.0)
	auto_free(wide)
	add_child(wide)
	wide.position = Vector2(plate.size.x + 1.0, 0.0) # a neighbour right beside it: no room on the right
	wide.size = Vector2(300.0, 72.0)
	assert_int(SelectableState.pick_arrow_side(overlay, Rect2(Vector2.ZERO, plate.size), [wide])).is_equal(SelectableState.ArrowSide.INSIDE)
	# With open space on the left the arrow sits outside it, pointing at the plate.
	plate.position = Vector2(200.0, 200.0)
	wide.position = Vector2(900.0, 200.0)
	assert_int(SelectableState.pick_arrow_side(overlay, Rect2(Vector2.ZERO, plate.size), [wide])).is_equal(SelectableState.ArrowSide.LEFT)


func test_the_theme_focus_box_follows_the_input_device() -> void:
	UiTheme.get_theme()
	UiInputMode.set_mode(UiInputMode.Mode.MOUSE)
	var box: StyleBoxFlat = UiTheme.get_theme().get_stylebox("focus", "Button") as StyleBoxFlat
	assert_float(box.bg_color.a).append_failure_message("a clicked button keeps no focus wash").is_equal(0.0)
	assert_int(box.border_width_left).append_failure_message("no yellow rectangle outline on a focused button").is_equal(0)
	UiInputMode.set_mode(UiInputMode.Mode.KEYBOARD)
	assert_float(box.bg_color.a).is_greater(0.0)


func test_a_selection_stays_when_focus_moves_away() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate, SelectableState.Layout.TILE)
	overlay.set_selected(true)
	overlay.set_focused(true)
	overlay.set_focused(false)
	assert_bool(overlay.is_selected()).is_true()
	assert_int(overlay.get_state()).is_equal(SelectableState.State.SELECTED)
	var cues: Dictionary = overlay.visible_cues()
	assert_bool(cues["check"]).append_failure_message("the tick stays with focus gone").is_true()
	assert_bool(cues["arrow"]).append_failure_message("focus and selection never look alike: no arrow once focus has left").is_false()


func test_selected_is_the_tick_alone_and_it_sits_inside_the_plate() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true)
	var cues: Dictionary = overlay.visible_cues()
	assert_array(_cue_names(cues)).append_failure_message("selected shows nothing but the tick").is_equal(["check"])
	var badge: Rect2 = overlay._badge_rect(Rect2(Vector2.ZERO, Vector2(440.0, 72.0)))
	assert_bool(Rect2(Vector2.ZERO, Vector2(440.0, 72.0)).encloses(badge)).append_failure_message("the tick sits INSIDE the plate: %s" % str(badge)).is_true()


func test_a_focused_selected_plate_shows_both_groups() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true)
	overlay.set_focused(true)
	var cues: Dictionary = overlay.visible_cues()
	assert_bool(cues["arrow"] and cues["check"]).append_failure_message("the plate you are on AND already hold shows the arrow and the tick").is_true()


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
	var badge: Rect2 = overlay._badge_rect(Rect2(Vector2.ZERO, Vector2(440.0, 72.0)))
	assert_bool(Rect2(Vector2.ZERO, Vector2(440.0, 72.0)).encloses(badge)).append_failure_message("the padlock sits INSIDE the plate").is_true()


func test_locked_wins_over_selected() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_selected(true)
	overlay.set_locked(true, "Need 45 Cores")
	assert_int(overlay.get_state()).is_equal(SelectableState.State.LOCKED)
	assert_bool(overlay.visible_cues()["check"]).is_false()


func test_press_feedback_dips_the_plate_and_releases_it() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.set_pressed(true)
	assert_bool(overlay.visible_cues()["pressed"]).is_true()
	assert_float(overlay.get_target_scale()).is_equal_approx(SelectableState.PRESS_SCALE, 0.001)
	overlay.set_pressed(false)
	assert_float(overlay.get_target_scale()).is_equal_approx(1.0, 0.001)


func test_hover_shows_only_for_a_real_mouse() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay._hover = true
	UiInputMode.set_mode(UiInputMode.Mode.KEYBOARD)
	assert_bool(overlay.visible_cues()["hover"]).is_false()
	UiInputMode.set_mode(UiInputMode.Mode.TOUCH)
	assert_bool(overlay.visible_cues()["hover"]).append_failure_message("a finger has no hover: no stuck highlight after a tap").is_false()
	UiInputMode.set_mode(UiInputMode.Mode.MOUSE)
	assert_bool(overlay.visible_cues()["hover"]).is_true()


func test_an_armed_card_shows_its_prompt_for_the_live_device() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.externally_driven = true
	overlay.set_armed(true)
	UiInputMode.set_mode(UiInputMode.Mode.KEYBOARD)
	assert_bool(overlay.visible_cues()["prompt"]).is_true()
	assert_bool(overlay.visible_cues()["arrow"]).is_true()
	assert_str(overlay.prompt_text()).is_equal("PRESS SPACE")
	UiInputMode.set_mode(UiInputMode.Mode.MOUSE)
	assert_str(overlay.prompt_text()).is_equal("CLICK TO CHOOSE")
	UiInputMode.set_mode(UiInputMode.Mode.TOUCH)
	assert_bool(overlay.visible_cues()["armed"]).append_failure_message("a finger has not touched a card yet: nothing looks pre-chosen").is_false()
	overlay.set_pressed(true)
	assert_bool(overlay.visible_cues()["armed"]).append_failure_message("while a finger is held on it, the card shows armed").is_true()
	assert_bool(overlay.visible_cues()["prompt"]).append_failure_message("no keyboard prompt on touch").is_false()


func test_the_other_cards_are_dimmed_while_one_is_armed() -> void:
	var plate: Button = _plate()
	var overlay: SelectableState = SelectableState.attach(plate)
	overlay.externally_driven = true
	overlay.set_dimmed(true)
	assert_bool(overlay.visible_cues()["dim"]).is_true()
	overlay.set_armed(true)
	assert_bool(overlay.visible_cues()["dim"]).append_failure_message("the armed card itself is never dimmed").is_false()


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


func test_input_device_classification() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	assert_int(UiInputMode.classify(key)).is_equal(UiInputMode.Mode.KEYBOARD)
	key.pressed = false
	assert_int(UiInputMode.classify(key)).append_failure_message("a key release says nothing").is_equal(-1)
	var motion := InputEventMouseMotion.new()
	assert_int(UiInputMode.classify(motion)).is_equal(UiInputMode.Mode.MOUSE)
	motion.device = InputEvent.DEVICE_ID_EMULATION
	assert_int(UiInputMode.classify(motion)).append_failure_message("the mouse a tap emulates is still touch").is_equal(-1)
	assert_int(UiInputMode.classify(InputEventScreenTouch.new())).is_equal(UiInputMode.Mode.TOUCH)
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = 0.1
	assert_int(UiInputMode.classify(stick)).append_failure_message("a stick at rest says nothing").is_equal(-1)
	stick.axis_value = 0.9
	assert_int(UiInputMode.classify(stick)).is_equal(UiInputMode.Mode.KEYBOARD)


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
	UiInputMode.set_mode(UiInputMode.Mode.KEYBOARD)
	recruit_button.grab_focus()
	var recruit: SelectableState = SelectableState.of(recruit_button)
	assert_int(recruit.get_state()).is_equal(SelectableState.State.FOCUSED)
	# The focused plate is not the selected one: they never look alike.
	assert_bool(recruit.visible_cues()["check"]).is_false()
	assert_bool(soldier.visible_cues()["arrow"]).is_false()


func test_a_tab_is_the_current_page_and_the_other_is_dimmed() -> void:
	var hub: HubScreen = _make_hub()
	var run_tab: SelectableState = SelectableState.of(hub.get_tab_button_for_test("run"))
	var loadout_tab: SelectableState = SelectableState.of(hub.get_tab_button_for_test("loadout"))
	assert_bool(run_tab.visible_cues()["tab_raise"]).is_true()
	assert_bool(run_tab.visible_cues()["check"]).is_false()
	assert_bool(loadout_tab.visible_cues()["tab_dim"]).is_true()
	hub.show_page_for_test("loadout")
	assert_bool(loadout_tab.visible_cues()["tab_raise"]).is_true()
	assert_bool(run_tab.visible_cues()["tab_dim"]).is_true()


func test_pressing_a_locked_war_camp_option_shows_why_and_changes_nothing() -> void:
	var hub: HubScreen = _make_hub()
	hub.press_difficulty_for_test("veteran")
	var overlay: SelectableState = SelectableState.of(hub.get_difficulty_button_for_test("veteran"))
	assert_str(overlay.get_last_reason_shown()).is_equal("Win on Soldier")
	assert_str(MetaProgress.get_selected_difficulty()).is_equal("soldier")


func test_a_relic_shows_the_tick_when_equipped() -> void:
	MetaProgress.ensure_loaded()
	var hub: HubScreen = _make_hub()
	hub.show_page_for_test("loadout")
	hub.press_relic_for_test("quiver_of_echoes")
	var overlay: SelectableState = SelectableState.of(hub.get_relic_button_for_test("quiver_of_echoes"))
	assert_int(overlay.get_state()).is_equal(SelectableState.State.SELECTED)
	assert_bool(overlay.visible_cues()["check"]).is_true()

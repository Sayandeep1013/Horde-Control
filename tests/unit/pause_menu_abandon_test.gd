extends GdUnitTestSuite

## UX review item 7 (D134): the pause menu's abandon option asks first, and a
## click confirms only the clicked option.

var _menu: PauseMenu
var _requested: int = 0


func before_test() -> void:
	_requested = 0
	_menu = auto_free(PauseMenu.new())
	add_child(_menu)
	_menu.main_menu_requested.connect(func() -> void: _requested += 1)
	_menu.set_active(true)


func test_main_menu_option_is_labelled_as_abandoning() -> void:
	assert_str(_menu.get_bar_for_test().get_option_label_for_test(PauseMenu.OPTION_MAIN_MENU).text).is_equal("Abandon run")


func test_choosing_it_asks_for_confirmation_instead_of_abandoning() -> void:
	_menu._on_option_confirmed(PauseMenu.OPTION_MAIN_MENU)
	assert_bool(_menu.is_confirming_abandon_for_test()).is_true()
	assert_int(_requested).is_equal(0)


func test_confirming_abandon_emits_main_menu_requested() -> void:
	_menu._on_option_confirmed(PauseMenu.OPTION_MAIN_MENU)
	_menu._on_option_confirmed(PauseMenu.ABANDON_OPTION_CONFIRM)
	assert_int(_requested).is_equal(1)


func test_cancel_returns_to_the_main_choices() -> void:
	_menu._on_option_confirmed(PauseMenu.OPTION_MAIN_MENU)
	_menu._on_option_confirmed(PauseMenu.ABANDON_OPTION_CANCEL)
	assert_bool(_menu.is_confirming_abandon_for_test()).is_false()
	assert_int(_requested).is_equal(0)


func test_closing_the_menu_resets_the_confirmation() -> void:
	_menu._on_option_confirmed(PauseMenu.OPTION_MAIN_MENU)
	_menu.set_active(false)
	assert_bool(_menu.is_confirming_abandon_for_test()).is_false()


func test_a_mouse_press_does_not_confirm_the_highlighted_option_via_the_global_action() -> void:
	var bar: PausedChoiceBar = _menu.get_bar_for_test()
	bar.set_test_input_mode_for_test(true)
	bar.skip_lockout_for_test()
	var confirmed: Array[int] = []
	bar.option_confirmed.connect(func(i: int) -> void: confirmed.append(i))
	bar.simulate_mouse_confirm_for_test()
	bar.press_action_once_for_test(&"confirm")
	bar.tick_for_test(0.016)
	assert_array(confirmed).is_empty()

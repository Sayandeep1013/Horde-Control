extends GdUnitTestSuite

## UX review P0-4 (D128): the Draft explains itself and clicks only confirm
## the clicked card.

const STEP: float = 1.0 / 60.0 # matches SimClock.PHYSICS_STEP; frame delta, not sim time (see draft_controller.gd's own header)

var _controller: DraftController
var _run_inventory: RunInventory
var _upgrade_system: UpgradeSystem
var _pause: Node
var _clock: Node


func before_test() -> void:
	_run_inventory = DraftTestHelpers.build_run_inventory()
	_upgrade_system = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(_upgrade_system)
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)

	_controller = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(_controller)
	_controller.set_run_inventory_for_test(_run_inventory)
	_controller.set_upgrade_system_for_test(_upgrade_system)
	_controller.set_pause_authority_for_test(_pause)
	_controller.set_sim_clock_for_test(_clock)
	_controller.set_test_input_mode_for_test(true)
	_controller.force_open_for_test(false)


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func _tick_seconds(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var d: float = minf(STEP, remaining)
		_controller.tick_for_test(d)
		remaining -= d



func test_a_click_on_empty_space_does_not_confirm_the_highlighted_card() -> void:
	_tick_seconds(0.5)
	_controller.simulate_mouse_confirm_for_test()
	_controller.press_action_once_for_test(&"confirm")
	_tick_seconds(STEP)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("a mouse press outside any card confirmed the highlighted card").is_true()


func test_keyboard_confirm_still_works() -> void:
	_tick_seconds(0.5)
	_controller.press_action_once_for_test(&"confirm")
	_tick_seconds(STEP)
	assert_bool(_controller.is_draft_showing_for_test()).is_false()


func test_clicking_a_card_confirms_that_card() -> void:
	_tick_seconds(0.5)
	_controller.simulate_card_click_for_test(2)
	assert_bool(_controller.is_draft_showing_for_test()).is_false()


func test_a_card_click_during_the_lockout_is_ignored() -> void:
	_tick_seconds(0.1)
	_controller.simulate_card_click_for_test(1)
	assert_bool(_controller.is_draft_showing_for_test()).is_true()


func test_footer_lists_every_way_to_pick_and_cards_carry_key_badges() -> void:
	var footer: String = _controller.get_how_to_pick_label_for_test().text
	for token in ["Click", "1 / 2 / 3", "A / D", "Space", "hold W"]:
		assert_str(footer).contains(token)
	for i in 3:
		var badge: Control = _controller.get_card_view_for_test(i).get_key_badge_for_test()
		assert_object(badge).is_not_null()


func test_reroll_text_shows_the_count_and_greys_out_at_zero() -> void:
	assert_str(_controller.get_reroll_label_for_test().text).is_equal("Reroll: R (1 left)")
	_tick_seconds(0.5)
	_controller.press_action_once_for_test(&"reroll")
	_tick_seconds(STEP)
	var label: Label = _controller.get_reroll_label_for_test()
	assert_str(label.text).is_equal("No rerolls left")
	assert_float(label.modulate.a).is_less(1.0)

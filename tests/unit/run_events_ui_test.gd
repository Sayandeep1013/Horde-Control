extends GdUnitTestSuite
## Run events: the EventDraftController (docs/32 §A; docs/19 Draft input contract).
## Drives it through its test-input double with frame-exact deltas: the 0.4 s
## lockout, neutral-return arming, left/right cycle with a 0.3 s repeat, hold-up
## 1.0 s, keys 1/2/3, a click or tap on a card; queueing behind a Level-Up Draft;
## the pause reason; and a mode title, accent and cost lines for every event.

const STEP: float = 1.0 / 60.0

var _w: Dictionary
var _events: RunEvents
var _us: UpgradeSystem
var _ui: EventDraftController
var _draft: DraftController
var _pause: Node
var _clock: Node
var _fake_director: DraftFakeWaveDirector
var _resolved: Array[Dictionary] = []


func before_test() -> void:
	_w = RunEventsTestHelpers.build_world(self)
	_events = _w["events"]
	_us = _w["us"]
	_resolved.clear()
	_events.event_resolved.connect(func(kind: String, choice: Dictionary) -> void: _resolved.append({"kind": kind, "choice": choice}))
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)
	_fake_director = auto_free(DraftFakeWaveDirector.new()) as DraftFakeWaveDirector
	add_child(_fake_director)
	_draft = auto_free(DraftTestHelpers.build_draft_controller()) as DraftController
	add_child(_draft)
	_draft.set_run_inventory_for_test(DraftTestHelpers.build_run_inventory())
	_draft.set_upgrade_system_for_test(_us)
	_draft.set_pause_authority_for_test(_pause)
	_draft.set_sim_clock_for_test(_clock)
	_draft.set_test_input_mode_for_test(true)
	_ui = auto_free(EventDraftController.new()) as EventDraftController
	add_child(_ui)
	_ui.setup(_events, _draft, _us, _fake_director)
	_ui.set_pause_authority_for_test(_pause)
	_ui.set_sim_clock_for_test(_clock)
	_ui.set_test_input_mode_for_test(true)


func after_test() -> void:
	RunEventsTestHelpers.cleanup()
	get_tree().paused = false


func _tick(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var d: float = minf(STEP, remaining)
		_ui.tick_for_test(d)
		remaining -= d


func _open(kind: String, flawless: bool = false) -> void:
	_events.queue_dev_event(kind, flawless)
	assert_bool(_ui.poll_open()).append_failure_message("the %s event did not open" % kind).is_true()


func _last_choice_id() -> String:
	var c: Dictionary = _resolved[_resolved.size() - 1]["choice"]
	return String(c.get("id", c.get("option", "")))


# --- Look: every event reads as itself ---------------------------------------------------------

func test_each_event_has_its_own_title_accent_and_subtitle() -> void:
	var titles: Array[String] = []
	var dims: Array[Color] = []
	var subs: Array[String] = []
	for kind in ["opening_pick", "patrons_boon", "sanctuary", "blood_pact"]:
		_open(kind)
		titles.append(_ui.get_title_text_for_test())
		subs.append(_ui.get_subtitle_text_for_test())
		dims.append(_ui._dim.color)
		_ui.skip_lockout_for_test()
		_ui.confirm_choice_for_test(2 if kind == "blood_pact" else 0)
	assert_array(titles).is_equal(["Opening Pick", "Patron's Boon", "Sanctuary", "Blood Pact"])
	for i in subs.size():
		for j in range(i + 1, subs.size()):
			assert_str(subs[i]).append_failure_message("two events share a subtitle").is_not_equal(subs[j])
			assert_bool(dims[i] == dims[j]).append_failure_message("two events share a dim tint").is_false()


func test_the_pact_cards_show_both_costs_in_numbers_and_a_refuse() -> void:
	_open("blood_pact")
	var views: Array[DraftCardView] = _ui.get_card_views_for_test()
	assert_int(views.size()).is_equal(3)
	assert_str(views[0].get_rank_label().text).is_equal("-%d max HP" % int(round(100.0 * 0.2)))
	assert_str(views[1].get_rank_label().text).is_equal("-%d Tower max HP" % int(round(500.0 * 0.2)))
	assert_str(views[2].get_name_label().text).is_equal("Refuse")
	assert_str(views[2].get_rank_label().text).is_equal("No cost")
	assert_str(views[0].get_name_label().text).is_equal("Pay with your blood")
	assert_str(views[1].get_name_label().text).is_equal("Pay with the Tower")
	assert_bool(views[0].get_effect_label().text.contains(":")).append_failure_message("the pact itself is named on the card").is_true()


func test_flawless_and_pactbound_show_halved_numbers_and_a_badge() -> void:
	_events.set_rules_for_test(false, true, false)
	_open("blood_pact", true)
	var views: Array[DraftCardView] = _ui.get_card_views_for_test()
	assert_str(views[0].get_rank_label().text).is_equal("-5 max HP")
	assert_str(views[1].get_rank_label().text).is_equal("-25 Tower max HP")
	assert_str(_ui._badge_label.text).contains("FLAWLESS")
	assert_str(_ui._badge_label.text).contains("PACTBOUND")


func test_sanctuary_cards_are_mend_restore_valor_with_numbers_from_the_register() -> void:
	_open("sanctuary")
	var views: Array[DraftCardView] = _ui.get_card_views_for_test()
	assert_str(views[0].get_name_label().text).is_equal("Mend")
	assert_str(views[0].get_effect_label().text).contains("50%")
	assert_str(views[1].get_name_label().text).is_equal("Restore")
	assert_str(views[1].get_effect_label().text).contains("30%")
	assert_str(views[2].get_name_label().text).is_equal("Valor")
	assert_str(views[2].get_effect_label().text).contains("10%")


func test_the_armory_opening_pick_shows_four_cards() -> void:
	_events.armory_enabled = true
	_open("opening_pick")
	assert_int(_ui.get_card_views_for_test().size()).is_equal(4)
	assert_str(_ui.get_subtitle_text_for_test()).contains("Armory")


# --- Pause and queueing ------------------------------------------------------------------------------

func test_opening_pauses_through_pause_authority_and_closing_resumes() -> void:
	_open("sanctuary")
	assert_bool(_pause.has_reason(&"draft")).is_true()
	assert_bool(get_tree().paused).is_true()
	_ui.skip_lockout_for_test()
	_ui.confirm_choice_for_test(0)
	assert_bool(_ui.is_showing()).is_false()
	assert_bool(_pause.has_reason(&"draft")).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(_fake_director.get_notify_draft_closed_calls_for_test().size()).append_failure_message("the 1.5 s post-Draft grace applies").is_equal(1)


func test_a_second_queued_event_opens_without_unpausing() -> void:
	_events.queue_dev_event("patrons_boon")
	_events.queue_dev_event("sanctuary")
	assert_bool(_ui.poll_open()).is_true()
	assert_str(_ui.get_kind()).is_equal("patrons_boon")
	_ui.skip_lockout_for_test()
	_ui.confirm_choice_for_test(0)
	assert_bool(_ui.is_showing()).is_true()
	assert_str(_ui.get_kind()).is_equal("sanctuary")
	assert_bool(_pause.has_reason(&"draft")).append_failure_message("the pause must hold between two events").is_true()
	_ui.skip_lockout_for_test()
	_ui.confirm_choice_for_test(0)
	assert_bool(_pause.has_reason(&"draft")).is_false()


func test_an_event_queues_behind_a_level_up_draft_and_never_opens_on_top() -> void:
	_draft.force_open_for_test(false)
	assert_bool(_draft.is_busy()).is_true()
	_events.queue_dev_event("sanctuary")
	assert_bool(_ui.poll_open()).append_failure_message("an event opened on top of a Draft").is_false()
	_ui.tick_for_test(STEP)
	assert_bool(_ui.is_showing()).is_false()
	_draft.skip_lockout_for_test()
	_draft.confirm_choice_for_test(0)
	assert_bool(_draft.is_busy()).is_false()
	assert_bool(_ui.poll_open()).append_failure_message("the event must open once the Draft is done").is_true()


func test_an_event_waits_for_every_queued_draft_not_just_the_one_on_screen() -> void:
	_draft.force_open_for_test(false)
	_draft.queue_forced_draft_for_meta() # a second Draft queued behind the open one
	_events.queue_dev_event("sanctuary")
	_draft.skip_lockout_for_test()
	_draft.confirm_choice_for_test(0) # the second Draft opens at once
	assert_bool(_draft.is_busy()).is_true()
	assert_bool(_ui.poll_open()).is_false()
	_draft.skip_lockout_for_test()
	_draft.confirm_choice_for_test(0)
	assert_bool(_ui.poll_open()).is_true()


func test_an_event_does_not_open_over_the_pause_menu_or_results() -> void:
	_pause.push_reason_immediate(&"pause_menu")
	_events.queue_dev_event("sanctuary")
	assert_bool(_ui.poll_open()).is_false()
	_pause.pop_reason_immediate(&"pause_menu")
	assert_bool(_ui.poll_open()).is_true()


func test_a_draft_cannot_be_opened_by_the_run_while_an_event_holds_the_pause() -> void:
	# The simulation (and so the Draft's step-11 level-up check) does not tick while paused.
	_open("sanctuary")
	assert_bool(get_tree().paused).is_true()
	assert_bool(_ui.is_showing()).is_true()


# --- Input contract ----------------------------------------------------------------------------------------

func test_confirm_is_ignored_during_the_0_4_second_lockout_then_works() -> void:
	_open("sanctuary")
	_ui.press_action_once_for_test(&"confirm")
	_tick(0.1)
	assert_bool(_ui.is_showing()).append_failure_message("confirm fired during the lockout").is_true()
	assert_bool(_ui.is_lockout_elapsed_for_test()).is_false()
	_tick(0.4)
	assert_bool(_ui.is_lockout_elapsed_for_test()).is_true()
	_ui.press_action_once_for_test(&"confirm")
	_tick(STEP)
	assert_bool(_ui.is_showing()).is_false()
	assert_str(_last_choice_id()).is_equal("mend")


func test_number_keys_and_clicks_are_ignored_during_the_lockout() -> void:
	_open("sanctuary")
	_ui.press_action_once_for_test(&"draft_select_2")
	_tick(0.1)
	_ui.simulate_card_click_for_test(1)
	assert_bool(_ui.is_showing()).is_true()
	assert_bool(_resolved.is_empty()).is_true()


func test_a_held_up_key_at_open_never_arms_or_confirms() -> void:
	_ui.set_action_pressed_for_test(&"move_up", true)
	_open("sanctuary")
	_tick(0.4)
	assert_bool(_ui.is_hold_up_armed_for_test()).is_false()
	_tick(2.0)
	assert_bool(_ui.is_showing()).append_failure_message("a key held at open auto-confirmed a card").is_true()
	assert_float(_ui.get_hold_progress_for_test()).is_equal(0.0)


func test_holding_up_one_second_after_returning_to_neutral_confirms() -> void:
	_ui.set_action_pressed_for_test(&"move_up", true)
	_open("sanctuary")
	_tick(0.5)
	_ui.set_action_pressed_for_test(&"move_up", false)
	_tick(STEP * 2.0)
	assert_bool(_ui.is_hold_up_armed_for_test()).is_true()
	_ui.set_action_pressed_for_test(&"move_up", true)
	_tick(0.9)
	assert_bool(_ui.is_showing()).append_failure_message("confirmed before 1.0 s").is_true()
	assert_float(_ui.get_hold_progress_for_test()).is_greater(0.8)
	_tick(0.2)
	assert_bool(_ui.is_showing()).is_false()


func test_releasing_up_before_one_second_resets_the_ring() -> void:
	_open("sanctuary")
	_tick(0.5)
	_ui.set_action_pressed_for_test(&"move_up", true)
	_tick(0.6)
	_ui.set_action_pressed_for_test(&"move_up", false)
	_tick(STEP)
	assert_float(_ui.get_hold_progress_for_test()).is_equal(0.0)
	assert_bool(_ui.is_showing()).is_true()


func test_left_right_cycle_on_press_with_a_0_3_second_repeat_and_wrap() -> void:
	_open("sanctuary")
	_tick(0.5)
	assert_int(_ui.get_highlighted_index_for_test()).is_equal(0)
	_ui.set_action_pressed_for_test(&"draft_cycle_left", true)
	_tick(STEP)
	assert_int(_ui.get_highlighted_index_for_test()).append_failure_message("left from the first card wraps to the last").is_equal(2)
	_tick(0.25)
	assert_int(_ui.get_highlighted_index_for_test()).append_failure_message("no repeat before 0.3 s").is_equal(2)
	_tick(0.1)
	assert_int(_ui.get_highlighted_index_for_test()).append_failure_message("repeat after 0.3 s").is_equal(1)
	_ui.set_action_pressed_for_test(&"draft_cycle_left", false)
	_tick(STEP)
	_ui.set_action_pressed_for_test(&"draft_cycle_right", true)
	_tick(STEP)
	assert_int(_ui.get_highlighted_index_for_test()).is_equal(2)


func test_number_keys_pick_the_matching_card() -> void:
	_open("sanctuary")
	_tick(0.5)
	_ui.press_action_once_for_test(&"draft_select_3")
	_tick(STEP)
	assert_str(_last_choice_id()).is_equal("valor")


func test_a_click_or_tap_picks_the_card_under_it() -> void:
	_open("sanctuary")
	_tick(0.5)
	_ui.simulate_card_click_for_test(1)
	assert_str(_last_choice_id()).is_equal("restore")


func test_a_bare_mouse_press_does_not_confirm_the_highlighted_card() -> void:
	_open("sanctuary")
	_tick(0.5)
	_ui._mouse_confirm_this_frame = true # what _input() sets for a mouse press on the `confirm` action
	_ui.press_action_once_for_test(&"confirm")
	_tick(STEP)
	assert_bool(_ui.is_showing()).is_true()


func test_picking_a_pact_option_through_the_ui_applies_it() -> void:
	_open("blood_pact")
	var pact_id: String = String(_ui.get_offer()["pact_id"])
	_tick(0.5)
	_ui.simulate_card_click_for_test(1) # Pay with the Tower
	assert_array(_events.taken_pacts).is_equal([pact_id])
	assert_float((_w["tower"] as Tower).health.max_health).is_equal_approx(400.0, 0.01)


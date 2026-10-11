extends GdUnitTestSuite
## First-encounter explainers over the run events (PT-UI, docs/33 A4; D323): the first time an
## event screen opens, its explainer card opens over it and the event waits; once the card closes
## the event's own 0.4 s lockout starts and the event is answered as before. Built on the same
## world as run_events_ui_test.

const STEP: float = 1.0 / 60.0

var _w: Dictionary
var _events: RunEvents
var _us: UpgradeSystem
var _ui: EventDraftController
var _draft: DraftController
var _pause: Node
var _clock: Node
var _fake_director: DraftFakeWaveDirector
var _explainers: ExplainerController
var _dir: String
var _resolved: Array[String] = []


func before_test() -> void:
	_dir = "user://__explainer_events_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	GameSettings.reset_state_for_test()
	_w = RunEventsTestHelpers.build_world(self)
	_events = _w["events"]
	_us = _w["us"]
	_resolved.clear()
	_events.event_resolved.connect(func(kind: String, _choice: Dictionary) -> void: _resolved.append(kind))
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
	_explainers = auto_free(ExplainerController.new()) as ExplainerController
	_explainers.forced_for_test = true
	_explainers.set_pause_authority_for_test(_pause)
	_explainers.set_test_input_mode_for_test(true)
	add_child(_explainers)
	_explainers.setup(_draft, _ui)
	_ui.explainers = _explainers


func after_test() -> void:
	RunEventsTestHelpers.cleanup()
	get_tree().paused = false
	GameSettings.reset_state_for_test()
	MetaProgress.set_base_path_for_test("user://")


func _tick_ui(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.0:
		var d: float = minf(STEP, remaining)
		_ui.tick_for_test(d)
		remaining -= d


func test_the_first_blood_pact_opens_its_explainer_over_the_event_and_the_event_waits() -> void:
	_events.queue_dev_event("blood_pact", false)
	assert_bool(_ui.poll_open()).is_true()
	assert_array(_explainers.get_queue()).append_failure_message("opening the event queues its card").is_equal(["blood_pact"])
	_explainers.tick_for_test(0.0)
	assert_str(_explainers.get_current_id()).is_equal("blood_pact")
	assert_array(_pause.get_active_reasons()).append_failure_message("the event holds the one pause; the card adds none").is_equal([&"draft"])
	_tick_ui(2.0)
	assert_bool(_ui.is_lockout_elapsed_for_test()).append_failure_message("the event's lockout does not run under the card").is_false()
	assert_str(_explainers.get_name_label_for_test().text).is_equal("Blood Pact")


func test_closing_the_card_restarts_the_events_lockout_then_it_answers_normally() -> void:
	_events.queue_dev_event("sanctuary", false)
	_ui.poll_open()
	_explainers.tick_for_test(0.0)
	_explainers.skip_lockout_for_test()
	_explainers.click_got_it_for_test()
	assert_bool(_explainers.is_showing()).is_false()
	assert_bool(_ui.is_showing()).is_true()
	assert_bool(_ui.is_lockout_elapsed_for_test()).is_false()
	_tick_ui(0.5)
	assert_bool(_ui.is_lockout_elapsed_for_test()).is_true()
	_ui.press_action_once_for_test(&"confirm")
	_tick_ui(STEP)
	assert_array(_resolved).is_equal(["sanctuary"])


func test_an_event_seen_before_opens_without_a_card() -> void:
	MetaProgress.mark_explainer_seen("opening_pick")
	_events.queue_dev_event("opening_pick", false)
	_ui.poll_open()
	assert_array(_explainers.get_queue()).is_empty()
	_tick_ui(0.5)
	assert_bool(_ui.is_lockout_elapsed_for_test()).is_true()

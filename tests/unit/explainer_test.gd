extends GdUnitTestSuite

## First-encounter explainers (PT-UI, docs/33 A4; D323): once per profile, a "don't show tips
## again" check box mirrored by Settings > Gameplay > "Show first-time tips", a queue that never
## stacks and never opens on top of a Draft, the Draft's movement-only input contract (0.4 s
## lockout, hold Up to confirm), and the hint toasts it replaced. Every test redirects MetaProgress
## and GameSettings to throwaway state first.

class FakeDraft extends DraftController:
	var busy: bool = false

	func is_busy() -> bool:
		return busy


class FakeEvents extends EventDraftController:
	var showing: bool = false

	func is_showing() -> bool:
		return showing


class FakePause extends Node:
	var reasons: Array[StringName] = []
	var pushes: int = 0
	var pops: int = 0

	func push_reason_immediate(reason: StringName) -> void:
		reasons.append(reason)
		pushes += 1

	func pop_reason_immediate(reason: StringName) -> void:
		reasons.erase(reason)
		pops += 1

	func get_active_reasons() -> Array[StringName]:
		return reasons


var _dir: String
var _settings_dir: String
var _pause: FakePause
var _draft: FakeDraft


func before_test() -> void:
	_dir = "user://__explainer_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	_settings_dir = "user://__explainer_settings_%d_%d.cfg" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	GameSettings.set_path_for_test(_settings_dir)
	GameSettings.reset_state_for_test()
	_pause = auto_free(FakePause.new())
	_draft = auto_free(FakeDraft.new())


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	MetaProgress.set_base_path_for_test("user://")


func _make() -> ExplainerController:
	var controller: ExplainerController = auto_free(ExplainerController.new())
	controller.forced_for_test = true
	controller.set_pause_authority_for_test(_pause)
	controller.set_test_input_mode_for_test(true)
	controller.setup(_draft, null)
	add_child(controller)
	return controller


## Ticks until the card is open and its lockout has elapsed.
func _open_and_unlock(controller: ExplainerController) -> void:
	controller.tick_for_test(0.0)
	assert_bool(controller.is_showing()).is_true()
	controller.skip_lockout_for_test()


func test_the_setting_defaults_on_and_persists() -> void:
	assert_bool(GameSettings.is_show_first_time_tips()).is_true()
	GameSettings.set_show_first_time_tips(false)
	GameSettings.reset_state_for_test() # forget the in-memory value
	GameSettings.load_from_disk()
	assert_bool(GameSettings.is_show_first_time_tips()).append_failure_message("the key show_first_time_tips was saved").is_false()


func test_the_settings_screen_has_the_gameplay_row() -> void:
	assert_array(SettingsMenu.TAB_ROWS[SettingsMenu.Tab.GAMEPLAY]).contains([SettingsMenu.ROW_FIRST_TIME_TIPS])
	assert_str(SettingsMenu.ROW_FIRST_TIME_TIPS).is_equal("first_time_tips")


func test_an_explainer_shows_once_per_profile() -> void:
	var controller: ExplainerController = _make()
	assert_bool(controller.request("tower_seeker")).is_true()
	assert_bool(controller.request("tower_seeker")).append_failure_message("already waiting: not queued twice").is_false()
	_open_and_unlock(controller)
	assert_str(controller.get_current_id()).is_equal("tower_seeker")
	assert_bool(MetaProgress.is_explainer_seen("tower_seeker")).is_true()
	assert_bool(MetaProgress.is_discovered("tower_seeker")).append_failure_message("the thing is now in the Field Guide").is_true()
	controller.click_got_it_for_test()
	assert_bool(controller.is_showing()).is_false()
	assert_bool(controller.request("tower_seeker")).append_failure_message("never again on this profile").is_false()
	# A new session on the same profile still remembers.
	MetaProgress.set_base_path_for_test(_dir)
	MetaProgress.ensure_loaded()
	assert_bool(_make().request("tower_seeker")).is_false()


func test_the_card_shows_the_entry_text_helps_hurts_and_a_symbol() -> void:
	var controller: ExplainerController = _make()
	controller.request("powder_keg")
	_open_and_unlock(controller)
	assert_str(controller.get_name_label_for_test().text).is_equal("Powder Keg")
	assert_str(controller.get_helps_text_for_test()).is_not_empty()
	assert_str(controller.get_hurts_text_for_test()).is_not_empty()
	assert_str(controller.get_effect_text_for_test()).contains(str(int(ArenaKeg.BLAST_RADIUS_PX)))
	controller.click_got_it_for_test()
	controller.request("goblin_warchief")
	_open_and_unlock(controller)
	assert_str(controller.get_hurts_text_for_test()).is_not_empty()
	assert_str(controller.get_helps_text_for_test()).append_failure_message("a boss does not help you").is_empty()


func test_dont_show_tips_again_turns_the_setting_off_and_clears_the_queue() -> void:
	var controller: ExplainerController = _make()
	controller.request("tower_seeker")
	controller.request("bomber")
	_open_and_unlock(controller)
	controller.get_check_box_for_test().button_pressed = true
	controller.click_got_it_for_test()
	assert_bool(GameSettings.is_show_first_time_tips()).is_false()
	assert_int(controller.get_queue().size()).append_failure_message("the waiting card is dropped").is_equal(0)
	assert_bool(controller.is_showing()).is_false()
	assert_bool(controller.request("brute")).append_failure_message("no tip is queued once they are off").is_false()


func test_with_the_setting_off_nothing_queues_and_nothing_is_marked_seen() -> void:
	GameSettings.set_show_first_time_tips_for_test(false)
	var controller: ExplainerController = _make()
	assert_bool(controller.request("shrine")).is_false()
	assert_int(controller.get_queue().size()).is_equal(0)
	controller.tick_for_test(0.5)
	assert_bool(controller.is_showing()).is_false()
	assert_bool(MetaProgress.is_explainer_seen("shrine")).append_failure_message("a skipped tip is not spent").is_false()
	# Turning the setting back on brings it back (it was never shown).
	GameSettings.set_show_first_time_tips_for_test(true)
	assert_bool(controller.request("shrine")).is_true()


func test_a_card_never_opens_on_top_of_a_draft_and_waits_until_it_closes() -> void:
	var controller: ExplainerController = _make()
	_draft.busy = true
	controller.request("bomber")
	controller.tick_for_test(0.5)
	assert_bool(controller.is_showing()).append_failure_message("a Draft is up: the card waits").is_false()
	assert_int(controller.get_queue().size()).is_equal(1)
	assert_int(_pause.pushes).is_equal(0)
	_draft.busy = false
	controller.tick_for_test(0.1)
	assert_bool(controller.is_showing()).append_failure_message("the Draft closed: now it opens").is_true()
	assert_int(_pause.pushes).is_equal(1)


func test_it_waits_while_something_else_holds_the_pause() -> void:
	var controller: ExplainerController = _make()
	_pause.reasons.append(&"pause_menu")
	controller.request("brute")
	controller.tick_for_test(0.5)
	assert_bool(controller.is_showing()).is_false()
	_pause.reasons.clear()
	controller.tick_for_test(0.1)
	assert_bool(controller.is_showing()).is_true()


func test_cards_queue_and_never_stack_the_next_follows_still_paused() -> void:
	var controller: ExplainerController = _make()
	controller.request("tower_seeker")
	controller.request("bomber")
	_open_and_unlock(controller)
	assert_str(controller.get_current_id()).is_equal("tower_seeker")
	assert_array(controller.get_queue()).is_equal(["bomber"])
	controller.click_got_it_for_test()
	assert_str(controller.get_current_id()).append_failure_message("the next card follows at once").is_equal("bomber")
	assert_int(_pause.pushes).append_failure_message("one pause for the whole chain, no flicker of unpaused play").is_equal(1)
	assert_int(_pause.pops).is_equal(0)
	controller.skip_lockout_for_test()
	controller.click_got_it_for_test()
	assert_bool(controller.is_showing()).is_false()
	assert_int(_pause.pops).is_equal(1)
	assert_array(_pause.reasons).is_empty()


func test_the_event_screens_card_opens_over_the_event_and_only_it() -> void:
	var events: FakeEvents = auto_free(FakeEvents.new())
	events.showing = true
	var controller: ExplainerController = _make()
	controller.setup(_draft, events)
	_pause.reasons.append(&"draft") # the event holds the Draft's own pause reason
	controller.request("bomber")
	controller.request("blood_pact")
	controller.tick_for_test(0.5)
	assert_str(controller.get_current_id()).append_failure_message("only the event's own card opens over it").is_equal("blood_pact")
	assert_int(_pause.pushes).append_failure_message("the event already holds the pause").is_equal(0)
	assert_array(controller.get_queue()).is_equal(["bomber"])


# --- the input contract ---------------------------------------------------------------------------

func test_input_is_locked_out_for_the_first_0_4_seconds() -> void:
	var controller: ExplainerController = _make()
	controller.request("tower_seeker")
	controller.tick_for_test(0.0)
	controller.press_action_once_for_test(&"confirm")
	controller.tick_for_test(0.2)
	assert_bool(controller.is_showing()).append_failure_message("a press inside the lockout does nothing").is_true()
	controller.click_got_it_for_test()
	assert_bool(controller.is_showing()).append_failure_message("a click inside the lockout does nothing").is_true()
	controller.tick_for_test(0.25)
	assert_bool(controller.is_lockout_elapsed_for_test()).is_true()
	controller.press_action_once_for_test(&"confirm")
	controller.tick_for_test(0.016)
	assert_bool(controller.is_showing()).append_failure_message("confirm after the lockout presses Got it").is_false()


func test_holding_up_for_a_second_confirms_got_it() -> void:
	var controller: ExplainerController = _make()
	controller.request("tower_seeker")
	_open_and_unlock(controller)
	controller.set_action_pressed_for_test(&"move_up", true)
	controller.tick_for_test(0.6)
	assert_float(controller.get_hold_progress_for_test()).is_greater(0.0)
	assert_bool(controller.is_showing()).is_true()
	controller.tick_for_test(0.5)
	assert_bool(controller.is_showing()).append_failure_message("hold Up for DraftController.HOLD_CONFIRM_SECONDS").is_false()


func test_a_hold_already_down_at_open_cannot_auto_confirm() -> void:
	var controller: ExplainerController = _make()
	controller.set_action_pressed_for_test(&"move_up", true)
	controller.request("tower_seeker")
	controller.tick_for_test(0.0)
	controller.tick_for_test(0.5) # lockout ends with Up still held: not armed
	controller.tick_for_test(2.0)
	assert_bool(controller.is_showing()).append_failure_message("neutral-return arming applies").is_true()
	controller.set_action_pressed_for_test(&"move_up", false)
	controller.tick_for_test(0.1)
	controller.set_action_pressed_for_test(&"move_up", true)
	controller.tick_for_test(1.1)
	assert_bool(controller.is_showing()).is_false()


func test_left_moves_to_the_check_box_and_confirm_toggles_it() -> void:
	var controller: ExplainerController = _make()
	controller.request("tower_seeker")
	_open_and_unlock(controller)
	assert_int(controller.get_highlight_for_test()).append_failure_message("Got it is highlighted first").is_equal(1)
	controller.press_action_once_for_test(&"move_left")
	controller.set_action_pressed_for_test(&"move_left", true)
	controller.tick_for_test(0.016)
	controller.set_action_pressed_for_test(&"move_left", false)
	assert_int(controller.get_highlight_for_test()).is_equal(0)
	controller.press_action_once_for_test(&"confirm")
	controller.tick_for_test(0.016)
	assert_bool(controller.get_check_box_for_test().button_pressed).is_true()
	assert_bool(controller.is_showing()).append_failure_message("confirm on the check box toggles it, it does not close").is_true()
	assert_bool(SelectableState.of(controller.get_check_box_for_test()).is_selected()).append_failure_message("a check box shows its own tick, never the selected plate look (D382)").is_false()


func test_the_card_is_a_paused_ui_that_keeps_running() -> void:
	var controller: ExplainerController = _make()
	assert_int(controller.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)
	assert_int(controller.layer).is_greater(DraftController.DRAFT_CANVAS_LAYER)


# --- triggers --------------------------------------------------------------------------------------

func test_every_trigger_id_has_an_entry_to_show() -> void:
	var ids: Array[String] = []
	ids.append_array(ExplainerController.EVENT_IDS)
	ids.append_array(ExplainerController.ENEMY_IDS)
	for id in ExplainerController.ARENA_GROUPS.values():
		ids.append(String(id))
	ids.append_array(["bridge", "elite", "goblin_warchief", "juggernaut", "bombardier_king"])
	for id in ids:
		assert_bool(FieldGuideCatalog.find_entry(id).is_empty()).append_failure_message("no entry for the explainer %s" % id).is_false()


func test_a_boss_and_the_first_elite_queue_their_cards() -> void:
	var controller: ExplainerController = _make()
	EventBus.emit_elite_spawned(null, "swift")
	EventBus.emit_boss_spawned(null, "warchief", "Goblin Warchief", 2200.0)
	assert_array(controller.get_queue()).contains(["elite", "goblin_warchief"])


func test_the_toast_hints_for_these_things_are_gone_but_the_control_hints_stay() -> void:
	var texts: Array = RunHints.TEXT_KEYS.keys()
	assert_array(texts).contains([RunHints.ID_START, RunHints.ID_DASH, RunHints.ID_SKILL_READY])
	assert_int(texts.size()).append_failure_message("only control and repair hints remain toasts").is_equal(4)


func test_how_to_play_points_to_the_field_guide() -> void:
	assert_str(HowToPlay.guide_line()).contains("Field Guide")
	assert_str(HowToPlay.body(3)).contains(str(AbilityIds.MAX_PLAYER_ABILITIES))

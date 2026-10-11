extends GdUnitTestSuite
## Run events in the assembled prototype scene (docs/32 §A). Kept apart from the
## unit suites: they build their own Player / Tower / UpgradeSystem in the same groups.


func after_test() -> void:
	RunConfig.reset_for_test()
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func test_the_prototype_scene_stays_event_free_headless_unless_forced() -> void:
	RunConfig.run_events_forced = false
	var proto: PrototypeIntegration = auto_free(preload("res://scenes/prototype.tscn").instantiate()) as PrototypeIntegration
	add_child(proto)
	assert_object(proto.get_run_events()).append_failure_message("headless scene tests must not stop at an Opening Pick").is_null()
	assert_bool(get_tree().paused).is_false()


func test_a_forced_prototype_opens_the_opening_pick_paused_before_the_first_tick_and_resumes_on_pick() -> void:
	RunConfig.run_events_forced = true
	var proto: PrototypeIntegration = auto_free(preload("res://scenes/prototype.tscn").instantiate()) as PrototypeIntegration
	add_child(proto)
	RunConfig.run_events_forced = false
	var ui: EventDraftController = proto.get_event_controller()
	assert_object(ui).is_not_null()
	assert_bool(ui.is_showing()).append_failure_message("the Opening Pick must be up before the first tick").is_true()
	assert_str(ui.get_kind()).is_equal("opening_pick")
	assert_bool(get_tree().paused).is_true()
	assert_int(ui.get_card_views_for_test().size()).is_equal(3)
	ui.skip_lockout_for_test()
	ui.confirm_choice_for_test(0)
	assert_bool(get_tree().paused).is_false()
	assert_int((proto.get_node("Main/AbilityManager") as AbilityManager).owned_count("player")).is_equal(1)


func test_the_wave_director_is_given_the_event_gap_floor_and_events_follow_its_waves() -> void:
	RunConfig.run_events_forced = true
	var proto: PrototypeIntegration = auto_free(preload("res://scenes/prototype.tscn").instantiate()) as PrototypeIntegration
	add_child(proto)
	RunConfig.run_events_forced = false
	var ui: EventDraftController = proto.get_event_controller()
	ui.skip_lockout_for_test()
	ui.confirm_choice_for_test(0)
	var wd: WaveDirector = proto.get_node("Main/WaveDirector") as WaveDirector
	var events: RunEvents = proto.get_run_events()
	# The director's own signal queues the event for the wave that just ended (wave index 3 = wave 4).
	wd.wave_ended.emit("wave_04", 3)
	assert_array(events.get_pending_kinds()).is_equal(["patrons_boon", "sanctuary"]) # PT-SWARM D346: the Warchief is wave 5
	assert_float(events.gap_floor_for_director(4)).is_equal(8.0)

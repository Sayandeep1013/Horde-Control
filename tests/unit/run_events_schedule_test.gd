extends GdUnitTestSuite
## Run events: WHEN each event fires (docs/32 §A; Register "v1.0 Run Events"), the
## 8 s gap floor, the queue order, and that a seed always offers the same cards.

const WaveDirectorScript: GDScript = preload("res://src/director/wave_director.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")

var _w: Dictionary


func before_test() -> void:
	_w = RunEventsTestHelpers.build_world(self)


func after_test() -> void:
	RunEventsTestHelpers.cleanup()


# --- the pure schedule ------------------------------------------------------------

func test_campaign_events_fire_after_exactly_waves_4_7_11_and_14() -> void:
	var expected: Dictionary = {4: ["patrons_boon"], 7: ["sanctuary"], 11: ["patrons_boon"], 14: ["sanctuary"]}
	for wave in range(1, 16):
		var got: Array[String] = RunEvents.events_after_wave(wave, false)
		assert_array(got).append_failure_message("campaign wave %d" % wave).is_equal(expected.get(wave, []))


func test_pactbound_adds_a_blood_pact_after_wave_11_between_the_boon_and_nothing_else() -> void:
	assert_array(RunEvents.events_after_wave(11, false, true)).is_equal(["patrons_boon", "blood_pact"])
	assert_array(RunEvents.events_after_wave(4, false, true)).is_equal(["patrons_boon"])
	assert_array(RunEvents.events_after_wave(11, false, false)).is_equal(["patrons_boon"])


func test_endless_repeats_a_patron_every_7th_wave_past_15_and_a_sanctuary_before_every_warchief() -> void:
	assert_array(RunEvents.events_after_wave(15, true)).is_equal(["sanctuary"]) # the Warchief of wave 16 follows
	assert_array(RunEvents.events_after_wave(22, true)).is_equal(["patrons_boon", "sanctuary"]) # Patron first, blessing last
	assert_array(RunEvents.events_after_wave(29, true)).is_equal(["patrons_boon", "sanctuary"])
	for wave in [16, 17, 18, 19, 20, 21, 23, 24, 28]:
		assert_array(RunEvents.events_after_wave(wave, true)).append_failure_message("endless wave %d" % wave).is_empty()
	# Sanctuary comes right before each Warchief wave: 16, 23, 30.
	for warchief in [16, 23, 30]:
		assert_bool(RunEvents.is_warchief_wave(warchief, true)).is_true()
		assert_bool(RunEvents.events_after_wave(warchief - 1, true).has("sanctuary")).append_failure_message("no Sanctuary before wave %d" % warchief).is_true()
	assert_bool(RunEvents.is_warchief_wave(16, false)).is_false()


func test_the_gap_after_an_event_wave_is_at_least_8_seconds() -> void:
	for wave in [4, 7, 8, 11, 14]:
		assert_float(RunEvents.gap_floor_after_wave(wave, false)).append_failure_message("wave %d" % wave).is_equal(8.0)
	for wave in [1, 2, 3, 5, 6, 9, 10, 12, 13]:
		assert_float(RunEvents.gap_floor_after_wave(wave, false)).append_failure_message("wave %d" % wave).is_equal(0.0)
	assert_float(RunEvents.gap_floor_after_wave(23, true)).is_equal(8.0) # the endless Warchief wave: its Blood Pact follows
	assert_float(RunEvents.gap_floor_after_wave(22, true)).is_equal(8.0)


func test_the_wave_director_honours_the_gap_floor_provider() -> void:
	var clock: Node = auto_free(SimClockScript.new())
	var director: WaveDirector = auto_free(WaveDirectorScript.new()) as WaveDirector
	director.use_legacy_prototype_sequence_for_test()
	director.driven_externally = true
	add_child(director)
	director.set_sim_clock_for_test(clock)
	var wave: WaveDefinition = WaveDefinition.new()
	wave.unique_id = "w"
	wave.inter_wave_gap_seconds = 3.0
	var encounter: EncounterDefinition = EncounterDefinition.new()
	encounter.minimum_recovery_gap_seconds = 1.0
	clock.now = 100.0
	director._current_wave_index = 3 # wave 4
	director.set_event_gap_provider(func(n: int) -> float: return 8.0 if n == 4 else 0.0)
	director._end_current_wave(wave, encounter)
	assert_float(director.get_gap_deadline_for_test() - 100.0).append_failure_message("an event wave's gap must be floored to 8 s").is_equal(8.0)
	director._current_wave_index = 4 # wave 5: no floor, the authored gap stands
	director._end_current_wave(wave, encounter)
	assert_float(director.get_gap_deadline_for_test() - 100.0).is_equal(3.0)


# --- the queue ----------------------------------------------------------------------

func test_begin_run_queues_the_opening_pick_first() -> void:
	var events: RunEvents = _w["events"]
	events.begin_run()
	assert_array(events.get_pending_kinds()).is_equal(["opening_pick"])


func test_a_wave_end_queues_its_events_in_order_and_other_waves_queue_nothing() -> void:
	var events: RunEvents = _w["events"]
	events.on_wave_ended(3)
	assert_bool(events.has_pending()).is_false()
	events.on_wave_ended(4)
	assert_array(events.get_pending_kinds()).is_equal(["patrons_boon"])
	events.pop_next(0.0)
	events.on_wave_ended(14)
	assert_array(events.get_pending_kinds()).is_equal(["sanctuary"])


func test_events_do_nothing_when_disabled() -> void:
	var events: RunEvents = _w["events"]
	events.enabled = false
	events.begin_run()
	events.on_wave_ended(4)
	assert_bool(events.has_pending()).is_false()


func test_a_warchief_kill_queues_a_blood_pact_that_waits_for_the_chest_draft() -> void:
	var events: RunEvents = _w["events"]
	events.on_warchief_defeated("warchief", 50.0, false)
	assert_array(events.get_pending_kinds()).is_equal(["blood_pact"])
	assert_bool(events.pop_next(51.0).is_empty()).append_failure_message("the pact must wait for the War Chest draft").is_true()
	# The chest opened: the pact is ready at once (the controller still queues it behind the chest Draft).
	events._on_war_chest_opened(51.0)
	assert_str(String(events.pop_next(51.0).get("kind", ""))).is_equal("blood_pact")


func test_a_blood_pact_opens_anyway_after_the_chest_wait() -> void:
	var events: RunEvents = _w["events"]
	events.on_warchief_defeated("warchief", 50.0, true)
	assert_bool(events.pop_next(50.0 + RunEvents.PACT_CHEST_WAIT_SECONDS - 0.1).is_empty()).is_true()
	var e: Dictionary = events.pop_next(50.0 + RunEvents.PACT_CHEST_WAIT_SECONDS)
	assert_str(String(e.get("kind", ""))).is_equal("blood_pact")
	assert_bool(bool(e.get("flawless", false))).is_true()


func test_only_the_goblin_warchief_brings_a_pact() -> void:
	var events: RunEvents = _w["events"]
	events.on_warchief_defeated("king", 50.0, true)
	assert_bool(events.has_pending()).is_false()


func test_a_seed_always_offers_the_same_cards_and_another_seed_can_differ() -> void:
	var a: Array[String] = _opening_ids_for_seed(11, true)
	var b: Array[String] = _opening_ids_for_seed(11, true)
	assert_array(a).append_failure_message("the same seed must offer the same Opening Pick").is_equal(b)
	var differs: bool = false
	for s in range(12, 30):
		if _opening_ids_for_seed(s, true) != a:
			differs = true
			break
	assert_bool(differs).append_failure_message("19 different seeds all offered the same Opening Pick: the roll ignores the seed").is_true()


func _opening_ids_for_seed(seed_value: int, unlock_all: bool) -> Array[String]:
	var events: RunEvents = _w["events"]
	events.run_seed = seed_value
	events._serials.clear()
	if unlock_all:
		(_w["us"] as UpgradeSystem).set_unlocked_card_ids(["frost_arrows", "storm_bolt", "sacred_ground"])
	return RunEventsTestHelpers.card_ids(events.build_offer({"kind": "opening_pick"}))

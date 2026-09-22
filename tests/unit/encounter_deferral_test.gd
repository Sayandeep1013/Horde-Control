extends GdUnitTestSuite

## Encounter deferral test (MASTER_SDLC.md > Acceptance Test Matrix >
## Encounter Tests, P2.12): "No encounter opens while the Level-Up Draft is
## open, and none opens within 1.5 seconds of it closing." PLAN.md names
## this task's own result as a "grace-period timestamp result": the Wave
## Director (P2.8/P2.9, read-only here -- src/director/wave_director.gd is
## outside this task's write scope) owns the actual 1.5 s grace-period
## countdown once `notify_draft_closed(now)` is called; this suite proves
## DraftController calls it with the CORRECT timestamp, exactly ONCE per
## whole queued session (never once per sub-draft), and only after the
## simulation has genuinely been frozen (via a REAL PauseAuthority/SimClock
## pair driven by real engine physics frames, mirroring
## tests/unit/pause_clock_test.gd's own pattern) for the entire time the
## Draft was open.
##
## "No encounter opens while the Draft is open" is a property of full pause
## itself (SimLoop -- and therefore the real WaveDirector's own
## physics_step() -- is PROCESS_MODE_PAUSABLE and simply never runs while
## paused), not something this suite re-derives from a fake; it verifies
## that guarantee here by observing a REAL SimClock genuinely stop advancing
## while the reason is active, which is the same mechanism that would
## freeze a real WaveDirector.


var _pause: Node
var _clock: Node
var _run_inventory: RunInventory
var _upgrade_system: UpgradeSystem
var _wave_director: DraftFakeWaveDirector
var _controller: DraftController


func before_test() -> void:
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)
	await get_tree().physics_frame # warm-up (pause_clock_test.gd's own reason: node-admission timing)

	_run_inventory = DraftTestHelpers.build_run_inventory()
	_upgrade_system = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(_upgrade_system)
	_wave_director = auto_free(DraftFakeWaveDirector.new())
	add_child(_wave_director)
	_wave_director.set_current_wave_id_for_test("wave_combat_1") # not a teaching wave -- see xp_cap_check_test.gd for that path

	_controller = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(_controller)
	_controller.set_run_inventory_for_test(_run_inventory)
	_controller.set_upgrade_system_for_test(_upgrade_system)
	_controller.set_wave_director_for_test(_wave_director)
	_controller.set_pause_authority_for_test(_pause)
	_controller.set_sim_clock_for_test(_clock)
	_controller.skip_lockout_for_test()


func after_test() -> void:
	get_tree().paused = false


func test_simclock_is_frozen_for_the_whole_time_the_draft_is_open() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var now_before: float = _clock.now

	_controller.force_open_for_test(false)
	_pause.flush() # SimLoop step 14 equivalent -- nothing else will call this while paused
	assert_bool(get_tree().paused).is_true()

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_clock.now).append_failure_message("SimClock advanced while the Draft was open -- an encounter could have progressed too").is_equal(now_before)


func test_notify_draft_closed_receives_the_close_instant_exactly_once() -> void:
	await get_tree().physics_frame
	_controller.force_open_for_test(false)
	_pause.flush()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var frozen_now: float = _clock.now

	_controller.confirm_choice_for_test(0)

	assert_bool(get_tree().paused).append_failure_message("tree did not unpause when the Draft closed").is_false()
	var calls: Array[float] = _wave_director.get_notify_draft_closed_calls_for_test()
	assert_int(calls.size()).append_failure_message("notify_draft_closed() must be called exactly once per closed session").is_equal(1)
	assert_float(calls[0]).append_failure_message("notify_draft_closed() was not called with SimClock.now at the instant of close").is_equal(frozen_now)


func test_notify_draft_closed_is_not_called_until_the_whole_two_draft_queue_drains() -> void:
	await get_tree().physics_frame
	# Two simultaneous level-ups -> two queued drafts (see draft_queue_test.gd).
	_run_inventory.credit_xp(19.0) # 8 (level 1) + 11 (level 2), Register > "XP & levels" (Author decision D108, 2026-09-23; was 15 + 20 = 35)
	_controller.physics_step(0.016)
	_pause.flush()
	assert_int(_controller.get_pending_draft_count_for_test()).is_equal(1)

	_controller.confirm_choice_for_test(0) # first of two
	assert_int(_wave_director.get_notify_draft_closed_calls_for_test().size()).append_failure_message("notify_draft_closed() fired between two sequential drafts in the same session -- the grace period must not start until the WHOLE queue drains").is_equal(0)
	assert_bool(get_tree().paused).append_failure_message("tree unpaused between two sequential drafts in the same session").is_true()

	_controller.confirm_choice_for_test(0) # second (last) of two
	assert_int(_wave_director.get_notify_draft_closed_calls_for_test().size()).is_equal(1)
	assert_bool(get_tree().paused).is_false()

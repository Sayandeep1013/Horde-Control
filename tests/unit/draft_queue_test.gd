extends GdUnitTestSuite

## Draft queue test (MASTER_SDLC.md > Acceptance Test Matrix > Encounter
## Tests, P2.12): "Two simultaneous level-ups produce two sequential drafts
## and no draft is dropped." MASTER_SDLC.md > "Experience (XP)": "Each
## level-up opens one Level-Up Draft; simultaneous level-ups queue their
## drafts sequentially." docs/20 > "Level-Up Draft Rule": "The draft queue
## is processed sequentially if multiple level-ups occurred."
##
## RunInventory.consume_level_up_requested() (src/economy/run_inventory.gd,
## outside this task's write scope) is a boolean, not a counter, so a
## SINGLE credit_xp() call that crosses two level thresholds at once (a
## burst large enough to pay for both level 1 and level 2 in one shot)
## produces exactly one `true` from that flag. This suite proves
## DraftController.physics_step() still recovers the true count -- by
## comparing RunInventory.level before/after -- and queues TWO requests,
## not one, so neither draft is dropped.

const RegisterLevelOneCost: int = 15 # Register > "XP & levels": 10 + 5*(0+1)
const RegisterLevelTwoCost: int = 20 # 10 + 5*(1+1)

var _controller: DraftController
var _run_inventory: RunInventory
var _upgrade_system: UpgradeSystem
var _wave_director: DraftFakeWaveDirector
var _pause: Node
var _clock: Node


func before_test() -> void:
	_run_inventory = DraftTestHelpers.build_run_inventory()

	_upgrade_system = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(_upgrade_system)

	_wave_director = auto_free(DraftFakeWaveDirector.new())
	add_child(_wave_director)
	_wave_director.set_current_wave_id_for_test("wave_combat_1") # not a teaching wave

	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)

	_controller = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(_controller)
	_controller.set_run_inventory_for_test(_run_inventory)
	_controller.set_upgrade_system_for_test(_upgrade_system)
	_controller.set_wave_director_for_test(_wave_director)
	_controller.set_pause_authority_for_test(_pause)
	_controller.set_sim_clock_for_test(_clock)
	_controller.skip_lockout_for_test()


func after_test() -> void:
	# Safety net (project convention -- pause_clock_test.gd,
	# player_input_buffer_test.gd): an interrupted test must never leak a
	# pause reason into the shared autoload for suites that run after it.
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func _credit_xp_crossing_two_levels() -> void:
	# 15 XP reaches level 1 exactly; 20 more reaches level 2 -- one
	# credit_xp() call carrying both (35) crosses two thresholds inside
	# RunInventory's own `while xp_current >= xp_required_for_next_level`
	# loop, in a single physics tick.
	_run_inventory.credit_xp(float(RegisterLevelOneCost + RegisterLevelTwoCost))


func test_two_simultaneous_level_ups_queue_two_drafts_not_one() -> void:
	assert_int(_run_inventory.level).is_equal(0)
	_credit_xp_crossing_two_levels()
	assert_int(_run_inventory.level).is_equal(2).append_failure_message("RunInventory itself did not cross two level thresholds -- test premise broken")

	_controller.physics_step(0.016)

	# One draft open now, ONE MORE still queued -- not zero, not dropped.
	assert_bool(_controller.is_draft_showing_for_test()).is_true()
	assert_int(_controller.get_pending_draft_count_for_test()).is_equal(1).append_failure_message("expected exactly one draft still queued after the first opened; got %d" % _controller.get_pending_draft_count_for_test())


func test_no_draft_is_dropped_across_the_whole_sequential_queue() -> void:
	_credit_xp_crossing_two_levels()
	_controller.physics_step(0.016)

	var first_ids: Array[String] = _controller.get_current_card_ids_for_test()
	assert_int(first_ids.size()).is_equal(3)

	# Resolve the first draft.
	_controller.confirm_choice_for_test(0)

	# The SECOND queued draft must open immediately -- the session must
	# still be paused (no live-simulation gap between two "simultaneous"
	# drafts), and nothing must have been silently skipped.
	assert_int(_controller.get_pending_draft_count_for_test()).is_equal(0)
	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("second queued draft never opened -- it was dropped").is_true()
	assert_bool(_controller.is_draft_session_active_for_test()).append_failure_message("session closed/unpaused between the two sequential drafts").is_true()

	var second_ids: Array[String] = _controller.get_current_card_ids_for_test()
	assert_int(second_ids.size()).is_equal(3)

	# Resolve the second (and last) draft -- only now does the session close.
	_controller.confirm_choice_for_test(0)
	assert_bool(_controller.is_draft_showing_for_test()).is_false()
	assert_bool(_controller.is_draft_session_active_for_test()).is_false()
	assert_bool(_wave_director.was_notify_draft_closed_called_for_test()).append_failure_message("WaveDirector.notify_draft_closed() was never called once the whole queue drained").is_true()


func test_each_queued_draft_offers_the_one_of_each_guarantee() -> void:
	_credit_xp_crossing_two_levels()
	_controller.physics_step(0.016)

	for draft_index in range(2):
		var ids: Array[String] = _controller.get_current_card_ids_for_test()
		var has_player: bool = false
		var has_tower: bool = false
		for id in ids:
			var def: UpgradeDefinition = _upgrade_system.get_definition(id)
			assert_object(def).is_not_null()
			if def.pool_ownership == ContractEnums.PoolOwnership.Player:
				has_player = true
			elif def.pool_ownership == ContractEnums.PoolOwnership.Tower:
				has_tower = true
		assert_bool(has_player).append_failure_message("draft %d had no Player card" % draft_index).is_true()
		assert_bool(has_tower).append_failure_message("draft %d had no Tower card" % draft_index).is_true()
		_controller.confirm_choice_for_test(0)


func test_pause_reason_stays_active_until_the_whole_queue_drains() -> void:
	_credit_xp_crossing_two_levels()
	_controller.physics_step(0.016)
	_pause.flush()
	assert_bool(_pause.has_reason(&"draft")).is_true()

	_controller.confirm_choice_for_test(0) # first of two resolved
	_pause.flush()
	assert_bool(_pause.has_reason(&"draft")).append_failure_message("pause reason dropped between two sequential drafts").is_true()

	_controller.confirm_choice_for_test(0) # second (last) resolved
	_pause.flush()
	assert_bool(_pause.has_reason(&"draft")).append_failure_message("pause reason never released once the whole queue drained").is_false()

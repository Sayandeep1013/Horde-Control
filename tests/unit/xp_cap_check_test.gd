extends GdUnitTestSuite

## XP cap check (MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests,
## P2.12): "During T1-T4, XP never exceeds 14 and no level-up fires; the
## forced Draft at T4's end grants level 1 and keeps the held XP toward
## level 2." Register > "Spawning & Waves" > "Teaching wave XP (C-XPCAP)":
## same rule, cap authored on data/economy/prototype.tres
## (xp_cap_during_teaching_waves = 14) by P2.10, which explicitly left
## enforcement to this task (P2.12 task brief).
##
## src/economy/run_inventory.gd (P2.10, outside this task's write scope)
## has no notion of teaching waves at all -- credit_xp() always applies the
## level curve unconditionally, so a burst of shards that crosses the
## level-1 threshold (15 XP) WILL fire a real level-up inside RunInventory
## itself before DraftController.physics_step() ever runs this same tick.
## This suite proves the enforcement this task adds catches and reverses
## that every time, including the "erroneous level-up already happened"
## case a naive "just clamp xp_current" implementation would under-refund
## (see draft_controller.gd's own `_enforce_xp_cap_and_revert_erroneous_
## level_up()` header comment for why a refund step is required, not just a
## clamp).

const CAP: float = 14.0 # data/economy/prototype.tres: xp_cap_during_teaching_waves
const LEVEL_1_COST: float = 15.0 # Register > "XP & levels": 10 + 5*(0+1)
const LEVEL_2_COST: float = 20.0 # 10 + 5*(1+1)

var _run_inventory: RunInventory
var _upgrade_system: UpgradeSystem
var _wave_director: DraftFakeWaveDirector
var _controller: DraftController


func before_test() -> void:
	_run_inventory = DraftTestHelpers.build_run_inventory()
	_upgrade_system = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(_upgrade_system)
	_wave_director = auto_free(DraftFakeWaveDirector.new())
	add_child(_wave_director)
	_wave_director.set_current_wave_id_for_test("wave_t1")

	_controller = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(_controller)
	_controller.set_run_inventory_for_test(_run_inventory)
	_controller.set_upgrade_system_for_test(_upgrade_system)
	_controller.set_wave_director_for_test(_wave_director)
	_controller.skip_lockout_for_test()


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func test_xp_never_exceeds_the_cap_across_all_four_teaching_waves() -> void:
	for wave_id in ["wave_t1", "wave_t2", "wave_t3", "wave_t4"]:
		_wave_director.set_current_wave_id_for_test(wave_id)
		# Far more single-XP shards than the cap allows through, so the
		# threshold-crossing/revert path (not just the simple clamp path)
		# is exercised repeatedly within each wave.
		for shard in 20:
			_run_inventory.credit_xp(1.0)
			_controller.physics_step(0.016)
			assert_float(_run_inventory.xp_current).append_failure_message(
				"XP exceeded the %.0f cap during %s (shard %d): got %s" % [CAP, wave_id, shard, _run_inventory.xp_current]
			).is_less_equal(CAP)
			assert_int(_run_inventory.level).append_failure_message(
				"a level-up fired during teaching wave %s (shard %d)" % [wave_id, shard]
			).is_equal(0)


func test_a_burst_that_crosses_the_level_1_threshold_is_fully_refunded_and_reverted() -> void:
	_wave_director.set_current_wave_id_for_test("wave_t3")
	_run_inventory.credit_xp(LEVEL_1_COST + 5.0) # 20 XP in one call: crosses the 15-XP threshold, 5 left over
	assert_int(_run_inventory.level).append_failure_message("test premise broken: RunInventory itself did not cross the level-1 threshold").is_equal(1)
	assert_float(_run_inventory.xp_current).is_equal(5.0)

	_controller.physics_step(0.016)

	assert_int(_run_inventory.level).append_failure_message("erroneous teaching-wave level-up was not reverted").is_equal(0)
	# The 15 XP credit_xp() spent on the bogus level-up must be refunded
	# BEFORE the cap clamps it -- 5 (leftover) + 15 (refunded) = 20, clamped
	# to 14. A naive implementation that reverts `level` without refunding
	# would leave this at 5, silently discarding 9 XP the player earned.
	assert_float(_run_inventory.xp_current).append_failure_message("XP was not correctly refunded-then-clamped after reverting the erroneous level-up").is_equal(CAP)


func test_forced_first_draft_at_t4_end_grants_level_1_and_keeps_the_held_xp_toward_level_2() -> void:
	_wave_director.set_current_wave_id_for_test("wave_t4")
	for shard in 20:
		_run_inventory.credit_xp(1.0)
		_controller.physics_step(0.016)
	assert_float(_run_inventory.xp_current).is_equal(CAP)
	assert_int(_run_inventory.level).is_equal(0)

	_wave_director.end_wave_for_test("wave_t4", 3, "wave_combat_1")

	assert_bool(_controller.is_draft_showing_for_test()).append_failure_message("the forced first Draft did not open at T4's end").is_true()
	assert_int(_run_inventory.level).append_failure_message("forced first Draft did not grant level 1").is_equal(1)
	assert_float(_run_inventory.xp_current).append_failure_message("held XP at the cap was discarded instead of carried toward level 2").is_equal(CAP)
	assert_float(_run_inventory.xp_required_for_next_level).is_equal(LEVEL_2_COST)

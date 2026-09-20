extends GdUnitTestSuite

## Guaranteed first draft test (MASTER_SDLC.md > Acceptance Test Matrix >
## Encounter Tests, P2.12): "The first Level-Up Draft opens at the end of
## the first Siege in 5 of 5 runs regardless of XP collected."
## MASTER_SDLC.md > "Experience (XP)": "The forced first Level-Up Draft when
## T4 ends grants level 1 at no XP cost, and the XP held counts toward
## level 2." Register > "Teaching wave XP (C-XPCAP)": same rule.
##
## Runs the scenario 5 times with 5 DIFFERENT held-XP amounts at the moment
## T4 ends (0, a small amount, the cap itself, and two values in between),
## proving "regardless of XP collected" rather than only the zero case. Each
## iteration builds a completely fresh RunInventory/UpgradeSystem/
## DraftController so no state leaks between the 5 runs.

const HELD_XP_SCENARIOS: Array[float] = [0.0, 3.0, 7.0, 10.0, 14.0] # 14.0 = the C-XPCAP ceiling itself
const EXPECTED_LEVEL_2_COST: float = 20.0 # Register > "XP & levels": 10 + 5*(1+1)

var _pause: Node
var _clock: Node


func before_test() -> void:
	_pause = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(_pause)
	_clock = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(_clock)


func after_test() -> void:
	PauseAuthority.pop_reason(&"draft")
	PauseAuthority.flush()
	get_tree().paused = false


func test_first_draft_opens_at_t4_end_in_5_of_5_runs_regardless_of_xp() -> void:
	for run_index in HELD_XP_SCENARIOS.size():
		var held_xp: float = HELD_XP_SCENARIOS[run_index]

		var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
		run_inventory.xp_current = held_xp # whatever the teaching-wave cap left standing by T4's end

		var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
		add_child(upgrade_system)

		var wave_director: DraftFakeWaveDirector = auto_free(DraftFakeWaveDirector.new())
		add_child(wave_director)
		wave_director.set_current_wave_id_for_test("wave_t4")

		var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
		add_child(controller)
		controller.set_run_inventory_for_test(run_inventory)
		controller.set_upgrade_system_for_test(upgrade_system)
		controller.set_wave_director_for_test(wave_director)
		controller.set_pause_authority_for_test(_pause)
		controller.set_sim_clock_for_test(_clock)
		controller.skip_lockout_for_test()

		assert_int(run_inventory.level).append_failure_message("run %d premise broken: level was not 0 before T4 ended" % run_index).is_equal(0)

		# The end of the first Siege: WaveDirector fires wave_ended for the
		# LAST teaching wave (wave_t4), regardless of how much XP is held.
		wave_director.end_wave_for_test("wave_t4", 3, "wave_combat_1")

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("run %d (held XP=%s): first Draft did not open at T4's end" % [run_index, held_xp]).is_true()
		assert_int(run_inventory.level).append_failure_message("run %d (held XP=%s): forced first Draft did not grant level 1" % [run_index, held_xp]).is_equal(1)
		assert_float(run_inventory.xp_current).append_failure_message("run %d (held XP=%s): held XP was not kept toward level 2" % [run_index, held_xp]).is_equal(held_xp)
		assert_float(run_inventory.xp_required_for_next_level).append_failure_message("run %d: level-2 cost not recomputed after the forced level" % run_index).is_equal(EXPECTED_LEVEL_2_COST)

		# Resolve it so the pause reason is released before the next iteration reuses _pause.
		controller.confirm_choice_for_test(0)


func test_first_draft_does_not_open_when_an_earlier_teaching_wave_ends() -> void:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var wave_director: DraftFakeWaveDirector = auto_free(DraftFakeWaveDirector.new())
	add_child(wave_director)
	wave_director.set_current_wave_id_for_test("wave_t1")

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_wave_director_for_test(wave_director)
	controller.set_pause_authority_for_test(_pause)
	controller.set_sim_clock_for_test(_clock)

	wave_director.end_wave_for_test("wave_t1", 0, "wave_t2")

	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("a non-final teaching wave (T1) ending must not force a Draft open").is_false()
	assert_int(run_inventory.level).is_equal(0)

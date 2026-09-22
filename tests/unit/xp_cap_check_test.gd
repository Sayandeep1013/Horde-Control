extends GdUnitTestSuite

## XP cap check (MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests,
## P2.12). NEW RULE (Author decision D108, 2026-09-23): "During T1-T4, XP is
## never artificially capped and level-ups fire normally, exactly as during
## a combat wave; a shard burst that crosses a level threshold mid-teaching-
## wave applies the level-up immediately, with no suppression and no
## revert." This REPLACES the rule this suite used to test (XP capped at 14
## during T1-T4, no level-up fires, a forced first Draft grants level 1 at
## T4's end) -- the teaching-wave XP cap (C-XPCAP, formerly
## `EconomyConfiguration.xp_cap_during_teaching_waves`) and the forced first
## Draft are both REMOVED from src/ui/draft_controller.gd; see that file's
## own "CHANGE 2" class-doc section and MASTER_SDLC.md's Review Decision
## Log, D108.
##
## `_wave_director` here is still `DraftFakeWaveDirector`
## (tests/unit/draft_fake_wave_director.gd), set to a teaching wave id via
## `set_current_wave_id_for_test()` exactly as before -- what changed is
## what DraftController now DOES with that: nothing. Setting the current
## wave to "wave_t1".."wave_t4" no longer alters its behaviour at all, which
## is exactly the claim every test below proves.

const LEVEL_1_COST: float = 8.0 # Register > "XP & levels": 5 + 3*(0+1) (Author decision D108, 2026-09-23)
const LEVEL_2_COST: float = 11.0 # 5 + 3*(1+1)

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


func _build(wave_id: String) -> Dictionary:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var wave_director: DraftFakeWaveDirector = auto_free(DraftFakeWaveDirector.new())
	add_child(wave_director)
	wave_director.set_current_wave_id_for_test(wave_id)

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_wave_director_for_test(wave_director)
	controller.set_pause_authority_for_test(_pause)
	controller.set_sim_clock_for_test(_clock)
	controller.skip_lockout_for_test()

	return {"run_inventory": run_inventory, "controller": controller}


## A level-up fires in EVERY teaching wave now, not suppressed by any of
## them -- proves the removal is complete, not just "T1 happens to work."
## Each iteration builds a fresh RunInventory/DraftController so no state
## leaks between waves (matching tests/unit/guaranteed_first_draft_test.gd's
## own established per-scenario pattern).
func test_level_ups_fire_normally_during_all_four_teaching_waves() -> void:
	for wave_id in ["wave_t1", "wave_t2", "wave_t3", "wave_t4"]:
		var h: Dictionary = _build(wave_id)
		var run_inventory: RunInventory = h["run_inventory"]
		var controller: DraftController = h["controller"]

		run_inventory.credit_xp(LEVEL_1_COST)
		controller.physics_step(0.016)

		assert_int(run_inventory.level).append_failure_message(
			"a level-up did not fire during teaching wave %s -- the old suppression may still be active" % wave_id
		).is_equal(1)
		assert_bool(controller.is_draft_showing_for_test()).append_failure_message(
			"the Level-Up Draft did not open during teaching wave %s" % wave_id
		).is_true()

		controller.confirm_choice_for_test(0) # release the pause reason before the next iteration reuses _pause


func test_a_burst_that_crosses_the_level_1_threshold_applies_normally_during_a_teaching_wave() -> void:
	var h: Dictionary = _build("wave_t3")
	var run_inventory: RunInventory = h["run_inventory"]
	var controller: DraftController = h["controller"]

	run_inventory.credit_xp(LEVEL_1_COST + 5.0) # 13 XP: crosses the 8-XP threshold, 5 left over
	assert_int(run_inventory.level).append_failure_message("test premise broken: RunInventory itself did not cross the level-1 threshold").is_equal(1)
	assert_float(run_inventory.xp_current).is_equal_approx(5.0, 0.001)

	controller.physics_step(0.016)

	assert_int(run_inventory.level).append_failure_message(
		"the level-up was reverted during a teaching wave -- the old C-XPCAP revert path may still be active"
	).is_equal(1)
	assert_float(run_inventory.xp_current).append_failure_message(
		"XP was altered during a teaching wave's level-up even though no cap or revert applies any more"
	).is_equal_approx(5.0, 0.001)
	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("the Level-Up Draft did not open for a burst crossing the level-1 threshold mid-teaching-wave").is_true()


## Proves the cap is REMOVED, not merely raised: a burst whose TOTAL XP
## (22) comfortably exceeds the former 14-XP teaching-wave ceiling crosses
## BOTH of its levels in one tick, with the true 3 XP remainder intact.
func test_a_large_burst_exceeding_the_former_14_xp_ceiling_crosses_multiple_levels_during_a_teaching_wave() -> void:
	var h: Dictionary = _build("wave_t4")
	var run_inventory: RunInventory = h["run_inventory"]
	var controller: DraftController = h["controller"]

	run_inventory.credit_xp(LEVEL_1_COST + LEVEL_2_COST + 3.0) # 8 + 11 + 3 = 22 XP
	controller.physics_step(0.016)

	assert_int(run_inventory.level).append_failure_message(
		"a burst exceeding the former 14-XP teaching-wave ceiling (C-XPCAP) did not cross both levels -- the old cap/suppression may still be active"
	).is_equal(2)
	assert_float(run_inventory.xp_current).append_failure_message("the true remainder was not preserved -- something is still clamping XP during a teaching wave").is_equal_approx(3.0, 0.001)

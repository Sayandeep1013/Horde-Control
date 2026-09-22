extends GdUnitTestSuite

## Guaranteed first draft test (MASTER_SDLC.md > Acceptance Test Matrix >
## Encounter Tests, P2.12). NEW RULE (Author decision D108, 2026-09-23):
## "The first Level-Up Draft opens the instant the player's XP first
## reaches the level-1 cost, even during a teaching wave (T1-T4), in 5 of 5
## runs -- level-ups are no longer suppressed or capped during onboarding."
## This REPLACES the rule this suite used to test (the first Draft forced
## open, regardless of XP collected, specifically at T4's end) -- that
## forced-open mechanism (`_on_wave_ended()`, the WaveDirector `wave_ended`
## signal connection, `_grant_forced_level()`) is REMOVED from
## src/ui/draft_controller.gd entirely, not merely retargeted; see that
## file's own "CHANGE 2" class-doc section and MASTER_SDLC.md's Review
## Decision Log, D108.
##
## Runs the scenario across 5 DIFFERENT waves the level-up could land in --
## all four teaching waves plus a combat wave, for comparison -- proving
## "regardless of which wave it happens in," the inverse of the old
## suite's own "regardless of XP collected." Each iteration builds a
## completely fresh RunInventory/UpgradeSystem/DraftController so no state
## leaks between the 5 runs.

const WAVE_ID_SCENARIOS: Array[String] = ["wave_t1", "wave_t2", "wave_t3", "wave_t4", "wave_combat_1"]
const LEVEL_1_COST: float = 8.0 # Register > "XP & levels": 5 + 3*(0+1) (Author decision D108, 2026-09-23)

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

	return {"run_inventory": run_inventory, "controller": controller, "wave_director": wave_director}


func test_first_draft_opens_on_the_players_first_level_up_in_5_of_5_runs_regardless_of_which_wave() -> void:
	for wave_id in WAVE_ID_SCENARIOS:
		var h: Dictionary = _build(wave_id)
		var run_inventory: RunInventory = h["run_inventory"]
		var controller: DraftController = h["controller"]

		assert_int(run_inventory.level).append_failure_message("wave %s premise broken: level was not 0 before the level-up" % wave_id).is_equal(0)

		run_inventory.credit_xp(LEVEL_1_COST)
		controller.physics_step(0.016)

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("wave %s: the first Draft did not open on the player's first level-up" % wave_id).is_true()
		assert_int(run_inventory.level).append_failure_message("wave %s: the level-up did not apply" % wave_id).is_equal(1)

		controller.confirm_choice_for_test(0) # release the pause reason before the next iteration reuses _pause


## Regression, replacing the OLD suite's "a non-final teaching wave ending
## must not force a Draft" case: since nothing listens to `wave_ended` any
## more (the forced-draft mechanism is REMOVED entirely, not merely
## retargeted), ending ANY wave -- teaching or combat -- with no XP
## credited must never, by itself, open a Draft.
func test_ending_a_wave_never_opens_a_draft_by_itself_with_no_xp_credited() -> void:
	for wave_id in WAVE_ID_SCENARIOS:
		var h: Dictionary = _build(wave_id)
		var run_inventory: RunInventory = h["run_inventory"]
		var controller: DraftController = h["controller"]
		var wave_director: DraftFakeWaveDirector = h["wave_director"]

		wave_director.end_wave_for_test(wave_id, 0, "wave_combat_1")

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("wave %s ending, with no XP credited, opened a Draft by itself" % wave_id).is_false()
		assert_int(run_inventory.level).is_equal(0)

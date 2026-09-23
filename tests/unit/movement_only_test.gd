extends GdUnitTestSuite

## Movement-only test (P2.14 named acceptance test, rewritten for D115).
## MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests >
## "Movement-only test": "Using only movement input, an internal tester
## resolves every Level-Up Draft of a prototype run." D115 (no in-run shop)
## removed the Tower Console, so the Register row's own former second half
## ("with the Movement-only controls setting on, completes at least one
## Console purchase; with the setting off, standing beside the Tower for 60
## seconds buys nothing") is gone -- the Movement-only controls setting's
## remaining function is the Hub's Skill Tree screen (docs/18 > "Buying, and
## respec"), covered by tests/unit/skill_tree_screen_test.gd, not this file.
##
## Written as the task brief asks -- "a scripted equivalent using this
## project's existing input-injection test seams" -- against the REAL
## src/ui/draft_controller.gd (P2.12), never a stand-in. Drives
## DraftController's own `_use_test_input` double
## (tests/unit/draft_input_lockout_test.gd's own established pattern) using
## ONLY `move_left` / `move_right` / `move_up` -- never `confirm`, never
## `draft_select_1/2/3`, never `reroll`, never `draft_cycle_left/right` --
## across THREE separate level-ups, so "every Level-Up Draft of a run" is
## exercised more than once, not just the first.
##
## ## What this script cannot cover (named plainly, per the task brief)
## "An internal tester" names a HUMAN play session across a run whose
## level-ups arise from genuine XP gained through real combat -- not
## reproducible by a script. What IS mechanically provable, and is proven
## here, is the RULE: the movement-only cycle-and-hold-to-confirm path
## resolves a Draft with no other input class touched.

const DraftTestHelpers: GDScript = preload("res://tests/unit/draft_test_helpers.gd")

const STEP: float = 1.0 / 60.0


func after_test() -> void:
	# Safety net (pause_clock_test.gd's own precedent): every PauseAuthority
	# instance in this file is fresh, never the real autoload, but a failed
	# assertion mid-draft-resolution must still never leak a stuck pause
	# into the SHARED tree for a suite that runs after this one.
	get_tree().paused = false


# --- Draft half ---------------------------------------------------------------

func _advance_draft(controller: DraftController, ticks: int) -> void:
	for _i in ticks:
		controller.tick_for_test(STEP)


## Resolves exactly one open Draft using ONLY move_left/move_right/move_up.
## Cycles right once (proves cycling works, not merely "confirm index 0"),
## then holds move_up past the 1.0 s hold-to-confirm threshold.
func _resolve_one_draft_movement_only(controller: DraftController) -> void:
	assert_bool(controller.is_draft_showing_for_test()).append_failure_message("test setup: no Draft is open to resolve").is_true()

	# Past the 0.4 s input lockout, touching no input at all.
	_advance_draft(controller, int(ceil(0.4 / STEP)) + 2)
	assert_bool(controller.is_lockout_elapsed_for_test()).is_true()

	# Cycle right once (movement key, not draft_cycle_right).
	controller.set_action_pressed_for_test(&"move_right", true)
	_advance_draft(controller, 1)
	controller.set_action_pressed_for_test(&"move_right", false)
	_advance_draft(controller, 2)
	assert_int(controller.get_highlighted_index_for_test()).is_equal(1)

	# Hold move_up past the 1.0 s confirm threshold.
	controller.set_action_pressed_for_test(&"move_up", true)
	_advance_draft(controller, int(ceil(1.0 / STEP)) + 2)
	controller.set_action_pressed_for_test(&"move_up", false)
	_advance_draft(controller, 1)


func test_every_level_up_draft_in_a_run_resolves_using_only_movement_input() -> void:
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var pause: Node = auto_free(DraftTestHelpers.build_fresh_pause_authority())
	add_child(pause)
	var clock: Node = auto_free(DraftTestHelpers.build_fresh_sim_clock())
	add_child(clock)

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_pause_authority_for_test(pause)
	controller.set_sim_clock_for_test(clock)
	controller.set_test_input_mode_for_test(true)

	# Three separate level-ups -- "every Level-Up Draft of a run", not just
	# the first one.
	for i in 3:
		run_inventory.credit_xp(run_inventory.xp_required_for_next_level + 1.0) # crosses exactly one threshold (RunInventory.credit_xp()'s own while loop)
		controller.physics_step(STEP) # SimLoop step 11 entry point: detects the level-up, opens the Draft

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("Draft #%d never opened" % (i + 1)).is_true()
		var rank_before: int = upgrade_system.get_current_rank(controller.get_current_card_ids_for_test()[1])
		var chosen_id: String = controller.get_current_card_ids_for_test()[1] # index 1, matching the single move_right cycle in _resolve_one_draft_movement_only()

		_resolve_one_draft_movement_only(controller)

		assert_bool(controller.is_draft_showing_for_test()).append_failure_message("Draft #%d did not close after a movement-only confirm" % (i + 1)).is_false()
		assert_int(upgrade_system.get_current_rank(chosen_id)).append_failure_message("movement-only confirm did not apply a rank to '%s' on Draft #%d" % [chosen_id, i + 1]).is_equal(rank_before + 1)

	assert_bool(controller.is_draft_session_active_for_test()).append_failure_message("Draft session stayed active after the last queued Draft closed").is_false()
	assert_bool(pause.has_reason(PauseAuthority.REASON_DRAFT)).append_failure_message("the draft pause reason was never popped").is_false()

extends GdUnitTestSuite

## Determinism test (MASTER_SDLC.md > Acceptance Test Matrix > Technical
## Tests, P2.12): "With the same run seed, a scripted sequence of keyed
## rolls produces identical results in 10 of 10 repetitions."
## MASTER_SDLC.md > Determinism where it matters: "the Level-Up Draft's
## k-th card hashes [run_seed, 'draft', k]." Register > "Keyed RNG": same.
##
## tests/unit/keyed_rng_test.gd already proves KeyedRng itself is
## deterministic and diverges correctly by key -- that is not re-tested
## here. This suite proves DraftController actually ROUTES its own
## `run_seed` export into that primitive, end to end, across a SCRIPTED
## MULTI-ROLL sequence (an initial draft, confirmed, then a second draft
## from a fresh level-up -- not just one single roll), which is exactly the
## shape of test a hardcoded seed root inside DraftController would fail:
## a hardcoded root would still pass a naive "roll once, compare" check
## (KeyedRng's own determinism would make repeated calls with the SAME
## hardcoded root agree with each other) but would make
## `test_a_different_run_seed_changes_at_least_one_offer` fail, since
## changing `run_seed` on the controller would have no effect at all.

const RUN_SEED_A: int = 424242
const RUN_SEED_B: int = 990011
const REPETITIONS: int = 10

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


## Scripted sequence: roll the first draft, confirm it, credit exactly
## enough XP for a second level-up, roll the second draft, confirm it too.
## Returns the two draft's card-id lists concatenated with a separator, so
## a single comparison covers the whole scripted sequence, not just the
## first roll.
func _run_scripted_sequence(seed_value: int) -> Array[String]:
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.run_seed = seed_value
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_pause_authority_for_test(_pause)
	controller.set_sim_clock_for_test(_clock)
	controller.skip_lockout_for_test()

	controller.force_open_for_test(false)
	var first_ids: Array[String] = controller.get_current_card_ids_for_test()
	controller.confirm_choice_for_test(0)

	run_inventory.credit_xp(8.0) # Register > "XP & levels": level 0->1 costs exactly 8 (Author decision D108, 2026-09-23)
	controller.physics_step(0.016)
	var second_ids: Array[String] = controller.get_current_card_ids_for_test()
	controller.confirm_choice_for_test(0)

	var out: Array[String] = first_ids.duplicate()
	out.append("|")
	out.append_array(second_ids)
	return out


func test_same_run_seed_reproduces_identical_offers_10_of_10() -> void:
	var baseline: Array[String] = _run_scripted_sequence(RUN_SEED_A)
	assert_int(baseline.size()).append_failure_message("scripted sequence produced no offers -- test premise broken").is_greater(0)
	for rep in REPETITIONS:
		var repeat: Array[String] = _run_scripted_sequence(RUN_SEED_A)
		assert_array(repeat).append_failure_message(
			"repetition %d of %d diverged from the baseline for the same run seed" % [rep + 1, REPETITIONS]
		).is_equal(baseline)


func test_a_different_run_seed_changes_at_least_one_offer() -> void:
	var baseline: Array[String] = _run_scripted_sequence(RUN_SEED_A)
	var other: Array[String] = _run_scripted_sequence(RUN_SEED_B)
	assert_array(other).append_failure_message(
		"a different run_seed produced byte-identical offers -- the draft roll is not actually keyed off DraftController.run_seed (a hardcoded seed root would produce exactly this symptom)"
	).is_not_equal(baseline)


# --- D117: rarity is a keyed, deterministic roll, same as the card pick ---

## Same scripted sequence as _run_scripted_sequence() above, but reports
## rarity instead of card ids -- proves the rarity roll (a SEPARATE
## KeyedRng purpose key, "draft_rarity") is deterministic per run_seed
## exactly like the card-pick roll already proven above.
func _run_scripted_sequence_rarities(seed_value: int) -> Array[int]:
	var upgrade_system: UpgradeSystem = auto_free(DraftTestHelpers.build_upgrade_system())
	add_child(upgrade_system)
	var run_inventory: RunInventory = DraftTestHelpers.build_run_inventory()

	var controller: DraftController = auto_free(DraftTestHelpers.build_draft_controller())
	add_child(controller)
	controller.run_seed = seed_value
	controller.set_run_inventory_for_test(run_inventory)
	controller.set_upgrade_system_for_test(upgrade_system)
	controller.set_pause_authority_for_test(_pause)
	controller.set_sim_clock_for_test(_clock)
	controller.skip_lockout_for_test()

	controller.force_open_for_test(false)
	var first_rarities: Array[int] = controller.get_current_card_rarities_for_test()
	controller.confirm_choice_for_test(0)

	run_inventory.credit_xp(8.0)
	controller.physics_step(0.016)
	var second_rarities: Array[int] = controller.get_current_card_rarities_for_test()
	controller.confirm_choice_for_test(0)

	var out: Array[int] = first_rarities.duplicate()
	out.append(-1) # separator, never a valid ContractEnums.Rarity value
	out.append_array(second_rarities)
	return out


func test_same_run_seed_reproduces_identical_rarities_10_of_10() -> void:
	var baseline: Array[int] = _run_scripted_sequence_rarities(RUN_SEED_A)
	for rep in REPETITIONS:
		var repeat: Array[int] = _run_scripted_sequence_rarities(RUN_SEED_A)
		assert_array(repeat).append_failure_message(
			"repetition %d of %d's rarity roll diverged from the baseline for the same run seed" % [rep + 1, REPETITIONS]
		).is_equal(baseline)


func test_a_different_run_seed_can_change_the_rarity_roll() -> void:
	var baseline: Array[int] = _run_scripted_sequence_rarities(RUN_SEED_A)
	var other: Array[int] = _run_scripted_sequence_rarities(RUN_SEED_B)
	assert_array(other).append_failure_message(
		"a different run_seed produced byte-identical rarities across two whole drafts -- the rarity roll is not actually keyed off DraftController.run_seed"
	).is_not_equal(baseline)

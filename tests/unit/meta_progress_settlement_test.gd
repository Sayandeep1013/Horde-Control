extends GdUnitTestSuite

## MetaProgress.settle_run() tests (Meta layer core, build brief item 6).
## MASTER_SDLC.md > Provisional Values Register > "Meta: Run-End Settlement
## (prototype)": "1 Core per full minute ... 2 Cores per wave fully cleared
## ... 1 Core per 25 enemies killed (floor) ... 5 Cores for clearing the
## final wave ... then the Prospector node's bonus on the sum, rounded down.
## Settled once per run id."

var _dir: String


func before_test() -> void:
	_dir = "user://__meta_test_settlement_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _grant_cores(amount: int) -> void:
	MetaProgress.settle_run({
		"run_id": "grant_%d_%d" % [amount, randi()],
		"sim_time_seconds": float(amount) * 60.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false,
	})


# --- Formula -------------------------------------------------------------------

func test_settlement_formula_time_waves_and_kills() -> void:
	# 4 minutes -> 4; 3 waves cleared -> 6; 60 kills -> floor(60/25)=2; no victory.
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_1", "sim_time_seconds": 240.0,
		"waves_cleared": 3, "kills": 60, "victory": false, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("expected 4 (time) + 6 (waves) + 2 (kills) = 12").is_equal(12)
	assert_int(MetaProgress.get_cores()).is_equal(12)


func test_victory_adds_the_victory_bonus() -> void:
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_victory", "sim_time_seconds": 0.0,
		"waves_cleared": 0, "kills": 0, "victory": true, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("Register v1.0 Meta Progression: 10 Cores for a victory").is_equal(10)


func test_boss_bounties_are_paid_per_boss_killed() -> void:
	# D255: Warchief 8 + King 20, no other lines.
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_bosses", "sim_time_seconds": 0.0,
		"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
		"boss_kills": {"warchief": 1, "king": 1},
	})
	assert_int(breakdown["total_cores"]).append_failure_message("Warchief 8 + King 20").is_equal(28)


func test_kill_count_floors_rather_than_rounds() -> void:
	# 49 kills -> floor(49/25) = 1, not 2.
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_floor", "sim_time_seconds": 0.0,
		"waves_cleared": 0, "kills": 49, "victory": false, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).is_equal(1)


## FALSIFICATION (named in the report): temporarily changing the kill term
## from `floor(kills / 25)` to `round(kills / 25)` in meta_progress.gd made
## this test fail (2 instead of 1 for 49 kills). Reverted after confirming.
func test_abandoned_settles_as_a_failure_with_the_same_formula_no_victory_bonus() -> void:
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_abandon", "sim_time_seconds": 60.0,
		"waves_cleared": 1, "kills": 0, "victory": false, "abandoned": true,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("abandon pays the same failure formula: 1 (time) + 2 (wave) = 3, no final-wave bonus").is_equal(3)
	assert_bool(breakdown["abandoned"]).is_true()
	assert_bool(breakdown["victory"]).is_false()


# --- Prospector bonus (Register > "Meta: Skill Tree effects": "+15%/rank") ---

func test_prospector_bonus_applies_once_to_the_whole_subtotal() -> void:
	_grant_cores(60) # scavenger (8) + scholar (8) + prospector rank 1 (28)
	MetaProgress.buy("scavenger")
	MetaProgress.buy("scholar")
	MetaProgress.buy("prospector") # rank 1: +15%

	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "prospector_1", "sim_time_seconds": 600.0, # 10 minutes -> 10 Cores subtotal
		"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("floor(10 * 1.15) = 11").is_equal(11)


func test_prospector_rank_2_stacks_to_thirty_percent() -> void:
	_grant_cores(120) # scavenger (8) + scholar (8) + prospector ranks 1 and 2 (28 + 42)
	MetaProgress.buy("scavenger")
	MetaProgress.buy("scholar")
	MetaProgress.buy("prospector")
	MetaProgress.buy("prospector") # rank 2: +30%

	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "prospector_2", "sim_time_seconds": 600.0,
		"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("floor(10 * 1.30) = 13").is_equal(13)


# --- Idempotence by run id ------------------------------------------------------

func test_settling_the_same_run_id_twice_pays_once() -> void:
	var run_summary: Dictionary = {
		"run_id": "idempotent_1", "sim_time_seconds": 300.0,
		"waves_cleared": 1, "kills": 0, "victory": false, "abandoned": false,
	}
	var first: Dictionary = MetaProgress.settle_run(run_summary)
	var cores_after_first: int = MetaProgress.get_cores()
	assert_int(first["total_cores"]).is_greater(0)

	var second: Dictionary = MetaProgress.settle_run(run_summary)

	assert_int(MetaProgress.get_cores()).append_failure_message("a repeat settle_run() for the same run id must not pay again").is_equal(cores_after_first)
	assert_bool(second["already_settled"]).is_true()


## The scenario named directly in the build brief: "same-tick double death
## settles once." Modelled here as the two systems (player death handler,
## Tower death handler) each independently calling settle_run() with the
## SAME run id in the same synchronous call stack -- exactly what
## RunFlowController's own `_state == State.ENDED` guard is ALSO defending
## against one layer up (see meta_run_flow_test.gd for that layer); this
## test proves MetaProgress itself is safe even if that guard were ever
## bypassed.
func test_same_tick_double_death_with_the_same_run_id_settles_once() -> void:
	var run_summary: Dictionary = {
		"run_id": "double_death_1", "sim_time_seconds": 120.0,
		"waves_cleared": 1, "kills": 10, "victory": false, "abandoned": false,
	}
	MetaProgress.settle_run(run_summary) # "player died" handler
	var cores_after_first_call: int = MetaProgress.get_cores()
	MetaProgress.settle_run(run_summary) # "Tower destroyed" handler, same tick

	assert_int(MetaProgress.get_cores()).is_equal(cores_after_first_call)


# --- Records / new-best flags --------------------------------------------------

func test_new_best_flags_are_true_on_the_first_run_and_false_on_a_worse_one() -> void:
	var first: Dictionary = MetaProgress.settle_run({
		"run_id": "records_1", "sim_time_seconds": 300.0,
		"waves_cleared": 3, "kills": 50, "victory": false, "abandoned": false,
	})
	assert_bool(first["new_best_waves"]).is_true()
	assert_bool(first["new_best_kills"]).is_true()

	var second: Dictionary = MetaProgress.settle_run({
		"run_id": "records_2", "sim_time_seconds": 60.0,
		"waves_cleared": 1, "kills": 5, "victory": false, "abandoned": false,
	})
	assert_bool(second["new_best_waves"]).append_failure_message("a worse run must not claim a new best").is_false()
	assert_bool(second["new_best_kills"]).is_false()

	var records: Dictionary = MetaProgress.get_records()
	assert_int(records["best_waves_cleared"]).is_equal(3)
	assert_int(records["best_kills"]).is_equal(50)


# --- v1.0 settlement (D253): elites, difficulty multiplier, unlock chain ------------

func test_elite_kills_pay_one_core_each() -> void:
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "elites_1", "sim_time_seconds": 0.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false, "elite_kills": 7,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("Register: 1 Core per elite killed").is_equal(7)


## FALSIFICATION (named in the report): removing the `cores_multiplier` step in
## settle_run() made the Veteran case below pay 10 instead of 14.
func test_the_difficulty_cores_multiplier_scales_the_whole_total() -> void:
	var soldier: Dictionary = MetaProgress.settle_run({
		"run_id": "mult_soldier", "sim_time_seconds": 600.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false, "difficulty_id": "soldier",
	})
	var veteran: Dictionary = MetaProgress.settle_run({
		"run_id": "mult_veteran", "sim_time_seconds": 600.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false, "difficulty_id": "veteran",
	})
	var recruit: Dictionary = MetaProgress.settle_run({
		"run_id": "mult_recruit", "sim_time_seconds": 600.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false, "difficulty_id": "recruit",
	})
	assert_int(soldier["total_cores"]).is_equal(10)
	assert_int(veteran["total_cores"]).append_failure_message("10 x 1.4 (Veteran Cores multiplier)").is_equal(14)
	assert_int(recruit["total_cores"]).append_failure_message("floor(10 x 0.75) (Recruit Cores multiplier)").is_equal(7)


func test_the_multiplier_applies_after_the_prospector_and_founder_bonuses() -> void:
	MetaProgress.set_achievement_unlocked_for_test("founder")  # +5%
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "mult_after_bonus", "sim_time_seconds": 600.0, "waves_cleared": 0, "kills": 0,
		"victory": false, "abandoned": false, "difficulty_id": "warlord",
	})
	# subtotal 10 -> floor(10 x 1.05) = 10 -> floor(10 x 1.85) = 18
	assert_int(breakdown["total_cores"]).is_equal(18)


## The unlock chain: a Soldier win opens Veteran, a Veteran win opens Warlord,
## any win opens Endless, and a defeat opens nothing.
func test_the_difficulty_unlock_chain_soldier_veteran_warlord() -> void:
	assert_bool(MetaProgress.is_difficulty_unlocked("soldier")).is_true()
	assert_bool(MetaProgress.is_difficulty_unlocked("recruit")).is_true()
	assert_bool(MetaProgress.is_difficulty_unlocked("veteran")).is_false()
	assert_bool(MetaProgress.is_difficulty_unlocked("warlord")).is_false()
	assert_bool(MetaProgress.is_endless_unlocked()).is_false()

	var loss: Dictionary = MetaProgress.settle_run({"run_id": "chain_loss", "sim_time_seconds": 60.0, "difficulty_id": "soldier", "victory": false})
	assert_bool(MetaProgress.is_difficulty_unlocked("veteran")).append_failure_message("a defeat must not unlock anything").is_false()
	assert_str(String(loss["unlocked_difficulty"])).is_empty()

	var soldier_win: Dictionary = MetaProgress.settle_run({"run_id": "chain_1", "sim_time_seconds": 60.0, "difficulty_id": "soldier", "victory": true})
	assert_bool(MetaProgress.is_difficulty_unlocked("veteran")).is_true()
	assert_bool(MetaProgress.is_difficulty_unlocked("warlord")).append_failure_message("Warlord needs a VETERAN win, not a Soldier one").is_false()
	assert_bool(MetaProgress.is_endless_unlocked()).is_true()
	assert_str(String(soldier_win["unlocked_difficulty"])).is_equal("veteran")
	assert_bool(bool(soldier_win["unlocked_endless"])).is_true()

	var veteran_win: Dictionary = MetaProgress.settle_run({"run_id": "chain_2", "sim_time_seconds": 60.0, "difficulty_id": "veteran", "victory": true})
	assert_bool(MetaProgress.is_difficulty_unlocked("warlord")).is_true()
	assert_str(String(veteran_win["unlocked_difficulty"])).is_equal("warlord")
	assert_bool(bool(veteran_win["unlocked_endless"])).append_failure_message("Endless unlocks once, on the first win").is_false()
	assert_int(MetaProgress.get_difficulty_victories("soldier")).is_equal(1)
	assert_int(MetaProgress.get_difficulty_victories("veteran")).is_equal(1)


func test_endless_records_the_best_wave_and_flags_a_new_best() -> void:
	var first: Dictionary = MetaProgress.settle_run({"run_id": "endless_1", "sim_time_seconds": 60.0, "endless": true, "wave_reached": 18})
	assert_bool(bool(first["new_best_endless_wave"])).is_true()
	assert_int(MetaProgress.get_best_endless_wave()).is_equal(18)
	var worse: Dictionary = MetaProgress.settle_run({"run_id": "endless_2", "sim_time_seconds": 60.0, "endless": true, "wave_reached": 12})
	assert_bool(bool(worse["new_best_endless_wave"])).is_false()
	assert_int(MetaProgress.get_best_endless_wave()).is_equal(18)
	var normal: Dictionary = MetaProgress.settle_run({"run_id": "endless_3", "sim_time_seconds": 60.0, "endless": false, "wave_reached": 30})
	assert_bool(bool(normal["new_best_endless_wave"])).append_failure_message("only an Endless run records an Endless best").is_false()
	assert_int(MetaProgress.get_best_endless_wave()).is_equal(18)


func test_runs_played_and_elite_and_boss_counters_accumulate() -> void:
	MetaProgress.settle_run({"run_id": "count_1", "sim_time_seconds": 60.0, "elite_kills": 3, "repair_total": 40, "boss_kills": {"warchief": 1, "king": 0}})
	MetaProgress.settle_run({"run_id": "count_2", "sim_time_seconds": 60.0, "elite_kills": 4, "repair_total": 60, "boss_kills": {"warchief": 0, "king": 1}})
	assert_int(MetaProgress.get_runs_played()).is_equal(2)
	assert_int(MetaProgress.get_lifetime_elite_kills()).is_equal(7)
	assert_int(MetaProgress.get_lifetime_repair()).is_equal(100)
	assert_int(MetaProgress.get_lifetime_boss_kills("warchief")).is_equal(1)
	assert_int(MetaProgress.get_lifetime_boss_kills("king")).is_equal(1)

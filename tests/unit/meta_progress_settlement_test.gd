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


func test_victory_adds_the_final_wave_bonus() -> void:
	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "formula_victory", "sim_time_seconds": 0.0,
		"waves_cleared": 0, "kills": 0, "victory": true, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("Register: '5 Cores for clearing the final wave'").is_equal(5)


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
	_grant_cores(30) # afford Prospector's prerequisites + itself
	MetaProgress.buy("scholar")
	MetaProgress.buy("prospector") # rank 1: +15%

	var breakdown: Dictionary = MetaProgress.settle_run({
		"run_id": "prospector_1", "sim_time_seconds": 600.0, # 10 minutes -> 10 Cores subtotal
		"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
	})
	assert_int(breakdown["total_cores"]).append_failure_message("floor(10 * 1.15) = 11").is_equal(11)


func test_prospector_rank_2_stacks_to_thirty_percent() -> void:
	_grant_cores(60)
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

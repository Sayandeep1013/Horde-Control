extends GdUnitTestSuite

## `_back_requested_fired` (not a local var): this GDScript build's lambdas
## capture a LOCAL variable by VALUE, not by reference, so `var flag = false;
## signal.connect(func(): flag = true)` never observes the mutation from the
## outside (confirmed by an isolated probe during this session) -- an
## INSTANCE field, mutated through the lambda's implicit `self`, is what
## actually propagates.
##
## Records panel tests (docs/18_Permanent_Skill_Tree.md section 5: "best
## wave reached, longest time survived, most kills in a run, total runs,
## total victories and lifetime Cores earned"). Read-only -- every test
## redirects MetaProgress to a throwaway directory first (hard constraint).

var _dir: String
var _back_requested_fired: bool = false


func before_test() -> void:
	_dir = "user://__records_panel_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func test_records_show_the_real_profile_values() -> void:
	MetaProgress.settle_run({
		"run_id": "records_1", "sim_time_seconds": 245.0, "waves_cleared": 4,
		"kills": 130, "victory": false, "abandoned": false,
	})
	MetaProgress.settle_run({
		"run_id": "records_2", "sim_time_seconds": 500.0, "waves_cleared": 8,
		"kills": 300, "victory": true, "abandoned": false,
	})

	var panel: RecordsPanel = auto_free(RecordsPanel.new())
	add_child(panel)
	panel.set_active(true)

	var records: Dictionary = MetaProgress.get_records()
	assert_str(panel.get_row_value_label_for_test("best_wave").text).is_equal(str(int(records["best_waves_cleared"])))
	assert_str(panel.get_row_value_label_for_test("most_kills").text).is_equal(str(int(records["best_kills"])))
	assert_str(panel.get_row_value_label_for_test("runs").text).is_equal("2")
	assert_str(panel.get_row_value_label_for_test("victories").text).is_equal("1")
	assert_str(panel.get_row_value_label_for_test("lifetime_cores").text).is_equal(str(MetaProgress.get_lifetime_cores()))


func test_back_button_emits_back_requested() -> void:
	_back_requested_fired = false
	var panel: RecordsPanel = auto_free(RecordsPanel.new())
	add_child(panel)
	panel.set_active(true)
	panel.back_requested.connect(func() -> void: _back_requested_fired = true)
	panel.get_back_button_for_test().pressed.emit()
	assert_bool(_back_requested_fired).is_true()

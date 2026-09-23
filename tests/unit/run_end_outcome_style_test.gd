extends GdUnitTestSuite

## Run-end screen restyle tests (Hub/Skill Tree screen session, build brief
## item 4): "outcome header (Victory / Defeated / Tower Fallen / Abandoned)"
## and the settlement card's structure (rows + NEW BEST ribbons built,
## Continue kept as the primary/first choice). Existing run-end behaviours
## (show_summary()'s cause/wave/scrap/time fields, the settlement box's own
## node identity) are untouched -- see tests/unit/meta_run_flow_settlement_test.gd
## for the full RunFlowController-driven path this screen sits behind.

## Not a local var in the test function that uses it: this GDScript build's
## lambdas capture a LOCAL variable by VALUE, not by reference (confirmed by
## an isolated probe during this session), so mutating a captured local
## never propagates back out. An instance field, mutated through the
## lambda's implicit `self`, does.
var _continue_requested_fired: bool = false


func _make_screen() -> RunEndScreen:
	var screen: RunEndScreen = auto_free(RunEndScreen.new())
	add_child(screen)
	return screen


func test_victory_summary_sets_the_victory_outcome_title() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.show_summary({"outcome_title": tr("RUN_END_OUTCOME_VICTORY"), "cause_text": "", "wave_reached": 8, "wave_total": 8, "scrap_held": 40, "time_survived_seconds": 500.0})
	assert_str(screen.get_title_label_for_test().text).is_equal(tr("RUN_END_OUTCOME_VICTORY"))


func test_tower_fallen_summary_sets_the_tower_fallen_outcome_title() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.show_summary({"outcome_title": tr("RUN_END_OUTCOME_TOWER_FALLEN"), "cause_text": tr("RUN_END_CAUSE_TOWER"), "wave_reached": 3, "wave_total": 8, "scrap_held": 10, "time_survived_seconds": 90.0})
	assert_str(screen.get_title_label_for_test().text).is_equal(tr("RUN_END_OUTCOME_TOWER_FALLEN"))


func test_abandoned_summary_sets_the_abandoned_outcome_title() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.show_summary({"outcome_title": tr("RUN_END_OUTCOME_ABANDONED"), "cause_text": tr("RUN_END_CAUSE_ABANDONED"), "wave_reached": 2, "wave_total": 8, "scrap_held": 0, "time_survived_seconds": 45.0})
	assert_str(screen.get_title_label_for_test().text).is_equal(tr("RUN_END_OUTCOME_ABANDONED"))


func test_missing_outcome_title_falls_back_to_the_generic_title() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.show_summary({"cause_text": "", "wave_reached": 8, "wave_total": 8, "scrap_held": 0, "time_survived_seconds": 1.0})
	assert_str(screen.get_title_label_for_test().text).is_equal(tr("RUN_END_TITLE"))


func test_settlement_builds_one_row_per_line_and_a_total_label() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({
		"lines": [{"label": "Time survived (4 min)", "amount": 4}, {"label": "Waves cleared (3)", "amount": 6}],
		"total_cores": 10, "new_best_waves": false, "new_best_kills": false, "new_best_survival_seconds": false,
	})
	var box: VBoxContainer = screen.get_settlement_box_for_test()
	assert_bool(box.visible).is_true()
	# 2 line rows + 1 total label (no ribbons) = 3 children.
	assert_int(box.get_child_count()).is_equal(3)
	assert_object(box.get_node_or_null("SettlementTotal")).append_failure_message("the total label must keep its established node name").is_not_null()


func test_new_best_flags_add_a_ribbon_per_flag() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({
		"lines": [{"label": "Waves cleared (8)", "amount": 16}],
		"total_cores": 16, "new_best_waves": true, "new_best_kills": true, "new_best_survival_seconds": false,
	})
	var box: VBoxContainer = screen.get_settlement_box_for_test()
	var ribbon_count: int = 0
	for child in box.get_children():
		# Godot enforces unique SIBLING names -- the second "NewBestRibbon"
		# child is silently renamed "NewBestRibbon2" on add_child(), so
		# counting by exact name would undercount. theme_type_variation
		# (UiTheme.RIBBON) is what actually identifies a ribbon.
		if child is PanelContainer and (child as PanelContainer).theme_type_variation == UiTheme.RIBBON:
			ribbon_count += 1
	assert_int(ribbon_count).append_failure_message("two NEW BEST flags were set -- exactly two ribbons must be built").is_equal(2)


func test_empty_lines_hides_the_settlement_box() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({"lines": [], "total_cores": 0})
	assert_bool(screen.get_settlement_box_for_test().visible).is_false()


# --- Settlement that failed to save (blind review of the meta layer, finding #6) -

## FALSIFICATION (named in the report): temporarily removing the
## `if bool(breakdown.get("saved", true))` branch in `set_settlement()`
## (always calling `_animate_settlement()`, the pre-fix behaviour) made this
## test fail -- the total label started as "Cores earned: 0" (about to
## count up to a real number) instead of the not-saved message. Reverted
## after confirming the failure.
func test_settlement_not_saved_shows_the_not_saved_message_instead_of_a_total() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({
		"lines": [{"label": "Time survived (4 min)", "amount": 4}],
		"total_cores": 4, "saved": false,
		"new_best_waves": false, "new_best_kills": false, "new_best_survival_seconds": false,
	})
	var box: VBoxContainer = screen.get_settlement_box_for_test()
	assert_bool(box.visible).append_failure_message("the earned-lines breakdown must still show even when the save failed").is_true()
	var total_label: Label = box.get_node("SettlementTotal") as Label
	assert_str(total_label.text).append_failure_message("a settlement that could not be saved must never claim a Cores total").is_equal(tr("RUN_END_NOT_SAVED"))


func test_settlement_saved_still_shows_the_normal_total_prefix() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({
		"lines": [{"label": "Time survived (4 min)", "amount": 4}],
		"total_cores": 4, "saved": true,
		"new_best_waves": false, "new_best_kills": false, "new_best_survival_seconds": false,
	})
	var box: VBoxContainer = screen.get_settlement_box_for_test()
	var total_label: Label = box.get_node("SettlementTotal") as Label
	assert_str(total_label.text).append_failure_message("a normally-saved settlement's total must start as the ordinary 'Cores earned: 0' before the count-up tween runs").is_equal("%s: 0" % tr("RUN_END_SETTLEMENT_TOTAL"))


func test_settlement_with_no_saved_key_defaults_to_the_normal_saved_display() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.set_settlement({
		"lines": [{"label": "Waves cleared (3)", "amount": 6}],
		"total_cores": 6, "new_best_waves": false, "new_best_kills": false, "new_best_survival_seconds": false,
	}) # no "saved" key at all -- backward compatible with any older caller
	var box: VBoxContainer = screen.get_settlement_box_for_test()
	var total_label: Label = box.get_node("SettlementTotal") as Label
	assert_str(total_label.text).append_failure_message("a breakdown with no 'saved' key must default to the normal display, not the not-saved message").is_equal("%s: 0" % tr("RUN_END_SETTLEMENT_TOTAL"))


func test_continue_is_the_first_and_default_highlighted_choice() -> void:
	var screen: RunEndScreen = _make_screen()
	screen.show_summary({"cause_text": "", "wave_reached": 8, "wave_total": 8, "scrap_held": 0, "time_survived_seconds": 1.0})
	var bar: PausedChoiceBar = screen.get_bar_for_test()
	assert_int(bar.get_highlighted_index()).is_equal(RunEndScreen.OPTION_CONTINUE)
	_continue_requested_fired = false
	screen.continue_requested.connect(func() -> void: _continue_requested_fired = true)
	bar.confirm_highlighted_for_test()
	assert_bool(_continue_requested_fired).append_failure_message("Continue must be OPTION_CONTINUE (index 0), the primary/default action").is_true()

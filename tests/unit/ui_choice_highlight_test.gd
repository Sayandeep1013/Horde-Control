extends GdUnitTestSuite

## UI pass regression (phases/UI_PASS/FAILURE_POINTS.md, UP-06). The paused
## menus' shape cue for the highlighted option must have a POSITION: it sits
## under the highlighted option and moves when the highlight moves. Its
## first version stretched under the whole row and never moved, so it
## carried no information, and nothing but a screenshot could see that.
## This asserts the geometry `ChoiceHighlightRow._draw()` actually fills.


func _build() -> Dictionary:
	var column: VBoxContainer = auto_free(VBoxContainer.new()) as VBoxContainer
	column.custom_minimum_size = Vector2(800, 0)
	add_child(column)
	var bar := PausedChoiceBar.new()
	column.add_child(bar)
	var labels: Array[String] = ["Resume", "Settings"]
	bar.set_options(labels)
	var row := ChoiceHighlightRow.new()
	column.add_child(row)
	row.configure(bar)
	return {"bar": bar, "row": row}


func test_underline_sits_under_the_highlighted_option_and_moves_with_it() -> void:
	var built: Dictionary = _build()
	var bar: PausedChoiceBar = built["bar"]
	var row: ChoiceHighlightRow = built["row"]
	await get_tree().process_frame
	await get_tree().process_frame

	var first: Rect2 = row.get_underline_rect()
	var first_option: Control = bar.get_child(0) as Control
	assert_float(first.size.x).append_failure_message("underline has no width").is_greater(0.0)
	assert_float(first.size.x).append_failure_message("underline is not the width of the option it marks").is_equal_approx(first_option.size.x, 1.0)
	assert_float(first.size.x).append_failure_message("underline spans the whole row, so it cannot indicate one option").is_less(row.size.x * 0.75)

	bar.highlighted_changed.emit(1)
	var second: Rect2 = row.get_underline_rect()
	var second_option: Control = bar.get_child(1) as Control
	assert_float(second.position.x).append_failure_message("underline did not move when the highlight moved").is_greater(first.position.x + 1.0)
	assert_float(second.position.x).is_equal_approx(second_option.global_position.x - row.global_position.x, 1.0)

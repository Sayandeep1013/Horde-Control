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


## UI pass round 2 (LEDGER UR-12). `get_underline_rect()` used to map only
## the option's ORIGIN through the row-relative transform and pair it with
## the option's raw, untransformed `size.x` for width. That happens to
## still land on the right answer while row and the option share exactly
## one common scaled ancestor with nothing else scaled in between (the
## menu card's own open tween: verified directly, see the round 2 package
## report) -- the scale factor cancels out of the position math and then
## applies uniformly to the whole drawn rect at render time regardless.
## It stops landing on the right answer the moment row's own effective
## scale and the option's own effective scale DIFFER, which is exactly
## what "map both ends through the same transform" fixes: this asserts the
## underline's true RENDERED width against the option's true RENDERED
## width (both computed by mapping local points through each control's own
## global transform), under a scale that is NOT shared identically by the
## two branches.
func test_underline_rendered_width_matches_option_under_non_identity_relative_scale() -> void:
	var root: Control = auto_free(Control.new()) as Control
	add_child(root)

	var bar_wrap: Control = auto_free(Control.new()) as Control
	root.add_child(bar_wrap)
	var bar := PausedChoiceBar.new()
	bar_wrap.add_child(bar)
	var labels: Array[String] = ["Resume", "Settings"]
	bar.set_options(labels)

	var row_wrap: Control = auto_free(Control.new()) as Control
	root.add_child(row_wrap)
	var row := ChoiceHighlightRow.new()
	row_wrap.add_child(row)
	row.configure(bar)

	await get_tree().process_frame
	await get_tree().process_frame

	# The option's branch is scaled 1.25x; row's own branch is left at 1.0x
	# -- a relative scale between the two that a single shared "card" scale
	# never produces, but the geometry math must still hold under it.
	bar_wrap.scale = Vector2(1.25, 1.25)
	row_wrap.scale = Vector2.ONE

	await get_tree().process_frame
	await get_tree().process_frame

	var option: Control = bar.get_child(0) as Control
	var rect: Rect2 = row.get_underline_rect()

	var row_gt: Transform2D = row.get_global_transform()
	var underline_rendered_width: float = (row_gt * (rect.position + Vector2(rect.size.x, 0.0))).x - (row_gt * rect.position).x

	var option_gt: Transform2D = option.get_global_transform()
	var option_rendered_width: float = (option_gt * Vector2(option.size.x, 0.0)).x - (option_gt * Vector2.ZERO).x

	assert_float(underline_rendered_width).append_failure_message(
		"underline's true rendered width (%.3f) does not match the option's true rendered width (%.3f) under a non-identity relative scale" % [underline_rendered_width, option_rendered_width]
	).is_equal_approx(option_rendered_width, 1.0)

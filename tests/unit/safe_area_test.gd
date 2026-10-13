extends GdUnitTestSuite

## Safe-area support (D370, phone feedback 2026-10-13): the one helper that turns the system
## safe area (window px) into logical canvas px, and the `fit()` / `watch()` hosts use.
## The window's content scale is pinned per test so the maths does not depend on the runner's window.

var _scale_before: float = 1.0


func before_test() -> void:
	_scale_before = get_window().content_scale_factor
	SafeArea.set_inset_override_for_test(null)
	TouchUi.set_override_for_test(-1)


func after_test() -> void:
	SafeArea.set_inset_override_for_test(null)
	TouchUi.set_override_for_test(-1)
	get_window().content_scale_factor = _scale_before


func test_desktop_without_an_inset_has_zero_margins() -> void:
	TouchUi.set_override_for_test(0)
	assert_vector(Vector2(SafeArea.margins(get_window()).x, SafeArea.margins(get_window()).w)).is_equal(Vector2.ZERO)
	assert_bool(SafeArea.is_active()).is_false()


func test_a_phone_keeps_a_minimum_margin_even_with_no_system_inset() -> void:
	TouchUi.set_override_for_test(1)
	var m: Vector4 = SafeArea.margins(get_window())
	for side: float in [m.x, m.y, m.z, m.w]:
		assert_float(side).is_equal_approx(SafeArea.MIN_MARGIN_PX, 0.001)


func test_an_inset_in_window_px_converts_to_logical_px_through_the_final_transform() -> void:
	TouchUi.set_override_for_test(1)
	SafeArea.set_inset_override_for_test(Vector4(110.0, 0.0, 0.0, 40.0))
	var window: Window = get_window()
	var k: float = SafeArea.logical_per_px(window)
	var m: Vector4 = SafeArea.margins(window)
	assert_float(m.x).is_equal_approx(maxf(110.0 * k, SafeArea.MIN_MARGIN_PX), 0.01)
	assert_float(m.w).is_equal_approx(maxf(40.0 * k, SafeArea.MIN_MARGIN_PX), 0.01)
	assert_float(m.y).is_equal_approx(SafeArea.MIN_MARGIN_PX, 0.01) # the top has no inset: only the minimum


func test_the_safe_rect_is_the_canvas_minus_the_margins() -> void:
	TouchUi.set_override_for_test(1)
	var window: Window = get_window()
	# a right inset of a tenth of the window, so the maths holds in the 64 px headless window too
	SafeArea.set_inset_override_for_test(Vector4(0.0, 0.0, float(window.size.x) * 0.1, 0.0))
	var canvas: Vector2 = SafeArea.canvas_size(window)
	var m: Vector4 = SafeArea.margins(window)
	var rect: Rect2 = SafeArea.rect(window)
	assert_float(rect.position.x).is_equal_approx(m.x, 0.01)
	assert_float(rect.end.x).is_equal_approx(canvas.x - m.z, 0.01)
	assert_float(rect.size.y).is_equal_approx(canvas.y - m.y - m.w, 0.01)


func test_a_larger_content_scale_makes_the_same_window_inset_smaller_in_logical_px() -> void:
	TouchUi.set_override_for_test(1)
	SafeArea.set_inset_override_for_test(Vector4(400.0, 400.0, 400.0, 400.0)) # well over the minimum margin
	var window: Window = get_window()
	window.content_scale_factor = 1.0
	await get_tree().process_frame # the window's final transform follows the factor on the next frame
	var at_one: float = SafeArea.margins(window).x
	window.content_scale_factor = 2.0
	await get_tree().process_frame
	var at_two: float = SafeArea.margins(window).x
	assert_float(at_two).is_equal_approx(at_one * 0.5, at_one * 0.02)


func test_fit_pins_a_full_rect_control_to_the_margins_and_follows_a_change() -> void:
	TouchUi.set_override_for_test(1)
	SafeArea.set_inset_override_for_test(Vector4(300.0, 0.0, 0.0, 0.0))
	var control := Control.new()
	add_child(control)
	auto_free(control)
	SafeArea.fit(control, Vector4(0.0, 10.0, 0.0, 0.0))
	var m: Vector4 = SafeArea.margins(get_window())
	assert_float(control.offset_left).is_equal_approx(m.x, 0.01)
	assert_float(control.offset_top).is_equal_approx(m.y + 10.0, 0.01)
	assert_float(control.offset_right).is_equal_approx(-m.z, 0.01)
	assert_float(control.offset_bottom).is_equal_approx(-m.w, 0.01)
	assert_float(control.anchor_right).is_equal(1.0)


func test_watch_reports_the_margins_at_once() -> void:
	TouchUi.set_override_for_test(1)
	var holder := Node.new()
	add_child(holder)
	auto_free(holder)
	var seen: Array = []
	SafeArea.watch(holder, func(m: Vector4) -> void: seen.append(m))
	assert_int(seen.size()).is_greater_equal(1)
	assert_float((seen[0] as Vector4).x).is_equal_approx(SafeArea.MIN_MARGIN_PX, 0.001)

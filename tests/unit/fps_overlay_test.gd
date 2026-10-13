extends GdUnitTestSuite

## PT-PHONE (D399): the Show FPS plate. Reads frame ms (smoothed) and the worst frame of the
## last second, enemies alive during a run, sits below the HUD's Scrap / kills panel, and lives
## under the scene-tree root so it survives title -> hub -> run.


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.apply()
	var overlay: Node = get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)
	if overlay != null:
		overlay.queue_free()


func _overlay() -> FpsOverlay:
	var overlay := FpsOverlay.new()
	add_child(overlay)
	auto_free(overlay)
	return overlay


func test_the_text_names_fps_frame_ms_worst_frame_and_enemies() -> void:
	assert_str(FpsOverlay.format_lines(60, 16.7, 24.4, 180)).is_equal("60 FPS   16.7 ms\nworst 24 ms   180 alive")
	assert_str(FpsOverlay.format_lines(31, 32.3, 80.0, -1)).is_equal("31 FPS   32.3 ms\nworst 80 ms") # no enemies outside a run


func test_frame_times_are_averaged_and_the_worst_is_kept_for_a_second() -> void:
	var overlay: FpsOverlay = _overlay()
	for i in 10:
		overlay.record_frame_ms(10.0)
	overlay.record_frame_ms(50.0) # one stutter
	overlay._refresh()
	assert_str(overlay.get_label_for_test().text).contains("worst 50 ms")
	for window in 3: # three more clean quarter seconds: the stutter is still inside the last second
		for i in 10:
			overlay.record_frame_ms(10.0)
		overlay._refresh()
	assert_str(overlay.get_label_for_test().text).contains("worst 50 ms")
	for i in 10:
		overlay.record_frame_ms(10.0)
	overlay._refresh() # the fifth window pushes it out
	assert_str(overlay.get_label_for_test().text).contains("worst 10 ms")
	assert_str(overlay.get_label_for_test().text).contains("100 FPS")


func test_it_uses_the_hud_text_size_not_the_tiny_tag_size() -> void:
	var overlay: FpsOverlay = _overlay()
	assert_object(overlay.get_label_for_test().theme_type_variation).is_equal(UiTheme.HUD_VALUE)
	assert_float(float(overlay.get_label_for_test().get_theme_font_size("font_size"))).is_greater_equal(float(UiPalette.FONT_SIZE_BODY))


func test_with_a_hud_it_sits_below_the_scrap_panel_and_never_on_it() -> void:
	var overlay: FpsOverlay = _overlay()
	var hud := Control.new()
	hud.add_to_group(&"hud")
	add_child(hud)
	auto_free(hud)
	var field := Control.new()
	field.name = FpsOverlay.HUD_FIELD_NAME
	field.position = Vector2(1500.0, 20.0)
	field.size = Vector2(380.0, 120.0)
	hud.add_child(field)
	await await_idle_frame()
	overlay._next_hud_lookup_msec = 0
	overlay._refresh()
	var plate: Control = overlay.get_plate_for_test()
	var field_rect: Rect2 = field.get_global_transform() * Rect2(Vector2.ZERO, field.size)
	var plate_rect: Rect2 = plate.get_global_transform() * Rect2(Vector2.ZERO, plate.size)
	assert_bool(plate_rect.intersects(field_rect)).is_false()
	assert_float(plate_rect.position.y).is_greater_equal(field_rect.end.y)


func test_it_lives_under_the_root_so_a_scene_change_keeps_it() -> void:
	GameSettings.set_show_fps(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay: Node = get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)
	assert_object(overlay).is_not_null()
	assert_object(overlay.get_parent()).is_same(get_tree().root)
	assert_int(overlay.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS) # also counts while a menu pauses the tree
	GameSettings.set_show_fps(false)
	await get_tree().process_frame
	assert_object(get_tree().root.get_node_or_null(FpsOverlay.NODE_NAME)).is_null()

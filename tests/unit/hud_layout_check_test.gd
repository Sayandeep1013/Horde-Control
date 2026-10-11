extends GdUnitTestSuite

## HUD layout check (v1.0 redesign, docs/31 §8.1). MASTER_SDLC.md > Acceptance
## Test Matrix > Readability Tests > "HUD layout check": every cluster renders
## in its defined corner with no overlap, at 1920x1080, at 1280x720 and at the
## mobile compact canvas, and at HUD Scale 150%.
##
## Each case builds the HUD inside a SubViewport of the logical canvas size
## (the project stretches canvas_items, so the HUD lays out against the visible
## rect, not the window). The positions are asserted as screen rects, not just
## existence: an earlier HUD shipped an XP bar pinned off-screen with every
## content assertion green (F03-20).

var _dir: String


func before_test() -> void:
	_dir = "user://__hud_layout_check_%d_%d/" % [Time.get_ticks_usec(), randi()]
	GameSettings.set_path_for_test(_dir.path_join("settings.cfg"))
	GameSettings.reset_state_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()
	GameSettings.reset_path_for_test()
	TouchUi.set_override_for_test(-1)


func _build(size: Vector2i) -> Hud:
	var vp: SubViewport = auto_free(SubViewport.new())
	vp.size = size
	add_child(vp)
	var hud: Hud = Hud.new()
	vp.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return hud


func _rects(hud: Hud) -> Dictionary:
	return {
		"player": hud.get_player_health_field().get_global_rect(),
		"tower": hud.get_tower_health_field().get_global_rect(),
		"scrap": hud.get_scrap_field().get_global_rect(),
		"build": hud.get_build_bar().get_global_rect(),
		"actions": hud.get_action_cluster().get_global_rect(),
	}


func _assert_layout(hud: Hud, size: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(size))
	var r: Dictionary = _rects(hud)
	for key: String in r:
		var rect: Rect2 = r[key]
		assert_bool(bounds.encloses(rect)).append_failure_message("%s cluster %s is outside %s" % [key, rect, bounds]).is_true()
	# Corners: player top-left, scrap top-right, tower top-centre, build bottom-left, actions bottom-right.
	assert_float((r["player"] as Rect2).position.x).is_less(100.0)
	assert_float((r["player"] as Rect2).position.y).is_less(100.0)
	assert_float((r["scrap"] as Rect2).end.x).is_greater(float(size.x) - 100.0)
	assert_float((r["scrap"] as Rect2).position.y).is_less(100.0)
	var tower_mid: float = (r["tower"] as Rect2).get_center().x
	assert_float(tower_mid).is_between(float(size.x) * 0.45, float(size.x) * 0.55)
	assert_float((r["build"] as Rect2).position.x).is_less(100.0)
	assert_float((r["build"] as Rect2).end.y).is_greater(float(size.y) - 100.0)
	assert_float((r["actions"] as Rect2).end.x).is_greater(float(size.x) - 100.0)
	assert_float((r["actions"] as Rect2).end.y).is_greater(float(size.y) - 100.0)
	var keys: Array = r.keys()
	for i: int in keys.size():
		for j: int in range(i + 1, keys.size()):
			assert_bool((r[keys[i]] as Rect2).intersects(r[keys[j]])).append_failure_message("%s overlaps %s: %s vs %s" % [keys[i], keys[j], r[keys[i]], r[keys[j]]]).is_false()


func test_layout_at_1920x1080() -> void:
	var hud: Hud = await _build(Vector2i(1920, 1080))
	_assert_layout(hud, Vector2i(1920, 1080))


func test_layout_at_1280x720_logical_canvas() -> void:
	var hud: Hud = await _build(Vector2i(1280, 720))
	_assert_layout(hud, Vector2i(1280, 720))


func test_layout_at_hud_scale_150_percent() -> void:
	GameSettings.set_hud_scale_pct(150)
	var hud: Hud = await _build(Vector2i(1920, 1080))
	assert_float(hud.get_scale_root().scale.x).is_equal_approx(1.5, 0.001)
	_assert_layout(hud, Vector2i(1920, 1080))


func test_hud_scale_is_capped_on_a_narrow_canvas_so_the_top_row_cannot_collide() -> void:
	GameSettings.set_hud_scale_pct(150)
	var hud: Hud = await _build(Vector2i(1280, 720))
	assert_float(hud.get_scale_root().scale.x).append_failure_message("150% on a 1280 wide canvas would overlap the clusters").is_less(1.5)
	_assert_layout(hud, Vector2i(1280, 720))


func test_layout_on_the_mobile_compact_canvas_with_the_action_cluster_replaced_by_touch_buttons() -> void:
	TouchUi.set_override_for_test(1)
	var hud: Hud = await _build(Vector2i(1560, 720))
	assert_bool(hud.get_action_cluster().visible).append_failure_message("on touch the TouchControls buttons ARE the cluster").is_false()
	var bounds := Rect2(Vector2.ZERO, Vector2(1560, 720))
	for field: Control in [hud.get_player_health_field(), hud.get_tower_health_field(), hud.get_scrap_field(), hud.get_build_bar()]:
		assert_bool(bounds.encloses(field.get_global_rect())).is_true()
	assert_bool(hud.get_player_health_field().get_global_rect().intersects(hud.get_tower_health_field().get_global_rect())).is_false()
	assert_bool(hud.get_tower_health_field().get_global_rect().intersects(hud.get_scrap_field().get_global_rect())).is_false()


func test_boss_bar_hangs_under_the_tower_cluster_and_stays_on_screen() -> void:
	var hud: Hud = await _build(Vector2i(1920, 1080))
	EventBus.emit_boss_spawned(null, "warchief", "Goblin Warchief", 2600.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var boss: Rect2 = hud.get_boss_box().get_global_rect()
	assert_bool(hud.get_boss_box().visible).is_true()
	assert_float(boss.position.y).is_greater_equal(hud.get_tower_health_field().get_global_rect().position.y)
	assert_bool(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(boss)).is_true()
	# The camera's HUD-clear band (src/camera/game_camera.gd) must cover the tallest top footprint.
	assert_float(boss.end.y).append_failure_message("boss bar ends at %f, below the camera's top HUD margin" % boss.end.y).is_less_equal(GameCamera.HUD_MARGIN_TOP)


func test_hud_numbers_respect_the_37_px_floor_at_100_percent() -> void:
	var hud: Hud = await _build(Vector2i(1920, 1080))
	for label: Label in [hud.get_wave_label(), hud.get_timer_label(), hud.get_kills_label(), hud.get_scrap_label(), hud.get_player_hp_label(), hud.get_tower_hp_label()]:
		var size_px: int = label.get_theme_font_size("font_size", label.theme_type_variation if label.theme_type_variation != &"" else &"Label")
		assert_int(size_px).append_failure_message("%s is %d px, under the 37 px legibility floor" % [label.name, size_px]).is_greater_equal(UiPalette.FONT_SIZE_BODY)

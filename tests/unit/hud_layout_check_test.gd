extends GdUnitTestSuite

## HUD layout check (P2.14 named acceptance test). MASTER_SDLC.md >
## Acceptance Test Matrix > Readability Tests > "HUD layout check": "The
## player health bar (top-left), Tower health bar with shield overlay and
## wave label (top-centre), Scrap counter (top-right), and XP bar with
## level and rerolls (bottom) render in their defined positions at
## 1920x1080 with no overlap." docs/19_UI_UX.md > "HUD".
##
## This is the class of test CLAUDE.md and this phase's own carried lesson
## 1 exist to force: "Assert Controls at a position on a 1920x1080
## viewport, not merely that they exist - this project shipped an XP bar
## pinned off-screen at y=1080 with every content assertion green (F03-20)."
## tests/unit/hud_layout_test.gd (P2.6's own suite) asserts wiring and
## content but never a single screen-space rect -- this suite is the
## position check that gap left unclosed, added under this task's write
## scope (`tests/unit/*.gd`) without editing src/ui/hud.gd itself.
##
## MEASURED, not assumed from tests/unit/draft_input_lockout_test.gd's own
## `VIEWPORT_REF` comment: this project's headless gdUnit4 runner's root
## viewport does NOT default to project.godot's configured 1920x1080 --
## running this suite with no size override at all reported an actual root
## viewport of (64, 64). Whatever draft_input_lockout_test.gd's own
## same-shaped assertion is actually measuring, this suite does not rely on
## that assumption: `before_test()` force-sets the root viewport size, and
## `after_test()` restores whatever it was before, since a headless
## viewport size is process-wide, shared-state, exactly like
## `get_tree().paused` (tests/unit/pause_clock_test.gd's own precedent for
## why a shared setting a suite changes must always be restored). At least
## two layout passes are awaited after both the resize AND the HUD's own
## instantiation, since a Container does not finish sizing its children on
## the same frame either happens (hud.gd's own header names this exact
## class of timing hazard for its VBoxContainer rewrite).

const HudScene: PackedScene = preload("res://scenes/ui/hud.tscn")

const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _hud: Hud
var _viewport_size_saved: Vector2i


func before_test() -> void:
	_viewport_size_saved = get_tree().root.size
	get_tree().root.size = VIEWPORT_SIZE
	_hud = auto_free(HudScene.instantiate()) as Hud
	add_child(_hud)
	await get_tree().process_frame
	await get_tree().process_frame # Container layout needs at least one full pass; a second is cheap insurance, matching hud.gd's own documented timing hazard


func after_test() -> void:
	get_tree().root.size = _viewport_size_saved


func _rect(field: Control) -> Rect2:
	return field.get_global_rect()


func test_viewport_is_actually_1920x1080_for_this_check() -> void:
	# A layout check whose own viewport silently reports a different size
	# would be measuring nothing -- assert the precondition, not just rely
	# on it (this project's own falsification discipline).
	assert_vector(Vector2(get_tree().root.size)).append_failure_message("test viewport is not 1920x1080 - every rect below would be meaningless").is_equal(Vector2(VIEWPORT_SIZE))


func test_player_health_bar_sits_top_left() -> void:
	var r: Rect2 = _rect(_hud.get_player_health_field())
	assert_float(r.position.x).append_failure_message("player health field is not near the left edge: x=%f" % r.position.x).is_less(150.0)
	assert_float(r.position.y).append_failure_message("player health field is not near the top edge: y=%f" % r.position.y).is_less(150.0)
	assert_float(r.position.x).append_failure_message("player health field has a negative x -- off-screen to the left").is_greater_equal(0.0)
	assert_float(r.position.y).append_failure_message("player health field has a negative y -- off-screen above the top").is_greater_equal(0.0)


func test_tower_health_bar_sits_top_centre_with_wave_label() -> void:
	var r: Rect2 = _rect(_hud.get_tower_health_field())
	var center_x: float = r.position.x + r.size.x * 0.5
	assert_float(center_x).append_failure_message("Tower health field is not roughly centred horizontally: centre x=%f (viewport width %d)" % [center_x, VIEWPORT_SIZE.x]).is_between(VIEWPORT_SIZE.x * 0.30, VIEWPORT_SIZE.x * 0.70)
	assert_float(r.position.y).append_failure_message("Tower health field is not near the top edge: y=%f" % r.position.y).is_less(150.0)
	assert_float(r.position.y).is_greater_equal(0.0)

	# "Tower health bar with ... wave label" -- the wave label is a real,
	# visible child inside this same field, not merely present in the tree.
	var wave_label: Label = _hud.get_wave_label()
	assert_object(wave_label).is_not_null()
	assert_bool(wave_label.is_visible_in_tree()).append_failure_message("the wave label exists but is not visible in the tree").is_true()
	var wave_rect: Rect2 = wave_label.get_global_rect()
	assert_bool(r.encloses(wave_rect) or r.intersects(wave_rect)).append_failure_message("the wave label is not positioned inside the Tower health field's own rect").is_true()


func test_scrap_counter_sits_top_right() -> void:
	var r: Rect2 = _rect(_hud.get_scrap_field())
	var right_edge: float = r.position.x + r.size.x
	assert_float(right_edge).append_failure_message("Scrap field is not near the right edge: right=%f (viewport width %d)" % [right_edge, VIEWPORT_SIZE.x]).is_greater(VIEWPORT_SIZE.x * 0.75)
	assert_float(right_edge).append_failure_message("Scrap field's right edge exceeds the viewport -- off-screen to the right").is_less_equal(float(VIEWPORT_SIZE.x) + 0.5)
	assert_float(r.position.y).append_failure_message("Scrap field is not near the top edge: y=%f" % r.position.y).is_less(150.0)
	assert_float(r.position.y).is_greater_equal(0.0)


func test_xp_bar_sits_at_the_bottom_with_level_and_rerolls() -> void:
	var r: Rect2 = _rect(_hud.get_xp_field())
	var bottom_edge: float = r.position.y + r.size.y
	assert_float(bottom_edge).append_failure_message("XP field is not near the bottom edge: bottom=%f (viewport height %d) - this is exactly the F03-20 class of defect (an XP bar pinned off-screen at y=1080)" % [bottom_edge, VIEWPORT_SIZE.y]).is_greater(VIEWPORT_SIZE.y * 0.80)
	assert_float(bottom_edge).append_failure_message("XP field's bottom edge is AT OR BEYOND the viewport height -- it is off-screen, the exact F03-20 defect").is_less_equal(float(VIEWPORT_SIZE.y))
	assert_float(r.position.y).append_failure_message("XP field has a negative y -- off-screen above the top").is_greater_equal(0.0)

	assert_bool(_hud.get_level_label().is_visible_in_tree()).is_true()
	assert_bool(_hud.get_rerolls_label().is_visible_in_tree()).is_true()
	assert_bool(r.intersects(_hud.get_level_label().get_global_rect()) or r.encloses(_hud.get_level_label().get_global_rect())).append_failure_message("the level label is not positioned inside the XP field's own rect").is_true()
	assert_bool(r.intersects(_hud.get_rerolls_label().get_global_rect()) or r.encloses(_hud.get_rerolls_label().get_global_rect())).append_failure_message("the rerolls label is not positioned inside the XP field's own rect").is_true()


func test_all_four_fields_are_entirely_within_the_viewport() -> void:
	var fields: Array = [_hud.get_player_health_field(), _hud.get_tower_health_field(), _hud.get_scrap_field(), _hud.get_xp_field()]
	var names: Array = ["player health", "Tower health", "Scrap", "XP"]
	for i in fields.size():
		var r: Rect2 = _rect(fields[i])
		assert_float(r.position.x).append_failure_message("%s field's left edge is off-screen (x=%f)" % [names[i], r.position.x]).is_greater_equal(0.0)
		assert_float(r.position.y).append_failure_message("%s field's top edge is off-screen (y=%f)" % [names[i], r.position.y]).is_greater_equal(0.0)
		assert_float(r.position.x + r.size.x).append_failure_message("%s field's right edge (%f) exceeds the viewport width (%d)" % [names[i], r.position.x + r.size.x, VIEWPORT_SIZE.x]).is_less_equal(float(VIEWPORT_SIZE.x) + 0.5)
		assert_float(r.position.y + r.size.y).append_failure_message("%s field's bottom edge (%f) exceeds the viewport height (%d)" % [names[i], r.position.y + r.size.y, VIEWPORT_SIZE.y]).is_less_equal(float(VIEWPORT_SIZE.y) + 0.5)


func test_no_two_of_the_four_fields_overlap() -> void:
	var fields: Array = [_hud.get_player_health_field(), _hud.get_tower_health_field(), _hud.get_scrap_field(), _hud.get_xp_field()]
	var names: Array = ["player health", "Tower health", "Scrap", "XP"]
	for i in fields.size():
		for j in range(i + 1, fields.size()):
			var a: Rect2 = _rect(fields[i])
			var b: Rect2 = _rect(fields[j])
			assert_bool(a.intersects(b)).append_failure_message("%s field overlaps the %s field: %s vs %s" % [names[i], names[j], a, b]).is_false()

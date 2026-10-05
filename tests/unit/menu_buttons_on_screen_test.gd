extends GdUnitTestSuite

## UX review P0-1/P0-2 (D127): every focusable button on the Title and the
## Hub must lie inside the viewport. The project's design viewport is
## 1920x1080 and the canvas_items stretch scales it uniformly, so a button
## inside this rect is inside 1280x720 too.

const BASE: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _dir: String


func before_test() -> void:
	_dir = "user://__menu_buttons_test_%d_%d/" % [Time.get_ticks_usec(), randi()]
	MetaProgress.set_base_path_for_test(_dir)


func after_test() -> void:
	MetaProgress.set_base_path_for_test("user://")


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button and (child as Button).focus_mode == Control.FOCUS_ALL and (child as Button).is_visible_in_tree():
			out.append(child)
		_collect_buttons(child, out)


func _check(screen: Node) -> void:
	var vp: SubViewport = auto_free(SubViewport.new())
	vp.size = Vector2i(1920, 1080)
	add_child(vp)
	vp.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons: Array[Button] = []
	_collect_buttons(screen, buttons)
	assert_int(buttons.size()).append_failure_message("no focusable buttons found").is_greater(3)
	for b in buttons:
		var r: Rect2 = b.get_global_rect()
		assert_bool(BASE.encloses(r)).append_failure_message("%s rect %s lies outside %s" % [b.name, r, BASE]).is_true()


func test_title_buttons_inside_viewport() -> void:
	await _check(TitleScreen.new())


func test_hub_buttons_inside_viewport() -> void:
	await _check(HubScreen.new())

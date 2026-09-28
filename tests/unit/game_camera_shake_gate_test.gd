extends GdUnitTestSuite

## Screen Shake setting gate (task brief: "gate the shake in
## src/camera/game_camera.gd (add_trauma or where offset is applied)").
## Mirrors tests/unit/camera_bounds_test.gd's own construction (`set_script`
## on a bare `Camera2D`) rather than instancing a scene GameCamera does not
## own. `GameSettings` state is memory-only here (`_for_test` setters) -- no
## disk path redirection needed since nothing is saved.

const GameCameraScript: GDScript = preload("res://src/camera/game_camera.gd")


func before_test() -> void:
	GameSettings.reset_state_for_test()


func after_test() -> void:
	GameSettings.reset_state_for_test()


func _make_camera() -> Camera2D:
	var camera: Camera2D = auto_free(Camera2D.new())
	camera.set_script(GameCameraScript)
	add_child(camera)
	return camera


func test_shake_enabled_by_default_accumulates_trauma() -> void:
	var camera: Camera2D = _make_camera()
	camera.add_trauma(0.5)
	assert_float(camera.get_trauma_for_test()).is_greater(0.0)


func test_shake_disabled_drops_add_trauma_entirely() -> void:
	GameSettings.set_screen_shake_enabled_for_test(false)
	var camera: Camera2D = _make_camera()
	camera.add_trauma(0.5)
	assert_float(camera.get_trauma_for_test()).append_failure_message("add_trauma() must be a no-op while Screen Shake is disabled").is_equal(0.0)


## FALSIFICATION (named in the report): temporarily removed the `if not
## GameSettings.is_screen_shake_enabled(): return` guard from `add_trauma()`
## -- this test failed (trauma accumulated regardless of the setting).
## Reverted after confirming the failure.
func test_re_enabling_shake_after_a_disabled_call_still_works() -> void:
	GameSettings.set_screen_shake_enabled_for_test(false)
	var camera: Camera2D = _make_camera()
	camera.add_trauma(0.5)
	assert_float(camera.get_trauma_for_test()).is_equal(0.0)

	GameSettings.set_screen_shake_enabled_for_test(true)
	camera.add_trauma(0.5)
	assert_float(camera.get_trauma_for_test()).is_greater(0.0)

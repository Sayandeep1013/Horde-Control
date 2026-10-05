extends GdUnitTestSuite
## Feel pass (D151): GameCamera follows the target's INTERPOLATED transform,
## takes its look-ahead from the body's `velocity` (not a finite difference of
## a ticked position), opts out of physics interpolation itself, and no longer
## lives under the Player node (that last part is asserted in
## prototype_scene_test.gd, which resolves the camera at Main/GameCamera).

const GameCameraScript: GDScript = preload("res://src/camera/game_camera.gd")


func _make(target: Node2D) -> Camera2D:
	var camera: Camera2D = auto_free(Camera2D.new())
	camera.set_script(GameCameraScript)
	camera.target = target
	add_child(camera)
	return camera


func test_camera_opts_out_of_physics_interpolation() -> void:
	var camera: Camera2D = _make(null)
	assert_int(camera.physics_interpolation_mode).is_equal(Node.PHYSICS_INTERPOLATION_MODE_OFF)


func test_lead_comes_from_the_bodys_velocity_even_when_the_position_is_static() -> void:
	var body: CharacterBody2D = auto_free(CharacterBody2D.new())
	add_child(body)
	body.global_position = Vector2(100.0, 0.0)
	body.velocity = Vector2(200.0, 0.0)
	var camera: Camera2D = _make(body)
	for _i in range(120):
		camera._process(1.0 / 144.0)
	# lead = 200 px/s * CAMERA_LEAD_TIME (0.25 s) = 50 px, below the 120 px cap
	assert_float(camera.global_position.x).append_failure_message("camera x=%f" % camera.global_position.x).is_equal_approx(150.0, 1.0)


func test_lead_is_stable_between_ticks_on_a_high_refresh_display() -> void:
	# Position changes only every 3rd frame (a 144 Hz display on a 48 Hz tick),
	# velocity is constant: the camera step must not go backward.
	var body: CharacterBody2D = auto_free(CharacterBody2D.new())
	add_child(body)
	body.velocity = Vector2(300.0, 0.0)
	var camera: Camera2D = _make(body)
	var last_x: float = camera.global_position.x
	for i in range(240):
		if i % 3 == 0:
			body.global_position += Vector2(300.0 / 48.0, 0.0)
			camera._physics_process(1.0 / 48.0) # the tick sample the engine would take
		camera._process(1.0 / 144.0)
		if i > 30:
			assert_float(camera.global_position.x).append_failure_message("camera moved backward at frame %d" % i).is_greater_equal(last_x - 0.0001)
		last_x = camera.global_position.x

extends GdUnitTestSuite

## Verification (Phase 02 carried lesson 5: "Verify by reading the artifact
## back; a tool reporting success is not evidence") that scenes/arena.tscn,
## as built, actually matches MASTER_SDLC.md > Provisional Values Register
## > Arena & Camera > "Arena size" row (4800x3200, hard walls on
## ArenaBounds, no interior obstacles) and docs/20_Technical_Architecture.md
## > Collision Layers table row 15 (ArenaBounds, static body, no mask). Not
## itself the named Camera bounds test (camera_bounds_test.gd is), but a
## defect in the arena's own geometry -- a wall placed at the wrong
## coordinate, or on the wrong collision layer -- would not be caught by
## camera_bounds_test.gd at all, since that suite exercises GameCamera's own
## clamp math against the Register's numbers directly, never against this
## scene file.

const ArenaScene: PackedScene = preload("res://scenes/arena.tscn")

const ARENA_SIZE: Vector2 = Vector2(4800.0, 3200.0) # Register > "Arena size" row
const ARENA_BOUNDS_LAYER_BIT: int = 1 << 14 # docs/20 Collision Layers table, layer 15 (1-indexed) = bit 14

var _arena: Node2D


func before_test() -> void:
	_arena = auto_free(ArenaScene.instantiate()) as Node2D
	add_child(_arena)


func test_floor_covers_exactly_the_registers_arena_size() -> void:
	var floor_sprite: Sprite2D = _arena.get_node("Floor") as Sprite2D
	assert_object(floor_sprite).append_failure_message("scenes/arena.tscn has no Floor node").is_not_null()
	assert_bool(floor_sprite.region_enabled).append_failure_message("Floor must use region_rect to tile the seamless texture across the arena").is_true()
	assert_vector(floor_sprite.region_rect.size).append_failure_message(
		"Floor.region_rect.size %s does not match the Register's 4800x3200 Arena size row" % floor_sprite.region_rect.size
	).is_equal(ARENA_SIZE)
	assert_int(floor_sprite.texture_repeat).append_failure_message(
		"Floor.texture_repeat must be ENABLED (2) for the region to tile the floor_tile.png texture instead of stretching it"
	).is_equal(CanvasItem.TEXTURE_REPEAT_ENABLED)
	assert_bool(floor_sprite.centered).append_failure_message(
		"Floor must stay centred so its region is centred on the arena's own centre (Tower-at-centre origin)"
	).is_true()


func test_arena_bounds_body_is_on_the_arenabounds_layer_with_no_mask() -> void:
	var bounds: StaticBody2D = _arena.get_node("ArenaBounds") as StaticBody2D
	assert_object(bounds).append_failure_message("scenes/arena.tscn has no ArenaBounds StaticBody2D").is_not_null()
	assert_int(bounds.collision_layer).append_failure_message(
		"ArenaBounds.collision_layer %d does not equal CollisionLayers.LAYER_ARENA_BOUNDS (%d)" % [bounds.collision_layer, ARENA_BOUNDS_LAYER_BIT]
	).is_equal(CollisionLayers.LAYER_ARENA_BOUNDS)
	assert_int(bounds.collision_layer).is_equal(ARENA_BOUNDS_LAYER_BIT)
	assert_int(bounds.collision_mask).append_failure_message(
		"docs/20 Collision Layers table row 15 lists ArenaBounds' mask as 'none'"
	).is_equal(0)


func test_arena_bounds_has_exactly_four_wall_shapes_and_no_interior_obstacles() -> void:
	var bounds: Node = _arena.get_node("ArenaBounds")
	var wall_names: Array[String] = []
	for child in bounds.get_children():
		if child is CollisionShape2D:
			wall_names.append(child.name)
	assert_array(wall_names).append_failure_message(
		"expected exactly 4 wall CollisionShape2D children (N/S/E/W), found %s" % str(wall_names)
	).has_size(4)

	# "no interior obstacles in the prototype" (Register > "Arena size" row):
	# nothing under Arena besides Floor and ArenaBounds should carry a
	# collision shape.
	for child in _arena.get_children():
		if child.name != "Floor" and child.name != "ArenaBounds":
			assert_bool(child is CollisionObject2D).append_failure_message(
				"unexpected node '%s' under Arena; the Register requires no interior obstacles in the prototype" % child.name
			).is_false()


func test_walls_fully_enclose_the_registers_arena_rectangle_with_no_gap() -> void:
	# Each wall's own rectangle, in Arena-local space, must cover the full
	# outer boundary on its side with its inner face flush at the Register's
	# +/-2400 / +/-1600 edges, and corners must not gap (Register: "hard
	# walls on ArenaBounds, so nothing escapes"; this task's brief: "hard
	# StaticBody2D walls ... so nothing escapes").
	var bounds: Node2D = _arena.get_node("ArenaBounds") as Node2D
	var half: Vector2 = ARENA_SIZE / 2.0 # (2400, 1600)

	var walls: Dictionary = {}
	for child in bounds.get_children():
		if child is CollisionShape2D:
			walls[child.name] = child

	for expected_name in ["WallNorth", "WallSouth", "WallWest", "WallEast"]:
		assert_object(walls.get(expected_name)).append_failure_message("missing wall node: %s" % expected_name).is_not_null()

	var north: CollisionShape2D = walls["WallNorth"]
	var south: CollisionShape2D = walls["WallSouth"]
	var west: CollisionShape2D = walls["WallWest"]
	var east: CollisionShape2D = walls["WallEast"]

	var north_shape: RectangleShape2D = north.shape as RectangleShape2D
	var north_top: float = north.position.y - north_shape.size.y / 2.0
	var north_bottom: float = north.position.y + north_shape.size.y / 2.0
	assert_float(north_bottom).append_failure_message(
		"WallNorth's inner (south-facing) edge at y=%.1f is not flush with the arena's top bound y=%.1f -- a gap would let the camera or player see/pass past the boundary" % [north_bottom, -half.y]
	).is_equal_approx(-half.y, 0.01)
	# The wall's own left/right extent must reach at least to the arena's
	# outer corners, so West/East wall thickness does not leave a gap.
	var north_left: float = north.position.x - north_shape.size.x / 2.0
	var north_right: float = north.position.x + north_shape.size.x / 2.0
	assert_float(north_left).append_failure_message("WallNorth does not reach the west corner").is_less_equal(-half.x)
	assert_float(north_right).append_failure_message("WallNorth does not reach the east corner").is_greater_equal(half.x)

	var south_shape: RectangleShape2D = south.shape as RectangleShape2D
	var south_top: float = south.position.y - south_shape.size.y / 2.0
	assert_float(south_top).append_failure_message(
		"WallSouth's inner (north-facing) edge at y=%.1f is not flush with the arena's bottom bound y=%.1f" % [south_top, half.y]
	).is_equal_approx(half.y, 0.01)

	var west_shape: RectangleShape2D = west.shape as RectangleShape2D
	var west_right: float = west.position.x + west_shape.size.x / 2.0
	assert_float(west_right).append_failure_message(
		"WallWest's inner (east-facing) edge at x=%.1f is not flush with the arena's left bound x=%.1f" % [west_right, -half.x]
	).is_equal_approx(-half.x, 0.01)

	var east_shape: RectangleShape2D = east.shape as RectangleShape2D
	var east_left: float = east.position.x - east_shape.size.x / 2.0
	assert_float(east_left).append_failure_message(
		"WallEast's inner (west-facing) edge at x=%.1f is not flush with the arena's right bound x=%.1f" % [east_left, half.x]
	).is_equal_approx(half.x, 0.01)

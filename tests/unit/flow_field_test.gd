extends GdUnitTestSuite

## PT-ARENA (docs/33 section B4; Register "v1.0 Arena Layout"): the FlowField service. The
## expectations are literals (bridge cells, the 32 px grid, the 0.25 s cadence), not values read
## back from the code under test.

const ArenaScene: PackedScene = preload("res://scenes/arena.tscn")

var _arena: Node2D
var _ff: FlowField
var _clock_before: float = 0.0
var _dummy_player: Node2D = null


func before_test() -> void:
	_clock_before = SimClock.now
	_arena = auto_free(ArenaScene.instantiate()) as Node2D
	add_child(_arena)
	_ff = _arena.get_node("FlowField") as FlowField


func after_test() -> void:
	if _dummy_player != null and is_instance_valid(_dummy_player):
		EntityRegistry.deregister_entity(_dummy_player)
		_dummy_player.free()
		_dummy_player = null
	SimClock.now = _clock_before


## Follows direction_to from `start` in 12 px steps; returns every visited position (or stops at the goal).
func _walk(kind: StringName, start: Vector2, goal_dist: float, goal: Vector2, max_steps: int = 700) -> Array[Vector2]:
	var path: Array[Vector2] = [start]
	var p: Vector2 = start
	for _i in max_steps:
		if p.distance_to(goal) <= goal_dist:
			break
		var d: Vector2 = _ff.direction_to(kind, p)
		if d == Vector2.ZERO:
			break
		p += d * 12.0
		path.append(p)
	return path


func test_grid_is_32_px_over_the_2432_by_1664_island() -> void:
	assert_int(_ff.cols).is_equal(76)
	assert_int(_ff.rows).is_equal(52)
	assert_int(_ff.cols * _ff.rows).is_less_equal(4000)


func test_water_and_obstacles_are_not_walkable_but_bridges_and_land_are() -> void:
	assert_bool(_ff.is_walkable(Vector2(0, -576))).append_failure_message("north moat water must block").is_false()
	assert_bool(_ff.is_walkable(Vector2(900, 300))).append_failure_message("east moat water must block").is_false()
	assert_bool(_ff.is_walkable(Vector2(-384, -576))).append_failure_message("north bridge must be walkable").is_true()
	assert_bool(_ff.is_walkable(Vector2(896, -128))).append_failure_message("east bridge must be walkable").is_true()
	assert_bool(_ff.is_walkable(Vector2(384, 576))).append_failure_message("south bridge must be walkable").is_true()
	assert_bool(_ff.is_walkable(Vector2(-896, 128))).append_failure_message("west bridge must be walkable").is_true()
	assert_bool(_ff.is_walkable(Vector2(0, 0))).append_failure_message("the Tower footprint is not walkable").is_false()
	assert_bool(_ff.is_walkable(Vector2(380, -250))).append_failure_message("the north-east rock outcrop must block").is_false()
	assert_bool(_ff.is_walkable(Vector2(-560, -204))).append_failure_message("the castle ruin must block").is_false()
	assert_bool(_ff.is_walkable(Vector2(300, 0))).append_failure_message("open keep ground").is_true()
	assert_bool(_ff.is_walkable(Vector2(1100, 0))).append_failure_message("outer bank").is_true()
	assert_bool(_ff.is_walkable(Vector2(5000, 0))).append_failure_message("off the grid").is_false()


## The four bridge openings as literals (cells x 64 px): north, east, south, west.
const BRIDGE_RECTS: Array[Rect2] = [Rect2(-448, -640, 128, 128), Rect2(832, -192, 128, 128), Rect2(320, 512, 128, 128), Rect2(-960, 64, 128, 128)]


func _in_moat_ring(p: Vector2) -> bool:
	var outer := Rect2(-960, -640, 1920, 1280)
	var inner := Rect2(-832, -512, 1664, 1024)
	return outer.has_point(p) and not inner.has_point(p)


func _on_a_bridge(p: Vector2) -> bool:
	for r in BRIDGE_RECTS:
		if r.has_point(p):
			return true
	return false


func test_a_path_from_the_bank_crosses_the_moat_only_on_a_bridge() -> void:
	for start in [Vector2(1130, 520), Vector2(1130, -560), Vector2(-1130, -400), Vector2(-700, 740), Vector2(0, -740)]:
		var path: Array[Vector2] = _walk(&"tower", start, 150.0, Vector2.ZERO, 1200)
		assert_bool(path[path.size() - 1].distance_to(Vector2.ZERO) <= 150.0).append_failure_message("from %s: ended at %s after %d steps" % [start, path[path.size() - 1], path.size()]).is_true()
		var crossed: bool = false
		for p in path.slice(0, path.size() - 1): # the last step may land on the Tower's footprint
			assert_bool(_ff.is_walkable(p)).append_failure_message("from %s: stepped on blocked ground at %s" % [start, p]).is_true()
			if _in_moat_ring(p):
				crossed = true
				assert_bool(_on_a_bridge(p)).append_failure_message("from %s: in the moat off a bridge at %s" % [start, p]).is_true()
		assert_bool(crossed).append_failure_message("from %s: the path never entered the moat ring" % start).is_true()


func test_the_east_bank_south_of_the_east_bridge_prefers_the_nearest_bridge_by_walking_distance() -> void:
	# From (1130, 520) the south bridge (x 320-448) is about 760 px of bank away and the east bridge
	# (y -192..-64) about 650 px: the field must pick the cheaper one, whichever it is.
	var d_field: float = _ff.distance_to(&"tower", Vector2(1130, 520))
	assert_float(d_field).is_greater(500.0)
	assert_float(d_field).is_less(2200.0)


func test_every_bank_start_reaches_the_tower_without_touching_water_or_obstacles() -> void:
	var starts: Array[Vector2] = [Vector2(-1000, -760), Vector2(0, -740), Vector2(1000, -760), Vector2(-1130, 0), Vector2(1130, 0), Vector2(-1000, 760), Vector2(100, 740), Vector2(1000, 760)]
	for s in starts:
		var path: Array[Vector2] = _walk(&"tower", s, 150.0, Vector2.ZERO, 1200)
		assert_bool(path[path.size() - 1].distance_to(Vector2.ZERO) <= 150.0).append_failure_message("from %s: stopped at %s" % [s, path[path.size() - 1]]).is_true()
		for p in path.slice(0, path.size() - 1):
			assert_bool(_ff.is_walkable(p)).append_failure_message("from %s: blocked ground at %s" % [s, p]).is_true()


func test_every_walkable_cell_is_reachable_from_the_tower() -> void:
	var count: int = 0
	for y in range(-832 + 16, 832, 32):
		for x in range(-1216 + 16, 1216, 32):
			var p := Vector2(x, y)
			if _ff.is_walkable(p):
				count += 1
				assert_bool(_ff.direction_to(&"tower", p) != Vector2.ZERO).append_failure_message("walkable cell %s has no route to the Tower" % p).is_true()
	assert_int(count).is_equal(_ff.walkable_cell_count())


func test_unreachable_and_off_grid_positions_give_zero() -> void:
	assert_vector(_ff.direction_to(&"tower", Vector2(5000, 5000))).is_equal(Vector2.ZERO)
	assert_vector(_ff.direction_to(&"nonsense", Vector2(300, 0))).is_equal(Vector2.ZERO)
	# The player field has not been computed yet.
	assert_vector(_ff.direction_to(&"player", Vector2(300, 0))).is_equal(Vector2.ZERO)
	# A walled-in pocket: a 5 x 5 cell room with a closed ring of blockers. It is pruned from the mask.
	var ff: FlowField = auto_free(FlowField.new())
	ff.half_size = Vector2(320, 320)
	add_child(ff)
	var ring: Array[Rect2] = [Rect2(-160, 96, 320, 32), Rect2(-160, 224, 320, 32), Rect2(-160, 96, 32, 160), Rect2(128, 96, 32, 160)]
	ff.build(ring, Vector2.ZERO, 40.0)
	assert_bool(ff.is_walkable(Vector2(0, 176))).append_failure_message("a walled-in pocket must not count as walkable").is_false()
	assert_vector(ff.direction_to(&"tower", Vector2(0, 176))).is_equal(Vector2.ZERO)
	assert_bool(ff.is_walkable(Vector2(-250, -250))).is_true()


func test_a_wall_makes_the_field_bend_round_it() -> void:
	var ff: FlowField = auto_free(FlowField.new())
	ff.half_size = Vector2(320, 320)
	add_child(ff)
	# A wall east of the Tower, from y -224 down to y +96: a body due east of it must go south.
	ff.build([Rect2(128, -224, 32, 320)] as Array[Rect2], Vector2.ZERO, 40.0)
	var d: Vector2 = ff.direction_to(&"tower", Vector2(250, -40))
	assert_float(d.y).append_failure_message("expected to head south round the wall, got %s" % d).is_greater(0.3)
	var open: Vector2 = ff.direction_to(&"tower", Vector2(-250, 0))
	assert_float(open.x).is_greater(0.9)


func test_player_field_recomputes_every_quarter_second_of_sim_time() -> void:
	_dummy_player = Node2D.new()
	add_child(_dummy_player)
	_dummy_player.global_position = Vector2(500, 0)
	EntityRegistry.register_entity(_dummy_player, _dummy_player.global_position, [&"player"])
	SimClock.now = 100.0
	var base: int = _ff.player_recomputes
	_ff._physics_process(0.0)
	assert_int(_ff.player_recomputes).is_equal(base + 1)
	for t in [0.05, 0.1, 0.2, 0.24]:
		SimClock.now = 100.0 + t
		_ff._physics_process(0.0)
	assert_int(_ff.player_recomputes).append_failure_message("no recompute before 0.25 s").is_equal(base + 1)
	SimClock.now = 100.26
	_ff._physics_process(0.0)
	assert_int(_ff.player_recomputes).is_equal(base + 2)
	# Frozen clock (a pause): nothing recomputes.
	_ff._physics_process(0.0)
	_ff._physics_process(0.0)
	assert_int(_ff.player_recomputes).is_equal(base + 2)
	# The field points towards the player: from the keep's far side the route runs along a bridge.
	assert_vector(_ff.direction_to(&"player", Vector2(300, 0))).is_not_equal(Vector2.ZERO)


func test_player_field_across_the_moat_goes_via_a_bridge() -> void:
	_ff.recompute_player_field(Vector2(300, 200))
	var path: Array[Vector2] = _walk(&"player", Vector2(1100, 500), 40.0, Vector2(300, 200), 900)
	assert_bool(path[path.size() - 1].distance_to(Vector2(300, 200)) <= 40.0).append_failure_message("did not reach the player, ended %s" % path[path.size() - 1]).is_true()
	for p in path:
		assert_bool(_ff.is_walkable(p)).is_true()


func test_recompute_cost_is_reported() -> void:
	var worst: int = 0
	for i in 20:
		_ff.recompute_player_field(Vector2(-900 + i * 90, -300 + (i % 5) * 150))
		worst = maxi(worst, _ff.last_player_usec)
	print("FLOWFIELD player recompute: last %.2f ms, worst of 20 %.2f ms; tower field %.2f ms; %d walkable cells" % [_ff.last_player_usec / 1000.0, worst / 1000.0, _ff.last_tower_usec / 1000.0, _ff.walkable_cell_count()])
	assert_int(worst).append_failure_message("recompute took %.1f ms" % (worst / 1000.0)).is_less(20000)


func test_random_walkable_point_respects_the_annulus_and_the_mask() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var from := Vector2(0, 0)
		var p: Vector2 = _ff.random_walkable_point(rng, from, 300.0, 700.0)
		assert_bool(p != Vector2.ZERO).is_true()
		assert_bool(_ff.is_walkable(p)).append_failure_message("%s is not walkable" % p).is_true()
		assert_bool(p.distance_to(from) >= 299.0 and p.distance_to(from) <= 701.0).is_true()
	# Nothing walkable within 5 px of a point in the middle of the moat's north-west corner water.
	assert_vector(_ff.random_walkable_point(rng, Vector2(5000, 5000), 0.0, 10.0)).is_equal(Vector2.ZERO)


func test_random_walkable_point_is_deterministic_per_seed() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 10:
		assert_vector(_ff.random_walkable_point(a, Vector2(100, 100), 200.0, 900.0)).is_equal(_ff.random_walkable_point(b, Vector2(100, 100), 200.0, 900.0))


func test_spawn_projection_lands_on_walkable_reachable_bank_cells_all_round() -> void:
	for k in 72:
		var angle: float = TAU * float(k) / 72.0
		for radius in [1331.0, 1400.0, 1459.0]:
			var raw: Vector2 = Vector2.from_angle(angle) * radius
			var p: Vector2 = _ff.project_to_spawn_edge(raw)
			assert_bool(_ff.is_walkable(p)).append_failure_message("angle %.0f r %.0f -> %s is not walkable" % [rad_to_deg(angle), radius, p]).is_true()
			assert_bool(absf(p.x) >= 960.0 or absf(p.y) >= 640.0).append_failure_message("%s is not on the outer bank" % p).is_true()
			assert_bool(_ff.direction_to(&"tower", p) != Vector2.ZERO).append_failure_message("%s cannot reach the Tower" % p).is_true()


func test_spawn_geometry_uses_the_installed_projector_and_clears_it_on_exit() -> void:
	assert_bool(SpawnGeometry.point_projector.is_valid()).append_failure_message("the arena's FlowField must install the projector").is_true()
	_arena.queue_free()
	await get_tree().process_frame
	assert_bool(SpawnGeometry.point_projector.is_valid()).append_failure_message("the projector must be cleared when the FlowField leaves the tree").is_false()

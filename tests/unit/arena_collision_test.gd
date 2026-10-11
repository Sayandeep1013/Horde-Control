extends GdUnitTestSuite

## PT-ARENA (docs/33 section B2, B3; D331, D332): the assembled arena's real collision. Water stops
## the player and walking enemies but not shots; rock outcrops and ruins stop all of them; the
## bridges are open. Probes are CharacterBody2D circles with the project's own body and projectile masks.

const ArenaScene: PackedScene = preload("res://scenes/arena.tscn")

var _arena: Node2D


func before_test() -> void:
	_arena = auto_free(ArenaScene.instantiate()) as Node2D
	add_child(_arena)
	await get_tree().physics_frame
	await get_tree().physics_frame


## Moves a probe circle from `from` towards `to` in 8 px steps and returns where it ended.
func _probe(mask: int, from: Vector2, to: Vector2, radius: float = 14.0) -> Vector2:
	var body := CharacterBody2D.new()
	body.collision_layer = 0
	body.collision_mask = mask
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = from
	var dir: Vector2 = (to - from).normalized()
	var remaining: float = from.distance_to(to)
	while remaining > 0.0:
		var step: float = minf(8.0, remaining)
		var hit: KinematicCollision2D = body.move_and_collide(dir * step)
		if hit != null:
			break
		remaining -= step
	var end: Vector2 = body.global_position
	body.free()
	return end


func test_layer_17_is_water_and_only_bodies_mask_it() -> void:
	assert_int(CollisionLayers.LAYER_WATER).is_equal(1 << 16)
	assert_int(CollisionLayers.MASK_PLAYER_BODY & CollisionLayers.LAYER_WATER).is_equal(CollisionLayers.LAYER_WATER)
	assert_int(CollisionLayers.MASK_ENEMY_BODY_GROUND & CollisionLayers.LAYER_WATER).is_equal(CollisionLayers.LAYER_WATER)
	assert_int(CollisionLayers.MASK_PLAYER_PROJECTILE & CollisionLayers.LAYER_WATER).is_equal(0)
	assert_int(CollisionLayers.MASK_TOWER_PROJECTILE & CollisionLayers.LAYER_WATER).is_equal(0)
	assert_int(CollisionLayers.MASK_ENEMY_PROJECTILE & CollisionLayers.LAYER_WATER).is_equal(0)


func test_the_player_and_an_enemy_are_stopped_by_the_east_moat() -> void:
	# y = 300 is south of the east bridge (y -192..-64): the moat water starts at x 832.
	for mask in [CollisionLayers.MASK_PLAYER_BODY, CollisionLayers.MASK_ENEMY_BODY_GROUND]:
		var end: Vector2 = _probe(mask, Vector2(700, 300), Vector2(1100, 300))
		assert_float(end.x).append_failure_message("mask %d crossed the water, ended at %s" % [mask, end]).is_less_equal(832.0)
		assert_float(end.x).is_greater(780.0) # it did reach the shore


func test_a_dashing_player_is_still_stopped_by_water() -> void:
	var dash_mask: int = CollisionLayers.MASK_PLAYER_BODY & ~CollisionLayers.LAYER_ENEMY_BODY
	var end: Vector2 = _probe(dash_mask, Vector2(700, 300), Vector2(1100, 300))
	assert_float(end.x).is_less_equal(832.0)


func test_bodies_cross_the_moat_on_each_bridge() -> void:
	# East bridge (y -128), west (y 128), north (x -384), south (x 384).
	for mask in [CollisionLayers.MASK_PLAYER_BODY, CollisionLayers.MASK_ENEMY_BODY_GROUND]:
		assert_float(_probe(mask, Vector2(800, -128), Vector2(1100, -128)).x).append_failure_message("east bridge blocked").is_greater_equal(1099.0)
		assert_float(_probe(mask, Vector2(-800, 128), Vector2(-1100, 128)).x).append_failure_message("west bridge blocked").is_less_equal(-1099.0)
		assert_float(_probe(mask, Vector2(-384, -400), Vector2(-384, -760)).y).append_failure_message("north bridge blocked").is_less_equal(-759.0)
		assert_float(_probe(mask, Vector2(384, 480), Vector2(384, 760)).y).append_failure_message("south bridge blocked").is_greater_equal(759.0)


func test_a_body_one_step_off_a_bridge_is_stopped() -> void:
	# The east bridge is y -192..-64; a 14 px circle at y -40 is on water.
	var end: Vector2 = _probe(CollisionLayers.MASK_ENEMY_BODY_GROUND, Vector2(700, -40), Vector2(1100, -40))
	assert_float(end.x).is_less_equal(832.0)


func test_rock_outcrop_and_ruin_stop_bodies() -> void:
	# North-east outcrop: x 256..512, y -384..-128 (with its cliff row).
	var end: Vector2 = _probe(CollisionLayers.MASK_PLAYER_BODY, Vector2(100, -250), Vector2(700, -250))
	assert_float(end.x).append_failure_message("walked into the outcrop: %s" % end).is_less_equal(256.0)
	# Ruined castle at (-560, -204) footprint 288 x 112.
	end = _probe(CollisionLayers.MASK_ENEMY_BODY_GROUND, Vector2(-900, -204), Vector2(-100, -204))
	assert_float(end.x).append_failure_message("walked into the castle ruin: %s" % end).is_less_equal(-704.0 + 1.0)
	# A timber pile in front of the north bridge exit: x -464..-304, y -324..-228.
	end = _probe(CollisionLayers.MASK_ENEMY_BODY_GROUND, Vector2(-384, -480), Vector2(-384, -150))
	assert_float(end.y).is_less_equal(-324.0)


func test_projectiles_fly_over_water_but_are_stopped_by_solids() -> void:
	var over_water: Vector2 = _probe(CollisionLayers.MASK_PLAYER_PROJECTILE, Vector2(700, 300), Vector2(1100, 300), 6.0)
	assert_float(over_water.x).append_failure_message("a shot must cross the moat, stopped at %s" % over_water).is_greater_equal(1099.0)
	var enemy_shot: Vector2 = _probe(CollisionLayers.MASK_ENEMY_PROJECTILE, Vector2(-700, 300), Vector2(-1100, 300), 6.0)
	assert_float(enemy_shot.x).is_less_equal(-1099.0)
	var into_rock: Vector2 = _probe(CollisionLayers.MASK_PLAYER_PROJECTILE, Vector2(100, -250), Vector2(700, -250), 6.0)
	assert_float(into_rock.x).append_failure_message("a shot must stop at the outcrop: %s" % into_rock).is_less_equal(256.0)
	var tower_shot: Vector2 = _probe(CollisionLayers.MASK_TOWER_PROJECTILE, Vector2(100, -250), Vector2(700, -250), 6.0)
	assert_float(tower_shot.x).is_less_equal(256.0)


func test_the_outer_wall_still_holds() -> void:
	var end: Vector2 = _probe(CollisionLayers.MASK_PLAYER_BODY, Vector2(1100, -128), Vector2(1400, -128))
	assert_float(end.x).is_less_equal(1216.0)

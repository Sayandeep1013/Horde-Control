extends GdUnitTestSuite
## Feel pass (D153): the enemy sprite must not flicker left/right when its
## heading hovers near vertical or reverses for a frame. Flips need a
## horizontal share above FACING_FLIP_HORIZONTAL_SHARE and a minimum gap of
## FACING_FLIP_MIN_INTERVAL_SECONDS between flips.

const HunterScene: PackedScene = preload("res://scenes/entities/player_hunter.tscn")
const STEP: float = 1.0 / 60.0


func _spawn() -> Array:
	var hunter: CharacterBody2D = HunterScene.instantiate()
	add_child(hunter)
	auto_free(hunter)
	var visuals: Node = hunter.get_node("Visuals")
	var sprite: AnimatedSprite2D = hunter.get_node("Visuals/AnimatedSprite2D")
	return [hunter, visuals, sprite]


func _tick(hunter: CharacterBody2D, visuals: Node, velocity: Vector2, seconds: float) -> void:
	hunter.velocity = velocity
	var steps: int = int(round(seconds / STEP))
	for _i in range(steps):
		visuals._process(STEP)


func test_near_vertical_heading_does_not_flip() -> void:
	var f: Array = _spawn()
	_tick(f[0], f[1], Vector2(100.0, 0.0), 0.5)
	assert_bool(f[2].flip_h).is_false()
	# 20 degrees off vertical: horizontal share ~0.34 < 0.35 -> stays right-facing even though x < 0
	_tick(f[0], f[1], Vector2(-34.0, 94.0), 1.0)
	assert_bool(f[2].flip_h).is_false()


func test_clear_reversal_flips_once_after_the_interval() -> void:
	var f: Array = _spawn()
	_tick(f[0], f[1], Vector2(100.0, 0.0), 0.5)
	_tick(f[0], f[1], Vector2(-100.0, 0.0), 0.5)
	assert_bool(f[2].flip_h).is_true()


func test_rapid_oscillation_flips_at_most_once_per_interval() -> void:
	var f: Array = _spawn()
	_tick(f[0], f[1], Vector2(100.0, 0.0), 0.5)
	var flips: int = 0
	var previous: bool = f[2].flip_h
	for i in range(60): # one second of per-frame direction reversals
		f[0].velocity = Vector2(100.0 if i % 2 == 0 else -100.0, 0.0)
		f[1]._process(STEP)
		if f[2].flip_h != previous:
			flips += 1
			previous = f[2].flip_h
	var allowed: int = int(1.0 / 0.2) + 1 # FACING_FLIP_MIN_INTERVAL_SECONDS
	assert_int(flips).append_failure_message("flips in 1 s of per-frame reversal: %d" % flips).is_less_equal(allowed)

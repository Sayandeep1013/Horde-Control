extends Node2D
class_name FallingArrow
## One Arrow Storm arrow (docs/31 §3.2): the arrow sprite drops from above onto
## `target`, then `on_land` applies the impact. Reuses the player arrow sprite.

const ARROW_TEXTURE: Texture2D = preload("res://assets/sprite_frames/arrow_projectile.tres")
const DROP_HEIGHT_PX: float = 300.0
const FALL_SECONDS: float = 0.26

var target: Vector2
var on_land: Callable = Callable()
var _start: float = 0.0


static func spawn(parent: Node, p_target: Vector2, p_on_land: Callable) -> FallingArrow:
	var a := FallingArrow.new()
	a.target = p_target
	a.on_land = p_on_land
	parent.add_child(a)
	return a


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	z_as_relative = false
	z_index = 47
	_start = SimClock.now
	global_position = target + Vector2(0.0, -DROP_HEIGHT_PX)
	rotation = PI * 0.5 # the sprite points right; rotate to point down


func _physics_process(_delta: float) -> void:
	var k: float = clampf((SimClock.now - _start) / FALL_SECONDS, 0.0, 1.0)
	global_position = target + Vector2(0.0, -DROP_HEIGHT_PX * (1.0 - k * k))
	if k >= 1.0:
		if on_land.is_valid():
			on_land.call(target)
		PulseRing.spawn(get_parent(), target, 26.0, 0.25, Color(0.95, 0.85, 0.55), 3.0, false)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = ARROW_TEXTURE.get_size()
	draw_texture(ARROW_TEXTURE, -s * 0.5)

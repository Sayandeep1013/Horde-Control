extends Node2D
class_name ArenaDustPuff
## Short dust puff for a breaking crate (visual only, SimClock-driven so it
## freezes with the tree). Draws a few expanding, fading pixel-style blobs.

const DURATION: float = 0.4
const Z_INDEX: int = 44

var _start: float = 0.0
var _seed_offset: float = 0.0


static func spawn(parent: Node, world_position: Vector2, tint: Color = Color(0.82, 0.74, 0.58)) -> ArenaDustPuff:
	var p := ArenaDustPuff.new()
	p.modulate = tint
	parent.add_child(p)
	p.global_position = world_position
	return p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = Z_INDEX
	_start = SimClock.now
	_seed_offset = fmod(global_position.x * 0.013 + global_position.y * 0.007, TAU)


func _process(_delta: float) -> void:
	if SimClock.now - _start >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf((SimClock.now - _start) / DURATION, 0.0, 1.0)
	var alpha: float = 1.0 - t
	for i in 7:
		var a: float = _seed_offset + float(i) * TAU / 7.0
		var r: float = 6.0 + 26.0 * t
		var c := Color(1, 1, 1, 0.8 * alpha)
		var s: float = 8.0 * (1.0 - t * 0.5)
		draw_rect(Rect2(Vector2(cos(a), sin(a) * 0.6) * r - Vector2(s, s) * 0.5, Vector2(s, s)), c)

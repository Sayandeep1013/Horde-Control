extends Node2D
class_name PulseRing
## Expanding ring (Frost Nova, Frost Ward, War Horn pulse). Visual only: the
## caller applies damage / buffs. Squashed vertically like GroundTelegraph so it
## reads on the ground plane. SimClock-driven so it freezes with the pause.

var max_radius: float = 100.0
var duration: float = 0.5
var color: Color = Color(0.6, 0.85, 1.0)
var line_width: float = 5.0
var filled: bool = true
var _start: float = 0.0


static func spawn(parent: Node, world_position: Vector2, radius: float, p_duration: float, p_color: Color, p_width: float = 5.0, p_filled: bool = true) -> PulseRing:
	var r := PulseRing.new()
	r.max_radius = radius
	r.duration = maxf(0.05, p_duration)
	r.color = p_color
	r.line_width = p_width
	r.filled = p_filled
	parent.add_child(r)
	r.global_position = world_position
	return r


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 44
	_start = SimClock.now


func progress() -> float:
	return clampf((SimClock.now - _start) / duration, 0.0, 1.0)


func _process(_delta: float) -> void:
	queue_redraw()
	if progress() >= 1.0:
		queue_free()


func _draw() -> void:
	var p: float = progress()
	var eased: float = 1.0 - pow(1.0 - p, 2.0)
	var r: float = max_radius * eased
	var alpha: float = 1.0 - p
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	if filled:
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.16 * alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.9 * alpha), line_width, false)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 64, Color(1, 1, 1, 0.35 * alpha), line_width * 0.5, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

extends Node2D
class_name LineTelegraph
## PT-SWARM line warning (charges, fissures, rolling charges, aimed lanes). The
## same visual language as GroundTelegraph: a danger-red lane whose fill grows
## from the origin over the wind-up in SimClock time, with a solid edge, so a
## player reads "this strip is about to be hit" at a glance. Visual only; the
## owner applies damage and frees it (or it frees itself after `duration`
## when `auto_free` is set).

const Z: int = 40

var from_position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var length: float = 300.0
var width: float = 60.0
var duration: float = 1.0
var color: Color = Color(0.9, 0.15, 0.1)
var auto_free: bool = false
var _t0: float = 0.0


static func spawn(parent: Node, from_pos: Vector2, dir: Vector2, p_length: float, p_width: float, p_duration: float, p_auto_free: bool = false, p_color: Color = Color(0.9, 0.15, 0.1)) -> LineTelegraph:
	var t := LineTelegraph.new()
	t.from_position = from_pos
	t.direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector2.RIGHT
	t.length = p_length
	t.width = p_width
	t.duration = maxf(0.01, p_duration)
	t.auto_free = p_auto_free
	t.color = p_color
	parent.add_child(t)
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = Z
	top_level = true
	global_position = from_position
	_t0 = SimClock.now


func get_progress() -> float:
	return clampf((SimClock.now - _t0) / duration, 0.0, 1.0)


func time_left() -> float:
	return maxf(0.0, duration - (SimClock.now - _t0))


## True when `point` lies inside the lane (plus `margin` px).
func contains(point: Vector2, margin: float = 0.0) -> bool:
	return LineTelegraph.lane_contains(from_position, direction, length, width, point, margin)


static func lane_contains(from_pos: Vector2, dir: Vector2, p_length: float, p_width: float, point: Vector2, margin: float = 0.0) -> bool:
	var rel: Vector2 = point - from_pos
	var along: float = rel.dot(dir)
	if along < -margin or along > p_length + margin:
		return false
	return absf(rel.dot(dir.orthogonal())) <= p_width * 0.5 + margin


func _process(_delta: float) -> void:
	queue_redraw()
	if auto_free and get_progress() >= 1.0:
		queue_free()


func _draw() -> void:
	var p: float = get_progress()
	var side: Vector2 = direction.orthogonal() * (width * 0.5)
	var far: Vector2 = direction * length
	var fill := color
	fill.a = 0.16 + 0.24 * p
	draw_colored_polygon(PackedVector2Array([-side, side, far + side, far - side]), Color(color, 0.10))
	draw_colored_polygon(PackedVector2Array([-side, side, far * p + side, far * p - side]), fill)
	var edge := color
	edge.a = 0.9
	draw_polyline(PackedVector2Array([-side, -side + far, side + far, side, -side]), edge, 3.0)

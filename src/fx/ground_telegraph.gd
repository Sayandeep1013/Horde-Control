extends Node2D
class_name GroundTelegraph
## v1.0 shared ground warning (WP0, decision D179; docs/31 §5). A flattened
## circle that fills from the centre over `duration` seconds of SimClock time
## to show where an area attack will land. Visual only; the caller applies
## damage when `time_left()` reaches zero (or on its own timer) and frees it.
##
## Colours follow docs/19's shape language: red/danger for attacks on the
## player or Tower, the ability's own tint for player abilities.

const TELEGRAPH_Z_INDEX: int = 40
## Matches the pack's top-down squash used by enemy telegraph rings.
const Y_SQUASH: float = 0.55

var radius: float = 64.0
var duration: float = 1.0
var color: Color = Color(0.9, 0.15, 0.1)
var auto_free: bool = true

var _start: float = 0.0


static func spawn(parent: Node, world_position: Vector2, p_radius: float, p_duration: float, p_color: Color = Color(0.9, 0.15, 0.1), p_auto_free: bool = true) -> GroundTelegraph:
	var t := GroundTelegraph.new()
	t.radius = p_radius
	t.duration = maxf(0.01, p_duration)
	t.color = p_color
	t.auto_free = p_auto_free
	parent.add_child(t)
	t.global_position = world_position
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = TELEGRAPH_Z_INDEX
	_start = SimClock.now


func get_progress() -> float:
	return clampf((SimClock.now - _start) / duration, 0.0, 1.0)


func time_left() -> float:
	return maxf(0.0, duration - (SimClock.now - _start))


func _process(_delta: float) -> void:
	queue_redraw()
	if auto_free and get_progress() >= 1.0:
		queue_free()


func _draw() -> void:
	var p: float = get_progress()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Y_SQUASH))
	var fill := color
	fill.a = 0.18 + 0.22 * p
	draw_circle(Vector2.ZERO, radius * p, fill)
	var edge := color
	edge.a = 0.85
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 3.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

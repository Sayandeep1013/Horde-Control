extends Node2D
class_name LightningBolt
## Storm Bolt visual: a jagged polyline through the struck points that fades in
## LIFETIME seconds. Drawn with lines (the lightning_segment.png sprite from
## WP-ASSETS is a stretched texture; a drawn bolt reads cleaner at any length).

const LIFETIME_SECONDS: float = 0.2
const JAG_PX: float = 14.0 # D351: bigger bolts read at swarm scale
const GLOW_WIDTH_PX: float = 16.0
const CORE_WIDTH_PX: float = 6.0

var points: PackedVector2Array = PackedVector2Array()
var _start: float = 0.0
var _jagged: PackedVector2Array = PackedVector2Array()
var glow_color: Color = Color(0.45, 0.6, 1.0, 0.55)
var width_scale: float = 1.0


static func spawn(parent: Node, p_points: PackedVector2Array, p_glow: Color = Color(0.45, 0.6, 1.0, 0.55), p_width_scale: float = 1.0) -> LightningBolt:
	var b := LightningBolt.new()
	b.points = p_points
	b.glow_color = p_glow
	b.width_scale = p_width_scale
	parent.add_child(b)
	return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	z_as_relative = false
	z_index = 48
	global_position = Vector2.ZERO
	_start = SimClock.now
	var rng := RandomNumberGenerator.new()
	rng.seed = int(points[0].x * 7.0 + points[0].y * 13.0) if points.size() > 0 else 1
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var normal: Vector2 = (b - a).orthogonal().normalized()
		var steps: int = maxi(2, int(a.distance_to(b) / 26.0))
		_jagged.append(a)
		for s in range(1, steps):
			_jagged.append(a.lerp(b, float(s) / float(steps)) + normal * rng.randf_range(-JAG_PX, JAG_PX))
	if points.size() > 0:
		_jagged.append(points[points.size() - 1])


func _process(_delta: float) -> void:
	if SimClock.now - _start >= LIFETIME_SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _jagged.size() < 2:
		return
	var k: float = 1.0 - clampf((SimClock.now - _start) / LIFETIME_SECONDS, 0.0, 1.0)
	draw_polyline(_jagged, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * k), GLOW_WIDTH_PX * width_scale, true)
	draw_polyline(_jagged, Color(0.85, 0.92, 1.0, k), CORE_WIDTH_PX * width_scale, true)

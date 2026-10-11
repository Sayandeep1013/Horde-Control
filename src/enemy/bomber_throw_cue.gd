extends Node2D
class_name BomberThrowCue
## Bomber shape cue (D206; Register "Bomber readability"): a lit dynamite stick
## held overhead with a flickering fuse spark, drawn above the health bar while
## the Bomber has a throw ready, so a ranged bomber reads at gameplay zoom
## without relying on colour. Cosmetic only (wall-clock flicker). The Hunter,
## Seeker and Opportunist carry nothing overhead.

const OFFSET_Y_PX: float = -104.0 # above the health bar (-76)
const STICK_SIZE_PX := Vector2(9.0, 22.0)
const STICK_COLOR := Color(0.86, 0.2, 0.2)
const OUTLINE_COLOR := Color(0.08, 0.05, 0.05)
const BAND_COLOR := Color(0.95, 0.85, 0.5)
const SPARK_COLOR := Color(1.0, 0.8, 0.2)
const SPARK_CORE_COLOR := Color(1.0, 0.98, 0.8)

var _behavior: BomberBehavior = null


func _ready() -> void:
	z_index = 2
	var owner_body: Node = get_parent()
	_behavior = owner_body.get_node_or_null("Behavior") as BomberBehavior if owner_body != null else null
	position = Vector2(0.0, OFFSET_Y_PX)


func _process(_delta: float) -> void:
	var armed: bool = _behavior != null and _behavior.is_armed()
	if visible != armed:
		visible = armed
	if armed:
		queue_redraw()


func _draw() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	var tilt: float = deg_to_rad(18.0)
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	var r := Rect2(-STICK_SIZE_PX.x * 0.5, -STICK_SIZE_PX.y * 0.5, STICK_SIZE_PX.x, STICK_SIZE_PX.y)
	draw_rect(r.grow(2.0), OUTLINE_COLOR, true)
	draw_rect(r, STICK_COLOR, true)
	draw_rect(Rect2(r.position.x, r.position.y + 6.0, r.size.x, 3.0), BAND_COLOR, true)
	# Fuse and spark: the spark flickers faster as the throw nears.
	var fuse_top := Vector2(0.0, r.position.y - 7.0)
	draw_line(Vector2(0.0, r.position.y), fuse_top, OUTLINE_COLOR, 3.0)
	draw_line(Vector2(0.0, r.position.y), fuse_top, Color(0.6, 0.45, 0.3), 1.5)
	var due: float = _behavior.seconds_to_throw() if _behavior != null else 3.0
	var rate: float = 9.0 if due > 1.0 else 18.0
	var flick: float = 0.5 + 0.5 * sin(t * rate)
	var radius: float = 3.5 + 2.5 * flick
	draw_circle(fuse_top, radius + 1.5, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.45))
	draw_circle(fuse_top, radius, SPARK_COLOR)
	draw_circle(fuse_top, radius * 0.5, SPARK_CORE_COLOR)
	for i in 3:
		var a: float = t * 7.0 + float(i) * 2.1
		draw_circle(fuse_top + Vector2(cos(a), sin(a) - 0.6) * (5.0 + 3.0 * flick), 1.2, SPARK_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

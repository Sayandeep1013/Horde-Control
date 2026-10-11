extends Node2D
class_name ShamanCue
## Goblin Shaman shape cue (D349): a staff with a glowing orb held up beside
## the body, so the caster reads at gameplay zoom without relying on its teal
## colour. The orb swells and brightens over the 0.6 s cast wind-up. Cosmetic
## only (wall-clock shimmer).

const OFFSET := Vector2(22.0, -58.0)
const STAFF_COLOR := Color(0.45, 0.28, 0.14)
const OUTLINE := Color(0.08, 0.05, 0.03)
const ORB_COLOR := Color(1.0, 0.55, 0.15)
const ORB_CORE := Color(1.0, 0.95, 0.7)

var _behavior: ShamanBehavior = null


func _ready() -> void:
	z_index = 2
	var body: Node = get_parent()
	_behavior = body.get_node_or_null("Behavior") as ShamanBehavior if body != null else null
	position = OFFSET


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var charge: float = _behavior.get_charge() if _behavior != null else 0.0
	var t: float = Time.get_ticks_msec() / 1000.0
	draw_line(Vector2(0, 0), Vector2(-4, 44), OUTLINE, 6.0)
	draw_line(Vector2(0, 0), Vector2(-4, 44), STAFF_COLOR, 3.0)
	var r: float = 6.0 + 5.0 * charge + 0.8 * sin(t * 6.0)
	draw_circle(Vector2.ZERO, r + 6.0 + 6.0 * charge, Color(ORB_COLOR, 0.25 + 0.35 * charge))
	draw_circle(Vector2.ZERO, r + 2.0, OUTLINE)
	draw_circle(Vector2.ZERO, r, ORB_COLOR)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.45, ORB_CORE)

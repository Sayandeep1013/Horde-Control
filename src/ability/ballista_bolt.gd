extends Node2D
class_name BallistaBolt
## Ballista bolt: flies along a fixed line and pierces EVERYTHING on it
## (docs/31 §4.3). Each enemy within HIT_RADIUS of the bolt is hit once.
## Damage is applied when the bolt reaches the enemy (hit resolution), as the
## Tower's "ballista" source.

const SPEED_PX_PER_S: float = 1100.0 # Register: Ballista bolt speed
const HIT_RADIUS_PX: float = 22.0 # Register: Ballista bolt hit radius

var direction: Vector2 = Vector2.RIGHT
var travel_left: float = 600.0
var damage: float = 40.0
var _hit: Array = []
var _tex: Texture2D = null


static func spawn(parent: Node, origin: Vector2, p_direction: Vector2, p_range: float, p_damage: float) -> BallistaBolt:
	var b := BallistaBolt.new()
	b.direction = p_direction.normalized()
	b.travel_left = p_range
	b.damage = p_damage
	parent.add_child(b)
	b.global_position = origin
	b.rotation = b.direction.angle()
	return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 46
	_tex = AbilityNode.load_v1_texture("ballista_bolt")
	Sfx.play("tower_bolt", global_position)


func _physics_process(delta: float) -> void:
	var step: float = minf(SPEED_PX_PER_S * delta, travel_left)
	# Sweep in HIT_RADIUS-sized increments so a fast bolt cannot skip an enemy.
	var moved: float = 0.0
	while moved < step:
		var s: float = minf(HIT_RADIUS_PX * 0.8, step - moved)
		global_position += direction * s
		moved += s
		for e in AbilityDamage.enemies_in_radius(global_position, HIT_RADIUS_PX + 12.0):
			if _hit.has(e):
				continue
			_hit.append(e)
			AbilityDamage.hit(e, damage * AbilitySynergy.shatter_mult(e), AbilityIds.BALLISTA, &"tower", false)
	travel_left -= step
	if travel_left <= 0.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _tex != null:
		draw_texture(_tex, -_tex.get_size() * 0.5)
		return
	draw_line(Vector2(-26, 0), Vector2(14, 0), Color(0.45, 0.3, 0.15), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(14, -6), Vector2(28, 0), Vector2(14, 6)]), Color(0.85, 0.85, 0.9))
	draw_line(Vector2(-26, 0), Vector2(-32, -5), Color(0.9, 0.9, 0.85), 2.0)
	draw_line(Vector2(-26, 0), Vector2(-32, 5), Color(0.9, 0.9, 0.85), 2.0)

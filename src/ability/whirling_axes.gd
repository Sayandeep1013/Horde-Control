extends AbilityNode
class_name WhirlingAxesAbility
## Whirling Axes (docs/31 §4.2): 1-4 axes orbit the player at 72-90 px; an axe
## hits an enemy at most once per 0.45 s. Axe sprite from WP-ASSETS
## (assets/sprites/v1/axe.png) with a drawn fallback.

const SPIN_RAD_PER_S: float = 4.2 # Register: Whirling Axes orbit speed
const AXE_HIT_RADIUS_PX: float = 22.0 # Register: Whirling Axes hit radius

var _angle: float = 0.0
var _next_hit: Dictionary = {} # "axe_index:enemy_id" -> time
var _tex: Texture2D = null


func _ready() -> void:
	super._ready()
	_tex = load_v1_texture("axe")
	z_index = 26


func _orbit_radius() -> float:
	return v("radius") * AbilityDamage.area_scale()


func axe_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var count: int = AbilityCatalog.ivalue(ability_id, "count", level)
	for i in count:
		out.append(global_position + Vector2.from_angle(_angle + TAU * float(i) / float(count)) * _orbit_radius())
	return out


func _physics_process(delta: float) -> void:
	global_position = owner_pos()
	_angle = fmod(_angle + SPIN_RAD_PER_S * delta, TAU)
	var now: float = SimClock.now
	var positions: Array[Vector2] = axe_positions()
	for i in positions.size():
		for e in AbilityDamage.enemies_in_radius(positions[i], AXE_HIT_RADIUS_PX + 8.0):
			var key: String = "%d:%d" % [i, e.get_instance_id()]
			if now < float(_next_hit.get(key, -1.0)):
				continue
			if AbilityDamage.hit(e, dmg(), ability_id, &"player", true) > 0.0:
				_next_hit[key] = now + v("rehit")
				Sfx.play("axe_hit", e.global_position)
	if _next_hit.size() > 256:
		for k in _next_hit.keys():
			if float(_next_hit[k]) < now:
				_next_hit.erase(k)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var count: int = AbilityCatalog.ivalue(ability_id, "count", level)
	for i in count:
		var ang: float = _angle + TAU * float(i) / float(count)
		var pos: Vector2 = Vector2.from_angle(ang) * _orbit_radius()
		draw_set_transform(pos, ang * 3.0, Vector2.ONE)
		if _tex != null:
			draw_texture(_tex, -_tex.get_size() * 0.5)
		else:
			draw_line(Vector2(0, 12), Vector2(0, -12), Color(0.45, 0.3, 0.15), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(16, -8), Vector2(18, 4), Vector2(0, 0)]), Color(0.75, 0.78, 0.85))
			draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(16, -8), Vector2(18, 4), Vector2(0, 0), Vector2(0, -12)]), Color(0.12, 0.12, 0.15), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

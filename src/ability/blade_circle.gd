extends AbilityNode
class_name BladeCircleAbility
## Blade Circle (PT-POWER D356, Archero's "Blade Circle"): a ring of 4-8 spinning blades
## orbits the player at a wide 220 px radius and shreds whatever walks into it, 28-52 damage
## per hit, one hit per blade per enemy per 0.4 s. Blades are tested point-wise against the
## spatial index (one small radius query each), never against every enemy.

const SPRITE_SCALE: float = 2.2 # Register: Blade Circle sprite scale

var _angle: float = 0.0
var _next_hit: Dictionary = {} # (enemy id << 4 | blade index) -> time
var _tex: Texture2D = null


func _ready() -> void:
	super._ready()
	_tex = load_v1_texture("blade")
	z_index = 26
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func ring_radius() -> float:
	return v("radius") * AbilityDamage.area_scale()


func blade_count() -> int:
	return AbilityCatalog.ivalue(ability_id, "count", level)


func blade_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var count: int = blade_count()
	var r: float = ring_radius()
	for i in count:
		out.append(global_position + Vector2.from_angle(_angle + TAU * float(i) / float(count)) * r)
	return out


func _physics_process(delta: float) -> void:
	global_position = owner_pos()
	_angle = fmod(_angle + v("spin") * delta, TAU)
	var now: float = SimClock.now
	var reach: float = v("hit_radius") + 8.0
	var positions: Array[Vector2] = blade_positions()
	for i in positions.size():
		for e in AbilityDamage.enemies_in_radius(positions[i], reach):
			var key: int = (e.get_instance_id() << 4) | i
			if now < float(_next_hit.get(key, -1.0)):
				continue
			if AbilityDamage.hit(e, dmg(), ability_id, &"player", true) > 0.0:
				_next_hit[key] = now + v("rehit")
				Sfx.play("axe_hit", e.global_position)
	if _next_hit.size() > 512:
		for k in _next_hit.keys():
			if float(_next_hit[k]) < now:
				_next_hit.erase(k)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r: float = ring_radius()
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(0.9, 0.95, 1.0, 0.30), 4.0, true) # the blade path
	var count: int = blade_count()
	for i in count:
		var ang: float = _angle + TAU * float(i) / float(count)
		draw_set_transform(Vector2.from_angle(ang) * r, ang * 5.0, Vector2(SPRITE_SCALE, SPRITE_SCALE))
		if _tex != null:
			draw_texture(_tex, -_tex.get_size() * 0.5)
		else:
			draw_circle(Vector2.ZERO, 14.0, Color(0.8, 0.85, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

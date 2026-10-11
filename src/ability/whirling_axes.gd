extends AbilityNode
class_name WhirlingAxesAbility
## Whirling Axes (docs/31 §4.2; PT-POWER D351): 2-6 big axes orbit the player at 110-160 px
## (drawn at twice the sprite size, hit radius 44 px); an axe hits an enemy at most once per
## 0.45 s. From level 3 each axe, in turn, flies out like a boomerang to 280 px and back every
## 2.5 s. Axe sprite from WP-ASSETS (assets/sprites/v1/axe.png) with a drawn fallback.

const SPIN_RAD_PER_S: float = 4.2 # Register: Whirling Axes orbit speed
const SPRITE_SCALE: float = 2.0 # Register: Whirling Axes sprite scale (D351)
const THROW_SECONDS: float = 1.0 # Register: Whirling Axes boomerang flight, out and back

var _angle: float = 0.0
var _next_hit: Dictionary = {} # (enemy id << 4 | axe index) -> time
var _tex: Texture2D = null


func _ready() -> void:
	super._ready()
	_tex = load_v1_texture("axe")
	z_index = 26
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _orbit_radius() -> float:
	return v("radius") * AbilityDamage.area_scale()


func axe_count() -> int:
	return AbilityCatalog.ivalue(ability_id, "count", level)


func boomerang_enabled() -> bool:
	return level >= AbilityCatalog.BOOMERANG_FIRST_LEVEL


## Distance of axe `index` from the player at SimClock time `now`: the orbit radius, or, while
## that axe is mid-throw, out to the boomerang range and back (a half sine). Throws are
## staggered so the axes do not all leave at once.
func axe_reach(index: int, now: float) -> float:
	var r0: float = _orbit_radius()
	if not boomerang_enabled():
		return r0
	var every: float = v("boomerang_every")
	var phase: float = fposmod(now - every * float(index) / float(maxi(1, axe_count())), every)
	if phase >= THROW_SECONDS:
		return r0
	var far: float = v("boomerang_range") * AbilityDamage.area_scale()
	return r0 + (far - r0) * sin(PI * phase / THROW_SECONDS)


func axe_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var count: int = axe_count()
	var now: float = SimClock.now
	for i in count:
		out.append(global_position + Vector2.from_angle(_angle + TAU * float(i) / float(count)) * axe_reach(i, now))
	return out


func _physics_process(delta: float) -> void:
	global_position = owner_pos()
	_angle = fmod(_angle + SPIN_RAD_PER_S * delta, TAU)
	var now: float = SimClock.now
	var positions: Array[Vector2] = axe_positions()
	var reach: float = v("hit_radius") + 8.0
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
	var count: int = axe_count()
	var now: float = SimClock.now
	draw_arc(Vector2.ZERO, _orbit_radius(), 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.10), 3.0, true) # the orbit path
	for i in count:
		var ang: float = _angle + TAU * float(i) / float(count)
		var pos: Vector2 = Vector2.from_angle(ang) * axe_reach(i, now)
		draw_set_transform(pos, ang * 3.0, Vector2(SPRITE_SCALE, SPRITE_SCALE))
		if _tex != null:
			draw_texture(_tex, -_tex.get_size() * 0.5)
		else:
			draw_line(Vector2(0, 12), Vector2(0, -12), Color(0.45, 0.3, 0.15), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(16, -8), Vector2(18, 4), Vector2(0, 0)]), Color(0.75, 0.78, 0.85))
			draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(16, -8), Vector2(18, 4), Vector2(0, 0), Vector2(0, -12)]), Color(0.12, 0.12, 0.15), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

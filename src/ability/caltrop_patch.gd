extends Node2D
class_name CaltropPatch
## One Caltrops spike patch (docs/31 §4.2): lasts `lifetime`, deals `damage` per
## `tick` to enemies standing on it and slows them. Source id "caltrops".

const RADIUS_PX: float = 30.0 # Register: Caltrop patch radius
const SLOW_REFRESH_SECONDS: float = 0.6

var damage: float = 10.0
var tick: float = 0.5
var slow_fraction: float = 0.25
var lifetime: float = 4.0
var _start: float = 0.0
var _next_tick: float = 0.0
var _tex: Texture2D = null


static func spawn(parent: Node, world_position: Vector2, p_damage: float, p_tick: float, p_slow: float, p_lifetime: float) -> CaltropPatch:
	var c := CaltropPatch.new()
	c.damage = p_damage
	c.tick = p_tick
	c.slow_fraction = p_slow
	c.lifetime = p_lifetime
	parent.add_child(c)
	c.global_position = world_position
	return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 12 # on the ground, under the play layer
	_start = SimClock.now
	_next_tick = _start + tick
	_tex = AbilityNode.load_v1_texture("caltrop")
	add_to_group(&"caltrop_patch")


func _physics_process(_delta: float) -> void:
	var now: float = SimClock.now
	if now >= _start + lifetime:
		queue_free()
		return
	if now >= _next_tick:
		_next_tick = now + tick
		for e in AbilityDamage.enemies_in_radius(global_position, RADIUS_PX):
			var amount: float = damage * AbilitySynergy.kindling_mult(e) # Kindling: +25% vs burning
			if AbilityDamage.hit(e, amount, AbilityIds.CALTROPS, &"player", true) > 0.0:
				StatusEffects.apply_slow(e, slow_fraction, SLOW_REFRESH_SECONDS)
				_kindle(e)


## Kindling: with Flame Arrows owned the patch ignites what stands in it, at
## Flame Arrows' own burn (dps and duration at its current level).
func _kindle(enemy: Node) -> void:
	if not AbilitySynergy.kindling_active():
		return
	var flame: AbilityNode = AbilityDamage.get_manager().get_ability_node("flame_arrows")
	if flame != null:
		StatusEffects.apply_burn(enemy, flame.dmg("dps"), flame.v("duration"), AbilityIds.CALTROPS)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf((_start + lifetime - SimClock.now) / 0.8, 0.0, 1.0)
	var tint := Color(1, 1, 1, fade)
	if _tex != null:
		for off in [Vector2(-10, 3), Vector2(8, -4), Vector2(2, 9)]:
			draw_texture(_tex, off - _tex.get_size() * 0.5, tint)
		return
	for off in [Vector2(-11, 3), Vector2(9, -4), Vector2(1, 9), Vector2(-2, -8)]:
		var pts := PackedVector2Array([off + Vector2(0, -7), off + Vector2(6, 4), off + Vector2(-6, 4)])
		draw_colored_polygon(pts, Color(0.62, 0.62, 0.68, fade))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.1, 0.1, 0.12, fade), 1.5)

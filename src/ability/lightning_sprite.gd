extends AbilityNode
class_name LightningSpriteAbility
## Lightning Sprite (PT-POWER D354, the Archero "Lightning Sprite" ability): a storm wisp
## orbits the player and, every 1.2-0.6 s, throws a chain bolt from where it floats at the
## nearest enemy within 420 px of it: 26-52 damage, chaining to 2-4 more within 200 px.
## Source id "lightning_sprite"; scales with the player ability damage terms and can crit.

const ORBIT_RAD_PER_S: float = 2.2 # Register: Lightning Sprite orbit speed
const SPRITE_SCALE: float = 2.0

var _angle: float = 0.0
var _tex: Texture2D = null


func _ready() -> void:
	super._ready()
	_tex = load_v1_texture("lightning_sprite")
	z_index = 27
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func sprite_position() -> Vector2:
	return global_position + Vector2.from_angle(_angle) * v("orbit_radius") + Vector2(0.0, -6.0 * sin(SimClock.now * 5.0))


func _physics_process(delta: float) -> void:
	global_position = owner_pos()
	_angle = fmod(_angle + ORBIT_RAD_PER_S * delta, TAU)
	if SimClock.now < _next_at:
		return
	var origin: Vector2 = sprite_position()
	var first: Node2D = AbilityDamage.nearest_enemy(origin, v("range"))
	if first == null:
		return
	_next_at = SimClock.now + v("interval")
	fire_at(first, origin)


## One chain bolt from `origin` through `first` and its chain. Returns the struck enemies.
func fire_at(first: Node2D, origin: Vector2) -> Array[Node2D]:
	var hit_list: Array[Node2D] = AbilityDamage.chain_targets(first, AbilityCatalog.ivalue(ability_id, "chains", level), v("chain_range") * AbilityDamage.area_scale())
	var pts := PackedVector2Array([origin])
	var amount: float = dmg()
	for e in hit_list:
		pts.append(e.global_position)
		AbilityDamage.hit(e, amount, ability_id, &"player", true)
	LightningBolt.spawn(fx_parent(), pts, Color(0.6, 0.9, 1.0, 0.6), 0.8)
	Sfx.play("lightning", first.global_position)
	return hit_list


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p: Vector2 = sprite_position() - global_position
	draw_circle(p, 22.0, Color(0.5, 0.85, 1.0, 0.18 + 0.08 * sin(SimClock.now * 9.0)))
	if _tex != null:
		draw_set_transform(p, 0.0, Vector2(SPRITE_SCALE, SPRITE_SCALE))
		draw_texture(_tex, -_tex.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(p, 10.0, Color(0.85, 0.95, 1.0))

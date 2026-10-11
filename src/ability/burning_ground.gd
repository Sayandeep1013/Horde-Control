extends Node2D
class_name BurningGround
## Firebomb's lingering fire (docs/31 §3.2: 4 s at 20 dps). Damage ticks every
## TICK seconds through AbilityDamage (source "firebomb"). Uses the Tiny Swords
## Fire.png strip (7 frames of 128 px) as flames around the radius.

const FIRE_SHEET: Texture2D = preload("res://assets/third_party/tiny_swords/Effects/Fire/Fire.png")
const FIRE_FRAMES: int = 7
const TICK_SECONDS: float = 0.5

var radius: float = 110.0
var dps: float = 20.0
var lifetime: float = 4.0
var source_id: String = "firebomb"
var _start: float = 0.0
var _next_tick: float = 0.0


static func spawn(parent: Node, world_position: Vector2, p_radius: float, p_dps: float, p_lifetime: float, p_source: String) -> BurningGround:
	var g := BurningGround.new()
	g.radius = p_radius
	g.dps = p_dps
	g.lifetime = p_lifetime
	g.source_id = p_source
	parent.add_child(g)
	g.global_position = world_position
	return g


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = 41
	_start = SimClock.now
	_next_tick = _start + TICK_SECONDS


func _physics_process(_delta: float) -> void:
	var now: float = SimClock.now
	while now >= _next_tick and _next_tick < _start + lifetime + 0.001:
		AbilityDamage.hit_area(global_position, radius, dps * TICK_SECONDS * StatusEffects.get_burn_damage_multiplier(), source_id, &"player", false)
		_next_tick += TICK_SECONDS
	if now >= _start + lifetime:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t: float = SimClock.now - _start
	var fade: float = clampf((lifetime - t) / 0.6, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.4, 0.05, 0.16 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.1, 0.7 * fade), 3.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Flame tufts spread inside the ring, each animated out of phase.
	for i in 7:
		var ang: float = float(i) * TAU / 7.0 + 0.4
		var rr: float = radius * (0.35 if i % 2 == 0 else 0.7)
		var pos := Vector2(cos(ang), sin(ang) * 0.55) * rr
		var frame: int = (int(t * 10.0) + i) % FIRE_FRAMES
		draw_texture_rect_region(FIRE_SHEET, Rect2(pos.x - 32.0, pos.y - 56.0, 64, 64), Rect2(frame * 128, 0, 128, 128), Color(1, 1, 1, fade))

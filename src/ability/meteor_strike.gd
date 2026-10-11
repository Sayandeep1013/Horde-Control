extends Node2D
class_name MeteorStrike
## One Meteor Shower meteor (PT-POWER D355): a GroundTelegraph ring fills for `delay` seconds,
## a flaming rock drops in over the last FALL_SECONDS, then `on_land(position)` applies the
## damage and the shared ExplosionFx plays. SimClock-driven so it freezes with the pause.

const FALL_SECONDS: float = 0.45 # Register: Meteor fall time
const DROP_HEIGHT_PX: float = 620.0
const DROP_SIDEWAYS_PX: float = -240.0 # the rock comes in from the upper left
const SPRITE_SCALE: float = 2.4
const TELEGRAPH_COLOR: Color = Color(1.0, 0.4, 0.12)

var target: Vector2
var radius: float = 120.0
var delay: float = 0.9
var on_land: Callable = Callable()
var _start: float = 0.0
var _telegraph: GroundTelegraph = null
var _tex: Texture2D = null


static func spawn(parent: Node, p_target: Vector2, p_radius: float, p_delay: float, p_on_land: Callable) -> MeteorStrike:
	var m := MeteorStrike.new()
	m.target = p_target
	m.radius = p_radius
	m.delay = maxf(FALL_SECONDS, p_delay)
	m.on_land = p_on_land
	parent.add_child(m)
	return m


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	z_as_relative = false
	z_index = 47
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_start = SimClock.now
	_tex = AbilityNode.load_v1_texture("meteor")
	global_position = target
	_telegraph = GroundTelegraph.spawn(get_parent(), target, radius, delay, TELEGRAPH_COLOR, false)


func fall_progress() -> float:
	return clampf((SimClock.now - _start - (delay - FALL_SECONDS)) / FALL_SECONDS, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if SimClock.now - _start >= delay:
		_land()
		return
	queue_redraw()


func _land() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	ExplosionFx.spawn(get_parent(), target, radius)
	Sfx.play("explosion", target)
	if on_land.is_valid():
		on_land.call(target)
	queue_free()


func _draw() -> void:
	var k: float = fall_progress()
	if k <= 0.0:
		return
	# top_level with global_position = target, so the local origin is the impact point.
	var off := Vector2(DROP_SIDEWAYS_PX, -DROP_HEIGHT_PX) * (1.0 - k * k)
	if _tex != null:
		draw_set_transform(off, atan2(off.x, -off.y), Vector2(SPRITE_SCALE, SPRITE_SCALE))
		draw_texture(_tex, -_tex.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(off, 22.0, Color(1.0, 0.5, 0.15))

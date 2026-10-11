extends Node2D
class_name LobbedBomb
## A thrown or lobbed projectile that lands, optionally fuses, then calls
## `on_land` (damage is the caller's, applied at that moment, not at launch).
## Used by Dynamite Satchel and Firebomb (the Tiny Swords TNT Dynamite.png,
## 6 frames of 64 px) and by the Catapult (rock sprite or a drawn rock).
## A GroundTelegraph marks the landing ring for flight + fuse. SimClock-driven.

const DYNAMITE_SHEET: Texture2D = preload("res://assets/third_party/tiny_swords/Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png")
const DYNAMITE_FRAMES: int = 6
const ARC_HEIGHT_PX: float = 110.0
const DYNAMITE_DRAW_PX: float = 104.0 # D351: the stick reads at swarm scale (was 64)
const ROCK_SCALE: float = 1.7

var visual: String = "dynamite" # "dynamite" | "rock"
var from_pos: Vector2
var to_pos: Vector2
var flight: float = 0.5
var fuse: float = 0.0
var blast_radius: float = 70.0
var telegraph_color: Color = Color(1.0, 0.55, 0.1)
var on_land: Callable = Callable()
var _start: float = 0.0
var _landed: bool = false
var _rock_tex: Texture2D = null
var _telegraph: GroundTelegraph = null


static func spawn(parent: Node, p_visual: String, p_from: Vector2, p_to: Vector2, p_flight: float, p_fuse: float, p_radius: float, p_on_land: Callable, p_color: Color = Color(1.0, 0.55, 0.1)) -> LobbedBomb:
	var b := LobbedBomb.new()
	b.visual = p_visual
	b.from_pos = p_from
	b.to_pos = p_to
	b.flight = maxf(0.05, p_flight)
	b.fuse = maxf(0.0, p_fuse)
	b.blast_radius = p_radius
	b.on_land = p_on_land
	b.telegraph_color = p_color
	parent.add_child(b)
	return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	top_level = true
	z_as_relative = false
	z_index = 46
	global_position = from_pos
	_start = SimClock.now
	texture_hint()
	_telegraph = GroundTelegraph.spawn(get_parent(), to_pos, blast_radius, flight + fuse, telegraph_color, false)
	if visual == "dynamite":
		Sfx.play("fuse", from_pos)


func texture_hint() -> void:
	if visual == "rock":
		_rock_tex = AbilityNode.load_v1_texture("catapult_rock")


func _physics_process(_delta: float) -> void:
	var t: float = SimClock.now - _start
	if t < flight:
		var k: float = t / flight
		var ground: Vector2 = from_pos.lerp(to_pos, k)
		global_position = ground + Vector2(0.0, -4.0 * ARC_HEIGHT_PX * k * (1.0 - k))
	else:
		_landed = true
		global_position = to_pos
		if t >= flight + fuse:
			_detonate()
			return
	queue_redraw()


func _detonate() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	if on_land.is_valid():
		on_land.call(to_pos)
	queue_free()


func _draw() -> void:
	var t: float = SimClock.now - _start
	if visual == "dynamite":
		var frame: int = int(t * 12.0) % DYNAMITE_FRAMES
		draw_texture_rect_region(DYNAMITE_SHEET, Rect2(-DYNAMITE_DRAW_PX * 0.5, -DYNAMITE_DRAW_PX * 0.5, DYNAMITE_DRAW_PX, DYNAMITE_DRAW_PX), Rect2(frame * 64, 0, 64, 64), Color.WHITE if not _landed or int(t * 14.0) % 2 == 0 else Color(1.6, 1.2, 1.2))
	elif _rock_tex != null:
		draw_set_transform(Vector2.ZERO, t * 5.0, Vector2(ROCK_SCALE, ROCK_SCALE))
		draw_texture(_rock_tex, -_rock_tex.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2.ZERO, 14.0, Color(0.35, 0.3, 0.28))
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 20, Color(0.15, 0.12, 0.1), 3.0)
		draw_circle(Vector2(-4, -4), 4.0, Color(0.55, 0.5, 0.45))

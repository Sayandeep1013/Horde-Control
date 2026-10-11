extends Node2D
class_name EnemyBomb
## v1.0 (WP-ENEMIES, docs/31 §5.1-5.3): a lobbed enemy explosive. Shows a
## GroundTelegraph ring at the landing point for the whole flight, optionally
## draws the Tiny Swords Dynamite sprite flying an arc to it, then detonates:
## ExplosionFx plus EnemyBlast damage to the player and the Tower. Also used
## with `show_dynamite = false` for ground blasts (Volatile elite death,
## boss slams, Siege Bomb) where there is nothing to throw.
## Timing is SimClock time; the node is PROCESS_MODE_PAUSABLE so it freezes
## with the tree. Values (radius, damage, flight) are passed by the caller from
## the Register's "v1.0 Enemies, Bosses & Waves" rows.

const DYNAMITE_SHEET: Texture2D = preload("res://assets/third_party/tiny_swords/Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png")
const DYNAMITE_FRAMES: int = 6
const DYNAMITE_FPS: float = 12.0
const ARC_HEIGHT_PX: float = 90.0
## Above the telegraph ring (40) and below explosions (45); absolute.
const SPRITE_Z_INDEX: int = 42

var from_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var flight_seconds: float = 1.0
var blast_radius: float = 56.0
var blast_damage: float = 22.0
var show_dynamite: bool = true
var hit_player: bool = true
var hit_tower: bool = true
var telegraph_color: Color = Color(0.9, 0.15, 0.1)
var attacker: Node = null
var registry: Node = null
var clock: Node = null

var _start_time: float = 0.0
var _sprite: Sprite2D = null
var _telegraph: GroundTelegraph = null
var _detonated: bool = false

signal detonated(center: Vector2, hit: Dictionary)


## Adds a bomb under `parent` (the arena's Entities container) and returns it.
static func launch(parent: Node, from_pos: Vector2, to_pos: Vector2, flight: float, radius: float, damage: float, with_dynamite: bool = true, source: Node = null, sim_clock: Node = null, sim_registry: Node = null) -> EnemyBomb:
	var b := EnemyBomb.new()
	b.from_position = from_pos
	b.target_position = to_pos
	b.flight_seconds = maxf(0.05, flight)
	b.blast_radius = radius
	b.blast_damage = damage
	b.show_dynamite = with_dynamite
	b.attacker = source
	b.clock = sim_clock
	b.registry = sim_registry
	parent.add_child(b)
	return b


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if registry == null:
		registry = EntityRegistry
	if clock == null:
		clock = SimClock
	global_position = from_position
	_start_time = clock.now
	_telegraph = GroundTelegraph.spawn(get_parent(), target_position, blast_radius, flight_seconds, telegraph_color, false)
	if show_dynamite:
		_sprite = Sprite2D.new()
		_sprite.texture = DYNAMITE_SHEET
		_sprite.hframes = DYNAMITE_FRAMES
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.z_as_relative = false
		_sprite.z_index = SPRITE_Z_INDEX
		add_child(_sprite)
		Sfx.play("fuse", from_position)


func get_progress() -> float:
	return clampf((clock.now - _start_time) / flight_seconds, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _sprite == null or _detonated:
		return
	var t: float = get_progress()
	global_position = from_position.lerp(target_position, t)
	_sprite.position = Vector2(0.0, -sin(PI * t) * ARC_HEIGHT_PX - 24.0)
	_sprite.rotation = t * TAU * 2.0
	_sprite.frame = int(clock.now * DYNAMITE_FPS) % DYNAMITE_FRAMES


func _physics_process(_delta: float) -> void:
	if _detonated or get_progress() < 1.0:
		return
	_detonate()


func _detonate() -> void:
	_detonated = true
	var hit: Dictionary = EnemyBlast.detonate(registry, target_position, blast_radius, blast_damage, hit_player, hit_tower, attacker if is_instance_valid(attacker) else null)
	if get_parent() != null:
		ExplosionFx.spawn(get_parent(), target_position, blast_radius)
	Sfx.play("explosion", target_position)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	detonated.emit(target_position, hit)
	queue_free()


func _exit_tree() -> void:
	if not _detonated and is_instance_valid(_telegraph):
		_telegraph.queue_free()

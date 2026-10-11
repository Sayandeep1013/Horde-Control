extends Node2D
class_name EnemyBulletField
## PT-SWARM enemy projectiles (docs/33 §C5; Register "v1.0 Enemies, Bosses &
## Waves" > "Enemy bullets", D347). One node per arena owns every enemy bullet
## as struct-of-arrays data: a fixed-capacity pool with no per-bullet nodes, no
## allocation per shot, one step loop and one draw call batch. Bosses and the
## Goblin Shaman fire through `BulletPattern`, which calls `fire()`.
##
## A bullet is a big bright orb with a dark outline (readable on grass and in a
## swarm). It hits the player, and the Tower when the shot is flagged for it,
## through SimLoop.enqueue_hit (EnemyBlast.hit_target); a dashing (invulnerable)
## player is passed through, not consumed. Solid obstacles (World collision
## layer) and the arena bounds stop it: a ray from its previous position, so a
## fast orb cannot tunnel through a thin wall. Water is not on the World layer,
## so shots fly over it (docs/33 §B2).

const GROUP: StringName = &"enemy_bullet_field"
## Above telegraph rings (40) and dynamite (42), below explosions (45).
const Z_INDEX: int = 43
const OUTLINE_COLOR: Color = Color(0.16, 0.04, 0.02, 1.0)
const CORE_COLOR: Color = Color(1.0, 0.95, 0.75, 1.0)
const OUTLINE_PX: float = 3.0
const DEFAULT_LIFETIME_SECONDS: float = 7.0
const BLOCK_MASK: int = CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_ARENA_BOUNDS

const FLAG_PLAYER: int = 1
const FLAG_TOWER: int = 2

var capacity: int = EntityCaps.MAX_ENEMY_BULLETS
var registry: Node = null
## When false, obstacles are ignored (tests that have no physics world).
var check_obstacles: bool = true

var _count: int = 0
var _pos: PackedVector2Array = PackedVector2Array()
var _vel: PackedVector2Array = PackedVector2Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _damage: PackedFloat32Array = PackedFloat32Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _flags: PackedInt32Array = PackedInt32Array()
var _color: PackedColorArray = PackedColorArray()
var _attacker: Array[Node] = []
var _serial: int = 0
var _born: PackedInt64Array = PackedInt64Array()

var fired_total: int = 0
var hits_player: int = 0
var hits_tower: int = 0
var blocked_total: int = 0


## The arena's field, created under `anchor` (the enemies' container) on first use.
static func get_or_create(anchor: Node, sim_registry: Node = null) -> EnemyBulletField:
	if anchor == null:
		return null
	if anchor.is_inside_tree():
		var existing: Node = anchor.get_tree().get_first_node_in_group(GROUP)
		if existing is EnemyBulletField and is_instance_valid(existing):
			return existing as EnemyBulletField
	var f := EnemyBulletField.new()
	f.registry = sim_registry
	anchor.add_child(f)
	return f


func _init() -> void:
	_pos.resize(capacity)
	_vel.resize(capacity)
	_radius.resize(capacity)
	_damage.resize(capacity)
	_age.resize(capacity)
	_life.resize(capacity)
	_flags.resize(capacity)
	_color.resize(capacity)
	_born.resize(capacity)
	_attacker.resize(capacity)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(GROUP)
	z_as_relative = false
	z_index = Z_INDEX
	top_level = true
	global_position = Vector2.ZERO
	if registry == null:
		registry = EntityRegistry


func get_count() -> int:
	return _count


## Adds one bullet. Returns its slot. At capacity the oldest bullet is recycled.
func fire(origin: Vector2, velocity: Vector2, radius: float, damage: float, hit_player: bool, hit_tower: bool, attacker: Node = null, color: Color = Color(1.0, 0.45, 0.1), lifetime: float = DEFAULT_LIFETIME_SECONDS) -> int:
	var i: int = _count
	if _count >= capacity:
		i = _oldest_index()
	else:
		_count += 1
	_pos[i] = origin
	_vel[i] = velocity
	_radius[i] = radius
	_damage[i] = damage
	_age[i] = 0.0
	_life[i] = lifetime
	_flags[i] = (FLAG_PLAYER if hit_player else 0) | (FLAG_TOWER if hit_tower else 0)
	_color[i] = color
	_attacker[i] = attacker
	_serial += 1
	_born[i] = _serial
	fired_total += 1
	return i


func get_bullet_position(i: int) -> Vector2:
	return _pos[i]


func get_bullet_velocity(i: int) -> Vector2:
	return _vel[i]


func clear() -> void:
	for i in _count:
		_attacker[i] = null
	_count = 0


func _oldest_index() -> int:
	var best: int = 0
	for i in _count:
		if _born[i] < _born[best]:
			best = i
	return best


func _physics_process(delta: float) -> void:
	step(delta)


func _process(_delta: float) -> void:
	if _count > 0 or _drawn_last:
		queue_redraw()


## Moves every bullet one tick, resolves obstacle blocks and hits.
func step(delta: float) -> void:
	if _count == 0:
		return
	var player: Node2D = _first(&"player")
	var tower: Node2D = _first(&"tower")
	var player_r: float = 0.0
	if player is Player and (player as Player).definition != null:
		player_r = float((player as Player).definition.body_radius_px)
	var tower_r: float = 0.0
	if tower is Tower and (tower as Tower).definition != null and (tower as Tower).definition.tower_footprint != null:
		tower_r = float((tower as Tower).definition.tower_footprint.footprint_radius_px)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state if check_obstacles and is_inside_tree() else null
	var query: PhysicsRayQueryParameters2D = null
	if space != null:
		query = PhysicsRayQueryParameters2D.new()
		query.collision_mask = BLOCK_MASK
		query.collide_with_areas = false
		query.collide_with_bodies = true
	var i: int = 0
	while i < _count:
		var from: Vector2 = _pos[i]
		var to: Vector2 = from + _vel[i] * delta
		_age[i] += delta
		if _age[i] >= _life[i]:
			_remove(i)
			continue
		if query != null:
			query.from = from
			query.to = to
			if not space.intersect_ray(query).is_empty():
				blocked_total += 1
				_remove(i)
				continue
		_pos[i] = to
		var flags: int = _flags[i]
		if (flags & FLAG_PLAYER) != 0 and player != null and to.distance_to(player.global_position) <= _radius[i] + player_r:
			var hb: Variant = player.get("hurtbox")
			if hb is Hurtbox and not (hb as Hurtbox).invulnerable and not (hb as Hurtbox).is_dead:
				EnemyBlast.hit_target(player, _damage[i], _attacker[i] if is_instance_valid(_attacker[i]) else null)
				hits_player += 1
				_remove(i)
				continue
		if (flags & FLAG_TOWER) != 0 and tower != null and to.distance_to(tower.global_position) <= _radius[i] + tower_r:
			EnemyBlast.hit_target(tower, _damage[i], _attacker[i] if is_instance_valid(_attacker[i]) else null)
			hits_tower += 1
			_remove(i)
			continue
		i += 1


var _cached: Dictionary = {} # tag -> Node2D, re-read from the registry only when gone


func _first(tag: StringName) -> Node2D:
	var c: Variant = _cached.get(tag)
	if c is Node2D and is_instance_valid(c) and (c as Node2D).is_inside_tree():
		return c
	if registry == null:
		return null
	var list: Array[Node2D] = registry.get_entities_with_tag(tag)
	var found: Node2D = list[0] if not list.is_empty() and is_instance_valid(list[0]) else null
	_cached[tag] = found
	return found


func _remove(i: int) -> void:
	var last: int = _count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_radius[i] = _radius[last]
		_damage[i] = _damage[last]
		_age[i] = _age[last]
		_life[i] = _life[last]
		_flags[i] = _flags[last]
		_color[i] = _color[last]
		_attacker[i] = _attacker[last]
		_born[i] = _born[last]
	_attacker[last] = null
	_count = last


var _drawn_last: bool = false


func _draw() -> void:
	_drawn_last = _count > 0
	for i in _count:
		var p: Vector2 = _pos[i]
		var r: float = _radius[i]
		var c: Color = _color[i]
		# Fade in over the first 0.08 s so a burst reads as leaving the boss.
		var a: float = clampf(_age[i] / 0.08, 0.35, 1.0)
		draw_circle(p, r + OUTLINE_PX, Color(OUTLINE_COLOR, a))
		draw_circle(p, r, Color(c, a))
		draw_circle(p - Vector2(r * 0.25, r * 0.3), r * 0.45, Color(CORE_COLOR, 0.9 * a))

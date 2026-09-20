extends Area2D
class_name Pickup

## Pickup entity (P2.10; MASTER_SDLC.md > Provisional Values Register >
## "Economy & Pickups"; > "Pickup Physics & Magnet Rules"). Acquired from
## `EntitySpawner.spawn_pickup()` (src/core/entity_spawner.gd) by
## `src/pickup/pickup_system.gd`, never instantiated directly by gameplay
## code -- PickupSystem owns spawning, the pickup cap / C-MERGE cascade, the
## Drop Table, and collection; this script is per-instance magnet/raycast/
## lifetime physics only, matching the `physics_step(delta)` /
## `driven_externally` convention every other entity in this project follows
## (src/player/player.gd, src/enemy/enemy_controller.gd, src/combat/
## auto_weapon.gd).
##
## docs/20_Technical_Architecture.md > "Collision Layers": Pickup Area2D,
## layer 12, masks none. `monitorable = true` so PlayerCollector (layer 16,
## masks 12; src/player/collector.gd) can detect it; `monitoring = false`
## since this Area2D never scans anything itself -- matching Hurtbox's own
## "never scans" convention (src/combat/hurtbox.gd) for the same reason:
## nothing here needs to detect the other side of an overlap, only be
## detected by it.
##
## PickupSystem owns collection (it is the one connected to
## PlayerCollector.pickup_entered) and lifetime expiry (it despawns an
## expired instance after this script's own physics_step marks it expired);
## this file never calls EntitySpawner.despawn_pickup() on itself.

@export var driven_externally: bool = false

## Register > Economy & Pickups > "Magnet radius / pickup motion": "96 px /
## accelerate 40 px/s initial, 900 px/s2 acceleration, 700 px/s max".
const INITIAL_SPEED_PX_PER_SECOND: float = 40.0
const ACCELERATION_PX_PER_SECOND_SQUARED: float = 900.0
const MAX_SPEED_PX_PER_SECOND: float = 700.0

## Register > Interfaces > "Readability": "draw order z_index: environment
## 0, pickups 10, enemies 20 ...".
const Z_INDEX_PICKUPS: int = 10

## NO REGISTER ROW -- escalated. Neither the Register nor document 16
## (Economy - Pickups, which does not exist as a file -- see the P2.10
## evidence report) states a pickup's own collision-detection radius; only
## the PlayerCollector's own radius (22 px, Register > Player & Weapons) is
## specified. Kept well under that so collection reads as "the collector
## reaches the pickup," not the reverse.
const COLLISION_RADIUS_PX: float = 6.0

## Register > Economy & Pickups > "Pickup lifetime": "60 s simulation time
## with a 5 s blink". PickupDefinition.lifetime_seconds also authors this
## same number (data/pickups/*.tres) -- this script reads the AUTHORED
## value off `definition` at configure() time, falling back to this
## constant only if no definition is set yet (defensive; every real spawn
## always sets one).
const LIFETIME_SECONDS_DEFAULT: float = 60.0
const BLINK_WINDOW_SECONDS: float = 5.0

## NO REGISTER ROW -- escalated. The Register states the blink WINDOW
## (5 s) but not a blink rate; this is a cosmetic warning flicker, not a
## balance number.
const BLINK_PERIOD_SECONDS: float = 0.2

@export var collision_shape_path: NodePath = NodePath("CollisionShape2D")
@export var sprite_path: NodePath = NodePath("Sprite")

var _sim_clock: Node = SimClock
var _registry: Node = EntityRegistry
var _sprite: Sprite2D = null

## Set by PickupDefinition/PickupSystem at configure() time; mutable
## afterwards only by the merge cascade (PickupSystem sums a merged-away
## pickup's value into its neighbour's `value` field directly).
var definition: PickupDefinition = null
var value: int = 0
var spawn_serial: int = -1

## PickupSystem re-resolves the live magnet radius once per tick (Register:
## "Upgrades can expand this") and writes it here before calling
## physics_step(), rather than this script hardcoding or caching a stale
## copy -- see pickup_system.gd's `_resolve_magnet_radius_px()`.
var magnet_radius_px: float = 96.0

var _lifetime_seconds: float = LIFETIME_SECONDS_DEFAULT
var _spawn_time: float = 0.0
var _attracted: bool = false
var _current_speed_px_per_second: float = 0.0
var _blocked: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = CollisionLayers.LAYER_PICKUP
	collision_mask = 0
	z_index = Z_INDEX_PICKUPS
	var shape_node: CollisionShape2D = get_node_or_null(collision_shape_path) as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = COLLISION_RADIUS_PX
	_sprite = get_node_or_null(sprite_path) as Sprite2D


func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


# --- Test/orchestrator DI seams (matching entity_spawner.gd's/enemy_
# controller.gd's own set_*_for_test convention) --------------------------

func set_sim_clock_for_test(clock: Node) -> void:
	_sim_clock = clock


func set_registry_for_test(registry: Node) -> void:
	_registry = registry


## Resets every mutable field a recycled pool instance could still be
## carrying from its previous life. Pool.gd only restores Logical-Death
## flags for nodes in its `pool_hitbox`/`pool_hurtbox`/`pool_body` groups
## (this script joins none of them, having no combat state to restore), so
## this method is the only place stale magnet/lifetime state from a
## previous drop gets cleared before reuse -- an un-reset `_attracted`/
## `_current_speed_px_per_second`/`_spawn_time` would let a reused instance
## skip its acceleration ramp or expire early, the pickup-side analogue of
## the Ghost Hit class of defect Pool.gd's own header names for combat
## state.
func configure(pickup_definition: PickupDefinition, pickup_value: int, position: Vector2, serial: int) -> void:
	definition = pickup_definition
	value = pickup_value
	spawn_serial = serial
	_lifetime_seconds = pickup_definition.lifetime_seconds if pickup_definition != null and pickup_definition.lifetime_seconds > 0.0 else LIFETIME_SECONDS_DEFAULT
	global_position = position
	_spawn_time = _sim_clock.now
	_attracted = false
	_current_speed_px_per_second = 0.0
	_blocked = false
	visible = true
	modulate.a = 1.0
	if _sprite != null and pickup_definition != null and pickup_definition.visual_audio_cue != null:
		var texture_path: String = pickup_definition.visual_audio_cue.sprite_reference
		if texture_path != "" and ResourceLoader.exists(texture_path):
			_sprite.texture = load(texture_path) as Texture2D


func get_pickup_type() -> ContractEnums.PickupType:
	return definition.pickup_type if definition != null else ContractEnums.PickupType.XP


func get_age_seconds() -> float:
	return _sim_clock.now - _spawn_time


func is_expired() -> bool:
	return get_age_seconds() >= _lifetime_seconds


func is_attracted() -> bool:
	return _attracted


func is_blocked_for_test() -> bool:
	return _blocked


func get_current_speed_for_test() -> float:
	return _current_speed_px_per_second


## Per-tick magnet/raycast/lifetime physics (Register > "Pickup Physics &
## Magnet Rules" in full). Called either by this node's own
## `_physics_process` (standalone / not yet SimLoop-driven) or directly by
## `PickupSystem.step_pickup_movement_and_collection()` once
## `driven_externally` is set true -- see this file's header.
func physics_step(delta: float) -> void:
	var age: float = get_age_seconds()
	_update_blink(age)
	if is_expired():
		return # PickupSystem despawns on its next check; no further motion once past lifetime

	if not _attracted:
		if definition != null and definition.magnet_behaviour != ContractEnums.MagnetBehaviour.Attracted:
			return # Static pickups (Pickup Definition Contract) never attract -- no prototype pickup uses this, but the schema allows it, so it is honoured rather than assumed away
		var nearby_players: Array[Node2D] = _registry.get_entities_in_radius(global_position, magnet_radius_px, &"player")
		if nearby_players.is_empty():
			return # Register: "a pickup that has never been attracted does not simulate at all" -- no motion, no raycast below this point
		_attracted = true
		_current_speed_px_per_second = INITIAL_SPEED_PX_PER_SECOND

	# Sticky (Register): once attracted, keep chasing the player regardless
	# of current distance, so a fresh in-radius check is wrong here -- pull
	# the player's live position unconditionally instead.
	var players: Array[Node2D] = _registry.get_entities_with_tag(&"player")
	if players.is_empty():
		return # no player registered to chase (edge case) -- hold position, keep accruing lifetime
	var target_position: Vector2 = players[0].global_position

	_current_speed_px_per_second = minf(_current_speed_px_per_second + ACCELERATION_PX_PER_SECOND_SQUARED * delta, MAX_SPEED_PX_PER_SECOND)

	_blocked = _is_ray_blocked(target_position)
	if _blocked:
		return # Register: "holds its current position while keeping its stored speed" -- speed is NOT reset, only motion withheld this tick

	global_position = global_position.move_toward(target_position, _current_speed_px_per_second * delta)
	if _registry != null:
		_registry.update_position(self, global_position)


## Register > Economy & Pickups > "Pickup raycast": "cast toward the player
## masking EnemyBody, TowerBody, World (layers 2, 3, 4); if blocked, hold
## position keeping stored speed". Logical-Dead enemies never block this
## (Register: "Logical-Dead enemies never block") because Logical Death
## (docs/20) already zeroes a dying body's collision_layer, dropping it off
## the EnemyBody bit before this mask could ever see it again -- this
## script relies on that existing guarantee rather than re-checking a
## `dead` flag itself, which src/combat/death_state.gd (outside this task's
## write scope) owns.
func _is_ray_blocked(target_position: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = CollisionLayers.LAYER_ENEMY_BODY | CollisionLayers.LAYER_TOWER_BODY | CollisionLayers.LAYER_WORLD
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()


func _update_blink(age: float) -> void:
	var remaining: float = _lifetime_seconds - age
	if remaining > BLINK_WINDOW_SECONDS or remaining < 0.0:
		modulate.a = 1.0
		return
	var t: float = fmod(age, BLINK_PERIOD_SECONDS)
	modulate.a = 1.0 if t < BLINK_PERIOD_SECONDS * 0.5 else 0.3

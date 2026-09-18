extends Node

## EntitySpawner (P1.3; PLAN.md > P1.3 "cap enforcement in the spawner
## API"). Not an Autoload -- like `SimLoop` (LEDGER F02-06), it belongs
## under the gameplay root `scenes/main.tscn` builds, since it owns
## references to that scene's pooled containers. Owns six `Pool`
## (src/core/pool.gd) instances, one per Provisional Values Register cap
## (MASTER_SDLC.md > Provisional Values Register > Technical Caps &
## Performance > "Entity caps"; values transcribed once, in
## src/core/entity_caps.gd, cited from the Register). Every `spawn_*`
## method enforces its cap by calling straight into that category's
## `Pool.acquire()` -- the cap is enforced AT the spawn call, not by a
## separate count-after-the-fact check.
##
## **EntityRegistry wiring** (task brief: "your pools will register and
## deregister entities through it"). `enemy`, `pickup`, and `projectile`
## are registered on acquire and deregistered on release/despawn, tagged
## `&"enemy"` / `&"pickup"` / `&"projectile"` respectively -- these three
## are the categories docs/20 names as needing spatial queries (Tower
## targeting, the magnet raycast, the Pressure Metric, wave/encounter
## completion counts all read EntityRegistry). `damage_number`,
## `telegraph`, and `high_intensity_vfx` are NOT registered: no document
## names a spatial query over any of the three, and EntityRegistry's own
## header comment expects "a handful" of distinct tags, not one per visual
## budget category. This is a P1.3 interpretation, not a directly stated
## rule -- named here and in the evidence report rather than silently
## assumed, per LEDGER F02-11's own pattern for this exact file.
##
## Deregistration happens at DESPAWN (Pool.release()), not at Logical
## Death. LEDGER F02-11: `EntityRegistry.set_entity_alive()` is P1.2's own
## channel for Logical Death to reach the registry without deregistering
## the entity outright, so a dying-but-not-yet-pooled entity (still
## playing its Visual Death) stays registered with alive=false and is
## excluded from live queries by that flag, not by being torn out of the
## registry. Only once P1.5's death_state.gd actually calls despawn_*()
## (Visual Death timer expired, docs/20 > "Spatial Cleanup": "the entity is
## returned to the object pool") does this file deregister it. This read
## is consistent with F02-11's own design -- see the evidence report's
## "set_entity_alive consistency" section.
##
## Container wiring is optional and deferred: the `@export`ed NodePaths
## below are resolved once, in `_ready()`, against whatever this node's
## siblings are at that point (the real scene wires them to `Entities` /
## `Projectiles` / `Pickups` / `Effects`). Left unset, every Pool below
## gets a null container, which `Pool` tolerates (nothing to reparent
## into) -- every test in `tests/unit/entity_cap_test.gd` relies on this,
## since those tests exist to prove cap enforcement, not scene wiring.

@export var entities_container_path: NodePath
@export var projectiles_container_path: NodePath
@export var pickups_container_path: NodePath
@export var effects_container_path: NodePath

var _registry: Node

var _enemy_pool: Pool
var _pickup_pool: Pool
var _projectile_pool: Pool
var _damage_number_pool: Pool
var _telegraph_pool: Pool
var _high_intensity_vfx_pool: Pool


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_registry = EntityRegistry
	_build_pools()


func _build_pools() -> void:
	var entities_container: Node = get_node_or_null(entities_container_path) if entities_container_path != NodePath() else null
	var projectiles_container: Node = get_node_or_null(projectiles_container_path) if projectiles_container_path != NodePath() else null
	var pickups_container: Node = get_node_or_null(pickups_container_path) if pickups_container_path != NodePath() else null
	var effects_container: Node = get_node_or_null(effects_container_path) if effects_container_path != NodePath() else null

	# Overflow policy per category: THROTTLE where the Register's "if
	# exceeded" text reads as a refusal/wait ("throttle", "wait with their
	# cooldown held"), RECYCLE_OLDEST where it reads as reclaiming the
	# oldest ("recycle[d]", "culled", "merge or expire" -- P1.3's closest
	# read of the pickup row, named as an interpretation in the evidence
	# report).
	_enemy_pool = Pool.new(_default_factory, entities_container, EntityCaps.MAX_ENEMIES, Pool.OverflowPolicy.THROTTLE)
	_pickup_pool = Pool.new(_default_factory, pickups_container, EntityCaps.MAX_PICKUPS, Pool.OverflowPolicy.RECYCLE_OLDEST)
	_projectile_pool = Pool.new(_default_factory, projectiles_container, EntityCaps.MAX_PROJECTILES, Pool.OverflowPolicy.RECYCLE_OLDEST)
	_damage_number_pool = Pool.new(_default_factory, effects_container, EntityCaps.MAX_DAMAGE_NUMBERS, Pool.OverflowPolicy.RECYCLE_OLDEST)
	_telegraph_pool = Pool.new(_default_factory, effects_container, EntityCaps.MAX_TELEGRAPHS, Pool.OverflowPolicy.THROTTLE)
	_high_intensity_vfx_pool = Pool.new(_default_factory, effects_container, EntityCaps.MAX_HIGH_INTENSITY_VFX, Pool.OverflowPolicy.THROTTLE)


static func _default_factory() -> Node2D:
	return Node2D.new()


## Test-only injection point (naming convention matches
## entity_registry.gd's own test helpers): overrides the EntityRegistry
## reference this spawner registers/deregisters against, so a test suite
## can hand it a throwaway instance instead of polluting the real
## Autoload singleton across the whole test run -- the same isolation
## `tests/unit/entity_registry_test.gd` already applies to EntityRegistry
## itself. Never called by gameplay code.
func set_registry_for_test(registry: Node) -> void:
	_registry = registry


## Test-only teardown: frees every instance every pool currently owns and
## clears their bookkeeping. Never called by gameplay code.
func clear_all_for_test() -> void:
	for pool in [_enemy_pool, _pickup_pool, _projectile_pool, _damage_number_pool, _telegraph_pool, _high_intensity_vfx_pool]:
		if pool != null:
			pool.clear_for_test()


# --- Enemy -------------------------------------------------------------

func spawn_enemy(position: Vector2 = Vector2.ZERO, factory: Callable = Callable()) -> Node2D:
	var instance: Node = _enemy_pool.acquire(factory)
	if instance == null:
		return null
	if _registry != null:
		_registry.register_entity(instance as Node2D, position, [&"enemy"])
	return instance as Node2D


func despawn_enemy(instance: Node) -> bool:
	if _registry != null:
		_registry.deregister_entity(instance)
	return _enemy_pool.release(instance)


func get_enemy_count() -> int:
	return _enemy_pool.get_active_count()


# --- Pickup --------------------------------------------------------------

func spawn_pickup(position: Vector2 = Vector2.ZERO, factory: Callable = Callable()) -> Node2D:
	var instance: Node = _pickup_pool.acquire(factory)
	if instance == null:
		return null
	if _registry != null:
		_registry.register_entity(instance as Node2D, position, [&"pickup"])
	return instance as Node2D


func despawn_pickup(instance: Node) -> bool:
	if _registry != null:
		_registry.deregister_entity(instance)
	return _pickup_pool.release(instance)


func get_pickup_count() -> int:
	return _pickup_pool.get_active_count()


# --- Projectile ----------------------------------------------------------

func spawn_projectile(position: Vector2 = Vector2.ZERO, factory: Callable = Callable()) -> Node2D:
	var instance: Node = _projectile_pool.acquire(factory)
	if instance == null:
		return null
	if _registry != null:
		_registry.register_entity(instance as Node2D, position, [&"projectile"])
	return instance as Node2D


func despawn_projectile(instance: Node) -> bool:
	if _registry != null:
		_registry.deregister_entity(instance)
	return _projectile_pool.release(instance)


func get_projectile_count() -> int:
	return _projectile_pool.get_active_count()


# --- Damage number (no EntityRegistry wiring -- see header) --------------

func spawn_damage_number(factory: Callable = Callable()) -> Node2D:
	return _damage_number_pool.acquire(factory) as Node2D


func despawn_damage_number(instance: Node) -> bool:
	return _damage_number_pool.release(instance)


func get_damage_number_count() -> int:
	return _damage_number_pool.get_active_count()


# --- Telegraph (no EntityRegistry wiring -- see header) -------------------

func spawn_telegraph(factory: Callable = Callable()) -> Node2D:
	return _telegraph_pool.acquire(factory) as Node2D


func despawn_telegraph(instance: Node) -> bool:
	return _telegraph_pool.release(instance)


func get_telegraph_count() -> int:
	return _telegraph_pool.get_active_count()


# --- High-intensity VFX (no EntityRegistry wiring -- see header) ---------

func spawn_high_intensity_vfx(factory: Callable = Callable()) -> Node2D:
	return _high_intensity_vfx_pool.acquire(factory) as Node2D


func despawn_high_intensity_vfx(instance: Node) -> bool:
	return _high_intensity_vfx_pool.release(instance)


func get_high_intensity_vfx_count() -> int:
	return _high_intensity_vfx_pool.get_active_count()

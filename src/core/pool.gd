extends RefCounted
class_name Pool

## Pool (P1.3; docs/20_Technical_Architecture.md > Godot 4.x Implementation
## Standards > "Communication, commands", named example "`Pool.acquire()`";
## > "Logical Death"; > "Scene Tree": "The containers exist for pool
## ownership ... not for traversal speed."). A reusable, generic object
## pool. `src/core/entity_spawner.gd` owns six instances of this class, one
## per Provisional Values Register cap (MASTER_SDLC.md > Provisional Values
## Register > Technical Caps & Performance > "Entity caps"); nothing here
## is enemy/projectile/pickup/effect-specific, so the same class serves all
## six without duplication.
##
## ## The cap
##
## `max_size` is enforced INSIDE acquire(), before a new instance is ever
## created or an existing one handed out -- "cap enforcement in the
## spawner API, enforced where spawning happens rather than checked after
## the fact" (P1.3 task brief), not a count taken after the spawn already
## occurred. See OverflowPolicy below for what happens once the cap is hit.
##
## ## The Logical Death restore contract (the critical requirement)
##
## docs/20 > Logical Death: the instant an entity's HP reaches 0, four
## things are deferredly changed so it can no longer deal or receive
## damage while its Visual Death plays: every hitbox `Area2D`'s
## `monitoring` -> false; the hurtbox `Area2D`'s `monitorable` -> false and
## `collision_layer` -> 0; the body's `collision_layer` -> 0 and
## `collision_mask` -> World+ArenaBounds only. The same bullet ends:
## "`Pool.acquire()` restores all of these -- layers, masks, and monitoring
## flags -- before reuse." A pool that restores only some of them
## reintroduces ghost-hit bugs on reuse (Phase 02 PLAN.md's own risk
## table), which is exactly what P1.5's Ghost hit test (100 mid-attack
## kills, zero post-death damage events) exists to catch on a REUSED
## instance -- a fresh instance would never exercise this path at all.
##
## **Discovery convention.** Pool must not depend on any single entity
## script -- P1.5's `hitbox.gd`/`hurtbox.gd`/`death_state.gd` land AFTER
## this task (LEDGER F02-11 names P1.5 as the owner of Logical Death, "and
## comes after you"). So a pooled instance opts in by placing the relevant
## node in one of three Godot groups, checked via `is_in_group()`:
##   - `pool_hitbox` (an `Area2D`; restores `monitoring`)
##   - `pool_hurtbox` (an `Area2D`; restores `monitorable` and
##     `collision_layer`)
##   - `pool_body` (any node exposing `collision_layer` and
##     `collision_mask`, typically the instance root)
## `is_in_group()` reflects group membership immediately after
## `add_to_group()`, even before the node has ever entered the SceneTree
## (Godot 4.x tracks group membership on the Node itself), so this works
## whether the candidate is already live in a container or still sitting
## unparented in the free list. An instance with none of these groups (a
## plain placeholder, or a pickup/effect with no combat state at all) has
## nothing to restore -- that is a no-op, not an error.
##
## **Snapshot-and-reapply, not a hard-coded default.** The first time an
## instance is ever handed out (the branch where the factory just created
## it), Pool snapshots its OWN monitoring/monitorable/collision_layer/
## collision_mask values as that instance's baseline -- whatever the scene
## itself defines, since Pool has no license to guess the right layer or
## mask for an enemy type it does not know about. Every later acquire() of
## that SAME instance reapplies the stored baseline, overwriting whatever
## Logical Death (or anything else) left behind. This is why the baseline
## must be captured at creation time, before anything has had a chance to
## mutate the instance.

enum OverflowPolicy {
	## The cap holds by refusing new spawns: acquire() returns null.
	## "throttle = spawn retries next tick without using budget" (Register).
	## Matches the enemy, telegraph, and (P1.3 interpretation, see the
	## evidence report) high-intensity-VFX budgets' documented behaviour.
	THROTTLE,
	## The cap holds by reclaiming the OLDEST still-active instance (the
	## one at the front of the acquisition order) and reusing its slot for
	## the new spawn, so the pool never grows past max_size but a request
	## is never simply refused either. Matches "oldest ... recycle[d]"
	## (projectiles), "oldest ... culled" (damage numbers), and (P1.3
	## interpretation) "oldest pickups merge or expire".
	RECYCLE_OLDEST,
}

var _factory: Callable
var _container: Node
var _max_size: int
var _overflow_policy: OverflowPolicy

var _free: Array[Node] = [] # released instances available for reuse
var _active: Array[Node] = [] # currently acquired, oldest at index 0
var _baseline: Dictionary = {} # instance (Node) -> Dictionary of snapshots, keyed by the node found in each pool_* group


## `factory` must return a fresh, unparented `Node` each time it is
## called; it is invoked only when the free list is empty AND the cap has
## not been reached (or, under RECYCLE_OLDEST, immediately after the
## oldest active instance was just released, which repopulates the free
## list instead). `container`, if not null, receives every instance this
## pool ever creates as a child, once, the first time that instance is
## created -- matching docs/20 > Scene Tree's "the containers exist for
## pool ownership". `container` may be null (every test in this project's
## suite passes null; nothing to reparent into).
func _init(factory: Callable, container: Node, max_size: int, overflow_policy: OverflowPolicy = OverflowPolicy.THROTTLE) -> void:
	_factory = factory
	_container = container
	_max_size = max_size
	_overflow_policy = overflow_policy


func get_active_count() -> int:
	return _active.size()


func get_free_count() -> int:
	return _free.size()


## Total instances this pool currently owns, active or free -- the figure
## the Pool unit check (10,000 acquire/release cycles) reads to confirm
## object count stays stable rather than growing per cycle.
func get_total_instance_count() -> int:
	return _active.size() + _free.size()


func get_max_size() -> int:
	return _max_size


## Typed command (docs/20 > Communication, commands, named example). Hands
## back a ready-to-use instance with every Logical Death flag restored, or
## null if the cap is reached under OverflowPolicy.THROTTLE. Never exceeds
## max_size under either policy.
##
## `factory_override`, if a valid Callable, is used instead of the
## constructor's default factory ONLY when this call needs to create a
## brand-new instance (free list empty, room under the cap). This lets one
## Pool serve more than one concrete scene/archetype over its lifetime
## without breaking the free-list reuse invariant for instances it already
## owns -- a per-call convenience the constructor's own `factory` argument
## still has to exist for, since a pool must always have SOME way to grow.
func acquire(factory_override: Callable = Callable()) -> Node:
	if _active.size() >= _max_size:
		if _overflow_policy == OverflowPolicy.RECYCLE_OLDEST and not _active.is_empty():
			release(_active[0]) # oldest active instance, freed for immediate reuse below
		else:
			return null

	var instance: Node
	if not _free.is_empty():
		instance = _free.pop_back()
	else:
		var factory_to_use: Callable = factory_override if factory_override.is_valid() else _factory
		instance = factory_to_use.call() as Node
		if instance == null:
			push_error("Pool: factory returned a null or non-Node instance")
			return null
		if _container != null and instance.get_parent() == null:
			_container.add_child(instance)
		_snapshot_baseline(instance)

	_restore_logical_death_flags(instance)
	instance.visible = true
	_active.append(instance)
	return instance


## Typed command. Returns `instance` to the free list for reuse. Refuses
## (returns false) an instance this pool did not currently have active --
## docs/20 > Communication, commands: "the owning system validates the
## request and may refuse it."
func release(instance: Node) -> bool:
	var idx: int = _active.find(instance)
	if idx == -1:
		return false
	_active.remove_at(idx)
	if is_instance_valid(instance):
		instance.visible = false
	_free.append(instance)
	return true


## Test-only teardown (naming convention matches entity_registry.gd's
## `set_cell_size_for_test`): frees every instance this pool currently
## owns, active or free, so a test suite does not leak orphan nodes across
## test functions. Never called by gameplay code -- gameplay-owned
## instances live for the lifetime of the pool.
func clear_for_test() -> void:
	for n in _active:
		if is_instance_valid(n):
			n.free()
	for n in _free:
		if is_instance_valid(n):
			n.free()
	_active.clear()
	_free.clear()
	_baseline.clear()


func _snapshot_baseline(instance: Node) -> void:
	var snap: Dictionary = {}
	for hitbox in _find_in_group(instance, &"pool_hitbox"):
		snap[hitbox] = {"monitoring": hitbox.monitoring}
	for hurtbox in _find_in_group(instance, &"pool_hurtbox"):
		snap[hurtbox] = {"monitorable": hurtbox.monitorable, "collision_layer": hurtbox.collision_layer}
	for body in _find_in_group(instance, &"pool_body"):
		snap[body] = {"collision_layer": body.collision_layer, "collision_mask": body.collision_mask}
	_baseline[instance] = snap


func _restore_logical_death_flags(instance: Node) -> void:
	var snap: Dictionary = _baseline.get(instance, {})
	for node in snap.keys():
		var values: Dictionary = snap[node]
		if values.has("monitoring"):
			node.monitoring = values["monitoring"]
		if values.has("monitorable"):
			node.monitorable = values["monitorable"]
		if values.has("collision_layer"):
			node.collision_layer = values["collision_layer"]
		if values.has("collision_mask"):
			node.collision_mask = values["collision_mask"]


func _find_in_group(root: Node, group: StringName) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_in_group(group):
		out.append(root)
	for child in root.get_children():
		out.append_array(_find_in_group(child, group))
	return out

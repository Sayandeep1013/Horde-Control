extends Area2D
class_name Hitbox

## Hitbox (P1.5; docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Physics & Collisions": "Hitboxes and
## Hurtboxes use Area2D"; > "Collision Layers" table). The binding table
## defines exactly ONE hitbox row -- EnemyHitbox (11), masking PlayerHurtbox
## (8) always, and TowerHurtbox (10) only for a telegraphed attack aimed at
## the Tower. Player and Tower deal damage through projectiles (layers 5/6),
## not a melee "hitbox" Area2D, in this table -- there is no PlayerHitbox or
## TowerHitbox row to implement, so this component only ever applies the
## EnemyHitbox layer/mask. Named here rather than silently generalized to a
## Faction enum with invented layer numbers the Register does not state
## (contrast hurtbox.gd, whose three rows are all real).
##
## Joins the `pool_hitbox` group src/core/pool.gd's discovery convention
## requires: `Pool.acquire()` snapshots this node's `monitoring` the first
## time it is ever handed out and restores it on every later acquire().
##
## **The ghost-hit defect this file exists to make impossible**: an enemy
## killed mid-attack-windup must not let its own hitbox land a hit
## afterward (docs/20 > "Animation Cancellation": "If an enemy is killed
## while in an attack wind-up, the attack state is immediately cancelled.
## The entity transitions directly to the Visual Death state."). Two
## independent protections, same reasoning as hurtbox.gd's header:
## 1. `_window_active`, a synchronous plain-GDScript flag, flipped false the
##    instant deactivate_window() is called -- so even an `area_entered`
##    signal already in flight this same tick (fired by the physics engine
##    before the deferred `monitoring = false` below has landed) is
##    rejected by `_on_area_entered()`'s own first check, not merely by
##    hoping the engine-level flag caught up in time.
## 2. `monitoring = false`, applied via `set_deferred` -- never directly.
##    Godot's physics server is locked while an `area_entered`/`body_entered`
##    signal is being dispatched (mid physics-step "flushing queries"); a
##    direct, non-deferred write to `monitoring` (or to a child
##    CollisionShape2D's `disabled`) from inside that callback is the exact
##    Godot error docs/20's Physics & Collisions bullet warns about:
##    "Disabling a CollisionShape2D from inside a physics callback must use
##    set_deferred('disabled', true)." This file applies the same rule to
##    `monitoring` itself, and to every child CollisionShape2D's `disabled`.

## Damage this hitbox deals to a hurtbox it lands on. Not a Provisional
## Values Register number -- see death_state.gd's header and the P1.5
## evidence report for why this is a framework/test-fixture constant, not
## gameplay content.
@export var damage: float = 10.0

## True only for a telegraphed attack aimed at the Tower (docs/20 table:
## "11 EnemyHitbox ... masks 8 (and 10 only for telegraphed attacks aimed at
## the Tower)"). False (PlayerHurtbox only) is the default for every other
## enemy attack.
@export var targets_tower: bool = false

## Set by whoever builds this hitbox (the placeholder enemy, later a real
## enemy) to the entity that owns it. Passed through to receive_hit() as the
## damage source -- resolved BY REFERENCE here (unlike docs/20's Projectile
## Orphans rule, which resolves a projectile's source BY VALUE at fire time
## because a projectile can outlive its firer; a melee hitbox cannot outlive
## its owner, since deactivate_window() at Logical Death always runs before
## the owner could ever despawn, so no orphan case exists for this file to
## handle).
var owner_entity: Node = null

## Synchronous "is my attack window currently live" flag -- see header,
## protection 1. Starts false: a freshly created or freshly reused hitbox
## deals no damage until something explicitly opens an attack window.
var _window_active: bool = false

## Emitted only when a hit is actually accepted by the target hurtbox
## (i.e. the target was not already dead) -- mirrors hurtbox.gd's
## damage_received but from the attacker's side, for tests and future
## VFX/audio listeners.
signal hit_landed(hurtbox: Hurtbox, damage: float, source: Variant)


func _ready() -> void:
	add_to_group(&"pool_hitbox")
	collision_layer = CollisionLayers.LAYER_ENEMY_HITBOX
	collision_mask = CollisionLayers.MASK_ENEMY_HITBOX_PLAYER_AND_TOWER if targets_tower else CollisionLayers.MASK_ENEMY_HITBOX_PLAYER_ONLY
	monitoring = false # inactive until activate_window() opens an attack
	monitorable = false # a hitbox is never itself a valid target
	area_entered.connect(_on_area_entered)


## Typed command: opens the attack window (docs/20 > SimLoop order, step 6
## "wind-up completion ... contact ticks"). Always deferred, even though the
## direct-mutation Godot error only bites when called from inside a physics
## callback -- deferring unconditionally is simpler than tracking every call
## site's context and cannot be wrong.
func activate_window() -> void:
	_window_active = true
	set_deferred("monitoring", true)
	_set_shapes_disabled(false)


## Typed command: closes the attack window, whether because the attack
## finished normally or because Logical Death cancelled it mid-windup
## (docs/20 > "Animation Cancellation"). See header for why both the
## synchronous flag and the deferred engine flag are set here, not one or
## the other.
func deactivate_window() -> void:
	_window_active = false
	set_deferred("monitoring", false)
	_set_shapes_disabled(true)


func is_window_active() -> bool:
	return _window_active


## Called after Pool.acquire() has already restored `monitoring` from its
## own baseline snapshot -- resets what Pool does not know about, the
## synchronous window flag this file owns, plus the collision shape (Pool's
## restore contract does not cover CollisionShape2D.disabled, only the four
## flags pool.gd's header names).
func reset_for_reuse() -> void:
	_window_active = false
	_set_shapes_disabled(true)


func _set_shapes_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)


func _on_area_entered(area: Area2D) -> void:
	if not _window_active:
		return # window already cancelled this tick -- see header, protection 1
	if not (area is Hurtbox):
		return
	var hurtbox: Hurtbox = area as Hurtbox
	var accepted: bool = hurtbox.receive_hit(self, damage, owner_entity)
	if accepted:
		hit_landed.emit(hurtbox, damage, owner_entity)

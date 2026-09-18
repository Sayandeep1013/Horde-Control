extends Area2D
class_name Hurtbox

## Hurtbox (P1.5; docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Physics & Collisions": "Hitboxes and
## Hurtboxes use Area2D"; > "Collision Layers" table, PlayerHurtbox (8) /
## EnemyHurtbox (9) / TowerHurtbox (10) rows, every one of which lists
## "none" in the Masks column -- a hurtbox is detected, it never scans. So
## `monitoring` stays false permanently and `collision_mask` stays 0
## permanently; only `collision_layer` (which faction owns this hurtbox) and
## `monitorable` (whether it can currently be detected) ever change.
##
## Joins the `pool_hurtbox` group src/core/pool.gd's discovery convention
## requires (its own header comment): `Pool.acquire()` snapshots this node's
## `monitorable` and `collision_layer` the first time it is ever handed out,
## then restores both values on every later acquire() of the same instance,
## overwriting whatever Logical Death left behind.
##
## **Two independent protections against a ghost hit landing on THIS
## hurtbox**, both required by docs/20 > "Logical Death", not one redundant
## with the other:
## 1. `is_dead`, a synchronous plain-GDScript flag, set the instant Logical
##    Death happens (death_state.gd calls mark_dead() first, before any
##    deferred call) and checked first by receive_hit() below -- docs/20's
##    own words: "a `dead` flag is set on it and checked first by every
##    damage handler, including overlaps already delivered earlier in the
##    same tick, so a hit already queued against a dying entity is
##    discarded rather than applied twice." A deferred engine-level flag
##    cannot retroactively cancel a signal that already fired synchronously
##    earlier in the same tick; only a flag checked at the moment of receipt
##    can.
## 2. `monitorable = false` and `collision_layer = 0`, applied via
##    `set_deferred` (never directly -- see hitbox.gd's header for why),
##    which stops an attacker from detecting this hurtbox AT ALL from the
##    next physics step onward, and independently lets a swept
##    `intersect_ray` pass through the corpse (docs/20's own reason for the
##    layer clear specifically, not `is_dead`'s job).

## Faction rows this component implements from the binding table (docs/20 >
## Collision Layers). Only the three Hurtbox rows -- Hitbox has only one row
## (EnemyHitbox) and lives in hitbox.gd instead.
enum Faction { PLAYER, ENEMY, TOWER }

@export var faction: Faction = Faction.ENEMY

## Synchronous "am I logically dead" flag -- see header, protection 1.
## Public (read by tests and by whichever system needs to know a hurtbox's
## owner is already gone) but only ever WRITTEN by mark_dead() /
## reset_for_reuse() below, never assigned directly by another file.
var is_dead: bool = false

## Emitted only when a hit is actually accepted (is_dead was false at the
## moment of receipt) -- the signal a test counts to distinguish a real
## damage event from a discarded ghost hit.
signal damage_received(amount: float, source: Variant, hitbox: Node)


func _ready() -> void:
	add_to_group(&"pool_hurtbox")
	monitoring = false # a hurtbox never scans (every table row's Masks column is "none")
	monitorable = true
	collision_mask = 0
	collision_layer = _layer_for_faction(faction)


static func _layer_for_faction(f: Faction) -> int:
	match f:
		Faction.PLAYER:
			return CollisionLayers.LAYER_PLAYER_HURTBOX
		Faction.TOWER:
			return CollisionLayers.LAYER_TOWER_HURTBOX
		_:
			return CollisionLayers.LAYER_ENEMY_HURTBOX


## Typed command, called only by a Hitbox that detected this hurtbox
## (docs/20 > "Communication, commands"). Returns true if the hit was
## accepted (this hurtbox was not already dead), false if it was discarded
## as a ghost hit. Never resolves damage math itself -- that is the
## caller's (ultimately death_state.gd's apply_damage()) job; this method
## only gates whether the attempt is even allowed through.
func receive_hit(hitbox: Node, amount: float, source: Variant) -> bool:
	if is_dead:
		return false # discarded -- docs/20 > Logical Death, checked first
	damage_received.emit(amount, source, hitbox)
	return true


## Called by death_state.gd FIRST, synchronously, as the very first action
## of Logical Death -- before any set_deferred call. See header, protection 1.
func mark_dead() -> void:
	is_dead = true


## Called by death_state.gd as part of Logical Death, after mark_dead().
## Deferred (docs/20 > "Logical Death": "the hurtbox Area2D sets
## monitorable = false and also collision_layer = 0 (deferred)"; > Physics &
## Collisions: "Disabling a CollisionShape2D from inside a physics callback
## must use set_deferred('disabled', true)" -- the same caution this project
## extends to every Logical Death flag, not only the collision-shape case
## the sentence names literally).
func apply_logical_death_layers() -> void:
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)


## Called after Pool.acquire() has already restored monitorable and
## collision_layer from its own baseline snapshot (see pool.gd) -- this
## method only resets what Pool does NOT know about: the synchronous
## is_dead flag this file owns. Never called by Pool itself.
func reset_for_reuse() -> void:
	is_dead = false

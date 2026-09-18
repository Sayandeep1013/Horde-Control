extends RefCounted
class_name CollisionLayers

## CollisionLayers (P1.5; docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Collision Layers (binding, not an example)";
## MASTER_SDLC.md > Provisional Values Register > "Collision layers
## (binding)" row, owner document 20). This file is the single transcription
## of the 16-layer binding table into named bit constants and pre-composed
## masks -- every other file in `src/combat/` references these constants
## instead of re-typing layer numbers, so a wrong bit can only be wrong in
## one place (Phase 02 carried lesson 2's pattern, applied here even though
## this file has no independent second source to diff against -- the
## Register row itself has only one text form, unlike P1.3's six numeric
## caps).
##
## Godot layer/mask integers are 1-indexed in the Inspector and in
## `set_collision_layer_value(N, ...)`, but the underlying `collision_layer`
## / `collision_mask` bitmask is 0-indexed (layer N -> bit N-1). Every
## constant below is written as `1 << (N - 1)` with N taken verbatim from
## the Register row, so the table row and the constant's own comment carry
## the same layer number a reviewer can diff by eye.

## Layer bits (docs/20 > Collision Layers table, "Layer" column).
const LAYER_PLAYER_BODY: int = 1 << 0 # 1 PlayerBody
const LAYER_ENEMY_BODY: int = 1 << 1 # 2 EnemyBody
const LAYER_TOWER_BODY: int = 1 << 2 # 3 TowerBody
const LAYER_WORLD: int = 1 << 3 # 4 World
const LAYER_PLAYER_PROJECTILE: int = 1 << 4 # 5 PlayerProjectile
const LAYER_TOWER_PROJECTILE: int = 1 << 5 # 6 TowerProjectile
const LAYER_ENEMY_PROJECTILE: int = 1 << 6 # 7 EnemyProjectile
const LAYER_PLAYER_HURTBOX: int = 1 << 7 # 8 PlayerHurtbox
const LAYER_ENEMY_HURTBOX: int = 1 << 8 # 9 EnemyHurtbox
const LAYER_TOWER_HURTBOX: int = 1 << 9 # 10 TowerHurtbox
const LAYER_ENEMY_HITBOX: int = 1 << 10 # 11 EnemyHitbox
const LAYER_PICKUP: int = 1 << 11 # 12 Pickup
const LAYER_HAZARD: int = 1 << 12 # 13 Hazard
const LAYER_INTERACTION_RADIUS: int = 1 << 13 # 14 InteractionRadius
const LAYER_ARENA_BOUNDS: int = 1 << 14 # 15 ArenaBounds
const LAYER_PLAYER_COLLECTOR: int = 1 << 15 # 16 PlayerCollector

## Pre-composed masks, one per binding-table row that has a non-"none" Masks
## column. Ground enemies only (P1.5's placeholder is a ground enemy; the
## table's "flying enemies drop 4" carve-out is not implemented here since
## no flying enemy exists yet -- named rather than silently assumed).
const MASK_PLAYER_BODY: int = LAYER_ENEMY_BODY | LAYER_TOWER_BODY | LAYER_WORLD | LAYER_ARENA_BOUNDS # masks 2,3,4,15
const MASK_ENEMY_BODY_GROUND: int = LAYER_PLAYER_BODY | LAYER_ENEMY_BODY | LAYER_TOWER_BODY | LAYER_WORLD | LAYER_ARENA_BOUNDS # masks 1,2,3,4,15
const MASK_PLAYER_PROJECTILE: int = LAYER_ENEMY_HURTBOX | LAYER_WORLD | LAYER_ARENA_BOUNDS # masks 9,4,15
const MASK_TOWER_PROJECTILE: int = LAYER_ENEMY_HURTBOX | LAYER_WORLD | LAYER_ARENA_BOUNDS # masks 9,4,15
const MASK_ENEMY_PROJECTILE: int = LAYER_PLAYER_HURTBOX | LAYER_TOWER_HURTBOX | LAYER_WORLD | LAYER_ARENA_BOUNDS # masks 8,10,4,15
const MASK_ENEMY_HITBOX_PLAYER_ONLY: int = LAYER_PLAYER_HURTBOX # masks 8
const MASK_ENEMY_HITBOX_PLAYER_AND_TOWER: int = LAYER_PLAYER_HURTBOX | LAYER_TOWER_HURTBOX # masks 8, and 10 only for telegraphed attacks aimed at the Tower
const MASK_HAZARD_DEFAULT: int = LAYER_PLAYER_HURTBOX | LAYER_ENEMY_HURTBOX # masks 8,9 (10 only where the biome allows)
const MASK_INTERACTION_RADIUS: int = LAYER_PLAYER_BODY # masks 1
const MASK_PLAYER_COLLECTOR: int = LAYER_PICKUP # masks 12

## Logical Death's dying-body mask (docs/20 > "Logical Death": "the body
## sets collision_layer = 0 and collision_mask to World (4) and ArenaBounds
## (15) only, so a Visual Death ragdoll or knockback still collides with
## terrain and the arena walls but is on no layer anything else can
## detect"). Named once here so death_state.gd does not re-derive it.
const DYING_BODY_MASK: int = LAYER_WORLD | LAYER_ARENA_BOUNDS

extends Area2D
class_name PlayerCollector

## Player Collector (P2.1; docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Physics & Collisions" > "Entity sizes":
## "Player Collector Area2D radius 22 px (body + 8)"; > "Collision Layers"
## table, row 16 "PlayerCollector ... Masks 12" (Pickup)). Radius itself is
## authored on data/player/prototype.tres (PlayerDefinition.
## collector_area_radius_px, Provisional Values Register > Player & Weapons
## > "Player body / hurtbox / collector / magnet") and applied to this
## node's CollisionShape2D by player.gd at _ready(), never hardcoded here.
##
## Unlike Hurtbox (src/combat/hurtbox.gd), which never scans (`monitoring`
## stays false permanently -- every Hurtbox row's Masks column is "none"),
## this Area2D DOES scan: the binding table's PlayerCollector row masks
## Pickup (12), so `monitoring = true` is correct here, mirroring the table
## instead of the Hurtbox convention.
##
## Pickup collection itself (magnet pull, merge/expire, XP/Scrap/Core
## crediting) is P2.8's Wave Director / Pickup Physics task (docs 14, 16),
## not this task's scope (P2.1's Plan inputs list movement, health, hurtbox,
## input buffer, contact damage receipt, death -- no pickup logic). This
## component only wires the collision geometry the binding table requires
## and re-broadcasts overlap as a typed signal, so a pickup system built
## later has a ready-made seam to connect to instead of re-deriving the
## layer/mask/radius setup P2.1 already owns.

## Emitted when a Pickup-layer Area2D starts overlapping this collector.
## No consumer exists yet (P2.8); named and typed now so the pickup system
## connects to an existing signal instead of this file growing pickup logic
## it has no owner document for yet.
signal pickup_entered(area: Area2D)

func _ready() -> void:
	# No src/core/pool.gd `pool_*` group membership: the player is a single
	# persistent entity, never acquired through EntitySpawner/Pool the way
	# enemies, pickups, projectiles, and effects are (src/core/entity_
	# spawner.gd's six pools are all built for those four categories only),
	# so there is no Pool.acquire() call that would ever read a baseline
	# snapshot off this node. Tagging it "pool_hurtbox" anyway would be
	# actively misleading (this is a collector, not a hurtbox) for zero
	# behavioural benefit.
	monitoring = true
	monitorable = false # nothing needs to detect the collector itself, only the reverse
	collision_layer = CollisionLayers.LAYER_PLAYER_COLLECTOR
	collision_mask = CollisionLayers.MASK_PLAYER_COLLECTOR
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	pickup_entered.emit(area)

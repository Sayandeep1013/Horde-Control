extends StaticBody2D
class_name ArenaBounds

## ArenaBounds (P2.2; docs/20_Technical_Architecture.md > Collision Layers
## table, row 15: "ArenaBounds | Arena boundary walls, static body | none").
## Sets collision_layer/mask from src/combat/collision_layers.gd's already-
## transcribed constants (CLAUDE.md: "the layer table is already
## transcribed into named constants. Use it; do not re-transcribe.") rather
## than hardcoding the bit value in this file or in scenes/arena.tscn.
##
## Four CollisionShape2D children (WallNorth/South/East/West), each a
## RectangleShape2D, are added in scenes/arena.tscn -- this script only
## owns the shared body's layer/mask, since all four shapes belong to one
## StaticBody2D.


func _ready() -> void:
	collision_layer = CollisionLayers.LAYER_ARENA_BOUNDS
	collision_mask = 0

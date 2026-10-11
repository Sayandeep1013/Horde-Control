extends Node2D
class_name ArenaSolid
## A large solid landmark (docs/33 section B3, D332): a building, rubble heap or boulder from the
## Tiny Swords pack with a rectangular footprint. ArenaCollision makes the footprint World-layer
## collision, so it blocks the player, enemies and shots, and the FlowField routes round it.
## `footprint_size` / `footprint_offset` are in px from the node origin (the sprite is centred on
## the origin plus `sprite_offset`). Group "arena_solid". Draws at ground level (z 0) like the
## rest of the biome art.

@export var texture: Texture2D
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var sprite_scale: float = 1.0
@export var footprint_size: Vector2 = Vector2(128.0, 64.0)
@export var footprint_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(&"arena_solid")
	z_index = 0
	if texture == null:
		return
	var s := Sprite2D.new()
	s.texture = texture
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = sprite_offset
	s.scale = Vector2.ONE * sprite_scale
	add_child(s)


func get_solid_rects() -> Array[Rect2]:
	return [Rect2(global_position + footprint_offset - footprint_size * 0.5, footprint_size)]

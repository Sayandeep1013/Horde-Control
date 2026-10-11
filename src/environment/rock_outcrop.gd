extends Node2D
class_name RockOutcrop
## Large solid rock outcrops (docs/33 section B3, D332): rectangles of the pack's stone plateau
## (`Tilemap_Elevation.png`: a cobbled top as a 9-slice, rows 0-2, and the banded cliff face, row 3)
## with the pack's own ground shadow under them. Each rect is `Rect2i` cells (top area, at least
## 2 x 2); the cliff row sits one cell south of it. ArenaCollision turns `get_solid_rects()` into
## World-layer collision, so the player, enemies and shots stop at them; the FlowField routes round.
## Group "arena_solid". Static: nothing here moves or ticks.

const TILE_SIZE: int = 64
const CLIFF_ROW: int = 3
const SHADOW_LEFT: Vector2i = Vector2i(0, 0)
const SHADOW_MID: Vector2i = Vector2i(1, 0)
const SHADOW_RIGHT: Vector2i = Vector2i(2, 0)

@export var elevation_texture: Texture2D
@export var shadow_texture: Texture2D
## Top-area cell rects (position = north-west cell, size in cells, each at least 2 x 2).
@export var rects: Array[Rect2i] = []


func _ready() -> void:
	add_to_group(&"arena_solid")
	z_index = 0
	if elevation_texture == null:
		push_warning("RockOutcrop has no elevation_texture; no outcrops will be drawn.")
		return
	var shadow: TileMapLayer = _layer(shadow_texture, [SHADOW_LEFT, SHADOW_MID, SHADOW_RIGHT]) if shadow_texture != null else null
	var face: TileMapLayer = _layer(elevation_texture, _all_coords())
	if shadow != null:
		add_child(shadow)
	add_child(face)
	for r in rects:
		var w: int = maxi(r.size.x, 2)
		var h: int = maxi(r.size.y, 2)
		for dy in h:
			for dx in w:
				var col: int = 0 if dx == 0 else (2 if dx == w - 1 else 1)
				var row: int = 0 if dy == 0 else (2 if dy == h - 1 else 1)
				face.set_cell(r.position + Vector2i(dx, dy), 0, Vector2i(col, row))
		for dx in w:
			var col: int = 0 if dx == 0 else (2 if dx == w - 1 else 1)
			face.set_cell(r.position + Vector2i(dx, h), 0, Vector2i(col, CLIFF_ROW))
			if shadow != null:
				var s: Vector2i = SHADOW_LEFT if dx == 0 else (SHADOW_RIGHT if dx == w - 1 else SHADOW_MID)
				shadow.set_cell(r.position + Vector2i(dx, h + 1), 0, s)


static func _all_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in 4:
		for x in 3:
			out.append(Vector2i(x, y))
	return out


func _layer(texture: Texture2D, coords: Array) -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for c in coords:
		source.create_tile(c)
	ts.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = ts
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


## World-space solid rects (top area plus the cliff row).
func get_solid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in rects:
		var w: int = maxi(r.size.x, 2)
		var h: int = maxi(r.size.y, 2)
		out.append(Rect2(Vector2(r.position) * TILE_SIZE + global_position, Vector2(w, h + 1) * TILE_SIZE))
	return out

extends Node2D
class_name FoamRing

## Animated foam along the island's true edge (art pass, D102; biome brief:
## "animated foam along the island edge (Foam.png 192x192 x8)").
##
## Art-consistency pass (D158): the three Line2D "surf" bands this node used to
## draw are gone. Foam.png is a ring drawn around a 64 px land tile, so, as in
## pond_field.gd, the ring is cut into its nine 64 px sub-tiles and the one that
## falls on each water cell next to the coast is placed there. That is the
## pack's own convention (foam under the land, peeking out into the water),
## done tile by tile so no foam ever lands on the island itself.
##
## The land is the same cell rectangle GroundDetail paints (its coastal sand
## ring runs to the arena edge), so the foam cells are the one-cell ring just
## outside it. Corner cells use the diagonal sub-tile.
##
## DETERMINISM. Each sprite starts on a KeyedRng frame so the ring does not
## pulse in unison.

const FRAME_SIZE: int = 192
const FRAME_COUNT: int = 8
const TILE_SIZE: int = 64
const ANIMATION_NAME: StringName = &"foam"
const FPS: float = 6.0

@export var foam_texture: Texture2D
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)
@export var seed_key: String = "arena_biome"

var _frames: Dictionary = {} # Vector2i offset -> SpriteFrames


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if foam_texture == null:
		push_warning("FoamRing has no foam_texture assigned; no foam will be placed.")
		return
	var half: Vector2 = arena_size / 2.0
	var min_land: Vector2i = FlatAutotile.world_to_cell(-half)
	var max_land: Vector2i = FlatAutotile.world_to_cell(half - Vector2.ONE)
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "coast_foam"])
	for cy in range(min_land.y - 1, max_land.y + 2):
		for cx in range(min_land.x - 1, max_land.x + 2):
			var cell: Vector2i = Vector2i(cx, cy)
			if _is_land(cell, min_land, max_land):
				continue
			for off in _offsets_for(cell, min_land, max_land):
				_place(cell, off, rng)


static func _is_land(cell: Vector2i, min_land: Vector2i, max_land: Vector2i) -> bool:
	return cell.x >= min_land.x and cell.x <= max_land.x and cell.y >= min_land.y and cell.y <= max_land.y


func _offsets_for(cell: Vector2i, min_land: Vector2i, max_land: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_land(cell + d, min_land, max_land):
			out.append(-d)
	for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if _is_land(cell + d, min_land, max_land) and not _is_land(cell + Vector2i(d.x, 0), min_land, max_land) and not _is_land(cell + Vector2i(0, d.y), min_land, max_land):
			out.append(-d)
	return out


func _place(cell: Vector2i, off: Vector2i, rng: RandomNumberGenerator) -> void:
	var foam: AnimatedSprite2D = AnimatedSprite2D.new()
	foam.sprite_frames = _frames_for_offset(off)
	foam.animation = ANIMATION_NAME
	foam.position = FlatAutotile.cell_center(cell)
	foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foam.frame = rng.randi_range(0, FRAME_COUNT - 1)
	add_child(foam)
	foam.play(ANIMATION_NAME)


func _frames_for_offset(off: Vector2i) -> SpriteFrames:
	if _frames.has(off):
		return _frames[off]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIMATION_NAME)
	frames.set_animation_loop_mode(ANIMATION_NAME, SpriteFrames.LOOP_LINEAR)
	frames.set_animation_speed(ANIMATION_NAME, FPS)
	for i in FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = foam_texture
		atlas.region = Rect2(i * FRAME_SIZE + (1 + off.x) * TILE_SIZE, (1 + off.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		frames.add_frame(ANIMATION_NAME, atlas)
	_frames[off] = frames
	return frames

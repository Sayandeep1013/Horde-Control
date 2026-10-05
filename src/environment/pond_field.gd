extends Node2D
class_name PondField

## Inland ponds (biome brief: "2-4 ponds/lakes inside the island with foam
## edges and bobbing water rocks, one crossed by a bridge on a path").
##
## Built from the pack's own tiles (art-consistency pass, D158; the vector
## polygons with a 5 px ink line it replaces were the main reason the ponds
## looked out of place next to the pixel art). Per pond, in draw order:
##   1. WATER, a TileMapLayer of `Terrain/Water/Water.png`, under the water
##      cells AND under the shore cells that touch them, so the scalloped
##      inner edge of the shore reveals water, not grass.
##   2. FOAM, the pack's animated `Foam.png`. Foam.png is a ring drawn around a
##      64 px land tile, so the ring is cut into its nine 64 px sub-tiles and
##      only the sub-tile that falls on each water cell is drawn. That keeps
##      foam strictly on water: it never leaks onto the grass outside the
##      shore and needs no clipping.
##   3. SHORE, a TileMapLayer of Tilemap_Flat's sand tiles (FlatAutotile),
##      `SHORE_CELLS` thick. It is thick enough that a shore cell touches
##      either water or grass but never both, so the two layers underneath
##      (water, grass) always match what the cell's scalloped edge reveals.
##   4. ROCKS, the pack's animated water rocks on water cells.
##
## SHAPE. `pond_axes[i]` is the pond's OUTER (water + shore) semi-axis pair in
## pixels, as before; the water is that ellipse shrunk by the shore thickness,
## with the same smoothed per-angle jitter (KeyedRng) so each pond is unique.
## Water and shore are rasterised to the 64 px grid, so every edge is a
## pack tile. Ponds that are too small for any water keep one water cell.
##
## No collision anywhere: purely visual, like every other biome-pass
## placement (the Register's arena has no interior obstacles).

const TILE_SIZE: int = 64
const ANGLE_SAMPLES: int = 24
const FOAM_FRAME_SIZE: int = 192
const FOAM_FRAME_COUNT: int = 8
const FOAM_FPS: float = 6.0
const ROCK_FRAME_SIZE: int = 128
const ROCK_FRAME_COUNT: int = 8

## Shore thickness in cells (see header, item 3). Two is the minimum for the
## "touches water or grass, never both" rule.
const SHORE_CELLS: int = 2
## Water ellipse = outer axes minus this many px, with a floor so small ponds
## keep at least a row or two of water. The shore (SHORE_CELLS thick) adds the
## rest, so a pond's footprint is a little larger than `pond_axes` and the
## scatter/tree avoid radii in scenes/arena.tscn are raised to match.
const WATER_SHRINK_PX: float = 100.0
const MIN_WATER_AXIS_PX: float = 56.0

@export var water_texture: Texture2D
@export var foam_texture: Texture2D
@export var flat_tilemap_texture: Texture2D
@export var rock_textures: Array[Texture2D] = []

## Parallel arrays: pond i is centred at `pond_centers[i]` with OUTER
## semi-axes `pond_axes[i]`. Hand-placed (see scenes/arena.tscn).
@export var pond_centers: Array[Vector2] = []
@export var pond_axes: Array[Vector2] = []
@export var seed_key: String = "arena_biome"

var _water_cells: Dictionary = {} # all ponds
var _shore_cells: Dictionary = {}
var _water_layer: TileMapLayer = null
var _shore_layer: TileMapLayer = null
var _foam_root: Node2D = null
var _foam_frames: Dictionary = {} # Vector2i offset -> SpriteFrames


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if water_texture == null or flat_tilemap_texture == null:
		push_warning("PondField is missing a required texture; no ponds will be placed.")
		return

	_water_layer = _make_water_layer()
	add_child(_water_layer)
	_foam_root = Node2D.new()
	_foam_root.name = "Foam"
	add_child(_foam_root)
	_shore_layer = TileMapLayer.new()
	_shore_layer.name = "Shore"
	_shore_layer.tile_set = FlatAutotile.make_tileset(flat_tilemap_texture)
	_shore_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shore_layer)

	var per_pond_water: Array[Array] = []
	for i in pond_centers.size():
		var axes: Vector2 = pond_axes[i] if i < pond_axes.size() else Vector2(180.0, 180.0)
		var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "pond", i])
		var jitter: Array[float] = _make_jitter(rng)
		var water: Array[Vector2i] = _rasterise_water(pond_centers[i], axes, jitter)
		per_pond_water.append(water)
		for c in water:
			_water_cells[c] = true
	for i in pond_centers.size():
		_add_shore_for(per_pond_water[i])

	# Water under every water cell and under the shore cells that touch one.
	for c: Vector2i in _water_cells.keys():
		_water_layer.set_cell(c, 0, Vector2i.ZERO)
	for c: Vector2i in _shore_cells.keys():
		if _touches_water(c):
			_water_layer.set_cell(c, 0, Vector2i.ZERO)
	FlatAutotile.paint(_shore_layer, FlatAutotile.SAND, _shore_cells)

	if foam_texture != null:
		_build_foam()
	if not rock_textures.is_empty():
		for i in pond_centers.size():
			var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "pond_rocks", i])
			_place_rocks(per_pond_water[i], rng)


func _make_water_layer() -> TileMapLayer:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = water_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	ts.add_source(source, 0)
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Water"
	layer.tile_set = ts
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


## One random multiplier per angular sample, then a circular 3-point average
## (so neighbours do not diverge sharply).
func _make_jitter(rng: RandomNumberGenerator) -> Array[float]:
	var raw: Array[float] = []
	for i in ANGLE_SAMPLES:
		raw.append(1.0 + rng.randf_range(-0.12, 0.12))
	var smoothed: Array[float] = []
	for i in ANGLE_SAMPLES:
		var prev: float = raw[(i - 1 + ANGLE_SAMPLES) % ANGLE_SAMPLES]
		var nxt: float = raw[(i + 1) % ANGLE_SAMPLES]
		smoothed.append((prev + raw[i] + nxt) / 3.0)
	return smoothed


func _threshold_at(jitter: Array[float], angle: float) -> float:
	var t: float = (angle + PI) / TAU * ANGLE_SAMPLES
	var i0: int = int(floor(t)) % ANGLE_SAMPLES
	var i1: int = (i0 + 1) % ANGLE_SAMPLES
	var frac: float = t - floor(t)
	return lerpf(jitter[i0], jitter[i1], frac)


func _inside(p: Vector2, center: Vector2, axes: Vector2, jitter: Array[float]) -> bool:
	var d: Vector2 = p - center
	var u: float = d.x / axes.x
	var v: float = d.y / axes.y
	var r: float = sqrt(u * u + v * v)
	var angle: float = atan2(v, u)
	return r <= _threshold_at(jitter, angle)


func _rasterise_water(center: Vector2, outer_axes: Vector2, jitter: Array[float]) -> Array[Vector2i]:
	var axes: Vector2 = Vector2(maxf(MIN_WATER_AXIS_PX, outer_axes.x - WATER_SHRINK_PX), maxf(MIN_WATER_AXIS_PX, outer_axes.y - WATER_SHRINK_PX))
	var out: Array[Vector2i] = []
	var min_cell: Vector2i = FlatAutotile.world_to_cell(center - axes * 1.3)
	var max_cell: Vector2i = FlatAutotile.world_to_cell(center + axes * 1.3)
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			if _inside(FlatAutotile.cell_center(cell), center, axes, jitter):
				out.append(cell)
	if out.is_empty():
		out.append(FlatAutotile.world_to_cell(center))
	return out


## Shore = every non-water cell within `SHORE_CELLS` + 0.25 cells of this
## pond's water.
func _add_shore_for(water: Array[Vector2i]) -> void:
	var reach: float = float(SHORE_CELLS) + 0.25
	var r: int = SHORE_CELLS + 1
	for w in water:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cell: Vector2i = w + Vector2i(dx, dy)
				if _water_cells.has(cell) or _shore_cells.has(cell):
					continue
				if Vector2(dx, dy).length() <= reach:
					_shore_cells[cell] = true


func _touches_water(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _water_cells.has(cell + Vector2i(dx, dy)):
				return true
	return false


# --- Foam -----------------------------------------------------------------

func _build_foam() -> void:
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "pond_foam"])
	for cell: Vector2i in _water_cells.keys():
		for off in _foam_offsets_for(cell):
			var foam: AnimatedSprite2D = AnimatedSprite2D.new()
			foam.sprite_frames = _frames_for_offset(off)
			foam.animation = &"foam"
			foam.position = FlatAutotile.cell_center(cell)
			foam.frame = rng.randi_range(0, FOAM_FRAME_COUNT - 1)
			foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_foam_root.add_child(foam)
			foam.play(&"foam")


## For a water cell W, the offsets (from the shore cell R toward W) whose foam
## sub-tile falls on W: every orthogonally adjacent shore cell, plus a diagonal
## shore cell when both cells between it and W are water (a concave corner).
func _foam_offsets_for(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _shore_cells.has(cell + d):
			out.append(-d) # W relative to R
	for d in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		if _shore_cells.has(cell + d) and _water_cells.has(cell + Vector2i(d.x, 0)) and _water_cells.has(cell + Vector2i(0, d.y)):
			out.append(-d)
	return out


func _frames_for_offset(off: Vector2i) -> SpriteFrames:
	if _foam_frames.has(off):
		return _foam_frames[off]
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"foam")
	frames.set_animation_loop_mode(&"foam", SpriteFrames.LOOP_LINEAR)
	frames.set_animation_speed(&"foam", FOAM_FPS)
	for i in FOAM_FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = foam_texture
		atlas.region = Rect2(i * FOAM_FRAME_SIZE + (1 + off.x) * TILE_SIZE, (1 + off.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		frames.add_frame(&"foam", atlas)
	_foam_frames[off] = frames
	return frames


# --- Rocks ----------------------------------------------------------------

func _place_rocks(water: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if water.size() < 3:
		return
	var rock_count: int = rng.randi_range(1, 2)
	for i in rock_count:
		# Only cells whose eight neighbours are all water, so the 128 px rock
		# sits fully on water.
		var interior: Array[Vector2i] = []
		for c in water:
			var ok: bool = true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not _water_cells.has(c + Vector2i(dx, dy)):
						ok = false
			if ok:
				interior.append(c)
		var pool: Array[Vector2i] = interior if not interior.is_empty() else water
		var cell: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		var rock: AnimatedProp = AnimatedProp.new()
		rock.sheet = rock_textures[rng.randi_range(0, rock_textures.size() - 1)]
		rock.frame_size = Vector2i(ROCK_FRAME_SIZE, ROCK_FRAME_SIZE)
		rock.frame_count = ROCK_FRAME_COUNT
		rock.fps = 5.0
		rock.loop_mode = SpriteFrames.LOOP_LINEAR
		rock.start_frame = rng.randi_range(0, ROCK_FRAME_COUNT - 1)
		rock.position = FlatAutotile.cell_center(cell)
		add_child(rock)


# --- Queries (tests, Bridge placement) ------------------------------------

func get_water_cells() -> Dictionary:
	return _water_cells


func get_shore_cells() -> Dictionary:
	return _shore_cells

extends TileMapLayer
class_name ElevationPlateau

## Raised grass plateaus (biome brief: "several raised grass plateaus ...
## placed away from the Tower plaza -- purely visual").
##
## Built from the pack's tiles (art-consistency pass, D158), replacing the
## layered smooth polygons with a 5 px vector outline:
##   * TOP: `Tilemap_Flat.png`'s grass tiles through FlatAutotile, so the
##     plateau edge is the pack's own scalloped ink edge. This node IS that
##     layer, tinted slightly (`TOP_TINT`, self_modulate only) so a hilltop still
##     reads as raised on the three sides that carry no cliff.
##   * CLIFF: `Tilemap_Elevation.png` row 3 (the rock-banded cliff face), one
##     cell under every cell with no cell to its south. Row 3 has a left cap,
##     a middle, a right cap and a one-cell piece (col 3), which is exactly
##     what a run of south-edge cells needs.
##   * SHADOW: the pack's `Shadows.png` blob, resized only by repeating its
##     opaque middle (Derived/shadow_band.png; hard edge, same ink colour and
##     alpha as the pack's), one band under the cliff row.
##
## `Tilemap_Elevation.png` also has a stair row (row 7). Its four 64 px bars are
## a single flight meant for a side-on cut, and every attempt to splice it into
## the cliff row read as a glitch, so the old "approximated stair" is dropped
## (stair_plateau_index is kept so scenes/arena.tscn still loads).
##
## No collision anywhere, as before: enemies and the player walk straight
## across a plateau exactly as they do plain grass.
##
## DETERMINISM via KeyedRng, matching every other placement in this biome pass.

const TILE_SIZE: int = 64

const CLIFF_LEFT: Vector2i = Vector2i(0, 3)
const CLIFF_MID: Vector2i = Vector2i(1, 3)
const CLIFF_RIGHT: Vector2i = Vector2i(2, 3)
const CLIFF_SINGLE: Vector2i = Vector2i(3, 3)

const SHADOW_LEFT: Vector2i = Vector2i(0, 0)
const SHADOW_MID: Vector2i = Vector2i(1, 0)
const SHADOW_RIGHT: Vector2i = Vector2i(2, 0)

## A touch richer/warmer than the flat `Floor` grass, applied to the top layer
## only (self_modulate), not the cliff.
const TOP_TINT: Color = Color(0.86, 1.0, 0.72)

const BLOB_SAMPLES: int = 64
const BLOB_SQUASH_Y: float = 0.72

@export var flat_tilemap_texture: Texture2D # Tilemap_Flat.png, for the grass top
@export var elevation_texture: Texture2D # Tilemap_Elevation.png, for the cliff face
@export var shadow_texture: Texture2D # Derived/shadow_band.png (from the pack's Shadows.png)

## Plateau anchor centres, hand-placed (see scenes/arena.tscn).
@export var plateau_centers: Array[Vector2] = []
@export var plateau_radii: Array[float] = [] # approx blob radius per centre
@export var stair_plateau_index: int = 0 # unused since D158, see header
@export var seed_key: String = "arena_biome"

var _top_cells: Dictionary = {}
var _cliff_cells: Dictionary = {}
var _face: TileMapLayer = null
var _shadow: TileMapLayer = null


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if flat_tilemap_texture == null or elevation_texture == null:
		push_warning("ElevationPlateau is missing a texture; no plateaus will be placed.")
		return
	tile_set = FlatAutotile.make_tileset(flat_tilemap_texture)
	self_modulate = TOP_TINT
	_build_face_layer()
	if shadow_texture != null:
		_build_shadow_layer()

	for i in plateau_centers.size():
		var radius: float = plateau_radii[i] if i < plateau_radii.size() else 280.0
		var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "plateau", i])
		var poly: PackedVector2Array = _blob_points(plateau_centers[i], radius, rng)
		for cell in _rasterise(poly):
			_top_cells[cell] = true
	_clean(_top_cells)
	_square_bottom(_top_cells)

	FlatAutotile.paint(self, FlatAutotile.GRASS, _top_cells)
	_paint_cliff()


func _build_face_layer() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = elevation_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [CLIFF_LEFT, CLIFF_MID, CLIFF_RIGHT, CLIFF_SINGLE]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	_face = TileMapLayer.new()
	_face.name = "Cliff"
	_face.tile_set = ts
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_face)


func _build_shadow_layer() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = shadow_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [SHADOW_LEFT, SHADOW_MID, SHADOW_RIGHT]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	_shadow = TileMapLayer.new()
	_shadow.name = "Shadow"
	_shadow.tile_set = ts
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_shadow)


## An irregular blob: a circle with smoothed random radius jitter, squashed
## vertically (the view is top-down with a tilt).
func _blob_points(center: Vector2, radius: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var raw: Array[float] = []
	for k in BLOB_SAMPLES:
		raw.append(1.0 + rng.randf_range(-0.08, 0.08))
	for _pass in 2:
		var smoothed: Array[float] = []
		for k in BLOB_SAMPLES:
			var acc: float = 0.0
			for d in range(-2, 3):
				acc += raw[(k + d + BLOB_SAMPLES) % BLOB_SAMPLES]
			smoothed.append(acc / 5.0)
		raw = smoothed
	var pts: PackedVector2Array = PackedVector2Array()
	for k in BLOB_SAMPLES:
		var a: float = float(k) / float(BLOB_SAMPLES) * TAU
		pts.append(center + Vector2(cos(a), sin(a) * BLOB_SQUASH_Y) * radius * raw[k])
	return pts


func _rasterise(poly: PackedVector2Array) -> Array[Vector2i]:
	var min_p: Vector2 = poly[0]
	var max_p: Vector2 = poly[0]
	for p in poly:
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.y))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.y))
	var out: Array[Vector2i] = []
	var a: Vector2i = FlatAutotile.world_to_cell(min_p)
	var b: Vector2i = FlatAutotile.world_to_cell(max_p)
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			if Geometry2D.is_point_in_polygon(FlatAutotile.cell_center(cell), poly):
				out.append(cell)
	return out


## Two passes: fill a cell with three orthogonal neighbours (notches) and drop
## a cell with at most one (spikes), so no run is thinner than two cells.
static func _clean(cells: Dictionary) -> void:
	for _pass in 2:
		var add: Array[Vector2i] = []
		var drop: Array[Vector2i] = []
		var candidates: Dictionary = {}
		for cell: Vector2i in cells.keys():
			for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				candidates[cell + d] = true
		for cell: Vector2i in candidates.keys():
			var n: int = 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if cells.has(cell + d):
					n += 1
			if cells.has(cell):
				if n <= 1:
					drop.append(cell)
			elif n >= 3:
				add.append(cell)
		for c in add:
			cells[c] = true
		for c in drop:
			cells.erase(c)


## D169: a bottom edge that steps down by one row beside a cell leaves that cell's
## cliff one row above the neighbouring run's (the corner cliff columns ended a row
## short in review captures). Extend such a cell down so the whole south edge is one
## row, with the pack's left and right cliff caps at its two ends.
static func _square_bottom(cells: Dictionary) -> void:
	for _pass in 2:
		var add: Array[Vector2i] = []
		for cell: Vector2i in cells.keys():
			if cells.has(cell + Vector2i(0, 1)):
				continue
			if cells.has(cell + Vector2i(-1, 1)) or cells.has(cell + Vector2i(1, 1)):
				add.append(cell + Vector2i(0, 1))
		if add.is_empty():
			break
		for c in add:
			cells[c] = true


## A cliff cell directly south of every top cell with no top cell to its south;
## a shadow band cell directly south of every cliff cell.
func _paint_cliff() -> void:
	for cell: Vector2i in _top_cells.keys():
		if not _top_cells.has(cell + Vector2i(0, 1)):
			_cliff_cells[cell + Vector2i(0, 1)] = true
	for cell: Vector2i in _cliff_cells.keys():
		var has_w: bool = _cliff_cells.has(cell + Vector2i(-1, 0))
		var has_e: bool = _cliff_cells.has(cell + Vector2i(1, 0))
		var coord: Vector2i = CLIFF_MID
		if not has_w and not has_e:
			coord = CLIFF_SINGLE
		elif not has_w:
			coord = CLIFF_LEFT
		elif not has_e:
			coord = CLIFF_RIGHT
		_face.set_cell(cell, 0, coord)
	if _shadow == null:
		return
	for cell: Vector2i in _cliff_cells.keys():
		var below: Vector2i = cell + Vector2i(0, 1)
		if _top_cells.has(below) or _cliff_cells.has(below):
			continue
		var has_w: bool = _cliff_cells.has(cell + Vector2i(-1, 0))
		var has_e: bool = _cliff_cells.has(cell + Vector2i(1, 0))
		var coord: Vector2i = SHADOW_MID
		if not has_w:
			coord = SHADOW_LEFT
		elif not has_e:
			coord = SHADOW_RIGHT
		_shadow.set_cell(below, 0, coord)


func get_top_cells() -> Dictionary:
	return _top_cells


func get_cliff_cells() -> Dictionary:
	return _cliff_cells

extends TileMapLayer
class_name ElevationPlateau

## Raised grass plateaus (biome brief: "several raised grass plateaus ...
## placed away from the Tower plaza -- purely visual").
##
## REBUILT this session after a supervisor review of the first version's
## captures: that version painted the WHOLE plateau top from
## Tilemap_Elevation.png, which turned out (confirmed twice now by direct
## PIL pixel sampling -- see the second inspection's per-cell RGB averages,
## every one G approx B and both well above R, i.e. a blue-grey/teal
## palette, never green) to have no grass-coloured tiles anywhere in its
## 32 cells. Painting it read as "a grey stone ring", not raised grass, no
## matter how the edges were classified. This version paints the TOP from
## `Tilemap_Flat.png`'s own grass 9-slice instead (cols 0-2, rows 0-2 --
## the same sheet and the same "9-slice blob" technique ground_detail.gd
## already uses for sand, confirmed genuinely green by the same pixel
## sampling: centre tile average (152,179,88)). Tilemap_Elevation.png is
## kept, but now ONLY for the south-facing cliff FACE (row 3's rock-banded
## tiles, which the supervisor separately described as "brown/grey rock
## wall" and this file's own inspection likewise reads as distinctly
## darker/rockier than the grass -- that part of the original reading was
## correct) plus a Shadows.png strip under its lip.
##
## No dedicated "stairs" tile exists anywhere in Tilemap_Elevation.png --
## re-verified this session with a full per-cell colour AND alpha-coverage
## scan, not just a visual grid read, and confirmed no file with "stair" in
## its name exists anywhere under assets/third_party/tiny_swords/ either.
## `_paint_face_and_shadow()`'s `with_stair` parameter approximates one
## honestly, as a gap left open in the wall, rather than inventing art
## that is not in the sheet.
##
## No collision anywhere -- these are flat images; the "raised" read comes
## from the grass top's own tint (a touch richer/warmer than the flat
## `Floor` grass, so a hilltop is still perceptible even on the sides that
## carry no cliff face) plus the south wall and its shadow. Enemies and the
## player walk straight across/through a plateau exactly as they do plain
## grass.
##
## DETERMINISM via KeyedRng, matching every other placement in this biome
## pass.

const TILE_SIZE: int = 64

## Grass 9-slice, Tilemap_Flat.png cols 0-2 rows 0-2 (PIL-confirmed this
## session: row1-col1's average colour (152,179,88) has zero alpha holes,
## i.e. the FILL tile; the surrounding 8 cells all skew slightly lower in
## alpha-coverage, i.e. genuine edge/corner cuts -- the same pattern
## ground_detail.gd's own header already documented for the sand 9-slice
## at cols 5-7).
const GRASS_TL: Vector2i = Vector2i(0, 0)
const GRASS_T: Vector2i = Vector2i(1, 0)
const GRASS_TR: Vector2i = Vector2i(2, 0)
const GRASS_L: Vector2i = Vector2i(0, 1)
const GRASS_FILL: Vector2i = Vector2i(1, 1)
const GRASS_R: Vector2i = Vector2i(2, 1)
const GRASS_BL: Vector2i = Vector2i(0, 2)
const GRASS_B: Vector2i = Vector2i(1, 2)
const GRASS_BR: Vector2i = Vector2i(2, 2)

const ELEV_FACE_FILL: Vector2i = Vector2i(1, 3)
const ELEV_FACE_L: Vector2i = Vector2i(0, 3)
const ELEV_FACE_R: Vector2i = Vector2i(3, 3)

## A touch richer/warmer than the flat `Floor` grass (which paints
## Tilemap_Flat.png's own fill tile at full white modulate), so a hilltop
## still reads as a distinct raised patch even on the three sides that
## carry no cliff face.
const TOP_TINT: Color = Color(0.86, 1.0, 0.72)

@export var flat_tilemap_texture: Texture2D # Tilemap_Flat.png, for the grass top
@export var elevation_texture: Texture2D # Tilemap_Elevation.png, for the cliff face only now
@export var shadow_texture: Texture2D

## Plateau anchor centres, hand-placed (see scenes/arena.tscn for why each
## site was chosen: clear of the Tower plaza, the coastal band and every
## other landmark). Small organic variation still comes from KeyedRng, but
## which QUADRANT each plateau reads in is deliberate art direction, not
## left to a rejection-sampling loop -- matching the existing
## LandmarkScarecrow/Signpost convention in this same scene file.
@export var plateau_centers: Array[Vector2] = []
@export var plateau_radii: Array[float] = [] # approx blob radius per centre, same size as plateau_centers
@export var stair_plateau_index: int = 0 # which plateau gets the approximated stair gap
@export var seed_key: String = "arena_biome"

var _face: TileMapLayer = null


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if flat_tilemap_texture == null or elevation_texture == null:
		push_warning("ElevationPlateau is missing a required texture; no plateaus will be placed.")
		return
	modulate = TOP_TINT
	_build_top_tileset()
	_build_face_layer()
	for i in plateau_centers.size():
		var radius: float = plateau_radii[i] if i < plateau_radii.size() else 280.0
		var cells: Dictionary = _grow_blob(plateau_centers[i], radius, i)
		cells = _smooth(cells)
		_paint_top(cells)
		_paint_face_and_shadow(cells, i == stair_plateau_index)


func _build_top_tileset() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = flat_tilemap_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [GRASS_TL, GRASS_T, GRASS_TR, GRASS_L, GRASS_FILL, GRASS_R, GRASS_BL, GRASS_B, GRASS_BR]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	tile_set = ts


func _build_face_layer() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = elevation_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [ELEV_FACE_FILL, ELEV_FACE_L, ELEV_FACE_R]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	_face = TileMapLayer.new()
	_face.name = "Face"
	_face.tile_set = ts
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.z_index = 0
	_face.z_as_relative = true # relative to this node, which is already absolute
	# The face is rock, not grass -- undo this node's own TOP_TINT so it
	# does not also come out tinted green.
	_face.modulate = Color.WHITE / TOP_TINT
	add_child(_face) # added once, before any per-plateau Shadow sprites are appended


func _world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))


## Organic blob via a "plus-stamp" random walk: each step fills the
## cursor's own cell AND its four orthogonal neighbours before advancing,
## which reliably produces a solid, roughly round blob within `radius`
## (a plain single-cell random walk left visible gaps at this tile size).
func _grow_blob(center: Vector2, radius: float, index: int) -> Dictionary:
	var cells: Dictionary = {}
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "plateau", index])
	var cursor: Vector2i = _world_to_cell(center)
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var steps: int = maxi(12, int(radius * radius / (TILE_SIZE * TILE_SIZE) * 1.4))
	var max_r_sq: float = radius * radius
	for i in steps:
		cells[cursor] = true
		for d in dirs:
			cells[cursor + d] = true
		var next_cursor: Vector2i = cursor + dirs[rng.randi_range(0, 3)]
		var world: Vector2 = Vector2(next_cursor.x * TILE_SIZE, next_cursor.y * TILE_SIZE)
		if world.distance_squared_to(center) <= max_r_sq:
			cursor = next_cursor
		# else: reject the step outside the radius cap and try again next iteration
	return cells


## One cellular-automata pass (procedural-generation skill's cave-smoothing
## recipe), fill-only: a cell that is currently empty but has >= 5 of its 8
## neighbours filled becomes filled. Turns the plus-stamp blob's remaining
## concave single-cell notches into a rounder silhouette with no single-
## tile stair-steps. Never removes an already-filled cell.
func _smooth(cells: Dictionary) -> Dictionary:
	var out: Dictionary = cells.duplicate()
	var candidates: Dictionary = {}
	for cell: Vector2i in cells.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				candidates[cell + Vector2i(dx, dy)] = true
	for cell: Vector2i in candidates.keys():
		if cells.has(cell):
			continue
		var filled_neighbors: int = 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				if cells.has(cell + Vector2i(dx, dy)):
					filled_neighbors += 1
		if filled_neighbors >= 5:
			out[cell] = true
	return out


## Paints the plateau's full top -- fill in the interior, the matching
## edge/corner tile at the silhouette (same 9-slice blob technique
## ground_detail.gd uses for sand, applied to Tilemap_Flat's grass 9-slice
## instead of its sand one).
func _paint_top(cells: Dictionary) -> void:
	for cell: Vector2i in cells.keys():
		var has_n: bool = cells.has(cell + Vector2i(0, -1))
		var has_s: bool = cells.has(cell + Vector2i(0, 1))
		var has_e: bool = cells.has(cell + Vector2i(1, 0))
		var has_w: bool = cells.has(cell + Vector2i(-1, 0))
		set_cell(cell, 0, _atlas_coord_for(has_n, has_s, has_e, has_w))


static func _atlas_coord_for(has_n: bool, has_s: bool, has_e: bool, has_w: bool) -> Vector2i:
	if not has_n and not has_w:
		return GRASS_TL
	if not has_n and not has_e:
		return GRASS_TR
	if not has_s and not has_w:
		return GRASS_BL
	if not has_s and not has_e:
		return GRASS_BR
	if not has_n:
		return GRASS_T
	if not has_s:
		return GRASS_B
	if not has_w:
		return GRASS_L
	if not has_e:
		return GRASS_R
	return GRASS_FILL


## Cliff face row(s): one FACE tile directly south of every cell that is
## the blob's own south-facing edge (has_s == false), plus a Shadows.png
## strip grounding the wall's foot. Shadow sprites are added to this node
## (NOT to `_face`) before `_face` itself was added to the tree back in
## `_build_face_layer()`, so draw order is Shadow (behind) then Face (in
## front) wherever the two overlap.
##
## `with_stair`: approximates a stair (class header: no stair tile exists
## anywhere in the inspected sheet) as a two-column GAP left open in the
## middle of the wall -- a gentle grass slope breaking the sheer cliff face
## on this one plateau, rather than inventing stair art that is not in the
## sheet. Purely visual either way; nothing in this scene has collision.
func _paint_face_and_shadow(cells: Dictionary, with_stair: bool) -> void:
	var south_edge: Array[Vector2i] = []
	for cell: Vector2i in cells.keys():
		if not cells.has(cell + Vector2i(0, 1)):
			south_edge.append(cell)
	if south_edge.is_empty():
		return

	var gap_x: int = 1 << 30 # far outside any real cell range when there is no stair
	if with_stair:
		var min_x: int = south_edge[0].x
		var max_x: int = south_edge[0].x
		for cell in south_edge:
			min_x = mini(min_x, cell.x)
			max_x = maxi(max_x, cell.x)
		gap_x = (min_x + max_x) / 2

	for cell: Vector2i in south_edge:
		if with_stair and (cell.x == gap_x or cell.x == gap_x + 1):
			continue # leave this stretch of wall open -- the stair gap
		var face_cell: Vector2i = cell + Vector2i(0, 1)
		var has_w: bool = south_edge.has(cell + Vector2i(-1, 0))
		var has_e: bool = south_edge.has(cell + Vector2i(1, 0))
		var coord: Vector2i = ELEV_FACE_FILL
		if not has_w:
			coord = ELEV_FACE_L
		elif not has_e:
			coord = ELEV_FACE_R
		_face.set_cell(face_cell, 0, coord)
	if shadow_texture != null:
		_place_shadow_strip(south_edge)


func _place_shadow_strip(south_edge: Array[Vector2i]) -> void:
	var min_x: int = south_edge[0].x
	var max_x: int = south_edge[0].x
	var y: int = south_edge[0].y
	for cell in south_edge:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		y = maxi(y, cell.y)
	var width_px: float = float(max_x - min_x + 1) * TILE_SIZE
	var face_row_bottom_px: float = float(y + 2) * TILE_SIZE # south edge of the FACE row below the top
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = shadow_texture
	shadow.scale = Vector2(width_px / shadow_texture.get_width(), 0.4)
	var shadow_half_height: float = shadow_texture.get_height() * shadow.scale.y * 0.5
	shadow.position = Vector2(
		(min_x + max_x + 1) * 0.5 * TILE_SIZE,
		face_row_bottom_px - 15.0 + shadow_half_height # a 15px tuck under the face row's own bottom edge
	)
	shadow.modulate = Color(0.15, 0.15, 0.2, 0.75) / TOP_TINT # undo this node's own TOP_TINT
	shadow.z_index = 0
	shadow.z_as_relative = true
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(shadow)
	move_child(shadow, 0) # stays behind `_face`, added earlier at index 0 -- keep shadows before it

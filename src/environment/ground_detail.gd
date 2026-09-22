extends TileMapLayer
class_name GroundDetail

## Ground detail overlay (art pass, D102). Paints organic sand onto the
## grass `Floor` beneath it: a clearing around the Tower, a handful of
## free-standing patches, path strips connecting them, and a coastal ring
## around the whole arena so the play space reads as an island rather than
## an infinite grass plain (author's biome brief: "a green grassland
## island ... with a few organic sand patches/paths ... including a
## sand/stone clearing around the Tower").
##
## WHY A TileMapLayer. `Terrain/Ground/Tilemap_Flat.png`'s sand tiles (atlas
## cols 5-7, rows 0-2) are a classic 3x3 "blob" autotile set -- each tile is
## drawn on a TRANSPARENT background with a jagged alpha edge on whichever
## sides face away from more sand, so stamping the correctly-chosen tile at
## each cell lets the grass `Floor` sprite show through at the boundary and
## the patch reads as organically shaped rather than a hard-edged rectangle.
## `_atlas_coord_for()` below is a hand-rolled 3x3 blob lookup (no Godot
## Terrain/peering-bit setup): cheaper to build from code and exactly
## matches what this file needs (one terrain, no diagonal-only cases to
## resolve) -- see godot-prompter:2d-essentials, "TileMap System", for the
## general TileSet/TileMapLayer API this follows.
##
## The TileSet itself is built once in `_ready()` from the same
## Tilemap_Flat.png sheet the grass fill tile was cropped from (see
## `assets/third_party/tiny_swords/PROVENANCE.md`, `Derived/` rows) --
## "generated from code" per the biome brief, no `.tres` checked in.
##
## DETERMINISM. Every placement below is seeded through `KeyedRng`, matching
## `scenery_scatter.gd`'s own precedent (that file's header explains why:
## a feel check, a bug report and a recorded run should describe the same
## world). No interior obstacles are added -- this paints tiles on the
## existing floor band (z_index 0), never a collider (MASTER_SDLC.md >
## Game Overview > Perspective and Arena's "no interior obstacles" rule,
## which is about pathing/cover, not art).

const TILE_SIZE: int = 64

## Sand 9-slice, atlas cols 5-7 rows 0-2 of Tilemap_Flat.png (task brief:
## "sand 9-slice cols 5-7" -- confirmed by direct pixel inspection during
## this session: each of the 9 tiles below is drawn with a jagged alpha
## edge on exactly the sides that are NOT covered by more sand, i.e. a
## standard corner/edge/fill 3x3 blob).
const SAND_TL: Vector2i = Vector2i(5, 0)
const SAND_T: Vector2i = Vector2i(6, 0)
const SAND_TR: Vector2i = Vector2i(7, 0)
const SAND_L: Vector2i = Vector2i(5, 1)
const SAND_FILL: Vector2i = Vector2i(6, 1)
const SAND_R: Vector2i = Vector2i(7, 1)
const SAND_BL: Vector2i = Vector2i(5, 2)
const SAND_B: Vector2i = Vector2i(6, 2)
const SAND_BR: Vector2i = Vector2i(7, 2)

@export var flat_tilemap_texture: Texture2D
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)
@export var tower_center: Vector2 = Vector2.ZERO

## Radius of the sand/stone clearing around the Tower. Bigger than
## SceneryScatter's own tower_clear_radius_px (320 px, the Interaction
## Radius doubled) so the clearing's visible edge sits just outside where
## ground clutter already stops, rather than the two boundaries
## coinciding.
@export var tower_clearing_radius_px: float = 400.0

## How far in from the true arena edge the coastal sand ring extends.
## Density/feel numbers, not gameplay numbers -- see class header.
@export var coastal_band_px: float = 176.0
@export var patch_count: int = 4
@export var path_count: int = 3
@export var seed_key: String = "arena_biome"

var _sand: Dictionary = {}


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if flat_tilemap_texture == null:
		push_warning("GroundDetail has no flat_tilemap_texture assigned; no sand will be painted.")
		return
	_build_tileset()
	_mark_tower_clearing()
	_mark_coastal_ring()
	_mark_patches_and_paths()
	_paint()


func _build_tileset() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = flat_tilemap_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [SAND_TL, SAND_T, SAND_TR, SAND_L, SAND_FILL, SAND_R, SAND_BL, SAND_B, SAND_BR]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	tile_set = ts


func _world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))


func _mark_tower_clearing() -> void:
	var r: float = tower_clearing_radius_px
	var r_sq: float = r * r
	var min_cell: Vector2i = _world_to_cell(tower_center - Vector2(r, r))
	var max_cell: Vector2i = _world_to_cell(tower_center + Vector2(r, r))
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var center: Vector2 = Vector2(cx * TILE_SIZE + TILE_SIZE / 2.0, cy * TILE_SIZE + TILE_SIZE / 2.0)
			if center.distance_squared_to(tower_center) <= r_sq:
				_sand[Vector2i(cx, cy)] = true


func _mark_coastal_ring() -> void:
	var half: Vector2 = arena_size / 2.0
	var min_cell: Vector2i = _world_to_cell(-half)
	var max_cell: Vector2i = _world_to_cell(half - Vector2.ONE)
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var center: Vector2 = Vector2(cx * TILE_SIZE + TILE_SIZE / 2.0, cy * TILE_SIZE + TILE_SIZE / 2.0)
			if half.x - absf(center.x) <= coastal_band_px or half.y - absf(center.y) <= coastal_band_px:
				_sand[Vector2i(cx, cy)] = true


func _mark_patches_and_paths() -> void:
	var half: Vector2 = arena_size / 2.0
	var inner_margin: float = coastal_band_px + TILE_SIZE * 2.0
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sand_patches", patch_count])

	var patch_centers: Array[Vector2] = []
	var attempts: int = 0
	while patch_centers.size() < patch_count and attempts < patch_count * 20:
		attempts += 1
		var p: Vector2 = Vector2(
			rng.randf_range(-half.x + inner_margin, half.x - inner_margin),
			rng.randf_range(-half.y + inner_margin, half.y - inner_margin)
		)
		if p.distance_to(tower_center) < tower_clearing_radius_px + 260.0:
			continue # leave a grass gap between the clearing and a patch
		patch_centers.append(p)
		_grow_blob(p, rng)

	# Paths: organic 2-tile-wide corridors from the Tower clearing's edge
	# out toward a few of the patches, so the clearing does not sit
	# isolated in a sea of grass.
	var path_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sand_paths", path_count])
	var path_targets: int = mini(path_count, patch_centers.size())
	for i in path_targets:
		_carve_path(tower_center, patch_centers[i], path_rng)


func _grow_blob(origin: Vector2, rng: RandomNumberGenerator) -> void:
	var cell: Vector2i = _world_to_cell(origin)
	var steps: int = rng.randi_range(18, 34)
	var cursor: Vector2i = cell
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for i in steps:
		_sand[cursor] = true
		# Occasionally also fill an orthogonal neighbour so the blob reads
		# as a filled patch rather than a single-cell-wide scribble.
		_sand[cursor + dirs[rng.randi_range(0, 3)]] = true
		cursor += dirs[rng.randi_range(0, 3)]


func _carve_path(from_pos: Vector2, to_pos: Vector2, rng: RandomNumberGenerator) -> void:
	var dist: float = from_pos.distance_to(to_pos)
	var steps: int = maxi(4, int(dist / (TILE_SIZE * 1.5)))
	var perpendicular: Vector2 = (to_pos - from_pos).orthogonal().normalized()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var jitter: float = rng.randf_range(-1.0, 1.0) * TILE_SIZE * 1.5
		var p: Vector2 = from_pos.lerp(to_pos, t) + perpendicular * jitter
		var c: Vector2i = _world_to_cell(p)
		# A 2-tile-wide corridor: the sampled cell plus its immediate
		# neighbours on the perpendicular axis.
		_sand[c] = true
		_sand[c + Vector2i(1, 0)] = true
		_sand[c + Vector2i(0, 1)] = true


func _paint() -> void:
	for cell in _sand.keys():
		var has_n: bool = _sand.has(cell + Vector2i(0, -1))
		var has_s: bool = _sand.has(cell + Vector2i(0, 1))
		var has_e: bool = _sand.has(cell + Vector2i(1, 0))
		var has_w: bool = _sand.has(cell + Vector2i(-1, 0))
		set_cell(cell, 0, _atlas_coord_for(has_n, has_s, has_e, has_w))


static func _atlas_coord_for(has_n: bool, has_s: bool, has_e: bool, has_w: bool) -> Vector2i:
	if not has_n and not has_w:
		return SAND_TL
	if not has_n and not has_e:
		return SAND_TR
	if not has_s and not has_w:
		return SAND_BL
	if not has_s and not has_e:
		return SAND_BR
	if not has_n:
		return SAND_T
	if not has_s:
		return SAND_B
	if not has_w:
		return SAND_L
	if not has_e:
		return SAND_R
	return SAND_FILL


func get_sand_cell_count_for_test() -> int:
	return _sand.size()

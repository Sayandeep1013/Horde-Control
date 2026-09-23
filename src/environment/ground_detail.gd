extends TileMapLayer
class_name GroundDetail

## Ground detail overlay (art pass, D102). Paints organic sand onto the
## grass `Floor` beneath it: a handful of free-standing patches and a
## coastal ring around the whole arena so the play space reads as an
## island rather than an infinite grass plain (author's biome brief: "a
## green grassland island ... with a few organic sand patches").
##
## THE TOWER PLAZA AND EVERY PATH LIVE ELSEWHERE NOW. This file used to
## also tile-stamp the Tower clearing, the landmark clearings and every
## connecting path; a supervisor review of this session's own captures
## called that out by name -- 64px tile stamps produce a visible single-
## tile staircase on any diagonal, and a tile-stamped circle reads as "a
## jagged cross" once several paths converge on it, not the rounded plaza
## the biome brief asks for. `sand_network.gd` (a sibling node in
## scenes/arena.tscn, placed after this one) replaces all of that with a
## single smooth Polygon2D + Line2D shape (a rounded plaza, rounded
## landmark clearings and curved ribbon paths, unioned via
## `Geometry2D.merge_polygons` into one seamless outline) -- vector shapes
## do not have this file's 64px grid problem at all. `get_patch_centers()`
## below is this file's side of that split: sand_network.gd still needs to
## know where the random patches below ended up so it can route a path
## ribbon to each one.
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

## Kept only as the "stay clear of the plaza" radius patches are rejection-
## sampled against below; sand_network.gd owns the plaza's own radius
## export now (its `plaza_radius_px`), since it is the one that actually
## renders it.
@export var tower_clearing_radius_px: float = 400.0

## How far in from the true arena edge the coastal sand ring extends.
## Density/feel numbers, not gameplay numbers -- see class header.
@export var coastal_band_px: float = 176.0
@export var patch_count: int = 4
@export var seed_key: String = "arena_biome"

var _sand: Dictionary = {}
var _patch_centers: Array[Vector2] = []


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if flat_tilemap_texture == null:
		push_warning("GroundDetail has no flat_tilemap_texture assigned; no sand will be painted.")
		return
	_build_tileset()
	_mark_coastal_ring()
	_mark_patches()
	_sand = _smooth(_sand)
	_paint()


## sand_network.gd (a later sibling in scenes/arena.tscn) reads this after
## this node's own _ready() has already run, to route one path ribbon to
## each random patch -- see the class header for why the two files split
## this way.
func get_patch_centers() -> Array[Vector2]:
	return _patch_centers


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


func _mark_coastal_ring() -> void:
	var half: Vector2 = arena_size / 2.0
	var min_cell: Vector2i = _world_to_cell(-half)
	var max_cell: Vector2i = _world_to_cell(half - Vector2.ONE)
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var center: Vector2 = Vector2(cx * TILE_SIZE + TILE_SIZE / 2.0, cy * TILE_SIZE + TILE_SIZE / 2.0)
			if half.x - absf(center.x) <= coastal_band_px or half.y - absf(center.y) <= coastal_band_px:
				_sand[Vector2i(cx, cy)] = true


## Random free-standing sand patches only -- no paths (see class header;
## sand_network.gd routes a smooth ribbon to each of `_patch_centers`
## instead of this file carving one itself).
func _mark_patches() -> void:
	var half: Vector2 = arena_size / 2.0
	var inner_margin: float = coastal_band_px + TILE_SIZE * 2.0
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sand_patches", patch_count])

	var attempts: int = 0
	while _patch_centers.size() < patch_count and attempts < patch_count * 20:
		attempts += 1
		var p: Vector2 = Vector2(
			rng.randf_range(-half.x + inner_margin, half.x - inner_margin),
			rng.randf_range(-half.y + inner_margin, half.y - inner_margin)
		)
		if p.distance_to(tower_center) < tower_clearing_radius_px + 260.0:
			continue # leave a grass gap between the plaza and a patch
		_patch_centers.append(p)
		_grow_blob(p, rng)


## One lenient cellular-automata pass (procedural-generation skill's cave-
## smoothing recipe): fills a concave single-cell notch (>= 5 of 8
## neighbours already sand) and drops a near-isolated protruding cell
## (< 3 of 8 neighbours sand), leaving every patch blob's own body
## untouched. This is what turns the random-walk patches' and the coastal
## ring's single-tile staircase edges into a rounder, organic coastline --
## this task's own "no single-tile stair-steps" requirement.
func _smooth(cells: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var candidates: Dictionary = {}
	for cell: Vector2i in cells.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				candidates[cell + Vector2i(dx, dy)] = true
	for cell: Vector2i in candidates.keys():
		var filled_neighbors: int = 0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				if cells.has(cell + Vector2i(dx, dy)):
					filled_neighbors += 1
		var was_filled: bool = cells.has(cell)
		if was_filled and filled_neighbors >= 3:
			out[cell] = true
		elif not was_filled and filled_neighbors >= 5:
			out[cell] = true
	return out


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

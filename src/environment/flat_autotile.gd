class_name FlatAutotile
extends RefCounted

## Cell-set autotiler for the pack's own flat ground sheet
## (`Terrain/Ground/Tilemap_Flat.png`, 64 px tiles; art-consistency pass, D158).
##
## The sheet carries two terrains with the same layout (grass at atlas cols 0-3,
## sand at cols 5-8): a 3x3 "blob" 9-slice, a one-cell-wide vertical strip
## (top cap / middle / bottom cap), a one-cell-high horizontal strip (left cap /
## middle / right cap) and a single island tile. Every one of them is drawn on a
## transparent background with the pack's own scalloped 2-texel ink edge, so
## stamping the right tile per cell reproduces the pack's coastline exactly,
## with no vector outline.
##
## The pack has no inner-corner tiles. A concave corner is therefore painted
## with the fill tile; the two edge tiles beside it close the corner cleanly
## (checked in captures).
##
## `coord_for()` classifies a cell from which of its four orthogonal neighbours
## belong to the same cell set. Both ground_detail.gd, sand_network.gd,
## pond_field.gd and elevation_plateau.gd use it, so every shore in the arena
## is the same art.

const TILE_SIZE: int = 64
const GRASS: int = 0 # base atlas column of the grass terrain
const SAND: int = 5 # base atlas column of the sand terrain


## Atlas coordinate for a cell of `terrain_base_col`'s terrain given which of its
## orthogonal neighbours are in the same set.
static func coord_for(terrain_base_col: int, has_n: bool, has_s: bool, has_e: bool, has_w: bool) -> Vector2i:
	var c: int = terrain_base_col
	var local: Vector2i
	if has_n and has_s and has_e and has_w:
		local = Vector2i(1, 1) # fill
	elif has_n and has_s and has_e:
		local = Vector2i(0, 1) # missing W: left edge
	elif has_n and has_s and has_w:
		local = Vector2i(2, 1) # missing E: right edge
	elif has_n and has_e and has_w:
		local = Vector2i(1, 2) # missing S: bottom edge
	elif has_s and has_e and has_w:
		local = Vector2i(1, 0) # missing N: top edge
	elif has_s and has_e:
		local = Vector2i(0, 0) # top-left corner
	elif has_s and has_w:
		local = Vector2i(2, 0) # top-right corner
	elif has_n and has_e:
		local = Vector2i(0, 2) # bottom-left corner
	elif has_n and has_w:
		local = Vector2i(2, 2) # bottom-right corner
	elif has_n and has_s:
		local = Vector2i(3, 1) # vertical strip, middle
	elif has_e and has_w:
		local = Vector2i(1, 3) # horizontal strip, middle
	elif has_s:
		local = Vector2i(3, 0) # vertical strip, top cap
	elif has_n:
		local = Vector2i(3, 2) # vertical strip, bottom cap
	elif has_e:
		local = Vector2i(0, 3) # horizontal strip, left cap
	elif has_w:
		local = Vector2i(2, 3) # horizontal strip, right cap
	else:
		local = Vector2i(3, 3) # single island tile
	return Vector2i(c + local.x, local.y)


## Classifies `cell` against a Dictionary used as a set (keys = Vector2i).
static func coord_in_set(terrain_base_col: int, cells: Dictionary, cell: Vector2i) -> Vector2i:
	return coord_for(
		terrain_base_col,
		cells.has(cell + Vector2i(0, -1)),
		cells.has(cell + Vector2i(0, 1)),
		cells.has(cell + Vector2i(1, 0)),
		cells.has(cell + Vector2i(-1, 0))
	)


## A TileSet exposing every grass and sand tile of the sheet.
static func make_tileset(flat_texture: Texture2D) -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = flat_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for base in [GRASS, SAND]:
		for cx in range(4):
			for cy in range(4):
				source.create_tile(Vector2i(base + cx, cy))
	ts.add_source(source, 0)
	return ts


## Paints every cell of `cells` with the terrain's tiles.
static func paint(layer: TileMapLayer, terrain_base_col: int, cells: Dictionary) -> void:
	for cell: Vector2i in cells.keys():
		layer.set_cell(cell, 0, coord_in_set(terrain_base_col, cells, cell))


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)

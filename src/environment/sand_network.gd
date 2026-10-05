extends TileMapLayer
class_name SandNetwork

## The Tower plaza, every landmark clearing, every path and (merged in from
## GroundDetail) the coastal sand and the free sand patches, painted as ONE
## connected sand set from the pack's own `Tilemap_Flat.png` sand tiles
## (art-consistency pass, decision D158).
##
## History. The first version was tile-stamped and read as a staircase on
## diagonals; the second (a Polygon2D + 5 px Line2D union of circles and curved
## ribbons) fixed the staircase but put a smooth vector outline next to
## scalloped pixel art. The author's answer to the brief "make the art style
## more consistent" (Q2, taken while away) was to follow the pack's tile grid:
## the plaza and each clearing are rounded squares, and paths are axis-aligned
## L-shaped runs three cells wide, the way the pack's own sample maps draw
## roads. The ink edge now comes from the tiles themselves (a 2-texel scallop),
## so nothing here draws a line.
##
## Layout is unchanged in substance: the same plaza radius, the same clearing
## centres and radii, the same path targets (GroundDetail's patch centres, the
## three landmark paths, the bridge landing). Only the outline style changed.
##
## DETERMINISM. Every shape is a pure function of the exports; the only random
## input is GroundDetail's own KeyedRng patches, read through
## `take_cells()` / `get_patch_centers()`.

@export var flat_tilemap_texture: Texture2D
@export var ground_detail_path: NodePath = ^"../GroundDetail"

@export var tower_center: Vector2 = Vector2.ZERO
@export var plaza_radius_px: float = 400.0

## Landmark clearings this network also renders, and which of them get a path
## from the plaza.
@export var landmark_clearings: Array[Vector2] = []
@export var landmark_clearing_radii: Array[float] = []
@export var landmark_path_targets: Array[int] = []
@export var bridge_crossing_target: Vector2 = Vector2.ZERO # Vector2.ZERO means "no bridge path"

## Path width in px, rounded to a whole, odd number of cells (170 -> 3 cells).
@export var path_width_px: float = 170.0
@export var seed_key: String = "arena_biome"

## Exponent of the rounded-square clearing shape: 2 is a circle, large values
## approach a square. 3.5 gives the rounded corner the pack's tiles imply.
const CLEARING_EXPONENT: float = 3.5

var _cells: Dictionary = {}


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if flat_tilemap_texture == null:
		push_warning("SandNetwork has no flat_tilemap_texture assigned; no plaza/paths will be drawn.")
		return
	tile_set = FlatAutotile.make_tileset(flat_tilemap_texture)

	var targets: Array[Vector2] = []
	var ground_detail: Node = get_node_or_null(ground_detail_path)
	if ground_detail != null and ground_detail.has_method("get_patch_centers"):
		targets.append_array(ground_detail.get_patch_centers())
	if ground_detail != null and ground_detail.has_method("take_cells"):
		_cells = ground_detail.take_cells()

	_add_clearing(tower_center, plaza_radius_px)
	for i in landmark_clearings.size():
		var radius: float = landmark_clearing_radii[i] if i < landmark_clearing_radii.size() else 180.0
		_add_clearing(landmark_clearings[i], radius)

	for i in landmark_path_targets.size():
		var idx: int = landmark_path_targets[i]
		if idx >= 0 and idx < landmark_clearings.size():
			targets.append(landmark_clearings[idx])

	var width_cells: int = _odd_cells(path_width_px)
	for i in targets.size():
		_add_l_path(tower_center, targets[i], width_cells, i % 2 == 0)
	if bridge_crossing_target != Vector2.ZERO:
		# Horizontal first, so the last leg runs north-south through the pond
		# the Bridge crosses.
		_add_l_path(tower_center, bridge_crossing_target, width_cells, true)

	_fill_notches()
	FlatAutotile.paint(self, FlatAutotile.SAND, _cells)


## Fills a cell that has sand on three or four sides (a one-cell pocket or
## notch left where two shapes meet): the pack's strip tiles can draw a
## one-cell-wide gap, but it reads as a mistake, not as terrain.
func _fill_notches() -> void:
	for _pass in 2:
		var add: Array[Vector2i] = []
		var seen: Dictionary = {}
		for cell: Vector2i in _cells.keys():
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var c: Vector2i = cell + d
				if _cells.has(c) or seen.has(c):
					continue
				seen[c] = true
				var n: int = 0
				for e in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _cells.has(c + e):
						n += 1
				if n >= 3:
					add.append(c)
		for c in add:
			_cells[c] = true


## Whole, odd number of cells covering about `px`.
static func _odd_cells(px: float) -> int:
	var n: int = maxi(1, int(round(px / float(FlatAutotile.TILE_SIZE))))
	if n % 2 == 0:
		n += 1
	return n


## A rounded square of half-extent `radius_px` (superellipse test on cell
## centres).
func _add_clearing(center: Vector2, radius_px: float) -> void:
	var half_cells: int = int(ceil(radius_px / FlatAutotile.TILE_SIZE)) + 1
	var c: Vector2i = FlatAutotile.world_to_cell(center)
	for dy in range(-half_cells, half_cells + 1):
		for dx in range(-half_cells, half_cells + 1):
			var cell: Vector2i = c + Vector2i(dx, dy)
			var p: Vector2 = FlatAutotile.cell_center(cell) - center
			var u: float = absf(p.x) / radius_px
			var v: float = absf(p.y) / radius_px
			if pow(u, CLEARING_EXPONENT) + pow(v, CLEARING_EXPONENT) <= 1.0:
				_cells[cell] = true


## An axis-aligned L from `from_pos` to `to_pos`, `width_cells` wide.
func _add_l_path(from_pos: Vector2, to_pos: Vector2, width_cells: int, horizontal_first: bool) -> void:
	var a: Vector2i = FlatAutotile.world_to_cell(from_pos)
	var b: Vector2i = FlatAutotile.world_to_cell(to_pos)
	var corner: Vector2i = Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
	_add_run(a, corner, width_cells)
	_add_run(corner, b, width_cells)


func _add_run(from_cell: Vector2i, to_cell: Vector2i, width_cells: int) -> void:
	var half: int = (width_cells - 1) / 2
	var x0: int = mini(from_cell.x, to_cell.x)
	var x1: int = maxi(from_cell.x, to_cell.x)
	var y0: int = mini(from_cell.y, to_cell.y)
	var y1: int = maxi(from_cell.y, to_cell.y)
	for y in range(y0 - half, y1 + half + 1):
		for x in range(x0 - half, x1 + half + 1):
			_cells[Vector2i(x, y)] = true


func get_cells() -> Dictionary:
	return _cells


func has_cell_at_for_test(world_pos: Vector2) -> bool:
	return _cells.has(FlatAutotile.world_to_cell(world_pos))

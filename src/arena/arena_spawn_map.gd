extends RefCounted
class_name ArenaSpawnMap
## Where arena interactables may stand (Register "v1.0 Arena Interactables"). Built from the
## arena scene's own data: the SandNetwork cells, the PondField ellipses, the
## ElevationPlateaus blobs and the landmark clearings. A point is walkable when it
## is inside the arena (minus the coastal margin), not in or near water, not on a
## plateau and not on a landmark building. Spike traps are the one placement that
## must also be on sand (`is_sand`).

const ARENA_HALF_SIZE: Vector2 = Vector2(2400.0, 1600.0) # arena.tscn Floor region 4800 x 3200
const EDGE_MARGIN_PX: float = 320.0 # Register: Arena edge margin (coastal band 176 px + clearance)
const POND_MARGIN_PX: float = 140.0 # shore (2 cells) plus a body
const PLATEAU_MARGIN_PX: float = 60.0
const CLEARING_MARGIN_PX: float = 40.0

var _sand: Dictionary = {}
var _pond_centers: Array[Vector2] = []
var _pond_axes: Array[Vector2] = []
var _plateau_centers: Array[Vector2] = []
var _plateau_radii: Array[float] = []
var _clearing_centers: Array[Vector2] = []
var _clearing_radii: Array[float] = []


## `arena` is the instantiated arena.tscn root (already in the tree so its layers have built).
static func from_arena(arena: Node) -> ArenaSpawnMap:
	var m := ArenaSpawnMap.new()
	var sand: Node = arena.get_node_or_null("SandNetwork")
	if sand != null and sand.has_method("get_cells"):
		m._sand = sand.get_cells()
		var centers: Variant = sand.get("landmark_clearings")
		var radii: Variant = sand.get("landmark_clearing_radii")
		if centers != null:
			for i in centers.size():
				m._clearing_centers.append(centers[i])
				m._clearing_radii.append(float(radii[i]) if radii != null and i < radii.size() else 180.0)
	var ponds: Node = arena.get_node_or_null("PondField")
	if ponds != null:
		var pc: Variant = ponds.get("pond_centers")
		var pa: Variant = ponds.get("pond_axes")
		for i in pc.size():
			m._pond_centers.append(pc[i])
			m._pond_axes.append(pa[i])
	var plateaus: Node = arena.get_node_or_null("ElevationPlateaus")
	if plateaus != null:
		var lc: Variant = plateaus.get("plateau_centers")
		var lr: Variant = plateaus.get("plateau_radii")
		for i in lc.size():
			m._plateau_centers.append(lc[i])
			m._plateau_radii.append(float(lr[i]))
	return m


func is_sand(p: Vector2) -> bool:
	return _sand.has(FlatAutotile.world_to_cell(p))


func in_arena(p: Vector2) -> bool:
	return absf(p.x) <= ARENA_HALF_SIZE.x - EDGE_MARGIN_PX and absf(p.y) <= ARENA_HALF_SIZE.y - EDGE_MARGIN_PX


func in_water_or_plateau(p: Vector2) -> bool:
	for i in _pond_centers.size():
		var d: Vector2 = p - _pond_centers[i]
		var ax: Vector2 = _pond_axes[i] + Vector2(POND_MARGIN_PX, POND_MARGIN_PX)
		if (d.x * d.x) / (ax.x * ax.x) + (d.y * d.y) / (ax.y * ax.y) <= 1.0:
			return true
	for i in _plateau_centers.size():
		if p.distance_to(_plateau_centers[i]) <= _plateau_radii[i] + PLATEAU_MARGIN_PX:
			return true
	return false


func on_landmark(p: Vector2) -> bool:
	for i in _clearing_centers.size():
		if p.distance_to(_clearing_centers[i]) <= _clearing_radii[i] + CLEARING_MARGIN_PX:
			return true
	return false


## Ground a crate, keg or shrine may stand on.
func is_walkable(p: Vector2) -> bool:
	return in_arena(p) and not in_water_or_plateau(p) and not on_landmark(p)

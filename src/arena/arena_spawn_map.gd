extends RefCounted
class_name ArenaSpawnMap
## Where arena interactables may stand (Register "v1.0 Arena Layout" and "v1.0 Arena Interactables"). Built
## from the arena scene's own FlowField, so crates, kegs and the Shrine sit on exactly the ground
## enemies and the player can walk: not in the moat, not inside an outcrop or ruin, not in the
## Tower footprint, never in a sealed pocket. A point must also have clearance (its four neighbours
## at CLEARANCE_PX walkable too) so nothing is wedged against water or a wall. Spike plates use the
## bridge geometry from ArenaLayout instead.

const EDGE_MARGIN_PX: float = 48.0 # keep off the island's outer wall
const CLEARANCE_PX: float = 40.0

var _field: FlowField = null
var _sand: Dictionary = {}


## `arena` is the instantiated arena.tscn root (already in the tree so its layers have built).
static func from_arena(arena: Node) -> ArenaSpawnMap:
	var m := ArenaSpawnMap.new()
	m._field = arena.get_node_or_null("FlowField") as FlowField
	var sand: Node = arena.get_node_or_null("SandNetwork")
	if sand != null and sand.has_method("get_cells"):
		m._sand = sand.get_cells()
	return m


func get_flow_field() -> FlowField:
	return _field


func is_sand(p: Vector2) -> bool:
	return _sand.has(FlatAutotile.world_to_cell(p))


func in_arena(p: Vector2) -> bool:
	return absf(p.x) <= ArenaLayout.HALF_SIZE.x - EDGE_MARGIN_PX and absf(p.y) <= ArenaLayout.HALF_SIZE.y - EDGE_MARGIN_PX


## Ground a crate, keg or shrine may stand on.
func is_walkable(p: Vector2) -> bool:
	if _field == null or not in_arena(p):
		return false
	if not _field.is_walkable(p):
		return false
	for d in [Vector2(CLEARANCE_PX, 0), Vector2(-CLEARANCE_PX, 0), Vector2(0, CLEARANCE_PX), Vector2(0, -CLEARANCE_PX)]:
		if not _field.is_walkable(p + d):
			return false
	return true

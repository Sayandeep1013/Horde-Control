extends Node2D
class_name ArenaCollision
## The arena's real collision (docs/33 section B2/B3, D331, D332). Builds, once, from the same data
## the art uses: the moat water (ArenaLayout minus the bridge openings) on the Water layer
## (CollisionLayers.LAYER_WATER, which player and enemy bodies mask but projectiles do not), and
## every sibling that offers `get_solid_rects()` (RockOutcrop, ArenaSolid) on the World layer
## (which blocks bodies and shots). Rects are merged row-wise so the shape count stays small.
## Exposes the rect lists so the FlowField builds its walkable mask from exactly the same blockers.
## Group "arena_collision". Place it after the visual nodes in arena.tscn.

var _water_rects: Array[Rect2] = []
var _solid_rects: Array[Rect2] = []


func _ready() -> void:
	add_to_group(&"arena_collision")
	rebuild()


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_water_rects = merge_cells(ArenaLayout.blocking_water_cells())
	_solid_rects.clear()
	var host: Node = get_parent()
	if host != null:
		for n in host.get_children():
			if n != self and n.has_method(&"get_solid_rects"):
				_solid_rects.append_array(n.get_solid_rects())
	_make_body("WaterBody", CollisionLayers.LAYER_WATER, _water_rects)
	_make_body("SolidBody", CollisionLayers.LAYER_WORLD, _solid_rects)


func _make_body(body_name: String, layer: int, rects: Array[Rect2]) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = layer
	body.collision_mask = 0
	for r in rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)
	add_child(body)


func get_water_rects() -> Array[Rect2]:
	return _water_rects


func get_solid_rects() -> Array[Rect2]:
	return _solid_rects


func get_blocked_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.append_array(_water_rects)
	out.append_array(_solid_rects)
	return out


## Merges a set of 64 px cells into world rects: runs along x, then stacks identical runs along y.
static func merge_cells(cells: Dictionary) -> Array[Rect2]:
	var rows: Dictionary = {} # y -> Array[int] of x
	for c: Vector2i in cells.keys():
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	var ys: Array = rows.keys()
	ys.sort()
	var open: Dictionary = {} # "x0:x1" -> [x0, x1, y_start, y_last]
	var done: Array[Rect2] = []
	for y in ys:
		var xs: Array = rows[y]
		xs.sort()
		var seen: Dictionary = {}
		var i: int = 0
		while i < xs.size():
			var j: int = i
			while j + 1 < xs.size() and xs[j + 1] == xs[j] + 1:
				j += 1
			var key: String = "%d:%d" % [xs[i], xs[j]]
			seen[key] = true
			if open.has(key) and open[key][3] == y - 1:
				open[key][3] = y
			else:
				if open.has(key):
					done.append(_run_rect(open[key]))
				open[key] = [xs[i], xs[j], y, y]
			i = j + 1
		for key in open.keys():
			if not seen.has(key):
				done.append(_run_rect(open[key]))
				open.erase(key)
	for key in open.keys():
		done.append(_run_rect(open[key]))
	return done


static func _run_rect(run: Array) -> Rect2:
	var s: float = float(ArenaLayout.CELL)
	return Rect2(Vector2(run[0], run[2]) * s, Vector2(run[1] - run[0] + 1, run[3] - run[2] + 1) * s)

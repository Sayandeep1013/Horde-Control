extends RefCounted
class_name ArenaLayout
## The arena's fixed geometry (Register "v1.0 Arena Layout", docs/33 section B, D330-D334): one
## walkable island of 2432 x 1664 px around the Tower, a 128 px water moat ring crossed by four
## bridges, and an outer bank the waves spawn on. Pure data on the 64 px tile grid, so the water
## and the bridge art (PondField, BridgeSpan), the collision (ArenaCollision), the FlowField and
## the interactable placement all read the same numbers. Cell (cx, cy) covers world
## [64*cx, 64*cx + 64) x [64*cy, 64*cy + 64); the Tower is at the origin.

const CELL: int = 64
const HALF_SIZE: Vector2 = Vector2(1216.0, 832.0) # walkable half extents: 2432 x 1664 px
const SIZE: Vector2 = Vector2(2432.0, 1664.0)
## Moat ring in cells: water = OUTER minus INNER (two cells = 128 px wide), x -15..14, y -10..9.
const MOAT_OUTER: Rect2i = Rect2i(-15, -10, 30, 20)
const MOAT_INNER: Rect2i = Rect2i(-13, -8, 26, 16)
## Bridge openings in cells (each crosses the 2-cell moat and is 2 cells = 128 px wide), a pinwheel:
## north (west of centre), east (north of centre), south (east of centre), west (south of centre).
const BRIDGES: Array[Rect2i] = [Rect2i(-7, -10, 2, 2), Rect2i(13, -3, 2, 2), Rect2i(5, 8, 2, 2), Rect2i(-15, 1, 2, 2)]
const BRIDGE_NAMES: Array[String] = ["north", "east", "south", "west"]
## The spawn road: the mid line of the outer bank (the land outside the moat and its shore).
const SPAWN_ROAD_HALF: Vector2 = Vector2(1088.0, 736.0)
## Land outside the moat's outer edge is the outer bank (its first 2 cells are the sand shore).
const BANK_INNER_HALF: Vector2 = Vector2(960.0, 640.0)


static func moat_cells() -> Dictionary:
	var out: Dictionary = {}
	for cy in range(MOAT_OUTER.position.y, MOAT_OUTER.end.y):
		for cx in range(MOAT_OUTER.position.x, MOAT_OUTER.end.x):
			var c := Vector2i(cx, cy)
			if not MOAT_INNER.has_point(c):
				out[c] = true
	return out


static func is_bridge_cell(cell: Vector2i) -> bool:
	for b in BRIDGES:
		if b.has_point(cell):
			return true
	return false


## Moat cells a body cannot cross: all of the ring except the bridge openings.
static func blocking_water_cells() -> Dictionary:
	var out: Dictionary = moat_cells()
	for c: Vector2i in out.keys():
		if is_bridge_cell(c):
			out.erase(c)
	return out


static func bridge_rect_px(i: int) -> Rect2:
	var b: Rect2i = BRIDGES[i]
	return Rect2(Vector2(b.position) * CELL, Vector2(b.size) * CELL)


static func bridge_center(i: int) -> Vector2:
	return bridge_rect_px(i).get_center()


## True when the bridge runs north-south (it crosses a horizontal part of the moat).
static func bridge_is_vertical(i: int) -> bool:
	return BRIDGES[i].position.y == MOAT_OUTER.position.y or BRIDGES[i].end.y == MOAT_OUTER.end.y


## Unit vector from the Tower side of bridge `i` towards the outer bank.
static func bridge_outward(i: int) -> Vector2:
	var c: Vector2 = bridge_center(i)
	if bridge_is_vertical(i):
		return Vector2(0.0, signf(c.y))
	return Vector2(signf(c.x), 0.0)


## The point `offset` px from the bridge centre along its axis (positive = towards the outer bank).
static func bridge_point(i: int, offset: float) -> Vector2:
	return bridge_center(i) + bridge_outward(i) * offset


static func in_bank(p: Vector2) -> bool:
	return absf(p.x) >= BANK_INNER_HALF.x or absf(p.y) >= BANK_INNER_HALF.y


static func in_island(p: Vector2) -> bool:
	return absf(p.x) < HALF_SIZE.x and absf(p.y) < HALF_SIZE.y


## True when `p` is within `margin` px of the moat ring (water or its sand shore): decoration and
## trees keep off it.
static func near_moat(p: Vector2, margin: float) -> bool:
	var outer := Rect2(Vector2(MOAT_OUTER.position) * CELL, Vector2(MOAT_OUTER.size) * CELL)
	var inner := Rect2(Vector2(MOAT_INNER.position) * CELL, Vector2(MOAT_INNER.size) * CELL)
	return outer.grow(margin).has_point(p) and not inner.grow(-margin).has_point(p)

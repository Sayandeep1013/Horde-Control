extends Node2D
class_name FlowField
## Walking-distance flow fields over the arena (docs/33 section B4, D333). Group "flow_field".
##
## A 32 px grid covers the walkable island. A cell is walkable unless a blocker overlaps it (the
## moat water outside the bridges, rock outcrops, ruins; ArenaCollision's rects) or the Tower's
## footprint covers it. Two integer Dijkstra fields (costs 10 straight / 14 diagonal, no corner
## cutting) give every cell its walking distance: toward the Tower (computed once at build) and
## toward the player (recomputed every PLAYER_RECOMPUTE_SECONDS of SimClock). Bridges are plain
## walkable cells, so paths cross the moat only there.
##
## Contract used by the enemy code (docs/33 B4):
##   direction_to(kind, world_pos) -> Vector2    normalised; ZERO when off-grid or unreachable
##   is_walkable(world_pos) -> bool
##   random_walkable_point(rng, from, min_dist, max_dist) -> Vector2   ZERO when none exists
## A caller that gets ZERO falls back to a straight line. The direction is the sum of the unit
## steps that lie on a shortest path (at most two in open ground, so it points within a few
## degrees of the straight line) and bends round water and walls.
##
## Spawn edge: the node installs SpawnGeometry.point_projector so ring points land on walkable
## outer-bank cells (project_to_spawn_edge).
## Debug: F8 (debug builds) or set_debug_draw(true) draws the mask and both fields.

const CELL_PX: float = 32.0
const PLAYER_RECOMPUTE_SECONDS: float = 0.25 # Register "v1.0 Arena Layout": FlowField player recompute
const TOWER_FOOTPRINT_PX: float = 106.0 # Tower body radius (scenes/tower.tscn)
const COST_STRAIGHT: int = 10
const COST_DIAGONAL: int = 14
const UNREACHED: int = 1 << 30
const BUCKETS: int = COST_DIAGONAL + 1
const KIND_TOWER: StringName = &"tower"
const KIND_PLAYER: StringName = &"player"

@export var half_size: Vector2 = ArenaLayout.HALF_SIZE
@export var collision_path: NodePath = ^"../ArenaCollision"
@export var tower_position: Vector2 = Vector2.ZERO
@export var debug_draw: bool = false

var cols: int = 0
var rows: int = 0
var last_tower_usec: int = 0
var last_player_usec: int = 0
var player_recomputes: int = 0
var pruned_cells: int = 0 # walkable but sealed off from the Tower, removed from the mask

var _pw: int = 0 # padded row width (a one-cell blocked border removes every bounds check)
var _origin: Vector2 = Vector2.ZERO
var _walk: PackedByteArray = PackedByteArray() # 1 = walkable (padded)
var _tower_goal: PackedInt32Array = PackedInt32Array()
var _tower_dist: PackedInt32Array = PackedInt32Array()
var _player_dist: PackedInt32Array = PackedInt32Array()
var _player_cell: int = -1
var _player_pos: Vector2 = Vector2.ZERO
var _last_player_time: float = -1000.0
var _walkable_list: PackedInt32Array = PackedInt32Array()
var _offsets: PackedInt32Array = PackedInt32Array()
var _off_dx: PackedInt32Array = PackedInt32Array()
var _off_dy: PackedInt32Array = PackedInt32Array()
var _off_cost: PackedInt32Array = PackedInt32Array()
var _blocked_rects: Array[Rect2] = []


func _ready() -> void:
	add_to_group(&"flow_field")
	var coll: Node = get_node_or_null(collision_path)
	var rects: Array[Rect2] = []
	if coll != null and coll.has_method(&"get_blocked_rects"):
		rects = coll.get_blocked_rects()
	build(rects, tower_position, TOWER_FOOTPRINT_PX)
	SpawnGeometry.point_projector = Callable(self, "project_to_spawn_edge")


func _exit_tree() -> void:
	var p: Callable = SpawnGeometry.point_projector
	if p.is_valid() and p.get_object() == self:
		SpawnGeometry.point_projector = Callable()


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		set_debug_draw(not debug_draw)


func _physics_process(_delta: float) -> void:
	if SimClock.now - _last_player_time >= PLAYER_RECOMPUTE_SECONDS:
		_last_player_time = SimClock.now
		var players: Array[Node2D] = EntityRegistry.get_entities_with_tag(&"player")
		if not players.is_empty() and is_instance_valid(players[0]):
			recompute_player_field(players[0].global_position)


# --- build -------------------------------------------------------------------

## Builds the mask from world-space blocker rects and the Tower footprint, then the Tower field.
func build(blocked_rects: Array[Rect2], tower_pos: Vector2, tower_radius: float) -> void:
	_blocked_rects = blocked_rects
	tower_position = tower_pos
	cols = int(round(half_size.x * 2.0 / CELL_PX))
	rows = int(round(half_size.y * 2.0 / CELL_PX))
	_pw = cols + 2
	_origin = -half_size
	_walk.resize(_pw * (rows + 2))
	_walk.fill(0)
	for y in rows:
		for x in cols:
			_walk[_idx(x, y)] = 1
	for r in blocked_rects:
		var x0: int = maxi(0, int(floor((r.position.x - _origin.x) / CELL_PX)))
		var x1: int = mini(cols - 1, int(ceil((r.end.x - _origin.x) / CELL_PX)) - 1)
		var y0: int = maxi(0, int(floor((r.position.y - _origin.y) / CELL_PX)))
		var y1: int = mini(rows - 1, int(ceil((r.end.y - _origin.y) / CELL_PX)) - 1)
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				_walk[_idx(x, y)] = 0
	_tower_goal = PackedInt32Array()
	for y in rows:
		for x in cols:
			var cell := Rect2(_origin + Vector2(x, y) * CELL_PX, Vector2(CELL_PX, CELL_PX))
			var nearest: Vector2 = Vector2(clampf(tower_pos.x, cell.position.x, cell.end.x), clampf(tower_pos.y, cell.position.y, cell.end.y))
			if nearest.distance_to(tower_pos) < tower_radius:
				_tower_goal.append(_idx(x, y))
				_walk[_idx(x, y)] = 0
	_walkable_list = PackedInt32Array()
	for y in rows:
		for x in cols:
			if _walk[_idx(x, y)] == 1:
				_walkable_list.append(_idx(x, y))
	_setup_offsets()
	_tower_dist = _new_dist()
	var t0: int = Time.get_ticks_usec()
	_flood(_tower_goal, _tower_dist)
	last_tower_usec = Time.get_ticks_usec() - t0
	# A walkable cell the Tower field cannot reach is a sealed pocket: drop it from the mask so
	# nothing is ever placed or spawned where it could not walk out.
	var reachable := PackedInt32Array()
	for i in _walkable_list:
		if _tower_dist[i] >= UNREACHED:
			_walk[i] = 0
		else:
			reachable.append(i)
	pruned_cells = _walkable_list.size() - reachable.size()
	_walkable_list = reachable
	_player_dist = _new_dist()
	_player_cell = -1
	if debug_draw:
		queue_redraw()


## Call when the arena changes (a blocker added or removed): rebuilds the mask and the Tower field.
func rebuild(blocked_rects: Array[Rect2]) -> void:
	build(blocked_rects, tower_position, TOWER_FOOTPRINT_PX)
	if _player_cell >= 0:
		recompute_player_field(_player_pos)


func _setup_offsets() -> void:
	# E, W, S, N, SE, SW, NE, NW
	_off_dx = PackedInt32Array([1, -1, 0, 0, 1, -1, 1, -1])
	_off_dy = PackedInt32Array([0, 0, 1, -1, 1, 1, -1, -1])
	_off_cost = PackedInt32Array([10, 10, 10, 10, 14, 14, 14, 14])
	_offsets = PackedInt32Array()
	for k in 8:
		_offsets.append(_off_dy[k] * _pw + _off_dx[k])


func _new_dist() -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(_pw * (rows + 2))
	d.fill(UNREACHED)
	return d


func _idx(x: int, y: int) -> int:
	return (y + 1) * _pw + (x + 1)


## Dial's algorithm (circular buckets, edge costs <= 14): exact octile walking distance.
func _flood(sources: PackedInt32Array, dist: PackedInt32Array) -> void:
	var buckets: Array[PackedInt32Array] = []
	for _i in BUCKETS:
		buckets.append(PackedInt32Array())
	var max_d: int = 0
	for s in sources:
		dist[s] = 0
		buckets[0].append(s)
	var walk: PackedByteArray = _walk
	var pw: int = _pw
	var d: int = 0
	while d <= max_d:
		var b: PackedInt32Array = buckets[d % BUCKETS]
		var nd: int = d + COST_STRAIGHT
		var nb: int = nd % BUCKETS
		var dd: int = d + COST_DIAGONAL
		var db: int = dd % BUCKETS
		for cur in b:
			if dist[cur] != d:
				continue
			var e: bool = walk[cur + 1] == 1
			var w: bool = walk[cur - 1] == 1
			var so: bool = walk[cur + pw] == 1
			var no: bool = walk[cur - pw] == 1
			var n: int
			if e and nd < dist[cur + 1]:
				dist[cur + 1] = nd
				buckets[nb].append(cur + 1)
			if w and nd < dist[cur - 1]:
				dist[cur - 1] = nd
				buckets[nb].append(cur - 1)
			if so and nd < dist[cur + pw]:
				dist[cur + pw] = nd
				buckets[nb].append(cur + pw)
			if no and nd < dist[cur - pw]:
				dist[cur - pw] = nd
				buckets[nb].append(cur - pw)
			if e and so:
				n = cur + pw + 1
				if walk[n] == 1 and dd < dist[n]:
					dist[n] = dd
					buckets[db].append(n)
			if w and so:
				n = cur + pw - 1
				if walk[n] == 1 and dd < dist[n]:
					dist[n] = dd
					buckets[db].append(n)
			if e and no:
				n = cur - pw + 1
				if walk[n] == 1 and dd < dist[n]:
					dist[n] = dd
					buckets[db].append(n)
			if w and no:
				n = cur - pw - 1
				if walk[n] == 1 and dd < dist[n]:
					dist[n] = dd
					buckets[db].append(n)
		if not b.is_empty():
			max_d = maxi(max_d, d + COST_DIAGONAL)
		b.clear()
		buckets[d % BUCKETS] = b
		d += 1
		if d > 100000:
			break


# --- queries -----------------------------------------------------------------

func _cell_index(world_pos: Vector2) -> int:
	var x: int = int(floor((world_pos.x - _origin.x) / CELL_PX))
	var y: int = int(floor((world_pos.y - _origin.y) / CELL_PX))
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return -1
	return _idx(x, y)


func _cell_center(i: int) -> Vector2:
	var x: int = i % _pw - 1
	var y: int = i / _pw - 1
	return _origin + Vector2(x + 0.5, y + 0.5) * CELL_PX


func is_walkable(world_pos: Vector2) -> bool:
	var i: int = _cell_index(world_pos)
	return i >= 0 and _walk[i] == 1


## Normalised walking direction towards `target_kind` (&"tower" or &"player") from `world_pos`;
## Vector2.ZERO when the position is off the grid, the field has no route from it, or the
## player field has not been computed yet.
func direction_to(target_kind: StringName, world_pos: Vector2) -> Vector2:
	var dist: PackedInt32Array
	if target_kind == KIND_TOWER:
		dist = _tower_dist
	elif target_kind == KIND_PLAYER:
		if _player_cell < 0:
			return Vector2.ZERO
		dist = _player_dist
	else:
		return Vector2.ZERO
	var i: int = _cell_index(world_pos)
	if i < 0:
		return Vector2.ZERO
	if target_kind == KIND_PLAYER and i == _player_cell:
		var to_player: Vector2 = _player_pos - world_pos
		return to_player.normalized() if to_player.length_squared() > 1.0 else Vector2.ZERO
	var d: int = dist[i]
	if d >= UNREACHED:
		# A centre in a partly blocked cell: head for the best neighbouring cell.
		var best: int = -1
		var best_d: int = UNREACHED
		for k in 8:
			var n: int = i + _offsets[k]
			if dist[n] < best_d:
				best_d = dist[n]
				best = n
		if best < 0:
			return Vector2.ZERO
		return (_cell_center(best) - world_pos).normalized()
	if d == 0:
		return Vector2.ZERO
	var sum := Vector2.ZERO
	var fallback: int = -1
	var fallback_d: int = d
	for k in 8:
		var n: int = i + _offsets[k]
		var nd: int = dist[n]
		if nd >= d:
			continue
		if k >= 4 and not (_walk[i + _off_dx[k]] == 1 and _walk[i + _off_dy[k] * _pw] == 1):
			continue
		if d - nd >= _off_cost[k]:
			sum += Vector2(_off_dx[k], _off_dy[k]).normalized()
		if nd < fallback_d:
			fallback_d = nd
			fallback = n
	if sum != Vector2.ZERO:
		return sum.normalized()
	if fallback >= 0:
		return (_cell_center(fallback) - world_pos).normalized()
	return Vector2.ZERO


## Walking distance in px (octile, 32 px cells) from `world_pos` to the target, or -1.0 when unreachable.
func distance_to(target_kind: StringName, world_pos: Vector2) -> float:
	var i: int = _cell_index(world_pos)
	if i < 0:
		return -1.0
	var d: int = (_tower_dist if target_kind == KIND_TOWER else _player_dist)[i]
	return -1.0 if d >= UNREACHED else float(d) * CELL_PX / float(COST_STRAIGHT)


## A walkable point with min_dist <= distance from `from` <= max_dist, or Vector2.ZERO (never
## walkable: the Tower covers the origin) when no such cell exists.
func random_walkable_point(rng: RandomNumberGenerator, from: Vector2, min_dist: float, max_dist: float) -> Vector2:
	for _a in 24:
		var p: Vector2 = from + Vector2.from_angle(rng.randf() * TAU) * lerpf(min_dist, max_dist, sqrt(rng.randf()))
		if is_walkable(p):
			return p
	var candidates: PackedInt32Array = PackedInt32Array()
	for i in _walkable_list:
		var dd: float = _cell_center(i).distance_to(from)
		if dd >= min_dist and dd <= max_dist:
			candidates.append(i)
	if candidates.is_empty():
		return Vector2.ZERO
	return _cell_center(candidates[rng.randi_range(0, candidates.size() - 1)]) + Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-12.0, 12.0))


func walkable_cell_count() -> int:
	return _walkable_list.size()


# --- player field ------------------------------------------------------------

## Recomputes the player field with the player standing at `player_pos` (SimClock cadence in
## _physics_process; public for tests and for a caller that knows the player just teleported).
func recompute_player_field(player_pos: Vector2) -> void:
	var t0: int = Time.get_ticks_usec()
	_player_pos = player_pos
	var c: int = _nearest_walkable_index(player_pos)
	if c < 0:
		_player_cell = -1
		return
	_player_cell = c
	_player_dist.fill(UNREACHED)
	_flood(PackedInt32Array([c]), _player_dist)
	player_recomputes += 1
	last_player_usec = Time.get_ticks_usec() - t0
	if debug_draw:
		queue_redraw()


func _nearest_walkable_index(p: Vector2) -> int:
	var i: int = _cell_index(p)
	if i >= 0 and _walk[i] == 1:
		return i
	var base: int = i if i >= 0 else _cell_index(p.clamp(_origin + Vector2.ONE, -_origin - Vector2.ONE))
	if base < 0:
		return -1
	var best: int = -1
	var best_d: float = INF
	for radius in range(1, 6):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n: int = base + dy * _pw + dx
				if n > 0 and n < _walk.size() and _walk[n] == 1:
					var dd: float = _cell_center(n).distance_squared_to(p)
					if dd < best_d:
						best_d = dd
						best = n
		if best >= 0:
			return best
	return -1


# --- spawn edge --------------------------------------------------------------

## Maps a spawn-ring point onto the walkable outer bank (SpawnGeometry.point_projector): the point
## is clamped to the spawn road (the bank's mid line), pushed out of the moat rectangle if it fell
## inside, spread across the bank's width by a deterministic function of the input, then snapped
## to the nearest walkable bank cell. The direction from the Tower is preserved.
func project_to_spawn_edge(raw: Vector2) -> Vector2:
	var road: Vector2 = ArenaLayout.SPAWN_ROAD_HALF
	var inner: Vector2 = ArenaLayout.BANK_INNER_HALF
	var q: Vector2 = raw.clamp(-road, road)
	if absf(q.x) < inner.x and absf(q.y) < inner.y:
		if (road.x - absf(q.x)) / road.x < (road.y - absf(q.y)) / road.y:
			q.x = (signf(q.x) if q.x != 0.0 else 1.0) * road.x
		else:
			q.y = (signf(q.y) if q.y != 0.0 else 1.0) * road.y
	var spread: float = fposmod(raw.x * 0.173 + raw.y * 0.319, 1.0) - 0.5
	if absf(q.x) >= road.x - 1.0:
		q.x += spread * 120.0
	elif absf(q.y) >= road.y - 1.0:
		q.y += spread * 90.0
	if is_walkable(q) and ArenaLayout.in_bank(q):
		return q
	var base: int = _cell_index(q.clamp(_origin + Vector2.ONE, -_origin - Vector2.ONE))
	if base < 0:
		return q
	var best: Vector2 = q
	var best_d: float = INF
	for radius in range(1, 9):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n: int = base + dy * _pw + dx
				if n > 0 and n < _walk.size() and _walk[n] == 1:
					var c: Vector2 = _cell_center(n)
					if ArenaLayout.in_bank(c) and c.distance_squared_to(q) < best_d:
						best_d = c.distance_squared_to(q)
						best = c
		if best_d < INF:
			break
	return best


# --- debug -------------------------------------------------------------------

func set_debug_draw(on: bool) -> void:
	debug_draw = on
	z_index = 90
	queue_redraw()


func _draw() -> void:
	if not debug_draw or cols == 0:
		return
	for y in rows:
		for x in cols:
			var r := Rect2(_origin + Vector2(x, y) * CELL_PX, Vector2(CELL_PX, CELL_PX))
			if _walk[_idx(x, y)] == 1:
				draw_rect(r.grow(-1.0), Color(0.2, 1.0, 0.3, 0.10), true)
			else:
				draw_rect(r.grow(-1.0), Color(1.0, 0.2, 0.2, 0.35), true)
	for y in range(0, rows, 2):
		for x in range(0, cols, 2):
			var c: Vector2 = _origin + Vector2(x + 0.5, y + 0.5) * CELL_PX
			var t: Vector2 = direction_to(KIND_TOWER, c)
			if t != Vector2.ZERO:
				draw_line(c, c + t * 14.0, Color(0.3, 0.9, 1.0, 0.9), 2.0)
			var p: Vector2 = direction_to(KIND_PLAYER, c)
			if p != Vector2.ZERO:
				draw_line(c + Vector2(3, 3), c + Vector2(3, 3) + p * 14.0, Color(1.0, 0.9, 0.2, 0.9), 2.0)

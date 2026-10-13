extends Node
class_name SwarmBrain

## SwarmBrain (PT-PERF, D390-D399). The "batched brain" half of Performance Fallback
## Ladder step 3 (docs/20 > Performance): ONE SimLoop step-3 registrant that steps every
## plain enemy (an EnemyController with no Behavior: Tower Seeker, Player Hunter,
## Opportunist, Brute) in a deterministic order (registration order), replacing the
## per-enemy registrations, `move_and_slide()` calls and `get_entities_in_radius()`
## separation queries.
##
## ## What stays per enemy, what is batched
## Behaviour rules (intents, attack slots, body-block, leash, Opportunist switching,
## the stuck rule, the attack cycle and its timing, freeze and slow, elites, the speed
## ramp, the LOD think interval) stay exactly where they were, in EnemyController;
## `swarm_plan()` runs them for an enemy on its think tick. What moves here:
## - Movement. A plain enemy has no collision body any more (its BodyShape is disabled,
##   its layer and mask are 0): position is stepped directly, kept on walkable
##   FlowField cells (full step, else x only, else y only, i.e. sliding along a wall) and
##   pushed out of the player's and the Tower's circles. Its Hurtbox / Hitbox Area2Ds
##   follow the node.
## - Separation. One spatial hash per tick in packed arrays (a head / next linked list
##   over 32 px cells, ~64 x 64 buckets with wrap-around: a 3 x 3 neighbourhood never
##   aliases) replaces the registry radius query per enemy.
## - The coast ticks between two plans touch no object: a position integration, a
##   walkability lookup in the FlowField's byte mask and one registry slot update.
## - The LOD think interval (Register "Swarm AI LOD (D341, D342)") is unchanged.
##
## ## Struct of arrays
## Slot s describes one enemy; the arrays below are public because SwarmRenderer reads
## `pos` / `prev` (interpolation) directly. `_order` is registration order, so the step
## order is deterministic (docs/20 SimLoop ordering rule).
##
## ## Without a brain
## Enemies in a tree with no SwarmBrain (isolated unit tests) keep the old per-enemy
## step (`EnemyController.physics_step`, `move_and_slide`) and their node visuals.

const HASH_CELL_PX: float = 32.0
const HASH_OFFSET_PX: float = 4096.0 # keeps the cell index positive: int() truncation = floor
const HASH_MASK: int = 63
const HASH_SHIFT: int = 6
const GRID_CELL_PX: float = 32.0 # FlowField.CELL_PX

var ents: Array = []
var pos: PackedVector2Array = PackedVector2Array()
var prev: PackedVector2Array = PackedVector2Array()
var vel: PackedVector2Array = PackedVector2Array()
var rad: PackedFloat32Array = PackedFloat32Array()
var uid: PackedInt64Array = PackedInt64Array()
var mode: PackedByteArray = PackedByteArray() # 0 free, 1 stepping
var attn: PackedByteArray = PackedByteArray() # 1: the attack cycle needs a call this tick
var needs_plan: PackedByteArray = PackedByteArray()
var hold: PackedByteArray = PackedByteArray() # 1: stands still (capture lineups)
var phase: PackedInt32Array = PackedInt32Array()
var regslot: PackedInt32Array = PackedInt32Array()
var hnext: PackedInt32Array = PackedInt32Array()

## Read by SwarmRenderer for the Y-sort bands.
var player_y: float = 0.0
var tower_y: float = 0.0

var _head: PackedInt32Array = PackedInt32Array()
var _order: PackedInt32Array = PackedInt32Array()
var _free: PackedInt32Array = PackedInt32Array()
var _order_dirty: bool = false
var _clock: Node = null
var _registry: Node = null
var _sim_loop: Node = null

var _player: Node2D = null
var _tower: Node2D = null
var _player_radius: float = 0.0
var _tower_radius: float = 0.0
var _ref_retry_tick: int = -1000

var _flow: Node = null
var _walk: PackedByteArray = PackedByteArray()
var _grid_pw: int = 0
var _grid_cols: float = 0.0
var _grid_rows: float = 0.0
var _grid_ox: float = 0.0
var _grid_oy: float = 0.0
var _has_grid: bool = false

## Dev: per-step cost of the last tick in microseconds (swarm_probe).
var last_hash_usec: int = 0
var last_loop_usec: int = 0
var last_plan_count: int = 0
var profile_enabled: bool = false
var last_plan_usec: int = 0
var last_sync_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"swarm_brain")
	SwarmState.brain = self
	_head.resize((HASH_MASK + 1) * (HASH_MASK + 1))
	_head.fill(-1)
	call_deferred(&"_register_with_sim_loop")


func _exit_tree() -> void:
	if SwarmState.brain == self:
		SwarmState.brain = null


func _register_with_sim_loop() -> void:
	if _sim_loop == null and is_inside_tree():
		_sim_loop = get_tree().get_first_node_in_group(&"sim_loop")
	if _sim_loop != null:
		_sim_loop.register(SimLoop.Step.ENEMY_AI_AND_MOVEMENT, self)


func set_sim_loop_for_test(loop: Node) -> void:
	_sim_loop = loop


# --- membership ---------------------------------------------------------------

## Adds `enemy` (already in the tree and registered with the EntityRegistry) and returns
## its slot.
func add(enemy: Node2D) -> int:
	var s: int
	if _order_dirty:
		_compact() # a freed slot is reused below: no stale entry of it may remain in the order
	if not _free.is_empty():
		s = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
	else:
		s = ents.size()
		ents.append(null)
		pos.append(Vector2.ZERO)
		prev.append(Vector2.ZERO)
		vel.append(Vector2.ZERO)
		rad.append(0.0)
		uid.append(0)
		mode.append(0)
		attn.append(0)
		needs_plan.append(0)
		hold.append(0)
		phase.append(0)
		regslot.append(-1)
		hnext.append(-1)
	if _clock == null:
		_clock = enemy.get_clock() if enemy.has_method(&"get_clock") else SimClock
	if _registry == null:
		_registry = enemy.get_registry() if enemy.has_method(&"get_registry") else null
	ents[s] = enemy
	var p: Vector2 = enemy.global_position
	pos[s] = p
	prev[s] = p
	vel[s] = Vector2.ZERO
	rad[s] = enemy.get_body_radius()
	uid[s] = enemy.get_instance_id()
	mode[s] = 1
	attn[s] = 0
	needs_plan[s] = 1
	hold[s] = 0
	phase[s] = int(enemy.get_instance_id() % 60) # 60 = lcm(3, 4, 5): spreads plans over every interval
	set_registry_slot(s, enemy)
	_order.append(s)
	return s


func set_registry_slot(slot: int, enemy: Node2D) -> void:
	regslot[slot] = _registry.get_entity_slot(enemy) if _registry != null else -1


func remove(slot: int) -> void:
	if slot < 0 or slot >= mode.size() or mode[slot] == 0:
		return
	mode[slot] = 0
	ents[slot] = null
	_free.append(slot)
	_order_dirty = true


func get_count() -> int:
	return _order.size() - (0 if not _order_dirty else _count_free_in_order())


func _count_free_in_order() -> int:
	var n: int = 0
	for s in _order:
		if mode[s] == 0:
			n += 1
	return n


func set_hold(slot: int, held: bool) -> void:
	hold[slot] = 1 if held else 0


func _compact() -> void:
	var kept: int = 0
	for k in _order.size():
		var s: int = _order[k]
		if mode[s] == 1:
			_order[kept] = s
			kept += 1
	_order.resize(kept)
	_order_dirty = false


# --- references ---------------------------------------------------------------

## The shared references an enemy would otherwise look up itself with a registry scan
## each (null while not yet present).
func player_node() -> Node2D:
	return _player if _player != null and is_instance_valid(_player) else null


func tower_node() -> Node2D:
	return _tower if _tower != null and is_instance_valid(_tower) else null


func flow_node() -> Node:
	return _flow


func _refresh_refs(tick: int) -> void:
	if _registry == null:
		return
	var retry: bool = tick - _ref_retry_tick >= 20
	if (_player == null or not is_instance_valid(_player)) and retry:
		var players: Array[Node2D] = _registry.get_entities_with_tag(&"player")
		if not players.is_empty():
			_player = players[0]
			var pdef: Variant = _player.get("definition")
			_player_radius = float(pdef.body_radius_px) if pdef != null else 0.0
	if (_tower == null or not is_instance_valid(_tower)) and retry:
		var towers: Array[Node2D] = _registry.get_entities_with_tag(&"tower")
		if not towers.is_empty():
			_tower = towers[0]
			var tdef: Variant = _tower.get("definition")
			if tdef != null and tdef.tower_footprint != null:
				_tower_radius = float(tdef.tower_footprint.footprint_radius_px)
	if retry and (_player == null or _tower == null):
		_ref_retry_tick = tick # a missing one is looked up again at most every 20 ticks
	_refresh_flow()


func _refresh_flow() -> void:
	var ff: Node = EnemyController.flow_field_service(self)
	if ff == _flow:
		return
	_flow = ff
	_has_grid = false
	if ff != null and ff.has_method(&"walk_mask"):
		_walk = ff.walk_mask()
		_grid_pw = ff.row_stride()
		var o: Vector2 = ff.grid_origin()
		_grid_ox = o.x
		_grid_oy = o.y
		_grid_cols = float(ff.cols)
		_grid_rows = float(ff.rows)
		_has_grid = _walk.size() > 0


## Walkable per the FlowField's mask (true without one): the same cell test
## FlowField.is_walkable does, on the cached byte array.
func is_walkable_at(p: Vector2) -> bool:
	if not _has_grid:
		return true
	var fx: float = (p.x - _grid_ox) * (1.0 / GRID_CELL_PX)
	var fy: float = (p.y - _grid_oy) * (1.0 / GRID_CELL_PX)
	return fx >= 0.0 and fy >= 0.0 and fx < _grid_cols and fy < _grid_rows and _walk[(int(fy) + 1) * _grid_pw + int(fx) + 1] == 1


# --- separation -----------------------------------------------------------------

## Sum of the C-SLOTS separation vectors from the enemies within `radius` (<= 32 px) of
## `p`, as EnemyController._apply_movement computed them from the registry, here from
## this tick's spatial hash.
func separation_at(slot: int, p: Vector2, radius: float) -> Vector2:
	var sx: float = 0.0
	var sy: float = 0.0
	var r: float = minf(radius, HASH_CELL_PX)
	if r <= 0.0:
		return Vector2.ZERO
	var r2: float = r * r
	var inv_r: float = 1.0 / r
	var cx: int = int((p.x + HASH_OFFSET_PX) * (1.0 / HASH_CELL_PX))
	var cy: int = int((p.y + HASH_OFFSET_PX) * (1.0 / HASH_CELL_PX))
	for oy in 3:
		var row: int = ((cy + oy - 1) & HASH_MASK) << HASH_SHIFT
		for ox in 3:
			var j: int = _head[((cx + ox - 1) & HASH_MASK) | row]
			while j >= 0:
				if j != slot and mode[j] == 1:
					var q: Vector2 = pos[j]
					var dx: float = p.x - q.x
					var dy: float = p.y - q.y
					var d2: float = dx * dx + dy * dy
					if d2 <= r2:
						if d2 < 0.000001:
							var a: float = float(slot) * 2.399963 # golden angle: a stable, spread-out push
							sx += cos(a)
							sy += sin(a)
						else:
							var d: float = sqrt(d2)
							var w: float = (r - d) * inv_r / d
							sx += dx * w
							sy += dy * w
				j = hnext[j]
	return Vector2(sx, sy)


# --- the step ---------------------------------------------------------------------

func physics_step(delta: float) -> void:
	if _order_dirty:
		_compact()
	var n: int = _order.size()
	if n == 0:
		return
	var t0: int = Time.get_ticks_usec() if profile_enabled else 0
	var clock: Node = _clock if _clock != null else SimClock
	var now: float = clock.now
	var tick: int = Engine.get_physics_frames()
	_refresh_refs(tick)
	var ppos: Vector2 = Vector2.ZERO
	var has_player: bool = _player != null and is_instance_valid(_player)
	if has_player:
		ppos = _player.global_position
		player_y = ppos.y
		if _player.has_method(&"is_pass_through") and _player.is_pass_through():
			has_player = false # dashing: the player passes through enemy bodies
	var tpos: Vector2 = Vector2.ZERO
	var has_tower: bool = _tower != null and is_instance_valid(_tower)
	if has_tower:
		tpos = _tower.global_position
		tower_y = tpos.y

	# Spatial hash (head / next linked list over 32 px cells).
	_head.fill(-1)
	var inv_cell: float = 1.0 / HASH_CELL_PX
	for k in n:
		var s: int = _order[k]
		var q: Vector2 = pos[s]
		var b: int = (int((q.x + HASH_OFFSET_PX) * inv_cell) & HASH_MASK) | ((int((q.y + HASH_OFFSET_PX) * inv_cell) & HASH_MASK) << HASH_SHIFT)
		hnext[s] = _head[b]
		_head[b] = s
	if profile_enabled:
		last_hash_usec = Time.get_ticks_usec() - t0

	var alive: int = SwarmState.alive_count
	var lod: bool = alive >= EnemyController.SWARM_LOD_MIN_ALIVE
	var interval: int = EnemyController.swarm_think_interval()
	var statuses: Dictionary = StatusEffects.get_state()
	var has_status: bool = not statuses.is_empty()
	var tower_zone: float = _tower_radius
	var plans: int = 0
	var plan_us: int = 0
	var sync_us: int = 0

	for k in n:
		var i: int = _order[k]
		if mode[i] == 0:
			continue
		var p: Vector2 = pos[i]
		prev[i] = p
		if hold[i] == 1:
			continue
		if has_status and statuses.has(uid[i]) and StatusEffects.is_frozen(ents[i]):
			ents[i].swarm_frozen(now) # frozen: no movement, no attack (physics_step's own freeze gate)
			continue
		if needs_plan[i] == 1 or not lod or (tick + phase[i]) % interval == 0:
			needs_plan[i] = 0
			plans += 1
			var e = ents[i]
			var tp0: int = Time.get_ticks_usec() if profile_enabled else 0
			var alive_after: bool = e.swarm_plan(self, i, now)
			if profile_enabled:
				plan_us += Time.get_ticks_usec() - tp0
			if not alive_after:
				continue # despawned (stuck rule) or dead
			vel[i] = e._sw_vel
			attn[i] = 1 if e._sw_attn else 0
		elif attn[i] == 1:
			var e2 = ents[i]
			e2.swarm_coast(now)
			attn[i] = 1 if e2._sw_attn else 0

		var np: Vector2 = p
		var v: Vector2 = vel[i]
		if v.x != 0.0 or v.y != 0.0:
			np = p + v * delta
			if _has_grid:
				var fx: float = (np.x - _grid_ox) * (1.0 / GRID_CELL_PX)
				var fy: float = (np.y - _grid_oy) * (1.0 / GRID_CELL_PX)
				if not (fx >= 0.0 and fy >= 0.0 and fx < _grid_cols and fy < _grid_rows and _walk[(int(fy) + 1) * _grid_pw + int(fx) + 1] == 1):
					# Blocked: slide along the wall (x only, then y only); stay when
					# neither works, unless this cell is itself blocked (walk out).
					var nx := Vector2(np.x, p.y)
					var ny := Vector2(p.x, np.y)
					if is_walkable_at(nx):
						np = nx
					elif is_walkable_at(ny):
						np = ny
					elif is_walkable_at(p):
						np = p
		# Push out of the player and the Tower (bodies must not overlap visibly).
		var r_i: float = rad[i]
		if has_player:
			var rr: float = _player_radius + r_i
			var dx: float = np.x - ppos.x
			var dy: float = np.y - ppos.y
			if absf(dx) < rr and absf(dy) < rr:
				var l2: float = dx * dx + dy * dy
				if l2 < rr * rr:
					var out: Vector2 = Vector2(dx, dy)
					if l2 < 0.0001:
						out = Vector2.from_angle(float(i) * 2.399963)
						l2 = 1.0
					var cand: Vector2 = ppos + out * (rr / sqrt(l2))
					if is_walkable_at(cand):
						np = cand
		if has_tower:
			var tr: float = tower_zone + r_i
			var tx: float = np.x - tpos.x
			var ty: float = np.y - tpos.y
			if absf(tx) < tr and absf(ty) < tr:
				var tl2: float = tx * tx + ty * ty
				if tl2 < tr * tr:
					var tout: Vector2 = Vector2(tx, ty)
					if tl2 < 0.0001:
						tout = Vector2.from_angle(float(i) * 2.399963)
						tl2 = 1.0
					var tcand: Vector2 = tpos + tout * (tr / sqrt(tl2))
					if is_walkable_at(tcand):
						np = tcand
		if np != p:
			pos[i] = np
			var ts0: int = Time.get_ticks_usec() if profile_enabled else 0
			var e3: Node2D = ents[i] as Node2D
			e3.global_position = np
			var rs: int = regslot[i]
			if rs >= 0:
				_registry.update_position_by_slot(rs, np)
			if profile_enabled:
				sync_us += Time.get_ticks_usec() - ts0
	last_plan_count = plans
	last_plan_usec = plan_us
	last_sync_usec = sync_us
	if profile_enabled:
		last_loop_usec = Time.get_ticks_usec() - t0
	var r: Node = SwarmState.renderer
	if r != null:
		r.mark_dirty()


# --- test seams ----------------------------------------------------------------------

func get_position_of(slot: int) -> Vector2:
	return pos[slot]


func get_velocity_of(slot: int) -> Vector2:
	return vel[slot]


func slot_count() -> int:
	return _order.size()

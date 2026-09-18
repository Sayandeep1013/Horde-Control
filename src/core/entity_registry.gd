extends Node

## EntityRegistry Autoload (docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Communication, queries"; MASTER_SDLC.md >
## Global Simulation Authority, process-mode paragraph: "`SimClock`,
## `EntityRegistry`, and `CombatStats` are `PROCESS_MODE_PAUSABLE`, so they
## stop with the simulation"). The typed READ-ONLY query interface docs/20
## names directly: "`EntityRegistry.get_enemies_in_radius(origin, radius)`".
##
## docs/20 bans a signal emitted every tick to broadcast state ("A signal
## emitted every tick to broadcast state is an anti-pattern and is banned").
## This registry never emits anything at all -- it is pulled, not pushed.
## The only way in or out of it is a typed command (register/deregister/
## update_position/set_entity_alive, below) or a typed query
## (get_*_in_radius, get_*_count, etc.). No per-tick self-driven work either:
## this script has no _process()/_physics_process() of its own: the mover of
## an entity (SimLoop step 2 "player movement" / step 3 "enemy AI and
## movement", once built) is the one typed-command caller responsible for
## keeping this registry's cached position current, exactly the way step 5's
## projectile sweep is the one caller of SimLoop.enqueue_hit() -- the
## registry does not go looking for state itself.
##
## Storage design (Registry query check, P1.2: one radius query under
## 0.05 ms with 300 entities registered -- see the P1.2 evidence report for
## the full timing method, iteration counts, spread, and the clustered-
## versus-uniform result this design was measured against, not assumed to
## meet):
##   - "Structure of arrays": every registered entity occupies one dense
##     integer "slot". Positions live in a single PackedVector2Array
##     (_slot_position), liveness in a PackedByteArray (_slot_alive), and
##     tag membership in a PackedInt64Array bitmask (_slot_tag_mask, one bit
##     per distinct tag string, assigned the first time that tag is seen) --
##     not scattered across Node2D.global_position look-ups or a per-slot
##     Array[StringName] scanned with .has() per candidate. The bitmask
##     replaced an initial Array[StringName]-per-slot design after measuring
##     it: the tag membership test alone accounted for roughly half of the
##     per-candidate cost in the clustered timing probe (154us with a tag
##     filter vs 79us with none, same candidate set) before the bitmask
##     replaced it with a single integer AND.
##   - A uniform spatial hash grid (_grid: Vector2i cell -> Array[int] slot)
##     buckets every slot by floor(position / _cell_size). A radius query
##     visits only the grid cells overlapping the query circle's bounding
##     box, not every registered entity, so it beats a brute-force scan
##     whenever the queried entities are NOT all clustered in the query's
##     own neighbourhood. Because each slot lives in exactly one cell, a
##     query never has to de-duplicate a slot seen twice.
##   - The grid is maintained incrementally (register/update_position/
##     deregister each move at most one slot between at most two cells), not
##     rebuilt from scratch per query -- a per-query rebuild would cost the
##     same O(n) the grid exists to avoid, on every single call.
##   - Honest limit, stated rather than hidden: the grid's benefit depends on
##     entities NOT all sharing the queried neighbourhood's cells. 300
##     enemies converging on the Tower -- the clustered case this game will
##     actually produce -- puts most of the entity cap inside the same
##     handful of cells the Tower's own queries touch, so the grid degrades
##     toward a cost close to (measured slightly ABOVE) a brute-force scan's
##     per-candidate cost, times the number of true positives. The entity
##     cap itself (300, Provisional Values Register) is what bounds the
##     worst case, not the grid; the P1.2 evidence report's clustered
##     measurement is the actual number for that worst case, stated
##     honestly even where it exceeds the 0.05 ms bound, not a claim that
##     the grid protects it.

const DEFAULT_CELL_SIZE: float = 200.0

## Hard ceiling on distinct tags this registry can track at once (a 63-bit
## mask, bit 63 reserved to keep the mask a positive GDScript int). Every
## tag this project's documents name so far (enemy, player, tower, pickup,
## projectile) is a handful; this ceiling exists so a runaway caller fails
## loudly (see _bit_for_tag) rather than corrupting another tag's bit.
const MAX_DISTINCT_TAGS: int = 63

var _cell_size: float = DEFAULT_CELL_SIZE

# Dense slot arrays, structure-of-arrays layout (see header comment).
var _slot_entity: Array[Node2D] = []
var _slot_position: PackedVector2Array = PackedVector2Array()
var _slot_alive: PackedByteArray = PackedByteArray() # 0 or 1
var _slot_tag_mask: PackedInt64Array = PackedInt64Array()
var _free_slots: Array[int] = []

## Typed Dictionaries throughout (Godot 4.4+, godot-prompter:gdscript-advanced
## "Typed Dictionary access ... skip the Variant unbox per read") -- applies
## directly to `_grid`, looked up 9-36 times per radius query depending on
## cell size and query radius (see the header comment's storage design).
var _entity_to_slot: Dictionary[Node2D, int] = {}
var _grid: Dictionary[Vector2i, PackedInt32Array] = {}

var _tag_bit: Dictionary[StringName, int] = {}
var _next_tag_bit: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Test-only knob (see tests/unit/entity_registry_query_perf_test.gd): lets
## the acceptance test exercise a specific cell size against uniform and
## clustered distributions without rebuilding the whole registry. Never
## called by gameplay code -- the DEFAULT_CELL_SIZE above is what ships.
func set_cell_size_for_test(cell_size: float) -> void:
	assert(cell_size > 0.0, "cell size must be positive")
	_cell_size = cell_size
	_rebuild_grid_for_test()


func _rebuild_grid_for_test() -> void:
	_grid.clear()
	for slot in _slot_entity.size():
		if _slot_entity[slot] != null:
			_add_to_grid(slot, _slot_position[slot])


## Typed command (docs/20 > Communication, commands). Registers `entity`
## under `position` and `tags`, alive by default. Refuses (returns false,
## registers nothing) a null entity or one already registered -- the
## validation this project's commands rule requires is real here: a caller
## cannot double-register the same node into two slots by mistake.
##
## `tags` is deliberately typed as a bare `Array`, not `Array[StringName]`,
## and converted internally -- matching the existing KeyedRng.rng_for(parts:
## Array) precedent for the same reason: a caller that only holds this
## Autoload through a weakly-typed `Node` reference (the pattern every test
## file in this project uses for an Autoload script under test, e.g.
## pause_clock_test.gd's `var _pause: Node`) passes an array literal like
## `[&"enemy"]` whose static type GDScript cannot verify against a
## strictly-typed `Array[StringName]` parameter at that call site; Godot
## 4.7.1 raises a runtime "does not have the same element type" error rather
## than converting it, discovered while building the P1.2 timing probe --
## see the P1.2 evidence report, "Contradictions and ambiguities."
func register_entity(entity: Node2D, position: Vector2, tags: Array) -> bool:
	if entity == null:
		return false
	if _entity_to_slot.has(entity):
		return false
	var mask: int = _mask_for_tags(tags, true)
	var slot: int
	if not _free_slots.is_empty():
		slot = _free_slots.pop_back()
		_slot_entity[slot] = entity
		_slot_position[slot] = position
		_slot_alive[slot] = 1
		_slot_tag_mask[slot] = mask
	else:
		slot = _slot_entity.size()
		_slot_entity.append(entity)
		_slot_position.append(position)
		_slot_alive.append(1)
		_slot_tag_mask.append(mask)
	_entity_to_slot[entity] = slot
	_add_to_grid(slot, position)
	return true


## Typed command. Refuses (returns false) an entity that was never
## registered, or is already deregistered. The freed slot is recycled by
## register_entity() rather than left as a permanent hole, so long-running
## register/deregister churn (a real Pool acquire/release cycle, once P1.3
## exists) does not grow these arrays without bound.
func deregister_entity(entity: Node2D) -> bool:
	if entity == null or not _entity_to_slot.has(entity):
		return false
	var slot: int = _entity_to_slot[entity]
	_remove_from_grid(slot, _slot_position[slot])
	_entity_to_slot.erase(entity)
	_slot_entity[slot] = null
	_slot_tag_mask[slot] = 0
	_free_slots.append(slot)
	return true


## Slots whose entity was freed without being deregistered. Collected during a
## query and released after it, because the grid cannot be mutated while it is
## being iterated.
var _dangling: PackedInt32Array = PackedInt32Array()


## Releases slots whose entity reference has been freed.
##
## Phase 02 LEDGER F02-15. A registered entity that is freed without
## `deregister_entity()` leaves a dangling reference in `_slot_entity`.
## Appending that reference to a typed `Array[Node2D]` makes Godot emit
## "Attempted to push_back an invalid (previously freed?) object instance" -
## an engine-level error that gdUnit4 does NOT count as a test error, so a
## suite reporting "172 tests, 0 errors, exit 0" was emitting thirty of them.
##
## Freeing without deregistering is a caller bug, but the registry is queried
## by Tower targeting, weapon auto-targeting, the magnet and the Pressure
## Metric - every tick, from several systems - so it self-heals rather than
## propagating one caller's mistake into a query result or an engine error.
func _reap_dangling() -> void:
	if _dangling.is_empty():
		return
	for slot in _dangling:
		var stale: Variant = _slot_entity[slot]
		_remove_from_grid(slot, _slot_position[slot])
		if stale != null:
			_entity_to_slot.erase(stale)
		_slot_entity[slot] = null
		_slot_tag_mask[slot] = 0
		_slot_alive[slot] = 0
		_free_slots.append(slot)
	_dangling.clear()


## Typed command. Moves a registered entity's tracked position, updating the
## spatial grid incrementally (remove from the old cell, add to the new
## one). Refuses an unregistered entity.
func update_position(entity: Node2D, position: Vector2) -> bool:
	if entity == null or not _entity_to_slot.has(entity):
		return false
	var slot: int = _entity_to_slot[entity]
	_remove_from_grid(slot, _slot_position[slot])
	_slot_position[slot] = position
	_add_to_grid(slot, position)
	return true


## Typed command. Flips a registered entity's liveness for query purposes,
## without deregistering it -- Logical Death (docs/20) sets a `dead` flag on
## the entity itself and keeps it in the scene (ragdoll/knockback, pool
## reuse later); this is the one sanctioned channel for that flag to reach
## the registry's query results, since docs/20 bans a per-tick broadcast and
## the registry has no license to read arbitrary properties off arbitrary
## node classes. Refuses an unregistered entity.
func set_entity_alive(entity: Node2D, alive: bool) -> bool:
	if entity == null or not _entity_to_slot.has(entity):
		return false
	_slot_alive[_entity_to_slot[entity]] = 1 if alive else 0
	return true


func is_registered(entity: Node2D) -> bool:
	return entity != null and _entity_to_slot.has(entity)


## Typed query. Empty array (not an error) for an unregistered entity.
func get_tags(entity: Node2D) -> Array[StringName]:
	if entity == null or not _entity_to_slot.has(entity):
		return []
	var mask: int = _slot_tag_mask[_entity_to_slot[entity]]
	var out: Array[StringName] = []
	for tag in _tag_bit.keys():
		var bit: int = _tag_bit[tag]
		if (mask & (1 << bit)) != 0:
			out.append(tag)
	return out


## Typed query (docs/20 named example): every LIVE registered entity within
## `radius` of `origin`, filtered to entities carrying `tag` if `tag` is not
## the empty StringName, else unfiltered. `include_dead` exists for the rare
## caller that needs corpses too (none in the prototype); every named
## consumer in the documents -- Tower targeting, the magnet raycast, wave
## completion counts -- wants live entities only, so that is the default.
func get_entities_in_radius(origin: Vector2, radius: float, tag: StringName = &"", include_dead: bool = false) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if radius <= 0.0:
		return result
	var filter_by_tag: bool = tag != &""
	var tag_mask: int = 0
	if filter_by_tag:
		var bit: int = _bit_for_tag(tag, false)
		if bit < 0:
			return result # no entity has ever carried this tag
		tag_mask = 1 << bit
	var r2: float = radius * radius
	var min_cell: Vector2i = _cell_of(origin - Vector2(radius, radius))
	var max_cell: Vector2i = _cell_of(origin + Vector2(radius, radius))
	for cx in range(min_cell.x, max_cell.x + 1):
		for cy in range(min_cell.y, max_cell.y + 1):
			var bucket: Variant = _grid.get(Vector2i(cx, cy))
			if bucket == null:
				continue
			for slot in (bucket as PackedInt32Array):
				if not include_dead and _slot_alive[slot] == 0:
					continue
				if filter_by_tag and (_slot_tag_mask[slot] & tag_mask) == 0:
					continue
				var pos: Vector2 = _slot_position[slot]
				if origin.distance_squared_to(pos) <= r2:
					var entity: Node2D = _slot_entity[slot]
					if not is_instance_valid(entity):
						_dangling.append(slot)
						continue
					result.append(entity)
	_reap_dangling()
	return result


## Typed query (docs/20 named example, `EntityRegistry.get_enemies_in_radius
## (origin, radius)` verbatim): convenience wrapper over
## get_entities_in_radius() filtered to the `&"enemy"` tag.
func get_enemies_in_radius(origin: Vector2, radius: float) -> Array[Node2D]:
	return get_entities_in_radius(origin, radius, &"enemy")


## Typed query. Every live registered entity carrying `tag` (docs/11_Wave_
## Director.md: "Wave and encounter completion is always driven by
## EntityRegistry tag queries against actual live entities").
func get_entities_with_tag(tag: StringName, include_dead: bool = false) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var bit: int = _bit_for_tag(tag, false)
	if bit < 0:
		return result
	var tag_mask: int = 1 << bit
	for slot in _slot_entity.size():
		if _slot_entity[slot] == null:
			continue
		if not is_instance_valid(_slot_entity[slot]):
			_dangling.append(slot)
			continue
		if not include_dead and _slot_alive[slot] == 0:
			continue
		if (_slot_tag_mask[slot] & tag_mask) != 0:
			result.append(_slot_entity[slot])
	_reap_dangling()
	return result


## Typed query (docs/11_Wave_Director.md: "The final combat wave ... ends
## only when the EntityRegistry live-enemy count is zero").
func get_live_enemy_count() -> int:
	return get_entity_count(&"enemy")


## Typed query. Count of live entities, optionally filtered to `tag`.
func get_entity_count(tag: StringName = &"", include_dead: bool = false) -> int:
	var filter_by_tag: bool = tag != &""
	var tag_mask: int = 0
	if filter_by_tag:
		var bit: int = _bit_for_tag(tag, false)
		if bit < 0:
			return 0
		tag_mask = 1 << bit
	var count: int = 0
	for slot in _slot_entity.size():
		if _slot_entity[slot] == null:
			continue
		if not include_dead and _slot_alive[slot] == 0:
			continue
		if filter_by_tag and (_slot_tag_mask[slot] & tag_mask) == 0:
			continue
		count += 1
	return count


## Returns the bitmask index for `tag`, assigning a fresh one on first sight
## when `create_if_missing` is true (registration). When false (query-side
## lookups), an unseen tag returns -1 so the caller can short-circuit --
## nothing has ever been registered under a tag this registry has never
## assigned a bit for, so the query result is trivially empty.
func _bit_for_tag(tag: StringName, create_if_missing: bool) -> int:
	if _tag_bit.has(tag):
		return _tag_bit[tag]
	if not create_if_missing:
		return -1
	if _next_tag_bit >= MAX_DISTINCT_TAGS:
		push_error("EntityRegistry: more than %d distinct tags registered; '%s' cannot be tracked" % [MAX_DISTINCT_TAGS, tag])
		return -1
	var bit: int = _next_tag_bit
	_tag_bit[tag] = bit
	_next_tag_bit += 1
	return bit


func _mask_for_tags(tags: Array, create_if_missing: bool) -> int:
	var mask: int = 0
	for t in tags:
		var bit: int = _bit_for_tag(StringName(t), create_if_missing)
		if bit >= 0:
			mask |= (1 << bit)
	return mask


func _cell_of(position: Vector2) -> Vector2i:
	return Vector2i(int(floor(position.x / _cell_size)), int(floor(position.y / _cell_size)))


func _add_to_grid(slot: int, position: Vector2) -> void:
	var cell: Vector2i = _cell_of(position)
	if not _grid.has(cell):
		_grid[cell] = PackedInt32Array()
	var bucket: PackedInt32Array = _grid[cell]
	bucket.append(slot)
	_grid[cell] = bucket


func _remove_from_grid(slot: int, position: Vector2) -> void:
	var cell: Vector2i = _cell_of(position)
	if not _grid.has(cell):
		return
	var bucket: PackedInt32Array = _grid[cell]
	var idx: int = bucket.find(slot)
	if idx != -1:
		bucket.remove_at(idx)
	if bucket.is_empty():
		_grid.erase(cell)
	else:
		_grid[cell] = bucket

extends Node2D
class_name PickupSystem

## PickupSystem (P2.10; MASTER_SDLC.md > Provisional Values Register >
## "Economy & Pickups"; > "Pickup Physics & Magnet Rules"; > "Economy
## Rules"; > "Economy Edge Cases"; docs/20_Technical_Architecture.md >
## "SimLoop order" steps 9-11). Owns pickup spawning (always through
## `EntitySpawner.spawn_pickup()`, never ad hoc), the pickup cap / C-MERGE
## cascade, the Drop Table, collection, and `run_inventory` (RunInventory,
## src/economy/run_inventory.gd) -- the run-scoped Scrap/XP/level state the
## HUD wiring brief asks this task to expose.
##
## `extends Node2D` (not plain Node) only so `_resolve_open_point()` can
## call the same `get_world_2d().direct_space_state` pattern already
## established in this codebase (src/combat/player_projectile.gd) --
## nothing here uses this node's own transform.
##
## ## Wiring surface for the orchestrator
## `src/core/sim_loop.gd` gained a generic registration API
## (`register(step, node)`, F03-09) concurrently with this task -- this file
## discovered it mid-implementation and self-registers against it (see
## `_register_adapters()` below) via three small `PickupSystemStepAdapter`
## instances, one per step, exactly the way `src/director/wave_director.gd`
## already registers itself at step 13. This node finds the live SimLoop
## instance the same documented way every other caller does
## (`get_tree().get_first_node_in_group(&"sim_loop")`, deferred past
## `_ready()` -- see sim_loop.gd's own header, "Reaching this instance from
## elsewhere"), so simply placing this node anywhere under the same tree as
## the real SimLoop is enough; no manual per-step wiring is required.
## REQUIRED SEAM (see the P2.10 evidence report): `sim_loop.gd`'s own
## `_step_09_drops()`, `_step_10_pickup_movement_and_collection()`, and
## `_step_11_xp_and_level_up_requests()` do not yet call `_run_step()` for
## their steps the way `_step_13_wave_director()` already does -- until
## whoever owns src/core/sim_loop.gd adds those three calls, registering
## here has no observable effect in the running game even though the
## registration itself succeeds.
## `step_drops()`/`step_pickup_movement_and_collection()`/
## `step_xp_and_level_up_requests()` remain public and directly callable
## (accepting an unused optional `delta` where the step itself needs none),
## for a test or an alternate integration that prefers calling them
## directly over the registration API.
##
## Also: `player_collector_path` (or `configure_collector()`) must be wired
## to the real Player's PlayerCollector node, and `player_path` (or
## `configure_player_for_test()`) to the real Player, for the magnet radius
## and collection to do anything in the assembled scene. `entity_spawner_path`
## must be wired to the scene's EntitySpawner. See the P2.10 evidence
## report, "Wiring surface", for the full list and defaults.

## Register > Technical Caps & Performance > "Entity caps": "pickups 150".
## Independently transcribed, not read from src/core/entity_caps.gd --
## that file's own header states "src/core/entity_spawner.gd is the only
## reader of these six constants", the same reasoning
## tests/unit/entity_cap_test.gd already applies to avoid a value agreeing
## with itself if it were ever wrong in one place.
const PICKUP_CAP: int = 150

## Search pattern for "Unreachable drops" (MASTER_SDLC.md: "A drop whose
## spawn position is inside terrain is placed at the nearest open point").
## NO REGISTER ROW -- escalated: the master states the RULE but not a
## search radius/step count; these are a fallback-chain shape, not a
## balance number, chosen generously enough to clear any plausible terrain
## footprint in a 4800x3200 arena without an unbounded search.
const OPEN_POINT_SEARCH_RADII_PX: Array[float] = [16.0, 32.0, 48.0, 64.0, 96.0, 128.0, 192.0]
const OPEN_POINT_SEARCH_DIRECTIONS: int = 8

@export var economy_configuration: EconomyConfiguration = preload("res://data/economy/prototype.tres")
@export var xp_shard_definition: PickupDefinition = preload("res://data/pickups/xp_shard.tres")
@export var scrap_definition: PickupDefinition = preload("res://data/pickups/scrap.tres")

@export var entity_spawner_path: NodePath
@export var player_path: NodePath
@export var player_collector_path: NodePath

## Register > Economy & Pickups > "Magnet radius / pickup motion": "96 px".
## Also PlayerDefinition.magnet_radius_px (data/player/prototype.tres),
## which is the LIVE source of truth once `player_path` is wired --
## src/player/player.gd's own header: "magnet_radius_px is authored on the
## .tres for the future pickup system ... to read". This field is only the
## fallback used when no player is configured (an isolated unit test, or
## the system running before the Player exists in the tree).
@export var magnet_radius_px_default: float = 96.0

var run_inventory: RunInventory = RunInventory.new()

var _spawner: Node = null
var _player: Player = null
var _collector: PlayerCollector = null
var _registry: Node = EntityRegistry
var _event_bus: Object = EventBus
var _sim_clock: Node = SimClock

var _active_pickups: Array[Pickup] = []
var _next_spawn_serial: int = 0
var _pending_drops: Array[Dictionary] = [] # {"drop_table": DropTable, "position": Vector2}

var _drops_adapter: PickupSystemStepAdapter = null
var _movement_adapter: PickupSystemStepAdapter = null
var _xp_adapter: PickupSystemStepAdapter = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	run_inventory.configure(economy_configuration, _event_bus)
	if entity_spawner_path != NodePath():
		_spawner = get_node_or_null(entity_spawner_path)
	if player_path != NodePath():
		_player = get_node_or_null(player_path) as Player
	if player_collector_path != NodePath():
		_collector = get_node_or_null(player_collector_path) as PlayerCollector
	_connect_collector()
	_connect_enemy_died()
	call_deferred("_find_and_register_with_sim_loop")


## Deferred past _ready() per sim_loop.gd's own documented convention
## ("Reaching this instance from elsewhere"): a same-frame, non-deferred
## group lookup from this node's own _ready() could run before SimLoop's
## _ready() has joined the &"sim_loop" group, depending on sibling order.
func _find_and_register_with_sim_loop() -> void:
	if _drops_adapter != null:
		return # already registered (e.g. a test called set_sim_loop_for_test() first)
	var sim_loop: Node = get_tree().get_first_node_in_group(&"sim_loop") if is_inside_tree() else null
	if sim_loop != null:
		_register_adapters(sim_loop)


## Test/orchestrator seam: register against a specific SimLoop instance
## synchronously, without waiting for the deferred group lookup above --
## matching this project's "test-injectable, defaults to the real thing"
## convention applied to a scene-tree singleton instead of an Autoload.
func set_sim_loop_for_test(sim_loop: Node) -> void:
	_register_adapters(sim_loop)


func _register_adapters(sim_loop: Node) -> void:
	_drops_adapter = PickupSystemStepAdapter.new()
	_drops_adapter.configure(Callable(self, "step_drops"))
	add_child(_drops_adapter)

	_movement_adapter = PickupSystemStepAdapter.new()
	_movement_adapter.configure(Callable(self, "step_pickup_movement_and_collection"))
	add_child(_movement_adapter)

	_xp_adapter = PickupSystemStepAdapter.new()
	_xp_adapter.configure(Callable(self, "step_xp_and_level_up_requests"))
	add_child(_xp_adapter)

	sim_loop.register(SimLoop.Step.DROPS, _drops_adapter)
	sim_loop.register(SimLoop.Step.PICKUP_MOVEMENT_AND_COLLECTION, _movement_adapter)
	sim_loop.register(SimLoop.Step.XP_AND_LEVEL_UP_REQUESTS, _xp_adapter)


func _connect_enemy_died() -> void:
	if _event_bus == null:
		return
	var callable: Callable = Callable(self, "_on_enemy_died")
	if _event_bus.has_signal("enemy_died") and not _event_bus.is_connected("enemy_died", callable):
		_event_bus.connect("enemy_died", callable)


func _connect_collector() -> void:
	if _collector != null and not _collector.pickup_entered.is_connected(_on_pickup_entered_collector):
		_collector.pickup_entered.connect(_on_pickup_entered_collector)


# --- Test/orchestrator DI seams -------------------------------------------

func set_entity_spawner_for_test(spawner: Node) -> void:
	_spawner = spawner


func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_sim_clock_for_test(clock: Node) -> void:
	_sim_clock = clock


## Also re-wires run_inventory and the enemy_died connection onto the same
## fake bus, so a test's fake EventBus is the single source every part of
## this system listens to.
func set_event_bus_for_test(event_bus: Object) -> void:
	_event_bus = event_bus
	run_inventory.configure(economy_configuration, _event_bus)
	_connect_enemy_died()


func configure_collector(collector: PlayerCollector) -> void:
	_collector = collector
	_connect_collector()


func configure_player_for_test(player: Player) -> void:
	_player = player


## Test-only teardown, matching entity_spawner.gd's own clear_all_for_test()
## naming convention: despawns every pickup this system currently tracks so
## a test suite does not leak pooled instances across test functions.
func clear_all_for_test() -> void:
	for p in _active_pickups.duplicate():
		if _spawner != null:
			_spawner.despawn_pickup(p)
	_active_pickups.clear()
	_pending_drops.clear()


func get_active_pickup_count() -> int:
	return _active_pickups.size()


## Test seam: a snapshot of every pickup this system currently tracks, in
## spawn order (oldest first) -- lets a test inspect the C-MERGE cascade's
## outcome (which instance survived, its value, its position) without
## reaching into private state via Object.get().
func get_active_pickups_for_test() -> Array[Pickup]:
	return _active_pickups.duplicate()


# --- Drop Table (EventBus.enemy_died / EnemyController.removed_while_stuck) -

## MASTER_SDLC.md > Provisional Values Register > "Economy & Pickups" >
## "Drop Table". Listens to the existing EventBus.enemy_died signal
## (entity, position, timestamp) rather than reaching into enemies for a
## death poll, per this task's own brief.
func _on_enemy_died(entity: Node2D, position: Vector2, _timestamp: float) -> void:
	var drop_table: DropTable = _resolve_drop_table_for(entity)
	if drop_table == null:
		return
	_queue_drop(drop_table, position)


## `entity.get("definition")` / `.get("is_finisher")` are duck-typed public
## FIELD reads off the entity `enemy_died` already hands this listener --
## the same class of read src/enemy/enemy_controller.gd's own
## `removed_while_stuck` signal already performs
## (`definition.drop_table if definition != null else null`) -- not a
## behavioural reach into the enemy's AI/state. `.get()` on an Object
## returns null for a property that does not exist rather than erroring, so
## this tolerates any Node2D EventBus.enemy_died might ever be emitted for.
##
## Escalation (see the P2.10 evidence report, "Escalations", for the full
## reasoning): MASTER_SDLC.md > Provisional Values Register > "Spawning &
## Waves" > "Overtime finishers": "drop 1 XP and no Scrap". The one
## per-instance signal available here is EnemyController.is_finisher (a
## public @export field, already built by P1.5/P2.5); docs/11's own
## OvertimeCondition.finisher_drop_override field
## (src/data/overtime_condition.gd) is the data-authored source Wave
## Director (P2.8) configuration carries for this override, but it lives on
## Wave Director state this task has no reach into from an EventBus signal
## alone (entity, position, timestamp -- no configuration reference). This
## falls back to a fixed override instead: is_finisher true keeps the
## entity's own authored XP count and zeroes Scrap, matching the Register's
## literal "1 XP and no Scrap" directly. If a wave ever authors a
## finisher_drop_override with a different XP amount, this will not reflect
## it -- named as a seam for reconciliation, not silently assumed correct.
func _resolve_drop_table_for(entity: Node2D) -> DropTable:
	if entity == null:
		return null
	var definition: Object = entity.get("definition")
	if definition == null:
		return null
	var base_drop_table: DropTable = definition.get("drop_table")
	if base_drop_table == null:
		return null
	var is_finisher: Variant = entity.get("is_finisher")
	if is_finisher == true:
		var override: DropTable = DropTable.new()
		override.xp_shards = base_drop_table.xp_shards
		override.scrap = 0
		override.cores = 0
		return override
	return base_drop_table


## Public seam for a stuck-despawned enemy (docs/09_Enemy_AI_Architecture.md
## > "Stuck rules": "it despawns, its drops are placed at its position, and
## it counts as removed, not killed"; MASTER_SDLC.md task brief: "a
## stuck-despawned enemy still drops, placed").
## src/enemy/enemy_controller.gd's own `removed_while_stuck(position,
## drop_table)` signal already carries exactly this payload (its own
## comment: "No EventBus signal exists for 'enemy removed, not killed, with
## drops to place' ... Named as an Escalation" -- P2.5's own escalation,
## which this method is the answer to).
##
## REQUIRED SEAM (see the P2.10 evidence report): this task's write scope
## does not include spawning enemies, so nothing here connects a live
## EnemyController's removed_while_stuck signal to this method. Whoever
## spawns EnemyController instances (currently src/director/wave_director.gd,
## P2.8, outside this task's write paths) must connect each spawned
## instance's `removed_while_stuck` signal to this method for a
## stuck-despawned enemy's drop to actually reach the field.
func handle_enemy_removed_while_stuck(position: Vector2, drop_table: DropTable) -> void:
	if drop_table == null:
		return
	_queue_drop(drop_table, position)


func _queue_drop(drop_table: DropTable, position: Vector2) -> void:
	_pending_drops.append({"drop_table": drop_table, "position": position})


func get_pending_drop_count_for_test() -> int:
	return _pending_drops.size()


## SimLoop step 9 ("drops") entry point. Drains every drop queued since the
## last call and turns each into real pickups through EntitySpawner,
## resolving "Unreachable drops" placement and the pickup cap / C-MERGE
## cascade for each currency independently (a kill can drop both an XP
## shard and Scrap in the same call).
func step_drops(_delta: float = 0.0) -> void:
	var drops: Array[Dictionary] = _pending_drops.duplicate()
	_pending_drops.clear()
	for entry in drops:
		var drop_table: DropTable = entry["drop_table"]
		var position: Vector2 = _resolve_open_point(entry["position"])
		if drop_table.xp_shards > 0:
			_spawn_one_pickup(xp_shard_definition, drop_table.xp_shards, position)
		if drop_table.scrap > 0:
			_spawn_one_pickup(scrap_definition, drop_table.scrap, position)


# --- Spawning, the pickup cap, and C-MERGE ----------------------------------

func _spawn_one_pickup(definition: PickupDefinition, amount: int, position: Vector2) -> Pickup:
	if _spawner == null:
		push_warning("PickupSystem: no EntitySpawner wired (entity_spawner_path unset); drop discarded")
		return null
	_free_cap_slot_for(definition.pickup_type)
	var factory: Callable = Callable(self, "_pickup_factory")
	var instance: Node = _spawner.spawn_pickup(position, factory)
	if instance == null:
		push_warning("PickupSystem: EntitySpawner.spawn_pickup() refused a pickup at the cap")
		return null
	var pickup: Pickup = instance as Pickup
	pickup.set_sim_clock_for_test(_sim_clock)
	pickup.set_registry_for_test(_registry)
	pickup.configure(definition, amount, position, _next_spawn_serial)
	pickup.driven_externally = true # this system, not this instance's own _physics_process, drives it (step_pickup_movement_and_collection)
	_next_spawn_serial += 1
	_active_pickups.append(pickup)
	return pickup


## The pool's own factory_override mechanism (src/core/pool.gd: "lets ONE
## Pool serve more than one concrete scene/archetype over its lifetime") is
## what lets a single pickup pool serve both XP and Scrap pickups; every
## call passes this SAME factory (never the pool's bare-Node2D default), so
## a reused free-list instance is always a real Pickup, of either currency.
static func _pickup_factory() -> Node2D:
	var packed: PackedScene = load("res://scenes/pickups/pickup.tscn") as PackedScene
	return packed.instantiate() as Node2D


## Rule C-MERGE (MASTER_SDLC.md > "Pickup Physics & Magnet Rules" >
## "Merging"; > Provisional Values Register > "Economy & Pickups" > "Pickup
## merge (C-MERGE)"), applied exactly: "the oldest pickup of the incoming
## drop's type merges into its nearest same-type neighbour within the merge
## radius ... If no such pair exists, the oldest pickup of the incoming
## type expires; if none of that type exists, the oldest XP shard expires,
## then the oldest Scrap." Called BEFORE `EntitySpawner.spawn_pickup()` so
## the pool's own generic RECYCLE_OLDEST overflow policy (which would
## recycle whatever instance is oldest overall, not oldest-of-this-type
## with a value-preserving merge) never actually triggers in normal
## operation -- it remains only a defensive fallback if this bookkeeping
## and the pool's own count were ever to disagree.
func _free_cap_slot_for(incoming_type: ContractEnums.PickupType) -> void:
	if _spawner == null or _spawner.get_pickup_count() < PICKUP_CAP:
		return
	var victim: Pickup = _find_oldest_of_type(incoming_type)
	if victim != null:
		var neighbor: Pickup = _find_nearest_same_type_neighbor(victim)
		if neighbor != null:
			neighbor.value += victim.value
		_despawn_pickup(victim)
		return
	var oldest_xp: Pickup = _find_oldest_of_type(ContractEnums.PickupType.XP)
	if oldest_xp != null:
		_despawn_pickup(oldest_xp)
		return
	var oldest_scrap: Pickup = _find_oldest_of_type(ContractEnums.PickupType.Scrap)
	if oldest_scrap != null:
		_despawn_pickup(oldest_scrap)
		return
	push_warning("PickupSystem: pickup cap reached with no XP or Scrap pickup active to free -- this should not happen while the cap is positive")


## `_active_pickups` is always appended in spawn order (oldest first), so
## the first match by type IS the oldest of that type.
func _find_oldest_of_type(pickup_type: ContractEnums.PickupType) -> Pickup:
	for p in _active_pickups:
		if is_instance_valid(p) and p.get_pickup_type() == pickup_type:
			return p
	return null


func _find_nearest_same_type_neighbor(victim: Pickup) -> Pickup:
	var merge_radius_px: float = float(economy_configuration.merge_radius_px)
	if victim.definition != null and victim.definition.merge_rule != null:
		merge_radius_px = float(victim.definition.merge_rule.get_match_radius_px(economy_configuration))
	var nearest: Pickup = null
	var nearest_distance: float = INF
	for p in _active_pickups:
		if p == victim or not is_instance_valid(p):
			continue
		if p.get_pickup_type() != victim.get_pickup_type():
			continue
		var distance: float = p.global_position.distance_to(victim.global_position)
		if distance <= merge_radius_px and distance < nearest_distance:
			nearest = p
			nearest_distance = distance
	return nearest


func _despawn_pickup(pickup: Pickup) -> void:
	_active_pickups.erase(pickup)
	if _spawner != null:
		_spawner.despawn_pickup(pickup)


# --- Movement & collection (SimLoop step 10) --------------------------------

## SimLoop step 10 ("pickup movement and collection") entry point. Resolves
## the live magnet radius once per tick (Register: "Upgrades can expand
## this" -- re-read every call rather than cached at spawn time), steps
## every tracked pickup's own physics, and despawns anything that expired
## this tick (Register > "Pickup lifetime": "a pickup that cannot be
## reached within its lifetime simply expires; no orphan remains").
func step_pickup_movement_and_collection(delta: float) -> void:
	var current_magnet_radius: float = _resolve_magnet_radius_px()
	for pickup in _active_pickups.duplicate():
		if not is_instance_valid(pickup):
			_active_pickups.erase(pickup)
			continue
		pickup.magnet_radius_px = current_magnet_radius
		pickup.physics_step(delta)
		if pickup.is_expired():
			_despawn_pickup(pickup)


## D115/D117 pool expansion (Magnet, +25% pickup radius/rank): reads
## `Player.get_effective_magnet_radius_px()` (definition value x the live
## upgrade multiplier) rather than `definition.magnet_radius_px` directly,
## so a Magnet rank taken mid-run is reflected here on the very next tick
## without this system ever touching the (possibly shared) PlayerDefinition
## resource itself.
func _resolve_magnet_radius_px() -> float:
	if _player != null and is_instance_valid(_player) and _player.definition != null:
		return _player.get_effective_magnet_radius_px()
	return magnet_radius_px_default


## MASTER_SDLC.md > "Pickup Physics & Magnet Rules" > "Collection": "A
## pickup is collected the instant it overlaps the player's PlayerCollector
## area ... not the player's body or hurtbox." Connected to the EXISTING
## seam (src/player/collector.gd's `pickup_entered` signal) from this node,
## per this task's own brief, rather than editing collector.gd.
func _on_pickup_entered_collector(area: Area2D) -> void:
	if not (area is Pickup):
		return
	var pickup: Pickup = area as Pickup
	if not _active_pickups.has(pickup):
		return # already processed this tick (e.g. expired or merged away)
	_collect(pickup)


func _collect(pickup: Pickup) -> void:
	match pickup.get_pickup_type():
		ContractEnums.PickupType.XP:
			run_inventory.credit_xp(float(pickup.value))
		ContractEnums.PickupType.Scrap:
			run_inventory.credit_scrap(pickup.value)
		_:
			pass # Core/Health are out of prototype scope (task brief)
	_despawn_pickup(pickup)


# --- XP / level-up requests (SimLoop step 11) -------------------------------

func step_xp_and_level_up_requests(_delta: float = 0.0) -> bool:
	return run_inventory.consume_level_up_requested()


# --- Unreachable drop placement ---------------------------------------------

## MASTER_SDLC.md > "Pickup Physics & Magnet Rules" > "Unreachable drops":
## "A drop whose spawn position is inside terrain is placed at the nearest
## open point; there is no separate 'unreachable' state." Terrain is the
## World layer (docs/20 > Collision Layers, layer 4, "Terrain and arena
## interior geometry"). Searches concentric rings of candidate points at
## increasing radius (see OPEN_POINT_SEARCH_RADII_PX's own header comment
## for why these numbers are escalated, not Register numbers) and returns
## the original position, with a warning, if none clears within the search
## bound -- there is no separate "unreachable" state to fall into instead.
func _resolve_open_point(position: Vector2) -> Vector2:
	if not is_inside_tree():
		return position
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if not _point_is_inside_world(space_state, position):
		return position
	for radius in OPEN_POINT_SEARCH_RADII_PX:
		for i in OPEN_POINT_SEARCH_DIRECTIONS:
			var angle: float = TAU * float(i) / float(OPEN_POINT_SEARCH_DIRECTIONS)
			var candidate: Vector2 = position + Vector2(cos(angle), sin(angle)) * radius
			if not _point_is_inside_world(space_state, candidate):
				return candidate
	push_warning("PickupSystem: could not find an open point near %s; placing the drop inside terrain" % position)
	return position


func _point_is_inside_world(space_state: PhysicsDirectSpaceState2D, position: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = position
	query.collision_mask = CollisionLayers.LAYER_WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var results: Array[Dictionary] = space_state.intersect_point(query, 1)
	return not results.is_empty()

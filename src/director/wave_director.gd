extends Node
class_name WaveDirector

## WaveDirector (P2.8, brought forward from its plan position by the
## author's "where is the wave" verdict on the P2.7 feel-check fixture --
## phases/PHASE_03_Core_Entities_And_Feel_Check/EXECUTION_LOG.md, P2.7 row).
## docs/11_Wave_Director.md > "Wave Runtime Model", "Encounter Budgets for
## the Prototype", "Spawn Rings & Placement", "Directional Weighting" in
## full; MASTER_SDLC.md > Provisional Values Register > Spawning & Waves,
## Encounter Budgets. Sequences the prototype's eight in-scope waves
## (T1-T4, combat waves 1-4; no boss waves) and spawns their authored spawn
## groups on the two Spawn Rings, off-screen, on schedule.
##
## ## Scope, named per this task's own binding brief
## Deliberately NOT built here (see phases/PHASE_03_.../evidence/
## p28_report.md, "Deferred"): the Pressure Metric and escalation/
## de-escalation, Overtime and the stall check, encounter priorities and
## deferral between simultaneously-due encounters (moot in this scope --
## the prototype's eight waves each carry exactly one encounter, so two
## encounters are never due at once), pickups and drops, boss waves, and
## the Siege volume FORMULA (the prototype's Siege spawn counts are
## authored numbers per the Register's own instruction -- "transcribe them
## into .tres resources, do not compute them" -- not computed from Tower
## DPS at runtime). Off-screen spawn MARKERS (the 0.75s visual telegraph
## before a spawn) are also not built -- a visual/UI feature distinct from
## "enemies arrive ... from off-screen", which ring placement plus camera
## exclusion already guarantees structurally.
##
## Every non-final wave that reaches its maximum duration without its
## encounter completing always takes the Register's NOT-STALLED branch
## (living enemies carry over, uncounted against the next wave's budget):
## since Overtime/the stall check are out of scope, this is not a
## simplification of behaviour so much as the one branch this task
## actually implements of a rule with two branches.
##
## ## SimLoop wiring (task instruction, matching src/player/player.gd's,
## src/enemy/enemy_controller.gd's and others' own precedent exactly)
## `physics_step(delta)` is public; `driven_externally` (default false) lets
## a future SimLoop integration (src/core/sim_loop.gd step 13, currently an
## empty stub -- "P2.8 Wave Director") take over without this node ever
## double-stepping in the same tick. src/core/sim_loop.gd is NOT modified by
## this task (out of write scope; a separate architectural task per
## LEDGER F03-09/F03-22).
##
## ## Integration seams -- expose, do not wire (task instruction)
## `tower_seeker_scene`/`player_hunter_scene`/`opportunist_scene` are
## exported `PackedScene` properties, left null by default: the orchestrator
## supplies them. Nothing here hardcodes a `res://scenes/entities/...` path.
## `entity_spawner_path`/`tower_path`/`camera_path` are NodePaths resolved
## once against this node's siblings, matching `tower_weapon.gd`'s
## `origin_path` and `enemy_controller.gd`'s `tower_path` seams; a Tower or
## camera left unwired falls back to Register-cited constants (Tower at the
## world origin, a 1920x1080 reference view), named at each fallback site.
##
## ## Completion counting (Register > Spawning & Waves > "Completion
## counting": "Via EntityRegistry tag queries, never counters")
## A non-final wave's encounter completes when every enemy IT spawned
## (tracked as a plain Array[Node2D] of the instances this director itself
## handed out this wave -- not a count that could drift, a fixed list of
## real references) no longer appears in `EntityRegistry.
## get_entities_with_tag(TowerWeapon.ENEMY_TAG)` (the LIVE set; the registry
## excludes anything Logical Death has already flagged not-alive). This
## reads "every enemy the encounter spawned is dead or removed" (Register >
## "Encounter completion") literally: a previous wave's carried-over
## survivors are, by construction, absent from THIS wave's own spawned
## list, so they cannot block it from completing. The final wave (C-FINAL)
## does not use this per-wave list at all -- it reads
## `EntityRegistry.get_live_enemy_count()` directly, matching "ends only
## when the EntityRegistry live-enemy count is zero" (global, not scoped to
## its own spawns, per "adopts every living enemy when it opens").

signal wave_opened(wave_id: String, wave_index: int)
signal wave_ended(wave_id: String, wave_index: int)
signal sequence_completed()
signal enemy_spawned(instance: Node2D, enemy_definition_id: String, position: Vector2)

enum State { IDLE, WAVE_ACTIVE, GAP, SEQUENCE_COMPLETE }

## Register > Ring validation: "after 8 consecutive failed ticks, ignore
## direction weighting and take the nearest valid point on the ring
## instead."
const CONSECUTIVE_FAIL_ESCALATION_TICKS: int = 8

## Register > Directional weighting > "Hunt": "When the camera centre is
## within 240 px of the Tower, the arc instead centres on the player's last
## movement direction."
const HUNT_CAMERA_TOWER_PROXIMITY_PX: float = 240.0

## Register > Arena & Camera > "Arena size": "4800 x 3200 px ... Tower at
## centre." Register > Spawn Rings: "clipped to the arena inset by 32
## pixels."
const ARENA_SIZE: Vector2 = Vector2(4800.0, 3200.0)
const ARENA_INSET_PX: float = 32.0

## Register > Arena & Camera > "View scale": "1.0 = 1920x1080 world px."
## Used only as a last-resort camera-view size when no camera is wired
## (`camera_path` unset and `set_camera_reference()` never called) -- named
## at the call site, see `_view_half_size()`.
const FALLBACK_VIEW_SIZE: Vector2 = Vector2(1920.0, 1080.0)

## Register > Tower > "Tower footprint / Interaction Radius": "160 px."
## Last-resort literal, used only if even `tower_definition_for_interaction_
## radius_fallback` fails to resolve -- see `_tower_interaction_radius_px()`.
const FALLBACK_TOWER_INTERACTION_RADIUS_PX: float = 160.0


@export var driven_externally: bool = false

## Keyed RNG root (Register > "Keyed RNG": "spawn position = hash([run_seed,
## "spawn", spawn_serial])"). A run assigns one seed; this project's
## KeyedRng.rng_for() derives every roll from it deterministically.
@export var run_seed: int = 0

@export var entity_spawner_path: NodePath
@export var tower_path: NodePath
@export var camera_path: NodePath

## "Tower at centre" (Register > Arena & Camera). Matches
## src/camera/game_camera.gd's own `arena_center` export and its verified
## value (Phase 03 EXECUTION_LOG: scenes/tower.tscn's root carries no
## position override, so the Tower sits at the world origin).
@export var arena_center: Vector2 = Vector2.ZERO

@export var director_configuration: DirectorConfiguration = preload("res://data/encounters/director_configuration.tres")

## The prototype's eight in-scope waves, in sequence order (T1, T2, T3, T4,
## combat 1-4). Orchestrator-overridable per this task's "expose, do not
## wire" instruction, but ships pre-populated with the authored prototype
## sequence so the director is playable with no further wiring.
@export var waves: Array[WaveDefinition] = [
	preload("res://data/waves/t1.tres"),
	preload("res://data/waves/t2.tres"),
	preload("res://data/waves/t3.tres"),
	preload("res://data/waves/t4.tres"),
	preload("res://data/waves/combat_1.tres"),
	preload("res://data/waves/combat_2.tres"),
	preload("res://data/waves/combat_3.tres"),
	preload("res://data/waves/combat_4.tres"),
]

@export var encounter_definitions: Array[EncounterDefinition] = [
	preload("res://data/encounters/t1_standard_assault.tres"),
	preload("res://data/encounters/t2_standard_assault.tres"),
	preload("res://data/encounters/t3_split_assault.tres"),
	preload("res://data/encounters/t4_siege.tres"),
	preload("res://data/encounters/combat_1_hunt.tres"),
	preload("res://data/encounters/combat_2_siege.tres"),
	preload("res://data/encounters/combat_3_split_assault.tres"),
	preload("res://data/encounters/combat_4_siege.tres"),
]

## Orchestrator-supplied (task instruction: "do not hardcode paths"). Left
## null by default; a WaveDirector with no scenes wired is still fully
## testable (spawn attempts simply fail loudly via push_error, never
## silently) but spawns nothing in a real scene.
@export var tower_seeker_scene: PackedScene
@export var player_hunter_scene: PackedScene
@export var opportunist_scene: PackedScene

## The three prototype enemies' own authored data, read for
## `target_intent` (ring routing) and `unique_id` (the enemy_lookup key a
## SpawnGroup's `enemy_definition_id` resolves against). Preloaded from the
## same resources P2.5's enemy scenes already reference, matching
## enemy_controller.gd's own precedent (`seeker_definition_for_conversion`,
## `player_definition_for_speed_reference`) of preloading a reference
## resource rather than retyping its values.
@export var tower_seeker_definition: EnemyDefinition = preload("res://data/enemies/tower_seeker.tres")
@export var player_hunter_definition: EnemyDefinition = preload("res://data/enemies/player_hunter.tres")
@export var opportunist_definition: EnemyDefinition = preload("res://data/enemies/opportunist.tres")

## Fallback source for the Tower's Interaction Radius when no live Tower is
## wired (`tower_path` unset and `set_tower_reference()` never called) --
## see `_tower_interaction_radius_px()`.
@export var tower_definition_for_interaction_radius_fallback: TowerDefinition = preload("res://data/tower/base.tres")


var _registry: Node = null
var _clock: Node = null
var _entity_spawner: Node = null
var _tower: Node2D = null
var _camera: Node2D = null

var _state: State = State.IDLE
var _current_wave_index: int = -1
var _wave_open_time: float = 0.0
var _gap_deadline: float = 0.0

var _group_emitted_counts: Dictionary = {} # group_index (int) -> emitted count (int)
var _group_fail_counts: Dictionary = {} # "group_index:spawn_index" -> consecutive failed ticks (int)
var _current_wave_spawned: Array[Node2D] = []

var _encounter_lookup: Dictionary = {} # unique_id (String) -> EncounterDefinition
var _enemy_lookup: Dictionary = {} # unique_id (String) -> {"definition": EnemyDefinition, "scene": PackedScene}
var _serial_base: Dictionary = {} # "wave_index:group_index" -> int (deterministic spawn_serial base)

var _configured: bool = false
var _warned_not_configured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if _registry == null:
		_registry = EntityRegistry
	if _clock == null:
		_clock = SimClock
	_resolve_entity_spawner()
	_build_encounter_lookup()
	_build_enemy_lookup()
	_build_serial_bases()
	_configured = _entity_spawner != null and not waves.is_empty() and not _encounter_lookup.is_empty()
	# Deliberately no push_error here: `entity_spawner_path` resolves above
	# for a real scene, but the test seam (`set_entity_spawner_for_test()`,
	# matching this project's own set_*_for_test convention) is always
	# called AFTER `_ready()` runs via `add_child()` -- exactly like every
	# other component's test seams in this codebase -- so "not configured
	# yet, right after _ready()" is an expected transient state, not a
	# defect. `physics_step()` warns once, lazily, only if it is actually
	# asked to do work while still unconfigured (see below), which is the
	# real misconfiguration signal.


func _resolve_entity_spawner() -> void:
	if _entity_spawner != null:
		return
	if entity_spawner_path != NodePath():
		var n: Node = get_node_or_null(entity_spawner_path)
		if n != null:
			_entity_spawner = n


func _build_encounter_lookup() -> void:
	_encounter_lookup.clear()
	for e in encounter_definitions:
		if e is EncounterDefinition and (e as EncounterDefinition).unique_id != "":
			_encounter_lookup[(e as EncounterDefinition).unique_id] = e


func _build_enemy_lookup() -> void:
	_enemy_lookup.clear()
	if tower_seeker_definition != null:
		_enemy_lookup[tower_seeker_definition.unique_id] = {"definition": tower_seeker_definition, "scene": tower_seeker_scene}
	if player_hunter_definition != null:
		_enemy_lookup[player_hunter_definition.unique_id] = {"definition": player_hunter_definition, "scene": player_hunter_scene}
	if opportunist_definition != null:
		_enemy_lookup[opportunist_definition.unique_id] = {"definition": opportunist_definition, "scene": opportunist_scene}


## Deterministic, structure-derived spawn_serial bases (see header,
## "Completion counting" and the Keyed RNG citation above): a function of
## wave order and each encounter's own authored spawn_groups order, fixed at
## `_ready()`, never of runtime pacing or retry timing. Two runs with the
## same `run_seed` therefore assign identical serials to identical logical
## spawns regardless of incidental frame timing (Determinism test, and this
## task's own "same seed -> same spawn positions" acceptance check).
func _build_serial_bases() -> void:
	_serial_base.clear()
	var running: int = 0
	for wave_index in waves.size():
		var wave: WaveDefinition = waves[wave_index]
		if wave == null or wave.encounter_sequence.is_empty():
			continue
		var encounter: EncounterDefinition = _encounter_lookup.get(wave.encounter_sequence[0])
		if encounter == null:
			continue
		for group_index in encounter.spawn_groups.size():
			var group: SpawnGroup = encounter.spawn_groups[group_index]
			_serial_base["%d:%d" % [wave_index, group_index]] = running
			running += group.count


func _spawn_serial_for(group_index: int, spawn_index: int) -> int:
	var key: String = "%d:%d" % [_current_wave_index, group_index]
	return int(_serial_base.get(key, 0)) + spawn_index


# --- Test-only seams (never called by gameplay code) ------------------------

func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_entity_spawner_for_test(spawner: Node) -> void:
	_entity_spawner = spawner
	_configured = _entity_spawner != null and not waves.is_empty() and not _encounter_lookup.is_empty()


func rebuild_lookups_for_test() -> void:
	_build_encounter_lookup()
	_build_enemy_lookup()
	_build_serial_bases()
	_configured = _entity_spawner != null and not waves.is_empty() and not _encounter_lookup.is_empty()


func get_state_name() -> String:
	return State.keys()[_state]


func get_current_wave_id() -> String:
	if _current_wave_index < 0 or _current_wave_index >= waves.size():
		return ""
	return waves[_current_wave_index].unique_id


func get_current_wave_index_for_test() -> int:
	return _current_wave_index


func get_wave_open_time_for_test() -> float:
	return _wave_open_time


func get_gap_deadline_for_test() -> float:
	return _gap_deadline


func get_spawned_count_for_test() -> int:
	return _current_wave_spawned.size()


func get_emitted_count_for_test(group_index: int) -> int:
	return int(_group_emitted_counts.get(group_index, 0))


## Typed command, real seam (not test-only): a live Tower this director
## reads position and Interaction Radius from. See header, "Integration
## seams."
func set_tower_reference(tower: Node2D) -> void:
	_tower = tower


## Typed command, real seam: a live GameCamera (or anything exposing
## `global_position` and `get_visible_world_size()`) this director reads the
## current view rectangle from.
func set_camera_reference(camera: Node2D) -> void:
	_camera = camera


func _resolve_tower() -> Node2D:
	if _tower != null and is_instance_valid(_tower):
		return _tower
	if tower_path != NodePath():
		var n: Node = get_node_or_null(tower_path)
		if n is Node2D:
			_tower = n as Node2D
	return _tower


func _resolve_camera() -> Node2D:
	if _camera != null and is_instance_valid(_camera):
		return _camera
	if camera_path != NodePath():
		var n: Node = get_node_or_null(camera_path)
		if n is Node2D:
			_camera = n as Node2D
	return _camera


func _resolve_player() -> Node2D:
	if _registry == null:
		return null
	var players: Array[Node2D] = _registry.get_entities_with_tag(&"player")
	return players[0] if not players.is_empty() else null


func _now() -> float:
	return _clock.now if _clock != null else 0.0


# --- Physics step (SimLoop step 13 seam) ------------------------------------

func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


func physics_step(delta: float) -> void:
	if not _configured:
		if not _warned_not_configured:
			_warned_not_configured = true
			push_error("WaveDirector: physics_step() called while not configured -- entity_spawner=%s waves=%d encounters=%d. Wire entity_spawner_path (or call set_entity_spawner_for_test()) before driving this node." % [_entity_spawner, waves.size(), _encounter_lookup.size()])
		return
	if _state == State.IDLE:
		_open_wave(0)
	match _state:
		State.WAVE_ACTIVE:
			_process_wave_active(delta)
		State.GAP:
			_process_gap()
		State.SEQUENCE_COMPLETE:
			pass


func _open_wave(index: int) -> void:
	_current_wave_index = index
	_wave_open_time = _now()
	_group_emitted_counts.clear()
	_group_fail_counts.clear()
	_current_wave_spawned.clear()
	_state = State.WAVE_ACTIVE
	wave_opened.emit(waves[index].unique_id, index)


func _current_encounter() -> EncounterDefinition:
	if _current_wave_index < 0 or _current_wave_index >= waves.size():
		return null
	var wave: WaveDefinition = waves[_current_wave_index]
	if wave.encounter_sequence.is_empty():
		return null
	return _encounter_lookup.get(wave.encounter_sequence[0])


func _process_wave_active(_delta: float) -> void:
	var wave: WaveDefinition = waves[_current_wave_index]
	var encounter: EncounterDefinition = _current_encounter()
	if encounter == null:
		push_error("WaveDirector: wave '%s' names an encounter sequence that does not resolve to any wired EncounterDefinition" % wave.unique_id)
		return
	_process_spawn_groups(encounter)
	if _is_wave_ended(wave, encounter):
		_end_current_wave(wave, encounter)


func _process_spawn_groups(encounter: EncounterDefinition) -> void:
	var now: float = _now()
	for group_index in encounter.spawn_groups.size():
		var group: SpawnGroup = encounter.spawn_groups[group_index]
		var emitted: int = int(_group_emitted_counts.get(group_index, 0))
		while emitted < group.count:
			var due_time: float = _wave_open_time + group.start_offset_seconds + float(emitted) * group.spawn_interval_seconds
			if now < due_time:
				break
			if not _attempt_spawn(encounter, group, group_index, emitted):
				break # throttled or invalid this tick -- retries next tick WITHOUT consuming budget (Register: both throttle and "no valid candidate" share this rule)
			emitted += 1
			_group_emitted_counts[group_index] = emitted


func _attempt_spawn(encounter: EncounterDefinition, group: SpawnGroup, group_index: int, spawn_index: int) -> bool:
	var enemy_info: Dictionary = _enemy_lookup.get(group.enemy_definition_id, {})
	var definition: EnemyDefinition = enemy_info.get("definition")
	var scene: PackedScene = enemy_info.get("scene")
	if definition == null:
		push_error("WaveDirector: spawn group references unknown enemy id '%s'" % group.enemy_definition_id)
		return false
	if scene == null:
		push_error("WaveDirector: no PackedScene wired for enemy id '%s' -- the orchestrator must assign tower_seeker_scene/player_hunter_scene/opportunist_scene" % group.enemy_definition_id)
		return false

	var slot_key: String = "%d:%d" % [group_index, spawn_index]
	var serial: int = _spawn_serial_for(group_index, spawn_index)
	var placement: Dictionary = _resolve_spawn_placement(encounter, definition, serial, group_index, spawn_index, group.count)

	if not placement.get("valid", false):
		var fails: int = int(_group_fail_counts.get(slot_key, 0)) + 1
		_group_fail_counts[slot_key] = fails
		if fails >= CONSECUTIVE_FAIL_ESCALATION_TICKS:
			var escalated: Dictionary = _escalated_placement(definition, serial)
			if escalated.get("valid", false):
				placement = escalated
		if not placement.get("valid", false):
			return false

	_group_fail_counts.erase(slot_key)

	var spawn_position: Vector2 = placement["position"]
	var instance: Node2D = _entity_spawner.spawn_enemy(spawn_position, func() -> Node2D: return scene.instantiate())
	if instance == null:
		return false # cap throttle (EntitySpawner/Pool) -- a DIFFERENT mechanism from the validation-fail-count above; never touches it
	instance.global_position = spawn_position
	if _registry != null:
		_registry.update_position(instance, spawn_position)
	_current_wave_spawned.append(instance)
	enemy_spawned.emit(instance, group.enemy_definition_id, spawn_position)
	return true


# --- Ring selection and directional weighting --------------------------------

func _ring_for_intent(target_intent: ContractEnums.TargetIntent) -> Dictionary:
	if target_intent == ContractEnums.TargetIntent.TowerSeeker:
		return {"ring": director_configuration.spawn_ring_geometry.tower_ring, "center": _tower_center(), "ring_type": ContractEnums.RingType.Tower}
	return {"ring": director_configuration.spawn_ring_geometry.view_ring, "center": _view_center(), "ring_type": ContractEnums.RingType.View}


func _other_ring(ring_type: ContractEnums.RingType) -> Dictionary:
	if ring_type == ContractEnums.RingType.Tower:
		return {"ring": director_configuration.spawn_ring_geometry.view_ring, "center": _view_center()}
	return {"ring": director_configuration.spawn_ring_geometry.tower_ring, "center": _tower_center()}


func _weighting_for_type(encounter_type: ContractEnums.EncounterType) -> DirectionalWeightingEntry:
	if director_configuration == null:
		return null
	for entry in director_configuration.directional_weighting_rules:
		if (entry as DirectionalWeightingEntry).encounter_type == encounter_type:
			return entry
	return null


## Register > Directional weighting. "Uniform" (Standard Assault, Siege) is
## a plain full-circle draw. Split Assault fixes a deterministic lane
## (SpawnGeometry.split_assault_lane_sequence, by spawn index -- not
## randomised) and rolls only the angle WITHIN that lane's sector. Hunt
## rolls whether this spawn lands in the biased arc at all, then the angle
## within it (or a full-circle fallback).
##
## Interpretation, named rather than silently assumed: the Register fixes
## Split Assault's lane SEPARATION ("prototype lane centres are 180 deg
## apart") but not their absolute world bearing. This project fixes the
## heavy lane at bearing 0 (east, +X) and the light lane at 180 deg (west)
## for every Split Assault encounter -- simple, deterministic, and
## sufficient to satisfy "180 deg apart" and "fixed when the encounter
## opens", though the Register does not itself forbid rolling the
## orientation per encounter.
func _base_angle_for(encounter: EncounterDefinition, rng: RandomNumberGenerator, spawn_index: int, group_count: int) -> float:
	var weighting: DirectionalWeightingEntry = encounter.directional_weighting_override if encounter.directional_weighting_override != null else _weighting_for_type(encounter.encounter_type)
	match encounter.encounter_type:
		ContractEnums.EncounterType.SplitAssault:
			var heavy_share: float = weighting.heavy_share if weighting != null and weighting.heavy_share > 0.0 else 0.6
			var lane_width_deg: float = weighting.lane_width_degrees if weighting != null and weighting.lane_width_degrees > 0.0 else 40.0
			var sequence: Array[bool] = SpawnGeometry.split_assault_lane_sequence(group_count, heavy_share)
			var is_heavy: bool = sequence[spawn_index] if spawn_index < sequence.size() else true
			var lane_center: float = 0.0 if is_heavy else PI # see interpretation note above
			var half_width: float = deg_to_rad(lane_width_deg) * 0.5
			return lane_center + rng.randf_range(-half_width, half_width)
		ContractEnums.EncounterType.Hunt:
			var arc_share: float = weighting.hunt_arc_share if weighting != null and weighting.hunt_arc_share > 0.0 else 0.8
			var arc_degrees: float = weighting.hunt_arc_degrees if weighting != null and weighting.hunt_arc_degrees > 0.0 else 120.0
			var in_arc: bool = rng.randf() < arc_share
			if in_arc:
				var arc_center: float = _hunt_arc_center(rng)
				var half_arc: float = deg_to_rad(arc_degrees) * 0.5
				return arc_center + rng.randf_range(-half_arc, half_arc)
			return rng.randf() * TAU
		_: # StandardAssault, Siege: uniform across the ring
			return rng.randf() * TAU


## Register > Directional weighting > "Hunt": bearing from the Tower to the
## camera centre; if the camera centre is within 240 px of the Tower,
## centre on the player's last movement direction instead; with no such
## direction, a keyed RNG roll picks the centre.
func _hunt_arc_center(rng: RandomNumberGenerator) -> float:
	var tower_c: Vector2 = _tower_center()
	var camera_c: Vector2 = _view_center()
	if tower_c.distance_to(camera_c) > HUNT_CAMERA_TOWER_PROXIMITY_PX:
		return (camera_c - tower_c).angle()
	var player: Node2D = _resolve_player()
	if player is CharacterBody2D and (player as CharacterBody2D).velocity.length() > 0.01:
		return (player as CharacterBody2D).velocity.angle()
	return rng.randf() * TAU


func _resolve_spawn_placement(encounter: EncounterDefinition, definition: EnemyDefinition, serial: int, _group_index: int, spawn_index: int, group_count: int) -> Dictionary:
	var ring_info: Dictionary = _ring_for_intent(definition.target_intent)
	var rng: RandomNumberGenerator = KeyedRng.rng_for([run_seed, "spawn", serial]) # Register > "Keyed RNG"
	var angle: float = _base_angle_for(encounter, rng, spawn_index, group_count)
	var radius_fraction: float = rng.randf()
	return SpawnGeometry.validate_and_shift(
		angle, radius_fraction,
		ring_info["ring"], ring_info["center"],
		_tower_center(), _tower_interaction_radius_px(),
		_view_center(), _view_half_size(), float(director_configuration.camera_exclusion_margin_px),
		arena_center, ARENA_SIZE / 2.0, ARENA_INSET_PX,
		director_configuration.spawn_validation_retry.steps, director_configuration.spawn_validation_retry.angle_degrees
	)


## Register > Ring validation, the 8-consecutive-failed-tick escalation.
func _escalated_placement(definition: EnemyDefinition, serial: int) -> Dictionary:
	var rng: RandomNumberGenerator = KeyedRng.rng_for([run_seed, "spawn", serial])
	var preferred_angle: float = rng.randf() * TAU
	var primary: Dictionary = _ring_for_intent(definition.target_intent)
	var point: Variant = SpawnGeometry.nearest_valid_point_on_ring(
		preferred_angle, primary["ring"], primary["center"],
		_tower_center(), _tower_interaction_radius_px(),
		_view_center(), _view_half_size(), float(director_configuration.camera_exclusion_margin_px),
		arena_center, ARENA_SIZE / 2.0, ARENA_INSET_PX
	)
	if point == null:
		var other: Dictionary = _other_ring(primary["ring_type"])
		point = SpawnGeometry.nearest_valid_point_on_ring(
			preferred_angle, other["ring"], other["center"],
			_tower_center(), _tower_interaction_radius_px(),
			_view_center(), _view_half_size(), float(director_configuration.camera_exclusion_margin_px),
			arena_center, ARENA_SIZE / 2.0, ARENA_INSET_PX
		)
	if point == null:
		return {"valid": false}
	return {"valid": true, "position": point}


# --- World-state readers, with named Register-cited fallbacks ---------------

func _tower_center() -> Vector2:
	var tower: Node2D = _resolve_tower()
	if tower != null:
		return tower.global_position
	return arena_center # Register > Arena & Camera: "Tower at centre" -- see header


func _view_center() -> Vector2:
	var camera: Node2D = _resolve_camera()
	if camera != null:
		return camera.global_position
	return arena_center # no camera wired -- see header, "Integration seams"


func _view_half_size() -> Vector2:
	var camera: Node = _resolve_camera()
	if camera != null and camera.has_method("get_visible_world_size"):
		return (camera.call("get_visible_world_size") as Vector2) / 2.0
	return FALLBACK_VIEW_SIZE / 2.0 # Register > "View scale": 1.0 = 1920x1080 -- see FALLBACK_VIEW_SIZE


func _tower_interaction_radius_px() -> float:
	var tower: Node = _resolve_tower()
	if tower != null:
		var def: Variant = tower.get("definition")
		if def is TowerDefinition and (def as TowerDefinition).tower_footprint != null:
			return float((def as TowerDefinition).tower_footprint.interaction_radius_px)
	if tower_definition_for_interaction_radius_fallback != null and tower_definition_for_interaction_radius_fallback.tower_footprint != null:
		return float(tower_definition_for_interaction_radius_fallback.tower_footprint.interaction_radius_px)
	return FALLBACK_TOWER_INTERACTION_RADIUS_PX


# --- Wave ending and sequencing ----------------------------------------------

func _all_groups_emitted(encounter: EncounterDefinition) -> bool:
	for group_index in encounter.spawn_groups.size():
		var group: SpawnGroup = encounter.spawn_groups[group_index]
		if int(_group_emitted_counts.get(group_index, 0)) < group.count:
			return false
	return true


## Register > "Encounter completion": "every enemy the encounter spawned is
## dead or removed" -- see header, "Completion counting".
func _all_own_spawned_dead_or_removed() -> bool:
	if _current_wave_spawned.is_empty():
		return true
	if _registry == null:
		return true
	var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	for instance in _current_wave_spawned:
		if is_instance_valid(instance) and live.has(instance):
			return false
	return true


func _is_wave_ended(wave: WaveDefinition, encounter: EncounterDefinition) -> bool:
	var is_final: bool = _current_wave_index == waves.size() - 1
	if is_final:
		# C-FINAL: "adopts every living enemy when it opens ... ends only
		# when the EntityRegistry live-enemy count is zero" -- global, not
		# scoped to this wave's own spawns; gated on full emission too, so
		# it cannot be declared ended before it has even finished spawning.
		return _all_groups_emitted(encounter) and _registry != null and _registry.get_live_enemy_count() == 0
	if _all_groups_emitted(encounter) and _all_own_spawned_dead_or_removed():
		return true
	if _now() >= _wave_open_time + wave.maximum_duration_seconds:
		return true # NOT-STALLED branch always taken -- Overtime/the stall check are out of scope (see header)
	return false


func _end_current_wave(wave: WaveDefinition, encounter: EncounterDefinition) -> void:
	wave_ended.emit(wave.unique_id, _current_wave_index)
	# The inter-wave gap exists to delay the NEXT wave's opening (Register:
	# "No spawn group starts during a gap"); the final wave in this task's
	# scope has no next wave to delay, so it goes straight to
	# SEQUENCE_COMPLETE rather than sitting in a GAP state waiting for a
	# deadline nothing is scheduled against.
	if _current_wave_index >= waves.size() - 1:
		_state = State.SEQUENCE_COMPLETE
		sequence_completed.emit()
		return
	var gap: float = maxf(wave.inter_wave_gap_seconds, encounter.minimum_recovery_gap_seconds) # Register > "Inter-wave gap": max(default, last encounter's recovery gap)
	_gap_deadline = _now() + gap
	_state = State.GAP


func _process_gap() -> void:
	if _now() < _gap_deadline:
		return
	_open_wave(_current_wave_index + 1)

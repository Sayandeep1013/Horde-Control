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
## P2.8 (phases/PHASE_03_.../evidence/p28_report.md, "Deferred") named eight
## items it deliberately left out. This task (P2.8b,
## phases/PHASE_04_.../evidence/p28b_report.md) builds four of them:
## 1. The real two-branch Wave end / STALLED rule (the kill-rate check at
##    maximum duration) plus Overtime and its finisher spawning -- see
##    `_maybe_enter_overtime()`, `_stall_check_triggers_overtime()`,
##    `_process_finisher_spawns()`, `_attempt_finisher_spawn()`.
## 2. Encounter priorities and deferral between simultaneously-due
##    encounters -- see `_build_priority_sorted_encounter_queue()` and
##    `_wave_encounter_queue`/`_wave_encounter_position`. Moot for the real
##    8-wave prototype (every wave still carries exactly one encounter, so
##    this sorts a 1-element array and the between-encounters recovery gap
##    this priority ordering can trigger is never reached by real data --
##    see "Regression" below); exercised by this task's own scripted
##    double-schedule tests instead.
## 3. The encounter-level alive cap (`EncounterDefinition.encounter_alive_
##    cap`) -- see `_encounter_cap_blocks_spawn()`, applied to both ordinary
##    spawn-group attempts and finisher attempts.
## 4. The Siege volume formula, COMPUTED against live Tower DPS once it is
##    ABOVE the base 25 DPS reference (i.e. once Caliber ranks are bought) --
##    see `_maybe_scale_siege_spawn_groups()`. At exactly base DPS (no
##    upgrade system wired, which is this build's own current state -- the
##    orchestrator wires `set_tower_capacity_provider()` separately) this is
##    a documented no-op and the authored `.tres` literal (43/57 Seekers)
##    is used unchanged.
## Still NOT built: pickups/drops (P2.10's own task), boss waves, and
## off-screen spawn MARKERS -- docs/11 > "Spawn Rings & Placement" specifies
## a visual telegraph ("a spawn marker appears 0.75 seconds before its
## spawn") but never what that marker RENDERS (shape, colour, node type);
## per this task's own brief ("ONLY if docs/11 actually specifies what a
## marker renders and where. If it does not specify, leave it unbuilt"),
## this remains unbuilt -- see the evidence report.
##
## ## Regression (task instruction: "do not re-time the existing eight-wave
## sequence")
## With no stall (every real wave's kill rate is designed to clear its own
## encounter before maximum duration in ordinary play), no Overtime, a
## 1-element encounter queue per wave, and Tower DPS never reported above
## the base 25 DPS reference (nothing in this build's current wiring reports
## higher), every new branch added by this task resolves to exactly the
## behaviour P2.8 shipped: `_evaluate_wave_state()`'s NOT-STALLED branch
## returns the same `true` `_is_wave_ended()` used to return, priority
## sorting a 1-element array is the identity, and `_maybe_scale_siege_spawn_
## groups()` never populates `_group_count_override`. The existing P2.8/P2.9
## suites are the regression guard for this claim, not a re-derivation here.
##
## The Pressure Metric and escalation/bounded de-escalation (P2.9, docs/11 >
## "Pacing & Escalation Algorithm") ARE built here, added on top of the
## above -- see `_process_pressure_metric()` and src/director/
## pressure_metric.gd (a pure RefCounted this file is the only real caller
## of; every Register-cited constant and formula lives there or on
## data/encounters/director_configuration.tres's `pressure_metric_*`
## fields, never restated as a literal in this file). Overtime is still not
## implemented, so `is_overtime` is always passed false to PressureMetric
## from this file (see `_process_pressure_metric()`'s own comment) --
## PressureMetric's own test suite exercises `is_overtime = true` directly.
## Quadrant-aware spawn SELECTION remains out of scope (task brief, docs/11
## open question, answered telemetry-only for this task -- see the P2.9
## evidence report): the health quadrant is computed and pushed to the
## debug overlay, never read back to change what spawns.
##
## A non-final wave that reaches its maximum duration without its encounter
## completing now runs the REAL two-branch rule (`_maybe_enter_overtime()`,
## `_stall_check_triggers_overtime()`): kills in the last 30 s (excluding
## finishers) below the stall threshold starts Overtime; otherwise the
## NOT-STALLED branch still applies exactly as P2.8 built it (living
## enemies carry over, uncounted against the next wave's budget).
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
## An encounter completes when every enemy IT spawned (tracked as a plain
## Array[Node2D] of the instances this director itself handed out for the
## CURRENTLY OPEN encounter -- not a count that could drift, a fixed list of
## real references, cleared at every encounter transition by
## `_start_encounter_tracking()`) no longer appears in `EntityRegistry.
## get_entities_with_tag(TowerWeapon.ENEMY_TAG)` (the LIVE set; the registry
## excludes anything Logical Death has already flagged not-alive). This
## reads "every enemy the encounter spawned is dead or removed" (Register >
## "Encounter completion") literally: a previous encounter's (or a previous
## wave's) carried-over survivors are, by construction, absent from THE
## CURRENT encounter's own spawned list, so they cannot block it from
## completing. The final wave (C-FINAL) does not use this per-encounter list
## at all -- it reads `EntityRegistry.get_live_enemy_count()` directly,
## matching "ends only when the EntityRegistry live-enemy count is zero"
## (global, not scoped to its own spawns, per "adopts every living enemy
## when it opens").

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

## Register > "Wave end / STALLED (non-final combat waves)": "kills in the
## last 30 seconds, not counting finishers, are below the stall threshold."
const STALL_WINDOW_SECONDS: float = 30.0

## Register > "Final combat wave rule (C-FINAL)": "After its maximum
## duration the stall check re-runs every 0.5 seconds until Overtime
## starts." A DIFFERENT Register row from Pressure & Overtime's own "every
## 0.5 s" cadence (Pressure Calculation) -- both happen to be 0.5 s today,
## but they cite different rules, so this is its OWN named constant rather
## than reusing `PressureMetric.EVAL_INTERVAL_SECONDS`.
const FINAL_WAVE_STALL_RECHECK_INTERVAL_SECONDS: float = 0.5

## Register > "Keyed RNG": "spawn position = hash([run_seed, "spawn",
## spawn_serial])." Overtime finishers are not part of any authored spawn
## group, so `_build_serial_bases()` (which derives every ordinary spawn's
## serial from wave/encounter/group structure) never assigns them one; this
## is a disjoint serial range, offset well past any real spawn-group total
## the prototype's 8-wave sequence could ever reach (its largest single
## wave, combat_4_siege, sums to 66 spawns) so a finisher's keyed RNG draw
## never collides with an ordinary spawn's.
const FINISHER_SERIAL_BASE: int = 10_000_000

## Per-wave serial spacing within FINISHER_SERIAL_BASE (see
## `_finisher_spawn_serial()`), generous enough that no single wave's
## Overtime could ever spawn this many finishers.
const FINISHER_SERIAL_PER_WAVE: int = 1000


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

## P2.9. Register/Wave Runtime Model structural fact (D91 carve-out: the
## master itself names these four specific waves as "teaching", not a
## tunable count -- "A run's first biome opens with teaching waves T1-T4
## before combat wave 1"), not a per-field schema flag: src/data/
## wave_definition.gd has no "is teaching" field, and this task's write
## scope does not include src/data/** to add one -- named as a required
## schema seam in the P2.9 evidence report. Orchestrator/test-overridable
## like every other export here; the four real prototype teaching wave IDs
## are the default so gameplay needs no wiring. Pressure is evaluated only
## for a wave whose unique_id is NOT in this list (Register > Pressure &
## Overtime > "Pressure formula": "only while a combat wave (not a teaching
## wave) is open").
@export var teaching_wave_unique_ids: Array[String] = ["wave_t1", "wave_t2", "wave_t3", "wave_t4"]

## P2.9 Capacity seam fallback (Register > Pressure & Overtime > "Capacity
## formula": "sheet DPS of the player and the Tower with their current
## upgrades"). Used only when neither `set_player_capacity_provider()` nor a
## live CombatStats("player") report exists yet -- see `_player_capacity_
## dps()`. data/weapons/handgun.tres is the same resource src/combat/
## auto_weapon.gd's own `definition` export preloads (10 dmg x 2 shots/s =
## 20 DPS, matching MASTER_SDLC.md > Player Overview).
@export var player_weapon_definition_fallback: WeaponDefinition = preload("res://data/weapons/handgun.tres")

## Same reasoning as player_weapon_definition_fallback, for the Tower side
## (20 dmg x 1.25 shots/s = 25 DPS, matching Register > "Tower base weapon"
## and > "Siege volume formula": "base Tower 25 DPS"). data/tower/
## base_weapon.tres is the same resource src/tower/tower.gd assigns to
## TowerWeapon.configure().
@export var tower_weapon_definition_fallback: WeaponDefinition = preload("res://data/tower/base_weapon.tres")

## P2.9. Orchestrator-supplied, matching tower_path/camera_path's own
## "resolved once against this node's siblings" convention. Left unset by
## default -- see `_resolve_debug_overlay()`; a WaveDirector with no overlay
## wired still computes and remembers Pressure (readable via the
## `get_..._for_test()` seams below) but displays nothing.
@export var debug_overlay_path: NodePath

## P2.8b (this task). Register > "Overtime finishers": "Player Hunters at
## 25% Hunter health, 160% Hunter speed ... the finisher flag survives any
## conversion." A distinct EnemyDefinition/unique_id from `player_hunter_
## definition` above (see data/encounters/player_hunter_finisher.tres's own
## header for why this is a separate Resource, not a mutation of the
## normal one). Spawned through the SAME `player_hunter_scene` PackedScene
## as an ordinary Hunter -- only the definition/is_finisher fields differ,
## set on the fresh instance before it is ever added to the scene tree (see
## `_attempt_finisher_spawn()`).
@export var player_hunter_finisher_definition: EnemyDefinition = preload("res://data/encounters/player_hunter_finisher.tres")

## P2.8b. Register > "Siege volume formula": exactly two multipliers, [1.5,
## 2.0] (also authored on `director_configuration.tres`'s own
## `siege_volume_constants.multiplier_defaults`), but the Encounter
## Definition Contract (src/data/encounter_definition.gd, out of this
## task's write scope) has no field recording WHICH multiplier a given
## Siege encounter is. This project-level mapping by Encounter Unique ID --
## the same key spawn groups already resolve enemies by -- is this task's
## own addition, orchestrator-overridable like every other export here; the
## prototype's own two combat Sieges are the default so nothing further
## needs wiring. A Siege encounter's unique_id absent from this table (T4,
## exempt from the formula per the Register; any encounter this task does
## not know about) is left at its authored literal spawn-group counts
## unconditionally -- see `_maybe_scale_siege_spawn_groups()`.
@export var siege_multiplier_by_encounter_id: Dictionary = {
	"combat_2_siege": 1.5,
	"combat_4_siege": 2.0,
}


var _registry: Node = null
var _clock: Node = null
var _entity_spawner: Node = null
var _tower: Node2D = null
var _camera: Node2D = null
var _combat_stats: Node = null # P2.9
var _debug_overlay: Node = null # P2.9

var _state: State = State.IDLE
var _current_wave_index: int = -1
var _wave_open_time: float = 0.0
## P2.8b. Distinct from `_wave_open_time`: SpawnGroup's own schema comment
## and the Register's "Spawn group" row both anchor `start_offset_seconds`
## to "from encounter open", not from wave open -- the two coincide exactly
## for the prototype's own single-encounter-per-wave waves (an encounter
## opens the instant its wave does), which is what keeps every real prototype
## wave's spawn timing byte-for-byte unchanged, but they can differ once a
## wave's priority queue (see `_wave_encounter_queue`) opens a SECOND
## encounter partway through the wave's own lifetime. Set by
## `_start_encounter_tracking()`, read by `_process_spawn_groups()` and
## `_process_pressure_metric()`'s Escalation Trigger override.
var _encounter_open_time: float = 0.0
var _gap_deadline: float = 0.0

var _group_emitted_counts: Dictionary = {} # group_index (int) -> emitted count (int)
var _group_fail_counts: Dictionary = {} # "group_index:spawn_index" -> consecutive failed ticks (int)
var _group_start_offset_override: Dictionary = {} # P2.9: group_index (int) -> effective start_offset_seconds (float), set by the Escalation Trigger
var _current_wave_spawned: Array[Node2D] = []

var _encounter_lookup: Dictionary = {} # unique_id (String) -> EncounterDefinition
var _enemy_lookup: Dictionary = {} # unique_id (String) -> {"definition": EnemyDefinition, "scene": PackedScene}
var _serial_base: Dictionary = {} # "wave_index:group_index" -> int (deterministic spawn_serial base)

var _configured: bool = false
var _warned_not_configured: bool = false

# --- P2.9 Pressure Metric state ---------------------------------------------
var _pressure_metric: PressureMetric = PressureMetric.new()
var _pressure_was_active_last_tick: bool = false # for reset_escalation_hold_timer() on resume -- see _process_pressure_metric()
var _next_pressure_eval_time: float = -INF # Register: "evaluated every 0.5 s" -- cadence gate
var _de_escalation_active_now: bool = false # mirrors _pressure_metric.is_de_escalation_active(), read by _process_spawn_groups() for the interval multiplier
var _grace_period_deadline: float = -INF # see notify_draft_closed()
var _player_capacity_provider: Callable = Callable() # see set_player_capacity_provider()
var _tower_capacity_provider: Callable = Callable() # see set_tower_capacity_provider()
var _last_pressure_for_test: float = 0.0
var _last_pressure_state_for_test: String = "Normal"
var _last_health_quadrant_for_test: String = "BothNormal"

# --- P2.8b: encounter priority queue (per wave) -----------------------------
var _wave_encounter_queue: Array[EncounterDefinition] = [] # this wave's due encounters, priority-sorted desc (ties by Unique ID asc) once, at wave open -- see _build_priority_sorted_encounter_queue()
var _wave_encounter_position: int = 0 # index into _wave_encounter_queue of the encounter currently open (or about to open, once _encounter_gap_deadline elapses)
var _encounter_gap_deadline: float = -INF # -INF = no between-encounters gap pending; see _process_wave_active()
var _group_count_override: Dictionary = {} # P2.8b Siege scaling: group_index (int) -> effective count (int), cleared at every encounter transition -- see _maybe_scale_siege_spawn_groups()

# --- P2.8b: stall check / Overtime / finishers ------------------------------
var _overtime_active: bool = false
var _kill_timestamps: Array[float] = [] # SimClock.now of every non-finisher EventBus.enemy_died, pruned to the last STALL_WINDOW_SECONDS on read -- see _kills_in_last_window()
var _next_stall_check_time: float = -INF # final wave only -- the 0.5s re-check cadence (C-FINAL)
var _next_finisher_spawn_time: float = -INF # -INF = no burst scheduled yet (see _process_finisher_spawns())
var _finisher_emitted_in_current_burst: int = 0
var _finisher_next_index: int = 0 # per-wave counter, feeds _finisher_spawn_serial() and _finisher_fail_counts' key -- mirrors _group_emitted_counts/_group_fail_counts' own indexing
var _finisher_fail_counts: Dictionary = {} # finisher index (int) -> consecutive failed validation ticks, mirrors _group_fail_counts
var _current_wave_finishers: Array[Node2D] = [] # finishers THIS wave has spawned and are still tracked as live -- see _despawn_remaining_finishers_without_drops()
var _event_bus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if _registry == null:
		_registry = EntityRegistry
	if _clock == null:
		_clock = SimClock
	if _combat_stats == null:
		_combat_stats = CombatStats
	if _event_bus == null:
		_event_bus = EventBus
	_connect_event_bus()
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
	# P2.8b: the Overtime finisher reuses player_hunter_scene (same
	# CharacterBody2D/EnemyController script -- only its stats differ) but
	# is looked up under its OWN unique_id, distinct from a normal Hunter's,
	# so wave_director.gd's own encounter-authored spawn groups (which
	# reference "player_hunter") can never accidentally resolve to it.
	if player_hunter_finisher_definition != null:
		_enemy_lookup[player_hunter_finisher_definition.unique_id] = {"definition": player_hunter_finisher_definition, "scene": player_hunter_scene}


## P2.8b test-injectable EventBus reference, matching this file's own
## set_registry_for_test()/set_combat_stats_for_test() convention -- and,
## for the connect call itself, src/pickup/pickup_system.gd's own
## `_connect_enemy_died()` (built by a concurrent task today against this
## SAME signal): the STRING-based `connect("enemy_died", callable)` /
## `is_connected("enemy_died", callable)` API, not the dot-property form
## (`bus.enemy_died.connect(...)`) -- the dot form only resolves against a
## signal declared statically in a script, and a test's fake bus (matching
## tests/unit/drop_table_test.gd's own `add_user_signal()` pattern) adds
## `enemy_died` dynamically at runtime, which dot-access cannot see (a real
## engine error confirmed while writing this task's own tests, not a
## theoretical concern). Real Autoload by default; a test hands a fresh
## double so the real singleton is never touched by this suite.
func _connect_event_bus() -> void:
	if _event_bus == null:
		return
	var callable: Callable = Callable(self, "_on_enemy_died")
	if _event_bus.has_signal("enemy_died") and not _event_bus.is_connected("enemy_died", callable):
		_event_bus.connect("enemy_died", callable)


func set_event_bus_for_test(bus: Node) -> void:
	_event_bus = bus
	_connect_event_bus()


## Register > "Wave end / STALLED": "kills in the last 30 seconds, not
## counting finishers." `entity` carries its own `is_finisher` flag (the
## SAME EnemyController field _attempt_finisher_spawn() sets) at the moment
## this fires -- EventBus.enemy_died is emitted synchronously from
## death_state.gd's own _enter_logical_death(), before the entity is ever
## freed (docs/20 > Logical Death: Visual Death, not immediate removal), so
## reading it here is safe and current.
func _on_enemy_died(entity: Variant, _position: Vector2, timestamp: float) -> void:
	var is_finisher: bool = false
	if entity is Object:
		var v: Variant = (entity as Object).get("is_finisher")
		is_finisher = v is bool and v
	if not is_finisher:
		_kill_timestamps.append(timestamp)


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


## P2.9. Matches set_registry_for_test()/set_sim_clock_for_test()'s own
## convention: a fresh CombatStats instance per test avoids one suite's
## report_sheet_dps() calls leaking into another's (combat_stats_test.gd's
## own header states the same reasoning for its fresh instance).
func set_combat_stats_for_test(stats: Node) -> void:
	_combat_stats = stats


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


## Integration task (P2.14's own evidence report named this exact gap:
## "WaveDirector exposes no non-test-suffixed 'current wave number' query
## ... A proper get_current_wave_display_index() ... is a required seam").
## 1-based for display ("Wave n/8"), matching `Hud._refresh_wave()`'s own
## `"%d/%d" % [wave_current, wave_total]` format; `-1` before the sequence
## has opened its first wave clamps to 0 rather than reading negative.
func get_current_wave_display_index() -> int:
	return maxi(0, _current_wave_index + 1)


## Integration task -- companion to the query above; drives
## HudEconomyState.wave_total, which nothing in this codebase populates
## today (confirmed by the same evidence report).
func get_wave_total_count() -> int:
	return waves.size()


func get_wave_open_time_for_test() -> float:
	return _wave_open_time


func get_gap_deadline_for_test() -> float:
	return _gap_deadline


func get_spawned_count_for_test() -> int:
	return _current_wave_spawned.size()


func get_emitted_count_for_test(group_index: int) -> int:
	return int(_group_emitted_counts.get(group_index, 0))


## P2.9: the value/state/quadrant most recently pushed to the debug overlay
## (task instruction: "make the values readable by a test without a running
## game" -- no DebugOverlay CanvasLayer/scene is required to read these).
func get_pressure_value_for_test() -> float:
	return _last_pressure_for_test


func get_pressure_state_for_test() -> String:
	return _last_pressure_state_for_test


func get_health_quadrant_for_test() -> String:
	return _last_health_quadrant_for_test


func is_de_escalation_active_for_test() -> bool:
	return _de_escalation_active_now


## -1.0 if this group index has never been pulled forward by the Escalation
## Trigger (i.e. it is still running on its authored start_offset_seconds).
func get_group_start_offset_override_for_test(group_index: int) -> float:
	return float(_group_start_offset_override.get(group_index, -1.0))


## Direct access to the underlying PressureMetric instance, for a test that
## wants to inspect its own timer state (get_below_threshold_since_for_test(),
## get_last_escalation_time_for_test(), get_de_escalation_lockout_until_for_
## test()) without driving a full WaveDirector fixture for every assertion.
func get_pressure_metric_for_test() -> PressureMetric:
	return _pressure_metric


# --- P2.8b test-only seams (never called by gameplay code) ------------------

func is_overtime_active_for_test() -> bool:
	return _overtime_active


func get_current_encounter_id_for_test() -> String:
	var encounter: EncounterDefinition = _current_encounter()
	return encounter.unique_id if encounter != null else ""


func get_wave_encounter_position_for_test() -> int:
	return _wave_encounter_position


func get_wave_encounter_queue_size_for_test() -> int:
	return _wave_encounter_queue.size()


func get_encounter_gap_deadline_for_test() -> float:
	return _encounter_gap_deadline


func get_finisher_spawned_count_for_test() -> int:
	return _current_wave_finishers.size()


func get_effective_group_count_for_test(encounter: EncounterDefinition, group_index: int) -> int:
	return _effective_group_count(group_index, encounter.spawn_groups[group_index])


func get_encounter_open_time_for_test() -> float:
	return _encounter_open_time


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


## P2.9 typed command, real seam: the debug overlay this director pushes
## Pressure/state/quadrant to (docs/20 > "Communication, commands": a system
## pushes its own state to another system's typed setter; this director
## never reaches into the overlay's fields). Matches set_tower_reference()'s
## own "resolved once against this node's siblings, or supplied directly"
## convention -- see `debug_overlay_path` and `_resolve_debug_overlay()`.
func set_debug_overlay_reference(overlay: Node) -> void:
	_debug_overlay = overlay


## P2.9 Capacity seam (task instruction: "read capacity through a narrow
## seam you define ... with a documented fallback to base values when
## nothing is wired"). The orchestrator wires this to the upgrade system
## once it exists this session; until then, `_player_capacity_dps()` falls
## back to CombatStats("player") if anything has ever reported it (real
## weapon systems already do -- src/combat/auto_weapon.gd), then to
## `player_weapon_definition_fallback`'s sheet DPS. The provider is checked
## FIRST and unconditionally: this function contains no branch on pause,
## Console, or any other state, by design -- Register: "the player's term is
## not zeroed while the Console is open" (see `_player_capacity_dps()`'s own
## comment for why no such branch exists here at all).
func set_player_capacity_provider(provider: Callable) -> void:
	_player_capacity_provider = provider


## Same seam, Tower side.
func set_tower_capacity_provider(provider: Callable) -> void:
	_tower_capacity_provider = provider


## P2.9 seam for a future Level-Up Draft system (P2.11+, not built this
## session -- Phase 05). Register > "Wave Runtime Model": "For 1.5 seconds
## after a Level-Up Draft closes, no encounter opens and no spawn group
## starts"; the same grace period also gates Pressure evaluation (Register >
## Pressure & Overtime > "Pressure formula": "... outside the grace
## period"). This method implements ONLY the Pressure-gating half of that
## rule (`_is_in_grace_period()`, read by `_process_pressure_metric()`); the
## "no encounter opens and no spawn group starts" half is a P2.8-scoped
## Wave Runtime Model rule this task does not touch -- named as a required
## seam in the P2.9 evidence report. Left uncalled by anything today, so
## `_grace_period_deadline` stays -INF and `_is_in_grace_period()` is always
## false -- the documented fallback.
func notify_draft_closed(now: float) -> void:
	if director_configuration != null:
		_grace_period_deadline = now + director_configuration.post_draft_grace_period_seconds


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
	_overtime_active = false
	_next_stall_check_time = -INF
	_next_finisher_spawn_time = -INF
	_finisher_emitted_in_current_burst = 0
	_finisher_next_index = 0
	_finisher_fail_counts.clear()
	_current_wave_finishers.clear()
	_encounter_gap_deadline = -INF
	_wave_encounter_position = 0
	_wave_encounter_queue = _build_priority_sorted_encounter_queue(waves[index])
	_start_encounter_tracking(_current_encounter())
	_state = State.WAVE_ACTIVE
	wave_opened.emit(waves[index].unique_id, index)


## P2.8b. Register > "Priorities & recovery gaps": "When two encounters are
## due at the same moment, the higher-priority one opens and the
## lower-priority one waits until the higher-priority one completes plus
## its recovery gap." Every encounter named in a wave's `encounter_sequence`
## becomes due the instant the wave opens (Wave Runtime Model's own second
## paragraph: "A wave runs an ordered sequence of encounters" -- read here
## as the ORDER this director resolves them in, not necessarily authoring
## order, since priority is what actually arbitrates a tie); this director
## resolves that ordering ONCE, at wave open, into a fixed
## priority-descending queue (ties broken by Unique ID ascending -- Encounter
## Definition Contract's own documented tie rule: "priority: 0 to 100; ties
## by Unique ID ascending") rather than re-arbitrating every tick, since
## priority is a static per-encounter field, not a time-varying one.
##
## The prototype's own 8 waves each carry exactly one encounter (P2.8
## report), so this sort is a no-op array of length 1 for every wave the
## real prototype sequence ever opens -- see this file's own header,
## "Regression".
func _build_priority_sorted_encounter_queue(wave: WaveDefinition) -> Array[EncounterDefinition]:
	var queue: Array[EncounterDefinition] = []
	for encounter_id in wave.encounter_sequence:
		var encounter: EncounterDefinition = _encounter_lookup.get(encounter_id)
		if encounter != null:
			queue.append(encounter)
	queue.sort_custom(func(a: EncounterDefinition, b: EncounterDefinition) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.unique_id < b.unique_id
	)
	return queue


func _current_encounter() -> EncounterDefinition:
	if _wave_encounter_position < 0 or _wave_encounter_position >= _wave_encounter_queue.size():
		return null
	return _wave_encounter_queue[_wave_encounter_position]


## Shared by _open_wave() (the first/only encounter) and
## _advance_to_next_encounter_in_wave() (a later one in the same wave's
## priority queue): resets every piece of state scoped to "the currently
## open encounter" and applies P2.8b's Siege scaling (see
## _maybe_scale_siege_spawn_groups()) for whichever encounter is starting.
func _start_encounter_tracking(encounter: EncounterDefinition) -> void:
	_encounter_open_time = _now()
	_group_emitted_counts.clear()
	_group_fail_counts.clear()
	_group_start_offset_override.clear() # P2.9: group indices are per-encounter and reused across encounters/waves, like the clears above
	_group_count_override.clear()
	_current_wave_spawned.clear()
	if encounter != null:
		_maybe_scale_siege_spawn_groups(encounter)


func _advance_to_next_encounter_in_wave() -> void:
	_wave_encounter_position += 1
	_start_encounter_tracking(_current_encounter())


func _process_wave_active(_delta: float) -> void:
	var wave: WaveDefinition = waves[_current_wave_index]
	var now: float = _now()

	# P2.8b: the recovery gap between two encounters WITHIN this wave
	# (Register > "Priorities & recovery gaps": the lower-priority encounter
	# "waits until the higher-priority one completes plus its recovery
	# gap"). No encounter is open while this is pending -- distinct from the
	# INTER-WAVE gap (State.GAP / _process_gap()), which this state machine
	# already had. Moot for the real 8-wave prototype (see this file's
	# header, "Regression"): _encounter_gap_deadline is only ever set when a
	# wave's priority queue has a NEXT encounter still waiting, which never
	# happens for a 1-element queue.
	if _encounter_gap_deadline > -INF:
		if now < _encounter_gap_deadline:
			return
		_encounter_gap_deadline = -INF
		_advance_to_next_encounter_in_wave()

	var encounter: EncounterDefinition = _current_encounter()
	if encounter == null:
		push_error("WaveDirector: wave '%s' names an encounter sequence that does not resolve to any wired EncounterDefinition" % wave.unique_id)
		return

	_process_pressure_metric(wave, encounter) # P2.9 -- before spawn groups, so an escalation/de-escalation decided THIS tick already applies to _process_spawn_groups() below
	_maybe_enter_overtime(wave, encounter, now) # P2.8b -- may flip _overtime_active THIS tick, before spawn processing below decides which path to take
	if _overtime_active:
		_process_finisher_spawns(wave, now) # Register: "During Overtime no further spawn groups start" -- enforced by calling this instead of _process_spawn_groups(), not by a branch inside either
	else:
		_process_spawn_groups(encounter)

	var result: Dictionary = _evaluate_wave_state(wave, encounter)
	if not bool(result.get("encounter_ended", false)):
		return
	if bool(result.get("wave_ends", false)) or _wave_encounter_position + 1 >= _wave_encounter_queue.size():
		_end_current_wave(wave, encounter)
	else:
		# Register: "the lower-priority one waits until the higher-priority
		# one completes plus its recovery gap" -- THIS encounter just
		# completed naturally (not via a wave-level stall/Overtime/C-FINAL
		# rule), and another encounter is still queued for this same wave.
		_encounter_gap_deadline = now + encounter.minimum_recovery_gap_seconds


func _process_spawn_groups(encounter: EncounterDefinition) -> void:
	var now: float = _now()
	# P2.9 Register > "De-escalation (bounded)": "spawn intervals double".
	# Applied encounter-wide while active; reverts the instant it lifts.
	# Recomputing due_time from this multiplier on every call (rather than
	# tracking a separate "time of last spawn" per group) means a group
	# already mid-emission when de-escalation toggles gets its NEXT pending
	# spawn's wait recomputed from the same wave_open_time+offset anchor
	# every group already used before P2.9 -- when the multiplier is 1.0 and
	# no group has ever been escalated (the default state), this produces
	# EXACTLY the pre-P2.9 formula, byte-for-byte (named here so a reviewer
	# does not have to re-derive it from the diff).
	var interval_multiplier: float = 2.0 if _de_escalation_active_now else 1.0
	for group_index in encounter.spawn_groups.size():
		var group: SpawnGroup = encounter.spawn_groups[group_index]
		var effective_count: int = _effective_group_count(group_index, group)
		var emitted: int = int(_group_emitted_counts.get(group_index, 0))
		# P2.9 Escalation Trigger override (Register > "Escalation Trigger":
		# "the current encounter's next spawn group starts"; SpawnGroup's own
		# schema comment: "a spawn group starts at its start offset or
		# earlier if the Escalation Trigger starts it"). Absent for every
		# group nothing has ever escalated -- see _find_next_pending_group_
		# index() / _process_pressure_metric().
		var start_offset: float = float(_group_start_offset_override.get(group_index, group.start_offset_seconds))
		while emitted < effective_count:
			var due_time: float = _encounter_open_time + start_offset + float(emitted) * group.spawn_interval_seconds * interval_multiplier
			if now < due_time:
				break
			if not _attempt_spawn(encounter, group, group_index, emitted):
				break # throttled or invalid this tick -- retries next tick WITHOUT consuming budget (Register: both throttle and "no valid candidate" share this rule)
			emitted += 1
			_group_emitted_counts[group_index] = emitted


## P2.8b. `group.count` as authored, UNLESS `_maybe_scale_siege_spawn_
## groups()` populated an override for this group index this encounter
## (live-DPS-scaled Siege sizing) -- see that method's own header. Never
## mutates the shared SpawnGroup Resource itself.
func _effective_group_count(group_index: int, group: SpawnGroup) -> int:
	return int(_group_count_override.get(group_index, group.count))


## P2.9. The first group (in authored order) that has not yet emitted even
## its first spawn AND has never itself already been pulled forward --
## Register: "the current encounter's next spawn group starts." -1 if none
## (Register: "If no spawn group remains, escalation does nothing" -- see
## src/director/pressure_metric.gd's `update()` header for how the caller
## (this file) honours that literally).
func _find_next_pending_group_index(encounter: EncounterDefinition) -> int:
	for group_index in encounter.spawn_groups.size():
		if int(_group_emitted_counts.get(group_index, 0)) == 0 and not _group_start_offset_override.has(group_index):
			return group_index
	return -1


## P2.9. docs/11 > "Pacing & Escalation Algorithm" in full -- this task's
## complete owning section; MASTER_SDLC.md > Provisional Values Register >
## "Pressure & Overtime" for every numeric default (all read from
## data/encounters/director_configuration.tres's `pressure_metric_*` fields
## or a Wave's own override, never restated as a literal here).
##
## Gating, in order: (1) only a combat wave, never a teaching wave
## (`teaching_wave_unique_ids`); (2) outside the post-draft grace period
## (`_is_in_grace_period()`); (3) the Register's fixed 0.5 s cadence
## (`PressureMetric.EVAL_INTERVAL_SECONDS`). When (1) or (2) fail, this
## function returns without advancing PressureMetric at all -- Pressure
## simply holds its last pushed value/state until evaluation resumes, and
## `reset_escalation_hold_timer()` is called on the resuming tick so paused
## time is never counted as "held below threshold" (see pressure_metric.gd's
## own comment on that method).
func _process_pressure_metric(wave: WaveDefinition, encounter: EncounterDefinition) -> void:
	var now: float = _now()
	var active: bool = not _is_teaching_wave(wave) and not _is_in_grace_period(now)
	if not active:
		_pressure_was_active_last_tick = false
		return
	if not _pressure_was_active_last_tick:
		_pressure_metric.reset_escalation_hold_timer()
	_pressure_was_active_last_tick = true
	if now < _next_pressure_eval_time:
		return
	_next_pressure_eval_time = now + PressureMetric.EVAL_INTERVAL_SECONDS

	var threat: float = _compute_current_threat()
	var capacity: float = _player_capacity_dps() + _tower_capacity_dps()
	var pressure: float = PressureMetric.compute_pressure(threat, capacity)

	var is_siege: bool = encounter.encounter_type == ContractEnums.EncounterType.Siege
	var is_overtime: bool = _overtime_active # P2.8b: was unconditionally false while Overtime did not exist -- now wired to the real state (Register > De-escalation: "never applies during a Siege or Overtime")
	# docs/20: "absent fields fall back to the Director Configuration
	# defaults" -- whole-resource fallback (see pressure_metric.gd's
	# update() header for why this is read as per-RESOURCE, not per-field).
	var constants: PressureMetricConstants = wave.pressure_metric_constants
	if constants == null and director_configuration != null:
		constants = director_configuration.pressure_metric_timers
	if constants == null:
		return # no Pressure Metric constants wired anywhere -- cannot evaluate; matches this file's existing "not configured yet" pattern rather than crashing on a null field access

	var result: Dictionary = _pressure_metric.update(now, pressure, is_siege, is_overtime, constants)

	var state_label: String = "Normal"
	if bool(result["escalate"]):
		var group_index: int = _find_next_pending_group_index(encounter)
		if group_index >= 0:
			_group_start_offset_override[group_index] = now - _encounter_open_time
			_pressure_metric.notify_escalated(now)
			state_label = "Escalated"
	_de_escalation_active_now = bool(result["de_escalating"])
	if _de_escalation_active_now and state_label == "Normal":
		state_label = "DeEscalating"

	var quadrant: PressureMetric.HealthQuadrant = _compute_health_quadrant()
	var quadrant_label: String = PressureMetric.quadrant_label(quadrant)

	_last_pressure_for_test = pressure
	_last_pressure_state_for_test = state_label
	_last_health_quadrant_for_test = quadrant_label
	_push_overlay_pressure(pressure, state_label)
	_push_overlay_quadrant(quadrant_label)


func _is_teaching_wave(wave: WaveDefinition) -> bool:
	return wave != null and teaching_wave_unique_ids.has(wave.unique_id)


func _is_in_grace_period(now: float) -> bool:
	return now < _grace_period_deadline


## P2.9 Threat (Register > "Threat formula"). Reads every living, non-dying
## enemy via the SAME EntityRegistry tag query wave/encounter completion
## already uses (default `include_dead = false` excludes anything Logical
## Death has flagged not-alive -- see this file's own header, "Completion
## counting"). Duck-typed reads of `definition`/`death_state` off each
## instance, matching this file's own `_tower_interaction_radius_px()`
## precedent (`tower.get("definition")`) and enemy_controller.gd's own
## precedent (`target.get("death_state")`) -- never a hard Enemy/Tower
## script dependency this director does not otherwise have.
func _compute_current_threat() -> float:
	if _registry == null:
		return 0.0
	var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	var entries: Array = []
	for entity in live:
		var definition: Variant = entity.get("definition")
		if not (definition is EnemyDefinition):
			continue
		var current_hp: float = 0.0
		var death_state: Variant = entity.get("death_state")
		if death_state is DeathState:
			current_hp = (death_state as DeathState).current_hp
		var weight: float = _intent_weight_for((definition as EnemyDefinition).target_intent)
		var dps: float = 0.0
		if _combat_stats != null:
			dps = _combat_stats.sheet_dps_from_attack_profile((definition as EnemyDefinition).attack_profile)
		entries.append({"current_hp": current_hp, "intent_weight": weight, "dps": dps})
	return PressureMetric.compute_threat(entries)


## Register > "Threat formula": "intent_weight is 1.0 for Player Hunters,
## 1.25 for Tower Seekers, and 1.1 for Opportunists" -- read from
## data/encounters/director_configuration.tres's
## `pressure_metric_intent_weights` field, never restated as a literal here.
func _intent_weight_for(target_intent: ContractEnums.TargetIntent) -> float:
	if director_configuration == null:
		return 0.0
	for entry in director_configuration.pressure_metric_intent_weights:
		if (entry as PressureIntentWeightEntry).target_intent == target_intent:
			return (entry as PressureIntentWeightEntry).weight
	return 0.0


## P2.9 Capacity, player term (Register > "Capacity formula"). Checked in
## this fixed order: (1) the orchestrator's own provider, if wired --
## presumably the upgrade system, reflecting current ranks live; (2)
## CombatStats("player"), if anything has ever reported it (src/combat/
## auto_weapon.gd already does, every time it (re)configures); (3) this
## file's own `player_weapon_definition_fallback` .tres, computed via the
## SAME CombatStats.sheet_dps_from_weapon() every real weapon system uses,
## never a duplicated literal. Deliberately NO branch on PauseAuthority,
## Console state, or anything else: Register: "the player's term is not
## zeroed while the Console is open" -- the Console does not pause the game
## at all (Phase 05's own "Console non-pause test" title), so there is
## nothing here that COULD zero this term on Console open without this
## function inventing a special case the Register explicitly forbids.
func _player_capacity_dps() -> float:
	if _player_capacity_provider.is_valid():
		return float(_player_capacity_provider.call())
	if _combat_stats != null and _combat_stats.has_reported_sheet_dps(&"player"):
		return _combat_stats.get_sheet_dps(&"player")
	if _combat_stats != null:
		return _combat_stats.sheet_dps_from_weapon(player_weapon_definition_fallback)
	return 0.0


## Same seam and fallback chain, Tower side (src/tower/tower_weapon.gd
## reports to CombatStats("tower") the same way).
func _tower_capacity_dps() -> float:
	if _tower_capacity_provider.is_valid():
		return float(_tower_capacity_provider.call())
	if _combat_stats != null and _combat_stats.has_reported_sheet_dps(&"tower"):
		return _combat_stats.get_sheet_dps(&"tower")
	if _combat_stats != null:
		return _combat_stats.sheet_dps_from_weapon(tower_weapon_definition_fallback)
	return 0.0


## P2.9 Health quadrant (Register > "Health quadrant": "Low is below 40% of
## maximum health, shield excluded, for either pool"). Player HP comes from
## DeathState (current_hp/max_hp -- the player pool has no shield at all, so
## "shield excluded" is trivially satisfied); Tower HP comes from
## TowerHealth.get_current_health()/max_health (its shield is a SEPARATE
## field this never reads). Duck-typed, matching `_compute_current_threat()`
## and `_tower_interaction_radius_px()`'s own precedent. Either fraction
## stays NAN (treated as Normal, never Low -- see pressure_metric.gd) if the
## player/Tower cannot be resolved at all.
func _compute_health_quadrant() -> PressureMetric.HealthQuadrant:
	var player_fraction: float = NAN
	var player: Node2D = _resolve_player()
	if player != null:
		var death_state: Variant = player.get("death_state")
		if death_state is DeathState and (death_state as DeathState).max_hp > 0.0:
			player_fraction = (death_state as DeathState).current_hp / (death_state as DeathState).max_hp

	var tower_fraction: float = NAN
	var tower: Node2D = _resolve_tower()
	if tower != null:
		var health: Variant = tower.get("health")
		if health != null and health.has_method("get_current_health"):
			var max_health: float = float(health.get("max_health"))
			if max_health > 0.0:
				tower_fraction = float(health.call("get_current_health")) / max_health

	var threshold: float = director_configuration.health_quadrant_threshold if director_configuration != null else 0.4
	return PressureMetric.compute_health_quadrant(player_fraction, tower_fraction, threshold)


func _resolve_debug_overlay() -> Node:
	if _debug_overlay != null and is_instance_valid(_debug_overlay):
		return _debug_overlay
	if debug_overlay_path != NodePath():
		var n: Node = get_node_or_null(debug_overlay_path)
		if n != null:
			_debug_overlay = n
	return _debug_overlay


func _push_overlay_pressure(value: float, state: String) -> void:
	var overlay: Node = _resolve_debug_overlay()
	if overlay != null and overlay.has_method("set_pressure"):
		overlay.call("set_pressure", value, state)


func _push_overlay_quadrant(quadrant: String) -> void:
	var overlay: Node = _resolve_debug_overlay()
	if overlay != null and overlay.has_method("set_health_quadrant"):
		overlay.call("set_health_quadrant", quadrant)


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

	if _encounter_cap_blocks_spawn(encounter):
		return false # P2.8b: encounter-level alive cap throttle -- see _encounter_cap_blocks_spawn(); a DIFFERENT mechanism from the global-cap null check below, checked first so it never wastes a global-pool acquisition it would have to immediately undo

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


## P2.8b. Register > "Encounter-level alive cap": "e.g. 120 in heavy Siege;
## throttles like the global cap"; docs/11 > Wave Runtime Model: "counts all
## living enemies, not just its own spawns." A predetermined Phase 04 risk
## (PLAN.md: "The entity cap being exceeded by Overtime finishers") named
## finisher spawning as the case that must go through the SAME throttle as
## an ordinary spawn group, not around it -- this check is shared by both
## _attempt_spawn() (above) and _attempt_finisher_spawn() (below), never
## duplicated.
func _encounter_cap_blocks_spawn(encounter: EncounterDefinition) -> bool:
	if encounter == null or encounter.encounter_alive_cap <= 0:
		return false
	return _registry != null and _registry.get_live_enemy_count() >= encounter.encounter_alive_cap


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


# --- P2.8b: Overtime finisher spawning ---------------------------------------

## Register > "Overtime finishers": "2 per 5 s on the view ring." Runs every
## tick while `_overtime_active` is true (called from `_process_wave_
## active()` INSTEAD of `_process_spawn_groups()` -- Register: "During
## Overtime no further spawn groups start" is enforced by that choice, not
## by a branch inside either method). Mirrors `_process_spawn_groups()`'s
## own per-group emitted-count pattern: `_finisher_emitted_in_current_burst`
## persists across ticks so a burst partially throttled by the cap (or a
## validation failure) resumes exactly where it left off next tick, rather
## than restarting the whole burst of `count` and risking a double-spawn of
## whichever member already went out.
func _process_finisher_spawns(wave: WaveDefinition, now: float) -> void:
	if wave.overtime_condition == null:
		return
	var rate: FinisherSpawnRate = wave.overtime_condition.finisher_spawn_rate
	if rate == null or rate.count <= 0 or rate.interval_seconds <= 0.0:
		return # documented fallback: nothing authored to spawn against
	if _next_finisher_spawn_time == -INF:
		# First burst fires the instant Overtime opens -- matching how a
		# spawn group authored at start_offset_seconds = 0 fires immediately
		# at wave/encounter open, for the same "no arbitrary initial delay"
		# reasoning, since the Register does not itself say whether the
		# first burst is immediate or after the first interval.
		_next_finisher_spawn_time = now
	if now < _next_finisher_spawn_time:
		return
	while _finisher_emitted_in_current_burst < rate.count:
		if not _attempt_finisher_spawn(wave):
			return # throttled or invalid this tick -- retries next tick WITHOUT consuming the burst, matching _process_spawn_groups()'s own rule
		_finisher_emitted_in_current_burst += 1
	_next_finisher_spawn_time = now + rate.interval_seconds
	_finisher_emitted_in_current_burst = 0


## Deterministic per-wave finisher serial (see FINISHER_SERIAL_BASE's own
## header) -- a FIXED number for "the Nth finisher this wave has attempted",
## tried repeatedly across retries until it succeeds, exactly like an
## ordinary spawn's `_spawn_serial_for()` never re-rolls a retried slot.
func _finisher_spawn_serial() -> int:
	return FINISHER_SERIAL_BASE + _current_wave_index * FINISHER_SERIAL_PER_WAVE + _finisher_next_index


## One finisher spawn attempt. Goes through the SAME encounter-alive-cap
## throttle (`_encounter_cap_blocks_spawn()`) and the SAME global-cap/Pool
## path (`_entity_spawner.spawn_enemy()`) as `_attempt_spawn()` above -- the
## Phase 04 PLAN.md predetermined risk this task exists to close ("Overtime
## finishers... subject to the same global entity cap and ring validation/
## throttle logic... as any other spawn group").
func _attempt_finisher_spawn(wave: WaveDefinition) -> bool:
	var finisher_id: String = wave.overtime_condition.finisher_enemy_id
	var enemy_info: Dictionary = _enemy_lookup.get(finisher_id, {})
	var definition: EnemyDefinition = enemy_info.get("definition")
	var scene: PackedScene = enemy_info.get("scene")
	if definition == null or scene == null:
		push_error("WaveDirector: Overtime finisher_enemy_id '%s' does not resolve to a wired enemy definition/scene" % finisher_id)
		return false

	if _encounter_cap_blocks_spawn(_current_encounter()):
		return false

	var serial: int = _finisher_spawn_serial()
	var placement: Dictionary = _resolve_finisher_spawn_placement(definition, serial)
	var fail_key: int = _finisher_next_index
	if not placement.get("valid", false):
		var fails: int = int(_finisher_fail_counts.get(fail_key, 0)) + 1
		_finisher_fail_counts[fail_key] = fails
		if fails >= CONSECUTIVE_FAIL_ESCALATION_TICKS:
			var escalated: Dictionary = _escalated_placement(definition, serial)
			if escalated.get("valid", false):
				placement = escalated
		if not placement.get("valid", false):
			return false
	_finisher_fail_counts.erase(fail_key)

	var spawn_position: Vector2 = placement["position"]
	# The finisher's reduced-stat definition and the is_finisher flag are
	# set on the FRESH instance inside this factory closure, before
	# EntitySpawner/Pool ever add_child()s it -- EnemyController's own
	# _ready() reads both synchronously on that same call (leash timeout,
	# max HP, speed), so setting them any later (after spawn_enemy()
	# returns) would be too late for a first-time-created instance. Today's
	# actual runtime never recycles a released enemy instance through the
	# free list (nothing in src/ yet calls EntitySpawner.despawn_enemy() for
	# a normally-dying enemy -- confirmed by reading the whole tree), so
	# this factory runs for every finisher spawn in practice; named as a
	# cross-task seam in the evidence report for when that changes, since
	# Pool.acquire()'s free-list-reuse path does not invoke ANY factory at
	# all and would silently skip this assignment on a recycled instance.
	var instance: Node2D = _entity_spawner.spawn_enemy(spawn_position, func() -> Node2D:
		var inst: Node2D = scene.instantiate()
		inst.set("definition", definition)
		inst.set("is_finisher", true)
		return inst
	)
	if instance == null:
		return false # global cap throttle
	instance.global_position = spawn_position
	if _registry != null:
		_registry.update_position(instance, spawn_position)
	_current_wave_finishers.append(instance)
	_finisher_next_index += 1
	enemy_spawned.emit(instance, finisher_id, spawn_position)
	return true


## Register > "Overtime finishers": "on the view ring." `definition.
## target_intent` (PlayerHunter) already routes to the view ring via the
## SAME `_ring_for_intent()` every ordinary Hunter/Opportunist spawn uses --
## no special-casing needed. Uniform across the ring: the Register defines
## directional weighting for Standard Assault/Split Assault/Siege/Hunt
## specifically (docs/11 > "Directional Weighting") and says nothing about
## a finisher's placement bias, so this is a named interpretation (uniform,
## matching `_base_angle_for()`'s own default branch for an unlisted type),
## not a silently invented rule.
func _resolve_finisher_spawn_placement(definition: EnemyDefinition, serial: int) -> Dictionary:
	var ring_info: Dictionary = _ring_for_intent(definition.target_intent)
	var rng: RandomNumberGenerator = KeyedRng.rng_for([run_seed, "spawn", serial])
	var angle: float = rng.randf() * TAU
	var radius_fraction: float = rng.randf()
	return SpawnGeometry.validate_and_shift(
		angle, radius_fraction,
		ring_info["ring"], ring_info["center"],
		_tower_center(), _tower_interaction_radius_px(),
		_view_center(), _view_half_size(), float(director_configuration.camera_exclusion_margin_px),
		arena_center, ARENA_SIZE / 2.0, ARENA_INSET_PX,
		director_configuration.spawn_validation_retry.steps, director_configuration.spawn_validation_retry.angle_degrees
	)


# --- P2.8b: Siege volume formula, computed against live Tower DPS ----------

## Register > "Siege volume formula": "Seeker count = ceil(multiplier x
## Tower DPS at Siege open (upgrades counted) x 0.75 x wave maximum
## duration / 60) ... Hunters = round(0.15 x Seeker count at Siege open)."
## Base Tower DPS (`tower_weapon_definition_fallback`'s own sheet DPS,
## matching the Register's own "base Tower 25 DPS" citation) is read once
## via CombatStats, not restated as a literal.
##
## Gated on `live_dps > base_dps` (strictly greater), not `!= base_dps` or
## unconditional: at EXACTLY base DPS (no Caliber ranks bought -- this
## build's own current state, since nothing wires `set_tower_capacity_
## provider()` yet and CombatStats never reports a Tower figure above base
## without a real upgrade system), this is always a no-op and the AUTHORED
## LITERAL counts (43/57 Seekers) are used unchanged. This is required for
## the task instruction "do not re-time the existing eight-wave sequence"
## to hold regardless of whether/when the orchestrator wires the upgrade
## system's provider.
##
## DISCOVERED DOCUMENT INCONSISTENCY (named here and in the evidence
## report, not silently resolved either way): applying the stated formulas
## literally at the Register's own worked example (Tower DPS 25, 90 s wave,
## multiplier 1.5) gives Seeker count ceil(1.5*25*0.75*90/60) = ceil(42.1875)
## = 43 (matches the authored/stated "43 Seekers" exactly), but Hunter count
## round(0.15*43) = round(6.45) = 6 -- NOT the Register's own stated "+7
## Hunters" for that same case. (The x2.0/combat_4 case has no such
## conflict: ceil(2.0*25*0.75*90/60)=57, round(0.15*57)=round(8.55)=9,
## matching "+9 Hunters" exactly.) Because this method is gated to never
## run AT exactly base DPS (see above), this inconsistency is never
## actually reachable through this code path -- it would only resurface if
## a future change lowered the `> base_dps` gate to `>=` or removed it.
func _maybe_scale_siege_spawn_groups(encounter: EncounterDefinition) -> void:
	if encounter.encounter_type != ContractEnums.EncounterType.Siege:
		return
	if not siege_multiplier_by_encounter_id.has(encounter.unique_id):
		return # not one of the mapped combat Sieges (also covers T4, exempt from the formula per the Register) -- keep the authored literal
	if _combat_stats == null:
		return
	var base_dps: float = _combat_stats.sheet_dps_from_weapon(tower_weapon_definition_fallback)
	var live_dps: float = _tower_capacity_dps()
	if base_dps <= 0.0 or live_dps <= base_dps:
		return # documented fallback: nothing to scale to -- keep the authored .tres literal

	var multiplier: float = float(siege_multiplier_by_encounter_id[encounter.unique_id])
	var constants: SiegeVolumeConstants = director_configuration.siege_volume_constants if director_configuration != null else null
	var window_fraction: float = constants.spawn_window_fraction if constants != null and constants.spawn_window_fraction > 0.0 else 0.75
	var hunter_pct: float = constants.hunter_percentage if constants != null and constants.hunter_percentage > 0.0 else 0.15
	var wave: WaveDefinition = waves[_current_wave_index]
	var seeker_count: int = int(ceil(multiplier * live_dps * window_fraction * wave.maximum_duration_seconds / 60.0))
	var hunter_count: int = int(round(hunter_pct * float(seeker_count)))

	for group_index in encounter.spawn_groups.size():
		var group: SpawnGroup = encounter.spawn_groups[group_index]
		if group.enemy_definition_id == tower_seeker_definition.unique_id:
			_group_count_override[group_index] = seeker_count
		elif group.enemy_definition_id == player_hunter_definition.unique_id:
			_group_count_override[group_index] = hunter_count


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
		if int(_group_emitted_counts.get(group_index, 0)) < _effective_group_count(group_index, group):
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


## P2.8b. Register > "Wave end / STALLED": "kills in the last 30 seconds,
## not counting finishers, are below the stall threshold (5)." `wave.
## overtime_condition == null` (should not happen for any authored wave --
## every data/waves/*.tres carries one -- but a hand-built test WaveDefinition
## might omit it) is the documented fallback: never stall with no data to
## act on, matching this file's existing "nothing wired -- do not crash"
## convention elsewhere (e.g. `_process_pressure_metric()`'s own null-
## constants return).
func _stall_check_triggers_overtime(wave: WaveDefinition, now: float) -> bool:
	if wave.overtime_condition == null:
		return false
	return _kills_in_last_window(now) < wave.overtime_condition.stall_threshold


## Prunes `_kill_timestamps` to the trailing STALL_WINDOW_SECONDS window as
## it counts, so the array never grows unboundedly across a long run. Not
## reset per wave (see `_kill_timestamps`' own declaration): every real
## combat wave's maximum duration (>= 20 s in the prototype, and every
## combat wave the stall rule actually applies to is 90 s) is well over the
## 30 s window, so by the time ANY wave reaches its own maximum duration,
## any residual timestamps from a PRIOR wave are already outside the window
## by simple elapsed time -- no explicit cross-wave reset is needed for
## correctness, only for not growing the array forever, which the pruning
## already does.
func _kills_in_last_window(now: float) -> int:
	var cutoff: float = now - STALL_WINDOW_SECONDS
	var i: int = 0
	while i < _kill_timestamps.size():
		if _kill_timestamps[i] < cutoff:
			_kill_timestamps.remove_at(i)
		else:
			i += 1
	return _kill_timestamps.size()


## P2.8b. Decides whether THIS tick is the one that starts Overtime, for
## whichever wave/encounter is currently open. A pure side-effect method
## (sets `_overtime_active`), deliberately separate from `_evaluate_wave_
## state()` (a pure predicate) so the stall check runs EXACTLY once -- the
## instant this returns with `_overtime_active` newly true, every later tick
## takes `_evaluate_wave_state()`'s `_overtime_active` branch instead of
## ever re-entering the "at maximum duration" branch below.
func _maybe_enter_overtime(wave: WaveDefinition, _encounter: EncounterDefinition, now: float) -> void:
	if _overtime_active:
		return
	var is_final: bool = _current_wave_index == waves.size() - 1
	if is_final:
		# C-FINAL: "After its maximum duration the stall check re-runs every
		# 0.5 seconds until Overtime starts."
		if now < _wave_open_time + wave.maximum_duration_seconds:
			return
		if now < _next_stall_check_time:
			return
		_next_stall_check_time = now + FINAL_WAVE_STALL_RECHECK_INTERVAL_SECONDS
		if _stall_check_triggers_overtime(wave, now):
			_overtime_active = true
		return
	# Non-final combat wave. Teaching waves never run the stall rule
	# (Register > "Teaching wave runtime (C-TEACH)": "they never run the
	# stall rule, Overtime, or escalation").
	if _is_teaching_wave(wave):
		return
	if now < _wave_open_time + wave.maximum_duration_seconds:
		return
	# The stall check runs ONCE: this branch is reached at most once per
	# wave, because either it sets _overtime_active = true (so the guard at
	# the top of this method short-circuits every later call), or
	# _evaluate_wave_state() below ends the wave THIS SAME tick (the
	# NOT-STALLED branch), and a wave that has ended never calls this method
	# again.
	if _stall_check_triggers_overtime(wave, now):
		_overtime_active = true


## P2.8b. Replaces P2.8's `_is_wave_ended()`: now a pure predicate returning
## BOTH whether the CURRENTLY OPEN ENCOUNTER has ended and, if so, whether
## that also ends the WHOLE WAVE (a stall-final/Overtime-cleanup/C-FINAL
## rule) as opposed to merely clearing the way for the next encounter in
## this wave's priority queue (Register > "Priorities & recovery gaps").
## Never mutates state itself (Overtime's own start decision lives in
## `_maybe_enter_overtime()`, called earlier in `_process_wave_active()`) --
## the one exception is `_despawn_remaining_finishers_without_drops()`,
## which is itself a CONSEQUENCE of this predicate becoming true, not a
## precondition for it.
func _evaluate_wave_state(wave: WaveDefinition, encounter: EncounterDefinition) -> Dictionary:
	var is_final: bool = _current_wave_index == waves.size() - 1
	var now: float = _now()

	if is_final:
		# C-FINAL: "adopts every living enemy when it opens ... ends only
		# when the EntityRegistry live-enemy count is zero." Gated on full
		# emission UNLESS Overtime is active: Overtime permanently halts
		# further spawn-group emission (Register: "no further spawn groups
		# start"), so a Siege whose Overtime fires before every authored
		# group has emitted would otherwise never satisfy `_all_groups_
		# emitted()` again, and the true win condition (nothing left alive)
		# would be unreachable -- named as an interpretation, since the
		# Register does not spell out this specific interaction.
		if not _overtime_active and not _all_groups_emitted(encounter):
			return {"encounter_ended": false, "wave_ends": false}
		# P2.8b generalisation for a final wave carrying more than one queued
		# encounter (moot for the real prototype -- every final wave there
		# has exactly one, so `more_encounters_queued` is always false and
		# `wave_ends` collapses to exactly `live_clear`, unchanged from
		# before this task): the live-enemy count can legitimately hit zero
		# for a moment between the higher-priority encounter's own last kill
		# and the lower-priority one's first spawn, and C-FINAL must not
		# read that as "the run is over" while an encounter is still queued
		# behind a deferred recovery gap. `encounter_ended` alone (with
		# `wave_ends` false) is what lets the ordinary dispatcher in
		# `_process_wave_active()` set that recovery gap instead of ending
		# the wave outright -- discovered and named via this task's own
		# encounter_recovery_test.gd falsification pass, not assumed.
		var live_clear: bool = _registry != null and _registry.get_live_enemy_count() == 0
		if not live_clear:
			return {"encounter_ended": false, "wave_ends": false}
		var more_encounters_queued: bool = _wave_encounter_position + 1 < _wave_encounter_queue.size()
		return {"encounter_ended": true, "wave_ends": not more_encounters_queued}

	if _overtime_active:
		# Register: "the wave continues until every non-finisher enemy it
		# owns is dead, then remaining finishers despawn without drops."
		if _all_non_finisher_enemies_dead():
			_despawn_remaining_finishers_without_drops()
			return {"encounter_ended": true, "wave_ends": true} # Overtime cleanup always ends the WHOLE wave, never just "advance to the next queued encounter"
		return {"encounter_ended": false, "wave_ends": false}

	if _all_groups_emitted(encounter) and _all_own_spawned_dead_or_removed():
		return {"encounter_ended": true, "wave_ends": false} # natural completion -- may advance to the next queued encounter (Priorities & recovery gaps) instead of ending the wave

	if _is_teaching_wave(wave):
		var teaching_done: bool = now >= _wave_open_time + wave.maximum_duration_seconds
		return {"encounter_ended": teaching_done, "wave_ends": teaching_done}

	if now >= _wave_open_time + wave.maximum_duration_seconds:
		# _maybe_enter_overtime() already ran this tick (see
		# _process_wave_active()); if it triggered Overtime, the branch
		# above already returned. Reaching here means it said NOT-STALLED:
		# the whole wave ends now and its living enemies carry over.
		return {"encounter_ended": true, "wave_ends": true}

	return {"encounter_ended": false, "wave_ends": false}


## Register > "Overtime finishers" / Wave Runtime Model: "the wave continues
## until every non-finisher enemy it owns is dead." Global, not scoped to
## this wave's own spawned list (see this file's own header, "Completion
## counting" -- carried-over survivors from an earlier wave/encounter are,
## by construction, already part of "every living enemy" once Overtime is
## active, matching C-FINAL's own "adopts every living enemy" phrasing for
## the analogous final-wave case).
func _all_non_finisher_enemies_dead() -> bool:
	if _registry == null:
		return true
	var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
	for entity in live:
		var v: Variant = entity.get("is_finisher")
		var is_finisher: bool = v is bool and v
		if not is_finisher:
			return false
	return true


## Register > "Overtime finishers": "then remaining finishers despawn
## without drops." Routed straight through EntitySpawner/Pool (deregister +
## release), never through death_state.apply_damage()/kill(), which would
## emit EventBus.enemy_died and (per src/pickup/pickup_system.gd's own
## finisher handling) still place the finisher's 1-XP drop -- this is a
## REMOVAL, not a kill, matching EnemyController's own established
## distinction for the same class of event (`_despawn_due_to_stuck()`'s own
## header: "this MUST NOT go through death_state.apply_damage()/kill(),
## which would ... mislabel a removal as a kill"). WaveDirector's side of an
## equivalent rule, not a duplicate of that function -- no EventBus signal
## exists for "a finisher was force-cleared, no drop", so none is emitted;
## this method's only externally-visible effect is that the entity stops
## appearing in any live EntityRegistry query.
func _despawn_remaining_finishers_without_drops() -> void:
	if _registry != null and _entity_spawner != null:
		var live: Array[Node2D] = _registry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)
		for f in _current_wave_finishers:
			if is_instance_valid(f) and live.has(f):
				_entity_spawner.despawn_enemy(f)
	_current_wave_finishers.clear()


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

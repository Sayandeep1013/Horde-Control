class_name RunRecorder
extends Node

## Run Recorder (docs/20_Technical_Architecture.md > "Debugging, Telemetry &
## Run Recording" > Run Recorder bullet; MASTER_SDLC.md > Provisional
## Values Register > Technical Caps & Performance > "Run Recorder" row,
## C-TELEMETRY). Writes, per run, under
## `user://telemetry/<run_seed>_<yyyyMMdd-HHmmss>_<controller_id>/`: a
## `header.csv` (run seed, build hash, Godot version), `ticks.csv` (dense,
## 2 Hz), and `events.csv` (sparse, one row per discrete event). See
## phases/PHASE_02_Technical_Foundations/evidence/p14_report.md for the two
## CSV schemas as written and the process-mode justification below in full.
##
## NOT an autoload (see the evidence report, "Autoload decision"): a run
## has a bounded lifetime (start_run() .. end_run()), which fits a plain
## Node a future run-owning system instances and frees, not a singleton
## that outlives every run and would grow tests/settings_check.gd's exact
## autoload set for no reason this task needs. No caller wires this into
## scenes/main.tscn yet -- that file belongs to a concurrent P1.3
## delegation, and the system that actually starts/ends a run is a later
## phase. This task delivers the class, verified the same way P1.1/P1.2
## verify their own not-yet-wired autoload SCRIPTS: a fresh instance added
## to a test's own tree (tests/unit/pause_clock_test.gd's own pattern).
##
## PROCESS_MODE_PAUSABLE: the dense ticks.csv trace samples SIMULATION
## state, and simulation state is frozen while the tree is paused (SimClock
## itself is PROCESS_MODE_PAUSABLE per Global Simulation Authority), so
## continuing to sample during a pause would only write duplicate rows of
## the same frozen values -- matching SimClock's own process mode is the
## simplest way to guarantee that. Idleness accumulation (below) rides the
## same _physics_process, for the same reason: "idle" describes a stretch
## of unfilled SIMULATION time, and a Level-Up Draft pause is not that.
## Event-driven writes (record_event(), called directly or from EventBus
## signal handlers) are ordinary method calls, not engine _process
## callbacks, so they are NEVER gated by this node's own process_mode -- an
## event that genuinely occurs while paused (for example a Level-Up Draft
## purchase, once that system exists) is still recorded at the exact
## SimClock.now instant it happened, regardless of this node's process
## mode. This is why a PAUSABLE choice for the periodic-sampling half of
## this class does not cost anything on the event-recording half.

const TICK_SAMPLE_INTERVAL: float = 0.5 # 2 Hz (docs/20 > Run Recorder: "ticks.csv, sampled at 2 Hz")
const IDLE_FIXED_GRACE: float = 3.0 # docs/20 > Idleness Metric: "... plus 3 seconds"
const MAGNET_RADIUS_MULTIPLIER: float = 2.0 # docs/20 > Idleness Metric: "twice the magnet radius"

## Magnet radius itself is a Provisional Default (MASTER_SDLC.md >
## Provisional Values Register > Interfaces / Player Overview: "Magnet
## radius / pickup motion | 96 px ...", owner doc 16) -- cited per
## CLAUDE.md's numbers rule, not restated as an unexplained literal.
## Overridable per set_magnet_radius(), since a later system (doc 16) owns
## the real value and any upgrades to it.
const DEFAULT_MAGNET_RADIUS: float = 96.0

## docs/20's own wording: "ticks.csv, sampled at 2 Hz, with columns SimClock
## time, player position, player HP, Tower HP and shield, Pressure, health
## quadrant, XP level, Scrap, and hopper amount." "player position" is not
## itself one CSV-safe scalar; this is this implementer's documented
## interpretation splitting it into an x and a y column (evidence report,
## "Contradictions and ambiguities") -- an interpretation call, not
## something docs/20 states in so many words.
const TICKS_HEADER: PackedStringArray = [
	"sim_time", "player_pos_x", "player_pos_y", "player_hp",
	"tower_hp", "tower_shield", "pressure", "health_quadrant",
	"xp_level", "scrap", "hopper_amount",
]

## docs/20's own wording: "events.csv, one row per discrete event, with
## columns SimClock time, event type, source intent, source bearing from
## the Tower, and amount."
const EVENTS_HEADER: PackedStringArray = [
	"sim_time", "event_type", "source_intent", "source_bearing", "amount",
]

var _run_seed: int = 0
var _controller_id: String = "human"
var _run_dir: String = ""
var _running: bool = false

var _ticks_file: FileAccess
var _events_file: FileAccess

var _time_since_tick_sample: float = 0.0
var _last_sim_time: float = 0.0

var _no_activity_accum: float = 0.0
var _idle_flagged: bool = false
var _scheduled_gap: float = 0.0
var _grace_period: float = 0.0
var _magnet_radius: float = DEFAULT_MAGNET_RADIUS

var _player_position: Vector2 = Vector2.ZERO
var _tower_position: Vector2 = Vector2.ZERO
var _player_hp: float = 0.0
var _tower_hp: float = 0.0
var _tower_shield: float = 0.0
var _pressure_value: float = 0.0
var _health_quadrant: String = ""
var _xp_level: int = 0
var _scrap: int = 0
var _hopper_amount: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Typed command. Opens a new run folder, writes header.csv and both CSV
## header rows, and starts listening to EventBus for the event types P1.2
## already implements (enemy_died, tower_damaged, draft_opened). Refuses
## (logs an error, does nothing) if a run is already open, since two open
## runs from one instance would interleave two SimClock-timestamped traces
## into the same files.
func start_run(controller_id: String = "human", run_seed: int = -1) -> void:
	if _running:
		push_error("RunRecorder: start_run() called while a run is already active")
		return
	_run_seed = run_seed if run_seed >= 0 else randi()
	_controller_id = controller_id
	_run_dir = "user://telemetry/%d_%s_%s" % [_run_seed, _format_timestamp(), _controller_id]
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_write_header()
	_open_csv_files()

	_last_sim_time = SimClock.now
	_time_since_tick_sample = 0.0
	_no_activity_accum = 0.0
	_idle_flagged = false
	_running = true

	if EventBus != null:
		if not EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.connect(_on_enemy_died)
		if not EventBus.tower_damaged.is_connected(_on_tower_damaged):
			EventBus.tower_damaged.connect(_on_tower_damaged)
		if not EventBus.draft_opened.is_connected(_on_draft_opened):
			EventBus.draft_opened.connect(_on_draft_opened)


## Typed command. Writes a final "run_end" event row, disconnects from
## EventBus, and closes both CSV files. Safe to call when no run is open
## (no-op).
func end_run(reason: String = "") -> void:
	if not _running:
		return
	record_event(&"run_end", StringName(reason), 0.0, 0.0)
	_running = false

	if EventBus != null:
		if EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.disconnect(_on_enemy_died)
		if EventBus.tower_damaged.is_connected(_on_tower_damaged):
			EventBus.tower_damaged.disconnect(_on_tower_damaged)
		if EventBus.draft_opened.is_connected(_on_draft_opened):
			EventBus.draft_opened.disconnect(_on_draft_opened)

	_close_csv_files()


func is_running() -> bool:
	return _running


func get_run_dir() -> String:
	return _run_dir


func get_run_seed() -> int:
	return _run_seed


## ---- Typed commands: future systems push their own current state here
## (docs/20 > "Communication, commands"). This class never reaches into
## another system's fields to read them.

func set_player_state(hp: float, position: Vector2, xp_level: int, scrap: int, hopper_amount: float) -> void:
	_player_hp = hp
	_player_position = position
	_xp_level = xp_level
	_scrap = scrap
	_hopper_amount = hopper_amount


func set_tower_state(hp: float, shield: float) -> void:
	_tower_hp = hp
	_tower_shield = shield


func set_tower_position(position: Vector2) -> void:
	_tower_position = position


func set_pressure(value: float) -> void:
	_pressure_value = value


func set_health_quadrant(quadrant: String) -> void:
	_health_quadrant = quadrant


## Scheduled gap and grace period are Wave Director (P2.8) values with no
## source yet; default 0.0 each, so today's idleness threshold is exactly
## the fixed 3 s docs/20 states, until P2.8 calls this with real numbers.
func set_idle_thresholds(scheduled_gap: float, grace_period: float) -> void:
	_scheduled_gap = scheduled_gap
	_grace_period = grace_period


func set_magnet_radius(radius: float) -> void:
	_magnet_radius = radius


## ---- Per-tick sampling and the Idleness Metric.

func _physics_process(_delta: float) -> void:
	if not _running:
		return
	var now: float = SimClock.now
	var sim_delta: float = maxf(now - _last_sim_time, 0.0)
	_last_sim_time = now

	_time_since_tick_sample += sim_delta
	while _time_since_tick_sample >= TICK_SAMPLE_INTERVAL:
		_time_since_tick_sample -= TICK_SAMPLE_INTERVAL
		record_tick_sample()

	_update_idleness(sim_delta)


## Typed command. Writes one ticks.csv row from this instance's current
## injected state. Called automatically at 2 Hz of SimClock time while a
## run is open; also callable directly (used by the schema check, which
## does not want to wait on real physics frames to see a row).
func record_tick_sample() -> void:
	if not _running or _ticks_file == null:
		return
	var row: PackedStringArray = [
		"%f" % SimClock.now,
		"%f" % _player_position.x,
		"%f" % _player_position.y,
		"%f" % _player_hp,
		"%f" % _tower_hp,
		"%f" % _tower_shield,
		"%f" % _pressure_value,
		_health_quadrant,
		"%d" % _xp_level,
		"%d" % _scrap,
		"%f" % _hopper_amount,
	]
	_write_csv_row(_ticks_file, row)


## Typed command. Any system -- an EventBus signal handler below, or a
## future caller with no EventBus signal to hang off yet (purchases,
## spawns, wave/encounter open-close, Console open-close) -- appends one
## events.csv row through this single entry point.
func record_event(event_type: StringName, source_intent: StringName = &"", source_bearing: float = 0.0, amount: float = 0.0) -> void:
	if not _running or _events_file == null:
		return
	var row: PackedStringArray = [
		"%f" % SimClock.now,
		String(event_type),
		String(source_intent),
		"%f" % source_bearing,
		"%f" % amount,
	]
	_write_csv_row(_events_file, row)


## docs/20 > Idleness Metric: "a stretch longer than the scheduled gap plus
## any grace period plus 3 seconds with no enemy alive and no pickup within
## twice the magnet radius." Flags (records one "idle" event) at most once
## per contiguous idle stretch -- re-arms only after activity resumes.
func _update_idleness(sim_delta: float) -> void:
	var no_enemies: bool = EntityRegistry == null or EntityRegistry.get_live_enemy_count() == 0
	var pickup_nearby: bool = false
	if EntityRegistry != null:
		pickup_nearby = not EntityRegistry.get_entities_in_radius(
			_player_position, _magnet_radius * MAGNET_RADIUS_MULTIPLIER, &"pickup"
		).is_empty()
	var idle_conditions_met: bool = no_enemies and not pickup_nearby

	if not idle_conditions_met:
		_no_activity_accum = 0.0
		_idle_flagged = false
		return

	_no_activity_accum += sim_delta
	var threshold: float = _scheduled_gap + _grace_period + IDLE_FIXED_GRACE
	if not _idle_flagged and _no_activity_accum > threshold:
		_idle_flagged = true
		record_event(&"idle", &"", 0.0, _no_activity_accum)


## Test-only knob (mirrors src/core/entity_registry.gd's own
## set_cell_size_for_test() convention): advances the idleness check by
## `sim_delta` without waiting on real physics frames. Calls the exact same
## _update_idleness() the real _physics_process() path calls -- never a
## duplicate/separate check -- so a test exercising this is still testing
## the production logic, not a stand-in for it.
func force_idle_update_for_test(sim_delta: float) -> void:
	_update_idleness(sim_delta)


## ---- EventBus signal handlers (docs/20 > "Communication, events": P1.2
## implements exactly three signals so far -- enemy_died, tower_damaged,
## draft_opened. The remaining event TYPES docs/20 names for events.csv
## (wave/encounter open-close, Draft close, Console open/close, purchases,
## spawns, run end) have no EventBus signal yet, since the owning systems
## do not exist yet (P2.x); record_event() above is public specifically so
## those later systems can call it directly once they exist, without this
## file needing to invent signals under src/core/, which this delegation
## may not edit.)

func _on_enemy_died(_entity: Node2D, position: Vector2, _timestamp: float) -> void:
	# "source intent" for a death is read here as the dying entity's own
	# EntityRegistry tag set, since no per-enemy AI-intent component exists
	# yet (P1.5+) to give a more specific answer than "enemy".
	record_event(&"death", &"enemy", _bearing_from_tower(position), 0.0)


func _on_tower_damaged(amount: float, _new_health: float, _new_shield: float, _timestamp: float) -> void:
	# tower_damaged carries no attacker reference (P1.2 deliverable, see
	# src/core/event_bus.gd), so source_intent is left blank rather than
	# guessed, and source_bearing is 0.0 (the damage IS at the Tower, not
	# somewhere bearing FROM it).
	record_event(&"damage", &"tower", 0.0, amount)


func _on_draft_opened(_timestamp: float) -> void:
	record_event(&"draft_open", &"", 0.0, 0.0)


func _bearing_from_tower(position: Vector2) -> float:
	return rad_to_deg((position - _tower_position).angle())


## ---- Header, CSV plumbing, and folder naming.

func _write_header() -> void:
	var f: FileAccess = FileAccess.open(_run_dir + "/header.csv", FileAccess.WRITE)
	if f == null:
		push_error("RunRecorder: could not open header.csv in %s" % _run_dir)
		return
	_write_csv_row(f, ["key", "value"])
	_write_csv_row(f, ["run_seed", str(_run_seed)])
	_write_csv_row(f, ["build_hash", _read_build_hash()])
	_write_csv_row(f, ["godot_version", _godot_version_string()])
	f.close()


## docs/20 > Run Recorder: "res://build_info.txt is written by an
## EditorExportPlugin that calls add_file(...) inside _export_begin;
## editor and headless runs record build hash 'editor'." Writing that
## export plugin is out of this task's scope (P1.4 is the overlay/
## recorder/pseudo-loc toggle, and this delegation is explicitly barred
## from export tooling); this reads the file if a later phase's export
## plugin ever produces it, and otherwise returns exactly "editor" -- which
## is every run this delegation itself can produce, since it may only run
## Godot headless.
func _read_build_hash() -> String:
	if FileAccess.file_exists("res://build_info.txt"):
		var content: String = FileAccess.get_file_as_string("res://build_info.txt").strip_edges()
		if not content.is_empty():
			return content
	return "editor"


func _godot_version_string() -> String:
	var v: Dictionary = Engine.get_version_info()
	return "%d.%d.%d.%s" % [v.get("major", 0), v.get("minor", 0), v.get("patch", 0), str(v.get("status", ""))]


func _format_timestamp() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system(false)
	return "%04d%02d%02d-%02d%02d%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]


func _open_csv_files() -> void:
	_ticks_file = FileAccess.open(_run_dir + "/ticks.csv", FileAccess.WRITE)
	if _ticks_file != null:
		_write_csv_row(_ticks_file, TICKS_HEADER)
	else:
		push_error("RunRecorder: could not open ticks.csv in %s" % _run_dir)

	_events_file = FileAccess.open(_run_dir + "/events.csv", FileAccess.WRITE)
	if _events_file != null:
		_write_csv_row(_events_file, EVENTS_HEADER)
	else:
		push_error("RunRecorder: could not open events.csv in %s" % _run_dir)


func _close_csv_files() -> void:
	if _ticks_file != null:
		_ticks_file.close()
		_ticks_file = null
	if _events_file != null:
		_events_file.close()
		_events_file = null


func _csv_escape(value: String) -> String:
	if value.find(",") == -1 and value.find("\"") == -1 and value.find("\n") == -1:
		return value
	return "\"%s\"" % value.replace("\"", "\"\"")


func _write_csv_row(file: FileAccess, values: PackedStringArray) -> void:
	var escaped: PackedStringArray = []
	for v in values:
		escaped.append(_csv_escape(v))
	file.store_line(",".join(escaped))
	# Flushed on every row, not just on close(): a caller (or this suite's
	# own schema check) may open a SECOND FileAccess handle on the same
	# path to read back what has been written so far while the run is
	# still open. Without an explicit flush, Godot's buffered FileAccess
	# does not guarantee that content is visible to a second handle before
	# this one closes -- observed directly as the schema check reading back
	# an empty header row (Phase 02 carried lesson 5: "verify by reading
	# the artifact back", which is exactly what caught this).
	file.flush()

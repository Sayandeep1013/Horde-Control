extends Node2D
class_name Console

## Console (P2.13 - Tower Console). docs/19_UI_UX.md > "Tower Console UI" in
## full (Presentation, Contents, Input, Lifecycle, Placement,
## Differentiation); MASTER_SDLC.md > Provisional Values Register >
## "Interfaces" > "Tower Console rules" (C-CONSOLE-NODE, C-REPAIR,
## C-AUTOFIRE) and > "Movement-only controls setting" (C-SECTORS); >
## "Progression & Upgrades" > "Console price", "Fallback cards"
## (C-FALLBACK-CONSOLE); > "Tower Overview" > "Health Recovery Rules"
## (Repair formula); > "Economy & Pickups" > "Scrap". Every number below is
## cited to one of those rows in a comment beside its constant, never
## restated as a bare literal in logic.
##
## ## The one hard rule this whole file exists to protect
## "The Console is the Draft's opposite in every operational respect: it
## never pauses the simulation." (task brief; MASTER_SDLC.md > Global
## Simulation Authority: "The Tower Console is the one exception to
## pausing... it never adds a pause reason and is never itself frozen by
## another reason's effect on the tree -- instead it manually hides itself
## and stops accepting input whenever PauseAuthority's reason set is
## non-empty"). Consequences this file draws from that one sentence:
##   1. This node's own `process_mode` is PROCESS_MODE_ALWAYS, NOT the
##      PROCESS_MODE_PAUSABLE every other gameplay entity in this codebase
##      uses -- the one deliberate exception in the project, named here so a
##      future reviewer does not "fix" it back to PAUSABLE. Everything this
##      node reads through SimClock.now still freezes correctly during a
##      pause (SimClock itself is PAUSABLE), so a frozen dwell/channel
##      deadline simply stops advancing and resumes exactly where it left
##      off with no drift -- this file never needs to compensate for a
##      pause duration itself.
##   2. Nowhere in this file calls `PauseAuthority.push_reason()` /
##      `pop_reason()` / `push_reason_immediate()` / `pop_reason_immediate()`
##      -- grep confirms it. The Console only ever LISTENS to
##      `PauseAuthority.reasons_changed` (via `_on_pause_reasons_changed()`)
##      to hide itself and go input-dead; it never writes pause state.
##   3. `_paused` (mirrors "the reason set is non-empty") gates both
##      `_process()`'s visibility and `_unhandled_input()`'s handling
##      explicitly, rather than relying on the engine's automatic
##      PROCESS_MODE_PAUSABLE gating -- because this node is ALWAYS mode, the
##      engine would otherwise keep showing/accepting input on a stale
##      Console during, say, the pause menu. The one exception that gets
##      MORE than "hidden": the `draft` reason specifically also forces a
##      real close (`_close_console()`), per the Lifecycle rule's explicit
##      "closes on ... a Level-Up Draft opening" -- distinct from a mere
##      pause-menu/focus-loss freeze, which preserves `_is_open` underneath
##      the hide so it reappears open (not re-dwelled) once that OTHER
##      reason clears. Named as an interpretation, not restated Register
##      text -- see the evidence report, "Interpretations."
##
## ## SimLoop registration (task instruction: "Register at SimLoop step 12
## ... rather than polling in _process")
## Every gameplay deadline below (`_dwell_started_at`, `_channel_started_at`)
## is an ABSOLUTE SimClock.now snapshot compared with `>=`, never a `_process`
## delta accumulator -- matching src/tower/tower_health.gd's shield-regen
## convention and src/player/player.gd's input-buffer convention exactly.
## `physics_step(delta)` is the public per-tick entry point docs/20's SimLoop
## order names as step 12 (CONSOLE_CHANNEL_COMPLETION); `driven_externally`
## (default false) mirrors every other `driven_externally`-capable file in
## this codebase (auto_weapon.gd, player.gd, wave_director.gd) -- this file
## self-drives via its own `_physics_process()` until a future integration
## task calls `SimLoop.register(SimLoop.Step.CONSOLE_CHANNEL_COMPLETION,
## console)` and sets `driven_externally = true` in the assembled scene
## (scenes/prototype.tscn is outside this task's write scope, per its hard
## constraints -- named as a required seam in the evidence report, exactly
## the same shape as wave_director.gd's and auto_weapon.gd's own unresolved
## SimLoop seams). `_process(delta)` (visual placement/scale/text refresh
## only, never a gameplay decision) mirrors src/camera/game_camera.gd's own
## precedent of running purely-visual work in `_process` rather than
## `_physics_process` (that file's own header cites "the godot-prompter
## camera-system skill's own implementation checklist").
##
## ## Cross-task seams this file could not close itself (hard constraints:
## src/economy/**, src/tower/**, src/upgrade/** are off limits this session)
## - RunInventory (src/economy/run_inventory.gd) exposes `credit_scrap()`
##   (adds only; `amount <= 0` is a no-op) but no debit/spend command. This
##   file charges a purchase by writing `_run_inventory.scrap_current`
##   directly, clamped at 0 -- the SAME direct-public-field-write pattern
##   this codebase already uses for exactly this class of gap (src/player/
##   player.gd's own `heal()`, and src/tower/tower_health.gd's own
##   `configure()` writing `_death_state.current_hp` directly). A proper
##   `RunInventory.spend_scrap(amount)` command is the correct home for this
##   and is named as a required seam in the evidence report.
## - TowerHealth (src/tower/tower_health.gd) exposes no heal()/restore()
##   command either. Repair writes `tower.death_state.current_hp` directly,
##   mirroring TowerHealth's OWN `configure()` doing exactly that to the same
##   field. Named as a required seam (`TowerHealth.repair(amount)`) in the
##   evidence report.
## - UpgradeSystem.apply_rank() (src/upgrade/upgrade_system.gd) "has no cost
##   concept" (F05-08, anticipated in that task's own ledger) -- this file
##   charges Scrap itself, BEFORE calling apply_rank() would be wrong (a
##   channel that completes must charge exactly once even if apply_rank()
##   somehow failed after a successful afford-check, which it cannot in the
##   single-player, single-writer case) -- so this file charges AFTER
##   apply_rank() returns true, never before, and never if apply_rank()
##   returns false.
##
## ## Wiring seams the orchestrator must complete (this file cannot touch
## scenes/prototype.tscn, src/tower/**, src/player/**, src/economy/**,
## src/upgrade/** this session)
## `tower_path`, `player_path`, `player_weapon_path` (falls back to
## `_player.get_node_or_null("AutoWeapon")` if unset -- matches
## scenes/player.tscn's fixed child name), `upgrade_system_path`,
## `camera_path` are all `@export`ed NodePaths resolved in `_ready()`,
## exactly like every other P2.x component in this codebase
## (Tower/Player/Hud's own `*_path` + `get_node_or_null()` convention).
## `set_run_inventory(RunInventory)` is a typed COMMAND (not merely a test
## seam) the orchestrator must call once, because RunInventory is a
## RefCounted (P2.10), not a scene node a NodePath can find.
##
## ## Presentation simplification, named rather than silently shipped
## docs/19 describes each purchase channel "with a fill ring." This file
## renders a linear `ProgressBar` instead of a circular radial fill --
## functionally equivalent (0..1 progress, visible only while a channel is
## active) but not pixel-for-pixel a ring, given this session's scope. Named
## in the evidence report, not silently substituted.
##
## ## GodotPrompter skill conflict, recorded per CLAUDE.md
## The `godot-ui` skill's own guidance: "Place UI nodes inside a
## `CanvasLayer` ... so they render on top of the 3D/2D world, unaffected by
## Camera transforms." docs/19 > "Tower Console UI" > "Placement" and the
## Register's C-CONSOLE-NODE row are explicit and binding the other way: the
## Console is "a world-space Node2D under the gameplay root," deliberately
## AFFECTED by the camera (its own `scale` is set every frame from
## `GameCamera.get_view_scale()` so its text keeps a constant on-screen
## size as the camera zooms) so it can sit anchored beside the Tower rather
## than pinned to the screen. This project's document wins; recorded here
## and in the evidence report/LEDGER per CLAUDE.md's GodotPrompter section.

# --- Provisional Values Register > Interfaces > "Tower Console rules" ------
const OPEN_DWELL_SECONDS: float = 0.3 # "Opens after 0.3 s inside the radius..."
const SPEED_GATE_FRACTION: float = 0.10 # "...while player speed < 10% base..."
const CHANNEL_DURATION_SECONDS: float = 0.5 # "...every purchase is a 0.5 s channel..."
const PLACEMENT_DISTANCE_PX: float = 200.0 # "...nearest edge 200 px from the Tower's centre..."
const PLACEMENT_FLIP_THRESHOLD_DEG: float = 30.0 # "...flipping only after a 30 degree change."
const CONSOLE_OPACITY: float = 0.85 # "...85% opacity..."
const CONSOLE_Z_INDEX: int = 38 # "...z_index 38 (above enemies, below telegraphs)..."
const ENTRY_FONT_SIZE_PX: int = 24 # "...text stays >= 24 px tall on screen..."

# --- Provisional Values Register > Interfaces > "Movement-only controls
# setting" (C-SECTORS) ------------------------------------------------------
const SECTOR_COUNT: int = 7 # "seven fixed 51.4 degree sectors clockwise from north"
## INTERPRETATION, named rather than silently resolved: the Register states
## 51.4 degrees, a value rounded to one decimal for display; 7 x 51.4 =
## 359.8, which would leave a 0.2 degree dead zone belonging to no sector.
## 360.0/7.0 (51.428571...) is used here so the seven sectors exactly tile a
## full circle with no gap a player could stand in and trigger nothing.
## Recorded in the evidence report, "Interpretations."
const SECTOR_WIDTH_DEG: float = 360.0 / float(SECTOR_COUNT)
const SECTOR_DWELL_SECONDS: float = 1.0 # docs/19 > Tower Console UI > Input: "Standing still ... inside a sector for 1.0 second buys one rank"

## Register > Tower Overview > "Health Recovery Rules": "One purchase
## restores min(50, missing health rounded down to an even number, 2 x Scrap
## held) health at 1 Scrap per 2 health." The 1:2 ratio itself is read live
## from `TowerDefinition.repair_price` (data/tower/base.tres), never
## hardcoded here; the "50" ceiling has no dedicated contract field to carry
## it (same pattern as this file's own CONSOLE_Z_INDEX above), so it is
## cited here as a named constant instead of a bare literal.
const REPAIR_MAX_HEAL: float = 50.0

const PLAYER_IDS: Array[String] = ["rapid_fire", "heavy_rounds", "patch_kit"]
const TOWER_IDS: Array[String] = ["caliber", "optics", "shield_matrix"]

## Sector order clockwise from north, index 0 held for Repair (handled by a
## dedicated branch, never looked up here). docs/19 > Tower Console UI >
## Input: "Repair, Rapid Fire, Heavy Rounds, Patch Kit, Caliber, Optics,
## Shield Matrix" -- the SAME order as `console_select_1..7` (below) and the
## catalogue's own first seven entries.
const SECTOR_IDS: Array[String] = ["", "rapid_fire", "heavy_rounds", "patch_kit", "caliber", "optics", "shield_matrix"]

const SELECT_ACTIONS: Array[StringName] = [
	&"console_select_1", &"console_select_2", &"console_select_3", &"console_select_4",
	&"console_select_5", &"console_select_6", &"console_select_7",
]

const MAX_LIST_ENTRIES: int = 9 # 7 fixed + Overdrive + Reinforce (C-FALLBACK-CONSOLE)

# --- Wiring (orchestrator completes; scenes/prototype.tscn is out of this
# task's write scope) --------------------------------------------------------
@export var tower_path: NodePath
@export var player_path: NodePath
@export var player_weapon_path: NodePath
@export var upgrade_system_path: NodePath
@export var camera_path: NodePath

## C-SECTORS: "Default off; offered as a hold-to-confirm choice on run-end
## screens and pause/settings menus." A plain exported property so the
## pause/settings menu (P2.14, not this task) can toggle it directly:
## `console.movement_only_controls_enabled = true`.
@export var movement_only_controls_enabled: bool = false

## See class doc, "SimLoop registration."
@export var driven_externally: bool = false

var _tower: Tower = null
var _player: Player = null
var _player_weapon: AutoWeapon = null
var _upgrade_system: UpgradeSystem = null
var _camera: GameCamera = null
## Untyped deliberately: production wiring assigns the Tower's real
## TowerInteractionRadius (an Area2D), but tests inject a lightweight double
## exposing only `is_player_inside() -> bool` (this file's own only call on
## it) so the non-pause/rules tests do not depend on a real Area2D physics
## overlap tick -- that overlap detection itself is P2.4's own scope, not
## re-tested here.
var _interaction_radius: Object = null
var _run_inventory: RunInventory = null

var _clock: Node = null
var _pause_authority: Node = null
var _event_bus: Node = null

var _paused: bool = true # updated the instant PauseAuthority's real state is known, in _ready()
var _player_is_dead: bool = false
var _was_inside_last_tick: bool = false

var _is_open: bool = false
var _requires_reentry: bool = false # Lifecycle: "After a Cancel, stays closed until the player leaves the radius and re-enters"
var _dwell_started_at: float = -1.0 # SimClock.now snapshot; -1 = not currently dwelling

var _channel_active: bool = false
var _channel_is_sector: bool = false
var _channel_list_index: int = -1
var _channel_sector_index: int = -1
var _channel_started_at: float = 0.0

var _sector_armed: Array = [true, true, true, true, true, true, true]

var _highlighted_index: int = 0
var _committed_bearing_deg: float = NAN # unset sentinel; see _update_placement()
var _panel_size_override: Vector2 = Vector2(-1.0, -1.0) # (-1,-1) = "no override, use the built panel's own size"

# --- Built UI (code-built, matching src/ui/hud.gd's own precedent) ---------
var _panel: PanelContainer = null
var _rows: Array = []
var _row_frames: Array = []
var _row_glyphs: Array = []
var _row_headers: Array = []
var _row_texts: Array = []
var _fill_bar: ProgressBar = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # see class doc, "never itself frozen"
	z_index = CONSOLE_Z_INDEX
	modulate.a = CONSOLE_OPACITY
	visible = false

	if _clock == null:
		_clock = SimClock
	if _pause_authority == null:
		_pause_authority = PauseAuthority
	if _event_bus == null:
		_event_bus = EventBus

	if _tower == null and tower_path != NodePath():
		_tower = get_node_or_null(tower_path) as Tower
	if _player == null and player_path != NodePath():
		_player = get_node_or_null(player_path) as Player
	if _player_weapon == null:
		if player_weapon_path != NodePath():
			_player_weapon = get_node_or_null(player_weapon_path) as AutoWeapon
		elif _player != null:
			_player_weapon = _player.get_node_or_null("AutoWeapon") as AutoWeapon
	if _upgrade_system == null and upgrade_system_path != NodePath():
		_upgrade_system = get_node_or_null(upgrade_system_path) as UpgradeSystem
	if _camera == null and camera_path != NodePath():
		_camera = get_node_or_null(camera_path) as GameCamera
	if _interaction_radius == null and _tower != null:
		_interaction_radius = _tower.interaction_radius

	if _pause_authority != null and _pause_authority.has_signal("reasons_changed"):
		_pause_authority.reasons_changed.connect(_on_pause_reasons_changed)
		if _pause_authority.has_method("get_active_reasons"):
			_paused = not _pause_authority.get_active_reasons().is_empty()
		else:
			_paused = false
	else:
		_paused = false

	if _event_bus != null and _event_bus.has_signal("player_died"):
		_event_bus.player_died.connect(_on_player_died)

	_build_ui()


# --- Test / orchestrator seams ----------------------------------------------

func set_tower_for_test(tower: Tower) -> void:
	_tower = tower
	if _interaction_radius == null and tower != null:
		_interaction_radius = tower.interaction_radius


func set_player_for_test(player: Player) -> void:
	_player = player


func set_player_weapon_for_test(weapon: AutoWeapon) -> void:
	_player_weapon = weapon


func set_interaction_radius_for_test(radius: Object) -> void:
	_interaction_radius = radius


func set_upgrade_system_for_test(system: UpgradeSystem) -> void:
	_upgrade_system = system


func set_camera_for_test(camera: GameCamera) -> void:
	_camera = camera


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_pause_authority_for_test(pa: Node) -> void:
	_pause_authority = pa


func set_event_bus_for_test(bus: Node) -> void:
	_event_bus = bus


## Typed COMMAND, not merely a test seam -- see class doc, "Wiring seams."
## RunInventory (P2.10) is a RefCounted, not a scene node, so no NodePath can
## find it; the orchestrator calls this once with the run's live inventory.
func set_run_inventory(inventory: RunInventory) -> void:
	_run_inventory = inventory


func set_panel_size_override_for_test(size: Vector2) -> void:
	_panel_size_override = size


func force_refresh_for_test() -> void:
	_refresh_entries_ui()
	_update_placement()


func _now() -> float:
	return _clock.now if _clock != null else 0.0


# --- Per-tick game logic (SimLoop step 12) ----------------------------------

func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


func physics_step(_delta: float) -> void:
	if _paused:
		return
	if _tower == null or _player == null or _interaction_radius == null:
		return

	var inside: bool = _interaction_radius.is_player_inside()

	# C-AUTOFIRE: "player auto-fire disabled at ANY speed while overlapping
	# the Interaction Radius ... Tower keeps firing" -- independent of
	# whether the Console itself has opened.
	if _player_weapon != null:
		_player_weapon.set_auto_fire_suppressed(inside)

	if inside and not _was_inside_last_tick:
		_requires_reentry = false # Lifecycle: "leaves the radius and re-enters" clears the post-Cancel lock
	_was_inside_last_tick = inside

	if _player_is_dead:
		if _is_open:
			_close_console(false)
		return

	if not inside:
		if _is_open:
			_close_console(false) # Lifecycle: "Closes on leaving the radius"
		_dwell_started_at = -1.0
		return

	var speed: float = _player.velocity.length()
	var base_speed: float = _player.definition.base_speed_px_per_second if _player.definition != null else 0.0
	var slow_enough: bool = base_speed <= 0.0 or speed < base_speed * SPEED_GATE_FRACTION

	if not _is_open:
		if _requires_reentry or not slow_enough or not _has_any_affordable_entry():
			_dwell_started_at = -1.0
		else:
			if _dwell_started_at < 0.0:
				_dwell_started_at = _now()
			elif _now() - _dwell_started_at >= OPEN_DWELL_SECONDS:
				_open_console()

	if _is_open:
		_process_channel(speed, base_speed)
		if movement_only_controls_enabled and not _channel_active:
			_process_sectors(slow_enough)


func _open_console() -> void:
	_is_open = true
	_dwell_started_at = -1.0
	_highlighted_index = 0
	if _event_bus != null and _event_bus.has_method("emit_console_opened"):
		_event_bus.emit_console_opened()


func _close_console(require_reentry: bool) -> void:
	_is_open = false
	_dwell_started_at = -1.0
	if require_reentry:
		_requires_reentry = true
	_reset_channel_state() # any in-progress channel is abandoned, uncharged
	if _event_bus != null and _event_bus.has_method("emit_console_closed"):
		_event_bus.emit_console_closed()


# --- Pause / death reactions (Console never WRITES pause state; it only
# reacts to it -- see class doc, point 2) ------------------------------------

func _on_pause_reasons_changed(reasons: Array) -> void:
	var has_draft: bool = false
	for r in reasons:
		if r == PauseAuthority.REASON_DRAFT:
			has_draft = true
			break
	_paused = not reasons.is_empty()
	if has_draft and _is_open:
		_close_console(false) # Lifecycle: "closes ... when a Level-Up Draft opens" -- no re-entry lock, unlike Cancel


func _on_player_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_player_is_dead = true
	_close_console(false)


# --- Input (discrete actions only; movement always drives the player
# independently -- docs/19 > Input Map: "the left stick always moves the
# player") -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _paused or not _is_open or _player_is_dead:
		return
	if event.is_action_pressed(&"console_cancel"):
		request_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"confirm"):
		start_channel_for_highlighted()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"console_cycle_next"):
		cycle(1)
		return
	if event.is_action_pressed(&"console_cycle_prev"):
		cycle(-1)
		return
	for i in range(SELECT_ACTIONS.size()):
		if event.is_action_pressed(SELECT_ACTIONS[i]):
			select_and_start_channel(i)
			return


## Typed command (Cancel: Q / B-Circle, docs/19 > Input Map).
func request_cancel() -> void:
	if not _is_open:
		return
	_close_console(true) # Lifecycle: "After a Cancel, stays closed until the player leaves the radius and re-enters"


func cycle(step_dir: int) -> void:
	if not _is_open:
		return
	var count: int = _catalogue_entries_for_list().size()
	if count <= 0:
		return
	_highlighted_index = wrapi(_highlighted_index + step_dir, 0, count)


## Number-key style: "highlight an entry and start its purchase channel
## directly" (docs/19 > Tower Console UI > Input).
func select_and_start_channel(index_in_list: int) -> bool:
	_highlighted_index = index_in_list
	return _start_channel(index_in_list)


func start_channel_for_highlighted() -> bool:
	return _start_channel(_highlighted_index)


func _start_channel(index_in_list: int) -> bool:
	if not _is_open or _channel_active:
		return false
	var entries: Array = _catalogue_entries_for_list()
	if index_in_list < 0 or index_in_list >= entries.size():
		return false
	var entry: Dictionary = entries[index_in_list]
	if not bool(entry.get("affordable", false)):
		return false
	_channel_active = true
	_channel_is_sector = false
	_channel_list_index = index_in_list
	_channel_started_at = _now()
	return true


func _process_channel(speed: float, base_speed: float) -> void:
	if not _channel_active:
		return
	if base_speed > 0.0 and speed > base_speed * SPEED_GATE_FRACTION:
		_reset_channel_state() # "moving faster than 10% of base speed before it completes cancels it without charge"
		return
	var duration: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	if _now() - _channel_started_at >= duration:
		_complete_channel()


func _complete_channel() -> void:
	if _channel_is_sector:
		var idx: int = _channel_sector_index
		var ctx: Dictionary = _sector_context(idx)
		if bool(ctx.get("affordable", false)):
			_apply_purchase(ctx)
		if idx >= 0 and idx < _sector_armed.size():
			_sector_armed[idx] = false # "a sector only re-arms after the player moves ... or leaves it"
	else:
		var entries: Array = _catalogue_entries_for_list()
		if _channel_list_index >= 0 and _channel_list_index < entries.size():
			var entry: Dictionary = entries[_channel_list_index]
			if bool(entry.get("affordable", false)):
				_apply_purchase(entry)
	_reset_channel_state()


func _reset_channel_state() -> void:
	_channel_active = false
	_channel_is_sector = false
	_channel_list_index = -1
	_channel_sector_index = -1
	_channel_started_at = 0.0


func _apply_purchase(ctx: Dictionary) -> void:
	var kind: String = String(ctx.get("kind", ""))
	var cost: int = int(ctx.get("cost", 0))
	var channel_seconds: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	if kind == "repair":
		var heal: float = float(ctx.get("heal", 0.0))
		if heal <= 0.0 or _tower == null or _tower.death_state == null:
			return
		# See class doc, "Cross-task seams": no TowerHealth.repair() command
		# exists; mirrors TowerHealth's own configure() writing this same
		# field directly.
		_tower.death_state.current_hp = minf(_tower.death_state.max_hp, _tower.death_state.current_hp + heal)
		_charge_scrap(cost)
		_emit_console_purchase("repair", channel_seconds, cost)
	elif kind == "upgrade" or kind == "fallback":
		var id: String = String(ctx.get("id", ""))
		if _upgrade_system != null and _upgrade_system.apply_rank(id):
			_charge_scrap(cost) # charged only once apply_rank() actually succeeded -- never before, never twice
			_emit_console_purchase(id, channel_seconds, cost)


## Integration task (C-TELEMETRY). Called only from the two branches above,
## only once `_charge_scrap()` has actually run for that purchase.
func _emit_console_purchase(entry_id: String, channel_seconds: float, cost: int) -> void:
	if _event_bus != null and _event_bus.has_method("emit_console_purchase"):
		_event_bus.emit_console_purchase(entry_id, channel_seconds, cost)


func _charge_scrap(cost: int) -> void:
	if _run_inventory == null or cost <= 0:
		return
	_run_inventory.scrap_current = maxi(0, _run_inventory.scrap_current - cost)


# --- Movement-only sectors (C-SECTORS) --------------------------------------

func _process_sectors(slow_enough: bool) -> void:
	var current: int = _current_sector_index()
	for i in range(SECTOR_COUNT):
		if i != current or not slow_enough:
			_sector_armed[i] = true # re-arms once the player moves fast or is not in that sector
	if current < 0 or not slow_enough or not bool(_sector_armed[current]):
		return
	var ctx: Dictionary = _sector_context(current)
	if not bool(ctx.get("affordable", false)):
		return
	_channel_active = true
	_channel_is_sector = true
	_channel_sector_index = current
	_channel_started_at = _now()


func _current_sector_index() -> int:
	if _tower == null or _player == null:
		return -1
	var bearing: float = _bearing_deg_from_north(_player.global_position - _tower.global_position)
	return clampi(int(floor(bearing / SECTOR_WIDTH_DEG)), 0, SECTOR_COUNT - 1)


func _sector_context(i: int) -> Dictionary:
	if i == 0:
		return _compute_repair()
	var pool: int = ContractEnums.PoolOwnership.Player if i <= 3 else ContractEnums.PoolOwnership.Tower
	if _upgrade_system != null and _upgrade_system.is_pool_exhausted(pool):
		var fc: UpgradeDefinition = _upgrade_system.get_fallback_card(pool)
		if fc != null:
			return _entry_for_upgrade(fc.unique_id)
	if i < 0 or i >= SECTOR_IDS.size():
		return {"kind": "none", "affordable": false}
	return _entry_for_upgrade(SECTOR_IDS[i])


func is_sector_armed_for_test(i: int) -> bool:
	return bool(_sector_armed[i]) if i >= 0 and i < _sector_armed.size() else false


func get_current_sector_index_for_test() -> int:
	return _current_sector_index()


# --- Catalogue / entries -----------------------------------------------------

func _compute_repair() -> Dictionary:
	var base: Dictionary = {
		"kind": "repair", "id": "repair", "name": "Repair",
		"pool": ContractEnums.PoolOwnership.Tower, "is_max": false,
		"heal": 0.0, "cost": 0, "affordable": false,
	}
	if _tower == null or _tower.health == null or _tower.definition == null or _tower.definition.repair_price == null:
		return base
	var rp: RepairPrice = _tower.definition.repair_price
	if rp.scrap_cost <= 0:
		return base
	var per_scrap_health: float = float(rp.health_restored) / float(rp.scrap_cost)
	var max_health: float = _tower.health.max_health
	var current_health: float = _tower.health.get_current_health()
	var missing: float = max_health - current_health
	var missing_even: float = floor(missing / 2.0) * 2.0 # "rounded down to an even number"
	var scrap_held: int = _run_inventory.scrap_current if _run_inventory != null else 0
	var max_afford_heal: float = float(scrap_held) * per_scrap_health
	var heal: float = minf(REPAIR_MAX_HEAL, minf(missing_even, max_afford_heal))
	var cost: int = int(round(heal / per_scrap_health)) if heal > 0.0 else 0
	var affordable: bool = missing >= 2.0 and scrap_held >= 1 and heal > 0.0 # C-REPAIR
	base["heal"] = heal
	base["cost"] = cost
	base["affordable"] = affordable
	return base


func _entry_for_upgrade(id: String) -> Dictionary:
	var unknown: Dictionary = {"kind": "upgrade", "id": id, "name": id, "pool": ContractEnums.PoolOwnership.Player, "is_max": false, "cost": -1, "affordable": false, "rank": 0, "max_rank": 3, "has_max_rank": true}
	if _upgrade_system == null:
		return unknown
	var def: UpgradeDefinition = _upgrade_system.get_definition(id)
	if def == null:
		# UpgradeSystem.get_console_cost() push_error()s on an unknown id
		# (by design, for a real gameplay caller); never call it for one --
		# an id absent from a deliberately-restricted test pool (or a
		# not-yet-authored id) must not spam the engine error channel every
		# tick this file's own dwell/afford checks run.
		return unknown
	var maxed: bool = _upgrade_system.is_maxed(id)
	var cost: int = _upgrade_system.get_console_cost(id)
	var scrap: int = _run_inventory.scrap_current if _run_inventory != null else 0
	var affordable: bool = (not maxed) and cost >= 0 and scrap >= cost
	return {
		"kind": "fallback" if (def != null and not def.has_max_rank) else "upgrade",
		"id": id,
		"name": (def.effect_description if def != null else id),
		"pool": (def.pool_ownership if def != null else ContractEnums.PoolOwnership.Player),
		"is_max": maxed,
		"cost": cost,
		"affordable": affordable,
		"rank": _upgrade_system.get_current_rank(id),
		"max_rank": (def.max_rank if def != null else 0),
		"has_max_rank": (def.has_max_rank if def != null else true),
	}


## The Tab/wheel/D-pad/number-key CATALOGUE: the fixed 7 (Repair + six
## upgrades) always present, PLUS a fallback entry APPENDED once its pool is
## exhausted (docs/19 > Tower Console UI > Contents: fallback cards "appear
## here" -- an addition, never a replacement of the six real entries, which
## keep showing "MAX" individually. Distinct from _sector_context(), where a
## maxed POOL repurposes its three fixed sector slots instead -- see class
## doc's sibling note and the evidence report, "Interpretations.")
func _catalogue_entries_for_list() -> Array:
	var out: Array = []
	out.append(_compute_repair())
	for id in PLAYER_IDS:
		out.append(_entry_for_upgrade(id))
	for id in TOWER_IDS:
		out.append(_entry_for_upgrade(id))
	if _upgrade_system != null:
		if _upgrade_system.is_pool_exhausted(ContractEnums.PoolOwnership.Player):
			var fc: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Player)
			if fc != null:
				out.append(_entry_for_upgrade(fc.unique_id))
		if _upgrade_system.is_pool_exhausted(ContractEnums.PoolOwnership.Tower):
			var fc2: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Tower)
			if fc2 != null:
				out.append(_entry_for_upgrade(fc2.unique_id))
	return out


func _has_any_affordable_entry() -> bool:
	for e in _catalogue_entries_for_list():
		if bool(e.get("affordable", false)):
			return true
	return false


# --- Public queries ----------------------------------------------------------

func is_open() -> bool:
	return _is_open


func get_paused_for_test() -> bool:
	return _paused


func get_requires_reentry_for_test() -> bool:
	return _requires_reentry


func is_channel_active() -> bool:
	return _channel_active


func get_channel_progress_for_test() -> float:
	if not _channel_active:
		return 0.0
	var duration: float = SECTOR_DWELL_SECONDS if _channel_is_sector else CHANNEL_DURATION_SECONDS
	return clampf((_now() - _channel_started_at) / duration, 0.0, 1.0)


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func set_highlighted_index_for_test(i: int) -> void:
	_highlighted_index = i


func get_catalogue_size_for_test() -> int:
	return _catalogue_entries_for_list().size()


func get_entry_for_test(i: int) -> Dictionary:
	var entries: Array = _catalogue_entries_for_list()
	return entries[i] if i >= 0 and i < entries.size() else {}


func get_placement_position_for_test() -> Vector2:
	return global_position


func get_committed_bearing_for_test() -> float:
	return _committed_bearing_deg


func get_scrap_current_for_test() -> int:
	return _run_inventory.scrap_current if _run_inventory != null else -1


func get_entry_label_for_test(i: int) -> Label:
	return _row_texts[i] if i >= 0 and i < _row_texts.size() else null


func get_panel_control_for_test() -> Control:
	return _panel


# --- Placement (docs/19 > Tower Console UI > "Placement") -------------------

func _process(_delta: float) -> void:
	if _paused or not _is_open:
		visible = false
		return
	visible = true
	_update_placement()
	_refresh_entries_ui()


func _update_placement() -> void:
	if _tower == null or _player == null:
		return
	var tower_pos: Vector2 = _tower.global_position
	var player_pos: Vector2 = _player.global_position
	var raw_bearing: float = _bearing_deg_from_north(player_pos - tower_pos)
	if is_nan(_committed_bearing_deg):
		_committed_bearing_deg = raw_bearing
	else:
		var diff: float = _angle_diff_deg(raw_bearing, _committed_bearing_deg)
		if absf(diff) > PLACEMENT_FLIP_THRESHOLD_DEG:
			_committed_bearing_deg = raw_bearing

	var opposite_deg: float = fposmod(_committed_bearing_deg + 180.0, 360.0)
	var dir: Vector2 = _direction_from_bearing(opposite_deg)
	var half_extent: Vector2 = _panel_half_extent()
	var denom: float = maxf(absf(dir.x) / maxf(0.0001, half_extent.x), absf(dir.y) / maxf(0.0001, half_extent.y))
	var edge_offset: float = 1.0 / maxf(0.0001, denom)
	global_position = tower_pos + dir * (PLACEMENT_DISTANCE_PX + edge_offset)

	var view_scale: float = _camera.get_view_scale() if _camera != null else 1.0
	scale = Vector2.ONE * view_scale


func _panel_half_extent() -> Vector2:
	if _panel_size_override != Vector2(-1.0, -1.0):
		return _panel_size_override / 2.0
	if _panel == null:
		return Vector2(100.0, 60.0)
	var sz: Vector2 = _panel.get_combined_minimum_size()
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Vector2(100.0, 60.0)
	_panel.size = sz
	_panel.position = -sz / 2.0
	return sz / 2.0


static func _bearing_deg_from_north(v: Vector2) -> float:
	if v.length_squared() < 0.0001:
		return 0.0
	return fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)


static func _direction_from_bearing(deg: float) -> Vector2:
	var rad: float = deg_to_rad(deg)
	return Vector2(sin(rad), -cos(rad))


static func _angle_diff_deg(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


# --- Presentation (docs/19 > UI Layout & Dynamic Container Rules: "Tower
# Console entry rows" are named explicitly as a container that must use
# Label/RichTextLabel with autowrap_mode = AUTOWRAP_WORD_SMART and
# size_flags_horizontal = SIZE_EXPAND_FILL) ----------------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	var title := _make_label(tr("CONSOLE_TITLE"), 20)
	vbox.add_child(title)

	for i in range(MAX_LIST_ENTRIES):
		var row := HBoxContainer.new()
		row.name = "Row%d" % i
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)

		var frame := Panel.new()
		frame.name = "Frame"
		frame.custom_minimum_size = Vector2(20, 20)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(frame)

		var glyph := Label.new()
		glyph.name = "Glyph"
		glyph.custom_minimum_size = Vector2(18, 0)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(glyph)

		var header := Label.new()
		header.name = "Header"
		header.custom_minimum_size = Vector2(64, 0)
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(header)

		var text := _make_label("", ENTRY_FONT_SIZE_PX)
		text.name = "Text"
		row.add_child(text)

		vbox.add_child(row)
		_rows.append(row)
		_row_frames.append(frame)
		_row_glyphs.append(glyph)
		_row_headers.append(header)
		_row_texts.append(text)

	_fill_bar = ProgressBar.new()
	_fill_bar.name = "ChannelFill"
	_fill_bar.min_value = 0.0
	_fill_bar.max_value = 1.0
	_fill_bar.show_percentage = false
	_fill_bar.custom_minimum_size = Vector2(0, 8)
	_fill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_bar.visible = false
	vbox.add_child(_fill_bar)


## docs/19 > UI Layout & Dynamic Container Rules: "must use Label or
## RichTextLabel with autowrap_mode = TextServer.AUTOWRAP_WORD_SMART and
## size_flags_horizontal = Control.SIZE_EXPAND_FILL" -- applied here so
## pseudo-localization's 30% expansion wraps and grows instead of silently
## truncating (the UI scaling test's own falsification target).
func _make_label(txt: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _refresh_entries_ui() -> void:
	var entries: Array = _catalogue_entries_for_list()
	for i in range(MAX_LIST_ENTRIES):
		var row_visible: bool = i < entries.size()
		_rows[i].visible = row_visible
		if not row_visible:
			continue
		var e: Dictionary = entries[i]
		_refresh_one_row(i, e)

	if _channel_active:
		_fill_bar.visible = true
		_fill_bar.value = get_channel_progress_for_test()
	else:
		_fill_bar.visible = false


func _refresh_one_row(i: int, e: Dictionary) -> void:
	var is_tower: bool = int(e.get("pool", 0)) == ContractEnums.PoolOwnership.Tower

	# Differentiation (docs/19 > Tower Console UI > "Differentiation": "The
	# same frame-shape and glyph rules as the Draft apply to its entries" --
	# rounded frame + glyph + header word for Player, squared for Tower,
	# never colour alone).
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.35, 0.35, 0.15, 0.85) if i == _highlighted_index else Color(0.2, 0.2, 0.25, 0.6)
	sb.set_corner_radius_all(0 if is_tower else 10)
	_row_frames[i].add_theme_stylebox_override("panel", sb)
	_row_glyphs[i].text = tr("CONSOLE_GLYPH_TOWER") if is_tower else tr("CONSOLE_GLYPH_PLAYER")
	_row_headers[i].text = tr("CONSOLE_HEADER_TOWER") if is_tower else tr("CONSOLE_HEADER_PLAYER")

	var name_text: String = String(e.get("name", ""))
	var suffix: String
	if String(e.get("kind", "")) == "repair":
		suffix = "%s (%d %s / %d %s)" % [tr("CONSOLE_REPAIR"), int(e.get("heal", 0.0)), tr("CONSOLE_HP"), int(e.get("cost", 0)), tr("CONSOLE_SCRAP")]
	elif bool(e.get("is_max", false)):
		suffix = tr("CONSOLE_MAX")
	elif bool(e.get("has_max_rank", true)):
		suffix = "%s %d %s 3 (%d %s)" % [tr("CONSOLE_RANK"), int(e.get("rank", 0)) + 1, tr("CONSOLE_OF"), int(e.get("cost", 0)), tr("CONSOLE_SCRAP")]
	else:
		suffix = "%s %d (%d %s)" % [tr("CONSOLE_TAKEN"), int(e.get("rank", 0)), int(e.get("cost", 0)), tr("CONSOLE_SCRAP")]

	_row_texts[i].text = "%s -- %s" % [name_text, suffix]
	var affordable_or_max: bool = bool(e.get("affordable", false)) or bool(e.get("is_max", false))
	_row_texts[i].modulate = Color(1, 1, 1, 1) if affordable_or_max else Color(0.55, 0.55, 0.55, 1.0)

extends Node
class_name RunFlowController

## Run Flow Controller (P2.14 - the last feature task of the Minimum
## Playable Prototype). MASTER_SDLC.md > Development Phase Map > P2.14;
## docs/19_UI_UX.md > "HUD", > "UI Layout & Dynamic Container Rules", >
## "Input Map"; Provisional Values Register > "Interfaces" (Platform input
## floor, Movement-only controls setting), > "Economy & Pickups" (Scrap).
##
## Owns the run's own state (running / paused / ended) and the transitions
## between them, and coordinates the three paused-menu surfaces this task
## builds (`PauseMenu`, `SettingsMenu`, `RunEndScreen`) so exactly one of
## them is visible at a time, driven by a single `_ui_mode` value rather
## than each screen reactively guessing whether it should be the one
## showing. `PauseAuthority` is the single source of truth for WHETHER the
## simulation is paused and WHY; this controller is the single source of
## truth for WHICH paused-menu SCREEN is on top, given that reason set.
##
## ## Death of either pool ends the run (task item 1)
## - Player: `EventBus.player_died` (exists; docs/20 > "Communication,
##   events"). Connected by signal name/string, matching
##   src/economy/run_inventory.gd's own `_connect_player_died()` precedent,
##   so this file tolerates whatever exact signal shape `player_died`
##   carries without a hard dependency on the static `.connect()` form.
## - Tower: **read directly, not through EventBus** (task brief, verbatim:
##   "The Tower's death currently still emits `enemy_died` (a known open
##   finding, F03-41) - do not fix that in a file you do not own"; LEDGER
##   F03-41: "the Tower's own death still emits `enemy_died` ... whether it
##   needs its own signal or the run-end path reads the Tower directly is
##   P2.14's to decide"). This file takes the second option: it connects
##   directly to `TowerHealth.tower_destroyed(timestamp)` -- a signal that
##   ALREADY exists, already fired exactly once at the Tower's own Logical
##   Death (src/tower/tower_health.gd's `_on_death_state_logical_death()`),
##   and is not the mislabelled `enemy_died` broadcast at all. This is the
##   seam the task brief asked for ("take the seam you need and name it in
##   your report"): no file this task does not own is touched, and F03-41
##   remains open exactly as filed -- this controller simply never listens
##   for the Tower's death on the channel that finding says is wrong.
##
## ## Reading Scrap only after it is truly final (Scrap loss test)
## `RunInventory._on_player_died()` (src/economy/run_inventory.gd, outside
## this task's write scope) zeroes `scrap_current` from its OWN listener on
## the SAME `player_died` signal this file also listens to. Godot invokes
## every connected listener for one `emit()` synchronously, in connection
## order -- if THIS controller's own listener happened to run before
## RunInventory's (an ordering this file has no control over, since it
## depends on which system's `configure()`/`_ready()` connected first), and
## it read `RunInventory.scrap_current` immediately inside that same
## listener, it could capture the PRE-zero value and cache a wrong number.
## `_on_player_died()` below therefore does no reading at all -- it only
## `call_deferred("_end_run", ...)`. A deferred call runs on the SAME
## frame's idle-call phase, strictly AFTER the `player_died.emit()` call
## that queued it has fully returned (every listener for that emission,
## RunInventory's zeroing included, has already run by then, regardless of
## connection order) -- so `_end_run()`'s own read of
## `_run_inventory.scrap_current`, later, is guaranteed to observe the
## already-zeroed value. This is the concrete mechanism behind the task
## brief's instruction: "your screen must show the zeroed value, not a
## cached one."
##
## ## Focus loss, controller disconnect, and the harness flag (task item 5)
## `_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)` pushes
## `PauseAuthority.REASON_FOCUS_LOSS` via `push_reason_immediate()` -- the
## Focus Loss Rule's own escape hatch (pause_authority.gd's header: "a
## request made BETWEEN ticks ... applies immediately") -- so the pause
## takes effect within the same frame the engine delivers the notification,
## never waiting for SimLoop's own step-14 flush (which cannot run anyway
## once the tree is paused, and does not need to run to APPLY a pause that
## has not happened yet). Getting focus back
## (`NOTIFICATION_APPLICATION_FOCUS_IN`) does nothing -- this file never
## pops `REASON_FOCUS_LOSS` on refocus. Only an explicit player action
## (pressing `pause` again, or the Pause Menu's own Resume choice) pops it,
## which is what makes "the game does not resume until the player
## confirms" true regardless of how quickly the window regains focus. A
## joypad disconnecting (`Input.joy_connection_changed(device, false)`)
## opens the exact same Pause Menu the exact same way, via
## `PauseAuthority.REASON_CONTROLLER_DISCONNECT`.
##
## `--no-focus-pause` (task item 5) disables BOTH triggers (focus loss AND
## controller disconnect) for a scripted harness run, not only the one
## named in the flag's own text -- see `_parse_harness_flags()` below for
## why both are covered by one flag and which `OS` API this file reads.
##
## ## PauseAuthority is the only pause writer this file uses (CLAUDE.md;
## docs/20 > "Communication, commands")
## Every push/pop below goes through `PauseAuthority.push_reason[_immediate]
## ()` / `pop_reason[_immediate]()`. `REASON_PAUSE_MENU`, `REASON_FOCUS_LOSS`,
## and `REASON_CONTROLLER_DISCONNECT` are PauseAuthority's own named
## constants (docs/20 > Global Simulation Authority's canonical five).
## `REASON_RUN_ENDED` (below) is NOT one of those five -- PauseAuthority's
## own header states "any StringName is accepted, the five constants below
## are just typo-proof names for the canonical ones," so accepting a sixth,
## project-local reason requires no change to `pause_authority.gd` (outside
## this task's write scope) at all. Named as an interpretation extending
## the reason vocabulary, not a Register-defined reason, in the P2.14
## evidence report.
##
## ## Cross-task seams this file could not close itself (hard constraints:
## src/director/**, src/economy/**, src/tower/**, src/player/**,
## src/ui/hud*.gd, src/ui/console.gd are off limits this session)
## - `WaveDirector` exposes no non-test-suffixed "current wave number"
##   query -- only `get_current_wave_index_for_test()`. This file calls
##   that method anyway (it is the only seam available) to populate the
##   run-end screen's "wave reached" field and to record a final wave
##   index; a proper `WaveDirector.get_current_wave_display_index()` (or
##   similar, non-test-named) query is named as a required seam in the
##   P2.14 evidence report. The SAME gap means `src/ui/hud_economy_state.gd`
##   > `wave_current` (which the live HUD's "Wave n/8" field reads,
##   src/ui/hud.gd `_refresh_tower_health()`) is never actually driven by
##   the real WaveDirector by anything in this codebase as of this task --
##   also named there.
## - `Console.movement_only_controls_enabled` is a plain exported bool with
##   no setter command; `SettingsMenu.set_console_ref()` writes it directly,
##   matching the Console's own header, which already documents this exact
##   call shape as the pause/settings menu's intended seam.
## - Wiring `tower_path`/`wave_director_path`/the Console reference/the
##   RunInventory instance into the assembled run scene is the
##   orchestrator's job (`scenes/prototype.tscn` is outside this task's
##   write scope) -- named as a required seam in the P2.14 evidence report,
##   exactly like every other P2.x task's own standalone-until-wired
##   deliverable.

enum State { RUNNING, PAUSED, ENDED }
## ABANDONED (Meta layer core; decision D113): the pause menu's Main Menu
## choice, or the window closing, while the run is still live -- see
## `_on_main_menu_requested()` / `_on_close_requested()` below. Settles as a
## failure (MetaProgress.settle_run()'s own `victory` field is false), same
## as PLAYER_DEFEATED/TOWER_DESTROYED.
enum EndCause { NONE, PLAYER_DEFEATED, TOWER_DESTROYED, SEQUENCE_COMPLETED, ABANDONED }
enum UiMode { NONE, PAUSE, SETTINGS_FROM_PAUSE, SETTINGS_FROM_RUN_END, RUN_END }

## Not one of PauseAuthority's five canonical reasons -- see class header.
const REASON_RUN_ENDED: StringName = &"run_ended"

## Cited to docs/19 > "Input Map" (harness flags parsed as user args) and to
## this task's own brief: "Parse the flag from
## OS.get_cmdline_user_args() / OS.get_cmdline_args()". No Register row
## assigns a flag SPELLING (this is a harness/CLI concern, not a gameplay
## number), so the literal string is a named constant here rather than a
## Register citation.
const NO_FOCUS_PAUSE_FLAG: String = "--no-focus-pause"

@export var tower_path: NodePath
@export var wave_director_path: NodePath
@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
@export var settings_menu_scene: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
@export var run_end_scene: PackedScene = preload("res://scenes/ui/run_end.tscn")

var pause_menu: PauseMenu = null
var settings_menu: SettingsMenu = null
var run_end_screen: RunEndScreen = null

var _tower: Tower = null
var _wave_director: Object = null
var _run_inventory: RunInventory = null
var _console: Console = null

var _pause_authority: Node = PauseAuthority
var _event_bus: Object = EventBus
var _sim_clock: Node = SimClock

var _state: int = State.RUNNING
var _ui_mode: int = UiMode.NONE
var _settings_return_mode: int = UiMode.PAUSE

var _run_start_sim_time: float = 0.0
var _end_cause: int = EndCause.NONE
var _end_sim_time: float = 0.0
var _final_wave_index: int = -1
var _final_wave_total: int = 0

var _focus_pause_disabled: bool = false

## Test-only: suppresses the real `get_tree().quit()` call inside
## `_on_close_requested()` so a test can drive
## `simulate_close_requested_for_test()` (which exercises the SAME method a
## real NOTIFICATION_WM_CLOSE_REQUEST would) without killing the test
## runner's own process. Never true in real play.
var _suppress_quit_for_test: bool = false

## Meta layer core (Register > "Meta: Run-End Settlement (prototype)": "one
## real run id" + "settled once per run id"). Generated once per run, from
## wall-clock time + a random int -- this is a de-duplication KEY for
## MetaProgress.settle_run(), never a gameplay/determinism seed, so wall
## clock is fine here (contrast SimClock.now, used for every actual
## gameplay timestamp in this file).
var _run_id: String = ""

## Meta layer core: incremented on every EventBus.enemy_died this run, for
## the Run-End Settlement's "1 Core per 25 enemies killed" term.
var _kill_count: int = 0
## Meta layer core: incremented on every WaveDirector.wave_ended this run,
## for the Settlement's "2 Cores per wave fully cleared" term. Deliberately
## a count of ENDED waves, not `_final_wave_index` ("wave reached") -- a wave
## still in progress when the run ends has not been cleared.
var _waves_cleared: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_focus_pause_disabled = _flag_present(OS.get_cmdline_user_args()) or _flag_present(OS.get_cmdline_args())
	_run_id = "run_%d_%d" % [Time.get_unix_time_from_system(), randi()]
	# Meta layer core (build brief item 4): "Window close during a run ...
	# = settle as abandon, save, quit." The engine's default (true) would
	# close the window immediately, before `_on_close_requested()` below
	# ever runs. Reset to true the instant the run ends (`_end_run()`) or
	# this scene is left (`_on_main_menu_requested()`/
	# `_on_continue_requested()`), so a close from the run-end screen, the
	# Hub, or the title uses the engine's ordinary immediate-quit behaviour.
	get_tree().auto_accept_quit = false
	_resolve_dependencies()
	_build_ui()
	_connect_signals()
	_run_start_sim_time = _now()


func _resolve_dependencies() -> void:
	if tower_path != NodePath():
		_tower = get_node_or_null(tower_path) as Tower
	if wave_director_path != NodePath():
		_wave_director = get_node_or_null(wave_director_path)


func _build_ui() -> void:
	if pause_menu == null and pause_menu_scene != null:
		pause_menu = pause_menu_scene.instantiate() as PauseMenu
		add_child(pause_menu)
	if settings_menu == null and settings_menu_scene != null:
		settings_menu = settings_menu_scene.instantiate() as SettingsMenu
		add_child(settings_menu)
	if run_end_screen == null and run_end_scene != null:
		run_end_screen = run_end_scene.instantiate() as RunEndScreen
		add_child(run_end_screen)
	if pause_menu != null:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.settings_requested.connect(_on_open_settings_from_pause)
		pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	if settings_menu != null:
		settings_menu.closed.connect(_on_settings_closed)
		if _console != null:
			settings_menu.set_console_ref(_console)
	if run_end_screen != null:
		run_end_screen.settings_requested.connect(_on_open_settings_from_run_end)
		run_end_screen.main_menu_requested.connect(_on_main_menu_requested)
		run_end_screen.continue_requested.connect(_on_continue_requested)
	_refresh_ui_visibility()


func _connect_signals() -> void:
	if _pause_authority != null and _pause_authority.has_signal(&"reasons_changed"):
		if not _pause_authority.reasons_changed.is_connected(_on_pause_reasons_changed):
			_pause_authority.reasons_changed.connect(_on_pause_reasons_changed)
	_connect_player_died()
	_connect_tower_destroyed()
	_connect_sequence_completed()
	_connect_enemy_died_for_meta()
	_connect_wave_ended_for_meta()
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _connect_player_died() -> void:
	if _event_bus == null or not _event_bus.has_signal("player_died"):
		return
	var callable: Callable = Callable(self, "_on_player_died")
	if not _event_bus.is_connected("player_died", callable):
		_event_bus.connect("player_died", callable)


## Meta layer core: see `_kill_count`'s own field comment.
func _connect_enemy_died_for_meta() -> void:
	if _event_bus == null or not _event_bus.has_signal("enemy_died"):
		return
	var callable: Callable = Callable(self, "_on_enemy_died_for_meta")
	if not _event_bus.is_connected("enemy_died", callable):
		_event_bus.connect("enemy_died", callable)


func _on_enemy_died_for_meta(_entity: Variant = null, _position: Variant = null, _timestamp: Variant = null) -> void:
	_kill_count += 1


## Meta layer core: see `_waves_cleared`'s own field comment.
func _connect_wave_ended_for_meta() -> void:
	if _wave_director != null and _wave_director.has_signal(&"wave_ended"):
		if not _wave_director.wave_ended.is_connected(_on_wave_ended_for_meta):
			_wave_director.wave_ended.connect(_on_wave_ended_for_meta)


func _on_wave_ended_for_meta(_wave_id: String, _wave_index: int) -> void:
	_waves_cleared += 1


func _connect_tower_destroyed() -> void:
	if _tower != null and _tower.health != null:
		if not _tower.health.tower_destroyed.is_connected(_on_tower_destroyed):
			_tower.health.tower_destroyed.connect(_on_tower_destroyed)


func _connect_sequence_completed() -> void:
	if _wave_director != null and _wave_director.has_signal(&"sequence_completed"):
		if not _wave_director.sequence_completed.is_connected(_on_sequence_completed):
			_wave_director.sequence_completed.connect(_on_sequence_completed)


# --- Test / orchestrator seams (project convention: set_*_for_test(),
# default to the real thing; the RunInventory/Console setters are also
# genuine production commands -- see class header) --------------------------

func set_tower_for_test(tower: Tower) -> void:
	_tower = tower
	_connect_tower_destroyed()


func set_wave_director_for_test(wd: Object) -> void:
	if _wave_director != null and _wave_director.has_signal(&"sequence_completed") and _wave_director.sequence_completed.is_connected(_on_sequence_completed):
		_wave_director.sequence_completed.disconnect(_on_sequence_completed)
	if _wave_director != null and _wave_director.has_signal(&"wave_ended") and _wave_director.wave_ended.is_connected(_on_wave_ended_for_meta):
		_wave_director.wave_ended.disconnect(_on_wave_ended_for_meta)
	_wave_director = wd
	_connect_sequence_completed()
	_connect_wave_ended_for_meta()


func set_run_inventory(inventory: RunInventory) -> void:
	_run_inventory = inventory


func set_console_ref(console: Console) -> void:
	_console = console
	if settings_menu != null:
		settings_menu.set_console_ref(console)


func set_pause_authority_for_test(pa: Node) -> void:
	if _pause_authority != null and _pause_authority.has_signal(&"reasons_changed") and _pause_authority.reasons_changed.is_connected(_on_pause_reasons_changed):
		_pause_authority.reasons_changed.disconnect(_on_pause_reasons_changed)
	_pause_authority = pa
	if _pause_authority != null and _pause_authority.has_signal(&"reasons_changed"):
		if not _pause_authority.reasons_changed.is_connected(_on_pause_reasons_changed):
			_pause_authority.reasons_changed.connect(_on_pause_reasons_changed)


func set_event_bus_for_test(bus: Object) -> void:
	_event_bus = bus
	_connect_player_died()
	_connect_enemy_died_for_meta()


func set_sim_clock_for_test(clock: Node) -> void:
	_sim_clock = clock


func set_focus_pause_disabled_for_test(disabled: bool) -> void:
	_focus_pause_disabled = disabled


func is_focus_pause_disabled_for_test() -> bool:
	return _focus_pause_disabled


func set_suppress_quit_for_test(suppress: bool) -> void:
	_suppress_quit_for_test = suppress


func get_state_for_test() -> int:
	return _state


func get_ui_mode_for_test() -> int:
	return _ui_mode


func get_end_cause_for_test() -> int:
	return _end_cause


func get_run_id_for_test() -> String:
	return _run_id


func get_kill_count_for_test() -> int:
	return _kill_count


func get_waves_cleared_for_test() -> int:
	return _waves_cleared


func is_auto_accept_quit_disabled_for_test() -> bool:
	return not get_tree().auto_accept_quit


## Pure function, tested directly against constructed argument arrays --
## see class header for why the real `OS.get_cmdline_user_args()`/
## `get_cmdline_args()` read cannot itself be exercised from inside a
## gdUnit4 suite running in the same process (there is no second launch to
## pass the flag to).
static func _flag_present(args: PackedStringArray) -> bool:
	return args.has(NO_FOCUS_PAUSE_FLAG)


# --- Test-only direct triggers for the notifications/signals this file
# otherwise only receives from the real engine/OS (focus, joypad) ----------

func simulate_focus_out_for_test() -> void:
	_on_focus_out()


func simulate_controller_disconnected_for_test(device: int = 0) -> void:
	_on_joy_connection_changed(device, false)


func simulate_pause_pressed_for_test() -> void:
	_on_pause_action_pressed()


func simulate_player_died_for_test() -> void:
	_on_player_died()


func simulate_tower_destroyed_for_test() -> void:
	_on_tower_destroyed(_now())


func simulate_sequence_completed_for_test() -> void:
	_on_sequence_completed()


func simulate_close_requested_for_test() -> void:
	_on_close_requested()


func simulate_main_menu_requested_for_test() -> void:
	_on_main_menu_requested()


func simulate_continue_requested_for_test() -> void:
	_on_continue_requested()


# --- Input ("pause" action, docs/19 > Input Map: "Pause Escape / Start") ---

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.ENDED:
		return
	if event.is_action_pressed(&"pause"):
		_on_pause_action_pressed()
		get_viewport().set_input_as_handled()


func _on_pause_action_pressed() -> void:
	if _pause_authority != null and _pause_authority.has_method(&"has_reason") and _pause_authority.has_reason(PauseAuthority.REASON_DRAFT):
		return # the Draft has no Cancel and must always resolve -- see class header
	if _ui_mode == UiMode.PAUSE:
		_on_resume_requested()
	elif _ui_mode == UiMode.SETTINGS_FROM_PAUSE:
		_on_settings_closed()
	elif _ui_mode == UiMode.NONE:
		_pause_authority.push_reason_immediate(PauseAuthority.REASON_PAUSE_MENU)


# --- Focus loss / controller disconnect ------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_out()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()


## Meta layer core (build brief item 4): "Window close during a run
## ... = settle as abandon, save, quit." `MetaProgress.settle_run()` is
## synchronous (a blocking `FileAccess` write, per that Autoload's own
## header) and "commits before returning" per the Register, so the save is
## guaranteed complete before `get_tree().quit()` runs below. A close AFTER
## the run has already ended (`_state == State.ENDED`) needs no settlement
## of its own -- the real end (death/tower/sequence/abandon-via-pause) has
## already settled through `_end_run()`, and re-settling would be a no-op
## anyway (MetaProgress.settle_run() is idempotent by run id) but is skipped
## here to avoid a redundant disk write on every ordinary quit from the
## run-end screen.
func _on_close_requested() -> void:
	if _state != State.ENDED:
		MetaProgress.settle_run(_build_run_summary(false, true))
	if not _suppress_quit_for_test:
		get_tree().quit()


func _on_focus_out() -> void:
	if _focus_pause_disabled or _state == State.ENDED:
		return
	_pause_authority.push_reason_immediate(PauseAuthority.REASON_FOCUS_LOSS)


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected or _focus_pause_disabled or _state == State.ENDED:
		return
	_pause_authority.push_reason_immediate(PauseAuthority.REASON_CONTROLLER_DISCONNECT)


# --- PauseAuthority reactions (one writer -- RunFlowController itself for
# the three menu-ish reasons; this handler only decides which SCREEN to
# show, mirroring src/ui/console.gd's "react, never cause" discipline for
# every OTHER reason it does not itself own) ---------------------------------

func _on_pause_reasons_changed(reasons: Array) -> void:
	if _state == State.ENDED:
		return
	var menu_reason_active: bool = false
	for r in reasons:
		if r == PauseAuthority.REASON_PAUSE_MENU or r == PauseAuthority.REASON_FOCUS_LOSS or r == PauseAuthority.REASON_CONTROLLER_DISCONNECT:
			menu_reason_active = true
			break
	if menu_reason_active and _ui_mode == UiMode.NONE:
		_ui_mode = UiMode.PAUSE
		_refresh_ui_visibility()
	elif not menu_reason_active and (_ui_mode == UiMode.PAUSE or _ui_mode == UiMode.SETTINGS_FROM_PAUSE):
		_ui_mode = UiMode.NONE
		_refresh_ui_visibility()


func _on_resume_requested() -> void:
	_pause_authority.pop_reason_immediate(PauseAuthority.REASON_PAUSE_MENU)
	_pause_authority.pop_reason_immediate(PauseAuthority.REASON_FOCUS_LOSS)
	_pause_authority.pop_reason_immediate(PauseAuthority.REASON_CONTROLLER_DISCONNECT)
	_ui_mode = UiMode.NONE
	_refresh_ui_visibility()


func _on_open_settings_from_pause() -> void:
	_settings_return_mode = UiMode.PAUSE
	_ui_mode = UiMode.SETTINGS_FROM_PAUSE
	_refresh_ui_visibility()


func _on_open_settings_from_run_end() -> void:
	_settings_return_mode = UiMode.RUN_END
	_ui_mode = UiMode.SETTINGS_FROM_RUN_END
	_refresh_ui_visibility()


func _on_settings_closed() -> void:
	_ui_mode = _settings_return_mode
	_refresh_ui_visibility()


## "Main Menu" (title screen + credits session): returns to
## res://scenes/title.tscn from either the pause menu or the run-end
## screen (src/ui/pause_menu.gd / src/ui/run_end.gd's own
## `main_menu_requested`, connected to this same handler above -- neither
## file owns a scene change or a PauseAuthority write of its own, matching
## every other option on both screens).
##
## Every active PauseAuthority reason is popped, immediately, BEFORE the
## scene change -- a scene change while `get_tree().paused` is still true
## would hand the fresh title scene a tree that is already paused, and
## PauseAuthority (the only writer of that flag; src/core/
## pause_authority.gd's own header) would have no reason left active to
## ever pop it back once the run that pushed those reasons is gone.
## `get_active_reasons()` is read fresh rather than popping only the small
## set this file itself pushes (REASON_PAUSE_MENU, REASON_RUN_ENDED) so
## REASON_FOCUS_LOSS / REASON_CONTROLLER_DISCONNECT / REASON_DRAFT are also
## cleared if any happened to still be active, with no separate list here
## to go stale later.
##
## No per-run autoload state needs a matching reset here, named rather than
## silently assumed: RunInventory and this controller itself are scene-local
## nodes (not autoloads) and are freed with the rest of scenes/prototype.tscn
## by `change_scene_to_file()`; EntityRegistry (an autoload) already
## self-heals slots for entities freed without deregistering (LEDGER
## F02-15, src/core/entity_registry.gd); and SimClock deliberately never
## resets its own `now` at runtime (that file's own header: "SimClock never
## resets its own `now`... a test suite that needs a fresh clock value
## builds its own throwaway instance instead"). There was no pre-existing
## "restart" path anywhere in this codebase to mirror (grepped; none
## exists) -- this is the first flow that ever returns to a scene capable
## of starting a second run in the same process.
## Meta layer core (decision D109/D113): "Abandon via the pause menu's Main
## Menu = failure settlement, then show the run-end screen (not straight to
## the title)." The run-end screen's OWN "Main Menu" choice (see
## `_on_continue_requested()`'s sibling below) reaches this SAME handler
## too (class header, "the same handler" -- both `PauseMenu.main_menu_
## requested` and `RunEndScreen.main_menu_requested` connect here) but by
## then `_state == State.ENDED` already, so the branch below tells the two
## apart: a live run (RUNNING/PAUSED) means this call came from the PAUSE
## menu and is an abandon; an already-ended run means it came from the
## RUN-END screen itself, after settlement has already happened once, and
## proceeds straight to the title exactly as before.
func _on_main_menu_requested() -> void:
	if _state != State.ENDED:
		_end_run(EndCause.ABANDONED)
		return
	for reason in _pause_authority.get_active_reasons():
		_pause_authority.pop_reason_immediate(reason)
	get_tree().change_scene_to_file("res://scenes/title.tscn")


## Meta layer core (build brief item 4): the run-end screen's new
## "Continue" choice -> the Hub. Only reachable once `_state == State.ENDED`
## (the run-end screen is not visible otherwise), so settlement has always
## already happened by the time this fires -- mirrors `_on_main_menu_
## requested()`'s own pause-reason-clearing shape exactly, targeting
## `scenes/hub.tscn` instead of `scenes/title.tscn`.
func _on_continue_requested() -> void:
	for reason in _pause_authority.get_active_reasons():
		_pause_authority.pop_reason_immediate(reason)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _refresh_ui_visibility() -> void:
	if pause_menu != null:
		pause_menu.set_active(_ui_mode == UiMode.PAUSE)
	if settings_menu != null:
		settings_menu.set_active(_ui_mode == UiMode.SETTINGS_FROM_PAUSE or _ui_mode == UiMode.SETTINGS_FROM_RUN_END)
	if run_end_screen != null:
		run_end_screen.set_active(_ui_mode == UiMode.RUN_END)


# --- Run end (death of either pool, or the full wave sequence completing) --

func _now() -> float:
	return _sim_clock.now if _sim_clock != null else 0.0


func _on_player_died(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	call_deferred("_end_run", EndCause.PLAYER_DEFEATED)


func _on_tower_destroyed(_timestamp: float = 0.0) -> void:
	call_deferred("_end_run", EndCause.TOWER_DESTROYED)


func _on_sequence_completed() -> void:
	call_deferred("_end_run", EndCause.SEQUENCE_COMPLETED)


func _end_run(cause: int) -> void:
	if _state == State.ENDED:
		return
	_state = State.ENDED
	_end_cause = cause
	_end_sim_time = _now()
	_capture_final_wave()
	# Meta layer core: the run is over one way or another from here on --
	# see the field comment on `_suppress_quit_for_test`'s sibling,
	# `_run_id`'s block, and `_ready()`'s own comment on this same line.
	get_tree().auto_accept_quit = true
	_pause_authority.push_reason_immediate(REASON_RUN_ENDED)
	_ui_mode = UiMode.RUN_END
	_refresh_ui_visibility()

	# Meta layer core (build brief item 4): settle BEFORE the run-end screen
	# shows, per the Register's own "committed to disk before the run-end
	# screen shows" (Meta: Run-End Settlement (prototype)). `victory` is
	# true only for the one END path that means the player actually won
	# (the full wave sequence completed with nobody dead); every other
	# cause, ABANDONED included, settles as a failure (no final-wave bonus),
	# per D110/D113.
	var victory: bool = cause == EndCause.SEQUENCE_COMPLETED
	var abandoned: bool = cause == EndCause.ABANDONED
	var breakdown: Dictionary = MetaProgress.settle_run(_build_run_summary(victory, abandoned))

	if run_end_screen != null:
		run_end_screen.show_summary(_build_summary())
		run_end_screen.set_settlement(breakdown)


## Meta layer core. `run_summary` keys match `MetaProgress.settle_run()`'s
## own documented contract exactly (that file's header): `run_id`,
## `sim_time_seconds`, `waves_cleared`, `kills`, `victory`, `abandoned`.
func _build_run_summary(victory: bool, abandoned: bool) -> Dictionary:
	return {
		"run_id": _run_id,
		"sim_time_seconds": maxf(0.0, _now() - _run_start_sim_time),
		"waves_cleared": _waves_cleared,
		"kills": _kill_count,
		"victory": victory,
		"abandoned": abandoned,
	}


## `WaveDirector._current_wave_index` (read through the only available
## seam, `get_current_wave_index_for_test()` -- see class header,
## "Cross-task seams") is a raw, 0-based ARRAY index into `waves[]`,
## confirmed by reading that file directly (`_current_wave_index: int = -1`
## before any wave opens, `0` for the first). docs/19 > "HUD" and this
## task's own exit criterion both speak of wave numbers the HUMAN way --
## "Wave n/8", "reaches wave eight" -- so `_final_wave_index` here is
## already converted to that 1-based display number; nothing else in this
## file ever reads the raw 0-based index back out.
func _capture_final_wave() -> void:
	if _wave_director != null and _wave_director.has_method(&"get_current_wave_index_for_test"):
		var raw_index: int = int(_wave_director.get_current_wave_index_for_test())
		_final_wave_index = raw_index + 1 if raw_index >= 0 else -1
	var waves: Variant = _wave_director.get("waves") if _wave_director != null else null
	if waves is Array:
		_final_wave_total = (waves as Array).size()


func _build_summary() -> Dictionary:
	var cause_text: String = ""
	if _end_cause == EndCause.PLAYER_DEFEATED:
		cause_text = tr("RUN_END_CAUSE_PLAYER")
	elif _end_cause == EndCause.TOWER_DESTROYED:
		cause_text = tr("RUN_END_CAUSE_TOWER")
	elif _end_cause == EndCause.ABANDONED:
		# Meta layer core (D113). No UiStrings/tr() key exists for this cause
		# (src/ui/theme/* -- where every OTHER cause's key is registered --
		# is off limits this session; see this file's own header for the
		# HUD-visuals agent's exclusive scope). A literal English string,
		# named here as a follow-up seam for whoever next owns
		# src/ui/theme/ui_strings.gd to promote to a real
		# RUN_END_CAUSE_ABANDONED key, exactly like every other cause line.
		cause_text = "Run abandoned"
	# EndCause.SEQUENCE_COMPLETED intentionally leaves cause_text empty --
	# see class header, "The death cause or the final wave reached."

	var scrap_held: int = _run_inventory.scrap_current if _run_inventory != null else 0
	var survived: float = maxf(0.0, _end_sim_time - _run_start_sim_time)

	return {
		"cause_text": cause_text,
		"wave_reached": _final_wave_index,
		"wave_total": _final_wave_total,
		"scrap_held": scrap_held,
		"time_survived_seconds": survived,
	}


func get_summary_for_test() -> Dictionary:
	return _build_summary()

extends CanvasLayer
class_name DraftController

## Level-Up Draft (P2.12; MASTER_SDLC.md > Provisional Values Register >
## "Progression & Upgrades" > "Level-Up Draft", "Draft card display", "Draft
## input" rows; > "Spawning & Waves" > "XP & levels"; > "Interfaces" >
## "Platform input floor"; docs/19_UI_UX.md > "Upgrade Draft UI &
## Navigation" in full). CHANGE 2 (Author decision D108, 2026-09-23) removed
## the Register's former "Teaching wave XP (C-XPCAP)" row entirely -- see
## this file's own "CHANGE 2" class-doc section below.
##
## ## Two clocks, deliberately, and why (open contradiction -- flagged for
## the author, not silently resolved)
## SimClock is PROCESS_MODE_PAUSABLE (src/core/sim_clock.gd's own header:
## "the engine itself stops calling _physics_process on this node while
## PauseAuthority pauses the tree") and the Pause authority test asserts
## exactly that: "SimClock.now stops under pause and resumes exactly." The
## Level-Up Draft's own job is to run WHILE the simulation it just paused is
## frozen -- its 0.4 s input lockout, 0.3 s cycle repeat, and 1.0 s
## hold-to-confirm ring all have to keep counting during that freeze, or the
## Draft could never resolve. A literal "all timing on SimClock" is
## therefore unsatisfiable for this one system: SimClock cannot be both the
## clock that freezes for the Draft and the clock the Draft uses to time its
## own unfreezing. This mirrors PauseAuthority's own stated reason for being
## PROCESS_MODE_ALWAYS ("it has to, since it is the one thing able to
## unpause it") -- the Draft is the one UI system that has to keep timing
## while everything else is frozen, in order to ever close.
##
## Resolution taken here, named rather than silently chosen: this node is
## PROCESS_MODE_ALWAYS (like PauseAuthority, EventBus, Hud, UiSfx -- all
## already PROCESS_MODE_ALWAYS and already outside the gameplay root, per
## docs/20 > Scene Tree: "Nothing under the gameplay root may set
## PROCESS_MODE_ALWAYS"; this CanvasLayer is likewise never placed under the
## gameplay root) and accumulates its OWN elapsed-time counter
## (`_time_since_open`) from `_process(delta)`'s own per-frame `delta` --
## never `get_tree().create_timer()`/`create_tween()` for this controller's
## OWN input-timing accumulator (the specifically banned APIs for
## game-state/input timing; P1.1's grep check targets exactly those two
## calls under the gameplay root, not a plain float accumulator on a menu
## CanvasLayer). That ban is about `get_tree()`-rooted timing standing in
## for SimClock/PauseAuthority; it does NOT reach a bare, node-bound
## `create_tween()` used purely for this surface's cosmetic motion --
## MASTER_SDLC.md ("Determinism where it matters"): "`Node.create_tween()`
## is permitted for cosmetic animation only, since a tween bound to a
## paused node pauses with it. All of these remain permitted in pure UI,
## which is not bound by SimClock," and P1.1's own banned-API grep check is
## scoped "under the gameplay root ... Out: UI". src/ui/draft_card_view.gd's
## highlight-lift and card-entrance tweens (UI Pass) are exactly that
## permitted case -- named here so this header does not read as forbidding
## them. Never SimClock.now either. This is real elapsed time, not a simulation-time
## value -- an open question for the author is whether a future phase should
## give SimClock a second, non-pausable "menu time" instead of each paused
## menu (Draft here; the pause menu and Console purchase-channel in P2.13/
## P2.14) inventing its own accumulator. Recorded here and in the P2.12
## evidence report rather than resolved unilaterally, parallel to the
## existing open AudioDucking/PROCESS_MODE_ALWAYS contradiction (Carried
## Lesson 6).
##
## The Console's own 0.5 s purchase channel (P2.13) is NOT in this
## situation -- the Console never pauses, so SimClock keeps ticking for it
## and it can use SimClock.now directly, per the Risk Register's "Console
## non-pause test as the inverse check, confirming the Console's own
## channel timer keeps running under SimClock."
##
## ## CHANGE 2 (author decision D108, 2026-09-23): faster levelling, no more
## teaching-wave suppression
## The level curve moved from 10 + 5(L+1) XP to 5 + 3(L+1) XP (8, 11, 14,
## 17... -- data/economy/prototype.tres, src/data/xp_level_cost.gd). The
## teaching-wave XP cap (C-XPCAP, formerly `xp_cap_during_teaching_waves` on
## EconomyConfiguration -- that field is now REMOVED, not merely unused) and
## the level-up suppression it enforced during T1-T4 are both gone: a
## level-up now fires exactly the same way whether the current wave is
## teaching or combat. `physics_step()` therefore always calls
## `_check_for_new_level_up_requests()` unconditionally -- the old
## `_is_teaching_wave_active()` branch, `_enforce_xp_cap_and_revert_
## erroneous_level_up()`, and `_teaching_xp_cap()` are deleted rather than
## kept dead, since nothing calls them any more. The forced first
## Level-Up Draft at T4's end (`_on_wave_ended()`, `_grant_forced_level()`,
## `_is_last_teaching_wave()`, and this node's own `wave_ended` signal
## connection) is deleted too, per this task's own recommendation: the
## faster curve typically brings the player's first REAL level-up naturally
## within the teaching waves, so a second, artificial "first Draft" trigger
## would leave two mechanisms fighting over which one is really first. This
## reverses D37's own rationale (a level-up mid-teaching-wave would pause
## the simulation and interrupt the lesson) -- see D108's own row for the
## alternatives weighed. `_wave_director`'s `notify_draft_closed()` call
## (the post-Draft grace period hook, unrelated to teaching waves) is
## UNCHANGED and still wired exactly as before.
##
## ## Two responsibilities, one node, two entry points
## 1. `physics_step(delta)` -- called by SimLoop at step 11
##    (XP_AND_LEVEL_UP_REQUESTS, docs/20 > "SimLoop order") via the
##    `register(step, node)` API (src/core/sim_loop.gd, F03-09). Runs only
##    while UNPAUSED (SimLoop is PROCESS_MODE_PAUSABLE and simply never gets
##    a `_physics_process` call while the tree is paused, so this method
##    naturally cannot fire while a Draft it opened is on screen -- no extra
##    "already open" guard is needed against re-entering from this path).
##    Detects new level-ups and queues a Draft request for each one, exactly
##    the same during a teaching wave as during a combat wave (CHANGE 2,
##    D108, above -- there is no longer a teaching-wave branch here at all).
## 2. `_process(delta)` -- this node's own PROCESS_MODE_ALWAYS loop, the
##    only thing still running once the tree is paused. Reads input, drives
##    the lockout/arming/repeat/hold timers, and resolves a Draft on
##    confirm.
##
## ## Unpausing from inside the pause it caused
## SimLoop cannot call `PauseAuthority.flush()` (step 14) while the tree is
## already paused (it is PROCESS_MODE_PAUSABLE and gets no
## `_physics_process` call at all during pause) -- so once the LAST queued
## Draft in a session resolves, this node calls
## `PauseAuthority.pop_reason_immediate()` directly (queue + flush in one
## call, the same escape hatch pause_authority.gd documents for the Focus
## Loss Rule) rather than relying on the normal step-14 path, which would
## never run.
##
## ## Cross-task seams (named, not silently invented)
## - `pickup_system_path` resolves to the live `PickupSystem` (P2.10) whose
##   `.run_inventory` field IS the real `RunInventory` this task reads/
##   reverts; there is no separate RunInventory instance to construct.
## - `upgrade_system_path` / `wave_director_path` / `ui_sfx_path` resolve
##   the same way, all left for the orchestrator's scene assembly (this
##   task's write scope forbids editing scenes/prototype.tscn or the
##   systems themselves).
## - `run_seed` MUST be set to the SAME value as `WaveDirector.run_seed`
##   (and RunRecorder's run seed) by whoever assembles the run scene, or
##   the Determinism test's premise (one run seed governs every keyed
##   roll) does not hold across systems. Named in the P2.12 evidence report.
## - `_wave_director` is read by DUCK TYPING (`has_method()` on a plain
##   Object), not a static `WaveDirector` type, so an isolated unit test can
##   substitute a small fake exposing only `notify_draft_closed()` (see
##   tests/unit/draft_fake_wave_director.gd) instead of constructing a full
##   WaveDirector with every one of its own dependencies just to test this
##   file. CHANGE 2 (D108): this fake ALSO still exposes
##   `teaching_wave_unique_ids`/`get_current_wave_id()`/`wave_ended` for the
##   suites that use them to set up a "current wave is a teaching wave"
##   scenario (xp_cap_check_test.gd, guaranteed_first_draft_test.gd) -- this
##   file itself no longer reads any of the three, which is exactly what
##   those suites now prove (setting the fake's wave id has no effect on
##   whether a level-up fires).

## Register > "Draft input": "0.4 s input lockout on open".
const LOCKOUT_SECONDS: float = 0.4
## Register > "Draft input": "left/right cycle on press with 0.3 s repeat, wrap".
const CYCLE_REPEAT_SECONDS: float = 0.3
## Register > "Draft input": "hold up 1.0 s confirms with a fill ring that resets on release".
const HOLD_CONFIRM_SECONDS: float = 1.0

## UI Pass (look only). No UiPalette token covers a modal card's fixed
## minimum footprint or a timed ring's diameter -- both are single-widget
## dimensions, not a reusable spacing/colour/font concept.
## TODO(ui-pass): promote to UiPalette if another surface needs the same
## card or ring size.
const CARD_MIN_SIZE: Vector2 = Vector2(360, 300)
const HOLD_RING_DIAMETER: float = 56.0
## `tr()` key for the heading Label; its English text is registered by
## src/ui/theme/ui_strings.gd.
const HEADING_TEXT_KEY: String = "DRAFT_TITLE"

## Draft is the topmost paused modal in this project: strictly above Hud
## (layer 10) and src/ui/threat_feedback.gd (layer 11, per hud.gd's own
## header) so its dim/cards occlude every other CanvasLayer while open. Not
## a Register number (no row assigns CanvasLayer indices; docs/20's z_index
## values are world-space only, per hud.gd's identical note).
const DRAFT_CANVAS_LAYER: int = 20

## Must equal PauseAuthority.REASON_DRAFT (&"draft") -- duplicated as a
## local constant, not read off the (possibly test-substituted) injected
## `_pause_authority` reference, since the STRING VALUE is part of this
## project's fixed vocabulary (docs/20 > Global Simulation Authority names
## "draft" as one of the five canonical reasons), not an implementation
## detail of whichever PauseAuthority instance a test happens to inject.
const REASON_DRAFT: StringName = &"draft"

const MAX_DISTINCT_REROLL_ATTEMPTS: int = 6

@export var pickup_system_path: NodePath
@export var upgrade_system_path: NodePath
@export var wave_director_path: NodePath
@export var ui_sfx_path: NodePath

## Keyed RNG root (MASTER_SDLC.md > Provisional Values Register > "Keyed
## RNG": "draft k = hash([run_seed, 'draft', k])"). See class header,
## "Cross-task seams" -- the orchestrator must set this to the SAME value as
## every other keyed-RNG system in the assembled run (WaveDirector.run_seed
## and RunRecorder's run seed).
@export var run_seed: int = 0

## Read-only default; never mutated (P2.11/P2.10's own convention of
## preloading data/economy/prototype.tres as a shared default). CHANGE 2
## (D108, 2026-09-23): this file no longer reads anything off it at all --
## `xp_level_cost` and the since-removed `xp_cap_during_teaching_waves`
## (C-XPCAP) were its only two consumers, and both of the functions that
## read them are deleted (see class doc, "CHANGE 2"). The export is kept
## (rather than deleted) as a documented seam for a future task that needs
## this controller to read economy data again, so the wiring convention
## does not have to be re-invented.
@export var economy_configuration: EconomyConfiguration = preload("res://data/economy/prototype.tres")

var _run_inventory: RunInventory = null
var _upgrade_system: UpgradeSystem = null
var _wave_director: Object = null
var _ui_sfx: UiSfx = null
var _pause_authority: Node = PauseAuthority
var _sim_clock: Node = SimClock
var _event_bus: Object = EventBus

# --- Queue / level tracking --------------------------------------------------

var _pending_draft_requests: Array[Dictionary] = []
var _last_observed_level: int = 0
var _draft_card_serial: int = 0

## Register > "Level-Up Draft": "Reroll 1 per run (prototype)". Meta layer
## core (Lucky Draw node; MASTER_SDLC.md > Provisional Values Register >
## "Meta: Skill Tree effects": "Lucky Draw +1 Draft reroll per run (2)")
## widens this from a bool to a counter -- `add_bonus_rerolls()` is called at
## most once, at run start, by `MetaLoadoutApplier`, adding Lucky Draw's
## ranks on top of this baseline 1.
var _rerolls_remaining: int = 1

var _draft_session_active: bool = false # true across a whole back-to-back queue, false once fully closed
var _draft_showing: bool = false # true while one card set is on screen awaiting a decision

# --- Current cards ------------------------------------------------------------

var _cards: Array[UpgradeDefinition] = []
var _last_shown_ids: Array[String] = []
var _highlighted_index: int = 0

# --- UI nodes ------------------------------------------------------------------

var _root: Control
var _card_row: HBoxContainer
var _fill_ring: DraftFillRing
var _reroll_label: Label
var _card_views: Array[DraftCardView] = []

# --- Input/timing state (see class header, "Two clocks") ---------------------

var _time_since_open: float = 0.0
var _lockout_elapsed: bool = false
var _hold_up_armed: bool = false
var _hold_up_progress: float = 0.0
var _left_held: bool = false
var _left_repeat_timer: float = 0.0
var _right_held: bool = false
var _right_repeat_timer: float = 0.0

# --- Test input override (mirrors src/player/player.gd's
# set_input_direction_override_for_test() convention -- a real hardware
# InputEvent is not needed to exercise this controller's logic) -----------

var _use_test_input: bool = false
var _test_pressed: Dictionary = {} # StringName -> bool
var _test_just_pressed: Dictionary = {} # StringName -> bool, consumed on read


func _ready() -> void:
	layer = DRAFT_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_dependencies()
	_build_ui()
	if _run_inventory != null:
		_last_observed_level = _run_inventory.level
	call_deferred("_find_and_register_with_sim_loop")


func _resolve_dependencies() -> void:
	if pickup_system_path != NodePath():
		var ps: PickupSystem = get_node_or_null(pickup_system_path) as PickupSystem
		if ps != null:
			_run_inventory = ps.run_inventory
	if upgrade_system_path != NodePath():
		_upgrade_system = get_node_or_null(upgrade_system_path) as UpgradeSystem
	if wave_director_path != NodePath():
		_wave_director = get_node_or_null(wave_director_path)
	if ui_sfx_path != NodePath():
		_ui_sfx = get_node_or_null(ui_sfx_path) as UiSfx


## CHANGE 2 (D108, 2026-09-23): REMOVED. `_connect_wave_director_signal()`
## existed only to wire the now-deleted `_on_wave_ended()` (the forced
## first Draft at T4's end) to the WaveDirector's `wave_ended` signal --
## see class doc, "CHANGE 2." Nothing in this file consumes `wave_ended`
## any more.


func _find_and_register_with_sim_loop() -> void:
	# Deferred past _ready() for the same reason sim_loop.gd's own header
	# documents (siblings under Main may finish _ready() before SimLoop
	# does): matches src/pickup/pickup_system.gd's identical pattern.
	var loop: Node = get_tree().get_first_node_in_group(&"sim_loop")
	if loop != null and loop.has_method(&"register"):
		loop.register(SimLoop.Step.XP_AND_LEVEL_UP_REQUESTS, self)


# --- Test seams (project convention: set_*_for_test(), default to the real thing) ---

func set_run_inventory_for_test(inv: RunInventory) -> void:
	_run_inventory = inv
	_last_observed_level = inv.level if inv != null else 0


func set_upgrade_system_for_test(sys: UpgradeSystem) -> void:
	_upgrade_system = sys


## CHANGE 2 (D108, 2026-09-23): no longer connects/disconnects a
## `wave_ended` listener (that signal has no consumer left in this file --
## see class doc, "CHANGE 2") -- a plain assignment.
func set_wave_director_for_test(wd: Object) -> void:
	_wave_director = wd


func set_ui_sfx_for_test(sfx: UiSfx) -> void:
	_ui_sfx = sfx


func set_pause_authority_for_test(pa: Node) -> void:
	_pause_authority = pa


func set_sim_clock_for_test(clock: Node) -> void:
	_sim_clock = clock


func set_event_bus_for_test(bus: Object) -> void:
	_event_bus = bus


func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


## Simulates a single just-pressed edge (and marks the action held until
## release_action_for_test() is called), for a one-shot action (confirm,
## reroll, a number-select key).
func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true
	_test_pressed[action] = true


func release_action_for_test(action: StringName) -> void:
	_test_pressed[action] = false


## Test-only alias for _process(), so a suite can drive deterministic,
## explicit frame steps instead of depending on the engine's own frame
## timing (project convention: see player_input_buffer_test.gd's
## set_input_direction_for_test() + direct physics_step() calls).
func tick_for_test(delta: float) -> void:
	_process(delta)


func force_open_for_test(forced: bool = false) -> void:
	_open_one_draft(forced)


func simulate_hover_for_test(index: int) -> void:
	_on_card_hovered(index)


## Test-only shortcut: confirms card `index` directly, bypassing the
## lockout/hold/press machinery entirely -- for suites (draft_queue_test,
## draft_determinism_test, xp_cap_check_test) whose own assertions are about
## the queue, RNG, or XP bookkeeping, not about input timing (that is
## draft_input_lockout_test's job).
func confirm_choice_for_test(index: int) -> void:
	_highlighted_index = index
	_confirm_highlighted_card()


## Test-only shortcut: marks the lockout already elapsed and the hold-up
## mechanism already armed, for suites that do not exercise the lockout/
## arming rule themselves.
func skip_lockout_for_test() -> void:
	_lockout_elapsed = true
	_hold_up_armed = true


func get_pending_draft_count_for_test() -> int:
	return _pending_draft_requests.size()


func is_draft_showing_for_test() -> bool:
	return _draft_showing


func is_draft_session_active_for_test() -> bool:
	return _draft_session_active


func get_highlighted_index_for_test() -> int:
	return _highlighted_index


func get_current_card_ids_for_test() -> Array[String]:
	return _ids_of(_cards)


func get_card_view_for_test(i: int) -> DraftCardView:
	return _card_views[i] if i >= 0 and i < _card_views.size() else null


func get_card_view_count_for_test() -> int:
	return _card_views.size()


func get_root_control_for_test() -> Control:
	return _root


func get_fill_ring_for_test() -> DraftFillRing:
	return _fill_ring


func get_reroll_label_for_test() -> Label:
	return _reroll_label


func get_hold_progress_for_test() -> float:
	return _hold_up_progress


func is_lockout_elapsed_for_test() -> bool:
	return _lockout_elapsed


func is_hold_up_armed_for_test() -> bool:
	return _hold_up_armed


## Kept for backward compatibility with anything that asked "has the
## baseline reroll been spent" -- true once the counter reaches zero,
## regardless of how many bonus rerolls Lucky Draw ever added.
func get_reroll_used_for_test() -> bool:
	return _rerolls_remaining <= 0


## Integration task (F05-15: "the HUD's rerolls_remaining field is never
## populated by anything"). Not a `_for_test()` seam -- a genuine production
## query the HUD wiring reads every frame. Register: "Reroll 1 per run
## (prototype)" plus any Lucky Draw bonus already added by
## `add_bonus_rerolls()`.
func get_rerolls_remaining() -> int:
	return maxi(0, _rerolls_remaining)


## Typed command (Meta layer core, Lucky Draw node). Called once, at run
## start, by `MetaLoadoutApplier`. Adds to the baseline reroll count rather
## than replacing it, since this is the one Skill Tree effect that is itself
## additive to a per-run counter rather than a percentage/flat bonus folded
## into a definition Resource.
func add_bonus_rerolls(count: int) -> void:
	if count > 0:
		_rerolls_remaining += count


## Typed command (Meta layer core, War Chest node). MASTER_SDLC.md >
## Provisional Values Register > "Meta: Skill Tree effects": "War Chest: ...
## one free Draft when the first wave begins." Called by `MetaLoadoutApplier`
## from a one-shot `WaveDirector.wave_opened` connection for the first wave
## (wave_index == 0) -- enqueues a Draft request exactly the way a real
## level-up does, so it queues behind/ahead of a simultaneous real level-up
## by the same first-come-first-served rule (`_try_open_next_draft()` no-ops
## if a Draft is already showing, matching every other enqueue call site).
func queue_forced_draft_for_meta() -> void:
	_enqueue_draft_request(false)
	_try_open_next_draft()


func get_draft_card_serial_for_test() -> int:
	return _draft_card_serial


func get_last_observed_level_for_test() -> int:
	return _last_observed_level


# --- SimLoop step 11 entry point (unpaused only -- see class header) ---------

## CHANGE 2 (D108, 2026-09-23): always the same path now, teaching wave or
## not -- see class doc, "CHANGE 2." The old `_is_teaching_wave_active()`
## branch that routed to a separate XP-cap-and-revert enforcement path is
## gone; `_check_for_new_level_up_requests()` below is unconditional.
func physics_step(_delta: float) -> void:
	if _run_inventory == null:
		return
	_check_for_new_level_up_requests()


## Register > "XP & levels" / "Experience (XP)": "simultaneous level-ups
## queue their drafts sequentially." RunInventory's own
## `consume_level_up_requested()` is a boolean, not a counter (P2.10 is out
## of this task's write scope), so it cannot by itself distinguish "levelled
## up once this tick" from "levelled up twice in one very large credit_xp()
## call." Comparing `level` before/after recovers the true count: a burst
## that crosses two thresholds in a single credit_xp() call raises `level`
## by 2, and this queues two requests, not one -- "no draft dropped."
func _check_for_new_level_up_requests() -> void:
	if _run_inventory.consume_level_up_requested():
		var gained: int = _run_inventory.level - _last_observed_level
		if gained < 1:
			gained = 1
		for i in gained:
			_enqueue_draft_request(false)
	_last_observed_level = _run_inventory.level
	_try_open_next_draft()


## CHANGE 2 (D108, 2026-09-23): REMOVED. The forced first Level-Up Draft at
## T4's end (`_on_wave_ended()`, formerly connected to the WaveDirector's
## own `wave_ended` signal via `_connect_wave_director_signal()`) no longer
## exists -- see class doc, "CHANGE 2," for why. `_wave_director`'s
## `notify_draft_closed()` call (the post-Draft grace period hook, a
## SEPARATE mechanism) is unaffected and still wired below.


func _enqueue_draft_request(forced: bool) -> void:
	_pending_draft_requests.append({"forced": forced})


func _try_open_next_draft() -> void:
	if _draft_showing or _pending_draft_requests.is_empty():
		return
	var request: Dictionary = _pending_draft_requests.pop_front()
	_open_one_draft(bool(request.get("forced", false)))


func _open_one_draft(forced: bool) -> void:
	_draft_showing = true
	if not _draft_session_active:
		_draft_session_active = true
		# Queued; applied at SimLoop step 14 in THIS tick (still unpaused --
		# see docs/20 "Level-Up Draft Rule": pause takes effect the same
		# tick the level-up was requested).
		if _pause_authority != null:
			_pause_authority.push_reason(REASON_DRAFT)
	# CHANGE 2 (D108, 2026-09-23): `forced` is no longer acted on here --
	# _grant_forced_level() (the forced-first-Draft-at-T4's-end grant) is
	# REMOVED, since nothing enqueues a request with forced=true any more
	# (see class doc, "CHANGE 2"). The parameter itself, `_enqueue_draft_
	# request()`, `_try_open_next_draft()`, and `force_open_for_test()`'s own
	# signature are left UNCHANGED rather than threading a signature change
	# through every caller, per this task's own "keep this file's diff
	# small" instruction -- named here rather than silently narrowed.
	_roll_three_cards([])
	_reset_input_state_for_open()
	_show_ui()
	if _event_bus != null and _event_bus.has_method(&"emit_draft_opened"):
		# EventBus header: "Emitted ... after it has itself pushed the draft
		# pause reason on PauseAuthority" -- push_reason() above runs first.
		_event_bus.emit_draft_opened()


## CHANGE 2 (D108, 2026-09-23): REMOVED. `_grant_forced_level()` and
## `_compute_level_cost()` (its only other caller was the also-removed
## `_enforce_xp_cap_and_revert_erroneous_level_up()`) existed solely to
## serve the forced-first-Draft/XP-cap mechanics -- see class doc,
## "CHANGE 2." Neither had a `_for_test()` caller of its own (grepped
## before removal), so nothing else in this codebase calls them.


# --- Card rolling (KeyedRng; one-of-each guarantee; fallback substitution) ---

## Register > "Level-Up Draft": "3 cards in a row ... >= 1 player + >= 1
## Tower card." Rolls a guaranteed Player card, a guaranteed Tower card,
## then a wildcard from whatever remains, retrying (bounded) if the result
## exactly repeats `avoid_ids` and the pool is large enough to avoid it --
## the Reroll rule ("avoids showing the same three cards again when the
## pool allows it"). `avoid_ids` is empty for an initial draft open.
func _roll_three_cards(avoid_ids: Array[String]) -> void:
	if _upgrade_system == null:
		push_error("DraftController._roll_three_cards(): no UpgradeSystem wired -- cannot roll cards")
		_cards = []
		_last_shown_ids = []
		return
	var attempts: int = 0
	var result: Array[UpgradeDefinition] = []
	while attempts < MAX_DISTINCT_REROLL_ATTEMPTS:
		result = _roll_three_once()
		attempts += 1
		if avoid_ids.is_empty() or not _same_id_set(result, avoid_ids):
			break
	_cards = result
	_last_shown_ids = _ids_of(result)


func _roll_three_once() -> Array[UpgradeDefinition]:
	var player_pool: Array[UpgradeDefinition] = _upgrade_system.get_offerable_upgrades(ContractEnums.PoolOwnership.Player)
	var tower_pool: Array[UpgradeDefinition] = _upgrade_system.get_offerable_upgrades(ContractEnums.PoolOwnership.Tower)

	var card_player: UpgradeDefinition = _pick_guaranteed(player_pool, ContractEnums.PoolOwnership.Player)
	var card_tower: UpgradeDefinition = _pick_guaranteed(tower_pool, ContractEnums.PoolOwnership.Tower)

	var remaining: Array[UpgradeDefinition] = []
	for d in player_pool:
		if card_player == null or d.unique_id != card_player.unique_id:
			remaining.append(d)
	for d in tower_pool:
		if card_tower == null or d.unique_id != card_tower.unique_id:
			remaining.append(d)

	var card_wild: UpgradeDefinition = _pick_wildcard(remaining)

	var out: Array[UpgradeDefinition] = []
	if card_player != null:
		out.append(card_player)
	if card_tower != null:
		out.append(card_tower)
	if card_wild != null:
		out.append(card_wild)
	return out


func _pick_guaranteed(pool: Array[UpgradeDefinition], pool_ownership: int) -> UpgradeDefinition:
	if not pool.is_empty():
		var idx: int = _next_rng().randi_range(0, pool.size() - 1)
		return pool[idx]
	# Pool exhausted (is_pool_exhausted() would be true) -- C-FALLBACK-CONSOLE.
	return _upgrade_system.get_fallback_card(pool_ownership)


func _pick_wildcard(remaining: Array[UpgradeDefinition]) -> UpgradeDefinition:
	if not remaining.is_empty():
		var idx: int = _next_rng().randi_range(0, remaining.size() - 1)
		return remaining[idx]
	var fallback_pool: Array[UpgradeDefinition] = []
	var fb_p: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Player)
	var fb_t: UpgradeDefinition = _upgrade_system.get_fallback_card(ContractEnums.PoolOwnership.Tower)
	if fb_p != null:
		fallback_pool.append(fb_p)
	if fb_t != null:
		fallback_pool.append(fb_t)
	if fallback_pool.is_empty():
		# Fully degenerate pool state -- should not occur with this
		# prototype's authored 8-card set (named in the P2.12 evidence
		# report rather than invented further).
		return null
	var idx: int = _next_rng().randi_range(0, fallback_pool.size() - 1)
	return fallback_pool[idx]


## Register > "Keyed RNG": "draft k = hash([run_seed, 'draft', k])". `k`
## (`_draft_card_serial`) is a run-lifetime monotonic counter, incremented
## once per roll (guaranteed-player pick, guaranteed-tower pick, wildcard
## pick, and every retry) -- matching the `spawn_serial` pattern already
## used for drops/spawns (a per-roll identifier that never resets per
## draft), which is what makes every roll across a whole run distinct and
## still fully reproducible from the same run_seed.
func _next_rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = KeyedRng.rng_for([run_seed, "draft", _draft_card_serial])
	_draft_card_serial += 1
	return rng


func _same_id_set(cards: Array[UpgradeDefinition], ids: Array[String]) -> bool:
	if cards.size() != ids.size():
		return false
	var a: Array = _ids_of(cards)
	a.sort()
	var b: Array = ids.duplicate()
	b.sort()
	return a == b


func _ids_of(cards: Array[UpgradeDefinition]) -> Array[String]:
	var out: Array[String] = []
	for d in cards:
		out.append(d.unique_id)
	return out


# --- Confirm / reroll / close ------------------------------------------------

func _confirm_highlighted_card() -> void:
	if _cards.is_empty() or _highlighted_index < 0 or _highlighted_index >= _cards.size():
		return
	var chosen: UpgradeDefinition = _cards[_highlighted_index]
	if _ui_sfx != null:
		_ui_sfx.play_confirm()
	_on_card_confirmed(chosen.unique_id)


func _on_card_confirmed(upgrade_id: String) -> void:
	if _upgrade_system != null:
		_upgrade_system.apply_rank(upgrade_id)
	_hide_ui()
	if not _pending_draft_requests.is_empty():
		_try_open_next_draft() # stays paused -- next queued draft opens immediately (Draft queue test)
	else:
		_close_session()


## Register > "Level-Up Draft": "Reroll ... 1 per run (prototype) ...
## replaces all 3 cards, keeps the guarantee ... avoids the 3 just shown
## when the pool allows." Does NOT reset the 0.4 s lockout or the
## neutral-return arming (those are an "on open" rule; a reroll happens
## inside an already-open draft) -- but DOES reset the hold-up progress, so
## a hold already in progress cannot suddenly confirm a card that just
## changed under it (an interpretation, named in the P2.12 evidence report).
func _try_reroll() -> void:
	if _rerolls_remaining <= 0 or _cards.is_empty():
		return
	_rerolls_remaining -= 1
	_roll_three_cards(_last_shown_ids.duplicate())
	_highlighted_index = 0
	_hold_up_progress = 0.0
	_build_card_views()
	if _ui_sfx != null:
		_ui_sfx.play_reroll()


func _close_session() -> void:
	_draft_session_active = false
	if _pause_authority != null:
		# SimLoop cannot flush() while already paused -- see class header,
		# "Unpausing from inside the pause it caused."
		_pause_authority.pop_reason_immediate(REASON_DRAFT)
	if _wave_director != null and _wave_director.has_method(&"notify_draft_closed"):
		var now: float = _sim_clock.now if _sim_clock != null else 0.0
		_wave_director.notify_draft_closed(now)


# --- Input (see class header, "Two clocks") ----------------------------------

func _process(delta: float) -> void:
	if not _draft_showing:
		return
	_time_since_open += delta
	if not _lockout_elapsed:
		if _time_since_open >= LOCKOUT_SECONDS:
			_lockout_elapsed = true
			_update_hold_up_arming_state()
		_update_fill_ring_visual()
		_clear_test_edges_for_frame() # a swallowed press during lockout must not leak into the next frame
		return # input locked out for the whole 0.4 s window
	_poll_cycle_input(delta)
	_poll_number_select_input()
	_poll_confirm_input()
	_poll_reroll_input()
	_poll_hold_up_input(delta)
	_update_fill_ring_visual()
	_clear_test_edges_for_frame()


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


## Real hardware `Input.is_action_just_pressed()` is only ever true for the
## one frame after the physical press, regardless of whether any code reads
## it. The test-input double above stores an explicit flag instead, so it
## must be cleared at the end of every `_process()` call (whether or not
## anything consumed it this frame) to reproduce that same one-frame-only
## semantics -- otherwise a press queued during the input lockout would
## incorrectly survive, unconsumed, into the first post-lockout frame.
func _clear_test_edges_for_frame() -> void:
	if _use_test_input:
		_test_just_pressed.clear()


## Register > "Draft input": "hold-to-confirm arms only after input returns
## to neutral once"; docs/19 > "Input Lockout & Arming": "so a key or stick
## already held at the moment the Draft opens cannot auto-confirm a card."
## Called once, the instant the lockout elapses.
func _update_hold_up_arming_state() -> void:
	if not _is_pressed(&"move_up"):
		_hold_up_armed = true


func _poll_hold_up_input(delta: float) -> void:
	var pressed: bool = _is_pressed(&"move_up")
	if not _hold_up_armed:
		if not pressed:
			_hold_up_armed = true # neutral observed post-lockout -- armed now
		return # never accumulate hold progress until armed
	if pressed:
		_hold_up_progress += delta
		if _hold_up_progress >= HOLD_CONFIRM_SECONDS:
			_confirm_highlighted_card()
			_hold_up_progress = 0.0
	else:
		_hold_up_progress = 0.0 # "resets if the hold is released before it completes"


func _poll_cycle_input(delta: float) -> void:
	var left_now: bool = _is_pressed(&"draft_cycle_left") or _is_pressed(&"move_left")
	var right_now: bool = _is_pressed(&"draft_cycle_right") or _is_pressed(&"move_right")

	if left_now and not _left_held:
		_cycle_highlight(-1)
		_left_repeat_timer = CYCLE_REPEAT_SECONDS
	elif left_now and _left_held:
		_left_repeat_timer -= delta
		if _left_repeat_timer <= 0.0:
			_cycle_highlight(-1)
			_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_held = left_now

	if right_now and not _right_held:
		_cycle_highlight(1)
		_right_repeat_timer = CYCLE_REPEAT_SECONDS
	elif right_now and _right_held:
		_right_repeat_timer -= delta
		if _right_repeat_timer <= 0.0:
			_cycle_highlight(1)
			_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_held = right_now


func _cycle_highlight(step: int) -> void:
	if _cards.is_empty():
		return
	_highlighted_index = wrapi(_highlighted_index + step, 0, _cards.size())
	_refresh_highlight_visual()
	if _ui_sfx != null:
		_ui_sfx.play_cycle()


func _poll_number_select_input() -> void:
	if _is_just_pressed(&"draft_select_1") and _cards.size() > 0:
		_highlighted_index = 0
		_confirm_highlighted_card()
	elif _is_just_pressed(&"draft_select_2") and _cards.size() > 1:
		_highlighted_index = 1
		_confirm_highlighted_card()
	elif _is_just_pressed(&"draft_select_3") and _cards.size() > 2:
		_highlighted_index = 2
		_confirm_highlighted_card()


func _poll_confirm_input() -> void:
	if _is_just_pressed(&"confirm"):
		_confirm_highlighted_card()


func _poll_reroll_input() -> void:
	if _is_just_pressed(&"reroll"):
		_try_reroll()


func _on_card_hovered(index: int) -> void:
	if not _lockout_elapsed:
		return
	_highlighted_index = index
	_refresh_highlight_visual()


func _reset_input_state_for_open() -> void:
	_time_since_open = 0.0
	_lockout_elapsed = false
	_hold_up_armed = false
	_hold_up_progress = 0.0
	_left_held = false
	_right_held = false
	_left_repeat_timer = 0.0
	_right_repeat_timer = 0.0
	_highlighted_index = 0


# --- UI construction ----------------------------------------------------------

func _build_ui() -> void:
	# Round 2, UR-08: explicit, not only as UiTheme.get_theme()'s side effect
	# below -- tr(HEADING_TEXT_KEY) a few lines down needs the key registered
	# regardless of theme-build order.
	UiStrings.ensure_registered()
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	# UI Pass: applied ONCE at this surface's root Control, per
	# src/ui/theme/ui_theme.gd's own header ("A surface applies it ONCE, at
	# its root Control ... and inherits from there"). Every descendant
	# Control built below (dim aside) inherits it.
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	# Register > "Level-Up Draft": "background dimmed 60%" -- battlefield
	# stays visible underneath (this ColorRect is the only thing drawn here;
	# nothing hides the gameplay viewport itself). The 0.6 alpha IS the
	# Register-cited figure and is never touched by this pass; only its RGB
	# is tinted, from UiPalette.DIM_TINT (no test asserts the exact colour --
	# see UiPalette's own header on DIM_DRAFT/DIM_TINT).
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = UiPalette.with_alpha(UiPalette.DIM_TINT, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.theme_type_variation = UiTheme.vbox("XL") # Round 2, UR-06
	center.add_child(column)

	# Heading (docs/19 > "Upgrade Draft UI & Navigation"; direction: "State
	# is shown near the thing it describes"). A real `tr()` key, registered
	# in src/ui/theme/ui_strings.gd, rather than a plain literal.
	var heading := Label.new()
	heading.name = "Heading"
	heading.theme_type_variation = UiTheme.HEADING
	heading.text = tr(HEADING_TEXT_KEY)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(heading)

	_card_row = HBoxContainer.new()
	_card_row.name = "CardRow"
	_card_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.theme_type_variation = UiTheme.hbox("XXL") # Round 2, UR-06
	column.add_child(_card_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.theme_type_variation = UiTheme.hbox("L") # Round 2, UR-06
	column.add_child(bottom_row)

	_fill_ring = DraftFillRing.new()
	_fill_ring.name = "HoldRing"
	# Round 2, UR-03: a drawn triangle, not the "▲" character (not in the
	# shipped font -- see draft_fill_ring.gd's own header), the same shape
	# geometry as the Player pool glyph on the cards above, hinting the
	# "hold up" gesture this ring times (docs/19 > "Movement-only").
	_fill_ring.center_shape = UiShapeGlyph.Shape.TRIANGLE
	_fill_ring.custom_minimum_size = Vector2(HOLD_RING_DIAMETER, HOLD_RING_DIAMETER)
	bottom_row.add_child(_fill_ring)

	# docs/19 > "Draft Actions": "Reroll is also a focusable element beside
	# the cards" (Register > "Platform input floor"). Wrapped in a UiPill
	# panel (direction: "small pill-shaped edge widgets") -- purely a visual
	# wrapper; get_reroll_label_for_test() still returns the Label itself,
	# unchanged, at the same node name.
	var reroll_pill := PanelContainer.new()
	reroll_pill.name = "RerollPill"
	reroll_pill.theme_type_variation = UiTheme.PILL
	reroll_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.add_child(reroll_pill)

	_reroll_label = Label.new()
	_reroll_label.name = "RerollHint"
	_reroll_label.text = "Reroll: R / Square"
	_reroll_label.theme_type_variation = UiTheme.DIM
	_reroll_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reroll_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_reroll_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reroll_label.custom_minimum_size = Vector2(240, 0)
	_reroll_label.focus_mode = Control.FOCUS_ALL
	reroll_pill.add_child(_reroll_label)


func _show_ui() -> void:
	_root.visible = true
	_build_card_views()


func _hide_ui() -> void:
	_draft_showing = false
	_root.visible = false


func _build_card_views() -> void:
	# queue_free() alone, never remove_child() first: remove_child() detaches
	# the node immediately while its queue_free() is still only pending
	# (deferred to the next idle frame), leaving it parentless-but-alive for
	# that window -- exactly what gdUnit4's orphan-node monitor flags,
	# because a test can finish and tear its scene down before that deferred
	# free ever runs (this project's own F03-35 names the same
	# remove_child() hazard for a different call site, gdUnit4's own
	# after_test()). queue_free() by itself removes AND frees atomically at
	# the same deferred point, so the node is never observed detached.
	for child in _card_row.get_children():
		child.queue_free()
	_card_views.clear()
	for i in _cards.size():
		var def: UpgradeDefinition = _cards[i]
		var view: DraftCardView = DraftCardView.new()
		view.name = "Card%d" % i
		view.custom_minimum_size = CARD_MIN_SIZE
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_card_row.add_child(view)
		var current_rank: int = 0
		if _upgrade_system != null:
			current_rank = _upgrade_system.get_current_rank(def.unique_id)
		view.setup(def, current_rank)
		view.mouse_entered.connect(_on_card_hovered.bind(i))
		# Card-row entrance (PLAN.md direction): a short staggered fade/rise,
		# purely cosmetic (see DraftCardView.play_entrance()'s own header) --
		# every existing rule below (lockout, arming, cycle, confirm, hover)
		# reads `_cards`/`_highlighted_index`/input state directly, never
		# this animation's progress, so a card is fully interactable
		# regardless of where this playback is.
		view.play_entrance(i * UiPalette.MOTION_FAST)
		_card_views.append(view)
	_refresh_highlight_visual()


func _refresh_highlight_visual() -> void:
	for i in _card_views.size():
		_card_views[i].set_highlighted(i == _highlighted_index)


func _update_fill_ring_visual() -> void:
	if _fill_ring != null:
		_fill_ring.progress = clampf(_hold_up_progress / HOLD_CONFIRM_SECONDS, 0.0, 1.0)

extends Node

## PauseAuthority Autoload (MASTER_SDLC.md > Global Simulation Authority,
## paragraph 2, and > Pause Rules; docs/20 > Godot 4.x Implementation
## Standards > "SimLoop order", step 14 "PauseAuthority.flush()"). The ONLY
## writer of get_tree().paused anywhere in this project. PROCESS_MODE_ALWAYS
## so it keeps functioning while the tree is paused -- it has to, since it
## is the one thing able to unpause it.
##
## Holds a set of pause reasons (draft, pause menu, focus loss, controller
## disconnect, debug per the master's list; any StringName is accepted, the
## five constants below are just typo-proof names for the canonical ones).
## The tree is paused whenever the set is non-empty and unpaused only when
## it is empty.
##
## Requests are NOT applied immediately. push_reason()/pop_reason() called
## during a tick only QUEUE a pending change; flush() -- called once, by
## SimLoop, at step 14 of the fixed per-tick order -- applies every change
## queued since the last flush() and updates get_tree().paused to match.
## This is a determinism guarantee, not a convenience: "Every pause and
## unpause request is applied by PauseAuthority at the end of the tick it
## was requested on, never mid-tick" (Pause Rules), so a pause can never
## interrupt the fixed fifteen-step order partway through (Determinism
## where it matters).
##
## Exception: the Focus Loss Rule requires a request made BETWEEN ticks
## (there is no in-progress tick resolution to protect) to apply
## immediately -- push_reason_immediate()/pop_reason_immediate() below
## queue AND flush in the same call for exactly that case.

signal reasons_changed(reasons: Array[StringName])

const REASON_DRAFT: StringName = &"draft"
const REASON_PAUSE_MENU: StringName = &"pause_menu"
const REASON_FOCUS_LOSS: StringName = &"focus_loss"
const REASON_CONTROLLER_DISCONNECT: StringName = &"controller_disconnect"
const REASON_DEBUG: StringName = &"debug"

var _active_reasons: Dictionary = {} # StringName -> true
var _pending_add: Dictionary = {} # StringName -> true, queued since the last flush()
var _pending_remove: Dictionary = {} # StringName -> true, queued since the last flush()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Queues a pause reason to be added at the next flush(). Idempotent:
## queuing an already-active or already-queued reason changes nothing
## extra. Cancels a same-reason pending removal queued earlier this tick.
func push_reason(reason: StringName) -> void:
	_pending_add[reason] = true
	_pending_remove.erase(reason)


## Queues a pause reason to be removed at the next flush(). Cancels a
## same-reason pending addition queued earlier this tick.
func pop_reason(reason: StringName) -> void:
	_pending_remove[reason] = true
	_pending_add.erase(reason)


## Called once per tick, at SimLoop step 14. Applies every reason change
## queued since the last flush(), writes get_tree().paused to match whether
## the (now-updated) reason set is empty, and emits reasons_changed only if
## the active set actually changed.
func flush() -> void:
	if _pending_add.is_empty() and _pending_remove.is_empty():
		return
	var changed: bool = false
	for reason in _pending_add.keys():
		if not _active_reasons.has(reason):
			_active_reasons[reason] = true
			changed = true
	for reason in _pending_remove.keys():
		if _active_reasons.has(reason):
			_active_reasons.erase(reason)
			changed = true
	_pending_add.clear()
	_pending_remove.clear()
	if changed:
		_apply_paused_state()


## Focus Loss Rule: a request made between ticks applies immediately rather
## than waiting for the next flush(), since there is no in-progress tick
## resolution a mid-tick apply could corrupt.
func push_reason_immediate(reason: StringName) -> void:
	push_reason(reason)
	flush()


func pop_reason_immediate(reason: StringName) -> void:
	pop_reason(reason)
	flush()


func has_reason(reason: StringName) -> bool:
	return _active_reasons.has(reason)


## Typed query (docs/20 > Communication, queries).
func get_active_reasons() -> Array[StringName]:
	var out: Array[StringName] = []
	for r in _active_reasons.keys():
		out.append(r)
	return out


func _apply_paused_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var should_pause: bool = not _active_reasons.is_empty()
	if tree.paused != should_pause:
		tree.paused = should_pause
	reasons_changed.emit(get_active_reasons())

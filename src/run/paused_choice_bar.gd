extends HBoxContainer
class_name PausedChoiceBar

## Shared horizontal, hold-to-confirm choice bar (P2.14 - Run flow).
## MASTER_SDLC.md > Provisional Values Register > "Interfaces" > "Platform
## input floor": "every paused menu (Draft, pause menu, settings, run-end
## screens) lays choices out horizontally and supports hold-to-confirm."
## This single `HBoxContainer` subclass IS that horizontal layout (docs/19
## > "UI Layout & Dynamic Container Rules" prefers a real Container over
## manual positioning) and is reused, unmodified, by
## src/ui/pause_menu.gd, src/ui/settings_menu.gd, and src/ui/run_end.gd so
## the three paused-menu surfaces this task builds share exactly one
## cycle/hold-to-confirm implementation rather than three drifting copies.
##
## ## Timing numbers reused from the Draft, named as an interpretation
## The Register defines a hold-to-confirm timing in exactly one place --
## Provisional Values Register > "Progression & Upgrades" > "Draft input":
## "left/right cycle on press with 0.3 s repeat, wrap ... hold up 1.0 s
## confirms with a fill ring that resets on release." Nothing in the
## Register or docs/19 restates a SEPARATE timing for the pause menu,
## settings menu, or run-end screens -- only that they must "support
## hold-to-confirm" at all. This bar reuses the Draft's own two numbers
## (0.3 s cycle repeat, 1.0 s hold-to-confirm) as the one hold-to-confirm
## timing the Register defines anywhere, rather than inventing a second,
## uncited pair of constants. Named here and in the P2.14 evidence report,
## "Interpretations" -- not a second Register citation for a second use.
##
## ## Neutral-return arming, no separate lockout window
## docs/19 > "Upgrade Draft UI & Navigation" > "Input Lockout & Arming":
## "Hold-to-confirm inputs ... only arm once input has returned to neutral
## at least once ..., so a key or stick already held at the moment the
## Draft opens cannot auto-confirm a card." The SAME hazard applies to any
## paused menu: a player holding `move_up` as ordinary movement at the
## instant they press `pause` must not have that hold instantly confirm
## the highlighted option. This bar applies the identical neutral-return
## rule (`_reset_input_state()` below), applied the instant the bar
## becomes active -- but, unlike the Draft, does NOT add a separate 0.4 s
## timed lockout first: the Register's 0.4 s figure is cited specifically
## to the Draft's own opening ("Input is locked out for 0.4 seconds after
## the Draft opens"), and no equivalent duration is stated for a paused
## menu opened by a discrete key press (`pause`, not a level-up that can
## land while the player is mid-input). Named as an interpretation in the
## P2.14 evidence report, not a silently invented Register number.
##
## ## Paused-menu timing carve-out (Author decision D104, docs/20 > Godot
## 4.x Implementation Standards > "Paused-menu timing")
## This bar's own `_process(delta)` accumulates `_hold_up_progress` and the
## two cycle-repeat timers from its own per-frame `delta` -- never
## `SimClock.now` (frozen for exactly as long as the pause these menus
## exist to run during lasts) and never `get_tree().create_timer()` /
## `create_tween()` (banned project-wide; the banned-API check enforces
## it). `process_mode` is left at the default `PROCESS_MODE_INHERIT`
## deliberately: this bar is always a child of a `CanvasLayer` that itself
## sets `PROCESS_MODE_ALWAYS` (pause_menu.gd / settings_menu.gd /
## run_end.gd), and `INHERIT` correctly picks that up, matching
## src/ui/hud.gd's own children (which set no process_mode of their own
## either).
##
## ## GodotPrompter skill conflict, recorded per CLAUDE.md
## The `godot-ui` skill's own checklist: "Pause menu root Control has
## process_mode = PROCESS_MODE_ALWAYS" together with its "Common UI
## Patterns" section's pause-menu example, which pauses by writing
## `get_tree().paused = true` directly. This project's binding rule
## (docs/20 > "Communication, commands"; src/core/pause_authority.gd's own
## header: "The ONLY writer of get_tree().paused anywhere in this
## project") is explicit and binding the other way -- every push/pop of a
## pause reason goes through `PauseAuthority`, never a direct
## `get_tree().paused` write. This file itself never touches
## `get_tree().paused` at all (it only reports which option was confirmed,
## via `option_confirmed`); the actual push/pop calls live in
## src/run/run_flow_controller.gd, the one caller both src/ui/console.gd
## (an earlier phase) and this task follow the same "one writer, everyone
## else reacts" discipline for. This project's document wins; recorded
## here, in src/run/run_flow_controller.gd's own header, and in the P2.14
## evidence report/LEDGER per CLAUDE.md's GodotPrompter section.

signal option_confirmed(index: int)
signal highlighted_changed(index: int)

const CYCLE_REPEAT_SECONDS: float = 0.3
const HOLD_CONFIRM_SECONDS: float = 1.0

var _labels: Array[String] = []
var _views: Array[Label] = []
var _fill_ring: DraftFillRing = null
var _highlighted: int = 0
var _active: bool = false

var _hold_up_armed: bool = false
var _hold_up_progress: float = 0.0
var _left_held: bool = false
var _left_repeat_timer: float = 0.0
var _right_held: bool = false
var _right_repeat_timer: float = 0.0

## Test input override -- mirrors src/ui/draft_controller.gd's own
## `_use_test_input`/`_test_pressed`/`_test_just_pressed` convention
## letter for letter, so tests already familiar with that shape need no
## new mental model for this bar.
var _use_test_input: bool = false
var _test_pressed: Dictionary = {}
var _test_just_pressed: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 32)


## Typed command. Rebuilds the row from `labels`, in order (index 0..n-1
## is confirmed as that same index via `option_confirmed`).
func set_options(labels: Array[String]) -> void:
	_labels = labels.duplicate()
	for child in get_children():
		child.queue_free() # never remove_child() first -- see draft_controller.gd's own _build_card_views() note; same hazard (F03-35's class), same fix.
	_views.clear()
	for i in _labels.size():
		var lbl := Label.new()
		lbl.name = "Option%d" % i
		lbl.text = _labels[i]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.focus_mode = Control.FOCUS_ALL
		lbl.mouse_entered.connect(_on_hovered.bind(i))
		lbl.gui_input.connect(_on_option_gui_input.bind(i))
		add_child(lbl)
		_views.append(lbl)
	_highlighted = 0
	_refresh_highlight()


func set_fill_ring(ring: DraftFillRing) -> void:
	_fill_ring = ring


## Typed command. `active` gates this bar's own `_process()` input polling
## (matching draft_controller.gd's `_draft_showing` gate) and re-applies
## the neutral-return arming rule every time the bar is (re)activated --
## covers both "menu just opened" and "menu re-shown after Settings closed
## and returned focus to it," both of which are moments a held key must
## not carry over as an instant confirm.
func set_active(active: bool) -> void:
	_active = active
	if active:
		_reset_input_state()


func is_active() -> bool:
	return _active


func get_highlighted_index() -> int:
	return _highlighted


func get_option_count() -> int:
	return _labels.size()


# --- test seams (mirror draft_controller.gd's convention) ------------------

func set_test_input_mode_for_test(enabled: bool) -> void:
	_use_test_input = enabled
	_test_pressed.clear()
	_test_just_pressed.clear()


func set_action_pressed_for_test(action: StringName, pressed: bool) -> void:
	_test_pressed[action] = pressed


func press_action_once_for_test(action: StringName) -> void:
	_test_just_pressed[action] = true
	_test_pressed[action] = true


func release_action_for_test(action: StringName) -> void:
	_test_pressed[action] = false


func tick_for_test(delta: float) -> void:
	_process(delta)


func confirm_highlighted_for_test() -> void:
	_confirm(_highlighted)


func get_hold_progress_for_test() -> float:
	return _hold_up_progress


func is_hold_up_armed_for_test() -> bool:
	return _hold_up_armed


func get_option_label_for_test(i: int) -> Label:
	return _views[i] if i >= 0 and i < _views.size() else null


# --- internals ---------------------------------------------------------------

func _reset_input_state() -> void:
	_hold_up_progress = 0.0
	_left_held = false
	_right_held = false
	_left_repeat_timer = 0.0
	_right_repeat_timer = 0.0
	_hold_up_armed = not _is_pressed(&"move_up") # neutral-return rule, applied at activation -- see class header


func _is_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_pressed.get(action, false))
	return Input.is_action_pressed(action)


func _is_just_pressed(action: StringName) -> bool:
	if _use_test_input:
		return bool(_test_just_pressed.get(action, false))
	return Input.is_action_just_pressed(action)


func _clear_test_edges_for_frame() -> void:
	if _use_test_input:
		_test_just_pressed.clear()


func _process(delta: float) -> void:
	if not _active or _labels.is_empty():
		return
	_poll_cycle_input(delta)
	_poll_confirm_input()
	_poll_hold_up_input(delta)
	_update_fill_ring_visual()
	_clear_test_edges_for_frame()


func _poll_cycle_input(delta: float) -> void:
	var left_now: bool = _is_pressed(&"draft_cycle_left") or _is_pressed(&"move_left")
	var right_now: bool = _is_pressed(&"draft_cycle_right") or _is_pressed(&"move_right")

	if left_now and not _left_held:
		_cycle(-1)
		_left_repeat_timer = CYCLE_REPEAT_SECONDS
	elif left_now and _left_held:
		_left_repeat_timer -= delta
		if _left_repeat_timer <= 0.0:
			_cycle(-1)
			_left_repeat_timer = CYCLE_REPEAT_SECONDS
	_left_held = left_now

	if right_now and not _right_held:
		_cycle(1)
		_right_repeat_timer = CYCLE_REPEAT_SECONDS
	elif right_now and _right_held:
		_right_repeat_timer -= delta
		if _right_repeat_timer <= 0.0:
			_cycle(1)
			_right_repeat_timer = CYCLE_REPEAT_SECONDS
	_right_held = right_now


func _cycle(step: int) -> void:
	if _labels.is_empty():
		return
	_highlighted = wrapi(_highlighted + step, 0, _labels.size())
	_refresh_highlight()
	highlighted_changed.emit(_highlighted)


func _poll_confirm_input() -> void:
	if _is_just_pressed(&"confirm"):
		_confirm(_highlighted)


func _poll_hold_up_input(delta: float) -> void:
	var pressed: bool = _is_pressed(&"move_up")
	if not _hold_up_armed:
		if not pressed:
			_hold_up_armed = true
		return
	if pressed:
		_hold_up_progress += delta
		if _hold_up_progress >= HOLD_CONFIRM_SECONDS:
			_confirm(_highlighted)
			_hold_up_progress = 0.0
	else:
		_hold_up_progress = 0.0


func _confirm(index: int) -> void:
	if index < 0 or index >= _labels.size():
		return
	option_confirmed.emit(index)


func _on_hovered(index: int) -> void:
	_highlighted = index
	_refresh_highlight()
	highlighted_changed.emit(index)


func _on_option_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_highlighted = index
		_confirm(index)


func _refresh_highlight() -> void:
	for i in _views.size():
		_views[i].modulate = Color(1.0, 0.85, 0.2) if i == _highlighted else Color(1, 1, 1)


func _update_fill_ring_visual() -> void:
	if _fill_ring != null:
		_fill_ring.progress = clampf(_hold_up_progress / HOLD_CONFIRM_SECONDS, 0.0, 1.0)

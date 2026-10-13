extends Node
class_name UiInputMode

## Which kind of device the player used last: keyboard / gamepad, a real mouse, or a finger
## (author feedback 2026-10-13, decision D380). The selection language reads it so that:
##   - the keyboard focus ring shows ONLY while the last input was keyboard / gamepad (on a
##     touch screen, or after the mouse moved, a ring on whatever last took focus read as a
##     second selection);
##   - mouse hover brightens a plate only for a real mouse (a finger has no hover; the emulated
##     mouse a tap produces must not leave a stuck hover);
##   - a Draft card's confirm prompt names the key or the click that is actually live.
## It is a tiny node the first `SelectableState` adds to the tree root (not an autoload: docs/20
## fixes the autoload list); it only listens in `_input` and never consumes an event. The change
## signal lives on a RefCounted bus so tests and headless runs need no node in the tree.

enum Mode { KEYBOARD, MOUSE, TOUCH }

const JOY_AXIS_THRESHOLD: float = 0.5


class Bus extends RefCounted:
	signal mode_changed(mode: int)


static var _bus: Bus = Bus.new()
static var _listener: UiInputMode = null
static var _mode: int = -1 ## -1 until the first input: then the platform default
static var _pinned: bool = false ## a capture run pins the mode: the real cursor over its window must not flip it


## The current mode. Before any input: TOUCH in the touch layout (a phone build or `--touch-ui`),
## KEYBOARD on a desktop (the first focused control shows its ring until the mouse moves).
static func current() -> int:
	if _mode == -1:
		return Mode.TOUCH if TouchUi.is_mobile_layout() else Mode.KEYBOARD
	return _mode


static func is_keyboard() -> bool:
	return current() == Mode.KEYBOARD


static func is_mouse() -> bool:
	return current() == Mode.MOUSE


static func is_touch() -> bool:
	return current() == Mode.TOUCH


## Sets the mode and tells every listener. Public for tests and for hosts that know better.
static func set_mode(mode: int) -> void:
	var before: int = current()
	_mode = mode
	if before != mode:
		_bus.mode_changed.emit(mode)


## Forget what was learned (tests).
static func reset_for_test() -> void:
	_mode = -1
	_pinned = false


## Dev captures: fix the mode so no real input changes it.
static func pin(mode: int) -> void:
	set_mode(mode)
	_pinned = true


## Connects `callable` to mode changes (idempotent).
static func watch(callable: Callable) -> void:
	if not _bus.mode_changed.is_connected(callable):
		_bus.mode_changed.connect(callable)


static func unwatch(callable: Callable) -> void:
	if _bus.mode_changed.is_connected(callable):
		_bus.mode_changed.disconnect(callable)


## Adds the listening node to the scene tree root once. Safe to call from any `_ready`.
static func ensure_listening() -> void:
	if _listener != null and is_instance_valid(_listener):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or DisplayServer.get_name() == "headless":
		return # a headless run (the test suite) has no device to learn from
	_listener = UiInputMode.new()
	_listener.name = "UiInputMode"
	_listener.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_listener)


## The Draft footer line for the live device: the keys, the click or the tap that picks a card.
static func how_to_pick_text() -> String:
	UiStrings.ensure_registered()
	match current():
		Mode.MOUSE:
			return TranslationServer.translate("DRAFT_HOW_MOUSE")
		Mode.TOUCH:
			return TranslationServer.translate("DRAFT_HOW_TOUCH")
	return TranslationServer.translate("DRAFT_HOW_TO_PICK")


## Which mode an event implies, or -1 when it says nothing (a key release, a stick at rest,
## the mouse event a tap emulates).
static func classify(event: InputEvent) -> int:
	if event is InputEventKey:
		return Mode.KEYBOARD if (event as InputEventKey).pressed else -1
	if event is InputEventJoypadButton:
		return Mode.KEYBOARD if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		return Mode.KEYBOARD if absf((event as InputEventJoypadMotion).axis_value) > JOY_AXIS_THRESHOLD else -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return Mode.TOUCH
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return -1 # a tap's emulated mouse: the finger already said TOUCH
		return Mode.MOUSE
	return -1


func _input(event: InputEvent) -> void:
	var mode: int = classify(event)
	if mode >= 0 and mode != current() and not _pinned:
		UiInputMode.set_mode(mode)

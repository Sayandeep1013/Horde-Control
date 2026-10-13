class_name SafeArea
extends RefCounted

## Safe-area support in ONE place (phone feedback 2026-10-13, D370).
##
## Why: the Android build runs immersive (export_presets `immersive_mode`), so the
## camera punch-hole / notch, rounded corners and the gesture bar sit INSIDE the
## window. `DisplayServer.get_display_safe_area()` reports the usable rectangle in
## WINDOW pixels; every screen in this project lays out in LOGICAL canvas px
## (1920x1080 base, `canvas_items` + `expand`, times `Window.content_scale_factor`,
## see TouchUi). This class converts one into the other and gives every full-screen
## UI root two tools:
##
##  - `SafeArea.fit(control)`: the one-liner. `control` is a full-rect anchored
##    Control (or a child of a CanvasLayer root); its offsets are set to the safe
##    margins and re-applied whenever the window size, the content scale or the
##    inset changes. Backgrounds stay OUTSIDE it and may still bleed to the edges;
##    the interactive and text content goes INSIDE it.
##  - `SafeArea.watch(owner, callback)`: for hosts that position things themselves
##    (HUD clusters, toasts, touch buttons). `callback(margins: Vector4)` is called
##    now and on every change; margins are (left, top, right, bottom) in logical px.
##
## Margins = max(system inset, MIN_MARGIN_PX) on a phone (so rounded corners are
## respected even when the system reports no cutout), and exactly the system inset
## on desktop (zero), so the 1920x1080 desktop layout is untouched.
##
## Dev flag for desktop testing: `--safe-inset=L,T,R,B` in WINDOW pixels, e.g.
## `--safe-inset=110,0,0,40` (camera cutout on the left in landscape plus a gesture
## bar). The flag also switches the minimum margin on, as if on a phone.
## `set_inset_override_for_test()` does the same for tests.

const FLAG_INSET: String = "--safe-inset="
## Minimum edge margin on a phone, logical px (Register "Safe-area minimum margin").
const MIN_MARGIN_PX: float = 24.0

static var _override_active: bool = false
static var _override_insets: Vector4 = Vector4.ZERO
static var _cmd_checked: bool = false
static var _cmd_active: bool = false
static var _cmd_insets: Vector4 = Vector4.ZERO


## Window-pixel insets (left, top, right, bottom) that the system or the dev flag
## says are unusable. Zero on desktop without the flag.
static func window_insets_px(window: Window) -> Vector4:
	if _override_active:
		return _override_insets
	_read_cmdline()
	if _cmd_active:
		return _cmd_insets
	if window == null or not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var win: Vector2i = window.size
	if safe.size.x <= 0 or safe.size.y <= 0 or win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var screen: Vector2i = DisplayServer.screen_get_size(window.current_screen)
	# The safe rect is in screen px; the (immersive, fullscreen) window covers the screen.
	var sx: float = float(win.x) / maxf(1.0, float(screen.x))
	var sy: float = float(win.y) / maxf(1.0, float(screen.y))
	return Vector4(
		maxf(0.0, float(safe.position.x) * sx),
		maxf(0.0, float(safe.position.y) * sy),
		maxf(0.0, float(screen.x - safe.end.x) * sx),
		maxf(0.0, float(screen.y - safe.end.y) * sy))


## True when the minimum edge margin applies (phone layout, or a dev inset flag).
static func is_active() -> bool:
	_read_cmdline()
	return _override_active or _cmd_active or TouchUi.is_mobile_layout()


## Logical px per window px for `window` right now (1 / final-transform scale).
static func logical_per_px(window: Window) -> float:
	if window == null:
		return 1.0
	var s: float = window.get_final_transform().get_scale().x
	return 1.0 / s if s > 0.0001 else 1.0


## Safe margins in LOGICAL canvas px: (left, top, right, bottom).
static func margins(window: Window) -> Vector4:
	if window == null:
		return Vector4.ZERO
	var inset: Vector4 = window_insets_px(window)
	var k: float = logical_per_px(window)
	var m := Vector4(inset.x * k, inset.y * k, inset.z * k, inset.w * k)
	if is_active():
		m = Vector4(maxf(m.x, MIN_MARGIN_PX), maxf(m.y, MIN_MARGIN_PX), maxf(m.z, MIN_MARGIN_PX), maxf(m.w, MIN_MARGIN_PX))
	return m


## The safe rectangle in logical canvas px.
static func rect(window: Window) -> Rect2:
	if window == null:
		return Rect2()
	var m: Vector4 = margins(window)
	var size: Vector2 = Vector2(window.size) * logical_per_px(window)
	return Rect2(m.x, m.y, maxf(0.0, size.x - m.x - m.z), maxf(0.0, size.y - m.y - m.w))


## The full logical canvas of `window`.
static func canvas_size(window: Window) -> Vector2:
	return Vector2(window.size) * logical_per_px(window) if window != null else Vector2.ZERO


## Sets `control` (full-rect anchored) to the safe rectangle, now and on every change.
## `extra` adds to the margins (left, top, right, bottom), e.g. the HUD's own 20 px.
static func fit(control: Control, extra: Vector4 = Vector4.ZERO) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	watch(control, func(m: Vector4) -> void:
		control.offset_left = m.x + extra.x
		control.offset_top = m.y + extra.y
		control.offset_right = -(m.z + extra.z)
		control.offset_bottom = -(m.w + extra.w))


## Calls `callback(margins)` now and whenever the margins change; the watcher is a
## child of `owner` and dies with it. One watcher per owner and callback.
static func watch(owner: Node, callback: Callable) -> void:
	if owner == null:
		return
	var watcher := SafeAreaWatcher.new()
	watcher.callback = callback
	owner.add_child(watcher)


static func set_inset_override_for_test(insets: Variant) -> void:
	_override_active = insets is Vector4
	_override_insets = insets if insets is Vector4 else Vector4.ZERO


static func _read_cmdline() -> void:
	if _cmd_checked:
		return
	_cmd_checked = true
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(FLAG_INSET):
			var p: PackedStringArray = arg.trim_prefix(FLAG_INSET).split(",")
			if p.size() == 4:
				_cmd_active = true
				_cmd_insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
				return


## Child node that re-evaluates the margins when the window, the content scale or
## the inset changes (a cheap signature compare each frame; it also runs while the
## owner is hidden so a screen that opens later is already correct).
class SafeAreaWatcher extends Node:
	var callback: Callable
	var _signature: Array = []

	func _enter_tree() -> void:
		process_priority = -1000
		process_mode = Node.PROCESS_MODE_ALWAYS
		_refresh(true)

	func _ready() -> void:
		var window: Window = get_window()
		if window != null:
			window.size_changed.connect(_refresh.bind(false))

	func _process(_delta: float) -> void:
		_refresh(false)

	func _refresh(force: bool) -> void:
		var window: Window = get_window()
		if window == null or not callback.is_valid():
			return
		var m: Vector4 = SafeArea.margins(window)
		var sig: Array = [m, window.size, window.content_scale_factor]
		if not force and sig == _signature:
			return
		_signature = sig
		callback.call(m)

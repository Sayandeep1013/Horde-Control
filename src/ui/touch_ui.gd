class_name TouchUi
extends RefCounted

## Touch-UI gate (mobile port, D146). One place that answers "should the
## on-screen touch controls show, and is this a phone build?" so the HUD
## add-on (src/ui/touch_controls.gd), the Settings menu and the tests agree.
##
## Two separate questions, deliberately:
##  - `is_enabled()`: show the virtual joystick and the pause button. True on
##    a touchscreen device (`DisplayServer.is_touchscreen_available()`), on a
##    mobile build (`OS.has_feature("mobile")`), or with the `--touch-ui`
##    user arg (desktop captures and tests). `--no-touch-ui` forces it off.
##  - `is_mobile_layout()`: hide desktop-only Settings rows (Display mode,
##    V-Sync). True on a mobile build or with `--touch-ui`; a Windows laptop
##    that merely has a touchscreen keeps those rows.
##
## `set_override_for_test()` lets a test pin the answer without touching the
## command line. -1 = no override, 0 = off, 1 = on.

const FLAG_FORCE_ON: String = "--touch-ui"
const FLAG_FORCE_OFF: String = "--no-touch-ui"

## "Mobile UI scale" and "Touch target minimum" rows (D147).
## The project canvas is 1080 px tall and `canvas_items` stretching already
## scales it to the window. The mobile layout multiplies that by up to 1.5
## (`Window.content_scale_factor`): a 20:9 phone gets 1.5, a logical canvas of
## 1600x720, and text that was 22 px tall reads as 12 dp or more. A 16:9 phone
## gets less, because the HUD's top row needs a logical canvas at least
## `UI_MIN_LOGICAL_WIDTH_PX` wide. The camera divides the factor back out
## (src/camera/game_camera.gd), so the player sees the same amount of world.
const UI_SCALE_MAX: float = 1.5
const UI_MIN_LOGICAL_WIDTH_PX: float = 1560.0
const UI_BASE_HEIGHT_PX: float = 1080.0
## Smallest tap target on a menu row, in logical px (x1.5 on a 1080 px phone
## = 96 px, about 38 dp on a 6.7 in phone) -- the most that eight Settings
## rows fit into 720 px.
const MENU_TOUCH_MIN_PX: float = 64.0
## Smallest tap target for the few big buttons that have room (Title, Hub
## menus, Back): 80 logical px = 120 px on a 1080 px phone, about 47 dp.
const BUTTON_TOUCH_MIN_PX: float = 80.0

static var _override: int = -1
static var _scale_suspended: bool = false


static func is_enabled() -> bool:
	if _override != -1:
		return _override == 1
	if _has_user_arg(FLAG_FORCE_OFF):
		return false
	if _has_user_arg(FLAG_FORCE_ON) or OS.has_feature("mobile"):
		return true
	return DisplayServer.is_touchscreen_available()


## The real platform answer, ignoring `set_override_for_test()`. Used for
## one-time process-wide choices (the registered UI strings) that a test's
## override must not leak into.
static func is_mobile_layout_real() -> bool:
	return OS.has_feature("mobile") or _has_user_arg(FLAG_FORCE_ON)


static func is_mobile_layout() -> bool:
	if _override != -1:
		return _override == 1
	return OS.has_feature("mobile") or _has_user_arg(FLAG_FORCE_ON)


## `base` raised to the touch minimum in the mobile layout, unchanged on desktop.
static func touch_height(base: float) -> float:
	return maxf(base, MENU_TOUCH_MIN_PX) if is_mobile_layout() else base


static func touch_size(base: Vector2) -> Vector2:
	return Vector2(base.x, touch_height(base.y))


## For the big Title / Hub / Back buttons.
static func button_size(base: Vector2) -> Vector2:
	return Vector2(base.x, maxf(base.y, BUTTON_TOUCH_MIN_PX) if is_mobile_layout() else base.y)


## `Window.content_scale_factor` for the mobile layout; 1.0 elsewhere (and
## while a screen that cannot take the scale has suspended it).
static func ui_scale_for(window_size: Vector2) -> float:
	if not is_mobile_layout() or _scale_suspended or window_size.y <= 0.0:
		return 1.0
	var aspect: float = window_size.x / window_size.y
	return clampf(aspect * UI_BASE_HEIGHT_PX / UI_MIN_LOGICAL_WIDTH_PX, 1.0, UI_SCALE_MAX)


## Applies the mobile UI scale to `window` and keeps it applied when the
## window is resized or rotated. Safe to call repeatedly from any screen that
## can be the first one on screen; does nothing on desktop.
static func apply_ui_scale(window: Window) -> void:
	if window == null or not is_mobile_layout():
		return
	window.content_scale_factor = ui_scale_for(Vector2(window.size))
	var cb := Callable(TouchUi, "_on_window_resized").bind(window)
	if not window.size_changed.is_connected(cb):
		window.size_changed.connect(cb)


## The Skill Tree board is laid out in 1920x1080 px and does not fit a 720 px
## tall logical canvas, so it runs at scale 1.0 while it is open (D147).
static func set_scale_suspended(window: Window, suspended: bool) -> void:
	_scale_suspended = suspended
	if window != null and is_mobile_layout():
		window.content_scale_factor = ui_scale_for(Vector2(window.size))


static func _on_window_resized(window: Window) -> void:
	if window != null:
		window.content_scale_factor = ui_scale_for(Vector2(window.size))


static func set_override_for_test(value: int) -> void:
	_override = value


static func _has_user_arg(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag) or OS.get_cmdline_args().has(flag)

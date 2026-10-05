class_name TouchControls
extends CanvasLayer

## On-screen touch controls for a run (mobile port, D146 and D147). Kept in
## its own scene/script so the HUD files stay untouched by the port.
##
## Two things, both shown only when `TouchUi.is_enabled()`:
##  1. A floating virtual joystick over the left half of the screen. Godot
##     4.7's built-in `VirtualJoystick` is used in JOYSTICK_DYNAMIC mode: it
##     appears where the thumb lands. It drives the existing `move_left/
##     right/up/down` actions through the engine's own action strength, so
##     `Player._raw_input_direction()` (`Input.get_vector`) and every menu
##     that polls those actions need no change and no new Input Map action.
##  2. A pause button at the top right, below the Scrap panel. It injects the
##     same `pause` action Esc produces, so `RunFlowController`'s one
##     `_unhandled_input` handler stays the only pause path. It hides while
##     anything has paused the game (Draft, pause menu, focus loss), because
##     those screens own their own taps.
##
## Register citations (MASTER_SDLC.md > Provisional Values Register >
## Interfaces > "Touch controls", D147), mirrored as consts below:
## joystick diameter, tip diameter, dead-zone ratio, joystick zone width,
## pause button size and margins, and the opacity of the idle button.

const TOUCH_CANVAS_LAYER: int = 12 ## above Hud (10) and ThreatFeedback (11), below every menu (18+)

# --- "Touch controls" row (D147) ---
const JOYSTICK_SIZE_PX: float = 200.0
const JOYSTICK_TIP_SIZE_PX: float = 90.0
const JOYSTICK_DEADZONE_RATIO: float = 0.1
const JOYSTICK_ZONE_WIDTH_RATIO: float = 0.5
const PAUSE_BUTTON_SIZE_PX: float = 88.0 ## logical px; x1.5 = 132 px on a 1080 px phone = 48 dp
const PAUSE_BUTTON_MARGIN_RIGHT_PX: float = 20.0 ## HUD side margin
const PAUSE_BUTTON_TOP_PX: float = 128.0 ## clears the top HUD row and the Scrap panel's second line
const IDLE_ALPHA: float = 0.75

var joystick: VirtualJoystick = null
var pause_button: Button = null

var _pause_authority: Node = null


func _ready() -> void:
	layer = TOUCH_CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	TouchUi.apply_ui_scale(get_window())
	if not TouchUi.is_enabled():
		visible = false
		set_process_input(false)
		return
	_build_joystick()
	_build_pause_button()
	_pause_authority = get_node_or_null("/root/PauseAuthority")
	if _pause_authority != null and _pause_authority.has_signal(&"reasons_changed"):
		_pause_authority.reasons_changed.connect(_on_reasons_changed)
	_refresh_pause_visibility()


func _build_joystick() -> void:
	joystick = VirtualJoystick.new()
	joystick.name = "MoveJoystick"
	joystick.action_left = &"move_left"
	joystick.action_right = &"move_right"
	joystick.action_up = &"move_up"
	joystick.action_down = &"move_down"
	joystick.joystick_mode = VirtualJoystick.JOYSTICK_DYNAMIC
	joystick.visibility_mode = VirtualJoystick.VISIBILITY_WHEN_TOUCHED
	joystick.joystick_size = JOYSTICK_SIZE_PX
	joystick.tip_size = JOYSTICK_TIP_SIZE_PX
	joystick.deadzone_ratio = JOYSTICK_DEADZONE_RATIO
	# Left half, full height. The right half stays free for taps on the HUD
	# and the pause button.
	joystick.anchor_left = 0.0
	joystick.anchor_top = 0.0
	joystick.anchor_right = JOYSTICK_ZONE_WIDTH_RATIO
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 0.0
	joystick.offset_top = 0.0
	joystick.offset_right = 0.0
	joystick.offset_bottom = 0.0
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick.add_theme_stylebox_override("normal_joystick", _circle(Color(UiPalette.INK, 0.35), Color(UiPalette.LINE_STRONG, 0.8), JOYSTICK_SIZE_PX))
	joystick.add_theme_stylebox_override("normal_tip", _circle(Color(UiPalette.PARCHMENT, 0.55), Color(UiPalette.WOOD_BORDER, 0.9), JOYSTICK_TIP_SIZE_PX))
	joystick.add_theme_stylebox_override("pressed_joystick", _circle(Color(UiPalette.INK, 0.45), Color(UiPalette.ACCENT, 0.9), JOYSTICK_SIZE_PX))
	joystick.add_theme_stylebox_override("pressed_tip", _circle(Color(UiPalette.PARCHMENT, 0.8), Color(UiPalette.ACCENT, 1.0), JOYSTICK_TIP_SIZE_PX))
	add_child(joystick)


func _build_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.theme = UiTheme.get_theme()
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.custom_minimum_size = Vector2(PAUSE_BUTTON_SIZE_PX, PAUSE_BUTTON_SIZE_PX)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.anchor_top = 0.0
	pause_button.anchor_bottom = 0.0
	pause_button.offset_left = -(PAUSE_BUTTON_MARGIN_RIGHT_PX + PAUSE_BUTTON_SIZE_PX)
	pause_button.offset_right = -PAUSE_BUTTON_MARGIN_RIGHT_PX
	pause_button.offset_top = PAUSE_BUTTON_TOP_PX
	pause_button.offset_bottom = PAUSE_BUTTON_TOP_PX + PAUSE_BUTTON_SIZE_PX
	pause_button.modulate.a = IDLE_ALPHA
	pause_button.tooltip_text = ""
	pause_button.accessibility_name = "Pause"
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)

	# Two bars drawn with panels, not a font glyph: no font has to carry them.
	var center := CenterContainer.new()
	center.name = "PauseGlyph"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_button.add_child(center)
	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 14)
	center.add_child(bars)
	for i: int in 2:
		var bar := ColorRect.new()
		bar.color = UiPalette.TEXT
		bar.custom_minimum_size = Vector2(12.0, 36.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bars.add_child(bar)


## Same event Esc makes: `RunFlowController._unhandled_input` is the only
## pause handler, so there is exactly one pause path. Pushed straight into
## this viewport (`push_input`) rather than through `Input.parse_input_event`,
## so it reaches the same handlers with no dependency on the OS event queue.
func _on_pause_pressed() -> void:
	var down := InputEventAction.new()
	down.action = &"pause"
	down.pressed = true
	get_viewport().push_input(down)
	var up := InputEventAction.new()
	up.action = &"pause"
	up.pressed = false
	get_viewport().push_input(up)


func _on_reasons_changed(_reasons: Array = []) -> void:
	_refresh_pause_visibility()


func _refresh_pause_visibility() -> void:
	if pause_button == null:
		return
	var blocked: bool = false
	if _pause_authority != null and _pause_authority.has_method(&"get_active_reasons"):
		blocked = not (_pause_authority.get_active_reasons() as Array).is_empty()
	pause_button.visible = not blocked


func _circle(fill: Color, border: Color, diameter: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(UiPalette.BORDER_THICK)
	sb.set_corner_radius_all(int(diameter * 0.5))
	return sb

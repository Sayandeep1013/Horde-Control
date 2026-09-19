extends Control
class_name HudBar

## HudBar (P2.6). A custom-drawn progress bar shared by the player health
## bar, the Tower health bar, and the XP bar (docs/19_UI_UX.md > "HUD").
## Custom-drawn rather than ProgressBar/TextureProgressBar because two of
## the three Register rules below need geometry a stock progress bar does
## not expose: a fixed tick mark plus a border-SHAPE change (not colour
## alone), and a second overlaid segment for the Tower's shield.
##
## Register citations (cited, never restated as a bare literal elsewhere):
## - MASTER_SDLC.md > Provisional Values Register > Interfaces > "HUD":
##   "both bars tick at 40% and change border shape below it" -> TICK_FRACTION,
##   consumed only when `enable_health_tick_rule` is true (the player and
##   Tower health bars; not the XP bar, which the Register does not mention
##   in this rule at all).
## - > "Tower Health": "the Tower's shield drawn as an overlaid segment on
##   the health bar" -> `enable_shield_segment`, Tower bar only.
## - MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions": "No
##   gameplay-critical information may be conveyed through colour alone.
##   Shape and motion must carry it as well." -- the border-shape change
##   below the tick (sharp corners + thicker border vs rounded + thin) is
##   what satisfies this for the low-health state; colour still changes too,
##   but shape carries the information independently of it.
##
## Godot Implementation note (docs/19 > "UI Layout & Dynamic Container
## Rules" > "Max Dimensions"): this Control is given a `custom_minimum_size`
## by its owner (Hud._build_ui()) and never has a fixed `size` assigned in
## code; its actual on-screen size is left to the container it sits in.

## Register > Interfaces > "HUD": "both bars tick at 40% of maximum and
## change border shape below it."
const TICK_FRACTION: float = 0.4

## The Tower's shield segment is drawn as a thinner strip along the top of
## the bar rather than a second colour smeared over the same rectangle -
## the SHAPE (a distinct sub-region, not just a different hue) is what makes
## "overlaid segment" readable under the colour-only rule above, even though
## no rule explicitly names this a colour-only case.
const SHIELD_SEGMENT_HEIGHT_FRACTION: float = 0.35

@export var enable_health_tick_rule: bool = false
@export var enable_shield_segment: bool = false
@export var fill_color: Color = Color(0.30, 0.80, 0.35, 0.95)
@export var low_fill_color: Color = Color(0.85, 0.20, 0.18, 0.95)
@export var shield_color: Color = Color(0.45, 0.75, 1.0, 0.9)
@export var background_color: Color = Color(0.06, 0.06, 0.08, 0.85)
@export var border_color: Color = Color(0.92, 0.92, 0.92, 0.9)
@export var tick_color: Color = Color(1.0, 1.0, 1.0, 0.85)

var _value: float = 0.0
var _max_value: float = 1.0
var _shield_value: float = 0.0
var _shield_max_value: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(240, 22)


## Typed command: sets the bar's own value/max (health, or XP progress).
func set_value(current: float, max_v: float) -> void:
	var changed: bool = not is_equal_approx(current, _value) or not is_equal_approx(max_v, _max_value)
	_value = current
	_max_value = max_v
	if changed:
		queue_redraw()


## Typed command: sets the overlaid shield segment (Tower bar only; a
## caller may still call this on a bar with `enable_shield_segment = false`,
## it will simply never be drawn).
func set_shield(current: float, max_v: float) -> void:
	var changed: bool = not is_equal_approx(current, _shield_value) or not is_equal_approx(max_v, _shield_max_value)
	_shield_value = current
	_shield_max_value = max_v
	if changed:
		queue_redraw()


func get_fraction() -> float:
	if _max_value <= 0.0:
		return 0.0
	return clampf(_value / _max_value, 0.0, 1.0)


## True once the CURRENT value (not the shield) has dropped below the
## Register's 40% tick, for bars that opt into the rule at all.
func is_below_tick() -> bool:
	return enable_health_tick_rule and get_fraction() < TICK_FRACTION


func get_value() -> float:
	return _value


func get_max_value() -> float:
	return _max_value


func get_shield_value() -> float:
	return _shield_value


func get_shield_max_value() -> float:
	return _shield_max_value


func _draw() -> void:
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return
	var fraction: float = get_fraction()
	var below_tick: bool = is_below_tick()

	draw_rect(Rect2(Vector2.ZERO, box_size), background_color, true)

	var fill_top: float = 0.0
	var fill_height: float = box_size.y
	if enable_shield_segment:
		fill_top = box_size.y * SHIELD_SEGMENT_HEIGHT_FRACTION
		fill_height = box_size.y - fill_top

	var current_fill_color: Color = low_fill_color if below_tick else fill_color
	draw_rect(Rect2(Vector2(0.0, fill_top), Vector2(box_size.x * fraction, fill_height)), current_fill_color, true)

	if enable_shield_segment and _max_value > 0.0:
		# The shield strip is scaled against the HEALTH bar's own max, not the
		# shield's own max, so "shield = 25% of Tower max health" (Register >
		# Tower) reads as one quarter of the SAME bar length health uses -
		# the two pools share one visual scale, per "overlaid ... on the
		# health bar."
		var shield_fraction: float = clampf(_shield_value / _max_value, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, Vector2(box_size.x * shield_fraction, fill_top)), shield_color, true)

	if enable_health_tick_rule:
		var tick_x: float = box_size.x * TICK_FRACTION
		draw_line(Vector2(tick_x, 0.0), Vector2(tick_x, box_size.y), tick_color, 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border_color
	style.set_border_width_all(int(get_border_width()))
	style.set_corner_radius_all(get_border_corner_radius())
	draw_style_box(style, Rect2(Vector2.ZERO, box_size))


## Border SHAPE (width + corner radius), not colour, is what carries the
## below-tick state independently of colour (MASTER_SDLC.md > Visual Edge
## Cases > "Colour-only distinctions"). Exposed as its own methods, used by
## `_draw()` above, so a test can assert the SAME values `_draw()` actually
## renders instead of re-deriving them.
func get_border_width() -> float:
	return 4.0 if is_below_tick() else 2.0


func get_border_corner_radius() -> int:
	return 0 if is_below_tick() else 6

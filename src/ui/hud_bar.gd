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
##
## ## UI pass (phases/UI_PASS/BRIEF.md, package A): palette + cosmetic polish
## Every literal `Color(...)` default is now read from `UiPalette` (set in
## `_init()`, not as an inline `@export` default expression, so this file
## has one obvious place to look rather than six -- `hud.gd` still overrides
## `fill_color`/`shield_color` per instance role, e.g. `UiPalette.TOWER` for
## the Tower bar). `get_border_width()`/`get_border_corner_radius()` now
## return `UiPalette.BORDER_THIN`/`BORDER_THICK` and `0`/`RADIUS_SMALL`
## instead of bare `2.0`/`4.0`/`6` -- confirmed against
## tests/unit/hud_layout_test.gd first: it asserts `is_greater(2.0)`,
## `is_equal(0)`, and `is_greater(0)`, never the exact old numbers, so the
## SHAPE-CHANGE semantics survive unchanged while the numbers become
## palette-driven. `_draw()` adds three purely cosmetic layers that never
## touch `_value`/`_max_value`/`_shield_value` or any getter's return value:
## a rounded track and fill (square-cornered on the fill's cut edge, both
## corners rounding once the fill reaches 100%), a faint top highlight band,
## a trailing "ghost" segment that lags behind a drop over `UiPalette.
## BAR_LAG` seconds, and a brief flash over `UiPalette.BAR_FLASH` seconds on
## a loss. Both are driven from `_process(delta)`, per the brief's own
## suggestion ("the HUD is PROCESS_MODE_ALWAYS") -- every HudBar in this
## project is always a descendant of `Hud`, which is already
## `PROCESS_MODE_ALWAYS`, and is always inside the tree by the time any test
## touches it (see hud_layout_test.gd/hud_economy_display_test.gd, which
## always `add_child(hud)` first).

## Register > Interfaces > "HUD": "both bars tick at 40% of maximum and
## change border shape below it."
const TICK_FRACTION: float = 0.4

## The Tower's shield segment is drawn as a thinner strip along the top of
## the bar rather than a second colour smeared over the same rectangle -
## the SHAPE (a distinct sub-region, not just a different hue) is what makes
## "overlaid segment" readable under the colour-only rule above, even though
## no rule explicitly names this a colour-only case.
const SHIELD_SEGMENT_HEIGHT_FRACTION: float = 0.35

## Cosmetic-only constants with no UiPalette equivalent yet (UiPalette has a
## spacing/radius/motion scale, not an "overlay alpha" scale).
## TODO(ui-pass): promote to UiPalette if a later pass wants these shared.
const GHOST_ALPHA: float = 0.35 ## trailing "lost value" segment's opacity
const FLASH_PEAK_ALPHA: float = 0.55 ## the loss-flash's peak opacity
const HIGHLIGHT_ALPHA: float = 0.10 ## the top inner highlight band's opacity
const FALLBACK_MIN_SIZE: Vector2 = Vector2(240, 22) ## defensive default only; every real owner sets its own custom_minimum_size (hud.gd)

@export var enable_health_tick_rule: bool = false
@export var enable_shield_segment: bool = false
@export var fill_color: Color
@export var low_fill_color: Color
@export var shield_color: Color
@export var background_color: Color
@export var border_color: Color
@export var tick_color: Color

var _value: float = 0.0
var _max_value: float = 1.0
var _shield_value: float = 0.0
var _shield_max_value: float = 0.0

## Cosmetic-only state (UI pass): never read by get_value()/get_fraction()/
## is_below_tick(), only by _draw(). `_ghost_fraction` is a FRACTION, not a
## raw value, so it lags correctly even if `_max_value` itself changes
## mid-animation.
var _ghost_fraction: float = 0.0
var _flash_alpha: float = 0.0


## Defaults every colour export from UiPalette. Done here, not as an inline
## `@export var x: Color = UiPalette.X` default expression, so every default
## lives in one obvious block instead of scattered across six declarations.
func _init() -> void:
	fill_color = UiPalette.PLAYER
	low_fill_color = UiPalette.DANGER
	shield_color = UiPalette.SHIELD
	background_color = UiPalette.with_alpha(UiPalette.INK, UiPalette.PANEL_ALPHA)
	border_color = UiPalette.LINE_STRONG
	tick_color = UiPalette.TEXT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = FALLBACK_MIN_SIZE
	# UI-pass follow-up fix: a HudBar is a slim, fixed-height bar, never a
	# fill-the-row shape. Left at the Control default (SIZE_FILL), an
	# HBoxContainer/VBoxContainer row that happens to be taller than the
	# bar itself -- e.g. because a SIBLING label's own minimum width was
	# wrong and it wrapped vertically -- stretched the bar to match that
	# row's height (observed: the player bar rendering ~235x160 instead of
	# ~240x18). SHRINK_CENTER makes the bar hold its own custom_minimum_size
	# height and centre within whatever vertical space its row is given,
	# independent of what any sibling does. This is a second, independent
	# line of defence on top of fixing the actual starvation bug in
	# hud.gd's label minimum widths -- the bar must never stretch, even if
	# some future sibling gets this wrong again.
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Advances the two cosmetic-only effects (ghost catch-up, loss flash).
## Guarded by `animating` so a bar that never loses value never redraws for
## no reason.
func _process(delta: float) -> void:
	var animating: bool = false
	var fraction: float = get_fraction()
	if _ghost_fraction > fraction + 0.0005:
		var step: float = delta / UiPalette.BAR_LAG
		_ghost_fraction = maxf(fraction, _ghost_fraction - step)
		animating = true
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta / UiPalette.BAR_FLASH)
		animating = true
	if animating:
		queue_redraw()


## Typed command: sets the bar's own value/max (health, or XP progress).
## A drop in the displayed FRACTION (not necessarily `current` alone --
## `max_v` changing can drop it too) seeds the ghost segment at the old
## fraction and starts the loss flash; a rise just snaps the ghost up with
## no animation. Purely cosmetic bookkeeping: `_value`/`_max_value` are set
## unconditionally either way, exactly as before this pass.
func set_value(current: float, max_v: float) -> void:
	var changed: bool = not is_equal_approx(current, _value) or not is_equal_approx(max_v, _max_value)
	if changed:
		var old_fraction: float = get_fraction()
		_value = current
		_max_value = max_v
		var new_fraction: float = get_fraction()
		if new_fraction < old_fraction - 0.0005:
			_ghost_fraction = maxf(_ghost_fraction, old_fraction)
			_flash_alpha = 1.0
		else:
			_ghost_fraction = maxf(_ghost_fraction, new_fraction)
		queue_redraw()
	else:
		_value = current
		_max_value = max_v


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
	var corner_radius: int = get_border_corner_radius()
	var border_width: float = get_border_width()

	# Track: a rounded background whose corners square off in step with the
	# border below the Register's 40% tick -- the whole bar reads as one
	# shape changing, not a rounded fill sitting inside a differently-shaped
	# frame.
	var track := StyleBoxFlat.new()
	track.bg_color = background_color
	track.anti_aliasing = true
	track.set_corner_radius_all(corner_radius)
	draw_style_box(track, Rect2(Vector2.ZERO, box_size))

	var fill_top: float = 0.0
	var fill_height: float = box_size.y
	if enable_shield_segment:
		fill_top = box_size.y * SHIELD_SEGMENT_HEIGHT_FRACTION
		fill_height = box_size.y - fill_top

	var current_fill_color: Color = low_fill_color if below_tick else fill_color

	# Cosmetic: a trailing "ghost" segment showing the fraction this bar
	# most recently held, fading down to meet the new one over
	# UiPalette.BAR_LAG seconds (advanced in _process()). Never read by any
	# getter.
	if _ghost_fraction > fraction + 0.001:
		var ghost_rect := Rect2(Vector2(box_size.x * fraction, fill_top), Vector2(box_size.x * (_ghost_fraction - fraction), fill_height))
		draw_style_box(_fill_box(UiPalette.with_alpha(current_fill_color, GHOST_ALPHA), 0, 0), ghost_rect)

	if fraction > 0.0:
		# Rounded on the leading (left) edge always; the trailing (cut) edge
		# only rounds once the bar is completely full, so a partial fill's
		# straight cut reads as a cut, not a rounded nub.
		var right_radius: int = corner_radius if fraction >= 0.999 else 0
		draw_style_box(_fill_box(current_fill_color, corner_radius, right_radius), Rect2(Vector2(0.0, fill_top), Vector2(box_size.x * fraction, fill_height)))

	if enable_shield_segment and _max_value > 0.0:
		# The shield strip is scaled against the HEALTH bar's own max, not the
		# shield's own max, so "shield = 25% of Tower max health" (Register >
		# Tower) reads as one quarter of the SAME bar length health uses -
		# the two pools share one visual scale, per "overlaid ... on the
		# health bar."
		var shield_fraction: float = clampf(_shield_value / _max_value, 0.0, 1.0)
		if shield_fraction > 0.0:
			var shield_right_radius: int = corner_radius if shield_fraction >= 0.999 else 0
			draw_style_box(_fill_box(shield_color, corner_radius, shield_right_radius), Rect2(Vector2.ZERO, Vector2(box_size.x * shield_fraction, fill_top)))

	# Cosmetic: a subtle inner highlight band near the top of the whole
	# track, independent of fill level, for a slight glossy read.
	var highlight_height: float = maxf(1.0, box_size.y * 0.22)
	var highlight_inset: float = border_width + 1.0
	if box_size.x > highlight_inset * 2.0:
		draw_rect(Rect2(Vector2(highlight_inset, highlight_inset), Vector2(box_size.x - highlight_inset * 2.0, highlight_height)), UiPalette.with_alpha(UiPalette.TEXT, HIGHLIGHT_ALPHA), true)

	if enable_health_tick_rule:
		var tick_x: float = box_size.x * TICK_FRACTION
		draw_line(Vector2(tick_x, 0.0), Vector2(tick_x, box_size.y), tick_color, 2.0)

	# Cosmetic: a brief flash across the whole bar on a value LOSS, fading
	# over UiPalette.BAR_FLASH seconds (advanced in _process()). Drawn last
	# so it reads over the fill/shield/tick.
	if _flash_alpha > 0.0:
		draw_style_box(_fill_box(UiPalette.with_alpha(UiPalette.TEXT, _flash_alpha * FLASH_PEAK_ALPHA), corner_radius, corner_radius), Rect2(Vector2.ZERO, box_size))

	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = border_color
	border.set_border_width_all(int(border_width))
	border.set_corner_radius_all(corner_radius)
	border.anti_aliasing = true
	draw_style_box(border, Rect2(Vector2.ZERO, box_size))


## A flat, borderless fill box with independently rounded left/right
## corners (top+bottom share each side's radius), used for the fill, the
## shield strip, the ghost segment, and the loss flash.
func _fill_box(color: Color, left_radius: int, right_radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.anti_aliasing = true
	sb.set_corner_radius(CORNER_TOP_LEFT, left_radius)
	sb.set_corner_radius(CORNER_BOTTOM_LEFT, left_radius)
	sb.set_corner_radius(CORNER_TOP_RIGHT, right_radius)
	sb.set_corner_radius(CORNER_BOTTOM_RIGHT, right_radius)
	return sb


## Border SHAPE (width + corner radius), not colour, is what carries the
## below-tick state independently of colour (MASTER_SDLC.md > Visual Edge
## Cases > "Colour-only distinctions"). Exposed as its own methods, used by
## `_draw()` above, so a test can assert the SAME values `_draw()` actually
## renders instead of re-deriving them.
##
## UI pass: now returns UiPalette.BORDER_THICK/BORDER_THIN (3.0/2.0) instead
## of bare 4.0/2.0 -- tests/unit/hud_layout_test.gd only asserts
## `is_greater(2.0)`, never the literal old value, so the inequality (and
## therefore the shape-change semantics) survives unchanged.
func get_border_width() -> float:
	return float(UiPalette.BORDER_THICK) if is_below_tick() else float(UiPalette.BORDER_THIN)


## UI pass: returns UiPalette.RADIUS_SMALL (4) instead of a bare 6 for the
## "not below tick" case -- tests/unit/hud_layout_test.gd only asserts
## `is_greater(0)`, never the literal old value. The below-tick case stays a
## bare 0: "sharp square corner" is the shape itself, not a palette radius.
func get_border_corner_radius() -> int:
	return 0 if is_below_tick() else UiPalette.RADIUS_SMALL

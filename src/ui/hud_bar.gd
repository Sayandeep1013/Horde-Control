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
##
## ## Tiny Swords restyle (second UI pass): a decaying shake on a loss
## Task instruction: "a shake/flash when taking damage". The flash already
## existed (above); a shake is added the same way -- a purely visual,
## decaying offset driven from `_process(delta)`, seeded on the exact same
## branch that already seeds the loss flash, so both fire together on every
## real loss and neither can fire without the other going stale. It moves
## `offset_transform_position`, never `position`/`size` (this Control always
## sits in a Container -- docs/19 > "UI Layout"), matching
## `src/ui/draft_card_view.gd`'s own established use of that same visual-
## only property for its highlight lift and entrance animations.
##
## ## Tiny Swords restyle (second UI pass): a gain glow, symmetric to the
## loss flash
## Task instruction (XP bar): "a fill glow/animation on gain." Every
## `HudBar` already had a flash on a LOSS (`_flash_alpha`, white); this adds
## the mirror case on a RISE (`_gain_glow_alpha`, `UiPalette.GOLD`-tinted,
## `UiPalette.XP_GLOW` seconds) on the exact branch that already handles a
## rise, so the player and Tower bars get a subtle heal glow "for free" and
## the XP bar's own gain -- the task's explicit ask -- is simply this same
## generic behaviour applied to one more `HudBar` instance, not a special
## case.

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

## Second UI pass: remaining shake time, counting down from
## `UiPalette.BAR_SHAKE` to 0 on a loss; never read outside `_process()`.
var _shake_remaining: float = 0.0
## Second UI pass: gain-glow alpha, counting down from 1.0 to 0 over
## `UiPalette.XP_GLOW` seconds on a rise; never read outside `_process()`/`_draw()`.
var _gain_glow_alpha: float = 0.0


## Defaults every colour export from UiPalette. Done here, not as an inline
## `@export var x: Color = UiPalette.X` default expression, so every default
## lives in one obvious block instead of scattered across six declarations.
func _init() -> void:
	fill_color = UiPalette.PLAYER
	low_fill_color = UiPalette.DANGER
	shield_color = UiPalette.SHIELD
	background_color = UiPalette.with_alpha(UiPalette.INK, UiPalette.PANEL_ALPHA)
	border_color = UiPalette.INK_PIXEL
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
	# Second UI pass: the shake below moves `offset_transform_position`, a
	# visual-only transform (see class header) that needs this flag on
	# before it has any effect -- matches draft_card_view.gd's own _init().
	offset_transform_enabled = true


## Advances the three cosmetic-only effects (ghost catch-up, loss flash,
## damage shake). Guarded by `animating` so a bar that never loses value
## never redraws for no reason.
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
	if _gain_glow_alpha > 0.0:
		_gain_glow_alpha = maxf(0.0, _gain_glow_alpha - delta / UiPalette.XP_GLOW)
		animating = true
	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - delta)
		var decay: float = _shake_remaining / UiPalette.BAR_SHAKE
		# A decaying sideways wobble -- sin() at a fixed frequency scaled by
		# the remaining time, so it settles to Vector2.ZERO exactly when
		# _shake_remaining reaches 0 rather than snapping.
		offset_transform_position = Vector2(sin(_shake_remaining * 50.0) * UiPalette.BAR_SHAKE_AMPLITUDE_PX * decay, 0.0)
		animating = true
	elif offset_transform_position != Vector2.ZERO:
		offset_transform_position = Vector2.ZERO
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
			_shake_remaining = UiPalette.BAR_SHAKE # second UI pass: "a shake/flash when taking damage" -- same trigger as the flash above
		else:
			_ghost_fraction = maxf(_ghost_fraction, new_fraction)
			if new_fraction > old_fraction + 0.0005:
				_gain_glow_alpha = 1.0 # second UI pass: "a fill glow/animation on gain" -- see class header
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


## Art-consistency pass (D160): drawn as pixel art, not as anti-aliased
## rounded StyleBoxFlats. The bar is a hard-edged ink border (the pack's ink
## colour, `UiPalette.INK_PIXEL`) around square fills; the "rounded" corner of
## the above-tick state is a two-pixel chamfer on the border's corners, and
## the below-tick state is the plain square corner, so the border-SHAPE cue
## (get_border_corner_radius() > 0 versus 0) is unchanged. Every edge is a
## whole pixel, so nothing is resampled at any window size.
const CHAMFER_PX: int = 2


func _draw() -> void:
	var box_size: Vector2 = size
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return
	var fraction: float = get_fraction()
	var below_tick: bool = is_below_tick()
	var corner_radius: int = get_border_corner_radius()
	var bw: float = get_border_width()
	var notch: float = float(CHAMFER_PX) if corner_radius > 0 else 0.0

	# Ink border (a chamfered or square solid), then the inner area on top.
	_draw_chamfered(Rect2(Vector2.ZERO, box_size), border_color, notch)
	var inner := Rect2(Vector2(bw, bw), box_size - Vector2(bw, bw) * 2.0)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	draw_rect(inner, background_color, true)

	var fill_top: float = 0.0
	var fill_height: float = inner.size.y
	if enable_shield_segment:
		fill_top = inner.size.y * SHIELD_SEGMENT_HEIGHT_FRACTION
		fill_height = inner.size.y - fill_top

	var current_fill_color: Color = low_fill_color if below_tick else fill_color
	var fill_w: float = round(inner.size.x * fraction)

	# Cosmetic trailing "ghost" segment (see _process()).
	if _ghost_fraction > fraction + 0.001:
		var ghost_w: float = round(inner.size.x * (_ghost_fraction - fraction))
		draw_rect(Rect2(inner.position + Vector2(fill_w, fill_top), Vector2(ghost_w, fill_height)), UiPalette.with_alpha(current_fill_color, GHOST_ALPHA), true)

	if fraction > 0.0:
		var fill_rect := Rect2(inner.position + Vector2(0.0, fill_top), Vector2(fill_w, fill_height))
		draw_rect(fill_rect, current_fill_color, true)
		# A one-pixel lighter top edge and a darker bottom edge: the pack's
		# flat three-tone shading, replacing the old translucent gloss band.
		if fill_rect.size.x > 0.0 and fill_rect.size.y > 4.0:
			draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, 2.0)), current_fill_color.lightened(0.25), true)
			draw_rect(Rect2(fill_rect.position + Vector2(0.0, fill_rect.size.y - 2.0), Vector2(fill_rect.size.x, 2.0)), current_fill_color.darkened(0.25), true)
		if _gain_glow_alpha > 0.0:
			draw_rect(fill_rect, UiPalette.with_alpha(UiPalette.GOLD, _gain_glow_alpha * FLASH_PEAK_ALPHA), true)

	if enable_shield_segment and _max_value > 0.0:
		# The shield strip is scaled against the HEALTH bar's own max (see the
		# class header), so both pools share one visual scale.
		var shield_fraction: float = clampf(_shield_value / _max_value, 0.0, 1.0)
		if shield_fraction > 0.0:
			draw_rect(Rect2(inner.position, Vector2(round(inner.size.x * shield_fraction), fill_top)), shield_color, true)

	if enable_health_tick_rule:
		var tick_x: float = round(inner.position.x + inner.size.x * TICK_FRACTION)
		draw_rect(Rect2(Vector2(tick_x, inner.position.y), Vector2(2.0, inner.size.y)), tick_color, true)

	# Cosmetic: a brief flash across the whole bar on a value LOSS.
	if _flash_alpha > 0.0:
		draw_rect(inner, UiPalette.with_alpha(UiPalette.TEXT, _flash_alpha * FLASH_PEAK_ALPHA), true)


## A solid rect with its four corners cut by `notch` px (0 = a plain rect).
func _draw_chamfered(rect: Rect2, color: Color, notch: float) -> void:
	if notch <= 0.0:
		draw_rect(rect, color, true)
		return
	draw_rect(Rect2(rect.position + Vector2(notch, 0.0), Vector2(rect.size.x - notch * 2.0, rect.size.y)), color, true)
	draw_rect(Rect2(rect.position + Vector2(0.0, notch), Vector2(rect.size.x, rect.size.y - notch * 2.0)), color, true)


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

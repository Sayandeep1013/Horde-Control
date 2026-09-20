extends Control
class_name DraftFillRing

## Hold-to-confirm fill ring (P2.12). docs/19_UI_UX.md > "Upgrade Draft UI &
## Navigation" > "Movement-only": "holding up for 1.0 second confirms the
## highlighted card, filling a visible ring that resets if the hold is
## released before it completes." MASTER_SDLC.md > Provisional Values
## Register > "Progression & Upgrades" > "Draft input": "hold up 1.0 s
## confirms with a fill ring that resets on release."
##
## Purely a display: `progress` (0..1) is driven every frame by
## DraftController from its own hold-up accumulator (see that file's header
## for why the accumulator is not SimClock-driven). This node never reads
## input or a clock itself -- a typed `set`, nothing else, matching this
## project's "small typed surface" convention.
##
## `custom_minimum_size` is set by the caller (DraftController), not fixed
## here, so this stays a reusable, size-agnostic widget per docs/19 > "UI
## Layout & Dynamic Container Rules": "Containers must have a defined
## custom_minimum_size but no fixed size."
##
## ## UI Pass restyle (look only -- `progress` semantics, the exported
## `ring_color`/`track_color` names, and the sizing contract above are
## unchanged; this is also used by src/run/paused_choice_bar.gd and the
## pause/settings/run-end menus, so only the drawing changed)
## `_draw()` now layers, back to front: a dark, opaque under-stroke (reads
## against any battlefield content behind this Control, per
## phases/UI_PASS/PLAN.md's direction), a dim track from `UiPalette`, the
## accent progress arc, and a rounded cap (a small filled circle) at each
## end of that arc -- `draw_arc()` has no native line-cap option, so a
## circle the width of the stroke at each endpoint is this project's own
## way of faking one. `antialiased = true` was already passed to
## `draw_arc()` before this pass; kept, and matched on the new
## `draw_circle()` calls.

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

## Never the only signal of state -- this ring is a supplementary visual
## for the hold timer, not a Player/Tower differentiation channel (that
## rule lives in DraftCardView), so a colour-only ring here does not
## violate "never by colour alone" (Register > Visual Edge Cases).
@export var ring_color: Color = UiPalette.ACCENT
@export var track_color: Color = UiPalette.with_alpha(UiPalette.LINE, 0.55)
@export var ring_width: float = DEFAULT_RING_WIDTH
## Optional small glyph drawn at the ring's centre (e.g. a "hold up" arrow).
## Empty (the default) draws nothing -- every existing caller that never set
## this keeps its previous, glyph-less look.
@export var center_glyph: String = ""

## No UiPalette token covers a ring's stroke width or its under-stroke's
## extra margin -- both are specific to this one custom-drawn widget, not a
## reusable spacing/colour concept. TODO(ui-pass): promote to UiPalette if
## another custom-drawn ring ever needs the same numbers.
const DEFAULT_RING_WIDTH: float = 6.0
const UNDER_STROKE_MARGIN: float = 2.0
const UNDER_STROKE_COLOR: Color = UiPalette.INK
const ARC_POINTS: int = 48


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5 - ring_width
	if r <= 0.0:
		return
	var center: Vector2 = size * 0.5

	# Dark under-stroke, wider than every ring drawn on top of it, so the
	# whole widget reads as one shape against bright or busy backgrounds
	# rather than blending into them.
	draw_arc(center, r, 0.0, TAU, ARC_POINTS, UNDER_STROKE_COLOR, ring_width + UNDER_STROKE_MARGIN, true)
	draw_arc(center, r, 0.0, TAU, ARC_POINTS, track_color, ring_width, true)

	if progress > 0.0:
		# Starts at the top (-PI/2) and sweeps clockwise, a conventional
		# "filling" direction for a confirm ring.
		var start_angle: float = -PI / 2.0
		var end_angle: float = start_angle + TAU * progress
		draw_arc(center, r, start_angle, end_angle, ARC_POINTS, ring_color, ring_width, true)
		_draw_round_cap(center, r, start_angle)
		_draw_round_cap(center, r, end_angle)

	if center_glyph != "":
		_draw_center_glyph(center, r)


## Fakes a rounded line cap at one end of the progress arc: `draw_arc()`
## itself has no cap style, so a small filled circle the stroke's own width,
## centred on the arc's edge point, closes it off with the same rounded
## silhouette a `LINE_CAP_ROUND` stroke would have.
func _draw_round_cap(center: Vector2, r: float, angle: float) -> void:
	var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * r
	draw_circle(point, ring_width * 0.5, ring_color, true, -1.0, true)


func _draw_center_glyph(center: Vector2, r: float) -> void:
	var font: Font = UiTheme.get_display_font()
	var font_size: int = maxi(1, int(r * 1.1))
	var glyph_size: Vector2 = font.get_string_size(center_glyph, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var baseline: Vector2 = center + Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.35)
	var color: Color = ring_color if progress > 0.0 else track_color
	draw_string(font, baseline, center_glyph, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, color)


func reset() -> void:
	progress = 0.0


func get_progress_for_test() -> float:
	return progress

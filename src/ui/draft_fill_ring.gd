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

var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

## Never the only signal of state -- this ring is a supplementary visual
## for the hold timer, not a Player/Tower differentiation channel (that
## rule lives in DraftCardView), so a colour-only ring here does not
## violate "never by colour alone" (Register > Visual Edge Cases).
@export var ring_color: Color = Color(1.0, 0.85, 0.2)
@export var track_color: Color = Color(0.3, 0.3, 0.35, 0.6)
@export var ring_width: float = 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5 - ring_width
	if r <= 0.0:
		return
	var center: Vector2 = size * 0.5
	draw_arc(center, r, 0.0, TAU, 48, track_color, ring_width, true)
	if progress > 0.0:
		# Starts at the top (-PI/2) and sweeps clockwise, a conventional
		# "filling" direction for a confirm ring.
		draw_arc(center, r, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, ring_color, ring_width, true)


func reset() -> void:
	progress = 0.0


func get_progress_for_test() -> float:
	return progress

extends Control
class_name HudLevelEmblem

## Round level emblem (Tiny Swords restyle, second UI pass; task
## instruction: "the level shown in a round emblem"). A small, custom-drawn
## circular badge (wood fill, bronze/gold ring) sitting BEHIND
## `Hud._level_label` -- see `Hud._build_xp_field()`, which reparents the
## existing `LevelLabel` node (same name, same object, same
## `get_level_label()` seam) inside this Control's full rect. Nothing about
## the label's identity, text, or visibility changes; this only adds a
## backdrop, matching this project's established "typed, purely cosmetic
## widget" convention (HudBar, DraftFillRing, OutcomeGlyph all follow the
## same shape: a plain `set`/typed command, `_draw()`, nothing else read by
## any test).
##
## `trigger_burst()` is called by `Hud._refresh_xp()` on a level increase
## (task instruction: "a burst when a level-up is ready" -- read here as "a
## level-up just landed", the one moment this HUD can observe without a new
## EventBus signal this task's write scope does not extend to; see
## hud.gd's own header for the established convention of naming a
## cross-task seam rather than inventing one). Purely visual: it never
## delays or gates the real `level`/`xp_current` values `_refresh_xp()`
## already sets on the unchanged Label nodes every frame.

var fill_color: Color = UiPalette.SURFACE
var ring_color: Color = UiPalette.ACCENT

var _burst: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _burst > 0.0:
		_burst = maxf(0.0, _burst - delta / UiPalette.XP_BURST)
		queue_redraw()


## Typed command: starts the celebration pulse (task: "a burst when a
## level-up is ready"). Idempotent to call again mid-burst -- always resets
## to full intensity rather than stacking.
func trigger_burst() -> void:
	_burst = 1.0
	queue_redraw()


func get_burst_for_test() -> float:
	return _burst


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	if side <= 0.0:
		return
	var center: Vector2 = size * 0.5
	var radius: float = side * 0.5 - 2.0
	if _burst > 0.0:
		# A soft, fading ring pulse growing outward -- the "burst" -- drawn
		# behind the badge itself so it never occludes the level number.
		var pulse_radius: float = radius * (1.0 + _burst * 0.7)
		draw_circle(center, pulse_radius, UiPalette.with_alpha(ring_color, 0.35 * _burst), true)
	draw_circle(center, radius, fill_color, true)
	var ring_width: float = float(UiPalette.BORDER_THICK) + (1.0 if _burst > 0.0 else 0.0)
	draw_arc(center, radius - ring_width * 0.5, 0.0, TAU, 28, ring_color, ring_width, true)

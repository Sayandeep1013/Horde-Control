extends Control
class_name OutcomeGlyph

## Defeat/victory glyph for the run-end outcome title (UI pass, package D,
## task item 3: "a large cause/outcome title coloured UiPalette.DANGER for
## defeat or UiPalette.SUCCESS for victory WITH a distinct glyph or word
## per outcome (never colour alone ...)").
##
## Drawn, not a font character: `assets/ui/fonts/PixelifySans-Variable.ttf`
## has none of the common dingbat/check/star/skull glyphs
## (`Font.has_char()` checked against it directly returns false for
## U+2713/2715/2717/2605/2606/2620/etc. -- only plain ASCII and a handful
## of Latin-1 punctuation marks are present), so a font glyph here risks a
## tofu box in the shipped build. Two short vector strokes avoid that
## entirely and are exactly the kind of "custom-drawn control" this
## project already uses for a small UI indicator (`DraftFillRing`'s own
## `_draw()`).
##
## Purely a display, matching `DraftFillRing`'s own convention (its header:
## "a typed `set`, nothing else"): `set_defeat()` is the one seam, driven
## by `run_end.gd`'s `show_summary()` from the SAME `cause_text` emptiness
## check that colours the title -- never a second source of truth for the
## outcome. `custom_minimum_size` is left to the caller, also matching
## `DraftFillRing`.

var _defeat: bool = true
var _color: Color = UiPalette.DANGER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Typed command. `is_defeat == true` draws an X (player death or the
## Tower destroyed); `false` draws a check mark (the wave sequence
## completed with nobody dead) -- see run_end.gd's own header, "The death
## cause or the final wave reached," for why cause_text's emptiness alone
## already distinguishes the two.
func set_defeat(is_defeat: bool) -> void:
	_defeat = is_defeat
	_color = UiPalette.DANGER if is_defeat else UiPalette.SUCCESS
	queue_redraw()


func _draw() -> void:
	var stroke: float = float(UiPalette.BORDER_THICK) + 1.0
	var pad: float = minf(size.x, size.y) * 0.22
	if _defeat:
		draw_line(Vector2(pad, pad), Vector2(size.x - pad, size.y - pad), _color, stroke, true)
		draw_line(Vector2(size.x - pad, pad), Vector2(pad, size.y - pad), _color, stroke, true)
	else:
		var p1 := Vector2(pad, size.y * 0.55)
		var p2 := Vector2(size.x * 0.42, size.y - pad)
		var p3 := Vector2(size.x - pad, pad)
		draw_line(p1, p2, _color, stroke, true)
		draw_line(p2, p3, _color, stroke, true)

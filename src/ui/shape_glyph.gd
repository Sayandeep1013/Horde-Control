extends Label
class_name UiShapeGlyph

## Pool glyph drawn as a vector shape (UI pass review, LEDGER UR-03).
##
## docs/19 > "Differentiation" asks for a fixed glyph per pool on Draft cards
## and Console entries. The shipped font has none of the geometric shapes
## (`Font.has_char()` is false for U+25B2, U+25A0, U+25CF - see
## outcome_glyph.gd's header), so as text they rendered only through the
## operating system's fallback font: a second typeface on screen, and a tofu
## box wherever that fallback is missing. This draws the shape instead.
##
## It stays a Label, and keeps its `text`, because `DraftCardView
## .get_glyph_label()` is a test seam that reads the glyph character. The
## text is rendered fully transparent; `_draw()` runs after the Label's own
## drawing and paints the shape in `glyph_color`.

enum Shape { TRIANGLE, SQUARE }

## Fraction of the shorter side left empty around the shape.
const INSET_FRACTION: float = 0.12

var shape: Shape = Shape.TRIANGLE:
	set(value):
		shape = value
		queue_redraw()

var glyph_color: Color = UiPalette.TEXT:
	set(value):
		glyph_color = value
		queue_redraw()


func _init() -> void:
	var clear := UiPalette.with_alpha(UiPalette.TEXT, 0.0)
	add_theme_color_override("font_color", clear)
	add_theme_color_override("font_outline_color", clear)
	add_theme_color_override("font_shadow_color", clear)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Square footprint, `side` px at the base resolution. The caller picks the
## side from a UiPalette font-size token so the glyph tracks the text beside it.
func set_side(side: int) -> void:
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_text = true


func _draw() -> void:
	var side: float = minf(size.x, size.y)
	var inset: float = side * INSET_FRACTION
	var origin := (size - Vector2(side, side)) * 0.5 + Vector2(inset, inset)
	var extent: float = side - inset * 2.0
	draw_shape(self, shape, Rect2(origin, Vector2(extent, extent)), glyph_color)


## Shared with custom-drawn controls (the hold rings) so every pool glyph on
## screen is the same geometry.
static func draw_shape(canvas: CanvasItem, which: Shape, rect: Rect2, color: Color) -> void:
	match which:
		Shape.TRIANGLE:
			var points := PackedVector2Array([
				Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y),
				rect.end,
				Vector2(rect.position.x, rect.end.y),
			])
			canvas.draw_colored_polygon(points, color)
		Shape.SQUARE:
			canvas.draw_rect(rect, color, true)

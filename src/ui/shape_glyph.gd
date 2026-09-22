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
##
## ## HUD icons (Tiny Swords restyle, second UI pass)
## Three more shapes -- HEART, TOWER, RECYCLE -- added at the END of the enum
## (never renumbered: TRIANGLE/SQUARE keep their original ordinal values, so
## anything that stored a `Shape` as a plain int, e.g. `DraftFillRing.
## center_shape`, is unaffected). Used by `src/ui/hud.gd` for the player/
## Tower/rerolls field glyphs, matching this file's own convention of a
## drawn vector shape rather than a font character or a new binary asset
## (the shipped font has no heart/tower/refresh glyph either; adding one
## more case here costs nothing new to license or provenance).

enum Shape { TRIANGLE, SQUARE, HEART, TOWER, RECYCLE }

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
		Shape.HEART:
			_draw_heart(canvas, rect, color)
		Shape.TOWER:
			_draw_tower(canvas, rect, color)
		Shape.RECYCLE:
			_draw_recycle(canvas, rect, color)


## A classic double-lobe heart, sampled from the standard parametric heart
## curve into a polygon (so it draws through the same `draw_colored_polygon`
## call every other shape here uses) and fit to `rect` by its own measured
## bounding box rather than a hand-tuned scale constant, so it fills `rect`
## exactly regardless of the curve's own native proportions.
static func _draw_heart(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var samples: int = 28
	var raw := PackedVector2Array()
	for i in range(samples + 1):
		var t: float = TAU * float(i) / float(samples)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		raw.append(Vector2(x, -y)) # flip: the formula's own y is math-up; canvas y is down, and the point must stay at the bottom
	var min_v: Vector2 = raw[0]
	var max_v: Vector2 = raw[0]
	for p in raw:
		min_v = Vector2(minf(min_v.x, p.x), minf(min_v.y, p.y))
		max_v = Vector2(maxf(max_v.x, p.x), maxf(max_v.y, p.y))
	var span: Vector2 = max_v - min_v
	var out := PackedVector2Array()
	for p in raw:
		var nx: float = (p.x - min_v.x) / span.x
		var ny: float = (p.y - min_v.y) / span.y
		out.append(rect.position + Vector2(nx * rect.size.x, ny * rect.size.y))
	canvas.draw_colored_polygon(out, color)


## A small crenellated tower silhouette (a shaft topped with three merlons
## and two notches) -- the HUD's Tower field icon. Coordinates are authored
## in a 0..1 unit square, then mapped into `rect`, matching the TRIANGLE/
## SQUARE cases' own "author in local space, scale to rect" approach.
static func _draw_tower(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var unit_points := PackedVector2Array([
		Vector2(0.10, 1.00), Vector2(0.10, 0.40), Vector2(0.00, 0.40), Vector2(0.00, 0.20),
		Vector2(0.20, 0.20), Vector2(0.20, 0.34), Vector2(0.40, 0.34), Vector2(0.40, 0.20),
		Vector2(0.60, 0.20), Vector2(0.60, 0.34), Vector2(0.80, 0.34), Vector2(0.80, 0.20),
		Vector2(1.00, 0.20), Vector2(1.00, 0.40), Vector2(0.90, 0.40), Vector2(0.90, 1.00),
	])
	var out := PackedVector2Array()
	for p in unit_points:
		out.append(rect.position + Vector2(p.x * rect.size.x, p.y * rect.size.y))
	canvas.draw_colored_polygon(out, color)


## Two arced arrows chasing each other around a circle, each with a small
## triangular arrowhead at its leading end -- the conventional "reroll /
## refresh" glyph, drawn rather than a font character for the same reason
## every other shape in this file is (see class header).
static func _draw_recycle(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5 * 0.72
	# Bolder and more closed than a first pass at this: at the ~20px
	# effective size this glyph renders at in the HUD (ICON_SIZE_SMALL,
	# hud.gd), a thin stroke with a wide gap between the two arcs read as
	# two disconnected hooks ("()") rather than a circular refresh symbol.
	# A thicker stroke, a longer span, and a narrower gap keep the two arcs
	# reading as one broken ring even at this size.
	var stroke: float = maxf(3.0, radius * 0.42)
	var arc_points: int = 16
	var span: float = deg_to_rad(155.0)
	var gap: float = deg_to_rad(25.0)
	var start1: float = -PI / 2.0 + gap * 0.5
	var end1: float = start1 + span
	canvas.draw_arc(center, radius, start1, end1, arc_points, color, stroke, true)
	_draw_recycle_arrowhead(canvas, center, radius, end1, stroke, color)

	var start2: float = start1 + PI
	var end2: float = start2 + span
	canvas.draw_arc(center, radius, start2, end2, arc_points, color, stroke, true)
	_draw_recycle_arrowhead(canvas, center, radius, end2, stroke, color)


static func _draw_recycle_arrowhead(canvas: CanvasItem, center: Vector2, radius: float, angle: float, stroke: float, color: Color) -> void:
	var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
	var tangent: Vector2 = Vector2(-sin(angle), cos(angle)) # direction of travel along the arc, at this angle
	var normal: Vector2 = Vector2(cos(angle), sin(angle))
	var head_size: float = stroke * 2.6
	var back: Vector2 = tip - tangent * head_size
	var p1: Vector2 = back + normal * head_size * 0.75
	var p2: Vector2 = back - normal * head_size * 0.75
	canvas.draw_colored_polygon(PackedVector2Array([tip + tangent * head_size * 0.5, p1, p2]), color)

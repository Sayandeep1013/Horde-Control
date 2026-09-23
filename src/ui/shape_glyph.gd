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

## Meta layer core (Hub/Skill Tree screen): COIN (the Fortune branch's
## icon), CRYSTAL (the Cores currency's own icon, UiPalette.CORES), and TENT
## (the Skill Tree's root/Command Tent -- polish pass, coordinator: "keep
## the root visibly special ... tent/banner icon, not a plain green
## square") -- added at the END, same convention as HEART/TOWER/RECYCLE's
## own addition note above (never renumbered).
##
## ## Skill Tree art pass (author request, 2026-09-23: "the skill tree
## graphics needs to be more detailed ... real pictorial icons instead of
## plain triangles/squares where possible: arrow for damage, boots for
## speed, heart for vitality, tower for tower nodes, gold for fortune")
## ARROW replaces the Archer branch's own former plain TRIANGLE (never
## renumbered -- TRIANGLE keeps its ordinal, ARROW is new); BOOT is Swift
## Boots' own per-node icon override (src/ui/skill_tree_screen.gd's
## `_build_nodes()`); LOCK is the LOCKED-state icon `SkillNodeView` swaps in
## for a node whose prerequisites are not yet met (task instruction:
## "locked fog nodes as dim silhouettes with a lock"). Vitality already
## reuses the existing HEART shape and every Tower/Fortune node already uses
## TOWER/COIN -- no new shape needed for those three.
enum Shape { TRIANGLE, SQUARE, HEART, TOWER, RECYCLE, COIN, CRYSTAL, TENT, ARROW, BOOT, LOCK }

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
		Shape.COIN:
			_draw_coin(canvas, rect, color)
		Shape.CRYSTAL:
			_draw_crystal(canvas, rect, color)
		Shape.TENT:
			_draw_tent(canvas, rect, color)
		Shape.ARROW:
			_draw_arrow(canvas, rect, color)
		Shape.BOOT:
			_draw_boot(canvas, rect, color)
		Shape.LOCK:
			_draw_lock(canvas, rect, color)


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


## Meta layer core (Hub/Skill Tree screen): the Fortune branch's icon -- a
## plain filled coin/token, the simplest possible read at the small size a
## grid node's icon renders at (matches SQUARE's own single-primitive
## simplicity, deliberately not a two-tone coin that would need a second
## colour this shared, one-colour `draw_shape()` contract cannot carry).
static func _draw_coin(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	canvas.draw_circle(rect.get_center(), radius, color, true, -1.0, true)


## Meta layer core: the Cores currency's own icon (UiPalette.CORES) -- a
## faceted gem silhouette, authored in a 0..1 unit square and mapped into
## `rect`, matching TOWER's own "author in local space, scale to rect"
## approach. Drawn rather than a font character or a reused Tiny Swords coin
## icon for the same reason every other shape in this file is (class
## header): the Cores currency is not Scrap (already the coin-pouch icon in
## the HUD) and needs its own, unambiguous silhouette.
static func _draw_crystal(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var unit_points := PackedVector2Array([
		Vector2(0.50, 0.00), Vector2(0.85, 0.30), Vector2(1.00, 0.55),
		Vector2(0.70, 1.00), Vector2(0.30, 1.00), Vector2(0.00, 0.55),
		Vector2(0.15, 0.30),
	])
	var out := PackedVector2Array()
	for p in unit_points:
		out.append(rect.position + Vector2(p.x * rect.size.x, p.y * rect.size.y))
	canvas.draw_colored_polygon(out, color)


## Skill Tree screen (polish pass): the root/Command Tent's own icon -- a
## simple ridge tent (a wide triangle) with a pennant flag on a pole above
## it, distinguishing it at a glance from the Archer branch's own plain
## TRIANGLE. Authored in local space, mapped into `rect`, matching TOWER/
## CRYSTAL's own approach; drawn as two polygons plus a line (still one
## `color`, per this file's shared `draw_shape()` contract).
static func _draw_tent(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var o: Vector2 = rect.position
	var body := PackedVector2Array([
		o + Vector2(w * 0.5, h * 0.30), o + Vector2(w * 1.0, h * 1.0), o + Vector2(w * 0.0, h * 1.0),
	])
	canvas.draw_colored_polygon(body, color)
	var pole_top: Vector2 = o + Vector2(w * 0.5, h * 0.0)
	var pole_bottom: Vector2 = o + Vector2(w * 0.5, h * 0.30)
	canvas.draw_line(pole_top, pole_bottom, color, maxf(2.0, w * 0.06), true)
	var flag := PackedVector2Array([
		pole_top, pole_top + Vector2(w * 0.32, h * 0.07), pole_top + Vector2(0.0, h * 0.16),
	])
	canvas.draw_colored_polygon(flag, color)


## Skill Tree art pass: a classic archery arrow (a diamond head, a thin
## shaft, and a small V-notch fletching) pointing up-right -- the Archer
## branch's own icon (task instruction: "arrow for damage"), replacing the
## generic TRIANGLE that branch used before. Authored in a 0..1 unit square
## and mapped into `rect`, matching TOWER's/CRYSTAL's own approach; the
## shaft is drawn as a thin filled quad (not `draw_line`, which this file's
## shared one-colour `draw_shape()` contract has no width/colour parameter
## for) so it stays one `draw_colored_polygon` call per part, like every
## other shape here.
static func _draw_arrow(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var o: Vector2 = rect.position

	# Head: a diamond at the top-right end of the shaft.
	var head := PackedVector2Array([
		o + Vector2(w * 1.00, h * 0.00), o + Vector2(w * 0.68, h * 0.10),
		o + Vector2(w * 0.78, h * 0.22), o + Vector2(w * 1.00, h * 0.00),
	])
	canvas.draw_colored_polygon(head, color)

	# Shaft: a thin quad from the head down to the fletching, angled the
	# same 45 degrees as the head.
	var shaft_w: float = w * 0.09
	var dir: Vector2 = Vector2(1.0, -1.0).normalized()
	var normal: Vector2 = Vector2(-dir.y, dir.x) * shaft_w * 0.5
	var shaft_start: Vector2 = o + Vector2(w * 0.74, h * 0.16)
	var shaft_end: Vector2 = o + Vector2(w * 0.12, h * 0.78)
	canvas.draw_colored_polygon(PackedVector2Array([
		shaft_start + normal, shaft_end + normal, shaft_end - normal, shaft_start - normal,
	]), color)

	# Fletching: a small V-notch at the tail end.
	var fletch := PackedVector2Array([
		o + Vector2(w * 0.00, h * 1.00), o + Vector2(w * 0.26, h * 0.70),
		o + Vector2(w * 0.20, h * 1.00), o + Vector2(w * 0.00, h * 1.00),
	])
	canvas.draw_colored_polygon(fletch, color)
	var fletch2 := PackedVector2Array([
		o + Vector2(w * 0.00, h * 1.00), o + Vector2(w * 0.30, h * 0.74),
		o + Vector2(w * 0.00, h * 0.80), o + Vector2(w * 0.00, h * 1.00),
	])
	canvas.draw_colored_polygon(fletch2, color)


## Skill Tree art pass: a simple ankle boot silhouette -- Swift Boots' own
## icon (task instruction: "boots for speed"). Authored the same way as
## every other unit-square shape above.
static func _draw_boot(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var o: Vector2 = rect.position
	var boot := PackedVector2Array([
		o + Vector2(w * 0.32, h * 0.00), o + Vector2(w * 0.62, h * 0.00),
		o + Vector2(w * 0.62, h * 0.52), o + Vector2(w * 0.88, h * 0.62),
		o + Vector2(w * 1.00, h * 0.80), o + Vector2(w * 1.00, h * 1.00),
		o + Vector2(w * 0.06, h * 1.00), o + Vector2(w * 0.06, h * 0.86),
		o + Vector2(w * 0.20, h * 0.86), o + Vector2(w * 0.32, h * 0.72),
	])
	canvas.draw_colored_polygon(boot, color)
	# Heel notch and sole line read as a boot, not a sock, at small sizes.
	canvas.draw_line(o + Vector2(w * 0.06, h * 0.94), o + Vector2(w * 1.00, h * 0.94), color, maxf(1.0, w * 0.04), true)


## Skill Tree art pass: a padlock silhouette (a round shackle over a
## rounded body with a keyhole) -- the LOCKED-state icon `SkillNodeView`
## swaps in for a node whose prerequisites are not yet met (task
## instruction: "locked fog nodes as dim silhouettes with a lock").
static func _draw_lock(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var o: Vector2 = rect.position

	# Shackle: an arc drawn as a thick stroke, matching RECYCLE's own
	# "draw_arc with a stroke width" technique.
	var shackle_center: Vector2 = o + Vector2(w * 0.5, h * 0.38)
	var shackle_radius: float = w * 0.26
	canvas.draw_arc(shackle_center, shackle_radius, PI, TAU, 16, color, maxf(2.0, w * 0.12), true)

	# Body: a rounded rectangle (approximated with a plain rect -- this
	# file's shared one-colour contract has no rounded-rect primitive of its
	# own, and a lock body reads clearly even square at this size).
	var body := Rect2(o + Vector2(w * 0.16, h * 0.42), Vector2(w * 0.68, h * 0.52))
	canvas.draw_rect(body, color, true)

	# Keyhole: a small circle over a short slot, cut out in the BACKGROUND
	# colour is not available to this shared one-colour contract, so instead
	# it is drawn as a small light accent -- callers needing a true cutout
	# use a different shape; here a subtle darker dot reads as a keyhole
	# highlight without a second required colour.
	var keyhole_center: Vector2 = o + Vector2(w * 0.5, h * 0.60)
	canvas.draw_circle(keyhole_center, w * 0.05, color.lightened(0.5), true, -1.0, true)
	canvas.draw_rect(Rect2(keyhole_center + Vector2(-w * 0.02, 0.0), Vector2(w * 0.04, h * 0.10)), color.lightened(0.5), true)

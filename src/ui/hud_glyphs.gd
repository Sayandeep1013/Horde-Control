class_name HudGlyphs
extends RefCounted

## Small drawing helpers for the v1.0 HUD: pixel glyphs the shape set lacks,
## the icon-or-monogram fallback, the radial cooldown wedge and the spawn
## chevron. Static and stateless, like UiShapeGlyph.

const SKULL_ROWS: Array[String] = [
	"..XXXXXX..",
	".XXXXXXXX.",
	"XXXXXXXXXX",
	"XX..XX..XX",
	"XX..XX..XX",
	"XXXXXXXXXX",
	".XXX..XXX.",
	"..XXXXXX..",
	"..X.XX.X..",
	"..XXXXXX..",
]
const DASH_ROWS: Array[String] = [
	"..........",
	"X..X..X...",
	"XX.XX.XX..",
	".XX.XX.XX.",
	"..XX.XX.XX",
	"..XX.XX.XX",
	".XX.XX.XX.",
	"XX.XX.XX..",
	"X..X..X...",
	"..........",
]


## Draws a 10x10 pixel pattern ('X' = filled) tinted `color` over a 1 px ink
## shadow, as large a whole-number scale as fits `rect`, centred.
static func draw_pattern(canvas: CanvasItem, rows: Array[String], rect: Rect2, color: Color) -> void:
	var n: int = rows.size()
	var cell: float = maxf(1.0, floorf(minf(rect.size.x, rect.size.y) / float(n)))
	var origin: Vector2 = (rect.position + (rect.size - Vector2(cell, cell) * float(n)) * 0.5).round()
	for pass_index: int in 2:
		var offset: Vector2 = Vector2(cell, cell) * 0.5 if pass_index == 0 else Vector2.ZERO
		var col: Color = UiPalette.INK_PIXEL if pass_index == 0 else color
		for y: int in n:
			var row: String = rows[y]
			for x: int in row.length():
				if row[x] == "X":
					canvas.draw_rect(Rect2(origin + Vector2(float(x), float(y)) * cell + offset, Vector2(cell, cell)), col, true)


static func draw_skull(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	draw_pattern(canvas, SKULL_ROWS, rect, color)


static func draw_dash(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	draw_pattern(canvas, DASH_ROWS, rect, color)


## Up to two letters from an id ("flame_arrows" -> "FA", "storm" -> "ST").
static func monogram(id: String) -> String:
	var parts: PackedStringArray = id.split("_", false)
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 1)).to_upper()
	return id.substr(0, 2).to_upper()


static func draw_monogram(canvas: CanvasItem, rect: Rect2, id: String, color: Color) -> void:
	var font: Font = UiTheme.get_display_font()
	var text: String = monogram(id)
	var font_size: int = UiPalette.FONT_SIZE_BODY
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: Vector2 = rect.position + Vector2((rect.size.x - text_size.x) * 0.5, (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	baseline = baseline.round()
	canvas.draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, UiPalette.OUTLINE_BODY, UiPalette.INK_PIXEL)
	canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


## `texture_path` drawn at the largest whole-number scale that fits `rect`, or
## `fallback` (a Callable taking the rect) when the file is not there yet.
static func draw_icon_or(canvas: CanvasItem, texture_path: String, rect: Rect2, fallback: Callable) -> void:
	var tex: Texture2D = icon_texture(texture_path)
	if tex == null:
		fallback.call(rect)
		return
	var tex_size: Vector2 = tex.get_size()
	var scale_i: float = maxf(1.0, floorf(minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)))
	var draw_size: Vector2 = tex_size * scale_i
	canvas.draw_texture_rect(tex, Rect2((rect.position + (rect.size - draw_size) * 0.5).round(), draw_size), false)


static var _tex_cache: Dictionary = {}


static func icon_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tex_cache[path] = tex
	return tex


static func clear_cache_for_test() -> void:
	_tex_cache.clear()


## Polygon of the part of `rect` swept by a ray from its centre between
## `a0` and `a1` (radians, Godot's y-down angles, a1 > a0), for a clockwise
## cooldown wipe. Exact at the rectangle's corners.
static func wedge_points(rect: Rect2, a0: float, a1: float) -> PackedVector2Array:
	var centre: Vector2 = rect.get_center()
	var half: Vector2 = rect.size * 0.5
	var angles: Array[float] = [a0, a1]
	for corner: Vector2 in [Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y), Vector2(half.x, -half.y)]:
		var corner_angle: float = corner.angle()
		for turn: int in [-1, 0, 1, 2]:
			var candidate: float = corner_angle + TAU * float(turn)
			if candidate > a0 + 0.001 and candidate < a1 - 0.001:
				angles.append(candidate)
	var steps: int = maxi(1, int(ceil((a1 - a0) / (PI / 24.0))))
	for i: int in range(1, steps):
		angles.append(a0 + (a1 - a0) * float(i) / float(steps))
	angles.sort()
	var points := PackedVector2Array([centre])
	for a: float in angles:
		points.append(_ray_to_rect(centre, half, a))
	return points


static func _ray_to_rect(centre: Vector2, half: Vector2, angle: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	var t: float = INF
	if absf(dir.x) > 0.0001:
		t = minf(t, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		t = minf(t, half.y / absf(dir.y))
	return centre + dir * (t if is_finite(t) else 0.0)


## Points of a chunky ">" chevron pointing along `dir` (unit vector), centred
## on `centre`: arm length `size`, stroke `thickness`.
static func chevron_points(centre: Vector2, dir: Vector2, size: float, thickness: float) -> PackedVector2Array:
	var fwd: Vector2 = dir.normalized()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var tip: Vector2 = centre + fwd * size * 0.5
	var arm_back: Vector2 = centre - fwd * size * 0.5
	var outer_a: Vector2 = arm_back + side * size * 0.75
	var outer_b: Vector2 = arm_back - side * size * 0.75
	var inner_tip: Vector2 = tip - fwd * thickness * 1.6
	var inner_a: Vector2 = outer_a - fwd * thickness * 1.2
	var inner_b: Vector2 = outer_b - fwd * thickness * 1.2
	return PackedVector2Array([tip, outer_a, inner_a, inner_tip, inner_b, outer_b])

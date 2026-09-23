extends Node2D
class_name SandNetwork

## The Tower plaza and every sand path, as ONE smooth vector shape
## (supervisor review, this session): a tile-stamped circle and tile-
## carved paths (ground_detail.gd's earlier approach, still used there for
## the coastal ring and the random patches, which were not the complaint)
## show a visible single-tile staircase on any diagonal at 64px resolution,
## and several tile-stamped circles/paths meeting at the Tower read as "a
## jagged cross", not a rounded plaza. This file instead builds:
##   1. A rounded plaza circle at `tower_center` and a rounded circle at
##      each landmark clearing (organic radius jitter via KeyedRng, same
##      "smoothed circular jitter" technique pond_field.gd uses for a
##      shoreline).
##   2. A curved ribbon (a `Curve2D`-baked centreline, extruded to a fixed
##      width) from the Tower to every random patch (read from
##      GroundDetail.get_patch_centers() -- see that file's header for why
##      the split), every landmark that wants a path, and the bridge
##      crossing target.
##   3. All of the above merged into ONE polygon via repeated
##      `Geometry2D.merge_polygons()` calls, so the final shape has a
##      single continuous silhouette -- no seam where a path meets the
##      plaza or a landmark circle.
## The merged polygon is filled with the pack's own sand fill tile
## (`Derived/sand_fill_tile.png`, tiled via `texture_repeat`) and outlined
## with a Line2D in the pack's own ink colour (22,28,46 -- sampled by PIL
## from Tilemap_Flat.png's sand edge tiles this session), matching this
## project's existing sand art exactly rather than inventing a new look.
##
## DETERMINISM via KeyedRng, matching every other placement in this biome
## pass.

const OUTLINE_COLOR: Color = Color(22.0 / 255.0, 28.0 / 255.0, 46.0 / 255.0)

@export var sand_texture: Texture2D
@export var ground_detail_path: NodePath = ^"../GroundDetail"

@export var tower_center: Vector2 = Vector2.ZERO
@export var plaza_radius_px: float = 400.0

## Landmark clearings this network also renders as rounded circles, and
## which of them get a path ribbon from the plaza -- same meaning as the
## arrays ground_detail.gd used to own; moved here because this file is
## the one that actually draws them now.
@export var landmark_clearings: Array[Vector2] = []
@export var landmark_clearing_radii: Array[float] = []
@export var landmark_path_targets: Array[int] = []
@export var bridge_crossing_target: Vector2 = Vector2.ZERO # Vector2.ZERO means "no bridge path"

@export var path_width_px: float = 170.0
@export var path_curve_jitter_px: float = 180.0
@export var outline_width_px: float = 5.0
@export var seed_key: String = "arena_biome"


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if sand_texture == null:
		push_warning("SandNetwork has no sand_texture assigned; no plaza/paths will be drawn.")
		return

	var shapes: Array[PackedVector2Array] = []
	shapes.append(_make_circle(tower_center, plaza_radius_px, "plaza"))
	for i in landmark_clearings.size():
		var radius: float = landmark_clearing_radii[i] if i < landmark_clearing_radii.size() else 180.0
		shapes.append(_make_circle(landmark_clearings[i], radius, "landmark_%d" % i))

	var targets: Array[Vector2] = []
	var ground_detail: Node = get_node_or_null(ground_detail_path)
	if ground_detail != null and ground_detail.has_method("get_patch_centers"):
		targets.append_array(ground_detail.get_patch_centers())
	for i in landmark_path_targets.size():
		var idx: int = landmark_path_targets[i]
		if idx >= 0 and idx < landmark_clearings.size():
			targets.append(landmark_clearings[idx])
	if bridge_crossing_target != Vector2.ZERO:
		targets.append(bridge_crossing_target)

	for i in targets.size():
		shapes.append(_make_ribbon(tower_center, targets[i], path_width_px, "path_%d" % i))

	var merged: PackedVector2Array = _union_all(shapes)
	if merged.is_empty():
		return
	_build_fill(merged)
	_build_outline(merged)


func _union_all(shapes: Array[PackedVector2Array]) -> PackedVector2Array:
	if shapes.is_empty():
		return PackedVector2Array()
	var merged: PackedVector2Array = shapes[0]
	for i in range(1, shapes.size()):
		var result: Array[PackedVector2Array] = Geometry2D.merge_polygons(merged, shapes[i])
		if result.is_empty():
			continue
		merged = _largest(result)
	return merged


func _largest(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best: PackedVector2Array = polys[0]
	var best_area: float = absf(_polygon_area(best))
	for i in range(1, polys.size()):
		var area: float = absf(_polygon_area(polys[i]))
		if area > best_area:
			best = polys[i]
			best_area = area
	return best


## Shoelace formula. No built-in Geometry2D helper for this in Godot 4.7
## (checked); trivial enough to inline rather than pull in a dependency.
static func _polygon_area(points: PackedVector2Array) -> float:
	var sum: float = 0.0
	var n: int = points.size()
	for i in n:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


## An organic circle: `samples` points around `center` at `radius`, each
## with an independent random multiplier smoothed against its neighbours
## (pond_field.gd's own "_make_jitter" technique) so the plaza and every
## landmark clearing read as rounded-but-hand-drawn, never a mechanically
## perfect circle or a tile-jagged one.
func _make_circle(center: Vector2, radius: float, key: String) -> PackedVector2Array:
	var samples: int = 28
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sand_network_circle", key])
	var raw: Array[float] = []
	for i in samples:
		raw.append(1.0 + rng.randf_range(-0.06, 0.06))
	var pts: PackedVector2Array = PackedVector2Array()
	for i in samples:
		var prev: float = raw[(i - 1 + samples) % samples]
		var nxt: float = raw[(i + 1) % samples]
		var mult: float = (prev + raw[i] + nxt) / 3.0
		var angle: float = float(i) / float(samples) * TAU
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius * mult)
	return pts


## A ribbon from `from_pos` to `to_pos`: a smooth `Curve2D`-baked centre
## line (2-3 interior control points, each perpendicular-jittered by
## KeyedRng, so the road curves gently rather than running dead straight)
## extruded to `width` by offsetting every baked point along its local
## normal. Both ends are pushed 1.5x the path width back along the line so
## they land well inside whichever circle they are meant to merge with (or
## inside a patch's own tile blob), guaranteeing `Geometry2D.merge_polygons`
## sees real overlap instead of two shapes that only touch at a point.
##
## Every control point gets an explicit Catmull-Rom-style tangent handle
## (`in`/`out` on `Curve2D.add_point()`) computed from its own neighbours --
## `Curve2D` draws a STRAIGHT segment between two points that have no
## handles at all, which is what an earlier version of this method did (it
## only ever called `add_point(position)`), and a supervisor review of
## that version's captures called the resulting paths out as a series of
## straight-segment kinks, not the "organic curves" this task asks for.
func _make_ribbon(from_pos: Vector2, to_pos: Vector2, width: float, key: String) -> PackedVector2Array:
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sand_network_path", key])
	var direction: Vector2 = (to_pos - from_pos)
	var length: float = direction.length()
	if length < 1.0:
		return PackedVector2Array()
	direction = direction / length
	var perpendicular: Vector2 = direction.orthogonal()

	var overshoot: float = width * 1.5
	var points: Array[Vector2] = [from_pos - direction * overshoot]
	var control_count: int = maxi(2, int(length / 450.0))
	for i in range(1, control_count + 1):
		var t: float = float(i) / float(control_count + 1)
		var jitter: float = rng.randf_range(-1.0, 1.0) * path_curve_jitter_px
		points.append(from_pos.lerp(to_pos, t) + perpendicular * jitter)
	points.append(to_pos + direction * overshoot)

	var curve: Curve2D = Curve2D.new()
	curve.bake_interval = 24.0
	var smoothing: float = 0.35
	for i in points.size():
		var prev: Vector2 = points[maxi(i - 1, 0)]
		var nxt: Vector2 = points[mini(i + 1, points.size() - 1)]
		var tangent: Vector2 = (nxt - prev) * smoothing
		curve.add_point(points[i], -tangent, tangent)

	var baked: PackedVector2Array = curve.get_baked_points()
	if baked.size() < 2:
		return PackedVector2Array()

	var half: float = width * 0.5
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i in baked.size():
		var tangent: Vector2
		if i == 0:
			tangent = (baked[1] - baked[0]).normalized()
		elif i == baked.size() - 1:
			tangent = (baked[i] - baked[i - 1]).normalized()
		else:
			tangent = (baked[i + 1] - baked[i - 1]).normalized()
		var normal: Vector2 = tangent.orthogonal()
		left.append(baked[i] + normal * half)
		right.append(baked[i] - normal * half)

	var polygon: PackedVector2Array = PackedVector2Array()
	polygon.append_array(left)
	for i in range(right.size() - 1, -1, -1):
		polygon.append(right[i])
	return polygon


func _build_fill(points: PackedVector2Array) -> void:
	var poly: Polygon2D = Polygon2D.new()
	poly.name = "Fill"
	poly.polygon = points
	poly.uv = points
	poly.texture = sand_texture
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(poly)


func _build_outline(points: PackedVector2Array) -> void:
	var line: Line2D = Line2D.new()
	line.name = "Outline"
	var closed_points: PackedVector2Array = points.duplicate()
	closed_points.append(points[0])
	line.points = closed_points
	line.width = outline_width_px
	line.default_color = OUTLINE_COLOR
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 0
	line.z_as_relative = true
	add_child(line)

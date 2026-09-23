extends Node2D
class_name PondField

## Inland ponds/lakes (biome brief: "2-4 ponds/lakes inside the island with
## foam edges and bobbing water rocks, one crossed by a bridge on a
## path").
##
## REBUILT this session after a supervisor review of the first version's
## captures: that version painted a hard-edged water blob with foam
## sprites ringed OUTSIDE it, on the grass -- described as "blocky
## turquoise blobs ringed by square pale tiles". The actual Tiny Swords
## convention (and this project's own already-working ground_detail.gd
## precedent for sand) is the other way around: water sits underneath
## everything, then foam sprites sit right at the shoreline, THEN the
## shore's sand -- with the sheet's own alpha-cut edge/corner tiles -- is
## painted on TOP, so only the outward sliver of each foam sprite peeks
## past the sand's rounded edge into the water. This file now builds, per
## pond, three layers in this order (Water -> Foam -> SandRing), each
## added as a later child so it draws over the one before it:
##   1. `_water`, a TileMapLayer filled solid across the pond's OUTER
##      "warped ellipse" (see below) with Water.png.
##   2. Foam.png AnimatedSprite2D instances placed around the INNER
##      warped ellipse (the shoreline, i.e. the water-to-sand seam).
##   3. `_sand`, a TileMapLayer painted as an ANNULUS -- every cell inside
##      the outer ellipse but outside the inner one -- using
##      Tilemap_Flat.png's sand 9-slice and ground_detail.gd's own
##      `_atlas_coord_for` classifier (reused via that class's static
##      method rather than re-derived, so a pond's shoreline tiles are
##      pixel-for-pixel the same alpha-cut art already proven to read well
##      for the coastal ring and the random sand patches). Cells adjacent
##      to the inner hole get an edge/corner tile that reveals the foam
##      and water underneath; cells adjacent to open grass get one that
##      reveals the grass `Floor` -- the SAME tiles doing both jobs,
##      because the classifier only looks at which neighbours are missing,
##      never at what is drawn under them.
## A pond's visible water shape is therefore the inner ellipse's own
## rounded, jittered silhouette, not a hard rectangle grid.
##
## WARPED-ELLIPSE SHAPE, not ground_detail.gd's random-walk blob: a pond
## needs a predictable footprint so the one hand-placed Bridge sprite in
## scenes/arena.tscn can be sized to actually span it (see that scene's
## own comment on the bridge crossing). `pond_axes[i]` is each pond's
## OUTER (rx, ry) semi-axis pair in pixels; the boundary is that ellipse
## with a per-angle random radius multiplier (KeyedRng-seeded, smoothed
## circularly so the jitter reads as an organic shoreline, not spiky
## noise) rather than a perfect ellipse. The inner ellipse (the true water
## line) is the same shape scaled by `shore_fraction`.
##
## No collision anywhere -- purely visual, matching every other biome-pass
## placement in this task (enemies and the player path straight across a
## pond exactly as they do plain grass; nothing here registers with
## EntityRegistry).

const TILE_SIZE: int = 64
const ANGLE_SAMPLES: int = 24
const FOAM_FRAME_SIZE: int = 192
const FOAM_FRAME_COUNT: int = 8
const FOAM_ANIM: StringName = &"foam"
const FOAM_FPS: float = 6.0
const FOAM_SPACING_PX: float = 90.0

const POLY_SAMPLES: int = 72
const SHORE_OUTLINE_COLOR: Color = Color(22.0 / 255.0, 28.0 / 255.0, 46.0 / 255.0) # sand_network.gd's ink colour
const WATER_EDGE_COLOR: Color = Color(0.85, 0.97, 0.95, 0.9)
const SURF_COLOR: Color = Color(0.9, 1.0, 0.98, 0.45)
const SURF_WIDTH_PX: float = 16.0
const ROCK_FRAME_SIZE: int = 128
const ROCK_FRAME_COUNT: int = 8

@export var water_texture: Texture2D
@export var foam_texture: Texture2D
@export var flat_tilemap_texture: Texture2D # Tilemap_Flat.png, for the shore's sand ring (unused since the polygon rework; kept so arena.tscn stays valid)
@export var sand_fill_texture: Texture2D = preload("res://assets/third_party/tiny_swords/Derived/sand_fill_tile.png")
@export var rock_textures: Array[Texture2D] = []

## Parallel arrays: pond i is centred at `pond_centers[i]` with OUTER
## semi-axes `pond_axes[i]`. Hand-placed (see scenes/arena.tscn), exactly
## like ElevationPlateau's `plateau_centers` -- deliberate art direction
## for which quadrant reads as having water, with KeyedRng only
## responsible for the organic jitter of each shoreline.
@export var pond_centers: Array[Vector2] = []
@export var pond_axes: Array[Vector2] = []

## How much of the outer ellipse the visible water (the inner ellipse)
## fills -- 0.6 means the shore/sand ring is the outer 40% of the radius.
@export var shore_fraction: float = 0.8
@export var seed_key: String = "arena_biome"


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if water_texture == null or sand_fill_texture == null:
		push_warning("PondField is missing a required texture; no ponds will be placed.")
		return
	var foam_frames: SpriteFrames = _build_foam_frames() if foam_texture != null else null
	for i in pond_centers.size():
		var axes: Vector2 = pond_axes[i] if i < pond_axes.size() else Vector2(180.0, 180.0)
		var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "pond", i])
		var jitter: Array[float] = _make_jitter(rng)
		var inner_axes: Vector2 = axes * shore_fraction

		# Orchestrator rework: drawn as smooth polygons (the same technique as
		# sand_network.gd) instead of 64 px tile stamps, which read as blocky
		# squares at the shore. Sand shore (with ink outline) -> water -> surf.
		var shore_pts: PackedVector2Array = _ellipse_points(pond_centers[i], axes, jitter)
		var water_pts: PackedVector2Array = _ellipse_points(pond_centers[i], inner_axes, jitter)
		_add_polygon(shore_pts, sand_fill_texture, "Shore%d" % i)
		_add_outline(shore_pts, "ShoreOutline%d" % i)
		_add_polygon(water_pts, water_texture, "Water%d" % i)
		# Surf: a soft wide band plus a crisp inner line along the water's
		# edge. The pack's 192 px Foam.png frames are sized for whole island
		# coastlines and swamped a pond this small.
		_add_outline(water_pts, "Surf%d" % i, SURF_COLOR, SURF_WIDTH_PX)
		_add_outline(water_pts, "WaterOutline%d" % i, WATER_EDGE_COLOR, 3.0)

		if not rock_textures.is_empty():
			_place_rocks(pond_centers[i], inner_axes, jitter, rng)


func _build_water_layer(index: int) -> TileMapLayer:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = water_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i.ZERO)
	ts.add_source(source, 0)
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Water%d" % index
	layer.tile_set = ts
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = 0
	layer.z_as_relative = true
	return layer


func _build_sand_layer(index: int) -> TileMapLayer:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = flat_tilemap_texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord in [
		GroundDetail.SAND_TL, GroundDetail.SAND_T, GroundDetail.SAND_TR,
		GroundDetail.SAND_L, GroundDetail.SAND_FILL, GroundDetail.SAND_R,
		GroundDetail.SAND_BL, GroundDetail.SAND_B, GroundDetail.SAND_BR,
	]:
		source.create_tile(coord)
	ts.add_source(source, 0)
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = "Shore%d" % index
	layer.tile_set = ts
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = 0
	layer.z_as_relative = true
	return layer


func _build_foam_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(FOAM_ANIM)
	frames.set_animation_loop_mode(FOAM_ANIM, SpriteFrames.LOOP_LINEAR)
	frames.set_animation_speed(FOAM_ANIM, FOAM_FPS)
	for i in FOAM_FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = foam_texture
		atlas.region = Rect2(i * FOAM_FRAME_SIZE, 0, FOAM_FRAME_SIZE, FOAM_FRAME_SIZE)
		frames.add_frame(FOAM_ANIM, atlas)
	return frames


## One random multiplier per angular sample, then a circular 3-point
## average so neighbouring samples do not diverge sharply (an unsmoothed
## per-sample jitter reads as a spiky sea urchin, not a shoreline). Shared
## by both the outer and inner ellipse of the same pond, so the shore ring
## has a consistent (not independently-random) width all the way around.
func _make_jitter(rng: RandomNumberGenerator) -> Array[float]:
	var raw: Array[float] = []
	for i in ANGLE_SAMPLES:
		raw.append(1.0 + rng.randf_range(-0.16, 0.16))
	var smoothed: Array[float] = []
	for i in ANGLE_SAMPLES:
		var prev: float = raw[(i - 1 + ANGLE_SAMPLES) % ANGLE_SAMPLES]
		var nxt: float = raw[(i + 1) % ANGLE_SAMPLES]
		smoothed.append((prev + raw[i] + nxt) / 3.0)
	return smoothed


func _threshold_at(jitter: Array[float], angle: float) -> float:
	var t: float = (angle + PI) / TAU * ANGLE_SAMPLES
	var i0: int = int(floor(t)) % ANGLE_SAMPLES
	var i1: int = (i0 + 1) % ANGLE_SAMPLES
	var frac: float = t - floor(t)
	return lerpf(jitter[i0], jitter[i1], frac)


func _world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))


func _inside(p: Vector2, center: Vector2, axes: Vector2, jitter: Array[float]) -> bool:
	var d: Vector2 = p - center
	var u: float = d.x / axes.x
	var v: float = d.y / axes.y
	var r: float = sqrt(u * u + v * v)
	var angle: float = atan2(v, u)
	return r <= _threshold_at(jitter, angle)


func _paint_ellipse(layer: TileMapLayer, center: Vector2, axes: Vector2, jitter: Array[float]) -> void:
	var max_r: float = maxf(axes.x, axes.y) * 1.25
	var min_cell: Vector2i = _world_to_cell(center - Vector2(max_r, max_r))
	var max_cell: Vector2i = _world_to_cell(center + Vector2(max_r, max_r))
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var p: Vector2 = Vector2(cx * TILE_SIZE + TILE_SIZE / 2.0, cy * TILE_SIZE + TILE_SIZE / 2.0)
			if _inside(p, center, axes, jitter):
				layer.set_cell(Vector2i(cx, cy), 0, Vector2i.ZERO)


## Paints the shore annulus (outer ellipse minus inner ellipse) with the
## sand 9-slice, classifying each cell exactly like ground_detail.gd's own
## `_atlas_coord_for` -- a cell missing a neighbour toward the hole reveals
## the water/foam underneath; a cell missing a neighbour toward open grass
## reveals the `Floor` sprite. Same tiles, same classifier, both jobs.
func _paint_ring(layer: TileMapLayer, center: Vector2, outer_axes: Vector2, inner_axes: Vector2, jitter: Array[float]) -> void:
	var max_r: float = maxf(outer_axes.x, outer_axes.y) * 1.25
	var min_cell: Vector2i = _world_to_cell(center - Vector2(max_r, max_r))
	var max_cell: Vector2i = _world_to_cell(center + Vector2(max_r, max_r))
	var ring: Dictionary = {}
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var cell: Vector2i = Vector2i(cx, cy)
			var p: Vector2 = Vector2(cx * TILE_SIZE + TILE_SIZE / 2.0, cy * TILE_SIZE + TILE_SIZE / 2.0)
			if _inside(p, center, outer_axes, jitter) and not _inside(p, center, inner_axes, jitter):
				ring[cell] = true
	for cell: Vector2i in ring.keys():
		var has_n: bool = ring.has(cell + Vector2i(0, -1))
		var has_s: bool = ring.has(cell + Vector2i(0, 1))
		var has_e: bool = ring.has(cell + Vector2i(1, 0))
		var has_w: bool = ring.has(cell + Vector2i(-1, 0))
		layer.set_cell(cell, 0, GroundDetail._atlas_coord_for(has_n, has_s, has_e, has_w))


func _ring_foam(center: Vector2, inner_axes: Vector2, jitter: Array[float], rng: RandomNumberGenerator, frames: SpriteFrames) -> void:
	var approx_perimeter: float = TAU * (inner_axes.x + inner_axes.y) * 0.5
	var count: int = maxi(8, int(approx_perimeter / FOAM_SPACING_PX))
	for i in count:
		var angle: float = (float(i) / float(count)) * TAU - PI
		var t: float = _threshold_at(jitter, angle)
		var pos: Vector2 = center + Vector2(cos(angle) * inner_axes.x, sin(angle) * inner_axes.y) * t
		var foam: AnimatedSprite2D = AnimatedSprite2D.new()
		foam.sprite_frames = frames
		foam.animation = FOAM_ANIM
		foam.position = pos
		foam.rotation = angle
		foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foam.frame = rng.randi_range(0, FOAM_FRAME_COUNT - 1)
		foam.z_index = 0
		foam.z_as_relative = true
		add_child(foam)
		foam.play(FOAM_ANIM)


func _place_rocks(center: Vector2, inner_axes: Vector2, jitter: Array[float], rng: RandomNumberGenerator) -> void:
	var rock_count: int = rng.randi_range(1, 2)
	for i in rock_count:
		var angle: float = rng.randf_range(0.0, TAU)
		var t: float = _threshold_at(jitter, angle) * rng.randf_range(0.4, 0.75) # inside the water, not on the shore
		var pos: Vector2 = center + Vector2(cos(angle) * inner_axes.x, sin(angle) * inner_axes.y) * t
		var rock: AnimatedProp = AnimatedProp.new()
		rock.sheet = rock_textures[rng.randi_range(0, rock_textures.size() - 1)]
		rock.frame_size = Vector2i(ROCK_FRAME_SIZE, ROCK_FRAME_SIZE)
		rock.frame_count = ROCK_FRAME_COUNT
		rock.fps = 5.0
		rock.loop_mode = SpriteFrames.LOOP_LINEAR
		rock.start_frame = rng.randi_range(0, ROCK_FRAME_COUNT - 1)
		rock.position = pos
		rock.z_index = 0
		rock.z_as_relative = true
		add_child(rock)


func _ellipse_points(center: Vector2, axes: Vector2, jitter: Array[float]) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in POLY_SAMPLES:
		var angle: float = (float(k) / float(POLY_SAMPLES)) * TAU - PI
		var t: float = _threshold_at(jitter, angle)
		pts.append(center + Vector2(cos(angle) * axes.x, sin(angle) * axes.y) * t)
	return pts


func _add_polygon(points: PackedVector2Array, tex: Texture2D, node_name: String) -> void:
	var poly: Polygon2D = Polygon2D.new()
	poly.name = node_name
	poly.polygon = points
	poly.uv = points
	poly.texture = tex
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	poly.z_index = 0
	poly.z_as_relative = true
	add_child(poly)


func _add_outline(points: PackedVector2Array, node_name: String, colour: Color = SHORE_OUTLINE_COLOR, width: float = 5.0) -> void:
	var line: Line2D = Line2D.new()
	line.name = node_name
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	line.points = closed
	line.width = width
	line.default_color = colour
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 0
	line.z_as_relative = true
	add_child(line)

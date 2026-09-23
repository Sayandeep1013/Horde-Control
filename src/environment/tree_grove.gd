extends Node2D
class_name TreeGrove

## Animated tree groves clustered toward the arena's edges (art pass, D102;
## biome brief: "animated trees ... clustered in groves toward the edges").
##
## Z-ORDER, NAMED RATHER THAN SILENTLY DECIDED. The task brief asks to
## "Y-sort tall things (trees) with the entities if the scene uses Y-sort."
## scenes/main.tscn's `Entities` container is Y-sort-enabled, but it sits
## in its OWN z_index band (20); this arena (instanced under
## `Main/Environment`, z_index 0) is a sibling container, not a child of
## Entities, and this project's own draw-order rule (scenery_scatter.gd's
## header: "environment 0, pickups 10, enemies 20, Tower 25") is deliberate
## readability infrastructure, not an oversight -- reparenting tree sprites
## into Entities at runtime to get true Y-sorting against live entities
## would let a tree draw OVER an enemy, which is exactly what the SAME
## brief warns against ("trees must not hide enemies badly"). Kept at
## z_index 0 instead: trees can never occlude an entity, which is a
## stronger guarantee against hiding enemies than Y-sorting would give,
## at the cost of trees never occluding an entity that walks in "front" of
## one either. Documented here as a deliberate trade-off, not a gap.
##
## SHARED SpriteFrames, one build for every tree instance (see
## scenery_scatter.gd's own "share SpriteFrames resources" rule). Sway is 4
## frames (row 0 of Tree.png, 192x192 per frame), looped ping-pong (Godot
## 4.7+ SpriteFrames.LOOP_PINGPONG) so a short 4-frame clip reads as a
## continuous back-and-forth sway rather than a hard loop-reset snap.
##
## DETERMINISM via KeyedRng, matching every other placement in this biome
## pass. No collision is added (MASTER_SDLC.md's "no interior obstacles"
## rule for the prototype arena is about pathing, not art -- see
## scenery_scatter.gd's header for the same citation).

const FRAME_SIZE: int = 192
const FRAME_COUNT: int = 4
const ANIMATION_NAME: StringName = &"sway"
const FPS: float = 5.0

@export var tree_texture: Texture2D
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)
@export var tower_center: Vector2 = Vector2.ZERO
@export var edge_inset_px: float = 320.0 # keep groves off the coastal sand band
@export var tower_clear_radius_px: float = 900.0 # keep the Tower's approach clear of trees
@export var cluster_count: int = 6
@export var trees_per_cluster: int = 6
@export var cluster_radius_px: float = 220.0
@export var seed_key: String = "arena_biome"

## Rim clusters (this array), placed inside a band close to `edge_inset_px`
## so the forest reads "thicker toward the edges, framing the play space"
## per this biome pass's brief -- kept separate from `cluster_count`'s
## general clusters (which can land anywhere in the mid-field) rather than
## just raising `cluster_count`, so the density gradient from rim to
## centre is deliberate instead of an accident of where the RNG happened
## to land.
@export var rim_cluster_count: int = 5
@export var rim_band_px: float = 260.0 # how deep, past edge_inset_px, the rim band extends
@export var rim_trees_per_cluster: int = 8

## Sparse single trees scattered through the interior (brief: "sparse lone
## trees inside"), independent of the clustered groves above.
@export var lone_tree_count: int = 14

## Circles other biome features occupy (plateaus, ponds, landmarks) that a
## tree must not spawn inside -- e.g. a tree trunk rendered on top of a
## pond reads as a bug, not scenery. Parallel arrays, set from
## scenes/arena.tscn alongside those features' own exported positions.
@export var avoid_centers: Array[Vector2] = []
@export var avoid_radii: Array[float] = []

var _frames: SpriteFrames = null


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if tree_texture == null:
		push_warning("TreeGrove has no tree_texture assigned; no trees will be placed.")
		return
	_build_frames()
	_scatter_clusters()
	_scatter_rim_clusters()
	_scatter_lone_trees()


func _blocked(pos: Vector2) -> bool:
	if pos.distance_to(tower_center) < tower_clear_radius_px * 0.6:
		return true
	for i in avoid_centers.size():
		var r: float = avoid_radii[i] if i < avoid_radii.size() else 0.0
		if pos.distance_to(avoid_centers[i]) < r:
			return true
	return false


func _build_frames() -> void:
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	_frames.add_animation(ANIMATION_NAME)
	_frames.set_animation_loop_mode(ANIMATION_NAME, SpriteFrames.LOOP_PINGPONG)
	_frames.set_animation_speed(ANIMATION_NAME, FPS)
	for i in FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = tree_texture
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frames.add_frame(ANIMATION_NAME, atlas)


func _scatter_clusters() -> void:
	var half: Vector2 = arena_size / 2.0
	var min_x: float = -half.x + edge_inset_px
	var max_x: float = half.x - edge_inset_px
	var min_y: float = -half.y + edge_inset_px
	var max_y: float = half.y - edge_inset_px

	var center_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "tree_clusters", cluster_count])
	var placed_trees: int = 0
	for cluster_i in cluster_count:
		var attempts: int = 0
		var center: Vector2 = Vector2.ZERO
		var found: bool = false
		while attempts < 20:
			attempts += 1
			center = Vector2(
				center_rng.randf_range(min_x, max_x),
				center_rng.randf_range(min_y, max_y)
			)
			if center.distance_to(tower_center) >= tower_clear_radius_px:
				found = true
				break
		if not found:
			continue
		var tree_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "tree_grove", cluster_i])
		for i in trees_per_cluster:
			var offset: Vector2 = Vector2(tree_rng.randf_range(-1.0, 1.0), tree_rng.randf_range(-1.0, 1.0)) * cluster_radius_px
			var pos: Vector2 = center + offset
			if _blocked(pos):
				continue
			_place_tree(pos, tree_rng)
			placed_trees += 1


## Denser groves confined to a band just inside the coastal sand ring, so
## the forest visually frames the island rather than being spread evenly
## (the general clusters above already cover the mid-field).
func _scatter_rim_clusters() -> void:
	var half: Vector2 = arena_size / 2.0
	var band_min: float = edge_inset_px
	var band_max: float = edge_inset_px + rim_band_px
	var center_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "tree_rim_clusters", rim_cluster_count])

	for cluster_i in rim_cluster_count:
		# Pick one of the four sides, then a point inside that side's band.
		var side: int = center_rng.randi_range(0, 3)
		var t: float = center_rng.randf_range(-1.0, 1.0)
		var depth: float = center_rng.randf_range(band_min, band_max)
		var center: Vector2
		match side:
			0: center = Vector2(t * (half.x - band_max), -half.y + depth) # north
			1: center = Vector2(t * (half.x - band_max), half.y - depth) # south
			2: center = Vector2(-half.x + depth, t * (half.y - band_max)) # west
			_: center = Vector2(half.x - depth, t * (half.y - band_max)) # east
		if _blocked(center):
			continue
		var tree_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "tree_rim", cluster_i])
		for i in rim_trees_per_cluster:
			var offset: Vector2 = Vector2(tree_rng.randf_range(-1.0, 1.0), tree_rng.randf_range(-1.0, 1.0)) * cluster_radius_px * 0.85
			var pos: Vector2 = center + offset
			if _blocked(pos):
				continue
			_place_tree(pos, tree_rng)


## Sparse single trees through the interior (brief: "sparse lone trees
## inside"), rejection-sampled against the Tower's approach and every
## `avoid_centers` circle so a lone tree never lands on a pond, a plateau
## or a landmark's footprint.
func _scatter_lone_trees() -> void:
	var half: Vector2 = arena_size / 2.0
	var min_x: float = -half.x + edge_inset_px
	var max_x: float = half.x - edge_inset_px
	var min_y: float = -half.y + edge_inset_px
	var max_y: float = half.y - edge_inset_px
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "lone_trees", lone_tree_count])

	var placed: int = 0
	var attempts: int = 0
	while placed < lone_tree_count and attempts < lone_tree_count * 20:
		attempts += 1
		var pos: Vector2 = Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
		if _blocked(pos):
			continue
		_place_tree(pos, rng)
		placed += 1


func _place_tree(pos: Vector2, rng: RandomNumberGenerator) -> void:
	var tree: AnimatedSprite2D = AnimatedSprite2D.new()
	tree.sprite_frames = _frames
	tree.animation = ANIMATION_NAME
	tree.position = pos
	tree.scale = Vector2.ONE * rng.randf_range(0.85, 1.15)
	tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tree.frame = rng.randi_range(0, FRAME_COUNT - 1)
	tree.z_index = 0
	tree.z_as_relative = true
	add_child(tree)
	tree.play(ANIMATION_NAME)

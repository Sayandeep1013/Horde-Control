extends Node2D
class_name SheepFlock

## A few idle sheep wandering cosmetically near the arena's edges (art
## pass, D102; biome brief: "a few idle sheep (HappySheep_All.png row0 idle
## x8) wandering cosmetically near edges"). Purely decorative, exactly like
## `scenery_scatter.gd`'s own scatter -- no collision, no EntityRegistry
## registration, so the prototype's "no interior obstacles" rule
## (MASTER_SDLC.md > Game Overview > Perspective and Arena) is untouched
## and nothing in gameplay can ever query or collide with a sheep.
##
## "Cosmetic" per this project's own established meaning (TowerVisuals'
## header): this movement has no bearing on any acceptance test and does
## not touch SimClock, so a plain `_process(delta)` drift is appropriate
## here exactly as it is for TowerVisuals' tweens -- there is no gameplay
## deadline to keep in step with.
##
## Each sheep wanders inside a small circle around its own spawn point
## (never far from where KeyedRng placed it, so the flock stays "near
## edges" rather than drifting into the Tower clearing over a long run),
## picking a new random heading every few seconds. Shares one SpriteFrames
## across every instance (see scenery_scatter.gd's "share SpriteFrames
## resources" rule).

const FRAME_SIZE: int = 128
const FRAME_COUNT: int = 8
const ANIMATION_NAME: StringName = &"idle"
const FPS: float = 6.0

const WANDER_SPEED_PX_S: float = 18.0
const WANDER_RADIUS_PX: float = 140.0
const MIN_RETARGET_SECONDS: float = 2.0
const MAX_RETARGET_SECONDS: float = 5.0

@export var sheep_texture: Texture2D
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)
@export var tower_center: Vector2 = Vector2.ZERO
@export var edge_inset_px: float = 260.0
@export var tower_clear_radius_px: float = 700.0
@export var sheep_count: int = 5
@export var seed_key: String = "arena_biome"

## Grazing flocks (biome brief: "sheep flocks grazing", plural): if
## `flock_anchors` is non-empty, each entry spawns `sheep_per_flock` sheep
## clustered tightly around it (each still wandering independently once
## placed, exactly like the single-flock path below) instead of
## `sheep_count` sheep scattered independently across the whole edge band.
## Hand-placed, like every other landmark anchor in scenes/arena.tscn, so
## a flock sits somewhere that reads as a grazing spot (open grass, clear
## of a pond/plateau/building) rather than wherever uniform RNG lands.
## Left empty, `_spawn_flock()` falls back to the original single-flock
## behaviour so existing callers/tests are unaffected.
@export var flock_anchors: Array[Vector2] = []
@export var sheep_per_flock: int = 4
@export var flock_radius_px: float = 100.0

var _frames: SpriteFrames = null
var _sheep: Array[Dictionary] = [] # {node, anchor, heading, retarget_in}


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if sheep_texture == null:
		push_warning("SheepFlock has no sheep_texture assigned; no sheep will be placed.")
		return
	_build_frames()
	_spawn_flock()


func _build_frames() -> void:
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	_frames.add_animation(ANIMATION_NAME)
	_frames.set_animation_loop_mode(ANIMATION_NAME, SpriteFrames.LOOP_LINEAR)
	_frames.set_animation_speed(ANIMATION_NAME, FPS)
	for i in FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheep_texture
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frames.add_frame(ANIMATION_NAME, atlas)


func _spawn_flock() -> void:
	if not flock_anchors.is_empty():
		for i in flock_anchors.size():
			var flock_rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sheep_flock", i])
			for j in sheep_per_flock:
				var offset: Vector2 = Vector2(flock_rng.randf_range(-1.0, 1.0), flock_rng.randf_range(-1.0, 1.0)) * flock_radius_px
				_place_sheep(flock_anchors[i] + offset, flock_rng)
		return

	var half: Vector2 = arena_size / 2.0
	var min_x: float = -half.x + edge_inset_px
	var max_x: float = half.x - edge_inset_px
	var min_y: float = -half.y + edge_inset_px
	var max_y: float = half.y - edge_inset_px
	var rng: RandomNumberGenerator = KeyedRng.rng_for([seed_key, "sheep", sheep_count])

	var placed: int = 0
	var attempts: int = 0
	while placed < sheep_count and attempts < sheep_count * 20:
		attempts += 1
		var anchor: Vector2 = Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y))
		if anchor.distance_to(tower_center) < tower_clear_radius_px:
			continue
		_place_sheep(anchor, rng)
		placed += 1


func _place_sheep(anchor: Vector2, rng: RandomNumberGenerator) -> void:
	var sheep: AnimatedSprite2D = AnimatedSprite2D.new()
	sheep.sprite_frames = _frames
	sheep.animation = ANIMATION_NAME
	sheep.position = anchor
	sheep.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheep.frame = rng.randi_range(0, FRAME_COUNT - 1)
	add_child(sheep)
	sheep.play(ANIMATION_NAME)
	_sheep.append({
		"node": sheep,
		"anchor": anchor,
		"heading": Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)),
		"retarget_in": rng.randf_range(MIN_RETARGET_SECONDS, MAX_RETARGET_SECONDS),
	})


func _process(delta: float) -> void:
	for entry in _sheep:
		entry["retarget_in"] -= delta
		if entry["retarget_in"] <= 0.0:
			entry["heading"] = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
			entry["retarget_in"] = randf_range(MIN_RETARGET_SECONDS, MAX_RETARGET_SECONDS)
		var node: AnimatedSprite2D = entry["node"]
		var anchor: Vector2 = entry["anchor"]
		var next_pos: Vector2 = node.position + entry["heading"] * WANDER_SPEED_PX_S * delta
		if next_pos.distance_to(anchor) > WANDER_RADIUS_PX:
			# Turn back toward the anchor instead of wandering further out.
			entry["heading"] = (anchor - node.position).normalized()
			next_pos = node.position + entry["heading"] * WANDER_SPEED_PX_S * delta
		node.position = next_pos
		node.flip_h = entry["heading"].x < 0.0

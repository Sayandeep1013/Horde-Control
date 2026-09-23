extends AnimatedSprite2D
class_name AnimatedProp

## Generic single-animation AnimatedSprite2D builder for one-off decorative
## landmark props whose sheet is a single horizontal strip of equal-size
## frames on one row (e.g. Wood_Tower_Red's 4-frame idle sway, Fire.png's
## 7-frame flame loop, a Water/Rocks_0N bob loop).
##
## WHY THIS EXISTS, SEPARATE FROM foam_ring.gd / tree_grove.gd /
## sheep_flock.gd's own SpriteFrames builders. Those three each build ONE
## SpriteFrames resource and share it across MANY placed instances (their
## own documented "share SpriteFrames resources" performance rule) -- the
## right call when placing dozens of identical foam/tree/sheep sprites.
## This script is for the opposite, much smaller case: a handful of
## one-off landmark props (a goblin camp's watchtower, its campfire, a
## pond's water rocks) where building a private SpriteFrames per instance
## costs nothing measurable and avoids re-deriving the same ~15-line
## SpriteFrames boilerplate a fourth, fifth and sixth time.
##
## Biome pass (author's "rich, lush grassland" brief): "Animated where the
## sheet allows."

@export var sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(64, 64)
@export var frame_count: int = 1
@export var row: int = 0
@export var fps: float = 6.0
@export var loop_mode: int = SpriteFrames.LOOP_LINEAR
@export var should_autoplay: bool = true

## -1 means "start at frame 0"; a caller that wants staggered starts (so a
## handful of instances do not pulse in lockstep) sets this from ITS OWN
## KeyedRng roll before the node enters the tree, matching this biome
## pass's determinism rule -- this script deliberately has no seed_key of
## its own and never calls global randi()/randf().
@export var start_frame: int = -1

const ANIM: StringName = &"play"


func _ready() -> void:
	if sheet == null:
		push_warning("AnimatedProp has no sheet assigned; nothing will be drawn.")
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIM)
	frames.set_animation_loop_mode(ANIM, loop_mode)
	frames.set_animation_speed(ANIM, fps)
	for i in frame_count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		frames.add_frame(ANIM, atlas)
	sprite_frames = frames
	animation = ANIM
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if start_frame >= 0 and frame_count > 0:
		frame = start_frame % frame_count
	if should_autoplay:
		play(ANIM)

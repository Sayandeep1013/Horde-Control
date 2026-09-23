extends Node2D
class_name FoamRing

## Animated foam along the island's true edge (art pass, D102; biome brief:
## "animated foam along the island edge (Foam.png 192x192 x8)"). Places a
## line of AnimatedSprite2D instances right at the arena's real boundary
## (`arena_size`'s own edge, the same rectangle `scenes/arena.tscn`'s Floor
## and ArenaBounds already agree on) so the seam between the coastal sand
## `GroundDetail` paints and the `Water*Sprite` tiles beyond it has motion,
## not a hard cut.
##
## SHARED SpriteFrames. Every instance plays the SAME SpriteFrames resource
## (built once here, sliced from `Terrain/Water/Foam/Foam.png`), matching
## this project's own "share SpriteFrames resources" performance rule
## (scenery_scatter.gd's header) -- this file can place several dozen foam
## sprites for the cost of one 8-frame texture set. Each instance starts on
## a different frame (KeyedRng-seeded) so the whole ring does not pulse in
## perfect unison.
##
## VISIBILITY. `camera_bounds_test.gd`'s own arena/view-scale numbers mean
## the live camera's edge, at its most extreme clamp, lands exactly on the
## arena boundary this ring sits on -- so this is the outermost dressing a
## player can actually see, right where GroundDetail's coastal sand band
## ends. It is placed here for that reason, not as unreachable set
## dressing.

const FRAME_SIZE: int = 192
const FRAME_COUNT: int = 8
const ANIMATION_NAME: StringName = &"foam"
const FPS: float = 6.0

## Spacing between foam instances along an edge. Feel/density number, not
## a Register number.
const SPACING_PX: float = 176.0

@export var foam_texture: Texture2D
@export var arena_size: Vector2 = Vector2(4800.0, 3200.0)
@export var seed_key: String = "arena_biome"

var _frames: SpriteFrames = null


func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if foam_texture == null:
		push_warning("FoamRing has no foam_texture assigned; no foam will be placed.")
		return
	# Orchestrator rework: a drawn surf band along the coast instead of a row
	# of 192 px foam sprites, which read as evenly spaced squares on a
	# straight edge. Same treatment as pond_field.gd's surf.
	var half: Vector2 = arena_size / 2.0
	var corners: PackedVector2Array = PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y),
	])
	_band(corners, Color(0.9, 1.0, 0.98, 0.35), SURF_OUTER_WIDTH_PX)
	_band(corners, Color(0.9, 1.0, 0.98, 0.55), SURF_MID_WIDTH_PX)
	_band(corners, Color(0.95, 1.0, 1.0, 0.95), 4.0)


const SURF_OUTER_WIDTH_PX: float = 56.0
const SURF_MID_WIDTH_PX: float = 22.0


func _band(points: PackedVector2Array, colour: Color, width: float) -> void:
	var line: Line2D = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = colour
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)


func _build_frames() -> void:
	_frames = SpriteFrames.new()
	_frames.remove_animation(&"default")
	_frames.add_animation(ANIMATION_NAME)
	_frames.set_animation_loop_mode(ANIMATION_NAME, SpriteFrames.LOOP_LINEAR)
	_frames.set_animation_speed(ANIMATION_NAME, FPS)
	for i in FRAME_COUNT:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = foam_texture
		atlas.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		_frames.add_frame(ANIMATION_NAME, atlas)


func _line(from_pos: Vector2, to_pos: Vector2, rotation_deg: float, rng: RandomNumberGenerator) -> void:
	var length: float = from_pos.distance_to(to_pos)
	var count: int = maxi(1, int(length / SPACING_PX))
	for i in range(count):
		var t: float = (float(i) + 0.5) / float(count)
		var pos: Vector2 = from_pos.lerp(to_pos, t)
		var foam: AnimatedSprite2D = AnimatedSprite2D.new()
		foam.sprite_frames = _frames
		foam.animation = ANIMATION_NAME
		foam.position = pos
		foam.rotation_degrees = rotation_deg
		foam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		foam.frame = rng.randi_range(0, FRAME_COUNT - 1)
		add_child(foam)
		foam.play(ANIMATION_NAME)

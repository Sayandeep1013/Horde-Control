extends Sprite2D
class_name DashAfterimage
## One fading copy of the player's current frame (docs/31 §3.1: the Dash trail
## is 3 of these). Visual only. Uses real frame delta because it is cosmetic
## and PAUSABLE; nothing in the simulation reads it.

const LIFETIME_SECONDS: float = 0.28 # Register: Dash afterimage lifetime
const START_ALPHA: float = 0.55
const TINT: Color = Color(0.7, 0.85, 1.0)

var _age: float = 0.0


static func spawn(parent: Node, source: AnimatedSprite2D, world_position: Vector2) -> DashAfterimage:
	var tex: Texture2D = null
	if source.sprite_frames != null and source.sprite_frames.has_animation(source.animation):
		tex = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if tex == null:
		return null
	var img := DashAfterimage.new()
	img.texture = tex
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.flip_h = source.flip_h
	img.scale = source.global_scale
	img.offset = source.offset
	parent.add_child(img)
	img.global_position = source.global_position
	img.z_as_relative = false
	img.z_index = 18 # just under the play layer (20) so the real player stays on top
	img.modulate = Color(TINT.r, TINT.g, TINT.b, START_ALPHA)
	return img


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	_age += delta
	var k: float = clampf(_age / LIFETIME_SECONDS, 0.0, 1.0)
	modulate.a = START_ALPHA * (1.0 - k)
	if k >= 1.0:
		queue_free()

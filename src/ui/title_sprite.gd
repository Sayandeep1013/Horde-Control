extends TextureRect
class_name TitleSprite

## A looping frame-strip sprite for the title screen's background art
## (src/ui/title_screen.gd only calls this; nothing else references it).
## Builds its own `AtlasTexture` frames from a sheet + frame size + row +
## count (the Tiny Swords sheet-layout table in
## assets/third_party/tiny_swords/PROVENANCE.md), then advances through
## them on a fixed frame rate from this node's own `_process()` -- never a
## `Timer` or `get_tree().create_timer()`/`create_tween()`. Both are banned
## under the gameplay root (tools/checks/banned_api_check.sh), which exempts
## every `.../ui/...` path entirely, but this file needs neither regardless:
## a manual per-frame accumulator is the simplest correct way to loop a
## fixed-rate sprite sheet.
##
## `configure()` optionally randomizes the starting frame and phase
## (`start_random`) so several instances of the same sheet (the two trees,
## the idling goblins) do not all animate in lockstep -- a purely cosmetic
## touch with no gameplay meaning.

@export var fps: float = 6.0

var _frames: Array[AtlasTexture] = []
var _frame_index: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Typed command. `sheet` is the whole spritesheet texture; `frame_size` is
## one frame's pixel size; `row` (0-based) and `count` select the frames
## along that row, left to right, matching every sheet-layout row this
## project's Tiny Swords PROVENANCE.md documents.
func configure(sheet: Texture2D, frame_size: Vector2i, row: int, count: int, start_random: bool = true) -> void:
	_frames.clear()
	for col in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
		_frames.append(atlas)
	if start_random and not _frames.is_empty():
		_frame_index = randi() % _frames.size()
		_elapsed = randf() * (1.0 / fps)
	else:
		_frame_index = 0
		_elapsed = 0.0
	_apply_frame()


func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_elapsed += delta
	var step: float = 1.0 / fps
	while _elapsed >= step:
		_elapsed -= step
		_frame_index = (_frame_index + 1) % _frames.size()
	_apply_frame()


func _apply_frame() -> void:
	if _frames.is_empty():
		return
	texture = _frames[_frame_index]

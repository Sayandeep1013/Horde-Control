extends Node2D
class_name BridgeSpan

## A north-south plank bridge built from the pack's own vertical bridge piece
## (`Terrain/Bridge/Bridge_All.png`, the left column: x 0-64, y 80-240), at
## native scale and no rotation (art-consistency pass, D157/D158). It replaces
## the horizontal piece rotated 90 degrees and stretched 1.4 x 1.15, which put
## the light on the wrong side and gave non-square pixels.
##
## The piece is a top cap (posts), a plank run whose planks repeat every 16 px,
## and a bottom cap. The caps are used once and the plank run is repeated to
## reach `length_px`, so any length that is a multiple of 16 beyond the 64 px of
## caps keeps the pack's pixels unscaled.
##
## The node's origin is the centre of the span.

const CAP_TOP: Rect2 = Rect2(0, 80, 64, 32)
const PLANKS: Rect2 = Rect2(0, 112, 64, 16)
const CAP_BOTTOM: Rect2 = Rect2(0, 208, 64, 32)

@export var texture: Texture2D
@export var length_px: float = 160.0


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture == null:
		push_warning("BridgeSpan has no texture assigned; no bridge will be drawn.")
		return
	var plank_count: int = maxi(0, int(round((length_px - CAP_TOP.size.y - CAP_BOTTOM.size.y) / PLANKS.size.y)))
	var total: float = CAP_TOP.size.y + CAP_BOTTOM.size.y + PLANKS.size.y * plank_count
	var y: float = -total * 0.5
	_add_piece(CAP_TOP, y)
	y += CAP_TOP.size.y
	for i in plank_count:
		_add_piece(PLANKS, y)
		y += PLANKS.size.y
	_add_piece(CAP_BOTTOM, y)


func _add_piece(region: Rect2, top_y: float) -> void:
	var s: Sprite2D = Sprite2D.new()
	s.texture = texture
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = Vector2(-region.size.x * 0.5, top_y)
	add_child(s)

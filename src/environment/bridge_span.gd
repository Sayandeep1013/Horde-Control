extends Node2D
class_name BridgeSpan

## A plank bridge built from the pack's own bridge pieces (`Terrain/Bridge/Bridge_All.png`) at
## native scale and no rotation (art-consistency pass, D157/D158; widened and given an
## east-west form for the moat, D330).
##
## The vertical piece (left column: x 0-64, y 80-240) is a top cap (posts), a plank run whose
## planks repeat every 16 px and a bottom cap; the horizontal piece (x 16-176, y 0-62) is the same
## turned a quarter (left cap, planks repeating every 16 px, right cap). The caps are used once and
## the plank run is repeated to reach `length_px`. `width_px` widens the deck past the pack's 64 px
## by repeating an 8 px slice of the middle of every row, so the posts stay at the two outer
## edges: the arena's bridges are 128 px wide (a chokepoint four bodies wide, not one).
##
## The node's origin is the centre of the span; `horizontal` runs it east-west.

const CAP_TOP: Rect2 = Rect2(0, 80, 64, 32)
const PLANKS: Rect2 = Rect2(0, 112, 64, 16)
const CAP_BOTTOM: Rect2 = Rect2(0, 208, 64, 32)
const H_CAP_LEFT: Rect2 = Rect2(16, 0, 58, 64)
const H_PLANKS: Rect2 = Rect2(74, 0, 16, 64)
const H_CAP_RIGHT: Rect2 = Rect2(138, 0, 38, 64)
const SLICE_PX: float = 8.0

@export var texture: Texture2D
@export var length_px: float = 160.0
@export var width_px: float = 64.0
@export var horizontal: bool = false

var _batch: GroundBatch = null


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture == null:
		push_warning("BridgeSpan has no texture assigned; no bridge will be drawn.")
		return
	# PT-PHONE (D397): every plank and slice is an entry of ONE canvas item, not a Sprite2D each.
	_batch = GroundBatch.new()
	_batch.name = "Planks"
	_batch.textures = [texture]
	_batch.cull = false
	add_child(_batch)
	if horizontal:
		var plank_count: int = maxi(0, int(round((length_px - H_CAP_LEFT.size.x - H_CAP_RIGHT.size.x) / H_PLANKS.size.x)))
		var total: float = H_CAP_LEFT.size.x + H_CAP_RIGHT.size.x + H_PLANKS.size.x * plank_count
		var x: float = -total * 0.5
		_add_row(H_CAP_LEFT, Vector2(x, 0.0), true)
		x += H_CAP_LEFT.size.x
		for i in plank_count:
			_add_row(H_PLANKS, Vector2(x, 0.0), true)
			x += H_PLANKS.size.x
		_add_row(H_CAP_RIGHT, Vector2(x, 0.0), true)
	else:
		var plank_count: int = maxi(0, int(round((length_px - CAP_TOP.size.y - CAP_BOTTOM.size.y) / PLANKS.size.y)))
		var total: float = CAP_TOP.size.y + CAP_BOTTOM.size.y + PLANKS.size.y * plank_count
		var y: float = -total * 0.5
		_add_row(CAP_TOP, Vector2(0.0, y), false)
		y += CAP_TOP.size.y
		for i in plank_count:
			_add_row(PLANKS, Vector2(0.0, y), false)
			y += PLANKS.size.y
		_add_row(CAP_BOTTOM, Vector2(0.0, y), false)
	_batch.bake()


## One strip of the span. Across the deck (x for the vertical form, y for the horizontal) it is
## drawn as left half + repeated middle slices + right half, centred on the node.
func _add_row(region: Rect2, along_pos: Vector2, is_horizontal: bool) -> void:
	var cross: float = region.size.y if is_horizontal else region.size.x
	var half: float = cross * 0.5
	var extra: int = maxi(0, int(round((width_px - cross) / SLICE_PX)))
	var total_cross: float = cross + SLICE_PX * extra
	var start: float = -total_cross * 0.5
	var lo: Rect2 = _sub(region, 0.0, half, is_horizontal)
	var mid: Rect2 = _sub(region, half - SLICE_PX * 0.5, SLICE_PX, is_horizontal)
	var hi: Rect2 = _sub(region, half, half, is_horizontal)
	var c: float = start
	_piece(lo, along_pos, c, is_horizontal)
	c += half
	for i in extra:
		_piece(mid, along_pos, c, is_horizontal)
		c += SLICE_PX
	_piece(hi, along_pos, c, is_horizontal)


func _sub(region: Rect2, from: float, length: float, is_horizontal: bool) -> Rect2:
	if is_horizontal:
		return Rect2(region.position.x, region.position.y + from, region.size.x, length)
	return Rect2(region.position.x + from, region.position.y, length, region.size.y)


func _piece(region: Rect2, along_pos: Vector2, cross_pos: float, is_horizontal: bool) -> void:
	var pos: Vector2 = Vector2(along_pos.x, cross_pos) if is_horizontal else Vector2(cross_pos, along_pos.y)
	_batch.add(0, Rect2(pos, region.size), region)

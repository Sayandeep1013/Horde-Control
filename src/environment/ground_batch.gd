class_name GroundBatch
extends Node2D

## PT-PHONE (D397): many small static or looping ground sprites drawn by ONE canvas item.
##
## The arena floor carried about 800 canvas items (a Sprite2D per bridge plank and scenery prop,
## an AnimatedSprite2D per foam tile, 320 of them animating every frame). Each costs a node, a
## cull test, a transform and, on the Compatibility renderer, often its own draw call. They are
## all ground paint below every entity (z 0, nothing y-sorts against them), so they can be one
## item: a list of (texture, destination rect, source rect, start frame) drawn in `_draw`.
##
## - Looping tiles (foam) step `frame_stride` px per frame in the source rect, `fps` frames a
##   second; the item is redrawn when the frame changes.
## - Only entries near the screen are drawn (`cull`): the item redraws when the view leaves the
##   rect it last drew, so a 4800 x 3200 arena costs what is on screen.
## - `sort_by_texture` draws entries grouped by texture (ground props that never overlap), so
##   the renderer merges them into one draw call per texture instead of one per prop.
##
## Look: nearest filtering, no rotation, positions and sizes exactly as the sprites had them.

## Margin around the screen that is drawn, and so how far the view may move before a redraw.
const CULL_MARGIN_PX: float = 320.0

var textures: Array[Texture2D] = []
var frame_count: int = 1
var fps: float = 0.0
var frame_stride: Vector2 = Vector2.ZERO
var cull: bool = true
var sort_by_texture: bool = false
var tint: Color = Color.WHITE

var _tex: PackedInt32Array = PackedInt32Array()
var _dst: PackedFloat32Array = PackedFloat32Array() # x, y, w, h per entry
var _src: PackedFloat32Array = PackedFloat32Array() # x, y, w, h per entry; w <= 0: the whole texture
var _start: PackedInt32Array = PackedInt32Array()
var _flip: PackedByteArray = PackedByteArray()
var _order: PackedInt32Array = PackedInt32Array()
var _baked: bool = false
var _drawn_rect: Rect2 = Rect2()
var _drawn_frame: int = -1


## Adds one entry. `src` is the first frame's source rect (size zero: the whole texture).
func add(texture_index: int, dst: Rect2, src: Rect2 = Rect2(), start_frame: int = 0, flip_h: bool = false) -> void:
	_tex.append(texture_index)
	_dst.append_array(PackedFloat32Array([dst.position.x, dst.position.y, dst.size.x, dst.size.y]))
	_src.append_array(PackedFloat32Array([src.position.x, src.position.y, src.size.x, src.size.y]))
	_start.append(start_frame)
	_flip.append(1 if flip_h else 0)
	_baked = false


func get_entry_count() -> int:
	return _tex.size()


## Entry centres (tests, placement queries).
func get_entry_centres() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _tex.size():
		out.append(Vector2(_dst[i * 4] + _dst[i * 4 + 2] * 0.5, _dst[i * 4 + 1] + _dst[i * 4 + 3] * 0.5))
	return out


func clear() -> void:
	_tex.clear()
	_dst.clear()
	_src.clear()
	_start.clear()
	_flip.clear()
	_order.clear()
	_baked = false
	_drawn_rect = Rect2()
	queue_redraw()


## Fixes the draw order (entry order, or grouped by texture) and starts drawing.
func bake() -> void:
	var n: int = _tex.size()
	_order.resize(n)
	for i in n:
		_order[i] = i
	if sort_by_texture:
		var keys := PackedInt64Array()
		keys.resize(n)
		for i in n:
			keys[i] = (int(_tex[i]) << 32) | i # stable: ties keep entry order
		keys.sort()
		for i in n:
			_order[i] = int(keys[i] & 0xFFFFFFFF)
	_baked = true
	_drawn_rect = Rect2()
	set_process(cull or (fps > 0.0 and frame_count > 1))
	queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	if not _baked and not _tex.is_empty():
		bake()


func _process(_delta: float) -> void:
	if not _baked:
		return
	if fps > 0.0 and frame_count > 1 and _current_frame() != _drawn_frame:
		queue_redraw()
		return
	if cull and not _drawn_rect.encloses(_view_rect()):
		queue_redraw()


func _current_frame() -> int:
	return int(floor(float(Time.get_ticks_msec()) * 0.001 * fps)) % frame_count


## What the screen shows, in this node's local space.
func _view_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var screen: Rect2 = vp.get_visible_rect()
	var world: Rect2 = get_canvas_transform().affine_inverse() * screen
	return get_global_transform().affine_inverse() * world


func _draw() -> void:
	if not _baked or _order.is_empty():
		return
	var view: Rect2 = Rect2()
	if cull:
		view = _view_rect().grow(CULL_MARGIN_PX)
		_drawn_rect = view
	var frame: int = _current_frame() if fps > 0.0 and frame_count > 1 else 0
	_drawn_frame = frame
	var animated: bool = frame_count > 1 and frame_stride != Vector2.ZERO
	for k in _order.size():
		var i: int = _order[k]
		var b: int = i * 4
		if cull and not (_dst[b] < view.end.x and _dst[b] + _dst[b + 2] > view.position.x and _dst[b + 1] < view.end.y and _dst[b + 1] + _dst[b + 3] > view.position.y):
			continue
		var dst := Rect2(_dst[b], _dst[b + 1], _dst[b + 2], _dst[b + 3])
		if _flip[i] == 1:
			dst.size.x = -dst.size.x # a negative width flips the texture in place (the position stays the left edge)
		var texture: Texture2D = textures[_tex[i]]
		if _src[b + 2] <= 0.0:
			draw_texture_rect(texture, dst, false, tint)
		else:
			var src := Rect2(_src[b], _src[b + 1], _src[b + 2], _src[b + 3])
			if animated:
				src.position += frame_stride * float((frame + _start[i]) % frame_count)
			draw_texture_rect_region(texture, dst, src, tint)

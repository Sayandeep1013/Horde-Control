class_name FpsOverlay
extends CanvasLayer

## Frame-rate readout for Settings > Video > Show FPS (docs/31 §8.4; PT-PHONE item 6, D399).
## The author needs real phone numbers, so it works in shipped Windows and Android builds and
## is off by default. Not an autoload: `FpsOverlay.sync()` adds one instance under the
## scene-tree root while `GameSettings.is_show_fps()` is on and frees it when it is off, so it
## survives title -> hub -> run scene changes without a further global singleton.
##
## Reads like the HUD (the HUD value text size, on a dark walnut plate with an ink border) and
## never sits on the HUD: inside the safe area, in the top-right corner below the Scrap / kills
## panel when a HUD exists, flush to the corner otherwise (title, hub). Two lines:
##
##   60 FPS   16.7 ms           smoothed over the last quarter second
##   worst 24 ms   180 alive    slowest frame of the last second; enemies alive during a run
##
## Frame times come from the clock, not `Engine.get_frames_per_second()` (a one-second average
## that hides a stutter), and the per-frame work is three additions; the text is rewritten
## four times a second.

const NODE_NAME: String = "FpsOverlay"
const OVERLAY_LAYER: int = 100
const REFRESH_SECONDS: float = 0.25
## Windows of `REFRESH_SECONDS` that make up the "worst frame of the last second".
const WORST_WINDOWS: int = 4
const PLATE_PADDING: Vector2 = Vector2(14.0, 6.0)
const HUD_GAP_PX: float = 8.0
const HUD_FIELD_NAME: String = "ScrapField"

var _plate: PanelContainer
var _label: Label
var _frame: Control
var _last_usec: int = 0
var _accum: float = 0.0
var _sum_ms: float = 0.0
var _count: int = 0
var _max_ms: float = 0.0
var _worst_windows: PackedFloat32Array = PackedFloat32Array()
var _hud_field: Control = null
var _next_hud_lookup_msec: int = 0


static func sync() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var existing: Node = tree.root.get_node_or_null(NODE_NAME)
	if GameSettings.is_show_fps():
		if existing == null:
			var overlay := FpsOverlay.new()
			overlay.name = NODE_NAME
			_attach.call_deferred(tree, overlay)
	elif existing != null:
		tree.root.remove_child(existing) # out of the tree at once, so a later sync cannot find a dying overlay
		existing.free()


## Deferred so the root is free to take a child; skipped if the setting flipped off meanwhile.
static func _attach(tree: SceneTree, overlay: FpsOverlay) -> void:
	if GameSettings.is_show_fps() and tree.root.get_node_or_null(NODE_NAME) == null:
		tree.root.add_child(overlay)
	else:
		overlay.free()


## The two lines of text for one reading. Static so a test can pin the wording.
static func format_lines(fps: int, frame_ms: float, worst_ms: float, alive: int) -> String:
	var first: String = "%d FPS   %.1f ms" % [fps, frame_ms]
	var second: String = "worst %d ms" % roundi(worst_ms)
	if alive >= 0:
		second += "   %d alive" % alive
	return first + "\n" + second


func _ready() -> void:
	layer = OVERLAY_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_worst_windows.resize(WORST_WINDOWS)
	_worst_windows.fill(0.0)
	_frame = Control.new() # D370: inside the phone's safe area
	_frame.name = "Safe"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	SafeArea.fit(_frame)
	_plate = PanelContainer.new()
	_plate.name = "FpsPlate"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiPalette.INK_PIXEL, 0.82)
	box.border_color = Color(UiPalette.TEXT, 0.35)
	box.set_border_width_all(2)
	box.set_corner_radius_all(UiPalette.RADIUS_SMALL)
	box.content_margin_left = PLATE_PADDING.x
	box.content_margin_right = PLATE_PADDING.x
	box.content_margin_top = PLATE_PADDING.y
	box.content_margin_bottom = PLATE_PADDING.y
	_plate.add_theme_stylebox_override("panel", box)
	_frame.add_child(_plate)
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.theme = UiTheme.get_theme()
	_label.theme_type_variation = UiTheme.HUD_VALUE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_plate.add_child(_label)
	_plate.resized.connect(_place)
	_last_usec = Time.get_ticks_usec()
	_refresh()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	record_frame_ms(ms)
	_accum += ms / 1000.0
	if _accum >= REFRESH_SECONDS:
		_accum = 0.0
		_refresh()


## One frame's duration; the three additions the overlay does every frame.
func record_frame_ms(ms: float) -> void:
	_sum_ms += ms
	_count += 1
	if ms > _max_ms:
		_max_ms = ms


func get_label_for_test() -> Label:
	return _label


func get_plate_for_test() -> Control:
	return _plate


## Closes the current window: average and worst frame of the window, worst of the last second.
func _refresh() -> void:
	var avg_ms: float = _sum_ms / float(_count) if _count > 0 else 0.0
	for i in WORST_WINDOWS - 1:
		_worst_windows[i] = _worst_windows[i + 1]
	_worst_windows[WORST_WINDOWS - 1] = _max_ms
	_sum_ms = 0.0
	_count = 0
	_max_ms = 0.0
	var worst: float = 0.0
	for w in _worst_windows:
		worst = maxf(worst, w)
	var fps: int = roundi(1000.0 / avg_ms) if avg_ms > 0.01 else int(Engine.get_frames_per_second())
	_label.text = format_lines(fps, avg_ms, worst, _alive_enemies())
	_place()


## Enemies alive during a run (-1 outside one: title, hub).
func _alive_enemies() -> int:
	var tree: SceneTree = get_tree()
	if tree == null or tree.get_first_node_in_group(&"sim_loop") == null:
		return -1
	return EntityRegistry.get_live_enemy_count()


## Top-right of the safe frame; below the Scrap / kills panel when the HUD is up.
func _place() -> void:
	if _plate == null or _frame == null:
		return
	var width: float = _plate.size.x
	var top: float = 0.0
	var right: float = _frame.size.x
	var field: Control = _hud_scrap_field()
	if field != null:
		var rect: Rect2 = field.get_global_transform() * Rect2(Vector2.ZERO, field.size)
		var frame_origin: Vector2 = _frame.get_global_transform().origin
		top = rect.end.y - frame_origin.y + HUD_GAP_PX
		right = rect.end.x - frame_origin.x
	_plate.position = Vector2(maxf(0.0, right - width), maxf(0.0, top))


func _hud_scrap_field() -> Control:
	if _hud_field != null and is_instance_valid(_hud_field) and _hud_field.is_inside_tree():
		return _hud_field
	_hud_field = null
	var now: int = Time.get_ticks_msec()
	if now < _next_hud_lookup_msec:
		return null
	_next_hud_lookup_msec = now + 1000 # a scene without a HUD is looked at once a second
	var hud: Node = get_tree().get_first_node_in_group(&"hud") if get_tree() != null else null
	if hud != null:
		_hud_field = hud.find_child(HUD_FIELD_NAME, true, false) as Control
	return _hud_field

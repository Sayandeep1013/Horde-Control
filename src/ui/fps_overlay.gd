class_name FpsOverlay
extends CanvasLayer

## Small frames-per-second readout for the "Show FPS" video setting (docs/31
## §8.4). Not an autoload: `FpsOverlay.sync()` adds one instance under the
## scene-tree root while `GameSettings.is_show_fps()` is on and frees it when
## it is off, so it survives scene changes without a further global singleton.
## Non-essential tag, so it uses the 19 px small style (docs/19, D166).

const NODE_NAME: String = "FpsOverlay"
const OVERLAY_LAYER: int = 100
const REFRESH_SECONDS: float = 0.25

var _label: Label
var _accum: float = 0.0


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
		existing.queue_free()


## Deferred so the root is free to take a child; skipped if the setting flipped off meanwhile.
static func _attach(tree: SceneTree, overlay: FpsOverlay) -> void:
	if GameSettings.is_show_fps() and tree.root.get_node_or_null(NODE_NAME) == null:
		tree.root.add_child(overlay)
	else:
		overlay.free()


func _ready() -> void:
	layer = OVERLAY_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.theme = UiTheme.get_theme()
	_label.theme_type_variation = UiTheme.SMALL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_label.offset_left = UiPalette.SCREEN_MARGIN
	_label.offset_bottom = -UiPalette.SCREEN_MARGIN
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_label)
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= REFRESH_SECONDS:
		_accum = 0.0
		_refresh()


func get_label_for_test() -> Label:
	return _label


func _refresh() -> void:
	_label.text = "%d FPS" % int(Engine.get_frames_per_second())

extends Node
## Development-only capture harness (art session, D102). Instantiates a scene,
## lets it run for a number of frames, and saves screenshots of the real
## rendered viewport, then quits. Not part of the shipped game; nothing in
## scenes/ references it.
##
## Usage (a window opens briefly; audio is muted by the dummy driver):
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/dev/scene_capture.tscn -- --scene=res://scenes/prototype.tscn \
##     --frames=240,600 --out=sandbox/captures/shot [--size=1920x1080] [--hold_move=right]
## Writes <out>_<frame>.png for each listed frame.

var _frames: Array[int] = []
var _out: String = "sandbox/captures/shot"
var _count: int = 0
var _hold_action: String = ""
var _dump_filter: String = ""

func _ready() -> void:
	var scene_path: String = "res://scenes/prototype.tscn"
	var size: Vector2i = Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--frames="):
			for f in arg.trim_prefix("--frames=").split(","):
				_frames.append(int(f))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var p: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--dump-tree="):
			_dump_filter = arg.trim_prefix("--dump-tree=")
		elif arg.begins_with("--hold_move="):
			_hold_action = "move_" + arg.trim_prefix("--hold_move=")
	if _frames.is_empty():
		_frames = [240]
	_frames.sort()
	get_window().size = size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out.get_base_dir()))
	var packed: PackedScene = load(scene_path)
	add_child(packed.instantiate())
	if _hold_action != "" and InputMap.has_action(_hold_action):
		Input.action_press(_hold_action)

func _process(_delta: float) -> void:
	_count += 1
	if not _frames.is_empty() and _count >= _frames[0]:
		var f: int = _frames.pop_front()
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://").path_join("%s_%d.png" % [_out, f])
		img.save_png(path)
		print("CAPTURED ", path)
		if _dump_filter != "":
			_dump(get_tree().root, 0)
		if _frames.is_empty():
			get_tree().quit()


## `--dump-tree=<substring>` prints every node whose path contains the
## substring, with visibility and child count, at capture time. Used to
## diagnose exported-build differences (the pck cannot be inspected in the
## editor).
func _dump(node: Node, depth: int) -> void:
	var path: String = str(node.get_path())
	if path.contains(_dump_filter):
		var vis: String = ""
		if node is CanvasItem:
			vis = " visible=%s z=%d" % [(node as CanvasItem).is_visible_in_tree(), (node as CanvasItem).z_index]
		print("TREE %s (%s) children=%d%s" % [path, node.get_class(), node.get_child_count(), vis])
	if depth < 6:
		for c in node.get_children():
			_dump(c, depth + 1)

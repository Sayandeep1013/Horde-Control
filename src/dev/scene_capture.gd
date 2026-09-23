extends Node
## Development-only capture harness (art session, D102). Instantiates a scene,
## lets it run for a number of frames, and saves screenshots of the real
## rendered viewport, then quits. Not part of the shipped game; nothing in
## scenes/ references it.
##
## Usage (a window opens briefly; audio is muted by the dummy driver):
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/dev/scene_capture.tscn -- --scene=res://scenes/prototype.tscn \
##     --frames=240,600 --out=sandbox/captures/shot [--size=1920x1080] [--hold_move=right] \
##     [--player_pos=X,Y] [--meta-profile-dir=<dir>] [--debug-panel=skill_tree]
## Writes <out>_<frame>.png for each listed frame.
##
## `--player_pos=X,Y` and `--meta-profile-dir=`/`--debug-panel=` are not
## parsed by THIS file: the first teleports `res://scenes/prototype.tscn`'s
## own `Main/Player` (best-effort -- silently skipped for any scene without
## that exact path) to an exact world position immediately after the scene
## loads, for a deterministic depth/occlusion capture that a single held
## direction from the player's fixed spawn point cannot reach in one run
## (Draw-order verification, Author decision D119). The other two are read
## directly by `src/meta/meta_progress.gd`'s own `_resolve_base_path_from_
## cmdline()` and `src/ui/hub_screen.gd`'s own `_apply_debug_panel_flag()`
## -- both already existing, generic `OS.get_cmdline_user_args()` readers,
## independent of this harness; named here only so a caller finds them
## documented in the one place they would think to look.

var _frames: Array[int] = []
var _out: String = "sandbox/captures/shot"
var _count: int = 0
var _hold_action: String = ""
var _dump_filter: String = ""
var _has_player_pos: bool = false
var _player_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep counting frames while a Draft or menu pauses the tree
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
		elif arg.begins_with("--player_pos="):
			var xy: PackedStringArray = arg.trim_prefix("--player_pos=").split(",")
			if xy.size() == 2:
				_player_pos = Vector2(float(xy[0]), float(xy[1]))
				_has_player_pos = true
	if _frames.is_empty():
		_frames = [240]
	_frames.sort()
	get_window().size = size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out.get_base_dir()))
	var packed: PackedScene = load(scene_path)
	var instance: Node = packed.instantiate()
	add_child(instance)
	if _has_player_pos:
		var player: Node2D = instance.get_node_or_null("Main/Player") as Node2D
		if player != null:
			player.global_position = _player_pos
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

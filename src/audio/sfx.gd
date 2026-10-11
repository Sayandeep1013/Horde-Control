extends RefCounted
class_name Sfx
## v1.0 one-call sound cue helper (WP0, decision D178; docs/31 §9).
##
## `Sfx.play("dash", global_position)` plays `assets/audio/sfx/<cue>.wav`
## (or .ogg) through the gameplay AudioPool (group "audio_pool"), so world
## sounds pause with the tree and obey the 32-voice stealing rules.
## `Sfx.play_ui("level_up")` plays on the UI bus with a PROCESS_MODE_ALWAYS
## one-shot player, for sounds that must be heard while paused (docs/20:
## "UI sounds do not draw from this pool").
##
## A cue whose file does not exist yet is a silent no-op, so code can wire a
## cue before WP-ASSETS delivers the file. Each cue is throttled to one play
## per MIN_INTERVAL_MS of wall time (audio only; no gameplay reads it) so a
## burst of 40 hits in a frame does not stack 40 identical sounds.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MIN_INTERVAL_MS: int = 45

static var _streams: Dictionary = {} # cue -> AudioStream or null
static var _last_play_ms: Dictionary = {} # cue -> int


static func play(cue: String, world_position: Vector2 = Vector2.INF, priority: int = 0, is_priority: bool = false) -> void:
	var stream: AudioStream = _stream_for(cue)
	if stream == null or not _throttle_ok(cue):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var pool: Node = tree.get_first_node_in_group("audio_pool")
	if pool != null and pool.has_method("play"):
		var pos: Vector2 = world_position
		if pos == Vector2.INF:
			var cam: Camera2D = tree.root.get_camera_2d()
			pos = cam.get_screen_center_position() if cam != null else Vector2.ZERO
		pool.play(stream, pos, priority, is_priority, "SFX_Priority" if is_priority else "SFX")
		return
	_play_one_shot(tree, stream, "SFX")


static func play_ui(cue: String) -> void:
	var stream: AudioStream = _stream_for(cue)
	if stream == null or not _throttle_ok(cue):
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_play_one_shot(tree, stream, "UI")


static func has_cue(cue: String) -> bool:
	return _stream_for(cue) != null


static func _play_one_shot(tree: SceneTree, stream: AudioStream, bus: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func _stream_for(cue: String) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var stream: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = SFX_DIR + cue + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	_streams[cue] = stream
	return stream


static func _throttle_ok(cue: String) -> bool:
	var now: int = Time.get_ticks_msec()
	if now - int(_last_play_ms.get(cue, -100000)) < MIN_INTERVAL_MS:
		return false
	_last_play_ms[cue] = now
	return true


static func clear_cache_for_test() -> void:
	_streams.clear()
	_last_play_ms.clear()


## Shutdown hygiene (D256 hook, ShutdownHygiene): drop cached streams so the engine
## leak report at quit does not list them.
static func release_caches() -> void:
	_streams.clear()
	_last_play_ms.clear()

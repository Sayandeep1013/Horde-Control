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
##     [--grant=flame_arrows:3,ballista:2] [--skill=firebomb] [--cast-frames=F,F]
##     [--dash-frames=F,F] [--spawn-frame=F --spawn-count=N] [--tower-hp=0.4 --scrap=100]
##     [--pause-frame=F]  (opens the pause menu at frame F)
##     [--champion=warden --relics=quiver_of_echoes,iron_banner]  (WP-LOADOUT: RunConfig for the run)
##     [--lineup=tower_seeker,player_hunter,opportunist,bomber]  (at --spawn-frame: a static
##      row of those enemy scenes 170 px below the player, for readability captures)
##     [--arena-showcase=war|haste|ward|bounty] (at frame 3: two crates, a keg and a shrine around the player)
##     [--arena-wave=N] (at frame 3: spawn wave N's arena interactables by the normal rules)
##     [--boons=war,haste,ward,bounty] (at frame 3: claim those Shrine boons for a tray capture)
##     [--light-kegs=F] (at frame F: light every Powder Keg)
##   [--first-time-tips]  (PT-UI: keep the first-encounter explainers on; captures turn them off)
##   (the v1.0 flags are dev-only helpers for WP-COMBAT captures, prototype scene only)
##   [--event=opening|patrons_boon|sanctuary|blood_pact] [--flawless] [--armory]
##   [--champion=pactbound] [--relic=lucky_coin]   (docs/32 run events: at frame 1 the
##    Opening Pick that opens every run is answered with card 1, so captures that do not
##    ask for an event run unpaused as before; --event then queues that event at once)
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
var _grants: Array[String] = []
var _cast_frames: Array[int] = []
var _dash_frames: Array[int] = []
var _spawn_frame: int = -1
var _spawn_count: int = 0
var _tower_hp_fraction: float = -1.0
var _scrap: int = -1
var _skill_id: String = ""
var _lineup: Array[String] = []
var _arena_showcase: String = ""
var _arena_wave: int = 0
var _boons: Array[String] = []
var _light_kegs_frame: int = -1
var _pause_frame: int = -1 # WP-LOADOUT: opens the pause menu at this frame
var _scene: Node = null
var _has_player_pos: bool = false
var _player_pos: Vector2 = Vector2.ZERO
var _event_kind: String = ""
var _event_flawless: bool = false
var _event_armory: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # keep counting frames while a Draft or menu pauses the tree
	# PT-UI (docs/33 A4): first-encounter explainers pause the run; a capture must not wait on one
	# unless it asks for them (`--first-time-tips`).
	if not OS.get_cmdline_user_args().has("--first-time-tips"):
		GameSettings.set_show_first_time_tips_for_test(false)
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
		elif arg.begins_with("--grant="):
			for g in arg.trim_prefix("--grant=").split(","):
				_grants.append(g)
		elif arg.begins_with("--skill="):
			_skill_id = arg.trim_prefix("--skill=")
		elif arg.begins_with("--cast-frames="):
			for f in arg.trim_prefix("--cast-frames=").split(","):
				_cast_frames.append(int(f))
		elif arg.begins_with("--dash-frames="):
			for f in arg.trim_prefix("--dash-frames=").split(","):
				_dash_frames.append(int(f))
		elif arg.begins_with("--spawn-frame="):
			_spawn_frame = int(arg.trim_prefix("--spawn-frame="))
		elif arg.begins_with("--spawn-count="):
			_spawn_count = int(arg.trim_prefix("--spawn-count="))
		elif arg.begins_with("--lineup="):
			for n in arg.trim_prefix("--lineup=").split(","):
				_lineup.append(n)
		elif arg.begins_with("--arena-showcase="):
			_arena_showcase = arg.trim_prefix("--arena-showcase=")
		elif arg.begins_with("--arena-wave="):
			_arena_wave = int(arg.trim_prefix("--arena-wave="))
		elif arg.begins_with("--boons="):
			for b in arg.trim_prefix("--boons=").split(","):
				_boons.append(b)
		elif arg.begins_with("--light-kegs="):
			_light_kegs_frame = int(arg.trim_prefix("--light-kegs="))
		elif arg.begins_with("--pause-frame="):
			_pause_frame = int(arg.trim_prefix("--pause-frame="))
		elif arg.begins_with("--champion="): # WP-LOADOUT: a run as that Champion (RunConfig is written before the scene loads)
			RunConfig.champion_id = arg.trim_prefix("--champion=")
		elif arg.begins_with("--relics="):
			var chosen: Array[String] = []
			for r in arg.trim_prefix("--relics=").split(","):
				if r != "":
					chosen.append(r)
			RunConfig.relic_ids = chosen
		elif arg.begins_with("--tower-hp="):
			_tower_hp_fraction = float(arg.trim_prefix("--tower-hp="))
		elif arg.begins_with("--scrap="):
			_scrap = int(arg.trim_prefix("--scrap="))
		elif arg.begins_with("--hold_move="):
			_hold_action = "move_" + arg.trim_prefix("--hold_move=")
		elif arg.begins_with("--event="):
			_event_kind = arg.trim_prefix("--event=")
		elif arg == "--flawless":
			_event_flawless = true
		elif arg == "--armory":
			_event_armory = true
		elif arg.begins_with("--relic="):
			RunConfig.relic_ids.append(arg.trim_prefix("--relic="))
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
	if _skill_id != "":
		RunConfig.battle_skill_id = _skill_id
	var packed: PackedScene = load(scene_path)
	var instance: Node = packed.instantiate()
	_scene = instance
	add_child(instance)
	if _has_player_pos:
		var player: Node2D = instance.get_node_or_null("Main/Player") as Node2D
		if player != null:
			player.global_position = _player_pos
			player.reset_physics_interpolation()
	if _hold_action != "" and InputMap.has_action(_hold_action):
		Input.action_press(_hold_action)

## docs/32: answers the run-start Opening Pick (so every other capture runs unpaused),
## then queues the event named by `--event=` (the event controller opens it next frame).
func _drive_run_events() -> void:
	if not _scene.has_method("get_event_controller"):
		return
	var ui: Node = _scene.get_event_controller()
	var events: Node = _scene.get_run_events()
	if ui == null or events == null:
		return
	while ui.is_showing():
		ui.skip_lockout_for_test()
		ui.confirm_choice_for_test(0)
	if _event_kind != "":
		events.armory_enabled = _event_armory
		events.queue_dev_event(_event_kind, _event_flawless)


## v1.0 dev helpers (WP-COMBAT captures): grants abilities, edits the Tower's
## health and Scrap, spawns a ring of Seekers and presses the dash / skill actions.
func _drive_v1_helpers() -> void:
	if _scene == null:
		return
	if _count == 1:
		_drive_run_events()
	if _count == 2:
		var mgr: Node = get_tree().get_first_node_in_group(&"ability_manager")
		var us: Node = _scene.get_node_or_null("Main/UpgradeSystem")
		for g in _grants:
			var parts: PackedStringArray = g.split(":")
			var levels: int = int(parts[1]) if parts.size() > 1 else 1
			for i in levels:
				if us != null and us.get_definition(parts[0]) != null:
					us.apply_rank(parts[0], 1.0)
				elif mgr != null:
					mgr.grant_ability(parts[0], 1.0)
		var tower: Node = _scene.get_node_or_null("Main/Tower")
		if tower != null and _tower_hp_fraction >= 0.0:
			tower.death_state.current_hp = tower.health.max_health * _tower_hp_fraction
		var ps: Node = _scene.get_node_or_null("Main/PickupSystem")
		if ps != null and _scrap >= 0:
			ps.run_inventory.scrap_current = _scrap
	var arena: Node = _scene.get_node_or_null("Main/ArenaInteractables")
	if arena != null:
		if _count == 3:
			var pl: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
			if _arena_showcase != "" and pl != null:
				arena.dev_spawn_showcase(pl.global_position, _arena_showcase)
			if _arena_wave > 0:
				arena.spawn_for_wave(_arena_wave)
			for b in _boons:
				arena.claim_boon(b)
		if _light_kegs_frame >= 0 and _count == _light_kegs_frame:
			for k in arena.get_kegs():
				k.light("capture")
	if _pause_frame >= 0 and _count == _pause_frame:
		var pause_event := InputEventAction.new()
		pause_event.action = &"pause"
		pause_event.pressed = true
		Input.parse_input_event(pause_event)
	if _cast_frames.has(_count):
		var sk: Node = get_tree().get_first_node_in_group(&"battle_skill")
		if sk != null:
			print("CAST ", sk.get_state(), " -> ", sk.try_cast())
	if _dash_frames.has(_count):
		var pl: Node = get_tree().get_first_node_in_group(&"player")
		if pl != null:
			pl.press_dash_for_test()
	if _spawn_frame >= 0 and _count == _spawn_frame:
		var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
		var entities: Node = _scene.get_node_or_null("Main/Entities")
		var scene: PackedScene = load("res://scenes/entities/tower_seeker.tscn")
		for i in _lineup.size():
			var le: EnemyController = (load("res://scenes/entities/%s.tscn" % _lineup[i]) as PackedScene).instantiate() as EnemyController
			le.driven_externally = true
			le.tower_path = NodePath("")
			(entities if entities != null else _scene).add_child(le)
			le.set_tower_reference(_scene.get_node("Main/Tower"))
			le.global_position = player.global_position + Vector2((float(i) - float(_lineup.size() - 1) * 0.5) * 130.0, 170.0)
			le.set_physics_process(false) # a still lineup, nothing walks into the player
			EntityRegistry.update_position(le, le.global_position)
		for i in _spawn_count:
			var e: EnemyController = scene.instantiate() as EnemyController
			e.driven_externally = true
			e.tower_path = NodePath("")
			(entities if entities != null else _scene).add_child(e)
			e.set_tower_reference(_scene.get_node("Main/Tower"))
			e.global_position = player.global_position + Vector2.from_angle(TAU * float(i) / float(maxi(1, _spawn_count))) * (150.0 + 12.0 * float(i % 5))
			EntityRegistry.update_position(e, e.global_position)


func _process(_delta: float) -> void:
	_count += 1
	_drive_v1_helpers()
	if not _frames.is_empty() and _count >= _frames[0]:
		var f: int = _frames.pop_front()
		var tex: ViewportTexture = get_viewport().get_texture()
		var img: Image = tex.get_image() if tex != null else null
		var path: String = ProjectSettings.globalize_path("res://").path_join("%s_%d.png" % [_out, f])
		# Headless (the CI build check) has no renderer, so there is no image:
		# skip the PNG but still run `--dump-tree` below, which is what that
		# check reads.
		if img != null and not img.is_empty():
			img.save_png(path)
			print("CAPTURED ", path)
		else:
			print("NO IMAGE (headless?) for frame ", f)
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

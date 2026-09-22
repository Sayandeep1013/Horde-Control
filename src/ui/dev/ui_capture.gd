extends Node

## UI capture tool (UI pass, dev-only). Drives the real assembled
## `scenes/prototype.tscn` through each player-facing UI state and saves one
## PNG per state, so a restyle can be compared before and after against the
## scene a human actually launches rather than against isolated mock-ups.
##
## Windowed run only: `--headless` disables all rendering, so there is no
## screenshot path under it (docs/28 > "Known failure modes"). This goes
## through the plain Godot CLI, not an MCP `run_project`, so nothing is
## injected into `project.godot` and no listener is opened.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 \
##       res://src/ui/dev/ui_capture.tscn -- --out=<absolute dir> [--pseudo] ##       [--size=1920x1080]
##
## `--size` makes the window borderless at exactly that client size. Without
## it the desktop clamps a decorated 1920x1080 window to its work area
## (FAILURE_POINTS UP-05: 1875x1055 on the capture machine).
##
## It reaches into a few private members (`_run_inventory`, `_end_run`)
## to stage states that otherwise take minutes of play. That is acceptable
## for a capture tool and for nothing else; no game code may depend on it.

const PROTOTYPE_SCENE: String = "res://scenes/prototype.tscn"

var _out_dir: String = "user://ui_capture"
var _proto: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A capture run is looked at, never listened to; several may run at once.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			if parts.size() == 2:
				var window: Window = get_window()
				window.borderless = true
				window.size = Vector2i(int(parts[0]), int(parts[1]))
				window.position = DisplayServer.screen_get_position(window.current_screen)
		elif arg == "--pseudo":
			TranslationServer.set_pseudolocalization_enabled(true)
			TranslationServer.reload_pseudolocalization()
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


func _run() -> void:
	_proto = (load(PROTOTYPE_SCENE) as PackedScene).instantiate()
	add_child(_proto)
	# The F1 debug overlay opens by default and covers the HUD's top-left
	# field; it is QA chrome, not player-facing UI, so it is hidden here.
	var overlay: Node = _proto.get_node_or_null("DebugOverlay")
	if overlay != null:
		overlay.set("visible", false) # CanvasLayer and CanvasItem both carry `visible`

	await _frames(150)
	await _shot("01_hud_gameplay")

	var draft: DraftController = _proto.get_node("DraftInstance") as DraftController
	draft.force_open_for_test(false)
	# The Draft ignores hover until its real-time input lockout has elapsed,
	# and a fixed frame count is a different wall time at every frame rate:
	# two resolutions once highlighted two different cards. Wait on the clock.
	var opened_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - opened_msec < 700:
		await get_tree().process_frame
	draft.simulate_hover_for_test(1)
	await _frames(20)
	await _shot("02_draft")
	draft.skip_lockout_for_test()
	draft.confirm_choice_for_test(1)
	await _frames(20)

	var flow: Node = _proto.get_node("RunFlowController")
	_press_action(&"pause")
	await _frames(10)
	if not flow.pause_menu.is_active_for_test():
		# A synthetic InputEventAction does not always reach _unhandled_input
		# in a capture run; fall back to the handler the key press calls.
		print("ui_capture: synthetic pause press did not open the menu (pause reasons: %s); calling the handler directly" % str(PauseAuthority.get_active_reasons()))
		flow._on_pause_action_pressed()
	await _frames(30)
	print("ui_capture: pause menu active=%s" % flow.pause_menu.is_active_for_test())
	await _shot("03_pause_menu")
	flow.pause_menu.settings_requested.emit()
	await _frames(30)
	await _shot("04_settings_menu")
	flow.settings_menu.closed.emit()
	await _frames(5)
	flow.pause_menu.resume_requested.emit()
	await _frames(20)

	await _stage_console()
	await _shot("05_console")

	await _stage_threat_feedback()

	flow._end_run(flow.EndCause.TOWER_DESTROYED)
	await _frames(40)
	await _shot("06_run_end")

	get_tree().quit()


## Parks the player just outside the Tower's footprint, standing still, with
## Scrap to spend, and waits out the Console's open dwell.
func _stage_console() -> void:
	var console: Console = _proto.get_node("Console") as Console
	var tower: Node2D = _proto.get_node("Main/Tower") as Node2D
	var player: Player = _proto.get_node("Main/Player") as Player
	# phases/UI_PASS/HANDOFF.md, H-01: scenes/prototype.tscn authors the
	# Console's four NodePaths relative to the scene root, but the Console
	# resolves them relative to itself, so all four come back null and the
	# Console can never open in the assembled scene. Until that file is
	# fixed by its owner, the references are injected here so the Console
	# can be photographed at all. Said loudly, so nobody reads a Console
	# screenshot as proof that it opens in the real game.
	if console._tower == null:
		print("ui_capture: WARNING Console had no Tower reference in the assembled scene (HANDOFF H-01); injecting references for the screenshot only")
		console.set_tower_for_test(tower as Tower)
		console.set_player_for_test(player)
		console.set_player_weapon_for_test(player.get_node_or_null("AutoWeapon") as AutoWeapon)
		console.set_upgrade_system_for_test(_proto.get_node_or_null("Main/UpgradeSystem") as UpgradeSystem)
		console.set_camera_for_test(_proto.get_node_or_null("Main/Player/GameCamera") as GameCamera)
	if console._run_inventory != null:
		console._run_inventory.scrap_current = 150
	for i in 90:
		player.global_position = tower.global_position + Vector2(130, 40)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
		if console.is_open() and i > 45:
			break
	await _frames(15)
	print("ui_capture: console open=%s paused=%s requires_reentry=%s scrap=%d pause_reasons=%s" % [
		console.is_open(), console.get_paused_for_test(), console.get_requires_reentry_for_test(),
		console.get_scrap_current_for_test(), str(PauseAuthority.get_active_reasons())])
	print("ui_capture: console inside=%s velocity=%s affordable=%s driven_externally=%s dead=%s dist=%.0f" % [
		console._interaction_radius.is_player_inside() if console._interaction_radius != null else "no-radius",
		player.velocity, console._has_any_affordable_entry(), console.driven_externally,
		console._player_is_dead, player.global_position.distance_to(tower.global_position)])


## Threat feedback is drawn only while the Tower is taking damage, so it is
## staged by emitting the Tower Hurtbox's own `damage_received` - the signal
## both ThreatFeedback and TowerHealth listen to - with a stand-in attacker
## east of the Tower. Three frames: the vignette with the Tower on screen,
## the off-screen indicator (circle + hit arc), and the same indicator once
## Tower health is under ThreatFeedback.LOW_HEALTH_FRACTION (diamond).
func _stage_threat_feedback() -> void:
	var overlay: ThreatFeedback = _proto.get_node("ThreatFeedbackLayer/Overlay") as ThreatFeedback
	var tower: Tower = _proto.get_node("Main/Tower") as Tower
	var player: Player = _proto.get_node("Main/Player") as Player
	var hurtbox: Node = tower.find_child("Hurtbox", true, false)
	var health: TowerHealth = tower.find_child("TowerHealth", true, false) as TowerHealth
	if overlay == null or hurtbox == null or health == null:
		print("ui_capture: WARNING threat feedback could not be staged (overlay=%s hurtbox=%s health=%s); no frame taken" % [overlay, hurtbox, health])
		return
	var attacker := Node2D.new()
	_proto.add_child(attacker)
	attacker.global_position = tower.global_position + Vector2(400, 0)
	var max_health: float = health.get_current_health()

	# Out of the Interaction Radius so the Console closes, Tower still on screen.
	for i in 90:
		player.global_position = tower.global_position + Vector2(-420, 260)
		player.velocity = Vector2.ZERO
		await get_tree().physics_frame
	hurtbox.emit_signal(&"damage_received", max_health * 0.1, attacker, attacker)
	await _frames(6)
	print("ui_capture: threat on-screen=%s intensity=%.2f segment=%d" % [overlay.is_tower_on_screen(), overlay.get_display_intensity(), overlay.get_active_segment_index()])
	await _shot("07_threat_vignette")

	var camera: GameCamera = _proto.get_node("Main/Player/GameCamera") as GameCamera
	for i in 40:
		player.global_position = tower.global_position + Vector2(-1500, -700)
		player.velocity = Vector2.ZERO
		camera.snap_to(player.global_position) # skip the follow smoothing
		await get_tree().physics_frame
	hurtbox.emit_signal(&"damage_received", max_health * 0.1, attacker, attacker)
	await _frames(6)
	print("ui_capture: threat on-screen=%s indicator=%s shape=%s arc=%s" % [overlay.is_tower_on_screen(), overlay.is_showing_offscreen_indicator(), overlay.get_indicator_shape(), overlay.has_recent_hit_arc()])
	await _shot("08_threat_offscreen")

	# The shield absorbs part of every hit, so step down until health is
	# under the low-health line rather than computing one exact amount.
	for i in 20:
		if health.get_current_health() < max_health * ThreatFeedback.LOW_HEALTH_FRACTION * 0.9:
			break
		hurtbox.emit_signal(&"damage_received", max_health * 0.1, attacker, attacker)
		await _frames(2)
	await _frames(6)
	print("ui_capture: threat low-health=%s shape=%s tower_health=%.0f/%.0f" % [overlay.is_indicator_low_health(), overlay.get_indicator_shape(), health.get_current_health(), max_health])
	await _shot("09_threat_low_health")
	attacker.queue_free()


func _press_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event.call_deferred(release)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(shot_name + ".png")
	var err: Error = image.save_png(path)
	print("ui_capture: %s %dx%d -> %s (err %d)" % [shot_name, image.get_width(), image.get_height(), path, err])

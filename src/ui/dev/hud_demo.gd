extends Node

## HUD / pause / settings capture tool (v1.0 WP-UI, dev-only). Runs the real
## `scenes/prototype.tscn`, installs the stand-ins from `hud_fakes.gd` for the
## systems other packages build, stages states and saves one PNG per step.
## Windowed only (a headless run has no renderer). Settings are redirected to a
## throwaway user:// file, so the real settings.cfg is never touched.
##
##   Godot_v4.7.1-stable_win64_console.exe --path . --audio-driver Dummy \
##     res://src/ui/dev/hud_demo.tscn -- --out=sandbox/captures/ui/hud --size=1920x1080 \
##     --meta-profile-dir=<absolute sandbox dir> --no-focus-pause \
##     --steps=idle,cooldown,boss,siege,repair,markers,elite,pause,howto,settings0,settings1,settings2,settings3,settings4 \
##     [--hud-scale=150] [--touch-ui]
##
## `--out` is a path relative to the project, without extension; each step
## saves `<out>_<step>.png`.

var _out: String = "sandbox/captures/ui/hud"
var _steps: PackedStringArray = PackedStringArray(["idle"])
var _proto: Node = null
var _fakes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	GameSettings.set_path_for_test("user://__hud_demo_%d/settings.cfg" % Time.get_ticks_usec())
	var size := Vector2i.ZERO
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--steps="):
			_steps = arg.trim_prefix("--steps=").split(",")
		elif arg.begins_with("--hud-scale="):
			GameSettings.set_hud_scale_pct(int(arg.trim_prefix("--hud-scale=")))
		elif arg.begins_with("--size="):
			var parts: PackedStringArray = arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	if size != Vector2i.ZERO:
		var window: Window = get_window()
		window.borderless = true
		window.size = size
		window.position = DisplayServer.screen_get_position(window.current_screen)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(_out.get_base_dir()))
	_run.call_deferred()


func _run() -> void:
	_proto = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
	add_child(_proto)
	var overlay: Node = _proto.get_node_or_null("DebugOverlay")
	if overlay != null:
		overlay.set("visible", false)
	await _frames(90)
	_fakes = HudFakes.install(_proto)
	CombatStats.add_run_counter("kills", 312)
	CombatStats.add_run_counter("elite_kills", 4)
	CombatStats.add_run_counter("damage_taken", 188)
	CombatStats.add_run_counter("scrap_repaired", 240)
	var player: Player = _proto.get_node("Main/Player") as Player
	player.apply_damage(player.death_state.max_hp * 0.22, "demo")
	await _frames(40)
	for step: String in _steps:
		await _do_step(step.strip_edges())
	get_tree().quit()


func _do_step(step: String) -> void:
	var skill: HudFakes.FakeBattleSkill = _fakes["skill"]
	var dash: HudFakes.FakePlayer = _fakes["player"]
	var director: HudFakes.FakeWaveDirector = _fakes["director"]
	match step:
		"idle":
			pass
		"cooldown":
			skill.cooldown_remaining = 9.0
			skill.is_ready = false
			dash.charges = 1
			dash.cooldown_remaining = 1.4
		"boss":
			director.wave_number = 8
			director.wave_type = "boss"
			director.boss = true
			EventBus.emit_wave_started(8, 15, "boss", true)
			EventBus.emit_boss_spawned(null, "warchief", "Goblin Warchief", 2600.0)
			EventBus.emit_boss_health_changed("warchief", 1500.0, 2600.0)
		"siege":
			director.wave_number = 7
			director.wave_type = "siege"
			director.boss = false
			EventBus.emit_wave_started(7, 15, "siege", false)
			EventBus.emit_siege_warning(12.0)
		"repair":
			(_fakes["repair"] as HudFakes.FakeTowerRepair).repairing = true
		"markers":
			var camera: GameCamera = _proto.get_node("Main/GameCamera") as GameCamera
			var centre: Vector2 = camera.global_position
			EventBus.emit_spawn_warning(centre + Vector2(1500, -200), ContractEnums.TargetIntent.TowerSeeker, 6.0)
			EventBus.emit_spawn_warning(centre + Vector2(-1500, 100), ContractEnums.TargetIntent.PlayerHunter, 6.0)
			EventBus.emit_spawn_warning(centre + Vector2(100, -1200), ContractEnums.TargetIntent.Opportunist, 6.0)
			EventBus.emit_spawn_warning(centre + Vector2(900, 1100), ContractEnums.TargetIntent.TowerSeeker, 6.0)
		"elite":
			EventBus.emit_elite_spawned(null, "swift")
		"pause":
			(_proto.get_node("RunFlowController") as RunFlowController)._on_pause_action_pressed()
		"howto":
			(_proto.get_node("RunFlowController") as RunFlowController).pause_menu._on_option_confirmed(PauseMenu.OPTION_HOW_TO_PLAY)
		"settings0", "settings1", "settings2", "settings3", "settings4":
			var flow: RunFlowController = _proto.get_node("RunFlowController") as RunFlowController
			if not flow.settings_menu.is_active_for_test():
				flow.pause_menu.settings_requested.emit()
				await _frames(10)
			flow.settings_menu.show_tab_for_debug(int(step.trim_prefix("settings")))
	await _frames(28)
	await _shot(step)


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _shot(step: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://").path_join("%s_%s.png" % [_out, step])
	var err: Error = image.save_png(path)
	print("hud_demo: %s %dx%d -> %s (err %d)" % [step, image.get_width(), image.get_height(), path, err])

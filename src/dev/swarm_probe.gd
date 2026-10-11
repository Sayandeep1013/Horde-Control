extends SceneTree
## PT-SWARM dev probe (not shipped). Drives the assembled prototype scene and
## prints machine-readable lines. Two probes:
##
##   --probe=perf  Keeps N enemies alive around the player (spawned through the
##                 Wave Director's own summon path, so pools, caps and scaling
##                 apply), grants abilities, and reports the wall-clock cost per
##                 frame (median / p95 / max, ms) over the measured window.
##                 Run with --fixed-fps 60 so one frame = one physics tick.
##   --probe=boss  Opens the wave given by --start-wave and logs, every 2 s, what
##                 the boss is doing: projectiles and bombs launched, damage dealt
##                 to the player and the Tower, distance to the Tower, phase.
##
## USAGE:
##   Godot --headless --path <project> --audio-driver Dummy --fixed-fps 60 \
##     -s res://src/dev/swarm_probe.gd -- --probe=perf --alive=350 --start-wave=10 \
##     --frames=600 --warmup=240 --grant=whirling_axes:4,ballista:3 \
##     --meta-profile-dir=<abs sandbox dir>
## Output: PROBE_PERF alive_target=.. alive_avg=.. median_ms=.. p95_ms=.. max_ms=..
##         PROBE_BOSS t=.. id=.. phase=.. bullets=.. bombs=.. pdmg=.. tdmg=.. dist=..

const PROFILE_FLAG: String = "--meta-profile-dir="

var probe: String = "perf"
var alive_target: int = 350
var measure_frames: int = 600
var warmup_frames: int = 240
var max_seconds: float = 120.0
var grants: Array[String] = []
var root_scene: Node = null
var frames: int = 0
var last_usec: int = 0
var samples: PackedFloat64Array = PackedFloat64Array()
var alive_sum: int = 0
var proc_sum: float = 0.0
var phys_sum: float = 0.0
var pairs_sum: float = 0.0
var toggles: Array[String] = []
var spawn_rng := RandomNumberGenerator.new()
var bombs_seen: int = 0
var bullets_seen: int = 0
var next_boss_log: float = 2.0
var boss_seen: bool = false
var granted: bool = false


func _initialize() -> void:
	var has_profile: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe="): probe = a.trim_prefix("--probe=")
		elif a.begins_with("--alive="): alive_target = int(a.trim_prefix("--alive="))
		elif a.begins_with("--frames="): measure_frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--warmup="): warmup_frames = int(a.trim_prefix("--warmup="))
		elif a.begins_with("--seconds="): max_seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--grant="):
			for g in a.trim_prefix("--grant=").split(","):
				if g != "":
					grants.append(g)
		elif a.begins_with("--toggle="):
			for t in a.trim_prefix("--toggle=").split(","):
				toggles.append(t)
		elif a.begins_with(PROFILE_FLAG): has_profile = true
	if not has_profile:
		push_error("swarm_probe: refusing to run without --meta-profile-dir=<sandbox dir>")
		quit(2)
		return
	spawn_rng.seed = 7
	node_added.connect(_on_node_added)
	print("PROBE_START probe=%s alive=%d frames=%d" % [probe, alive_target, measure_frames])


func _on_node_added(n: Node) -> void:
	var scr: Script = n.get_script()
	if scr == null:
		return
	var gname: StringName = scr.get_global_name()
	if gname == &"EnemyBomb":
		bombs_seen += 1
	elif gname == &"EnemyBullet" and n.is_inside_tree():
		bullets_seen += 1


func _n(p: String) -> Node:
	return root_scene.get_node_or_null(p) if root_scene != null and root_scene.is_inside_tree() else null


func _answer_menus() -> void:
	var draft: Node = _n("DraftInstance")
	if draft != null and draft.is_draft_showing_for_test():
		draft.skip_lockout_for_test()
		draft.confirm_choice_for_test(0)
	var ev: Node = _n("EventDraftInstance")
	if ev != null and ev.is_showing():
		ev.skip_lockout_for_test()
		ev.confirm_choice_for_test(0)


func _grant() -> void:
	granted = true
	var mgr: Node = root_scene.get_tree().get_first_node_in_group(&"ability_manager")
	var us: Node = _n("Main/UpgradeSystem")
	for g in grants:
		var parts: PackedStringArray = g.split(":")
		var levels: int = int(parts[1]) if parts.size() > 1 else 1
		for i in levels:
			if us != null and us.get_definition(parts[0]) != null:
				us.apply_rank(parts[0], 1.0)
			elif mgr != null:
				mgr.grant_ability(parts[0], 1.0)


func _process(_delta: float) -> bool:
	frames += 1
	var now_usec: int = Time.get_ticks_usec()
	var dt_ms: float = float(now_usec - last_usec) / 1000.0 if last_usec > 0 else 0.0
	last_usec = now_usec
	if root_scene == null:
		# Autoloads are only in the tree once the main loop runs, so the scene
		# (and RunConfig) is set up on the first frame, not in _initialize().
		(load("res://src/run/run_config.gd") as Script).set("run_events_forced", true)
		root_scene = (load("res://scenes/prototype.tscn") as PackedScene).instantiate()
		root_scene.set("run_seed", 11)
		root.add_child(root_scene)
		return false
	if not root_scene.is_inside_tree():
		return false
	_answer_menus()
	var player: Node = _n("Main/Player")
	var tower: Node = _n("Main/Tower")
	var wd: Node = _n("Main/WaveDirector")
	if player == null or tower == null or wd == null:
		return false
	if frames == 3 and not granted:
		_grant()
	player.death_state.current_hp = player.death_state.max_hp
	tower.health.heal(100000.0)
	var reg: Node = root.get_node("EntityRegistry")
	var now: float = root.get_node("SimClock").now
	if probe == "perf":
		if not toggles.is_empty() and frames % 30 == 0:
			_apply_toggles(reg)
		var alive: int = reg.get_live_enemy_count()
		var deficit: int = alive_target - alive
		if deficit > 0:
			var batch: int = mini(deficit, 40)
			var ids: Array[String] = ["tower_seeker", "player_hunter", "player_hunter", "opportunist"]
			for i in int(ceil(batch / 4.0)):
				var near: Vector2 = player.global_position + Vector2.from_angle(spawn_rng.randf() * TAU) * spawn_rng.randf_range(450.0, 800.0)
				wd.spawn_summons(ids[i % ids.size()], 4, near)
		if frames > warmup_frames:
			samples.append(dt_ms)
			alive_sum += alive
			proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			pairs_sum += Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
			if samples.size() >= measure_frames:
				_report_perf()
				return true
	else:
		var boss: Node = wd.get_boss_instance_for_test()
		if boss != null and is_instance_valid(boss):
			boss_seen = true
		if now >= next_boss_log:
			next_boss_log = now + 2.0
			var cs: Node = root.get_node("CombatStats")
			var line: String = "PROBE_BOSS t=%.1f wave=%d bullets=%d bombs=%d pdmg=%.0f tdmg=%.0f alive=%d" % [now, wd.get_current_wave_number(), bullets_seen, bombs_seen, cs.get_run_counter("damage_taken"), cs.get_run_counter("tower_damage_taken"), reg.get_live_enemy_count()]
			if boss != null and is_instance_valid(boss):
				var b: Node = boss.get("behavior")
				line += " boss=%s phase=%s state=%s hp=%.0f dist=%.0f" % [boss.get("boss_id"), b.get("phase"), b.get("state"), boss.death_state.current_hp, boss.global_position.distance_to(tower.global_position)]
			print(line)
		if now > max_seconds or (boss_seen and (wd.get_boss_instance_for_test() == null or not is_instance_valid(wd.get_boss_instance_for_test()))):
			print("PROBE_DONE t=%.1f" % now)
			quit(0)
			return true
	if frames > 40000:
		quit(1)
		return true
	return false


func _report_perf() -> void:
	var sorted: Array = Array(samples)
	sorted.sort()
	var n: int = sorted.size()
	var median: float = sorted[n / 2]
	var p95: float = sorted[mini(n - 1, int(n * 0.95))]
	var mx: float = sorted[n - 1]
	var mean: float = 0.0
	for s in sorted:
		mean += s
	mean /= float(n)
	print("PROBE_PERF alive_target=%d alive_avg=%.0f frames=%d median_ms=%.2f mean_ms=%.2f p95_ms=%.2f max_ms=%.2f fps_median=%.0f process_ms=%.2f physics_ms=%.2f pairs=%.0f toggles=%s" % [alive_target, float(alive_sum) / float(n), n, median, mean, p95, mx, 1000.0 / maxf(median, 0.001), proc_sum / n, phys_sum / n, pairs_sum / n, ",".join(toggles)])
	quit(0)


## Diagnostic switches (perf probe only): turn a per-enemy cost off to see its share.
func _apply_toggles(reg: Node) -> void:
	for e in reg.get_entities_with_tag(&"enemy"):
		if toggles.has("no_anim"):
			var v: Node = e.get_node_or_null("Visuals")
			if v != null:
				v.set_process(false)
		if toggles.has("no_bar"):
			var b: Node = e.get_node_or_null("HealthBar")
			if b != null:
				b.set_process(false)
		if toggles.has("no_tele"):
			var t: Node = e.get_node_or_null("TelegraphVisual")
			if t != null:
				t.set_process(false)
		if toggles.has("no_enemy_collide"):
			(e as CollisionObject2D).set_collision_mask_value(2, false)
		if toggles.has("hide"):
			(e as CanvasItem).visible = false

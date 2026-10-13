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
## --shots=F,F,... --out=sandbox/captures/x (relative to the project): windowed
## screenshots at those frames (any probe); the run quits after the last one.
var shot_frames: Array[int] = []
var shot_out: String = "sandbox/captures/probe"
var player_offset: Vector2 = Vector2.INF
## --near-boss=PX (watch): once the boss is within the island, keep the player
## PX from it on the Tower side, so captures frame the fight.
var near_boss: float = -1.0
## --boss-damage=F (watch): when the boss first appears, deal F x its max HP so a
## capture can show a later phase.
var boss_damage: float = 0.0
var boss_damaged: bool = false
var _t_phys: int = 0
var _t_proc: int = 0
var _phys_sum2: int = 0
var _idle_sum: int = 0
var frames_total: int = 0
var draw_calls_sum: float = 0.0
var draw_objects_sum: float = 0.0
var draw_prims_sum: float = 0.0
var brain_hash_us: int = 0
var brain_loop_us: int = 0
var brain_plans: int = 0
var brain_plan_us: int = 0
var brain_sync_us: int = 0
var brain_frames: int = 0
var spawn_rng := RandomNumberGenerator.new()
var bombs_seen: int = 0
var bullets_seen: int = 0
var next_boss_log: float = 2.0
var boss_seen: bool = false
var granted: bool = false
var _dumped: bool = false
var spawn_us: int = 0
var spawn_count: int = 0
var spawn_max_us: int = 0
var _scan_nodes: Array[Node] = []
var _scan_idx: int = -1
var _scan_phase: int = 0
var _scan_base: float = 0.0
var _scan_started: bool = false
var _last_kills: float = 0.0
var _last_nodes: int = 0
var _pscan_nodes: Array[Node] = []
var _pscan_idx: int = -1
var _pscan_wait: int = 0
var _pscan_acc: float = 0.0
var _pscan_n: int = 0
var _pscan_base: float = 0.0
var _pscan_started: bool = false
var render_cpu_sum: float = 0.0
var render_gpu_sum: float = 0.0
var setup_cpu_sum: float = 0.0


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
		elif a.begins_with("--shots="):
			for f in a.trim_prefix("--shots=").split(","):
				shot_frames.append(int(f))
		elif a.begins_with("--out="): shot_out = a.trim_prefix("--out=")
		elif a.begins_with("--near-boss="): near_boss = float(a.trim_prefix("--near-boss="))
		elif a.begins_with("--boss-damage="): boss_damage = float(a.trim_prefix("--boss-damage="))
		elif a.begins_with("--player-offset="):
			var xy: PackedStringArray = a.trim_prefix("--player-offset=").split(",")
			player_offset = Vector2(float(xy[0]), float(xy[1]))
		elif a == "--mobile":
			(load("res://src/core/entity_caps.gd") as Script).set("mobile_override", 1) # the phone caps and LOD
		elif a.begins_with(PROFILE_FLAG): has_profile = true
	if not has_profile:
		push_error("swarm_probe: refusing to run without --meta-profile-dir=<sandbox dir>")
		quit(2)
		return
	spawn_rng.seed = 7
	# Windowed runs measure render cost too: uncapped, no vsync.
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.size = Vector2i(1920, 1080)
	node_added.connect(_on_node_added)
	physics_frame.connect(func() -> void:
		var t: int = Time.get_ticks_usec()
		if _t_proc > 0:
			_idle_sum += t - _t_proc
		_t_phys = t)
	process_frame.connect(func() -> void:
		var t: int = Time.get_ticks_usec()
		if _t_phys > 0:
			_phys_sum2 += t - _t_phys
		_t_proc = t)
	print("PROBE_START probe=%s alive=%d frames=%d" % [probe, alive_target, measure_frames])


func _on_node_added(n: Node) -> void:
	var scr: Script = n.get_script()
	if scr == null:
		return
	var gname: StringName = scr.get_global_name()
	if gname == &"EnemyBomb":
		bombs_seen += 1


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
	if player_offset != Vector2.INF and frames == 4:
		player.global_position = tower.global_position + player_offset
		player.reset_physics_interpolation()
	if not shot_frames.is_empty() and frames >= shot_frames[0]:
		shot_frames.pop_front()
		var img: Image = root.get_texture().get_image()
		if img != null and not img.is_empty():
			var path: String = ProjectSettings.globalize_path("res://").path_join("%s_%d.png" % [shot_out, frames])
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			img.save_png(path)
			print("CAPTURED ", path)
		if shot_frames.is_empty() and probe == "watch":
			quit(0)
			return true
	var reg: Node = root.get_node("EntityRegistry")
	var now: float = root.get_node("SimClock").now
	if probe == "watch":
		var nb: Variant = wd.get("_boss_instance")
		if boss_damage > 0.0 and not boss_damaged and is_instance_valid(nb):
			boss_damaged = true
			nb.death_state.apply_damage(nb.death_state.max_hp * boss_damage, "probe")
		if near_boss > 0.0 and is_instance_valid(nb):
			var bpos: Vector2 = (nb as Node2D).global_position
			if bpos.distance_to(tower.global_position) < 520.0 and player.global_position.distance_to(bpos) > near_boss * 1.6:
				player.global_position = bpos + (tower.global_position - bpos).normalized() * near_boss
				player.reset_physics_interpolation()
		if now >= next_boss_log:
			next_boss_log = now + 5.0
			var cs2: Node = root.get_node("CombatStats")
			var near_t: int = 0
			var near_p: int = 0
			var attacking: int = 0
			for en in reg.get_entities_with_tag(&"enemy"):
				var dt: float = (en as Node2D).global_position.distance_to(tower.global_position)
				if dt < 175.0:
					near_t += 1
				if (en as Node2D).global_position.distance_to(player.global_position) < 80.0:
					near_p += 1
				if en.has_method("is_windup_active") and en.is_windup_active():
					attacking += 1
			print("PROBE_WATCH t=%.1f wave=%d alive=%d kills=%.0f pdmg=%.0f tdmg=%.0f near_tower=%d near_player=%d windups=%d" % [now, wd.get_current_wave_number(), reg.get_live_enemy_count(), cs2.get_run_counter("kills"), cs2.get_run_counter("damage_taken"), cs2.get_run_counter("tower_damage_taken"), near_t, near_p, attacking])
		if frames > 120:
			samples.append(dt_ms)
			var kills_now: float = root.get_node("CombatStats").get_run_counter("kills")
			var nodes_now: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if dt_ms > 35.0:
				print("PROBE_SPIKE frame=%d t=%.2f dt_ms=%.1f alive=%d dkills=%d dnodes=%d" % [frames, now, dt_ms, reg.get_live_enemy_count(), int(kills_now - _last_kills), nodes_now - _last_nodes])
			_last_kills = kills_now
			_last_nodes = nodes_now
		if now > max_seconds:
			print("PROBE_WATCH_DMG ", str(root.get_node("CombatStats").get_damage_by_source()))
			if samples.size() > 10:
				var sorted_w: Array = Array(samples)
				sorted_w.sort()
				var nw: int = sorted_w.size()
				var over20: int = 0
				var over33: int = 0
				for sv in sorted_w:
					if sv > 20.0:
						over20 += 1
					if sv > 33.4:
						over33 += 1
				print("PROBE_FRAMES frames=%d median_ms=%.2f p95_ms=%.2f p99_ms=%.2f max_ms=%.2f over20=%d over33=%d" % [nw, sorted_w[nw / 2], sorted_w[int(nw * 0.95)], sorted_w[int(nw * 0.99)], sorted_w[nw - 1], over20, over33])
			quit(0)
			return true
	elif probe == "perf":
		if not toggles.is_empty() and frames % 10 == 0 and _scan_idx < 0:
			_apply_toggles(reg)
		if _pscan_started:
			if _pscan_step(dt_ms):
				quit(0)
				return true
		if _scan_idx >= 0:
			_scan_step()
			if _scan_idx >= _scan_nodes.size() + 1:
				quit(0)
				return true
		var alive: int = reg.get_live_enemy_count()
		var deficit: int = alive_target - alive
		if deficit > 0:
			var batch: int = mini(deficit, 40)
			var ids: Array[String] = ["tower_seeker", "player_hunter", "player_hunter", "opportunist"]
			for i in int(ceil(batch / 4.0)):
				var near: Vector2 = player.global_position + Vector2.from_angle(spawn_rng.randf() * TAU) * spawn_rng.randf_range(450.0, 800.0)
				var ts0: int = Time.get_ticks_usec()
				var made: int = wd.spawn_summons(ids[i % ids.size()], 4, near)
				if frames > warmup_frames:
					var took: int = Time.get_ticks_usec() - ts0
					spawn_us += took
					spawn_count += made
					spawn_max_us = maxi(spawn_max_us, took)
		if frames > warmup_frames:
			frames_total += 1
			samples.append(dt_ms)
			alive_sum += alive
			proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draw_calls_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var vp_rid: RID = root.get_viewport_rid()
			render_cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
			render_gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			setup_cpu_sum += RenderingServer.get_frame_setup_time_cpu()
			draw_objects_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
			draw_prims_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			pairs_sum += Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
			var brain: Node = _n("Main/SwarmBrain")
			if brain != null and brain.get("profile_enabled"):
				brain_hash_us += int(brain.get("last_hash_usec"))
				brain_loop_us += int(brain.get("last_loop_usec"))
				brain_plans += int(brain.get("last_plan_count"))
				brain_plan_us += int(brain.get("last_plan_usec"))
				brain_sync_us += int(brain.get("last_sync_usec"))
				brain_frames += 1
			if samples.size() == 1:
				RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
				var rnd: Node = _n("Main/Entities/SwarmRenderer")
				if rnd != null:
					rnd.set("profile_enabled", true)
				if brain != null:
					brain.set("profile_enabled", true)
				_phys_sum2 = 0
				_idle_sum = 0
				var sls: Script = load("res://src/core/sim_loop.gd")
				sls.set("profile_enabled", true)
				sls.set("profile_step_usec", PackedInt64Array())
			if samples.size() >= measure_frames:
				print("PROBE_SPLIT physics_phase_ms=%.2f idle_phase_ms=%.2f" % [_phys_sum2 / 1000.0 / measure_frames, _idle_sum / 1000.0 / measure_frames])
				var parts: PackedStringArray = PackedStringArray()
				var total_us: int = 0
				var usec: PackedInt64Array = (load("res://src/core/sim_loop.gd") as Script).get("profile_step_usec")
				for i in usec.size():
					total_us += usec[i]
					parts.append("s%d=%.2f" % [i + 1, usec[i] / 1000.0 / measure_frames])
				var ffn: Node = _n("Main/Environment/ArenaInstance/FlowField")
				if ffn != null:
					print("PROBE_FLOW last_player_ms=%.2f recomputes=%s tower_ms=%.2f" % [float(ffn.get("last_player_usec")) / 1000.0, ffn.get("player_recomputes"), float(ffn.get("last_tower_usec")) / 1000.0])
				var asm: Script = load("res://src/enemy/attack_slot_manager.gd")
				print("PROBE_DRAW draw_calls=%.0f objects=%.0f primitives=%.0f (frame average) render_cpu_ms=%.2f render_gpu_ms=%.2f setup_cpu_ms=%.2f" % [draw_calls_sum / measure_frames, draw_objects_sum / measure_frames, draw_prims_sum / measure_frames, render_cpu_sum / measure_frames, render_gpu_sum / measure_frames, setup_cpu_sum / measure_frames])
				var rr: Node = _n("Main/Entities/SwarmRenderer")
				if rr != null:
					print("PROBE_RENDERER process_ms=%.2f fill_ms=%.2f overlay_draw_ms=%.2f (per rendered frame, %d frames)" % [float(rr.get("prof_process_usec")) / 1000.0 / measure_frames, float(rr.get("prof_fill_usec")) / 1000.0 / measure_frames, float(rr.get("prof_overlay_usec")) / 1000.0 / measure_frames, measure_frames])
				if brain_frames > 0:
					print("PROBE_BRAIN hash_ms=%.2f loop_total_ms=%.2f plans_per_tick=%.1f plan_ms=%.2f node_sync_ms=%.2f" % [brain_hash_us / 1000.0 / brain_frames, brain_loop_us / 1000.0 / brain_frames, float(brain_plans) / brain_frames, brain_plan_us / 1000.0 / brain_frames, brain_sync_us / 1000.0 / brain_frames])
				var sp_node: Node = _n("Main/EntitySpawner")
				print("PROBE_SPAWN spawns=%d us_per_spawn=%.0f max_call_us=%d reused=%s created=%s" % [spawn_count, float(spawn_us) / maxf(spawn_count, 1), spawn_max_us, str(sp_node.get("enemies_reused")) if sp_node != null else "n/a", str(sp_node.get("enemies_created")) if sp_node != null else "n/a"])
				print("PROBE_STEPS simloop_ms=%.2f %s" % [total_us / 1000.0 / measure_frames, " ".join(parts)])
				_report_perf()
				return true
	else:
		var bv: Variant = wd.get("_boss_instance")
		var boss: Node = bv if is_instance_valid(bv) else null
		if boss != null:
			boss_seen = true
		var field: Node = root_scene.get_tree().get_first_node_in_group(&"enemy_bullet_field")
		if field != null:
			bullets_seen = int(field.get("fired_total"))
		if now >= next_boss_log:
			next_boss_log = now + 2.0
			var cs: Node = root.get_node("CombatStats")
			var line: String = "PROBE_BOSS t=%.1f wave=%d bullets=%d bombs=%d pdmg=%.0f tdmg=%.0f alive=%d" % [now, wd.get_current_wave_number(), bullets_seen, bombs_seen, cs.get_run_counter("damage_taken"), cs.get_run_counter("tower_damage_taken"), reg.get_live_enemy_count()]
			if boss != null:
				var b: Node = boss.get("behavior")
				line += " boss=%s phase=%s state=%s hp=%.0f/%.0f staggers=%s dist=%.0f pos=%s vel=%.0f" % [boss.get("boss_id"), b.get("phase"), b.get("state"), boss.death_state.current_hp, boss.death_state.max_hp, b.get("staggers_total"), boss.global_position.distance_to(tower.global_position), boss.global_position.round(), (boss as CharacterBody2D).velocity.length()]
				if b.get("patterns_used") != null:
					line += " patterns=%s" % str(b.get("patterns_used"))
			if field != null:
				line += " bullet_hits_p=%s bullet_hits_t=%s blocked=%s live_bullets=%s" % [field.get("hits_player"), field.get("hits_tower"), field.get("blocked_total"), field.call("get_count")]
			print(line)
		if now > max_seconds or (boss_seen and boss == null):
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
	for t in toggles:
		if t == "phys_off":
			PhysicsServer2D.set_active(false)
		if t.begins_with("group_off:"):
			for n in root_scene.get_tree().get_nodes_in_group(StringName(t.trim_prefix("group_off:"))):
				n.process_mode = Node.PROCESS_MODE_DISABLED
		if t == "pickups_off":
			for n in root_scene.get_tree().get_nodes_in_group(&"pickup"):
				n.process_mode = Node.PROCESS_MODE_DISABLED
	for t in toggles:
		if t.begins_with("hide:"):
			var hn: Node = root_scene.get_node_or_null(t.trim_prefix("hide:"))
			if hn != null and ("visible" in hn):
				hn.set("visible", false)
		if t.begins_with("hidegroup:"):
			for hn2 in root_scene.get_tree().get_nodes_in_group(StringName(t.trim_prefix("hidegroup:"))):
				if "visible" in hn2:
					hn2.set("visible", false)
		if t == "dump_tree" and not _dumped and frames > warmup_frames:
			_dumped = true
			_dump(root_scene, 0, 4)
		if t.begins_with("scan:") and not _scan_started and frames > warmup_frames:
			_scan_started = true
			var sp: String = t.trim_prefix("scan:")
			var depth: int = int(sp.get_slice("@", 1)) if "@" in sp else 1
			var sn: Node = root_scene.get_node_or_null(sp.get_slice("@", 0)) if sp.get_slice("@", 0) != "" else root_scene
			if sn != null:
				_scan_collect(sn, depth)
			_scan_idx = 0
		if t.begins_with("procscan:") and not _pscan_started and frames > warmup_frames:
			_pscan_started = true
			var pp: String = t.trim_prefix("procscan:")
			var pn: Node = root_scene.get_node_or_null(pp) if pp != "" else root_scene
			if pn != null:
				for c in pn.get_children():
					_pscan_nodes.append(c)
			_pscan_idx = -1
			_pscan_wait = 20
			_pscan_acc = 0.0
			_pscan_n = 0
		if t.begins_with("dump:") and not _dumped and frames > warmup_frames:
			_dumped = true
			var dn: Node = root_scene.get_node_or_null(t.trim_prefix("dump:").get_slice("@", 0)) if t.get_slice("@", 0) != "dump:" else root_scene
			if dn != null:
				_dump(dn, 0, int(t.get_slice("@", 1)) if "@" in t else 3)
		if t.begins_with("off:"):
			var n: Node = root_scene.get_node_or_null(t.trim_prefix("off:"))
			if n != null:
				n.process_mode = Node.PROCESS_MODE_DISABLED
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
				t.set_physics_process(false)
		if toggles.has("no_enemy_collide"):
			(e as CollisionObject2D).set_collision_mask_value(2, false)
		if toggles.has("no_hurt"):
			var hb: Area2D = e.get_node_or_null("Hurtbox") as Area2D
			if hb != null:
				hb.monitorable = false
				hb.collision_layer = 0
			var hx: Area2D = e.get_node_or_null("Hitbox") as Area2D
			if hx != null:
				hx.process_mode = Node.PROCESS_MODE_DISABLED
		if toggles.has("no_body"):
			(e as CollisionObject2D).collision_layer = 0
			(e as CollisionObject2D).collision_mask = 0
		if toggles.has("strip_tele"):
			var tv: Node = e.get_node_or_null("TelegraphVisual")
			if tv != null:
				tv.free()
		if toggles.has("strip_hurt"):
			var hu: Node = e.get_node_or_null("Hurtbox")
			if hu != null:
				e.remove_child(hu)
		if toggles.has("strip_hitbox"):
			var hx2: Node = e.get_node_or_null("Hitbox")
			if hx2 != null:
				e.remove_child(hx2)
		if toggles.has("hold_all") and e.has_method("swarm_hold_for_test"):
			e.swarm_hold_for_test(true)
		if toggles.has("hide"):
			(e as CanvasItem).visible = false


## Diagnostic (toggle "dump_tree"): the scene tree down to `max_depth` with the number of visible
## canvas items in each subtree (an upper bound on its draw calls).
func _dump(n: Node, depth: int, max_depth: int) -> void:
	var cls: String = n.get_class()
	var scr: Script = n.get_script()
	if scr != null and scr.get_global_name() != &"":
		cls = String(scr.get_global_name())
	print("TREE %s%s [%s] items=%d%s" % ["  ".repeat(depth), n.name, cls, _visible_items(n), " HIDDEN" if (n is CanvasItem and not (n as CanvasItem).visible) else ""])
	if depth >= max_depth:
		return
	var seen: Dictionary = {}
	for c in n.get_children():
		if _visible_items(c) > 0 or c is CanvasItem:
			var key: String = c.get_class() + ("/" + String(c.get_script().get_global_name()) if c.get_script() != null else "")
			if String(c.name).begins_with("@"):
				seen[key] = int(seen.get(key, 0)) + 1
				if int(seen[key]) > 2:
					continue # anonymous siblings of one kind: the first two stand for the rest
			_dump(c, depth + 1, max_depth)


func _visible_items(n: Node) -> int:
	var cnt: int = 0
	if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
		cnt = 1
	for c in n.get_children():
		cnt += _visible_items(c)
	return cnt


func _scan_collect(n: Node, depth: int) -> void:
	for c in n.get_children():
		if (c is CanvasItem and (c as CanvasItem).visible) or (c is CanvasLayer and (c as CanvasLayer).visible):
			_scan_nodes.append(c)
			if depth > 1:
				_scan_collect(c, depth - 1)


## Diagnostic (toggle "scan:<path>@<depth>"): hides each canvas child in turn and prints how many
## draw calls the frame loses ("SCAN <path> calls=N items=M").
func _scan_step() -> void:
	if _scan_idx >= _scan_nodes.size():
		_scan_idx += 1
		return
	var n: Node = _scan_nodes[_scan_idx]
	if not is_instance_valid(n):
		_scan_idx += 1
		return
	var calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if _scan_phase == 0:
		_scan_base = calls
		n.set("visible", false)
		_scan_phase = 1
	elif _scan_phase == 1:
		_scan_phase = 2
	else:
		n.set("visible", true)
		_scan_phase = 0
		_scan_idx += 1
		if _scan_base - calls != 0.0:
			print("SCAN %s calls=%d (of %d) items=%d" % [root_scene.get_path_to(n), int(_scan_base - calls), int(_scan_base), _visible_items(n)])


## Diagnostic (toggle "procscan:<path>"): disables the processing of each child of <path> in turn
## (process_mode DISABLED) and prints how much the mean frame time drops ("PSCAN <child> delta_ms").
## Headless runs are stable to about 0.1 ms. Returns true when done.
func _pscan_step(dt_ms: float) -> bool:
	if _pscan_wait > 0:
		_pscan_wait -= 1
		return false
	_pscan_acc += dt_ms
	_pscan_n += 1
	if _pscan_n < 90:
		return false
	var mean: float = _pscan_acc / float(_pscan_n)
	_pscan_acc = 0.0
	_pscan_n = 0
	if _pscan_idx < 0:
		_pscan_base = mean
		print("PSCAN baseline %.2f" % mean)
	else:
		var prev: Node = _pscan_nodes[_pscan_idx]
		if is_instance_valid(prev):
			prev.process_mode = Node.PROCESS_MODE_INHERIT
			print("PSCAN %s delta_ms=%.2f (%.2f)" % [prev.name, _pscan_base - mean, mean])
	_pscan_idx += 1
	_pscan_wait = 10
	while _pscan_idx < _pscan_nodes.size() and not is_instance_valid(_pscan_nodes[_pscan_idx]):
		_pscan_idx += 1
	if _pscan_idx >= _pscan_nodes.size():
		return true
	_pscan_nodes[_pscan_idx].process_mode = Node.PROCESS_MODE_DISABLED
	return false

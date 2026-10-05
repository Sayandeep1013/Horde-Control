extends SceneTree
## Balance bot (review 2026-10-05 P0-2, promoted from the reviewer's throwaway
## sandbox script). Dev tooling, not shipped gameplay: it drives the assembled
## prototype scene headlessly with a scripted movement policy, always confirms
## a Draft card, and prints one machine-readable result line.
##
## Lives in src/dev/ rather than tools/balance/ because tools/ carries a
## .gdignore (Godot hides it from res://, so `-s res://tools/...` would not
## resolve reliably).
##
## USAGE (one Godot process at a time; ~1-4 wall-clock minutes per run):
##   timeout 590 D:/godot/Godot_v4.7.1-stable_win64_console.exe --headless \
##     --path <project> --audio-driver Dummy --fixed-fps 60 --no-focus-pause \
##     -s res://src/dev/balance_bot.gd -- --mode=still --seed=11 \
##     --meta-profile-dir=<abs sandbox dir>
##
## User args (after `--`):
##   --mode=still|orbit|collect|far   movement policy (default still)
##       still   never moves (the "idle minute" / "safe corner" ban test)
##       orbit   circles the Tower at 200 px, ignores pickups (Register Orbit test)
##       collect walks to the nearest pickup within 700 px of the player and
##               900 px of the Tower (350 px during Siege waves), else orbits, and steps away from enemies
##               within 130 px (what a real player does)
##       far     walks 1400 px east of the Tower and stands
##   --seed=N                         run seed (default: random, printed)
##   --pick=0|1|2|-1|smart            Draft card: index (default 0), -1 = random,
##       smart = highest on a fixed power-first priority list (damage, fire rate,
##       Tower cards before sustain), except Patch Kit when the player is below
##       50% health and Repair Kit when the Tower is, which approximates a human
##   --max-sim=SECONDS                abort at this SimClock time (default 1200)
##   --csv=<abs path>                 append one result row to this CSV
##   --meta-profile-dir=<abs dir>     REQUIRED in practice: MetaProgress writes
##       its profile there instead of the real user:// profile. If omitted the
##       bot refuses to start (it would otherwise settle the real profile).
##
## Output: "BOT_RESULT mode=.. seed=.. outcome=VICTORY|TOWER|PLAYER|TIMEOUT
## t=.. wave=.. P=.. T=.. drafts=.. kills=.." as the last line.

const SIEGE_WAVES: Array[String] = ["wave_t4", "wave_combat_2", "wave_combat_4"]
const PROFILE_FLAG: String = "--meta-profile-dir="

var mode: String = "still"
var pick: int = 0
var smart_pick: bool = false
const SMART_PRIORITY: Array[String] = ["caliber", "tower_volley", "rapid_fire", "heavy_rounds", "optics", "shield_matrix", "reinforced_plating", "vitality", "multishot", "regeneration", "watchtower_upgrade", "piercing_arrows", "repair_kit", "swift_feet", "magnet", "patch_kit"]
var seed_value: int = -1
var max_sim: float = 1200.0
var csv_path: String = ""
var root_scene: Node
var next_log: float = 0.0
var last_wave: String = ""
var drafts: int = 0
var ended: bool = false
var frames: int = 0
var peak_pressure: float = 0.0
var min_tower: float = 1.0e9
var min_player: float = 1.0e9


func _initialize() -> void:
	var has_profile_dir: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="): mode = a.trim_prefix("--mode=")
		if a == "--pick=smart": smart_pick = true
		elif a.begins_with("--pick="): pick = int(a.trim_prefix("--pick="))
		if a.begins_with("--seed="): seed_value = int(a.trim_prefix("--seed="))
		if a.begins_with("--max-sim="): max_sim = float(a.trim_prefix("--max-sim="))
		if a.begins_with("--csv="): csv_path = a.trim_prefix("--csv=")
		if a.begins_with(PROFILE_FLAG): has_profile_dir = true
	for a in OS.get_cmdline_args():
		if a.begins_with(PROFILE_FLAG): has_profile_dir = true
	if not has_profile_dir:
		push_error("balance_bot: refusing to run without --meta-profile-dir=<sandbox dir>")
		quit(2)
		return
	if seed_value < 0:
		seed_value = int(randi() & 0x7fffffff)
	var ps: PackedScene = load("res://scenes/prototype.tscn")
	root_scene = ps.instantiate()
	root_scene.run_seed = seed_value
	root.add_child.call_deferred(root_scene)
	print("BOT_START mode=%s seed=%d pick=%s" % [mode, seed_value, "smart" if smart_pick else str(pick)])


func _n(p: String) -> Node:
	return root_scene.get_node_or_null(p) if root_scene and root_scene.is_inside_tree() else null


func _movement_dir(player: Node2D, tower: Node2D, ps: Node) -> Vector2:
	var pp: Vector2 = player.global_position
	var tp: Vector2 = tower.global_position
	var dir := Vector2.ZERO
	if mode == "far":
		var tg: Vector2 = tp + Vector2(1400, 0)
		if pp.distance_to(tg) > 12.0:
			dir = (tg - pp).normalized()
	elif mode == "orbit" or mode == "collect":
		var target: Vector2 = tp + (pp - tp).normalized().rotated(0.6) * 200.0
		if mode == "collect":
			var best: Node2D = null
			var best_d: float = 700.0
			# During a Siege wave a real player heeds the warning and stays home:
			# only pickups close to the Tower are worth fetching.
			var leash: float = 350.0 if SIEGE_WAVES.has(last_wave) else 900.0
			for p in ps.get_active_pickups_for_test():
				var d: float = p.global_position.distance_to(pp)
				if d < best_d and p.global_position.distance_to(tp) < leash:
					best_d = d
					best = p
			if best != null:
				target = best.global_position
		if pp.distance_to(target) > 12.0:
			dir = (target - pp).normalized()
		if mode == "collect":
			# A human steps away from enemies that are on top of them; the
			# collect bot does the same (repulsion from enemies within 130 px).
			var push := Vector2.ZERO
			for e in root.get_node("EntityRegistry").get_enemies_in_radius(pp, 130.0):
				var away: Vector2 = pp - e.global_position
				var d: float = maxf(away.length(), 1.0)
				push += away / d * (1.0 - d / 130.0)
			if push != Vector2.ZERO:
				dir = (dir + push * 1.5).normalized()
	return dir


func _process(_delta: float) -> bool:
	frames += 1
	if root_scene == null or not root_scene.is_inside_tree():
		return false
	var wd: Node = _n("Main/WaveDirector")
	var tower: Node = _n("Main/Tower")
	var player: Node = _n("Main/Player")
	var draft: Node = _n("DraftInstance")
	var ps: Node = _n("Main/PickupSystem")
	var rfc: Node = _n("RunFlowController")
	if wd == null or tower == null or player == null:
		return false
	var now: float = root.get_node("SimClock").now

	if draft != null and draft.is_draft_showing_for_test():
		var ids: Array = draft.get_current_card_ids_for_test()
		draft.skip_lockout_for_test()
		var idx: int = pick
		if smart_pick:
			var best_rank: int = 999
			idx = 0
			var p_frac: float = player.death_state.current_hp / maxf(1.0, player.death_state.max_hp)
			var t_frac: float = tower.health.get_current_health() / maxf(1.0, tower.health.max_health)
			for i in ids.size():
				var rank: int = SMART_PRIORITY.find(str(ids[i]))
				if rank < 0:
					rank = 500
				# A human takes the heal when the pool it heals is below half.
				if str(ids[i]) == "patch_kit" and p_frac < 0.5:
					rank = -2
				if str(ids[i]) == "repair_kit" and t_frac < 0.5:
					rank = -1
				if rank < best_rank:
					best_rank = rank
					idx = i
		elif pick < 0:
			idx = randi() % ids.size()
		print("[%6.1f] DRAFT lvl=%d offered=%s -> %s" % [now, ps.run_inventory.level, ids, ids[idx]])
		draft.confirm_choice_for_test(idx)
		drafts += 1

	if not ended:
		player.set_input_direction_for_test(_movement_dir(player, tower, ps))

	var wid: String = wd.get_current_wave_id()
	if wid != last_wave:
		print("[%6.1f] WAVE %s (%d/%d) state=%s" % [now, wid, wd.get_current_wave_display_index(), wd.get_wave_total_count(), wd.get_state_name()])
		last_wave = wid

	var p_hp: float = player.death_state.current_hp
	var t_hp: float = tower.health.get_current_health()
	min_player = minf(min_player, p_hp)
	min_tower = minf(min_tower, t_hp)
	peak_pressure = maxf(peak_pressure, wd.get_pressure_value_for_test())
	if now >= next_log:
		next_log = now + 10.0
		var reg: Node = root.get_node("EntityRegistry")
		var tpos: Vector2 = tower.global_position
		var near_mix: Array[int] = [0, 0, 0] # intents within 150 px of the player: Seeker, Hunter, Opportunist
		for e in reg.get_enemies_in_radius(player.global_position, 150.0):
			var it: int = int(e.get("current_intent"))
			if it >= 0 and it < 3:
				near_mix[it] += 1
		print("[%6.1f] st=%s P=%.0f T=%.0f+%.0f enemies=%d (<200px:%d <480px:%d) nearP[S/H/O]=%s pickups=%d lvl=%d scrap=%d press=%.2f" % [now, wd.get_state_name(), p_hp, t_hp, tower.health.current_shield, reg.get_live_enemy_count(), reg.get_enemies_in_radius(tpos, 200.0).size(), reg.get_enemies_in_radius(tpos, 480.0).size(), str(near_mix), ps.get_active_pickup_count(), ps.run_inventory.level, ps.run_inventory.scrap_current, wd.get_pressure_value_for_test()])

	if rfc != null and rfc.get_state_for_test() == 2 and not ended:
		ended = true
		var cause: int = rfc.get_end_cause_for_test()
		var outcome: String = "VICTORY" if cause == 3 else ("TOWER" if cause == 2 else ("PLAYER" if cause == 1 else "OTHER"))
		_finish(outcome, now, wd, p_hp, t_hp, rfc)
		return true
	if now > max_sim or frames > 400000:
		_finish("TIMEOUT", now, wd, p_hp, t_hp, rfc)
		return true
	return false


func _finish(outcome: String, now: float, wd: Node, p_hp: float, t_hp: float, rfc: Node) -> void:
	var kills: int = rfc.get_kill_count_for_test() if rfc != null else -1
	var line: String = "BOT_RESULT mode=%s seed=%d outcome=%s t=%.1f wave=%d P=%.0f T=%.0f minP=%.0f minT=%.0f peakPress=%.2f drafts=%d kills=%d" % [mode, seed_value, outcome, now, wd.get_current_wave_display_index(), p_hp, t_hp, min_player, min_tower, peak_pressure, drafts, kills]
	print(line)
	if csv_path != "":
		var existed: bool = FileAccess.file_exists(csv_path)
		var f: FileAccess = FileAccess.open(csv_path, FileAccess.READ_WRITE if existed else FileAccess.WRITE)
		if f != null:
			if existed:
				f.seek_end()
			else:
				f.store_line("mode,seed,outcome,t,wave,player_hp,tower_hp,min_player,min_tower,peak_pressure,drafts,kills")
			f.store_line("%s,%d,%s,%.1f,%d,%.0f,%.0f,%.0f,%.0f,%.2f,%d,%d" % [mode, seed_value, outcome, now, wd.get_current_wave_display_index(), p_hp, t_hp, min_player, min_tower, peak_pressure, drafts, kills])
			f.close()

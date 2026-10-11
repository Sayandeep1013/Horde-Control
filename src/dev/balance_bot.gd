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
##   --autocast                       turn Auto-cast Battle Skill on (v1.0, docs/31 Â§3.3);
##       the bot never presses the skill key itself, so without this flag no
##       Battle Skill is cast. Dash is never auto-cast and the bot does not dash.
##   --no-autocast                    kite only: leave Auto-cast Battle Skill off
##   --difficulty=recruit|soldier|veteran|warlord   sets RunConfig.difficulty_id
##       before the scene loads (default soldier)
##   --immortal-player / --immortal-tower   top that pool up every frame so the other
##       pool's pressure can be read to the end (measurement aid; damage counters
##       still count every hit)
##   --max-sim=SECONDS                abort at this SimClock time (default 1200)
##   --csv=<abs path>                 append one result row to this CSV
##   --meta-profile-dir=<abs dir>     REQUIRED in practice: MetaProgress writes
##       its profile there instead of the real user:// profile. If omitted the
##       bot refuses to start (it would otherwise settle the real profile).
##
## Output: "BOT_RESULT mode=.. diff=.. seed=.. outcome=VICTORY|TOWER|PLAYER|TIMEOUT
## cause=.. t=.. wave=.. P=.. T=.. .. dmg=src:amount,.." as the last line. WAVE_STAT
## lines (one per wave: duration, player damage taken, Tower damage taken, Tower
## HP at wave end) are printed as the run goes.

const SIEGE_WAVES: Array[String] = ["wave_04", "wave_07", "wave_10", "wave_13", "wave_14"] # v1.0 Siege and Grand Assault waves
const PROFILE_FLAG: String = "--meta-profile-dir="

var mode: String = "still"
var pick: int = 0
var smart_pick: bool = false
## v1.0 order: abilities first (a level-up of an owned ability is the same id, so
## "abilities, then their levels" falls out of the order), strongest by measured
## damage share first (baseline damage reports: Ballista, Whirling Axes and
## Dynamite Satchel carried runs; Flame Arrows and Frost Ward were 1-7%), then
## damage/rate passives, then sustain. Caltrops is late (only works while moving)
## and Spiked Palisade is a defensive tail.
const SMART_PRIORITY: Array[String] = ["ballista", "whirling_axes", "dynamite_satchel", "storm_bolt", "catapult", "sacred_ground", "flame_arrows", "frost_arrows", "frost_ward", "caliber", "tower_volley", "rapid_fire", "heavy_rounds", "ability_power", "keen_eye", "multishot", "piercing_arrows", "blast_radius", "battle_focus", "optics", "shield_matrix", "reinforced_plating", "vitality", "leather_armor", "regeneration", "watchtower_upgrade", "stone_mason", "caltrops", "spiked_palisade", "fleet_step", "repair_kit", "swift_feet", "magnet", "patch_kit"]
const BOSS_IDS: Array[String] = ["goblin_warchief", "bombardier_king"]
const KITE_HUNTER_R: float = 220.0
const KITE_BOMBER_R: float = 230.0
const KITE_BOSS_R: float = 330.0
const KITE_DASH_R: float = 60.0
var autocast: bool = false
var no_autocast: bool = false
## Measurement aids, not policies: keep a pool topped up so the other pool's
## pressure can be read for the whole sequence ("Tower loses health in every
## Siege wave without player help"). Damage counters still count every hit.
var immortal_player: bool = false
var immortal_tower: bool = false
var difficulty: String = "soldier"
var repairing: bool = false
var tele_cache: Array = []
var tele_next_scan: int = 0
var wave_t0: float = 0.0
var wave_p0: float = 0.0
var wave_tw0: float = 0.0
var wave_stats: Array[String] = []
var boss_alive_since: float = -1.0
var boss_start_stats: Dictionary = {}
var boss_log: Array[String] = []
var dashes_used: int = 0
var profile_dir: String = ""
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
		if a == "--autocast": autocast = true
		if a == "--no-autocast": no_autocast = true
		if a == "--immortal-player": immortal_player = true
		if a == "--immortal-tower": immortal_tower = true
		if a.begins_with("--difficulty="): difficulty = a.trim_prefix("--difficulty=")
		if a == "--pick=smart": smart_pick = true
		elif a.begins_with("--pick="): pick = int(a.trim_prefix("--pick="))
		if a.begins_with("--seed="): seed_value = int(a.trim_prefix("--seed="))
		if a.begins_with("--max-sim="): max_sim = float(a.trim_prefix("--max-sim="))
		if a.begins_with("--csv="): csv_path = a.trim_prefix("--csv=")
		if a.begins_with(PROFILE_FLAG):
			has_profile_dir = true
			profile_dir = a.trim_prefix(PROFILE_FLAG)
	for a in OS.get_cmdline_args():
		if a.begins_with(PROFILE_FLAG):
			has_profile_dir = true
			profile_dir = a.trim_prefix(PROFILE_FLAG)
	if not has_profile_dir:
		push_error("balance_bot: refusing to run without --meta-profile-dir=<sandbox dir>")
		quit(2)
		return
	if mode == "kite" and not no_autocast:
		autocast = true
	if autocast:
		# Redirect the settings file into the sandbox profile dir first: turning
		# the option on saves GameSettings, and the bot must never touch the
		# real user:// settings.
		GameSettings.set_path_for_test(profile_dir.path_join("bot_settings.cfg"))
		GameSettings.set_auto_cast_enabled(true)
	if seed_value < 0:
		seed_value = int(randi() & 0x7fffffff)
	RunConfig.run_events_forced = true # docs/32: the run events run headless too, and the bot answers them
	RunConfig.difficulty_id = difficulty
	var ps: PackedScene = load("res://scenes/prototype.tscn")
	root_scene = ps.instantiate()
	root_scene.run_seed = seed_value
	root.add_child.call_deferred(root_scene)
	print("BOT_START mode=%s diff=%s seed=%d pick=%s autocast=%s" % [mode, difficulty, seed_value, "smart" if smart_pick else str(pick), str(autocast)])


func _n(p: String) -> Node:
	return root_scene.get_node_or_null(p) if root_scene and root_scene.is_inside_tree() else null


func _movement_dir(player: Node2D, tower: Node2D, ps: Node) -> Vector2:
	var pp: Vector2 = player.global_position
	var tp: Vector2 = tower.global_position
	var dir := Vector2.ZERO
	if mode == "kite":
		return _kite_dir(player, tower, ps)
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
			var arena_target: Vector2 = _arena_target(pp, tp) # v1.0 WP-ARENA: claim a safe Shrine, break nearby crates
			if arena_target != Vector2.INF:
				target = arena_target
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


## v1.0 WP-ARENA (Register "v1.0 Arena Interactables"): a point worth walking to for the collect policy: an unclaimed
## Shrine within reach when no enemy is near it (the bot then stands on it until it
## is claimed), else the nearest Supply Crate within 600 px. Never during a Siege
## wave and never beyond 900 px of the Tower. Vector2.INF = nothing to do.
func _arena_target(pp: Vector2, tp: Vector2) -> Vector2:
	var mgr: Node = _n("Main/ArenaInteractables")
	if mgr == null or SIEGE_WAVES.has(last_wave):
		return Vector2.INF
	var reg: Node = root.get_node("EntityRegistry")
	var shrine: Node2D = mgr.get_shrine()
	if shrine != null and not shrine.is_claimed and not shrine.is_expired and shrine.time_left() > 4.0:
		var sp: Vector2 = shrine.global_position
		if sp.distance_to(pp) < 900.0 and sp.distance_to(tp) < 900.0 and reg.get_enemies_in_radius(sp, 220.0).is_empty():
			return sp
	var best: Vector2 = Vector2.INF
	var best_d: float = 600.0
	for c in mgr.get_crates():
		var d: float = c.global_position.distance_to(pp)
		if d < best_d and c.global_position.distance_to(tp) < 900.0:
			best_d = d
			best = c.global_position
	return best

func _enemy_id(e: Node) -> String:
	var d: Variant = e.get("definition")
	return str(d.unique_id) if d != null else ""


func _scan_telegraphs() -> void:
	# Cheap enough at ~20 Hz: walk the scene once and keep every live red ring.
	tele_cache.clear()
	var stack: Array = [root_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		# Duck-typed on purpose: naming GroundTelegraph here would compile that script
		# while this -s script loads, before the autoloads (SimClock) exist, and
		# poison it for the game.
		var scr: Script = n.get_script()
		if scr != null and scr.get_global_name() == &"GroundTelegraph":
			var g: Node2D = n
			# Player-ability telegraphs use the ability's own tint; only danger red counts.
			var col: Color = g.get("color")
			if col.r > 0.7 and col.g < 0.4 and g.time_left() > 0.0:
				tele_cache.append(g)
			continue
		for c in n.get_children():
			if not (c is CollisionShape2D) and not (c is Sprite2D) and not (c is AnimatedSprite2D):
				stack.append(c)


## Set by _kite_dir when a dash is warranted.
var want_dash: bool = false


func _kite_dir(player: Node2D, tower: Node2D, ps: Node) -> Vector2:
	want_dash = false
	var pp: Vector2 = player.global_position
	var tp: Vector2 = tower.global_position
	var reg: Node = root.get_node("EntityRegistry")
	var siege: bool = SIEGE_WAVES.has(last_wave)
	var p_frac: float = player.death_state.current_hp / maxf(1.0, player.death_state.max_hp)
	var t_frac: float = tower.health.get_current_health() / maxf(1.0, tower.health.max_health)
	var scrap: int = ps.run_inventory.scrap_current
	# Repair hysteresis: start under 60% with Scrap, stop at 90% or when Scrap is gone.
	if not repairing and t_frac < 0.6 and scrap > 20:
		repairing = true
	if repairing and (t_frac >= 0.9 or scrap <= 0 or p_frac < 0.3):
		repairing = false
	# 1) Telegraph dodge overrides everything.
	if frames >= tele_next_scan:
		tele_next_scan = frames + 3
		_scan_telegraphs()
	var escape := Vector2.ZERO
	var imminent: bool = false
	for g in tele_cache:
		if not is_instance_valid(g):
			continue
		var off: Vector2 = pp - g.global_position
		var d: float = off.length()
		var r: float = float(g.get("radius")) + 24.0
		if d < r:
			escape += (off / maxf(d, 1.0)) * (1.0 + (r - d) / r)
			if g.time_left() < 0.35:
				imminent = true
	if escape != Vector2.ZERO:
		want_dash = imminent
		return escape.normalized()
	# 2) Base target.
	var target: Vector2 = tp + (pp - tp).normalized().rotated(0.6) * 200.0
	var live: Array = reg.get_enemies_in_radius(pp, 700.0)
	if repairing:
		target = tp + (pp - tp).normalized() * 40.0 if pp.distance_to(tp) > 40.0 else pp
	elif siege:
		# Hold the side of the Tower where the horde is heaviest.
		var c := Vector2.ZERO
		var n: int = 0
		for e in reg.get_enemies_in_radius(tp, 650.0):
			c += e.global_position
			n += 1
		if n > 0:
			target = tp + ((c / n) - tp).normalized() * 190.0
	else:
		var best: Node2D = null
		var best_d: float = 700.0
		for pk in ps.get_active_pickups_for_test():
			var dd: float = pk.global_position.distance_to(pp)
			if dd < best_d and pk.global_position.distance_to(tp) < 900.0:
				best_d = dd
				best = pk
		if best != null:
			target = best.global_position
	var dir := Vector2.ZERO
	if pp.distance_to(target) > 12.0:
		dir = (target - pp).normalized()
	# 3) Repulsion: Hunters, Bombers and bosses are kited; anything on top of us is stepped away from.
	var push := Vector2.ZERO
	var close_threat: bool = false
	for e in live:
		var id: String = _enemy_id(e)
		var away: Vector2 = pp - e.global_position
		var d: float = maxf(away.length(), 1.0)
		var r: float = 130.0
		if BOSS_IDS.has(id):
			r = KITE_BOSS_R
		elif id == "bomber":
			r = KITE_BOMBER_R
		elif id == "player_hunter" or int(e.get("current_intent")) == 1:
			r = KITE_HUNTER_R
		if d < r:
			push += away / d * (1.0 - d / r)
		if d < KITE_DASH_R:
			close_threat = true
	if push != Vector2.ZERO:
		var k: float = 2.2 if not repairing else 1.2
		dir = (dir + push * k).normalized() if dir != Vector2.ZERO else push.normalized()
	want_dash = close_threat and dir != Vector2.ZERO
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

	_handle_events(now, player, tower)
	if not ended:
		player.set_input_direction_for_test(_focus_adjust(_movement_dir(player, tower, ps), player, now))

		player.set_input_direction_for_test(_movement_dir(player, tower, ps))
		if mode == "kite" and want_dash and not player.is_dashing() and player.get_dash_state()["charges"] > 0:
			player.press_dash_for_test()
			dashes_used += 1

	var wid: String = wd.get_current_wave_id()
	if wid != last_wave:
		_close_wave(now, tower)
		print("[%6.1f] WAVE %s (%d/%d) state=%s" % [now, wid, wd.get_current_wave_display_index(), wd.get_wave_total_count(), wd.get_state_name()])
		last_wave = wid

	if immortal_tower and not ended:
		tower.health.heal(100000.0)
		tower.health.restore_shield()
	if immortal_player and not ended:
		player.death_state.current_hp = player.death_state.max_hp
	var p_hp: float = player.death_state.current_hp
	var t_hp: float = tower.health.get_current_health()
	_track_boss(now)
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


func _close_wave(now: float, tower: Node) -> void:
	if last_wave == "":
		wave_t0 = now
		return
	var pd: float = _cs().get_run_counter("damage_taken")
	var td: float = _cs().get_run_counter("tower_damage_taken")
	var line: String = "%s dur=%.0f pdmg=%.0f tdmg=%.0f T=%.0f" % [last_wave, now - wave_t0, pd - wave_p0, td - wave_tw0, tower.health.get_current_health()]
	wave_stats.append(line)
	print("[%6.1f] WAVE_STAT %s" % [now, line])
	wave_t0 = now
	wave_p0 = pd
	wave_tw0 = td


func _track_boss(now: float) -> void:
	var alive: bool = false
	var bid: String = ""
	for e in root.get_node("EntityRegistry").get_entities_with_tag(&"enemy"):
		var id: String = _enemy_id(e)
		if BOSS_IDS.has(id):
			alive = true
			bid = id
			break
	if alive and boss_alive_since < 0.0:
		boss_alive_since = now
		boss_start_stats = {"id": bid, "pd": _cs().get_run_counter("damage_taken"), "td": _cs().get_run_counter("tower_damage_taken")}
	elif not alive and boss_alive_since >= 0.0:
		_close_boss(now)


func _close_boss(now: float) -> void:
	var s: String = "boss=%s fight=%.0fs pdmg=%.0f tdmg=%.0f" % [boss_start_stats.get("id", "?"), now - boss_alive_since, _cs().get_run_counter("damage_taken") - float(boss_start_stats.get("pd", 0)), _cs().get_run_counter("tower_damage_taken") - float(boss_start_stats.get("td", 0))]
	boss_log.append(s)
	print("[%6.1f] BOSS_FIGHT %s" % [now, s])
	boss_alive_since = -1.0


func _finish(outcome: String, now: float, wd: Node, p_hp: float, t_hp: float, rfc: Node) -> void:
	var kills: int = rfc.get_kill_count_for_test() if rfc != null else -1
	if boss_alive_since >= 0.0:
		_close_boss(now)
	var cause: String = "none"
	if rfc != null:
		cause = ["NONE", "PLAYER_DEFEATED", "TOWER_DESTROYED", "SEQUENCE_COMPLETED", "ABANDONED"][clampi(rfc.get_end_cause_for_test(), 0, 4)]
	var dmg_parts: Array[String] = []
	var total: float = 0.0
	for r in _cs().get_damage_by_source():
		total += float(r["damage"])
	for r in _cs().get_damage_by_source():
		dmg_parts.append("%s:%.0f(%.0f%%)" % [r["source_id"], r["damage"], 100.0 * float(r["damage"]) / maxf(total, 1.0)])
	var line: String = "BOT_RESULT mode=%s diff=%s seed=%d outcome=%s cause=%s t=%.1f wave=%d P=%.0f T=%.0f minP=%.0f minT=%.0f peakPress=%.2f drafts=%d kills=%d dashes=%.0f skills=%.0f repaired=%.0f dmg=%s" % [mode, difficulty, seed_value, outcome, cause, now, wd.get_current_wave_display_index(), p_hp, t_hp, min_player, min_tower, peak_pressure, drafts, kills, _cs().get_run_counter("dashes"), _cs().get_run_counter("skills_cast"), _cs().get_run_counter("tower_repaired"), ",".join(dmg_parts)]
	print(line)
	if csv_path != "":
		var existed: bool = FileAccess.file_exists(csv_path)
		var f: FileAccess = FileAccess.open(csv_path, FileAccess.READ_WRITE if existed else FileAccess.WRITE)
		if f != null:
			if existed:
				f.seek_end()
			else:
				f.store_line("mode,difficulty,seed,outcome,cause,t,wave,player_hp,tower_hp,min_player,min_tower,drafts,kills,boss_fights,damage")
			f.store_line("%s,%s,%d,%s,%s,%.1f,%d,%.0f,%.0f,%.0f,%.0f,%d,%d,\"%s\",\"%s\"" % [mode, difficulty, seed_value, outcome, cause, now, wd.get_current_wave_display_index(), p_hp, t_hp, min_player, min_tower, drafts, kills, " | ".join(boss_log), ",".join(dmg_parts)])
			f.close()


# --- WP-RUNEVENTS (docs/32 §A, §A2): run events and Focus ------------------------

const FOCUS_NEAR_ENEMY_PX: float = 150.0 ## stand only when nothing is this close
const FOCUS_STAND_SECONDS: float = 2.0 ## long enough to reach full Focus (0.25 s + 1.5 s)
const FOCUS_MOVE_SECONDS: float = 3.0 ## then carry on (pickups, orbit) before standing again
var events_taken: int = 0
var _focus_stand_until: float = -1.0
var _focus_next_stand: float = 0.0


## Answers an open run event: Opening Pick and Patron's Boon by the smart priority,
## Sanctuary by need (Restore if the Tower is under 50%, Mend if the player is, else
## Valor), Blood Pact by paying with the pool that has more HP (refusing if both are
## under 60%). Skips the input lockout like the Draft block does.
func _handle_events(now: float, player: Node, tower: Node) -> void:
	var ev: Node = _n("EventDraftInstance")
	if ev == null or not ev.is_showing():
		return
	var offer: Dictionary = ev.get_offer()
	var cards: Array = offer.get("cards", [])
	var p_frac: float = player.death_state.current_hp / maxf(1.0, player.death_state.max_hp)
	var t_frac: float = tower.health.get_current_health() / maxf(1.0, tower.health.max_health)
	var idx: int = 0
	match str(offer.get("kind", "")):
		"opening_pick", "patrons_boon":
			var best_rank: int = 999
			for i in cards.size():
				var rank: int = SMART_PRIORITY.find(str(cards[i].get("id", "")))
				rank = 500 if rank < 0 else rank
				if str(cards[i].get("id", "")) == "patch_kit" and p_frac < 0.5:
					rank = -2
				if str(cards[i].get("id", "")) == "repair_kit" and t_frac < 0.5:
					rank = -1
				if rank < best_rank:
					best_rank = rank
					idx = i
		"sanctuary":
			idx = 1 if t_frac < 0.5 else (0 if p_frac < 0.5 else 2) # Restore, Mend, Valor
		"blood_pact":
			idx = 2 if (p_frac < 0.6 and t_frac < 0.6) else (1 if t_frac > p_frac else 0) # Refuse, Tower, blood
	print("[%6.1f] EVENT %s -> %d (P=%.2f T=%.2f)" % [now, offer.get("kind", ""), idx, p_frac, t_frac])
	events_taken += 1
	ev.skip_lockout_for_test()
	ev.confirm_choice_for_test(idx)


## Stands still for FOCUS_STAND_SECONDS whenever no enemy is within FOCUS_NEAR_ENEMY_PX,
## then moves for FOCUS_MOVE_SECONDS, so the bow reaches full Focus in quiet moments.
func _focus_adjust(dir: Vector2, player: Node2D, now: float) -> Vector2:
	if now < _focus_stand_until:
		return Vector2.ZERO if root.get_node("EntityRegistry").get_enemies_in_radius(player.global_position, FOCUS_NEAR_ENEMY_PX).is_empty() else dir
	if now >= _focus_next_stand and root.get_node("EntityRegistry").get_enemies_in_radius(player.global_position, FOCUS_NEAR_ENEMY_PX).is_empty():
		_focus_stand_until = now + FOCUS_STAND_SECONDS
		_focus_next_stand = _focus_stand_until + FOCUS_MOVE_SECONDS
	return dir

func _cs() -> Node:
	return root.get_node("CombatStats")


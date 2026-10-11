extends Node

## MetaProgress Autoload (Meta layer core; decision D112: "a fifth Autoload,
## `MetaProgress`, owns the profile, the wallet, tree ranks, settlement and
## saving, alongside SimClock, PauseAuthority, EventBus and EntityRegistry").
## Registered in project.godot after the existing autoloads.
##
## MASTER_SDLC.md > Provisional Values Register > "Meta: Save profile", >
## "Meta: Skill Tree costs", > "Meta: Skill Tree effects", > "Meta: Run-End
## Settlement (prototype)"; docs/18_Permanent_Skill_Tree.md (stub -- this
## file and `data/meta/skill_tree.tres` ARE its section 4/5 content, per
## this task's brief: "where they are silent, choose the industry-standard
## behaviour and record it"); docs/24_Save_System.md (also a stub for the
## same reason).
##
## ## Never touches the real `user://profile.json` unless asked to
## `_ready()` performs NO disk I/O at all -- it only resolves `_base_path`
## (from `--meta-profile-dir=<dir>`, a harness/test flag mirroring
## `RunFlowController`'s own `--no-focus-pause` precedent, or the real
## `user://` default) and builds a fresh, all-zero, IN-MEMORY profile. This
## matters because MetaProgress is an Autoload: gdUnit4's headless test
## runner boots the WHOLE project, `_ready()` included, for every single
## test file, even ones that have nothing to do with the meta layer. Actually
## reading (and, on first save, creating) the real save file only happens
## once something calls `load_profile()` / `ensure_loaded()` -- the real
## game's Hub scene is the one production caller; every test instead calls
## `set_base_path_for_test()` with a throwaway directory FIRST, exactly
## per this task's hard constraint.
##
## ## Atomic save (docs/24 stub; Register > "Meta: Save profile")
## `profile.json.tmp` is written in full, THEN the previous `profile.json`
## (if any) is copied to `profile.json.bak`, THEN `profile.json.tmp` is
## renamed over `profile.json`. The real file is only ever touched by that
## final rename, so a process killed at any point before it completes
## leaves the previous, fully-written `profile.json` exactly as it was --
## see `set_fail_after_tmp_write_for_test()` / `set_fail_after_bak_write_for_test()`,
## the two injectable failure hooks a test uses to prove this.
##
## ## Corruption fallback (Register: "corrupt file falls back to .bak, then
## a fresh profile with profile.corrupt.json kept")
## A `profile.json` that fails to parse is copied to `profile.corrupt.json`
## (kept, never overwritten silently -- a second corruption in the same
## session would clobber the first copy, which is accepted: the flag
## `recovered_from_corruption` is what a caller checks, not the file's
## presence) before falling back to `profile.json.bak`, then to a fresh
## profile if the backup is unusable too.
##
## ## Reconciliation (Register: "reconcile (rank above max / unknown id
## refunded)")
## Every load (fresh, from-disk, or from-backup) passes through
## `_reconcile()`: a stored rank for an id no longer in the authored tree,
## or a rank exceeding that node's current `max_rank`, is refunded to Cores
## rather than silently dropped or silently kept out-of-range -- an
## authored-content change (a node removed or its `max_rank` lowered)
## between sessions must never stand a strand a player's spent Cores.
##
## ## Idempotent settlement (Register: "Settled once per run id")
## `settle_run()` checks the run id against `settled_run_ids` (persisted,
## capped at the last 16) before paying anything; a repeat call for an
## already-settled id returns the SAME cached breakdown if this process
## still holds it in memory (`_settled_breakdown_cache`), or a zeroed
## `already_settled` breakdown otherwise (a cross-process replay, which
## still correctly pays nothing twice, just without the original
## itemisation to hand back).
##
## ## Schema version / migration table
## `schema_version` is 3 (D118 added lifetime achievement counters; D252 the
## v1.0 meta fields -- see below). A file whose `schema_version` is HIGHER than this code's own
## `SCHEMA_VERSION` (this build is older than the one that wrote it) is
## loaded read-only: `flags.read_only_newer_version` is set, and `_save()`
## refuses to write at all, so a downgrade never clobbers a newer save
## format. `_migrate()` is the one seam a future schema bump extends (a
## `match` over `schema_version` applying each step forward in turn, per
## the save-load skill's own "Version Migration" guidance and docs/24
## section 5's own naming convention, `migrate_N_to_N_plus_1`).
##
## ## Schema version 2 (D118, 2026-09-23): lifetime achievement counters
## Adds three top-level fields: `lifetime_kills` (int), `lifetime_scrap_
## collected` (int), and `unlocked_achievement_ids` (Array[String]). A v1
## profile has none of the three; `_migrate_1_to_2()` adds them at zero/
## empty, which is the correct historical value (a profile that predates
## achievements has, by definition, unlocked none and has no lifetime
## counters to backfill from -- the six authored achievements all gate on
## FUTURE play, never retroactively on past runs this profile already
## banked Cores for).

## ## Schema version 3 (D252, 2026-10-11): the v1.0 meta loop
## Adds `selected_difficulty`, `selected_battle_skill`, `selected_endless`,
## `difficulty_victories{recruit,soldier,veteran,warlord}`, `endless_unlocked`,
## `best_endless_wave`, `lifetime_elite_kills`, `lifetime_boss_kills{warchief,
## king}`, `lifetime_repair`, `runs_played` and `tree_migrated_v3_notice`.
## `_migrate_2_to_3()` refunds every Core spent on v2 nodes (priced with the OLD
## 5/10/18/30 tier table and the old node tiers, kept below as constants because
## the authored tree no longer contains them), resets `tree_ranks`, and sets the
## one-time Hub notice flag. docs/31 section 7.3; docs/24.

signal cores_changed(new_total: int)
signal rank_changed(node_id: String, new_rank: int)
signal profile_saved(ok: bool)

const SCHEMA_VERSION: int = 3
const PROFILE_FILENAME: String = "profile.json"
const BACKUP_FILENAME: String = "profile.json.bak"
const TMP_FILENAME: String = "profile.json.tmp"
const CORRUPT_FILENAME: String = "profile.corrupt.json"

## Register > "Meta: Save profile": "settled run ids kept: last 16".
const MAX_SETTLED_RUN_IDS: int = 16
## Register > "Meta: Skill Tree costs": "Core wallet clamped at 999,999".
const CORE_WALLET_CAP: int = 999999

## Register > "Meta: Skill Tree effects": "Prospector +15% settlement Cores
## (2)" -- 2 ranks, +15% each, applied once to the whole settlement subtotal
## (not compounded per rank).
const PROSPECTOR_BONUS_PER_RANK: float = 0.15

## Register > "v1.0 Meta Progression" > "Run-End Settlement (v1.0)" (D253):
## 1 Core per full minute, 2 per wave cleared, 1 per 25 kills, 1 per elite
## killed, 10 for a victory; then x (1 + bonuses) x difficulty Cores multiplier.
const SETTLEMENT_PER_MINUTE_CORES: int = 1
const SETTLEMENT_PER_WAVE_CLEARED_CORES: int = 2
const SETTLEMENT_KILLS_PER_CORE: int = 25
const SETTLEMENT_PER_ELITE_CORES: int = 1
const SETTLEMENT_VICTORY_CORES: int = 10
## docs/31 §5.3/§7.4: boss bounties (Register "v1.0 Meta Progression" >
## settlement). Paid at settlement from the run's boss kills, since bosses drop
## no Core pickup (D255).
const SETTLEMENT_BOSS_CORES: Dictionary = {"warchief": 8, "king": 20}

## Register > "v1.0 Meta Progression": the v2 -> v3 refund table. The v2 tree's
## own tier price table and each v2 node's tier, so the refund is exact even
## though the authored tree changed (D252).
const V2_TIER_BASE_COST: Array[int] = [0, 5, 10, 18, 30]
const V2_NODE_TIERS: Dictionary = {
	"vitality": 1, "swift_boots": 1, "sharpened_arrows": 2, "quick_draw": 2, "long_reach": 3,
	"second_wind": 4, "stone_walls": 1, "arrow_slits": 1, "shield_runes": 2, "masons_kit": 2,
	"watchtower": 3, "fortress": 4, "scavenger": 1, "scholar": 1, "lucky_draw": 2,
	"prospector": 2, "lucky_charm": 2, "deep_pockets": 3, "war_chest": 4,
}
const DIFFICULTY_IDS: Array[String] = ["recruit", "soldier", "veteran", "warlord"]
const BOSS_IDS: Array[String] = ["warchief", "king"]

## D115 (no in-run shop): Scrap has no in-run sink any more -- Register >
## "Meta: Run-End Settlement (prototype)": "Scrap line: floor(scrap_carried
## / 10) Cores". Floor, matching every other settlement term's own rounding.
const SETTLEMENT_SCRAP_PER_CORE: int = 10

## D118 (achievements). Register > "Meta: Achievements": "Founder perk
## (settlement_cores_bonus): +5% Run-End Settlement Cores". Applied here,
## alongside Prospector's own identical-shape bonus, since settle_run() is
## already the one place that re-reads live percentage bonuses at
## settlement time rather than trusting a frozen MetaLoadout snapshot (see
## this file's own `prospector_fraction` local a few lines below). The
## "Marksman" perk (`weapon_damage_bonus`, +5% player weapon damage) is a
## RUN-START bonus instead, applied by `MetaLoadoutApplier` beside Fortress's
## own identical-shape fixed addition -- its own constant lives there, not
## here. `hoarder`'s own perk (`bonus_reroll`) needs no constant at all: a
## flat +1, read directly by `MetaLoadoutApplier`.
const ACHIEVEMENT_SETTLEMENT_CORES_BONUS: float = 0.05
## D251: Regicide's own settlement bonus (Register "Meta: Achievements").
const ACHIEVEMENT_REGICIDE_CORES_BONUS: float = 0.10

## Harness/test-only cmdline flag (mirrors RunFlowController's
## `--no-focus-pause` precedent): redirects the save directory away from the
## real `user://` for a scripted verification run of the real game (e.g. the
## capture harness against `scenes/hub.tscn`) without ever touching the
## player's real profile.
const META_PROFILE_DIR_FLAG_PREFIX: String = "--meta-profile-dir="

var skill_tree: SkillTreeDefinition = preload("res://data/meta/skill_tree.tres")
var achievement_list: AchievementList = preload("res://data/meta/achievements.tres")

var _base_path: String = "user://"
var _profile: Dictionary = {}
var _loaded: bool = false
var _ever_loaded: bool = false # gates the save-on-close handler; see class header
var _settled_breakdown_cache: Dictionary = {} # run_id (String) -> breakdown Dictionary, in-memory only

var _test_fail_after_tmp_write: bool = false
var _test_fail_after_bak_write: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # matches EventBus/PauseAuthority; this node does no per-frame work, so it costs nothing
	_base_path = _resolve_base_path_from_cmdline()
	_profile = _fresh_profile()


## Register > "Meta: Save profile" + build brief item 4: "on close outside a
## run" is one of the four save triggers. `RunFlowController` separately
## handles a close DURING a run (settle-as-abandon, then quit) -- this
## handler is the one that fires for a close OUTSIDE a run (title, Hub),
## where nothing else is listening for this notification. Guarded on
## `_ever_loaded` so a process that only ever visited the title screen
## (never called `ensure_loaded()`/`load_profile()`) does not create a real
## save file out of nothing on close.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _ever_loaded:
		_save()


func _resolve_base_path_from_cmdline() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(META_PROFILE_DIR_FLAG_PREFIX):
			return arg.trim_prefix(META_PROFILE_DIR_FLAG_PREFIX)
	return "user://"


# --- Test / harness seams (project convention: set_*_for_test()) -----------

## Redirects every subsequent read/write to `path` (a throwaway directory)
## instead of the real `user://`, and drops any in-memory profile so the
## next `load_profile()`/`ensure_loaded()` call reads fresh from THAT
## directory. Every test calls this before touching anything else on this
## Autoload -- see class header.
func set_base_path_for_test(path: String) -> void:
	_base_path = path
	_loaded = false
	_ever_loaded = false
	_settled_breakdown_cache.clear()
	_profile = _fresh_profile()


## Simulates a crash immediately after `profile.json.tmp` is fully written,
## before the previous file is backed up or the rename happens. The next
## `_save()` call returns false without touching `profile.json`/`.bak`.
func set_fail_after_tmp_write_for_test(fail: bool) -> void:
	_test_fail_after_tmp_write = fail


## Simulates a crash immediately after `profile.json.bak` is written (or
## skipped, if no previous `profile.json` existed to back up), before the
## rename that would make the new data live.
func set_fail_after_bak_write_for_test(fail: bool) -> void:
	_test_fail_after_bak_write = fail


func set_skill_tree_for_test(tree: SkillTreeDefinition) -> void:
	skill_tree = tree


func set_achievement_list_for_test(list: AchievementList) -> void:
	achievement_list = list


## D118. Sets a lifetime counter directly, bypassing settle_run()'s own
## increment-by-this-run's-contribution arithmetic -- for a test that wants
## a specific counter value going INTO settlement (e.g. "299 lifetime kills,
## then settle a 5-kill run to prove the 300th kill crosses the Goblin
## Slayer threshold") without replaying every prior run that would have
## produced it.
func set_lifetime_counter_for_test(key: String, value: int) -> void:
	if ["lifetime_kills", "lifetime_scrap_collected", "lifetime_elite_kills", "lifetime_repair", "runs_played", "best_endless_wave"].has(key):
		_profile[key] = maxi(0, value)


## Sets a difficulty's recorded victory count directly (unlock-chain tests).
func set_difficulty_victories_for_test(id: String, count: int) -> void:
	(_profile["difficulty_victories"] as Dictionary)[id] = maxi(0, count)
	if count > 0:
		_profile["endless_unlocked"] = true


func get_profile_for_test() -> Dictionary:
	return _profile.duplicate(true)


## Grants an achievement directly, bypassing settle_run()'s own metric
## check -- for a test that needs a specific unlocked-achievement state
## (e.g. an UNLOCK-gated card's own offerability) without replaying the
## run that would have earned it. Never called by gameplay code.
func set_achievement_unlocked_for_test(id: String) -> void:
	var unlocked: Array = _profile["unlocked_achievement_ids"]
	if not unlocked.has(id):
		unlocked.append(id)


## Grants `rank` on `id` directly, bypassing cost/prerequisite checks --
## for tests that need a specific tree state (loadout application,
## settlement's Prospector bonus) without simulating a whole purchase
## sequence. Never called by gameplay code.
func set_rank_for_test(id: String, rank: int) -> void:
	if rank <= 0:
		(_profile["tree_ranks"] as Dictionary).erase(id)
	else:
		_profile["tree_ranks"][id] = rank


func reload_for_test() -> void:
	_loaded = false
	load_profile()


func get_base_path_for_test() -> String:
	return _base_path


func is_loaded_for_test() -> bool:
	return _loaded


func get_all_ranks_for_test() -> Dictionary:
	return (_profile.get("tree_ranks", {}) as Dictionary).duplicate()


# --- Loading -----------------------------------------------------------------

func ensure_loaded() -> void:
	if not _loaded:
		load_profile()


func load_profile() -> void:
	_profile = _load_from_disk()
	_loaded = true
	_ever_loaded = true


func _load_from_disk() -> Dictionary:
	var real_path: String = _path(PROFILE_FILENAME)
	var bak_path: String = _path(BACKUP_FILENAME)
	var tmp_path: String = _path(TMP_FILENAME)

	if FileAccess.file_exists(real_path):
		var parsed: Variant = _try_parse_file(real_path)
		if parsed is Dictionary:
			return _reconcile(_migrate(parsed as Dictionary))
		# Corrupt: keep a forensic copy, then fall back to .bak, then fresh.
		_copy_file(real_path, _path(CORRUPT_FILENAME))
		var from_bak: Dictionary = _load_from_backup(bak_path)
		if not from_bak.is_empty():
			(from_bak["flags"] as Dictionary)["recovered_from_corruption"] = true
			return from_bak
		var fresh: Dictionary = _fresh_profile()
		(fresh["flags"] as Dictionary)["recovered_from_corruption"] = true
		return fresh

	# BUGFIX (blind review of the meta layer, finding #5): docs/24 section 2
	# itself already names the risk -- "DirAccess.rename, which replaces on
	# Windows through Godot's implementation" is not guaranteed atomic on
	# every platform. profile.json missing while profile.json.tmp is still
	# sitting there, fully written and parseable, means a save's rename step
	# never completed (or completed only partially): the .tmp IS the newest
	# COMPLETE write -- newer than whatever `.bak` holds -- so it is loaded
	# ahead of the backup rather than treated as leftover garbage from an
	# interrupted write (which `_write_atomic()`'s own header already
	# documents `.tmp` normally being, in the ALREADY-handled case where
	# `profile.json` itself survived that same interruption untouched).
	if FileAccess.file_exists(tmp_path):
		var parsed_tmp: Variant = _try_parse_file(tmp_path)
		if parsed_tmp is Dictionary:
			return _reconcile(_migrate(parsed_tmp as Dictionary))

	if FileAccess.file_exists(bak_path):
		var from_bak2: Dictionary = _load_from_backup(bak_path)
		if not from_bak2.is_empty():
			return from_bak2

	return _fresh_profile()


func _load_from_backup(bak_path: String) -> Dictionary:
	if not FileAccess.file_exists(bak_path):
		return {}
	var parsed: Variant = _try_parse_file(bak_path)
	if parsed is Dictionary:
		return _reconcile(_migrate(parsed as Dictionary))
	return {}


func _try_parse_file(path: String) -> Variant:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


## See class header, "Schema version / migration table." Applies each step
## forward in turn (docs/24 section 5's own `migrate_N_to_N_plus_1` naming),
## then falls through to the "newer than this code" guard, which stays
## correct regardless of how many steps ran first (a profile two versions
## newer than this build is still marked read-only after migrating as far
## as this code understands).
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", 0))
	var d: Dictionary = data
	if version < 2:
		d = _migrate_1_to_2(d)
		version = 2
	if version < 3:
		d = _migrate_2_to_3(d)
		version = 3
	if version > SCHEMA_VERSION:
		d = d.duplicate(true)
		var flags: Dictionary = d.get("flags", {})
		if not (flags is Dictionary):
			flags = {}
		flags["read_only_newer_version"] = true
		d["flags"] = flags
		return d
	return d


## Schema version 2 (D118, 2026-09-23): see class header. A v1 profile
## (schema_version 0 or 1 -- 0 covers a profile hand-edited to strip the key
## entirely) gains the three lifetime-achievement fields at their correct
## historical value: zero/empty, since achievements did not exist yet.
func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	if not d.has("lifetime_kills"):
		d["lifetime_kills"] = 0
	if not d.has("lifetime_scrap_collected"):
		d["lifetime_scrap_collected"] = 0
	if not d.has("unlocked_achievement_ids"):
		d["unlocked_achievement_ids"] = []
	d["schema_version"] = 2
	return d


## Schema version 3 (D252): see class header. Refunds every Core spent on the
## v2 tree at the v2 prices, clears the ranks, sets the one-time notice flag and
## leaves the v1.0 fields to `_reconcile()` (zero: no past run is credited).
func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var refund: int = 0
	var raw_ranks: Variant = d.get("tree_ranks", {})
	if raw_ranks is Dictionary:
		for id in (raw_ranks as Dictionary).keys():
			var tier: int = int(V2_NODE_TIERS.get(String(id), 1)) # an id v2 never authored: the cheapest tier, as _reconcile() does
			var rank: int = maxi(0, int((raw_ranks as Dictionary)[id]))
			for r in range(1, rank + 1):
				refund += int(round(float(V2_TIER_BASE_COST[tier]) * (1.0 + 0.5 * float(r - 1))))
	d["tree_ranks"] = {}
	d["cores"] = clampi(int(d.get("cores", 0)) + refund, 0, CORE_WALLET_CAP)
	d["tree_migrated_v3_notice"] = true
	d["v3_refund_amount"] = refund
	d["schema_version"] = 3
	return d


## See class header, "Reconciliation." Always returns a COMPLETE, freshly
## shaped profile Dictionary (every key defaulted), never a passthrough of
## `data` -- a hand-edited or partially-written file missing a key must
## never propagate a missing key into live state.
func _reconcile(data: Dictionary) -> Dictionary:
	var profile: Dictionary = _fresh_profile()
	profile["schema_version"] = SCHEMA_VERSION
	profile["cores"] = clampi(int(data.get("cores", 0)), 0, CORE_WALLET_CAP)
	profile["lifetime_cores"] = maxi(0, int(data.get("lifetime_cores", 0)))
	profile["first_hub_seen"] = bool(data.get("first_hub_seen", false))
	profile["first_run_hints_seen"] = bool(data.get("first_run_hints_seen", false))
	var seen_hints: Array = []
	var raw_hints: Variant = data.get("hints_seen", [])
	if raw_hints is Array:
		for v in (raw_hints as Array):
			var hint_id: String = String(v)
			if hint_id != "" and not seen_hints.has(hint_id):
				seen_hints.append(hint_id)
	profile["hints_seen"] = seen_hints
	# PT-UI (docs/33 A3/A4): Field Guide discoveries and shown explainers; additive id lists, no schema bump.
	profile["discovered_ids"] = _clean_id_list(data.get("discovered_ids", []))
	profile["explainers_seen"] = _clean_id_list(data.get("explainers_seen", []))
	profile["lifetime_kills"] = maxi(0, int(data.get("lifetime_kills", 0)))
	profile["lifetime_scrap_collected"] = maxi(0, int(data.get("lifetime_scrap_collected", 0)))
	_reconcile_v3_fields(profile, data)

	var raw_unlocked: Variant = data.get("unlocked_achievement_ids", [])
	if raw_unlocked is Array:
		var unlocked: Array[String] = []
		for v in (raw_unlocked as Array):
			var achievement_id: String = String(v)
			# An id no longer authored (achievements.tres content changed
			# since this profile was saved) is dropped silently -- unlike a
			# Skill Tree rank, an unlocked achievement carries no Cores to
			# refund, so there is nothing here for reconciliation to restore.
			if achievement_list == null or achievement_list.get_achievement(achievement_id) != null:
				if not unlocked.has(achievement_id):
					unlocked.append(achievement_id)
		profile["unlocked_achievement_ids"] = unlocked

	var records: Variant = data.get("records", {})
	if records is Dictionary:
		var r: Dictionary = profile["records"]
		r["best_waves_cleared"] = int((records as Dictionary).get("best_waves_cleared", 0))
		r["best_kills"] = int((records as Dictionary).get("best_kills", 0))
		r["best_survival_seconds"] = float((records as Dictionary).get("best_survival_seconds", 0.0))
		r["runs_settled"] = int((records as Dictionary).get("runs_settled", 0))
		r["victories"] = int((records as Dictionary).get("victories", 0))

	var settled_ids: Variant = data.get("settled_run_ids", [])
	if settled_ids is Array:
		var ids: Array = []
		for v in (settled_ids as Array):
			ids.append(String(v))
		while ids.size() > MAX_SETTLED_RUN_IDS:
			ids.pop_front()
		profile["settled_run_ids"] = ids

	var flags: Variant = data.get("flags", {})
	if flags is Dictionary:
		var f: Dictionary = profile["flags"]
		f["last_save_failed"] = bool((flags as Dictionary).get("last_save_failed", false))
		f["recovered_from_corruption"] = bool((flags as Dictionary).get("recovered_from_corruption", false))
		f["read_only_newer_version"] = bool((flags as Dictionary).get("read_only_newer_version", false))

	var raw_ranks: Variant = data.get("tree_ranks", {})
	var refund: int = 0
	if raw_ranks is Dictionary:
		for id in (raw_ranks as Dictionary).keys():
			var stored_rank: int = int((raw_ranks as Dictionary)[id])
			if stored_rank <= 0:
				continue
			var node: SkillNodeDefinition = skill_tree.get_node_definition(String(id)) if skill_tree != null else null
			if node == null:
				# Unknown id (removed from the authored tree since this
				# profile was saved). No tier is knowable any more; tier 1
				# (the cheapest) is used as the conservative refund floor --
				# an industry-standard reconciliation choice recorded here,
				# not a Register-stated rule (docs/18 is silent).
				refund += _cost_of_ranks(1, 1, stored_rank)
				continue
			var clamped_rank: int = mini(stored_rank, node.max_rank)
			if clamped_rank > 0:
				(profile["tree_ranks"] as Dictionary)[String(id)] = clamped_rank
			if stored_rank > node.max_rank:
				refund += _cost_of_ranks(node.tier, node.max_rank + 1, stored_rank)
	if refund > 0:
		profile["cores"] = clampi(int(profile["cores"]) + refund, 0, CORE_WALLET_CAP)
	if not _skill_unlocked_in(profile["tree_ranks"], String(profile["selected_battle_skill"])):
		profile["selected_battle_skill"] = RunConfig.DEFAULT_BATTLE_SKILL_ID
	_reconcile_loadout(profile, data)
	return profile


## WP-LOADOUT (docs/32 C3): the Champion and Relic choices are validated against
## the unlocks DERIVED from the reconciled achievements and boss kills. A locked
## or unknown Champion falls back to Ranger; a locked, unknown or duplicate
## Relic is dropped; slot 2 needs a victory.
func _reconcile_loadout(profile: Dictionary, data: Dictionary) -> void:
	var champion: String = String(data.get("selected_champion", LoadoutCatalog.DEFAULT_CHAMPION_ID))
	if not LoadoutCatalog.is_champion(champion) or not _loadout_item_unlocked_in(profile, champion):
		champion = LoadoutCatalog.DEFAULT_CHAMPION_ID
	profile["selected_champion"] = champion
	var kept: Array = []
	var raw: Variant = data.get("selected_relics", [])
	if raw is Array:
		for v in (raw as Array):
			var id: String = String(v)
			if kept.size() < _relic_slot_count_in(profile) and LoadoutCatalog.is_relic(id) and not kept.has(id) and _loadout_item_unlocked_in(profile, id):
				kept.append(id)
	profile["selected_relics"] = kept


## True when `profile` (a reconciled or live profile Dictionary) has earned the
## Champion or Relic: its unlock achievement is held, or its boss has been killed.
func _loadout_item_unlocked_in(profile: Dictionary, id: String) -> bool:
	var rule: Dictionary = LoadoutCatalog.unlock_rule(id)
	if rule.is_empty():
		return LoadoutCatalog.is_champion(id) or LoadoutCatalog.is_relic(id)
	if rule.has("achievement"):
		return (profile.get("unlocked_achievement_ids", []) as Array).has(String(rule["achievement"]))
	if rule.has("boss"):
		return int((profile.get("lifetime_boss_kills", {}) as Dictionary).get(String(rule["boss"]), 0)) > 0
	return false


func _relic_slot_count_in(profile: Dictionary) -> int:
	var won: bool = int((profile.get("records", {}) as Dictionary).get("victories", 0)) > 0
	for id in DIFFICULTY_IDS:
		if int((profile.get("difficulty_victories", {}) as Dictionary).get(id, 0)) > 0:
			won = true
	return LoadoutCatalog.RELIC_SLOTS_MAX if won else LoadoutCatalog.RELIC_SLOTS_BASE


## v3 fields (D252): every value clamped, every key defaulted, an unknown
## difficulty/skill id falling back to the default, and a selection that is not
## unlocked falling back too (a hand-edited profile cannot start a locked run).
func _reconcile_v3_fields(profile: Dictionary, data: Dictionary) -> void:
	var raw_victories: Variant = data.get("difficulty_victories", {})
	var victories: Dictionary = profile["difficulty_victories"]
	if raw_victories is Dictionary:
		for id in DIFFICULTY_IDS:
			victories[id] = maxi(0, int((raw_victories as Dictionary).get(id, 0)))
	var raw_bosses: Variant = data.get("lifetime_boss_kills", {})
	var bosses: Dictionary = profile["lifetime_boss_kills"]
	if raw_bosses is Dictionary:
		for id in BOSS_IDS:
			bosses[id] = maxi(0, int((raw_bosses as Dictionary).get(id, 0)))
	profile["lifetime_elite_kills"] = maxi(0, int(data.get("lifetime_elite_kills", 0)))
	profile["lifetime_repair"] = maxi(0, int(data.get("lifetime_repair", 0)))
	profile["runs_played"] = maxi(0, int(data.get("runs_played", 0)))
	profile["best_endless_wave"] = maxi(0, int(data.get("best_endless_wave", 0)))
	profile["tree_migrated_v3_notice"] = bool(data.get("tree_migrated_v3_notice", false))
	profile["v3_refund_amount"] = maxi(0, int(data.get("v3_refund_amount", 0)))
	var any_victory: bool = false
	for id in DIFFICULTY_IDS:
		if int(victories[id]) > 0:
			any_victory = true
	profile["endless_unlocked"] = bool(data.get("endless_unlocked", false)) or any_victory
	profile["selected_endless"] = bool(data.get("selected_endless", false)) and bool(profile["endless_unlocked"])
	var difficulty: String = String(data.get("selected_difficulty", RunConfig.DEFAULT_DIFFICULTY_ID))
	if not DIFFICULTY_IDS.has(difficulty) or not _difficulty_unlocked_in(victories, difficulty):
		difficulty = RunConfig.DEFAULT_DIFFICULTY_ID
	profile["selected_difficulty"] = difficulty
	var skill: String = String(data.get("selected_battle_skill", RunConfig.DEFAULT_BATTLE_SKILL_ID))
	if not AbilityIds.BATTLE_SKILLS.has(skill):
		skill = RunConfig.DEFAULT_BATTLE_SKILL_ID
	profile["selected_battle_skill"] = skill # a locked skill is corrected once the tree ranks are reconciled, in _reconcile()


static func _difficulty_unlocked_in(victories: Dictionary, id: String) -> bool:
	var required: String = RunConfig.get_difficulty_by_id(id).unlocked_by_victory_on
	return required == "" or int(victories.get(required, 0)) > 0


## True when `ranks` (a tree_ranks Dictionary) owns the node that unlocks `skill_id`.
func _skill_unlocked_in(ranks: Dictionary, skill_id: String) -> bool:
	if skill_id == RunConfig.DEFAULT_BATTLE_SKILL_ID:
		return true
	if skill_tree == null:
		return false
	for node in skill_tree.nodes:
		if node != null and node.effect_kind == SkillNodeDefinition.EffectKind.BATTLE_SKILL_UNLOCK and node.unlock_id == skill_id:
			return int(ranks.get(node.id, 0)) > 0
	return false


static func _cost_of_ranks(node_tier: int, from_rank: int, to_rank: int) -> int:
	var total: int = 0
	for r in range(from_rank, to_rank + 1):
		total += SkillNodeDefinition.price_for_rank(node_tier, r)
	return total


func _fresh_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"cores": 0,
		"lifetime_cores": 0,
		"tree_ranks": {},
		"records": {
			"best_waves_cleared": 0,
			"best_kills": 0,
			"best_survival_seconds": 0.0,
			"runs_settled": 0,
			"victories": 0,
		},
		"settled_run_ids": [],
		"first_hub_seen": false,
		"first_run_hints_seen": false, # UX review item 4 (D129); additive key, no schema bump
		"hints_seen": [], # D241: contextual hint ids already shown; additive key, no schema bump
		"discovered_ids": [], # PT-UI: Field Guide entries the player has met; additive key, no schema bump
		"explainers_seen": [], # PT-UI: first-encounter explainer ids already shown; additive key, no schema bump
		"flags": {
			"last_save_failed": false,
			"recovered_from_corruption": false,
			"read_only_newer_version": false,
		},
		"lifetime_kills": 0,
		"lifetime_scrap_collected": 0,
		"unlocked_achievement_ids": [],
		"selected_difficulty": RunConfig.DEFAULT_DIFFICULTY_ID,
		"selected_battle_skill": RunConfig.DEFAULT_BATTLE_SKILL_ID,
		"selected_endless": false,
		"selected_champion": LoadoutCatalog.DEFAULT_CHAMPION_ID, # WP-LOADOUT (docs/32 C3); additive key, no schema bump
		"selected_relics": [],
		"difficulty_victories": {"recruit": 0, "soldier": 0, "veteran": 0, "warlord": 0},
		"endless_unlocked": false,
		"best_endless_wave": 0,
		"lifetime_elite_kills": 0,
		"lifetime_boss_kills": {"warchief": 0, "king": 0},
		"lifetime_repair": 0,
		"runs_played": 0,
		"tree_migrated_v3_notice": false,
		"v3_refund_amount": 0,
	}


func _path(filename: String) -> String:
	return _base_path.path_join(filename)


# --- Saving ------------------------------------------------------------------

## Guarded on "never redirected AND never loaded" (see class header, "Never
## touches the real user://profile.json unless asked to"): `buy()`/
## `respec()`/`settle_run()` still update the in-memory profile and emit
## their signals even when this returns false, so a caller that never
## unlocked persistence still behaves correctly in-process -- it just never
## writes to disk. Two independent ways to unlock a real write, matching how
## this Autoload is actually used:
##   1. `ensure_loaded()`/`load_profile()` ran (`_ever_loaded`) -- the real
##      production path (the Hub's own `_ready()`).
##   2. `set_base_path_for_test()` redirected `_base_path` away from the
##      default `user://` -- a test's explicit opt-in to real (but
##      throwaway-directory) disk I/O, with no separate load call required.
## This is what keeps every OTHER existing test that reaches this Autoload
## without ever calling either (an existing test exercising
## `RunFlowController._end_run()`, for instance, with no idea this Autoload
## exists) from ever writing to the real `user://profile.json`: a session
## that neither redirected nor loaded has nothing real to overwrite, and is
## never allowed to invent one.
func _save() -> bool:
	if _base_path == "user://" and not _ever_loaded:
		return false
	if bool((_profile.get("flags", {}) as Dictionary).get("read_only_newer_version", false)):
		return false # never clobber a newer-schema file with this older build's understanding of it
	# BUGFIX (blind review of the meta layer, finding #3): the flag must be
	# cleared BEFORE `_write_atomic()` serialises `_profile`, not after --
	# `_write_atomic()` writes THIS dictionary verbatim, so setting the flag
	# only afterward meant a SUCCESSFUL save still wrote the PREVIOUS
	# attempt's "last_save_failed: true" into the new profile.json, and only
	# corrected the in-memory copy too late to matter. Set optimistically
	# false first (this write, if it succeeds, has no failure to report);
	# if the write itself then fails, it never touched the real file at all
	# (see `_write_atomic()`'s own header), so correcting it back to true
	# afterward is purely an in-memory signal for the Hub's warning banner,
	# picked up correctly by whichever save succeeds next.
	(_profile["flags"] as Dictionary)["last_save_failed"] = false
	var ok: bool = _write_atomic(_profile)
	(_profile["flags"] as Dictionary)["last_save_failed"] = not ok
	profile_saved.emit(ok)
	return ok


## See class header, "Atomic save". The real `profile.json` is touched only
## by the final `rename()` call -- everything before it only ever creates or
## overwrites `.tmp`/`.bak`, so a kill at either injectable failure point
## leaves whatever `profile.json` already held completely intact.
func _write_atomic(profile: Dictionary) -> bool:
	var tmp_path: String = _path(TMP_FILENAME)
	var real_path: String = _path(PROFILE_FILENAME)
	var bak_path: String = _path(BACKUP_FILENAME)

	DirAccess.make_dir_recursive_absolute(_base_path) # user:// always exists already; a test's throwaway dir may not yet

	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("MetaProgress: could not open '%s' for writing (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()

	if _test_fail_after_tmp_write:
		return false

	# BUGFIX (blind review of the meta layer, finding #4): a `profile.json`
	# that failed to parse at the LAST load (e.g. this session recovered via
	# `.bak` after a corruption -- see `_load_from_disk()`) is never deleted
	# or rewritten by the load itself; it just sits there until the NEXT
	# save. Backing THAT file up unconditionally would overwrite the one
	# good `.bak` a corruption recovery depends on with more garbage, the
	# very next time anything saves. Re-validating here (rather than trusting
	# a "did the last load parse OK" flag, which could go stale across a
	# process restart) means a save NEVER backs up a file that cannot
	# actually be read back -- this write's own successful rename below
	# simply replaces the broken file with fresh, valid data either way.
	if FileAccess.file_exists(real_path):
		if _try_parse_file(real_path) is Dictionary:
			if not _copy_file(real_path, bak_path):
				push_error("MetaProgress: could not write backup '%s'" % bak_path)
				return false
		# else: real_path failed to parse -- this is the expected, already-
		# handled corruption-recovery case (see `_load_from_disk()`, which
		# already copied it to `profile.corrupt.json` and set
		# `recovered_from_corruption`), not a new failure to log here. The
		# backup step is skipped silently; this write's own rename below
		# still replaces the broken file with fresh, valid data.

	if _test_fail_after_bak_write:
		return false

	var dir: DirAccess = DirAccess.open(_base_path)
	if dir == null:
		push_error("MetaProgress: could not open directory '%s' to rename the profile into place" % _base_path)
		return false
	var rename_err: Error = dir.rename(tmp_path, real_path)
	if rename_err != OK:
		push_error("MetaProgress: rename '%s' -> '%s' failed (%s)" % [tmp_path, real_path, error_string(rename_err)])
		return false
	return true


func _copy_file(src: String, dst: String) -> bool:
	if not FileAccess.file_exists(src):
		return false
	var data: PackedByteArray = FileAccess.get_file_as_bytes(src)
	var f: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return true


# --- Public API (build brief item 2) -----------------------------------------

func get_cores() -> int:
	return int(_profile.get("cores", 0))


## The root is always owned (free, never purchased, and never given an
## explicit `tree_ranks` entry -- see `respec()`'s own comment) but is still
## a legitimate `prerequisite_ids` target for every tier-1 node (docs/18
## section 4.1). Reporting it as rank 1 here, rather than 0, is what makes
## `_prerequisites_met()`'s uniform "every prerequisite has rank >= 1" check
## correct for tier-1 nodes without a special case at every call site.
## Harmless everywhere else `get_rank()` is read: `price_of_next_rank()`/
## `can_buy()` both refuse the root before ever reaching this value (`tier
## <= 0`), and `respec()`/`build_run_loadout()` read `tree_ranks` and
## `skill_tree.nodes` respectively, never gaining a phantom root entry.
func get_rank(id: String) -> int:
	if skill_tree != null and id == skill_tree.root_id:
		return 1
	return int((_profile.get("tree_ranks", {}) as Dictionary).get(id, 0))


func get_records() -> Dictionary:
	return (_profile.get("records", {}) as Dictionary).duplicate()


## Read-only query (Records panel: docs/18 section 5, "lifetime Cores
## earned"). `lifetime_cores` is a top-level profile field, not part of
## `get_records()`'s own dictionary (`_fresh_profile()`'s shape) -- a
## dedicated query rather than folding it into `get_records()`'s existing,
## already-asserted-on shape.
func get_lifetime_cores() -> int:
	return int(_profile.get("lifetime_cores", 0))


## D118 (achievements). Read-only queries (Achievements panel, Hub).
func get_lifetime_kills() -> int:
	return int(_profile.get("lifetime_kills", 0))


func get_lifetime_scrap_collected() -> int:
	return int(_profile.get("lifetime_scrap_collected", 0))


func is_achievement_unlocked(id: String) -> bool:
	return (_profile.get("unlocked_achievement_ids", []) as Array).has(id)


func get_unlocked_achievement_ids() -> Array[String]:
	var out: Array[String] = []
	for v in (_profile.get("unlocked_achievement_ids", []) as Array):
		out.append(String(v))
	return out


## Typed query (UpgradeSystem's own run-start seam:
## `set_unlocked_card_ids()`, read by `src/integration/prototype_
## integration.gd` once at run start). Every `unlocks_card_id` named by an
## unlocked achievement, in authoring order -- an UNLOCK-gated
## `UpgradeDefinition` (`is_unlock == true`) never offers itself in the
## Draft unless its `unique_id` appears here.
func get_unlocked_card_ids() -> Array[String]:
	var out: Array[String] = []
	if achievement_list == null:
		return out
	for id in get_unlocked_achievement_ids():
		var achievement: AchievementDefinition = achievement_list.get_achievement(id)
		if achievement != null and achievement.unlocks_card_id != "":
			out.append(achievement.unlocks_card_id)
	return out


## Typed query (MetaLoadoutApplier's own run-start seam). True once the
## achievement naming `perk_id` as its OWN `perk_id` field is unlocked --
## the reverse lookup of `get_unlocked_card_ids()`, for the three
## non-card-unlock achievements (Hoarder/Founder/Marksman).
func has_perk(perk_id: String) -> bool:
	if achievement_list == null or perk_id == "":
		return false
	for id in get_unlocked_achievement_ids():
		var achievement: AchievementDefinition = achievement_list.get_achievement(id)
		if achievement != null and achievement.perk_id == perk_id:
			return true
	return false


func get_flags() -> Dictionary:
	return (_profile.get("flags", {}) as Dictionary).duplicate()


## Production command (Hub scene: `HubScreen._refresh_warning_banner()`).
## BUGFIX (blind review of the meta layer, finding #3): `recovered_from_
## corruption` used to never be cleared, so the Hub's one-time warning
## banner showed on EVERY future visit, forever, once a profile had ever
## been recovered once. `read_only_newer_version` is a different shape of
## flag -- it reflects a condition that is STILL true (the file on disk
## really is newer, every single visit, until the player upgrades) -- so it
## deliberately has no equivalent "acknowledge" call and is left alone here.
## `first_hub_seen` (`mark_hub_seen()` above) is this exact same "one-time,
## clear it once shown" shape and is this method's own precedent -- the
## Hub's own `_ready()` captures the PRE-clear value locally (`first_visit`)
## before marking it seen, and does the identical thing here (captures the
## flags dict's value for THIS display before calling this).
func acknowledge_recovered_from_corruption() -> void:
	var flags: Dictionary = _profile.get("flags", {})
	if not bool(flags.get("recovered_from_corruption", false)):
		return
	flags["recovered_from_corruption"] = false
	_save()


## UX review item 4 (D129): the three wave-1 hint toasts are shown until the
## whole set has been shown once. Same one-time-flag shape as first_hub_seen.
func is_first_run_hints_seen() -> bool:
	return bool(_profile.get("first_run_hints_seen", false))


func mark_first_run_hints_seen() -> void:
	if is_first_run_hints_seen():
		return
	_profile["first_run_hints_seen"] = true
	_save()


## Review fix (D241): contextual v1.0 hints, each shown once per profile. An
## additive `hints_seen` list of hint ids (reconcile adds it; no schema bump).
func is_hint_seen(hint_id: String) -> bool:
	return (_profile.get("hints_seen", []) as Array).has(hint_id)


func mark_hint_seen(hint_id: String) -> void:
	if hint_id == "" or is_hint_seen(hint_id):
		return
	var seen: Array = _profile.get("hints_seen", [])
	seen.append(hint_id)
	_profile["hints_seen"] = seen
	_save()


## PT-UI (docs/33 A3): Field Guide discovery. An id is recorded the first time the
## player meets the thing (a card shown, an enemy sighted); the Guide shows "???" until then.
func is_discovered(entry_id: String) -> bool:
	return (_profile.get("discovered_ids", []) as Array).has(entry_id)


func mark_discovered(entry_id: String) -> void:
	if entry_id == "" or is_discovered(entry_id):
		return
	var found: Array = _profile.get("discovered_ids", [])
	found.append(entry_id)
	_profile["discovered_ids"] = found
	_save()


func get_discovered_ids() -> Array[String]:
	var out: Array[String] = []
	for v in (_profile.get("discovered_ids", []) as Array):
		out.append(String(v))
	return out


## PT-UI (docs/33 A4): each first-encounter explainer is shown once per profile.
func is_explainer_seen(explainer_id: String) -> bool:
	return (_profile.get("explainers_seen", []) as Array).has(explainer_id)


func mark_explainer_seen(explainer_id: String) -> void:
	if explainer_id == "" or is_explainer_seen(explainer_id):
		return
	var seen: Array = _profile.get("explainers_seen", [])
	seen.append(explainer_id)
	_profile["explainers_seen"] = seen
	_save()


static func _clean_id_list(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in (raw as Array):
			var id: String = str(v)
			if id != "" and not out.has(id):
				out.append(id)
	return out


func is_first_hub_seen() -> bool:
	return bool(_profile.get("first_hub_seen", false))


## Production command (Hub scene, first visit only): saves immediately so
## the flag itself is never lost, matching every other profile mutation's
## own "saves at ... each purchase, each respec" cadence (Register > "Meta:
## Save profile").
func mark_hub_seen() -> void:
	if is_first_hub_seen():
		return
	_profile["first_hub_seen"] = true
	_save()


# --- v1.0 meta loop API (D252-D254) -------------------------------------------

## A selection that is no longer open reads as the default (D243): a locked
## difficulty -> Soldier, a locked Battle Skill -> Arrow Storm.
func get_selected_difficulty() -> String:
	var id: String = String(_profile.get("selected_difficulty", RunConfig.DEFAULT_DIFFICULTY_ID))
	if not DIFFICULTY_IDS.has(id) or not is_difficulty_unlocked(id):
		return RunConfig.DEFAULT_DIFFICULTY_ID
	return id


func get_selected_battle_skill() -> String:
	var id: String = String(_profile.get("selected_battle_skill", RunConfig.DEFAULT_BATTLE_SKILL_ID))
	if not AbilityIds.BATTLE_SKILLS.has(id) or not is_battle_skill_unlocked(id):
		return RunConfig.DEFAULT_BATTLE_SKILL_ID
	return id


func get_selected_endless() -> bool:
	return bool(_profile.get("selected_endless", false)) and is_endless_unlocked()


## Each setter refuses a locked choice (returns false) and saves on success,
## matching every other profile mutation's save cadence.
func set_selected_difficulty(id: String) -> bool:
	if not DIFFICULTY_IDS.has(id) or not is_difficulty_unlocked(id):
		return false
	_profile["selected_difficulty"] = id
	_save()
	return true


func set_selected_battle_skill(id: String) -> bool:
	if not AbilityIds.BATTLE_SKILLS.has(id) or not is_battle_skill_unlocked(id):
		return false
	_profile["selected_battle_skill"] = id
	_save()
	return true


func set_selected_endless(on: bool) -> bool:
	if on and not is_endless_unlocked():
		return false
	_profile["selected_endless"] = on
	_save()
	return true


# --- Loadout: Champions and Relics (WP-LOADOUT, docs/32 C) --------------------------

func is_champion_unlocked(id: String) -> bool:
	return LoadoutCatalog.is_champion(id) and _loadout_item_unlocked_in(_profile, id)


func is_relic_unlocked(id: String) -> bool:
	return LoadoutCatalog.is_relic(id) and _loadout_item_unlocked_in(_profile, id)


func get_unlocked_champions() -> Array[String]:
	var out: Array[String] = []
	for id in LoadoutCatalog.CHAMPION_IDS:
		if is_champion_unlocked(id):
			out.append(id)
	return out


func get_unlocked_relics() -> Array[String]:
	var out: Array[String] = []
	for id in LoadoutCatalog.RELIC_IDS:
		if is_relic_unlocked(id):
			out.append(id)
	return out


## 1 slot at the start, 2 after the first victory (any difficulty).
func get_relic_slot_count() -> int:
	return _relic_slot_count_in(_profile)


## A selection that is no longer open reads as the default, like the Battle Skill.
func get_selected_champion() -> String:
	var id: String = String(_profile.get("selected_champion", LoadoutCatalog.DEFAULT_CHAMPION_ID))
	return id if is_champion_unlocked(id) else LoadoutCatalog.DEFAULT_CHAMPION_ID


## The chosen Relics: unique, unlocked, at most `get_relic_slot_count()`, in slot order.
func get_selected_relics() -> Array[String]:
	var out: Array[String] = []
	for v in (_profile.get("selected_relics", []) as Array):
		var id: String = String(v)
		if out.size() < get_relic_slot_count() and is_relic_unlocked(id) and not out.has(id):
			out.append(id)
	return out


func set_selected_champion(id: String) -> bool:
	if not is_champion_unlocked(id):
		return false
	_profile["selected_champion"] = id
	_save()
	return true


## Puts `id` in relic slot `slot` (0 or 1); "" empties the slot. A relic already in the
## other slot moves (no duplicates); slots stay packed. Refuses a locked relic or a slot
## that is not open yet.
func set_selected_relic(slot: int, id: String) -> bool:
	if slot < 0 or slot >= get_relic_slot_count():
		return false
	if id != "" and not is_relic_unlocked(id):
		return false
	var slots: Array = ["", ""]
	var current: Array[String] = get_selected_relics()
	for i in current.size():
		slots[i] = current[i]
	for i in slots.size():
		if id != "" and slots[i] == id:
			slots[i] = ""
	slots[slot] = id
	var packed: Array = []
	for v in slots:
		if String(v) != "":
			packed.append(String(v))
	_profile["selected_relics"] = packed
	_save()
	return true


## Hub toggle: equips `id` in the first free slot (replacing the oldest when every
## open slot is taken), or removes it when it is already equipped. False if locked.
func toggle_selected_relic(id: String) -> bool:
	if not is_relic_unlocked(id):
		return false
	var list: Array = get_selected_relics()
	if list.has(id):
		list.erase(id)
	else:
		list.append(id)
		while list.size() > get_relic_slot_count():
			list.remove_at(0)
	_profile["selected_relics"] = list
	_save()
	return true


## Boss kills recorded directly (tests of the boss-derived Relic unlocks).
func set_boss_kills_for_test(boss_id: String, count: int) -> void:
	(_profile["lifetime_boss_kills"] as Dictionary)[boss_id] = maxi(0, count)


## Writes the three persisted choices into `RunConfig` (the Hub calls this
## right before it changes scene; Retry reuses what is already there).
func apply_selection_to_run_config() -> void:
	RunConfig.difficulty_id = get_selected_difficulty()
	RunConfig.battle_skill_id = get_selected_battle_skill()
	RunConfig.endless = get_selected_endless()
	RunConfig.champion_id = get_selected_champion() # WP-LOADOUT: validated like the Battle Skill
	var relics: Array[String] = get_selected_relics()
	RunConfig.relic_ids = relics


func get_difficulty_victories(id: String) -> int:
	return int((_profile.get("difficulty_victories", {}) as Dictionary).get(id, 0))


## "" unlock condition = open; otherwise the named difficulty must have been won.
func is_difficulty_unlocked(id: String) -> bool:
	return _difficulty_unlocked_in(_profile.get("difficulty_victories", {}), id)


## The difficulty a first victory on `won_id` newly opens ("" if none, or if it
## was already open before this call's own increment).
func _difficulty_unlocked_by(won_id: String) -> String:
	for id in DIFFICULTY_IDS:
		if RunConfig.get_difficulty_by_id(id).unlocked_by_victory_on == won_id and get_difficulty_victories(won_id) == 1:
			return id
	return ""


func is_endless_unlocked() -> bool:
	return bool(_profile.get("endless_unlocked", false))


func get_best_endless_wave() -> int:
	return int(_profile.get("best_endless_wave", 0))


func get_lifetime_elite_kills() -> int:
	return int(_profile.get("lifetime_elite_kills", 0))


func get_lifetime_repair() -> int:
	return int(_profile.get("lifetime_repair", 0))


func get_runs_played() -> int:
	return int(_profile.get("runs_played", 0))


func get_lifetime_boss_kills(boss_id: String) -> int:
	return int((_profile.get("lifetime_boss_kills", {}) as Dictionary).get(boss_id, 0))


## A Battle Skill is open when it is the free default, or the tree node that
## names it in `unlock_id` is owned.
func is_battle_skill_unlocked(skill_id: String) -> bool:
	return _skill_unlocked_in(_profile.get("tree_ranks", {}), skill_id)


func get_unlocked_battle_skills() -> Array[String]:
	var out: Array[String] = []
	for id in AbilityIds.BATTLE_SKILLS:
		if is_battle_skill_unlocked(id):
			out.append(id)
	return out


## The tree node id that unlocks `skill_id` ("" for the free default).
func get_battle_skill_unlock_node_id(skill_id: String) -> String:
	if skill_tree == null:
		return ""
	for node in skill_tree.nodes:
		if node != null and node.effect_kind == SkillNodeDefinition.EffectKind.BATTLE_SKILL_UNLOCK and node.unlock_id == skill_id:
			return node.id
	return ""


## One-time Hub notice after the v2 -> v3 migration (D252).
func has_v3_notice() -> bool:
	return bool(_profile.get("tree_migrated_v3_notice", false))


func get_v3_refund_amount() -> int:
	return int(_profile.get("v3_refund_amount", 0))


func acknowledge_v3_notice() -> void:
	if not has_v3_notice():
		return
	_profile["tree_migrated_v3_notice"] = false
	_save()


## Achievements panel (D251): {"current": float, "target": float, "fraction":
## float, "per_run": bool, "unlocked": bool}. Per-run metrics report 0 outside a run.
func get_achievement_progress(id: String) -> Dictionary:
	var achievement: AchievementDefinition = achievement_list.get_achievement(id) if achievement_list != null else null
	if achievement == null:
		return {}
	var unlocked: bool = is_achievement_unlocked(id)
	var per_run: bool = achievement.metric.begins_with("run_")
	var current: float = 0.0 if per_run else maxf(0.0, _metric_value(achievement.metric, {}))
	var target: float = achievement.threshold
	if unlocked:
		current = maxf(current, target)
	return {
		"current": current, "target": target,
		"fraction": clampf(current / target, 0.0, 1.0) if target > 0.0 else 1.0,
		"per_run": per_run, "unlocked": unlocked,
	}


## `id == root_id` -> full info (owned, and free). Otherwise: full info if
## owned OR any ONE `prerequisite_ids` entry is owned; a silhouette (false)
## otherwise. docs/18 section 4.1: "A node is revealed ... once it is owned
## or any ONE of its `prerequisite_ids` is owned" -- deliberately a looser
## gate than `can_buy()` (which requires EVERY prerequisite), so the two
## tier-3 convergence nodes (needing both tier-2 siblings) reveal as soon as
## either sibling is taken, before they are actually buyable.
func is_visible(id: String) -> bool:
	if skill_tree == null:
		return false
	if id == skill_tree.root_id:
		return true
	var node: SkillNodeDefinition = skill_tree.get_node_definition(id)
	if node == null:
		return false
	if get_rank(id) > 0:
		return true
	for prereq in node.prerequisite_ids:
		if get_rank(prereq) > 0:
			return true
	return false


## -1 if `id` is unknown, is the root (never purchased), or is already at
## `max_rank`.
func price_of_next_rank(id: String) -> int:
	var node: SkillNodeDefinition = skill_tree.get_node_definition(id) if skill_tree != null else null
	if node == null or node.tier <= 0:
		return -1
	var current_rank: int = get_rank(id)
	if current_rank >= node.max_rank:
		return -1
	return SkillNodeDefinition.price_for_rank(node.tier, current_rank + 1)


## docs/18 section 4.1: "A node can be bought once EVERY node in its
## `prerequisite_ids` is owned at rank >= 1."
func _prerequisites_met(node: SkillNodeDefinition) -> bool:
	for prereq in node.prerequisite_ids:
		if get_rank(prereq) <= 0:
			return false
	return true


## Read-only query (Hub/Skill Tree screen). Whether every one of `id`'s
## prerequisites is owned at rank >= 1 -- the SAME gate `can_buy()` applies
## internally (`_prerequisites_met()`), exposed publicly so the screen can
## tell "revealed but a prerequisite still missing" (docs/18 section 4.1's
## dim/locked state, shown with a price in place but no purchase possible)
## apart from "prerequisites met but too few Cores" (the separate red-price
## state) without duplicating this Autoload's own rule. The root and any
## unknown id both report true (the root has no prerequisites of its own;
## an unknown id has nothing to be locked behind).
func prerequisites_met(id: String) -> bool:
	if skill_tree != null and id == skill_tree.root_id:
		return true
	var node: SkillNodeDefinition = skill_tree.get_node_definition(id) if skill_tree != null else null
	if node == null:
		return true
	return _prerequisites_met(node)


## Read-only query (Hub/Skill Tree screen's Reset Tree control: docs/18
## section 4.5, "Respec ... shows the refund amount" before the hold-to-
## confirm completes). Mirrors `respec()`'s own refund arithmetic exactly
## (`_cost_of_ranks(node.tier, 1, rank)` per owned node) without mutating
## anything -- `respec()` itself remains the only writer.
func get_respec_refund_preview() -> int:
	var ranks: Dictionary = _profile.get("tree_ranks", {})
	var refund: int = 0
	for id in ranks.keys():
		var node: SkillNodeDefinition = skill_tree.get_node_definition(String(id)) if skill_tree != null else null
		if node != null:
			refund += _cost_of_ranks(node.tier, 1, int(ranks[id]))
	return refund


func can_buy(id: String) -> bool:
	if bool((_profile.get("flags", {}) as Dictionary).get("read_only_newer_version", false)):
		return false
	var node: SkillNodeDefinition = skill_tree.get_node_definition(id) if skill_tree != null else null
	if node == null or node.tier <= 0:
		return false
	if get_rank(id) >= node.max_rank:
		return false
	if not _prerequisites_met(node):
		return false
	var price: int = price_of_next_rank(id)
	return price >= 0 and get_cores() >= price


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var price: int = price_of_next_rank(id)
	var new_rank: int = get_rank(id) + 1
	(_profile["tree_ranks"] as Dictionary)[id] = new_rank
	_profile["cores"] = clampi(get_cores() - price, 0, CORE_WALLET_CAP)
	_save()
	cores_changed.emit(get_cores())
	rank_changed.emit(id, new_rank)
	return true


## Register > "Meta: Skill Tree costs": "respec is free and full, Hub only"
## (D111). Refunds every Core ever spent across every owned node and clears
## every rank; the root is untouched (it is never a `tree_ranks` entry --
## always owned, never purchased). Returns the amount ACTUALLY credited to
## the wallet, after the Register's own 999,999 cap clamp.
##
## BUGFIX (blind review of the meta layer, finding #6): this used to return
## the raw, pre-clamp refund total even when the wallet cap silently
## absorbed part of it -- a player a few Cores under the cap could respec a
## tree worth hundreds of Cores, see "refunded 200" (or whatever the Hub/
## Skill Tree screen showed from this return value), and have the wallet
## actually gain only a handful, with the rest silently discarded. Mirrors
## `settle_run()`'s own identical `cores_after - cores_before` fix.
func respec() -> int:
	if bool((_profile.get("flags", {}) as Dictionary).get("read_only_newer_version", false)):
		return 0
	var ranks: Dictionary = _profile["tree_ranks"]
	if ranks.is_empty():
		return 0
	var raw_refund: int = 0
	for id in ranks.keys().duplicate():
		var node: SkillNodeDefinition = skill_tree.get_node_definition(String(id)) if skill_tree != null else null
		var rank: int = int(ranks[id])
		if node != null:
			raw_refund += _cost_of_ranks(node.tier, 1, rank)
		ranks.erase(id)
		rank_changed.emit(String(id), 0)
	var credited: int = 0
	if raw_refund > 0:
		var cores_before: int = get_cores()
		var cores_after: int = clampi(cores_before + raw_refund, 0, CORE_WALLET_CAP)
		credited = cores_after - cores_before # the amount ACTUALLY credited, after the wallet-cap clamp
		_profile["cores"] = cores_after
	# Review fix (D243): a respec re-locks every Battle Skill, so a selected
	# non-default skill is corrected NOW, not on the next load.
	if not is_battle_skill_unlocked(String(_profile.get("selected_battle_skill", RunConfig.DEFAULT_BATTLE_SKILL_ID))):
		_profile["selected_battle_skill"] = RunConfig.DEFAULT_BATTLE_SKILL_ID
	_save()
	cores_changed.emit(get_cores())
	return credited


## Pure settlement preview (review fix, D240): the itemised lines and the total
## a run with `run_summary` would pay, difficulty multiplier included, with no
## wallet clamp and no mutation. `settle_run()` is built on this and the pause
## menu's "estimated Cores" reads it, so the formula exists once. Keys as in
## `settle_run()`; every key is optional.
func preview_settlement(run_summary: Dictionary) -> Dictionary:
	var sim_time: float = float(run_summary.get("sim_time_seconds", 0.0))
	var waves_cleared: int = maxi(0, int(run_summary.get("waves_cleared", 0)))
	var kills: int = maxi(0, int(run_summary.get("kills", 0)))
	var victory: bool = bool(run_summary.get("victory", false))
	var scrap_carried: int = maxi(0, int(run_summary.get("scrap_carried", 0)))
	var difficulty_id: String = String(run_summary.get("difficulty_id", RunConfig.DEFAULT_DIFFICULTY_ID))
	if not DIFFICULTY_IDS.has(difficulty_id):
		difficulty_id = RunConfig.DEFAULT_DIFFICULTY_ID
	var elite_kills: int = maxi(0, int(run_summary.get("elite_kills", 0)))
	var boss_kills: Dictionary = {}
	var raw_boss_kills: Variant = run_summary.get("boss_kills", {})
	if raw_boss_kills is Dictionary:
		for boss_id in BOSS_IDS:
			boss_kills[boss_id] = maxi(0, int((raw_boss_kills as Dictionary).get(boss_id, 0)))
	var difficulty: DifficultyProfile = RunConfig.get_difficulty_by_id(difficulty_id)
	var minutes: int = int(floor(sim_time / 60.0))
	var lines: Array = []
	var subtotal: int = 0

	var minute_cores: int = minutes * SETTLEMENT_PER_MINUTE_CORES
	lines.append({"label": "Time survived (%d min)" % minutes, "amount": minute_cores})
	subtotal += minute_cores

	var wave_cores: int = waves_cleared * SETTLEMENT_PER_WAVE_CLEARED_CORES
	lines.append({"label": "Waves cleared (%d)" % waves_cleared, "amount": wave_cores})
	subtotal += wave_cores

	var kill_cores: int = int(floor(float(kills) / float(SETTLEMENT_KILLS_PER_CORE)))
	lines.append({"label": "Enemies defeated (%d)" % kills, "amount": kill_cores})
	subtotal += kill_cores

	# D115 (no in-run shop): Scrap converts to Cores here, its only
	# remaining sink -- floor(scrap_carried / 10), the same rounding every
	# other settlement term above uses. `scrap_carried` already reflects the
	# Scrap cap and loss-on-death rules (RunFlowController reads
	# RunInventory.scrap_current, which RunInventory itself zeroes on
	# player death -- see run_flow_controller.gd's own class header,
	# "Reading Scrap only after it is truly final").
	var scrap_cores: int = int(floor(float(scrap_carried) / float(SETTLEMENT_SCRAP_PER_CORE)))
	lines.append({"label": "Scrap (%d)" % scrap_carried, "amount": scrap_cores})
	subtotal += scrap_cores

	var elite_each: int = SETTLEMENT_PER_ELITE_CORES
	var run_relics: Variant = run_summary.get("relic_ids", [])
	if run_relics is Array and (run_relics as Array).has("kings_crown"):
		elite_each += LoadoutCatalog.CROWN_CORES_PER_ELITE # King's Crown (docs/32 C2)
	var elite_cores: int = elite_kills * elite_each
	if elite_kills > 0:
		lines.append({"label": "Elites defeated (%d)" % elite_kills, "amount": elite_cores})
		subtotal += elite_cores

	for boss_id in SETTLEMENT_BOSS_CORES.keys():
		var count: int = int(boss_kills.get(boss_id, 0))
		if count > 0:
			var boss_cores: int = count * int(SETTLEMENT_BOSS_CORES[boss_id])
			var boss_name: String = "Goblin Warchief" if boss_id == "warchief" else "Bombardier King"
			lines.append({"label": "%s defeated (%d)" % [boss_name, count], "amount": boss_cores})
			subtotal += boss_cores

	if victory:
		lines.append({"label": "Victory", "amount": SETTLEMENT_VICTORY_CORES})
		subtotal += SETTLEMENT_VICTORY_CORES

	var prospector_rank: int = get_rank("prospector")
	var bonus_fraction: float = float(prospector_rank) * PROSPECTOR_BONUS_PER_RANK
	# D118: Founder's own perk composes additively with Prospector, exactly
	# like Fortress composes with Stone Walls/Arrow Slits in
	# MetaLoadoutApplier -- ONE combined fraction, applied once. D251:
	# Regicide's +10% joins the same fraction.
	if has_perk("settlement_cores_bonus"):
		bonus_fraction += ACHIEVEMENT_SETTLEMENT_CORES_BONUS
	if has_perk("settlement_cores_bonus_regicide"):
		bonus_fraction += ACHIEVEMENT_REGICIDE_CORES_BONUS
	var total: int = subtotal
	if bonus_fraction > 0.0:
		total = int(floor(float(subtotal) * (1.0 + bonus_fraction)))
		lines.append({"label": "Settlement bonus (+%d%%)" % int(round(bonus_fraction * 100.0)), "amount": total - subtotal})
	# D253: the difficulty's Cores multiplier is applied last, to the
	# bonus-inclusive total, and shown as its own line when it is not 1.
	if not is_equal_approx(difficulty.cores_multiplier, 1.0):
		var scaled: int = int(floor(float(total) * difficulty.cores_multiplier))
		lines.append({"label": "%s difficulty (x%s)" % [difficulty.display_name, _trim_float(difficulty.cores_multiplier)], "amount": scaled - total})
		total = scaled

	return {"lines": lines, "total_cores": total}


## Register > "Meta: Run-End Settlement (prototype)" and > "v1.0 Meta
## Progression"; D110/D115/D118/D253. Idempotent by `run_summary.run_id` --
## see class header, "Idempotent settlement". `run_summary` keys: `run_id:
## String`, `sim_time_seconds: float`, `waves_cleared: int`, `kills: int`,
## `victory: bool`, `abandoned: bool`, `scrap_carried: int` (D115),
## `tower_health_fraction: float` (D118) and the v1.0 keys (D253, all
## optional): `difficulty_id: String`, `endless: bool`, `wave_reached: int`,
## `elite_kills: int`, `boss_kills: Dictionary` (id -> count), `repair_total:
## int`, `scrap_collected: int`, `untouchable_wave: bool`, `player_abilities:
## int`. Commits to disk (via `_save()`) before returning, per the build
## brief.
func settle_run(run_summary: Dictionary) -> Dictionary:
	var run_id: String = String(run_summary.get("run_id", ""))
	if run_id != "" and (_profile.get("settled_run_ids", []) as Array).has(run_id):
		if _settled_breakdown_cache.has(run_id):
			# The cached breakdown's OWN "already_settled" reflects whatever it
			# was when first computed (false -- it was a real settlement at the
			# time). A caller re-settling the same run id needs to see THIS
			# call's own truth (a repeat, not a fresh payment), so the flag is
			# overridden on a duplicate rather than replayed verbatim -- the
			# itemised lines/total are kept for display, matching "returns the
			# itemised breakdown" even for a replay.
			var cached: Dictionary = (_settled_breakdown_cache[run_id] as Dictionary).duplicate(true)
			cached["already_settled"] = true
			return cached
		return _already_settled_breakdown(run_id)

	var sim_time: float = float(run_summary.get("sim_time_seconds", 0.0))
	var waves_cleared: int = maxi(0, int(run_summary.get("waves_cleared", 0)))
	var kills: int = maxi(0, int(run_summary.get("kills", 0)))
	var victory: bool = bool(run_summary.get("victory", false))
	var abandoned: bool = bool(run_summary.get("abandoned", false))
	var scrap_carried: int = maxi(0, int(run_summary.get("scrap_carried", 0)))
	var tower_health_fraction: float = float(run_summary.get("tower_health_fraction", 1.0))
	var difficulty_id: String = String(run_summary.get("difficulty_id", RunConfig.DEFAULT_DIFFICULTY_ID))
	if not DIFFICULTY_IDS.has(difficulty_id):
		difficulty_id = RunConfig.DEFAULT_DIFFICULTY_ID
	var endless: bool = bool(run_summary.get("endless", false))
	var wave_reached: int = maxi(0, int(run_summary.get("wave_reached", waves_cleared)))
	var elite_kills: int = maxi(0, int(run_summary.get("elite_kills", 0)))
	var boss_kills: Dictionary = {}
	var raw_boss_kills: Variant = run_summary.get("boss_kills", {})
	if raw_boss_kills is Dictionary:
		for boss_id in BOSS_IDS:
			boss_kills[boss_id] = maxi(0, int((raw_boss_kills as Dictionary).get(boss_id, 0)))
	var repair_total: int = maxi(0, int(run_summary.get("repair_total", 0)))
	var scrap_collected: int = maxi(scrap_carried, int(run_summary.get("scrap_collected", scrap_carried)))

	var preview: Dictionary = preview_settlement(run_summary)
	var lines: Array = preview["lines"]
	var total: int = int(preview["total_cores"])

	var cores_before: int = get_cores()
	var cores_after: int = clampi(cores_before + total, 0, CORE_WALLET_CAP)
	total = cores_after - cores_before # reflects any wallet-cap clamp actually applied

	var records: Dictionary = _profile["records"]
	var new_best_waves: bool = waves_cleared > int(records.get("best_waves_cleared", 0))
	var new_best_kills: bool = kills > int(records.get("best_kills", 0))
	var new_best_survival: bool = sim_time > float(records.get("best_survival_seconds", 0.0))
	records["best_waves_cleared"] = maxi(int(records.get("best_waves_cleared", 0)), waves_cleared)
	records["best_kills"] = maxi(int(records.get("best_kills", 0)), kills)
	records["best_survival_seconds"] = maxf(float(records.get("best_survival_seconds", 0.0)), sim_time)
	records["runs_settled"] = int(records.get("runs_settled", 0)) + 1
	if victory:
		records["victories"] = int(records.get("victories", 0)) + 1

	# D252/D253: the v1.0 profile counters, updated BEFORE achievements run
	# (same rule as the lifetime counters below).
	var unlocked_difficulty: String = ""
	var unlocked_endless: bool = false
	var new_best_endless: bool = false
	_profile["runs_played"] = int(_profile.get("runs_played", 0)) + 1
	_profile["lifetime_elite_kills"] = int(_profile.get("lifetime_elite_kills", 0)) + elite_kills
	_profile["lifetime_repair"] = int(_profile.get("lifetime_repair", 0)) + repair_total
	var lifetime_bosses: Dictionary = _profile["lifetime_boss_kills"]
	for boss_id in BOSS_IDS:
		lifetime_bosses[boss_id] = int(lifetime_bosses.get(boss_id, 0)) + int(boss_kills.get(boss_id, 0))
	if victory:
		var victories: Dictionary = _profile["difficulty_victories"]
		victories[difficulty_id] = int(victories.get(difficulty_id, 0)) + 1
		unlocked_difficulty = _difficulty_unlocked_by(difficulty_id)
		if not bool(_profile.get("endless_unlocked", false)):
			_profile["endless_unlocked"] = true
			unlocked_endless = true
	if endless:
		new_best_endless = wave_reached > int(_profile.get("best_endless_wave", 0))
		_profile["best_endless_wave"] = maxi(int(_profile.get("best_endless_wave", 0)), wave_reached)

	_profile["cores"] = cores_after
	_profile["lifetime_cores"] = int(_profile.get("lifetime_cores", 0)) + maxi(0, total)

	# D118: lifetime counters, updated BEFORE evaluating achievements below,
	# so a threshold crossed exactly on this run's own contribution unlocks
	# on the same settlement that crossed it (e.g. 299 lifetime kills + a
	# 1-kill run reads 300 when Goblin Slayer's own check runs).
	_profile["lifetime_kills"] = int(_profile.get("lifetime_kills", 0)) + kills
	_profile["lifetime_scrap_collected"] = int(_profile.get("lifetime_scrap_collected", 0)) + scrap_collected

	var run_metrics: Dictionary = {
		"run_waves_cleared": float(waves_cleared), # legacy v1 metrics, kept as aliases (D118)
		"run_tower_health_fraction": tower_health_fraction,
		"run_wave_reached": float(wave_reached),
		"run_victory": 1.0 if victory else 0.0,
		"run_victory_tower_fraction": tower_health_fraction if victory else 0.0,
		"run_king_killed_hard": 1.0 if (int(boss_kills.get("king", 0)) > 0 and (difficulty_id == "veteran" or difficulty_id == "warlord")) else 0.0,
		"run_untouchable_wave": 1.0 if bool(run_summary.get("untouchable_wave", false)) else 0.0,
		"run_player_abilities": float(maxi(0, int(run_summary.get("player_abilities", 0)))),
	}
	var newly_unlocked: Array[Dictionary] = _evaluate_achievements(run_metrics)

	if run_id != "":
		var ids: Array = _profile["settled_run_ids"]
		ids.append(run_id)
		while ids.size() > MAX_SETTLED_RUN_IDS:
			ids.pop_front()

	# `_save()` runs BEFORE the breakdown dict is built (not merely before
	# `return`, as the class header's "commits to disk before returning"
	# already required) so `saved` below reflects what actually reached
	# disk this call, not an assumption. Finding #6 (blind review of the
	# meta layer): a read-only-newer-version profile (or any other save
	# failure at this exact moment -- disk full, a permissions error) means
	# these Cores exist only in THIS process's memory; the run-end screen
	# must not claim "+N Cores" were saved when they were not (see
	# src/ui/run_end.gd's own `set_settlement()`).
	var saved: bool = _save()

	var breakdown: Dictionary = {
		"run_id": run_id,
		"already_settled": false,
		"saved": saved,
		"lines": lines,
		"total_cores": total,
		"cores_before": cores_before,
		"cores_after": cores_after,
		"victory": victory,
		"abandoned": abandoned,
		"new_best_waves": new_best_waves,
		"new_best_kills": new_best_kills,
		"new_best_survival_seconds": new_best_survival,
		"newly_unlocked_achievements": newly_unlocked,
		"difficulty_id": difficulty_id,
		"endless": endless,
		"wave_reached": wave_reached,
		"new_best_endless_wave": new_best_endless,
		"unlocked_difficulty": unlocked_difficulty,
		"unlocked_endless": unlocked_endless,
	}
	if run_id != "":
		_settled_breakdown_cache[run_id] = breakdown

	cores_changed.emit(get_cores())
	return breakdown


func _already_settled_breakdown(run_id: String) -> Dictionary:
	return {
		"run_id": run_id, "already_settled": true, "saved": true, "lines": [], "total_cores": 0,
		"cores_before": get_cores(), "cores_after": get_cores(),
		"victory": false, "abandoned": false,
		"new_best_waves": false, "new_best_kills": false, "new_best_survival_seconds": false,
		"newly_unlocked_achievements": [],
		"difficulty_id": RunConfig.DEFAULT_DIFFICULTY_ID, "endless": false, "wave_reached": 0,
		"new_best_endless_wave": false, "unlocked_difficulty": "", "unlocked_endless": false,
	}


## D118. Checks every authored achievement not already unlocked against
## this run's own metric (docs: `AchievementDefinition.metric`'s own
## header). Mutates `unlocked_achievement_ids` for every one newly met and
## returns each as `{"id": ..., "display_name": ...}`, in authoring order,
## for the run-end screen's "Achievement unlocked: ..." lines and the
## breakdown this settlement returns. Lifetime counters (`lifetime_kills`/
## `lifetime_scrap_collected`) must already reflect THIS run's own
## contribution before this runs -- see settle_run()'s own call site.
## D251: `run_metrics` (key -> float) carries the per-run metric values.
func _evaluate_achievements(run_metrics: Dictionary) -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []
	if achievement_list == null:
		return newly_unlocked
	var unlocked: Array = _profile["unlocked_achievement_ids"]
	for achievement in achievement_list.achievements:
		if achievement == null or achievement.id == "" or unlocked.has(achievement.id):
			continue
		var current_value: float = _metric_value(achievement.metric, run_metrics)
		if current_value < 0.0:
			push_warning("MetaProgress._evaluate_achievements(): unknown metric '%s' on achievement '%s'" % [achievement.metric, achievement.id])
			continue
		if current_value >= achievement.threshold:
			unlocked.append(achievement.id)
			newly_unlocked.append({"id": achievement.id, "display_name": achievement.display_name})
	return newly_unlocked


## Current value of one achievement metric (AchievementDefinition's header
## lists them). `run_metrics` carries this run's per-run values; an empty
## Dictionary (the Achievements panel, outside any run) reads them as 0.
## -1.0 marks an unknown metric.
func _metric_value(metric: String, run_metrics: Dictionary) -> float:
	var victories: Dictionary = _profile.get("difficulty_victories", {})
	match metric:
		"lifetime_kills":
			return float(_profile.get("lifetime_kills", 0))
		"lifetime_scrap_collected":
			return float(_profile.get("lifetime_scrap_collected", 0))
		"lifetime_elite_kills":
			return float(_profile.get("lifetime_elite_kills", 0))
		"lifetime_repair":
			return float(_profile.get("lifetime_repair", 0))
		"lifetime_boss_kills_warchief":
			return float((_profile.get("lifetime_boss_kills", {}) as Dictionary).get("warchief", 0))
		"victories_total":
			return float((_profile.get("records", {}) as Dictionary).get("victories", 0))
		"difficulty_victories_warlord":
			return float(victories.get("warlord", 0))
		"best_endless_wave":
			return float(_profile.get("best_endless_wave", 0))
		"runs_played":
			return float(_profile.get("runs_played", 0))
		"run_waves_cleared", "run_tower_health_fraction", "run_wave_reached", "run_victory", "run_victory_tower_fraction", "run_king_killed_hard", "run_untouchable_wave", "run_player_abilities":
			return float(run_metrics.get(metric, 0.0))
	return -1.0


static func _trim_float(value: float) -> String:
	return String.num(value, 2).rstrip("0").rstrip(".")


## Build brief item 3. Reads every OWNED node's effect into a fresh
## `MetaLoadout` -- one flat match over `SkillNodeDefinition.EffectKind` so
## adding a future node kind touches this one function and `MetaLoadout`'s
## own field list, nowhere else.
func build_run_loadout() -> MetaLoadout:
	var loadout: MetaLoadout = MetaLoadout.new()
	if skill_tree == null:
		return loadout
	for node in skill_tree.nodes:
		if node == null or node.id == skill_tree.root_id:
			continue # the root contributes no effect of its own -- see get_rank()'s header on why it now reports rank 1
		var rank: int = get_rank(node.id)
		if rank <= 0:
			continue
		var total_value: float = node.value_per_rank * float(rank)
		match node.effect_kind:
			SkillNodeDefinition.EffectKind.PLAYER_MAX_HEALTH_PERCENT:
				loadout.player_max_health_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_MOVE_SPEED_PERCENT:
				loadout.player_move_speed_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_WEAPON_DAMAGE_PERCENT:
				loadout.player_weapon_damage_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_FIRE_RATE_PERCENT:
				loadout.player_fire_rate_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_MAGNET_RADIUS_PERCENT:
				loadout.player_magnet_radius_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_SECOND_WIND:
				loadout.second_wind_enabled = true
			SkillNodeDefinition.EffectKind.TOWER_MAX_HEALTH_PERCENT:
				loadout.tower_max_health_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_WEAPON_DAMAGE_PERCENT:
				loadout.tower_weapon_damage_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_MAX_SHIELD_PERCENT:
				loadout.tower_max_shield_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_SHIELD_REGEN_RATE_PERCENT:
				loadout.tower_shield_regen_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_WEAPON_RANGE_PERCENT:
				loadout.tower_weapon_range_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_FORTRESS_START:
				loadout.fortress_enabled = true
			SkillNodeDefinition.EffectKind.ECONOMY_STARTING_SCRAP_FLAT:
				loadout.starting_scrap = int(round(total_value))
			SkillNodeDefinition.EffectKind.ECONOMY_XP_GAIN_PERCENT:
				loadout.xp_gain_bonus = total_value
			SkillNodeDefinition.EffectKind.ECONOMY_DRAFT_REROLL_FLAT:
				loadout.bonus_draft_rerolls = int(round(total_value))
			SkillNodeDefinition.EffectKind.ECONOMY_SETTLEMENT_CORES_PERCENT:
				loadout.settlement_cores_bonus = total_value
			SkillNodeDefinition.EffectKind.ECONOMY_SCRAP_CAP_FLAT:
				loadout.scrap_cap_bonus = int(round(total_value))
			SkillNodeDefinition.EffectKind.ECONOMY_WAR_CHEST_START:
				loadout.war_chest_enabled = true
			SkillNodeDefinition.EffectKind.ECONOMY_DRAFT_RARITY_LUCK_FLAT:
				loadout.rarity_luck_points = int(round(total_value))
			SkillNodeDefinition.EffectKind.PLAYER_CRIT_CHANCE:
				loadout.player_crit_chance_bonus = total_value
			SkillNodeDefinition.EffectKind.PLAYER_WEAPON_RANGE_PERCENT:
				loadout.player_weapon_range_bonus = total_value
			SkillNodeDefinition.EffectKind.ARMORY_START_ABILITY:
				loadout.armory_enabled = true
			SkillNodeDefinition.EffectKind.PLAYER_DAMAGE_TAKEN_REDUCTION:
				loadout.damage_taken_reduction = total_value
			SkillNodeDefinition.EffectKind.DASH_COOLDOWN_REDUCTION:
				loadout.dash_cooldown_reduction = total_value
			SkillNodeDefinition.EffectKind.DASH_EXTRA_CHARGE:
				loadout.dash_extra_charges = int(round(total_value))
			SkillNodeDefinition.EffectKind.BATTLE_SKILL_UNLOCK:
				if node.unlock_id != "" and not loadout.unlocked_battle_skills.has(node.unlock_id):
					loadout.unlocked_battle_skills.append(node.unlock_id)
			SkillNodeDefinition.EffectKind.SKILL_COOLDOWN_REDUCTION:
				loadout.skill_cooldown_reduction = total_value
			SkillNodeDefinition.EffectKind.SKILL_DAMAGE_PERCENT:
				loadout.skill_damage_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_REPAIR_PERCENT:
				loadout.tower_repair_bonus = total_value
			SkillNodeDefinition.EffectKind.TOWER_ABILITY_DAMAGE_PERCENT:
				loadout.tower_ability_damage_bonus = total_value
	return loadout

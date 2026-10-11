class_name FieldGuideCatalog
extends RefCounted

## The Field Guide's entries (PT-UI, docs/33 A3; decision D322). Every entry is built from the
## game's own data on each call, so a number on a page is the number the game uses:
## AbilityCatalog (ability levels), data/upgrades/*.tres (passives), data/enemies/*.tres
## (enemy and boss stats), the Register-cited constants on the behaviour and arena scripts, and
## RunEvents / LoadoutCatalog. Only qualitative text lives in UiStrings ("FG_*"); a number is
## never typed into a string where a data source exists. A constant that a later change
## renames or removes reads as "?" rather than breaking the page (`_c`).
##
## Entry: {id, tab, name, icon, helps, hurts, effect, tip, hint, always_known}. The `id` is also
## the icon id (assets/ui/icons/icon_<id>.png) and the key stored in the profile's
## `discovered_ids` / used by the first-encounter explainers.

enum Tab { ABILITIES, PASSIVES, BATTLE_SKILLS, PACTS, ENEMIES, BOSSES, ARENA, LOADOUT }

const TAB_KEYS: Array[String] = [
	"FG_TAB_ABILITIES", "FG_TAB_PASSIVES", "FG_TAB_BATTLE_SKILLS", "FG_TAB_PACTS",
	"FG_TAB_ENEMIES", "FG_TAB_BOSSES", "FG_TAB_ARENA", "FG_TAB_LOADOUT",
]

## Abilities added by the playtest round (PT-POWER): shown with their text until the ability's own
## data lands in AbilityCatalog, then with its live numbers.
const NEW_ABILITY_IDS: Array[String] = ["diagonal_arrows", "ricochet", "lightning_sprite", "meteor_shower", "blade_circle"]
const NEW_PASSIVE_IDS: Array[String] = ["rear_arrow", "shadow_step"]
const ENEMY_IDS: Array[String] = ["tower_seeker", "player_hunter", "opportunist", "bomber", "brute", "goblin_shaman", "elite"]
const BOSS_IDS: Array[String] = ["goblin_warchief", "juggernaut", "bombardier_king"]
const ARENA_IDS: Array[String] = ["supply_crate", "powder_keg", "shrine", "spike_trap", "bridge", "water"]
const BOON_IDS: Array[String] = ["boon_war", "boon_haste", "boon_ward", "boon_bounty"]
const EVENT_IDS: Array[String] = ["opening_pick", "patrons_boon", "sanctuary", "blood_pact"]
const BLESSING_IDS: Array[String] = ["mend", "restore", "valor"]

const UPGRADE_DIR: String = "res://data/upgrades/"
const ENEMY_DIR: String = "res://data/enemies/"
const PLAYER_DATA: String = "res://data/player/prototype.tres"

## The ids the boss events and EventBus use -> the Guide's id.
const BOSS_ID_ALIASES: Dictionary = {"warchief": "goblin_warchief", "king": "bombardier_king"}

const PATH_WARCHIEF: String = "res://src/enemy/warchief_behavior.gd"
const PATH_KING: String = "res://src/enemy/king_behavior.gd"
const PATH_BOMBER: String = "res://src/enemy/bomber_behavior.gd"
const PATH_ENEMY: String = "res://src/enemy/enemy_controller.gd"
const PATH_SKILLS: String = "res://src/ability/battle_skill_controller.gd"
const PATH_KEG: String = "res://src/arena/arena_keg.gd"
const PATH_CRATE: String = "res://src/arena/arena_interactables.gd"
const PATH_SHRINE: String = "res://src/arena/arena_shrine.gd"
const PATH_SPIKES: String = "res://src/arena/arena_spike_trap.gd"
const PATH_BOON: String = "res://src/arena/arena_boon.gd"
const PATH_EVENTS: String = "res://src/run/run_events.gd"
const PATH_DIRECTOR: String = "res://src/director/wave_director.gd"

static var _const_cache: Dictionary = {} # script path -> constant map


# --- Public API -------------------------------------------------------------------------------

static func tab_name(tab: int) -> String:
	return _t(TAB_KEYS[tab])


## Every entry of `tab`, in display order.
static func entries(tab: int) -> Array[Dictionary]:
	UiStrings.ensure_registered()
	match tab:
		Tab.ABILITIES:
			return _ability_entries()
		Tab.PASSIVES:
			return _passive_entries()
		Tab.BATTLE_SKILLS:
			return _battle_skill_entries()
		Tab.PACTS:
			return _pact_entries()
		Tab.ENEMIES:
			return _enemy_entries()
		Tab.BOSSES:
			return _boss_entries()
		Tab.ARENA:
			return _arena_entries()
		Tab.LOADOUT:
			return _loadout_entries()
	return []


static func all_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tab in Tab.values():
		out.append_array(entries(tab))
	return out


## The entry for `id` ({} when the Guide has none).
static func find_entry(id: String) -> Dictionary:
	var resolved: String = String(BOSS_ID_ALIASES.get(id, id))
	for entry: Dictionary in all_entries():
		if String(entry["id"]) == resolved:
			return entry
	return {}


## True when the player has met `entry` (or it is known from the start / unlocked).
static func is_known(entry: Dictionary) -> bool:
	if bool(entry.get("always_known", false)):
		return true
	return MetaProgress.is_discovered(String(entry["id"]))


## Records that the player has now seen `id` (a card shown, an enemy sighted). Idempotent.
static func note_seen(id: String) -> void:
	if id == "":
		return
	MetaProgress.mark_discovered(String(BOSS_ID_ALIASES.get(id, id)))


static func discovered_count(tab: int) -> Vector2i:
	var found: int = 0
	var list: Array[Dictionary] = entries(tab)
	for entry: Dictionary in list:
		if is_known(entry):
			found += 1
	return Vector2i(found, list.size())


# --- Abilities ------------------------------------------------------------------------------------

static func _ability_entries() -> Array[Dictionary]:
	var ids: Array[String] = []
	ids.append_array(AbilityIds.PLAYER_ABILITIES)
	ids.append_array(AbilityIds.TOWER_ABILITIES)
	for id in NEW_ABILITY_IDS:
		if not ids.has(id):
			ids.append(id)
	var out: Array[Dictionary] = []
	for id in ids:
		var tower: bool = AbilityIds.TOWER_ABILITIES.has(id)
		var effect: String = ""
		if AbilityCatalog.has(id):
			effect = _t("FG_LEVEL_LINE") % [1, AbilityCatalog.describe(id, 1)] + "\n" + _t("FG_LEVEL_LINE") % [AbilityIds.MAX_ABILITY_LEVEL, AbilityCatalog.describe(id, AbilityIds.MAX_ABILITY_LEVEL)]
		else:
			effect = _t("FG_%s_EFFECT" % id.to_upper())
		var tip: String = _t("FG_%s_TIP" % id.to_upper())
		var slots: String = _t("FG_SLOTS_TOWER") % _slot_limit(true) if tower else _t("FG_SLOTS_PLAYER") % _slot_limit(false)
		out.append(_entry(id, Tab.ABILITIES, _ability_name(id), id, _t("FG_%s_HELPS" % id.to_upper()), "", effect, tip + " " + slots, _t("FG_HINT_ABILITY")))
	return out


static func _ability_name(id: String) -> String:
	var def: UpgradeDefinition = _upgrade(id)
	if def != null and def.effect_description.contains(":"):
		return def.effect_description.split(":", true, 1)[0].strip_edges()
	return AbilityDisplay.display_name(id)


## The slot limit lives in AbilityIds today; PT-POWER raises the player's to 6 there.
static func _slot_limit(tower: bool) -> int:
	return AbilityIds.MAX_TOWER_ABILITIES if tower else AbilityIds.MAX_PLAYER_ABILITIES


# --- Passives -------------------------------------------------------------------------------------

static func _passive_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ids: Array[String] = []
	for file in ResourceLoader.list_directory(UPGRADE_DIR):
		var id: String = file.trim_suffix(".remap").trim_suffix(".tres")
		if id == file.trim_suffix(".remap") and not file.ends_with(".tres"):
			continue
		ids.append(id)
	ids.sort()
	for id in NEW_PASSIVE_IDS:
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		var def: UpgradeDefinition = _upgrade(id)
		if def != null and (def.get_kind() == UpgradeDefinition.Kind.ABILITY or def.get_kind() == UpgradeDefinition.Kind.TOWER_ABILITY):
			continue # an ability: listed on its own tab
		if def == null and not NEW_PASSIVE_IDS.has(id):
			continue
		var tower: bool = def != null and def.pool_ownership == ContractEnums.PoolOwnership.Tower
		var pass_name: String = id.capitalize()
		var effect: String = _t("FG_%s_EFFECT" % id.to_upper())
		var tip: String = _t("FG_PASSIVE_TIP_GENERIC")
		if def != null:
			var parts: PackedStringArray = def.effect_description.split(":", true, 1)
			pass_name = parts[0].strip_edges() if parts.size() >= 2 else id.capitalize()
			effect = _capitalise(parts[1].strip_edges() if parts.size() >= 2 else def.effect_description)
			tip = _t("FG_PASSIVE_TIP_RANKS") % def.max_rank if def.has_max_rank else _t("FG_PASSIVE_TIP_ONCE")
			if def.get_kind() == UpgradeDefinition.Kind.HEAL:
				tip = _t("FG_PASSIVE_TIP_HEAL")
		var helps: String = _t("FG_HELPS_TOWER") if tower else _t("FG_HELPS_PLAYER")
		var special: String = _t("FG_%s_HELPS" % id.to_upper())
		if special != "":
			helps = special
		out.append(_entry(id, Tab.PASSIVES, pass_name, id, helps, "", effect, tip, _t("FG_HINT_PASSIVE")))
	return out


# --- Battle Skills -----------------------------------------------------------------------------------

static func _battle_skill_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in AbilityIds.BATTLE_SKILLS:
		var cd: Variant = (_c(PATH_SKILLS, "COOLDOWNS", {}) as Dictionary).get(id, null)
		var effect: String = ""
		match id:
			"arrow_storm":
				effect = _fmt("FG_ARROW_STORM_EFFECT", [_c(PATH_SKILLS, "STORM_IMPACTS"), _c(PATH_SKILLS, "STORM_SEARCH_RANGE"), _c(PATH_SKILLS, "STORM_IMPACT_DAMAGE"), _c(PATH_SKILLS, "STORM_IMPACT_RADIUS")])
			"frost_nova":
				effect = _fmt("FG_FROST_NOVA_EFFECT", [_c(PATH_SKILLS, "NOVA_RADIUS"), _c(PATH_SKILLS, "NOVA_DAMAGE"), _pct(_c(PATH_SKILLS, "NOVA_SLOW")), _c(PATH_SKILLS, "NOVA_SLOW_SECONDS")])
			"firebomb":
				effect = _fmt("FG_FIREBOMB_EFFECT", [_c(PATH_SKILLS, "FIREBOMB_RANGE"), _c(PATH_SKILLS, "FIREBOMB_DAMAGE"), _c(PATH_SKILLS, "FIREBOMB_RADIUS"), _c(PATH_SKILLS, "FIREBOMB_BURN_DPS"), _c(PATH_SKILLS, "FIREBOMB_BURN_SECONDS")])
			"war_horn":
				effect = _fmt("FG_WAR_HORN_EFFECT", [_c(PATH_SKILLS, "HORN_SECONDS"), _c(PATH_SKILLS, "HORN_TOWER_RATE"), _c(PATH_SKILLS, "HORN_PLAYER_RATE")])
		effect += " " + _fmt("FG_COOLDOWN", [cd])
		var unlocked_hint: String = _t("FG_HINT_SKILL")
		out.append(_entry(id, Tab.BATTLE_SKILLS, AbilityDisplay.display_name(id), id, _t("FG_%s_HELPS" % id.to_upper()), "", effect, _t("FG_%s_TIP" % id.to_upper()), unlocked_hint, id == RunConfig.DEFAULT_BATTLE_SKILL_ID))
	return out


# --- Pacts, blessings and the event screens ----------------------------------------------------------------

static func _pact_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var patron_waves: String = _join_ints(_c(PATH_EVENTS, "PATRON_WAVES", []))
	var sanctuary_waves: String = _join_ints(_c(PATH_EVENTS, "SANCTUARY_WAVES", []))
	out.append(_entry("opening_pick", Tab.PACTS, _t("EVENT_OPENING_TITLE"), "opening_pick", _t("FG_OPENING_PICK_HELPS"), "",
		_fmt("FG_OPENING_PICK_EFFECT", [_c(PATH_EVENTS, "OPENING_CARDS")]), _t("FG_OPENING_PICK_TIP"), _t("FG_HINT_EVENT")))
	out.append(_entry("patrons_boon", Tab.PACTS, _t("EVENT_PATRON_TITLE"), "patrons_boon", _t("FG_PATRONS_BOON_HELPS"), "",
		_fmt("FG_PATRONS_BOON_EFFECT", [patron_waves, _c(PATH_EVENTS, "PATRON_CARDS")]), _t("FG_PATRONS_BOON_TIP"), _t("FG_HINT_EVENT")))
	out.append(_entry("sanctuary", Tab.PACTS, _t("EVENT_SANCTUARY_TITLE"), "sanctuary", _t("FG_SANCTUARY_HELPS"), "",
		_fmt("FG_SANCTUARY_EFFECT", [sanctuary_waves]), _t("FG_SANCTUARY_TIP"), _t("FG_HINT_EVENT")))
	out.append(_entry("blood_pact", Tab.PACTS, _t("EVENT_PACT_TITLE"), "blood_pact", _t("FG_BLOOD_PACT_HELPS"), _t("FG_BLOOD_PACT_HURTS"),
		_fmt("FG_BLOOD_PACT_EFFECT", [_pct(_c(PATH_EVENTS, "PACT_COST_FRACTION")), _pct(_c(PATH_EVENTS, "FLAWLESS_COST_FACTOR"))]), _t("FG_BLOOD_PACT_TIP"), _t("FG_HINT_EVENT")))
	for id in BLESSING_IDS:
		var effect: String = ""
		match id:
			"mend":
				effect = _t("SANCT_MEND_DESC") % _pct(_c(PATH_EVENTS, "MEND_HEAL_FRACTION"))
			"restore":
				effect = _t("SANCT_RESTORE_DESC") % _pct(_c(PATH_EVENTS, "RESTORE_HEAL_FRACTION"))
			_:
				effect = _t("SANCT_VALOR_DESC") % _pct(_c(PATH_EVENTS, "VALOR_DAMAGE_BONUS"))
		out.append(_entry(id, Tab.PACTS, _t("SANCT_%s_NAME" % id.to_upper()), id, _t("FG_%s_HELPS" % id.to_upper()), "", effect, _t("FG_%s_TIP" % id.to_upper()), _t("FG_HINT_BLESSING")))
	for id in (_c(PATH_EVENTS, "PACT_IDS", []) as Array):
		var pact: String = String(id)
		out.append(_entry(pact, Tab.PACTS, EventDraftController.pact_name(pact), pact, _t("FG_%s_HELPS" % pact.to_upper()), _fmt("FG_PACT_HURTS", [_pct(_c(PATH_EVENTS, "PACT_COST_FRACTION"))]),
			EventDraftController.pact_effect(pact), _t("FG_%s_TIP" % pact.to_upper()), _t("FG_HINT_PACT")))
	return out


# --- Enemies -----------------------------------------------------------------------------------------

static func _enemy_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ENEMY_IDS:
		if id == "elite":
			out.append(_entry("elite", Tab.ENEMIES, _t("FG_ELITE_NAME"), "elite", "", _t("FG_ELITE_HURTS"),
				_fmt("FG_ELITE_EFFECT", [_c(PATH_ENEMY, "ELITE_HP_MULTIPLIER"), _pct(_minus_one(_c(PATH_ENEMY, "ELITE_DAMAGE_MULTIPLIER"))), _pct(_minus_one(_c(PATH_ENEMY, "ELITE_SWIFT_SPEED_MULTIPLIER"))), _c(PATH_ENEMY, "ELITE_VOLATILE_RADIUS_PX"), _c(PATH_ENEMY, "ELITE_VOLATILE_DAMAGE"), _pct(_c(PATH_ENEMY, "ELITE_VAMPIRIC_LEECH_FRACTION"))]),
				_t("FG_ELITE_TIP"), _t("FG_HINT_ENEMY")))
			continue
		var def: EnemyDefinition = _enemy(id)
		var stats: String = _enemy_stats(def) if def != null else _t("FG_DATA_PENDING")
		var behaviour: String = _t("FG_%s_EFFECT" % id.to_upper())
		if id == "bomber":
			behaviour = _fmt("FG_BOMBER_EFFECT", [_c(PATH_BOMBER, "THROW_INTERVAL_SECONDS"), _c(PATH_BOMBER, "TELEGRAPH_SECONDS"), _c(PATH_BOMBER, "BLAST_RADIUS_PX"), _c(PATH_BOMBER, "BLAST_DAMAGE")])
		out.append(_entry(id, Tab.ENEMIES, _t("FG_%s_NAME" % id.to_upper()), id, "", _t("FG_%s_HURTS" % id.to_upper()), behaviour + "\n" + stats, _t("FG_%s_TIP" % id.to_upper()), _t("FG_HINT_ENEMY")))
	return out


## "60 HP. Speed x0.55 (176 px/s). Hits for 15 every 1.5 s, reach 20 px. Drops 1 Scrap." from the .tres.
static func _enemy_stats(def: EnemyDefinition) -> String:
	var hp: int = def.health_band.value if def.health_band != null else 0
	var mult: float = def.movement_profile.speed_multiplier if def.movement_profile != null else 0.0
	var speed_px: int = roundi(mult * _player_speed())
	var out: String = _t("FG_STATS_LINE") % [hp, _trim(mult), speed_px]
	if def.attack_profile != null:
		out += " " + _t("FG_STATS_HIT") % [def.attack_profile.damage_per_hit_or_tick, _trim(def.attack_profile.cycle_or_tick_interval_seconds), def.attack_profile.reach_or_range_px]
	if def.drop_table != null and def.drop_table.scrap > 0:
		out += " " + _t("FG_STATS_DROP") % def.drop_table.scrap
	return out


static func _player_speed() -> float:
	var def: Resource = load(PLAYER_DATA) as Resource
	return float(def.get("base_speed_px_per_second")) if def != null else 0.0


# --- Bosses ------------------------------------------------------------------------------------------

static func _boss_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in BOSS_IDS:
		var def: EnemyDefinition = _enemy(id)
		var lines: Array[String] = []
		if def != null and def.health_band != null:
			lines.append(_t("FG_BOSS_HP") % def.health_band.value)
		match id:
			"goblin_warchief":
				lines.append(_fmt("FG_GOBLIN_WARCHIEF_SLAM", [_c(PATH_WARCHIEF, "SLAM_RADIUS_PX"), _c(PATH_WARCHIEF, "SLAM_DAMAGE"), _c(PATH_WARCHIEF, "SLAM_TELEGRAPH_SECONDS")]))
				lines.append(_fmt("FG_GOBLIN_WARCHIEF_CHARGE", [_c(PATH_WARCHIEF, "CHARGE_DISTANCE_PX"), _c(PATH_WARCHIEF, "CHARGE_DAMAGE")]))
				lines.append(_fmt("FG_GOBLIN_WARCHIEF_RALLY", [_c(PATH_WARCHIEF, "RALLY_HUNTER_COUNT")]))
			"bombardier_king":
				lines.append(_fmt("FG_BOMBARDIER_KING_BARRAGE", [_c(PATH_KING, "BARRAGE_COUNT"), _c(PATH_KING, "BARRAGE_DAMAGE"), _c(PATH_KING, "BARRAGE_RADIUS_PX")]))
				lines.append(_fmt("FG_BOMBARDIER_KING_SIEGE", [_c(PATH_KING, "SIEGE_DAMAGE"), _c(PATH_KING, "SIEGE_RADIUS_PX")]))
				lines.append(_fmt("FG_BOMBARDIER_KING_HORDE", [_c(PATH_KING, "HORDE_SEEKERS"), _c(PATH_KING, "HORDE_BOMBERS")]))
			_:
				lines.append(_t("FG_%s_EFFECT" % id.to_upper()))
		out.append(_entry(id, Tab.BOSSES, _t("FG_%s_NAME" % id.to_upper()), id, "", _t("FG_%s_HURTS" % id.to_upper()), "\n".join(lines), _t("FG_%s_TIP" % id.to_upper()), _t("FG_HINT_BOSS")))
	return out


# --- Arena -------------------------------------------------------------------------------------------

static func _arena_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ARENA_IDS:
		var effect: String = ""
		match id:
			"supply_crate":
				effect = _fmt("FG_SUPPLY_CRATE_EFFECT", [_pct(_c(PATH_CRATE, "DROP_SCRAP_CHANCE")), _c(PATH_CRATE, "DROP_SCRAP_AMOUNT"), _pct(_c(PATH_CRATE, "DROP_MEAT_CHANCE")), _c(PATH_CRATE, "DROP_XP_AMOUNT")])
			"powder_keg":
				effect = _fmt("FG_POWDER_KEG_EFFECT", [_c(PATH_KEG, "FUSE_SECONDS"), _c(PATH_KEG, "BLAST_RADIUS_PX"), _c(PATH_KEG, "ENEMY_DAMAGE"), _c(PATH_KEG, "PLAYER_DAMAGE")])
			"shrine":
				effect = _fmt("FG_SHRINE_EFFECT", [_c(PATH_SHRINE, "CLAIM_SECONDS"), _c(PATH_SHRINE, "LIFETIME_SECONDS")])
			"spike_trap":
				effect = _fmt("FG_SPIKE_TRAP_EFFECT", [_c(PATH_SPIKES, "RETRACTED_SECONDS"), _c(PATH_SPIKES, "TELEGRAPH_SECONDS"), _c(PATH_SPIKES, "DAMAGE")])
			_:
				effect = _t("FG_%s_EFFECT" % id.to_upper())
		out.append(_entry(id, Tab.ARENA, _t("FG_%s_NAME" % id.to_upper()), id, _t("FG_%s_HELPS" % id.to_upper()), _t("FG_%s_HURTS" % id.to_upper()), effect, _t("FG_%s_TIP" % id.to_upper()), _t("FG_HINT_ARENA")))
	var boon_seconds: Variant = _c(PATH_BOON, "DURATION_SECONDS")
	for id in BOON_IDS:
		var key: String = id.trim_prefix("boon_")
		var effect2: String = ""
		match key:
			"war":
				effect2 = _fmt("FG_BOON_WAR_EFFECT", [_pct(_minus_one(_c(PATH_BOON, "WAR_DAMAGE_MULTIPLIER"))), boon_seconds])
			"haste":
				effect2 = _fmt("FG_BOON_HASTE_EFFECT", [_pct(_minus_one(_c(PATH_BOON, "HASTE_SPEED_MULTIPLIER"))), _pct(_minus_one(_c(PATH_BOON, "HASTE_DASH_RECHARGE_MULTIPLIER"))), boon_seconds])
			"ward":
				effect2 = _fmt("FG_BOON_WARD_EFFECT", [_pct(_one_minus(_c(PATH_BOON, "WARD_TOWER_DAMAGE_TAKEN_MULTIPLIER"))), boon_seconds])
			_:
				effect2 = _fmt("FG_BOON_BOUNTY_EFFECT", [_c(PATH_BOON, "BOUNTY_KILLS"), _c(PATH_BOON, "BOUNTY_SCRAP_MULTIPLIER")])
		out.append(_entry(id, Tab.ARENA, _t("FG_BOON_%s_NAME" % key.to_upper()), id, _t("FG_BOON_%s_HELPS" % key.to_upper()), "", effect2, _t("FG_BOON_TIP"), _t("FG_HINT_ARENA")))
	return out


# --- Champions and Relics --------------------------------------------------------------------------------

static func _loadout_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw in LoadoutCatalog.CHAMPION_IDS:
		var unlocked: bool = MetaProgress.is_champion_unlocked(raw)
		out.append(_entry("champion_" + raw, Tab.LOADOUT, LoadoutCatalog.display_name(raw), "champion_" + raw, _t("FG_CHAMPION_HELPS"), LoadoutCatalog.downside_text(raw),
			LoadoutCatalog.twist_text(raw), _t("FG_CHAMPION_TIP"), LoadoutCatalog.unlock_text(raw), unlocked))
	for raw in LoadoutCatalog.RELIC_IDS:
		var unlocked2: bool = MetaProgress.is_relic_unlocked(raw)
		out.append(_entry("relic_" + raw, Tab.LOADOUT, LoadoutCatalog.display_name(raw), "relic_" + raw, _t("FG_RELIC_HELPS"), "",
			LoadoutCatalog.twist_text(raw), _t("FG_RELIC_TIP"), LoadoutCatalog.unlock_text(raw), unlocked2))
	return out


# --- Internals ---------------------------------------------------------------------------------------------

static func _entry(id: String, tab: int, entry_name: String, icon: String, helps: String, hurts: String, effect: String, tip: String, hint: String, always_known: bool = false) -> Dictionary:
	return {"id": id, "tab": tab, "name": entry_name, "icon": icon, "helps": helps, "hurts": hurts, "effect": effect, "tip": tip, "hint": hint, "always_known": always_known}


## A string key's text, or "" when the key has none (an optional line such as a "Hurts:" is then hidden).
static func _t(key: String) -> String:
	UiStrings.ensure_registered()
	var text: String = TranslationServer.translate(StringName(key))
	return "" if text == key else text


## A translated template filled with `args`; a missing (null) constant shows as "?".
static func _fmt(key: String, args: Array) -> String:
	var clean: Array = []
	for a in args:
		clean.append("?" if a == null else (_trim(float(a)) if (a is float) else a))
	return _t(key) % clean


## Constant `const_name` on the script at `path` (the Register-cited number), or `fallback` when
## a later change has renamed or removed it.
static func _c(path: String, const_name: String, fallback: Variant = null) -> Variant:
	if not _const_cache.has(path):
		var script: Script = load(path) as Script
		_const_cache[path] = script.get_script_constant_map() if script != null else {}
	return (_const_cache[path] as Dictionary).get(const_name, fallback)


static func _pct(v: Variant) -> Variant:
	return null if v == null else roundi(float(v) * 100.0)


static func _minus_one(v: Variant) -> Variant:
	return null if v == null else float(v) - 1.0


static func _one_minus(v: Variant) -> Variant:
	return null if v == null else 1.0 - float(v)


static func _capitalise(text: String) -> String:
	return text if text == "" else text.substr(0, 1).to_upper() + text.substr(1)


static func _trim(v: float) -> String:
	return String.num(v, 2).rstrip("0").rstrip(".")


static func _join_ints(list: Variant) -> String:
	var parts: PackedStringArray = []
	for v in (list as Array):
		parts.append(str(int(v)))
	return ", ".join(parts)


static func _upgrade(id: String) -> UpgradeDefinition:
	var path: String = UPGRADE_DIR + id + ".tres"
	return load(path) as UpgradeDefinition if ResourceLoader.exists(path) else null


static func _enemy(id: String) -> EnemyDefinition:
	var path: String = ENEMY_DIR + id + ".tres"
	return load(path) as EnemyDefinition if ResourceLoader.exists(path) else null


## Shutdown hygiene: drop the cached script constant maps.
static func release_caches() -> void:
	_const_cache.clear()

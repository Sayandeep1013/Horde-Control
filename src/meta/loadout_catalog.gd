extends RefCounted
class_name LoadoutCatalog
## v1.0 Loadout catalog (WP-LOADOUT, docs/32 section C; Register "v1.0 Loadout").
## Static data for the four Champions and eight Relics: ids, unlock rules and
## every number. Unlocks are DERIVED from achievements and lifetime boss kills
## by `MetaProgress` (never stored twice, docs/32 C3). Text lives in
## `UiStrings` under LOADOUT_*; effects are applied by `LoadoutEffects`.

const CHAMPION_IDS: Array[String] = ["ranger", "warden", "skirmisher", "pactbound"]
const RELIC_IDS: Array[String] = [
	"quiver_of_echoes", "masons_trowel", "hunters_charm", "warchiefs_horn",
	"kings_crown", "lucky_coin", "iron_banner", "ember_heart",
]
const DEFAULT_CHAMPION_ID: String = "ranger"

## Relic slots (Register "Relic slots"): one at the start, a second after the first victory.
const RELIC_SLOTS_BASE: int = 1
const RELIC_SLOTS_MAX: int = 2

## --- Champion numbers (Register "Champions") ---------------------------------
const WARDEN_TOWER_REGEN_HP_PER_SECOND: float = 1.0
const WARDEN_TOWER_ABILITY_DAMAGE_BONUS: float = 0.15
const WARDEN_PLAYER_MAX_HEALTH_PENALTY: float = 0.10
const SKIRMISHER_MOVING_FIRE_RATE_BONUS: float = 0.15
const SKIRMISHER_EXTRA_DASH_CHARGES: int = 1
const PACTBOUND_PLAYER_MAX_HEALTH_PENALTY: float = 0.15
## Speed below which the player counts as standing still (same line Focus uses, docs/32 A2).
const MOVING_SPEED_THRESHOLD_PX_PER_SECOND: float = 8.0

## --- Relic numbers (Register "Relics") ---------------------------------------
const QUIVER_ECHO_EVERY_SHOTS: int = 8
const QUIVER_ECHO_SPREAD_DEGREES: float = 4.0
const TROWEL_REPAIR_BONUS: float = 0.50
const CHARM_XP_BONUS: float = 0.20
const HORN_SKILL_COOLDOWN_REDUCTION: float = 0.15
const CROWN_ELITE_CHANCE_ADD: float = 0.03
const CROWN_CORES_PER_ELITE: int = 1
const COIN_BONUS_REROLLS: int = 1
const BANNER_SHIELD_BONUS: float = 0.25
const BANNER_IN_WAVE_SHIELD_REGEN_FRACTION: float = 0.25
const EMBER_BURN_DAMAGE_BONUS: float = 0.40

## Unlock rules: {"achievement": id} or {"boss": "warchief"|"king"}; {} = open.
const CHAMPION_UNLOCKS: Dictionary = {
	"ranger": {},
	"warden": {"achievement": "keeper_of_the_keep"},
	"skirmisher": {"achievement": "untouchable"},
	"pactbound": {"achievement": "warchief_slayer"},
}
const RELIC_UNLOCKS: Dictionary = {
	"quiver_of_echoes": {},
	"masons_trowel": {},
	"hunters_charm": {"achievement": "goblin_slayer"},
	"warchiefs_horn": {"boss": "warchief"},
	"kings_crown": {"boss": "king"},
	"lucky_coin": {"achievement": "hoarder"},
	"iron_banner": {"achievement": "mason"},
	"ember_heart": {"achievement": "elite_hunter"},
}


static func is_champion(id: String) -> bool:
	return CHAMPION_IDS.has(id)


static func is_relic(id: String) -> bool:
	return RELIC_IDS.has(id)


static func unlock_rule(id: String) -> Dictionary:
	if CHAMPION_UNLOCKS.has(id):
		return CHAMPION_UNLOCKS[id]
	return RELIC_UNLOCKS.get(id, {})


## The achievement whose unlock this item is a reward for ("" for a boss-kill or open item).
static func unlocking_achievement(id: String) -> String:
	return String(unlock_rule(id).get("achievement", ""))


## Champion or Relic ids that the given achievement unlocks (for the Achievements panel).
static func rewards_of_achievement(achievement_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in CHAMPION_IDS + RELIC_IDS:
		if unlocking_achievement(id) == achievement_id:
			out.append(id)
	return out


static func name_key(id: String) -> String:
	return ("LOADOUT_CHAMPION_NAME_%s" if is_champion(id) else "LOADOUT_RELIC_NAME_%s") % id.to_upper()


static func twist_key(id: String) -> String:
	return ("LOADOUT_CHAMPION_TWIST_%s" if is_champion(id) else "LOADOUT_RELIC_TWIST_%s") % id.to_upper()


static func downside_key(id: String) -> String:
	return "LOADOUT_CHAMPION_DOWNSIDE_%s" % id.to_upper()


static func icon_path(id: String) -> String:
	return "res://assets/ui/icons/icon_%s_%s.png" % ["champion" if is_champion(id) else "relic", id]


static func display_name(id: String) -> String:
	UiStrings.ensure_registered()
	return TranslationServer.translate(name_key(id))


static func twist_text(id: String) -> String:
	UiStrings.ensure_registered()
	var template: String = TranslationServer.translate(twist_key(id))
	var args: Array = _twist_args(id)
	return template % args if not args.is_empty() else template


static func downside_text(id: String) -> String:
	if not is_champion(id):
		return ""
	UiStrings.ensure_registered()
	var template: String = TranslationServer.translate(downside_key(id))
	match id:
		"warden":
			return template % roundi(WARDEN_PLAYER_MAX_HEALTH_PENALTY * 100.0)
		"pactbound":
			return template % roundi(PACTBOUND_PLAYER_MAX_HEALTH_PENALTY * 100.0)
	return template


## "Locked. <how to earn it>": the unlocking achievement's own description, or the boss to defeat.
static func unlock_text(id: String) -> String:
	UiStrings.ensure_registered()
	var rule: Dictionary = unlock_rule(id)
	var how: String = ""
	if rule.has("achievement"):
		var achievement: AchievementDefinition = MetaProgress.achievement_list.get_achievement(String(rule["achievement"])) if MetaProgress.achievement_list != null else null
		how = achievement.description if achievement != null else String(rule["achievement"])
	elif rule.has("boss"):
		how = TranslationServer.translate("LOADOUT_UNLOCK_BOSS_%s" % String(rule["boss"]).to_upper())
	return TranslationServer.translate("LOADOUT_LOCKED") % how


static func _twist_args(id: String) -> Array:
	match id:
		"warden":
			return [String.num(WARDEN_TOWER_REGEN_HP_PER_SECOND, 1).rstrip("0").rstrip("."), roundi(WARDEN_TOWER_ABILITY_DAMAGE_BONUS * 100.0)]
		"skirmisher":
			return [roundi(SKIRMISHER_MOVING_FIRE_RATE_BONUS * 100.0), SKIRMISHER_EXTRA_DASH_CHARGES]
		"quiver_of_echoes":
			return [QUIVER_ECHO_EVERY_SHOTS]
		"masons_trowel":
			return [roundi(TROWEL_REPAIR_BONUS * 100.0)]
		"hunters_charm":
			return [roundi(CHARM_XP_BONUS * 100.0)]
		"warchiefs_horn":
			return [roundi(HORN_SKILL_COOLDOWN_REDUCTION * 100.0)]
		"kings_crown":
			return [roundi(CROWN_ELITE_CHANCE_ADD * 100.0), CROWN_CORES_PER_ELITE]
		"lucky_coin":
			return [COIN_BONUS_REROLLS]
		"iron_banner":
			return [roundi(BANNER_SHIELD_BONUS * 100.0), roundi(BANNER_IN_WAVE_SHIELD_REGEN_FRACTION * 100.0)]
		"ember_heart":
			return [roundi(EMBER_BURN_DAMAGE_BONUS * 100.0)]
	return []

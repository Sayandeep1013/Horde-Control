extends RefCounted
class_name AbilityIds
## v1.0 shared identifiers (WP0, decision D175; docs/31 §3-§4). One place for
## every ability / Battle Skill / damage-source id so the Draft (WP-COMBAT),
## icons (WP-ASSETS, assets/ui/icons/icon_<id>.png), the HUD build bar (WP-UI),
## unlocks (WP-META) and the damage report agree on spelling.

# Battle Skills (docs/31 §3.2)
const ARROW_STORM: String = "arrow_storm"
const FROST_NOVA: String = "frost_nova"
const FIREBOMB: String = "firebomb"
const WAR_HORN: String = "war_horn"
const BATTLE_SKILLS: Array[String] = [ARROW_STORM, FROST_NOVA, FIREBOMB, WAR_HORN]

# Player abilities (docs/31 §4.2)
const FLAME_ARROWS: String = "flame_arrows"
const FROST_ARROWS: String = "frost_arrows"
const WHIRLING_AXES: String = "whirling_axes"
const DYNAMITE_SATCHEL: String = "dynamite_satchel"
const STORM_BOLT: String = "storm_bolt"
const CALTROPS: String = "caltrops"
const SACRED_GROUND: String = "sacred_ground"
const PLAYER_ABILITIES: Array[String] = [FLAME_ARROWS, FROST_ARROWS, WHIRLING_AXES, DYNAMITE_SATCHEL, STORM_BOLT, CALTROPS, SACRED_GROUND]

# Tower abilities (docs/31 §4.3)
const BALLISTA: String = "ballista"
const CATAPULT: String = "catapult"
const FROST_WARD: String = "frost_ward"
const SPIKED_PALISADE: String = "spiked_palisade"
const TOWER_ABILITIES: Array[String] = [BALLISTA, CATAPULT, FROST_WARD, SPIKED_PALISADE]

# New passives (docs/31 §4.4)
const FLEET_STEP: String = "fleet_step"
const BATTLE_FOCUS: String = "battle_focus"
const BLAST_RADIUS: String = "blast_radius"
const KEEN_EYE: String = "keen_eye"
const LEATHER_ARMOR: String = "leather_armor"
const ABILITY_POWER: String = "ability_power"
const STONE_MASON: String = "stone_mason"

# Slot limits (docs/31 §4.1) -- Register "Ability slots" owns the numbers.
const MAX_PLAYER_ABILITIES: int = 4
const MAX_TOWER_ABILITIES: int = 3
const MAX_ABILITY_LEVEL: int = 5

# Damage sources that are not abilities (docs/31 §4.6)
const SOURCE_BOW: String = "bow"
const SOURCE_TOWER_BOW: String = "tower_bow"
const SOURCE_REFLECT: String = "spiked_palisade"
const SOURCE_STATUS_BURN: String = "burn"


static func is_player_ability(id: String) -> bool:
	return PLAYER_ABILITIES.has(id)


static func is_tower_ability(id: String) -> bool:
	return TOWER_ABILITIES.has(id)


static func icon_path(id: String) -> String:
	return "res://assets/ui/icons/icon_%s.png" % id

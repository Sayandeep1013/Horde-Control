extends RefCounted
class_name ArenaBoon
## The four Shrine boons (Register "v1.0 Arena Interactables", docs/32 section B). Static data
## only: ids, durations, magnitudes, icon paths and tray labels. ArenaInteractables
## owns which boons are active and applies them.

const WAR: String = "war"
const HASTE: String = "haste"
const WARD: String = "ward"
const BOUNTY: String = "bounty"
const IDS: Array[String] = [WAR, HASTE, WARD, BOUNTY]

# Register "v1.0 Arena Interactables": Boon durations and magnitudes
const DURATION_SECONDS: float = 20.0 # War, Haste, Ward
const WAR_DAMAGE_MULTIPLIER: float = 1.35 # +35% player damage
const HASTE_SPEED_MULTIPLIER: float = 1.30 # +30% move speed
const HASTE_DASH_RECHARGE_MULTIPLIER: float = 1.30 # +30% dash recharge rate
const WARD_TOWER_DAMAGE_TAKEN_MULTIPLIER: float = 0.75 # -25% Tower damage taken
const BOUNTY_KILLS: int = 20 # kills that drop double Scrap
const BOUNTY_SCRAP_MULTIPLIER: int = 2

const NAMES: Dictionary = {WAR: "War", HASTE: "Haste", WARD: "Ward", BOUNTY: "Bounty"}
const SUMMARIES: Dictionary = {
	WAR: "+35% damage",
	HASTE: "+30% speed and dash recharge",
	WARD: "Tower shield refilled, -25% damage taken",
	BOUNTY: "Next 20 kills drop double Scrap",
}


static func icon_path(id: String) -> String:
	return "res://assets/ui/icons/icon_boon_%s.png" % id


static func is_timed(id: String) -> bool:
	return id != BOUNTY

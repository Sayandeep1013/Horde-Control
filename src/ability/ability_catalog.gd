extends RefCounted
class_name AbilityCatalog
## v1.0 ability numbers in one table (docs/31 §4.2-§4.3; Register
## "v1.0 Combat & Abilities"). Each entry is [level 1 value, level 5 value];
## levels 2-4 interpolate linearly so the card text and the ability node read
## the same number. Rarity scales only the keys listed in DAMAGE_KEYS (D123 /
## docs/31 §4.1: "rarity scales an ability's damage numbers, not cooldowns or
## counts").

const DAMAGE_KEYS: Array[String] = ["damage", "dps", "reflect"]

const TABLE: Dictionary = {
	"flame_arrows": {"every_n": [4.0, 2.0], "dps": [9.0, 20.0], "duration": [3.0, 3.0], "spread_radius": [90.0, 90.0]},
	"frost_arrows": {"slow": [0.20, 0.40], "duration": [1.5, 1.5], "freeze_chance": [0.0, 0.12], "freeze_duration": [1.0, 1.0]},
	"whirling_axes": {"count": [1.0, 4.0], "radius": [72.0, 90.0], "damage": [14.0, 26.0], "rehit": [0.45, 0.45]},
	"dynamite_satchel": {"interval": [3.2, 2.2], "range": [320.0, 320.0], "fuse": [0.5, 0.5], "damage": [30.0, 60.0], "radius": [70.0, 95.0]},
	"storm_bolt": {"interval": [2.6, 1.6], "range": [300.0, 300.0], "damage": [22.0, 40.0], "chains": [2.0, 6.0], "chain_range": [140.0, 140.0]},
	"caltrops": {"interval": [0.9, 0.5], "lifetime": [4.0, 4.0], "damage": [10.0, 20.0], "tick": [0.5, 0.5], "slow": [0.25, 0.25]},
	"sacred_ground": {"radius": [85.0, 130.0], "dps": [6.0, 20.0], "heal_fraction": [0.0, 0.005]},
	"ballista": {"interval": [3.0, 1.6], "damage": [34.0, 76.0]},
	"catapult": {"interval": [5.0, 3.0], "flight": [0.9, 0.9], "range": [620.0, 620.0], "damage": [50.0, 110.0], "radius": [90.0, 90.0]},
	"frost_ward": {"interval": [4.0, 2.5], "radius": [210.0, 280.0], "damage": [14.0, 30.0], "slow": [0.30, 0.45], "duration": [2.0, 2.0]},
	"spiked_palisade": {"reflect": [10.0, 30.0], "reduction": [0.05, 0.20]},
}

const NAMES: Dictionary = {
	"flame_arrows": "Flame Arrows", "frost_arrows": "Frost Arrows", "whirling_axes": "Whirling Axes",
	"dynamite_satchel": "Dynamite Satchel", "storm_bolt": "Storm Bolt", "caltrops": "Caltrops",
	"sacred_ground": "Sacred Ground", "ballista": "Ballista", "catapult": "Catapult",
	"frost_ward": "Frost Ward", "spiked_palisade": "Spiked Palisade",
}


static func has(id: String) -> bool:
	return TABLE.has(id)


## Value of `key` at `level` (1-5). Rarity multiplier applies to damage keys only.
static func value(id: String, key: String, level: int, rarity_mult: float = 1.0) -> float:
	var entry: Dictionary = TABLE.get(id, {})
	if not entry.has(key):
		return 0.0
	var pair: Array = entry[key]
	var t: float = clampf(float(level - 1) / float(AbilityIds.MAX_ABILITY_LEVEL - 1), 0.0, 1.0)
	var v: float = lerpf(float(pair[0]), float(pair[1]), t)
	if DAMAGE_KEYS.has(key):
		v *= rarity_mult
	return v


static func ivalue(id: String, key: String, level: int) -> int:
	return roundi(value(id, key, level))


## Dynamite Satchel throws two from level 4 (docs/31 §4.2).
static func dynamite_count(level: int) -> int:
	return 2 if level >= 4 else 1


static func display_name(id: String) -> String:
	return String(NAMES.get(id, id.capitalize()))


## Honest one-line description of what `level` does at `rarity_mult`.
static func describe(id: String, level: int, rarity_mult: float = 1.0) -> String:
	match id:
		"flame_arrows":
			var n: int = ivalue(id, "every_n", level)
			var spread: String = " A burning enemy that dies spreads its burn." if level >= 5 else ""
			return "Every %d%s arrow ignites: %d dps for %ds.%s" % [n, _ord(n), roundi(value(id, "dps", level, rarity_mult)), roundi(value(id, "duration", level)), spread]
		"frost_arrows":
			var fr: String = ""
			if level >= 3:
				fr = " %d%% chance to freeze for 1s." % roundi(value(id, "freeze_chance", level) * 100.0)
			return "Arrows slow %d%% for %.1fs.%s" % [roundi(value(id, "slow", level) * 100.0), value(id, "duration", level), fr]
		"whirling_axes":
			var c: int = ivalue(id, "count", level)
			return "%d orbiting %s, %d damage per hit." % [c, "axe" if c == 1 else "axes", roundi(value(id, "damage", level, rarity_mult))]
		"dynamite_satchel":
			return "Every %.1fs throw %s: %d damage, %d px blast." % [value(id, "interval", level), "2 dynamite" if dynamite_count(level) == 2 else "dynamite", roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "radius", level))]
		"storm_bolt":
			return "Every %.1fs lightning hits for %d and chains to %d more." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult)), ivalue(id, "chains", level)]
		"caltrops":
			return "Drop spikes every %.1fs while moving: %d damage, 25%% slow." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult))]
		"sacred_ground":
			var heal: String = " Kills inside heal you." if level >= 5 else ""
			return "Aura %d px: %d dps.%s" % [roundi(value(id, "radius", level)), roundi(value(id, "dps", level, rarity_mult)), heal]
		"ballista":
			return "Every %.1fs a bolt pierces the furthest enemy line for %d." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult))]
		"catapult":
			return "Every %.1fs a rock lands for %d in %d px." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "radius", level))]
		"frost_ward":
			return "Every %.1fs pulse %d px: %d damage, %d%% slow." % [value(id, "interval", level), roundi(value(id, "radius", level)), roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "slow", level) * 100.0)]
		"spiked_palisade":
			return "Attackers take %d back. Tower takes %d%% less damage." % [roundi(value(id, "reflect", level, rarity_mult)), roundi(value(id, "reduction", level) * 100.0)]
	return id


static func _ord(n: int) -> String:
	match n:
		2: return "nd"
		3: return "rd"
		_: return "th"

extends RefCounted
class_name AbilityCatalog
## v1.0 ability numbers in one table (docs/31 §4.2-§4.3; Register
## "v1.0 Combat & Abilities"). Each entry is [level 1 value, level 5 value];
## levels 2-4 interpolate linearly so the card text and the ability node read
## the same number. Rarity scales only the keys listed in DAMAGE_KEYS (D123 /
## docs/31 §4.1: "rarity scales an ability's damage numbers, not cooldowns or
## counts").

const FREEZE_FIRST_LEVEL: int = 3
const BOOMERANG_FIRST_LEVEL: int = 3 # Whirling Axes throw from level 3 (D351)

const DAMAGE_KEYS: Array[String] = ["damage", "dps", "reflect"]

const TABLE: Dictionary = {
	# PT-POWER (D351): every damage and area figure roughly doubled for the swarm; the
	# balance pass retunes. Old -> new is recorded in the Register "v1.0 Combat & Abilities".
	"flame_arrows": {"every_n": [3.0, 1.0], "dps": [18.0, 40.0], "duration": [3.0, 3.0], "spread_radius": [150.0, 150.0]},
	"frost_arrows": {"slow": [0.25, 0.45], "duration": [1.5, 1.5], "freeze_chance": [0.05, 0.12], "freeze_duration": [1.0, 1.0]},
	"whirling_axes": {"count": [2.0, 6.0], "radius": [110.0, 160.0], "damage": [30.0, 56.0], "rehit": [0.45, 0.45], "hit_radius": [44.0, 44.0], "boomerang_range": [280.0, 280.0], "boomerang_every": [2.5, 2.5]},
	"dynamite_satchel": {"interval": [2.4, 1.4], "range": [420.0, 420.0], "fuse": [0.5, 0.5], "damage": [70.0, 140.0], "radius": [130.0, 170.0]},
	"storm_bolt": {"interval": [1.8, 1.0], "range": [420.0, 420.0], "damage": [48.0, 90.0], "chains": [4.0, 10.0], "chain_range": [220.0, 220.0]},
	"caltrops": {"interval": [0.6, 0.35], "lifetime": [5.0, 5.0], "damage": [22.0, 42.0], "tick": [0.5, 0.5], "slow": [0.35, 0.35], "radius": [60.0, 90.0]},
	"sacred_ground": {"radius": [150.0, 230.0], "dps": [14.0, 45.0], "heal_fraction": [0.0, 0.005]},
	"ballista": {"interval": [2.4, 1.2], "damage": [70.0, 150.0]},
	"catapult": {"interval": [4.0, 2.4], "flight": [0.9, 0.9], "range": [620.0, 620.0], "damage": [110.0, 230.0], "radius": [140.0, 180.0]},
	"frost_ward": {"interval": [3.2, 2.0], "radius": [300.0, 400.0], "damage": [30.0, 64.0], "slow": [0.35, 0.50], "duration": [2.0, 2.0]},
	"spiked_palisade": {"reflect": [22.0, 60.0], "reduction": [0.08, 0.25]},
	# PT-POWER new abilities (D352-D357). `damage` of diagonal_arrows is a fraction of the arrow's own damage.
	"diagonal_arrows": {"damage": [0.7, 1.0]},
	"ricochet": {"bounces": [2.0, 5.0], "bounce_range": [220.0, 300.0], "fraction": [0.7, 0.7]},
	"lightning_sprite": {"interval": [1.2, 0.6], "range": [420.0, 420.0], "damage": [26.0, 52.0], "chains": [2.0, 4.0], "chain_range": [200.0, 200.0], "orbit_radius": [90.0, 90.0]},
	"meteor_shower": {"interval": [6.0, 3.5], "meteors": [3.0, 6.0], "damage": [180.0, 180.0], "radius": [120.0, 120.0], "range": [520.0, 520.0], "delay": [0.9, 0.9]},
	"blade_circle": {"count": [4.0, 8.0], "radius": [220.0, 220.0], "damage": [28.0, 52.0], "rehit": [0.4, 0.4], "hit_radius": [40.0, 40.0], "spin": [2.6, 2.6]},
}

const NAMES: Dictionary = {
	"flame_arrows": "Flame Arrows", "frost_arrows": "Frost Arrows", "whirling_axes": "Whirling Axes",
	"dynamite_satchel": "Dynamite Satchel", "storm_bolt": "Storm Bolt", "caltrops": "Caltrops",
	"sacred_ground": "Sacred Ground", "ballista": "Ballista", "catapult": "Catapult",
	"frost_ward": "Frost Ward", "spiked_palisade": "Spiked Palisade",
	"diagonal_arrows": "Diagonal Arrows", "ricochet": "Ricochet", "lightning_sprite": "Lightning Sprite",
	"meteor_shower": "Meteor Shower", "blade_circle": "Blade Circle",
}

# Shadow Step (Register "Dash", D350): the dash damages enemies it passes through and extends the
# invulnerability tail. Rank 1-3; rarity does not scale it (like Multishot, a count-style card).
const SHADOW_STEP_DAMAGE: Array[float] = [30.0, 50.0, 70.0]
const SHADOW_STEP_INVULN_SECONDS: Array[float] = [0.1, 0.2, 0.3]


static func shadow_step_damage(rank: int) -> float:
	return SHADOW_STEP_DAMAGE[clampi(rank, 1, SHADOW_STEP_DAMAGE.size()) - 1] if rank > 0 else 0.0


static func shadow_step_invuln(rank: int) -> float:
	return SHADOW_STEP_INVULN_SECONDS[clampi(rank, 1, SHADOW_STEP_INVULN_SECONDS.size()) - 1] if rank > 0 else 0.0


## Diagonal Arrows (D352): the extra-arrow angles in degrees from the aim line. Levels 1-2 fire
## +-45; from level 3 four more at +-30 and +-60 join them.
static func diagonal_angles(level: int) -> Array[float]:
	var out: Array[float] = [45.0, -45.0]
	if level >= 3:
		out.append_array([30.0, -30.0, 60.0, -60.0])
	return out


static func has(id: String) -> bool:
	return TABLE.has(id)


## Value of `key` at `level` (1-5). Rarity multiplier applies to damage keys only.
static func value(id: String, key: String, level: int, rarity_mult: float = 1.0) -> float:
	var entry: Dictionary = TABLE.get(id, {})
	if not entry.has(key):
		return 0.0
	var pair: Array = entry[key]
	if key == "freeze_chance": # Register: Frost Arrows freezes from level 3 only (5%, 8.5%, 12%)
		if level < FREEZE_FIRST_LEVEL:
			return 0.0
		return lerpf(float(pair[0]), float(pair[1]), clampf(float(level - FREEZE_FIRST_LEVEL) / float(AbilityIds.MAX_ABILITY_LEVEL - FREEZE_FIRST_LEVEL), 0.0, 1.0))
	var t: float = clampf(float(level - 1) / float(AbilityIds.MAX_ABILITY_LEVEL - 1), 0.0, 1.0)
	var v: float = lerpf(float(pair[0]), float(pair[1]), t)
	if DAMAGE_KEYS.has(key):
		v *= rarity_mult
	return v


static func ivalue(id: String, key: String, level: int) -> int:
	return roundi(value(id, key, level))


## Dynamite Satchel throws 2 sticks at levels 1-2, 3 at levels 3-4, 4 at level 5 (D351).
static func dynamite_count(level: int) -> int:
	return 4 if level >= 5 else (3 if level >= 3 else 2)


static func display_name(id: String) -> String:
	return String(NAMES.get(id, id.capitalize()))


## Honest one-line description of what `level` does at `rarity_mult`.
static func describe(id: String, level: int, rarity_mult: float = 1.0) -> String:
	match id:
		"flame_arrows":
			var n: int = ivalue(id, "every_n", level)
			var spread: String = " A burning enemy that dies spreads its burn." if level >= 5 else ""
			if n <= 1:
				return "Every arrow ignites: %d dps for %ds.%s" % [roundi(value(id, "dps", level, rarity_mult)), roundi(value(id, "duration", level)), spread]
			return "Every %d%s arrow ignites: %d dps for %ds.%s" % [n, _ord(n), roundi(value(id, "dps", level, rarity_mult)), roundi(value(id, "duration", level)), spread]
		"frost_arrows":
			var fr: String = ""
			if level >= 3:
				var pct: float = value(id, "freeze_chance", level) * 100.0
				fr = " %s%% chance to freeze for 1s." % (("%.1f" % pct) if absf(pct - roundf(pct)) > 0.01 else "%d" % roundi(pct))
			return "Arrows slow %d%% for %.1fs.%s" % [roundi(value(id, "slow", level) * 100.0), value(id, "duration", level), fr]
		"whirling_axes":
			var c: int = ivalue(id, "count", level)
			var boom: String = " Every %.1fs they fly out %d px and back." % [value(id, "boomerang_every", level), roundi(value(id, "boomerang_range", level))] if level >= BOOMERANG_FIRST_LEVEL else ""
			return "%d big orbiting axes at %d px, %d damage per hit.%s" % [c, roundi(value(id, "radius", level)), roundi(value(id, "damage", level, rarity_mult)), boom]
		"dynamite_satchel":
			return "Every %.1fs throw %d dynamite: %d damage, %d px blast." % [value(id, "interval", level), dynamite_count(level), roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "radius", level))]
		"storm_bolt":
			return "Every %.1fs lightning hits for %d and chains to %d more." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult)), ivalue(id, "chains", level)]
		"caltrops":
			return "Drop spikes every %.2fs while moving: %d damage, %d px patch, %d%% slow." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "radius", level)), roundi(value(id, "slow", level) * 100.0)]
		"sacred_ground":
			var heal: String = " Kills inside heal you." if level >= 5 else ""
			return "Aura %d px: %d dps.%s" % [roundi(value(id, "radius", level)), roundi(value(id, "dps", level, rarity_mult)), heal]
		"diagonal_arrows":
			var n: int = diagonal_angles(level).size()
			return "Every volley adds %d arrows at %s, each %d%% arrow damage." % [n, "+-45 degrees" if level < 3 else "+-30, +-45 and +-60 degrees", roundi(value(id, "damage", level, rarity_mult) * 100.0)]
		"ricochet":
			return "Arrow hits bounce to %d nearby enemies within %d px for %d%% damage." % [ivalue(id, "bounces", level), roundi(value(id, "bounce_range", level)), roundi(value(id, "fraction", level) * 100.0)]
		"lightning_sprite":
			return "A sprite orbits you and every %.1fs fires a bolt for %d that chains to %d more." % [value(id, "interval", level), roundi(value(id, "damage", level, rarity_mult)), ivalue(id, "chains", level)]
		"meteor_shower":
			return "Every %.1fs %d meteors fall on enemy clusters: %d damage, %d px blast." % [value(id, "interval", level), ivalue(id, "meteors", level), roundi(value(id, "damage", level, rarity_mult)), roundi(value(id, "radius", level))]
		"blade_circle":
			return "%d blades spin around you at %d px: %d damage per hit." % [ivalue(id, "count", level), roundi(value(id, "radius", level)), roundi(value(id, "damage", level, rarity_mult))]
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

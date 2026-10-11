extends RefCounted
class_name AbilitySynergy
## v1.0 cross-ability synergies (decision D204; Register "v1.0 Combat &
## Abilities" > Synergies). Four named synergies read status effects set by a
## partner ability, so the build is more than a sum of cards. Each is active only
## while its partner ability is owned (any level) and is shown on the Draft card
## and the pause Build panel as soon as the partner is owned.
##
##   CONDUCTION  Storm Bolt (player) + Frost Ward (Tower): +2 chains, and the bolt
##               deals +50% to Slowed or Frozen enemies.
##   KINDLING    Caltrops + Flame Arrows (both player): a patch ignites what
##               stands in it at Flame Arrows' own burn; burning enemies take +25%
##               Caltrops damage.
##   SHATTER     Ballista and Catapult (Tower) + Frost Arrows (player): a Frozen
##               enemy takes double damage from either.
##   CHAIN REACTION  Ricochet + Flame Arrows / Frost Arrows (player, D353): every bounce
##               runs the partner's arrow-hit effect, so bounced arrows count toward
##               igniting and slow (and can freeze) what they reach.
##   HALLOWED    Sacred Ground (player): with Flame Arrows each burning enemy
##               killed inside heals +1% of max HP; with Frost Ward (Tower) the
##               aura slows enemies inside by 15%.

const CONDUCTION_EXTRA_CHAINS: int = 2 # Register: Synergy Conduction
const CONDUCTION_DAMAGE_MULT: float = 1.5
const KINDLING_DAMAGE_MULT: float = 1.25
const SHATTER_DAMAGE_MULT: float = 2.0
const HALLOWED_BURN_KILL_HEAL: float = 0.01
const HALLOWED_SLOW: float = 0.15
const HALLOWED_SLOW_REFRESH_SECONDS: float = 0.6

## ability id -> [[partner id, text], ...]. Text is the honest effect line.
const TABLE: Dictionary = {
	"storm_bolt": [["frost_ward", "Conduction (Frost Ward): +2 chains, +50% damage to Slowed or Frozen enemies."]],
	"frost_ward": [
		["storm_bolt", "Conduction (Storm Bolt): Storm Bolt chains +2 and hits Slowed or Frozen enemies for +50%."],
		["sacred_ground", "Hallowed (Sacred Ground): Sacred Ground's aura slows enemies 15%."],
	],
	"caltrops": [["flame_arrows", "Kindling (Flame Arrows): patches ignite enemies; burning enemies take +25% Caltrops damage."]],
	"ricochet": [
		["flame_arrows", "Chain Reaction (Flame Arrows): each bounce counts toward igniting, and ignites on the Nth."],
		["frost_arrows", "Chain Reaction (Frost Arrows): each bounce slows, and can freeze, what it reaches."],
	],
	"flame_arrows": [
		["ricochet", "Chain Reaction (Ricochet): bounced arrows count toward igniting."],
		["caltrops", "Kindling (Caltrops): Caltrops ignite enemies and hit burning ones for +25%."],
		["sacred_ground", "Hallowed (Sacred Ground): each burning enemy killed in the aura heals you 1% max HP."],
	],
	"ballista": [["frost_arrows", "Shatter (Frost Arrows): Frozen enemies take double damage."]],
	"catapult": [["frost_arrows", "Shatter (Frost Arrows): Frozen enemies take double damage."]],
	"frost_arrows": [
		["ricochet", "Chain Reaction (Ricochet): bounced arrows slow and can freeze."],
		["ballista", "Shatter (Ballista): Frozen enemies take double Ballista damage."],
		["catapult", "Shatter (Catapult): Frozen enemies take double Catapult damage."],
	],
	"sacred_ground": [
		["flame_arrows", "Hallowed (Flame Arrows): each burning enemy killed inside heals you 1% max HP."],
		["frost_ward", "Hallowed (Frost Ward): the aura slows enemies inside by 15%."],
	],
}


## Synergy lines of `ability_id` whose partner is in `owned_ids`.
static func active_texts(ability_id: String, owned_ids: Array) -> Array[String]:
	var out: Array[String] = []
	for pair in TABLE.get(ability_id, []):
		if owned_ids.has(pair[0]):
			out.append(String(pair[1]))
	return out


## Every synergy line of the ability (the always-available description/tooltip).
static func all_texts(ability_id: String) -> Array[String]:
	var out: Array[String] = []
	for pair in TABLE.get(ability_id, []):
		out.append(String(pair[1]))
	return out


static func owns(ability_id: String) -> bool:
	var mgr: Node = AbilityDamage.get_manager()
	return mgr != null and mgr.get_level(ability_id) > 0


static func conduction_active() -> bool:
	return owns("frost_ward")


static func conduction_mult(enemy: Object) -> float:
	if conduction_active() and (StatusEffects.is_slowed(enemy) or StatusEffects.is_frozen(enemy)):
		return CONDUCTION_DAMAGE_MULT
	return 1.0


static func kindling_active() -> bool:
	return owns("flame_arrows")


static func kindling_mult(enemy: Object) -> float:
	return KINDLING_DAMAGE_MULT if kindling_active() and StatusEffects.is_burning(enemy) else 1.0


static func shatter_mult(enemy: Object) -> float:
	return SHATTER_DAMAGE_MULT if owns("frost_arrows") and StatusEffects.is_frozen(enemy) else 1.0

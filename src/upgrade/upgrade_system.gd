extends Node
class_name UpgradeSystem

## UpgradeSystem (P2.11). Owns the run-scoped rank state for the prototype's
## six upgrades and two fallback cards, and applies each rank's effect to
## the live player weapon / player health / Tower weapon / Tower health
## components through a modifier layer that never mutates the authored
## base .tres resources (data/weapons/handgun.tres, data/tower/base.tres,
## data/player/prototype.tres are owned by other tasks and read-only from
## this system's perspective -- P2.11's own hard constraints forbid editing
## them).
##
## Register citations (MASTER_SDLC.md > Provisional Values Register >
## "Progression & Upgrades"): "Prototype upgrade pool | Player - Rapid Fire
## +20% fire rate/rank; Heavy Rounds +20% damage/rank; Patch Kit restores 30
## health/rank taken. Tower - Caliber +20% damage/rank; Optics +15%
## range/rank; Shield Matrix +10% of Tower maximum health as extra
## shield/rank. Max rank 3 each, shared ranks" and "Fallback cards
## (C-FALLBACK-CONSOLE) | No max rank, add 0 evolution ranks; Player
## 'Overdrive +10% weapon damage', Tower 'Reinforce +10% Tower damage';
## appear in the Draft for an exhausted pool AND at the Console for 90
## Scrap once that pool is exhausted, so Scrap always has a sink" and
## "Console price | 30 Scrap x rank being bought (30/60/90)". MASTER_SDLC.md
## > Player Overview > "Upgrade Channels": "An upgrade rank purchased in one
## channel counts in the other; maximum rank is shared." Every per-rank
## number above is authored on the eight data/upgrades/*.tres files this
## system reads (unique_id, effect_target, effect_per_rank,
## console_price_per_rank, max_rank, has_max_rank) -- never restated as a
## literal in this script's own logic.
##
## ## Stacking rule: additive, not multiplicative (C-STACK) -- cited, not
## escalated
## MASTER_SDLC.md > Progression Edge Cases > "Percentage bonuses to the same
## stat stack": "Percentage bonuses to the same stat add, then apply once:
## stat = base x (1 + sum of bonuses) (C-STACK)." Every percentage-based
## upgrade in this pool (Rapid Fire, Heavy Rounds, Caliber, Optics, Shield
## Matrix, and both fallback cards) sums its effect_per_rank across every
## rank currently held, then applies that ONE combined multiplier to the
## authored base value -- e.g. Heavy Rounds at rank 3 is
## base_damage x (1 + 0.20 + 0.20 + 0.20) = base_damage x 1.6, NEVER
## base_damage x 1.2 x 1.2 x 1.2 (= 1.728, a materially different number
## and exactly the "drift after 3 ranks" this task's named acceptance test
## polices). _apply_effect() below always recomputes this total fraction
## from the upgrade's CURRENT total shared rank, never by multiplying an
## already-applied multiplier again -- see that function's own comment.
##
## Patch Kit is not a percentage-of-a-stat upgrade: "restores 30 health per
## rank TAKEN" is an on-apply, one-shot heal fired once per rank-taking
## event (from either channel), holding no persistent multiplier of its own
## and so unable to drift the way a stacked percentage can.
##
## ## Modifier layer (never mutates authored .tres resources)
## AutoWeapon and TowerWeapon each gained a small pair of multiplier fields
## this task added (set_damage_multiplier() on both; set_fire_rate_
## multiplier() on AutoWeapon; set_range_multiplier() on TowerWeapon -- see
## those files' own header comments) that combine with the definition-
## derived BASE damage / fire-interval / range at the point of use, every
## time, never by writing back into the weapon's own base fields or the
## WeaponDefinition resource. TowerHealth gained set_bonus_max_shield_
## fraction() the same way, folded onto max_shield/current_shield on top of
## the definition-derived `_base_max_shield`. Player gained a minimal
## heal() seam for Patch Kit (see player.gd's own header comment on that
## method for why death_state.gd itself could not be extended in this
## task's write scope).
##
## ## Routing by unique_id, not by effect_target alone
## `effect_target` (Player/Tower/PlayerWeapon/TowerWeapon) names WHICH
## component an upgrade's effect reaches, but not WHICH of that component's
## several stats -- TowerWeapon alone carries both damage (Caliber) and
## range (Optics), and the Upgrade Definition Contract has no fourth field
## for that finer distinction. This is a fixed, eight-card prototype pool
## (weapon evolutions are explicitly out of this task's scope per PLAN.md),
## so _apply_effect() below routes by the unique_id every one of the eight
## authored .tres files declares, rather than inventing an unscoped
## fifth contract field or a generic effect-execution engine for exactly
## eight known cards. See the P2.11 evidence report, "Design notes."
##
## No per-tick work of any kind lives in this file -- unlike src/combat/
## auto_weapon.gd or src/tower/tower_weapon.gd, this system is purely a
## command/query surface driven by whichever channel (P2.12's Draft, P2.13's
## Console) calls apply_rank()/get_*() -- so it declares no physics_step()
## or driven_externally (CLAUDE.md's per-tick convention does not apply
## here for the same reason it does not apply to, say, entity_registry.gd).

## The eight authored Upgrade/TowerUpgrade Definitions this system owns: the
## six prototype upgrades (Rapid Fire, Heavy Rounds, Patch Kit, Caliber,
## Optics, Shield Matrix) plus the two fallback cards (Overdrive, Reinforce;
## C-FALLBACK-CONSOLE). Overridable per instance without touching this
## script; set_upgrade_definitions_for_test() below lets a test suite
## substitute a smaller subset (e.g. to exhaust a one-upgrade pool without
## maxing all three real Tower upgrades first).
## D115/D117 pool expansion: six new Player cards, four new Tower cards
## (Swift Feet/Vitality/Magnet/Regeneration/Piercing Arrows/Multishot;
## Reinforced Plating/Watchtower/Tower Volley/Repair Kit), added alongside
## the original eight. "Reinforced Plating" is the task's own "Reinforce"
## renamed to avoid colliding with the existing `reinforce_fallback` card
## (also displayed "Reinforce", a different effect) -- named here rather
## than silently reusing the name for two different cards.
@export var upgrade_definitions: Array[UpgradeDefinition] = [
	preload("res://data/upgrades/rapid_fire.tres"),
	preload("res://data/upgrades/heavy_rounds.tres"),
	preload("res://data/upgrades/patch_kit.tres"),
	preload("res://data/upgrades/swift_feet.tres"),
	preload("res://data/upgrades/vitality.tres"),
	preload("res://data/upgrades/magnet.tres"),
	preload("res://data/upgrades/regeneration.tres"),
	preload("res://data/upgrades/piercing_arrows.tres"),
	preload("res://data/upgrades/multishot.tres"),
	preload("res://data/upgrades/caliber.tres"),
	preload("res://data/upgrades/optics.tres"),
	preload("res://data/upgrades/shield_matrix.tres"),
	preload("res://data/upgrades/reinforced_plating.tres"),
	preload("res://data/upgrades/watchtower_upgrade.tres"),
	preload("res://data/upgrades/tower_volley.tres"),
	preload("res://data/upgrades/repair_kit.tres"),
	preload("res://data/upgrades/overdrive_fallback.tres"),
	preload("res://data/upgrades/reinforce_fallback.tres"),
]

## Wiring seams for the live components this system pushes recomputed
## multipliers/heals into, following this project's own *_path export +
## get_node_or_null() convention (e.g. src/tower/tower.gd's own *_path
## fields). Left for whichever future integration task assembles the real
## run scene (scenes/** is outside this task's write scope) to assign; a
## test wires the four set_*_for_test() methods below directly instead, and
## a null reference is tolerated everywhere below (an upgrade whose target
## is not wired yet simply has its rank tracked with no live effect,
## rather than crashing).
@export var player_weapon_path: NodePath
@export var player_path: NodePath
@export var tower_weapon_path: NodePath
@export var tower_health_path: NodePath

## Integration task (F05-06): `evolution_stage_contribution` is authored
## correctly on Caliber/Optics/Shield Matrix (1 each) and Reinforce (0,
## the explicit "add 0 evolution ranks" carve-out) but nothing summed it
## and pushed it to TowerEvolutionStage -- the P2.11 evidence report named
## this as open, owner "the integration task." Same null-tolerant wiring
## convention as the four paths above.
@export var tower_evolution_stage_path: NodePath

## Upgrade unique_id (String) -> current shared rank (int). The ONE
## dictionary both channels read and write -- there is no separate
## per-channel counter anywhere in this file, which is what makes "ranks
## apply from either channel and cap correctly at rank 3" (this task's own
## exit criterion) true by construction rather than by careful bookkeeping
## across two stores.
var _ranks: Dictionary = {}

## D118: card unique_ids gated by a lifetime achievement (`UpgradeDefinition.
## is_unlock`) that have been unlocked -- String -> true. Empty by default,
## so every `is_unlock` card is correctly absent from a fresh profile's
## Draft pool until `set_unlocked_card_ids()` is called (the production
## caller is `src/integration/prototype_integration.gd`, reading
## `MetaProgress`'s own unlocked-achievement query at run start).
var _unlocked_ids: Dictionary = {}

var _definitions_by_id: Dictionary = {} # String -> UpgradeDefinition

var _player_weapon: AutoWeapon = null
var _player: Player = null
var _tower_weapon: TowerWeapon = null
var _tower_health: TowerHealth = null
var _tower_evolution_stage: TowerEvolutionStage = null

# --- unique_id routing constants (match the .tres files' own unique_id) ---
const RAPID_FIRE_ID: String = "rapid_fire"
const HEAVY_ROUNDS_ID: String = "heavy_rounds"
const PATCH_KIT_ID: String = "patch_kit"
const CALIBER_ID: String = "caliber"
const OPTICS_ID: String = "optics"
const SHIELD_MATRIX_ID: String = "shield_matrix"
const OVERDRIVE_FALLBACK_ID: String = "overdrive_fallback"
const REINFORCE_FALLBACK_ID: String = "reinforce_fallback"

# --- D115/D117 pool expansion ------------------------------------------------
const SWIFT_FEET_ID: String = "swift_feet"
const VITALITY_ID: String = "vitality"
const MAGNET_ID: String = "magnet"
const REGENERATION_ID: String = "regeneration"
const PIERCING_ARROWS_ID: String = "piercing_arrows"
const MULTISHOT_ID: String = "multishot"
const REINFORCED_PLATING_ID: String = "reinforced_plating"
const WATCHTOWER_UPGRADE_ID: String = "watchtower_upgrade"
const TOWER_VOLLEY_ID: String = "tower_volley"
const REPAIR_KIT_ID: String = "repair_kit"


func _ready() -> void:
	_build_definition_index()
	if player_weapon_path != NodePath():
		_player_weapon = get_node_or_null(player_weapon_path) as AutoWeapon
	if player_path != NodePath():
		_player = get_node_or_null(player_path) as Player
	if tower_weapon_path != NodePath():
		_tower_weapon = get_node_or_null(tower_weapon_path) as TowerWeapon
	if tower_health_path != NodePath():
		_tower_health = get_node_or_null(tower_health_path) as TowerHealth
	if tower_evolution_stage_path != NodePath():
		_tower_evolution_stage = get_node_or_null(tower_evolution_stage_path) as TowerEvolutionStage


func _build_definition_index() -> void:
	_definitions_by_id.clear()
	for def in upgrade_definitions:
		if def == null:
			continue
		_definitions_by_id[def.unique_id] = def


# --- Test-only seams (never called by gameplay code) -----------------------

func set_upgrade_definitions_for_test(defs: Array[UpgradeDefinition]) -> void:
	upgrade_definitions = defs
	_build_definition_index()


func set_player_weapon_for_test(weapon: AutoWeapon) -> void:
	_player_weapon = weapon


func set_player_for_test(player: Player) -> void:
	_player = player


func set_tower_weapon_for_test(weapon: TowerWeapon) -> void:
	_tower_weapon = weapon


func set_tower_health_for_test(health: TowerHealth) -> void:
	_tower_health = health


func set_tower_evolution_stage_for_test(stage: TowerEvolutionStage) -> void:
	_tower_evolution_stage = stage


# --- Public typed queries (P2.12 Draft / P2.13 Console call these) --------

## Typed query: the authored definition for `upgrade_id`, or null if
## unknown. P2.12/P2.13 read display fields (effect_description,
## console_price_per_rank, etc.) directly off the returned resource.
func get_definition(upgrade_id: String) -> UpgradeDefinition:
	return _definitions_by_id.get(upgrade_id, null)


## Typed query: the upgrade's current SHARED rank (0 if never taken from
## either channel).
func get_current_rank(upgrade_id: String) -> int:
	return int(_ranks.get(upgrade_id, 0))


## Typed query. A fallback card (has_max_rank == false) is never maxed --
## C-FALLBACK-CONSOLE's "No max rank" is exactly this.
func is_maxed(upgrade_id: String) -> bool:
	var def: UpgradeDefinition = get_definition(upgrade_id)
	if def == null or not def.has_max_rank:
		return false
	return get_current_rank(upgrade_id) >= def.max_rank


## D118: true once `def` counts as part of the "live" pool -- ranked
## (has_max_rank) AND (not an achievement-gated `is_unlock` card, or
## already unlocked). A locked `is_unlock` card is treated as if it did not
## exist in the pool at all: never offered, and never counted toward
## `is_pool_exhausted()`'s "every ranked upgrade is maxed" check (a card the
## player cannot yet reach must never block or fake that check).
func _is_live(def: UpgradeDefinition) -> bool:
	if def == null or not def.has_max_rank:
		return false
	return not def.is_unlock or _unlocked_ids.has(def.unique_id)


## Typed command (D118). Replaces the whole unlocked set -- called once, at
## run start, by whoever wires MetaProgress's achievement query to this
## system (production: src/integration/prototype_integration.gd). Also
## usable directly from a test.
func set_unlocked_card_ids(ids: Array[String]) -> void:
	_unlocked_ids.clear()
	for id in ids:
		_unlocked_ids[id] = true


func is_card_unlocked_for_test(upgrade_id: String) -> bool:
	return bool(_unlocked_ids.has(upgrade_id))


## Typed query ("what is offerable"): every LIVE upgrade (see _is_live())
## in `pool_ownership` that is not already at max rank. Fallback cards are
## never included here -- P2.12's own exhausted-pool substitution reaches
## them through get_fallback_card() below, only once is_pool_exhausted() is
## true, never as one of the normal three random draws that consult this
## list.
func get_offerable_upgrades(pool_ownership: ContractEnums.PoolOwnership) -> Array[UpgradeDefinition]:
	var result: Array[UpgradeDefinition] = []
	for def in upgrade_definitions:
		if def == null or def.pool_ownership != pool_ownership or not _is_live(def):
			continue
		if not is_maxed(def.unique_id):
			result.append(def)
	return result


## Typed query ("whether a pool is exhausted, so fallbacks unlock"): true
## once every LIVE upgrade (see _is_live()) authored for `pool_ownership`
## is at max rank. False for a pool with no live upgrades at all (Weapon/
## Utility in the prototype, or every card in `pool_ownership` still
## achievement-locked), so a caller cannot be misled into treating a pool
## that was simply never populated -- or not yet unlocked -- as "exhausted."
func is_pool_exhausted(pool_ownership: ContractEnums.PoolOwnership) -> bool:
	var ranked_found: bool = false
	for def in upgrade_definitions:
		if def == null or def.pool_ownership != pool_ownership or not _is_live(def):
			continue
		ranked_found = true
		if not is_maxed(def.unique_id):
			return false
	return ranked_found


## Typed query: the fallback card (Overdrive for Player, Reinforce for
## Tower) authored for `pool_ownership` -- the card P2.12 substitutes into a
## Draft slot, and P2.13 lists at the Console, once
## is_pool_exhausted(pool_ownership) is true (C-FALLBACK-CONSOLE). Null if
## this pool has no fallback card authored (Weapon/Utility in the
## prototype).
func get_fallback_card(pool_ownership: ContractEnums.PoolOwnership) -> UpgradeDefinition:
	for def in upgrade_definitions:
		if def != null and def.pool_ownership == pool_ownership and not def.has_max_rank:
			return def
	return null


## Typed query ("what a rank costs"): the Scrap cost of buying `upgrade_id`'s
## NEXT rank at the Console. MASTER_SDLC.md > Provisional Values Register >
## "Progression & Upgrades" > "Console price": "30 Scrap x rank being
## bought (30/60/90)" for the six ranked upgrades --
## `console_price_per_rank * (current_rank + 1)`.
##
## C-FALLBACK-CONSOLE states the fallback price as a flat "90 Scrap," not a
## per-rank formula -- a fallback card has no max rank for a "rank being
## bought" number to multiply against in the first place. has_max_rank ==
## false therefore returns `console_price_per_rank` UNMULTIPLIED. This is an
## interpretation of how the schema's single console_price_per_rank field
## is reused for a flat-price card, not a restated Register formula -- see
## the P2.11 evidence report, "Interpretations."
##
## Returns -1 (never a valid Scrap cost) if `upgrade_id` is unknown or
## already maxed, so a caller cannot mistake a bogus 0 for a free purchase.
func get_console_cost(upgrade_id: String) -> int:
	var def: UpgradeDefinition = get_definition(upgrade_id)
	if def == null:
		push_error("UpgradeSystem.get_console_cost(): unknown upgrade_id '%s'" % upgrade_id)
		return -1
	if is_maxed(upgrade_id):
		push_warning("UpgradeSystem.get_console_cost(): '%s' is already at max rank" % upgrade_id)
		return -1
	if not def.has_max_rank:
		return def.console_price_per_rank # flat fallback price (C-FALLBACK-CONSOLE)
	var rank_being_bought: int = get_current_rank(upgrade_id) + 1
	return def.console_price_per_rank * rank_being_bought


# --- Public typed command ---------------------------------------------------

## Typed command ("apply a rank"): applies exactly one rank of `upgrade_id`,
## from EITHER channel -- the Level-Up Draft (free) or the Tower Console
## (this method has no notion of cost; the Console caller charges Scrap via
## get_console_cost() BEFORE calling this). MASTER_SDLC.md > Player Overview
## > "Upgrade Channels": "An upgrade rank purchased in one channel counts in
## the other; maximum rank is shared." Both channels call this exact same
## method against this system's ONE `_ranks` dictionary -- there is no
## separate "apply from Draft" / "apply from Console" code path for the
## shared-rank rule to accidentally diverge between.
##
## Guards the max-rank cap HERE, not only at offer time (is_maxed() /
## get_offerable_upgrades()): a caller holding a stale snapshot (three Draft
## cards rolled a moment before a Console purchase of the same upgrade
## landed, both inside the same paused instant) must not be able to push a
## rank past max_rank just because it already held the card when offered.
##
## Returns false (applies nothing, rank unchanged) for an unknown
## upgrade_id or one already at max rank; true on success.
##
## D117 (card rarity): `rarity_multiplier` is the rolled card's own value
## multiplier (Common 1.0 / Rare 1.5 / Epic 2.2, src/ui/draft_controller.gd's
## own roll) -- REPLACES the previous multiplier for this upgrade_id, never
## compounds, matching this file's own established replace-not-compound
## convention for every other multiplier field. A named simplification for a
## multi-rank upgrade bought at different rarities across separate
## purchases: the MOST RECENT purchase's rarity governs the whole
## accumulated stack's scaling (`total_fraction` below), not a per-rank
## locked-in value -- the alternative (summing per-rank values independently
## of the shared-rank counter) would require a second parallel accumulator
## next to `_ranks` for no gameplay benefit this prototype's own acceptance
## test needs. Defaults to 1.0 (Common) so every existing caller -- the
## Console price/rank formula tests and any direct test call -- is
## unaffected.
func apply_rank(upgrade_id: String, rarity_multiplier: float = 1.0) -> bool:
	var def: UpgradeDefinition = get_definition(upgrade_id)
	if def == null:
		push_error("UpgradeSystem.apply_rank(): unknown upgrade_id '%s'" % upgrade_id)
		return false
	if is_maxed(upgrade_id):
		push_warning("UpgradeSystem.apply_rank(): '%s' is already at max rank -- refusing to exceed it" % upgrade_id)
		return false

	var new_rank: int = get_current_rank(upgrade_id) + 1
	_ranks[upgrade_id] = new_rank
	_apply_effect(def, new_rank, rarity_multiplier)

	# F05-06 (fixed): sum evolution_stage_contribution into
	# TowerEvolutionStage.add_ranks(), once per rank ACTUALLY just taken
	# (never re-derived from the running total -- add_ranks() is itself
	# additive, matching this file's own C-STACK "apply once" pattern one
	# level up: a single rank grants its own contribution exactly once).
	# `def.get(...)` (duck-typed) rather than a hard cast: the base
	# UpgradeDefinition class carries no such field, only the
	# TowerUpgradeDefinition subclass (Caliber/Optics/Shield Matrix/
	# Reinforce) does -- a Player-pool card's `get()` returns null here,
	# which `is int`/`is float` below both correctly reject.
	if _tower_evolution_stage != null:
		var contribution: Variant = def.get("evolution_stage_contribution")
		if (contribution is int or contribution is float) and int(contribution) > 0:
			_tower_evolution_stage.add_ranks(int(contribution))

	return true


## Routes `def`'s effect to the live component it targets, recomputing the
## ONE combined multiplier from `rank` (the upgrade's NEW TOTAL shared rank,
## never an incremental step) every time -- C-STACK. See this file's own
## header, "Routing by unique_id," for why routing keys on unique_id rather
## than effect_target alone.
##
## Fallback cards (Overdrive, Reinforce) route through the SAME branch as
## their real-pool counterpart (Heavy Rounds, Caliber): both are a flat
## percentage bonus to the same stat, so the same C-STACK additive-sum
## formula applies, just with `rank` here meaning "times taken" rather than
## a capped rank (is_maxed() never true for a fallback card, so `rank` can
## grow without bound, exactly matching "no max rank ... so Scrap always has
## a sink").
##
## D117: `rarity_multiplier` (see apply_rank()'s own header) scales every
## PERCENTAGE-based effect below (`total_fraction`). It does NOT scale a
## flat one-shot heal fired once per rank-TAKEN event (Patch Kit,
## Reinforced Plating's heal-the-increase, Repair Kit) -- rarity is about
## how much bigger a stat bonus is, not about a one-time heal amount, named
## here rather than silently applied everywhere -- nor a discrete integer
## count (Piercing Arrows' pierce count, Multishot's extra-arrow count),
## since "1.5 extra pierced enemies" has no meaning; those two always use
## `def.effect_per_rank * rank` directly, at every rarity.
func _apply_effect(def: UpgradeDefinition, rank: int, rarity_multiplier: float = 1.0) -> void:
	var total_fraction: float = def.effect_per_rank * float(rank) * rarity_multiplier # C-STACK: sum first, apply once, then scale by rarity
	match def.unique_id:
		RAPID_FIRE_ID:
			if _player_weapon != null:
				_player_weapon.set_fire_rate_multiplier(1.0 + total_fraction)
		HEAVY_ROUNDS_ID, OVERDRIVE_FALLBACK_ID:
			if _player_weapon != null:
				_player_weapon.set_damage_multiplier(1.0 + total_fraction)
		CALIBER_ID, REINFORCE_FALLBACK_ID:
			if _tower_weapon != null:
				_tower_weapon.set_damage_multiplier(1.0 + total_fraction)
		OPTICS_ID, WATCHTOWER_UPGRADE_ID:
			if _tower_weapon != null:
				_tower_weapon.set_range_multiplier(1.0 + total_fraction)
		TOWER_VOLLEY_ID:
			if _tower_weapon != null:
				_tower_weapon.set_fire_rate_multiplier(1.0 + total_fraction)
		SHIELD_MATRIX_ID:
			if _tower_health != null:
				_tower_health.set_bonus_max_shield_fraction(total_fraction)
		REINFORCED_PLATING_ID:
			if _tower_health != null:
				_tower_health.set_bonus_max_health_fraction(total_fraction)
		SWIFT_FEET_ID:
			if _player != null:
				_player.set_speed_multiplier(1.0 + total_fraction)
		VITALITY_ID:
			if _player != null:
				_player.set_max_health_bonus_fraction(total_fraction)
		MAGNET_ID:
			if _player != null:
				_player.set_pickup_radius_multiplier(1.0 + total_fraction)
		REGENERATION_ID:
			if _player != null:
				_player.set_regen_fraction_per_second(total_fraction)
		PIERCING_ARROWS_ID:
			# Discrete count -- rarity does not scale "extra enemies pierced."
			if _player_weapon != null:
				_player_weapon.set_pierce_bonus(int(round(def.effect_per_rank * float(rank))))
		MULTISHOT_ID:
			# Discrete count -- rarity does not scale "extra arrows fired."
			if _player_weapon != null:
				_player_weapon.set_multishot_extra_count(int(round(def.effect_per_rank * float(rank))))
		PATCH_KIT_ID:
			# Not a persistent multiplier -- "restores 30 health per rank
			# TAKEN" fires once, per rank-taking event, using
			# def.effect_per_rank directly (never `total_fraction`, which
			# would wrongly treat 30 as a per-rank ADDITIVE percentage
			# instead of a flat heal fired once per event, and never scaled
			# by rarity -- see this function's own header).
			if _player != null:
				_player.heal(def.effect_per_rank)
		REPAIR_KIT_ID:
			# Same one-shot-per-take shape as Patch Kit, applied to the
			# Tower's CURRENT max_health (25% of whatever it is right now,
			# including any Reinforced Plating/meta bonus already applied).
			if _tower_health != null:
				_tower_health.heal(_tower_health.max_health * def.effect_per_rank)
		_:
			push_warning("UpgradeSystem._apply_effect(): '%s' has no routing -- effect not applied to any live component" % def.unique_id)

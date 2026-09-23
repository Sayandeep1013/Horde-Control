extends RefCounted
class_name MetaLoadout

## The frozen per-run bonuses computed once at run start (build brief item 3;
## MASTER_SDLC.md > Provisional Values Register > "Meta: Skill Tree
## effects"). `MetaProgress.build_run_loadout()` is the only producer --
## it reads the CURRENT tree ranks once and packs them into this plain,
## immutable-by-convention data holder (a RefCounted, not a Resource: this
## is per-run runtime state, never saved, never shared -- resource-pattern
## skill's own "Resource vs Node"/anti-pattern guidance argues for a plain
## data object here, and RunInventory (src/economy/run_inventory.gd) already
## sets this project's precedent for exactly that shape).
##
## `MetaLoadoutApplier` (src/meta/meta_loadout_applier.gd) is the only
## consumer -- it reads every field below exactly once, at run start, and
## applies each to a RUNTIME COPY of the relevant system's data contract (or
## to a small typed command on the system itself for the three non-scalar
## "mechanic" nodes). See that file's header for the full application seam.
##
## Every field name matches one `SkillNodeDefinition.EffectKind` member
## one-to-one (see that enum's own comment) so `MetaProgress.
## build_run_loadout()`'s translation is a single flat match statement with
## no branch-specific special-casing.

## --- Player branch ----------------------------------------------------------
var player_max_health_bonus: float = 0.0 ## fraction, e.g. 0.20 = +20% (Vitality)
var player_move_speed_bonus: float = 0.0 ## fraction (Swift Boots)
var player_weapon_damage_bonus: float = 0.0 ## fraction (Sharpened Arrows)
var player_fire_rate_bonus: float = 0.0 ## fraction (Quick Draw)
var player_magnet_radius_bonus: float = 0.0 ## fraction (Long Reach)
var second_wind_enabled: bool = false ## Second Wind

## --- Tower branch ------------------------------------------------------------
var tower_max_health_bonus: float = 0.0 ## fraction (Stone Walls)
var tower_weapon_damage_bonus: float = 0.0 ## fraction (Arrow Slits)
var tower_max_shield_bonus: float = 0.0 ## fraction of max_health, additive to the base shield fraction (Shield Runes)
## fraction, e.g. 0.10 = +10% Tower shield regen rate per rank (Mason's
## Kit). D115 (no in-run shop) removed the Tower Console and its repair
## price, which this field used to discount (`repair_price_reduction`) --
## renamed and repurposed rather than deleted, since Mason's Kit stays a
## real, purchasable node (a prerequisite for Watchtower).
var tower_shield_regen_bonus: float = 0.0
var tower_weapon_range_bonus: float = 0.0 ## fraction (Watchtower)
var fortress_enabled: bool = false ## Fortress

## --- Economy / run-flow branch ------------------------------------------------
var starting_scrap: int = 0 ## flat, credited once at run start (Scavenger)
var xp_gain_bonus: float = 0.0 ## fraction, multiplies every XP shard collected (Scholar)
var bonus_draft_rerolls: int = 0 ## flat, added to the Register's baseline 1 (Lucky Draw)
var settlement_cores_bonus: float = 0.0 ## fraction, applied by MetaProgress.settle_run() itself (Prospector) -- informational here; settle_run() re-reads the live rank rather than trusting a frozen copy, since ranks cannot change mid-run anyway (see meta_progress.gd)
var scrap_cap_bonus: int = 0 ## flat, added to RunInventory.scrap_cap (Deep Pockets)
var war_chest_enabled: bool = false ## War Chest
var rarity_luck_points: int = 0 ## flat luck points, added to the Draft's own rarity roll (D117; Lucky Charm)

extends Resource
class_name AchievementDefinition

## Achievement definition (D118; MASTER_SDLC.md > Provisional Values
## Register > "Meta: Achievements"). One instance per row authored on
## `data/meta/achievements.tres` (AchievementList.achievements). A small,
## data-driven list rather than hardcoded logic, matching this project's
## own precedent for the Skill Tree (`SkillNodeDefinition` /
## `SkillTreeDefinition`).
##
## ## `metric` (a String, not an enum -- named interpretation)
## Five metrics cover the six authored achievements (Register row lists
## them): "lifetime_kills", "lifetime_scrap_collected" (both cumulative
## profile counters, checked against `threshold`), and "run_waves_cleared",
## "run_victory", "run_tower_health_fraction" (all three read straight off
## the CURRENT run's own `run_summary` dictionary at settlement, never a
## cumulative counter). A String, not a new ContractEnums member, since
## this is meta-layer-only content with no Content Data Contract of its
## own (docs/20 does not list an Achievement Contract) -- MetaProgress's own
## `_evaluate_achievements()` is the one place that interprets the string,
## exactly as it is the one place that interprets `SkillNodeDefinition.
## EffectKind`.
##
## ## `unlocks_card_id` vs `perk_id` -- a card XOR a small permanent perk
## (D118: "each unlocking a card or a small permanent perk"). At most one of
## the two is non-empty on any one row; `unlocks_card_id` matches an
## `UpgradeDefinition.unique_id` whose own `is_unlock` is true (the card is
## authored into the pool but invisible to the Draft until this achievement
## is unlocked -- `MetaProgress.get_unlocked_card_ids()` is read once at run
## start by `src/integration/prototype_integration.gd` and pushed into
## `UpgradeSystem.set_unlocked_card_ids()`). `perk_id` names a small fixed
## effect `MetaLoadoutApplier` applies at run start once
## profile.unlocked_achievement_ids contains this row's `id` -- see that
## file's own header for the fixed table of perk ids.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var metric: String = ""
@export var threshold: float = 0.0
@export var unlocks_card_id: String = "" ## empty = this achievement unlocks no Draft card
@export var perk_id: String = "" ## empty = this achievement grants no permanent perk

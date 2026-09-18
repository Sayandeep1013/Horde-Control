extends Resource
class_name UpgradeDefinition

## Upgrade Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Upgrade Definition Contract"). Field types per docs/20 > Contract Field
## Semantics > Shared fields and struct types, and > Upgrade Definition
## Contract fields. Field-to-type mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## TowerUpgradeDefinition extends this class (P0.6 convention 9) rather than
## duplicating its fields.
##
## max_rank is a nullable integer (P0.6 convention 4): meaningless when
## has_max_rank is false - null for the no-max-rank fallback cards.
##
## recursive_interaction_guard: docs/20 types this "enum/string, nullable" -
## flagged as an ambiguity in the P0.6 report, since no enum member list is
## given anywhere. Resolved as a String (inventing enum members for a rule
## MASTER only describes in prose would violate P0.6 convention 3).
##
## Nullability corrected in the P0.6 review, iteration 2 (Ruling #1 / R7):
## the original empty-string sentinel doubled as both "no guard, deliberately"
## and "never filled in", because "" is also the export's own default -
## exactly the ambiguity MASTER's "No upgrade may be implemented if it can
## trigger unbounded recursion without a defined guard" rule needs to tell
## apart. Paired with has_recursive_interaction_guard instead, matching the
## has_<field> convention already used for max_rank and Wave's
## maximum_duration_seconds, rather than an empty-string sentinel.
##
## "No upgrade may be implemented if it can trigger unbounded recursion
## without a defined guard" (MASTER) - has_recursive_interaction_guard false
## must still be checked explicitly by a consuming system when the upgrade
## has a triggered effect with no guard defined (covers both "no guard,
## deliberately" and "never filled in" until a consuming system tells them
## apart some other way; the boolean only tells the schema whether a guard
## rule string has been authored).

@export var unique_id: String = ""
@export var pool_ownership: ContractEnums.PoolOwnership = ContractEnums.PoolOwnership.Player
@export var rarity: ContractEnums.Rarity = ContractEnums.Rarity.Common
@export var max_rank: int = 0
@export var has_max_rank: bool = false
@export var prerequisites: Array[String] = [] ## Upgrade Unique IDs
@export var exclusions: Array[String] = [] ## Upgrade Unique IDs
@export var effect_description: String = ""
@export var effect_target: ContractEnums.UpgradeEffectTarget = ContractEnums.UpgradeEffectTarget.Player
@export var effect_per_rank: float = 0.0
@export var console_price_per_rank: int = 0 ## Scrap
@export var recursive_interaction_guard: String = "" ## nullable via has_recursive_interaction_guard; meaningless when that flag is false
@export var has_recursive_interaction_guard: bool = false ## false = null (no guard defined / not yet filled in); true = recursive_interaction_guard holds the guard rule
@export var visual_readability_impact: ContractEnums.VisualReadabilityImpact = ContractEnums.VisualReadabilityImpact.None
@export var performance_cost_category: ContractEnums.PerformanceCostCategory = ContractEnums.PerformanceCostCategory.Light

extends Resource
class_name TowerDefinition

## Tower Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Tower Definition Contract"). Field types per docs/20 > Contract Field
## Semantics > Tower Definition Contract fields. Field-to-type mapping
## recorded in phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## evolution_stage_thresholds is "list of 4 integers" per docs/20 (Base,
## Reinforced, Armed, Fortress) - typed as Array[int]; its length-4
## requirement is a sample-content rule, not a type-level one Godot can
## express, so the schema check asserts it on the sample.

@export var unique_id: String = ""
@export var max_health_and_shield_fraction: MaxHealthAndShieldFraction = null
@export var shield_regeneration: ShieldRegeneration = null
@export var tower_footprint: TowerFootprint = null
@export var base_weapon_reference_id: String = "" ## Weapon Definition Unique ID
@export var targeting_rule_parameters: TargetingRuleParameters = null
@export var evolution_stage_thresholds: Array[int] = [] ## exactly 4: Base, Reinforced, Armed, Fortress
@export var repair_price: RepairPrice = null
@export var persistent_asset_rules: Array[PersistentAssetRule] = []

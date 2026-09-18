extends Resource
class_name EnemyDefinition

## Enemy Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Enemy Definition Contract"). Field types per docs/20_Technical_Architecture.md
## > Contract Field Semantics > Shared fields and struct types, and >
## Enemy Definition Contract fields. Field-to-type mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## "No enemy may be implemented if its target intent is undefined" (MASTER):
## target_intent has no meaningful zero value in this schema; a consuming
## system must still check it explicitly since Godot cannot forbid a default
## enum value at the export level.

@export var unique_id: String = ""
@export var target_intent: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker
@export var movement_profile: MovementProfile = null
@export var attack_profile: AttackProfile = null
@export var telegraph_data: TelegraphData = null
@export var health_band: BandedValue = null ## BandedValue per P0.6 convention 5
@export var damage_band: BandedValue = null ## BandedValue per P0.6 convention 5
@export var contact_behaviour: ContractEnums.ContactBehaviour = ContractEnums.ContactBehaviour.None
@export var pathing_fallback_behavior: ContractEnums.PathingFallbackBehavior = ContractEnums.PathingFallbackBehavior.Standard
@export var entity_cap_weight: int = 0 ## integer >= 1; schema default kept at Godot's natural 0 (an invalid value here) rather than 1, so an unset field cannot be mistaken for a validly-set 1 in a sample
@export var elite_eligibility: bool = false
@export var allowed_affixes: Array[String] = [] ## Elite Affix Unique IDs (out-of-scope contract referenced by ID)
@export var biome_tags: Array[String] = [] ## Biome Unique IDs (out-of-scope contract referenced by ID)
@export var readability_profile: ReadabilityProfile = null
@export var drop_table: DropTable = null

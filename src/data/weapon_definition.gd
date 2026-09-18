extends Resource
class_name WeaponDefinition

## Weapon and Evolution Definition Contract (MASTER_SDLC.md > Content Data
## Contracts > "Weapon and Evolution Definition Contract"). Field types per
## docs/20 > Contract Field Semantics > Shared fields and struct types, and
## > Weapon and Evolution Definition Contract fields. Field-to-type mapping
## recorded in phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## evolution_changes_axes is "list of enum ..., length >= 1" per docs/20 -
## the length-1 minimum is a sample-content rule the schema check asserts,
## not a type-level constraint Godot can express on Array[enum].

@export var unique_id: String = ""
@export var effective_range_px: int = 0
@export var coverage_shape: ContractEnums.CoverageShape = ContractEnums.CoverageShape.Cone
@export var target_count: int = 0
@export var engagement_rhythm: EngagementRhythm = null
@export var damage_band: BandedValue = null ## BandedValue per P0.6 convention 5 ("Damage per shot")
@export var projectile_definition: ProjectileDefinition = null
@export var evolution_requirement: WeaponEvolutionRequirement = null ## "Evolution prerequisites and the evolution target"
@export var evolution_changes_axes: Array[ContractEnums.EvolutionChangeAxis] = [] ## length >= 1, per Weapon Evolution Philosophy

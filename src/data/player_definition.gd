extends Resource
class_name PlayerDefinition

## Player Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Player Definition Contract"). Field types per docs/20 > Contract Field
## Semantics > Player Definition Contract fields. Field-to-type mapping
## recorded in phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.

@export var unique_id: String = ""
@export var max_health: int = 0
@export var base_speed_px_per_second: float = 0.0
@export var acceleration_time_seconds: float = 0.0
@export var deceleration_time_seconds: float = 0.0
@export var body_radius_px: int = 0
@export var hurtbox_definition: ContractEnums.HurtboxDefinition = ContractEnums.HurtboxDefinition.SameAsBody
@export var collector_area_radius_px: int = 0
@export var magnet_radius_px: int = 0
@export var input_buffer: InputBufferDuration = null
@export var starting_weapon_reference_id: String = "" ## Weapon Definition Unique ID

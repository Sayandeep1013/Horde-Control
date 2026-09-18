extends Resource
class_name PickupDefinition

## Pickup Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Pickup Definition Contract"). Field types per docs/20 > Contract Field
## Semantics > Pickup Definition Contract fields. Field-to-type mapping
## recorded in phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## MASTER's "Unique ID and type" bullet is docs/20's single struct
## {Unique ID: string, type: enum}; flattened here into unique_id +
## pickup_type as two plain exports rather than a one-off wrapper struct,
## matching how "Unique ID" is a flat field on every other contract in this
## project (P0.6 report documents this as a deliberate, stated exception to
## "every named struct gets its own Resource class").
##
## The Pickup Definition Contract carries no Entity cap weight field
## (docs/20): the pickup cap is a flat count, not a weighted sum, so this
## schema correctly omits that field.

@export var unique_id: String = ""
@export var pickup_type: ContractEnums.PickupType = ContractEnums.PickupType.XP
@export var value: int = 0
@export var magnet_behaviour: ContractEnums.MagnetBehaviour = ContractEnums.MagnetBehaviour.Attracted
@export var merge_rule: MergeRule = null
@export var lifetime_seconds: float = 0.0
@export var visual_audio_cue: VisualAudioCue = null

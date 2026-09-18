extends Resource
class_name TelegraphData

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Telegraph data"). Describes how an attack or spawn is signalled
## before it resolves.
##
## lead_time_seconds was added by decision D90 (2026-09-18). docs/20's
## Encounter contract requires "Telegraph requirements ... with lead time"
## and the struct had nowhere to hold it. It is NOT the same quantity as
## windup_duration_seconds: wind-up is how long the telegraph plays before
## the attack resolves, lead time is how far ahead of an on-screen spawn the
## telegraph must be scheduled. The Wave Director needs the second to
## schedule; see the Director Configuration's marker lead times.

@export var windup_duration_seconds: float = 0.0
@export var telegraph_shape: ContractEnums.TelegraphShape = ContractEnums.TelegraphShape.Wedge
@export var telegraph_colour: Color = Color.WHITE
@export var audio_cue_id: String = ""
@export var lead_time_seconds: float = 0.0 ## decision D90; distinct from windup_duration_seconds

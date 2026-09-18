extends Resource
class_name SpawnGroup

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Spawn group"). One wave of enemies an encounter emits; a spawn
## group starts at its start offset or earlier if the Escalation Trigger
## starts it; an encounter is an ordered list of these.
##
## direction_weighting_override is a nullable reference to the encounter's
## Directional Weighting rule (P0.6 convention 4: nullable Resource field,
## naturally null when unset - no paired boolean needed).

@export var enemy_definition_id: String = "" ## Enemy Unique ID
@export var count: int = 0
@export var start_offset_seconds: float = 0.0
@export var spawn_interval_seconds: float = 0.0
@export var direction_weighting_override: DirectionalWeightingEntry = null

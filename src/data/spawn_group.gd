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
## D138 (balance pass 2026-10-05): spawns per burst. 1 = the original even
## trickle (one spawn every `spawn_interval_seconds`). N > 1 emits N spawns on
## the same tick and then waits N x `spawn_interval_seconds`, so the average
## rate is unchanged but the enemies arrive as a clump. A Siege Seeker group
## with burst_size > 1 also sends each burst down one of the Siege's lanes.
@export var burst_size: int = 1

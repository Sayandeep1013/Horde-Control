extends Resource
class_name OvertimeCondition

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Overtime condition"). When a wave enters Overtime at its maximum
## duration, and what its finishers are.

@export var stall_threshold: int = 0 ## kills per 30s below which Overtime may fire
@export var finisher_enemy_id: String = "" ## Enemy Unique ID
@export var finisher_spawn_rate: FinisherSpawnRate = null
@export var finisher_drop_override: DropTable = null

extends Resource
class_name SpawnValidationRetry

## Director-specific struct (docs/20 Contract Field Semantics > Director
## Configuration Contract fields > "Spawn validation retry steps and angle
## increment"). How spawn validation shifts along a ring before giving up
## for the tick.

@export var steps: int = 0
@export var angle_degrees: float = 0.0

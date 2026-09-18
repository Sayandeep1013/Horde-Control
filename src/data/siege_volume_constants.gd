extends Resource
class_name SiegeVolumeConstants

## Director-specific struct (docs/20 Contract Field Semantics > Director
## Configuration Contract fields > "Siege volume formula constants"). Inputs
## to the Siege Seeker-count formula.

@export var multiplier_defaults: Array[float] = []
@export var hunter_percentage: float = 0.0
@export var spawn_window_fraction: float = 0.0 ## fraction of wave duration

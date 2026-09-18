extends Resource
class_name OffscreenUpdateThresholds

## Director-specific struct (docs/20 Contract Field Semantics > Director
## Configuration Contract fields > "Off-screen update reduction
## thresholds"). When an off-screen enemy switches to reduced-tick updates.

@export var distance_multiplier: float = 0.0
@export var tick_divisor: int = 0
@export var tower_exclusion_radius_px: int = 0

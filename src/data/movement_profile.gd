extends Resource
class_name MovementProfile

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Movement profile"). The enemy's locomotion values; pathing
## behaviour itself is the separate Pathing fallback behavior field.

@export var speed_multiplier: float = 1.0
@export var body_radius_px: int = 0

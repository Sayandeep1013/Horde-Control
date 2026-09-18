extends Resource
class_name ProjectileDefinition

## Weapon-specific struct (docs/20 Contract Field Semantics > Weapon and
## Evolution Definition Contract fields > "Projectile definition"). The
## projectile a weapon spawns, if any.

@export var speed_px_per_second: int = 0
@export var lifetime_seconds: float = 0.0
@export var pooling_class: String = ""

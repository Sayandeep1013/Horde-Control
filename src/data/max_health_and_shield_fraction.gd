extends Resource
class_name MaxHealthAndShieldFraction

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Maximum health and base shield fraction"). The Tower's
## health pool and its starting shield as a fraction of that pool.

@export var maximum_health: int = 0
@export var base_shield_fraction: float = 0.0

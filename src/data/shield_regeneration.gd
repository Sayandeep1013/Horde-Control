extends Resource
class_name ShieldRegeneration

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Shield regeneration rate and delay"). How and when the
## shield regenerates after damage.

@export var rate_percent_per_second: float = 0.0
@export var delay_seconds: float = 0.0

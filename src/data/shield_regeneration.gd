extends Resource
class_name ShieldRegeneration

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Shield regeneration rate and delay"). How and when the
## shield regenerates after damage.

@export var rate_percent_per_second: float = 0.0
@export var delay_seconds: float = 0.0
## D136 (balance pass 2026-10-05): fraction of `rate_percent_per_second` that
## applies while a wave is open. 1.0 = regenerate at full rate at all times
## (the original rule); 0.0 = the shield only recharges between waves.
@export_range(0.0, 1.0) var in_wave_rate_fraction: float = 1.0

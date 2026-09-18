extends Resource
class_name AttackProfile

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Attack profile"). The enemy's damage-dealing values; wind-up
## timing lives in Telegraph data, not here.

@export var attack_type: ContractEnums.AttackType = ContractEnums.AttackType.Melee
@export var damage_per_hit_or_tick: int = 0
@export var cycle_or_tick_interval_seconds: float = 0.0
@export var reach_or_range_px: int = 0

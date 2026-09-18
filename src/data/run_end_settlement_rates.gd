extends Resource
class_name RunEndSettlementRates

## Economy-specific struct (docs/20 Contract Field Semantics > Economy
## Configuration Contract fields > "Run-End Settlement rates"). Core payout
## formula at run end.

@export var per_biome_cleared_cores: int = 0
@export var per_boss_killed_cores: int = 0
@export var per_full_minute_cores: int = 0

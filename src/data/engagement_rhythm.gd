extends Resource
class_name EngagementRhythm

## Weapon-specific struct (docs/20 Contract Field Semantics > Weapon and
## Evolution Definition Contract fields > "Engagement rhythm (sustained or
## burst) and fire rate"). How the weapon fires over time.

@export var rhythm: ContractEnums.EngagementRhythmKind = ContractEnums.EngagementRhythmKind.Sustained
@export var fire_rate_per_second: float = 0.0

extends Resource
class_name DominanceAuditParameters

## Economy-specific struct (docs/20 Contract Field Semantics > Economy
## Configuration Contract fields > "Dominance audit threshold and sample
## size"). Inputs to the dominant-pair audit.

@export var threshold_fraction: float = 0.0
@export var minimum_runs: int = 0

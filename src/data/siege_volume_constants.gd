extends Resource
class_name SiegeVolumeConstants

## Director-specific struct (docs/20 Contract Field Semantics > Director
## Configuration Contract fields > "Siege volume formula constants"). Inputs
## to the Siege Seeker-count formula.

@export var multiplier_defaults: Array[float] = []
@export var hunter_percentage: float = 0.0
@export var spawn_window_fraction: float = 0.0 ## fraction of wave duration
## D137 (balance pass 2026-10-05): share of the Tower's upgrade DPS bonus
## (live DPS minus base DPS) that the Siege volume formula counts. 1.0 = live
## DPS (the original rule, where Tower damage cards cancel against Siege size);
## 0.0 = base DPS only.
@export_range(0.0, 1.0) var live_dps_bonus_share: float = 1.0

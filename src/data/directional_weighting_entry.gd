extends Resource
class_name DirectionalWeightingEntry

## One entry of Director Configuration's "Directional weighting rules per
## encounter type" struct, keyed by encounter type (docs/20 Contract Field
## Semantics > Director Configuration Contract fields). Also the exact shape
## Encounter.directional_weighting_override and SpawnGroup's direction
## weighting override reuse ("nullable struct, shaped like Director
## Configuration's per-encounter-type directional weighting entry").
## Typed per P0.6 convention 6.

@export var encounter_type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault
@export var lane_count: int = 0
@export var lane_width_degrees: float = 0.0
@export var lane_separation_rule: ContractEnums.LaneSeparationRule = ContractEnums.LaneSeparationRule.Fixed180
@export var heavy_share: float = 0.0
@export var ring: ContractEnums.RingType = ContractEnums.RingType.Tower
@export var hunt_arc_degrees: float = 0.0
@export var hunt_arc_share: float = 0.0

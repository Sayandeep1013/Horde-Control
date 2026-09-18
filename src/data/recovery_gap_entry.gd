extends Resource
class_name RecoveryGapEntry

## One {encounter type, recovery gap} pair (docs/20 Contract Field Semantics
## > Director Configuration Contract fields > "Default recovery gap table").
## Default Minimum recovery gap values by encounter type. Typed per P0.6
## convention 6.

@export var encounter_type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault
@export var recovery_gap_seconds: float = 0.0

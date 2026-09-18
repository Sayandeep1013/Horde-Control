extends Resource
class_name EncounterPriorityEntry

## One {encounter type, priority} pair (docs/20 Contract Field Semantics >
## Director Configuration Contract fields > "Encounter priority table").
## Default Priority values by encounter type. Typed per P0.6 convention 6.

@export var encounter_type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault
@export var priority: int = 0 ## 0 to 100

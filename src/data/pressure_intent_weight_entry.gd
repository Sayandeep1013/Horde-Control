extends Resource
class_name PressureIntentWeightEntry

## One {target intent, weight} pair (docs/20 Contract Field Semantics >
## Director Configuration Contract fields > "Pressure Metric intent
## weights"). The intent_weight term used in the Threat calculation. Typed
## per P0.6 convention 6.

@export var target_intent: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker
@export var weight: float = 0.0

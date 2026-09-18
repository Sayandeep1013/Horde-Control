extends Resource
class_name TargetingRuleParameters

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Targeting rule parameters"). Inputs to the Tower
## Targeting Rule.

@export var range_px: int = 0
@export var intent_preference: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker

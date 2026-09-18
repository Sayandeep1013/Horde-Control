extends Resource
class_name IntentBudgetOverride

## One {target intent, count} pair (docs/20 Contract Field Semantics >
## Encounter Definition Contract fields > "Intent budget overrides").
## Overrides the wave's Enemy intent mix for this specific encounter
## (for example T1's Hunters-only budget). Typed per P0.6 convention 6 -
## never a bare Dictionary or Array.

@export var target_intent: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker
@export var count: int = 0

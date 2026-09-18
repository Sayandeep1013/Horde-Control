extends Resource
class_name EnemyIntentMixEntry

## One {target intent, proportion} pair (docs/20 Contract Field Semantics >
## Wave Definition Contract fields > "Enemy intent mix"). The wave's default
## composition, expressed as proportions (0-1, summing to 1 across a wave's
## full list). Typed per P0.6 convention 6.

@export var target_intent: ContractEnums.TargetIntent = ContractEnums.TargetIntent.TowerSeeker
@export var proportion: float = 0.0 ## 0 to 1

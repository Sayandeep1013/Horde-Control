extends Resource
class_name Reward

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Reward"). The fixed reward an encounter grants on completion;
## used by Encounter.reward and by Encounter.partial_reward_rules (nullable
## use of this same type per P0.6 convention 4).

@export var xp: int = 0
@export var scrap: int = 0
@export var cores: int = 0

extends UpgradeDefinition
class_name TowerUpgradeDefinition

## Tower Upgrade Definition Contract (MASTER_SDLC.md > Content Data
## Contracts > "Tower Upgrade Definition Contract"): "every Tower upgrade
## definition must include every field of the Upgrade Definition Contract,
## with Pool ownership set to Tower, plus" the two fields below. Implemented
## by extending UpgradeDefinition (P0.6 convention 9) rather than copying
## its fields; pool_ownership is inherited and is expected to be set to
## ContractEnums.PoolOwnership.Tower on every instance (the schema check
## asserts this on the sample - Godot cannot pin an inherited export's
## default per-subclass).
##
## Field types per docs/20 > Contract Field Semantics > Tower Upgrade
## Definition Contract fields.

@export var evolution_stage_contribution: int = 0 ## ranks counted toward the Tower's visual evolution stage
@export var draft_weight: int = 0 ## >= 0; 0 excludes a card, every prototype Tower upgrade uses 1 - schema default kept at Godot's natural 0 so the sample's 1 is visibly non-default

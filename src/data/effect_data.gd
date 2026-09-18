extends Resource
class_name EffectData

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Effect"). A single mechanical consequence, used by a status
## effect's Tick effect field. Typed here for forward compatibility with the
## out-of-scope Status Effect Definition Contract (P0.6 convention 2); no
## in-scope P0.6 contract's sample resource uses this struct.

@export var kind: ContractEnums.EffectKind = ContractEnums.EffectKind.Damage
@export var magnitude: float = 0.0
@export var target: ContractEnums.EffectStructTarget = ContractEnums.EffectStructTarget.Player

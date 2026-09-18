extends Resource
class_name BandedValue

## Shared struct (P0.6 convention 5, author decision this session): MASTER's
## Enemy contract requires "Health band" and "Damage band", and the Weapon
## contract requires "Damage band"; docs/20 types the raw value (integer)
## separately from "Band label" (nullable enum {Low, Mid, High}, null in the
## prototype). One resource covers all three usages: Enemy health,
## Enemy damage, Weapon damage per shot.
##
## band_label is meaningless (ignore it) whenever has_band_label is false -
## this is the nullable-enum convention from P0.6 convention 4: Godot cannot
## export a null enum, so a paired boolean carries the "is set" state.

@export var value: int = 0
@export var band_label: ContractEnums.BandLabel = ContractEnums.BandLabel.Low
@export var has_band_label: bool = false

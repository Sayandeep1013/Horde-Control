extends Resource
class_name RepairPrice

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Repair price"). Cost and effect of one Tower Repair
## purchase.
##
## pro_ration_rule: docs/20 names this sub-field but gives no enum member
## list or further structure for it anywhere in Contract Field Semantics -
## flagged as an ambiguity in the P0.6 report. Typed as a free-form
## description string rather than silently inventing enum members.

@export var scrap_cost: int = 0
@export var health_restored: int = 0
@export var pro_ration_rule: String = ""

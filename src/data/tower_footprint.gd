extends Resource
class_name TowerFootprint

## Tower-specific struct (docs/20 Contract Field Semantics > Tower Definition
## Contract fields > "Footprint radius and Interaction Radius"). The Tower's
## physical size and its vulnerability-window radius.

@export var footprint_radius_px: int = 0
@export var interaction_radius_px: int = 0

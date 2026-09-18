extends Resource
class_name MarkerLeadTimes

## Director-specific struct (docs/20 Contract Field Semantics > Director
## Configuration Contract fields > "Off-screen and on-screen marker lead
## times"). How far ahead a spawn marker must appear before its spawn.

@export var off_screen_seconds: float = 0.0
@export var on_screen_minimum_seconds: float = 0.0

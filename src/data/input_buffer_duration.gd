extends Resource
class_name InputBufferDuration

## Player-specific struct (docs/20 Contract Field Semantics > Player
## Definition Contract fields > "Input buffer duration"). How long a queued
## input is held, cleared on pause.

@export var duration_ms: float = 0.0
@export var ticks: int = 0

extends Resource
class_name ArenaSpikeLayout
## Data-driven Spike Trap placement (Register "v1.0 Arena Interactables": eight fixed plates, one on each
## bridge deck and one on the road at its Tower-side end). One entry per plate; `phase_offsets`
## staggers the cycles so a bridge's two plates never raise together.

@export var positions: PackedVector2Array = PackedVector2Array()
@export var phase_offsets: PackedFloat32Array = PackedFloat32Array()

extends Resource
class_name ArenaSpikeLayout
## Data-driven Spike Trap placement (Register "v1.0 Arena Interactables": four fixed plates on the sand
## paths, 380-650 px from the Tower). One entry per plate; `phase_offsets`
## staggers the cycles so the four never raise together.

@export var positions: PackedVector2Array = PackedVector2Array()
@export var phase_offsets: PackedFloat32Array = PackedFloat32Array()

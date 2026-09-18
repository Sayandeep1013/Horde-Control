extends Resource
class_name PressureMetricConstants

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Pressure Metric constants"). Per-wave tuning of the Pressure
## Metric; absent fields fall back to the Director Configuration defaults.
## Reused by Wave.pressure_metric_constants and by Director Configuration's
## "Pressure Metric escalation and de-escalation timers" field.

@export var escalation_threshold: float = 0.0
@export var escalation_hold_time_seconds: float = 0.0
@export var minimum_gap_between_escalations_seconds: float = 0.0
@export var de_escalation_threshold: float = 0.0
@export var de_escalation_lift_threshold: float = 0.0
@export var de_escalation_expiry_seconds: float = 0.0
@export var re_arm_lockout_seconds: float = 0.0

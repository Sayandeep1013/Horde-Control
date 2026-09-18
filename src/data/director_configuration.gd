extends Resource
class_name DirectorConfiguration

## Director Configuration Contract (MASTER_SDLC.md > Content Data Contracts
## > "Director Configuration Contract"). Field types per docs/20 > Contract
## Field Semantics > Shared fields and struct types, and > Director
## Configuration Contract fields. Field-to-type mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## "Directional weighting rules per encounter type" is docs/20's "struct,
## keyed by encounter type" - typed as Array[DirectionalWeightingEntry] per
## P0.6 convention 6, since each entry already carries its own encounter_type
## field (the same struct SpawnGroup and Encounter's nullable override
## reuse).
##
## "Pressure Metric escalation and de-escalation timers" reuses the shared
## PressureMetricConstants struct (docs/20: "Pressure Metric constants
## struct") rather than a new one-off type.

@export var unique_id: String = ""
@export var spawn_ring_geometry: SpawnRingGeometry = null
@export var camera_exclusion_margin_px: int = 0
@export var spawn_validation_retry: SpawnValidationRetry = null
@export var marker_lead_times: MarkerLeadTimes = null
@export var directional_weighting_rules: Array[DirectionalWeightingEntry] = [] ## keyed by encounter type
@export var encounter_priority_table: Array[EncounterPriorityEntry] = []
@export var default_recovery_gap_table: Array[RecoveryGapEntry] = []
@export var inter_wave_gap_defaults: InterWaveGapDefaults = null
@export var post_draft_grace_period_seconds: float = 0.0
@export var pressure_metric_intent_weights: Array[PressureIntentWeightEntry] = []
@export var pressure_metric_timers: PressureMetricConstants = null ## "Pressure Metric escalation and de-escalation timers"; defaults a Wave's own constants may override
@export var offscreen_update_thresholds: OffscreenUpdateThresholds = null
@export var siege_volume_constants: SiegeVolumeConstants = null
@export var health_quadrant_threshold: float = 0.0 ## fraction; below this a pool is recorded as Low

extends Resource
class_name WaveDefinition

## Wave Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Wave Definition Contract"). Field types per docs/20 > Contract Field
## Semantics > Shared fields and struct types, and > Wave Definition
## Contract fields. Field-to-type mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## Spawn budget is explicitly "derived: not authored" (docs/20) - it is NOT
## an @export (P0.6 convention 8 / step 8 of the plan). get_spawn_budget()
## below computes it as "sum of the wave's spawn groups' cap weights"
## (MASTER). A Wave's own field list only carries an Encounter sequence of
## Unique IDs (strings), not embedded Encounter or SpawnGroup resources, and
## Cap weight lives on the Enemy Definition an Encounter's SpawnGroup
## references by ID - so computing the real number needs cross-resource
## lookups a bare schema cannot own. The method therefore takes lookup
## dictionaries (Encounter Unique ID -> EncounterDefinition, Enemy Unique ID
## -> EnemyDefinition) rather than resolving them itself; a later phase's
## EntityRegistry / Wave Director is the natural owner of supplying those
## dictionaries at runtime. This is a method, not a computed property,
## because GDScript properties (via `get`) cannot take parameters.
##
## maximum_duration_seconds is a nullable float (P0.6 convention 4):
## meaningless when has_maximum_duration is false - null for boss waves.

@export var unique_id: String = ""
@export var biome_context_id: String = "" ## Biome Unique ID (out-of-scope contract referenced by ID)
@export var difficulty_band: ContractEnums.DifficultyBand = ContractEnums.DifficultyBand.Low
@export var encounter_sequence: Array[String] = [] ## ordered list of Encounter Unique IDs
@export var enemy_intent_mix: Array[EnemyIntentMixEntry] = []
@export var elite_chance: float = 0.0 ## 0 to 1; 0 in the prototype (no elites)
@export var maximum_duration_seconds: float = 0.0
@export var has_maximum_duration: bool = false ## false = null; true for every wave except boss waves
@export var target_duration_seconds: float = 0.0
@export var inter_wave_gap_seconds: float = 0.0
@export var overtime_condition: OvertimeCondition = null
@export var pressure_metric_constants: PressureMetricConstants = null
@export var boss_overlap_rules: ContractEnums.BossOverlapRules = ContractEnums.BossOverlapRules.NotApplicable

## Derived: not authored (docs/20). Sum of this wave's spawn groups' cap
## weights, resolved through the two lookup dictionaries described above.
func get_spawn_budget(encounter_lookup: Dictionary, enemy_lookup: Dictionary) -> int:
	var total := 0
	for encounter_id in encounter_sequence:
		var encounter: EncounterDefinition = encounter_lookup.get(encounter_id)
		if encounter == null:
			continue
		for group in encounter.spawn_groups:
			var spawn_group := group as SpawnGroup
			var enemy: EnemyDefinition = enemy_lookup.get(spawn_group.enemy_definition_id)
			if enemy == null:
				continue
			total += spawn_group.count * enemy.entity_cap_weight
	return total

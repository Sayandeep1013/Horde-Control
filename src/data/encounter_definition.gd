extends Resource
class_name EncounterDefinition

## Encounter Definition Contract (MASTER_SDLC.md > Content Data Contracts >
## "Encounter Definition Contract"). Field types per docs/20 > Contract
## Field Semantics > Shared fields and struct types, and > Encounter
## Definition Contract fields. Field-to-type mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## directional_weighting_override and partial_reward_rules are nullable
## Resource fields (P0.6 convention 4): naturally null when unset, no
## paired boolean needed. "No encounter may be implemented if it cannot
## define what pressure it applies and how it resolves when failed" (MASTER)
## - reward and failure_resolution still default to a zero-ish state here;
## a consuming system must check them explicitly.

@export var unique_id: String = ""
@export var encounter_type: ContractEnums.EncounterType = ContractEnums.EncounterType.StandardAssault
@export var design_intent: String = ""
@export var pressure_target: float = 0.0
@export var player_answer: String = ""
@export var failure_signature: String = ""
@export var spawn_groups: Array[SpawnGroup] = []
@export var intent_budget_overrides: Array[IntentBudgetOverride] = []
@export var directional_weighting_override: DirectionalWeightingEntry = null ## nullable; overrides Director Configuration's entry for this encounter's type when non-null
@export var telegraph_requirements: Array[TelegraphData] = []
@export var minimum_recovery_gap_seconds: float = 0.0
@export var priority: int = 0 ## 0 to 100; ties by Unique ID ascending
@export var entity_cap_behavior: ContractEnums.EntityCapBehaviour = ContractEnums.EntityCapBehaviour.Throttle
@export var encounter_alive_cap: int = 0
@export var allowed_encounter_tags: Array[String] = []
@export var excluded_encounter_tags: Array[String] = []
@export var reward: Reward = null ## zero for the four prototype encounters (MASTER)
@export var failure_resolution: ContractEnums.FailureResolution = ContractEnums.FailureResolution.RewardForfeited
@export var partial_reward_rules: Reward = null ## nullable; null if the encounter defines none
@export var pause_and_deferral_behavior: ContractEnums.PauseAndDeferralBehaviour = ContractEnums.PauseAndDeferralBehaviour.DeferUntilDraftCloses

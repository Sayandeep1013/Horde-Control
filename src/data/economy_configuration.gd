extends Resource
class_name EconomyConfiguration

## Economy Configuration Contract (MASTER_SDLC.md > Content Data Contracts >
## "Economy Configuration Contract"). Field types per docs/20 > Contract
## Field Semantics > Economy Configuration Contract fields. Field-to-type
## mapping recorded in
## phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md.
##
## See xp_level_cost.gd and console_price_formula.gd for how each contract's
## "formula" field was resolved - flagged as an ambiguity in the P0.6
## report.

@export var unique_id: String = ""
@export var merge_radius_px: int = 0
@export var xp_level_cost: XpLevelCost = null
@export var xp_cap_during_teaching_waves: int = 0
@export var scrap_cap: int = 0
@export var overflow_hopper_capacity: int = 0
@export var hopper_conversion_rule: HopperConversionRule = null
@export var core_persistence_write_cadence_seconds: float = 0.0
@export var run_end_settlement_rates: RunEndSettlementRates = null
@export var console_price_formula: ConsolePriceFormula = null
@export var dominance_audit_parameters: DominanceAuditParameters = null

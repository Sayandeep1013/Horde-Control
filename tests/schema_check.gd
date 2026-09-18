extends SceneTree

## Schema check (MASTER_SDLC.md > Acceptance Test Matrix > Build Checks,
## first task P0.6): "Every content type's data contract schema, including
## Player, Director, and Economy Configuration, validates against a sample
## `.tres` resource with no missing required field."
##
## Three passes:
## 1. Load every schema script under res://src/data/ (contracts and shared
##    structs alike) and confirm zero script errors (P0.6 plan step 9).
## 2. For each of the eleven prototype-scope contracts, check its sample
##    `.tres` against REQUIRED_FIELD_MANIFEST below - a hand-written list of
##    MASTER's Content Data Contracts bullets, independent of what the
##    schema script itself declares (P0.6 review iteration 2, R1 - Major).
## 3. For each of the eleven prototype-scope contracts, load its sample
##    `.tres` under res://src/data/samples/ and recursively walk every
##    @export property the sample's Resource class declares (including
##    inherited ones, so TowerUpgradeDefinition's UpgradeDefinition fields
##    are covered too, and including nested struct Resources, to the depth
##    the field-to-type mapping in
##    phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md
##    describes, and every element of every typed array - not only element
##    [0] - per P0.6 review iteration 2, R4), asserting no field is left at
##    its script-declared default, and asserting the value-domain bounds
##    docs/20 actually states (P0.6 review iteration 2, R11).
##
## How "default" is decided: rather than hardcoding a per-type default table,
## this script instantiates a FRESH copy of the same Resource class (a plain
## `.new()`) and compares each exported property's value against the fresh
## instance's value via Variant equality. Any property equal to its fresh
## default is flagged, UNLESS it is named in one of the three exception
## tables below - each documents, by "ClassName.field_name" (P0.6 review
## iteration 2, R9 - keyed by class AND field, not by bare field name; see
## that finding for why a bare-field-name key is wrong), why that field's
## match to its default in THIS sample is correct rather than an omission:
##
## NULLABLE_RESOURCE_OK: "ClassName.field" pairs whose type is a nullable
## Resource reference (P0.6 convention 4) - null is a legitimate value, so a
## null match to default is not flagged; if the sample populated the field
## anyway, the check still recurses into it normally.
##
## NULLABLE_PRIMITIVE_PAIRS: the has_<field>/<field> pairs (P0.6 convention
## 4) for a nullable primitive or enum, keyed "ClassName.value_field". Each
## entry's "mode" is either:
##   - "require_set": this project's samples must demonstrate the SET state
##     (has_ true, value checked against its default) - used for max_rank,
##     maximum_duration_seconds and recursive_interaction_guard, where a
##     sample that never demonstrates a populated value would be a weaker
##     fixture than the project wants.
##   - "optional": the sample may demonstrate either state, and a populated
##     value is NEVER a failure (P0.6 review iteration 2, R9) - used for
##     BandedValue.band_label, which docs/20 states is "null in the
##     prototype, populated by document 12 ... from the vertical slice
##     onward". Under the old bare-field-name, boolean "expect_set" design,
##     a populated band label would have started failing the check the
##     moment content did what docs/20 says it will; "optional" mode can
##     never fail on a populated value, only on a value claimed set (has_
##     true) but left at its default (a genuine authoring bug).
##
## SKIP_ALWAYS: "ClassName.field" pairs with no possible non-default value to
## demonstrate - today only PlayerDefinition.hurtbox_definition, a
## single-member enum {SameAsBody} where the schema default and the only
## valid value are the same integer, so value equality can never distinguish
## "set" from "never touched". (P0.6 review iteration 2, R5/R6: known
## limitations, recorded rather than fixed this pass - see
## evidence/p06_fixes.md.)
##
## Exits 0 on pass, 1 on failure, so it can gate CI, matching the pattern in
## tests/settings_check.gd.

const NULLABLE_RESOURCE_OK: Array[String] = [
	"EncounterDefinition.directional_weighting_override", # nullable reference to the encounter's Directional Weighting rule; overrides Director Configuration's entry for this encounter's type when non-null
	"SpawnGroup.direction_weighting_override", # SpawnGroup's own field name for the same struct (docs/20's Spawn group struct: "direction weighting override")
	"EncounterDefinition.partial_reward_rules", # null if the encounter defines none
]

## {"ClassName.value_field": {"flag": <has_ field name>, "mode": "require_set" | "optional"}}
const NULLABLE_PRIMITIVE_PAIRS := {
	"UpgradeDefinition.max_rank": {"flag": "has_max_rank", "mode": "require_set"},
	"WaveDefinition.maximum_duration_seconds": {"flag": "has_maximum_duration", "mode": "require_set"},
	"UpgradeDefinition.recursive_interaction_guard": {"flag": "has_recursive_interaction_guard", "mode": "require_set"}, # added P0.6 review iteration 2, Ruling #1 / R7
	"BandedValue.band_label": {"flag": "has_band_label", "mode": "optional"}, # docs/20: null in the prototype, populated by doc 12 from the vertical slice onward - see R9 above
}

const SKIP_ALWAYS: Array[String] = [
	"PlayerDefinition.hurtbox_definition", # single-member enum {SameAsBody}; default == only valid value
]

## Value-domain assertions (P0.6 review iteration 2, R11) for exactly the
## bounds docs/20's Contract Field Semantics states in prose for an in-scope
## contract's own fields - no bound is invented beyond what docs/20 gives.
## Keyed "ClassName.field", parallel to the exception tables above. A bound
## side ("min" / "max") is omitted when docs/20 does not state that side.
## The "proportion summing to 1" half of Enemy intent mix's domain is a
## whole-array constraint, not a per-field bound, and is asserted in
## _check_contract()'s Wave Definition contract-specific block instead.
const DOMAIN_CONSTRAINTS := {
	"EnemyDefinition.entity_cap_weight": {"min": 1}, # docs/20 shared table: "Entity cap weight | integer >= 1"
	"EncounterDefinition.priority": {"min": 0, "max": 100}, # docs/20 shared table: "Priority | integer 0 to 100"
	"EncounterPriorityEntry.priority": {"min": 0, "max": 100}, # same shared "Priority" field, reused on Director Configuration's per-encounter-type table
	"WaveDefinition.elite_chance": {"min": 0.0, "max": 1.0}, # docs/20 Wave Definition Contract fields: "Elite chance | float 0 to 1"
	"EnemyIntentMixEntry.proportion": {"min": 0.0, "max": 1.0}, # docs/20 Wave Definition Contract fields: "proportion: float 0-1 summing to 1"
	"TowerUpgradeDefinition.draft_weight": {"min": 0}, # docs/20 Tower Upgrade Definition Contract fields: "Draft weight | integer >= 0"
}

## Required-field manifest (P0.6 review iteration 2, R1 - Major fix).
## Hand-transcribed from MASTER_SDLC.md > Content Data Contracts
## (~line 2182), one entry per contract bullet, INDEPENDENT of anything any
## schema script under src/data/ declares. This is what closes R1: the
## per-property walk below (_exported_properties) can only ever see what a
## script currently declares, so if a required field were removed from a
## schema, it would disappear from the script AND the sample at the same
## time and the walk would stay green - the walk enforces "no declared field
## is left at its default", not MASTER's "no missing required field". This
## manifest is typed here by hand from MASTER's prose, not derived from any
## script, specifically so a schema and its manifest entry CAN disagree.
##
## Each entry is a Dictionary:
##   {"master": "<the MASTER bullet, verbatim or lightly paraphrased>",
##    "exports": [<export name>, ...]}
## for a field realized as one or more @export properties on the contract's
## own script (its own class's get_property_list(), which for
## TowerUpgradeDefinition includes UpgradeDefinition's inherited exports
## too - see UPGRADE_DEFINITION_REQUIRED_FIELDS below), or:
##   {"master": "<the MASTER bullet>", "method": "<method name>"}
## for MASTER's one derived (explicitly NOT authored) field, Wave's Spawn
## budget - asserted by method presence rather than property presence.
##
## A "master" bullet that maps to more than one export (a split - e.g.
## Pickup's "Unique ID and type" -> unique_id + pickup_type) or to a
## has_<field> pair for a nullable primitive (e.g. Upgrade's "Maximum rank"
## -> max_rank + has_max_rank) lists every export it maps to, so the
## rename/split is recorded here as data rather than assumed silently.

const UPGRADE_DEFINITION_REQUIRED_FIELDS := [
	{"master": "Unique ID.", "exports": ["unique_id"]},
	{"master": "Pool ownership.", "exports": ["pool_ownership"]},
	{"master": "Rarity.", "exports": ["rarity"]},
	{"master": "Maximum rank.", "exports": ["max_rank", "has_max_rank"]},
	{"master": "Prerequisites.", "exports": ["prerequisites"]},
	{"master": "Exclusions.", "exports": ["exclusions"]},
	{"master": "Effect description.", "exports": ["effect_description"]},
	{"master": "Effect target.", "exports": ["effect_target"]},
	{"master": "Effect per rank.", "exports": ["effect_per_rank"]},
	{"master": "Console price per rank.", "exports": ["console_price_per_rank"]},
	{"master": "Recursive interaction guard.", "exports": ["recursive_interaction_guard", "has_recursive_interaction_guard"]},
	{"master": "Visual readability impact.", "exports": ["visual_readability_impact"]},
	{"master": "Performance cost category.", "exports": ["performance_cost_category"]},
]

const REQUIRED_FIELD_MANIFEST := {
	"Enemy Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Target intent.", "exports": ["target_intent"]},
		{"master": "Movement profile.", "exports": ["movement_profile"]},
		{"master": "Attack profile.", "exports": ["attack_profile"]},
		{"master": "Telegraph data.", "exports": ["telegraph_data"]},
		{"master": "Health band.", "exports": ["health_band"]},
		{"master": "Damage band.", "exports": ["damage_band"]},
		{"master": "Contact behavior.", "exports": ["contact_behaviour"]},
		{"master": "Pathing fallback behavior.", "exports": ["pathing_fallback_behavior"]},
		{"master": "Entity cap weight.", "exports": ["entity_cap_weight"]},
		{"master": "Elite eligibility.", "exports": ["elite_eligibility"]},
		{"master": "Allowed affixes.", "exports": ["allowed_affixes"]},
		{"master": "Biome tags.", "exports": ["biome_tags"]},
		{"master": "Readability profile.", "exports": ["readability_profile"]},
		{"master": "Drop table.", "exports": ["drop_table"]},
	],
	"Encounter Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Encounter type.", "exports": ["encounter_type"]},
		{"master": "Design intent.", "exports": ["design_intent"]},
		{"master": "Pressure target.", "exports": ["pressure_target"]},
		{"master": "Player answer.", "exports": ["player_answer"]},
		{"master": "Failure signature.", "exports": ["failure_signature"]},
		{"master": "Spawn groups.", "exports": ["spawn_groups"]},
		{"master": "Intent budget overrides.", "exports": ["intent_budget_overrides"]},
		{"master": "Directional weighting override.", "exports": ["directional_weighting_override"]},
		{"master": "Telegraph requirements.", "exports": ["telegraph_requirements"]},
		{"master": "Minimum recovery gap.", "exports": ["minimum_recovery_gap_seconds"]},
		{"master": "Priority.", "exports": ["priority"]},
		{"master": "Entity cap behavior.", "exports": ["entity_cap_behavior"]},
		{"master": "Encounter alive cap.", "exports": ["encounter_alive_cap"]},
		{"master": "Allowed encounter tags.", "exports": ["allowed_encounter_tags"]},
		{"master": "Excluded encounter tags.", "exports": ["excluded_encounter_tags"]},
		{"master": "Reward.", "exports": ["reward"]},
		{"master": "Failure resolution.", "exports": ["failure_resolution"]},
		{"master": "Partial reward rules.", "exports": ["partial_reward_rules"]},
		{"master": "Pause and deferral behavior.", "exports": ["pause_and_deferral_behavior"]},
	],
	"Upgrade Definition": UPGRADE_DEFINITION_REQUIRED_FIELDS,
	"Wave Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Biome context.", "exports": ["biome_context_id"]},
		{"master": "Difficulty band.", "exports": ["difficulty_band"]},
		{"master": "Encounter sequence.", "exports": ["encounter_sequence"]},
		{"master": "Spawn budget (derived: sum of its spawn groups' cap weights).", "method": "get_spawn_budget"},
		{"master": "Enemy intent mix.", "exports": ["enemy_intent_mix"]},
		{"master": "Elite chance.", "exports": ["elite_chance"]},
		{"master": "Maximum duration (nullable; null for boss waves).", "exports": ["maximum_duration_seconds", "has_maximum_duration"]},
		{"master": "Target duration.", "exports": ["target_duration_seconds"]},
		{"master": "Inter-wave gap.", "exports": ["inter_wave_gap_seconds"]},
		{"master": "Overtime condition (stall threshold and finisher definition).", "exports": ["overtime_condition"]},
		{"master": "Pressure Metric constants (escalation and de-escalation thresholds).", "exports": ["pressure_metric_constants"]},
		{"master": "Boss overlap rules.", "exports": ["boss_overlap_rules"]},
	],
	"Tower Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Maximum health and base shield fraction.", "exports": ["max_health_and_shield_fraction"]},
		{"master": "Shield regeneration rate and delay.", "exports": ["shield_regeneration"]},
		{"master": "Footprint radius and Interaction Radius.", "exports": ["tower_footprint"]},
		{"master": "Base weapon reference (a Weapon Definition).", "exports": ["base_weapon_reference_id"]},
		{"master": "Targeting rule parameters (range, intent preference).", "exports": ["targeting_rule_parameters"]},
		{"master": "Evolution stage thresholds (four stages).", "exports": ["evolution_stage_thresholds"]},
		{"master": "Repair price.", "exports": ["repair_price"]},
		{"master": "Persistent asset rules (drones across biomes).", "exports": ["persistent_asset_rules"]},
	],
	"Tower Upgrade Definition": UPGRADE_DEFINITION_REQUIRED_FIELDS + [
		{"master": "Evolution stage contribution (integer ranks counted toward the visual stage).", "exports": ["evolution_stage_contribution"]},
		{"master": "Draft weight (0 excludes; every prototype upgrade 1).", "exports": ["draft_weight"]},
		# "Pool ownership set to Tower" (MASTER) is a VALUE constraint on the
		# inherited pool_ownership export, not a presence one; asserted in
		# _check_contract()'s Tower Upgrade Definition contract-specific
		# block below, not here.
	],
	"Weapon and Evolution Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Effective range.", "exports": ["effective_range_px"]},
		{"master": "Coverage shape (cone, line, radius, single target).", "exports": ["coverage_shape"]},
		{"master": "Target count.", "exports": ["target_count"]},
		{"master": "Engagement rhythm (sustained or burst) and fire rate.", "exports": ["engagement_rhythm"]},
		{"master": "Damage band.", "exports": ["damage_band"]},
		{"master": "Projectile definition (speed, lifetime, pooling class).", "exports": ["projectile_definition"]},
		{"master": "Evolution prerequisites and the evolution target.", "exports": ["evolution_requirement"]},
		{"master": "Which of range, coverage, target count, or rhythm the evolution changes (at least one).", "exports": ["evolution_changes_axes"]},
	],
	"Pickup Definition": [
		{"master": "Unique ID and type (XP, Scrap, Core; Health from the vertical slice).", "exports": ["unique_id", "pickup_type"]},
		{"master": "Value.", "exports": ["value"]},
		{"master": "Magnet behaviour (attracted or static).", "exports": ["magnet_behaviour"]},
		{"master": "Merge rule (same type only).", "exports": ["merge_rule"]},
		{"master": "Lifetime in simulation seconds.", "exports": ["lifetime_seconds"]},
		{"master": "Visual and audio cue.", "exports": ["visual_audio_cue"]},
	],
	"Player Definition": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Maximum health.", "exports": ["max_health"]},
		{"master": "Base speed.", "exports": ["base_speed_px_per_second"]},
		{"master": "Acceleration time to base speed.", "exports": ["acceleration_time_seconds"]},
		{"master": "Deceleration time to stop.", "exports": ["deceleration_time_seconds"]},
		{"master": "Body radius.", "exports": ["body_radius_px"]},
		{"master": "Hurtbox definition.", "exports": ["hurtbox_definition"]},
		{"master": "Collector area radius.", "exports": ["collector_area_radius_px"]},
		{"master": "Magnet radius.", "exports": ["magnet_radius_px"]},
		{"master": "Input buffer duration.", "exports": ["input_buffer"]},
		{"master": "Starting weapon reference (a Weapon Definition).", "exports": ["starting_weapon_reference_id"]},
	],
	"Director Configuration": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Spawn ring geometry (Tower ring and view ring).", "exports": ["spawn_ring_geometry"]},
		{"master": "Camera exclusion margin.", "exports": ["camera_exclusion_margin_px"]},
		{"master": "Spawn validation retry steps and angle increment.", "exports": ["spawn_validation_retry"]},
		{"master": "Off-screen and on-screen marker lead times.", "exports": ["marker_lead_times"]},
		{"master": "Directional weighting rules per encounter type.", "exports": ["directional_weighting_rules"]},
		{"master": "Encounter priority table.", "exports": ["encounter_priority_table"]},
		{"master": "Default recovery gap table.", "exports": ["default_recovery_gap_table"]},
		{"master": "Inter-wave gap defaults.", "exports": ["inter_wave_gap_defaults"]},
		{"master": "Post-draft grace period.", "exports": ["post_draft_grace_period_seconds"]},
		{"master": "Pressure Metric intent weights.", "exports": ["pressure_metric_intent_weights"]},
		{"master": "Pressure Metric escalation and de-escalation timers.", "exports": ["pressure_metric_timers"]},
		{"master": "Off-screen update reduction thresholds.", "exports": ["offscreen_update_thresholds"]},
		{"master": "Siege volume formula constants.", "exports": ["siege_volume_constants"]},
		{"master": "Health quadrant threshold.", "exports": ["health_quadrant_threshold"]},
	],
	"Economy Configuration": [
		{"master": "Unique ID.", "exports": ["unique_id"]},
		{"master": "Merge radius.", "exports": ["merge_radius_px"]},
		{"master": "XP shard value and level cost formula.", "exports": ["xp_level_cost"]},
		{"master": "XP cap during teaching waves.", "exports": ["xp_cap_during_teaching_waves"]},
		{"master": "Scrap cap.", "exports": ["scrap_cap"]},
		{"master": "Overflow hopper capacity.", "exports": ["overflow_hopper_capacity"]},
		{"master": "Hopper-to-Core conversion rate and trigger.", "exports": ["hopper_conversion_rule"]},
		{"master": "Core persistence write cadence.", "exports": ["core_persistence_write_cadence_seconds"]},
		{"master": "Run-End Settlement rates.", "exports": ["run_end_settlement_rates"]},
		{"master": "Upgrade Console price formula.", "exports": ["console_price_formula"]},
		{"master": "Dominance audit threshold and sample size.", "exports": ["dominance_audit_parameters"]},
	],
}

## Struct-level required-field manifest (P0.6 review iteration 2 follow-up,
## closing the residual the same reviewer scored 9/10 and flagged in a fresh
## pass). REQUIRED_FIELD_MANIFEST above closes R1 at the CONTRACT level: it
## independently asserts that every MASTER bullet has a matching @export on
## the contract's own schema script. But roughly a dozen of MASTER's bullets
## are compound and name sub-quantities the schema puts inside a struct
## Resource (e.g. "XP shard value and level cost formula" -> the wrapper
## export xp_level_cost, whose class XpLevelCost has its own shard_value,
## base_cost, and per_level_increment fields). REQUIRED_FIELD_MANIFEST only
## ever asserted the wrapper export exists - it had nothing to say about
## XpLevelCost's own three fields - so deleting XpLevelCost.shard_value (or
## TowerFootprint.interaction_radius_px, docs/20's other reviewer-demonstrated
## case) from both the struct script and its sample left the whole check at
## exit 0: the wrapper export (xp_level_cost / tower_footprint) still existed,
## and Pass 3's generic default-value walk below can only ever see what the
## struct script currently declares, so a field deleted from script AND
## sample together vanishes from that walk too.
##
## STRUCT_REQUIRED_FIELD_MANIFEST closes that residual one level down, using
## the exact same independence rule as REQUIRED_FIELD_MANIFEST: every entry
## is hand-transcribed from docs/20_Technical_Architecture.md, section
## "Contract Field Semantics" - the "Shared fields and struct types" table
## (whose struct types are written out in full: Telegraph data, Spawn group,
## Movement profile, Attack profile, Effect, Overtime condition, Pressure
## Metric constants, Drop table, Reward) plus the contract-specific tables
## beneath it, for the struct types unique to one contract (Tower's
## footprint/interaction radius pair, Economy's XP cost struct, Pickup's
## merge rule, and so on) - NEVER from the struct .gd scripts themselves,
## so a script and its manifest entry can disagree.
##
## Keyed by STRUCT CLASS NAME (Script.get_global_name(), matching the key
## _validate_resource() below already computes), not by contract display
## name or by MASTER bullet, because one struct class is routinely reused
## across more than one contract or more than one field on the same
## contract (TelegraphData is EnemyDefinition.telegraph_data AND every
## element of EncounterDefinition.telegraph_requirements; DropTable is
## EnemyDefinition.drop_table AND OvertimeCondition.finisher_drop_override;
## PressureMetricConstants is both DirectorConfiguration's and
## WaveDefinition's field of that name; RingDefinition is both
## SpawnRingGeometry.tower_ring and .view_ring). One entry here covers
## every place that class appears - no separate per-contract or per-field
## copy is kept, so there is nothing to let drift out of sync.
##
## Each entry's dictionaries use "docs20" rather than REQUIRED_FIELD_MANIFEST's
## "master" key, on purpose: these strings are transcribed from docs/20's
## struct-shape prose, not from a MASTER bullet (MASTER never itemises a
## struct's own sub-fields; only docs/20 does). Same {"...": ..., "exports":
## [...]} / {"...": ..., "method": "..."} shape as REQUIRED_FIELD_MANIFEST
## otherwise, including the "method" form for a sub-quantity docs/20 types
## as part of a struct but the schema correctly resolves rather than
## authors (Merge rule's "match radius" is a reference to Economy
## Configuration's own Merge radius field, not a per-pickup number - see
## merge_rule.gd; Upgrade Console price formula's "formula" is a pure
## function of scrap_per_rank and a caller-supplied rank, not stored data -
## see console_price_formula.gd - both follow the precedent Wave's Spawn
## budget already set in REQUIRED_FIELD_MANIFEST above).
##
## Checked by _check_struct_required_fields(), called from inside
## _validate_resource() below for every Resource instance the recursive
## walk visits - the contract root, every nested struct at any depth, and
## every element of every typed array - so an entry here is exercised
## wherever a sample actually instantiates that class, with no separate
## per-contract driver list to keep in sync (unlike CONTRACTS below, which
## IS a hand-kept driver list, because contract roots are not reached by
## any recursion of their own).
##
## A struct class with no entry below is either: contract_enums.gd
## (ContractEnums holds only enum definitions - no @export instance fields
## exist to require, so it is not a struct resource at all), or BandedValue
## (src/data/banded_value.gd, used by EnemyDefinition.health_band,
## EnemyDefinition.damage_band, and WeaponDefinition.damage_band): docs/20
## types BandedValue's two sub-quantities as separate shared-table rows -
## "Health" (integer) and "Band label" (nullable enum {Low, Mid, High}) -
## and never writes out a combined struct shape resembling BandedValue's
## three fields (value, band_label, has_band_label). Grouping Health and
## Band label into one Resource is a P0.6 schema convention (see
## banded_value.gd's own header comment, "P0.6 convention 5"), not a
## docs/20-stated struct - giving it an entry here would mean transcribing
## the schema's own convention back into the manifest, the exact derivation
## this manifest exists to avoid. BandedValue.value is still exercised by
## the generic default-value walk (Pass 3, below) and BandedValue.band_label
## already has its own NULLABLE_PRIMITIVE_PAIRS entry above; only a full
## deletion of BandedValue.value from script and sample together would
## still slip through undetected - recorded as a known gap in
## evidence/p06_fixes_iter2.md rather than fixed this pass.
##
## EffectData has an entry below (docs/20's shared "Effect" struct is
## written out in full), but it is inert today: none of the CONTRACTS
## below instantiate it anywhere in their sample graphs. docs/20 says
## Effect is "used by a status effect's Tick effect field", and Status
## Effect Definition is a slice-only, deferred contract with no schema
## script or sample under src/data/ yet - the entry starts being exercised
## the day that contract is built.
const STRUCT_REQUIRED_FIELD_MANIFEST := {
	## BandedValue's shape is stated in MASTER_SDLC.md > Review Decision Log >
	## D87, not in docs/20, which types the value and the band label as two
	## separate rows of the shared table and never writes the combined struct.
	## This entry was omitted in the first struct-manifest pass on the ground
	## that no document of record wrote the shape, which a reviewer showed was
	## false - D87 names all three fields. Transcribed from D87, not from
	## banded_value.gd, so the manifest and the script can still disagree.
	"BandedValue": [
		{"docs20": "BandedValue struct (MASTER Review Decision Log D87, author decision): an integer value.", "exports": ["value"]},
		{"docs20": "BandedValue struct (MASTER Review Decision Log D87, author decision): a {Low, Mid, High} band label.", "exports": ["band_label"]},
		{"docs20": "BandedValue struct (MASTER Review Decision Log D87, author decision): a boolean recording whether the label is set.", "exports": ["has_band_label"]},
	],
	"ReadabilityProfile": [
		{"docs20": "Readability profile struct (Shared fields and struct types): silhouette class.", "exports": ["silhouette_class"]},
		{"docs20": "Readability profile struct (Shared fields and struct types): reserved colour.", "exports": ["reserved_colour"]},
		{"docs20": "Readability profile struct (Shared fields and struct types): minimum on-screen size.", "exports": ["minimum_on_screen_size_px"]},
	],
	"TelegraphData": [
		{"docs20": "Telegraph data struct (Shared fields and struct types): wind-up duration.", "exports": ["windup_duration_seconds"]},
		{"docs20": "Telegraph data struct (Shared fields and struct types): telegraph shape.", "exports": ["telegraph_shape"]},
		{"docs20": "Telegraph data struct (Shared fields and struct types): telegraph colour reference.", "exports": ["telegraph_colour"]},
		{"docs20": "Telegraph data struct (Shared fields and struct types): audio cue ID.", "exports": ["audio_cue_id"]},
		{"docs20": "Telegraph data struct (Shared fields and struct types): lead time.", "exports": ["lead_time_seconds"]},
	],
	"SpawnGroup": [
		{"docs20": "Spawn group struct (Shared fields and struct types): enemy definition.", "exports": ["enemy_definition_id"]},
		{"docs20": "Spawn group struct (Shared fields and struct types): count.", "exports": ["count"]},
		{"docs20": "Spawn group struct (Shared fields and struct types): start offset.", "exports": ["start_offset_seconds"]},
		{"docs20": "Spawn group struct (Shared fields and struct types): spawn interval.", "exports": ["spawn_interval_seconds"]},
		{"docs20": "Spawn group struct (Shared fields and struct types): direction weighting override.", "exports": ["direction_weighting_override"]},
	],
	"MovementProfile": [
		{"docs20": "Movement profile struct (Shared fields and struct types): speed multiplier.", "exports": ["speed_multiplier"]},
		{"docs20": "Movement profile struct (Shared fields and struct types): body radius.", "exports": ["body_radius_px"]},
	],
	"AttackProfile": [
		{"docs20": "Attack profile struct (Shared fields and struct types): attack type.", "exports": ["attack_type"]},
		{"docs20": "Attack profile struct (Shared fields and struct types): damage per hit or tick.", "exports": ["damage_per_hit_or_tick"]},
		{"docs20": "Attack profile struct (Shared fields and struct types): cycle or tick interval.", "exports": ["cycle_or_tick_interval_seconds"]},
		{"docs20": "Attack profile struct (Shared fields and struct types): reach or range.", "exports": ["reach_or_range_px"]},
	],
	"EffectData": [
		{"docs20": "Effect struct (Shared fields and struct types): kind.", "exports": ["kind"]},
		{"docs20": "Effect struct (Shared fields and struct types): magnitude.", "exports": ["magnitude"]},
		{"docs20": "Effect struct (Shared fields and struct types): target.", "exports": ["target"]},
	], # inert today - see header note; no CONTRACTS sample instantiates EffectData yet
	"OvertimeCondition": [
		{"docs20": "Overtime condition struct (Shared fields and struct types): stall threshold.", "exports": ["stall_threshold"]},
		{"docs20": "Overtime condition struct (Shared fields and struct types): finisher enemy reference.", "exports": ["finisher_enemy_id"]},
		{"docs20": "Overtime condition struct (Shared fields and struct types): finisher spawn rate.", "exports": ["finisher_spawn_rate"]},
		{"docs20": "Overtime condition struct (Shared fields and struct types): finisher drop override.", "exports": ["finisher_drop_override"]},
	],
	"FinisherSpawnRate": [
		{"docs20": "Overtime condition struct > finisher spawn rate sub-struct (Shared fields and struct types): count.", "exports": ["count"]},
		{"docs20": "Overtime condition struct > finisher spawn rate sub-struct (Shared fields and struct types): interval.", "exports": ["interval_seconds"]},
	],
	"PressureMetricConstants": [
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): escalation threshold.", "exports": ["escalation_threshold"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): escalation hold time.", "exports": ["escalation_hold_time_seconds"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): minimum gap between escalations.", "exports": ["minimum_gap_between_escalations_seconds"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): de-escalation threshold.", "exports": ["de_escalation_threshold"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): de-escalation lift threshold.", "exports": ["de_escalation_lift_threshold"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): de-escalation expiry.", "exports": ["de_escalation_expiry_seconds"]},
		{"docs20": "Pressure Metric constants struct (Shared fields and struct types): re-arm lockout.", "exports": ["re_arm_lockout_seconds"]},
	],
	"DropTable": [
		{"docs20": "Drop table struct (Shared fields and struct types): XP shards.", "exports": ["xp_shards"]},
		{"docs20": "Drop table struct (Shared fields and struct types): Scrap.", "exports": ["scrap"]},
		{"docs20": "Drop table struct (Shared fields and struct types): Cores.", "exports": ["cores"]},
	],
	"Reward": [
		{"docs20": "Reward struct (Shared fields and struct types): XP.", "exports": ["xp"]},
		{"docs20": "Reward struct (Shared fields and struct types): Scrap.", "exports": ["scrap"]},
		{"docs20": "Reward struct (Shared fields and struct types): Cores.", "exports": ["cores"]},
	],
	"IntentBudgetOverride": [
		{"docs20": "Encounter Definition Contract fields > Intent budget overrides entry: target intent.", "exports": ["target_intent"]},
		{"docs20": "Encounter Definition Contract fields > Intent budget overrides entry: count.", "exports": ["count"]},
	],
	"EnemyIntentMixEntry": [
		{"docs20": "Wave Definition Contract fields > Enemy intent mix entry: target intent.", "exports": ["target_intent"]},
		{"docs20": "Wave Definition Contract fields > Enemy intent mix entry: proportion.", "exports": ["proportion"]},
	],
	"MaxHealthAndShieldFraction": [
		{"docs20": "Tower Definition Contract fields > Maximum health and base shield fraction struct: maximum health.", "exports": ["maximum_health"]},
		{"docs20": "Tower Definition Contract fields > Maximum health and base shield fraction struct: base shield fraction.", "exports": ["base_shield_fraction"]},
	],
	"ShieldRegeneration": [
		{"docs20": "Tower Definition Contract fields > Shield regeneration rate and delay struct: rate.", "exports": ["rate_percent_per_second"]},
		{"docs20": "Tower Definition Contract fields > Shield regeneration rate and delay struct: delay.", "exports": ["delay_seconds"]},
	],
	"TowerFootprint": [
		{"docs20": "Tower Definition Contract fields > Footprint radius and Interaction Radius struct: footprint radius.", "exports": ["footprint_radius_px"]},
		{"docs20": "Tower Definition Contract fields > Footprint radius and Interaction Radius struct: Interaction Radius.", "exports": ["interaction_radius_px"]},
	],
	"TargetingRuleParameters": [
		{"docs20": "Tower Definition Contract fields > Targeting rule parameters struct: range.", "exports": ["range_px"]},
		{"docs20": "Tower Definition Contract fields > Targeting rule parameters struct: intent preference.", "exports": ["intent_preference"]},
	],
	"RepairPrice": [
		{"docs20": "Tower Definition Contract fields > Repair price struct: Scrap cost.", "exports": ["scrap_cost"]},
		{"docs20": "Tower Definition Contract fields > Repair price struct: health restored.", "exports": ["health_restored"]},
		{"docs20": "Tower Definition Contract fields > Repair price struct: pro-ration rule.", "exports": ["pro_ration_rule"]},
	],
	"PersistentAssetRule": [
		{"docs20": "Tower Definition Contract fields > Persistent asset rules entry: asset class.", "exports": ["asset_class"]},
		{"docs20": "Tower Definition Contract fields > Persistent asset rules entry: persists across biomes.", "exports": ["persists_across_biomes"]},
	],
	"EngagementRhythm": [
		{"docs20": "Weapon and Evolution Definition Contract fields > Engagement rhythm and fire rate struct: rhythm.", "exports": ["rhythm"]},
		{"docs20": "Weapon and Evolution Definition Contract fields > Engagement rhythm and fire rate struct: fire rate.", "exports": ["fire_rate_per_second"]},
	],
	"ProjectileDefinition": [
		{"docs20": "Weapon and Evolution Definition Contract fields > Projectile definition struct: speed.", "exports": ["speed_px_per_second"]},
		{"docs20": "Weapon and Evolution Definition Contract fields > Projectile definition struct: lifetime.", "exports": ["lifetime_seconds"]},
		{"docs20": "Weapon and Evolution Definition Contract fields > Projectile definition struct: pooling class.", "exports": ["pooling_class"]},
	],
	"WeaponEvolutionRequirement": [
		{"docs20": "Weapon and Evolution Definition Contract fields > Evolution prerequisites and the evolution target struct: prerequisites.", "exports": ["prerequisites"]},
		{"docs20": "Weapon and Evolution Definition Contract fields > Evolution prerequisites and the evolution target struct: evolution target.", "exports": ["evolution_target_id"]},
	],
	"MergeRule": [
		{"docs20": "Pickup Definition Contract fields > Merge rule struct: trigger.", "exports": ["trigger"]},
		{"docs20": "Pickup Definition Contract fields > Merge rule struct: same type only.", "exports": ["same_type_only"]},
		{"docs20": "Pickup Definition Contract fields > Merge rule struct: match radius (reference to Economy Configuration's Merge radius field; derived, not authored - see merge_rule.gd).", "method": "get_match_radius_px"},
		{"docs20": "Pickup Definition Contract fields > Merge rule struct: resulting behaviour.", "exports": ["resulting_behaviour"]},
	],
	"VisualAudioCue": [
		{"docs20": "Pickup Definition Contract fields > Visual and audio cue struct: sprite reference.", "exports": ["sprite_reference"]},
		{"docs20": "Pickup Definition Contract fields > Visual and audio cue struct: audio cue ID.", "exports": ["audio_cue_id"]},
	],
	"InputBufferDuration": [
		{"docs20": "Player Definition Contract fields > Input buffer duration struct: duration.", "exports": ["duration_ms"]},
		{"docs20": "Player Definition Contract fields > Input buffer duration struct: ticks.", "exports": ["ticks"]},
	],
	"SpawnRingGeometry": [
		{"docs20": "Director Configuration Contract fields > Spawn ring geometry struct: Tower ring.", "exports": ["tower_ring"]},
		{"docs20": "Director Configuration Contract fields > Spawn ring geometry struct: view ring.", "exports": ["view_ring"]},
	],
	"RingDefinition": [
		{"docs20": "Director Configuration Contract fields > Spawn ring geometry > Tower ring / view ring sub-struct: inner radius.", "exports": ["inner_radius_px"]},
		{"docs20": "Director Configuration Contract fields > Spawn ring geometry > Tower ring / view ring sub-struct: width.", "exports": ["width_px"]},
	],
	"SpawnValidationRetry": [
		{"docs20": "Director Configuration Contract fields > Spawn validation retry steps and angle increment struct: steps.", "exports": ["steps"]},
		{"docs20": "Director Configuration Contract fields > Spawn validation retry steps and angle increment struct: angle.", "exports": ["angle_degrees"]},
	],
	"MarkerLeadTimes": [
		{"docs20": "Director Configuration Contract fields > Off-screen and on-screen marker lead times struct: off-screen.", "exports": ["off_screen_seconds"]},
		{"docs20": "Director Configuration Contract fields > Off-screen and on-screen marker lead times struct: on-screen minimum.", "exports": ["on_screen_minimum_seconds"]},
	],
	"DirectionalWeightingEntry": [
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: encounter type (the key).", "exports": ["encounter_type"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: lane count.", "exports": ["lane_count"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: lane width.", "exports": ["lane_width_degrees"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: lane separation rule.", "exports": ["lane_separation_rule"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: heavy share.", "exports": ["heavy_share"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: ring.", "exports": ["ring"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: hunt arc.", "exports": ["hunt_arc_degrees"]},
		{"docs20": "Director Configuration Contract fields > Directional weighting rules per encounter type: hunt arc share.", "exports": ["hunt_arc_share"]},
	],
	"EncounterPriorityEntry": [
		{"docs20": "Director Configuration Contract fields > Encounter priority table entry: encounter type.", "exports": ["encounter_type"]},
		{"docs20": "Director Configuration Contract fields > Encounter priority table entry: priority.", "exports": ["priority"]},
	],
	"RecoveryGapEntry": [
		{"docs20": "Director Configuration Contract fields > Default recovery gap table entry: encounter type.", "exports": ["encounter_type"]},
		{"docs20": "Director Configuration Contract fields > Default recovery gap table entry: recovery gap.", "exports": ["recovery_gap_seconds"]},
	],
	"InterWaveGapDefaults": [
		{"docs20": "Director Configuration Contract fields > Inter-wave gap defaults struct: standard.", "exports": ["standard_seconds"]},
		{"docs20": "Director Configuration Contract fields > Inter-wave gap defaults struct: teaching-wave.", "exports": ["teaching_wave_seconds"]},
	],
	"PressureIntentWeightEntry": [
		{"docs20": "Director Configuration Contract fields > Pressure Metric intent weights entry: target intent.", "exports": ["target_intent"]},
		{"docs20": "Director Configuration Contract fields > Pressure Metric intent weights entry: weight.", "exports": ["weight"]},
	],
	"OffscreenUpdateThresholds": [
		{"docs20": "Director Configuration Contract fields > Off-screen update reduction thresholds struct: distance multiplier.", "exports": ["distance_multiplier"]},
		{"docs20": "Director Configuration Contract fields > Off-screen update reduction thresholds struct: tick divisor.", "exports": ["tick_divisor"]},
		{"docs20": "Director Configuration Contract fields > Off-screen update reduction thresholds struct: Tower exclusion radius.", "exports": ["tower_exclusion_radius_px"]},
	],
	"SiegeVolumeConstants": [
		{"docs20": "Director Configuration Contract fields > Siege volume formula constants struct: multiplier defaults.", "exports": ["multiplier_defaults"]},
		{"docs20": "Director Configuration Contract fields > Siege volume formula constants struct: Hunter percentage.", "exports": ["hunter_percentage"]},
		{"docs20": "Director Configuration Contract fields > Siege volume formula constants struct: spawn window.", "exports": ["spawn_window_fraction"]},
	],
	"XpLevelCost": [
		{"docs20": "Economy Configuration Contract fields > XP shard value and level cost formula struct: shard value.", "exports": ["shard_value"]},
		{"docs20": "Economy Configuration Contract fields > XP shard value and level cost formula struct: base cost.", "exports": ["base_cost"]},
		{"docs20": "Economy Configuration Contract fields > XP shard value and level cost formula struct: per-level increment.", "exports": ["per_level_increment"]},
	],
	"HopperConversionRule": [
		{"docs20": "Economy Configuration Contract fields > Hopper-to-Core conversion rate and trigger struct: rate.", "exports": ["rate_scrap_per_core"]},
		{"docs20": "Economy Configuration Contract fields > Hopper-to-Core conversion rate and trigger struct: trigger.", "exports": ["trigger"]},
	],
	"RunEndSettlementRates": [
		{"docs20": "Economy Configuration Contract fields > Run-End Settlement rates struct: per biome cleared.", "exports": ["per_biome_cleared_cores"]},
		{"docs20": "Economy Configuration Contract fields > Run-End Settlement rates struct: per boss killed.", "exports": ["per_boss_killed_cores"]},
		{"docs20": "Economy Configuration Contract fields > Run-End Settlement rates struct: per full minute.", "exports": ["per_full_minute_cores"]},
	],
	"ConsolePriceFormula": [
		{"docs20": "Economy Configuration Contract fields > Upgrade Console price formula struct: Scrap per rank.", "exports": ["scrap_per_rank"]},
		{"docs20": "Economy Configuration Contract fields > Upgrade Console price formula struct: formula (price = Scrap-per-rank x rank being bought; derived, not authored - see console_price_formula.gd).", "method": "compute_price"},
	],
	"DominanceAuditParameters": [
		{"docs20": "Economy Configuration Contract fields > Dominance audit threshold and sample size struct: threshold.", "exports": ["threshold_fraction"]},
		{"docs20": "Economy Configuration Contract fields > Dominance audit threshold and sample size struct: minimum runs.", "exports": ["minimum_runs"]},
	],
}

## Contract manifest: display name -> {script, sample}.
const CONTRACTS := [
	{"name": "Enemy Definition", "script": "res://src/data/enemy_definition.gd", "sample": "res://src/data/samples/enemy_definition_sample.tres"},
	{"name": "Encounter Definition", "script": "res://src/data/encounter_definition.gd", "sample": "res://src/data/samples/encounter_definition_sample.tres"},
	{"name": "Upgrade Definition", "script": "res://src/data/upgrade_definition.gd", "sample": "res://src/data/samples/upgrade_definition_sample.tres"},
	{"name": "Wave Definition", "script": "res://src/data/wave_definition.gd", "sample": "res://src/data/samples/wave_definition_sample.tres"},
	{"name": "Tower Definition", "script": "res://src/data/tower_definition.gd", "sample": "res://src/data/samples/tower_definition_sample.tres"},
	{"name": "Tower Upgrade Definition", "script": "res://src/data/tower_upgrade_definition.gd", "sample": "res://src/data/samples/tower_upgrade_definition_sample.tres"},
	{"name": "Weapon and Evolution Definition", "script": "res://src/data/weapon_definition.gd", "sample": "res://src/data/samples/weapon_definition_sample.tres"},
	{"name": "Pickup Definition", "script": "res://src/data/pickup_definition.gd", "sample": "res://src/data/samples/pickup_definition_sample.tres"},
	{"name": "Player Definition", "script": "res://src/data/player_definition.gd", "sample": "res://src/data/samples/player_definition_sample.tres"},
	{"name": "Director Configuration", "script": "res://src/data/director_configuration.gd", "sample": "res://src/data/samples/director_configuration_sample.tres"},
	{"name": "Economy Configuration", "script": "res://src/data/economy_configuration.gd", "sample": "res://src/data/samples/economy_configuration_sample.tres"},
]

const DATA_DIR := "res://src/data"

var _failures: Array[String] = []
var _contract_results: Array[String] = []

func _fail(msg: String) -> void:
	_failures.append(msg)

## Pass 1: load every .gd script directly under res://src/data (not
## recursing into samples/), confirming zero script errors and that each
## instantiates cleanly.
func _check_all_scripts_load() -> void:
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		_fail("cannot open %s" % DATA_DIR)
		return
	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".gd"):
			var path := DATA_DIR.path_join(fname)
			var script: Script = load(path)
			if script == null:
				_fail("script failed to load: %s" % path)
			else:
				var inst: Object = script.new()
				if inst == null:
					_fail("script failed to instantiate: %s" % path)
				else:
					count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	if _failures.is_empty():
		print("Pass 1 (script load): PASS (%d scripts under src/data/ loaded and instantiated with zero errors)" % count)

## Returns the exported property names an instance's script declares,
## INCLUDING inherited ones (TowerUpgradeDefinition extends
## UpgradeDefinition), by reading the live instance's own property list and
## filtering to script-level variables. Godot's Object.get_property_list()
## on a script instance walks the full script inheritance chain, unlike
## Script.get_script_property_list() which returns only that script's own
## declarations.
func _exported_properties(instance: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in instance.get_property_list():
		var usage: int = int(p.get("usage", 0))
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var pname: String = str(p.get("name", ""))
		if pname == "":
			continue
		result.append({"name": pname, "type": int(p.get("type", TYPE_NIL))})
	return result

## Pass 2 (P0.6 review iteration 2, R1 fix): checks the hand-written
## REQUIRED_FIELD_MANIFEST entry for one contract against the actual
## exported properties (and methods, for the one derived field) a fresh
## instance of its schema script declares. Independent of
## _exported_properties() driving anything about the manifest itself - the
## manifest is read-only data here.
func _check_required_field_manifest(contract_name: String, instance: Object) -> void:
	if not REQUIRED_FIELD_MANIFEST.has(contract_name):
		_fail("%s: no entry in REQUIRED_FIELD_MANIFEST - the manifest itself is incomplete for this contract" % contract_name)
		return
	var declared: Dictionary = {}
	for prop in _exported_properties(instance):
		declared[prop["name"]] = true
	var manifest: Array = REQUIRED_FIELD_MANIFEST[contract_name]
	for field in manifest:
		var master_text: String = field["master"]
		if field.has("method"):
			var method_name: String = field["method"]
			if not instance.has_method(method_name):
				_fail("%s: MASTER field \"%s\" (derived) has no method %s() on the schema" % [contract_name, master_text, method_name])
		else:
			for export_name in field["exports"]:
				if not declared.has(export_name):
					_fail("%s: MASTER field \"%s\" has no matching @export \"%s\" on the schema (REQUIRED_FIELD_MANIFEST)" % [contract_name, master_text, export_name])

## Struct-level counterpart of _check_required_field_manifest() above, driven
## by STRUCT_REQUIRED_FIELD_MANIFEST instead of REQUIRED_FIELD_MANIFEST (P0.6
## review iteration 2 follow-up). Called from _validate_resource() for every
## Resource instance the recursive walk visits, keyed by that instance's own
## class name; a no-op whenever class_name_str has no entry (most visited
## classes - including every contract root - are not mapped structs, see
## STRUCT_REQUIRED_FIELD_MANIFEST's header for which classes are and are not
## keys and why). Appends into the caller's failures array (the same
## per-contract local_failures list _validate_resource already threads
## through) rather than calling _fail() directly, so a struct-manifest
## failure is counted against the same contract _check_contract() is
## currently validating.
func _check_struct_required_fields(class_name_str: String, instance: Object, path_prefix: String, failures: Array[String]) -> void:
	if not STRUCT_REQUIRED_FIELD_MANIFEST.has(class_name_str):
		return
	var declared: Dictionary = {}
	for prop in _exported_properties(instance):
		declared[prop["name"]] = true
	var manifest: Array = STRUCT_REQUIRED_FIELD_MANIFEST[class_name_str]
	for field in manifest:
		var docs20_text: String = field["docs20"]
		if field.has("method"):
			var method_name: String = field["method"]
			if not instance.has_method(method_name):
				failures.append("%s (%s): required field \"%s\" (derived) has no method %s() on the struct" % [path_prefix, class_name_str, docs20_text, method_name])
		else:
			for export_name in field["exports"]:
				if not declared.has(export_name):
					failures.append("%s (%s): required field \"%s\" has no matching @export \"%s\" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)" % [path_prefix, class_name_str, docs20_text, export_name])

## Recursively validates one Resource instance against a freshly constructed
## default of the same class. path_prefix is the dotted path from the
## contract root, used only for readable failure messages. visited guards
## against re-entering the same object twice (not expected in these
## samples, but cheap to guard).
func _validate_resource(sample_obj: Resource, path_prefix: String, failures: Array[String], visited: Array, depth: int) -> void:
	if sample_obj == null:
		return
	if visited.has(sample_obj):
		return
	visited.append(sample_obj)
	if depth > 6:
		failures.append("%s: recursion depth exceeded (possible cycle)" % path_prefix)
		return

	var script: Script = sample_obj.get_script()
	if script == null:
		failures.append("%s: sample object has no attached script (wrong resource type?)" % path_prefix)
		return
	var fresh: Object = script.new()
	var class_name_str: String = str(script.get_global_name())
	if class_name_str == "":
		failures.append("%s: script has no class_name (cannot key exception/domain tables)" % path_prefix)

	# Struct-level required-field manifest (P0.6 review iteration 2 follow-up,
	# R1 extended one level down) - independent of the per-property walk
	# below, the same relationship REQUIRED_FIELD_MANIFEST has to it at the
	# contract level. A no-op when class_name_str has no entry in
	# STRUCT_REQUIRED_FIELD_MANIFEST.
	_check_struct_required_fields(class_name_str, sample_obj, path_prefix, failures)

	for prop in _exported_properties(sample_obj):
		var pname: String = prop["name"]
		var declared_type: int = prop["type"]
		var key := "%s.%s" % [class_name_str, pname]

		if key in SKIP_ALWAYS:
			continue
		if _is_nullable_pair_flag(class_name_str, pname):
			continue # handled alongside its paired value field below

		var full_path := "%s.%s" % [path_prefix, pname]
		var sample_val = sample_obj.get(pname)

		# Nullable-primitive pair (e.g. max_rank / has_max_rank).
		if NULLABLE_PRIMITIVE_PAIRS.has(key):
			var pair: Dictionary = NULLABLE_PRIMITIVE_PAIRS[key]
			var flag_name: String = pair["flag"]
			var mode: String = pair["mode"]
			var flag_val = sample_obj.get(flag_name)
			if mode == "require_set":
				if flag_val != true:
					failures.append("%s: expected %s to be true (this project's samples must demonstrate the set state), got %s" % [full_path, flag_name, str(flag_val)])
				else:
					var fresh_val_rs = fresh.get(pname)
					if sample_val == fresh_val_rs:
						failures.append("%s is at its default value (%s) while %s is true" % [full_path, str(sample_val), flag_name])
			else: # "optional" - a populated value is never a failure (R9); only a claimed-set-but-still-default value is
				if flag_val == true:
					var fresh_val_opt = fresh.get(pname)
					if sample_val == fresh_val_opt:
						failures.append("%s is at its default value (%s) while %s is true" % [full_path, str(sample_val), flag_name])
				# flag_val == false: nothing to check - null is a legitimate, undemonstrated-by-this-sample state
			continue

		# Branch on the property's DECLARED type (from get_property_list()),
		# not typeof(sample_val) - typeof(null) is TYPE_NIL regardless of the
		# property's static Resource type, which would otherwise misroute
		# every unset nullable-Resource field into the generic scalar branch
		# below and flag it as "at default" instead of "legitimately null".
		if declared_type == TYPE_OBJECT:
			if sample_val == null:
				if not (key in NULLABLE_RESOURCE_OK):
					failures.append("%s is null (required)" % full_path)
				# else: null is a legitimate, documented value here.
			else:
				_validate_resource(sample_val, full_path, failures, visited, depth + 1)
		elif declared_type == TYPE_ARRAY:
			var arr: Array = sample_val
			if arr.is_empty():
				failures.append("%s is an empty array (required non-empty in this sample)" % full_path)
			else:
				# Recurse into EVERY element (P0.6 review iteration 2, R4) -
				# not only element [0]. A blanked element past the first used
				# to leave the check green (e.g. a wave's second intent-mix
				# entry left at its default proportion).
				for i in range(arr.size()):
					var element = arr[i]
					if typeof(element) == TYPE_OBJECT and element != null:
						_validate_resource(element, "%s[%d]" % [full_path, i], failures, visited, depth + 1)
		else:
			var fresh_val = fresh.get(pname)
			if sample_val == fresh_val:
				failures.append("%s is at its default value: %s" % [full_path, str(sample_val)])
			# Value-domain assertions (P0.6 review iteration 2, R11) - only
			# for the bounds docs/20 actually states; independent of whether
			# the default check above also flagged this field.
			if DOMAIN_CONSTRAINTS.has(key):
				var bounds: Dictionary = DOMAIN_CONSTRAINTS[key]
				if bounds.has("min") and sample_val < bounds["min"]:
					failures.append("%s is %s, outside docs/20's stated domain (minimum %s)" % [full_path, str(sample_val), str(bounds["min"])])
				if bounds.has("max") and sample_val > bounds["max"]:
					failures.append("%s is %s, outside docs/20's stated domain (maximum %s)" % [full_path, str(sample_val), str(bounds["max"])])

## True if pname is the has_<field> flag half of some NULLABLE_PRIMITIVE_PAIRS
## entry belonging to class_name_str - derived from NULLABLE_PRIMITIVE_PAIRS
## itself rather than kept as a second, separately-maintained list, so a new
## pair (e.g. has_recursive_interaction_guard, added this session) can never
## be forgotten from it.
func _is_nullable_pair_flag(class_name_str: String, pname: String) -> bool:
	var prefix := class_name_str + "."
	for key in NULLABLE_PRIMITIVE_PAIRS.keys():
		if key.begins_with(prefix) and NULLABLE_PRIMITIVE_PAIRS[key]["flag"] == pname:
			return true
	return false

func _check_contract(entry: Dictionary) -> void:
	var name: String = entry["name"]
	var script_path: String = entry["script"]
	var sample_path: String = entry["sample"]

	if not FileAccess.file_exists(sample_path):
		_fail("%s: sample resource missing on disk: %s" % [name, sample_path])
		_contract_results.append("%s: FAIL (sample missing)" % name)
		return

	var script: Script = load(script_path)
	if script == null:
		_fail("%s: schema script failed to load: %s" % [name, script_path])
		_contract_results.append("%s: FAIL (schema script did not load)" % name)
		return

	var sample: Resource = load(sample_path)
	if sample == null:
		_fail("%s: sample resource failed to load: %s" % [name, sample_path])
		_contract_results.append("%s: FAIL (sample did not load)" % name)
		return

	if not is_instance_of(sample, script):
		_fail("%s: sample at %s is not an instance of %s (wrong resource class)" % [name, sample_path, script_path])
		_contract_results.append("%s: FAIL (wrong resource class)" % name)
		return

	var before := _failures.size()

	# Pass 2: required-field manifest, independent of the script (R1).
	_check_required_field_manifest(name, sample)

	# Pass 3: value walk against a fresh default instance, recursing into
	# every nested Resource and every array element (R4), with domain
	# assertions (R11).
	var local_failures: Array[String] = []
	_validate_resource(sample, name, local_failures, [], 0)
	for f in local_failures:
		_fail(f)

	# Contract-specific rules the field-level walk above cannot express
	# generically (docs/20 states these as sample-content or whole-array
	# rules, not type-level constraints Godot can express on a single field -
	# see tower_definition.gd and weapon_definition.gd comments).
	if name == "Tower Definition":
		var thresholds: Array = sample.evolution_stage_thresholds
		if thresholds.size() != 4:
			_fail("%s.evolution_stage_thresholds has %d entries, expected exactly 4 (Base, Reinforced, Armed, Fortress)" % [name, thresholds.size()])
	if name == "Weapon and Evolution Definition":
		var axes: Array = sample.evolution_changes_axes
		if axes.size() < 1:
			_fail("%s.evolution_changes_axes has %d entries, expected at least 1" % [name, axes.size()])
	if name == "Tower Upgrade Definition":
		if sample.pool_ownership != ContractEnums.PoolOwnership.Tower:
			_fail("%s.pool_ownership is %s, MASTER requires Tower Upgrade definitions to set Pool ownership to Tower" % [name, str(sample.pool_ownership)])
	if name == "Wave Definition":
		# docs/20 Wave Definition Contract fields: Enemy intent mix's
		# proportion is "float 0-1 summing to 1" - the per-element 0-1 bound
		# is DOMAIN_CONSTRAINTS' EnemyIntentMixEntry.proportion entry above;
		# the summing-to-1 half is a whole-array rule, asserted here.
		var mix: Array = sample.enemy_intent_mix
		var total := 0.0
		for mix_entry in mix:
			total += mix_entry.proportion
		if absf(total - 1.0) > 0.0001:
			_fail("%s.enemy_intent_mix proportions sum to %s, expected 1.0 (docs/20: \"proportion: float 0-1 summing to 1\")" % [name, str(total)])

	if _failures.size() == before:
		_contract_results.append("%s: PASS" % name)
	else:
		_contract_results.append("%s: FAIL (%d problem(s))" % [name, _failures.size() - before])

func _init() -> void:
	_check_all_scripts_load()
	for entry in CONTRACTS:
		_check_contract(entry)

	print("")
	print("Per-contract results:")
	for r in _contract_results:
		print("  %s" % r)
	print("")

	if _failures.is_empty():
		print("Schema check: PASS (%d contracts validated, 0 problems)" % CONTRACTS.size())
		quit(0)
	else:
		for f in _failures:
			printerr("Schema check FAILURE: %s" % f)
		printerr("Schema check: FAIL (%d problem(s) across %d contract(s))" % [_failures.size(), CONTRACTS.size()])
		quit(1)

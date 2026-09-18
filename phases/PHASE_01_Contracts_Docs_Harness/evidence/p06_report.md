# P0.6 Report — Data Contract Schemas

Task: MASTER_SDLC.md > Development Phase Map > Phase 0, task P0.6, executed per `phases/PHASE_01_Contracts_Docs_Harness/PLAN.md` § "P0.6 - Data contract schemas". This report does not claim the task is passed, satisfied, or ready — that is for reviewers and the author to decide (CLAUDE.md; phases/README.md loop rule).

Scope: the eleven prototype-scope contracts named in the P0.6 assignment — Enemy, Encounter, Wave, Upgrade, Tower, Tower Upgrade, Weapon (and Evolution), Pickup, Player, Director Configuration, Economy Configuration. Biome, Boss, Elite Affix, and Status Effect are out of scope (MASTER P0.6 row, "Scope out") and were not typed, except that the shared `Effect` struct was still typed for forward compatibility per convention 2 below (see "Contradictions and ambiguities").

## Files delivered

**Enums** (1 file): `src/data/contract_enums.gd` (`class_name ContractEnums`) — every enum used by any in-scope contract, shared or contract-specific, centralised in one file (see Conventions §3 below for why).

**Shared / reusable struct resources** (12 files, docs/20's "Shared fields and struct types" table): `readability_profile.gd`, `telegraph_data.gd`, `spawn_group.gd`, `movement_profile.gd`, `attack_profile.gd`, `effect_data.gd`, `finisher_spawn_rate.gd`, `overtime_condition.gd`, `pressure_metric_constants.gd`, `drop_table.gd`, `reward.gd`, `banded_value.gd`.

**"List of pairs" resources** (7 files, convention 6): `intent_budget_override.gd`, `enemy_intent_mix_entry.gd`, `encounter_priority_entry.gd`, `recovery_gap_entry.gd`, `pressure_intent_weight_entry.gd`, `persistent_asset_rule.gd`, `directional_weighting_entry.gd`.

**Contract-specific struct resources** (23 files): Tower — `max_health_and_shield_fraction.gd`, `shield_regeneration.gd`, `tower_footprint.gd`, `targeting_rule_parameters.gd`, `repair_price.gd`. Weapon — `projectile_definition.gd`, `weapon_evolution_requirement.gd`, `engagement_rhythm.gd`. Pickup — `merge_rule.gd`, `visual_audio_cue.gd`. Player — `input_buffer_duration.gd`. Director — `ring_definition.gd`, `spawn_ring_geometry.gd`, `spawn_validation_retry.gd`, `marker_lead_times.gd`, `inter_wave_gap_defaults.gd`, `offscreen_update_thresholds.gd`, `siege_volume_constants.gd`. Economy — `xp_level_cost.gd`, `hopper_conversion_rule.gd`, `run_end_settlement_rates.gd`, `console_price_formula.gd`, `dominance_audit_parameters.gd`.

**Contract resources** (11 files): `enemy_definition.gd`, `encounter_definition.gd`, `upgrade_definition.gd`, `wave_definition.gd`, `tower_definition.gd`, `tower_upgrade_definition.gd` (extends `upgrade_definition.gd`), `weapon_definition.gd`, `pickup_definition.gd`, `player_definition.gd`, `director_configuration.gd`, `economy_configuration.gd`.

Total: 54 `.gd` scripts under `src/data/` (1 enum file + 42 struct files + 11 contract files), each with a matching `.uid` sidecar Godot generates automatically.

**Samples**: `src/data/samples/*_sample.tres`, one per contract (11 files), each built and saved through Godot's own `ResourceSaver` (see "How the samples were produced" below) so the `.tres` text-resource syntax is exactly what 4.7.1 itself emits, not hand-typed.

**Test**: `tests/schema_check.gd`.

**This report**: `phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_report.md`.

No file outside `src/data/`, `tests/schema_check.gd`, and this report was written or edited.

## How the samples were produced

Rather than hand-writing eleven `.tres` files (a format with nested `[sub_resource]` blocks and typed-array syntax `Array[ExtResource("id")]([...])` that is easy to get subtly wrong by hand), a scratch generator script (`build_samples.gd`, run once via `--script` from the session scratchpad, not a project deliverable) constructed each of the eleven sample `Resource` objects programmatically with the placeholder values below and called `ResourceSaver.save()` on each. This guarantees syntactically correct `.tres` output because Godot's own serializer produced it, and was verified empirically (see "Schema check" below) rather than assumed.

---

## Conventions actually applied

1. **One file per resource**, `snake_case.gd` under `src/data/`, `extends Resource` + `class_name` in PascalCase. Followed for all 54 files.
2. **Shared structs typed exactly once**, reused by every contract that needs them. Followed. `EffectData` (the shared `Effect` struct) is typed but not referenced by any of the eleven in-scope samples — no in-scope contract's required-field list uses it directly (it is consumed by the out-of-scope Status Effect contract's "Tick effect" field); it is still typed per the plan's convention 2 instruction to represent every struct in docs/20's shared table.
3. **Enums**: every enum's member list matches Contract Field Semantics exactly — same members, same order, no extra `NONE`/`UNSET` member. **Deviation from the letter of the plan, stated and reasoned**: the plan allows contract-specific enums to live on their own contract resource; this implementation centralises **all** 28 enums (shared and contract-specific alike) in `contract_enums.gd`/`ContractEnums`, including single-contract ones like `PathingFallbackBehavior` or `HurtboxDefinition`. Reasoning: one discoverable source of truth, and it sidesteps any question of whether a same-named-but-different-membership enum (e.g. Upgrade's "Effect target" `{Player, Tower, PlayerWeapon, TowerWeapon}` vs. the shared Effect struct's "target" `{Player, Tower, Enemy}`) was accidentally reused — they are named `UpgradeEffectTarget` and `EffectStructTarget` respectively, both in `ContractEnums`, so the distinction is explicit at the call site.
4. **Nullable fields**: for a nullable field whose type is a Resource, the export is left naturally null when unset (`EncounterDefinition.directional_weighting_override`, `EncounterDefinition.partial_reward_rules`, `SpawnGroup.direction_weighting_override`). For a nullable primitive/enum, a paired `has_<field>: bool = false` export carries the "is set" state (`UpgradeDefinition.max_rank`/`has_max_rank`, `WaveDefinition.maximum_duration_seconds`/`has_maximum_duration`, `BandedValue.band_label`/`has_band_label`). **One extension beyond the plan's letter**: for `UpgradeDefinition.recursive_interaction_guard`, typed `"enum/string, nullable"` in docs/20 with no enum members given anywhere, this was resolved as a plain `String` where an empty string means null, with no paired boolean — reasoning: an empty string is already an unambiguous "unset" marker for a free-text field (unlike `0` for an integer), so the has_-boolean mechanism, built for values with no unambiguous "empty" state, was judged unnecessary here. Flagged in "Contradictions and ambiguities" below since this is an interpretation, not something docs/20 states.
5. **Band fields**: `BandedValue` (`value: int`, `band_label: ContractEnums.BandLabel`, `has_band_label: bool = false`) used for `EnemyDefinition.health_band`, `EnemyDefinition.damage_band`, `WeaponDefinition.damage_band`. `WaveDefinition.difficulty_band` uses the separate non-nullable `ContractEnums.DifficultyBand` directly, per the plan's explicit instruction that these are different fields.
6. **"List of pairs" fields**: every such field is a typed `Array[SomeSmallResource]`, never a bare `Array` or `Dictionary`. Applied to `Intent budget overrides`, `Enemy intent mix`, `Encounter priority table`, `Default recovery gap table`, `Pressure Metric intent weights`, `Persistent asset rules`, and `Directional weighting rules per encounter type` (this last one is docs/20's "struct, keyed by encounter type" — each `DirectionalWeightingEntry` carries its own `encounter_type` field, so `Array[DirectionalWeightingEntry]` represents the same "keyed by" relationship without a `Dictionary`).
7. **Typed arrays everywhere**: every `Array` export in every one of the 54 scripts declares its element type (`Array[String]`, `Array[int]`, `Array[float]`, `Array[SpawnGroup]`, `Array[ContractEnums.EvolutionChangeAxis]`, etc.). No bare `Array` export exists anywhere in `src/data/`.
8. **Derived fields**: `WaveDefinition`'s "Spawn budget" is **not** an `@export`. It is exposed as a method, `get_spawn_budget(encounter_lookup: Dictionary, enemy_lookup: Dictionary) -> int`, not a computed property — GDScript properties cannot take parameters, and computing "sum of the wave's spawn groups' cap weights" needs two cross-resource lookups (Encounter Unique ID → `EncounterDefinition`, Enemy Unique ID → `EnemyDefinition`) that a standalone `WaveDefinition` resource cannot own; a Wave's own field list carries only an `encounter_sequence: Array[String]` of IDs, and Cap weight lives on the Enemy Definition a spawn group references by ID. The method takes both lookups as parameters rather than resolving them itself. See "Contradictions and ambiguities" for why this could not be fully self-contained.
9. **Tower Upgrade**: `TowerUpgradeDefinition extends UpgradeDefinition` and adds only `evolution_stage_contribution: int` and `draft_weight: int`. `schema_check.gd` additionally asserts the sample's inherited `pool_ownership` equals `ContractEnums.PoolOwnership.Tower`, since MASTER requires this as a fixed rule ("with Pool ownership set to Tower") that a generic "differs from default" check cannot express (`Tower` is not the enum's zero-index/default member, so the generic check would already reject a `Player`-default sample, but would not catch every other wrong-but-non-default value like `Weapon` or `Utility`).

**One convention not in the plan's list, adopted for the schema check specifically**: rather than hand-listing every field's default value, `schema_check.gd` constructs a fresh `ClassName.new()` for comparison and flags any exported property whose sample value equals the fresh instance's value (Variant equality), except for a small, explicit exceptions manifest (the nullable-Resource fields, the three nullable-primitive pairs, and `PlayerDefinition.hurtbox_definition` — a single-member enum `{SameAsBody}` where the schema default and the only valid value are the same integer, so no non-default value exists to demonstrate "set" vs "never touched"; this field is exempted from the check with that reasoning recorded in `schema_check.gd`'s own comments).

---

## Per-contract field-to-type mapping

Enum values below are written as `ContractEnums.<Enum>` (all placed in `contract_enums.gd` per convention 3's deviation above). "Nullable (Resource)" means a nullable Resource-typed export per convention 4; "Nullable (has_ pair)" means the paired-boolean convention.

### Enemy Definition Contract (`src/data/enemy_definition.gd` → `EnemyDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Target intent | enum | `target_intent: ContractEnums.TargetIntent` |
| Movement profile | struct {speed multiplier: float, body radius: int} | `movement_profile: MovementProfile` |
| Attack profile | struct {attack type: enum, damage per hit/tick: int, cycle/tick interval: float, reach/range: int} | `attack_profile: AttackProfile` |
| Telegraph data | struct {wind-up duration: float, shape: enum, colour: colour ref, audio cue ID: string} | `telegraph_data: TelegraphData` |
| Health band | integer value + nullable Band label (author decision, convention 5) | `health_band: BandedValue` (`.value: int`, `.band_label`, `.has_band_label`) |
| Damage band | integer value + nullable Band label (convention 5) | `damage_band: BandedValue` |
| Contact behavior | enum {None, Damage, Explode, Block} | `contact_behaviour: ContractEnums.ContactBehaviour` |
| Pathing fallback behavior | enum {Standard, Custom} | `pathing_fallback_behavior: ContractEnums.PathingFallbackBehavior` |
| Entity cap weight | integer ≥ 1 | `entity_cap_weight: int` |
| Elite eligibility | boolean | `elite_eligibility: bool` |
| Allowed affixes | list of Elite Affix Unique IDs | `allowed_affixes: Array[String]` |
| Biome tags | list of Biome Unique IDs | `biome_tags: Array[String]` |
| Readability profile | struct {silhouette class: enum, reserved colour: colour ref, min on-screen size: int} | `readability_profile: ReadabilityProfile` |
| Drop table | struct {XP shards: int, Scrap: int, Cores: int} | `drop_table: DropTable` |

### Encounter Definition Contract (`src/data/encounter_definition.gd` → `EncounterDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Encounter type | enum (16 members) | `encounter_type: ContractEnums.EncounterType` |
| Design intent | string | `design_intent: String` |
| Pressure target | float | `pressure_target: float` |
| Player answer | string | `player_answer: String` |
| Failure signature | string | `failure_signature: String` |
| Spawn groups | ordered list of Spawn group structs | `spawn_groups: Array[SpawnGroup]` |
| Intent budget overrides | list of {target intent: enum, count: int} | `intent_budget_overrides: Array[IntentBudgetOverride]` |
| Directional weighting override | nullable struct, shaped like Director's per-encounter-type entry | `directional_weighting_override: DirectionalWeightingEntry` — Nullable (Resource) |
| Telegraph requirements | list of Telegraph data references | `telegraph_requirements: Array[TelegraphData]` |
| Minimum recovery gap | float seconds | `minimum_recovery_gap_seconds: float` |
| Priority | integer 0–100 | `priority: int` |
| Entity cap behavior | enum {Throttle, Defer, Skip} | `entity_cap_behavior: ContractEnums.EntityCapBehaviour` |
| Encounter alive cap | integer | `encounter_alive_cap: int` |
| Allowed encounter tags | string list | `allowed_encounter_tags: Array[String]` |
| Excluded encounter tags | string list | `excluded_encounter_tags: Array[String]` |
| Reward | struct {XP: int, Scrap: int, Cores: int}; zero for the four prototype encounters | `reward: Reward` — sample uses a non-zero placeholder (see "Contradictions") |
| Failure resolution | enum {RewardForfeited, CompletesWithPartialReward} | `failure_resolution: ContractEnums.FailureResolution` |
| Partial reward rules | nullable Reward struct | `partial_reward_rules: Reward` — Nullable (Resource) |
| Pause and deferral behavior | enum {DeferUntilDraftCloses, Cancel} | `pause_and_deferral_behavior: ContractEnums.PauseAndDeferralBehaviour` |

### Upgrade Definition Contract (`src/data/upgrade_definition.gd` → `UpgradeDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Pool ownership | enum {Player, Tower, Weapon, Utility} | `pool_ownership: ContractEnums.PoolOwnership` |
| Rarity | enum {Common, Rare, Epic} | `rarity: ContractEnums.Rarity` |
| Maximum rank | nullable integer | `max_rank: int` — Nullable (has_ pair) via `has_max_rank: bool` |
| Prerequisites | list of Upgrade Unique IDs | `prerequisites: Array[String]` |
| Exclusions | list of Upgrade Unique IDs | `exclusions: Array[String]` |
| Effect description | string | `effect_description: String` |
| Effect target | enum {Player, Tower, PlayerWeapon, TowerWeapon} | `effect_target: ContractEnums.UpgradeEffectTarget` |
| Effect per rank | float | `effect_per_rank: float` |
| Console price per rank | integer Scrap | `console_price_per_rank: int` |
| Recursive interaction guard | enum/string, nullable | `recursive_interaction_guard: String` — empty string means null (see convention 4 deviation) |
| Visual readability impact | enum {None, Low, High} | `visual_readability_impact: ContractEnums.VisualReadabilityImpact` |
| Performance cost category | enum {Light, Medium, Heavy} | `performance_cost_category: ContractEnums.PerformanceCostCategory` |

### Wave Definition Contract (`src/data/wave_definition.gd` → `WaveDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Biome context | Biome Unique ID | `biome_context_id: String` |
| Difficulty band | enum {Low, Mid, High}, non-nullable | `difficulty_band: ContractEnums.DifficultyBand` |
| Encounter sequence | ordered list of Encounter Unique IDs | `encounter_sequence: Array[String]` |
| Spawn budget | derived: not authored | **not exported** — `get_spawn_budget(encounter_lookup, enemy_lookup) -> int` method (convention 8) |
| Enemy intent mix | list of {target intent: enum, proportion: float} | `enemy_intent_mix: Array[EnemyIntentMixEntry]` |
| Elite chance | float 0–1 | `elite_chance: float` |
| Maximum duration | nullable float seconds | `maximum_duration_seconds: float` — Nullable (has_ pair) via `has_maximum_duration: bool` |
| Target duration | float seconds | `target_duration_seconds: float` |
| Inter-wave gap | float seconds | `inter_wave_gap_seconds: float` |
| Overtime condition | struct {stall threshold, finisher enemy ref, finisher spawn rate, finisher drop override} | `overtime_condition: OvertimeCondition` |
| Pressure Metric constants | struct (7 float fields) | `pressure_metric_constants: PressureMetricConstants` |
| Boss overlap rules | enum {NotApplicable, SuppressesRegularSpawns} | `boss_overlap_rules: ContractEnums.BossOverlapRules` |

### Tower Definition Contract (`src/data/tower_definition.gd` → `TowerDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Maximum health and base shield fraction | struct {max health: int, base shield fraction: float} | `max_health_and_shield_fraction: MaxHealthAndShieldFraction` |
| Shield regeneration rate and delay | struct {rate: float %/s, delay: float s} | `shield_regeneration: ShieldRegeneration` |
| Footprint radius and Interaction Radius | struct {footprint radius: int px, Interaction Radius: int px} | `tower_footprint: TowerFootprint` |
| Base weapon reference | Weapon Definition Unique ID | `base_weapon_reference_id: String` |
| Targeting rule parameters | struct {range: int px, intent preference: enum} | `targeting_rule_parameters: TargetingRuleParameters` |
| Evolution stage thresholds | list of 4 integers | `evolution_stage_thresholds: Array[int]` — length-4 asserted by `schema_check.gd`, not by the type |
| Repair price | struct {Scrap cost: int, health restored: int, pro-ration rule} | `repair_price: RepairPrice` |
| Persistent asset rules | list of {asset class: string, persists across biomes: bool} | `persistent_asset_rules: Array[PersistentAssetRule]` |

### Tower Upgrade Definition Contract (`src/data/tower_upgrade_definition.gd` → `TowerUpgradeDefinition extends UpgradeDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| *(every Upgrade Definition Contract field, Pool ownership forced to Tower)* | — | inherited from `UpgradeDefinition`; `pool_ownership == Tower` asserted on the sample by `schema_check.gd` |
| Evolution stage contribution | integer | `evolution_stage_contribution: int` |
| Draft weight | integer ≥ 0 | `draft_weight: int` |

### Weapon and Evolution Definition Contract (`src/data/weapon_definition.gd` → `WeaponDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Effective range | integer px | `effective_range_px: int` |
| Coverage shape | enum {Cone, Line, Radius, SingleTarget} | `coverage_shape: ContractEnums.CoverageShape` |
| Target count | integer | `target_count: int` |
| Engagement rhythm and fire rate | struct {rhythm: enum, fire rate: float shots/s} | `engagement_rhythm: EngagementRhythm` |
| Damage band (Damage per shot) | integer value + nullable Band label (convention 5) | `damage_band: BandedValue` |
| Projectile definition | struct {speed: int px/s, lifetime: float s, pooling class: string} | `projectile_definition: ProjectileDefinition` |
| Evolution prerequisites and target | struct {prerequisites: list of Upgrade IDs, evolution target: Weapon ID} | `evolution_requirement: WeaponEvolutionRequirement` |
| Which stat(s) the evolution changes | list of enum {Range, Coverage, TargetCount, Rhythm}, length ≥ 1 | `evolution_changes_axes: Array[ContractEnums.EvolutionChangeAxis]` — length ≥ 1 asserted by `schema_check.gd` |

### Pickup Definition Contract (`src/data/pickup_definition.gd` → `PickupDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID and type | struct {Unique ID: string, type: enum {XP, Scrap, Core, Health}} | flattened (see Conventions/report note): `unique_id: String`, `pickup_type: ContractEnums.PickupType` |
| Value | integer | `value: int` |
| Magnet behaviour | enum {Attracted, Static} | `magnet_behaviour: ContractEnums.MagnetBehaviour` |
| Merge rule | struct (see `merge_rule.gd` comment on the two fixed sub-fields) | `merge_rule: MergeRule` (`.match_radius_px: int`, `.same_type_only: bool`) |
| Lifetime in simulation seconds | float | `lifetime_seconds: float` |
| Visual and audio cue | struct {sprite reference: string, audio cue ID: string} | `visual_audio_cue: VisualAudioCue` |

No Entity cap weight field, matching docs/20's explicit note that the pickup cap is a flat count.

### Player Definition Contract (`src/data/player_definition.gd` → `PlayerDefinition`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Maximum health | integer | `max_health: int` |
| Base speed | float px/s | `base_speed_px_per_second: float` |
| Acceleration time to base speed | float seconds | `acceleration_time_seconds: float` |
| Deceleration time to stop | float seconds | `deceleration_time_seconds: float` |
| Body radius | integer px | `body_radius_px: int` |
| Hurtbox definition | enum {SameAsBody} | `hurtbox_definition: ContractEnums.HurtboxDefinition` — exempted from the "non-default" check (see Conventions) |
| Collector area radius | integer px | `collector_area_radius_px: int` |
| Magnet radius | integer px | `magnet_radius_px: int` |
| Input buffer duration | struct {duration: float ms, ticks: int} | `input_buffer: InputBufferDuration` |
| Starting weapon reference | Weapon Definition Unique ID | `starting_weapon_reference_id: String` |

### Director Configuration Contract (`src/data/director_configuration.gd` → `DirectorConfiguration`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Spawn ring geometry | struct {Tower ring, view ring: each {inner radius, width}} | `spawn_ring_geometry: SpawnRingGeometry` (`.tower_ring`/`.view_ring: RingDefinition`) |
| Camera exclusion margin | integer px | `camera_exclusion_margin_px: int` |
| Spawn validation retry steps and angle increment | struct {steps: int, angle: float} | `spawn_validation_retry: SpawnValidationRetry` |
| Off-screen and on-screen marker lead times | struct {off-screen: float, on-screen min: float} | `marker_lead_times: MarkerLeadTimes` |
| Directional weighting rules per encounter type | struct, keyed by encounter type | `directional_weighting_rules: Array[DirectionalWeightingEntry]` |
| Encounter priority table | list of {encounter type, priority} | `encounter_priority_table: Array[EncounterPriorityEntry]` |
| Default recovery gap table | list of {encounter type, recovery gap} | `default_recovery_gap_table: Array[RecoveryGapEntry]` |
| Inter-wave gap defaults | struct {standard: float, teaching-wave: float} | `inter_wave_gap_defaults: InterWaveGapDefaults` |
| Post-draft grace period | float seconds | `post_draft_grace_period_seconds: float` |
| Pressure Metric intent weights | list of {target intent, weight} | `pressure_metric_intent_weights: Array[PressureIntentWeightEntry]` |
| Pressure Metric escalation/de-escalation timers | Pressure Metric constants struct | `pressure_metric_timers: PressureMetricConstants` (reuses the shared struct) |
| Off-screen update reduction thresholds | struct {distance multiplier, tick divisor, Tower exclusion radius} | `offscreen_update_thresholds: OffscreenUpdateThresholds` |
| Siege volume formula constants | struct {multiplier defaults: list of float, Hunter %, spawn window} | `siege_volume_constants: SiegeVolumeConstants` |
| Health quadrant threshold | float fraction | `health_quadrant_threshold: float` |

### Economy Configuration Contract (`src/data/economy_configuration.gd` → `EconomyConfiguration`)

| MASTER required field | docs/20 type | `@export` written |
| --- | --- | --- |
| Unique ID | string | `unique_id: String` |
| Merge radius | integer px | `merge_radius_px: int` |
| XP shard value and level cost formula | struct {shard value: int, cost formula: L → 10 + 5(L+1)} | `xp_level_cost: XpLevelCost` (`.shard_value: int`, `.base_cost: int`, `.per_level_increment: int` — see "Contradictions") |
| XP cap during teaching waves | integer | `xp_cap_during_teaching_waves: int` |
| Scrap cap | integer | `scrap_cap: int` |
| Overflow hopper capacity | integer | `overflow_hopper_capacity: int` |
| Hopper-to-Core conversion rate and trigger | struct {rate: int:1, trigger: fixed} | `hopper_conversion_rule: HopperConversionRule` (`.rate_scrap_per_core: int`, `.trigger: String`) |
| Core persistence write cadence | float seconds | `core_persistence_write_cadence_seconds: float` |
| Run-End Settlement rates | struct {per biome, per boss, per minute: int} | `run_end_settlement_rates: RunEndSettlementRates` |
| Upgrade Console price formula | struct {Scrap per rank: int, formula: price = Scrap-per-rank × rank} | `console_price_formula: ConsolePriceFormula` (`.scrap_per_rank: int`; formula is a pure function of this field and the rank parameter, no extra field needed) |
| Dominance audit threshold and sample size | struct {threshold: float, minimum runs: int} | `dominance_audit_parameters: DominanceAuditParameters` |

---

## Schema check

Command (exactly as specified, `--import` run once first):

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
```

Exit code: **0**

Verbatim output:

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Pass 1 (script load): PASS (54 scripts under src/data/ loaded and instantiated with zero errors)

Per-contract results:
  Enemy Definition: PASS
  Encounter Definition: PASS
  Upgrade Definition: PASS
  Wave Definition: PASS
  Tower Definition: PASS
  Tower Upgrade Definition: PASS
  Weapon and Evolution Definition: PASS
  Pickup Definition: PASS
  Player Definition: PASS
  Director Configuration: PASS
  Economy Configuration: PASS

Schema check: PASS (11 contracts validated, 0 problems)
Boot check: Godot 4.7.1 matches the pin in document 20.
```

("Boot check: ..." is the project's `BootCheck` autoload firing as part of normal project startup under `--script`; unrelated to this check.)

---

## Falsification log

Per the project's LESSONS.md rule that a passing check proves nothing until it has been made to fail against its own mechanism, four separate falsifications were run, each restored immediately afterward and reconfirmed passing. All four samples were backed up to the session scratchpad before starting; a final `diff -rq` after all four confirmed every sample file is byte-identical to its pre-falsification state.

### (i) Reset a required field to its type default

Chosen deliberately as the **least-confident** case: an *inherited* field (`TowerUpgradeDefinition extends UpgradeDefinition`), to test whether the property-reflection walk (`Object.get_property_list()` on the instance) actually reaches ancestor-declared `@export` vars, not just the subclass's own two new fields.

Edit: `src/data/samples/tower_upgrade_definition_sample.tres`, `effect_per_rank = 1.75` → `effect_per_rank = 0.0` (the inherited field's type default).

Command: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`

Exit code: **1**

Verbatim failure line: `Schema check FAILURE: Tower Upgrade Definition.effect_per_rank is at its default value: 0.0`

Restoration: file restored from the scratchpad backup; re-run confirmed `Schema check: PASS (11 contracts validated, 0 problems)`, exit 0.

### (ii) Point a typed reference at the wrong resource class

Edit: `src/data/samples/enemy_definition_sample.tres` — `movement_profile = SubResource("Resource_fogw2")` (a `MovementProfile`) changed to `movement_profile = SubResource("Resource_7lp4w")` (the `AttackProfile` sub-resource already present in the same file), so a `MovementProfile`-typed export points at an `AttackProfile` instance.

Command: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`

Exit code: **1**

Verbatim failure line: `Schema check FAILURE: Enemy Definition.movement_profile is null (required)`

Finding worth recording: Godot 4.7.1's resource loader does not raise a load error or warning for this type mismatch — it silently sets the mismatched-type property to `null` instead of assigning the wrong-typed object. No engine-level error appeared in stdout/stderr for this case; the schema check's own null-check is what caught it (as a required Resource field being null), not an engine diagnostic. This means a reviewer cannot rely on Godot's own load output to catch a wrong-resource-class reference — the schema check has to.

Restoration: file restored from the scratchpad backup; re-run confirmed PASS, exit 0.

### (iii) Remove a sample entirely

Command: `mv src/data/samples/wave_definition_sample.tres <scratchpad>/wave_definition_sample_moved_aside.tres` (no delete tool used, per the hard constraint).

Check command: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`

Exit code: **1**

Verbatim failure line: `Schema check FAILURE: Wave Definition: sample resource missing on disk: res://src/data/samples/wave_definition_sample.tres`

Restoration: `mv <scratchpad>/wave_definition_sample_moved_aside.tres src/data/samples/wave_definition_sample.tres`; re-run confirmed PASS, exit 0.

### (iv) Add a rogue extra field not in the contract

Edit: `src/data/samples/economy_configuration_sample.tres`, appended a line `rogue_extra_field = "PLACEHOLDER_should_not_exist_in_the_contract"` under `[resource]`, a property name `EconomyConfiguration` never declares.

Command: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`

Exit code: **0** (unchanged — `Economy Configuration: PASS`, no warning of any kind in stdout/stderr).

**Decision and reasoning — the check does not, and by design cannot, catch this.** `schema_check.gd`'s recursive validator enumerates properties via `instance.get_property_list()` filtered to `PROPERTY_USAGE_SCRIPT_VARIABLE`, i.e. it only ever visits properties the target script actually declares with `@export`; a key in a `.tres` file that has no matching declared property is invisible to that walk by construction. Godot's own loader corroborates this at the engine level: loading a `.tres` with an undeclared property under a strictly-typed `script = ExtResource(...)` header produced no parse error, no warning, and no observable effect — the extra key is silently dropped. Two reasons this is the right scope for this specific check, not a gap to close:
1. MASTER's stated acceptance criterion is "validates against a sample `.tres` resource with **no missing required field**" — an extra field is a different failure mode (schema drift / stale content) than a missing one, and conflating the two would make failures harder to read (a rogue field and a genuinely missing field would report identically).
2. Catching this would require diffing the `.tres` file's raw key set against the script's declared property set, which is a meaningfully different (and heavier) check than the recursive default-value walk this script does; it would be a reasonable **addition** for a future harness task, not something the existing "no missing required field" check should silently start doing.

No restoration needed for this decision itself, but the edit was still reverted for cleanliness: `economy_configuration_sample.tres` restored from the scratchpad backup; re-run confirmed PASS, exit 0.

**Final confirmation**: `diff -rq src/data/samples <scratchpad>/samples_backup` after all four falsifications reported no differences — every sample file is back to its pre-falsification state.

---

## Contradictions and ambiguities found (not silently resolved)

1. **`UpgradeDefinition.recursive_interaction_guard` type is stated as "enum/string, nullable"** (docs/20 > Contract Field Semantics > Upgrade Definition Contract fields) with no enum member list given anywhere in the document. Resolved here as a plain nullable `String` (empty string = null), documented in `upgrade_definition.gd`'s header comment and in Conventions §4 above. A reviewer may prefer a different resolution (e.g. a real enum once its members are decided by the author) — this was not invented here.

2. **`RepairPrice.pro_ration_rule`** (Tower Definition Contract's "Repair price" struct) names a "pro-ration rule" sub-field with no type or enum member list given anywhere in Contract Field Semantics. Typed as a free-form `String` rather than inventing enum members, per convention 3's explicit bar on adding convenience members. Flagged in `repair_price.gd`'s header comment.

3. **`HopperConversionRule.trigger`** (Economy Configuration's "Hopper-to-Core conversion rate and trigger") similarly names a fixed "trigger" with only one value ever given ("enters Tower Interaction Radius") and no enumerated alternative anywhere. Typed as `String` for the same reason as above, not a one-member enum.

4. **`XpLevelCost`'s "cost formula" is the most substantive ambiguity found.** docs/20 states the type as `struct {shard value: integer, cost formula: L → 10 + 5(L+1)}` — the formula is given as a literal expression with two embedded magic numbers (10 and 5), not as named sub-fields, unlike the structurally similar `ConsolePriceFormula` (`price = Scrap-per-rank × rank`, where the only free variable, Scrap-per-rank, *is* a named field). Two readings are both defensible:
   - **(a)** the formula is fixed application logic (10 and 5 hardcoded in the consuming system's code), and the schema should export only `shard_value`;
   - **(b)** per MASTER's opening line ("All major content types must be data-driven") and docs/20's own rule that content data is "never hardcoded," the coefficients should be authored data too.
   This implementation took reading (b) and added `base_cost: int` and `per_level_increment: int` as exported fields (with `compute_level_cost(level) -> int` implementing `base_cost + per_level_increment * (level + 1)`), which is an **interpretation**, not something docs/20 states explicitly. A reviewer preferring reading (a) would remove the two extra fields and hardcode 10 and 5 in whatever system consumes `XpLevelCost`.

5. **`MergeRule`'s struct has mostly-fixed sub-fields.** docs/20 types Pickup's "Merge rule" as `struct {trigger: at pickup cap, same type only: true, match radius: reference to Economy Configuration's Merge radius field, resulting behaviour: sum into nearest same-type neighbour within radius, else expire oldest of that type}`. Three of the four named parts (`trigger`, `same type only`, `resulting behaviour`) are stated as fixed constants with no alternative given anywhere, not author-tunable values. Only `match_radius_px` and `same_type_only` (kept as an export for completeness even though its only valid value is `true`) were exported; `trigger` and `resulting behaviour` were left as documentation in `merge_rule.gd`'s header comment rather than turned into String fields, unlike the `pro_ration_rule`/`trigger` cases above where a value could plausibly vary by content. This inconsistency (why `trigger` here is a comment but `HopperConversionRule.trigger` above is a String field) is itself worth a reviewer's judgment call — both are "docs/20 states exactly one fixed value with no named alternative," and this implementation treated them differently. Recorded here rather than silently normalised one way.

6. **`PickupDefinition`'s "Unique ID and type" struct was flattened** into two plain exports (`unique_id`, `pickup_type`) rather than given its own wrapper Resource class, on the reasoning that "Unique ID" is a flat string field on every other contract in this project and Pickup's table only co-locates it with `type` as a formatting shorthand. This is a deliberate, stated exception to "every named struct gets its own Resource class," not an oversight.

7. **`WaveDefinition.get_spawn_budget()` cannot be fully self-contained.** "Spawn budget: derived: sum of the wave's spawn groups' cap weights" (docs/20) requires resolving `encounter_sequence` (Encounter Unique IDs) to `EncounterDefinition` resources, then each of those encounters' `spawn_groups` to `EnemyDefinition.entity_cap_weight` by ID — two levels of cross-resource lookup a standalone `Resource` script has no mechanism to perform (no registry, no autoload access from a `Resource`). The method signature takes both lookup dictionaries as parameters instead. This is documented as a genuine architectural gap between "Spawn budget is derived, not authored" and Wave's own field list only carrying string IDs — the actual runtime resolution is properly a job for a later phase's `EntityRegistry` / Wave Director (per docs/20's Owns list for document 20 itself), not for a P0.6 data-contract schema.

8. **`EncounterDefinition.reward` and `Encounter's zero-reward rule`**: MASTER states the Reward struct is "zero for the four prototype encounters." The schema-validation sample deliberately uses a **non-zero** placeholder Reward (`xp=11, scrap=13, cores=2`) rather than the real prototype's zero, since this sample's job (per deliverable B) is to prove every field round-trips through the schema with an unambiguous non-default value — a zero Reward in this fixture would be indistinguishable from an omitted field. The real prototype's four actual Encounter `.tres` files (a later task, not P0.6) are expected to author zero Reward structs as MASTER requires; this sample is a validation fixture, not real content. Same reasoning applied to `WaveDefinition.elite_chance` (real prototype value is 0, sample uses 0.05).

9. **Godot silently drops unrecognized properties and silently nulls type-mismatched ones** (see falsification (ii) and (iv) above) — this is an engine behavior finding, not a docs contradiction, but worth recording since it means no engine-level diagnostic backstops either failure mode; `schema_check.gd`'s own checks are the only backstop for (ii), and nothing backstops (iv) by design (see falsification (iv)'s reasoning).

---

## Honesty notes for the next reviewer

- `schema_check.gd`'s recursive walk recurses into every `Resource`-typed field to unlimited depth (capped at 6 for cycle safety) and into the *first* element of every `Resource`-typed array, but does not recurse into every element of a multi-element array (e.g. `WaveDefinition.enemy_intent_mix` has two entries in the sample; only the array's non-emptiness and the first entry's fields are checked field-by-field). This was a scope decision, not an oversight: MASTER's field list is about the Wave *having* an Enemy intent mix, not about every possible entry being independently audited.
- The check does not enforce numeric range constraints stated in prose (Priority "0 to 100", Elite chance "0 to 1", Health quadrant threshold as a "fraction") beyond the two explicit length rules called out in `tower_definition.gd`/`weapon_definition.gd` comments and implemented in `_check_contract()`. A critical agent should decide whether range enforcement belongs in this check or a later one.
- This report's field-to-type table was built by hand from `docs/20_Technical_Architecture.md` § "Contract Field Semantics" (lines 138-370 as read) and `MASTER_SDLC.md` § "Content Data Contracts" (lines 2182-2462 as read) at the time of writing. It has not been independently cross-checked against the scripts by a second pass — that cross-check is exactly what the next critical agent is for.

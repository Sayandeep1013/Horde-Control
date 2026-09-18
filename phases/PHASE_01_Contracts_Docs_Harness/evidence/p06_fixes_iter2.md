# P0.6 fixes, review iteration 2 (struct-level manifest)

Scope: close the one residual review iteration 2 flagged on `tests/schema_check.gd`
(P0.6 scored 9/10): `REQUIRED_FIELD_MANIFEST` independently asserts every MASTER
Content Data Contracts bullet against its wrapper `@export`, but roughly a dozen
of those bullets are compound and name sub-quantities the schema puts inside a
struct `Resource` (e.g. "XP shard value and level cost formula" -> the wrapper
export `xp_level_cost`, whose class `XpLevelCost` has its own `shard_value`,
`base_cost`, `per_level_increment`). The manifest only ever asserted the wrapper
export existed; it had nothing to say about the struct's own fields, so deleting
`XpLevelCost.shard_value` or `TowerFootprint.interaction_radius_px` from both the
struct script and its sample left the whole check at exit 0.

Only `tests/schema_check.gd` and this evidence file were written. No file under
`src/data/`, `docs/`, `MASTER_SDLC.md`, or any other phase record file was
edited; every file touched for falsification (listed below) was restored and
confirmed byte-identical to its pre-mutation state.

## The fix: `STRUCT_REQUIRED_FIELD_MANIFEST`

Added to `tests/schema_check.gd`, right after `REQUIRED_FIELD_MANIFEST` (the
manifests now sit together, ahead of the `CONTRACTS` driver list):

- **Shape**: `const STRUCT_REQUIRED_FIELD_MANIFEST := { "<StructClassName>": [ {"docs20": "<docs/20 wording>", "exports": ["<export>", ...]}, ... ], ... }`,
  and `{"docs20": "...", "method": "<method name>"}` for the two sub-quantities
  docs/20 types as part of a struct but the schema correctly resolves rather
  than authors (see "Method-based entries" below). Same two-shape convention
  `REQUIRED_FIELD_MANIFEST` already uses for `WaveDefinition.get_spawn_budget()`.
- **Key changed from `"master"` to `"docs20"`** relative to `REQUIRED_FIELD_MANIFEST`'s
  dictionaries, on purpose: these strings are transcribed from docs/20's
  struct-shape prose, not from a MASTER bullet - MASTER never itemises a
  struct's own sub-fields, only docs/20 does. Same structure otherwise.
- **Keyed by struct class name** (`Script.get_global_name()`, the same value
  `_validate_resource()` already computes as `class_name_str`), not by contract
  display name or MASTER bullet, because one struct class is routinely reused
  across more than one contract or field (`TelegraphData` is both
  `EnemyDefinition.telegraph_data` and every element of
  `EncounterDefinition.telegraph_requirements`; `DropTable` is both
  `EnemyDefinition.drop_table` and `OvertimeCondition.finisher_drop_override`;
  `PressureMetricConstants` is both `DirectorConfiguration`'s and
  `WaveDefinition`'s field of that name; `RingDefinition` is both
  `SpawnRingGeometry.tower_ring` and `.view_ring`). One entry covers every
  place the class appears.
- **Checked by** the new `_check_struct_required_fields(class_name_str, instance,
  path_prefix, failures)`, the struct-level counterpart of
  `_check_required_field_manifest()`. It is a no-op whenever `class_name_str`
  has no entry (contract root classes are never keys here, so no double-check
  against `REQUIRED_FIELD_MANIFEST` occurs).
- **Wired into the existing recursion, not a new driver.** The one new call
  site is inside `_validate_resource()`, immediately after `class_name_str` is
  computed and before the per-property walk:
  `_check_struct_required_fields(class_name_str, sample_obj, path_prefix, failures)`.
  Because `_validate_resource()` already recurses into every nested `Resource`
  field at any depth and every element of every typed array (R4, iteration 2),
  this one call site automatically exercises every struct's manifest entry
  everywhere a sample actually instantiates that class - contract root, single
  nested struct, doubly-nested struct (e.g.
  `WaveDefinition.overtime_condition.finisher_spawn_rate`), and every array
  element - with no separate per-contract list to keep in sync. Falsification
  test 5 below demonstrates the doubly-nested case.
- Failure message format: `"<path> (<StructClassName>): docs/20 field \"<docs20 text>\" has no matching @export \"<export>\" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)"`,
  and the method form: `"<path> (<StructClassName>): docs/20 field \"<docs20 text>\" (derived) has no method <name>() on the struct"`.
  Distinct wording from `REQUIRED_FIELD_MANIFEST`'s contract-level message
  (`"... MASTER field ... has no matching @export ... (REQUIRED_FIELD_MANIFEST)"`)
  so the two are never confused in output, and includes the full dotted
  `path_prefix` so a failure inside a doubly-nested struct still names exactly
  where it is.

### Method-based entries (derived sub-quantities)

Two docs/20 struct sub-quantities are correctly *not* authored `@export`
fields, and the manifest asserts their resolving method instead, following the
precedent `REQUIRED_FIELD_MANIFEST` already set for Wave's Spawn budget
(`get_spawn_budget()`):

- `MergeRule`: docs/20's "match radius" is typed "reference to Economy
  Configuration's Merge radius field", not a per-pickup number (`merge_rule.gd`'s
  own header comment explains this at length, citing P0.6 review iteration 2
  R2 - Major, and the two samples that had already drifted to 71 vs 64 the day
  they were written). The struct instead exposes `get_match_radius_px(economy)`.
  Manifest entry: `{"docs20": "... match radius ...", "method": "get_match_radius_px"}`.
- `ConsolePriceFormula`: docs/20's "formula" (`price = Scrap-per-rank x rank
  being bought`) is a pure function of `scrap_per_rank` and a caller-supplied
  rank, not stored data; the struct exposes `compute_price(rank_being_bought)`.
  Manifest entry: `{"docs20": "... formula ...", "method": "compute_price"}`.

## Struct coverage: 41 classes mapped, docs/20 source per entry

`src/data/` holds 54 `.gd` scripts: the 11 contract scripts already covered by
`REQUIRED_FIELD_MANIFEST`/`CONTRACTS`, `contract_enums.gd` (an enum registry
with no `@export` instance fields - not a struct resource at all, out of
scope), and 42 struct scripts. 41 of the 42 are mapped below; the one
exception (`BandedValue`) is explained in "Left unmapped" further down.

### Shared structs (docs/20 § Contract Field Semantics > "Shared fields and struct types")

| Struct class | docs/20 struct definition source | Exports required |
| --- | --- | --- |
| `ReadabilityProfile` | Shared table, "Readability profile" row | `silhouette_class`, `reserved_colour`, `minimum_on_screen_size_px` |
| `TelegraphData` | Shared table, "Telegraph data" row | `windup_duration_seconds`, `telegraph_shape`, `telegraph_colour`, `audio_cue_id`, `lead_time_seconds` |
| `SpawnGroup` | Shared table, "Spawn group" row | `enemy_definition_id`, `count`, `start_offset_seconds`, `spawn_interval_seconds`, `direction_weighting_override` |
| `MovementProfile` | Shared table, "Movement profile" row | `speed_multiplier`, `body_radius_px` |
| `AttackProfile` | Shared table, "Attack profile" row | `attack_type`, `damage_per_hit_or_tick`, `cycle_or_tick_interval_seconds`, `reach_or_range_px` |
| `EffectData` | Shared table, "Effect" row | `kind`, `magnitude`, `target` (inert - see note below) |
| `OvertimeCondition` | Shared table, "Overtime condition" row | `stall_threshold`, `finisher_enemy_id`, `finisher_spawn_rate`, `finisher_drop_override` |
| `FinisherSpawnRate` | Shared table, "Overtime condition" row's inline "finisher spawn rate" sub-struct | `count`, `interval_seconds` |
| `PressureMetricConstants` | Shared table, "Pressure Metric constants" row | `escalation_threshold`, `escalation_hold_time_seconds`, `minimum_gap_between_escalations_seconds`, `de_escalation_threshold`, `de_escalation_lift_threshold`, `de_escalation_expiry_seconds`, `re_arm_lockout_seconds` |
| `DropTable` | Shared table, "Drop table" row | `xp_shards`, `scrap`, `cores` |
| `Reward` | Shared table, "Reward" row | `xp`, `scrap`, `cores` |

**EffectData note**: mapped because docs/20 fully spells out the struct, but
it is inert today - none of the 11 `CONTRACTS` samples instantiate it anywhere
in their graph (`grep -rn "EffectData" src/data/` finds only its own
`class_name` line). docs/20 says Effect is "used by a status effect's Tick
effect field", and Status Effect Definition is a slice-only, deferred contract
with no schema script or sample yet. The entry starts being exercised the day
that contract exists; it does nothing harmful sitting unused now.

### Contract-specific structs

| Struct class | docs/20 source (Contract Field Semantics > ...) | Exports required |
| --- | --- | --- |
| `IntentBudgetOverride` | Encounter Definition Contract fields > Intent budget overrides (inline pair) | `target_intent`, `count` |
| `EnemyIntentMixEntry` | Wave Definition Contract fields > Enemy intent mix (inline pair) | `target_intent`, `proportion` |
| `MaxHealthAndShieldFraction` | Tower Definition Contract fields > Maximum health and base shield fraction | `maximum_health`, `base_shield_fraction` |
| `ShieldRegeneration` | Tower Definition Contract fields > Shield regeneration rate and delay | `rate_percent_per_second`, `delay_seconds` |
| `TowerFootprint` | Tower Definition Contract fields > Footprint radius and Interaction Radius | `footprint_radius_px`, `interaction_radius_px` |
| `TargetingRuleParameters` | Tower Definition Contract fields > Targeting rule parameters | `range_px`, `intent_preference` |
| `RepairPrice` | Tower Definition Contract fields > Repair price | `scrap_cost`, `health_restored`, `pro_ration_rule` |
| `PersistentAssetRule` | Tower Definition Contract fields > Persistent asset rules (inline pair) | `asset_class`, `persists_across_biomes` |
| `EngagementRhythm` | Weapon and Evolution Definition Contract fields > Engagement rhythm and fire rate | `rhythm`, `fire_rate_per_second` |
| `ProjectileDefinition` | Weapon and Evolution Definition Contract fields > Projectile definition | `speed_px_per_second`, `lifetime_seconds`, `pooling_class` |
| `WeaponEvolutionRequirement` | Weapon and Evolution Definition Contract fields > Evolution prerequisites and the evolution target | `prerequisites`, `evolution_target_id` |
| `MergeRule` | Pickup Definition Contract fields > Merge rule | `trigger`, `same_type_only`, `resulting_behaviour`, plus method `get_match_radius_px` for "match radius" |
| `VisualAudioCue` | Pickup Definition Contract fields > Visual and audio cue | `sprite_reference`, `audio_cue_id` |
| `InputBufferDuration` | Player Definition Contract fields > Input buffer duration | `duration_ms`, `ticks` |
| `SpawnRingGeometry` | Director Configuration Contract fields > Spawn ring geometry | `tower_ring`, `view_ring` |
| `RingDefinition` | Director Configuration Contract fields > Spawn ring geometry's inline Tower ring / view ring sub-struct | `inner_radius_px`, `width_px` |
| `SpawnValidationRetry` | Director Configuration Contract fields > Spawn validation retry steps and angle increment | `steps`, `angle_degrees` |
| `MarkerLeadTimes` | Director Configuration Contract fields > Off-screen and on-screen marker lead times | `off_screen_seconds`, `on_screen_minimum_seconds` |
| `DirectionalWeightingEntry` | Director Configuration Contract fields > Directional weighting rules per encounter type | `encounter_type`, `lane_count`, `lane_width_degrees`, `lane_separation_rule`, `heavy_share`, `ring`, `hunt_arc_degrees`, `hunt_arc_share` |
| `EncounterPriorityEntry` | Director Configuration Contract fields > Encounter priority table (inline pair) | `encounter_type`, `priority` |
| `RecoveryGapEntry` | Director Configuration Contract fields > Default recovery gap table (inline pair) | `encounter_type`, `recovery_gap_seconds` |
| `InterWaveGapDefaults` | Director Configuration Contract fields > Inter-wave gap defaults | `standard_seconds`, `teaching_wave_seconds` |
| `PressureIntentWeightEntry` | Director Configuration Contract fields > Pressure Metric intent weights (inline pair) | `target_intent`, `weight` |
| `OffscreenUpdateThresholds` | Director Configuration Contract fields > Off-screen update reduction thresholds | `distance_multiplier`, `tick_divisor`, `tower_exclusion_radius_px` |
| `SiegeVolumeConstants` | Director Configuration Contract fields > Siege volume formula constants | `multiplier_defaults`, `hunter_percentage`, `spawn_window_fraction` |
| `XpLevelCost` | Economy Configuration Contract fields > XP shard value and level cost formula | `shard_value`, `base_cost`, `per_level_increment` |
| `HopperConversionRule` | Economy Configuration Contract fields > Hopper-to-Core conversion rate and trigger | `rate_scrap_per_core`, `trigger` |
| `RunEndSettlementRates` | Economy Configuration Contract fields > Run-End Settlement rates | `per_biome_cleared_cores`, `per_boss_killed_cores`, `per_full_minute_cores` |
| `ConsolePriceFormula` | Economy Configuration Contract fields > Upgrade Console price formula | `scrap_per_rank`, plus method `compute_price` for "formula" |
| `DominanceAuditParameters` | Economy Configuration Contract fields > Dominance audit threshold and sample size | `threshold_fraction`, `minimum_runs` |

That is 11 shared + 30 contract-specific = 41 struct classes.

## Left unmapped

**`BandedValue`** (`src/data/banded_value.gd`, used by `EnemyDefinition.health_band`,
`EnemyDefinition.damage_band`, and `WeaponDefinition.damage_band`) has **no**
`STRUCT_REQUIRED_FIELD_MANIFEST` entry. docs/20 types its two sub-quantities as
two *separate* shared-table rows - "Health" (integer, "current or maximum HP
value") and "Band label" (nullable enum {Low, Mid, High}) - and never once
writes out a combined struct shape resembling `BandedValue`'s three fields
(`value`, `band_label`, `has_band_label`). `banded_value.gd`'s own header
comment confirms this reading: "docs/20 types the raw value (integer)
separately from 'Band label' ... One resource covers all three usages" -
grouping them into one `Resource` is a P0.6 schema convention ("P0.6
convention 5, author decision this session" per that same comment), not a
docs/20-stated struct. Giving it an entry here would mean transcribing the
schema's own convention back into an "independent" manifest - exactly the
derivation this manifest exists to avoid (requirement 1: transcribe from
docs/20, not from the scripts).

Practical effect of the gap: `BandedValue.value` is still exercised by the
existing generic default-value walk (Pass 3), and `BandedValue.band_label`
already has its own `NULLABLE_PRIMITIVE_PAIRS` entry (added review iteration
2). Only a *full deletion* of `BandedValue.value` from the struct script and
every sample together would still slip through undetected, the same class of
gap this whole pass exists to close, left open here rather than fixed because
fixing it would require inventing a struct shape docs/20 does not state. Flagging
for the author: if `BandedValue`'s shape should be documented in docs/20 as its
own struct (mirroring how the schema actually implements Health + Band label),
that is a docs/20 change the author would need to approve; short of that, this
residual stands as a known, recorded gap.

`contract_enums.gd` is not treated as a struct resource: it holds only enum
type definitions (`class_name ContractEnums`, no `@export` var declared), so
there is no instance shape for a manifest entry to require.

## Falsification log

All mutations below were performed by `cp` aside, hand-edit both the struct
`.gd` script and its sample `.tres`, run, capture, `cp` restore, then `diff`
the restored file against its backup. Every `diff` printed nothing (byte
identical). Godot invocation used throughout:
`/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`.

### Baseline (before any mutation)

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
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
EXIT: 0
```

### Test 1 (reviewer's demonstration #1): delete `XpLevelCost.shard_value`

Mutated `src/data/xp_level_cost.gd` (removed `@export var shard_value: int = 0`)
and `src/data/samples/economy_configuration_sample.tres` (removed
`shard_value = 3` from the `XpLevelCost` sub-resource).

```
EXIT: 1
Economy Configuration: FAIL (1 problem(s))
Schema check FAILURE: Economy Configuration.xp_level_cost (XpLevelCost): docs/20 field "Economy Configuration Contract fields > XP shard value and level cost formula struct: shard value." has no matching @export "shard_value" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
```

Restored both files; `diff` against backups: no output (identical) for both.

### Test 2 (reviewer's demonstration #2): delete `TowerFootprint.interaction_radius_px`

Mutated `src/data/tower_footprint.gd` (removed
`@export var interaction_radius_px: int = 0`) and
`src/data/samples/tower_definition_sample.tres` (removed
`interaction_radius_px = 167` from the `TowerFootprint` sub-resource).

```
EXIT: 1
Tower Definition: FAIL (1 problem(s))
Schema check FAILURE: Tower Definition.tower_footprint (TowerFootprint): docs/20 field "Tower Definition Contract fields > Footprint radius and Interaction Radius struct: Interaction Radius." has no matching @export "interaction_radius_px" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
```

Restored both files; `diff` against backups: no output (identical) for both.

### Test 3 (further field #1, different struct/contract): delete `ReadabilityProfile.minimum_on_screen_size_px`

Mutated `src/data/readability_profile.gd` and
`src/data/samples/enemy_definition_sample.tres` (removed
`minimum_on_screen_size_px = 28` from the `ReadabilityProfile` sub-resource).

```
EXIT: 1
Enemy Definition: FAIL (1 problem(s))
Schema check FAILURE: Enemy Definition.readability_profile (ReadabilityProfile): docs/20 field "Readability profile struct (Shared fields and struct types): minimum on-screen size." has no matching @export "minimum_on_screen_size_px" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
```

Restored both files; `diff` against backups: no output (identical) for both.

### Test 4 (further field #2, different struct/contract): delete `RunEndSettlementRates.per_boss_killed_cores`

Mutated `src/data/run_end_settlement_rates.gd` and
`src/data/samples/economy_configuration_sample.tres` (removed
`per_boss_killed_cores = 5` from the `RunEndSettlementRates` sub-resource).

```
EXIT: 1
Economy Configuration: FAIL (1 problem(s))
Schema check FAILURE: Economy Configuration.run_end_settlement_rates (RunEndSettlementRates): docs/20 field "Economy Configuration Contract fields > Run-End Settlement rates struct: per boss killed." has no matching @export "per_boss_killed_cores" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
```

Restored both files; `diff` against backups: no output (identical) for both.

### Test 5 (further field #3, different struct/contract, doubly-nested): delete `FinisherSpawnRate.interval_seconds`

Chosen specifically to exercise a struct nested two levels deep
(`WaveDefinition.overtime_condition.finisher_spawn_rate.interval_seconds`), to
confirm the single call site inside `_validate_resource()` reaches structs at
any recursion depth, not only direct contract-root fields. Mutated
`src/data/finisher_spawn_rate.gd` and
`src/data/samples/wave_definition_sample.tres` (removed
`interval_seconds = 5.0` from the `FinisherSpawnRate` sub-resource).

```
EXIT: 1
Wave Definition: FAIL (1 problem(s))
Schema check FAILURE: Wave Definition.overtime_condition.finisher_spawn_rate (FinisherSpawnRate): docs/20 field "Overtime condition struct > finisher spawn rate sub-struct (Shared fields and struct types): interval." has no matching @export "interval_seconds" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
```

The failure path (`Wave Definition.overtime_condition.finisher_spawn_rate`)
confirms both the depth reach and that `path_prefix` correctly names the full
dotted location. Restored both files; `diff` against backups: no output
(identical) for both.

### Test 6 (contract-level manifest regression check): delete `EnemyDefinition.unique_id`

Confirms `REQUIRED_FIELD_MANIFEST` (the existing contract-level check) still
fails exactly as it did before this change, unaffected by the new struct-level
addition. Mutated `src/data/enemy_definition.gd` (removed
`@export var unique_id: String = ""`) and
`src/data/samples/enemy_definition_sample.tres` (removed
`unique_id = "PLACEHOLDER_enemy_001"`).

```
EXIT: 1
Enemy Definition: FAIL (1 problem(s))
Schema check FAILURE: Enemy Definition: MASTER field "Unique ID." has no matching @export "unique_id" on the schema (REQUIRED_FIELD_MANIFEST)
```

Message text and format identical to `REQUIRED_FIELD_MANIFEST`'s pre-existing
behaviour - the new `STRUCT_REQUIRED_FIELD_MANIFEST` check did not fire here
(as expected: `EnemyDefinition` is never a key in it) and did not interfere.
Restored both files; `diff` against backups: no output (identical) for both.

### Final (after all mutations restored)

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
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
EXIT: 0
```

Identical to the baseline run.

## Repository state check

`git status --porcelain --untracked-files=all`, run after all restores, shows
`tests/schema_check.gd` modified and this evidence file untracked, as
expected. `git diff --stat -- src/data/` returns nothing (zero diff - every
falsification mutation was fully reverted). `git diff --stat -- tests/schema_check.gd`
shows `330 insertions(+), 0 deletions(-)` - a pure addition, consistent with
requirement 4 (keep every existing check working).

`git status` at the same moment also lists a number of files this session did
not touch (`CLAUDE.md`, `MASTER_SDLC.md`, `NEXT_SESSION.md`, `docs/01_Design_Pillars.md`,
`docs/02_Gameplay_Loop.md`, `docs/28_AI_Development_Workflow.md`,
`phases/LESSONS.md`, `phases/PHASE_01_Contracts_Docs_Harness/EXECUTION_LOG.md`,
`phases/PHASE_01_Contracts_Docs_Harness/LEDGER.md`,
`phases/PHASE_01_Contracts_Docs_Harness/REVIEW.md`, `phases/README.md`,
`tests/run_tests.ps1`) and one untracked file this session did not create
(`phases/PHASE_01_Contracts_Docs_Harness/evidence/review_p07_iter2.md`). These
are consistent with other, concurrent review-iteration-2 work in this
repository (the evidence directory already held `review_p04_iter2.md` and
`review_p06_iter2.md` at the start of this task) and are not this session's
changes - confirmed by this session never opening any of those paths with a
write tool. Flagging rather than silently reporting a narrower "only two files
changed" claim.

## Disagreements / things not done

- The rename from `"master"` to `"docs20"` as the dictionary key in
  `STRUCT_REQUIRED_FIELD_MANIFEST`'s entries is a deliberate deviation from
  copying `REQUIRED_FIELD_MANIFEST`'s key name verbatim, made because these
  strings are not MASTER bullets. Flagging in case the reviewer wanted literal
  key-name parity instead; the shape (dict with a text key + `exports`/`method`)
  is otherwise identical.
- `BandedValue` is left unmapped rather than fixed - see "Left unmapped" above.
  This is a recorded gap, not a silent omission.
- No gate is described as passed, satisfied, or ready anywhere in this file or
  in the report to the caller, per standing instruction.

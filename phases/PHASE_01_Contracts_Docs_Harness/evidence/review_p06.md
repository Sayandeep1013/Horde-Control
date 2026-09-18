# P0.6 Critical Agent Review — Data Contract Schemas

Reviewer: P0.6 critical agent (Opus), blind to the implementer's reasoning and transcript. Date: 2026-09-18.

Scope reviewed: `src/data/*.gd` (54 scripts), `src/data/samples/*.tres` (11), `tests/schema_check.gd`, against `MASTER_SDLC.md` § Content Data Contracts (lines 2182–2462), `docs/20_Technical_Architecture.md` § Contract Field Semantics (lines 138–369), `PLAN.md` § "P0.6 — Data contract schemas" (ten steps), the Tasks-table row, the exit criteria, and the predetermined-risk table. `evidence/p06_report.md` was read as the implementer's **claim** and every one of its eleven field-to-type tables was re-derived from the two source documents and re-checked against the scripts.

This review does not state that any gate is passed, satisfied, met, or ready. That is the author's decision.

**Work done for this review, beyond reading:** the Schema check was re-run by me at exit 0; four independent falsification runs were executed against mutated copies of the samples (two made it fail correctly, two revealed gaps); every sample was restored and verified byte-identical by `md5sum -c` against a pre-mutation manifest; the working tree carries no modification from this review other than this file.

---

## 1. Ledger disposition

| ID | Bears on P0.6? | Disposition | Reason |
| --- | --- | --- | --- |
| F01-01 | No (phase-entry configuration) | **Not closed** | Its own text makes closure conditional on a next-session re-check that has not happened. I confirmed `.claude/settings.local.json` now reads `{"permissions":{"allow":[]}}`, so the *file* half of D84 holds; the behavioural half (that `delete_file` and `export_project` prompt again) is still undemonstrated. Nothing in P0.6's artifacts touches it. |
| F01-02 | No | **Not closed** | Open half (the `ask` gate not intercepting subagents) is unchanged and untestable from inside this review. The closed half is unaffected by P0.6. The P0.6 delegation's no-delete/no-export constraint is visible in its outcome: `p06_report.md` falsification (iii) used `mv` to a scratchpad rather than a delete tool, and no export was run. Instruction-level mitigation held for this task. |
| F01-03 | No (P0.7) | **Not closed, correctly recorded** | Third-party skill defect, recorded rather than fixed per CLAUDE.md. Unchanged by P0.6. |
| F01-04 | No (P0.7) | **Not closed, low priority** | gdUnit4 exit code 1 still unreproduced. Out of P0.6's surface. |
| F01-05 | Partly | **Closed for the scope it names; the same lesson has a new uncovered instance in P0.6's artifacts** | I did not re-run the export (out of bounds for this review), so I take the recorded pack-search evidence at face value for `addons/gdUnit4`, `tests/` and `reports/`. But `export_presets.cfg` line 11 reads `exclude_filter="addons/gdUnit4/*, tests/*, reports/*"` under `export_filter="all_resources"`, and `src/data/samples/` is not in it — so the eleven PLACEHOLDER fixtures P0.6 created ship in every release build. F01-05 was fixed the same day the samples were written and swept the test surface but not the schema fixtures. Raised as **R10** below. |
| F01-06 | No (P0.4) | **Not closed, owner the author** | Unchanged. |
| F01-07 | No (P0.4) | **Closed** | Fix is in doc 02; unrelated to P0.6. |
| F01-08 | Yes (raised by P0.6) | **Closed as a recorded standing fact — independently reproduced by me** | I re-ran the experiment: pointed `enemy_definition_sample.tres`'s `movement_profile` (a `MovementProfile`) at the file's `AttackProfile` sub-resource, captured stdout and stderr separately. Result: exit 1, `Schema check FAILURE: Enemy Definition.movement_profile is null (required)` on stderr, and **zero** engine diagnostics on either stream. The claim is exactly right: Godot 4.7.1 silently nulls a type-mismatched resource property, and the check's own null assertion is the only backstop. The finding's own conclusion — that Phases 02 onward must assume no engine help here — is correct and should be carried to LESSONS. It is a tested observation, not an inferred one, and the ledger says so. |
| F01-09 | Yes (raised by P0.6) | **Adjudicated below — 3 go to the author, 6 I settle as reviewer** | See § 2. F01-09's ledger row should be split accordingly rather than closed as a single item. |

---

## 2. Adjudication of the nine F01-09 items

The test I applied: an item goes to the **author** if settling it changes what the game does, changes a contract's field list, or resolves a conflict between two documents the author owns. It is **mine to settle** if it is only a question of how an already-decided meaning is spelled in GDScript.

| # | Item | Verdict | Adjudication |
| --- | --- | --- | --- |
| 1 | `recursive_interaction_guard` typed "enum/string, nullable" with no member list | **Reviewer settles — but not the way it was implemented** | The type is under-specified, not contradictory, so no author question arises. A `String` is the right choice: inventing enum members for a rule MASTER only describes in prose would be exactly the convenience-member invention convention 3 bars. **But the nullability handling is wrong.** docs/20 says *nullable*; the fixed-in-advance convention pairs a nullable primitive with `has_<field>`; the implementation instead used `""` as the null sentinel, and `""` is also the export's default. So the schema cannot distinguish "the author decided this upgrade has no triggered effect" from "the author never filled the field in" — which is precisely what MASTER's "No upgrade may be implemented if it can trigger unbounded recursion without a defined guard" needs to be able to tell apart, and precisely the ambiguity the `has_` convention exists to remove. **Ruling: add `has_recursive_interaction_guard: bool`, per the convention as written.** Raised as **R7**. |
| 2 | `RepairPrice.pro_ration_rule` named as an enum with no members | **Reviewer settles — implementation correct** | `String` is right, for the same reason as item 1, and the nullability problem does not arise because docs/20 never calls this field nullable: every Repair price must state a pro-ration rule. No change. The one follow-on worth recording: docs/20's Tower table should eventually name the rule's members; that is a doc-20 maintenance note, not a blocker for P0.6. |
| 3 | `HopperConversionRule.trigger` named as an enum with one fixed value | **Reviewer settles — implementation correct** | `String` over a one-member enum is right. A one-member enum would be indistinguishable from its default forever (the same trap `hurtbox_definition` fell into — see R6), whereas a String carries an auditable value. No change. |
| 4 | XP level cost formula's constants (10, 5) exported as authored fields vs. hardcoded | **Reviewer settles the substance; the author owns the record** | Reading (b) is correct and I settle it: `10 + 5(L+1)` is a **Provisional Default** carried in MASTER's Provisional Values Register ("XP & levels", owner doc 13, MASTER line 3255) and restated at line 1278. Under the Provisional Defaults Policy a provisional number is by definition expected to be retuned, and CLAUDE.md requires every gameplay number to live in the Register with every other place referencing it. Baking 10 and 5 into consuming code would put a Register number in a place no data edit can reach. So `base_cost` and `per_level_increment` are right. **However**, this adds two sub-fields docs/20 does not name to a contract's field list, and CLAUDE.md requires every design change to get a Review Decision Log row naming the alternative. The report writes both alternatives up thoroughly, which is most of the work, but no row exists (D84–D87 are the latest and none covers this). **Ruling: keep the fields; the author writes or declines a Decision Log row, and docs/20's Economy table is updated to name the two sub-fields.** Raised as **R8**. |
| 5 | `MergeRule` treats fixed sub-fields inconsistently with `HopperConversionRule` | **Reviewer settles** | Both are "docs/20 names exactly one fixed value". The consistent resolution is the `HopperConversionRule` one: export the fixed value as a String so a `.tres` carries it and a diff can show it changed, rather than burying it in a header comment where no check and no reviewer diff will ever see it. **Ruling: `MergeRule` gains `trigger: String` and `resulting_behaviour: String`,** matching item 3. Raised as **R3**. This item also exposed a second, larger defect the report did not flag — see R2. |
| 6 | Pickup's "Unique ID and type" flattened rather than wrapped in a struct | **Reviewer settles — implementation correct** | docs/20 co-locates the two in one table row as a formatting shorthand; "Unique ID" is a flat string on all eleven contracts. A one-off `PickupIdentity` wrapper would make Pickup the only contract whose ID is not reachable at `.unique_id`, which is worse. No change. (The same shorthand appears in the out-of-scope Boss contract; whoever types Boss before Phase 3 should flatten it the same way.) |
| 7 | `get_spawn_budget()` cannot be self-contained | **Reviewer settles — implementation correct** | Not a contradiction at all: docs/20 says Spawn budget is derived and not authored, and a `Resource` has no registry access, so passing the two lookups as parameters is the only honest option that keeps the field out of the authorable surface. The convention "not exported because docs/20 marks it derived" is satisfied. One cosmetic note: the parameters are bare `Dictionary`; Godot 4.4+ supports `Dictionary[String, EncounterDefinition]`, and the project's own "never a bare Dictionary" convention reads more naturally if method signatures follow it too. Not a defect — method parameters are not exports. |
| 8 | Sample uses a non-zero Reward where MASTER says the four prototype encounters are zero | **Reviewer settles — implementation correct** | A validation fixture is not content. MASTER's zero-reward rule binds the four real prototype encounter `.tres` files, which are a later task explicitly out of P0.6's scope ("Out: content instances"). A zero Reward in this fixture would be indistinguishable from an omitted field, which is the exact failure mode PLAN step 8 was written to prevent. Same for `elite_chance = 0.05`. No change. Worth carrying forward as a note on the later content task so nobody copies the fixture's values. |
| 9 | Godot silently drops unrecognised properties and silently nulls type-mismatched ones | **Author does not need this; it is two separate items and only one is settled** | The nulling half is F01-08 and I reproduced it (above). The dropping half is *not* settled: see R5. The implementer ran the rogue-field falsification the PLAN named in advance, got exit 0, and argued the check should not catch it. The argument that "extra field ≠ missing field" is correct on its own terms, but the plan named that case precisely because Phase 00's defect was an existence-only assertion, and a stale `.tres` key is how schema drift actually shows up once content exists. **Ruling: this is a known limitation with an owner, not a resolved question.** Raised as **R5**. |

**Items that must go to the author: 4 (the Decision Log row only, not the substance), plus R12 below, which the implementer did not flag.** Items 1, 2, 3, 5, 6, 7, 8 and the F01-08 half of 9 are settled here.

---

## 3. Conformance table

Method: for each contract, MASTER's required-field bullets were listed, each field's type was read from docs/20's "Shared fields and struct types" table or the contract-specific table, and each was matched against the actual `@export`. Extras were found by counting exports against bullets. This was done for all eleven contracts and all 42 struct resources, not sampled.

| Contract | MASTER fields | Exports | Missing | Unrequired extras | Type mismatches |
| --- | --- | --- | --- | --- | --- |
| Enemy Definition | 15 | 15 | none | none | none. `health_band`/`damage_band` as `BandedValue` is D87; `entity_cap_weight` default 0 is deliberately an invalid value so "unset" is visible (see R11) |
| Encounter Definition | 20 | 20 | none | none | none. `telegraph_requirements: Array[TelegraphData]` is a defensible reading of "list of Telegraph data references", but docs/20's "with lead time" has nowhere to live — **R12** |
| Upgrade Definition | 13 | 14 (13 + `has_max_rank`) | none | none | `recursive_interaction_guard` nullability convention deviation — **R7** |
| Wave Definition | 12 authorable + 1 derived | 13 (12 + `has_maximum_duration`) | none | none | none. Spawn budget correctly **not** exported (method only). Difficulty band correctly a plain `DifficultyBand` enum, **not** `BandedValue` — the trap in D87 was avoided |
| Tower Definition | 9 | 9 | none | none | none. `evolution_stage_thresholds: Array[int]` with the length-4 rule asserted in the check, which is the right split |
| Tower Upgrade Definition | inherited + 2 | 2 + inherited | none | none | none. `extends UpgradeDefinition`, not copied; `pool_ownership == Tower` asserted on the sample rather than faked as a default |
| Weapon and Evolution | 9 | 9 | none | none | none |
| Pickup Definition | 6 bullets | 7 (ID+type flattened) | **`MergeRule.trigger`, `MergeRule.resulting_behaviour`** — 2 of docs/20's 4 Merge-rule sub-fields absent (**R3**) | none at contract level | **`MergeRule.match_radius_px: int`** where docs/20 types it "reference to Economy Configuration's Merge radius field" (**R2**) |
| Player Definition | 11 | 11 | none in the **schema**; `hurtbox_definition` absent from the **sample** (**R6**) | none | none |
| Director Configuration | 16 | 16 | none | none | none. `Array[DirectionalWeightingEntry]` for "struct, keyed by encounter type" is correct — each entry carries its own `encounter_type`, so the keying survives without a `Dictionary` |
| Economy Configuration | 12 | 12 | none | **`XpLevelCost.base_cost`, `XpLevelCost.per_level_increment`** — 2 sub-fields docs/20 does not name (**R8**; substance upheld, record incomplete) | none |

**Enum member lists — all 28 checked, member by member and in order, against Contract Field Semantics.** `TargetIntent`, `BandLabel`, `DifficultyBand`, `ContactBehaviour`, `EntityCapBehaviour`, `PauseAndDeferralBehaviour`, `PoolOwnership`, `VisualReadabilityImpact`, `PerformanceCostCategory`, `SilhouetteClass`, `TelegraphShape`, `AttackType`, `EffectKind`, `EffectStructTarget`, `EncounterType` (all 16, in order), `LaneSeparationRule`, `RingType`, `PathingFallbackBehavior`, `FailureResolution`, `Rarity`, `UpgradeEffectTarget`, `BossOverlapRules`, `CoverageShape`, `EngagementRhythmKind`, `EvolutionChangeAxis`, `MagnetBehaviour`, `PickupType`, `HurtboxDefinition`. **Zero deviations. No `NONE`/`UNSET`/`INVALID`/`MAX` member added anywhere.** The two `None` members (`ContactBehaviour.None`, `VisualReadabilityImpact.None`) are docs/20's own members, not conveniences. `PickupType.Health` and `SilhouetteClass.Boss` are docs/20 members too and do not constitute typing an out-of-scope contract. The one genuine trap here — Upgrade's "Effect target" `{Player, Tower, PlayerWeapon, TowerWeapon}` versus the Effect struct's "target" `{Player, Tower, Enemy}` — was not conflated; they are `UpgradeEffectTarget` and `EffectStructTarget`. This is the cleanest part of the deliverable.

**Shared structs typed exactly once.** 54 `class_name` declarations, 54 distinct names (verified by `grep -h "^class_name" src/data/*.gd | sort | uniq -d` returning nothing). Reuse verified at the call sites: `PressureMetricConstants` serves both Wave and Director; `DirectionalWeightingEntry` serves Director, Encounter's override and SpawnGroup's override; `Reward` serves `reward` and `partial_reward_rules`; `DropTable` serves Enemy and `OvertimeCondition.finisher_drop_override`; `TelegraphData` serves Enemy and Encounter; `BandedValue` serves three fields across two contracts. `DropTable` and `Reward` are correctly kept as two types — docs/20 defines them as two structs with different field names ("XP shards" vs "XP"). **No second copy of any shared struct exists.** The only duplication I found is of *data*, not of type: R2.

**Scope.** No `BiomeDefinition`, `BossDefinition`, `EliteAffixDefinition` or `StatusEffectDefinition` class exists. Every cross-contract reference is a `String` or `Array[String]` of Unique IDs (`allowed_affixes`, `biome_tags`, `biome_context_id`, `base_weapon_reference_id`, `starting_weapon_reference_id`, `finisher_enemy_id`, `encounter_sequence`, `enemy_definition_id`, `evolution_target_id`, `prerequisites`, `exclusions`) — correct. `EffectData` is typed, but that is the shared "Effect" struct PLAN step 4 names explicitly, not the Status Effect contract, so it is plan-compliant; note only that nothing in scope references it and no sample validates it (it is loaded and instantiated by the check's pass 1, so it is not entirely unexercised).

**Conventions fixed in advance.** One file per resource with `class_name`: 54/54. Nullable Resources exported typed and left null: 3/3. `BandedValue` per D87 on the three band fields, and *not* on Wave's Difficulty band: correct. Typed arrays everywhere, zero bare `Array`/`Dictionary` exports across all 54 scripts: verified by grep. List-of-pairs as `Array[SomeSmallResource]`: 7/7. `TowerUpgradeDefinition extends UpgradeDefinition`: yes. Wave's Spawn budget not exported: yes. **The `has_<field>` pairing is the one convention broken, on `recursive_interaction_guard` (R7).**

---

## 4. The Schema check: is it capable of failing?

Re-run by me: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd` → **exit 0**, 54 scripts loaded, 11 contracts PASS.

It is a **value-based** check, not an existence-based one, which is the correct answer to Phase 00's F-10. It compares every exported property against a freshly constructed `ClassName.new()` and flags equality, with a small explicit exceptions manifest. That is materially stronger than the check Phase 00 shipped.

Four falsification runs by me (samples backed up, mutated, run, restored, `md5sum -c` verified clean afterwards):

| # | Mutation | Expected | Actual |
| --- | --- | --- | --- |
| 1 | Deleted `magnet_radius_px = 211` from the player sample | fail | **exit 1** — `Player Definition.magnet_radius_px is at its default value: 0` |
| 2 | Deleted `proportion = 0.4` from the wave sample's **second** `EnemyIntentMixEntry`, so `enemy_intent_mix` sums to 0.6 instead of docs/20's required 1.0 | fail | **exit 0, PASS** — gap, see R4 |
| 3 | Appended `rogue_field_not_in_contract = 999` to the economy sample | fail | **exit 0, PASS**, no warning on either stream — gap, see R5 |
| 4 | Set `interval_seconds` to 0.0 at depth 3 (`wave → overtime_condition → finisher_spawn_rate`) | fail | **exit 1** — `Wave Definition.overtime_condition.finisher_spawn_rate.interval_seconds is at its default value: 0.0`; recursion works |

Plus the F01-08 reproduction (wrong resource class → exit 1 via the null assertion, no engine diagnostic).

**Could it pass on a broken project? Yes, in one structurally important way.** `_exported_properties()` enumerates `instance.get_property_list()` filtered to `PROPERTY_USAGE_SCRIPT_VARIABLE` — i.e. it asks the *script* what fields exist. `tests/schema_check.gd` contains no manifest of MASTER's required field names anywhere: the only field-name string literals in the whole file are the three exception tables (`band_label`, `has_band_label`, `max_rank`, `has_max_rank`, `maximum_duration_seconds`, `has_maximum_duration`, `hurtbox_definition`, `partial_reward_rules`, `directional_weighting_override`, `direction_weighting_override`) plus three contract-specific assertions. So if a required field were never added to a schema in the first place, it disappears from the script *and* from the sample simultaneously, and the check reports PASS. It enforces "no field the schema declares is left at its default"; MASTER's criterion is "no missing required field". Those are not the same property. This is R1, and it is why this review's field-by-field pass in § 3 — not the green run — is the actual evidence that no required field is missing. (I did not mutate a script to demonstrate this, because editing `src/data/` was outside my permitted write scope; the code path is unambiguous on reading and the grep above is the supporting evidence.)

---

## 5. Findings

### R1 — Major. The Schema check cannot detect a required field the schema never declared.
Evidence: § 4. The phase's own top predetermined risk row lists detection as "Critical agent cross-checks every `@export` … ; Schema check failing to load or validate a sample with a type-mismatched field" — but the check performs **no type comparison against docs/20 at all**, and cannot see an omission. The detection column overstates the instrument. The eleven schemas are in fact complete and correctly typed today (§ 3), so this is a durability defect rather than a present-state one: nothing stops a Phase 02 edit from dropping a field and leaving the check green. Suggested fix: a per-contract `const REQUIRED_FIELDS` manifest transcribed from MASTER § Content Data Contracts, asserted against the property list before the value walk.

### R2 — Major. `MergeRule.match_radius_px` duplicates a Register-owned number that docs/20 types as a reference, and the shipped samples already disagree.
docs/20 types Pickup's Merge rule sub-field as "match radius: **reference to** Economy Configuration's Merge radius field". `merge_rule.gd` exports it as an independent `int` and its own header says "this schema does not enforce that the two values match". Concrete evidence of immediate drift: `economy_configuration_sample.tres` sets `merge_radius_px = 71` while `pickup_definition_sample.tres` sets `match_radius_px = 64`. The merge radius is a Register/Economy-owned number (MASTER line 1401: "Economy Configuration, default 64 px; 128 px at Fallback Ladder step 1"), and CLAUDE.md requires every other place to reference it. A per-pickup copy also means the Fallback Ladder's documented 64→128 escalation cannot reach it at runtime. Fix: type it as an `EconomyConfiguration` reference, or drop the field and resolve it from the Economy Configuration at runtime.

### R3 — Minor. `MergeRule` drops two of docs/20's four named sub-fields into a header comment.
`trigger` and `resulting behaviour` are absent from the schema while the structurally identical `HopperConversionRule.trigger` is exported as a `String`. Adjudicated in § 2 item 5: export both as Strings, matching the `HopperConversionRule` treatment, so the fixed values live where a `.tres` diff can show them changing. A value documented only in a `.gd` comment is invisible to every check and to content review.

### R4 — Minor. Only element `[0]` of a typed Resource array is validated.
Falsification 2: blanking the **second** `EnemyIntentMixEntry.proportion` leaves the wave's intent mix summing to 0.6 against docs/20's explicit "proportion: float 0–1 **summing to 1**", and the check is green at exit 0. Self-disclosed in the report's honesty notes, and the disclosed rationale ("MASTER's field list is about the Wave *having* an intent mix") does not cover an array that is present but whose later entries are blank. Fix: recurse into every element; the arrays are small.

### R5 — Minor. A rogue undeclared key in a `.tres` is silently accepted by both engine and check.
Falsification 3: exit 0, no warning anywhere. PLAN Carried Lesson 1 named this case in advance ("test the something-extra-was-added case, not only the something-is-missing case"), precisely because Phase 00's defect was an existence-only assertion. The implementer ran it, reported the exit 0 honestly, and argued it out of scope. Adjudicated in § 2 item 9: the argument is reasonable but the conclusion should be "known limitation, owner named" rather than "resolved". Once real content exists, a stale key surviving a schema rename is the ordinary way drift happens, and nothing in the toolchain will report it.

### R6 — Minor. A MASTER-required field is absent from a sample and exempted from the check by name.
`player_definition_sample.tres` contains no `hurtbox_definition` line at all, and `SKIP_ALWAYS` guarantees nothing about it. The reasoning (single-member enum `{SameAsBody}`; no non-default value exists) is sound as far as it goes, but the file should still carry the line so the field's presence is auditable in the artifact, and the check should assert the key's presence in the parsed `.tres` text rather than skipping the property. As written, the one required field that cannot be value-checked is also the one field whose absence from the file no one will notice.

### R7 — Minor. A convention fixed in advance was re-chosen, in the one place where the substitute reintroduces the ambiguity the convention prevents.
`recursive_interaction_guard` is docs/20-typed "enum/string, **nullable**". The `has_<field>` pairing was fixed before the task (PLAN step 7; EXECUTION_LOG line 20) and is applied correctly to `max_rank`, `maximum_duration_seconds` and `band_label`. Here an empty-string sentinel was used instead, and `""` is also the export's default — so "no guard, deliberately" and "never filled in" are the same bytes. MASTER's rule for this contract ("No upgrade may be implemented if it can trigger unbounded recursion without a defined guard") is exactly the rule that needs to tell those apart. Ruling in § 2 item 1: add `has_recursive_interaction_guard: bool`.

### R8 — Minor. A contract's field list was extended without a Review Decision Log row.
`XpLevelCost` adds `base_cost` and `per_level_increment`, which docs/20's Economy table does not name. I uphold the substance (§ 2 item 4: the constants are a Provisional Default in the Register and must stay tunable as data). CLAUDE.md nonetheless requires a Decision Log row naming the alternative for a design change of this kind; `p06_report.md` writes both alternatives up properly, so the row is nearly drafted already, but MASTER's Review Decision Log ends at D87 and carries nothing for it. docs/20's Economy table should name the two sub-fields in the same pass.

### R9 — Minor. The check's exception tables are keyed by bare field name, not by class, and one entry will start failing correct content at the vertical slice.
`NULLABLE_PRIMITIVE_PAIRS["band_label"]` hard-codes `expect_set: false`, so **no** sample anywhere may ever demonstrate a populated band label. docs/20 states in terms that Band label is "null in the prototype, **populated by document 12 with its scaling curves from the vertical slice onward**". The moment that happens, a correct sample fails this check. The same name-keying applies to `hurtbox_definition`, `partial_reward_rules` and `direction_weighting_override`: any future class that reuses one of those names inherits the exemption silently. Fix: key the tables on `ClassName.field`.

### R10 — Minor. The eleven PLACEHOLDER sample fixtures ship in every release build.
`export_presets.cfg`: `export_filter="all_resources"`, `exclude_filter="addons/gdUnit4/*, tests/*, reports/*"`. `src/data/samples/` is not excluded. Same class as Phase 00 F-05 and this phase's F01-05; the F01-05 fix landed the same day the samples were created and swept the test surface but not the schema fixtures. Small in bytes (~20 KB), but "everything under the Godot project root is a resource" is a lesson this project has now paid for twice, and validation fixtures with `PLACEHOLDER_` values are not content. See the F01-05 row in § 1.

### R11 — Minor. No value-domain constraint stated in docs/20 prose is enforced.
`entity_cap_weight` is "integer ≥ 1" and its schema default is **0**, a value docs/20 forbids — nothing rejects 0 or a negative. Likewise `priority` "0 to 100", `elite_chance` and `proportion` "0 to 1" (and "summing to 1"), `draft_weight` "≥ 0", `health_quadrant_threshold` "fraction". Self-disclosed in the honesty notes and explicitly handed to the reviewer. **Ruling: at minimum assert the two cases whose schema default is itself an invalid value (`entity_cap_weight ≥ 1`, `draft_weight ≥ 0`), because there the default silently encodes an illegal state; the tuning ranges can wait for a later harness task.**

### R12 — Minor, and this one goes to the author. An ambiguity the implementer did not flag.
docs/20 types Encounter's "Telegraph requirements" as "list of Telegraph data references | Which telegraphs, **with lead time**, this encounter must schedule before any on-screen spawn". `TelegraphData` carries wind-up duration, shape, colour and audio cue ID — no lead time — and lead times otherwise live on the Director's `MarkerLeadTimes` (off-screen / on-screen minimum). So the per-encounter lead time docs/20's meaning column names has nowhere to live in the schema as typed. Either the phrase means the Director's global lead times and should be struck from that row, or `TelegraphData` needs a lead-time field and every telegraph gains one. This changes a contract's field list, so it is the author's call, not mine.

### R13 — Observation, no action. Sample placeholder quality.
Mostly well done: distinctive non-round values (733, 487, 113, 337.5, 0.42, 17.5) and `PLACEHOLDER_*` strings throughout, so "set" and "unset" are visibly different almost everywhere. Two exceptions worth knowing about: `merge_rule.match_radius_px = 64` is the Register's *real* default merge radius, so it reads as content rather than as a placeholder (and see R2); and `BandedValue.band_label`/`has_band_label` sit at type defaults in all three uses — correct per docs/20's "null in the prototype", but it means the set state of a nullable enum is demonstrated nowhere in the fixture set (and R9 forbids ever demonstrating it).

**Count: 13 findings — 2 Major, 10 Minor, 1 observation.** No Blocker. Items 4 and R12 need the author; the rest are within a following task's reach.

---

## 6. What was done well

Worth recording, because a critical review that only lists defects misrepresents the artifact:

- **Field-by-field conformance is genuinely exact.** Across eleven contracts and 42 struct resources I found zero missing required fields, zero unrequired contract-level fields, and two documented extra sub-fields whose substance I upheld. The phase's number-one predetermined risk did not materialise.
- **All 28 enums are exact, in order, with no convenience members,** including the two same-sounding "target" enums that would have been easy to conflate.
- **Every shared struct is typed once,** verified by name-uniqueness and by call site; `DropTable` and `Reward` correctly kept distinct; `PressureMetricConstants` and `DirectionalWeightingEntry` genuinely reused across contracts rather than copied.
- **The check is a value comparison against a fresh instance,** not an existence assertion — the direct lesson of Phase 00's F-10 was applied, and it holds up: it caught a defaulted inherited field, a defaulted field at nesting depth 3, a null-on-required, and a silently-nulled wrong-class reference.
- **The report is honest in a way that made this review harder, not easier.** It disclosed both gaps I independently falsified (array element `[1..n]`, rogue field) before I found them, reported a falsification that came back exit 0 rather than quietly dropping it, flagged nine ambiguities instead of resolving them silently, and closes by saying its own field-to-type table has not been independently cross-checked. That is the behaviour this project's rules ask for, and it is rarer than it should be.
- **F01-08 was found by experiment, not by reasoning** — the exact failure Phase 00's F-08 taught, avoided.

---

## 7. Score

# 8 / 10

The primary deliverable — eleven typed schemas that conform, field by field, to two documents that do not agree with each other in three places — is essentially clean under an exhaustive check, and the conventions fixed in advance were followed in every case but one. The acceptance instrument is materially better than the one Phase 00 shipped and I made it fail correctly twice.

The two points come off for:

1. **R1 (Major)** — the check's blind spot to a field that was never declared. The task's own named acceptance test cannot verify the criterion it is named for ("no missing required field"), and the phase's top-risk row claims a detection capability the check does not have. That the schemas are nonetheless complete is established by this review's manual pass, not by the instrument, which is the same gap in kind — if not in degree — that Phase 00 was marked down for.
2. **R2 (Major)** — a Register-owned number typed as a per-instance copy where docs/20 says "reference", with the two shipped samples already carrying different values (71 vs 64) on the day they were written. Small in code, but it is the precise thing CLAUDE.md's single-source rule exists to prevent, and the fixture set demonstrates the drift rather than guarding against it.

Plus the aggregate weight of R3–R12: a convention re-chosen without authority in the one spot where the substitute collides with the default (R7), a required field missing from a sample (R6), an exception table that will fail correct content at the vertical slice (R9), a contract field list extended without the Decision Log row CLAUDE.md requires (R8), and placeholder fixtures shipping in release builds (R10).

None of this is a Blocker and none of it invalidates the schemas. Whether this clears the task bar, and whether the phase gate is met, is for the phase reviewer and the author to decide.

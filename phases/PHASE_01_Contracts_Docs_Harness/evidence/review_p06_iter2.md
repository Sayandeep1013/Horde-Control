# P0.6 Critical Agent Review — iteration 2

Reviewer: P0.6 critical agent (Opus), review iteration 2. Date: 2026-09-18. Blind to how the fixes were made; `evidence/p06_fixes.md` was read as a **claim** and every claim in it that bears on a disposition was re-tested independently, on different contracts and different fields from the ones it used.

Scope: adjudicate iteration 1's two Majors (**F01-15**, **F01-16**) and its seven rulings (R3, R4, R7, R9, R11 to implement; R5, R6 deliberately not), sweep for regressions, and re-score P0.6.

This review does not state that any gate is passed, satisfied, met, or ready. That is the author's decision.

**Work done beyond reading.** Fourteen Godot runs: one baseline, one final, and twelve mutation runs. Every mutation was `cp`'d aside first, applied to the original, run, and restored, with restoration verified by `diff` **and** by `git status --porcelain --untracked-files=all` returning empty against the committed tree — a stronger check than `diff` alone, because it also proves no other file moved. The working tree at the end of this review is byte-identical to `HEAD` (`5a8e7a4`). Nothing was deleted, no export was run, no `mcp__godot-*` tool was used, and the only file this review wrote is this one.

---

## 1. Dispositions at a glance

| Item | Disposition |
| --- | --- |
| **F01-15** (Major) — check blind to an undeclared required field | **Closed at the contract level, with a demonstrated residual one level down.** See § 2. |
| **F01-16** (Major) — `MergeRule.match_radius_px` duplicated a Register-owned number | **Closed.** Verified by execution, not by reading. See § 3. |
| R3 — `MergeRule` sub-fields comment-only | **Closed as ruled** |
| R4 — only array element `[0]` validated | **Closed as ruled**, independently falsified on a different field |
| R7 — `recursive_interaction_guard` null sentinel | **Closed as ruled**, and the new pair is enforced |
| R9 — exception tables keyed by bare field name | **Closed as ruled**, both halves verified by doing |
| R11 — no value-domain enforcement | **Closed above the ruled minimum**; the "fraction" judgment call is defensible and was flagged, not hidden |
| R5 — rogue undeclared `.tres` key | **Correctly not changed**; recorded behaviour re-verified to match actual behaviour |
| R6 — `hurtbox_definition` absent from the sample | **Correctly not changed**; state re-verified |
| Regression sweep | **No regression found.** Exit 0, 11 contracts, 54 scripts, zero missing and zero unrequired fields, 28 exact enums, 54 unique `class_name`s, D90's new field correctly typed, populated and recorded |

**New findings: 4 Minor, 3 observations.** No Blocker. Details in § 7.

---

## 2. F01-15 — the required-field manifest

### 2.1 Does it fail when it should? Four independent falsifications

The claim under test is that `REQUIRED_FIELD_MANIFEST` in `tests/schema_check.gd` is hand-written from MASTER's contract bullets and independent of the scripts, so a required `@export` deleted from a schema is caught even though it vanishes from the sample at the same instant. The fix implementer demonstrated this on `EnemyDefinition.entity_cap_weight` and `UpgradeDefinition.effect_description`; the orchestrator used `PlayerDefinition.magnet_radius_px`. I used **four different targets on four different contracts**, including the one derived field.

**Falsification 1 — `DirectorConfiguration.health_quadrant_threshold`** (the last bullet of MASTER's Director contract), deleted from `src/data/director_configuration.gd` *and* from `src/data/samples/director_configuration_sample.tres`:

```
$ sed -i '/^@export var health_quadrant_threshold/d' src/data/director_configuration.gd
$ sed -i '/^health_quadrant_threshold = /d' src/data/samples/director_configuration_sample.tres
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
  Director Configuration: FAIL (1 problem(s))
Schema check FAILURE: Director Configuration: MASTER field "Health quadrant threshold." has no matching @export "health_quadrant_threshold" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check: FAIL (1 problem(s) across 11 contract(s))
EXIT=1
```
Restored; `diff` clean on both files; `git status` empty.

**Falsifications 2 and 3 — `WeaponDefinition.coverage_shape` and `PickupDefinition.lifetime_seconds`**, each deleted from its script and its sample in the same run:

```
  Weapon and Evolution Definition: FAIL (1 problem(s))
  Pickup Definition: FAIL (1 problem(s))
Schema check FAILURE: Weapon and Evolution Definition: MASTER field "Coverage shape (cone, line, radius, single target)." has no matching @export "coverage_shape" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check FAILURE: Pickup Definition: MASTER field "Lifetime in simulation seconds." has no matching @export "lifetime_seconds" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check: FAIL (2 problem(s) across 11 contract(s))
EXIT=1
```
Restored; `git status` empty.

**Falsification 4 — the derived field.** MASTER's Wave contract has one bullet docs/20 forbids being an `@export` (Spawn budget). The manifest asserts it by method presence. Renaming the method:

```
$ sed -i 's/^func get_spawn_budget(/func get_spawn_budget_RENAMED(/' src/data/wave_definition.gd
Schema check FAILURE: Wave Definition: MASTER field "Spawn budget (derived: sum of its spawn groups' cap weights)." (derived) has no method get_spawn_budget() on the schema
EXIT=1
```
Restored; `git status` empty.

The mechanism works, on contracts and a field class the implementer did not use, and the message names the MASTER bullet and the missing export by name.

### 2.2 Is the manifest complete and correct?

I listed MASTER's bullets for all eleven contracts from `MASTER_SDLC.md` § Content Data Contracts (lines 2183–2454) and diffed them entry by entry against the manifest, then cross-checked both against the actual `@export` list of every contract script (with `UpgradeDefinition`'s inherited exports folded into `TowerUpgradeDefinition`, as the check does).

| Contract | MASTER bullets | Manifest entries | Script exports | Manifest names absent from script | Exports absent from manifest |
| --- | --- | --- | --- | --- | --- |
| Enemy Definition | 15 | 15 | 15 | none | none |
| Encounter Definition | 20 | 20 | 20 | none | none |
| Upgrade Definition | 13 | 13 → 15 exports | 15 | none | none |
| Wave Definition | 12 | 13 → 13 exports + 1 method | 13 | none | none |
| Tower Definition | 9 | 9 | 9 | none | none |
| Tower Upgrade Definition | 13 inherited + 2 | 15 → 17 exports | 17 | none | none |
| Weapon and Evolution | 9 | 9 | 9 | none | none |
| Pickup Definition | 6 | 6 → 7 exports | 7 | none | none |
| Player Definition | 11 | 11 | 11 | none | none |
| Director Configuration | 15 | 15 | 15 | none | none |
| Economy Configuration | 11 | 11 | 11 | none | none |

The last two columns were computed mechanically (parsing the manifest out of `tests/schema_check.gd` and the `@export var` lines out of `src/data/*.gd`), not eyeballed. **Every contract is a perfect one-to-one: no manifest entry names an export that does not exist, and no export exists that the manifest does not name.** Since I derived the left-hand column from MASTER by hand, that is simultaneously the "zero missing required fields" and "zero unrequired extras" result iteration 1 established, re-confirmed on the edited tree.

Bullet-to-export splits the manifest records as data rather than assuming silently, all of which I verified against MASTER's wording:

- Wave's single bullet `Maximum duration (nullable; null for boss waves) and target duration.` → two entries (`maximum_duration_seconds` + `has_maximum_duration`; `target_duration_seconds`). This is why Wave shows 12 bullets against 13 entries.
- Pickup's `Unique ID and type (…)` → `["unique_id", "pickup_type"]`.
- The three nullable-primitive pairs each list both halves.
- `Tower Upgrade Definition` is written as `UPGRADE_DEFINITION_REQUIRED_FIELDS + [2]` rather than retyped, so a field deleted from `UpgradeDefinition` fails under both contract names — which falsification 2 of the implementer's own log shows, and which the reuse makes structurally true rather than coincidental.
- MASTER's "Pool ownership set to Tower" is correctly kept out of the manifest (it is a value constraint) and asserted in the contract-specific block instead.

Bullet texts are verbatim or, where the header says "lightly paraphrased", faithfully shortened — e.g. Encounter's `Reward (Reward struct; zero for the four prototype encounters).` is carried as `"Reward."`, and Weapon's last bullet drops `, per Weapon Evolution Philosophy`. Neither changes what is asserted.

**Verdict: the manifest is complete and correct for the surface it covers.** It does not silently omit a contract-level field.

### 2.3 The residual: the manifest stops at the contract level

MASTER's bullets are frequently **compound**, naming two or more quantities that the schema realises as sub-fields of one struct: `Maximum health and base shield fraction`, `Shield regeneration rate and delay`, `Footprint radius and Interaction Radius`, `XP shard value and level cost formula`, `Spawn validation retry steps and angle increment`, `Targeting rule parameters (range, intent preference)`, `Projectile definition (speed, lifetime, pooling class)`, `Overtime condition (stall threshold and finisher definition)`, `Hopper-to-Core conversion rate and trigger`, `Dominance audit threshold and sample size`, and more. For each of these the manifest asserts only that the **wrapper export** exists. The 42 struct resources' interiors are unprotected, and that is exactly F01-15's defect one level down.

Demonstrated twice, on quantities MASTER's own bullet text names:

**Probe A — `XpLevelCost.shard_value`** (MASTER: "XP shard value and level cost formula"), deleted from `src/data/xp_level_cost.gd` and from `economy_configuration_sample.tres`:
```
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```

**Probe B — `TowerFootprint.interaction_radius_px`** (MASTER: "Footprint radius and Interaction Radius"), deleted from `src/data/tower_footprint.gd` and from `tower_definition_sample.tres`:
```
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```

Both restored; `git status` empty after each. This is the same failure mode iteration 1 scored Major — the field disappears from script and sample at the same instant and the value walk stays green — narrowed to the struct interiors. Raised as **N1**.

### 2.4 The second half of F01-15's own text is untouched

F01-15 as worded in `LEDGER.md` has two sentences: the presence blindness, **and** "It also performs no type comparison against docs/20, though the phase's own top-risk row lists it as a type-mismatch detector." The resolution column addresses only the first, and the row's status reads `fixed` without distinguishing them.

**Probe C** — retyped `PickupDefinition.value` from `int` (docs/20: "Value | integer") to `float`, leaving the sample's `value = 17` in place:
```
$ sed -i 's/^@export var value: int = 0/@export var value: float = 0.0/' src/data/pickup_definition.gd
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
Restored; `git status` empty. Raised as **N2**. In fairness: the *sample*-side type-mismatch case the risk row describes **is** covered, by the null assertion F01-08 documents, so the risk row is not as wrong as it reads. What is not covered is a schema drifting from docs/20's stated type.

---

## 3. F01-16 — `MergeRule.match_radius_px`

**Gone from the schema.** `src/data/merge_rule.gd` now exports `trigger`, `same_type_only`, `resulting_behaviour` only, and carries `func get_match_radius_px(economy: EconomyConfiguration) -> int: return economy.merge_radius_px`.

**Gone from the samples.** `pickup_definition_sample.tres`'s `merge_rule` sub-resource sets `trigger`, `same_type_only`, `resulting_behaviour` and nothing else. A repo-wide grep for `match_radius_px` finds it only in `merge_rule.gd`'s doc comment and method name. The only merge-radius value authored anywhere in the sample set is `economy_configuration_sample.tres`'s `merge_radius_px = 71`. The 71-versus-64 drift is structurally impossible, not merely corrected.

**The method actually resolves.** Verified by running it, not by reading it. I copied `tests/schema_check.gd` aside, injected a probe into `_init()`, ran, and restored (`diff` clean, `git status` empty):

```
PROBE economy.merge_radius_px = 71
PROBE pickup.merge_rule.get_match_radius_px(economy) = 71
PROBE merge_rule has match_radius_px property = false
PROBE after Fallback-Ladder escalation to 128: 128
```

The last line is the part that matters beyond the drift: R2's second complaint was that a per-pickup copy puts the value beyond the documented Fallback Ladder escalation that raises Merge radius from 64 to 128 px at runtime. Mutating the Economy Configuration's field at runtime now changes what the pickup resolves, which is the behaviour docs/20's "reference to Economy Configuration's Merge radius field" describes.

**Nothing else in `src/data/` duplicates a Register-owned number the same way.** I grepped docs/20's Contract Field Semantics (lines 138–375) for every field typed as a reference to, derived from, or resolving from another field:

| docs/20 wording | In scope? | How the schema types it | Verdict |
| --- | --- | --- | --- |
| Merge rule → `match radius: reference to Economy Configuration's Merge radius field` | yes | method, no export | fixed |
| Spawn budget → `Derived …; not authored` | yes | `get_spawn_budget()`, no export | correct |
| Spawn group → `direction weighting override: nullable reference to the encounter's Directional Weighting rule` | yes | nullable `DirectionalWeightingEntry` Resource | correct — a Godot Resource handle *is* a reference; no number is copied |
| Base weapon / Starting weapon reference → `Weapon Definition Unique ID` | yes | `String` ID | correct |
| Transition cleanup rule → `reference to the Biome Transition persistence rules` | no (Biome) | untyped | out of scope |
| Hazard cleanup schedule → `reference` | no (Boss) | untyped | out of scope |
| Console price per rank → `integer Scrap … following the Economy Configuration's Console price formula`, and the Economy row: "The multiplier every prototype upgrade's Console price per rank **resolves from**" | yes | independently authored `int` | **nearest surviving analogue — N3** |

`console_price_per_rank` is genuinely weaker than F01-16: docs/20 types it `integer Scrap`, not "reference to", and the per-rank price is a product (`scrap_per_rank × rank`) rather than a straight copy, so a per-upgrade export is not simply a duplicated number. The samples also carry unambiguous placeholders (47, 63 against the Economy's 19), so unlike 71-vs-64 there is no demonstrated drift. But "resolves from" is the same word docs/20 uses for a derivation, and nothing anywhere cross-checks the two. Raised as **N3**, Minor, for a later pass or the author — not as a repeat of F01-16.

**Disposition: F01-16 closed.**

---

## 4. The seven rulings

### R3 — `MergeRule.trigger` and `resulting_behaviour` (ruled: export as Strings, matching `HopperConversionRule`) — **closed**
Both are now `@export var … : String = ""` on `merge_rule.gd`, and `pickup_definition_sample.tres` populates both (`PLACEHOLDER_trigger_at_pickup_cap`, `PLACEHOLDER_behaviour_merge_into_nearest_same_type_else_expire_oldest`). They are `String`, not a one-member enum, which is what § 2 item 3 of iteration 1 required. The value walk covers them, so a `.tres` that drops either fails.

### R4 — recurse into every array element (ruled: recurse; the arrays are small) — **closed**
The `TYPE_ARRAY` branch loops `for i in range(arr.size())`. Verified independently of the implementer's own test, which used `enemy_intent_mix[1].proportion` — I blanked a **different field** on the same non-first element so the R11 sum-to-1 rule could not be the thing catching it:

```
$ sed -i '17s/^target_intent = 2$/target_intent = 0/' src/data/samples/wave_definition_sample.tres
Schema check FAILURE: Wave Definition.enemy_intent_mix[1].target_intent is at its default value: 0
EXIT=1
```
Element `[1]` is named explicitly. Restored; `git status` empty.

Caveat, not a defect — see **N4**: `enemy_intent_mix` (2 entries) is the **only** Resource array in the entire fixture set with more than one element. Every other typed Resource array in all eleven samples holds exactly one. The fix is correct; the fixtures exercise it in one place.

### R7 — `has_recursive_interaction_guard` (ruled: add the flag, per the convention as written) — **closed**
`upgrade_definition.gd` declares `recursive_interaction_guard: String` immediately followed by `has_recursive_interaction_guard: bool = false`, with the doc comment rewritten to describe the pairing rather than the old empty-string sentinel. Both upgrade samples set the flag true. `NULLABLE_PRIMITIVE_PAIRS` carries `"UpgradeDefinition.recursive_interaction_guard"` in `require_set` mode, and the flag half is derived from that table by `_is_nullable_pair_flag()` rather than kept in a second hand-maintained list — which removes the class of bug where a new pair is added to one list and forgotten in the other.

Verified it is enforced, not merely declared:
```
$ sed -i 's/^has_recursive_interaction_guard = true$/has_recursive_interaction_guard = false/' src/data/samples/upgrade_definition_sample.tres
Schema check FAILURE: Upgrade Definition.recursive_interaction_guard: expected has_recursive_interaction_guard to be true (this project's samples must demonstrate the set state), got false
EXIT=1
```
"No guard, deliberately" and "never filled in" are now different bytes, which is what MASTER's recursion rule needs.

### R9 — key exceptions on `ClassName.field`, so a populated band label can never fail — **closed, both halves verified by doing**

All three exception tables and `DOMAIN_CONSTRAINTS` are keyed `"ClassName.field"`, resolved at validation time from `script.get_global_name()`, with an explicit failure if a script has no `class_name`.

**Half 1 — a populated band label must pass.** This is the specific scenario R9 named ("the moment document 12 populates band labels at the vertical slice, a correct sample fails this check"). I populated one on the enemy sample's `health_band` sub-resource:
```
$ # added to Resource_e3w2q:  band_label = 2   /   has_band_label = true
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
And the discriminating negative — claimed set but left at its default, which *is* an authoring bug:
```
$ # band_label = 0 with has_band_label = true
Schema check FAILURE: Enemy Definition.health_band.band_label is at its default value (0) while has_band_label is true
EXIT=1
```
Both restored; `git status` empty. `"optional"` mode behaves as specified: never fails on a populated value, fails only on a false claim.

**Half 2 — the exemption must not leak to another class.** This is the durability half of R9 and the implementer did not test it. I appended `hurtbox_definition` and `band_label` exports to `tower_definition.gd`, where neither is exempted:
```
Schema check FAILURE: Tower Definition.hurtbox_definition is at its default value: 0
Schema check FAILURE: Tower Definition.band_label is at its default value: 0
EXIT=1
```
Under the old bare-field-name keys both would have been silently exempted. Restored; `git status` empty.

### R11 — domain assertions for the domains docs/20 actually states, and no invented ones — **closed, above the ruled minimum**

R11's stated minimum was two assertions (`entity_cap_weight ≥ 1`, `draft_weight ≥ 0`). Six landed. I re-derived the list independently by grepping docs/20 lines 138–375 for every stated numeric domain on an in-scope contract:

| docs/20 statement | Covered? |
| --- | --- |
| `Entity cap weight \| integer ≥ 1` | yes — `EnemyDefinition.entity_cap_weight` min 1 |
| `Priority \| integer 0 to 100` | yes — on **both** users, `EncounterDefinition.priority` and `EncounterPriorityEntry.priority` |
| `Elite chance \| float 0 to 1` | yes |
| `proportion: float 0–1 summing to 1` | yes — per-element 0–1 **and** the whole-array sum, the latter in the Wave contract-specific block with float tolerance |
| `Draft weight \| integer ≥ 0` | yes |
| `list of 4 integers` (evolution stage thresholds) | yes — pre-existing size assert |
| `length ≥ 1` (evolution change axes) | yes — pre-existing size assert |

**Nothing is bounded that docs/20 does not bound.** I checked the converse too: no constraint exists for `Pressure target` (float, no range), `Console price per rank`, `Maximum rank`, `heavy share`, `hunt arc share`, `lane width degrees`, `rate: float % per second`, or `rate: integer:1` — none of which docs/20 gives a range for. Both halves of the ruling hold.

Four fire correctly, including one on a nested struct keyed by its own class:
```
Schema check FAILURE: Enemy Definition.entity_cap_weight is -2, outside docs/20's stated domain (minimum 1)
Schema check FAILURE: Encounter Definition.priority is 150, outside docs/20's stated domain (maximum 100)
Schema check FAILURE: Wave Definition.elite_chance is 1.7, outside docs/20's stated domain (maximum 1.0)
Schema check FAILURE: Director Configuration.encounter_priority_table[0].priority is 200, outside docs/20's stated domain (maximum 100)
```
All restored; `git status` empty after each.

**On the "fraction" judgment call.** The implementer declined to bound `health_quadrant_threshold`, `MaxHealthAndShieldFraction`'s base shield fraction, `SiegeVolumeConstants.hunter_percentage` and `spawn_window_fraction`, on the ground that docs/20 names "fraction" as a type rather than stating a range, and flagged the call in § 5 of its own write-up rather than deciding it silently. **I judge this reasonable and would have ruled the same way.** The ruling's words were "the domains docs/20 actually states"; docs/20 writes `float fraction` in the Type column, which is a type name, and writes `float 0 to 1` when it means a range — the document itself distinguishes them, twice, in the same tables. Adding 0–1 bounds to the fraction-typed fields would also be defensible and is a reasonable follow-on, but choosing not to invent them is within the ruling, and flagging it is the behaviour this project asks for.

### R5 — rogue undeclared `.tres` key (ruled: known limitation with an owner, **no code change**) — **correctly not changed, and the record matches reality**
Re-tested, because a recorded limitation is only useful if it is still true:
```
$ printf 'rogue_field_not_in_contract = 999\n' >> src/data/samples/economy_configuration_sample.tres
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
No warning on either stream, from engine or check. Unchanged, as ruled, and `LEDGER.md` F01-17 records it as one of the two deliberately-unfixed items. Restored; `git status` empty.

### R6 — `hurtbox_definition` absent from the player sample (ruled: **no code change** this pass) — **correctly not changed**
`grep -c hurtbox_definition src/data/samples/player_definition_sample.tres` → `0`. The exemption survives, now class-qualified as `"PlayerDefinition.hurtbox_definition"`, so at least it can no longer silently cover an unrelated class (proved in R9 half 2). The underlying finding — the one required field that cannot be value-checked is also the one whose absence from the file nobody will notice — is unchanged and remains recorded.

---

## 5. Regression sweep

**Baseline and final run** (identical, first and last actions of this review):
```
Pass 1 (script load): PASS (54 scripts under src/data/ loaded and instantiated with zero errors)
  Enemy Definition: PASS … Economy Configuration: PASS   [11 of 11]
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```

**Conformance re-confirmed on the edited tree**, since schemas and samples changed since iteration 1:
- **Zero missing, zero unrequired** — the mechanical export-vs-manifest table in § 2.2, all eleven contracts one-to-one, computed rather than eyeballed.
- **28 enums, exact.** `src/data/contract_enums.gd` declares exactly 28. `TargetIntent` is the six members docs/20 lists, in order; `EncounterType` is all sixteen, in order; the remaining 26 match their docs/20 member lists. Grep for `NONE|UNSET|INVALID|MAX|Unset|Invalid|Unknown` finds nothing outside a comment saying none were added. The two same-sounding target enums remain distinct (`UpgradeEffectTarget {Player, Tower, PlayerWeapon, TowerWeapon}` vs `EffectStructTarget {Player, Tower, Enemy}`).
- **No shared struct typed twice.** 54 `class_name` declarations, 54 distinct (`grep -h "^class_name" src/data/*.gd | sort | uniq -d` → nothing). The script count is still 54, so no class was added or split by the fix pass; `MergeRule` lost an export and gained a method rather than being duplicated.
- **No bare `Array`/`Dictionary` export** anywhere in the 54 scripts.

**Decision D90's new field, `TelegraphData.lead_time_seconds`** — checked on all four counts asked:
- *Typed correctly*: `@export var lead_time_seconds: float = 0.0` against docs/20 line 165, "lead time: float seconds". ✓
- *Populated in the samples that use it*: `TelegraphData` has exactly two consumers, `EnemyDefinition.telegraph_data` and `EncounterDefinition.telegraph_requirements`. `enemy_definition_sample.tres` sets `0.85`; `encounter_definition_sample.tres` sets `1.35`. Both distinct from `windup_duration_seconds` (`0.65`, `0.4`), so the two quantities are visibly different in the fixture rather than accidentally equal. ✓
- *Actually under the check*: blanking it fails — `Enemy Definition.telegraph_data.lead_time_seconds is at its default value: 0.0`, exit 1. Restored; `git status` empty. ✓
- *Recorded*: docs/20 line 165 carries the field and the wind-up/lead-time distinction; `MASTER_SDLC.md` carries the D90 Decision Log row with its alternative and reasoning, the 0.8.4 Change Log entry, and the `LEDGER.md` F01-09 row updated to say D90 settled R12. ✓

**Iteration 1's own R10** (placeholder fixtures shipping in release builds) is closed outside my brief: `export_presets.cfg` now reads `exclude_filter="addons/gdUnit4/*, tests/*, reports/*, src/data/samples/*"`, recorded as F01-20.

---

## 6. Falsification log — full index

Every run below was `cp`-backed-up first and restored after; restoration was verified by `diff` **and** by `git status --porcelain --untracked-files=all` returning empty.

| # | Mutation | Target of | Expected | Actual |
| --- | --- | --- | --- | --- |
| 0 | none (baseline) | regression | exit 0, 11 contracts | exit 0, 11 PASS, 54 scripts |
| 1 | delete `DirectorConfiguration.health_quadrant_threshold` from script + sample | F01-15 | fail | **exit 1**, manifest names the MASTER bullet |
| 2 | delete `WeaponDefinition.coverage_shape` from script + sample | F01-15 | fail | **exit 1**, manifest |
| 3 | delete `PickupDefinition.lifetime_seconds` from script + sample | F01-15 | fail | **exit 1**, manifest |
| 4 | rename `WaveDefinition.get_spawn_budget()` | F01-15 (derived field) | fail | **exit 1**, method assertion |
| 5 | delete `XpLevelCost.shard_value` from struct script + sample | F01-15 residual | fail | **exit 0, PASS** — gap, **N1** |
| 6 | delete `TowerFootprint.interaction_radius_px` from struct script + sample | F01-15 residual | fail | **exit 0, PASS** — gap, **N1** |
| 7 | retype `PickupDefinition.value` `int` → `float` | F01-15 type half | fail | **exit 0, PASS** — gap, **N2** |
| 8 | probe: call `get_match_radius_px()` against the Economy sample, then against a runtime 128 | F01-16 | 71, then 128 | **71, then 128**; `match_radius_px` property absent |
| 9 | populate `BandedValue.band_label = 2`, `has_band_label = true` | R9 half 1 | pass | **exit 0, PASS** |
| 10 | `band_label = 0` with `has_band_label = true` | R9 half 1 (negative) | fail | **exit 1**, named |
| 11 | add `hurtbox_definition` + `band_label` exports to `TowerDefinition` | R9 half 2 | fail on both | **exit 1**, both named — no leak |
| 12 | `has_recursive_interaction_guard = false` in the upgrade sample | R7 | fail | **exit 1**, named |
| 13 | `enemy_intent_mix[1].target_intent` → default; `entity_cap_weight = -2`; `priority = 150`; `elite_chance = 1.7` | R4 + R11 | 4 failures | **exit 1**, all four named individually |
| 14 | `encounter_priority_table[0].priority = 200` | R11 nested-class key | fail | **exit 1**, named with array index |
| 15 | append `rogue_field_not_in_contract = 999` to the economy sample | R5 (should be unchanged) | pass (known limit) | **exit 0, PASS**, silent — matches the record |
| 16 | none (final) | regression | exit 0, 11 contracts | exit 0, 11 PASS |

Final tree state: `git status --porcelain --untracked-files=all` → empty, against `HEAD` = `5a8e7a4`.

---

## 7. New findings

### N1 — Minor. The required-field manifest stops at the contract level, so F01-15's defect survives inside the struct types.
Evidence: § 2.3, falsifications 5 and 6. `XpLevelCost.shard_value` and `TowerFootprint.interaction_radius_px` are both named by MASTER's own bullet text ("XP shard value and level cost formula", "Footprint radius and Interaction Radius"); deleting either from its struct script **and** the sample leaves the check at exit 0, PASS. The manifest asserts only that the wrapper export exists. Roughly a dozen of MASTER's bullets are compound this way, across 42 struct resources. This is the same failure mode iteration 1 graded Major, narrowed to the struct interiors — the presence check is now genuine for all 145 contract-level exports and absent for the struct fields beneath them. Graded Minor rather than Major because the fix landed exactly as R1 ruled and the remaining surface is the smaller one, but it should be recorded against F01-15 rather than left implicit in a row marked `fixed`. Suggested direction: extend the manifest one level, keyed `"StructClassName"` → required sub-field names, transcribed from docs/20's struct type column the same way the contract level was transcribed from MASTER's bullets.

### N2 — Minor. F01-15's second sentence is unaddressed while the ledger row reads `fixed` without qualification.
`LEDGER.md` F01-15 states two defects: the presence blindness **and** "It also performs no type comparison against docs/20". Only the first is resolved. Evidence: falsification 7 — retyping `PickupDefinition.value` from `int` to `float`, against docs/20's `Value | integer`, leaves the check green. Mitigating: the *sample*-side type-mismatch case the phase's top-risk row actually describes **is** covered, by the null assertion documented in F01-08, so the instrument is not as blind as the sentence suggests; what is missing is detection of a schema drifting from docs/20's stated type. The fix here may simply be to split the ledger row, or to say the type half is deferred with an owner — the same treatment R5 got — rather than to write code.

### N3 — Minor. `UpgradeDefinition.console_price_per_rank` is the nearest surviving analogue of F01-16, and nothing cross-checks it.
docs/20's Economy table says its Console price formula is "The multiplier every prototype upgrade's Console price per rank **resolves from**", and its Upgrade table says the field follows that formula; the schema exports it as an independently authored `int`. Weaker than F01-16 — docs/20 types it `integer Scrap` rather than "reference to", the price is a product rather than a copy, and the samples carry unambiguous placeholders (47, 63 against the Economy's 19) so no drift is demonstrated. But the Register owns the number (Console price, 30 Scrap × rank, owner docs 14/17) and no check, method or comment ties the two together. For a later pass or the author; I am **not** calling this a repeat of F01-16.

### N4 — Observation. R4's every-element recursion is exercised by exactly one array in the whole fixture set.
`wave_definition_sample.tres`'s `enemy_intent_mix` (2 entries) is the only typed Resource array in all eleven samples with more than one element; the other eight hold exactly one. The fix is correct and I falsified it independently, but the fixtures demonstrate it once. Whoever writes the real content should give at least one more array two dissimilar entries so the recursion keeps being exercised.

### N5 — Observation. Two counts in iteration 1's conformance table are wrong and should not be carried forward.
That table records Director Configuration as 16 MASTER fields / 16 exports and Economy Configuration as 12 / 12. MASTER's bullet lists hold **15** and **11**, and the scripts declare **15** and **11**. The conclusion those rows support ("none missing, none extra") is correct and I re-confirmed it mechanically; only the arithmetic is off. Worth correcting if that table is reused as a baseline.

### N7 — Minor, outside P0.6 but noticed while re-reading the ledger. Two new iteration-2 rows sit outside the ledger table.
`LEDGER.md` changed on disk while this review was open. Rows `F01-29` and `F01-30` were added at **lines 4–5**, above the "Severities:" line and above the table header at line 11, separated from the table by two paragraphs and a blank line — so they render as their own detached, headerless table rather than as rows of the ledger. Their column *order* also differs from the header (`| ID | Finding | Severity | Raised by | Status | Evidence | Resolution |`): both put the evidence text in the Status position and the status word in the Evidence position. Verified with `awk` — all four rows are 7 columns, so a column count check alone would not catch it. This is the same defect class as F01-25, which iteration 1 raised against this very file, and loop rules (c) and (d) operate on the Status column. Not this review's to fix; recorded because it is live and mechanically checkable.

### N6 — Observation, outside P0.6. The tree moved under this review again.
`docs/28_AI_Development_Workflow.md` appeared as modified partway through my run and was then committed as `5a8e7a4` ("record gdUnit4 MIT licence, LEDGER F01-21") while this review was open. It touches no P0.6 artifact and changes none of my dispositions — every falsification above was re-verified against the tree as it stood — but F01-27 recorded exactly this pattern in iteration 1 and said the rule it argues for "applies to iteration 2". It recurred.

---

## 8. What was done well

- **The manifest is the real thing, not a gesture.** It is hand-written, one entry per MASTER bullet, independent of every script, and it records bullet-to-export splits as data rather than assuming them. I diffed all eleven contracts against MASTER by hand and computed the export correspondence mechanically: it is one-to-one everywhere, with nothing silently omitted at the level it covers. The `TowerUpgradeDefinition` entry reuses the `UpgradeDefinition` list rather than retyping it, which makes the inherited-field case structurally true instead of a coincidence that a later edit could break.
- **F01-16 was fixed by removal, not by reconciliation.** Setting the two samples to the same number would have "closed" the finding; deleting the authorable field made the drift impossible and restored the Fallback-Ladder behaviour, which I confirmed by running the method against a mutated Economy Configuration.
- **R9 was fixed better than it was ruled.** The ruling asked for class-and-field keys. The implementer also replaced a hard `expect_set: false` with an `"optional"` mode that still catches the genuine authoring bug (claimed set, left at default), and deleted the separately-maintained `NULLABLE_PRIMITIVE_FLAGS` list in favour of deriving it from the pairs table — removing a class of bug rather than an instance.
- **R11 exceeded its minimum and stopped where it should have.** Six bounds where two were required, the whole-array sum rule placed where it belongs, and nothing invented; the `"fraction"` judgment call was flagged in the write-up rather than decided silently, which is exactly the behaviour CLAUDE.md asks for.
- **The fix pass's own falsification log is accurate.** I re-tested its claims on different contracts and different fields and could not find one that did not hold. That is not the usual outcome.
- **The two rulings that said "do not fix" were not fixed.** R5 and R6 are unchanged, and the recorded limitation still describes the actual behaviour, which I re-verified rather than assumed. Resisting the urge to close a finding that was ruled open is worth noting.

---

## 9. Score

# 9 / 10

Both Majors were addressed with work I could verify by breaking it, on targets the fix pass had not used. F01-16 is closed outright — the duplicated number is gone from schema and samples, only one authored copy of the merge radius exists anywhere, and the replacement method resolves correctly and tracks the runtime escalation docs/20 describes. F01-15's presence half is closed: the manifest fails on a deleted `@export` across four contracts I chose and on the one derived field, and it is complete and correct against MASTER's bullets, one-to-one with every export on all eleven contracts. All five rulings marked for implementation landed, three of them beyond the letter of the ruling, and the two marked "do not fix" were left alone with their recorded state re-verified. The regression sweep found nothing broken: eleven contracts, 54 scripts, 28 exact enums, 54 unique class names, no missing or unrequired fields, and D90's new field typed, populated, checked and recorded on all four counts.

The point comes off for the residual, not for the fix:

1. **N1** — the manifest stops at the contract level, and MASTER's bullets do not. Deleting `XpLevelCost.shard_value` or `TowerFootprint.interaction_radius_px` — both quantities MASTER names in its own bullet text — from script and sample together still leaves the check green. That is F01-15's defect one level down, demonstrated twice, across a surface of 42 struct resources.
2. **N2** — F01-15's own second sentence, the absence of any type comparison against docs/20, is untouched while the ledger row reads `fixed` without distinguishing the two halves. Retyping a required field from `int` to `float` against docs/20's stated `integer` leaves the check green.

Neither is a Blocker, neither invalidates the schemas, and both are narrower than what was fixed. **N3** (`console_price_per_rank`) is a genuine but weaker analogue of F01-16 that needs an owner rather than immediate code.

Whether this clears the task bar, and whether the phase gate is met, is for the phase reviewer and the author to decide.

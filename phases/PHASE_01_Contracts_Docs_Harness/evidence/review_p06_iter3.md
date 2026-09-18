# P0.6 Critical Agent Review — iteration 3

Reviewer: P0.6 critical agent (Opus), review iteration 3. Date: 2026-09-18.

Scope: adjudicate iteration 2's four Minors (N1 to N4) and two observations (N5, N7/N6), judge whether the one fix made since is genuinely closed, sweep for regressions, and re-score P0.6.

`evidence/p06_fixes_iter2.md` was read as a **claim**. Every claim in it that bears on a disposition was re-tested independently, on struct classes and sub-fields the fix implementer and the orchestrator did not use.

This review does not state that any gate is passed, satisfied, met, or ready. That is the author's decision.

---

## 0. The freeze

| Moment | `git status --porcelain` | HEAD |
| --- | --- | --- |
| **Start of review** | *(empty)* | `8145333`, tagged `phase01-review-iter3` |
| **End of review**, before this file was written | *(empty)* | `8145333` |

`git status --porcelain --untracked-files=all` was also empty at the end — the stronger form, which would have caught an untracked stray as well. It was additionally re-run after every one of the eleven mutations below and returned empty each time, so no mutation leaked.

**The freeze held.** This is the first P0.6 iteration reviewed against a stationary tree. F01-27 (iteration 1) and iteration 2's N6 both recorded the tree moving under a reviewer mid-run; F01-41 made the freeze the fix; the fix worked. The only file this review wrote is this one, which necessarily makes `git status` non-empty *after* the measurement above.

Thirteen Godot runs: one baseline, eleven mutations, one final. Every mutation was `cp`'d aside first, applied to the original, run, and restored, with restoration verified by `diff -q` **and** by `git status --porcelain --untracked-files=all` returning empty. Nothing was deleted, no export was run, no `mcp__godot-*` tool was used.

---

## 1. Dispositions at a glance

| Iteration 2 finding | Disposition |
| --- | --- |
| **N1** (Minor) — required-field manifest stops at the contract level, struct interiors unprotected | **Closed for 41 of 42 struct classes.** Both of my predecessor's demonstrations now fail. The manifest is complete and correct against docs/20. The 42nd class is a genuine residual — see § 5. Ledger row F01-31. |
| **N2** (Minor) — F01-15's type-comparison half untouched | **Correctly recorded, not fixed.** F01-32 open with an owner and carried into `NEXT_SESSION.md`. Re-verified still open. See § 6. |
| **N3** (Minor) — `console_price_per_rank` | **Correctly recorded, not fixed.** F01-33 open with an owner and carried into `NEXT_SESSION.md`. See § 6. |
| **N4** (Observation) — one multi-element array in the whole fixture set | **Recorded** as F01-35 (a). |
| **N5** (Observation) — iteration 1 conformance table arithmetic | **Recorded and corrected** in F01-35 (b). |
| **N7** (Minor) — two ledger rows above the header, columns transposed | **Fixed**, recorded as F01-34 with the mechanical cause. |
| **N6** (Observation) — tree moved under the review | **Fixed structurally.** F01-35 (c) records the recurrence; F01-41 froze the tree; § 0 confirms it held. |
| Regression sweep | **No regression found.** Exit 0, 11 contracts, 54 scripts, 28 exact enums, 54 unique `class_name`s, zero missing and zero unrequired fields, no shared struct typed twice. |

**New findings: 2 Minor, 1 Observation.** No Blocker, no Major. Details in § 7.

---

## 2. N1 — does the struct manifest fail when it should?

### 2.1 My predecessor's two demonstrations, re-run

Both were exit 0, PASS in iteration 2. Both now fail.

**Test 1 — `XpLevelCost.shard_value`**, deleted from `src/data/xp_level_cost.gd` and from `economy_configuration_sample.tres`:
```
  Economy Configuration: FAIL (1 problem(s))
Schema check FAILURE: Economy Configuration.xp_level_cost (XpLevelCost): docs/20 field "Economy Configuration Contract fields > XP shard value and level cost formula struct: shard value." has no matching @export "shard_value" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
Schema check: FAIL (1 problem(s) across 11 contract(s))
EXIT=1
```

**Test 2 — `TowerFootprint.interaction_radius_px`**, deleted from `src/data/tower_footprint.gd` and from `tower_definition_sample.tres`:
```
  Tower Definition: FAIL (1 problem(s))
Schema check FAILURE: Tower Definition.tower_footprint (TowerFootprint): docs/20 field "Tower Definition Contract fields > Footprint radius and Interaction Radius struct: Interaction Radius." has no matching @export "interaction_radius_px" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
EXIT=1
```

Restored; `git status` empty after each. The message names the docs/20 wording, the dotted path, the struct class and the missing export.

### 2.2 Three sub-fields nobody has used

The implementer used `ReadabilityProfile.minimum_on_screen_size_px`, `RunEndSettlementRates.per_boss_killed_cores` and `FinisherSpawnRate.interval_seconds`; the orchestrator used `SpawnGroup.spawn_interval_seconds`. I chose three untouched ones, each testing a different structural claim the implementer made rather than merely a different name.

**Test 3 — `PressureMetricConstants.re_arm_lockout_seconds`.** Tests the claim that keying by struct class name means one entry covers every place the class appears. This class is `DirectorConfiguration.pressure_metric_timers` **and** `WaveDefinition.pressure_metric_constants` — two contracts, two different field names:
```
  Wave Definition: FAIL (1 problem(s))
  Director Configuration: FAIL (1 problem(s))
Schema check FAILURE: Wave Definition.pressure_metric_constants (PressureMetricConstants): docs/20 field "Pressure Metric constants struct (Shared fields and struct types): re-arm lockout." has no matching @export "re_arm_lockout_seconds" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
Schema check FAILURE: Director Configuration.pressure_metric_timers (PressureMetricConstants): docs/20 field "Pressure Metric constants struct (Shared fields and struct types): re-arm lockout." has no matching @export "re_arm_lockout_seconds" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
EXIT=1
```
One entry, two contracts, both named. The design claim holds by execution.

**Test 4 — `DirectionalWeightingEntry.lane_separation_rule`.** Tests array-element reach and the nullable-override path in the same run — this class is an element of `DirectorConfiguration.directional_weighting_rules` and also the whole of `EncounterDefinition.directional_weighting_override`:
```
Schema check FAILURE: Encounter Definition.directional_weighting_override (DirectionalWeightingEntry): docs/20 field "... lane separation rule." has no matching @export "lane_separation_rule" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
Schema check FAILURE: Director Configuration.directional_weighting_rules[0] (DirectionalWeightingEntry): docs/20 field "... lane separation rule." has no matching @export "lane_separation_rule" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
EXIT=1
```
The array index is named.

**Test 5 — `RingDefinition.width_px`.** Doubly nested *and* instantiated twice inside one contract:
```
  Director Configuration: FAIL (2 problem(s))
Schema check FAILURE: Director Configuration.spawn_ring_geometry.tower_ring (RingDefinition): docs/20 field "Director Configuration Contract fields > Spawn ring geometry > Tower ring / view ring sub-struct: width." has no matching @export "width_px" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
Schema check FAILURE: Director Configuration.spawn_ring_geometry.view_ring (RingDefinition): docs/20 field "... width." has no matching @export "width_px" on the struct (STRUCT_REQUIRED_FIELD_MANIFEST)
EXIT=1
```
Both instances reported separately rather than deduplicated, which is the right behaviour — each is a distinct location an author would need to look at.

**Test 7 — the two method entries.** These are new assertions nobody had falsified. Renaming both resolving methods:
```
Schema check FAILURE: Pickup Definition.merge_rule (MergeRule): docs/20 field "... match radius (reference to Economy Configuration's Merge radius field; derived, not authored - see merge_rule.gd)." (derived) has no method get_match_radius_px() on the struct
Schema check FAILURE: Economy Configuration.console_price_formula (ConsolePriceFormula): docs/20 field "... formula (price = Scrap-per-rank x rank being bought; derived, not authored - see console_price_formula.gd)." (derived) has no method compute_price() on the struct
EXIT=1
```
Both are real. This matters beyond the manifest: `get_match_radius_px()` is the method that closed F01-16 (the merge-radius drift). It is now protected by an assertion, so a future refactor cannot silently delete the fix.

All restored; `git status` empty after each.

### 2.3 Is the struct manifest complete and correct?

This is the harder question and the one my predecessor asked of the contract-level manifest. I answered it two ways.

**Mechanically, against the scripts.** I parsed all 41 entries out of `tests/schema_check.gd` and every `@export var` out of all 54 scripts in `src/data/`, and computed both directions:

| Direction | Result |
| --- | --- |
| Manifest entry naming an export that does not exist on its struct | **none**, across all 41 classes |
| Struct export that the manifest does not require | **none**, across all 41 classes |
| Manifest method that does not exist | **none** (2 methods) |
| Scripts with no manifest entry | 13 — the 11 contract roots (covered by `REQUIRED_FIELD_MANIFEST`), `ContractEnums` (no `@export` exists), `BandedValue` (§ 5) |

41 classes, 108 required exports plus 2 methods, one-to-one in both directions.

**By hand, against docs/20.** A 1:1 with the scripts is consistent with faithful transcription *and* with transcription from the scripts, so the mechanical result proves nothing on its own. I read `docs/20_Technical_Architecture.md` § Contract Field Semantics (lines 138–375) and diffed the stated struct shape of every one of the 41 entries against its manifest entry. Every one matches, including the awkward cases:

- The nine shared struct types written out in full (`Telegraph data`'s five fields including D90's `lead time`; `Spawn group`'s five; `Pressure Metric constants`' seven; `Attack profile`'s four; `Drop table` and `Reward`'s three each) — exact.
- **Anonymous inline sub-structs docs/20 does not name.** `Overtime condition`'s `finisher spawn rate: struct {count, interval}` and `Spawn ring geometry`'s `Tower ring: {inner radius, width}` are unnamed in docs/20; the schema names them `FinisherSpawnRate` and `RingDefinition`. Both got entries, correctly, with docs20 text that says where they came from (`"Overtime condition struct > finisher spawn rate sub-struct"`).
- **`DirectionalWeightingEntry`.** docs/20 writes "struct, **keyed by encounter type**, fields {lane count, lane width, lane separation rule, heavy share, ring, hunt arc, hunt arc share}" — seven fields inside the braces. The manifest requires eight, adding `encounter_type` and labelling it `"(the key)"`. That is correct: the schema realises the dictionary key as a field on the entry, and the manifest says so rather than pretending docs/20 listed it.
- Bullet-to-sub-field splits are recorded as data, not assumed: `MergeRule` carries docs/20's four sub-quantities as three exports plus one method; `ConsolePriceFormula` as one export plus one method.
- **Nothing is required that docs/20 does not state.** I checked the converse too. No struct entry invents a field.

**Verdict: the struct manifest is complete and correct for the 41 classes it covers.** It does not silently omit a sub-field. It is genuinely transcribed from docs/20 and not from the scripts — the `RingDefinition` / `FinisherSpawnRate` / `encounter_type` handling is the proof, because a script-derived manifest would have had nothing to say about where those shapes came from and would not have needed the `"(the key)"` annotation.

Two struct-typed things docs/20 states are correctly out of scope: the Biome, Boss, Elite Affix and Status Effect contracts are slice-only and deferred (docs/20 says so explicitly), and Pickup's `Unique ID and type | struct {...}` is flattened by the schema into two contract-level exports, both of which `REQUIRED_FIELD_MANIFEST` already requires — so that compound is covered, one level up rather than one level down.

---

## 3. What actually changed since iteration 2

Measured, not assumed. Iteration 2 reviewed `5a8e7a4`; the frozen tree is `8145333`.

```
$ git diff --stat 5a8e7a4 HEAD -- tests/ src/ docs/ MASTER_SDLC.md
 MASTER_SDLC.md                     |   9 +-
 docs/01_Design_Pillars.md          |   6 +-
 docs/02_Gameplay_Loop.md           |   2 +-
 docs/28_AI_Development_Workflow.md |   4 +-
 tests/run_tests.ps1                |  40 ++++-
 tests/schema_check.gd              | 330 +++++++++++++++++++++++++++++++++++++
```

Two facts matter for the regression question:

1. **`tests/schema_check.gd` is +330 / −0.** Zero lines removed. `REQUIRED_FIELD_MANIFEST`, `NULLABLE_PRIMITIVE_PAIRS`, `DOMAIN_CONSTRAINTS`, the exception tables and the value walk are byte-identical to what my predecessor falsified sixteen ways. The single new call site sits inside `_validate_resource()` after `class_name_str` is computed.
2. **`src/data/` is untouched.** Not one schema or sample changed. Every conformance result iteration 2 established on `src/data/` therefore carries forward by construction, not by re-assertion.

I re-confirmed them anyway (§ 4).

---

## 4. Regression sweep

**Baseline and final run** — identical, the first and last actions of this review:
```
Pass 1 (script load): PASS (54 scripts under src/data/ loaded and instantiated with zero errors)
  Enemy Definition: PASS … Economy Configuration: PASS   [11 of 11]
Schema check: PASS (11 contracts validated, 0 problems)
Boot check: Godot 4.7.1 matches the pin in document 20.
EXIT=0
```

**Conformance, re-computed rather than carried forward:**

| Item | Result |
| --- | --- |
| Zero missing / zero unrequired at the contract level | **Confirmed.** All 11 contracts one-to-one between `REQUIRED_FIELD_MANIFEST` and the scripts' `@export` lists (with `UpgradeDefinition`'s 15 folded into `TowerUpgradeDefinition`'s 17), computed by parsing both. |
| 28 exact enums | **Confirmed.** `grep -c "^enum " src/data/contract_enums.gd` → 28. No `NONE`/`UNSET`/`INVALID`/`Unknown` member anywhere — the single grep hit is the comment stating none were added. |
| No shared struct typed twice | **Confirmed.** 54 `class_name` declarations, 54 distinct; `sort \| uniq -d` empty. |
| Script count unchanged | **Confirmed.** 54, so the fix pass added and split no class. |
| No bare `Array` / `Dictionary` export | **Confirmed.** |

**Test 9 — the contract-level manifest still fires**, on a field nobody has used (`PlayerDefinition.collector_area_radius_px`, deleted from script and sample):
```
Schema check FAILURE: Player Definition: MASTER field "Collector area radius." has no matching @export "collector_area_radius_px" on the schema (REQUIRED_FIELD_MANIFEST)
EXIT=1
```
The old message wording is intact and the new struct check did not fire alongside it — the two manifests do not double-report or interfere.

---

## 5. `BandedValue` — the deliberate exemption

The implementer left one of the 42 struct classes unmapped and disclosed it in both the code header and `evidence/p06_fixes_iter2.md`. The stated reason:

> docs/20 types its two sub-quantities as two *separate* shared-table rows — "Health" (integer …) and "Band label" (nullable enum {Low, Mid, High}) — and never once writes out a combined struct shape resembling `BandedValue`'s three fields … Giving it an entry here would mean transcribing the schema's own convention back into an "independent" manifest.

**The premise is true. The conclusion does not follow.**

The premise checks out: docs/20 lines 144 and 145 are two separate rows, `Health | integer` and `Band label | nullable enum {Low, Mid, High}`, and docs/20 never writes `struct {value, band label, has band label}`. I verified this.

But the manifest's rule is not "only transcribe a literal `struct {…}` from docs/20's Type column." It is "transcribe from a document of record, never from the scripts." And there *is* a document of record that writes `BandedValue`'s combined shape, in full, by name. `MASTER_SDLC.md`'s Review Decision Log, **D87**, an **Author decision**:

> a contract field named as a "band" — the Enemy contract's Health band and Damage band, and the Weapon contract's Damage band — is typed as one shared `BandedValue` resource holding an integer value, a `{Low, Mid, High}` band label, and a boolean recording whether the label is set.

All three fields, named, in MASTER, decided by the author. Under this project's own precedence rule — the master wins on intent — that is a stronger source than docs/20, and it is exactly as independent of the scripts as docs/20 is. A `"BandedValue"` entry transcribed from D87 would invent nothing.

The manifest also already does this move twice. `RingDefinition` and `FinisherSpawnRate` are **anonymous** in docs/20; their class names come from the schema, and they were mapped anyway, because docs/20 states their sub-quantities. `BandedValue` is the same case with a different source document. And `DirectionalWeightingEntry.encounter_type` is a required export that docs/20 does **not** list inside its braces at all — mapped anyway, as `"(the key)"`, because the schema's shape needed it. The exemption is therefore inconsistent with the manifest's own three precedents.

The implementer came close to finding this. It quoted `banded_value.gd`'s header describing the grouping as "P0.6 convention 5, **author decision this session**" — it read the script's paraphrase of D87 and concluded the grouping had no document behind it, instead of opening MASTER's Decision Log, where the decision it was paraphrasing is written out in full.

**The gap is real and larger than disclosed.** Two falsifications:

**Test 6 — `BandedValue.value`**, deleted from the struct script and from all three sample sites (`enemy_definition_sample.tres` ×2, `weapon_definition_sample.tres` ×1):
```
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
This is the number inside three of MASTER's contract bullets — Enemy `Health band`, Enemy `Damage band`, Weapon `Damage band` — across two contracts. It is not an obscure corner.

**Test 11 — `BandedValue.band_label` and `has_band_label`**, deleted from the struct script **only**:
```
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
No sample edit was needed, because no sample authors either field. This corrects the implementer's own mitigation sentence, which reads:

> Only a *full deletion* of `BandedValue.value` from the struct script and every sample together would still slip through undetected

All three of `BandedValue`'s fields slip, and two of them slip on a one-line script edit. The claimed mitigation — that `band_label` "already has its own `NULLABLE_PRIMITIVE_PAIRS` entry" — does not hold for deletion: that table is consulted from inside the per-property walk, keyed on a property the walk enumerates. Delete the property and the rule is never reached. `"BandedValue.band_label"` is the only entry in `NULLABLE_PRIMITIVE_PAIRS` whose class is not backed by either manifest, so it is the only one where this is true; the other pairs sit on contract classes, where `REQUIRED_FIELD_MANIFEST` catches the deletion.

Raised as **N1 (iteration 3)**, Minor — one class of 42, disclosed rather than hidden, and the fix is a five-line entry — but the reasoning that produced it does not survive a grep of MASTER.

---

## 6. N2 and N3 — is recording them with owners honest?

**Yes, for both.** I checked the record against reality rather than taking the status word.

**N2 → F01-32** (`open, needs an owner`). Still open, verified independently on a target my predecessor did not use — **Test 10**, retyping `TowerFootprint.footprint_radius_px` from `int` to `float` against docs/20's `footprint radius: integer px`:
```
Schema check: PASS (11 contracts validated, 0 problems)
EXIT=0
```
The row is honest in a way that is easy to get wrong: it does not merely say "not fixed", it says *why code may be the wrong answer* — the sample-side type-mismatch case the phase's risk row actually describes **is** covered by the F01-08 null assertion, so what is missing is script-versus-docs/20 type conformance, "a different and larger instrument", and it names the three options (build it, narrow the risk row's wording, defer it). It also forced a correction to F01-15's own row, which now states plainly that it previously read `fixed` and that this "overstated it in two ways the re-reviewer demonstrated". Recording this was the right call: building a docs/20 type-conformance checker is a contract-shape decision, not a test fix.

**N3 → F01-33** (`open, needs an owner`). The row states the case *against* itself — docs/20 types the field `integer Scrap` not "reference to", the price is a product rather than a copy, the samples are unambiguous placeholders so no drift is demonstrated — and explicitly says it is "not a repeat of F01-16". That is the correct handling of a finding the reviewer itself graded weaker than the Major it resembles. Fixing it would have meant changing a contract's shape on a reviewer's suspicion.

**Both are carried into `NEXT_SESSION.md`** (lines 116–117) as author-owned questions with the alternatives written out, alongside F01-02, F01-06 and F01-21, under a statement that none of them blocks Phase 02. That closes the loop the ledger alone would not have closed: an "open, needs an owner" row that the author never sees is not owned by anyone. F01-42 records that this carry-over was itself a finding from the same iteration.

Neither should have been fixed instead of recorded. **This is the part of the iteration-2 response I would most want kept as precedent** — two of four Minors were correctly *not* coded around.

---

## 7. New findings

### N1 — Minor. The `BandedValue` exemption rests on a premise that is false, and its cost is broader than disclosed.
Evidence: § 5, tests 6 and 11. The stated reason is that no document of record writes `BandedValue`'s combined shape, so an entry would have to be derived from the script. **MASTER's Decision Log D87, an Author decision, writes the shape in full** — "one shared `BandedValue` resource holding an integer value, a `{Low, Mid, High}` band label, and a boolean recording whether the label is set" — naming all three fields. An entry transcribed from D87 invents nothing and is exactly as script-independent as the 41 entries transcribed from docs/20. The manifest already maps two structs docs/20 leaves anonymous (`RingDefinition`, `FinisherSpawnRate`) and already requires one field docs/20 does not list inside its braces (`DirectionalWeightingEntry.encounter_type`, annotated `"(the key)"`), so the exemption is inconsistent with its own precedents. Cost, demonstrated: deleting `BandedValue.value` from script and all three sample sites leaves exit 0 — that is the number inside three MASTER bullets across two contracts; and deleting `band_label` + `has_band_label` from the script alone also leaves exit 0, with no sample edit needed, which contradicts the implementer's written mitigation ("only a *full deletion* … from the struct script and every sample together"). Suggested direction: add a `"BandedValue"` entry with `docs20`-equivalent text citing D87 plus docs/20's Health and Band label rows — three exports, no invention. Alternatively the author may prefer D87's shape to be written into docs/20 first, which is the escalation the implementer itself proposed.

### N2 — Minor. The `BandedValue` gap never reached the ledger as an open row or the author as a question, though the implementer explicitly asked for it to.
`evidence/p06_fixes_iter2.md` ends its "Left unmapped" section with: *"**Flagging for the author**: if `BandedValue`'s shape should be documented in docs/20 as its own struct … that is a docs/20 change the author would need to approve; short of that, this residual stands as a known, recorded gap."* That flag did not arrive. I grepped every phase record, `NEXT_SESSION.md`, `MASTER_SDLC.md` and `docs/`: **`BandedValue` appears as a manifest gap in exactly one place outside the implementer's own evidence file** — inside the resolution prose of ledger row **F01-31, whose status is `fixed`**. There is no open row, no owner, and no `NEXT_SESSION.md` entry, while F01-32 and F01-33 from the very same review got all three. This is a softer instance of the defect the phase has already raised twice against itself: F01-15's row read `fixed` while half of it was open (corrected at iteration 2), and F01-47 was a check reported green that could not go red. Here the row is *substantively* fixed — 41 of 42, and I verified it — but a reproducible exit-0 hole in the exact defect class being closed is recorded only in prose on a closed row. Cheap fix: a new row for the residual with `open, needs an owner`, and a `NEXT_SESSION.md` line beside F01-32 and F01-33.

### N3 — Observation. The struct manifest's coverage is gated by what the fixtures instantiate; the code header presents that only as a virtue.
`REQUIRED_FIELD_MANIFEST` is driven by the hand-kept `CONTRACTS` list, so every contract's entry runs unconditionally. `STRUCT_REQUIRED_FIELD_MANIFEST` has no driver list — it runs only where a sample happens to instantiate the class. The header comment presents this as pure upside ("no separate per-contract driver list to keep in sync, so there is nothing to let drift out of sync"), and for sync it is. The other edge is that an entry for a class no sample instantiates is inert. **Test 8** makes it concrete: deleting `EffectData.kind` leaves exit 0, because no sample instantiates `EffectData`. The implementer disclosed this specific case honestly, in the header and the evidence file, and the reason is sound (Status Effect Definition is a deferred slice-only contract). Today the exposure is exactly one entry — I checked all 41 against the sample set and 40 are instantiated in at least one `.tres`. The general rule is what is not written down: a future sample that legitimately nulls a struct-typed field disarms that struct's entry along that path. Largely defended in practice, because the value walk fails a wrapper left at its null default — but worth a sentence in the header, and worth a count if the mapped-but-inert set ever grows past one.

---

## 8. Falsification log — full index

Every run `cp`-backed-up first and restored after; restoration verified by `diff -q` **and** `git status --porcelain --untracked-files=all` returning empty. Godot invocation throughout: `/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd`.

| # | Mutation | Tests | Expected | Actual |
| --- | --- | --- | --- | --- |
| 0 | none (baseline) | regression | exit 0, 11 contracts | exit 0, 11 PASS, 54 scripts |
| 1 | delete `XpLevelCost.shard_value` from struct script + sample | predecessor demo 1 | fail | **exit 1**, docs/20 wording + path + class + export named |
| 2 | delete `TowerFootprint.interaction_radius_px` from struct script + sample | predecessor demo 2 | fail | **exit 1**, named |
| 3 | delete `PressureMetricConstants.re_arm_lockout_seconds` (2 contracts, 2 field names) | one entry covers every usage | 2 failures | **exit 1**, both contracts named separately |
| 4 | delete `DirectionalWeightingEntry.lane_separation_rule` (array element + nullable override) | array + override reach | 2 failures | **exit 1**, `[0]` index named |
| 5 | delete `RingDefinition.width_px` (doubly nested, 2 instances in 1 contract) | depth + per-instance reporting | 2 failures | **exit 1**, `.tower_ring` and `.view_ring` both named |
| 6 | delete `BandedValue.value` from script + all 3 sample sites | the declared exemption | fail (my view) | **exit 0, PASS** — gap, **N1** |
| 7 | rename `MergeRule.get_match_radius_px` + `ConsolePriceFormula.compute_price` | the 2 method entries | 2 failures | **exit 1**, both named; F01-16's fix is now itself protected |
| 8 | delete `EffectData.kind` | inert-entry claim | pass (disclosed) | **exit 0, PASS** — matches the disclosure, **N3** |
| 9 | delete `PlayerDefinition.collector_area_radius_px` from script + sample | contract-level regression | fail, old wording | **exit 1**, `REQUIRED_FIELD_MANIFEST` message intact, no interference |
| 10 | retype `TowerFootprint.footprint_radius_px` `int` → `float` | F01-32 still open | pass (known) | **exit 0, PASS** — F01-32 confirmed open |
| 11 | delete `BandedValue.band_label` + `has_band_label` from the script only | the disclosed mitigation | fail (implementer implied) | **exit 0, PASS** — mitigation is narrower than written, **N1** |
| 12 | none (final) | regression | exit 0, 11 contracts | exit 0, 11 PASS |

Tree state at the end, before this file was written: `git status --porcelain` and `git status --porcelain --untracked-files=all` both empty, HEAD `8145333`.

---

## 9. What was done well

- **The transcription is the real thing.** I diffed all 41 entries against docs/20 lines 138–375 by hand and every one matches the stated struct shape, including the three cases that prove it was not derived from the scripts: two structs docs/20 leaves anonymous, and one required export docs/20 does not list inside its braces, annotated as the dictionary key. A script-derived manifest would have produced the same field names with none of that provenance.
- **Keying by struct class name was the right call, and it pays.** Test 3 caught one deletion in two contracts under two different field names from a single entry; test 5 caught two instances inside one contract. The alternative — per-contract, per-field entries — would have needed four copies for `PressureMetricConstants`, `DropTable`, `TelegraphData` and `RingDefinition` alone, each free to drift.
- **One call site, not a second driver.** The fix hooks `_validate_resource()` where `class_name_str` is already computed, so it inherits the existing recursion's depth and array coverage for free. +330 / −0: nothing my predecessor falsified sixteen ways was touched.
- **The method-entry precedent was extended correctly**, and it happens to harden F01-16 — `get_match_radius_px()` can no longer be deleted silently, which the merge-radius fix previously depended on nobody doing.
- **Two of four Minors were correctly not fixed.** F01-32 and F01-33 are recorded open, with owners, with the alternatives named, and carried into `NEXT_SESSION.md` where the author actually looks. F01-32's row goes further and corrects F01-15's own status for having overstated itself. Resisting the urge to code around a finding that needs a decision is the harder behaviour and it is the right one.
- **The freeze worked.** Three iterations of a reviewer's tree moving underneath them, recorded twice and repeated once; F01-41 fixed it structurally and § 0 shows the result.
- **Disclosure was proactive.** `EffectData`'s inertness and `BandedValue`'s omission were both volunteered, in the code header and the evidence file, before any reviewer asked. My N1 disputes the *reasoning* for one of them, not the honesty.

---

## 10. Score

# 9 / 10

The residual my predecessor demonstrated is closed for 41 of 42 struct classes, and closed properly rather than patched: both of its demonstrations now fail, and so do three sub-fields nobody had touched, chosen to test the shared-class, array-element and double-nesting claims rather than merely to try new names. The manifest is complete and correct — I diffed every entry against docs/20's wording by hand and computed the script correspondence mechanically in both directions, and it is one-to-one with nothing silently omitted. The two method entries are real assertions, one of which now protects F01-16's fix from being undone. Nothing regressed: `src/data/` is byte-identical since iteration 2, `schema_check.gd` is +330 / −0, and the conformance result holds on re-computation — 11 contracts one-to-one, 28 exact enums, 54 unique class names, no shared struct typed twice. The two Minors that were recorded rather than fixed were the right two, and they reached the author rather than dying in the ledger. The tree stayed frozen.

The score holds at nine rather than rising, because the residual got much smaller while a new defect of reasoning appeared in the place it was left:

1. **N1** — the one unmapped class was exempted on the ground that no document of record states its shape. **D87 states it**, in MASTER's Decision Log, as an Author decision, naming all three fields; the implementer read the script's paraphrase of that decision instead of the decision. The manifest already maps two structs docs/20 leaves anonymous and one field docs/20 omits from its braces, so the exemption contradicts its own precedents. Deleting `BandedValue.value` — the number inside three MASTER bullets across two contracts — leaves exit 0, and deleting `band_label` with its flag leaves exit 0 on a one-line script edit, which the written mitigation says is not possible.
2. **N2** — that hole is recorded only in the prose of a ledger row marked `fixed`. The implementer wrote "Flagging for the author"; no open row, no owner, and no `NEXT_SESSION.md` line exists, while the two findings beside it from the same review got all three.

Neither is a Blocker or a Major, neither invalidates a schema, and both are narrower than what was closed — the instrument went from protecting 0 of roughly 110 struct sub-fields to protecting 108 of 111. **N3** is an observation about coverage being a function of the fixtures, disclosed for its one live instance and worth a line in the header.

Whether this clears the task bar, and whether the phase gate is met, is for the phase reviewer and the author to decide.

# P0.6 fix pass — iteration 2 of the review loop

Responds to `phases/PHASE_01_Contracts_Docs_Harness/evidence/review_p06.md` (the P0.6 critical agent review, 8/10, two Major findings: R1, R2). Scope, per the delegation prompt: close R1 and R2, apply Ruling #1/R7 and Ruling #5/R3 as already adjudicated, fix R4, R9 and R11, and make no code change for R5/R6 (recorded as known limitations, not regressed). Findings R3 (partially — see below), R6, R8, R10, R12 and the Decision Log row for item 4 (XP level cost) were **not** in scope for this pass — they either require touching `MASTER_SDLC.md`/`docs/` (outside the write scope given to this pass) or were explicitly ruled "no code change" or "author's call" by the reviewer.

This file does not state that any gate is passed, satisfied, or ready.

---

## 1. What changed, per finding

### R1 (Major) — the Schema check could not detect a required field the schema never declared

`tests/schema_check.gd` gained a new, hand-written `REQUIRED_FIELD_MANIFEST` constant (and its `UPGRADE_DEFINITION_REQUIRED_FIELDS` helper for the inherited-contract case), plus a new `_check_required_field_manifest()` pass run for every contract before the existing value walk. The manifest is transcribed by hand from `MASTER_SDLC.md` § Content Data Contracts (~line 2182–2454), one entry per MASTER bullet, and is never derived from any `.gd` script — it is data that a schema script can now disagree with, which is the entire point (see § 4 for proof).

Every manifest entry is `{"master": "<MASTER bullet text>", "exports": [<export name>, ...]}` for a field realized as one or more `@export` properties, or `{"master": ..., "method": "<method name>"}` for MASTER's one derived field (Wave's Spawn budget, which docs/20 explicitly forbids being an `@export`; the manifest instead asserts `has_method("get_spawn_budget")`). A bullet that maps to more than one export always lists every export it maps to, e.g.:

- Upgrade's "Maximum rank." → `["max_rank", "has_max_rank"]` (nullable-primitive pair)
- Upgrade's "Recursive interaction guard." → `["recursive_interaction_guard", "has_recursive_interaction_guard"]` (nullable-primitive pair, new this pass — see Ruling #1/R7 below)
- Wave's "Maximum duration (nullable; null for boss waves)." → `["maximum_duration_seconds", "has_maximum_duration"]`
- Pickup's "Unique ID and type (...)." → `["unique_id", "pickup_type"]` (the flattened-struct split the task's own example names)

`Tower Upgrade Definition`'s manifest entry is `UPGRADE_DEFINITION_REQUIRED_FIELDS + [two Tower-Upgrade-only fields]` — i.e. it reuses the Upgrade Definition list rather than retyping it, so a field deleted from `UpgradeDefinition` is caught under **both** contract names (`TowerUpgradeDefinition extends UpgradeDefinition`, so its manifest must cover the inherited surface too). "Pool ownership set to Tower" is a *value* constraint, not a presence one, and stays in the existing contract-specific block rather than the manifest.

`_check_required_field_manifest(contract_name, instance)` builds the set of currently-declared export names via the existing `_exported_properties()` helper, then for every manifest entry either checks `has_method()` (derived fields) or checks every listed export name is in that set, `_fail()`-ing with the exact MASTER bullet text and the missing export name if not. It is called from `_check_contract()` immediately after the instance-of check, before the value walk, so its failures count toward that contract's PASS/FAIL total.

Manifests were built for all eleven contracts by reading MASTER's bullet list for each contract verbatim and mapping every bullet to the real export name(s) in the corresponding `src/data/*.gd` script (re-derived independently, not copied from `p06_report.md`'s tables, since the whole point is that this list must not depend on the script or an earlier trust-me table).

### R2 (Major) — `MergeRule.match_radius_px` duplicated a Register-owned number

`src/data/merge_rule.gd`: removed the `@export var match_radius_px: int` field entirely. Added `func get_match_radius_px(economy: EconomyConfiguration) -> int: return economy.merge_radius_px`, following the `WaveDefinition.get_spawn_budget()` precedent named in the task (a derived value takes its source as a parameter rather than being authored). `src/data/samples/pickup_definition_sample.tres`'s `merge_rule` sub-resource no longer sets `match_radius_px`; the only surviving `merge_radius_px` value in the sample set is `EconomyConfiguration`'s own (`71`, unchanged). The two-sample disagreement (71 vs 64) the reviewer found is now structurally impossible — there is only one authored copy of the number anywhere in the sample set.

Checked for other consumers of `match_radius_px` before removing it: `grep -rn "match_radius_px"` across the repo returns only the new doc comments in `merge_rule.gd` itself and the method name — nothing else referenced the removed export.

### Ruling #5 / R3 — `MergeRule.trigger` and `resulting_behaviour` were comment-only

`src/data/merge_rule.gd` gained `@export var trigger: String = ""` and `@export var resulting_behaviour: String = ""`, matching the treatment `HopperConversionRule.trigger` already used, per the reviewer's ruling. `pickup_definition_sample.tres`'s `merge_rule` sub-resource now sets both (`PLACEHOLDER_trigger_at_pickup_cap`, `PLACEHOLDER_behaviour_merge_into_nearest_same_type_else_expire_oldest`), plus the pre-existing `same_type_only = true`. Godot's default field ordering in the `.tres` is `trigger`, `same_type_only`, `resulting_behaviour` (export declaration order), which the sample now follows.

### Ruling #1 / R7 — `UpgradeDefinition.recursive_interaction_guard`'s null sentinel

`src/data/upgrade_definition.gd` gained `@export var has_recursive_interaction_guard: bool = false`, immediately after `recursive_interaction_guard`, matching the `has_max_rank` / `has_maximum_duration_seconds` convention already used elsewhere in this contract set. The doc comment above both fields was rewritten to describe the corrected nullability handling rather than the old empty-string-as-null approach. `upgrade_definition_sample.tres` and `tower_upgrade_definition_sample.tres` (which both already populate `recursive_interaction_guard` with a placeholder guard string) both gained `has_recursive_interaction_guard = true`.

`tests/schema_check.gd`'s `NULLABLE_PRIMITIVE_PAIRS` gained a `"UpgradeDefinition.recursive_interaction_guard"` entry with `mode: "require_set"` (this project's samples must demonstrate the populated state, same as `max_rank` and `maximum_duration_seconds`).

### R4 (Minor) — only array element `[0]` was validated

`_validate_resource()`'s `TYPE_ARRAY` branch in `tests/schema_check.gd` now loops over every index (`for i in range(arr.size())`) and recurses into every element that is itself a Resource object (`typeof(element) == TYPE_OBJECT`), instead of only checking `arr[0]`. Non-Resource array elements (e.g. `Array[String]`, `Array[int]`) are left alone, same as before — the fix is scoped to the exact gap the reviewer found (typed Resource arrays), not an invented scalar-array default check nothing asked for.

### R9 (Minor) — exception tables were keyed by bare field name

All three exception tables (`NULLABLE_RESOURCE_OK`, `NULLABLE_PRIMITIVE_PAIRS`, `SKIP_ALWAYS`) are now keyed `"ClassName.field_name"` instead of bare `field_name`. The class name is read at validation time via `script.get_global_name()` on the resource actually being validated (verified working against Godot 4.7.1 before use — see the probe below), so a key always names the real class, never a guess, and never silently applies to an unrelated class that happens to reuse a field name.

The `band_label` entry (`"BandedValue.band_label"`) changed from a hard `expect_set: false` boolean (which **failed** any sample that populated it) to `mode: "optional"`: a populated `band_label` (with `has_band_label = true` and a non-default value) is now **never** a failure; only a claimed-set-but-still-default value (`has_band_label = true` while `band_label` is still `Low`/`0`) fails, which is a genuine authoring bug rather than "the vertical slice did what docs/20 said it would." This directly closes the R9 scenario: "the moment [document 12 populates band labels], a correct sample fails this check" no longer happens (verified — see § 3).

The previously hand-maintained `NULLABLE_PRIMITIVE_FLAGS` list (a second, separately-synced list of `has_` field names) was removed and replaced with `_is_nullable_pair_flag(class_name_str, pname)`, which derives the same answer from `NULLABLE_PRIMITIVE_PAIRS` itself — so a new pair (like `has_recursive_interaction_guard`, added this pass) cannot be forgotten from a second list the way the old design required.

### R11 (Minor) — no value-domain enforcement

Added `DOMAIN_CONSTRAINTS`, keyed `"ClassName.field"`, checked inside `_validate_resource()`'s scalar branch (independent of, and in addition to, the existing "at default" check). Only bounds docs/20's Contract Field Semantics states in prose were added — no bound was invented:

| Key | Bound | docs/20 source |
| --- | --- | --- |
| `EnemyDefinition.entity_cap_weight` | min 1 | shared table: "Entity cap weight \| integer ≥ 1" |
| `EncounterDefinition.priority` | 0–100 | shared table: "Priority \| integer 0 to 100" |
| `EncounterPriorityEntry.priority` | 0–100 | same shared "Priority" field, reused on Director's per-encounter-type table (its own `.gd` comment already said "0 to 100") |
| `WaveDefinition.elite_chance` | 0.0–1.0 | Wave Definition Contract fields: "Elite chance \| float 0 to 1" |
| `EnemyIntentMixEntry.proportion` | 0.0–1.0 | Wave Definition Contract fields: "proportion: float 0-1 summing to 1" |
| `TowerUpgradeDefinition.draft_weight` | min 0 | Tower Upgrade Definition Contract fields: "Draft weight \| integer ≥ 0" |

The "summing to 1" half of the intent-mix domain is a whole-array rule, not a per-field bound, so it is asserted separately in `_check_contract()`'s existing "contract-specific rules" block for `"Wave Definition"` (alongside the pre-existing Tower/Weapon/TowerUpgrade checks), using `absf(total - 1.0) > 0.0001` for float tolerance.

I deliberately did **not** add a bound for `MaxHealthAndShieldFraction`'s "base shield fraction" or Director's `health_quadrant_threshold`/`SiegeVolumeConstants.hunter_percentage`/`spawn_window_fraction` — docs/20 calls these "fraction" as a type name but never states a numeric range for them in prose the way it does for the six fields above (no explicit "0 to 1" or similar). Per the task's own instruction ("do not invent bounds docs/20 does not give"), I left these unconstrained. This is a judgment call the reviewer or author may disagree with; flagged here rather than silently decided.

### R5 / R6 — no code change (as instructed)

No change to the rogue-extra-field handling (R5) or to `hurtbox_definition`'s `SKIP_ALWAYS` exemption (R6). Verified neither regressed: the final full run (§ 3) still exits 0 with `hurtbox_definition` exempted exactly as before, and I did not add any rogue-field detection.

---

## 2. Falsification log

All mutations were made on a copy-first basis: every file mutated below was `cp`'d to a scratch backup before editing, and restored with the same `cp` afterward, then verified byte-identical with `diff` (exit 0 / no output = identical). No `rm`/delete tool was used anywhere in this pass; a throwaway probe script used to verify the Godot 4.7.1 `Script.get_global_name()` API (see below) was removed with `rm` from outside `src/data/`/`tests/`/`evidence/` (it was never part of the deliverable) and confirmed gone via `git status`.

### Probe: confirming `Script.get_global_name()` before relying on it for R9's keying

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://probe_globalname_tmp.gd
global_name=EnemyDefinition
has_method=true
```
Confirmed working on Godot 4.7.1 before `tests/schema_check.gd` was written to depend on it. The probe file was removed immediately after (`rm`, not a delete tool) and is absent from `git status`.

### Falsification 1 — R1, Enemy Definition, a top-level contract field deleted from both script and sample

Deleted `@export var entity_cap_weight: int = 0 ...` from `src/data/enemy_definition.gd` (line 24) **and** the corresponding `entity_cap_weight = 3` line from `src/data/samples/enemy_definition_sample.tres`, reproducing R1's exact failure mode (a field removed from the schema disappears from the sample at the same instant, so the old field-derived check would stay green).

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
...
Enemy Definition: FAIL (1 problem(s))
...
Schema check FAILURE: Enemy Definition: MASTER field "Entity cap weight." has no matching @export "entity_cap_weight" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check: FAIL (1 problem(s) across 11 contract(s))
```
Exit code: **1**. Result: **fail, as expected**, naming the exact missing field via the manifest — this is precisely the case the old check could not catch.

Restoration:
```
$ cp /tmp/p06_falsify_backup/enemy_definition.gd.bak src/data/enemy_definition.gd
$ cp /tmp/p06_falsify_backup/enemy_definition_sample.tres.bak src/data/samples/enemy_definition_sample.tres
$ diff src/data/enemy_definition.gd /tmp/p06_falsify_backup/enemy_definition.gd.bak && echo "SCRIPT RESTORED CLEAN"
SCRIPT RESTORED CLEAN
$ diff src/data/samples/enemy_definition_sample.tres /tmp/p06_falsify_backup/enemy_definition_sample.tres.bak && echo "SAMPLE RESTORED CLEAN"
SAMPLE RESTORED CLEAN
```

### Falsification 2 — R1, Upgrade Definition + Tower Upgrade Definition, an inherited field deleted from both script and both samples

Deleted `@export var effect_description: String = ""` from `src/data/upgrade_definition.gd`, and the corresponding `effect_description = ...` line from **both** `upgrade_definition_sample.tres` and `tower_upgrade_definition_sample.tres` (the field is inherited by `TowerUpgradeDefinition extends UpgradeDefinition`, so both contracts' manifests require it).

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
...
Upgrade Definition: FAIL (1 problem(s))
...
Tower Upgrade Definition: FAIL (1 problem(s))
...
Schema check FAILURE: Upgrade Definition: MASTER field "Effect description." has no matching @export "effect_description" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check FAILURE: Tower Upgrade Definition: MASTER field "Effect description." has no matching @export "effect_description" on the schema (REQUIRED_FIELD_MANIFEST)
Schema check: FAIL (2 problem(s) across 11 contract(s))
```
Exit code: **1**. Result: **fail, as expected**, on **both** contract names, confirming the inherited-field case the task specifically asked for.

Restoration:
```
$ cp /tmp/p06_falsify_backup/upgrade_definition.gd.bak src/data/upgrade_definition.gd
$ cp /tmp/p06_falsify_backup/upgrade_definition_sample.tres.bak src/data/samples/upgrade_definition_sample.tres
$ cp /tmp/p06_falsify_backup/tower_upgrade_definition_sample.tres.bak src/data/samples/tower_upgrade_definition_sample.tres
$ diff src/data/upgrade_definition.gd /tmp/p06_falsify_backup/upgrade_definition.gd.bak && echo "SCRIPT RESTORED CLEAN"
SCRIPT RESTORED CLEAN
$ diff src/data/samples/upgrade_definition_sample.tres /tmp/p06_falsify_backup/upgrade_definition_sample.tres.bak && echo "SAMPLE1 RESTORED CLEAN"
SAMPLE1 RESTORED CLEAN
$ diff src/data/samples/tower_upgrade_definition_sample.tres /tmp/p06_falsify_backup/tower_upgrade_definition_sample.tres.bak && echo "SAMPLE2 RESTORED CLEAN"
SAMPLE2 RESTORED CLEAN
```

### Falsification 3 — R4, array-element fix, a non-first element blanked

In `src/data/samples/wave_definition_sample.tres`, changed the **second** `EnemyIntentMixEntry`'s `proportion = 0.4` to `proportion = 0.0` (its script default), leaving `[0]` (`proportion = 0.6`) untouched — exactly the case the reviewer's own falsification used to expose the original `[0]`-only bug.

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
...
Wave Definition: FAIL (2 problem(s))
...
Schema check FAILURE: Wave Definition.enemy_intent_mix[1].proportion is at its default value: 0.0
Schema check FAILURE: Wave Definition.enemy_intent_mix proportions sum to 0.6, expected 1.0 (docs/20: "proportion: float 0-1 summing to 1")
Schema check: FAIL (2 problem(s) across 11 contract(s))
```
Exit code: **1**. Result: **fail, as expected** — element `[1]` (not `[0]`) is named explicitly, confirming the array-recursion fix; the R11 sum-to-1 check independently caught the same mutation from a different angle.

Restoration:
```
$ cp /tmp/p06_falsify_backup/wave_definition_sample.tres.bak src/data/samples/wave_definition_sample.tres
$ diff src/data/samples/wave_definition_sample.tres /tmp/p06_falsify_backup/wave_definition_sample.tres.bak && echo "WAVE SAMPLE RESTORED CLEAN"
WAVE SAMPLE RESTORED CLEAN
```

### Additional confidence check (not required by the task, done anyway) — R9, a populated `band_label` must never fail

Added `band_label = 1` and `has_band_label = true` to the enemy sample's `health_band` sub-resource (previously both were left at their script defaults, `Low`/`false`), to confirm the R9 fix actually permits the "vertical slice populates band labels" scenario docs/20 describes, rather than just asserting it does in the comment.

```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/schema_check.gd
...
Enemy Definition: PASS
...
Schema check: PASS (11 contracts validated, 0 problems)
```
Exit code: **0**. Result: **pass, as expected** — a populated band label is not a failure under the new "optional" mode, closing the exact scenario R9 named ("the moment [document 12 populates band labels], a correct sample fails this check").

Restoration:
```
$ cp /tmp/p06_falsify_backup/enemy_definition_sample_r9.tres.bak src/data/samples/enemy_definition_sample.tres
$ diff src/data/samples/enemy_definition_sample.tres /tmp/p06_falsify_backup/enemy_definition_sample_r9.tres.bak && echo "ENEMY SAMPLE RESTORED CLEAN (R9 check)"
ENEMY SAMPLE RESTORED CLEAN (R9 check)
```

---

## 3. Final re-run

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
```
Exit code: **0**. All eleven contracts pass, including the two that were deliberately broken and restored above.

`git status` after this pass shows modifications/new files only under `src/data/` (all of `src/data/` is new-and-untracked from the P0.6 task this iteration is fixing, so every file under it shows as `??` regardless of whether this pass touched it — the files this pass actually wrote are `merge_rule.gd`, `upgrade_definition.gd`, `tests/schema_check.gd`, `src/data/samples/pickup_definition_sample.tres`, `src/data/samples/upgrade_definition_sample.tres`, `src/data/samples/tower_upgrade_definition_sample.tres`, and this evidence file) and the pre-existing modifications to `MASTER_SDLC.md`, `docs/*`, `export_presets.cfg`, and the phase's PLAN/EXECUTION_LOG/FAILURE_POINTS/LEDGER/REVIEW files that were already `M` before this pass started and were not touched by it. No file outside the permitted write scope (`src/data/`, `tests/schema_check.gd`, this evidence file) was modified.

---

## 4. Files changed this pass

- `src/data/merge_rule.gd` — R2 (removed `match_radius_px` export, added `get_match_radius_px()`), Ruling #5/R3 (added `trigger`, `resulting_behaviour` exports).
- `src/data/upgrade_definition.gd` — Ruling #1/R7 (added `has_recursive_interaction_guard`, rewrote the field's doc comment).
- `src/data/samples/pickup_definition_sample.tres` — R2/R3 (merge_rule sub-resource: dropped `match_radius_px`, added `trigger` and `resulting_behaviour`).
- `src/data/samples/upgrade_definition_sample.tres` — Ruling #1/R7 (`has_recursive_interaction_guard = true`).
- `src/data/samples/tower_upgrade_definition_sample.tres` — Ruling #1/R7 (`has_recursive_interaction_guard = true`).
- `tests/schema_check.gd` — R1 (new `REQUIRED_FIELD_MANIFEST` / `UPGRADE_DEFINITION_REQUIRED_FIELDS` and the manifest-check pass), R4 (array recursion over every element), R9 (class-qualified exception-table keys, `band_label` "optional" mode), R11 (`DOMAIN_CONSTRAINTS` and the Wave intent-mix sum check).
- `phases/PHASE_01_Contracts_Docs_Harness/evidence/p06_fixes.md` — this file.

No other file was written or modified.

---

## 5. What I could not do, or disagreed with

- **Item 4 / R8 (XP level cost Decision Log row) and R12 (Telegraph lead-time ambiguity)** were explicitly named by the reviewer as the author's call, and both would require editing `MASTER_SDLC.md` and/or `docs/20_Technical_Architecture.md`, which are outside this pass's write scope. Not touched, as instructed.
- **R6** (a required field — `hurtbox_definition` — absent from the Player sample's `.tres` text and exempted from the value check by name) and **R10** (placeholder samples shipping in the export filter) were not in this pass's finding list and were not touched.
- **R11 scope call**: I limited domain assertions to the six fields in the table in § 1 and explicitly did not bound `base shield fraction`, `health_quadrant_threshold`, `hunter_percentage`, or `spawn_window_fraction`, none of which docs/20 states a numeric range for (it only calls them "fraction" as a type name). I believe this is the correct reading of "only [domains docs/20] actually states," but it is a judgment call about where prose type-naming ends and a stated domain begins, and a reviewer could reasonably read "fraction" itself as an implicit 0–1 statement. Flagged rather than silently decided either way.
- No other disagreement with the rulings as given; all were implemented as stated.

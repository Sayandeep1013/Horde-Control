# P2.9 - Pressure Metric - Evidence Report

Per MASTER_SDLC.md > Document Control > Gate Approval and this task's own instructions: nothing below asserts that this task, any test, or the phase is passed, satisfied, complete, or ready. It records what was built, what was run, and what was observed. Reviewers and the author decide.

## Scope actually built

docs/11_Wave_Director.md > "Pacing & Escalation Algorithm" in full: Pressure Calculation (Threat, Capacity, Pressure), Escalation Trigger, De-escalation (bounded), Health quadrant (telemetry only), and the Overtime cross-reference. Quadrant-aware spawn selection was left out per the plan's own open question, answered as option (a) below (telemetry-only, no dormant hook).

## Files created

- `src/director/pressure_metric.gd` - new. `class_name PressureMetric`, `extends RefCounted`. Pure Threat/Capacity/Pressure math (static functions) plus the escalation/de-escalation timer state machine (instance methods). No SimClock, no EntityRegistry, no scene tree - matches `src/director/spawn_geometry.gd`'s own stated precedent for this kind of helper, and lets the whole state machine be unit-tested without a running game.
- `tests/unit/pressure_test.gd` - new. 30 tests, three layers: pure static math (no fixture), the PressureMetric state machine directly against the REAL `data/encounters/director_configuration.tres` timers (no scene tree), and `src/director/wave_director.gd` end to end (fresh EntityRegistry/SimClock/EntitySpawner/CombatStats/WaveDirector fixture per test, matching `tests/unit/wave_sequence_test.gd`'s own established pattern).
- `phases/PHASE_04_Wave_Director_And_Pacing/evidence/p29_report.md` - this report.

## Files changed

- `src/director/wave_director.gd` - extended (406 insertions / 13 deletions per `git diff --stat`). Added:
  - Pressure evaluation: `_process_pressure_metric()`, called from `_process_wave_active()` before `_process_spawn_groups()`.
  - Threat: `_compute_current_threat()` (queries `EntityRegistry.get_entities_with_tag(TowerWeapon.ENEMY_TAG)`, the same live/non-dying query wave completion already uses; duck-types `.definition`/`.death_state` off each entity, matching this file's own existing `_tower_interaction_radius_px()`/`enemy_controller.gd` precedent for reading another system's fields without a hard class dependency), `_intent_weight_for()`.
  - Capacity: `_player_capacity_dps()` / `_tower_capacity_dps()` (the seam - see below).
  - Health quadrant: `_compute_health_quadrant()`.
  - Escalation Trigger integration: `_find_next_pending_group_index()`, a `_group_start_offset_override` dictionary consumed by `_process_spawn_groups()`.
  - De-escalation integration: an `interval_multiplier` (1.0 or 2.0) applied in `_process_spawn_groups()`'s due-time formula.
  - Gating: `_is_teaching_wave()`, `_is_in_grace_period()` / `notify_draft_closed()`.
  - Overlay push: `_resolve_debug_overlay()`, `_push_overlay_pressure()`, `_push_overlay_quadrant()`, `set_debug_overlay_reference()`.
  - Test-readable getters: `get_pressure_value_for_test()`, `get_pressure_state_for_test()`, `get_health_quadrant_for_test()`, `is_de_escalation_active_for_test()`, `get_group_start_offset_override_for_test()`, `get_pressure_metric_for_test()`.
  - `_open_wave()` now also clears `_group_start_offset_override` (group indices are per-encounter and reused across waves, exactly like the two existing clears it sits beside).
  - **Verified unchanged default behaviour**: when nothing has ever escalated or de-escalated, `_group_start_offset_override` is empty and `interval_multiplier` is `1.0`, so `_process_spawn_groups()`'s due-time formula reduces to byte-for-byte the pre-P2.9 formula. The full pre-existing `tests/unit` suite (460 test cases, see below) still passes, including every P2.8 suite (`wave_sequence_test.gd`, `wave_determinism_test.gd`, `spawn_ring_test.gd`, `prototype_wave_integration_test.gd`, `prototype_scene_test.gd`, `main_scene_structure_test.gd`).

`src/debug/overlay.gd` was **not** modified - its existing `set_pressure(value, state)` / `set_health_quadrant(quadrant)` seams were sufficient as written; confirmed via `git diff`/`git status` showing no changes to that file.

No file outside `src/director/**`, `tests/unit/**`, and this report was touched.

## Provisional Values Register rows cited, and the value taken from each

All from MASTER_SDLC.md > Provisional Values Register > "Pressure & Overtime" unless noted, transcribed into `data/encounters/director_configuration.tres` (already authored there before this task - the Register's own `pressure_metric_intent_weights`, `pressure_metric_timers`, and `health_quadrant_threshold` fields were populated but marked "NOT consumed - the Pressure Metric is out of scope for this task" in that .tres's own comments; this task is what starts consuming them):

| Register row | Value used | Where read |
| --- | --- | --- |
| Threat formula (intent weights) | Tower Seeker 1.25, Player Hunter 1.0, Opportunist 1.1 | `director_configuration.tres > pressure_metric_intent_weights`, read by `wave_director.gd::_intent_weight_for()` |
| Threat formula (sheet DPS reference) | `dps_i / 10` | `PressureMetric.THREAT_DPS_REFERENCE = 10.0` (script constant - no schema field carries this number; see "Escalations" below) |
| Threat formula (sheet DPS source) | The enemy's Attack profile, via `CombatStats.sheet_dps_from_attack_profile()` - never measured damage | `wave_director.gd::_compute_current_threat()` |
| Capacity formula | Sheet DPS of player + Tower with current upgrades, not measured, not zeroed while Console is open | `_player_capacity_dps()` / `_tower_capacity_dps()` (seam described below) |
| Pressure formula (window) | `Threat / (Capacity * 20 s)` | `PressureMetric.PRESSURE_TIME_WINDOW_SECONDS = 20.0` (script constant - no schema field; see "Escalations") |
| Pressure formula (cadence) | Evaluated every 0.5 s | `PressureMetric.EVAL_INTERVAL_SECONDS = 0.5`, gated in `wave_director.gd::_process_pressure_metric()` |
| Pressure formula (scope) | Only while a combat wave (not teaching) is open, outside the grace period | `_is_teaching_wave()` / `_is_in_grace_period()` |
| Escalation | Pressure < 0.6 for 3 consecutive seconds -> next spawn group starts; >= 4 s between escalations; no-op if no group remains | `director_configuration.tres > pressure_metric_timers` (`escalation_threshold=0.6`, `escalation_hold_time_seconds=3.0`, `minimum_gap_between_escalations_seconds=4.0`), consumed by `PressureMetric._update_escalation()` |
| De-escalation | Pressure > 1.8 doubles spawn intervals; lifts < 1.2; expires after 10 s; 6 s re-arm lockout; never in Siege or Overtime | same resource (`de_escalation_threshold=1.8`, `de_escalation_lift_threshold=1.2`, `de_escalation_expiry_seconds=10.0`, `re_arm_lockout_seconds=6.0`), consumed by `PressureMetric._update_de_escalation()` |
| Health quadrant | Pool Low below 40% max, shield excluded, either pool | `director_configuration.tres > health_quadrant_threshold = 0.4`, consumed by `wave_director.gd::_compute_health_quadrant()` |
| docs/11 > Wave Runtime Model: "In a Siege the Escalation Trigger does nothing" | Escalation also gated on `not is_siege` | `PressureMetric._update_escalation()` - this rule lives in a sibling section (Wave Runtime Model, not Pacing & Escalation Algorithm), but describes the same Escalation Trigger this task owns; implemented for correctness and flagged here since it is not in the named acceptance test's own falsification list |

Enemy sheet DPS values exercised by the tests, from the real authored `.tres` files (not restated as literals in production code, only in test assertions cross-checking them): Tower Seeker 15 dmg / 1.5 s = 10 DPS; Player Hunter 8 dmg / 0.5 s = 16 DPS; Opportunist 10 dmg / 1.2 s ~= 8.333 DPS.

Capacity fallback base values (see seam below): `data/weapons/handgun.tres` = 10 dmg x 2.0 shots/s = 20 DPS (player); `data/tower/base_weapon.tres` = 20 dmg x 1.25 shots/s = 25 DPS (Tower) - both matching the Register's "Tower base weapon" and "Siege volume formula" rows (25 DPS) and the Player Overview row (20 DPS).

## The capacity seam the orchestrator must wire to the upgrade system

`WaveDirector` exposes two real (non-test) seams:

```gdscript
func set_player_capacity_provider(provider: Callable) -> void
func set_tower_capacity_provider(provider: Callable) -> void
```

Each `Callable` is expected to take no arguments and return a `float` (the subject's current sheet DPS with upgrades applied). Fallback chain when a provider is not wired (`Callable.is_valid() == false`), checked in this fixed order every time capacity is read:

1. The wired `Callable`, if valid - presumably the upgrade system, called every evaluation tick so it always reflects the live rank.
2. `CombatStats.get_sheet_dps(&"player")` / `(&"tower")`, if `CombatStats.has_reported_sheet_dps()` is true for that subject. `src/combat/auto_weapon.gd` and `src/tower/tower_weapon.gd` already report to this exact autoload on every (re)configure, so this layer already reflects real equip/upgrade state today with **no further wiring needed** - the explicit Callable is an extra override point in case the upgrade system's own source of truth is not itself channeled through `CombatStats`.
3. `player_weapon_definition_fallback` / `tower_weapon_definition_fallback` (`@export`ed `WeaponDefinition` resources, defaulting to `data/weapons/handgun.tres` / `data/tower/base_weapon.tres`), computed via `CombatStats.sheet_dps_from_weapon()` - the same function every real weapon system uses, never a duplicated literal.

Verified by `tests/unit/pressure_test.gd::test_capacity_falls_back_through_provider_then_combat_stats_then_base_weapon`, which exercises all three layers in priority order against one fixed Threat and asserts the exact resulting Pressure value at each layer.

**"Not zeroed while the Console is open"**: `_player_capacity_dps()` / `_tower_capacity_dps()` contain no branch on `PauseAuthority`, pause state, or any Console-related flag at all - by design, not by omission. `test_capacity_is_not_affected_by_an_unrelated_pause_reason` pushes an arbitrary `PauseAuthority` reason mid-test and asserts the computed Pressure value is unchanged. Cross-reference: phase 05's own task table names a "Console non-pause test," i.e. the Console is not expected to pause the simulation at all, which is consistent with this code path needing no special case.

**What the orchestrator must actually do**: call `wave_director.set_player_capacity_provider(...)` / `set_tower_capacity_provider(...)` once the upgrade system exists, if its stat source differs from what `auto_weapon.gd`/`tower_weapon.gd` already report to `CombatStats`. If the upgrade system updates weapon stats by re-calling `AutoWeapon.configure()` / `TowerWeapon.configure()` (which already re-report to `CombatStats`), **no orchestrator action is required at all** - layer 2 already carries it.

## Escalations (NO REGISTER ROW - escalated, and required seams)

1. **`THREAT_DPS_REFERENCE` (10.0) and `PRESSURE_TIME_WINDOW_SECONDS` (20.0)** - NO REGISTER ROW as a schema field. docs/20's own "Pressure Metric constants" struct definition carries only the seven escalation/de-escalation timer fields, not these two formula constants. Kept as cited script constants on `PressureMetric`, matching `wave_director.gd`'s own existing precedent for Register numbers with no schema field (e.g. `HUNT_CAMERA_TOWER_PROXIMITY_PX`). Not invented - both values are transcribed directly from the Register's "Threat formula" and "Pressure formula" rows.
2. **`Pressure` when Capacity <= 0 and Threat > 0** - NO REGISTER ROW. The Register defines "0 with no enemies" (Threat = 0) but not the case where both the player and Tower report zero sheet DPS while enemies are alive. Chosen behaviour: return `0.0` (never divide by zero, never propagate `INF` into the escalation state machine). Documented in `pressure_metric.gd::compute_pressure()`'s own comment; falsifiable only in principle (no clause to remove), tested directly (`test_compute_pressure_with_non_positive_capacity_and_positive_threat_is_the_documented_zero_fallback`).
3. **"Teaching wave" identification** - required schema seam, not implemented in `src/data/**` (out of this task's write scope). `WaveDefinition` has no boolean field marking a wave as teaching. `wave_director.gd` adds `@export var teaching_wave_unique_ids: Array[String] = ["wave_t1","wave_t2","wave_t3","wave_t4"]` (the four real prototype IDs, citing docs/11's own naming of T1-T4 as teaching waves - D91 structural carve-out, not a tunable count) and checks wave membership by `unique_id`. **Required seam for the orchestrator / a future phase**: if `WaveDefinition` ever gains a real `is_teaching_wave` (or similar) field, this list should be replaced by reading that field instead.
4. **Post-draft grace period** - required seam, `notify_draft_closed(now: float)` on `WaveDirector`. The Level-Up Draft system does not exist yet (Phase 05, not this session). This method implements only the Pressure-gating half of the Register's grace-period rule; the "no encounter opens and no spawn group starts" half is a Wave Runtime Model / P2.8-scoped rule this task does not touch. **Required seam for the orchestrator**: wire the future Draft-close signal to call `wave_director.notify_draft_closed(SimClock.now)`. Left uncalled today, so the grace period is always inactive - the documented fallback.
5. **Debug overlay reference** - required seam, `set_debug_overlay_reference(overlay: Node)` / `debug_overlay_path` (NodePath, resolved once against siblings, matching `tower_path`/`camera_path`'s own convention). **Required seam for the orchestrator**: wire this to the real `DebugOverlay` instance in the scene (e.g. from `main.tscn`'s assembly script) so Pressure/state/quadrant actually render during real play; every value is still directly test-readable without it via the `get_..._for_test()` getters.
6. **Interpretation - "the current encounter's next spawn group"**: read as the first spawn group (authored order) with zero emitted spawns so far AND not already escalated once, per `_find_next_pending_group_index()`. A group already mid-emission is not accelerated. Named, not silently assumed.
7. **Interpretation - de-escalation's spawn-interval doubling scope**: applied encounter-wide (every group's due-time computation), not only to whichever group happens to be actively emitting, since the Register says "spawn intervals double" without scoping it to one group. If de-escalation toggles on/off partway through a group's emission, the next pending spawn's wait is recomputed from the existing `wave_open_time + offset + emitted*interval*multiplier` formula (the same structural pattern P2.8 already used), which can produce a discontinuous jump in the very next due-time on the toggle tick itself; documented in `_process_spawn_groups()`'s own comment as a deliberate simplification rather than adding new "time since last spawn" side-state.
8. **Health quadrant display labels** ("BothNormal", "PlayerLow", "TowerLow", "BothLow") are this file's own naming convention - the Register never names these strings, only the two-pool Low/Normal concept ("quadrant" = the 2x2 combination).
9. **"Recorded at every escalation decision"** is read as "every Pressure evaluation tick while active" (i.e., every 0.5 s cadence tick, whether or not it results in an actual escalation or de-escalation transition), since each such tick is where the algorithm decides whether to change state.

## Answer to the plan's open question 1 (quadrant-aware selection)

Implemented as **(a) Telemetry-only, no hook**: the health quadrant is computed and pushed to the debug overlay (`set_health_quadrant()`) and to a test-readable getter; nothing reads it back to influence encounter or spawn selection, and no dormant hook was added. `test_health_quadrant_reports_low_for_either_pool_and_has_no_effect_on_spawn_selection` asserts the Escalation Trigger's behaviour (which group starts next) is identical under a Low quadrant to the quadrant-agnostic escalation test elsewhere in the suite. This was my own implementation choice within the task's explicit framing ("quadrant-aware SELECTION is explicitly OUT"), not something sent to the author as a fresh question, since the task instructions already named the answer as the default one to use for the prototype's own binding brief.

## Falsification table

All mutations made to the **real** tracked resource (`data/encounters/director_configuration.tres`) or the real source file (`src/director/pressure_metric.gd`), run through `tests/run_tests.ps1 -TestPath res://tests/unit/pressure_test.gd`, then restored and diffed.

| # | Mutation | File | Exit code (before restore) | Result | Restored, byte-identical? |
| --- | --- | --- | --- | --- | --- |
| 1 | Tower Seeker intent weight 1.25 -> 1.0 | `data/encounters/director_configuration.tres` | 100 (1 failure: `test_intent_weights_in_director_configuration_match_the_register`) | RED as expected | Yes - `git diff --stat` empty after `cp` restore |
| 2 | `minimum_gap_between_escalations_seconds` 4.0 -> 0.0 | `data/encounters/director_configuration.tres` | 100 (7 failures) | RED as expected | Yes - `git diff --stat` empty |
| 3 | `re_arm_lockout_seconds` 6.0 -> 0.0 | `data/encounters/director_configuration.tres` | 100 (11 failures) | RED as expected | Yes - `git diff --stat` empty |
| 4 | Removed `is_siege` from `_update_de_escalation()`'s Siege/Overtime gate (`if is_siege or is_overtime:` -> `if is_overtime:`) | `src/director/pressure_metric.gd` | 100 (40 failures) | RED as expected | Yes - `diff` against a pre-mutation backup copy (file is untracked/new, so `git diff` does not apply) reported no differences |

All four required mutations turned the suite red; none produced a false green, so none of the four indicate a weak test or dead code by the task's own criterion. `git status --short data/encounters/director_configuration.tres` shows no residual change after restoration; `src/director/pressure_metric.gd` was restored from a byte-for-byte backup copy taken before mutation #4 and diffed clean against it.

Only these four were performed (the task's stated minimum); other clauses (escalation hold time, de-escalation lift threshold, de-escalation expiry, Overtime exclusion, the Siege exclusion for escalation itself) are exercised by named tests but were not separately falsified against the real files, given the task's explicit "at minimum" framing.

## Final test counts and exit codes

`tests/unit/pressure_test.gd` alone, via `tests/run_tests.ps1 -TestPath res://tests/unit/pressure_test.gd`:
- **30 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans. Exit code 0.**
- Engine-error guard (the script's own `ERROR:`/`SCRIPT ERROR:`/`USER ERROR:`/`USER SCRIPT ERROR:` scan over the raw stdout/stderr): clean, zero matches.

Full `tests/unit` regression run (`-TestPath res://tests/unit`), to check for any effect on other suites:
- **460 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans. Exit code 100** (the harness script's own guard correctly reports 100, "at least one assertion failed").
- The one failure is `tests/unit/pickup_merge_cap_test.gd::test_merge_sums_value_into_the_nearest_same_type_neighbour_and_keeps_its_position` ("the oldest Scrap pickup was not removed by the merge cascade"). This is in `src/pickup/**` / `data/pickups/**`, explicitly outside this task's write scope and owned by a different implementer working concurrently this session (confirmed via `git status`: untracked `data/pickups/scrap.tres`, `data/pickups/xp_shard.tres`, `scenes/pickups/`, and modified files across `src/combat/**`, `src/core/**`, `src/tower/**`, `src/player/**`, `src/enemy/**` from other in-progress work this same session). Every other suite, including every P2.8 Wave Director suite (`spawn_ring_test.gd`, `wave_sequence_test.gd`, `wave_determinism_test.gd`, `prototype_wave_integration_test.gd`, `prototype_scene_test.gd`, `main_scene_structure_test.gd`), passed with 0 failures. I did not investigate or touch this failure further - it is not mine to fix and not caused by my diff (`src/director/**` and `tests/unit/pressure_test.gd` only).
- No engine ERROR/SCRIPT ERROR/USER ERROR lines anywhere in the 1700-line raw log; every suite reported 0 orphans.

## Skill conflicts

`godot-prompter:godot-testing` prescribes `test_*.gd` file naming and a `test_` prefix. This project's own convention (CLAUDE.md, this task's own instructions) is `<name>_test.gd` (suffix). Per CLAUDE.md's GodotPrompter section, this project wins; the file was written as `tests/unit/pressure_test.gd` per the task's explicit instruction (which also happens to satisfy the skill's suffix-vs-prefix distinction by coincidence of the word "pressure" - the project convention was followed, not the skill's literal `test_*` prefix form). No other conflict surfaced between `gdscript-advanced`, `math-essentials`, `godot-testing` and this project's docs/20, the Register, or an Author decision; no LEDGER entry was needed.

## Things discovered along the way (not defects in my own deliverable, recorded for completeness)

- **gdUnit4 CLI behaviour under repeated single-suite runs**: while iterating on `pressure_test.gd`, three separate early test-authoring bugs (an escalation test priming its hold timer at the exact moment it asserted escalation instead of accumulating held time first; a re-arm-lockout probe landing exactly on its own boundary; a "boundary oscillation" test whose oscillation amplitude reset the hold timer every single tick, making it vacuously unable to ever escalate) each caused the CLI run of that one file to report noticeably fewer discovered/executed test cases than the file actually contains (e.g. 10/10, then 14/14, then 17/17, before reaching the true 30/30 once every test in the file passed). The full-directory run (`-TestPath res://tests/unit`) did not exhibit this - it ran all 460 cases across all suites in one pass despite one unrelated failure partway through. I did not diagnose the CLI's exact mechanism (it is outside `src/director/**` and this task's scope); it is recorded here so a future single-file test run in this project is not mistaken for "the rest of the file doesn't exist" when a run reports N/N with N less than the file's real test count - rerun after fixing the reported failure to see whether more tests were hidden behind it.
- Every one of those three bugs was a test-authoring bug on my part, not a production-code bug; each is now fixed in the delivered `pressure_test.gd`, and the "negative case alongside every positive one" requirement is satisfied throughout (e.g. escalation firing vs. hold-timer-reset-so-no-fire; de-escalation activating vs. Siege/Overtime suppression; capacity provider vs. its absence).
- A duplicate leak-inducing mistake was made twice in early drafts of `pressure_test.gd`: constructing a `DeathState.new()` (a `Node`, not `RefCounted`) and assigning it only as a plain field on a `Node2D` test double, without also tracking the `DeathState` itself for explicit `.free()` at `after_test()`. This produced 7 orphan-node warnings and a non-zero exit code (101) even though every assertion passed. Fixed by tracking both objects. Recorded because it is exactly the kind of failure mode CLAUDE.md's F03-35 note warns about, though the mechanism here (an untracked field reference, not `remove_child()`) is different from that specific finding.

## What I could not do, and why

- Could not exercise the Overtime exclusion for de-escalation, nor the "In a Siege the Escalation Trigger does nothing" behaviour, through a real end-to-end `WaveDirector` run, because Overtime is not implemented at all (P2.8 deferred it - see `wave_director.gd`'s own header) and no wave in the prototype's own sequence combines "currently in Overtime" with a live `WaveDirector.physics_step()` loop. Both are instead exercised directly against `PressureMetric.update()` with a hand-set `is_overtime`/`is_siege` flag, which the class's pure-`RefCounted` design supports exactly for this reason. This is a scope limitation of the Overtime feature itself (owned by a future phase), not a gap I could close within `src/director/**` this session.
- Did not add a `WaveDefinition.is_teaching_wave` (or similar) schema field, or a `PostDraftGracePeriod`-style dedicated resource - both would require editing `src/data/**`, outside this task's write scope. Both are named as required seams above instead.
- Did not investigate or fix the one unrelated `pickup_merge_cap_test.gd` failure (outside `src/pickup/**`, not my scope).
- Left five stray debug-output text files in the repository root (`scratch_full_run1.txt`, `scratch_pressure_run1.txt` through `scratch_pressure_run5.txt`) from redirecting test-run output to disk while diagnosing the gdUnit4 CLI behaviour above; these should have gone to the scratchpad directory instead and I did not catch the mistake until after they existed. Per this task's hard constraint against deleting any file, I left them in place rather than removing them myself; they are untracked (`git status` shows them as `??`) and contain no code or test content, so they will not be committed unless explicitly staged. Flagging for the orchestrator to remove if desired.

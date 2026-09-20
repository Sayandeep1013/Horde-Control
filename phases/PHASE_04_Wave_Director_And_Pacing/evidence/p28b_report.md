# P2.8b Evidence Report — Wave Director: Stall/Overtime, Priorities, Alive Cap, Siege Scaling

Completes the remainder of P2.8's own Wave Runtime Model that P2.8 deliberately deferred (`phases/PHASE_03_Core_Entities_And_Feel_Check/evidence/p28_report.md`, "Deferred" section, items 2, 3, 6, 8, 11 in part, 7 investigated). Built inside Phase 04. Read in full before starting: `CLAUDE.md`; `phases/README.md` ("Loop rules"); `phases/PHASE_04_Wave_Director_And_Pacing/PLAN.md`; `phases/PHASE_03_.../evidence/p28_report.md`; `docs/11_Wave_Director.md` (Wave Runtime Model, Encounter Budgets, Spawn Rings & Placement, Directional Weighting); `MASTER_SDLC.md` > Provisional Values Register (Spawning & Waves, Encounter Budgets, Pressure & Overtime); `src/director/wave_director.gd` and `src/director/pressure_metric.gd` as they stood after today's P2.9 work.

No agent asserts below that a test, task, or phase is passed, satisfied, or ready. This records what was built and what was observed; reviewers and the author decide.

## GodotPrompter skills consulted

Invoked and followed: `godot-prompter:gdscript-advanced`, `godot-prompter:state-machine`, `godot-prompter:godot-testing`.

- **state-machine**: `WaveDirector.State` stays a 4-member enum FSM (IDLE/WAVE_ACTIVE/GAP/SEQUENCE_COMPLETE), under the skill's own "fewer than 5 states → Enum-Based" threshold. The new encounter-priority queue (`_wave_encounter_queue`/`_wave_encounter_position`/`_encounter_gap_deadline`) is deliberately NOT a second state machine — it is sub-state within `WAVE_ACTIVE`, since promoting it to its own enum would have meant two state machines racing to decide the same "is an encounter open" question. No conflict.
- **gdscript-advanced**: followed the lambda-capture-by-value warning explicitly (shared test state in `Array`s, e.g. `tests/unit/encounter_recovery_test.gd`'s `_heavy_bearings_deg`); no `Object.call(user_string, ...)` metaprogramming was needed; no `@tool` code. No conflict.
- **godot-testing**: same pre-existing conflict as every prior phase (F03-08) — the skill's `test_*.gd` prefix vs. this project's `*_test.gd` suffix. Followed the project. Not a new finding.

## What was built, against each of the six priority items

### 1. The stall check and Overtime (highest priority)

`src/director/wave_director.gd` now implements the Register's real two-branch rule.

- `_stall_check_triggers_overtime(wave, now)`: `_kills_in_last_window(now) < wave.overtime_condition.stall_threshold` (Register > Spawning & Waves > "Wave end / STALLED": "kills in the last 30 seconds, not counting finishers, are below the stall threshold (5)"). `_kills_in_last_window()` prunes a persistent, EventBus-fed `_kill_timestamps` array to the trailing `STALL_WINDOW_SECONDS = 30.0`.
- `_on_enemy_died(entity, position, timestamp)` connects to `EventBus.enemy_died` (real Autoload by default; test-injectable via `set_event_bus_for_test()`, matching `src/pickup/pickup_system.gd`'s own `_connect_enemy_died()` STRING-based `connect("enemy_died", callable)` / `is_connected(...)` convention — the dot-property form (`bus.enemy_died.connect(...)`) does not resolve against a signal a test double adds dynamically via `add_user_signal()`; this was a real engine error hit while writing `tests/unit/wave_runtime_test.gd`, not a theoretical concern). Excludes finisher kills by reading the dying entity's own `is_finisher` flag.
- `_maybe_enter_overtime(wave, encounter, now)`: runs the check exactly once for a non-final wave (Register: "the stall check runs once"); for the final wave, re-runs every `FINAL_WAVE_STALL_RECHECK_INTERVAL_SECONDS = 0.5` s (Register > "Final combat wave rule (C-FINAL)": "the stall check re-runs every 0.5 seconds until Overtime starts" — a DIFFERENT Register row from Pressure's own unrelated 0.5 s cadence, kept as its own named constant rather than reusing `PressureMetric.EVAL_INTERVAL_SECONDS`).
- Teaching waves are exempted (Register > "Teaching wave runtime (C-TEACH)": "they never run the stall rule, Overtime, or escalation") via the existing `_is_teaching_wave()`.
- Overtime finishers: `_process_finisher_spawns()` / `_attempt_finisher_spawn()` spawn Register-cited "2 per 5 s" bursts (`OvertimeCondition.finisher_spawn_rate`) on the view ring (`_resolve_finisher_spawn_placement()` reuses `_ring_for_intent()`, which already routes `PlayerHunter` there), through the SAME `_encounter_cap_blocks_spawn()` and global-cap (`EntitySpawner.spawn_enemy()` null-return) throttle path as an ordinary spawn group — this closes the Phase 04 PLAN.md predetermined risk ("The entity cap being exceeded by Overtime finishers") by construction, not by a second, parallel check.
- A new `data/encounters/player_hunter_finisher.tres` `EnemyDefinition` (25% Hunter health, 160% Hunter speed — see "Escalations" below for the one rounding interpretation), spawned through the SAME `player_hunter_scene` `PackedScene` as an ordinary Hunter, with `is_finisher` and the reduced `definition` set on the fresh instance inside the spawn factory closure, before `EntitySpawner`/`Pool` ever `add_child()`s it (`EnemyController._ready()` reads both synchronously that same call). `src/enemy/enemy_controller.gd` already implemented every downstream consequence of `is_finisher` (no leash timer, exempt from leash reset, flag untouched by `_convert_to_tower_seeker()` so it "survives any conversion") — this task did not need to touch that file.
- "During Overtime no further spawn groups start" is enforced structurally: `_process_wave_active()` calls `_process_finisher_spawns()` INSTEAD of `_process_spawn_groups()` while `_overtime_active` is true, never both.
- `_process_pressure_metric()`'s `is_overtime` argument, hardcoded `false` by P2.9 (Overtime did not exist yet), now reads `_overtime_active` — wiring Register > "De-escalation": "never applies during a Siege or Overtime" for real for the first time.
- Non-final NOT-STALLED ending (survivors carry over) is unchanged from P2.8.
- Overtime's own end for a non-final wave: `_all_non_finisher_enemies_dead()` (global live query, excludes finisher-flagged entities) then `_despawn_remaining_finishers_without_drops()` — routed through `EntitySpawner.despawn_enemy()` directly (deregister + `Pool.release()`), never through `death_state.apply_damage()/kill()`, so no `EventBus.enemy_died` fires and no drop is placed (Register: "remaining finishers despawn without drops"), matching `EnemyController._despawn_due_to_stuck()`'s own established "removal, not a kill" distinction, on WaveDirector's side of the equivalent rule.
- **Discovered and fixed while falsifying this task's own tests, not assumed correct**: the final wave's own ending condition (`live_enemy_count == 0`) is written for a single encounter. Combined with item 2 below (multi-encounter priority queues), a final wave's higher-priority encounter completing can leave the live count at zero for an instant before a queued lower-priority encounter has spawned anything — `_evaluate_wave_state()`'s `is_final` branch now also checks whether another encounter is still queued (`_wave_encounter_position + 1 < _wave_encounter_queue.size()`) before treating a momentary zero as "the wave is done." At exactly one queued encounter (every real prototype wave), this collapses to the original condition, unchanged.

### 2. Encounter priorities and deferred recovery gaps

`_build_priority_sorted_encounter_queue(wave)` resolves a wave's `encounter_sequence` into a priority-descending queue ONCE, at wave open (ties by Unique ID ascending — Encounter Definition Contract's own documented rule). `_wave_encounter_position` indexes the currently-open encounter; `_encounter_gap_deadline` holds the between-encounters gap (Register > "Priorities & recovery gaps": "the lower-priority one waits until the higher-priority one completes plus its recovery gap") — a NEW mechanism, distinct from the pre-existing inter-WAVE `State.GAP`. `_start_encounter_tracking()` (shared by `_open_wave()` and `_advance_to_next_encounter_in_wave()`) resets every per-encounter tracking dictionary and applies Siege scaling (item 4).

A real correctness gap found while building this: `SpawnGroup.start_offset_seconds` is documented as "from encounter open" (Contract Field Semantics; Register > "Spawn group"), not from wave open — P2.8's `_process_spawn_groups()` anchored every group to `_wave_open_time`, which was silently correct only because P2.8's encounters always opened in the same instant as their wave. A new `_encounter_open_time` (set by `_start_encounter_tracking()`) now anchors group scheduling; `_wave_open_time` remains reserved for the wave-level maximum-duration/stall clock, which the Register does define as wave-scoped. For every real prototype wave (encounter opens exactly when its wave does) the two are set in the same tick and this is byte-for-byte unchanged.

Acceptance test built against 10 scripted double-schedules (per this task's own brief, not the 8-wave prototype, since no real wave carries two encounters).

### 3. The encounter-level alive cap

`_encounter_cap_blocks_spawn(encounter)`: `encounter.encounter_alive_cap > 0 and EntityRegistry.get_live_enemy_count() >= encounter.encounter_alive_cap` (Register: "counts ALL living enemies, not just its own spawns... throttles spawning exactly like the global entity cap"). Checked in `_attempt_spawn()` (ordinary spawn groups) and `_attempt_finisher_spawn()` (finishers) — the SAME function, not two copies. `combat_4_siege.tres`'s authored `encounter_alive_cap = 120` is now enforced; nothing in that `.tres` was changed.

### 4. The Siege volume formula, computed against live Tower DPS

`_maybe_scale_siege_spawn_groups(encounter)` reads live Tower DPS through the EXISTING `_tower_capacity_dps()` seam (P2.9's own `set_tower_capacity_provider()` / `CombatStats("tower")` / `tower_weapon_definition_fallback` fallback chain — no new seam was added, this is a second consumer of the same one). A new `siege_multiplier_by_encounter_id` export (`{"combat_2_siege": 1.5, "combat_4_siege": 2.0}`) maps a Siege encounter's Unique ID to its Register-cited multiplier, since `EncounterDefinition` (`src/data/**`, out of this task's write scope) has no field carrying it.

**Gated on `live_dps > base_dps` (strictly greater)**, where `base_dps = CombatStats.sheet_dps_from_weapon(tower_weapon_definition_fallback)` (= 25.0, "base Tower 25 DPS"): at exactly base DPS — this build's own actual current state, since no orchestrator has wired `set_tower_capacity_provider()` to the upgrade system yet — this is a documented no-op and the authored literal counts (43/57 Seekers) are used unchanged. Above base DPS, `seeker_count = ceil(multiplier * live_dps * window_fraction * wave.maximum_duration_seconds / 60.0)`, `hunter_count = round(0.15 * seeker_count)`, applied via a NEW `_group_count_override` dictionary (`_effective_group_count()`) — the shared `.tres` `SpawnGroup.count` field is never mutated (Resources are process-wide cached by `preload()` path; mutating one would leak into every other suite that also preloads it).

**Discovered document inconsistency, named, not silently resolved**: applying the Register's own stated formulas literally to its own worked example (base Tower 25 DPS, 90 s wave, multiplier ×1.5) gives Seeker count `ceil(1.5×25×0.75×90/60) = ceil(42.1875) = 43` (matches the stated "43 Seekers" exactly), but Hunter count `round(0.15×43) = round(6.45) = 6` — **not** the Register's own stated "+7 Hunters" for that same case. The ×2.0/combat_4 case has no such conflict (`ceil(2.0×25×0.75×90/60)=57`, `round(0.15×57)=round(8.55)=9`, matching "+9 Hunters" exactly). Because this method never runs AT exactly base DPS, the inconsistency is not reachable through this code path today; it would resurface only if a future change relaxed the `> base_dps` gate to `>=` or removed it. **Not resolved either way here** — this needs an author/doc-11 decision (which is authoritative: the stated 43/57/7/9 literals, or the stated round()/ceil() formulas?).

**Provider seam the orchestrator must wire**: `WaveDirector.set_tower_capacity_provider(Callable)` (P2.9's own seam) must be pointed at the upgrade system's live Tower DPS once it exists, so BOTH the Pressure Metric's Capacity term and this Siege scaling respond to Caliber ranks together. Nothing in this task wires it; `src/upgrade/upgrade_system.gd` was not read or edited.

### 5. Split Assault test and Hunt test (never built as dedicated suites — P2.8 Deferred item 11)

- `tests/unit/split_assault_test.gd`: 20 generated Split Assaults (varying `run_seed` and group size `n` from 5–24), driven end to end through the real `WaveDirector`/`SpawnGeometry` path. Asserts lane assignment (`ceil(0.6×n)` in the heavier lane by the ACTUAL landed bearing, not by re-calling `SpawnGeometry.split_assault_lane_sequence()`) and centre separation (circular mean of every heavy vs. every light bearing across all 20 scenarios, ≈180° within a 3° sampling-variance tolerance).
- `tests/unit/hunt_test.gd`: (a) the real `combat_1_hunt.tres`/`combat_1.tres` plus two additional generated ratios spawn exactly their own authored per-Enemy-ID counts ("the data-defined intent mix" is the encounter's own spawn groups — every prototype wave's `enemy_intent_mix` field is deliberately unauthored, per `data/waves/t1.tres`'s own comment, so that field is not "the data" here); (b) a REAL Hunt-spawned `scenes/entities/player_hunter.tscn` instance (not a dummy) lands a genuine Hitbox/Hurtbox contact hit on a fake player, using the same real-physics fixture pattern `tests/unit/leash_test.gd`'s own "Mechanism 2" established.

### 6. Off-screen spawn markers — investigated, left unbuilt

Per this task's own brief: build ONLY if docs/11 specifies what a marker renders and where. The complete text is docs/11 > "Spawn Rings & Placement" > "Camera exclusion": *"A spawn marker appears 0.75 seconds before its spawn; the position is rolled and validated when the marker appears and re-validated at spawn — one marker per spawn group per 30° sector, counted as a single telegraph — so the player can read the direction before the enemy arrives."* This specifies timing, validation, and aggregation, never a shape, colour, node type, or screen position. Left unbuilt, named here rather than invented.

## Register citations, by row

| Register row | Landed in |
| --- | --- |
| Spawning & Waves > "Wave end / STALLED" | `_stall_check_triggers_overtime()`, `_maybe_enter_overtime()` |
| Spawning & Waves > "Overtime finishers" | `_process_finisher_spawns()`, `_attempt_finisher_spawn()`, `data/encounters/player_hunter_finisher.tres` |
| Spawning & Waves > "Final combat wave rule (C-FINAL)" | `_maybe_enter_overtime()`'s `is_final` branch (0.5 s re-check), `_evaluate_wave_state()`'s multi-encounter generalisation |
| Spawning & Waves > "Priorities & recovery gaps" | `_build_priority_sorted_encounter_queue()`, `_encounter_gap_deadline` |
| Spawning & Waves > "Encounter-level alive cap" | `_encounter_cap_blocks_spawn()` |
| Spawning & Waves > "Spawn group" (start offset "from encounter open") | new `_encounter_open_time` anchor |
| Encounter Budgets > "Siege volume formula" | `_maybe_scale_siege_spawn_groups()` |
| Encounter Budgets > "Combat wave 1 Hunt", "Combat wave 2 Siege ×1.5" | `tests/unit/hunt_test.gd`, `tests/unit/siege_volume_formula_test.gd` (read the real `.tres`, never restated) |
| Directional weighting > "Split Assault" (C-LANES) | `tests/unit/split_assault_test.gd` |
| Pressure & Overtime > "De-escalation" ("never ... during a Siege or Overtime") | `_process_pressure_metric()`'s `is_overtime` argument now wired to `_overtime_active` |
| Teaching wave runtime (C-TEACH) | `_maybe_enter_overtime()`'s teaching-wave exemption (pre-existing `_is_teaching_wave()`) |

## Escalations

None new (`NO REGISTER ROW` marker). One INTERPRETATION, not an escalation, named explicitly: `player_hunter_finisher.tres`'s `health_band.value = 8`. The Register gives both inputs (25%, and the Hunter's own 30 HP) but `BandedValue.value` is schema-typed `int`, and 25% of 30 is 7.5 — a value the schema cannot store exactly. Rounded to the nearest integer (8, Godot's `round()`) rather than floored (7), since the Register states the two percentages but not a rounding direction for their non-integer product. `movement_profile.speed_multiplier = 1.36` (160% of 0.85) needed no rounding.

## Provider seams the orchestrator must wire

1. `WaveDirector.set_tower_capacity_provider(Callable)` — already P2.9's seam; now also drives Siege sizing (item 4 above). Not wired by this task.
2. Nothing else new. `set_player_capacity_provider()` is unaffected by this task's own work.

## Skill conflicts

None new. `godot-testing`'s `test_*.gd` prefix vs. this project's `*_test.gd` suffix is the same recorded F03-08 conflict, followed per project convention.

## Falsification table

Every mutation below: real source edited, affected suite run, exit code recorded, source restored from a scratchpad-directory backup (`C:\Users\sayan\AppData\Local\Temp\claude\D--Gamedev\...\scratchpad\wave_director_orig*.gd`), byte-identical restoration confirmed via `md5sum` (both sides shown in the session transcript for each of the four).

| # | Mutation (real source) | Suite run | Before | After mutation | Restored byte-identical |
| --- | --- | --- | --- | --- | --- |
| 1 | `_stall_check_triggers_overtime()` returns `true` unconditionally (kill-rate check removed — "every wave stalls") | `wave_runtime_test.gd` | exit 0 (4/4) | **exit 100**, 4 assertion failures in the NOT-STALLED/carry-over test (Overtime wrongly active; state never left WAVE_ACTIVE; survivor not carried the way expected; wave 2 never opened) | Yes (md5 `741147fe...` both sides) |
| 2 | `_attempt_finisher_spawn()`'s `_encounter_cap_blocks_spawn()` check replaced with `if false: return false` (finisher cap throttle removed) | `overtime_test.gd` | exit 0 (5/5) | **exit 100**, 3 assertion failures (encounter's own cap-saturating spawn count read 3 instead of 1 — see note below; 6 finishers spawned instead of 0; live count 7 exceeding the cap of 1) | Yes |
| 3 | The `else` branch that sets `_encounter_gap_deadline` replaced with an unconditional `_advance_to_next_encounter_in_wave()` (recovery-gap deferral removed) | `encounter_recovery_test.gd` | exit 0 (2/2) | **exit 100**, 20 assertion failures — all 10 scripted double-schedules opened the low-priority encounter immediately | Yes |
| 4 | `_base_angle_for()`'s Split Assault `lane_center` fixed to `0.0` regardless of heavy/light (lane separation removed) | `split_assault_test.gd` | exit 0 (1/1) | **exit 100**, 42 assertion failures across all 20 generated scenarios (every spawn landed in one lane; centre separation read ≈0° instead of 180°) | Yes |

Falsification 2's "before" note: the setup assertion inside that same test also moved (3 instead of 1) because, with the throttle gone, finishers spawned into the SAME live-count slot the setup check was reading a tick later than intended in the mutated run — recorded as observed, not further diagnosed, since the point of the falsification (the cap-exceeded failures immediately below it) is unambiguous either way.

A mutation that does NOT turn its test red would mean the test is weak or the clause is dead code; all four here turned their target suite from clean (exit 0) to failing (exit 100) with failure messages naming the exact invariant broken, so none of the four is vacuous.

## Test and check status

`.\tests\run_tests.ps1 -TestPath res://tests/unit` (Windows PowerShell 5.1), after every falsification above was restored:

**544 test cases, 80 suites, 1 engine-channel error line, 3 assertion failures, exit 100.**

The single engine error (`SCRIPT ERROR: Out of bounds get index '4' (on base: 'Array')`) and all 3 assertion failures are ALL inside ONE existing test function, in ONE file NOT owned by this task: `tests/unit/wave_sequence_test.gd :: test_sequence_advances_t1_through_combat_4_in_order_with_the_correct_gaps`. This is not an unrelated concurrent-work failure (the task instructions distinguish "your suites" from suites "other implementers are editing... today" — this one is neither; it is a suite THIS task's own correctly-implemented feature causes to fail) and is not silently accepted:

**Root cause, precisely.** That suite's own header states its fixture: "A lightweight dummy PackedScene (a bare Node2D, no EnemyController) stands in for every enemy scene, so nothing ever fights or dies on its own." Before this task, the stall check did not exist, so every non-final wave always took the unconditional NOT-STALLED branch regardless of combat. With the REAL stall check now built (this task's #1 priority, explicitly instructed), a wave with genuinely zero kills over its full maximum duration is, by the Register's own literal definition, stalled — Overtime correctly starts for `combat_1`/`combat_2`/`combat_3` (real `.tres` data, real `overtime_condition`, `stall_threshold = 5`, zero kills possible with dummy enemies), and the suite's own assumption ("every non-final wave ends on its maximum duration") is no longer true for combat waves. The sequence advances through `wave_combat_1` and then never reaches `wave_combat_2`, so the array-order and gap-timing assertions fail (`Expecting: [...8 waves] but was: [...5 waves]`, `expected the first 7 waves to have ended... but was 4`), and a later index into the now-short `ended` array is what throws the engine error.

This is not something this task can fix without either (a) weakening the real stall-check implementation to stay inert against a fixture the Register itself says should stall — which would make item 1's own acceptance test (and the Overtime test this whole task exists to build) trivially satisfiable by a check that can never actually fire, exactly the "test that could not fail" failure mode this project's own culture forbids — or (b) editing `tests/unit/wave_sequence_test.gd` itself, which is an EXISTING file outside this task's write scope (`tests/unit/**` is scoped to "new test files" only) and belongs to P2.8's own already-closed record. Named here as a genuine, caused interaction requiring a decision, not resolved unilaterally: either that suite's own dummy fixture needs a minimal kill-emitting mechanism (or an authored `stall_threshold` override for its own scripted waves) so it can keep proving gap arithmetic without asserting through a scenario the Register's own stall rule now correctly rejects, or the author accepts this as the expected shape of P2.8's "one branch of a two-branch rule" becoming the real two-branch rule.

Every OTHER suite in the 544 (including all of this task's own 8 new files, and every pre-existing P2.8/P2.9 suite except the one above) passed clean, with the identical result whether run in isolation or as part of the full 544-case run.

## This task's own 8 new test files (all green in isolation and inside the full run)

| File | Cases | Named acceptance test this maps to |
| --- | --- | --- |
| `tests/unit/wave_runtime_test.gd` | 4 | **Wave runtime test** |
| `tests/unit/overtime_test.gd` | 5 | **Overtime test** |
| `tests/unit/encounter_recovery_test.gd` | 2 | **Encounter recovery test** |
| `tests/unit/encounter_alive_cap_test.gd` | 2 | deferral item 8 (encounter-level alive cap) |
| `tests/unit/siege_volume_formula_test.gd` | 2 | deferral item 6 (Siege volume formula, computed) |
| `tests/unit/split_assault_test.gd` | 1 (20 generated scenarios inside it) | **Split Assault test** |
| `tests/unit/hunt_test.gd` | 3 | **Hunt test** |

19 new test cases total (folded into the 544 above).

## Cross-task seams

1. **`set_tower_capacity_provider()` now has two consumers** (Pressure Metric's Capacity term, and Siege sizing) — the orchestrator wiring it once serves both; wiring it to something that reports ABOVE base DPS at combat_2/combat_4's own Siege-open moment will, for the first time, actually change those two waves' spawn counts from the authored literal. Recorded so nobody is surprised the first time a Caliber-equipped run's Siege looks different from the authored `.tres`.
2. **The document inconsistency in the Siege volume formula's own worked Hunter count** (see item 4 above) is unresolved and needs an author/doc-11 decision before this scaling is ever exercised above base DPS in a real run.
3. **`tests/unit/wave_sequence_test.gd`'s own regression**, above, needs a decision (fix the existing suite's fixture, or accept the new failure as correct).

## Anything not done, and why

- Off-screen spawn markers (deferral item 7): docs/11 never specifies what one renders or where — see item 6 above. Nothing built.
- Pickups/drops, boss waves: out of this task's scope (P2.10's own task; boss waves are out of the 8-wave prototype entirely).
- The Siege volume formula is computed but never actually exercised above base DPS by anything in this session (no upgrade-system wiring exists yet) — the formula's own document inconsistency (item 4) is therefore an identified risk, not something this task's own tests could observe against real gameplay data.
- `wave_sequence_test.gd`'s one failing test function was NOT edited (out of write scope) and was not "fixed" by weakening the stall check.

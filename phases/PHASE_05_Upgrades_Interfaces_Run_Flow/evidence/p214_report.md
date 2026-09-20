# P2.14 - Run flow: evidence report

Per MASTER_SDLC.md > Document Control > Gate Approval, nothing below asserts that P2.14, any of its seven named tests, or Phase 05 is passed, satisfied, met, or ready. This records what was built, what was measured, and what was found. Reviewers and the author decide.

## 1. Files created (all new; nothing outside this task's write scope was left modified)

Implementation:
- `src/run/run_flow_controller.gd` - the run-flow controller (state RUNNING/PAUSED/ENDED; focus loss; controller disconnect; `--no-focus-pause`; run end on player death, Tower destruction, or wave-sequence completion; coordinates which of the three menu screens is on top).
- `src/run/paused_choice_bar.gd` - shared horizontal, hold-to-confirm choice row (`HBoxContainer`) reused unmodified by all three menu screens.
- `src/ui/pause_menu.gd` + `scenes/ui/pause_menu.tscn`
- `src/ui/settings_menu.gd` + `scenes/ui/settings_menu.tscn`
- `src/ui/run_end.gd` + `scenes/ui/run_end.tscn`

The three `.tscn` files are thin wrappers (script attached to a bare `CanvasLayer`), matching `scenes/ui/hud.tscn`'s own established convention - the whole tree is built in code in `_ready()`.

Tests (all seven named acceptance tests, plus this report):
- `tests/unit/focus_loss_test.gd` (6 cases)
- `tests/unit/movement_only_test.gd` (3 cases)
- `tests/unit/teaching_siege_tuning_test.gd` (11 cases: 5 no-player seeds, 5 responsive-bot seeds, 1 combined aggregate)
- `tests/unit/scrap_loss_test.gd` (3 cases)
- `tests/unit/hud_layout_check_test.gd` (7 cases)
- `tests/unit/pause_authority_full_test.gd` (3 cases)
- `tests/unit/run_flow_check_test.gd` (4 cases)

No file outside `src/run/**`, `src/ui/pause_menu*.gd`, `src/ui/settings_menu*.gd`, `src/ui/run_end*.gd`, `scenes/ui/pause_menu.tscn`, `scenes/ui/settings_menu.tscn`, `scenes/ui/run_end.tscn`, `tests/unit/*_test.gd`, or this report was edited persistently. Five files outside that scope (`src/run/run_flow_controller.gd` is inside scope; the other four are `src/core/pause_authority.gd`, `src/ui/hud.gd`, `src/ui/console.gd`) were temporarily mutated for falsification and restored - see section 7.

## 2. Architecture summary

`RunFlowController` is the single owner of the run's state and of which of the three menu screens is visible (`UiMode`: NONE / PAUSE / SETTINGS_FROM_PAUSE / SETTINGS_FROM_RUN_END / RUN_END). It is the only caller in this task's own files that pushes/pops `PauseAuthority.REASON_PAUSE_MENU`, `REASON_FOCUS_LOSS`, and `REASON_CONTROLLER_DISCONNECT`; `PauseMenu`, `SettingsMenu`, and `RunEndScreen` never touch `PauseAuthority` or `get_tree().paused` themselves - they only report which option the player picked, mirroring `src/ui/console.gd`'s own "one writer, everyone else reacts" discipline (recorded as the GodotPrompter conflict in section 8).

Tower death is read directly from `TowerHealth.tower_destroyed(timestamp)` (a signal that already exists), never through `EventBus.enemy_died` - the task brief's own instruction, since F03-41 (the Tower's death still emitting `enemy_died`) is a finding this task does not own and does not touch.

Scrap is never cached at the moment `player_died` fires. `_on_player_died()` only calls `call_deferred("_end_run", ...)`; by the time that deferred call runs, every listener connected to `player_died` for that emission - including `RunInventory`'s own zeroing handler - has already run, regardless of which one connected first. `scrap_loss_test.gd` proves this holds in **both** connection orders (a naive cache-at-signal-time implementation passes under one order and fails under the other; see the falsification table).

`REASON_RUN_ENDED` (`&"run_ended"`) is a new, project-local `PauseAuthority` reason, not one of the five canonical ones - `pause_authority.gd`'s own header states any `StringName` is accepted, so this needed no change to that file. Recorded as an interpretation extending the reason vocabulary, not a Register-defined reason.

The Movement-only controls setting lives on `Console.movement_only_controls_enabled` (an existing plain exported bool); `SettingsMenu.set_console_ref()` writes it directly, exactly the call shape `console.gd`'s own header already documents as the intended seam. "Temporary debug persistence" (the task's own wording, no save system) is implemented as a `static var` on `SettingsMenu` remembering the player's last choice for the life of the Godot process only - not disk persistence.

## 3. T4 teaching-Siege measurement (item 6)

`tests/unit/teaching_siege_tuning_test.gd` builds a real harness per seed: the real `scenes/tower.tscn`, a real `WaveDirector` limited to `data/waves/t4.tres` / `data/encounters/t4_siege.tres` (unedited), a real `EntitySpawner`, and the real `scenes/entities/tower_seeker.tscn` / `player_hunter.tscn` scenes, driven through real engine physics frames so melee contact damage resolves through the real Area2D Hitbox/Hurtbox + SimLoop hit-queue path, not a logic-only stand-in. Five fixed seeds per scenario: 4001-4005.

**A cross-task seam had to be closed locally to measure T4 at all**, and it is the most important finding in this section:

> `src/integration/prototype_integration.gd`'s own `_wire_enemies()` calls `EnemyController.set_tower_reference()` only for the three hand-placed enemies from P2.7. Its own header names the gap directly: a Wave-Director-spawned enemy "is NOT reached by this method at all ... named as a required seam ... for whichever task next owns entity_spawner.gd/wave_director.gd's own spawn call sites." `EnemyController._resolve_tower_reference()` has no EntityRegistry fallback (confirmed by reading the file in full) even though the Tower now registers itself under `&"tower"` (F03-39) - that query route was never wired into the enemy side. **The practical consequence: every Tower Seeker the Wave Director spawns in the assembled game today never learns where the Tower is and therefore never targets or attacks it at all.** This is unrelated to T4's own spawn numbers, but it means the real, assembled prototype's T4 cannot threaten the Tower with **any** Seeker count until this is fixed - a Seeker count change alone will not do what this task's tuning target asks for. The test file's own `_wire_spawned_enemy()` closes this gap locally (for its own spawned enemies only, the same pattern `_wire_enemies()` already uses), so the measurement below is actually about T4's spawn **volume**, isolated from this separate, still-open wiring gap.

**Measured result, current authored numbers (Seekers 12 @3s interval 2.0s; Hunters 2 @10s; T4 max 40s), with the wiring gap compensated inside the test only:**

Scenario A - no player, 5 seeds:
```
seed 4001: destroyed=false at t=40.02s, final health=500.0/500.0
seed 4002: destroyed=false at t=40.02s, final health=500.0/500.0
seed 4003: destroyed=false at t=40.02s, final health=500.0/500.0
seed 4004: destroyed=false at t=40.00s, final health=500.0/500.0
seed 4005: destroyed=false at t=40.00s, final health=500.0/500.0
Destroyed in 0 of 5 seeds (target: >= 3 of 5).
```
The Tower ends every seed at **literal, exact full health** (500.0/500.0) - not merely "not destroyed," but never hit even once. This is a much wider miss than a marginal shortfall.

Scenario B - a scripted bot that holds within the Tower's defensive zone and only breaks toward a Seeker already within 400px of itself (see the bot-AI correction below), 5 seeds:
```
seed 4001-4005: final health=500.0/500.0 (100.0%), above 50%=true, distance at 10s=198.2px (within 480px=true)
Above 50% in 5 of 5 seeds (target: 5 of 5); within 480px of the Tower within 10s of the warning in 5 of 5 seeds.
```
This half of the target reads as met, but **it is not strong evidence that a responsive player is what saves the Tower** - Scenario A already shows the Tower is never threatened at all under the current numbers, with or without a player. A "5 of 5 above 50%" result is close to meaningless when the baseline (no player) is already "5 of 5 at 100%."

**A bot-AI defect was found and fixed mid-measurement, named rather than hidden**: the first version of the Scenario B bot always chased whichever live enemy was nearest with no range cap. Tower Seekers spawn on the Tower-centred ring at roughly 1331-1459px from the Tower (Register > "Spawn Rings & Placement"), and while none has yet closed that distance, "nearest enemy" is still a Seeker out on the ring - blindly closing on it pulled the bot **away** from the Tower it was supposed to be defending. Measured: the bot ended up 1336.1px from the Tower at the 10s check, in every one of 5 seeds - almost exactly the ring's own inner radius, and a clean failure of the 480px precondition. Fixed by only engaging a target already within 400px of the player, otherwise holding ~200px from the Tower. Both the broken and fixed runs are real, reproducible measurements; the broken one is not discarded from this report because it is itself informative about how easy it is for a "responsive defender" script (or a real player, chasing threat indicators without discipline) to accidentally abandon the Tower.

**Assertion result**: `test_z_aggregate_both_halves_of_the_t4_tuning_target` is **red** - `destroyed_count` (0) is less than the Register's own `>= 3 of 5` target. This is the one failing test case in the entire 584-case suite run (section 6).

**What this suggests, as a reasoned proposal, not a second verified data point**: the Tower's ranged weapon (25 DPS, 480px range, single target) can apparently intercept and kill every one of 12 Seekers before any of them ever lands a hit, because it starts firing on an approaching Seeker well before that Seeker reaches its own 20px melee reach, and its 2.4s kill time (60 HP / 25 DPS) is close enough to the 2.0s spawn interval that no backlog of simultaneous melee attackers ever forms. Two independent levers exist and were not separately measured here (no budget for a second ~7-minute empirical run per candidate, and this task's brief asks to measure the current numbers, not validate a replacement): (a) raise the Seeker **count** substantially (a linear increase alone may not be enough if the Tower keeps pace indefinitely at any count, since the bottleneck is throughput, not total volume); (b) shorten the spawn **interval** so more Seekers are simultaneously in transit than the Tower's single-target fire rate (1.25 shots/s) can intercept, letting some slip through to melee. **Escalated as a proposal requiring the author's/reviewer's own judgement and, ideally, a follow-up empirical pass once the tower-reference wiring gap above is fixed in the real game** - this report does not touch `data/waves/t4.tres`.

**Falsification of this test's own significance**: the test's real, data-dependent assertions genuinely went red on the actual current numbers rather than trivially passing - itself a form of falsification (an assertion that could not fail would be exactly the vacuous-check anti-pattern this project's `run_tests.ps1` header warns against). A dedicated mutate/restore falsification cycle was not performed on this file given each full run costs ~6-7 minutes; the real red result against real numbers is the evidence offered in its place.

**A known, unresolved imperfection in this test file itself**: `EntitySpawner` pools its enemy instances (`Pool.release()` keeps a despawned instance alive but detached from the tree, matching `tests/unit/prototype_wave_integration_test.gd`'s own documented convention). The harness's `_teardown_harness()` was fixed mid-session to call `spawner.clear_all_for_test()` before freeing its container (cutting orphans from ~160/seed to ~20/seed), but 200 orphan nodes and 5 Godot engine ERROR lines (leaked RIDs) still remain at process exit for this file specifically. The full-suite run's exit code (100, an assertion failure) already reflects a non-usable-run condition independent of this, so it did not change the final verdict, but the root cause of the residual 20/seed was not fully diagnosed - named here rather than left silent.

## 4. Seams the orchestrator must wire in the assembled scene

Ordered by how silent the failure is if skipped.

1. **`RunFlowController` is not instantiated anywhere in `scenes/prototype.tscn`.** Until a node running this script exists in the assembled scene, none of this task's work has any effect at all: no pause menu, no settings menu, no run-end screen, no focus-loss handling, no controller-disconnect handling. The game continues to run exactly as before, with **no error, warning, or visible symptom** - this is the most important seam, and it is completely silent.
2. **`RunFlowController.tower_path` / `wave_director_path` are empty NodePaths with no default**, unlike `PrototypeIntegration`'s own convention of pre-filled defaults (`NodePath("Main/Tower")`, etc.). If left unset: Tower destruction and wave-sequence completion will **never** end the run (only `EventBus.player_died` would, since that connection is automatic). A silent failure - the run just never ends from those two causes. Recommended values, matching `PrototypeIntegration`'s own field defaults: `tower_path = "Main/Tower"`, `wave_director_path = "Main/WaveDirector"`.
3. **`RunFlowController.set_run_inventory(inventory)` must be called once** with the same `RunInventory` instance `PickupSystem`/`DraftController` already hold. If skipped: the run-end screen's Scrap-held field silently reads 0 forever, regardless of how much Scrap was actually collected - a wrong number with no error.
4. **`RunFlowController.set_console_ref(console)` must be called once** with the real `Console` instance, which forwards it to `SettingsMenu`. If skipped: the Movement-only controls toggle in the Settings menu changes its own displayed label but never reaches the real Console, so the setting silently does nothing in play.
5. `WaveDirector` exposes no non-test-suffixed "current wave number" query - only `get_current_wave_index_for_test()`, which this task's own controller uses anyway (the only seam available) for the run-end screen's "wave reached" field. A proper `WaveDirector.get_current_wave_display_index()` (or similar) is a required seam for whoever next owns that file. The same gap means `src/ui/hud_economy_state.gd`'s `wave_current` (which the live HUD's own "Wave n/8" field reads) is never actually driven by the real WaveDirector by anything in this codebase as of this task.
6. The Tower-reference wiring gap named in section 3 (`set_tower_reference()` never called for Wave-Director-spawned enemies in the real game) is not this task's file to fix, but it is a prerequisite for the T4 tuning target to be reachable at all in real play, and is now recorded a second time here since it affects more than T4 (every Siege-type encounter, including combat waves 2 and 4, would show the same symptom).

## 5. Escalations (NO REGISTER ROW)

- **`RunEndScreen`'s background dim opacity (0.75)** - `NO REGISTER ROW - escalated`. The Draft's own 60% dim is a real Register-adjacent figure (docs/19); nothing states a run-end screen's dim. Chosen deeper than the Draft's since the run is over, not merely paused mid-play - a design choice, not a transcribed number.
- **The hold-to-confirm timing reused for the pause/settings/run-end menus (0.3s cycle repeat, 1.0s hold)** is not a fresh escalation - it is the Draft's own two Register-cited numbers (Provisional Values Register > "Progression & Upgrades" > "Draft input"), reused because the Register states no separate figure for a non-Draft paused menu, only that one must exist ("Platform input floor": "every paused menu ... supports hold-to-confirm"). Named as an interpretation in `src/run/paused_choice_bar.gd`'s own header, not restated as an independent literal.
- CanvasLayer indices for the three new screens (18, 19, 21) are not Register numbers, matching `src/ui/hud.gd`'s own established precedent that no Register row assigns them.
- The Scenario B scripted bot's own `ENGAGE_RADIUS_PX` (400) and `HOLD_DISTANCE_FROM_TOWER_PX` (200) in `teaching_siege_tuning_test.gd` are test-harness parameters for a scripted stand-in tester, not gameplay numbers shipped in the game - not escalated as Register violations, but named as interpretations in that file's own comments.

## 6. Final test counts (full suite, `res://tests/unit`, via `tests/run_tests.ps1`)

```
Overall Summary: 584 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 200 orphans
Executed test suites: (87/87)
Executed test cases : (584/584)
Total execution time: 7min 59s
Exit code: 100
ENGINE ERRORS: the Godot engine reported 5 error line(s) during this run (all traced to
teaching_siege_tuning_test.gd's own residual orphan cleanup, section 3 - not from any
other file, and not from the mechanism under test).
FAIL (exit 100): the suite ran; at least one assertion failed under res://tests/unit.
```

The **single** failing test case, across all 584, is `teaching_siege_tuning_test.gd`'s own `test_z_aggregate_both_halves_of_the_t4_tuning_target` - the real, data-driven measurement in section 3. Every other test this task added, and every pre-existing test in the project, passed. No pre-existing test was broken by this task's additions.

The engine-error guard is not clean for this run (5 lines, all attributable to section 3's own named, unresolved orphan-cleanup imperfection) - reported here rather than omitted, per this task's own instruction that a green gdUnit4 summary alone is not evidence.

Per-file counts for the six other named tests (all green, all confirmed via `tests/run_tests.ps1`, never the raw gdUnit4 command):
- `focus_loss_test.gd`: 6/6
- `scrap_loss_test.gd`: 3/3
- `hud_layout_check_test.gd`: 7/7
- `run_flow_check_test.gd`: 4/4
- `movement_only_test.gd`: 3/3
- `pause_authority_full_test.gd`: 3/3

## 7. Falsification table

Every mutation below was applied to the real source, the specific named test was re-run via `tests/run_tests.ps1`, the exit code was recorded, and the file was then restored and confirmed byte-identical (`git diff --stat` for files untouched by the orchestrator's own session; direct re-read plus `grep` for the one in-scope file, `src/run/run_flow_controller.gd`, which the orchestrator's session had already modified before this task and so has no clean git baseline to diff against).

| # | Target behaviour | File mutated | Mutation | Test run | Result before restore | Restored / verified clean |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Focus loss must pause | `src/run/run_flow_controller.gd` | `_on_focus_out()` returns immediately, does nothing | `focus_loss_test.gd` | Exit 100; `test_focus_loss_pauses_immediately_via_push_reason_immediate` FAILED (2 failures); gdUnit4 skipped the rest of the file (this project's own documented behaviour) | Yes - `grep FALSIFICATION` empty |
| 2 | Resume must require confirmation | `src/run/run_flow_controller.gd` | `_notification()` also pops `REASON_FOCUS_LOSS` on `NOTIFICATION_APPLICATION_FOCUS_IN` | `focus_loss_test.gd` (a new test, `test_regaining_focus_alone_does_not_resume`, was added first, since the existing suite never drove a real FOCUS_IN notification) | Exit 100; the new test FAILED (2 failures); the two earlier tests still passed | Yes - `grep FALSIFICATION` empty |
| 3 | Run-end Scrap must read the zeroed value, not a cached one | `src/run/run_flow_controller.gd` | `_on_player_died()` caches `RunInventory.scrap_current` synchronously at signal time; `_build_summary()` reads the cache | `scrap_loss_test.gd` | Exit 100; specifically `test_scrap_reads_zero_on_run_end_screen_when_controller_connects_first` FAILED (the ordering the naive cache gets wrong), while the other connection-order test still passed - demonstrating why both orders were tested | Yes - `grep FALSIFICATION` empty |
| 4 | Pause must actually freeze an enemy | `src/core/pause_authority.gd` | `_apply_paused_state()`'s `should_pause` forced to `false` unconditionally | `pause_authority_full_test.gd` | Exit 100; first sub-test FAILED with 6 assertion failures (tree never paused; nothing frozen); rest of file skipped | Yes - `git diff --stat` empty |
| 5 | A HUD element must not render off-screen | `src/ui/hud.gd` | XP field's `margin_bottom` changed 16 -> 2000 (the F03-20 defect class) | `hud_layout_check_test.gd` | Exit 100; exactly `test_xp_bar_sits_at_the_bottom_with_level_and_rerolls` FAILED; the other six cases (including the top-left/top-centre/top-right checks) stayed green | Yes - `grep FALSIFICATION` empty; `margin_bottom` confirmed back at 16 |
| 6 (bonus, beyond the required minimum) | Movement-only setting must actually gate sector purchases | `src/ui/console.gd` | The `movement_only_controls_enabled` check on the sector-purchase gate removed | `movement_only_test.gd` | Exit 100; exactly `test_movement_only_off_standing_beside_the_tower_for_sixty_seconds_buys_nothing` FAILED; the "on" test and the Draft test stayed green | Yes - `grep FALSIFICATION` empty |

No mutation failed to turn its target test red - every falsification listed above produced the expected failure, so none of the seven named tests is reported here as vacuous or dead-code-covering.

`teaching_siege_tuning_test.gd` itself was not put through a dedicated mutate/restore cycle (each full run costs ~6-7 minutes; see section 3 for why its own real red result against the real current numbers is offered as evidence in its place, and section 9 for what remains untested as a result).

## 8. Skill conflicts recorded (CLAUDE.md > GodotPrompter)

- `godot-ui`'s own checklist: "Pause menu root Control has `process_mode = PROCESS_MODE_ALWAYS`" together with its worked pause-menu example, which pauses by writing `get_tree().paused = true` directly. This project's binding rule (`docs/20` > "Communication, commands"; `pause_authority.gd`'s own header: "The ONLY writer of `get_tree().paused` anywhere in this project") wins: none of `PauseMenu`, `SettingsMenu`, `RunEndScreen`, or `PausedChoiceBar` ever write `get_tree().paused`; only `RunFlowController` pushes/pops `PauseAuthority` reasons. Recorded in `src/run/paused_choice_bar.gd`'s and `src/ui/pause_menu.gd`'s own headers as well as here.
- `godot-ui`'s "Common UI Patterns" pause-menu example is a centred `VBoxContainer` of stacked buttons; the Register's own "Platform input floor" requires every paused menu to lay its choices out **horizontally**. This project's document wins; `PausedChoiceBar` is an `HBoxContainer`.

## 9. Movement-only test: clauses a script cannot cover

`movement_only_test.gd` proves the **mechanical rule** in both directions: the movement-only cycle-and-hold-to-confirm path resolves a real Draft (three separate level-ups, never touching `confirm`/`draft_select_*`/`reroll`/`draft_cycle_*`), a Movement-only sector purchase completes from position and standing still alone with zero discrete input calls of any kind, and with the setting off across a full 60 simulated seconds of standing still, nothing is spent. What it cannot cover, named plainly:
- "An internal tester" names a **human** play session across a run whose level-ups arise from genuine XP earned through real combat, not three scripted `credit_xp()` calls.
- Genuine reflexive movement-only **play feel** - whether a real person finds the movement-only path comfortable or discoverable - is not something a script can measure at all.
- The Console's own dwell/channel timing was driven by a manually-advanced fake `SimClock` for determinism (matching `tests/unit/console_rules_test.gd`'s own established pattern), not by real engine frame pacing; the *rule* is proven exactly, but real-world frame-time jitter interacting with the dwell timers is not exercised here.

## 10. Falsification of the focus-loss/pause-authority OS-level delivery

`focus_loss_test.gd` drives `simulate_focus_out_for_test()` / `simulate_controller_disconnected_for_test()` / `simulate_pause_pressed_for_test()`, which call the exact same private handlers the real `NOTIFICATION_APPLICATION_FOCUS_OUT` notification and `Input.joy_connection_changed` signal call - proving the handler logic, not the OS's actual delivery of either event, which no in-process gdUnit4 run can trigger. The flag-parsing logic itself (`RunFlowController._flag_present()`) is a pure static function, tested directly against constructed `PackedStringArray` values, for the same reason - `OS.get_cmdline_user_args()`/`get_cmdline_args()` cannot be given a second, differently-flagged process launch from inside the same test run. `OS.get_cmdline_user_args()` was chosen as the primary read (with `OS.get_cmdline_args()` as a fallback, matching the task's own "which did you use and why" instruction) because it is the documented channel for game-specific flags placed after `--` when launching the exported binary, keeping the harness flag decoupled from Godot's own engine argument surface; the fallback covers an invocation that omits the `--` separator.

## 11. What could not be done, and why

- The T4 tuning target's own second half (Scenario B) is only weakly informative under the current numbers, since Scenario A already shows the Tower untouched with no player at all - noted plainly in section 3 rather than reported as a clean pass.
- No second empirical run against a candidate replacement Seeker count/interval was performed (budget: each full run costs ~6-7 minutes of real wall-clock time; ten seeds x two candidate configurations would cost another ~15-20 minutes at minimum). The proposal in section 3 is reasoned, not independently verified, and is named as such.
- The residual 200-orphan/5-engine-error imperfection in `teaching_siege_tuning_test.gd`'s own teardown (section 3) was reduced but not eliminated; its exact remaining cause was not tracked down further.
- `Engine.time_scale` was tried as a way to speed up the T4 suite's real wall-clock cost and measured to have no effect (Godot's fixed-step physics dispatches one `physics_frame` per real engine frame regardless of `time_scale`); recorded as a dead end in the test file's own header rather than silently dropped.

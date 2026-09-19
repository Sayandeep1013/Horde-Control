# P2.1 — Player Controller — Evidence Report

Per MASTER_SDLC.md > Document Control > Gate Approval, this report does not state that any test, gate, or this task is passed, satisfied, met, or ready. It records what was built, what each test checks, the commands run, their exit codes, and the falsification logs. Determinations belong to the reviewers and the author.

## GodotPrompter skills invoked first

`godot-prompter:player-controller` and `godot-prompter:input-handling` (required by the task), plus `godot-prompter:tween-animation` and `godot-prompter:godot-testing` (CLAUDE.md: "check for a matching godot-prompter:* skill and invoke it first" applies to the animation and test-authoring work this task also does).

No conflict with docs/20, the Provisional Values Register, or an Author decision was found in the technical guidance itself. Two points worth recording as minor deviations from the skills' generic idiom, not conflicts with project rules:

1. `player-controller`'s top-down example does not set `motion_mode`. This controller sets `motion_mode = CharacterBody2D.MOTION_MODE_FLOATING` (`src/player/player.gd`), the documented Godot practice for a top-down game with no floor/gravity concept — an improvement on the skill's minimal example, not a contradiction of it.
2. `godot-testing`'s naming convention is `test_*.gd` (prefix). Every existing suite in this repository (`combat_stats_test.gd`, `hitbox_hurtbox_test.gd`, etc.) uses `*_test.gd` (suffix) instead, and gdUnit4 discovers them correctly either way. This task's five new suites follow the project's own established suffix convention, not the skill's. **This is a real, if minor, skill-vs-project convention conflict, and CLAUDE.md says it belongs in the phase LEDGER; this task's allowed write paths do not include `phases/PHASE_03_Core_Entities_And_Feel_Check/LEDGER.md`, so it is recorded here instead and the orchestrator/reviewer is asked to copy it into the LEDGER.**

## Files created

- `data/player/prototype.tres` — the authored `PlayerDefinition` resource (below).
- `src/player/player.gd` — `class_name Player extends CharacterBody2D`, the controller.
- `src/player/collector.gd` — `class_name PlayerCollector extends Area2D`.
- `src/player/player_animator.gd` — `class_name PlayerAnimator extends Node2D`, the code-driven cosmetic animation.
- `scenes/player.tscn` — `Player` (`CharacterBody2D`) → `BodyShape`, `Hurtbox` (`src/combat/hurtbox.gd`, faction `PLAYER`) → `HurtboxShape`, `Collector` → `CollectorShape`, `DeathState` (`src/combat/death_state.gd`), `Visuals` (`player_animator.gd`) → `Sprite2D` (`assets/sprites/player.png`).
- `tests/unit/player_movement_test.gd`, `player_input_buffer_test.gd`, `player_scene_test.gd`, `player_silhouette_test.gd`, `player_animation_test.gd`.

## Provisional Values Register citations, and where each is read from

All from MASTER_SDLC.md > Provisional Values Register > **Player & Weapons**, cited by row, never restated as a bare literal in `player.gd`'s logic — every one is read from `definition` (`PlayerDefinition`, `data/player/prototype.tres`) at `_ready()`/`_apply_definition()`:

| Register row | Value | Where authored | Where read |
| --- | --- | --- | --- |
| "Player health / speed / accel / stop" | 100 HP; 320 px/s; full speed 0.08 s; stop 0.05 s | `prototype.tres`: `max_health=100`, `base_speed_px_per_second=320.0`, `acceleration_time_seconds=0.08`, `deceleration_time_seconds=0.05` | `player.gd::_apply_definition()` derives `_acceleration_rate_px_per_s2 = base_speed/accel_time` (4000 px/s²) and `_deceleration_rate_px_per_s2 = base_speed/decel_time` (6400 px/s²); `death_state.max_hp = definition.max_health` |
| "Player body / hurtbox / collector / magnet" | body radius 14; hurtbox = body; collector radius 22 (body+8); magnet radius 96 | `prototype.tres`: `body_radius_px=14`, `hurtbox_definition=0` (SameAsBody), `collector_area_radius_px=22`, `magnet_radius_px=96` | `_apply_definition()` writes `body_radius_px` onto `BodyShape`'s `CircleShape2D.radius` and (SameAsBody) the same value onto `HurtboxShape`'s; `collector_area_radius_px` onto `CollectorShape`'s. `magnet_radius_px` is authored but **not consumed by this controller** — it exists on the contract for the future pickup/magnet system (docs 16, P2.8), out of this task's scope (movement/hurtbox/input-buffer/contact-damage/death only, per PLAN.md's P2.1 Inputs line) |
| "Input buffer" | 100 ms (6 ticks), cleared on pause | `prototype.tres`: nested `InputBufferDuration` sub-resource, `duration_ms=100.0`, `ticks=6` | `_apply_definition()`: `_buffer_duration_seconds = definition.input_buffer.duration_ms / 1000.0` |
| "Readability" (draw order z_index) | "... player 50 ..." | Not a `PlayerDefinition` contract field (no Register-driven field exists for it) — set directly: `z_index = 50` in `player.gd::_ready()`, cited by comment | `player.gd::_ready()` |

`docs/20_Technical_Architecture.md` > Physics & Collisions > Collision Layers table, applied via the existing `src/combat/collision_layers.gd` constants (not restated as raw ints): `LAYER_PLAYER_BODY`/`MASK_PLAYER_BODY` on the body, `LAYER_PLAYER_HURTBOX` (mask 0) on `Hurtbox`, `LAYER_PLAYER_COLLECTOR`/`MASK_PLAYER_COLLECTOR` on `Collector`.

`docs/20` > Global Simulation Authority > "movers multiply their velocity by SimClock.time_scale before moving": implemented literally — `velocity = _local_velocity * SimClock.time_scale` immediately before `move_and_slide()`; the unscaled `_local_velocity` accumulator is never itself multiplied, so a scale can't compound tick over tick (tested: `player_movement_test.gd::test_velocity_handed_to_move_and_slide_is_scaled_by_sim_clock_time_scale`).

## `data/player/prototype.tres`

Authored from `src/data/player_definition.gd`'s contract. Full content:

```
unique_id = "player_prototype"
max_health = 100
base_speed_px_per_second = 320.0
acceleration_time_seconds = 0.08
deceleration_time_seconds = 0.05
body_radius_px = 14
hurtbox_definition = 0  # SameAsBody, the enum's only member
collector_area_radius_px = 22
magnet_radius_px = 96
input_buffer = { duration_ms = 100.0, ticks = 6 }
starting_weapon_reference_id = "handgun_prototype"
```

**Named, not silently resolved**: `starting_weapon_reference_id` is a provisional string. P2.3 (Handgun and auto-targeting) is a parallel, not-yet-complete task that owns `data/weapons/handgun.tres` and its real `unique_id`. `"handgun_prototype"` is this task's best guess at what that ID will be; if P2.3 authors a different `unique_id`, this field needs a one-line update to match. Out of this task's write scope (`data/weapons/**` is not in this task's allowed paths) to resolve any further than flagging it.

## Design decisions named, not silently resolved

### 1. SimLoop / `scenes/main.tscn` wiring gap
`docs/20` > "SimLoop order" assigns step 1 (input) and step 2 (player movement) to this controller, and `src/core/sim_loop.gd`'s own header states "entities do not run their own gameplay `_physics_process`". `sim_loop.gd`'s step 2 is still an empty stub commented "P2.1", and `scenes/main.tscn` has no `Player` node (confirmed by the pre-existing `tests/unit/main_scene_structure_test.gd::test_player_would_not_be_placed_inside_entities_container`, whose own comment reads "No Player node exists yet (P2.1)"). Both files are outside this task's allowed write paths (`src/core/`, `scenes/main.tscn`), and P2.2/P2.4 — the two other tasks touching the gameplay root in parallel — do not own `sim_loop.gd` either. **This task cannot perform that wiring.** The controller therefore drives its own per-tick logic via `_physics_process()` by default; a `driven_externally` export (default `false`) exists so a future SimLoop integration task can call `physics_step(delta)` directly instead and flip that flag to stop the local double-drive. Recorded in `player.gd`'s own header comment as well.

### 2. Input buffer does not feed back into the movement curve
The Register's own text — "A 100 millisecond ... input buffer is permitted for dashes and directional changes. If the player presses dash slightly before a cooldown ends ... it queues" — describes a **queue-ahead** pattern for a gated, discrete action. Dash and phase movement are explicitly excluded from this task (PLAN.md's P2.1 row: "dash and weapons excluded"), and plain directional movement has no cooldown/gate for a press to queue against: `Input.get_vector()` polling every physics tick cannot "eat" a held direction the way a discrete `is_action_just_pressed()` check at a low tick rate can. Feeding the buffered direction back into movement after a real key release would read as unwanted coasting, contradicting "Base movement must feel responsive with minimal acceleration ramp" (Movement Design & Input Buffering, paragraph 1). The buffer is implemented as real, running, Register-timed, pause-cleared state (`get_buffered_movement_direction()`, a typed query) for a future Dash system to consume, without altering this task's own acceleration/deceleration curve. Tested explicitly: `player_input_buffer_test.gd::test_buffer_does_not_reintroduce_movement_after_release`.

### 3. DeathState's `EventBus.emit_enemy_died()` fires on player death too
`src/combat/death_state.gd::_enter_logical_death()` unconditionally calls `EventBus.emit_enemy_died(entity, position)` — there is no `EventBus.emit_player_died()` (or equivalent) to call instead; `EventBus`'s own header states new signals are added "as the systems that own that state are built," and no later phase has added one yet. Reusing `DeathState` for the player (an explicit P2.1 dependency: "The ... Logical/Visual death state machine (P1.5 deliverable) exist[s] for the player's hurtbox") therefore means a player's Logical Death will broadcast on the `enemy_died` signal, semantically mislabelling the event. `src/core/event_bus.gd` is outside this task's write scope. **Named here, not resolved**: a future task that owns `src/core/` should add a dedicated player-death signal.

### 4. `reset_for_reuse()` used to resync `DeathState.max_hp`
`DeathState._ready()` (a child) runs before `Player._ready()` (the parent) under Godot's bottom-up ready order, so it sets `current_hp = max_hp` from its own framework default (30.0) before this controller ever gets a chance to overwrite `max_hp` from the Register. `_apply_definition()` sets `death_state.max_hp = definition.max_health` and then calls `death_state.reset_for_reuse()` — the framework's own public re-initialize entry point — rather than writing `current_hp` directly (`docs/20` > Communication, commands: writing another system's fields directly is banned even through a bare setter). Tested: `player_scene_test.gd::test_death_state_max_hp_and_current_hp_come_from_definition`.

### 5. z_index has no contract field
The Register's "player 50" draw-order value has no home on the `PlayerDefinition` Content Data Contract (no z_index field exists on it, and none should be invented without a Register-authored source). It is set as a plain literal in `player.gd::_ready()`, cited by comment to the Register row rather than read from a resource.

## Animation approach and pause-safety (`src/player/player_animator.gd`)

No `AnimationPlayer`/`AnimationTree` exists (the player has one static sprite, decision D99) — every effect is a procedural transform/modulate change, driven once per physics tick by `update_visuals()`, which `player.gd::physics_step()` calls itself (one driver per entity, matching `sim_loop.gd`'s "entities do not run their own gameplay `_physics_process`" spirit locally — the animator itself has no `_physics_process`).

- **Idle bob**: `sin(SimClock.now * frequency * TAU) * amplitude`, faded out as speed rises so it never fights active movement. Reads `SimClock.now` (never a raw `elapsed += delta` counter), matching the project's simulation-time convention (`SimClock`'s own header; `death_state.gd`'s Visual Death timer does the same).
- **Squash-and-stretch**: reacts to the *acceleration* this tick (`local_velocity - previous_local_velocity`), projected onto the previous tick's travel direction (or the new direction, if starting from rest) — stretch on speeding up, squash on stopping, settling to neutral at a steady cruise. Hand-rolled `lerp` smoothing each tick, no tween.
- **Lean**: horizontal velocity ratio, clamped to a configured max angle, same smoothing.
- **Hit flash**: the one genuinely discrete, one-shot effect — `Node.create_tween()` (bare, self-bound), exactly the case MASTER_SDLC.md's Global Simulation Authority carves out ("`Node.create_tween()` is permitted for cosmetic animation only, since a tween bound to a paused node pauses with it"). `tools/checks/banned_api_check.sh` confirms no `get_tree().create_tween()`/`get_tree().create_timer()` call exists in `src/player/**` (see "Banned-API check" below).

**Pause-safety**: the three continuous effects only ever run from inside `player.gd`'s own `_physics_process()`, which the engine itself does not call while the tree is paused (`Player` is `PROCESS_MODE_PAUSABLE`) — no extra guard code needed, verified end-to-end through a real `PauseAuthority.push_reason()`/`flush()` pause in `player_animation_test.gd::test_continuous_effects_freeze_while_the_player_is_paused`. The hit-flash tween is bound to the `Visuals` node (a `PROCESS_MODE_PAUSABLE`-inheriting child of `Player`), so its default pause mode (`TWEEN_PAUSE_BOUND`) freezes it too.

**A real bug this animation testing caught and fixed**: the original squash/stretch code computed "acceleration along motion" using `local_velocity`'s own direction as the projection axis, with a fallback to `accel_this_tick.length()` (always non-negative) when `local_velocity` was ~zero. At the exact tick a stop reaches zero velocity, that fallback fired and read every stop as a *stretch* instead of a *squash* — caught by `player_animation_test.gd::test_squashes_when_stopping`, fixed by projecting onto the *previous* tick's travel direction instead (see the file's own comment for the full reasoning).

## Acceptance tests

### Player movement check

MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests. PLAN.md's own exit criterion: "Movement-only run through an empty arena at reference speed and acceleration."

Covered by `tests/unit/player_movement_test.gd` (7 tests): acceleration curve (multiple sampled ticks, not just top speed), deceleration curve to exactly 0 in exactly 3 ticks (0.05 s), eight-direction diagonal cap at reference speed (not `sqrt(2)×`), `SimClock.time_scale` multiply-before-move, a positive control using the real `move_right` InputMap action (not the test override), and `EntityRegistry` registration/position-sync (the READ list's own instruction: "register the player").

Command:
```
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/player_movement_test.gd --ignoreHeadlessMode
```
Result (final, after fixes and falsifications restored): `7 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0.

**Falsification 1 — instant snap.** Temporarily replaced `_local_velocity = _local_velocity.move_toward(target_velocity, rate * delta)` with `_local_velocity = target_velocity` (no ramp) in `player.gd`. Re-ran the suite: `test_accelerates_along_a_linear_curve_not_an_instant_snap` FAILED (`1 test cases | 0 errors | 5 failures`; per LEDGER F02-08, one failure stops the rest of that suite file, so only that one test ran). Restored the file (`diff` confirmed byte-identical to the pre-falsification copy), re-ran: `7 test cases | 0 errors | 0 failures`, exit 0.

**Falsification 2 — wrong Register value.** Temporarily hardcoded both `_acceleration_rate_px_per_s2` and `_deceleration_rate_px_per_s2` to `base_speed / 0.5` (ignoring `definition.acceleration_time_seconds`/`deceleration_time_seconds`, i.e. simulating a value that drifted from, or never read, the Register row). Re-ran: `test_accelerates_along_a_linear_curve_not_an_instant_snap` FAILED (`1 test cases | 0 errors | 3 failures`). Restored, re-ran: `7 test cases | 0 errors | 0 failures`, exit 0.

### Player silhouette test

MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests. **PLAN.md itself scopes this task's version of the test**: "P2.1 render-order result (player above enemies when surrounded)" — distinct from the full human-tester distinguishability probe the Acceptance Test Matrix runs later at P2.16.

Covered by `tests/unit/player_silhouette_test.gd` (5 tests): sprite/silhouette assets exist and load; the silhouette is not blank; the silhouette's coarse 8×8 alpha-grid shape is measurably distinct from each of the three enemy silhouettes (going beyond PLAN.md's minimum scope); `z_index` (50) exceeds the Register's enemy `z_index` (20); and a concrete "surrounded" simulation — enemies placed both above and below the player's Y position inside a `y_sort_enabled` container (mirroring `scenes/main.tscn`'s real `Entities`), the player kept as a sibling outside it — confirming `z_index` (which is what actually governs Godot's canvas draw order across different parents) still wins regardless of relative Y.

Command:
```
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/player_silhouette_test.gd --ignoreHeadlessMode
```
Result: `5 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, exit 0.

**Falsification 1 — wrong z_index.** Temporarily changed `z_index = 50` to `z_index = 10` (below the enemy z_index) in `player.gd`. Re-ran: `test_player_z_index_is_above_the_register_enemy_z_index` FAILED (`4 test cases | 0 errors | 1 failures`), and separately `player_scene_test.gd::test_player_z_index_matches_register_readability_row` FAILED too (`2 test cases | 0 errors | 1 failures`). Restored, re-ran both: green.

**Falsification 2 — identical-shape check.** Temporarily changed the distinctness test to compare the player silhouette against **itself** (`PLAYER_SILHOUETTE_PATH` in place of the enemy path) instead of an enemy's. Re-ran: `test_player_silhouette_is_shape_distinct_from_each_enemy_silhouette` FAILED (distance 0, correctly below the threshold) (`3 test cases | 0 errors | 3 failures`). Restored (`diff` confirmed byte-identical), re-ran: `5 test cases | 0 errors | 0 failures`, exit 0.

Also verified, once during development and fixed: an original `Image.load("res://...png")` call on an imported PNG printed an engine `WARNING: Loaded resource as image file, this will not work on export`. Not an `ERROR` (does not trip `run_tests.ps1`'s Guard 4), but avoidable — replaced with `load(path) as Texture2D` → `.get_image()`, the correct route through the import pipeline. Confirmed the warning no longer appears in the final full-suite run.

## `--import` and full-suite gdUnit4 run (final)

```
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```
Exit 0, no errors.

```
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
```
Final result: **245 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans**, exit 0. This is the **new total** (up from the 172 already-passing baseline this task was told not to break). Per-suite breakdown for this task's five new files, each independently green:

| Suite | Test cases | Errors | Failures |
| --- | --- | --- | --- |
| `player_movement_test.gd` | 7 | 0 | 0 |
| `player_input_buffer_test.gd` | 8 | 0 | 0 |
| `player_scene_test.gd` | 13 | 0 | 0 |
| `player_silhouette_test.gd` | 5 | 0 | 0 |
| `player_animation_test.gd` | 13 | 0 | 0 |
| **Total new** | **46** | **0** | **0** |

**Contradiction noted, not caused by this task**: three other implementers' test files ran concurrently in the same working directory throughout this session (`src/camera/`, `src/tower/`, `scenes/arena.tscn`, `scenes/tower.tscn`, their tests — all outside this task's write scope, per the hard constraints). At one point during this session, running the full suite showed `tower_same_frame_death_test.gd` and `tower_weapon_test.gd` failing; `tower_same_frame_death_test.gd`'s failure was independently confirmed to reproduce identically when run in complete isolation (not caused by cross-suite pollution from any of this task's tests), and both files are entirely about Tower fixtures (`tower.hurtbox`, `TowerScene`) with no player-specific assertion involved. By the final run above, both had gone green on their own (the parallel implementer's own work), and the whole suite passed with zero failures. This is recorded for the timeline's honesty, not as something this task caused or fixed.

## `tests/run_tests.ps1` (the engine-error guard)

Task instruction: "A green gdUnit4 summary is no longer sufficient evidence" (LEDGER F02-14).

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit
```
Final result: import pass clean, suite `245 test cases | 0 errors | 0 failures`, **no `ENGINE ERRORS:` block printed** (the guard's own positive scan for `^(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR):` lines found nothing), `PASS (exit 0): 245 test case(s) executed under res://tests/unit, all passed.` Full console output saved to `reports/run_tests_ps1_final.txt` (outside this task's cited evidence paths but left as a local artifact of the run, not committed content this report depends on beyond what is quoted here).

Also run scoped to a single file for an unambiguous, minimal-noise artifact:
```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/player_movement_test.gd
```
`PASS (exit 0): 7 test case(s) executed under res://tests/unit/player_movement_test.gd, all passed.`

## Banned-API check

`tools/checks/banned_api_check.sh` (P1.1 deliverable, not owned by this task, run only):
```
bash tools/checks/banned_api_check.sh
```
Result: **FAIL**, one match — `src/tower/tower_visuals.gd:10`, a comment sentence containing the literal text `get_tree().create_tween()` as documentation of what is banned (the same kind of false positive this task's own `player_animator.gd` comment originally tripped, found and reworded during this task so the grep's textual pattern no longer matches it — see "Animation approach" above). `src/tower/tower_visuals.gd` is outside this task's write scope (`src/tower/`).

Scoped check confirming this task's own files are clean:
```
grep -rnE 'get_tree\(\)\s*\.\s*create_tween\s*\(|get_tree\(\)\s*\.\s*create_timer\s*\(' --include='*.gd' src/player scenes/player.tscn
```
Zero matches (grep exit 1).

## Summary for the caller

- Files created: `data/player/prototype.tres`; `src/player/player.gd`, `collector.gd`, `player_animator.gd`; `scenes/player.tscn`; five test files under `tests/unit/`.
- Both acceptance tests (Player movement check, Player silhouette test) each falsified two ways, restored, and re-confirmed green.
- New gdUnit4 total: **245 test cases, 0 errors, 0 failures** (up from the 172-test baseline; this task's own contribution is 46 tests, all green).
- `run_tests.ps1` (the engine-error guard): **PASS, exit 0**, no engine errors detected anywhere in the suite.
- Named, not silently resolved: (1) the SimLoop/`scenes/main.tscn` wiring gap this task cannot close from within its own write scope; (2) the input buffer's deliberate non-participation in the movement curve, given Dash's absence; (3) `DeathState` broadcasting the player's death on the `enemy_died` EventBus signal, for lack of a player-specific one; (4) the `godot-testing` skill's `test_*.gd` naming convention vs. this project's established `*_test.gd` convention — CLAUDE.md asks for a LEDGER row for this, which this task cannot write itself (see "GodotPrompter skills invoked first").
- `starting_weapon_reference_id` on `data/player/prototype.tres` is a provisional guess (`"handgun_prototype"`) pending P2.3's actual authored weapon ID.

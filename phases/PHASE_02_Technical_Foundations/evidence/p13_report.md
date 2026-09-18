# P1.3 evidence report — Object pools and all six entity caps

Deliverables: `src/core/pool.gd`, `src/core/entity_caps.gd`, `src/core/entity_spawner.gd`, `scenes/main.tscn`, `tests/unit/pool_test.gd`, `tests/unit/entity_cap_test.gd`, `tests/unit/main_scene_structure_test.gd`.

Skills invoked first, per CLAUDE.md: `godot-prompter:scene-organization` and `godot-prompter:gdscript-advanced`, both before any code was written. No conflict found with docs/20, the Provisional Values Register, or an Author decision. `scene-organization`'s container/grouping guidance (plain `Node`/`Node2D` containers for pool ownership, signals-up/commands-down/EventBus-sideways) matches docs/20's Scene Tree bullet directly. `gdscript-advanced` informed two implementation choices directly: the Godot 4.7 "packed-array property setters skip element writes" pitfall (not applicable here — `pool.gd` never mutates a packed array property element-by-element) and the general preference for `class_name` over ad hoc autoload-style singletons for a reusable, non-singleton utility class, which is why `Pool` and `EntityCaps` are given `class_name` rather than being referenced only by `preload()`.

## 1. Scene tree as built, against docs/20's Scene Tree list

docs/20 > Godot 4.x Implementation Standards > "Scene Tree" names: `Entities` (pooled, `y_sort_enabled = true`), `Projectiles` (pooled), `Pickups` (pooled), `Effects` (pooled), `Environment`, `Audio`; and the full z_index draw order: `environment 0, pickups 10, enemies 20 (Y-sorted among themselves), Tower 25, player projectiles 30 (rendered at ≤ 70% opacity), effects 35, telegraphs 40, player 50, damage numbers 60`.

`scenes/main.tscn` as built:

```
Main (Node2D, process_mode = PROCESS_MODE_PAUSABLE)
├── Entities      (Node2D, y_sort_enabled = true, z_index = 20)
├── Projectiles   (Node2D, z_index = 30)
├── Pickups       (Node2D, z_index = 10)
├── Effects       (Node2D, z_index = 0)
├── Environment   (Node2D, z_index = 0)
├── Audio         (Node2D, script = src/audio/audio_pool.gd, i.e. this node IS the AudioPool)
├── SimLoop       (Node,   script = src/core/sim_loop.gd)
└── EntitySpawner (Node,   script = src/core/entity_spawner.gd, NodePaths wired to the four pooled containers above)
```

z_index mapping, and why two containers are left at 0 rather than matching the list's numbers literally:

| Container | z_index set | Reasoning |
| --- | ---: | --- |
| Environment | 0 | 1:1 with the list's "environment 0" |
| Pickups | 10 | 1:1 with "pickups 10" |
| Entities | 20 | 1:1 with "enemies 20"; `y_sort_enabled = true` per docs/20, the only container with it set (verified: `test_entities_is_y_sorted_and_others_are_not`) |
| Projectiles | 30 | 1:1 with "player projectiles 30". The "≤ 70% opacity" qualifier applies to player projectiles specifically, not Tower or enemy projectiles, which share the same container and the same z-band per docs/20's single "Projectiles (pooled)" container — so the opacity reduction cannot be a container-level property without also dimming Tower/enemy projectiles. Left as a per-instance responsibility for whichever future task (P2.4 player weapon) spawns a player projectile, and named here rather than silently built in |
| Effects | 0 (deliberately not 35) | The list gives Effects-hosted content **three different, non-adjacent** z-bands: "effects 35", "telegraphs 40", "damage numbers 60". One container node cannot carry three different automatic z_index values for its children at once (Godot's `z_as_relative` adds a child's own z_index on top of its parent's, it does not let three different child *kinds* opt into three different parent offsets). Setting Effects to 35 would only be correct for generic/high-intensity VFX and would force telegraph- and damage-number-spawning code to know to apply a **relative** offset instead of an absolute one — a subtler, more error-prone contract than every other container in this list, which all work by absolute z_index. Effects is left at 0 and `entity_spawner.gd`'s header comment documents that whatever spawns a damage number, telegraph, or high-intensity VFX instance must set that instance's own absolute z_index (35 / 40 / 60 respectively) itself. **Named as an interpretation, not silently resolved**: docs/20 does not spell out this mechanism explicitly. |
| Audio | not set (non-visual) | Audio is not in docs/20's z_index list at all; `AudioStreamPlayer2D` voices do not draw |

Tower (z_index 25) and player (z_index 50) are not containers docs/20's Scene Tree bullet names, and no Tower or player system exists yet (both are later P2.x tasks) — no node was added for either, so as not to invent scope. `test_player_would_not_be_placed_inside_entities_container` asserts the structural precondition that keeps "the player is not a child of `Entities` and is not part of that Y-sort group" satisfiable once a player exists: `Entities` is a plain sibling of Main's other direct children, not a catch-all parent.

**Nothing under the gameplay root sets `PROCESS_MODE_ALWAYS`.** Verified by `test_nothing_under_the_gameplay_root_is_process_mode_always`, which walks the entire instantiated `Main` subtree recursively and asserts zero matches. `SimLoop` (`PROCESS_MODE_PAUSABLE`, set in its own `_ready()`), `EntitySpawner` (same), and `Audio`/`AudioPool` (never sets `process_mode`, inherits `PAUSABLE` from `Main`) all comply.

### Audio container: what is wired, and a named contradiction

docs/20's Scene Tree bullet describes the `Audio` container as *being* "the 32-voice `AudioPool`... it lives under the gameplay root so it pauses with the tree." P1.6's own evidence report (`p16_report.md`, "Scene ownership") states explicitly that it does not own `scenes/main.tscn` and that "actually instancing `AudioPool` under the gameplay root... is left to whichever task owns that scene" — naming P1.3. `AudioPool` (`src/audio/audio_pool.gd`) never sets `process_mode` and self-populates its 32 `AudioStreamPlayer2D` voices in its own `_ready()`, so it was safe to wire: the `Audio` node in `scenes/main.tscn` has `audio_pool.gd` attached directly (the container node *is* the AudioPool, matching docs/20's phrasing), and `test_all_six_named_containers_exist` confirms it resolves.

**`AudioDucking` and `TowerCuePlayer` (`src/audio/audio_ducking.gd`, `tower_cue_player.gd`) are deliberately left unwired.** `AudioDucking` sets `process_mode = PROCESS_MODE_ALWAYS` in its own `_ready()`, and MASTER_SDLC.md > Global Simulation Authority explicitly groups "the ducking node" with `PauseAuthority`/`EventBus`/the UI `CanvasLayer`/the UI sound players as the `PROCESS_MODE_ALWAYS` set — none of which live under the gameplay root; they are Autoloads or top-level UI siblings. This is a **genuine structural contradiction, named rather than silently resolved**: docs/20's own Scene Tree bullet says "nothing under the gameplay root may set `PROCESS_MODE_ALWAYS`," and `project.godot` (off-limits to me) already pins `run/main_scene = res://scenes/main.tscn` directly to this scene, with no outer non-gameplay-root wrapper scene above it. Introducing one would mean `Main` is no longer literally "the gameplay root," which is a bigger structural decision than this task's explicit brief ("the container nodes docs/20 names") authorizes me to make unilaterally. I did not invent a wrapper. `AudioDucking` and `TowerCuePlayer` are ready to instance (both self-contained, no scene-tree assumptions beyond their optional duck-typed `ducking_node`/`has_method` references already documented in `p16_report.md`) but are left for whoever resolves where a `PROCESS_MODE_ALWAYS` node belongs in a boot scene that is also the gameplay root — a question for the author, not a silent call.

## 2. Where `SimLoop` was placed, and why

LEDGER F02-06 records that the P1.1 implementer deliberately did **not** register `SimLoop` as an Autoload, on the reading that MASTER_SDLC.md calls only `SimClock` and `PauseAuthority` "Autoloads" and never uses that word for `SimLoop`, concluding it "belongs under the gameplay root P1.3 builds." I agree with this reading and did not revisit it: `SimLoop` is a `Node` child of `Main` (`scenes/main.tscn`), with `src/core/sim_loop.gd` attached, unchanged from P1.1's own deliverable. Its own script already sets `process_mode = PROCESS_MODE_PAUSABLE` in `_ready()`, matching "the gameplay root is `PROCESS_MODE_PAUSABLE`" and the "nothing under the gameplay root may set `PROCESS_MODE_ALWAYS`" rule. `test_sim_loop_is_present_under_the_gameplay_root` confirms both the node's presence and its process mode by instantiating the actual scene and reading it back, not by re-deriving the placement decision from source.

`EntitySpawner` was placed the same way and for the same reason (it owns references to the pooled containers, so it has to live where they live), which is my own extension of F02-06's precedent to a new node this task introduces, not a restatement of it.

## 3. `Pool`'s acquire/release contract

`src/core/pool.gd`, `extends RefCounted`, `class_name Pool`. One `Pool` instance per capped category; `entity_spawner.gd` owns six.

**Cap enforcement.** `max_size` is checked at the top of `acquire()`, before any instance is created or handed out — enforced where spawning happens, not counted after the fact. Two `OverflowPolicy` values:
- `THROTTLE`: once `active.size() >= max_size`, `acquire()` returns `null`. Used for `enemy` ("never exceeded... throttle" — Register), `telegraph` ("wait with their cooldown held" reads as a refusal, not a reclaim), and `high_intensity_vfx` (**named interpretation**: the Register's "effects reduce before enemy visibility reduces" does not unambiguously say whether an over-cap VFX request is refused or an existing one is culled; I read "reduce" as refusing new ones).
- `RECYCLE_OLDEST`: once at cap, the oldest still-active instance (front of acquisition order) is released and its freed slot is reused for the new request, so the pool never exceeds `max_size` but a request is never bluntly refused either. Used for `projectile` ("oldest recycled" — literal match), `damage_number` ("oldest... culled" — literal match), and `pickup` (**named interpretation**: the Register's "oldest pickups merge or expire" is closer to a domain-specific merge behaviour that P1.3's generic infrastructure cannot implement without a real pickup system; `RECYCLE_OLDEST`'s "expire the oldest to make room" is the closest available analog, not a literal implementation of "merge").

**The Logical Death restore contract — the critical requirement.** docs/20 > Logical Death defers four flag changes on a dying entity: every hitbox `Area2D`'s `monitoring` → `false`; the hurtbox `Area2D`'s `monitorable` → `false` **and** `collision_layer` → `0`; the body's `collision_layer` → `0` **and** `collision_mask` → World(4)+ArenaBounds(15) only. The same bullet: "`Pool.acquire()` restores all of these... before reuse." `pool.gd` restores all four in one path:

1. **Discovery** is duck-typed via three Godot groups, checked with `is_in_group()` (works before tree entry — Godot tracks group membership on the node itself, not via `SceneTree`): `pool_hitbox` (an `Area2D`; restores `monitoring`), `pool_hurtbox` (an `Area2D`; restores `monitorable` **and** `collision_layer`), `pool_body` (any node exposing `collision_layer` **and** `collision_mask`, typically the instance root). This is necessary because P1.5's `hitbox.gd`/`hurtbox.gd`/`death_state.gd` land after this task (LEDGER F02-11) — `Pool` cannot depend on a combat-component API that does not exist yet, only on a convention P1.5 can adopt.
2. **Snapshot-and-reapply**, not a hard-coded default: the first time an instance is ever handed out (the branch where the factory just created it, before anything could have mutated it), `_snapshot_baseline()` records that instance's own `monitoring`/`monitorable`/`collision_layer`/`collision_mask` values as its baseline. Every later `acquire()` of that same instance reapplies the stored baseline via `_restore_logical_death_flags()`, overwriting whatever Logical Death left behind — not a guessed "correct" layer/mask, since `Pool` has no license to know the right values for an enemy type it has never seen.
3. All four restorations happen inside one function, `_restore_logical_death_flags()`, called unconditionally at the top of every `acquire()` return path (both the free-list-reuse branch and the newly-created-instance branch, since the newly-created branch's snapshot equals its own current state — a no-op restore, not a skipped one).

`release(instance)` moves an active instance to the free list and sets `visible = false`; it refuses (`false`) an instance the pool did not currently have active. `acquire()` sets `visible = true` on hand-out. Neither touches `process_mode` — that stays out of `Pool`'s job, since P1.5's `death_state.gd` (Visual Death, ragdoll/knockback while still processing) may need to own that transition and nothing today requires `Pool` to.

## 4. How the six cap values reach the test independently of the spawner

Phase 02 carried lesson 2: "P1.3's cap check takes the six cap values from the Provisional Values Register, not from the spawner's own constants." Two separate files hold the same six numbers, on purpose:

- `src/core/entity_caps.gd` (`class_name EntityCaps`): the six `MAX_*` constants, transcribed from MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance > "Entity caps" row (mirrored by docs/20 > Interim Prototype Technical Budgets — the two agree). This is the only file `entity_spawner.gd` reads to configure its six `Pool` instances.
- `tests/unit/entity_cap_test.gd`: six `REGISTER_MAX_*` constants, transcribed a **second time**, independently, directly from the same Register text, in the test file's own header comment. The test file does **not** `preload` or reference `entity_caps.gd` anywhere — grep-verifiable (`grep -n EntityCaps tests/unit/entity_cap_test.gd` returns nothing). A wrong value written into `entity_caps.gd` cannot make `entity_cap_test.gd` pass by agreeing with itself, since the two never share a source.

Register values used (Enemies 300, pickups 150, projectiles 400, damage numbers 30, telegraphs 40, high-intensity VFX 24) match MASTER_SDLC.md's Register row and docs/20's Interim Prototype Technical Budgets table verbatim — no numeric conflict found between the two owner documents for this row.

## 5. Acceptance tests

Both run against the pinned console executable, `--import` first, per the task brief:

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
```

### 5.1 Cap unit check (`tests/unit/entity_cap_test.gd`)

Six independent tests, one per cap, each hammering `EntitySpawner.spawn_*()` for `cap + 50` attempts (so the cap is provably reached, not merely never approached — each test also asserts `observed_max == cap`, so a cap that was silently never hit would itself fail the test) and asserting the active count never exceeds the independently-transcribed Register value at any point during the hammering, not just at the end. A seventh and eighth test confirm the `EntityRegistry` wiring decision (§6): `spawn_enemy`/`despawn_enemy` register/deregister; `spawn_damage_number` does not touch the registry at all.

Green run (clean tree):
```
Run Test Suite: res://tests/unit/entity_cap_test.gd
Statistics: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
Exit code: 0
```

### 5.2 Pool unit check (`tests/unit/pool_test.gd`)

Two acquire/release-cycling tests (10,000 single-object cycles; 2,000 batches of 5 = 10,000 total `acquire()` calls, to also catch a leak that only shows up with concurrency > 1), each asserting (a) the pool's own creation counter stays at the true steady-state size (1, or 5 for the batched variant) rather than growing per cycle, and (b) `get_total_instance_count()` sampled partway through the run and again at the end stay within a ±1% band. Four overflow-policy tests (`THROTTLE` refuses past cap; `RECYCLE_OLDEST` never exceeds cap and reclaims the specific oldest instance; a cap of 0 never spawns under either policy without crashing; `release()` refuses a stranger instance). Two Logical Death restoration tests: the critical one (all four flags restored on reuse, against a fixture built from docs/20's own Collision Layers table numbers — EnemyBody layer 2/mask 1,2,3,4,15, EnemyHurtbox layer 9) and a no-op case (an instance with none of the three `pool_*` groups must not error).

Green run (clean tree):
```
Run Test Suite: res://tests/unit/pool_test.gd
Statistics: 8 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
Exit code: 0
```

### 5.3 Falsification log

Per carried lesson 1 ("A check is not believed until it has been made to fail") and the task brief's explicit instruction to falsify both tests, including the case named as most important. Each mutation was applied with a direct edit to `src/core/pool.gd`, the affected suite run to confirm red with the exact failure named, then the file restored from a byte-for-byte backup (`diff` confirmed identical afterward) and the full suite re-run to green — per LEDGER F02-08 (a failure stops the remaining tests in that same suite file only), the restored-suite run is what confirms the suite is whole again, not just the mutated test.

**Mutation 1 — break the cap so the spawner overshoots.** `pool.gd` line 139, `if _active.size() >= _max_size:` → `if _active.size() > _max_size + 1:` (lets the enemy pool grow to `max_size + 2` before refusing).
```
$ .../Godot...console.exe --headless --path . -s .../GdUnitCmdTool.gd -a res://tests/unit/entity_cap_test.gd --ignoreHeadlessMode
res://tests/unit/entity_cap_test.gd > test_enemy_cap_is_never_exceeded FAILED
  Expecting to be less than or equal: 300 but was 301
  enemy count 301 exceeded the Register cap of 300 after 301 spawn attempts
  ... (302 repeats for subsequent attempts)
Exit code: 100
```
Restored; `entity_cap_test.gd` re-run alone: `8 test cases | 0 errors | 0 failures | ... Exit code: 0`.

**Mutation 2 — make `acquire()` leak objects so the count drifts.** `pool.gd` line 146, `if not _free.is_empty():` → `if false:` (free list is never consulted; every `acquire()` creates a brand-new instance).
```
$ .../Godot...console.exe --headless --path . -s .../GdUnitCmdTool.gd -a res://tests/unit/pool_test.gd --ignoreHeadlessMode
res://tests/unit/pool_test.gd > test_ten_thousand_single_object_cycles_keep_object_count_stable FAILED
  pool created 10000 distinct instances over 10000 acquire/release cycles instead of reusing the free list -- a leak
  object count drifted from 1000 (sampled at cycle 1000) to 10000 (at cycle 10000), outside the +/-1% stability band
Statistics: 1 test cases | 0 errors | 2 failures | ...
Exit code: 100
```
(F02-08 in action: only the first of 8 tests in the file ran before gdUnit4 stopped the rest.) Restored; full `pool_test.gd` re-run: `8 test cases | 0 errors | 0 failures | ... Exit code: 0`.

**Mutation 3 — the most important one: make `acquire()` restore only *some* of the Logical Death flags.** `pool.gd`, `_restore_logical_death_flags()`: commented out the `collision_mask` restoration only, leaving `monitoring`, `monitorable`, and `collision_layer` (both hurtbox's and body's) restored correctly. This is exactly the defect class the task brief and LEDGER's risk table name, and the one P1.5's future Ghost hit test exists to catch on a reused instance.
```
$ .../Godot...console.exe --headless --path . -s .../GdUnitCmdTool.gd -a res://tests/unit/pool_test.gd --ignoreHeadlessMode
res://tests/unit/pool_test.gd > test_acquire_restores_all_four_logical_death_flags_on_reuse FAILED
  acquire() did not restore body.collision_mask
Statistics: 7 test cases | 0 errors | 1 failures | ...
Exit code: 100
```
The other three flags (`monitoring`, `monitorable`, both `collision_layer`s) passed their own assertions in the same failed test run — confirming the test catches a **partial** restore specifically, not merely "something changed." Restored; full `pool_test.gd` re-run: `8 test cases | 0 errors | 0 failures | ... Exit code: 0`.

**Final full-suite re-run after all three mutations were reverted** (`diff` against the pre-falsification backup confirmed `pool.gd` byte-identical):
```
Overall Summary: 136 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
Executed test suites: (18/18)
Executed test cases : (136/136)
Exit code: 0
```

## 6. `set_entity_alive` consistency

LEDGER F02-11: `EntityRegistry.set_entity_alive()` is P1.2's own channel for Logical Death to reach the registry — a dying entity stays **registered** with `alive = false` rather than being torn out, so live-only queries (Tower targeting, the magnet raycast, wave completion counts) exclude it while its Visual Death still occupies scene space, without a per-tick broadcast.

`entity_spawner.gd`'s acquire/release-adjacent wiring is consistent with this design, not in tension with it: `spawn_*()` calls `EntityRegistry.register_entity()`, and `despawn_*()` (which calls `Pool.release()`) calls `EntityRegistry.deregister_entity()`. **Deregistration happens at despawn (pool return), not at Logical Death.** In the eventual full lifecycle — P1.5 owns Logical Death and comes after this task — an entity dying will call `EntityRegistry.set_entity_alive(entity, false)` directly (bypassing this file), stay registered and excluded from live queries through its Visual Death animation, and only reach `entity_spawner.despawn_enemy()` (hence `Pool.release()` and `EntityRegistry.deregister_entity()`) once its Visual Death timer expires and docs/20's "Spatial Cleanup" rule returns it to the pool. Nothing in this task's files calls `set_entity_alive()` — that call site belongs to P1.5's `death_state.gd`. `test_spawn_enemy_registers_and_despawn_deregisters` exercises the two ends of this lifecycle this task actually owns (register on spawn, deregister on despawn); it does not and cannot exercise the middle (alive=false while still pooled-active), since that requires P1.5's component to exist.

One asymmetry worth naming: only `enemy`, `pickup`, and `projectile` are registered at all (see §1's "Contradictions and ambiguities" list below) — `damage_number`, `telegraph`, and `high_intensity_vfx` never call `register_entity`/`deregister_entity`/`set_entity_alive`, so the consistency question above only applies to the three categories that are ever registered in the first place.

## 7. Contradictions and ambiguities — named, not silently resolved

1. **`AudioDucking`'s required `PROCESS_MODE_ALWAYS` has no compliant place to live** under a gameplay root that is also the literal boot scene (`project.godot`'s `run/main_scene`, off-limits to me, already points straight at `scenes/main.tscn` with no outer wrapper scene). Left unwired; see §1.
2. **The `Effects` container cannot carry one z_index for three differently-banded child kinds** (VFX 35, telegraphs 40, damage numbers 60). Resolved by leaving the container at 0 and requiring each spawned instance to set its own absolute z_index — a mechanism docs/20 does not spell out explicitly. See §1's table.
3. **Player-projectile opacity (≤ 70%) cannot be a `Projectiles`-container property** without also dimming Tower and enemy projectiles that share the same container. Left as a per-instance responsibility for the future player-weapon task. See §1.
4. **Overflow policy per cap is a P1.3 interpretation**, not a value docs/20 or the Register states directly as an enum: `THROTTLE` vs `RECYCLE_OLDEST` was chosen by reading each cap row's "if exceeded" text as either a refusal ("throttle", "wait ... cooldown held") or a reclaim ("recycle[d]", "culled"). Pickup ("merge or expire") and high-intensity VFX ("reduce") do not cleanly fit either reading; see §3's table for the specific choice made for each.
5. **Only three of six categories are wired to `EntityRegistry`** (`enemy`, `pickup`, `projectile`) on the reading that only those three are ever the subject of a documented spatial query. `damage_number`/`telegraph`/`high_intensity_vfx` are not. The task brief's "your pools will register and deregister entities through it" does not itself say all six must be. See §1's header comment in `entity_spawner.gd` and `test_damage_number_spawn_does_not_touch_entity_registry`.
6. **Tower (z_index 25) and player (z_index 50)** are in docs/20's draw-order list but are not containers the Scene Tree bullet names and have no system yet (both P2.x). No node was added for either — not a decision that needed making yet, but recorded here so a later task does not have to rediscover why `Main` currently has no `Tower`/`Player` child.

## 8. Concurrent work observed, not touched

While this task ran, `src/debug/overlay.gd`, `overlay.tscn`, `run_recorder.gd` and three new suites (`tests/unit/debug_overlay_test.gd`, `tests/unit/run_recorder_behavior_test.gd`, `tests/unit/run_recorder_schema_test.gd`) appeared in the same working tree — the concurrent P1.4 implementer's own work, per the delegation's "stay out of `src/debug/`" instruction. One of those three suites was observed briefly red (`test_ticks_csv_header_matches_docs20_schema`, 1 failure) partway through this task's own work and green by the final full-suite run; nothing in that observation was acted on, since it is outside this task's scope and was never this task's own regression. `phases/PHASE_02_Technical_Foundations/EXECUTION_LOG.md` also shows as modified in `git status`; this task never opened or wrote it.

## 9. Total unit test count

136 test cases across 18 suite files, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit code 0, on the final post-falsification run. Of these, 24 (8 + 8 + 8) are this task's own (`entity_cap_test.gd`, `pool_test.gd`, `main_scene_structure_test.gd`); the pre-existing 90 from P1.1/P1.2/P1.6 remain green; the remaining 22 belong to the concurrent P1.4 work (§8), not this task.

This report does not assert that any gate is passed, satisfied, met, or ready; that determination belongs to the reviewers and the author.

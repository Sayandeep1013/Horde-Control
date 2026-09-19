# P2.3 Evidence Report — Handgun and Auto-Targeting

## GodotPrompter skills consulted

All four named in this task's brief were invoked in full before this report was written (the code itself was drafted from the pattern in `src/tower/tower_weapon.gd` / `src/tower/tower_projectile.gd` per the task's own instruction to "read and mirror it," then checked against each skill below; where a skill call would have changed something, it is recorded as a conflict rather than silently followed or silently ignored).

- **`godot-prompter:physics-system`** — read in full. Followed without conflict: "Code raycasts use `PhysicsDirectSpaceState` inside `_physics_process()` only" (`player_projectile.gd`'s `_sweep_and_resolve()` is called only from `_physics_process()`); `query.exclude = [get_rid()]` to skip self (done, as a typed `Array[RID]`); no `scale` on collision shapes (none set). The skill's own raycast section is silent on what to do when the ray's own origin sits inside the target shape or when the mover's own collision radius should be added to the query — this task worked that out empirically (see "Contradictions and ambiguities," item 1) rather than finding it in the skill.
- **`godot-prompter:gdscript-patterns`** — read in full. Section 3 ("Closures"): "Locals are captured by value, so a captured `int` counter returns 1 on every call. Share state through a reference type." This is exactly the bug this task's own falsification work reproduced independently (see "Contradictions and ambiguities," item 2) before reading this skill's own text — the skill's documented pitfall and this project's own established convention (Dictionary-wrapped counters, already used throughout `tests/unit/pool_test.gd`, `ghost_hit_test.gd`, `player_scene_test.gd`) agree with each other.
- **`godot-prompter:component-system`** — read in full.
  - **Conflict, third instance of the pattern F03-02/F03-11 already record.** Rule 2 states: "Communicate via signals, not direct sibling access. A component must not call `get_parent().get_node('SiblingComponent')`." `auto_weapon.gd`'s `_check_starting_weapon_reference_id()` does exactly that shape of call — `get_parent() as Player`, then reads `player.definition.starting_weapon_reference_id` directly — a typed read on a known, owned parent, not a signal. This mirrors docs/20's own three-way split (events / queries / commands), under which a direct call to a known owner is a legitimate typed query, not the loosely-coupled sibling-poking the skill's rule is written to forbid; F03-11 already records the same shape of conflict for `tower_health.gd`/`death_state.gd`. Project wins, per CLAUDE.md; recorded here as a third instance for the ledger.
  - The skill's own reference `HitboxComponent`/`HurtboxComponent` resolve damage inside `Area2D.area_entered` and call the target's own method directly (`area.receive_hit(damage)`), which is the same "typed command on a known target" shape this file's `_on_area_entered()`/`_sweep_and_resolve()` use (`hurtbox.receive_hit(...)`) — no conflict there, and it matches `hitbox.gd`'s and `tower_projectile.gd`'s already-established precedent in this codebase.
- **`godot-prompter:godot-testing`** — read in full. **Confirms, does not newly conflict**: F03-08 already records that this project's suites use a `*_test.gd` suffix where the skill (and GUT) prescribe a `test_*.gd` prefix; `tests/unit/weapon_check_test.gd` and `tests/unit/player_projectile_test.gd` both follow the project's own suffix convention, per this task's explicit instruction. The skill's assertion tables (`assert_array(...).contains([...])`, `assert_float(...).is_equal_approx(...)`) match what `gdUnit4` v6.2.1 actually ships in this project, confirmed by using them successfully. The skill's "What NOT to Test" section ("timing-sensitive floats without margins — use `is_equal_approx`") is followed throughout both suites.

## Files written (all within this task's write scope)

| Path | Purpose |
| --- | --- |
| `data/weapons/handgun.tres` | The `WeaponDefinition` contract instance for the Handgun — `unique_id = "handgun_prototype"`, matching `data/player/prototype.tres`'s `starting_weapon_reference_id` |
| `src/combat/auto_weapon.gd` | `AutoWeapon`: EntityRegistry-driven auto-targeting, fire cadence, projectile pooling, C-AUTOFIRE suppression, `driven_externally`/`physics_step()` seam |
| `src/combat/player_projectile.gd` | `PlayerProjectile`: the pooled `Area2D` projectile — Readability (z_index 30, <= 70% opacity), Projectile Orphans (by-value source), the `intersect_ray` sweep |
| `scenes/player.tscn` | Added `AutoWeapon` and `Projectiles` sibling nodes under the existing `Player` root; no other node in the scene touched |
| `tests/unit/weapon_check_test.gd` | Weapon check (named acceptance test): fire rate, damage, range, re-pick, sheet DPS, kill, no-input, C-AUTOFIRE, `driven_externally` |
| `tests/unit/player_projectile_test.gd` | Projectile-level unit coverage: Readability, Projectile Orphans, lifetime expiry, the sweep, no-piercing |
| This report | `phases/PHASE_03_Core_Entities_And_Feel_Check/evidence/p23_report.md` |

Nothing else was written or modified. `git status --short` at the time of this report shows exactly these six paths as mine (`scenes/player.tscn` modified; the other five untracked/new); every other changed or new path in the working tree (`src/enemy/**`, `src/ui/**`, `data/enemies/**`, `scenes/entities/{opportunist,player_hunter,tower_seeker}.tscn`, `scenes/ui/**`, `tests/unit/{attack_slot_manager,enemy_tag_registration,hud_*,leash,opportunist,stuck_exemption,threat_feedback_*,tower_cue_audibility}_test.gd`, `phases/PHASE_03_Core_Entities_And_Feel_Check/EXECUTION_LOG.md`, three stray `scratch_test_output*.txt` files at the repo root) belongs to the two parallel implementers (P2.5, P2.6) and was left untouched. No `mcp__godot-comprehensive__*`, `mcp__godot-coding-solo__*`, `run_project`, or `game_*` tool was called at any point; every Godot invocation ran through Bash against the pinned console executable (`D:\godot\Godot_v4.7.1-stable_win64_console.exe`).

## `scenes/player.tscn` diff, in full

```
[gd_scene load_steps=11 format=3]  ->  [gd_scene load_steps=13 format=3]
+ [ext_resource type="Script" path="res://src/combat/auto_weapon.gd" id="8_auto_weapon"]
+ [ext_resource type="Resource" path="res://data/weapons/handgun.tres" id="9_handgun"]
+ [node name="AutoWeapon" type="Node" parent="."]
+ script = ExtResource("8_auto_weapon")
+ definition = ExtResource("9_handgun")
+ origin_path = NodePath("..")
+ projectiles_container_path = NodePath("../Projectiles")
+ [node name="Projectiles" type="Node2D" parent="."]
```

`Player`, `BodyShape`, `Hurtbox`/`HurtboxShape`, `Collector`/`CollectorShape`, `DeathState`, and `Visuals`/`Sprite2D` are byte-identical to before this task — confirmed by `git diff scenes/player.tscn`, reproduced above in full (nothing elided). Movement, hurtbox, collector, animator, and `DeathState` configuration were not touched, per this task's hard constraint.

## Every Register citation, by row name, and where it is read from

All from MASTER_SDLC.md > Provisional Values Register (cited, never restated as a bare literal in any `.gd` file's logic):

| Register row | Value | Authored in | Read by |
| --- | --- | --- | --- |
| Player & Weapons > "Handgun (Starting Weapon)" | 10 dmg/shot, 2 shots/s (20 DPS), range 260 px, nearest re-picked every shot, projectile 1000 px/s | `data/weapons/handgun.tres` -> `damage_band.value` (10), `engagement_rhythm.fire_rate_per_second` (2.0), `effective_range_px` (260), `projectile_definition.speed_px_per_second` (1000) | `auto_weapon.gd`'s `configure()`, `physics_step()`, `_pick_nearest_target()`, `_fire_at()` |
| Tower > "Tower Console dwell / auto-fire" (C-AUTOFIRE) | "player auto-fire disabled at any speed while overlapping the [Interaction] radius; Tower keeps firing" | Not a `.tres` value — a behavioural rule. `auto_weapon.gd`'s `set_auto_fire_suppressed()` / `_auto_fire_suppressed` gate | `physics_step()`'s early return; driven externally by whichever future task connects `tower_interaction_radius.gd`'s `player_entered`/`player_exited` signals (see "Cross-task seams") |
| Interfaces > "Readability" | "player projectiles 30 (rendered at <= 70% opacity)" | `player_projectile.gd` -> `DRAW_Z_INDEX = 30`, `MAX_OPACITY = 0.7`, applied to `z_index` / `modulate.a` in `_ready()` | Node properties, verified by `player_projectile_test.gd::test_draws_at_z_index_30_and_at_most_70_percent_opacity` |
| MASTER_SDLC.md > Movement Design & Input Buffering > Input Buffering Rules > "Auto-Fire Targeting" | "Input buffering is strictly banned for auto-fire targeting... instantaneous and frame-perfect based on current position" | Structural: `auto_weapon.gd` contains no call to the `Input` singleton at all | `weapon_check_test.gd::test_reads_no_input_action_at_all` (source-text assertion) |
| docs/20 > "Physics & Collisions" | `intersect_ray` sweep, `collide_with_areas = true`, from previous to current position whenever travel exceeds 12 px; masks include ArenaBounds | `player_projectile.gd` -> `SWEEP_THRESHOLD_PX = 12.0` (framework constant, not a Register row); `CollisionLayers.MASK_PLAYER_PROJECTILE` | `_sweep_and_resolve()`, called from `_physics_process()` every tick (1000 px/s = 16.67 px/tick, always above the 12 px threshold) |
| docs/20 > Collision Layers table, row 5 | "PlayerProjectile \| Player projectile Area2D \| 9, 4, 15" | `CollisionLayers.LAYER_PLAYER_PROJECTILE` / `CollisionLayers.MASK_PLAYER_PROJECTILE` (pre-existing file, not modified — only referenced) | `player_projectile.gd`'s `_ready()` |
| docs/20 > "Animation, Hitbox, and State Cleanup Rules" > "Projectile Orphans" | "damage source reference is resolved by value at the time of firing, not by reference to the dead entity" | `auto_weapon.gd`'s `_fire_at()` passes `&"player"` (a `StringName`, a value) to `launch()`, never a `Node` reference | `player_projectile.gd`'s `_source: Variant`; verified by `player_projectile_test.gd::test_launch_source_is_a_value_not_a_live_node_reference` |
| Provisional Values Register > Technical Caps & Performance > "Entity caps" (projectiles 400) | `EntityCaps.MAX_PROJECTILES` (pre-existing file, not modified) | `auto_weapon.gd`'s `configure()` builds `Pool.new(..., EntityCaps.MAX_PROJECTILES, Pool.OverflowPolicy.RECYCLE_OLDEST)` — the same cap `tower_weapon.gd` uses, independently enforced per pool (see tower_weapon.gd's own header for the known limitation this inherits: no single global cap across all projectile sources yet) |

**Not a Register value, named as such (matching `tower_projectile.gd`'s own precedent for the same field):** `player_projectile.gd`'s `COLLISION_RADIUS_PX = 6.0` is a framework/rendering constant — no Register row sizes a generic projectile's own hit-detection circle.

**Derivation, not a Register literal (matching F03-16's own precedent):** `data/weapons/handgun.tres`'s `projectile_definition.lifetime_seconds = 0.286` is `range_px / speed_px_per_second * 1.1` = `260 / 1000 * 1.1`, the same 10% safety-margin formula `data/tower/base_weapon.tres` already uses (`480 / 900 * 1.1 = 0.586667`), applied here rather than invented fresh. The 1.1 margin is a choice, stated rather than buried.

**Interpretations, named rather than silently assumed:**
- `handgun.tres`'s `coverage_shape = 3` (`ContractEnums.CoverageShape.SingleTarget`) and `target_count = 1`: the Register states "nearest re-picked every shot" but does not name a `CoverageShape` enum value directly. `SingleTarget`/`1` is the only value consistent with "the nearest target" (singular) and matches `data/tower/base_weapon.tres`'s own choice for the same underlying single-target mechanic.
- `auto_weapon.gd` reads the Handgun's range from `WeaponDefinition.effective_range_px` directly, not from a second `TargetingRuleParameters`-style struct the way `tower_weapon.gd` reads Tower range from `TowerDefinition.targeting_rule_parameters.range_px`. `PlayerDefinition` has no such struct, and the Register states exactly one range figure for the Handgun — read literally, `effective_range_px` (the Weapon Definition Contract's own field) is that figure. Named as an interpretation since `configure()`'s signature (`configure(weapon: WeaponDefinition)`, one argument) therefore differs from `tower_weapon.gd`'s (`configure(weapon, range_px)`, two arguments).

## Acceptance test: falsification log

Godot: `D:\godot\Godot_v4.7.1-stable_win64_console.exe` (pinned 4.7.1 console build). Import pass run before every invocation. Every mutation below was applied to the **real** source or `.tres` (never to `tests/unit/weapon_check_test.gd` or `tests/unit/player_projectile_test.gd`), confirmed to make the targeted test **FAIL**, restored, confirmed **byte-identical to a pre-mutation backup via `diff`** (this task's two new resources/scripts are untracked, so `git diff` shows nothing for them — `diff` against a saved copy is the equivalent check), and confirmed **green again**.

gdUnit4 stops a suite file at its **first** failure (LEDGER F02-08). Where a mutation's own mechanism is shared with an earlier-numbered test in the same file (fire rate/damage and sheet DPS both derive from the same two `.tres` fields; damage and the kill test both derive from the same weapon), a throwaway single-test scratch harness under `tests/unit/_scratch_*_test.gd` was used to observe the later test fail in isolation, then deleted immediately — `tests/unit/weapon_check_test.gd` and `tests/unit/player_projectile_test.gd` themselves were never edited for this purpose.

### `tests/unit/weapon_check_test.gd` (8 tests)

| # | Test | Mutation | Result |
| --- | --- | --- | --- |
| 1 | `test_fires_at_the_registers_cadence_and_damage_per_shot` | `handgun.tres`: `damage_band.value` 10 -> 6 | **FAILED** (3 failures: per-shot amount mismatch). Restored, `diff` identical, suite re-run 8/8 green |
| 1 | (same test, second mutation) | `handgun.tres`: `fire_rate_per_second` 2.0 -> 1.0 | **FAILED** (2 failures: inter-shot gap mismatch). Restored, `diff` identical, re-run 8/8 green |
| 2 | `test_sheet_dps_from_weapon_matches_the_register` | Same `fire_rate_per_second` mutation as above; test 1 fails first in the real suite, so isolated via a scratch single-test harness calling `CombatStats.sheet_dps_from_weapon(HandgunResource)` directly | **FAILED** (`Expecting: [10.0] but was: [20.0]`, i.e. the reverse -- reads as 10 instead of 20). Restored, `diff` identical |
| 3 | `test_does_not_fire_beyond_the_registers_range_and_fires_once_in_range` | `handgun.tres`: `effective_range_px` 260 -> 1000 | **FAILED**, isolated cleanly (tests 1-2 still passed under this mutation, then test 3 failed — confirms the mutation is scoped to range only) |
| 4 | `test_repicks_the_nearest_target_every_shot` | `auto_weapon.gd`: `physics_step()`'s target pick changed to `_current_target if (_current_target != null and is_instance_valid(_current_target)) else _pick_nearest_target()` — i.e. accidentally copying `tower_weapon.gd`'s hold-until-dead-or-out-of-range rule | **FAILED**, isolated cleanly (tests 1-3 passed, test 4 failed) — this is the specific defect class this task's brief warned against ("Do not copy the Tower's retarget logic by accident") |
| 5 | `test_kills_a_placeholder_enemy_within_the_expected_number_of_shots` | `handgun.tres`: `damage_band.value` 10 -> 1; test 1 fails first in the real suite, so isolated via a scratch single-test harness reproducing the kill scenario | **FAILED** (2 failures: enemy not dead within timeout, and the elapsed-time bound). Restored, `diff` identical |
| 6 | `test_reads_no_input_action_at_all` | `auto_weapon.gd`: added a real `Input.get_vector(&"move_left", ...)` call inside `_now()` | **FAILED**, isolated cleanly (tests 1-5 passed, test 6 failed) |
| 7 | `test_set_auto_fire_suppressed_stops_firing_and_unsuppressing_resumes_it` | `auto_weapon.gd`: `set_auto_fire_suppressed()` body replaced with `pass` (drops the flag) | **FAILED**, isolated cleanly (tests 1-6 passed, test 7 failed) |
| 8 | `test_driven_externally_disables_self_stepping_but_physics_step_still_fires` | `auto_weapon.gd`: `_physics_process()` always calls `physics_step(delta)`, ignoring `driven_externally` | **FAILED**, isolated cleanly (tests 1-7 passed, test 8 failed) |

Final re-run after every mutation was restored: **8 test cases | 0 errors | 0 failures | 0 orphans | exit 0.**

### `tests/unit/player_projectile_test.gd` (5 tests)

| # | Test | Mutation | Result |
| --- | --- | --- | --- |
| 1 | `test_draws_at_z_index_30_and_at_most_70_percent_opacity` | `player_projectile.gd`: `z_index = DRAW_Z_INDEX + 5`, `modulate.a = 1.0` | **FAILED** (2 failures: both properties). Restored, `diff` identical |
| 2 | `test_launch_source_is_a_value_not_a_live_node_reference` | `player_projectile.gd`: `_sweep_and_resolve()`'s `hit_landed.emit(...)` hardcoded to `"MUTATION_WRONG_SOURCE"` instead of `_source` | **FAILED**, isolated cleanly |
| 3 | `test_expires_after_its_lifetime_with_no_target_in_range` | `player_projectile.gd`: the lifetime deadline check in `_physics_process()` short-circuited to `false and ...` | **FAILED**, isolated cleanly (tests 1-2 passed, test 3 failed) |
| 4 | `test_sweep_detects_a_hurtbox_the_projectile_would_otherwise_jump_over` | `player_projectile.gd`: the sweep branch short-circuited to `false and travel.length() > SWEEP_THRESHOLD_PX` | See "Contradictions and ambiguities," item 1 below — the **first** version of this test did **not** fail under this mutation, a real gap this task found and fixed before reporting a result. The **corrected** version **FAILED** cleanly (tests 1-3 passed, test 4 failed) |
| 5 | `test_a_hit_deactivates_the_projectile_so_it_cannot_hit_a_second_target` | `player_projectile.gd`: the `_expire()` call inside `_sweep_and_resolve()`'s hit branch removed | **FAILED** (`hits.size()` became 2, both the near and the far hurtbox), isolated cleanly (tests 1-4 passed, test 5 failed) |

Final re-run after every mutation was restored: **5 test cases | 0 errors | 0 failures | 0 orphans | exit 0.**

## Contradictions and ambiguities — named, not silently resolved

1. **This task's own test for the `intersect_ray` sweep could not catch the defect it was written for, on the first attempt — found by falsification, not by a reviewer.** The first version placed a 2 px-radius hurtbox at x=10 and disabled the sweep to confirm the test would fail; it did not (4/4 passed, 0 failures). Root cause: the test only accounted for the *hurtbox's* radius, not the *projectile's own* `COLLISION_RADIUS_PX` (6 px) — Godot's native, discrete, end-of-tick `Area2D` overlap check compares the two shapes' actual circles, so a hurtbox radius 2 at x=10 already overlaps the projectile's own end-of-tick circle at x=16.67 (distance 6.67 < combined radius 8) without any sweep at all. The corrected version places a 0.5 px hurtbox at x=8 (combined radius 6.5, smaller than one tick's ~16.67 px travel, and positioned so **neither** tick boundary's combined-radius circle reaches it), isolating the projectile's own **zero-width centre-path** — the actual thing `intersect_ray(from, to)` queries — from the native discrete check. Re-run with the sweep disabled: the corrected test **did** fail. This is the fifth named-test blind spot in this project's history (after F01-15, F02-02, F02-16, F03-03) and, per that pattern, caught by the implementer **before** reporting a result rather than by a reviewer afterward.
2. **A plain `int`/`bool` local variable, captured by a lambda connected to a signal and mutated inside it, is not reliably visible to the enclosing test function afterward in this project's GDScript/gdUnit4 combination** — confirmed independently before reading `gdscript-patterns`' own documented pitfall on exactly this (see "GodotPrompter skills consulted"). The first drafts of three tests (`test_does_not_fire_beyond_the_registers_range_and_fires_once_in_range`, `test_set_auto_fire_suppressed_stops_firing_and_unsuppressing_resumes_it`, `test_driven_externally_disables_self_stepping_but_physics_step_still_fires`) used bare `var shots_while_out_of_range: int = 0` / `var fired_in_range: bool = false` style counters; this project's own established convention (`pool_test.gd`'s `created["count"]`, `ghost_hit_test.gd`'s `counters[...]`, `player_scene_test.gd`'s `received["count"]`) already avoids exactly this by wrapping every such counter in a `Dictionary`, and all three tests were rewritten to match before ever being run against real code — so this did not surface as a false pass, but is recorded because it is the second time in this project a lambda-capture caveat has mattered enough to need its own convention (the first being `hits.append(...)`/`fire_log.append(...)`-style `Array` accumulation, already safe because arrays are reference types).
3. **Setting up the real `AutoWeapon` requires a `projectiles_container_path` pointing at a real Node2D, or `Pool.acquire()` silently never adds the projectile to the SceneTree at all.** Found the hard way: the first draft of `weapon_check_test.gd::_build_weapon()` left `projectiles_container_path` unset (matching a plausible, but wrong, reading of `tower_weapon.gd`'s own header comment "optional; null container is tolerated by Pool" as "safe to omit"). Every test timed out with **zero** hits, because `Pool.acquire()` only calls `_container.add_child(instance)` when `_container != null` (`src/core/pool.gd`) — with no container, the acquired `PlayerProjectile` is a real object that never enters the tree, so its own `_ready()` (which builds its `CollisionShape2D` and `Sprite2D`) and `_physics_process()` never run at all. `scenes/tower.tscn` avoids this because it always wires `TowerWeapon.projectiles_container_path = NodePath("../Projectiles")` to a real sibling `Projectiles` node — this task's own first draft of `scenes/player.tscn` made the identical omission for the same reason (no such container existed yet when the node was first added) and was fixed the same way, by adding a `Projectiles` sibling under `Player` and wiring `AutoWeapon.projectiles_container_path` to it. Diagnosed with a throwaway `tests/unit/_diag_test.gd` harness (deleted after use) that printed the pool's own `active`/`free` counts and confirmed both fired projectiles were stuck `active` and inert. Worth a LEDGER row: "optional" in `Pool`'s own contract means "a null container is accepted without erroring," not "gameplay works correctly without one" — the two readings are easy to conflate and this task conflated them once before catching it.
4. **`SimClock` and `EntityRegistry` are shared, never-reset Autoloads across the whole suite run** (same caveat `tower_weapon_test.gd`'s own comments already name): every timing assertion in `weapon_check_test.gd` measures elapsed time (`SimClock.now - start_time`), never an absolute value, for exactly this reason.
5. **gdUnit4 reported `Exit code: 101`** (not one of this project's catalogued 0/100/103/1) on a small, deliberately isolated throwaway diagnostic run whose own `Statistics:` line read `0 errors | 0 failures | ... PASSED`, alongside a benign `ERROR: 1 resources still in use at exit` engine message. Observed once, on a diagnostic file outside the deliverable and now deleted; not reproduced against a real deliverable suite (both `weapon_check_test.gd` and `player_projectile_test.gd` consistently report exit 0 on a clean pass). Recorded per this project's own rule about untested causes, not diagnosed further, and not treated as evidence about the real suites.

## The `driven_externally` / `physics_step()` seam, and how it differs from `tower_weapon.gd`

Per this task's explicit instruction (not `tower_weapon.gd`'s own precedent, which has neither member): `AutoWeapon` exposes `@export var driven_externally: bool = false` and a public `physics_step(delta: float)`, exactly mirroring `src/player/player.gd`'s own convention. `_physics_process(delta)` is a one-line guard (`if driven_externally: return; physics_step(delta)`), so a future SimLoop integration task can call `physics_step()` directly from `sim_loop.gd`'s `_step_04_weapon_targeting_and_firing()` once `driven_externally` is flipped true, without this weapon ever running twice in the same tick. Falsified directly (test 8 above): removing the guard makes the weapon fire on its own even while `driven_externally == true`.

## C-AUTOFIRE: the typed command, and the cross-task seam

`AutoWeapon.set_auto_fire_suppressed(suppressed: bool)` / `is_auto_fire_suppressed() -> bool` gate `physics_step()`'s very first branch. Covered by `weapon_check_test.gd::test_set_auto_fire_suppressed_stops_firing_and_unsuppressing_resumes_it`, falsified above (test 7).

**Unwired half, named rather than silently left implicit:** `src/tower/tower_interaction_radius.gd` (P2.4, out of this task's write scope — `src/tower/**`) already emits `player_entered(body)` / `player_exited(body)` signals when the player's body overlaps the Tower's Interaction Radius. Nothing in this codebase yet connects those two signals to this weapon's `set_auto_fire_suppressed()` command. The natural place is either `src/player/player.gd` (also outside this task's write scope) or a future integration task that owns both the `Player` and `Tower` scenes once they are instanced together under a shared gameplay root (`scenes/main.tscn`, which — per F03-09 and this phase's own entry conditions — contains neither yet). This is a cross-task seam, not a defect in either P2.3 or P2.4's own delivered work.

## Cross-task seams (summary)

1. **C-AUTOFIRE wiring** (above): `tower_interaction_radius.gd`'s signals -> `AutoWeapon.set_auto_fire_suppressed()`. Both halves exist; the connection between two different scenes' node trees does not yet, because neither scene is instanced under a shared root yet.
2. **`driven_externally` / SimLoop step 4**: `sim_loop.gd`'s `_step_04_weapon_targeting_and_firing()` is still an empty stub (`src/core/` out of scope) — this task exposes the seam (`physics_step()`, `driven_externally`) the way `player.gd` already does for steps 1-2, but does not (cannot) wire it. Player, Tower, and now this weapon all self-drive via their own `_physics_process()` today; all three carry the same documented deviation from docs/20's "entities do not run their own gameplay `_physics_process`" rule.
3. **F03-09, second half closed by authoring, first half still open:** authoring `data/weapons/handgun.tres` with `unique_id = "handgun_prototype"` closes the half of F03-09 that was "no real weapon resource exists yet to match `data/player/prototype.tres`'s provisional `starting_weapon_reference_id`." The other half — an actual ID-resolution mechanism, so a `Player` could be handed only a `starting_weapon_reference_id: String` and resolve the real `WeaponDefinition` itself, the way `tower.gd` takes `weapon_definition` as a second directly-assigned export rather than resolving `base_weapon_reference_id` through a registry that does not exist — remains open, for the same reason `tower.gd`'s own evidence report named it open (F03-15 / the p24 report's "Contradictions," item 8): there is no global weapon-ID registry anywhere in this codebase. This task's `AutoWeapon` follows the identical pragmatic pattern: `definition: WeaponDefinition` is a directly-assigned `@export` on the scene node, cross-checked against `Player.definition.starting_weapon_reference_id` via a `push_warning()` in `_check_starting_weapon_reference_id()` (read-only; `src/player/player.gd` itself was never touched).
4. **Tower's own projectile does not implement the `intersect_ray` sweep**, despite `900 px/s` also exceeding the 12 px/tick threshold docs/20 states as unconditional ("At 60 physics ticks per second this is every projectile defined in the prototype -- even the Tower's slowest, at 900 px/s, covers 15 px per tick"). `src/tower/tower_projectile.gd` relies solely on the `area_entered` signal. This is out of this task's write scope (`src/tower/`) to fix; named here as a ledger candidate for whoever next touches that file, not silently copied forward into `player_projectile.gd` (which does implement the sweep).

## Banned-API check

```
bash tools/checks/banned_api_check.sh
```
Output: `Banned-API check: PASS (0 banned calls under src scenes, excluding ui/ directories)`. **Exit status: 0** (checked directly via `$?`, never piped into a pager).

## `run_tests.ps1` result

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit
```

**Exit code: 100** (FAIL — at least one assertion failed under `res://tests/unit`). This is **not attributable to this task's own files.** The full run covers all 43 suites currently on disk, including the two parallel implementers' in-progress work (P2.5, P2.6), which land concurrently with this task per the phase's own "delegated in parallel" note. The failures are:

- `tests/unit/stuck_exemption_test.gd::test_an_enemy_waiting_for_a_full_ring_accrues_no_stuck_time_and_claims_a_freed_slot` — `SCRIPT ERROR: Invalid type in function 'release_claim' in base 'GDScript'... at: EnemyController._exit_tree (res://src/enemy/enemy_controller.gd:236)`. `src/enemy/` is P2.5's write scope, not this task's.
- `tests/unit/tower_cue_audibility_test.gd::test_hud_layout_survives_pseudolocalization_without_silent_truncation` — `Expecting: [3] but was: [0]`. This suite file is P2.6's HUD work (`src/ui/hud.gd` and related), not this task's.

**Every suite this task wrote or touched passed within this same full run**, confirmed by reading the log directly rather than only the top-level exit code:
- `res://tests/unit/weapon_check_test.gd` — 8 test cases | 0 errors | 0 failures | 0 orphans | PASSED
- `res://tests/unit/player_projectile_test.gd` — 5 test cases | 0 errors | 0 failures | 0 orphans | PASSED
- `res://tests/unit/player_scene_test.gd` (checks `scenes/player.tscn`'s structure, including `hitbox_paths`/`hurtbox_paths` this task did not touch) — 13 test cases | 0 errors | 0 failures | PASSED
- `res://tests/unit/main_scene_structure_test.gd`, `player_movement_test.gd`, `player_animation_test.gd`, `player_input_buffer_test.gd`, `player_silhouette_test.gd` — all 0 failures, confirming the `AutoWeapon`/`Projectiles` nodes added to `scenes/player.tscn` did not disturb the player's existing movement, silhouette, animation, or input-buffer behaviour

The engine-error guard (`ENGINE ERRORS:` block, Guard 4 of `run_tests.ps1`, F02-14) reported **9 error line(s)**, all five distinct `SCRIPT ERROR: Invalid type in function 'release_claim'...` lines from `src/enemy/enemy_controller.gd:236` (P2.5) repeated across the run, plus generic end-of-process leak warnings (`ObjectDB instances were leaked`, `1 resources still in use at exit`) that are not attributed to a specific file by the engine. None of these nine lines names `auto_weapon.gd`, `player_projectile.gd`, `handgun.tres`, or `scenes/player.tscn`. This report does not claim the guard passed for the phase as a whole — only that this task's own contribution to the run produced none of the reported engine errors.

**This report does not claim `run_tests.ps1`, the Weapon check, or this phase is passed, satisfied, or ready.** The full-suite exit code is reported honestly as 100, with the specific cause identified by reading the log, not asserted away.

## Escalations

None. Every number this task needed was in the Provisional Values Register (Player & Weapons > "Handgun (Starting Weapon)"; Tower > "Tower Console dwell / auto-fire"; Interfaces > "Readability"). No `# NO REGISTER ROW — escalated` constant was needed.

## Skill conflicts (summary, cross-referenced above)

1. `component-system` rule 2 (signals-only sibling communication) vs. docs/20's typed-command convention — `AutoWeapon._check_starting_weapon_reference_id()`'s direct `get_parent() as Player` read. Third instance of this exact conflict class (after F03-02, F03-11). Project wins, per CLAUDE.md.
2. `godot-testing`'s `test_*.gd` prefix vs. this project's `*_test.gd` suffix (F03-08, re-confirmed, not a new finding).

Neither conflict changed this task's code; both are recorded here because CLAUDE.md requires every skill-vs-project conflict to be recorded, not only the first time it is found.

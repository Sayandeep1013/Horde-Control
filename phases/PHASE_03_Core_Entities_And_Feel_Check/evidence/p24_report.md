# P2.4 Evidence Report — Tower

## GodotPrompter skills consulted

Both required skills were invoked first, before any file was written, per CLAUDE.md's instruction to subagents.

- **`godot-prompter:state-machine`** — read in full. The Tower has no multi-state gameplay FSM of the kind this skill targets (alive/dead is already `DeathState`'s job, built by P1.5 and reused here, not reimplemented). Where the skill's guidance still applied — `TowerWeapon`'s target-acquisition logic ("keep current target unless X or Y") is, in substance, a small enum-shaped state model (idle / engaged) with named transition rules — it was followed: transitions are explicit (`_retarget_if_needed()`'s three named branches: drop-on-Seeker-entry, keep-until-dead-or-left-range, pick-nearest), never implicit fallthrough.
- **`godot-prompter:component-system`** — read in full. Followed: every Tower system is its own single-responsibility `Node`/`Area2D` component (`TowerHealth`, `TowerWeapon`, `TowerInteractionRadius`, `TowerEvolutionStage`, `TowerVisuals`, `TowerProjectile`), each with `@export` configuration and a `configure()` entry point, matching the skill's `HealthComponent`/`HitboxComponent` shape.

**Conflict found and recorded here for the phase LEDGER** (CLAUDE.md: "Where a skill conflicts with docs/20 ... this project wins and the conflict is recorded in the phase LEDGER"):

The component-system skill's rule 2 states components must "communicate via signals, not direct sibling access" — "A component must not call `get_parent().get_node('SiblingComponent')`. Emit a signal instead." This project's own established framework (P1.5's `death_state.gd`, already reused unmodified by `Player.apply_damage()` and by this task) does the opposite for tightly-coupled owned children: `TowerHealth._on_hurtbox_damage_received()` calls `_death_state.apply_damage(remainder, source)` directly, a typed command on a specific, known, owned child — not a signal broadcast. `Tower.configure()` likewise reaches directly into `body`/`hurtbox`/`interaction_radius`'s `CollisionShape2D` children to set radii. This mirrors docs/20 > "Communication, commands" (a typed command is a direct call to a known owner-child; a signal is reserved for "announcing a state change already made," per EventBus's own header) rather than the skill's stricter signals-only rule, which is written for loosely-coupled, freely-mixed components at the scene level, not for a single entity's own internally-composed sub-parts. The project's own convention — already used by `death_state.gd`, `hitbox.gd`, `player.gd` before this task touched anything — wins, and this file's code follows it. **This belongs in the Phase 03 LEDGER as a second recorded skill-vs-project conflict (after P2.2's F03-02), resolved in the project's favour.**

## Files created (all within this task's write scope)

| Path | Purpose |
| --- | --- |
| `data/tower/base.tres` | The `TowerDefinition` contract instance — every Tower number in this task, authored from the Provisional Values Register |
| `data/tower/base_weapon.tres` | The `WeaponDefinition` the Tower's base weapon reads (referenced by ID from `base.tres`, per the contract's `base_weapon_reference_id: String` field) |
| `scenes/tower.tscn` | The assembled Tower scene |
| `src/tower/tower.gd` | `Tower`, the root controller: wires every component to the two resources above |
| `src/tower/tower_health.gd` | `TowerHealth`: health + shield pools, shield-before-health absorption, SimClock-timed regen delay/rate |
| `src/tower/tower_weapon.gd` | `TowerWeapon`: C-TOWERTARGET targeting, fire cadence, projectile pooling |
| `src/tower/tower_projectile.gd` | `TowerProjectile`: the pooled `Area2D` projectile the weapon fires |
| `src/tower/tower_interaction_radius.gd` | `TowerInteractionRadius`: the Interaction Radius `Area2D` trigger |
| `src/tower/tower_evolution_stage.gd` | `TowerEvolutionStage`: the rank-count → stage-index counter |
| `src/tower/tower_visuals.gd` | `TowerVisuals`: cosmetic, tween-driven legibility (health tint, shield shimmer, damage flash, fire pulse) |
| `src/tower/run_termination_recorder.gd` | `RunTerminationRecorder`: the same-tick Tower/Player death-order arbiter (see "Death-resolution ordering" below) |
| `tests/unit/tower_weapon_test.gd` | Tower weapon check (named acceptance test) |
| `tests/unit/tower_same_frame_death_test.gd` | Same-frame death test (named acceptance test) |
| `tests/unit/tower_health_recovery_test.gd` | Health recovery check (named acceptance test) |

Nothing was written outside this list. `src/player/`, `scenes/player.tscn`, `src/camera/`, `scenes/arena.tscn`, `scenes/main.tscn`, `project.godot`, `tests/settings_check.gd`, and everything under `src/core/`, `src/combat/`, `src/debug/`, `src/audio/`, `src/data/` were left untouched (confirmed by `git status --short` before finishing — every other path shown there belongs to the two parallel implementers, P2.1 and P2.2, both of which had already landed real files by the time this task read the tree; neither was modified). No `mcp__godot-comprehensive__*` or `mcp__godot-coding-solo__*` tool was called at all — every Godot invocation in this task ran through Bash against the pinned console executable, per the hard constraints.

## Scene tree built

```
Tower (Node2D, z_index = 25 — docs/20 Scene Tree draw order)
├── Visuals (Node2D, tower_visuals.gd)
│   ├── Sprite (Sprite2D, assets/sprites/tower.png, native scale)
│   └── ShieldShimmer (Sprite2D, same texture, additive-style overlay)
├── Body (StaticBody2D, layer TowerBody, mask none)
│   └── CollisionShape2D (CircleShape2D, footprint radius)
├── Hurtbox (Area2D, hurtbox.gd, faction = TOWER → layer TowerHurtbox)
│   └── CollisionShape2D (CircleShape2D, footprint radius)
├── DeathState (Node, death_state.gd — hurtbox_paths deliberately EMPTY, see below)
├── TowerHealth (Node, tower_health.gd)
├── TowerWeapon (Node, tower_weapon.gd)
├── InteractionRadius (Area2D, tower_interaction_radius.gd, layer InteractionRadius, mask PlayerBody)
│   └── CollisionShape2D (CircleShape2D, interaction radius)
├── TowerEvolutionStage (Node, tower_evolution_stage.gd)
└── Projectiles (Node2D, z_index = 30 — this Tower's own projectile pool container)
```

`Tower` is a standalone scene, not instanced under `scenes/main.tscn` — that file is off-limits to this task and, as of this task's start, contained no Tower, arena, or player either (P2.1/P2.2/P2.4 all land in parallel). Actually instancing `tower.tscn` under the shared gameplay root is left to whichever task next owns `scenes/main.tscn`.

**Cross-task integration note (LEDGER F03-05):** P2.2's arena/camera read "Tower at centre" as the world origin because `tower.tscn` did not exist yet when the arena was built, and set `arena_center = Vector2.ZERO`. This task's Tower scene is never given a non-zero `position` anywhere (every test instances it at the default `Vector2.ZERO`), so the half of F03-05 this task can close on its own is closed: the Tower's own local origin is the world origin, matching P2.2's assumption. The actual wiring of the two scenes together (so the assumption is verified end to end, not just individually consistent) is still open, exactly as F03-05 itself says ("open until P2.4 lands and the two are wired together") — landing is not the same as wiring.

## Every Register value cited, by row name, and where it is read from

All from MASTER_SDLC.md > Provisional Values Register > **Tower** (cited, never restated as a bare literal in any `.gd` file's logic — every number below is read from `data/tower/base.tres` / `data/tower/base_weapon.tres` at runtime via `TowerHealth.configure()` / `TowerWeapon.configure()` / `TowerEvolutionStage.configure()`):

| Register row | Value | Authored in | Read by |
| --- | --- | --- | --- |
| Tower health / shield / regen | 500 HP; base shield 25% (125); regen 10%/s after 8s, delay restarts on every hit including the breaking hit | `base.tres` → `max_health_and_shield_fraction` (500, 0.25), `shield_regeneration` (10.0, 8.0) | `tower_health.gd`'s `configure()`, `_on_hurtbox_damage_received()`, `_try_regenerate_shield()` |
| Tower footprint / Interaction Radius | 106 px / 160 px | `base.tres` → `tower_footprint` (106, 160) | `tower.gd`'s `configure()` → `_apply_circle_radius()` on `Body`, `Hurtbox`, `InteractionRadius`'s `CollisionShape2D`s |
| Tower base weapon | 20 dmg × 1.25 shots/s (25 DPS), range 480 px, projectile 900 px/s; targeting rule (C-TOWERTARGET) | `base_weapon.tres` → `damage_band.value` (20), `engagement_rhythm.fire_rate_per_second` (1.25), `projectile_definition.speed_px_per_second` (900); `base.tres` → `targeting_rule_parameters.range_px` (480), `intent_preference` (0 = TowerSeeker) | `tower_weapon.gd`'s `configure()`, `_retarget_if_needed()`, `_fire_at()` |
| Tower HP regen | None passive; Repair only | `tower_health.gd` — `_try_regenerate_shield()` only ever touches `current_shield`; `_death_state.current_hp` is never incremented anywhere in this file | (absence verified by inspection; no test asserts a negative, per the project's own "name it" instruction this is stated rather than silently assumed complete) |
| Tower evolution thresholds | 0 / 1 / 3 / 6 ranks (Base / Reinforced / Armed / Fortress) | `base.tres` → `evolution_stage_thresholds = [0, 1, 3, 6]` | `tower_evolution_stage.gd`'s `configure()` / `_stage_for_ranks()` |
| Tower Repair price | min(50, missing health rounded down to an even number, 2 × Scrap held) at 1 Scrap per 2 health; ≥2 missing health and ≥1 Scrap to be affordable (C-REPAIR) | `base.tres` → `repair_price` (`scrap_cost=1`, `health_restored=2`, `pro_ration_rule=` the full formula as a description string, per `repair_price.gd`'s own documented convention for this field) | Not consumed by any code in this task — Repair/the Tower Console is not in this task's scope (see "Scope boundaries"); authored on the contract instance only, so the contract is complete |

The Run Termination and SimLoop-order citations (death-resolution order; same-tick rule) are in the next section, since they are process, not a single value.

## Death-resolution ordering, and how the test proves it

MASTER_SDLC.md > "Edge Cases and Failure States" > Run Termination: *"Player and Tower reach zero on the same frame → Deterministic order from the Determinism rule: the Tower's depletion resolves first. Run ends, cause recorded as Tower."* docs/20_Technical_Architecture.md > "SimLoop order," step 8: *"death resolution in order Tower, bosses, player, other enemies."*

**The integration gap, named rather than silently resolved.** docs/20's own step 8 is the intended real hook (`src/core/sim_loop.gd`'s `_step_08_death_resolution()`), but that method is still an empty stub as of this task, and `src/core/` is outside this task's write scope. So this task built `RunTerminationRecorder` (`src/tower/run_termination_recorder.gd`) as a **self-contained, independently testable implementation of the documented category order**, not wired into the real SimLoop. Wiring it there (or replacing it with an equivalent) is left to whichever future task next owns `sim_loop.gd`.

**How it works:** `record_tick_deaths(categories_reached_zero_this_tick: Array, sim_time: float)` takes the *set* of categories (`TOWER`, `BOSS`, `PLAYER`, `ENEMY`) that reached zero on one tick — order the caller supplies them in is irrelevant, only category membership matters — and returns the first one present in the fixed, verbatim-transcribed order `[TOWER, BOSS, PLAYER, ENEMY]`. Once a cause is recorded, `_run_ended` latches true and every later call returns `null`, so a death on a *later* tick can never retroactively become the recorded cause.

**The test (`tests/unit/tower_same_frame_death_test.gd`), genuine case, not a near-miss:** `test_genuine_same_tick_zero_zero_credits_the_tower` instances the **real** `scenes/player.tscn` (P2.1) and the **real** `scenes/tower.tscn`, applies a lethal hit to the Tower's hurtbox and a lethal `apply_damage()` to the Player within the same synchronous test function — no `await`, no frame boundary between the two calls, which is what "the same tick" means operationally, since nothing can happen between two statements in one synchronous call with no yield. Both `death_state.is_dead` flags are confirmed true, then `RunTerminationRecorder.record_tick_deaths([PLAYER, TOWER], sim_time)` — matching what a real step-8 arbiter would have observed for that tick — is asserted to return `TOWER`.

## All three acceptance tests: commands, exit codes, falsification logs

Godot: `/d/godot/Godot_v4.7.1-stable_win64_console.exe` (pinned 4.7.1 console build, per the hard constraints). Import pass run before every test invocation below.

### Tower weapon check — `tests/unit/tower_weapon_test.gd`

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/tower_weapon_test.gd --ignoreHeadlessMode
```
Final result: **5 test cases | 0 errors | 0 failures | 0 orphans | exit 0.**

Five scenarios, each falsifying a distinct part of C-TOWERTARGET:
1. Fires on the Register's cadence (0.8s between shots) at the Register's damage (20/shot).
2. Prefers a **farther** Tower Seeker over a **nearer** non-Seeker.
3. Drops a non-Seeker target the tick a Seeker enters range.
4. Keeps its current target even when a strictly closer enemy appears (retargets only on death/leaving range).
5. Actually kills a target within the expected number of shots.

**Falsified by mutation (implementation deliberately broken, confirmed the test catches it, then restored and re-run green):**
- **Mutation 1 — Seeker priority disabled** (`_retarget_if_needed()`'s `seekers_in_range` forced to `[]`): `test_prefers_a_farther_tower_seeker_over_a_nearer_non_seeker` **FAILED** (1 failure). Restored; `diff` against the pre-mutation backup confirmed byte-identical; suite re-run **5/5 green**.
- **Mutation 2 — wrong damage-per-shot** (`data/tower/base_weapon.tres`: `value = 20` → `value = 15`): `test_fires_at_the_registers_cadence_and_damage_per_shot` **FAILED** (3 failures — every recorded shot amount mismatched). Restored; `diff` confirmed byte-identical; suite re-run **5/5 green**.

### Same-frame death test — `tests/unit/tower_same_frame_death_test.gd`

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/tower_same_frame_death_test.gd --ignoreHeadlessMode
```
Final result: **7 test cases | 0 errors | 0 failures | 0 orphans | exit 0.**

Seven tests: the genuine same-tick case (real Player + real Tower); reversing the pure resolver's input order; reversing which real entity is damaged first in code; the pure one-tick-apart case; the real-entity one-tick-apart case (an actual `await get_tree().physics_frame` between the two hits); an ordinary enemy death alone never ending the run; `Tower.gd`'s own wiring reporting its death to an injected recorder.

**Falsified by mutation, exactly the two the task named, plus restore-and-re-run-green after each:**
- **Reversing the resolution order:** `RESOLUTION_ORDER` temporarily edited from `[TOWER, BOSS, PLAYER, ENEMY]` to `[PLAYER, BOSS, TOWER, ENEMY]`. Re-ran the suite: `test_genuine_same_tick_zero_zero_credits_the_tower` **FAILED** (asserted `cause == TOWER`, got `PLAYER`). Restored (`diff` confirmed byte-identical); suite re-run **7/7 green**.
- **Making the two deaths one tick apart:** the `if _run_ended: return null` early-exit guard temporarily commented out (so a later tick's death can overwrite an earlier recorded cause). Re-ran the suite: `test_pure_one_tick_apart_deaths_credit_whichever_died_first_and_the_later_one_does_not_overwrite_it` **FAILED** (2 failures — the later Tower death was no longer rejected, and it overwrote the recorded `PLAYER` cause). This is exactly the property the "reversing order" mutation did **not** touch (that mutation left both same-tick tests correctly distinguishing "PASS" from "the intentionally-broken order still gives *a* deterministic answer, just the wrong one" — the one-tick-apart mutation instead breaks the *latching*, a different mechanism, so the two mutations exercise genuinely different code paths, confirming the test suite distinguishes the two failure modes the task asked for). Restored (`diff` confirmed byte-identical); suite re-run **7/7 green**.

**A genuine harness finding, surfaced while building the one-tick-apart real-entity test, worth recording:** the **first** `await get_tree().physics_frame` inside a gdUnit4 test function does not reliably correspond to a fresh `SimClock.now` tick — a throwaway diagnostic probe showed `t1 == t2` across exactly one await, then `t3`, `t4` each correctly advanced by one `PHYSICS_STEP` across the next two awaits. This is the same root phenomenon `tests/unit/pause_clock_test.gd`'s own `before_test()` comment already names for a *freshly-added node* ("not guaranteed to receive its first `_physics_process` call on the very next awaited physics_frame... one untested warm-up tick settles it"), but reproduced here for the test **function's own coroutine resumption**, not for a freshly-added node — the `SimClock` Autoload is not freshly added, it is the persistent singleton. `test_real_entities_one_tick_apart_do_not_get_credited_to_the_tower` now opens with one explicit warm-up `await` before it starts relying on "one await = one real tick," with the diagnosis recorded in the test's own comment. **This should go in the Phase 03 LEDGER** — it is a real, reproduced, previously-uncatalogued engine/harness quirk (related to but distinct from F03-04), not diagnosed to root cause, recorded per this project's own rule about untested causes.

### Health recovery check — `tests/unit/tower_health_recovery_test.gd`

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/tower_health_recovery_test.gd --ignoreHeadlessMode
```
Final result: **5 test cases | 0 errors | 0 failures | 0 orphans | exit 0.**

Five tests, measured against a **fresh injected `SimClock` instance** (see "Contradictions" below for why not the real Autoload), driven by direct `.now` assignment plus manual `_physics_process()` calls rather than real ticks — no Area2D overlap is needed for this component, unlike the weapon check, so this is deterministic and fast (all five run in ~0.4s real time versus what an 8-second delay's worth of real ticks would cost):
1. No regen before the Register's delay elapses.
2. Regen at the Register's rate once past the delay, with a second-tick check that regen does not double-count elapsed time.
3. The delay restarts on every hit, including a hit that lands **after** the shield is already broken (pure health damage) — constructed so a "measure from the first hit" bug and the correct "measure from the most recent hit" behaviour would disagree at the exact moment checked.
4. Shield clamps at its maximum and never overshoots.
5. A destroyed Tower's shield does not regenerate.

**Falsified by mutation, restore-and-re-run-green after each:**
- **Delay-restart disabled** (`_last_damage_sim_time` only ever set on the *first* hit): `test_shield_regen_delay_restarts_on_every_hit_including_after_the_shield_breaks` **FAILED**. Restored; `diff` confirmed byte-identical; suite re-run **5/5 green**.
- **Clamp removed** (`minf(max_shield, ...)` → unclamped): `test_shield_regenerates_at_the_registers_rate_once_the_delay_has_elapsed` **FAILED** (shield read back as 196.25 against an expected clamped 125 — the 8.1s-since-delay tick alone is enough to exceed the shield's own maximum, so this test catches the missing clamp on its own, before the suite even reaches the test named for it directly; gdUnit4 stops a suite file at its first failure — LEDGER F02-08 — so the dedicated clamp test never got a chance to run in this particular mutated pass, but the mechanism it would have caught is the same one this test already caught). Restored; `diff` confirmed byte-identical; suite re-run **5/5 green**.

## The `run_tests.ps1` result

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit
```
Output tail: `PASS (exit 0): 245 test case(s) executed under res://tests/unit, all passed.` Exit code **0**. No `ENGINE ERRORS:` line was printed (the script's Guard 4 — LEDGER F02-14 — scans every `ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR:`-prefixed line across the whole run and would have failed the run even at exit 0 if any had appeared; none did).

## New total

**245 test cases**, all passing, 0 errors, 0 orphans (via both the direct gdUnit4 CLI run and `run_tests.ps1`). This task's own contribution is **17** of the 245 (5 weapon + 7 same-frame-death + 5 health-recovery). The starting figure this task was told not to break was 172; the difference (245 − 172 − 17 = 56) is the two parallel implementers' (P2.1 player, P2.2 arena/camera) own tests, which had already landed by the time this task finished, confirmed still green.

## Contradictions and ambiguities — named, not silently resolved

1. **`SimClock.now` and the first `await get_tree().physics_frame` in a test** — covered in full under the same-frame death test section above.
2. **`src/core/sim_clock.gd`'s own header comment names a `reset_for_test()` method that does not exist anywhere in the file or the codebase** (`grep -rn "reset_for_test" src/ tests/` finds only the one comment reference). This task's tests inject a fresh `SimClockScript.new()` instance instead (matching `tests/unit/pause_clock_test.gd`'s own established pattern), which sidesteps the missing method rather than needing it, but the stale doc comment is itself worth a LEDGER row since a future reader could reasonably go looking for a method that is not there.
3. **DeathState's `hurtbox_paths` auto-wiring assumes one health pool.** `src/combat/death_state.gd`'s `_resolve_refs()` connects every hurtbox in `hurtbox_paths` directly to `apply_damage(amount)` with the *full* incoming amount — correct for every existing user (the placeholder enemy, the Player), wrong for the Tower's two-pool shield-then-health rule. This task's `TowerHealth` therefore deliberately leaves the Tower's `DeathState.hurtbox_paths` **empty** in the scene (no auto-connect) and replicates, by hand, the two Logical Death cleanup calls (`mark_dead()`, `apply_logical_death_layers()`) DeathState would otherwise have made, from a listener on `DeathState.logical_death`. Documented in full in `tower_health.gd`'s own header. `src/combat/death_state.gd` was not edited (outside this task's scope) and this is the reason why, spelled out rather than left implicit.
4. **`DeathState`'s Logical Death path unconditionally calls `EventBus.emit_enemy_died()`,** even for the Tower (which is not an enemy). This is inherited framework behaviour this task did not introduce and cannot fix without editing `src/combat/death_state.gd` (forbidden). A future listener that assumes every `enemy_died` signal means "spawn enemy drops" would misfire on a Tower death; nothing in this phase currently listens for that, so it is not yet a live bug, but it is a real, load-bearing naming mismatch worth a LEDGER row for whoever builds the drops system.
5. **The `&"tower_seeker"` EntityRegistry tag is a new convention this task introduces**, not a fact already true elsewhere in the codebase — no real Tower Seeker enemy exists yet (P2.5). `TowerWeapon` queries both `&"enemy"` (already established by `entity_spawner.gd`) and `&"tower_seeker"` (new). **P2.5 must register real Tower Seekers under both tags** for C-TOWERTARGET's Seeker-priority rule to work against real content; until then, the rule is correct and tested, but only against the test fixtures this task builds, not yet against a real Seeker.
6. **`SimLoop` step 4 (weapon targeting/firing), step 5 (projectile sweep), and step 8 (death resolution) are still empty stubs** in `src/core/sim_loop.gd`, and `src/core/` is outside this task's write scope. `TowerWeapon`, `TowerProjectile`, and the Tower's own Logical-Death → `RunTerminationRecorder` wiring therefore each run their own `_physics_process()` rather than being called by SimLoop, a deliberate, documented deviation from docs/20's "entities do not run their own gameplay `_physics_process`" rule (the same deviation P2.1's `player.gd` already records for exactly the same structural reason, in its own header, for steps 1–2). Wiring all of this into the real SimLoop is left to whichever future task next owns `sim_loop.gd`.
7. **`TowerProjectile`'s collision radius (6 px) is a framework/rendering constant, not a Register number** — no Register row sizes a generic projectile's own hit-detection circle (only entity body/hurtbox radii and the weapon's own damage/range/speed, all of which *are* Register-sourced). Named explicitly in the file's own header, mirroring the same carve-out `death_state.gd`'s placeholder `max_hp` and `hitbox.gd`'s placeholder `damage` already use.
8. **The Tower's base weapon resource (`data/tower/base_weapon.tres`) lives under `data/tower/`, not `data/weapons/`.** `TowerDefinition.base_weapon_reference_id` is typed as a bare `String` (a Weapon Definition Unique ID) per the contract — there is no global weapon-ID registry anywhere in this codebase yet to resolve that string against a resource at runtime, and this task's write scope does not include `data/weapons/` (P2.3's own path, per `phases/PHASE_03_Core_Entities_And_Feel_Check/PLAN.md`'s P2.3 row: `data/weapons/handgun.tres`, which did not exist on disk as of this task — P2.3 had not landed). `Tower.gd` therefore takes `weapon_definition` as a second, directly-assigned `@export` resource (matching `base_weapon_reference_id` by ID, with a `push_warning()` if the two ever disagree) rather than resolving the ID through a registry that does not exist. This is a pragmatic, working answer to a contract field with no resolver yet, not a silent reinterpretation — named here for whichever future task builds that registry.
9. **`data/tower/base_weapon.tres`'s `projectile_definition.lifetime_seconds` (0.586667) is derived, not a Register literal**: `range_px ÷ speed_px_per_second × 1.1` = `480 / 900 × 1.1`, a 10% safety margin over the exact travel time to the Tower's own maximum weapon range, so a shot fired at a target sitting exactly at max range does not expire one frame short of arriving. The Register gives range and speed as two separate numbers with no combined "projectile lifetime" row; this is this task's own derivation from those two Register numbers, named rather than presented as if it were itself a fifth Register value.

## Never stated as passed, satisfied, or ready

Every check above is reported as "N test cases, 0 errors, 0 failures, exit 0" and every Register citation is reported as "read from, not restated" — this report does not assert that the Tower weapon check, the Same-frame death test, the Health recovery check, or any project gate is passed, satisfied, or ready. That determination is for the reviewers and the author.

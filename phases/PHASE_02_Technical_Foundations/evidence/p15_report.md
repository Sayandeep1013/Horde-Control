# P1.5 Evidence Report — Collision Layers, Hitbox/Hurtbox Framework, Death State

Plan ID: P1.5 (`phases/PHASE_02_Technical_Foundations/PLAN.md` § "P1.5").
This document records what was built, the layer/mask assignment diffed
against the Provisional Values Register row, the Logical/Visual Death
sequence step by step, which flags change on Logical Death and how they
line up with what `Pool.acquire()` restores, the `set_entity_alive()`
ruling, the Ghost hit test with its kill-window justification and both
fresh and pooled runs, the falsification log, and every contradiction or
ambiguity found. It does not assert that any gate is passed, satisfied,
met, or ready — that is for reviewers and the author (CLAUDE.md;
phases/README.md loop rule (e)).

## GodotPrompter skills consulted

Invoked **before** writing any code, per CLAUDE.md's rule for subagents
writing Godot code.

- **`physics-system`**: confirms `Area2D` for hitboxes/hurtboxes (already
  docs/20's own rule), the layer/mask mental model ("Layer = I am, Mask = I
  scan for"), and — the one piece that shaped this task directly — the
  collision-shape `set_deferred` warning, which this task's own components
  generalize to every Logical Death flag, not only `CollisionShape2D.disabled`.
- **`state-machine`**: the enum-based approach ("fewer than 5 states, no
  significant enter/exit logic") is the right fit for Logical→Visual Death
  (two phases, `is_dead` as the discriminator) — used rather than a full
  node-based FSM, since `death_state.gd`'s own enter/exit logic is entirely
  contained in `_enter_logical_death()`/the Visual Death timer, with no
  benefit to splitting it into separate State nodes for two phases.

No conflict between either skill and docs/20, the Provisional Values
Register, or an Author decision was found; nothing to record in the phase
LEDGER for this task.

## Files created (all within this task's write scope)

- `src/combat/collision_layers.gd` — `class_name CollisionLayers`, the
  single transcription of the binding 16-layer table into named bit
  constants and pre-composed masks. Every other file below references these
  instead of re-typing layer numbers.
- `src/combat/hitbox.gd` — `class_name Hitbox extends Area2D`.
- `src/combat/hurtbox.gd` — `class_name Hurtbox extends Area2D`.
- `src/combat/death_state.gd` — `class_name DeathState extends Node`, the
  Logical/Visual Death state machine.
- `src/combat/placeholder_enemy.gd` — `class_name PlaceholderEnemy extends
  CharacterBody2D`, wiring the three above together.
- `scenes/entities/placeholder_enemy.tscn` — the placeholder enemy scene
  (body + `BodyShape`, `Hurtbox` + shape, `Hitbox` + shape, `DeathState`).
- `tests/unit/hitbox_hurtbox_test.gd` — component correctness coverage (15
  tests).
- `tests/unit/death_state_test.gd` — death-state correctness coverage (13
  tests).
- `tests/unit/ghost_hit_test.gd` — the named acceptance test (4 tests: a
  positive control, the 100-trial fresh run, the 100-trial pooled run, and
  a 10-trial same-tick-race variant).
- This report.

`src/core/pool.gd`, `entity_registry.gd`, `entity_spawner.gd`, and every
other file outside the permitted write scope were read but not modified.

## Layer/mask assignment, diffed against the Register row

MASTER_SDLC.md § Provisional Values Register → "Collision layers (binding)"
row (owner document 20), transcribed once into `collision_layers.gd` as
named bit constants. `hitbox.gd`/`hurtbox.gd`/`placeholder_enemy.gd` apply
only these constants — no other file restates a layer number.

| Register row | `CollisionLayers` constant | Applied by |
| --- | --- | --- |
| 1 PlayerBody, masks 2,3,4,15 | `MASK_PLAYER_BODY` | defined for future use; no Player scene exists yet (out of P1.5 scope) |
| 2 EnemyBody, masks 1,2,3,4,15 (flying drop 4) | `LAYER_ENEMY_BODY` / `MASK_ENEMY_BODY_GROUND` | `placeholder_enemy.gd` (ground enemy; flying carve-out not implemented, named as N/A rather than silently dropped) |
| 8 PlayerHurtbox, masks none | `LAYER_PLAYER_HURTBOX` | `hurtbox.gd` `Faction.PLAYER`; used by the Ghost hit test's victim fixture |
| 9 EnemyHurtbox, masks none | `LAYER_ENEMY_HURTBOX` | `hurtbox.gd` `Faction.ENEMY` (default); the placeholder enemy's own hurtbox |
| 10 TowerHurtbox, masks none | `LAYER_TOWER_HURTBOX` | `hurtbox.gd` `Faction.TOWER`; defined, unused by the placeholder |
| 11 EnemyHitbox, masks 8 (and 10 only for telegraphed Tower attacks) | `LAYER_ENEMY_HITBOX` / `MASK_ENEMY_HITBOX_PLAYER_ONLY` / `MASK_ENEMY_HITBOX_PLAYER_AND_TOWER` | `hitbox.gd`, gated by `targets_tower` |
| Logical Death dying-body mask: World(4) + ArenaBounds(15) | `DYING_BODY_MASK` | `death_state.gd`'s `_enter_logical_death()` |

**The binding table defines exactly one Hitbox row** (EnemyHitbox). Player
and Tower deal damage through projectiles (layers 5/6) in this table, not a
melee "hitbox" `Area2D` — there is no PlayerHitbox/TowerHitbox row to
implement. `hitbox.gd`'s header names this explicitly rather than
generalizing to a `Faction` enum with invented layer numbers the way
`hurtbox.gd` does (whose three rows — 8/9/10 — are all real). This is a
scope boundary, not an omission: a future Player/Tower melee or contact
attack would need a new Register row before this file could serve it.

**Entity sizes** (docs/20 § Physics & Collisions § "Entity sizes", cited
directly since docs/20 is the owner document for these values, not
restated in the Register): placeholder body radius 14 px ("Opportunist 14
px"), hitbox radius 20 px (body radius + 6, "Every enemy's contact hitbox
radius is its body radius plus 6 px"). Hurtbox radius 14 px — this file's
own interpretation, named rather than assumed: docs/20 states "hurtbox
equals the body" explicitly only for the Player; extended here to the
placeholder enemy for simplicity.

## Logical vs. Visual Death, step by step

`death_state.gd`'s own header comment is the authoritative version of this
sequence; summarized here:

1. `apply_damage(amount, source)` is called. If `is_dead` is already true,
   the call is discarded before HP is touched — "checked first by every
   damage handler" (docs/20 § Logical Death).
2. HP drops. If still > 0, nothing else happens.
3. If HP ≤ 0, `_enter_logical_death()` runs, **in this exact order**:
   a. `is_dead = true` — synchronous, first, unconditional.
   b. Every hurtbox's `mark_dead()` — synchronous.
   c. Every hitbox's `deactivate_window()` — Animation Cancellation
      (synchronous `_window_active = false` **and** deferred
      `monitoring = false` / shape `disabled = true`).
   d. Every hurtbox's `apply_logical_death_layers()` — deferred
      `monitorable = false`, `collision_layer = 0`.
   e. The body's `collision_layer = 0` (deferred), `collision_mask =`
      World+ArenaBounds only (deferred).
   f. `EntityRegistry.set_entity_alive(entity, false)`, if registered.
   g. `EventBus.emit_enemy_died(entity, position)`.
   h. This node's own `logical_death` signal.
4. Visual Death: while `is_dead` is true, `_physics_process` compares
   `SimClock.now` against a deadline set at step 3 (`SimClock.now +
   visual_death_duration`), never a raw per-frame countdown (see "Visual
   Death timing is SimClock-driven" below). The body keeps its
   World+ArenaBounds mask throughout (docs/20 § Spatial Cleanup).
5. On timer expiry: `visual_death_finished` is emitted. `death_state.gd`
   does **not** call `Pool.release()`/`EntitySpawner.despawn_enemy()`
   itself — docs/20 § Communication, events: "A system emits a signal; it
   never calls a mutating function on another system." The owner (whatever
   wires the placeholder enemy up) connects this signal and despawns.

## Which flags change on Logical Death, lined up against `Pool.acquire()`

`pool.gd`'s own header names the four things it restores: hitbox
`monitoring`; hurtbox `monitorable` and `collision_layer`; body
`collision_layer` and `collision_mask`. `death_state.gd`'s
`_enter_logical_death()` changes exactly these, and nothing else that Pool
would need to know about:

| Flag Pool restores | Where death_state.gd sets it | Deferred? |
| --- | --- | --- |
| hitbox `monitoring` | `hitbox.deactivate_window()` | yes (`set_deferred`) |
| hurtbox `monitorable` | `hurtbox.apply_logical_death_layers()` | yes |
| hurtbox `collision_layer` | `hurtbox.apply_logical_death_layers()` | yes |
| body `collision_layer` | `_body.set_deferred("collision_layer", 0)` | yes |
| body `collision_mask` | `_body.set_deferred("collision_mask", CollisionLayers.DYING_BODY_MASK)` | yes |

All three components (`hitbox.gd`, `hurtbox.gd`, `placeholder_enemy.gd`)
join `pool_hitbox`/`pool_hurtbox`/`pool_body` respectively in their own
`_ready()`, matching `pool.gd`'s discovery convention exactly.

**Two protections beyond what Pool restores, both required by docs/20, not
one redundant with the other:**
1. `hitbox._window_active` and `hurtbox.is_dead` — synchronous, plain
   GDScript booleans, flipped immediately (never deferred) and checked
   first by `_on_area_entered()` / `receive_hit()`. This is what makes a
   same-tick overlap signal already in flight (fired by the physics engine
   before a deferred flag has landed) get rejected anyway — a deferred
   engine flag alone cannot retroactively cancel a signal that already
   started dispatching earlier in the same tick.
2. The five deferred engine-level flags above — required independently for
   what they do at the physics-server level (an `intersect_ray` sweep
   passing through a corpse; a future frame's overlap detection never
   starting at all), not merely as a second attempt at the same job flag 1
   does.

This distinction is not academic — see "Falsification 3" below, where it
is exactly what a broken engine flag hides from the acceptance test.

## The `set_entity_alive()` seam — ruling

**Use it.** `death_state.gd`'s `_enter_logical_death()` calls
`EntityRegistry.set_entity_alive(entity, false)` at Logical Death (step
3f), if the entity is currently registered.

Reasoning, recorded in `death_state.gd`'s own header: `set_entity_alive()`
flips a registered entity's liveness for QUERY purposes without
deregistering it — exactly `entity_registry.gd`'s own stated purpose for
the method ("this is the one sanctioned channel for that flag to reach the
registry's query results"). The alternative — deregistering at Logical
Death — would contradict `entity_spawner.gd`'s own header, which states
deregistration happens at DESPAWN (`Pool.release()`), specifically so "a
dying-but-not-yet-pooled entity ... stays registered with alive=false and
is excluded from live queries by that flag, not by being torn out of the
registry." Wave/encounter completion (docs/11: "driven by EntityRegistry
tag queries against actual live entities") needs an enemy mid-Visual-Death
to stop counting toward a wave's live-enemy total immediately, well before
its Visual Death animation finishes and it is actually pooled — which is
exactly what `set_entity_alive(false)` at Logical Death, followed by
deregistration later at despawn, provides. Verified directly by
`death_state_test.gd`'s `test_logical_death_marks_the_registered_entity_not_alive`,
which asserts the entity is marked not-alive but remains registered.

## The Ghost hit test

### The kill window, stated precisely

Per trial: `attacker.start_attack_window()` opens the attack (hitbox
`monitoring` and its `CollisionShape2D.disabled` both go through
`set_deferred`), and **one physics frame is awaited** so those deferred
writes actually land — "hitbox activating" is complete. THEN, in a single
synchronous step with **no `await` in between**: the victim's hurtbox is
moved into the now-active hitbox's overlap range (the attack geometrically
"reaches" its target this instant), and the attacker is immediately dealt
a lethal blow via `apply_damage()`. This places the kill strictly BEFORE
the next physics step: the overlap that would resolve into a hit has just
been made true, but the physics engine has not yet had a single tick to
detect it and fire `area_entered` — the literal "window between a hitbox
activating and its damage resolving" the task brief names. Killing an idle
enemy proves nothing, because an idle hitbox was never monitoring in the
first place; there is no live overlap for a bug to leak through.
`test_positive_control_hit_lands_when_attacker_is_not_killed` proves the
identical fixture geometry DOES land a hit when the attacker is not
killed, so a permanent zero cannot be an artifact of the fixture failing
to attack at all.

A second, smaller-N adversarial variant
(`test_10_same_tick_race_kills_produce_zero_ghost_hits`) goes further: a
real, second `Hitbox` ("the killer") is positioned to newly overlap the
attacker's own hurtbox on the **identical physics step** that the
attacker's hitbox newly overlaps the victim — i.e. the kill is delivered
by a genuine `area_entered` signal fired *during* physics processing, not
by a direct method call from test code. Across all 10 trials Godot
consistently dispatched the killer's `area_entered` (which kills the
attacker) before the attacker's own attack's `area_entered` (`ordering =
"kill_first"` in all 10 trials, `str={"kill_first": 10}` — reproduced, not
assumed) — meaning by the time the attacker's own hitbox signal ran, its
`_window_active` flag was already synchronously false. `victim_hits`
stayed 0 in every one of the 10 race trials. The test's own assertion is
deliberately weaker than the main 100-trial test (it does not assert
`victim_hits == 0` unconditionally, since an attack that genuinely
resolved before the kill within the same tick would not be a bug); it
instead asserts the observed ordering is consistent across all 10 trials
(it was) and that neither event went unobserved (neither did).

### Fresh instances (100 trials)

`test_100_mid_attack_kills_produce_zero_post_death_damage_events_fresh`:
100/100 trials confirmed the attack window was active before the kill,
100/100 confirmed Logical Death, **0 total damage events landed on the
victim, 0 total hit reports from the attacker's own hitbox.** PASSED.

### Pooled instances (100 trials, reused, cap of 5)

`test_100_mid_attack_kills_produce_zero_post_death_damage_events_pooled`:
a `Pool` of cap 5 cycles `acquire()`/`release()` across all 100 trials
(`distinct_instances.size() ≤ 5`, confirming genuine reuse, not 100 fresh
allocations). `attacker.reset_for_reuse()` is called immediately after
every `acquire()` — the entity's own responsibility, since `Pool.acquire()`
restores only the four engine flags and has no knowledge of
`death_state.gd`'s own `is_dead`/`current_hp`. Same result: 100/100 window
active, 100/100 confirmed dead, **0 total damage events, 0 total hit
reports.** PASSED.

A prior manual check (`death_state_test.gd`'s
`test_reset_for_reuse_clears_is_dead_and_restores_hp_and_child_flags`)
confirms this reset is not a no-op: it asserts a reused instance can
successfully take damage again after `reset_for_reuse()`, so the pooled
Ghost hit test's zero-hit result is not an artifact of a still-"dead"
instance refusing every interaction.

### Total unit-test count

**172 test cases, 0 errors, 0 failures**, run via the mandated command
(`--headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a
res://tests/unit --ignoreHeadlessMode`, after `--import`), confirmed on two
consecutive full runs. 140 pre-existing + 32 new (15 `hitbox_hurtbox_test.gd`
+ 13 `death_state_test.gd` + 4 `ghost_hit_test.gd`).

### Falsification log

Per LEDGER F02-08 (a failure stops the remaining tests in that suite file),
every mutation below was followed by a full re-run to confirm green before
moving to the next.

**Falsification 1 — Logical Death does not disable the hurtbox** (the
deferred `hb.apply_logical_death_layers()` call removed from
`_enter_logical_death()`, `hb.mark_dead()` left in place):
- **Ghost hit test: stayed GREEN (all 4 tests).** Finding, stated plainly:
  none of the Ghost hit test's scenarios re-attack the dying attacker's own
  hurtbox a second time, so this mutation is invisible to it. The
  synchronous `is_dead` flag `mark_dead()` still sets is a genuinely
  separate protection that this specific falsification did not touch.
- **Direct unit coverage caught it**:
  `death_state_test.gd`'s `test_logical_death_clears_hurtbox_monitorable_and_layer_deferred`
  FAILED (`monitorable` still true, `collision_layer` still 256 instead of 0).

**Falsification 2 — disable the hitbox directly instead of deferred**
(`hitbox.gd`'s `deactivate_window()` changed to assign `monitoring = false`
and `child.disabled = true` directly, not via `set_deferred`):
- **Ghost hit test: stayed GREEN on damage-count assertions (all 4
  tests)** — but the same-tick race variant produced **10 genuine Godot
  engine errors**, one per trial: `ERROR: Can't change this state while
  flushing queries. Use call_deferred() or set_deferred() to change
  monitoring state instead.` This is the exact error docs/20's physics
  caution warns about, reproduced by killing the attacker from inside a
  real `area_entered` physics callback. Finding, stated plainly: gdUnit4's
  own pass/fail and its `0 errors` suite statistic do **not** surface this
  engine-level `ERROR:` line — only reading stderr does. A reviewer relying
  solely on the green checkmark and the reported error count would miss a
  real defect that fires on every single trial.
- **Direct unit coverage caught it**:
  `hitbox_hurtbox_test.gd`'s `test_deactivate_window_monitoring_change_is_deferred_not_immediate`
  FAILED (expected `monitoring` still true immediately after the call; got
  false).

**Falsification 3 — skip one of the four flags the pool restores**
(`hitbox.gd`'s `deactivate_window()` changed to never clear `monitoring` at
all — commented out — leaving only the synchronous `_window_active` flag
and the shape disable):
- **Ghost hit test: stayed GREEN (all 4 tests), including the same-tick
  race variant.** This is the sharpest finding of the three. The
  synchronous `_window_active` guard alone was sufficient to defeat every
  scenario this acceptance test constructs, meaning **the named Ghost hit
  test does not, by itself, prove `hitbox.monitoring` is ever correctly
  cleared** — a regression in that specific engine flag (exactly the flag
  `Pool.acquire()` is contracted to restore) is invisible to it.
- **Direct unit coverage caught it**: `hitbox_hurtbox_test.gd`'s
  `test_deactivate_window_monitoring_change_is_deferred_not_immediate` and
  `death_state_test.gd`'s
  `test_logical_death_deactivates_every_hitbox_synchronously_and_deferred`
  both FAILED.

**After each falsification, the mutation was reverted (verified with
`diff` against a pre-falsification backup copy of the three files) and the
full 172-test suite re-run to a clean 0 errors / 0 failures result**,
confirmed twice consecutively.

**What this log means, stated plainly rather than left implicit**: the
Ghost hit test, as named and scoped ("100 mid-attack kills produce zero
post-death damage events"), verifies the *outcome* of the defense-in-depth
design working end to end. It does not, and by its own construction
cannot, distinguish which of the two independent protections (the
synchronous flag vs. the deferred engine flag) is doing the work in any
given scenario, because this implementation's synchronous flag alone is
already sufficient for every scenario the test builds. Only the
component-level unit tests in `hitbox_hurtbox_test.gd`/`death_state_test.gd`
directly assert the deferred engine flags' own correctness. This is not
proposed as a fix — the redundancy is intentional and required by docs/20
verbatim — but a reviewer should know the acceptance test's own blind spot
rather than assume it exercises everything docs/20 requires.

## Contradictions and ambiguities, named rather than resolved silently

1. **No Register value exists for a placeholder enemy's HP, hitbox damage,
   or Visual Death duration.** `death_state.gd`'s `max_hp` (30.0),
   `visual_death_duration` (0.6s), and `hitbox.gd`'s `damage` (10.0) are
   framework/test-fixture constants, not gameplay content — no Enemy
   Definition Contract instance exists yet to source a real figure from,
   and this component's own docs/20 contract defines *behaviour*
   (Logical/Visual Death), not tuning. Per CLAUDE.md's own rule ("A number
   that could be tuned without changing the shape of the game is a
   gameplay number and cites the Register"), these WOULD need a Register
   citation if shipped as real enemy content — they are not; every
   prototype enemy that replaces this placeholder must source its own
   values once a Register entry exists. Flagged rather than silently
   treated as exempt.
2. **The `enqueue_hit()`/SimLoop steps 5–8 hit-queue pipeline is not wired
   up by this task.** `sim_loop.gd`'s own comments name steps 6–8
   ("P1.5 hitbox/hurtbox framework", "P1.5 death_state.gd") as this task's
   responsibility, but `sim_loop.gd` is outside this task's write scope,
   and `SimLoop.enqueue_hit()`'s own signature requires attacker/target
   *serials* that no system yet assigns (docs/20: "player serial 0, Tower
   serial 1" — no Player/Tower/Enemy instance exists to originate a serial
   from, and entity serials are not named as any P1.x deliverable).
   `hitbox.gd`/`hurtbox.gd`/`death_state.gd` therefore resolve damage
   directly (hitbox → hurtbox.receive_hit() → death_state.apply_damage()),
   not through the SimLoop hit queue. This is a P1.5 interpretation,
   consistent with the task's own "Out: enemy behaviour" scope line and
   with docs 05 (Combat System) being a stub with no damage-resolution
   contract, but it means full step-ordered, serial-sorted hit resolution
   remains future work for whichever P2.x task builds entity serials and
   the real combat system.
3. **The hitbox/hurtbox correctness of the "same-tick race" ordering is an
   observed engine behaviour, not a documented guarantee.** Godot
   consistently dispatched the killer's `area_entered` before the
   attacker's own attack's `area_entered` across all 10 race trials in
   this run, on this build (Godot 4.7.1) and this specific fixture (tree
   order: attacker → victim → killer, all newly overlapping on the same
   step). This project's own carried lesson ("measure, don't reason")
   applies here: the ordering is reported as observed, not claimed as a
   documented API guarantee Godot promises to keep.
4. **An external commit landed mid-session, outside this task's own git
   actions.** At some point during this task's work, `git log` shows a new
   commit (`65c6d3e`, "Prototype redirection: decisions D97-D100, and the
   sprite generator", authored outside this delegation) that included a
   snapshot of `src/combat/collision_layers.gd`, `hitbox.gd`, `hurtbox.gd`,
   `death_state.gd`, `placeholder_enemy.gd`, `scenes/entities/placeholder_enemy.tscn`,
   and `tests/unit/hitbox_hurtbox_test.gd` at whatever state they were in
   at that moment — this task never ran `git add` or `git commit` itself
   (per CLAUDE.md: only commit when explicitly asked, which did not
   happen). `tests/unit/death_state_test.gd`, `ghost_hit_test.gd`, and
   every later edit made during falsification are NOT part of that commit
   and remain as working-tree changes. Flagged as an observation for the
   orchestrator, not treated as this task's own action, and not remedied
   by this task (no git commands were run to add, commit, or otherwise
   alter history).
5. **`assets/sprites/*.import` cache files appear as untracked** after this
   task's own mandated `--import` runs, alongside the sprite `.png` files
   the commit in item 4 added. These are Godot's own regenerated import
   cache for assets outside this task's write scope; nothing under
   `assets/` was written by this task, only read/regenerated as an
   unavoidable side effect of the mandated headless import step before
   every test run.

## Summary

- Layer/mask assignment: every constant traces to the Register's binding
  Collision layers row via `collision_layers.gd`, diffed table above.
- Logical vs. Visual Death: implemented as docs/20 specifies, in the exact
  order stated, with the four Pool-restored engine flags plus two
  synchronous guards docs/20 also requires.
- `set_entity_alive()`: ruled the correct seam and used.
- Ghost hit test: 100/100 fresh and 100/100 pooled trials produced zero
  post-death damage events; a same-tick race variant (10 trials, real
  physics-driven kill) also produced zero, with the observed dispatch
  ordering reported rather than assumed.
- 172 total unit tests, 0 errors, 0 failures, confirmed on repeated runs.
- Three falsifications run; all three left the named acceptance test green
  while direct unit tests caught every one — reported plainly per the task
  brief's own instruction, not treated as a defect to silently fix.

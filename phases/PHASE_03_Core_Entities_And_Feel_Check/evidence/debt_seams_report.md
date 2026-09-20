# Debt/Seams Report — F03-17, F03-06, F03-26, F03-12

Implementer scope this session: `src/core/event_bus.gd`, `src/core/sim_clock.gd`
(header comment only), `src/combat/death_state.gd`, `src/tower/tower_projectile.gd`,
`src/tower/tower.gd`, new test files under `tests/unit/`. No other file was
touched. This report observes and records; it does not assert that any task,
test, or the phase is passed, satisfied, or ready — that is for reviewers and
the author.

## Files changed

- `src/tower/tower_projectile.gd` — F03-17: added the `intersect_ray` sweep.
- `src/core/event_bus.gd` — F03-06: added the `player_died` signal and
  `emit_player_died()`, plus a superseded-wording sweep of the header
  paragraph that said "those three are implemented below."
- `src/combat/death_state.gd` — F03-06: `_enter_logical_death()` now picks
  `emit_player_died()` vs `emit_enemy_died()` via a new `_is_player_entity()`
  helper.
- `src/tower/tower.gd` — F03-26: registers itself with `EntityRegistry` under
  a new tag in `_ready()`, deregisters in a new `_exit_tree()`.
- `src/core/sim_clock.gd` — F03-12: corrected the `now` doc comment; no
  behaviour changed.
- `tests/unit/tower_projectile_sweep_test.gd` (new)
- `tests/unit/death_state_player_died_test.gd` (new)
- `tests/unit/tower_entity_registry_query_test.gd` (new)
- `phases/PHASE_03_Core_Entities_And_Feel_Check/evidence/debt_seams_report.md` (this file)

`src/core/entity_registry.gd` was **not** edited (F03-26's constraint):
`register_entity()`, `deregister_entity()`, `is_registered()`,
`get_entities_in_radius()`, `get_entities_with_tag()`, `get_entity_count()`
and `get_tags()` — all pre-existing public API — were sufficient. No API gap
to report there.

## Exact signatures/names other implementers must match

- `signal player_died(entity: Node2D, position: Vector2, timestamp: float)`
  on the `EventBus` autoload, paired with
  `func emit_player_died(entity: Node2D, position: Vector2) -> void`. Same
  shape as the existing `enemy_died`/`emit_enemy_died()` pair.
- The Tower registers with `EntityRegistry` under the tag **`&"tower"`**
  (a new tag; nothing in the codebase queried it before this fix, confirmed
  by a full-repo search before choosing it). `Tower.set_registry_for_test(registry: Node)`
  exists for test injection, mirroring `player.gd`'s own convention
  (guarded assignment in `_ready()`, so a test calling it BEFORE `add_child()`
  has the injection stick).

## How F03-06 tells player from enemy (read before connecting to `player_died`)

`death_state.gd` is shared, unmodified, by the player, every enemy, and (via
`tower_health.gd`'s own forwarding call into `_death_state.apply_damage()`)
the Tower. It cannot hardcode which signal to emit. The fix queries
`EntityRegistry.get_tags(_registry_entity)` — a read-only query, not a new
field — for the `&"player"` tag `src/player/player.gd` already registers
itself under. Only a positive match switches to `emit_player_died()`; every
other case (a real enemy, an entity never registered at all, or the Tower,
which is now tagged `&"tower"` — not `&"player"`) keeps
`emit_enemy_died()` exactly as before. **This means the Tower's own death
still emits `enemy_died`, unchanged** — F03-06 named the player specifically,
not a general entity-kind switch, and this fix does not widen or narrow that
pre-existing mislabelling. Flagged below as a seam for whoever next revisits
EventBus's death signals.

## Falsification table

Every mutation was applied to the real source file, the suite was re-run,
the exit code recorded, then the file was restored from a byte-for-byte
backup copy and `git diff -- <file>` was captured again and diffed against
the pre-mutation `git diff` capture (both tracked files) to confirm the
restored file produces an identical diff-from-HEAD, i.e. is byte-identical
to the fixed state.

| # | Mutation | Target file | Re-run scope | Exit code | What went red | Restored byte-identical (git diff before == after) |
|---|---|---|---|---|---|---|
| 1 | `_physics_process()` reverted to bare `global_position += _velocity * delta`, sweep call removed | `src/tower/tower_projectile.gd` | `res://tests/unit` (full, 397 cases that run) | **100** | Exactly 1 failure: `tower_projectile_sweep_test.gd::test_sweep_detects_a_hurtbox_the_projectile_would_otherwise_jump_over` ("tunnelled through a hurtbox... instead of the intersect_ray sweep catching it"). No other suite affected. | **Yes** |
| 2 | `_enter_logical_death()`'s `if _is_player_entity(): ... else: ...` collapsed back to the original unconditional `_event_bus.emit_enemy_died(...)` | `src/combat/death_state.gd` | `res://tests/unit` (full, 397 cases that run) | **100** | 3 assertion failures, all inside `death_state_player_died_test.gd::test_player_tagged_entity_emits_player_died_and_not_enemy_died` (player_died not emitted; enemy_died emitted instead; entity reference null). See "gdUnit4 per-suite abort" below for why the suite's other 3 tests did not also report in this same run — `test_player_died_carries_the_same_shape_as_enemy_died` was separately confirmed red under the identical mutation (exit 100, "Expecting: 1 but was 0") by temporarily reordering it first in the file, then the reorder itself was restored and diffed byte-identical against a saved copy. | **Yes** (both `death_state.gd`, via `git diff`, and the temporarily-reordered test file, via `diff` against a saved copy) |
| 3 | The `if _registry == null: ... if _registry != null: _registry.register_entity(...)` block deleted from `_ready()` | `src/tower/tower.gd` | `res://tests/unit` (full, 380 cases that run) | **100** | 2 assertion failures, both inside `tower_entity_registry_query_test.gd::test_tower_registers_itself_under_the_tower_tag_on_ready` ("Tower did not register itself with EntityRegistry in _ready()"; count 0 instead of 1). Same per-suite abort as #2 stopped the file's other tests from running in this pass; logically identical code path, not independently re-verified by reorder (time-boxed — see below). | **Yes** |

No mutation was applied to `src/core/sim_clock.gd` (F03-12 is a comment-only
correction; there is no behaviour to falsify) or to `src/core/event_bus.gd`
in isolation (the `player_died` signal/`emit_player_died()` wiring is
exercised end-to-end by mutation #2's own test suite: every
`death_state_player_died_test.gd` test connects directly to
`_bus.player_died`, and all four passed in the clean baseline run before any
mutation — a broken or missing signal/emit wrapper would have failed every
one of them, not just the mutated case).

### An observed gdUnit4 CLI behaviour (recorded, not diagnosed)

Reproduced three times: once a test function inside a given suite **file**
fails, this project's `GdUnitCmdTool.gd` invocation does not run that same
file's remaining test functions for that invocation — it moves on to the
next suite file. First noticed when a single-file run of
`tower_projectile_sweep_test.gd` (4 test functions) against mutation #1
reported "Executed test cases: (1/1)"; confirmed again for mutation #2's
suite; worked around for mutation #2's second test by temporarily renaming
the first test so it does not run and the second becomes first. This does
not affect the validity of the results above — the intended test in each
case still turned red with the exact expected assertion message — but it
means a full-suite exit code of 100 undercounts how many tests in a
*failing* file actually executed on that pass. Outside this task's write
scope to fix (`tests/run_tests.ps1`, `addons/gdUnit4/**` are not in the edit
list); named here in the style of F03-04/F03-14.

## Test counts and exit codes actually observed

- **Immediately after implementing all four fixes**, before any mutation:
  `res://tests/unit` → **388 test cases | 0 errors | 0 failures | 0 flaky |
  0 skipped | 0 orphans | exit 0**. Engine-error guard: 0 lines matching
  `^(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR):` in the captured
  output — clean.
- **After all three mutations were restored and verified byte-identical**,
  a final full run: `res://tests/unit` → **409 test cases | 0 errors | 12
  failures | 0 flaky | 0 skipped | 0 orphans | exit 100**. Engine-error
  guard: still 0 matching lines — clean.
- The jump from 388→409 test cases and the 12 failures in that last run are
  **not attributable to this task**. This is a heavily concurrent session —
  `git status`/`git diff --stat` at the time of the final run show 29
  tracked files modified and a dozen-plus new untracked files across
  `src/player/`, `src/enemy/`, `src/director/`, `src/core/sim_loop.gd`,
  `src/combat/hitbox.gd`, `src/combat/auto_weapon.gd`, `src/tower/tower_health.gd`,
  `src/tower/tower_weapon.gd`, plus wholly new `src/economy/`, `src/pickup/`,
  `src/upgrade/`, `src/director/pressure_metric.gd` — none of which are in
  this task's edit list or were touched by it. The 12 failures in the final
  run are confined to `leash_test.gd`, `player_input_buffer_test.gd`,
  `player_movement_test.gd`, and `pressure_test.gd` (a brand-new file, not
  mine) — none of which exercise `event_bus.gd`, `death_state.gd`,
  `tower.gd`, `tower_projectile.gd`, or `sim_clock.gd`. Every suite that
  *does* exercise those five files — `death_state_test.gd` (13/13),
  `tower_same_frame_death_test.gd` (7/7), `tower_weapon_test.gd` (5/5),
  `tower_health_recovery_test.gd` (5/5), `tower_cue_audibility_test.gd`
  (11/11), `weapon_check_test.gd` (8/8), `player_projectile_test.gd` (5/5),
  `entity_registry_test.gd` (15/15), `event_bus_test.gd` (5/5), and this
  task's own three new suites (4/4, 4/4, 5/5) — passed with 0 failures in
  that same final run. This is stated as an observation, not a claim that
  the phase or any other task is in a good state; it is outside this task's
  scope to investigate or fix files it does not own.

## Skill conflicts (CLAUDE.md: record where a skill disagrees with the project)

1. **`godot-prompter:godot-testing`** prescribes a `test_*.gd` filename
   prefix. This project's convention (already on record as F03-06's ledger
   neighbour F03-08) is a `*_test.gd` suffix. All three new files follow the
   project convention; project wins per CLAUDE.md.
2. **`godot-prompter:event-bus`**, section 8 ("Testing"): "Always test
   against the real autoload EventBus retrieved via
   `get_tree().root.get_node("EventBus")`... not a fresh instance." This
   project's established convention — `death_state_test.gd`,
   `event_bus_test.gd`, `entity_registry_test.gd`, and now all three of this
   task's new suites — builds a fresh, throwaway `EventBus`/`EntityRegistry`
   instance per test, never touching the real Autoload singleton in a unit
   test. Project wins per CLAUDE.md; not previously on `LEDGER.md` under
   this exact wording as far as this search found, though it is the same
   class of conflict as F03-02/F03-11/F03-19 (the skills are right about
   generic Godot idiom, wrong about this project's own isolation rule).
3. **`godot-prompter:physics-system`**, section 7 ("Code-Based
   Raycasting"): no conflict — its guidance (`PhysicsDirectSpaceState2D`
   via `get_world_2d().direct_space_state`, `PhysicsRayQueryParameters2D.create()`,
   `query.exclude = [get_rid()]`, mask filtering, "only safe inside
   `_physics_process()`") matches docs/20's own sweep rule and
   `player_projectile.gd`'s existing implementation exactly. Named here for
   completeness, not as a departure.

`LEDGER.md` itself was not edited — it is outside this task's write scope,
matching the precedent already set by F03-08/F03-11/F03-19 (recorded in the
implementer's own evidence file; the orchestrator copies it into the
ledger).

## Seams needed outside this task's scope

- **The Tower's own death still emits `enemy_died`, not a Tower-specific
  signal.** `tower_health.gd` forwards Tower damage into the shared
  `death_state.gd`, whose entity is tagged `&"tower"` (this task's own
  fix), not `&"player"` — so it falls through to `emit_enemy_died()`
  exactly as it did before this task. F03-06 named the player specifically;
  this task did not widen scope to invent an unrequested `tower_died`
  signal or a general entity-kind enum. Named in `death_state.gd`'s own
  header for whoever next revisits EventBus's death signals — a
  `RunTerminationRecorder`/wave-completion/kill-count listener that assumes
  every `enemy_died` is a real enemy would still be wrong about the Tower.
- The gdUnit4 per-suite-abort-on-first-failure behaviour above, if it
  proves not to be a one-off, is worth its own investigation and possibly
  its own `run_tests.ps1` flag or gdUnit4 config change — outside this
  task's write scope.

## What was not done, and why

- No test exercises `sim_clock.gd`'s comment fix (F03-12) — there is no
  behaviour to test; the task itself specifies "Comment only; change no
  behaviour in that file."
- `test_player_died_carries_the_same_shape_as_enemy_died` and
  `tower_entity_registry_query_test.gd`'s tests 2-5 were confirmed correct
  under their respective fixes by the clean baseline run (388/388,
  0 failures) and, for the death_state case, independently re-verified red
  under mutation by reordering; the Tower registry suite's tests 2-5 were
  **not** independently re-verified red under mutation #3 (time-boxed
  against the gdUnit4 per-suite-abort behaviour) — they share the exact
  same `_registry.is_registered()`/tag-query code path as test 1, which
  *was* independently confirmed red, so a red result is expected but this
  specific claim rests on that inference rather than a directly observed
  re-run.
- No gameplay numbers were introduced. `SWEEP_THRESHOLD_PX = 12.0` in
  `tower_projectile.gd` is the same framework/architecture constant
  `player_projectile.gd` already carries under an identical name and an
  identical "not a Register number" justification (docs/20's own verbatim
  "12 pixels" threshold) — no `NO REGISTER ROW - escalated` marker applies
  because this was never treated as a gameplay number by the precedent this
  file mirrors.

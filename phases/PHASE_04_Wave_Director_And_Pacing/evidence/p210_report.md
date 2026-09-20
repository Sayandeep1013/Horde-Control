# P2.10 — Pickups, drop table, cap — evidence report

Status note (MASTER_SDLC.md > Document Control > Gate Approval): nothing below asserts that this task, its tests, or Phase 04 is passed, satisfied, complete, or ready. This report states what was built and what was observed; the critical agent and phase reviewer named in PLAN.md's "Agent assignment" decide the rest.

## Scope actually built

Pickup entities (XP shard, Scrap) acquired exclusively through the existing `EntitySpawner.spawn_pickup()` pool; magnet attraction, acceleration, and the per-tick raycast block (EnemyBody/TowerBody/World); lifetime with a blink window; the pickup cap (150) with rule C-MERGE; the Drop Table applied on `EventBus.enemy_died` and on `EnemyController.removed_while_stuck`; "Unreachable drops" placement at the nearest open point; a run inventory (`RunInventory`) for Scrap (cap, overflow discard, FULL) and XP/level (curve from Economy Configuration); Scrap zeroed on `EventBus.player_died`; the HUD field-shape exposure the brief asked for.

**Cores are out of scope and were not built** (per the task brief: "Cores are out of prototype scope for the prototype"). No `PickupType.Core` pickup is ever spawned, `EconomyConfiguration`'s Core-related fields (`hopper_conversion_rule`, `run_end_settlement_rates`) are authored on `data/economy/prototype.tres` only because the Economy Configuration Contract requires every field on the schema to exist, not because the prototype uses them.

## Files created

- `src/pickup/pickup.gd` — `Pickup` (`extends Area2D`), the per-instance pooled entity: magnet attraction via an `EntityRegistry` radius query, acceleration, the raycast block, lifetime + blink, `physics_step(delta)` / `driven_externally` matching every other entity.
- `src/pickup/pickup_system.gd` — `PickupSystem` (`extends Node2D`), the owner of spawning, the cap/C-MERGE cascade, Drop Table application, collection, and `run_inventory`.
- `src/pickup/pickup_system_step_adapter.gd` — `PickupSystemStepAdapter`, a tiny SimLoop registration adapter (see "SimLoop registration API" below).
- `src/economy/run_inventory.gd` — `RunInventory` (`extends RefCounted`), the run-scoped Scrap/XP/level state.
- `data/pickups/xp_shard.tres`, `data/pickups/scrap.tres` — real `PickupDefinition` resources.
- `data/economy/prototype.tres` — real `EconomyConfiguration` resource.
- `scenes/pickups/pickup.tscn` — the one shared pickup scene (Area2D + CollisionShape2D + Sprite2D), used for both currencies via `Pool`'s `factory_override` mechanism.
- `tests/unit/pickup_physics_test.gd`, `tests/unit/pickup_merge_cap_test.gd`, `tests/unit/drop_table_test.gd`, `tests/unit/run_inventory_test.gd`.
- This report.

No file outside the allowed paths was edited. `git status` at the end of this task shows my changes confined to `src/pickup/**`, `src/economy/**`, `data/pickups/**`, `data/economy/**`, `scenes/pickups/**`, and `tests/unit/*_test.gd` (plus Godot's own auto-generated `.uid` companions) — `src/player/collector.gd` was **not** touched; the existing `pickup_entered` signal seam was sufficient.

## Register citations (every number, by section/row)

| Value used | Register citation | Where |
| --- | --- | --- |
| Magnet radius 96 px | Economy & Pickups > "Magnet radius / pickup motion" | `PlayerDefinition.magnet_radius_px` (`data/player/prototype.tres`, P2.1's own authored field — read live via `player.definition.magnet_radius_px`, not duplicated); `PickupSystem.magnet_radius_px_default` fallback |
| Initial speed 40 px/s, acceleration 900 px/s², max 700 px/s | Economy & Pickups > "Magnet radius / pickup motion" | `Pickup.INITIAL_SPEED_PX_PER_SECOND` / `ACCELERATION_PX_PER_SECOND_SQUARED` / `MAX_SPEED_PX_PER_SECOND` (script constants — see "Schema gap" below for why these are not in a `.tres`) |
| Raycast mask EnemyBody/TowerBody/World (layers 2,3,4) | Economy & Pickups > "Pickup raycast"; docs/20 Collision Layers | `Pickup._is_ray_blocked()` via `CollisionLayers.LAYER_ENEMY_BODY/LAYER_TOWER_BODY/LAYER_WORLD` |
| Pickup cap 150 | Technical Caps & Performance > "Entity caps" | `PickupSystem.PICKUP_CAP` (independently transcribed, matching `entity_cap_test.gd`'s own stated convention — see "src/core/entity_caps.gd's own header: 'src/core/entity_spawner.gd is the only reader'") |
| Merge radius 64 px (default) | Economy & Pickups > "Merge radius (Economy Configuration field)" | `data/economy/prototype.tres` `merge_radius_px = 64`; `MergeRule.get_match_radius_px()` |
| C-MERGE cascade (oldest of incoming type → nearest same-type neighbour → sums value; else expires; else oldest XP; else oldest Scrap) | Economy & Pickups > "Pickup merge (C-MERGE)"; "Pickup Physics & Magnet Rules" > "Merging" | `PickupSystem._free_cap_slot_for()` |
| Pickup lifetime 60 s, blink 5 s | Economy & Pickups > "Pickup lifetime" | `data/pickups/*.tres` `lifetime_seconds = 60.0`; `Pickup.BLINK_WINDOW_SECONDS` |
| Drop Table: standard 1 XP + 1 Scrap; Overtime finisher 1 XP no Scrap; stuck-despawned still drops, placed | Economy & Pickups > "Drop Table" | `data/enemies/*.tres` (`drop_table`, pre-existing, not authored by this task); `PickupSystem._resolve_drop_table_for()` (finisher override); `handle_enemy_removed_while_stuck()` |
| Unreachable drops → nearest open point | "Pickup Physics & Magnet Rules" > "Unreachable drops" | `PickupSystem._resolve_open_point()` |
| Scrap cap 200, no hopper in the prototype (overflow discarded, FULL) | Economy & Pickups > "Scrap" | `data/economy/prototype.tres` `scrap_cap = 200`, `overflow_hopper_capacity = 0`; `RunInventory.credit_scrap()` |
| XP level curve 10 + 5(L+1) → 15/20/25; run starts at level 0; remainder carries | "Experience (XP)" | `data/economy/prototype.tres` `xp_level_cost` (`base_cost=10`, `per_level_increment=5`, per decision D89's authored-data resolution); `RunInventory.credit_xp()` |
| XP cap during teaching waves = 14 | "Experience (XP)": "XP above 14 is discarded" | `data/economy/prototype.tres` `xp_cap_during_teaching_waves = 14` (authored, **not enforced** by this task — see "Out of scope" below) |
| Console price 30/rank | Progression & Upgrades > "Console price" | `data/economy/prototype.tres` `console_price_formula.scrap_per_rank = 30` |
| Run-End Settlement 5/3/1 | Economy & Pickups > "Run-End Settlement" | `data/economy/prototype.tres` `run_end_settlement_rates` |
| Hopper 10:1 at Interaction Radius | Economy & Pickups > "Cores" | `data/economy/prototype.tres` `hopper_conversion_rule` (authored, inert — Cores/hopper out of scope) |
| Dominance 65% / 10 runs | Economy & Pickups > "Economy dominance measure" | `data/economy/prototype.tres` `dominance_audit_parameters` |
| Core persistence write cadence 2 s | Economy & Pickups > "Cores" | `data/economy/prototype.tres` `core_persistence_write_cadence_seconds = 2.0` |
| Pickup z_index 10 | Interfaces > "Readability" | `Pickup.Z_INDEX_PICKUPS` |

## Escalations (`NO REGISTER ROW`)

1. **Pickup's own collision-detection radius (6 px)** — `Pickup.COLLISION_RADIUS_PX`. Neither the Register nor document 16 (which does not exist as a file) states a pickup's own Area2D shape size; only PlayerCollector's radius (22 px) is specified. Chosen well under the collector's own radius; a reviewer may prefer a different value or an authored field.
2. **Blink rate (0.2 s period)** — `Pickup.BLINK_PERIOD_SECONDS`. The Register states the 5 s blink *window*, not a flicker frequency.
3. **"Unreachable drops" search pattern** (radii 16/32/48/64/96/128/192 px, 8 directions) — `PickupSystem.OPEN_POINT_SEARCH_RADII_PX`/`OPEN_POINT_SEARCH_DIRECTIONS`. The master states the rule ("placed at the nearest open point") but not a search shape.
4. **Audio cue IDs** (`PLACEHOLDER_cue_pickup_xp_collect`, `PLACEHOLDER_cue_pickup_scrap_collect`) — no pickup-collect sound has been authored yet; follows the exact convention `data/enemies/*.tres` already uses for the same situation.

## Schema gap (distinct from an escalation — flagged for the author)

The magnet's initial speed / acceleration / max speed (40 / 900 / 700) are real Register numbers, but **no Content Data Contract field carries them** — `PickupDefinition` has no motion fields, `EconomyConfiguration` has no motion fields, and CLAUDE.md/P0.6's own convention bars inventing a contract field docs/20 does not define. These three numbers therefore stay as cited script constants on `pickup.gd`, the same pattern this codebase already uses for a derived-not-authored Register number (`tower_seeker.tres`'s own header: "the 176 px/s absolute figure is DERIVED ... never authored as a literal"). This is why falsification #2 below mutates a script constant rather than a `.tres` field — the task's own falsification checklist item ("changing the magnet acceleration in the .tres") assumes a field that the schema does not have. **Author decision needed**: should a future revision of document 16 (Economy - Pickups) or docs/20's Pickup Definition / Economy Configuration Contract add a magnet-motion sub-struct so this becomes authored data instead of a script constant?

## Dependency / escalation: `EventBus.player_died`

At the time this task's brief was written and at the start of implementation, `EventBus` declared only `enemy_died`, `tower_damaged`, `draft_opened` — confirmed by reading `src/core/event_bus.gd` in full and by `grep -n player_died src/core/event_bus.gd` returning nothing. Per the brief, `RunInventory._connect_player_died()` was written against the name `player_died` regardless, guarded with `has_signal()`/`is_connected()`, with `try_connect_player_died()` as a re-attempt seam. **Mid-implementation, the concurrently-running implementer (per the task brief, "another implementer is adding an EventBus.player_died signal RIGHT NOW") landed it**: `signal player_died(entity: Node2D, position: Vector2, timestamp: float)`, same shape as `enemy_died`, emitted by `src/combat/death_state.gd`. This was verified by re-reading `event_bus.gd` after the fact. No code change was needed on my side — the guarded connection engaged correctly against the real signal once it existed, and `tests/unit/run_inventory_test.gd`'s `test_connection_is_guarded_when_the_bus_has_no_player_died_signal` still proves the miss-then-reconnect path works with a bus that lacks the signal.

## Discovery mid-task: a generic SimLoop registration API

`src/core/sim_loop.gd` (outside this task's write scope) gained a generic `register(step: int, node: Node) -> bool` API concurrently with this task (F03-09), where `node.physics_step(delta)` is called at the right point in the fixed 15-step order; `src/director/wave_director.gd` already uses it for step 13. Steps 9/10/11's own `_step_09_drops()`/`_step_10_pickup_movement_and_collection()`/`_step_11_xp_and_level_up_requests()` do **not** yet call `_run_step()` for their steps the way step 13 does — they still just log a step marker.

Because `register()` calls one fixed method name per node and PickupSystem does three distinct things at three different steps, `PickupSystem` builds three small `PickupSystemStepAdapter` instances (one per step) and registers each one, found via the documented `get_tree().get_first_node_in_group(&"sim_loop")` lookup, deferred past `_ready()`. This makes wiring automatic: placing a `PickupSystem` node anywhere under the same tree as the real `SimLoop` is enough — no manual per-step call is required from the orchestrator, **once** `sim_loop.gd`'s own `_step_09/_10/_11` methods are updated to call `_run_step()` for their steps (a change outside this task's write scope; named as a required seam below). `step_drops()` / `step_pickup_movement_and_collection(delta)` / `step_xp_and_level_up_requests(delta) -> bool` remain public and directly callable for any integration that prefers not to use the registration API.

## Public surface for the orchestrator ("Wiring surface")

- `PickupSystem` (place under the gameplay root, e.g. as a sibling of `EntitySpawner`):
  - `@export entity_spawner_path: NodePath` → the scene's `EntitySpawner`.
  - `@export player_path: NodePath` → the `Player` node (read-only access to `player.definition.magnet_radius_px`).
  - `@export player_collector_path: NodePath` → the `Player`'s `Collector` (`PlayerCollector`) node.
  - `run_inventory: RunInventory` — call `run_inventory.apply_to_hud_state(hud.economy_state)` once per frame (or on change) to drive the HUD; `Hud.economy_state` is strictly typed `HudEconomyState`, so this copy cannot be replaced by assignment.
  - Self-registers with `SimLoop` (see above) once `sim_loop.gd`'s steps 9/10/11 call `_run_step()`.
- `EnemyController.removed_while_stuck(position, drop_table)` — **REQUIRED SEAM**: whoever spawns `EnemyController` instances (currently `src/director/wave_director.gd`, outside this task's write scope; confirmed by `grep` that it does not yet call `spawn_enemy` with a `removed_while_stuck` connection) must connect each spawned instance's signal to `pickup_system.handle_enemy_removed_while_stuck`. Verified end-to-end against the signal's real declared shape in `tests/unit/drop_table_test.gd`'s `test_stuck_despawned_enemy_still_drops_via_the_real_removed_while_stuck_signal`, but nothing currently wires it live.
- `sim_loop.gd`'s `_step_09_drops()` / `_step_10_pickup_movement_and_collection()` / `_step_11_xp_and_level_up_requests()` need to call `_run_step(Step.DROPS/PICKUP_MOVEMENT_AND_COLLECTION/XP_AND_LEVEL_UP_REQUESTS, delta)` — currently they do not (outside this task's write scope).

## Interpretation: Overtime finisher's drop override

`EventBus.enemy_died` carries `(entity, position, timestamp)` — no drop table. `EnemyController.is_finisher` (public `@export`, already built by P1.5/P2.5) is the only per-instance signal reachable from the listener. `docs/09`'s own `OvertimeCondition.finisher_drop_override: DropTable` (`src/data/overtime_condition.gd`) is the documented, data-authored source for a finisher's real override, but it lives on Wave Director configuration this task has no reach into from an `EventBus` signal. `PickupSystem._resolve_drop_table_for()` therefore reads the entity's own `definition.drop_table` for XP and **hard-zeroes Scrap whenever `is_finisher == true`**, matching the Register's literal "drop 1 XP and no Scrap" directly rather than resolving `finisher_drop_override`. If a wave ever authors a finisher override with a different XP amount, this will not reflect it. Verified as currently moot: `src/director/wave_director.gd`'s own comments confirm Overtime is deferred ("Overtime is not implemented ... P2.8 deferred it"), so no finisher is spawned in the live game yet; this path is exercised only by `drop_table_test.gd`'s own direct unit test.

## Interpretation: drop-table reads off the entity

The brief says "listen for the existing `EventBus.enemy_died` signal rather than reaching into enemies." Since that signal carries no drop table, `_resolve_drop_table_for()` reads the entity's own public `definition.drop_table` field — a plain data read, not a behavioural call, and the exact same pattern `EnemyController.removed_while_stuck` already uses (`definition.drop_table if definition != null else null`). Named explicitly since a stricter reading of the brief might object to any read off the entity at all.

## Falsification table

Every mutation was applied to the real source, re-run against the real gdUnit4 harness (`tests/run_tests.ps1`), the exit code recorded, then the file restored from a pre-mutation copy in the session scratchpad and verified byte-identical with `diff -q`.

| # | Mutation | File | Test run | Exit code | Result | Restored byte-identical |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Deleted the raycast-blocked early return (`if _blocked: return`) so a blocked pickup keeps moving | `src/pickup/pickup.gd` | `pickup_physics_test.gd` | 100 | RED — `test_enemy_body_blocks_the_magnet_ray_and_the_pickup_holds_position` failed: "a blocked pickup moved instead of holding its position" | Yes (`diff -q`) |
| 2 | Changed `ACCELERATION_PX_PER_SECOND_SQUARED` from 900.0 to 1.0 | `src/pickup/pickup.gd` | `pickup_physics_test.gd` | 100 | RED — `test_pickup_accelerates_toward_the_player_once_in_range` failed: expected ~55.0, got 40.017 | Yes (`diff -q`) |
| 3 | Made `_free_cap_slot_for()` an immediate no-op (cap cascade disabled) | `src/pickup/pickup_system.gd` | `pickup_merge_cap_test.gd` | 100 | RED — `test_cap_never_exceeds_150_across_many_widely_spaced_drops` failed 30 times in one run: "PickupSystem's own bookkeeping (N) drifted from the pool's real count (150)" | Yes (`diff -q`) |
| 4 | Made `_on_player_died()` a no-op (Scrap no longer zeroed) | `src/economy/run_inventory.gd` | `run_inventory_test.gd` | 100 | RED — `test_player_death_zeroes_carried_scrap` failed: expected 0, got 120 | Yes (`diff -q`) |

Every one of the four mandated mutations turned its target test(s) red with the expected failure message, and every mutated file was confirmed byte-identical to its pre-mutation copy after restoration. No mutation left the tests green (no dead/weak-test finding to report here).

Note on mutation #2: the task's falsification checklist says "changing the magnet acceleration in the `.tres`"; there is no `.tres` field for this number (see "Schema gap" above), so the mutation was applied to the script constant that actually carries the Register-cited value instead.

## A genuine test-design lesson found and fixed along the way

The first draft of `pickup_merge_cap_test.gd` asserted merge/expire correctness by checking that a specific `Pickup` **Node reference** had disappeared from `PickupSystem`'s tracking (`_active_pickups.has(oldest) == false`). This is unsound: `EntitySpawner.despawn_pickup()` returns the evicted instance straight to `Pool`'s free list, and the very next `spawn_pickup()` call inside the same cap-cascade (the incoming drop) can — and, observed directly, does — hand back that exact freed instance, reconfigured, as the new pickup. The reference never actually leaves `_active_pickups`; it just starts meaning something else. This produced one real, reproduced test failure during development (caught before this report was written, not left in the delivered suite) and, on a second run, a similarly-shaped failure in a different test in the same file that used the identical unsound pattern. Both were rewritten to assert on **data** (position/value) instead of reference identity, matching the pattern already used successfully in `test_at_cap_the_oldest_of_the_incoming_type_expires_when_no_merge_partner_exists` (a count-only check, which was never affected). This is recorded here per this project's own convention of naming a discovered test-design pitfall rather than silently papering over it.

## Test counts and exit code (engine-error guard)

Final full run, `powershell -File tests\run_tests.ps1 -TestPath res://tests/unit`:

```
Overall Summary: 479 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans
PASS (exit 0): 479 test case(s) executed under res://tests/unit, all passed.
```

Exit code 0. No "ENGINE ERRORS" line and no "NOT A USABLE RUN" line were printed, i.e. the script's own engine-error-channel guard (distinct from gdUnit4's own summary) is clean. This project is under heavy **concurrent** development this session (five parallel implementers per the task brief); two earlier full-suite runs taken during this task's own work showed sporadic failures in three files this task never touches (`hit_queue_resolution_test.gd`, `pressure_test.gd`, `sim_loop_order_test.gd`) — all three sit under files with a live, large concurrent diff this session (`src/core/sim_loop.gd`: 392 lines changed; `src/director/wave_director.gd`: 419 lines changed; confirmed via `git diff --stat`). This task's own four suites were green in every single run this session, including inside those two noisy full-suite runs. Individually, right now:

```
pickup_physics_test.gd:    11 test cases | 0 errors | 0 failures | exit 0
pickup_merge_cap_test.gd:   5 test cases | 0 errors | 0 failures | exit 0
drop_table_test.gd:         6 test cases | 0 errors | 0 failures | exit 0
run_inventory_test.gd:     10 test cases | 0 errors | 0 failures | exit 0
```

32 test cases across this task's four suites, all green, both standalone and inside the 479-case full run above.

## Skill conflicts (CLAUDE.md GodotPrompter section)

- `godot-prompter:resource-pattern` — followed for every `.tres` (Resource subclass schemas, `@export` fields, real values cited by Register row). No conflict.
- `godot-prompter:physics-system` — followed for the Area2D layer/mask setup and `PhysicsDirectSpaceState2D.intersect_ray`/`intersect_point` usage, matching this project's own established `player_projectile.gd` precedent rather than the skill's generic guidance where the two diverged (e.g. the skill's generic examples lean on native two-body overlap; this project's raycast-based magnet block is an explicit Provisional Default the master itself states, "chosen for the performance budget" — Register > "Pickup Physics & Magnet Rules" > "Blocking"). No real conflict, just a project-specific default already decided upstream of this task.
- `godot-prompter:2d-essentials` — no conflict; nothing here uses TileMaps/parallax/lights.
- `godot-prompter:godot-testing` — this project's test-file naming convention (`tests/unit/<name>_test.gd`, suffix) overrides the skill's own `test_<name>.gd` prefix convention, per CLAUDE.md; followed the project convention. No other conflict — gdUnit4 patterns (`GdUnitTestSuite`, `auto_free`, `before_test`/`after_test`, fluent asserts) match the skill's own guidance.

## Out of scope / not done, and why

- **Cores** — not built at all (task brief: explicitly out of scope for the prototype).
- **XP cap during teaching waves (14) enforcement** — the value is authored on `data/economy/prototype.tres`, but `RunInventory.credit_xp()` does not enforce it. The Register's XP cap check is explicitly P2.12's own acceptance test ("XP cap check", P2.12), and P2.10's own task row lists "run inventory cap with FULL indicator" for Scrap only, not a teaching-wave XP ceiling. Left for P2.12 to apply against this same `RunInventory`.
- **Opening the actual Level-Up Draft** — `RunInventory.consume_level_up_requested()` is the seam; P2.12 owns the Draft UI itself.
- **Performance Fallback Ladder step 1** (magnet raycast every 2nd tick; merge radius 128 px) — not implemented; this is an explicit runtime escalation tier docs/20 describes for later, not part of P2.10's base behaviour.
- **Wiring `removed_while_stuck` live** and **calling `_run_step()` for steps 9/10/11 in `sim_loop.gd`** — both require edits to files outside this task's write scope; named as required seams above for the orchestrator.

## Godot version note

Confirmed via the harness's own boot check on every run: "Boot check: Godot 4.7.1 matches the pin in document 20." No 4.4 misread encountered.

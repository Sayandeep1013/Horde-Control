# Phase 04 - Wave Director and Pacing

Status: Not started; Executes: MASTER_SDLC.md > Development Phase Map > Phase 2 - Core Tension Prototype (the Minimum Playable Prototype) (part); Plan task IDs: P2.8, P2.9, P2.10

## Goal

Four encounter types built from data, both Spawn Rings, the Pressure Metric, and pickups with the Drop Table. This is phases/README.md's phase-table row 04 outcome: "Four encounter types from data, both spawn rings, the Pressure Metric, pickups." The owning detail for every task in this phase lives in docs/11_Wave_Director.md: Wave Runtime Model, Encounter Budgets for the Prototype, Spawn Rings & Placement, Directional Weighting, and Pacing & Escalation Algorithm.

## Entry conditions

- Phase 03 exit criteria recorded: Player movement check, Player silhouette test, Camera bounds test, Weapon check, Tower weapon check, Same-frame death test, Health recovery check, Leash test, Opportunist test, Stuck exemption test, and Tower cue audibility check all recorded; a Feel check verdict (go, or a named adjustment with a repeated check) recorded (phases/README.md phase-table row 03 gate).
- The player (P2.1 deliverable, `scenes/player.tscn`), arena and camera (P2.2 deliverable, `scenes/arena.tscn`), Handgun (P2.3 deliverable, `data/weapons/handgun.tres`), and Tower (P2.4 deliverable, `scenes/tower.tscn`, `data/tower/base.tres`) exist for the Wave Director to spawn enemies into and around.
- Tower Seeker, Player Hunter, and Opportunist `.tres` definitions and their AI scripts (P2.5 deliverable, `data/enemies/*.tres`, `src/enemy/*.gd`) exist for every encounter's spawn groups to reference by Enemy ID.
- The HUD and threat feedback (P2.6 deliverable) exist to show wave progress and the off-screen Tower indicator this phase's Siege warning uses.
- The recorded P2.7 Feel check verdict exists: a "go" recorded, or the named adjustment made and the check repeated to a "go", before automated pacing (this phase) replaces the hand-placed P2.7 arena.
- Object pools and entity caps (P1.3 deliverable) and the EntityRegistry query interface (P1.2 deliverable) exist, since every wave/encounter completion check in this phase is an EntityRegistry tag query, never a counter (docs/11_Wave_Director.md > Wave Runtime Model).

## Carried lessons

Filled at phase entry on 2026-09-20 from `phases/LESSONS.md` and the execution records of phases 00 through 03, per loop rule (a). Phase 03's record is the load-bearing one here, because P2.8 - this phase's largest task - was built inside it.

1. **Run tests through `tests/run_tests.ps1`, never the raw gdUnit4 command.** gdUnit4's error count excludes Godot's own engine errors; five `push_error` calls measured `0 errors` at exit 0, and that blind spot hid a real dangling-reference bug for a whole phase. The script reads the engine channel too, and both results have to be clean. `pwsh` is not installed on this machine; the runner is Windows PowerShell 5.1, invoked directly.
2. **Every named acceptance test is falsified by real mutation of the source or the `.tres`, restored, and proved byte-identical.** Phase 03 did this eleven times and three of those mutations exposed the *test* rather than the code. P2.9's Pressure test is the exact shape that fails this way: a lockout or a threshold test can be satisfied by a constant. Phase 03's wave-determinism suite stayed green against a hardcoded seed root, and only the paired negative case caught it - so every positive assertion in this phase carries its negative twin.
3. **A mutation with no effect is a finding about the implementation.** Phase 03 deleted a stuck-rule clause with zero test movement and found dead code behind an earlier early return, not a weak test. Decide which it is before moving on.
4. **Numbers come from the Provisional Values Register, and a missing row is escalated, never invented.** Four Phase 03 tasks in a row escalated rather than inventing (F03-01, F03-18, F03-24, F03-36). P2.10 authors the first real Economy Configuration; the only existing sample carries deliberate placeholder junk and must not be copied.
5. **A green suite is not evidence a human sees anything.** Three enemies shipped invisible with 353 tests green, because the art was referenced only by a test comparing PNG files on disk. Pickups carry the same risk: assert on the assembled scene, and assert the visual node exists.
6. **Parallel tasks break where they meet.** F02-13, F03-05 and F03-15 were all two implementers making defensible choices about a shared seam. Shared core files (`sim_loop.gd`, `event_bus.gd`, the EntityRegistry) have exactly one writer per session, and cross-task seams are reserved to the orchestrator rather than reached for by whoever needs them first.
7. **Never call `remove_child()` in a gdUnit4 `after_test()`** - it orphans every descendant at the instant gdUnit4 counts them and the suite exits 101 (F03-35). Free the root instead.
8. **Spot-check delegated output against the Register rather than trusting the report.** Reading three of twenty-six generated files in Phase 00 found a defect the agent called complete; the Phase 03 spot-check found a Major the whole 353-test suite had not.
9. **Under-claim.** Seven under-claims survived Phase 01's review intact; the single overclaim had to be corrected. Nothing in this phase's record says a test, task or phase is passed, satisfied or ready.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2.8 | Wave Director: data, rings, runtime model, prototype sequence, Siege warning | `src/director/wave_director.gd`, `data/encounters/*.tres`, `data/waves/*.tres` | Spawn ring test (P2.8); Split Assault test (P2.8); Hunt test (P2.8); Encounter recovery test (P2.8); Wave runtime test (P2.8); Overtime test (P2.8) | 1000 scripted spawns valid; all four prototype encounter types load from data; a scripted stall triggers Overtime | 11 | L | Sonnet (implementer) |
| P2.9 | Pressure Metric | Pressure fields on `src/director/wave_director.gd`, overlay fields | Pressure test (P2.9) | Scripted threat and capacity inputs reproduce the documented Pressure value within tolerance | 11 | M | Sonnet (implementer) |
| P2.10 | Pickups, drop table, cap | `src/pickup/*.gd`, `data/pickups/*.tres` | Pickup physics test (P2.10) | Cap holds; blocked pickups stop instead of sliding; death zeroes carried Scrap | 16 (consults 14) | M | Sonnet (implementer) |

## Step-by-step implementation

The step-by-step section below states each task's inputs and deliverable file paths now, and names the owning document section it must follow. It is deliberately not a full walkthrough: per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once Phase 03's actual lessons exist to inform them.

### P2.8 - Wave Director: data, rings, runtime model, prototype sequence, Siege warning

Inputs: Wave and Encounter resources, the two Spawn Rings, camera exclusion, spawn markers, validation, directional weighting, priority and recovery gaps, inter-wave gap, grace period, the Wave Runtime Model (stall, Overtime, carry-over, final-wave rule), the fixed prototype wave sequence as data, the Siege warning (the Pressure Metric excluded, see P2.9); P2.2 deliverable (arena/camera); P2.5 deliverable (enemies); P2.7 deliverable (go decision); P1.4 deliverable (overlay fields); P0.6 deliverable (typed schemas).
Deliverable file paths: `src/director/wave_director.gd`, `data/encounters/*.tres`, `data/waves/*.tres`.
Follows: docs/11_Wave_Director.md > "Wave Runtime Model" in full for the stall/Overtime/carry-over/final-wave rules, the inter-wave gap, and the grace period; > "Encounter Budgets for the Prototype" for the eight prototype waves' spawn groups and maximum durations, the Siege volume formula, and the Siege warning timing; > "Spawn Rings & Placement" for the Tower ring, view ring, camera exclusion, spawn markers, and validation fallback chain; > "Directional Weighting" for Standard Assault, Split Assault, Siege, and Hunt placement rules. Numeric values in these sections are cited by section, not restated here (MASTER_SDLC.md > Provisional Values Register > Spawning & Waves, Encounter Budgets, Pressure & Overtime own the numbers).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.9 - Pressure Metric

Inputs: threat and capacity formulas, escalation, bounded de-escalation, health-quadrant logging (quadrant-aware selection excluded); P2.8 deliverable (Wave Director).
Deliverable file paths: Pressure fields on `src/director/wave_director.gd`, overlay fields.
Follows: docs/11_Wave_Director.md > "Pacing & Escalation Algorithm" in full - Pressure Calculation, Escalation Trigger, De-escalation (bounded), Health quadrant, Overtime - which is this task's complete owning section. Numeric formula constants are cited via MASTER_SDLC.md > Provisional Values Register > Pressure & Overtime, not restated here.

Steps, written at phase entry on 2026-09-20 and given to the implementer:

1. Threat per living, non-dying enemy - current HP x intent weight x (sheet DPS / 10), summed - with sheet DPS read from the enemy's authored Attack profile rather than from measured damage, and the intent weights cited to their Register row.
2. Capacity as the sheet DPS of the player and the Tower with their current upgrades, not measured damage, with the player's term NOT zeroed while the Console is open. The upgrade system is being built in parallel, so capacity is read through a narrow seam with a documented fallback to base values, and the seam is recorded for the orchestrator to wire.
3. Pressure = Threat / (Capacity x 20 s), zero with no enemies, evaluated on the Register's cadence and only while a combat wave (not a teaching wave) is open and outside the grace period.
4. Escalation and bounded de-escalation with both lockouts implemented as independent timers - this phase's own predetermined risk is the two flapping at a boundary - and de-escalation asserted never to apply in a Siege or in Overtime.
5. Health quadrant recorded at every escalation decision, with no effect on selection: logged, not acted on.
6. Pressure, the escalation/de-escalation state and the quadrant surfaced through `src/debug/overlay.gd`'s existing `set_pressure()` and `set_health_quadrant()` seams, and readable by a test with no running game - following the precedent that keeps the Wave Director's spawn geometry a pure `RefCounted`.
7. All timing on SimClock, never wall time or `get_tree()` timers; per-tick work in `physics_step(delta)` behind a `driven_externally` export, with no self-registration against SimLoop.

### P2.10 - Pickups, drop table, cap

Inputs: pickup pool, magnet with raycast blocking, acceleration, merge, lifetime, the Drop Table, run inventory cap with FULL indicator, Scrap loss on death (Cores excluded); P1.3 deliverable (pools); P2.1 deliverable (player collector); P2.5 deliverable (enemies to drop).
Deliverable file paths: `src/pickup/*.gd`, `data/pickups/*.tres`.
Follows: MASTER_SDLC.md > Provisional Values Register > "Economy & Pickups" for Scrap cap/overflow, the Drop Table, magnet radius and motion, the pickup raycast, merge radius, and pickup lifetime (cited here, not restated); docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Collision Layers" table for the Pickup (12) and PlayerCollector (16) layers this task's `Area2D` nodes use. Document 16 (Economy - Pickups) is this task's nominal owner, consulting document 14 (Economy - Currencies); neither exists as a file yet - see "Open questions for the author".

Steps, written at phase entry on 2026-09-20 and given to the implementer:

1. Pickups acquired from the EXISTING pickup pool (`EntitySpawner.spawn_pickup`), never instantiated ad hoc, with type, value, magnet and lifetime authored in `.tres` against the existing `PickupDefinition` schema. Prototype types are the XP shard and Scrap; Cores are out of prototype scope.
2. Magnet and motion exactly per the Register - radius, initial speed, acceleration, maximum speed - each cited to its row.
3. The per-tick raycast toward the player masking EnemyBody, TowerBody and World; blocked means HOLD POSITION keeping stored speed, not slide; collection on overlap with the PlayerCollector; a never-attracted pickup does not simulate.
4. Lifetime with its blink window, and merge at the pickup cap following C-MERGE exactly, including the fallback chain when no merge pair exists.
5. The Drop Table applied on enemy death through the existing `EventBus.enemy_died` signal rather than by reaching into enemies: standard enemy 1 XP + 1 Scrap, Overtime finisher 1 XP and no Scrap, a stuck-despawned enemy still drops.
6. A run inventory: Scrap with its cap and FULL state, overflow discarded because the prototype has no hopper, XP accrual, and the level curve read from a real `data/economy/prototype.tres` authored against the `EconomyConfiguration` schema. The only existing sample of that schema carries deliberate placeholder values and is read for shape only.
7. Carried Scrap zeroed on player death, connected to the `EventBus.player_died` signal being added in the same session by the debt task, with the dependency recorded rather than assumed.
8. Live state exposed in the same field shape `src/ui/hud_economy_state.gd` already defines, so the HUD is wired to it without being rewritten - the seam P2.6 built for exactly this.
9. Per-tick work in `physics_step(delta)` behind a `driven_externally` export, with no self-registration against SimLoop; the orchestrator wires steps 9, 10 and 11.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Spawn ring test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result over 1000 scripted spawns (no instantiation inside the view margin or the Interaction Radius) |
| Split Assault test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result over 20 generated Split Assaults (lane assignment and centre separation) |
| Hunt test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result for every scripted Hunt (at least one landed hit; spawned mix matches the data-defined intent mix) |
| Encounter recovery test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result over 10 of 10 scripted double-schedules (priority open, deferred recovery gap) |
| Wave runtime test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result for stall/no-stall, carry-over, and the never-times-out final wave |
| Overtime test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.8 result for the finisher spawn-or-not decision at the stall threshold |
| Pressure test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.9 result reproducing Pressure from scripted threat/capacity inputs, plus escalation/de-escalation timing |
| Pickup physics test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.10 result for magnet acceleration, raycast blocking, and terrain non-penetration |

Per MASTER_SDLC.md > Document Control > Gate Approval, no agent writes that any of these tests, or this phase, is passed, satisfied, met, or ready; that determination belongs to the reviewers named in "Agent assignment" and, for any accepted-gate row, to the human designer alone. This document records what each test checks and where its result is recorded, nothing more.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The entity cap being exceeded by Overtime finishers | P2.8 implements Overtime finisher spawning on top of whatever enemies already carried over from a stalled wave; if the finisher spawner does not throttle against the live global count the same way ordinary spawn groups do, finishers could push the enemy count past its cap | Implement finisher spawning as a spawn group like any other, subject to the same global entity cap and ring validation/throttle logic (docs/11_Wave_Director.md > "Wave Runtime Model" > Overtime; MASTER_SDLC.md > Provisional Values Register > Spawning & Waves > "Overtime finishers", C-OVERTIME-CAP) | Overtime test; carried into Phase 06 (P2.15) as the Entity cap test, re-checked across every run |
| The Pressure Metric flapping between escalation and de-escalation | P2.9's escalation and de-escalation triggers sit close enough in the formula's range that a threat/capacity swing near a boundary could re-trigger the opposite state before its own lockout expires, unless both cooldowns are enforced independently | Implement both cooldowns as independent timers exactly per docs/11_Wave_Director.md > "Pacing & Escalation Algorithm" > Escalation Trigger and > De-escalation (bounded); expose both states on the debug overlay for scripted inspection (MASTER_SDLC.md > Risk Register: "Pressure Metric oscillates (escalate / de-escalate flapping)") | Pressure test; debug overlay's escalation/de-escalation state field, reviewed against Run Recorder pressure samples |
| Tower becoming irrelevant to moment-to-moment play | P2.8's four prototype encounter types are authored as data; a wave's spawn groups could omit a Tower Seeker or Opportunist with nothing but data review to catch it, silently breaking the Wave Composition rule | Validate every wave's data against the Wave composition rule (docs/11_Wave_Director.md > "Encounter Budgets for the Prototype": "Every combat wave after T1 contains at least one Tower Seeker or Opportunist") as part of authoring the wave resources, not after | A build-time schema check applying the same comparison the (VS-tagged, out-of-prototype-scope) Composition rule test uses, run against every prototype wave resource before P2.8 is reviewed |
| Ghost hits reappearing under spawn density | P2.8 raises enemy counts far above the hand-placed Phase 03 arena; a Logical Death edge case that never triggered at low density (for example many simultaneous deaths on one tick) could surface only once real spawn volume exists | Re-run the same Logical Death sequencing Phase 03 relied on (docs/20_Technical_Architecture.md > "Logical Death") inside a full encounter, and inspect the hit queue's sort order (docs/20 > "SimLoop order" step 7) at high entity counts | Wave runtime test and Spawn ring test runs; any damage event logged against an already-dead entity in events.csv |
| Spawn ring validation exhaustion under Siege volume | The Siege volume formula can place many Seekers on the Tower ring within a short window (combat wave 4); if enough candidate points fail validation at once, the 8-step alternating shift could exhaust before a valid point is found on that ring | Implement the full fallback chain exactly per docs/11_Wave_Director.md > "Spawn Rings & Placement" > "Validation": 8 alternating 10-degree steps, then re-queue the spawn for the next tick without spending budget, and after 8 consecutive failed ticks ignore direction weighting and fall back to the other ring | Spawn ring test (1000 scripted spawns); a log of re-queued spawns during the heavy Siege budget, reviewed for any spawn that never resolves |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P2.8, P2.9, P2.10).

Opus runs one critical agent per task (three critical agents, P2.8 through P2.10) plus one phase reviewer for Phase 04 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. docs/11_Wave_Director.md > "Pacing & Escalation Algorithm" > "Health quadrant" states its own open question: the quadrant is recorded to telemetry at every escalation decision but "has no effect on encounter or spawn selection" in the prototype or the slice, and document 11 "may define quadrant-aware selection later." Should P2.9 add a dormant hook now for future quadrant-aware selection (cheaper to add while this code is fresh, but is speculative scope beyond what P2.9's own task row asks for), or implement pure telemetry-only logging with no hook, matching the current binding rule exactly?
   a. Telemetry-only, no hook; a later document-11 revision adds selection logic when it is defined.
   b. Add a dormant, unused hook now for a future quadrant-aware rule.
   c. Other (please specify).
2. P2.10's owner is "16 (consults 14)"; neither document exists as a file yet, so this plan cites MASTER_SDLC.md > Provisional Values Register > Economy & Pickups in their place, the same pattern Phase 03 flagged for documents 03/05/06/07/27.
   a. The Provisional Values Register remains binding for P2.10 until 14/16 are written.
   b. Write stubs or working drafts for 14 and 16 before Phase 04 implementation starts.
   c. Other (please specify).

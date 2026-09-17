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

phases/LESSONS.md and every earlier phase's (00, 01, 02, 03) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase - recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved - are written into this section before implementation starts. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 03 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P2.8-P2.10 work in this phase begins, with particular attention to whatever Phase 03 recorded about the enemy AI (P2.5) and Tower (P2.4) foundations this phase's spawns and targeting depend on directly.

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
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.10 - Pickups, drop table, cap

Inputs: pickup pool, magnet with raycast blocking, acceleration, merge, lifetime, the Drop Table, run inventory cap with FULL indicator, Scrap loss on death (Cores excluded); P1.3 deliverable (pools); P2.1 deliverable (player collector); P2.5 deliverable (enemies to drop).
Deliverable file paths: `src/pickup/*.gd`, `data/pickups/*.tres`.
Follows: MASTER_SDLC.md > Provisional Values Register > "Economy & Pickups" for Scrap cap/overflow, the Drop Table, magnet radius and motion, the pickup raycast, merge radius, and pickup lifetime (cited here, not restated); docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Collision Layers" table for the Pickup (12) and PlayerCollector (16) layers this task's `Area2D` nodes use. Document 16 (Economy - Pickups) is this task's nominal owner, consulting document 14 (Economy - Currencies); neither exists as a file yet - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

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

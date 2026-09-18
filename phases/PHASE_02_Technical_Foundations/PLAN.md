# Phase 02 - Technical Foundations

Status: In progress since 2026-09-18; Executes: MASTER_SDLC.md > Development Phase Map > Phase 1 - Technical Foundations (the swarm test closes the phase); Plan task IDs: P1.1, P1.2, P1.3, P1.4, P1.5, P1.6, P1.7

## Goal

The engine-level spine, proven under load: SimClock, SimLoop, PauseAuthority, and keyed RNG; the EventBus and query interfaces; object pools and all six entity caps; the debug overlay and Run Recorder; the collision-layer, hitbox/hurtbox, and death-state framework; the audio bus layout and AudioPool; and the swarm stress test at a recorded Performance Fallback Ladder step. This is phases/README.md's phase-table row 02 outcome: "The engine-level spine, proven under load."

## Entry conditions

- Phase 01 exit criteria recorded: Schema check (P0.6) recorded against all eleven prototype-scope contracts under `src/data/`; Harness check (P0.7) recorded for gdUnit4 running headless through the pinned console executable; documents 00-02 at 1.0.0 with doc lint clean; the master's "Phase 0 accepted" row proposed to the author (phases/README.md phase-table row 01 gate).
- The Godot 4.7.1 project skeleton (P0.2) exists. **Corrected at phase entry, 2026-09-18**: this bullet also required the gameplay-root container layout to exist before the phase starts, which contradicts the task table - building that scene is P1.3's own deliverable, and `scenes/main.tscn` is a bare `Node2D` today. The condition is read as applying from P1.3's completion onward, not at phase entry. Recorded in LEDGER.md as F02-01.
- The eleven typed contract schemas under `src/data/` (P0.6 deliverable) exist, since later phases' placeholder content (for example P1.5's placeholder enemy, P1.7's 300 placeholder enemies) is instanced from Enemy, Weapon, and related schemas.

## Carried lessons

Filled on 2026-09-18 at phase entry from phases/LESSONS.md and the full records of Phases 00 and 01, per loop rule (a). Phase 01 alone produced 56 findings across three review iterations; the patterns below are the ones that bear on an engine-spine phase.

| # | Pattern | What it changes in Phase 02 |
| --- | --- | --- |
| 1 | **A check is not believed until it has been made to fail.** Phase 01 shipped three separate checks that could not fail: a schema check that asked the script under test what fields to expect, a CI guard that matched negatively on output so it passed whenever output was lost, and a ledger check reading the wrong column whose green result was reported to the author twice as evidence | Every acceptance test in this phase - and there are nine named ones - is falsified before its result is recorded. The RNG, pause-clock, cap, pool, recorder, ghost-hit and audio-priority checks each get at least one deliberate break proving the check goes red, and the break targets the assertion the implementer is least confident in |
| 2 | **A validator that derives its expectations from the thing it validates cannot detect an omission.** The fix was an independent manifest transcribed from the source document | P1.4's Recorder schema check takes its column list directly from docs/20's Run Recorder section, transcribed, not read back from the writer. P1.3's cap check takes the six cap values from the Provisional Values Register, not from the spawner's own constants |
| 3 | **Never write a cause, or a negative claim, without an experiment.** Recorded three times in Phase 01, and broken three times in the same phase - including "this cannot be reproduced here", which a reviewer disproved in two minutes | This phase measures rather than reasons. P1.7 in particular: the Performance Fallback Ladder step adopted is the one that was *measured* to pass, on an exported release build on the reference machine, never the one predicted to |
| 4 | **Freeze the tree when the review gate opens, and falsify against an exported copy rather than the shared working directory.** Phase 01 broke this twice; the third iteration fixed it with a tag and it held for every reviewer | Phase 02's gate opens on a tagged commit. Reviewers are told to falsify against `git archive` copies, not the live tree, since a reviewer mutating a shared file gave iteration 2 a false failure |
| 5 | **Verify by reading the artifact back; a tool reporting success is not evidence.** | Applies directly to P1.3 and P1.5: `Pool.acquire()` must be verified by reading back every flag Logical Death changed, not by the absence of an error. The Ghost hit test exists precisely because a clean return proves nothing |
| 6 | **Structural checks over the record must cover row position, column count and column identity - not just width.** Phase 01's ledger broke three times, twice in ways a column count could not see, once in the file holding the lesson about it | The structural check runs over *every* record file in this phase, not the one that broke last time |
| 7 | **When a decision lands mid-phase, re-check every already-written delegation scope against it.** A Phase 01 delegation forbade `docs/` edits hours after a decision required a docs edit, leaving the implementer structurally unable to satisfy an exit condition | Phase 02 takes its decisions at entry (D94-D96) rather than mid-flight, and any later decision triggers a sweep of open delegations before dispatch |
| 8 | **Nine of Phase 01's sixteen Majors were the orchestrator's, not the implementers'.** The blind gate is what caught them, including a decision mislabelled as the author's | The gate is not a formality to get through. Reviewer findings against the orchestrator's own work are expected and are recorded as such rather than attributed to implementers |

Two engine-specific carries from Phase 00 also apply here. **Everything under the Godot project root is a resource**, so P1.7's stress scene and any placeholder assets must be export-excluded or deliberately shipped, not left to chance. And **Godot 4.7.1 silently nulls a type-mismatched resource property** with no engine diagnostic (Phase 01 F01-08, reproduced twice), so P1.3's pool and P1.5's components cannot rely on the engine to surface a wrong-class reference.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P1.1 | SimClock, SimLoop, PauseAuthority, keyed RNG, banned-API grep check | `src/core/sim_clock.gd`, `sim_loop.gd`, `pause_authority.gd` | Keyed RNG unit check (P1.1); Pause clock unit check (P1.1) | `SimClock.now` stops under pause and resumes exactly; keyed rolls identical across repetitions; grep finds zero banned calls | 20 | S | Sonnet (implementer) |
| P1.2 | EventBus and query interfaces | `src/core/event_bus.gd`, `entity_registry.gd`, `combat_stats.gd` | Registry query check (P1.2) | Query passes the timing bound; committed with the docs/20 section it follows | 20 | S | Sonnet (implementer) |
| P1.3 | Object pools and all six caps | `src/core/pool.gd`, gameplay root scene | Cap unit check (P1.3); Pool unit check (P1.3) | All six caps hold in a stress script | 20 | M | Sonnet (implementer) |
| P1.4 | Debug overlay, Run Recorder, pseudo-localization toggle | `src/debug/overlay.tscn`, `run_recorder.gd` | Recorder schema check (P1.4) | Overlay shows every required field; `ticks.csv` and `events.csv` are written per run matching the schema | 20 | M | Sonnet (implementer) |
| P1.5 | Collision layers, hitbox/hurtbox framework, death state | `src/combat/hitbox.gd`, `hurtbox.gd`, `death_state.gd` | Ghost hit test (P1.5) | 100 mid-attack kills produce zero post-death damage events | 20 (consults 05) | M | Sonnet (implementer) |
| P1.6 | Audio bus layout and AudioPool | Bus layout resource, `src/audio/audio_pool.gd` | Audio priority check (P1.6) | Priority cue steals a voice and remains audible across trials | 26 | S | Sonnet (implementer) |
| P1.7 | Swarm stress test | Stress scene and a recorded result in document 20 | Swarm performance test (P1.7 soak with 300 placeholder enemies) | Either the base case passes the performance rule, or the Performance Fallback Ladder step that passes is recorded and adopted; if step 4 also fails, the design revision is recorded in the Review Decision Log and the test repeats | 20 | M | Sonnet (implementer) |

## Step-by-step implementation

The step-by-step section below states each task's inputs and deliverable file paths now, and names the owning document section it must follow. It is deliberately not a full walkthrough: per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once Phase 01's actual lessons exist to inform them.

### P1.1 - SimClock, SimLoop, PauseAuthority, keyed RNG, banned-API grep check

Inputs: physics-tick clock, time_scale cap, SimLoop fixed tick order, reason-set pause, process-mode mapping, keyed RNG helpers, a grep check banning `get_tree().create_tween()` and `create_timer()` calls under the gameplay root; P0.2 deliverable (project skeleton); P0.7 deliverable (harness).
Deliverable file paths: `src/core/sim_clock.gd`, `src/core/sim_loop.gd`, `src/core/pause_authority.gd`.
Follows: MASTER_SDLC.md > Global Simulation Authority in full (Pause Rules, Timing Rules, Level-Up Draft Rule, Focus Loss Rule) for what SimClock and PauseAuthority own, and docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "SimLoop order" bullet for the fixed per-tick step order.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.2 - EventBus and query interfaces

Inputs: EventBus signal list, `EntityRegistry` with radius queries, `CombatStats` (reports sheet DPS), typed commands; P0.2 deliverable; P1.1 deliverable (SimClock for timestamps); docs/20 > Godot 4.x Implementation Standards.
Deliverable file paths: `src/core/event_bus.gd`, `src/core/entity_registry.gd`, `src/core/combat_stats.gd`.
Follows: docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Communication, events", "Communication, queries", and "Communication, commands" bullets, which define the signals-vs-queries-vs-commands split this task implements.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.3 - Object pools and all six caps

Inputs: pools for enemies, projectiles, pickups, effects; cap enforcement in the spawner API; container nodes under the gameplay root; P1.2 deliverable (EntityRegistry).
Deliverable file paths: `src/core/pool.gd`, and the gameplay root scene (container nodes under it).
Follows: docs/20_Technical_Architecture.md > Interim Prototype Technical Budgets for the six cap values (cited via MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance, not restated here); > Godot 4.x Implementation Standards > "Scene Tree" for the container-node layout; and > "Logical Death" for what `Pool.acquire()` must restore before reuse.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.4 - Debug overlay, Run Recorder, pseudo-localization toggle

Inputs: every field the debug overlay and Run Recorder rules require; CSV export; run seed; pseudo-localization toggle; P1.1 deliverable (SimClock); P1.2 deliverable (EventBus).
Deliverable file paths: `src/debug/overlay.tscn`, `src/debug/run_recorder.gd`.
Follows: docs/20_Technical_Architecture.md > "Debugging, Telemetry & Run Recording" in full (Debug Overlay field list, Run Recorder file layout and column schema, Idleness Metric).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.5 - Collision layers, hitbox/hurtbox framework, death state

Inputs: the 16-layer binding table applied; hitbox and hurtbox components; deferred disabling on Logical Death; the Logical/Visual death state machine on a placeholder enemy; P1.3 deliverable (pools).
Deliverable file paths: `src/combat/hitbox.gd`, `src/combat/hurtbox.gd`, `src/combat/death_state.gd`.
Follows: docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Collision Layers" table and > "Logical Death" bullet, and > "Animation, Hitbox, and State Cleanup Rules" in full (Logical vs Visual Death, Animation Cancellation, Spatial Cleanup, Projectile Orphans); owner doc 20 consults document 05 (Combat System) per the master's task table.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.6 - Audio bus layout and AudioPool

Inputs: the six audio buses (Music, SFX, SFX_Priority, TowerCue, UI, Ambience; C-TOWERCUE) and their routing; ducking on a `PROCESS_MODE_ALWAYS` node; the 32-voice AudioPool with priority stealing; P0.2 deliverable; docs/20 > Audio Mixing & Dynamic Ducking.
Deliverable file paths: a bus layout resource, `src/audio/audio_pool.gd`.
Follows: docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic Ducking" in full (Audio Bus Hierarchy, Dynamic Ducking, Retrigger Limits, Tower Cue Player, Voice Limit); the master's task table names document 26 (Audio Design) as owner, which is a stub only at this time - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P1.7 - Swarm stress test

Inputs: 300 placeholder enemies with `CharacterBody2D` moving toward a point, 400 projectiles, 150 pickups, measured on the reference machine; adopting the first passing Performance Fallback Ladder step if the base case fails; P1.3, P1.4, P1.5 deliverables; the Performance Fallback Ladder.
Deliverable file paths: a stress test scene (path to be fixed at phase entry) and a recorded result written into docs/20_Technical_Architecture.md.
Follows: docs/20_Technical_Architecture.md > "Performance Fallback Ladder" in full (the ordered four steps and the rule that testing stops at the first step that passes) and > "Interim Prototype Technical Budgets" (the reference-machine measurement rule: exported release build, V-Sync off, 60 seconds of CSV-logged frame data). This task must record which ladder step was adopted, since the ladder's own text requires "document 20 records which step was needed."
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Keyed RNG unit check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.1 keyed-roll repetition result |
| Pause clock unit check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.1 `SimClock.now` pause/resume result |
| Registry query check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.2 radius-query timing result |
| Cap unit check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.3 scripted-spawner cap result, all six caps |
| Pool unit check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.3 acquire/release cycle result |
| Recorder schema check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.4 `ticks.csv` / `events.csv` header diff result |
| Ghost hit test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.5 mid-attack kill result |
| Audio priority check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.6 voice-stealing trial result |
| Swarm performance test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P1.7 result and the adopted Performance Fallback Ladder step (base case or step 1-4) |

Plus, per P1.1's own exit criterion: the banned-API grep check finds zero calls to `get_tree().create_tween()` or `create_timer()` under the gameplay root. Per phases/README.md's phase-table row 02 gate, the master's "Phase 1 accepted" row is proposed to the author, never written by an agent (MASTER_SDLC.md > Document Control > Gate Approval). This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Godot pause traps (SceneTreeTimer, Tween, PROCESS_MODE_ALWAYS leakage) per the Risk Register | `get_tree().create_timer()` and `create_tween()` are the default GDScript idiom for timing, and `PROCESS_MODE_ALWAYS` is a single inspector toggle that silently exempts a node from pause if it lands on a gameplay-root descendant | SimClock and PauseAuthority Autoloads are the only timing and pause writers (MASTER_SDLC.md > Risk Register; > Global Simulation Authority); P1.1's own exit criterion is a grep check banning the two calls under the gameplay root | The P1.1 grep check itself; a manual check during P1.3-P1.7 that nothing under Entities/Projectiles/Pickups/Effects sets PROCESS_MODE_ALWAYS (docs/20 > Scene Tree: "Nothing under the gameplay root may set PROCESS_MODE_ALWAYS") |
| Per-node physics cost of 300 CharacterBody2D enemies exceeding budget, with the Performance Fallback Ladder as the pre-agreed escape | MASTER_SDLC.md > Risk Register: per-node physics overhead in Godot is known to be the limiting factor for survivors-like enemy counts, and it has not been measured on this project yet | P1.7 runs last in this phase, after pools, the recorder, and hitboxes exist, and steps through docs/20 > Performance Fallback Ladder in order, adopting only the first step that passes | Swarm performance test on the reference machine, exported release build, V-Sync off, 60 s CSV log (docs/20 > Interim Prototype Technical Budgets) |
| NavigationServer2D asynchronous resolution (the prototype uses no NavigationAgent2D) | A `NavigationAgent2D` node looks like the natural way to move placeholder enemies toward the player or Tower, but its path resolution is asynchronous and can resolve on a different tick than issued, breaking the fixed per-tick resolution order Determinism promises | P1.5 and P1.7 placeholder enemy movement moves directly toward a point with no `NavigationAgent2D`, matching P1.7's own stated inputs; MASTER_SDLC.md > Risk Register states the same rule | Critical agent checks P1.5 and P1.7 scripts and scenes for any `NavigationAgent2D` node or `NavigationServer2D` call |
| A pool that leaks monitoring flags or collision layers on acquire | docs/20 > Logical Death requires `Pool.acquire()` to restore every layer, mask, and monitoring flag Logical Death changed; a pool that restores only some of them (for example the body's collision_layer but not the hurtbox's monitorable flag) reintroduces ghost-hit bugs on reuse | P1.3's pool restores every flag Logical Death changes (hitbox monitoring, hurtbox monitorable and collision_layer, body collision_layer and collision_mask) in one acquire() path, and P1.5 (which depends on P1.3) is reviewed against the same list | Pool unit check (acquire/release cycling, object count stable); Ghost hit test (100 mid-attack kills, zero post-death damage events) exercises a reused, previously-dead instance |
| The Run Recorder schema drifting from the defined columns | docs/20 > Run Recorder defines exact column lists for `ticks.csv` and `events.csv`; adding a convenience column or renaming one during P1.4 drifts the schema with no obvious failure until a later phase reads the CSV | P1.4 implements the header row directly from docs/20 > "Debugging, Telemetry & Run Recording" > Run Recorder's column list, not from memory | Recorder schema check: the scripted run's written headers diffed against the schema docs/20 defines |
| The swarm test being measured on the wrong machine or in the editor instead of an exported release build with vsync off | Running the stress scene directly in the Godot editor is the fastest iteration loop, and it is easy to record that result instead of re-measuring after an export | P1.7 explicitly requires an exported release build on the reference machine, V-Sync off (docs/20 > Interim Prototype Technical Budgets' reference-machine rule); EXECUTION_LOG.md records the build type and machine for the recorded result | Reviewer checks that the recorded result's metadata names an exported release build and the reference machine, not an editor run |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P1.1 through P1.7).

Opus runs the review gate at the pace decision **D94** fixes in advance, which narrows D83's literal one-agent-per-task rule for this phase and records the narrowing as D83 requires: **four critical agents grouped by coupled subsystem** - P1.1 with P1.2, P1.3 with P1.5, P1.4 alone, P1.6 alone - **plus one phase reviewer**, who also covers P1.7 as the phase's load test. Five reviewers per iteration rather than eight. The grouping follows the dependency chain so that a reviewer sees a whole subsystem rather than half of one. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. P1.6's owner document is "26" (Audio Design) in MASTER_SDLC.md's task table, but document 26 exists only as a P0.3 stub; the only current binding audio implementation detail is docs/20_Technical_Architecture.md > Audio Mixing & Dynamic Ducking. This PLAN.md follows docs/20 as binding, since docs/20's own Authority statement says it is "binding for the Minimum Playable Prototype." Is that the intended reading, or should docs/26 be written to at least "working" status before P1.6 starts?
   a. docs/20 remains binding for P1.6 even though 26 is the nominal owner; docs/26 catches up later.
   b. Write docs/26 to at least "working" status before P1.6 starts.
   c. Other (please specify).
2. As recorded in Phase 01's PLAN.md, `D:\Gamedev\phases\PHASE_00_Environment_And_Connection\` currently has none of its own five files, and Phase 01 (this phase's own dependency) has not run either. Should Phase 00 and Phase 01 be created and run to completion before this Phase 02 PLAN.md is acted on, or is drafting the fixed-scope sections of later phases' plans ahead of their dependencies intended, with only real execution waiting on those dependencies?
   a. Create and run Phase 00 and Phase 01 fully before Phase 02 starts.
   b. Drafting ahead is fine; execution order still waits on the stated dependencies.
   c. Other (please specify).
3. P1.3's six entity caps are Provisional Defaults in the Provisional Values Register with no "Author decision" tag (unlike, for example, the Onboarding & Session register's A1/A2 rows). If the swarm test (P1.7) forces Performance Fallback Ladder step 4, the ladder's own text says the resulting design revision (fewer simultaneous enemies per wave) is "recorded in the Review Decision Log" - but does not say the cap change itself needs separate author sign-off first. Confirm the intended process.
   a. Any Provisional Default, including these caps, may be revised per the master's own change rule (Register update plus a Review Decision Log row if intent changes) without a separate author sign-off step.
   b. Cap changes specifically need the author's sign-off before the Register is updated.
   c. Other (please specify).

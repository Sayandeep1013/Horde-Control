# Phase 03 - Core Entities and Feel Check

Status: Not started; Executes: MASTER_SDLC.md > Development Phase Map > Phase 2 - Core Tension Prototype (the Minimum Playable Prototype) (part); Plan task IDs: P2.1, P2.2, P2.3, P2.4, P2.5, P2.6, P2.7

## Goal

Player, arena, weapon, Tower, three enemy intents (one enemy type per target intent), HUD and threat feedback, and a recorded feel verdict. This is phases/README.md's phase-table row 03 outcome: "Player, arena, weapon, Tower, three enemy intents, HUD, and a recorded feel verdict." Per MASTER_SDLC.md > Development Phase Map > P2.7, P2.7's internal testers are the designer and the AI collaborator's scripted bots only, and nobody who plays P2.7 may take part in the external playtest at P2.16 (Phase 06).

## Entry conditions

- Phase 02 exit criteria recorded: Keyed RNG unit check, Pause clock unit check, Registry query check, Cap unit check, Pool unit check, Recorder schema check, Ghost hit test, and Audio priority check all recorded; Swarm performance test recorded at a Performance Fallback Ladder step (base case or step 1-4); the master's "Phase 1 accepted" row proposed to the author (phases/README.md phase-table row 02 gate).
- SimClock, SimLoop, and PauseAuthority Autoloads (P1.1 deliverable) exist for every timer this phase adds: the player's input buffer (P2.1), telegraph wind-ups (P2.5), and the Tower's shield-regen delay (P2.4).
- EventBus and the query interfaces - EntityRegistry, CombatStats (P1.2 deliverable) - exist for Tower targeting (P2.4) and enemy AI queries (P2.5).
- Object pools and the six entity caps (P1.3 deliverable), and the gameplay root's container-node layout (`Entities`, `Projectiles`, `Pickups`, `Effects`, `Environment`, `Audio`), exist for everything this phase pools: projectiles (P2.3), enemies (P2.5), VFX and damage numbers (P2.6).
- The debug overlay and Run Recorder (P1.4 deliverable) exist to verify this phase's scripted tests and to support the P2.7 feel check.
- The 16-layer collision binding, the hitbox/hurtbox framework, and the Logical/Visual death state machine (P1.5 deliverable) exist for the player's hurtbox (P2.1), the weapon's hit delivery (P2.3), the Tower's same-frame death handling (P2.4), and enemy contact damage (P2.5).
- The audio bus layout and AudioPool (P1.6 deliverable) exist for the Tower damage cue (P2.6).
- The swarm stress test result and the adopted Performance Fallback Ladder step (P1.7 deliverable) exist, so this phase's enemy and projectile counts are built against a proven performance baseline.
- The eleven typed contract schemas under `src/data/` (P0.6 deliverable) exist for every `.tres` resource this phase authors (`data/weapons/handgun.tres`, `data/tower/base.tres`, `data/enemies/*.tres`).

## Carried lessons

phases/LESSONS.md and every earlier phase's (00, 01, 02) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase - recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved - are written into this section before implementation starts. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows, and phases 00, 01, and 02 have not run to completion (Phase 02's own FAILURE_POINTS.md, LEDGER.md, and REVIEW.md do not yet exist), so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P2.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2.1 | Player controller | `scenes/player.tscn`, `src/player/*.gd` | Player movement check (P2.1); Player silhouette test (P2.1) | Movement-only run through an empty arena at reference speed and acceleration | 03 | M | Sonnet (implementer) |
| P2.2 | Arena and camera | `scenes/arena.tscn`, `src/camera/game_camera.gd` | Camera bounds test (P2.2) | Sweep passes at every view scale (0.9 to 1.15) | 27 (consults 20) | S | Sonnet (implementer) |
| P2.3 | Handgun and auto-targeting | `data/weapons/handgun.tres`, `src/combat/auto_weapon.gd` | Weapon check (P2.3) | Kills placeholder enemies at the sheet DPS; no targeting input exists | 06 (consults 05) | M | Sonnet (implementer) |
| P2.4 | Tower | `scenes/tower.tscn`, `src/tower/*.gd`, `data/tower/base.tres` | Tower weapon check (P2.4); Same-frame death test (P2.4); Health recovery check (P2.4) | Tower fires, takes damage, dies, ends the run; a same-tick zero-zero is credited to the Tower | 07 | M | Sonnet (implementer) |
| P2.5 | Three enemies, one per intent | `data/enemies/*.tres`, `src/enemy/*.gd` | Leash test (P2.5); Opportunist test (P2.5); Stuck exemption test (P2.5) | Each intent behaves per its default in a scripted arena | 09 | L | Sonnet (implementer) |
| P2.6 | HUD and threat feedback | `src/ui/hud.gd`, `src/ui/threat_feedback.gd` | Tower cue audibility check (P2.6) | HUD fields readable at 1080p; cue audible over concurrent sounds | 19 (consults 26, 27) | S | Sonnet (implementer) |
| P2.7 | Feel check | Recorded go/adjust decision in document 29 | Feel check (P2.7, designer and scripted bots, recorded go/adjust) | "Go" recorded, or the named adjustment is made and the check repeats | 29 | S | Sonnet (implementer) |

## Step-by-step implementation

The step-by-step section below states each task's inputs and deliverable file paths now, and names the owning document section it must follow. It is deliberately not a full walkthrough: per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once Phase 02's actual lessons exist to inform them.

### P2.1 - Player controller

Inputs: movement, acceleration/stop times, health, hurtbox, input buffer, contact damage receipt, death (dash and weapons excluded); P1.5 deliverable (hitbox/hurtbox framework, death state).
Deliverable file paths: `scenes/player.tscn`, `src/player/*.gd`.
Follows: MASTER_SDLC.md > Player Overview > Movement Design & Input Buffering and > Input Buffering Rules for movement, acceleration, stop timing, and the input buffer; MASTER_SDLC.md > Player Overview > Player Contact and Collision Rules for contact damage receipt; docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards (Physics & Collisions - Entity sizes; Logical Death) for the player's hurtbox and death state. Document 03 (Player Character) is this task's nominal owner in the master's task table but does not yet exist as a file - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.2 - Arena and camera

Inputs: 4800x3200 arena, hard walls, no interior obstacles, camera follow, lead, zoom rules, hard bounds (art excluded); P2.1 deliverable (player to follow).
Deliverable file paths: `scenes/arena.tscn`, `src/camera/game_camera.gd`.
Follows: MASTER_SDLC.md > Game Overview > Perspective and Arena for the arena's size and wall rule; MASTER_SDLC.md > Provisional Values Register > Arena & Camera for the camera follow, lead, zoom, and smoothing fields this task implements (cited here, not restated); docs/20_Technical_Architecture.md lines 9-135 (Godot 4.x Implementation Standards) for the pinned viewport, stretch mode, and aspect settings the camera must respect. Document 27 (Camera & Feel) is this task's nominal owner, consulting document 20; 27 does not yet exist as a file - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.3 - Handgun and auto-targeting

Inputs: one auto-fire weapon, nearest-target re-pick every shot, projectile pooling, damage by value at fire time (weapon evolutions excluded); P2.1 deliverable (player); P1.5 deliverable (hitbox framework); P0.6 deliverable (typed schemas).
Deliverable file paths: `data/weapons/handgun.tres`, `src/combat/auto_weapon.gd`.
Follows: MASTER_SDLC.md > Player Overview > Starting Weapon; docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "SimLoop order" step 4 (weapon targeting and firing) and step 7 (hit queue sorted by target serial, attacker serial) for firing and hit-resolution order, and > "Physics & Collisions" for projectile `Area2D` rules and the fast-projectile sweep. Document 06 (Combat & Weapons) is this task's nominal owner, consulting document 05 (Combat System); neither exists as a file yet - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.4 - Tower

Inputs: health, shield, footprint, Targeting Rule, base weapon, Interaction Radius trigger, death, stage counter (evolution art and drones excluded); P2.3 deliverable (weapon pattern to mirror); P2.2 deliverable (arena); P0.6 deliverable (typed schemas).
Deliverable file paths: `scenes/tower.tscn`, `src/tower/*.gd`, `data/tower/base.tres`.
Follows: MASTER_SDLC.md > Tower Overview in full (Why The Tower Has Its Own Health Pool, Tower Roles In Detail, Tower Interaction Mechanics, Tower Targeting Rule, Tower Evolution Stages, Tower Vulnerability Design, Health Recovery Rules); docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "SimLoop order" step 8 (death resolution in order Tower, bosses, player, other enemies) for the same-frame death rule this task's own acceptance test checks. Document 07 (Tower Systems) is this task's nominal owner and does not yet exist as a file - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.5 - Three enemies, one per intent

Inputs: Seeker, Hunter, Opportunist as `.tres` with Intent Behaviour Defaults, telegraphs, contact damage, seek-and-separation steering and attack slots, stuck rules (elites and archetypes excluded); P1.5 deliverable (hitbox framework); P2.4 deliverable (Tower to threaten); P0.6 deliverable (typed schemas).
Deliverable file paths: `data/enemies/*.tres`, `src/enemy/*.gd`.
Follows: docs/09_Enemy_AI_Architecture.md > "Intent Behaviour Defaults" in full - Attack slots, Tower Seeker body-block rule, Player Hunter leash rule, Opportunist event rule, Stuck rules, Telegraph minimums - which is this task's complete owning section (document 09 is Working and directly binding).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.6 - HUD and threat feedback

Inputs: both health bars, Scrap readout, XP bar, vignette with the two pointing rules, off-screen Tower indicator, Tower damage cue on the priority bus, placeholder VFX, damage numbers, a debug effect spawner (minimap excluded); P2.4 deliverable (Tower health/shield); P1.6 deliverable (AudioPool).
Deliverable file paths: `src/ui/hud.gd`, `src/ui/threat_feedback.gd`.
Follows: docs/19_UI_UX.md > "HUD" for the four HUD fields and their truncation rule; MASTER_SDLC.md > Provisional Values Register > Interfaces > "Threat feedback" row for the vignette and off-screen-indicator behaviour (cited here, not restated); docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic Ducking" > "Tower Cue Player" for the priority-bus cue, its pan rule, and its retrigger limit, which this task's own acceptance test checks. Document 19 is this task's owner and is Working; it consults documents 26 (Audio Design) and 27 (Camera & Feel), neither of which exists as a file yet.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.7 - Feel check

Inputs: hand-placed enemies, one per intent, no Wave Director running; the designer and the AI collaborator's scripted bots only as internal testers; a recorded go/adjust decision; the rule that nobody who plays P2.7 may take part in P2.16 (automated pacing excluded); P2.5 deliverable (enemies); P2.6 deliverable (HUD/feedback).
Deliverable file paths: a recorded go/adjust decision in document 29 (docs/29_Milestones_and_Roadmap.md).
Follows: MASTER_SDLC.md > Minimum Playable Prototype Gate, and MASTER_SDLC.md > Acceptance Test Matrix > Build Checks > "Feel check" row, for the test's own definition. Document 29 is this task's nominal deliverable location, but as read for this plan it currently contains no Phase 2 section to record a Feel check verdict in (only "Phase 3 - Vertical Slice", "Phase 4 - Production", and "Deferred Review Findings") - see "Open questions for the author"; until that is resolved, this task records its verdict in this folder's own EXECUTION_LOG.md and LEDGER.md as an interim location.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Player movement check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.1 acceleration/stop and input-buffer result |
| Player silhouette test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P2.1 render-order result (player above enemies when surrounded) |
| Camera bounds test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.2 arena-edge sweep result at every view scale |
| Weapon check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.3 fire-rate, damage, range, and re-pick result |
| Tower weapon check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.4 Tower targeting and fire result |
| Same-frame death test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.4 ten-trial same-tick zero-zero result |
| Health recovery check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.4 shield regen delay/restart result |
| Leash test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.5 Hunter leash-to-Seeker conversion result |
| Opportunist test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.5 Opportunist event-rule and hysteresis result |
| Stuck exemption test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.5 queued-vs-stuck timer result |
| Tower cue audibility check | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P2.6 bus/pan/retrigger scripted assertion result |
| Feel check | MASTER_SDLC.md > Acceptance Test Matrix > Build Checks | P2.7 designer-and-scripted-bot go/adjust verdict |

Per MASTER_SDLC.md > Document Control > Gate Approval, no agent writes that any of these tests, or this phase, is passed, satisfied, met, or ready; that determination belongs to the reviewers named in "Agent assignment" and, for any accepted-gate row, to the human designer alone. This document records what each test checks and where its result is recorded, nothing more.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Ghost hits from an entity that died mid-attack | P2.3 (weapon fire and hit queue) and P2.5 (enemy death, attack wind-up) are separate tasks; if the Logical Death deferred-flag sequencing is not wired into the enemy attack and hit-queue code exactly as specified, a hit already queued against a dying entity could still apply, or a dying enemy's own wind-up attack could still land | Implement Logical Death exactly per docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Logical Death" and > "Animation, Hitbox, and State Cleanup Rules" > "Animation Cancellation"; follow the SimLoop order (docs/20 > "SimLoop order") so death resolution and hit-queue sorting run in their defined step order | Re-run the same mid-attack-kill scenario the P1.5 Ghost hit test used, now against the built Seeker/Hunter/Opportunist and the Handgun/Tower weapon, in a scripted P2.5 arena; any damage event logged after an entity's death tick in the Run Recorder events.csv fails it |
| Tower becoming irrelevant to moment-to-moment play | P2.1-P2.3 build the player and weapon before the Tower (P2.4); if placeholder enemies used to validate P2.1-P2.3 target only the player, the Tower's threat model can become an afterthought, and P2.7 could record a "go" on player-only combat with nothing pressuring the Tower | Build Seeker, Hunter, and Opportunist together at P2.5, per docs/09_Enemy_AI_Architecture.md > Intent Behaviour Defaults, before P2.7 runs, so the feel check always includes at least one Tower-directed enemy; keep the Tower Targeting Rule and Interaction Radius (MASTER_SDLC.md > Tower Overview) implemented before P2.6/P2.7 (MASTER_SDLC.md > Risk Register: "Tower becomes irrelevant to moment-to-moment play") | The P2.7 Feel check verdict itself: the designer and scripted bots explicitly record whether the Tower read as a separate thing worth protecting |
| Tester probes being run by anyone who already played an earlier build | P2.7's internal testers are the designer and the AI collaborator's scripted bots only, by design; if any other person plays P2.7 informally, that person is no longer eligible for the external tester pool MASTER_SDLC.md > Development Phase Map names at P2.16 | Restrict P2.7 access to the designer and scripted bots only; log who ran each P2.7 session in this folder's EXECUTION_LOG.md | Phase 06 cross-checks its P2.16 tester roster against this phase's EXECUTION_LOG.md entries for P2.7 sessions, per loop rule (a) |
| Scripted bots whose behaviour does not match the test's definition | P2.7's scripted bots stand in for human play against three enemy intents with no Wave Director running; if a bot's movement or engagement logic drifts from what the Acceptance Test Matrix later names at P2.15/P2.16 (orbit bot, roam bot, still bot), a "go" verdict here could rest on behaviour those later bots do not reproduce | Build the P2.7 scripted bots as early, minimal versions of the same bot behaviours the Acceptance Test Matrix names, documented against their test definitions rather than invented ad hoc | The Phase 03 critical agent for P2.7 compares the bot scripts against the bot definitions cited in MASTER_SDLC.md > Acceptance Test Matrix |
| Player silhouette / Y-sort misconfiguration | P2.1 (player), P2.5 (enemies), and P2.6 (telegraphs, damage numbers) all touch the scene tree's draw order; if the player is added under the pooled `Entities` container instead of its own fixed-`z_index` node, it is Y-sorted with enemies instead of always drawing above them | Follow docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Scene Tree" exactly: the player is not a child of `Entities` and is not part of its Y-sort group, with a fixed `z_index` above enemies | Player silhouette test |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P2.1 through P2.7).

Opus runs one critical agent per task (seven critical agents, P2.1 through P2.7) plus one phase reviewer for Phase 03 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. Documents 03 (Player), 06 and 05 (Weapon/Combat), 07 (Tower), and 27 (Camera) are named as task owners in MASTER_SDLC.md's Development Phase Map for P2.1-P2.6, but none of them exist as files under `docs/` (only 09, 11, 19, 20, and 29 do). This plan follows MASTER_SDLC.md's own sections (Player Overview, Tower Overview, Game Overview) as binding in their place, since the master "wins on intent" until a system document overrides it.
   a. MASTER_SDLC.md remains binding for these tasks even though their nominal owners are unwritten; the owning documents catch up later (Phase 07, per phases/README.md's Coverage note on slice documentation).
   b. Write stubs or working drafts for 03, 05, 06, 07, and 27 before Phase 03 implementation starts.
   c. Other (please specify).
2. [Contradiction, reported, not resolved] docs/29_Milestones_and_Roadmap.md, as it currently exists, has no Phase 2 section - only "Phase 3 - Vertical Slice", "Phase 4 - Production", and "Deferred Review Findings". P2.7's deliverable is "Recorded go/adjust decision in document 29" per MASTER_SDLC.md's own task table, but there is nowhere in the current file to record it.
   a. Add a Phase 2 section to docs/29_Milestones_and_Roadmap.md before P2.7 needs it.
   b. Record the P2.7 verdict (and, later, P2.15/P2.16/P2.18's outputs) somewhere else - the master's own Change Log/Development Status, or a phases/ file - and leave document 29 to Phase 3 onward, matching its current first heading.
   c. Other (please specify).

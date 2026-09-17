# Phase 08 - Slice Systems

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.3, P3.4, P3.5, P3.6, P3.7, P3.8, P3.12

## Goal

Build the slice's core mechanical systems: the biome mechanical hook and its always-on hazard; the full economy (Cores across all three routes, the overflow hopper, the Drop Table, Run-End Settlement, the Meta Wallet); the status effect system; the dash movement upgrade with the hook degrade floor it must respect; the three weapon evolution steps offered through the Level-Up Draft; the slice's enemy roster (Zone Denier and Disruptor intents, eight base enemy types, two elite affixes, the Elite encounter); and the slice's player and Tower upgrade pools with their dominant-pair audit, Banish, and reroll. This is phases/README.md's phase-table row 08 outcome: "Biome hook and hazard, full economy, status effects, dash, weapon evolutions, enemy roster, upgrade pools."

P3.12 (upgrade pool) is placed in this phase, ahead of its numeric position in docs/29's task list, because P3.6 (dash, hook degrade floor) depends on P3.12's upgrade pool for the dash's place among Tower and player upgrades, while P3.12's own dependencies (P3.2, P2.11) both resolve earlier (Phase 07 and Phase 05 respectively). Running P3.12 in a later phase would have made this phase's systems task depend forward on a later phase, which phases/README.md's "Changes from the drafted phase split" item 3 also records for the phase split as a whole.

## Entry conditions

- Phase 07 deliverables: document 09 (Enemy AI Architecture) stable; documents 12, 14, 15, 17, 13 at a working draft (P3.2); documents 19, 08, 24, 06 at a working draft (P3.2b) - the specific working-draft documents this phase's tasks cite as Inputs in docs/29 (P3.3 cites doc 15 and doc 19; P3.4 cites doc 14, docs 08 and 24; P3.5 cites doc 09 stable and doc 12; P3.7 cites doc 17 and doc 06; P3.8 cites docs 09 and 14; P3.12 cites docs 17 and 13).
- Phase 05 deliverable: the upgrade system (P2.11), which P3.7 and P3.12 both list as an Input.
- Phase 04 deliverable: pickups and Scrap (P2.10), which P3.4 lists as an Input.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 07) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 07 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P3.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.3 | Biome hook and hazard | `data/biomes/slice.tres`, hazard scenes | Effect density test; Hazard telegraph test | Hook describable by 4 of 5 testers; hazard never damages the Tower outside a biome that explicitly allows it | 15 | L | Sonnet (implementer) |
| P3.4 | Economy: Cores, hopper, drop table, settlement, Meta Wallet | Economy resources and scripts | Overflow hopper test; Settlement test | Cores match expected totals against a scripted run | 14, 08 | M | Sonnet (implementer) |
| P3.5 | Status effect system | `src/combat/status_effect.gd` | Status stacking test | Stacking and duration rules match doc 09/12 without a runaway stack | 09, 12 | M | Sonnet (implementer) |
| P3.6 | Dash, mobility lane scaling, hook degrade floor | `data/upgrades/dash.tres` | Hook degrade test | Passes at maximum dash rank | 03 (consults 17) | S | Sonnet (implementer) |
| P3.7 | Weapon evolutions as Draft cards | Weapon evolution resources | Evolution check | Each evolution changes range, shape, count, or rhythm and is selectable from the Draft | 06 | M | Sonnet (implementer) |
| P3.8 | Enemy roster: Zone Denier, Disruptor, 8 base enemies, 2 affixes, Elite encounter | Enemy and affix resources | Elite affix loop guard test; Elite drop test | No affix loop; every elite drops a Core | 09, 11 | L | Sonnet (implementer) |
| P3.12 | Upgrade pool: player and Tower ranks, dominant pair audit, Banish, reroll per draft | Upgrade resources and audit sheet | Dominant pair audit | No pool accounts for more than the dominance threshold of ranks acquired across the audit's recorded-run minimum | 17, 13 | M | Sonnet (implementer) |

Cells above are copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Acceptance test, Exit criterion, Owner, Size columns). P3.12's Exit criterion is paraphrased to cite the Dominant pair audit's own pass condition rather than restate its percentage and run-count here; see MASTER_SDLC.md > Provisional Values Register > Progression & Upgrades > "Economy dominance measure" for the exact figures. Every other gameplay number a document states is owned by the Provisional Values Register or the cited owner document, not restated here.

## Step-by-step implementation

The step-by-step section below states each task's inputs, owning document, and deliverable paths now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 07's actual lessons exist to inform them.

### P3.3 - Biome hook and hazard

Inputs: P3.2 deliverable (document 15, Biomes, working draft); P3.2b deliverable (document 19, UI/UX, working draft, for hazard telegraph UI conventions).
Deliverable file paths: `data/biomes/slice.tres`, hazard scenes (paths fixed at phase entry).
Owning document: 15 (Biomes); telegraph conventions consult document 19 (UI/UX).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.4 - Economy: Cores, hopper, drop table, settlement, Meta Wallet

Inputs: P3.2 deliverable (document 14, Economy, working draft); P3.2b deliverable (documents 08, Factory System, and 24, Save System, working drafts); P2.10 deliverable (pickups and Scrap, Phase 04).
Deliverable file paths: economy resources and scripts (paths fixed at phase entry).
Owning documents: 14 (Economy), 08 (Factory System).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.5 - Status effect system

Inputs: P3.1 deliverable (document 09, Enemy AI Architecture, stable); P3.2 deliverable (document 12, Difficulty Scaling, working draft, for status effect interaction rules).
Deliverable file paths: `src/combat/status_effect.gd`.
Owning documents: 09 (Enemy AI Architecture), 12 (Difficulty Scaling).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.6 - Dash, mobility lane scaling, hook degrade floor

Inputs: P3.3 deliverable (the biome hook); P3.12 deliverable (the upgrade pool, for dash's place among Tower and player upgrades) - produced earlier in this same phase, per the reordering noted in "Goal," above.
Deliverable file paths: `data/upgrades/dash.tres`.
Owning document: 03 (Player Controller Specification), consulting document 17 (Upgrade Pools).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.7 - Weapon evolutions as Draft cards

Inputs: P3.2 deliverable (document 17, Upgrade Pools, working draft); P3.2b deliverable (document 06, Weapon Framework, working draft); P2.11 deliverable (the upgrade system, Phase 05).
Deliverable file paths: weapon evolution resources (paths fixed at phase entry).
Owning document: 06 (Weapon Framework).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.8 - Enemy roster: Zone Denier, Disruptor, 8 base enemies, 2 affixes, Elite encounter

Inputs: P3.2 deliverable (documents 09 and 14 working drafts); P3.4 deliverable (the Drop Table, produced earlier in this same phase); P3.5 deliverable (status effects, for affixes, produced earlier in this same phase).
Deliverable file paths: enemy and affix resources (paths fixed at phase entry).
Owning documents: 09 (Enemy AI Architecture), 11 (Wave Director).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.12 - Upgrade pool: player and Tower ranks, dominant pair audit, Banish, reroll per draft

Inputs: P3.2 deliverable (documents 17 and 13 working drafts); P2.11 deliverable (the upgrade system, Phase 05).
Deliverable file paths: upgrade resources and an audit sheet (paths fixed at phase entry).
Owning documents: 17 (Upgrade Pools), 13 (Roguelite Progression).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Effect density test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P3.3 telegraph-under-effects result |
| Hazard telegraph test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P3.3 hazard telegraph result |
| Overflow hopper test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.4 overflow-Cores result |
| Settlement test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.4 Run-End Settlement result (excluding the crash clause, closed in Phase 10 per deferred finding P7b) |
| Status stacking test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.5 stacking-rule result |
| Hook degrade test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.6 result at maximum dash rank |
| Evolution check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.7 per-evolution schema result |
| Elite affix loop guard test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P3.8 double-affix result |
| Elite drop test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P3.8 elite-drop result |
| Dominant pair audit | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.12 pool-share result across its recorded-run minimum |

This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An elite affix pair that loops | Two elite affixes can reference or amplify each other's behaviour with no terminating condition, per MASTER_SDLC.md > Elite Variants and the Elite affix loop guard test's own definition | P3.8's two affixes are designed and reviewed together specifically for their interaction, not independently, before either is marked implemented; a scripted double-affix Elite must complete in finite ticks | Elite affix loop guard test |
| Scope creep past the Vertical Slice Scope Freeze | Seven tasks land in one phase, the highest task density in this folder set, raising the chance a deliverable grows past MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice's stated counts (for example more than two elite affixes, more than three weapon evolution steps, more than one always-on hazard) without a recorded freeze amendment | Each task's deliverable is checked against its own Included-in-Slice line before being marked implemented; any excess goes through a Change Log freeze-amendment row, not a silent addition | Reviewer checks deliverable counts (enemy types, affixes, evolution steps, upgrades) against the Freeze list at the review gate |
| Upgrade pool produces a dominant build (MASTER_SDLC.md > Risk Register) | Ten player and eight Tower upgrades land together (P3.12) alongside the dash and evolution tasks that draw from the same pools, and an early imbalance is easy to miss without enough recorded runs | MASTER_SDLC.md > Risk Register's own mitigation - pool audit before every content milestone | Dominant pair audit |
| A dash or other upgrade combination reduces the hook degrade floor below its minimum | P3.6 (dash) and P3.12 (upgrade pool) land in the same phase, and dash's lane-travel-time effect is exactly the kind of movement upgrade the hook degrade floor exists to bound (MASTER_SDLC.md > Biome Edge Cases > "The hook interacts badly with a player upgrade") | Hook degrade test is run at maximum dash rank specifically, per P3.6's own exit criterion, not only at rank 1 | Hook degrade test |
| Performance ceiling during swarm encounters (MASTER_SDLC.md > Risk Register) | This phase brings the roster to its full slice size (eight base enemy types, two affixes, the Elite encounter) for the first time, ahead of the dedicated re-test in Phase 11 (P3.9) | MASTER_SDLC.md > Risk Register's own mitigation - entity caps and pooling enforced from the first prototype - remains in force through this phase | Debug overlay entity-count maxima checked during this phase's own scripted tests, ahead of the formal Swarm performance test re-run in Phase 11 |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P3.3, P3.4, P3.5, P3.6, P3.7, P3.8, P3.12).

Opus runs one critical agent per task (seven critical agents) plus one phase reviewer for Phase 08 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. P3.12 is scheduled first among this phase's tasks in practice (before P3.6 needs its deliverable), even though it is listed last in docs/29's Phase 3 table and last in this phase's own Tasks table above, which is copied from that table's row order. Should this phase's actual execution order be P3.3, P3.4, P3.5, P3.12, P3.6, P3.7, P3.8 (dependency order), or does the Tasks table's row order carry no sequencing meaning at all, only grouping?
   a. Execution order follows dependencies (P3.12 before P3.6); the Tasks table's row order is docs/29's numbering only, not a schedule.
   b. The Tasks table's row order is also the intended execution order, and P3.12 should be re-sequenced within it.
   c. Other (please specify).
2. P3.4's Settlement test exit criterion ("Cores match expected totals against a scripted run") does not mention the crash clause, which deferred finding P7b explicitly ties to P3.14 (Phase 10) instead. Should this phase's Settlement test evidence explicitly exclude the crash clause, or should it attempt a partial crash-clause check now and let Phase 10 only confirm it against the real save file?
   a. This phase's Settlement test evidence excludes the crash clause entirely; Phase 10 owns it alone.
   b. This phase attempts a partial crash-clause check (for example, a scripted process kill with no save file present) in addition to Phase 10's full check.
   c. Other (please specify).

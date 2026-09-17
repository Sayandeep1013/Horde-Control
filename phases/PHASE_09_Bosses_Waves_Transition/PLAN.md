# Phase 09 - Bosses, Wave Sequence, Transition

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.10, P3.11, P3.17

## Goal

Build the Mini-Boss Checkpoint and the Biome Boss, both bound by every Boss Design Requirement; the slice's eight-wave sequence with its two boss slots and the Duel decision (a Duel encounter, or a recorded Change Log waiver row); and the transition cleanup harness exercising the Biome Transition Rule. This is phases/README.md's phase-table row 09 outcome: "Mini-Boss, Biome Boss, the slice wave sequence, and the transition cleanup harness."

## Entry conditions

- Phase 08 deliverable: the biome arena (`data/biomes/slice.tres`, hazard scenes, P3.3), which P3.10 and P3.17 both list as an Input.
- Phase 08 deliverable: the enemy and affix roster (P3.8), which P3.10 lists as an Input the boss may reuse.
- Phase 08 deliverable: the economy resources and scripts (P3.4), which P3.17 lists as an Input, for what the transition must persist.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 08) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 08 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P3.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.10 | Mini-Boss, Biome Boss, boss waves | Boss resources and scenes | Boss edge case test | Every boss edge case in the register is handled or accepted in document 10 | 10 | L | Sonnet (implementer) |
| P3.11 | Slice wave sequence, Duel or recorded waiver, onboarding in biome | Encounter and wave resources | Composition rule test | Every biome has at least one Hunt, Siege, and Split Assault; the Duel/waiver decision is recorded in the Change Log | 11 | M | Sonnet (implementer) |
| P3.17 | Transition cleanup harness | Transition test harness and scripted second arena | Transition cleanup test | Zero survivors in every pool after the scripted transition; a Draft queued by a transition level-up opens before the new arena's first wave | 20 | S | Sonnet (implementer) |

Cells above are copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Acceptance test, Exit criterion, Owner, Size columns); any gameplay number a document states is owned by MASTER_SDLC.md's Provisional Values Register or the cited owner document, not restated here.

## Step-by-step implementation

The step-by-step section below states each task's inputs, owning document, and deliverable paths now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 08's actual lessons exist to inform them.

### P3.10 - Mini-Boss, Biome Boss, boss waves

Inputs: P3.3 deliverable (the biome arena, Phase 08); P3.8 deliverable (the enemy roster the boss may reuse, Phase 08).
Deliverable file paths: boss resources and scenes (paths fixed at phase entry).
Owning document: 10 (Boss Design); deferred finding F20's corrected wording (closed in Phase 07) is the binding text this task's Mini-Boss must follow.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.11 - Slice wave sequence, Duel or recorded waiver, onboarding in biome

Inputs: P3.10 deliverable (the bosses, produced earlier in this same phase).
Deliverable file paths: encounter and wave resources (paths fixed at phase entry).
Owning document: 11 (Wave Director); deferred finding P10 (the encounter-count/Duel-rule contradiction) closes here, and the open author question on the Duel decision (see "Open questions for the author," below) must be answered before this task's wave sequence is finalized.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.17 - Transition cleanup harness

Inputs: P3.3 deliverable (the biome arena, Phase 08); P3.4 deliverable (the economy, for what must persist across a transition, Phase 08).
Deliverable file paths: a transition test harness and a scripted second arena (paths fixed at phase entry).
Owning document: 20 (Technical Architecture); deferred finding P-m9 notes that P3.17's dependency minor remains open as of docs/29's latest round and must be checked here (see "Deferred findings due in this phase," below, and Phase 12's own P-m9 closure).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Boss edge case test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P3.10 result across every boss edge case in MASTER_SDLC.md > Boss Edge Cases, including that the Tower is present and undisplaced in every boss sub-region |
| Composition rule test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P3.11 result, including which branch of the Duel decision was taken and its Change Log row (Duel encounter, or a recorded waiver) |
| Transition cleanup test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.17 result: pooled-container entity counts after the scripted transition, and the queued-Draft timing check |

This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

### The open Duel/Biome Boss question

The author owns one decision this phase cannot make on its own: whether the Biome Boss reuses a Duel-taught mechanic. MASTER_SDLC.md > Encounter Composition Rules and the Composition rule test both require a Duel encounter in the biome's sequence if the Biome Boss reuses a Duel-taught mechanic, and a recorded Change Log waiver row if it does not. Absent an author decision, this PLAN.md defaults to including one Duel encounter (the reading MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice lists as the normal case: "Duel, when the Biome Boss reuses a mechanic"), and records that default explicitly if the author has not overridden it before P3.11's wave sequence is finalized. See "Open questions for the author," below.

## Deferred findings due in this phase

| ID | Finding | Owner doc | Must close by (docs/29) | Status this phase produces |
| --- | --- | --- | --- | --- |
| P10 | The slice's encounter count and the conditional Duel rule read as contradictory outside the freeze amendment | 29 (docs/29_Milestones_and_Roadmap.md) | Before Phase 3 (P3.11 Duel/waiver decision) | Closes here: P3.11 records the Duel/waiver decision in the Change Log, resolving the contradiction the finding names |

Deferred finding F20 (Mini-Boss wording) is due before P3.10, but it is recorded as closing in Phase 07 per that phase's PLAN.md, ahead of this phase's P3.10 implementation; this phase's P3.10 critical agent re-checks P3.10's Mini-Boss against the corrected wording rather than re-closing the finding. Deferred finding P-m9 (P3.17's dependency minor) is only fully due by Phase 12 (P3.18); this phase records what it finds about P3.17's dependency row as evidence for that later closure, without asserting P-m9 itself closes here.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A boss that displaces the Tower out of its own sub-region | Boss Design Requirements bind arena sub-region placement for both bosses (MASTER_SDLC.md > Boss Design Requirements, > Boss Edge Cases); a boss with knockback, terrain-altering, or large-hitbox behaviour could push or place the Tower outside its intended sub-region | Boss movement and hitbox design is reviewed against MASTER_SDLC.md > Boss Design Requirements before a boss is marked implemented; the Tower's presence and position inside its sub-region is checked explicitly, not inferred | Boss edge case test |
| A status effect that survives a biome transition it should not | P3.5's status effect system (Phase 08) and this phase's P3.17 transition cleanup harness are built in different phases; a status applied late in the biome could still be active when the scripted transition runs, and the Transition cleanup test's own pass condition is about pooled entities, not necessarily an already-applied player status | MASTER_SDLC.md > Biome Transition Rule's persistence list is checked explicitly for whether player-carried status effects belong on it; P3.17's harness includes a case where a status effect is active at the moment of transition | Transition cleanup test; a dedicated status-carryover check added to the harness if the persistence list does not already cover it |
| The Mini-Boss wording inconsistency (F20) resurfacing during implementation despite being recorded closed in Phase 07 | F20 closes as a documentation fix in Phase 07 (document 10), but the underlying wording is only tested against real boss-wave suppression behaviour once P3.10 actually implements a Mini-Boss here | Phase 07's critical-agent evidence for F20 (the corrected wording in document 10) is re-read at this phase's entry per loop rule (a), and P3.10's implementation is checked against that corrected wording specifically | Boss edge case test; reviewer cross-check against Phase 07's LEDGER.md F20 entry |
| The Duel-or-waiver decision remains undecided when P3.11 needs it | This is an author decision the phase cannot make on its own (see "The open Duel/Biome Boss question," above) | The question is raised to the author before P3.11's wave sequence is finalized, with the stated default (one Duel encounter) applied only if the author does not respond in time | Composition rule test; a LEDGER.md entry blocking phase closure until the decision or its default is recorded in the Change Log |
| The Tower becomes irrelevant to moment-to-moment play (MASTER_SDLC.md > Risk Register) | Adding bosses and a full eight-wave sequence changes pacing enough that the Siege/Split Assault balance the Risk Register's mitigation relies on could drift | MASTER_SDLC.md > Risk Register's own mitigation - at least one Siege and one Split Assault per biome, every combat wave after T1 contains at least one Tower Seeker or Opportunist - is exactly what the Composition rule test checks | Composition rule test |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P3.10, P3.11, P3.17).

Opus runs one critical agent per task (three critical agents) plus one phase reviewer for Phase 09 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. Does the Biome Boss reuse a Duel-taught mechanic? This determines whether P3.11 includes a Duel encounter or records a Change Log waiver row instead, per MASTER_SDLC.md > Encounter Composition Rules and the Composition rule test.
   a. Yes, the Biome Boss reuses a Duel-taught mechanic; include one Duel encounter in the wave sequence.
   b. No; record a Change Log waiver row and omit the Duel encounter.
   c. Not yet decided; this phase proceeds with one Duel encounter as the stated default until the author overrides it.
2. Deferred finding P-m9 states "P3.17's dependency minor remains open" without describing the minor itself in the text this PLAN.md was drafted from. Should this phase's P3.17 critical agent treat P3.17's currently stated Depends-on row (P3.3, P3.4) as correct and look for a different kind of dependency gap, or is the "minor" specifically about a missing or misordered dependency in that row that needs the author's clarification before it can be assessed?
   a. The stated P3.17 Depends-on row (P3.3, P3.4) is correct; look elsewhere for the minor.
   b. The minor is in the Depends-on row itself; the author will clarify what is missing or misordered.
   c. Other (please specify).

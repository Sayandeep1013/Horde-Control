# Phase 14 - M4.2 Biome 3

Status: Not started; Executes: docs/29 Phase 4, milestone M4.2; Plan task IDs: P4.2.1, P4.2.2, P4.2.3, P4.2.4, P4.2.5, P4.2.6, P4.2.7

## Goal

Deliver the third biome end to end, the same seven-task pattern as biome 2: design (doc 15 addendum), mechanical hook and hazard, enemy types unique to it, Mini-Boss Checkpoint and Biome Boss, eight-wave sequence with two boss slots, production art and audio, and a live transition into it from biome 2. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.2 - Biome 3 (same seven tasks))

## Entry conditions

- Phase 13 (M4.1 Biome 2) is complete: `phases/README.md`'s phase table lists phase 14's dependency as phase 13. Completion here means phase 13 met its bar under loop rule (d) - phase execution score at least 8/10, every task at least 7/10, no open Blocker or Major finding in its `LEDGER.md`, every M4.1 exit test passing - not that a formal Change Log gate row exists, since M4.1 carries no gate line of its own (see PHASE_13's PLAN.md > Exit criteria and acceptance tests).
- P4.2.1's own Depends-on field in docs/29 is P4.1.7 specifically (the live biome-1-to-biome-2 transition), narrower than "all of phase 13" - this document does not start P4.2.1 before P4.1.7's deliverable exists, even if other phase-13 tasks are still under review.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions (the slice gate precondition and the grappling hook's P2.17 parking rule) still apply here; they are not restated in full in this file.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` - including phase 13's, the first biome-production phase and the closest analogue to this one - are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, phase 13 has not yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.2.1 | Design doc 15 biome 3 | Doc 15 biome 3 addendum | none formal | Design reviewed against Biome Requirements with no open contradiction | 15 (Biomes) | M | Sonnet subagent |
| P4.2.2 | Hook & hazard | `data/biomes/biome3.tres`, hazard scenes | Hazard telegraph test | Hook describable by 4 of 5 testers | 15 (Biomes) | L | Sonnet subagent |
| P4.2.3 | Enemy additions | `data/enemies/biome3_*.tres` | Elite affix loop guard test (if elites included) | Every new enemy behaves per an Intent Behaviour Default | 09 (Enemy AI Architecture) | L | Sonnet subagent |
| P4.2.4 | Mini-Boss & Biome Boss | Boss resources and scenes | Boss edge case test | Every boss edge case handled or accepted in document 10 | 10 (Boss Design) | L | Sonnet subagent |
| P4.2.5 | Wave sequence | Wave resources | Composition rule test | At least one Hunt, Siege, and Split Assault present | 11 (Wave Director) | M | Sonnet subagent |
| P4.2.6 | Art & audio | Art and audio assets | Hook description test; Hazard telegraph test; Evolution silhouette test pattern where relevant | Readability Hierarchy holds at biome 3 density | 25 (Asset Pipeline), 26 (Audio Design) | M | Sonnet subagent |
| P4.2.7 | Real biome transition from biome 2 | Live transition path | Transition cleanup test | Zero survivors in every pool; persistence list holds across the transition | 20 (Technical Architecture) | M | Sonnet subagent |

## Step-by-step implementation

### P4.2.1 - Design doc 15 biome 3

- Scope in/out: In: third biome design. Out: implementation.
- Inputs: doc 15 at stable, including the biome 2 addendum from P4.1.1.
- Depends on: P4.1.7.
- Owning document: 15 (Biomes).
- Deliverable: Doc 15 biome 3 addendum.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.2 - Hook & hazard

- Scope in/out: In: biome 3's mechanical hook and hazard, telegraphed, reserved colour. Out: art pass.
- Inputs: P4.2.1's deliverable.
- Depends on: P4.2.1.
- Owning document: 15 (Biomes).
- Deliverable: `data/biomes/biome3.tres`, hazard scenes.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.3 - Enemy additions

- Scope in/out: In: enemy types unique to biome 3. Out: cross-biome roster changes.
- Inputs: P4.2.2's deliverable.
- Depends on: P4.2.2.
- Owning document: 09 (Enemy AI Architecture).
- Deliverable: `data/enemies/biome3_*.tres`.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.4 - Mini-Boss & Biome Boss

- Scope in/out: In: biome 3's Mini-Boss Checkpoint and Biome Boss. Out: a fourth boss pair.
- Inputs: P4.2.3's deliverable.
- Depends on: P4.2.3.
- Owning document: 10 (Boss Design).
- Deliverable: Boss resources and scenes.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.5 - Wave sequence

- Scope in/out: In: biome 3's eight-wave sequence with its two boss slots. Out: cross-biome balance.
- Inputs: P4.2.4's deliverable.
- Depends on: P4.2.4.
- Owning document: 11 (Wave Director).
- Deliverable: Wave resources.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.6 - Art & audio

- Scope in/out: In: biome 3 production art and audio, boss telegraph cues, one music track. Out: further biomes.
- Inputs: P4.2.2 and P4.2.4 deliverables.
- Depends on: P4.2.2, P4.2.4.
- Owning documents: 25 (Asset Pipeline), 26 (Audio Design).
- Deliverable: Art and audio assets.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.2.7 - Real biome transition from biome 2

- Scope in/out: In: a live transition from biome 2 to biome 3. Out: a run-complete screen beyond biome 3.
- Inputs: P4.2.5's deliverable.
- Depends on: P4.2.5.
- Owning document: 20 (Technical Architecture).
- Deliverable: Live transition path.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

docs/29 carries no single "M4.2 gate" line, the same as M4.1 (docs/29 > Phase 4 preamble: only A-tagged tests gate the alpha, beta, and release milestones). M4.2's completion is defined by the seven tasks' Acceptance test and Exit criterion cells above, matched against `phases/README.md` row 14's Gate column: Hazard telegraph test; Elite affix loop guard test; Boss edge case test; Composition rule test; Transition cleanup test.

The master's Definition Of Done For A Milestone (MASTER_SDLC.md, lines 2709-2716) applies in full to this phase:

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared - every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated.
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median >= 60 FPS, 1st-percentile >= 45 FPS) during the heaviest encounter in scope (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Performance rule").
- All acceptance tests tagged for the milestone pass.

This document does not assert that any of the above is met; reviewers and the author decide that, per loop rule (c) and the Gate Approval rule.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Content scope expands past M4.2 (a fourth-biome idea, or an idea for a biome beyond the three-biome run structure, leaks into this phase's tasks) | Two biomes already exist by this point, and it is easy for a designer or agent to start generalizing patterns into a fourth biome while building the third | Every task's Scope in/out cell above is fixed before work starts; anything beyond biome 3 is logged to document 30, since the run currently ends after three biomes (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems") | Critical agent for each P4.2.x task checks delivered files against that task's Scope in/out cell; any biome-4-or-later asset is a Ledger finding |
| Readability degrades further as biome 3 stacks a third layer of hazard, enemy, and boss art on top of biomes 1 and 2 | Each biome so far has passed its own readability check in isolation; nothing yet forces a check across all three biomes' visual vocabularies together | The Readability Hierarchy and effect-density rules gate P4.2.6, and the reserved hazard colour from each biome (docs 15 addenda for biomes 1-3) is diffed for collisions before art is approved (MASTER_SDLC.md > Risk Register > "Readability degrades as content is added") | Hook description test and Hazard telegraph test are run against biome 3's delivered art; a tester who cannot read a hazard at biome 3 density, or who confuses biome 3's hazard colour with an earlier biome's, is a Ledger finding |
| The live transition (P4.2.7) leaves orphaned entities between biome 2 and biome 3, or the biome-1-to-biome-2 persistence list regresses now that a second live transition exists | P4.1.7 proved one live transition; P4.2.7 is a second instance and could expose a persistence-list item that only breaks across two consecutive live transitions (for example, a drone or buff meant to persist across one transition but not two) | The Transition cleanup test is re-run against the real biome 3 content; the Biome Transition Rule's persistence list is checked for behaviour across the full biome-1 to biome-2 to biome-3 chain, not only the most recent hop | Entity count is swept in every pooled container immediately after the transition; a scripted run through both live transitions in sequence is part of this phase's execution, not deferred to P4.5.1's later full-run test |
| The Mini-Boss or Biome Boss reuses a mechanic from biome 1 or biome 2 without a fresh Duel-or-waiver decision for biome 3 | With two biomes' worth of bosses already built, mechanic reuse becomes more likely, and each biome needs its own recorded decision | P4.2.5's wave sequence is checked against the Composition rule test as its own instance for biome 3 (MASTER_SDLC.md > Encounter Composition Rules) | Composition rule test run against biome 3's full sequence; a missing Duel or waiver row is a Ledger finding |
| Documentation drifts from implementation across three biomes' worth of doc 15 addenda, making the document harder to keep internally consistent | Doc 15 now carries three biome addenda plus the base biome rules; a later addendum can silently contradict an earlier one (for example, both claiming the same reserved hazard colour) | Every commit that changes biome 3's implementation also changes doc 15 in the same commit (MASTER_SDLC.md > Risk Register > "Documentation drifts from implementation"); the phase reviewer diffs doc 15's three addenda against each other before closing the phase | Reviewer sweep of doc 15 for contradictions between biome addenda is part of the pre-re-review sweep required by loop rule (d) |
| Biome 3's new enemy types and boss, added on top of two biomes' worth of existing roster, push the swarm past the performance rule at reference-machine density | Entity caps and pooling are enforced structurally, but cumulative content across three biomes has not yet been swarm-tested together | New enemies are added under the existing entity-cap and pooling architecture; the Performance Fallback Ladder step already adopted carries forward unless a new step is recorded (MASTER_SDLC.md > Risk Register > "Per-node physics cost of 300 CharacterBody2D enemies exceeds budget") | The debug overlay's FPS maxima are watched during P4.2.3/P4.2.4/P4.2.7 execution even though the formal Swarm performance re-test is not an M4.2 acceptance test; a drop below the performance rule is logged as a discovered Failure Point |

## Agent assignment

Sonnet subagents implement and write every task above. Opus runs one critical agent per task (P4.2.1 through P4.2.7) plus the phase reviewer for M4.2 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. The same Provisional Values Register gap flagged in PHASE_13's PLAN.md (the biome hook's 40%-of-baseline degrade floor has no Register row) applies again to biome 3's hook at P4.2.2. If the author resolves it at phase 13, does the resolution apply retroactively to this phase without a separate decision? (a) Yes, one resolution covers every biome (b) No, each biome's hook needs its own Register row (c) Other.
2. Biome 3 is the last biome in the current three-biome run structure (MASTER_SDLC.md > Provisional Values Register > Onboarding & Session > "Session arithmetic": "three such biomes ... total a run"). Should P4.2.1's doc 15 addendum say explicitly that biome 3 is the final biome of the run, or is that left to doc 15's own narrative framing? (a) State it explicitly in the addendum (b) Leave it implicit (c) Other.

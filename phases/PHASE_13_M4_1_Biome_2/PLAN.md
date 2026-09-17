# Phase 13 - M4.1 Biome 2

Status: Not started; Executes: docs/29 Phase 4, milestone M4.1; Plan task IDs: P4.1.1, P4.1.2, P4.1.3, P4.1.4, P4.1.5, P4.1.6, P4.1.7

## Goal

Deliver the second biome end to end: its design (doc 15 addendum), its mechanical hook and hazard, the enemy types unique to it, its Mini-Boss Checkpoint and Biome Boss, its eight-wave sequence with two boss slots, its production art and audio, and a live (non-scripted) transition into it from biome 1. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.1 - Biome 2)

## Entry conditions

- Phase 12 (Slice Acceptance & Gate) is complete. phases/README.md's phase table lists phase 13's dependency as phase 12, whose own gate is the vertical slice acceptance row ("Vertical Slice accepted") that only the author writes into the Change Log (MASTER_SDLC.md > Document Control > Gate Approval).
- This document does not assert that phase 12's gate is recorded; that fact is read from `phases/PHASE_12_*/REVIEW.md` and the Status column of `phases/README.md` at phase entry, not restated here in advance.
- The two standing conditions below gate the whole of Phase 4, not only this phase, and are checked again at the entry of every later Phase 4 phase.

## Standing conditions

These two conditions come from docs/29_Milestones_and_Roadmap.md, end of the Phase 4 section, and apply to every phase from PHASE_13 through PHASE_19, not only this one. They are recorded here, in the first Phase 4 phase, per the task brief; later phases' PLAN.md files reference this section rather than restating it.

1. **Nothing in Phase 4 is scheduled until the slice gate is recorded.** The slice gate is the "Vertical Slice accepted" Change Log row, written only by the author under the Gate Approval rule (MASTER_SDLC.md > Document Control > Gate Approval; docs/29 > Phase 3 exit). No task in PHASE_13 through PHASE_19 begins implementation before that row exists. This document does not assert the row exists; it is confirmed by reading phase 12's own records at phase entry.
2. **The grappling hook enters Phase 4 only if it passed its P2.17 spike.** The spike is a bounded evaluation against four criteria, run once, after the prototype playtest (MASTER_SDLC.md > Provisional Values Register > Progression & Upgrades > "Grappling spike"; owning documents 04 and 30). If the spike's recorded verdict is go, grappling-related work may be scheduled inside the relevant Phase 4 milestone under its own task IDs (none of which currently name the grappling hook explicitly in docs/29). If the verdict is no-go, or was never recorded, the grappling hook stays parked in document 30 (Future Ideas) for the life of this map - no task in PHASE_13 through PHASE_19 may reintroduce it outside document 30 without a new Review Decision Log row recording that decision. This document does not assert which verdict was recorded; that is read from the P2.17 task's own record at phase entry.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase - recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved - are written into this section before implementation starts. As of this writing, phases 00 through 12 have not yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.1.1 | Design doc 15 biome 2 | Doc 15 biome 2 addendum | none formal | Design reviewed against Biome Requirements with no open contradiction | 15 (Biomes) | M | Sonnet subagent |
| P4.1.2 | Hook & hazard | `data/biomes/biome2.tres`, hazard scenes | Hazard telegraph test | Hook describable by 4 of 5 testers | 15 (Biomes) | L | Sonnet subagent |
| P4.1.3 | Enemy additions | `data/enemies/biome2_*.tres` | Elite affix loop guard test (if elites included) | Every new enemy behaves per an Intent Behaviour Default | 09 (Enemy AI Architecture) | L | Sonnet subagent |
| P4.1.4 | Mini-Boss & Biome Boss | Boss resources and scenes | Boss edge case test | Every boss edge case handled or accepted in document 10 | 10 (Boss Design) | L | Sonnet subagent |
| P4.1.5 | Wave sequence | Wave resources | Composition rule test | At least one Hunt, Siege, and Split Assault present | 11 (Wave Director) | M | Sonnet subagent |
| P4.1.6 | Art & audio | Art and audio assets | Hook description test; Hazard telegraph test; Evolution silhouette test pattern where relevant | Readability Hierarchy holds at biome 2 density | 25 (Asset Pipeline), 26 (Audio Design) | M | Sonnet subagent |
| P4.1.7 | Real biome transition from biome 1 | Live transition path | Transition cleanup test | Zero survivors in every pool; persistence list holds across the transition | 20 (Technical Architecture) | M | Sonnet subagent |

## Step-by-step implementation

### P4.1.1 - Design doc 15 biome 2

- Scope in/out: In: second biome design (hook concept, hazard concept, arena shape). Out: implementation.
- Inputs: doc 15 at stable; the Biome Requirements list (MASTER_SDLC.md > Biomes > Biome Requirements).
- Depends on: P3.18 (slice acceptance pass, per docs/29).
- Owning document: 15 (Biomes).
- Deliverable: Doc 15 biome 2 addendum.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.2 - Hook & hazard

- Scope in/out: In: biome 2's mechanical hook and hazard, telegraphed, reserved colour. Out: art pass.
- Inputs: P4.1.1's deliverable (the doc 15 addendum).
- Depends on: P4.1.1.
- Owning document: 15 (Biomes).
- Deliverable: `data/biomes/biome2.tres`, hazard scenes.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.3 - Enemy additions

- Scope in/out: In: enemy types unique to biome 2. Out: cross-biome roster changes.
- Inputs: P4.1.2's deliverable (biome identity).
- Depends on: P4.1.2.
- Owning document: 09 (Enemy AI Architecture).
- Deliverable: `data/enemies/biome2_*.tres`.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.4 - Mini-Boss & Biome Boss

- Scope in/out: In: biome 2's Mini-Boss Checkpoint and Biome Boss. Out: a third boss pair.
- Inputs: P4.1.3's deliverable (the roster the boss may reuse).
- Depends on: P4.1.3.
- Owning document: 10 (Boss Design).
- Deliverable: Boss resources and scenes.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.5 - Wave sequence

- Scope in/out: In: biome 2's eight-wave sequence with its two boss slots. Out: onboarding (biome 1 only).
- Inputs: P4.1.4's deliverable (bosses).
- Depends on: P4.1.4.
- Owning document: 11 (Wave Director).
- Deliverable: Wave resources.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.6 - Art & audio

- Scope in/out: In: biome 2 production art and audio, boss telegraph cues, one music track. Out: biome 3 assets.
- Inputs: P4.1.2 and P4.1.4 deliverables.
- Depends on: P4.1.2, P4.1.4.
- Owning documents: 25 (Asset Pipeline), 26 (Audio Design).
- Deliverable: Art and audio assets.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.1.7 - Real biome transition from biome 1

- Scope in/out: In: a live (non-scripted) transition from biome 1 to biome 2 using the Biome Transition Rule. Out: transition to biome 3.
- Inputs: P4.1.5's deliverable (wave sequence); P3.17's deliverable (the transition cleanup harness).
- Depends on: P4.1.5.
- Owning document: 20 (Technical Architecture).
- Deliverable: Live transition path.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

docs/29 does not carry a single "M4.1 gate" line the way it does for M4.5, M4.6, and M4.7; its Phase 4 preamble states that only "A-tagged tests ... gate the alpha, beta, and release milestones" (docs/29 > Phase 4). M4.1's completion is therefore defined by the seven tasks' own Acceptance test and Exit criterion cells in the Tasks table above, matched against `phases/README.md`'s row 13 Gate column: Hazard telegraph test; Elite affix loop guard test; Boss edge case test; Composition rule test; Transition cleanup test.

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
| Content scope expands past M4.1 (biome-3-or-later material leaks into this phase's tasks) | Biome design work naturally generates ideas beyond the biome in front of it; a task drifts past its own Scope in/out cell | Every task's Scope in/out cell above is fixed before work starts; anything beyond biome 2 is logged to document 30 instead of built here (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems") | Critical agent for each P4.1.x task checks delivered files against that task's Scope in/out cell; any biome-3-or-later asset found in a P4.1.x deliverable is a Ledger finding |
| Readability degrades as biome 2's hazard, enemies, and boss art stack on top of biome 1's carried-over elements | Each new layer is reviewed against its own acceptance test in isolation, not against the combined on-screen density it will share with biome 1 | The Readability Hierarchy and effect-density rules gate P4.1.6 (MASTER_SDLC.md > Risk Register > "Readability degrades as content is added"; owning document 27) | Hook description test and Hazard telegraph test are run against biome 2's delivered art, not only against isolated asset review; a tester who cannot read a hazard at biome 2 density is a Ledger finding |
| The live transition (P4.1.7) leaves orphaned entities between biome 1 and biome 2 | P4.1.7 is the first non-scripted transition; the P3.17 harness proved the mechanism only on a scripted placeholder arena, not on biome 2's real content | The Transition cleanup test is re-run against the real biome 2 content, and the Biome Transition Rule's persistence list is checked item by item, not assumed from the harness result | Entity count is swept in every pooled container immediately after the transition; any nonzero count is a Ledger finding |
| The Mini-Boss or Biome Boss reuses a mechanic from biome 1 without the Duel-or-waiver decision being re-checked for biome 2 | The Composition rule test's Duel clause was satisfied once for the slice biome; biome 2 is a separate composition and needs its own instance of the check | P4.1.5's wave sequence is checked against the Composition rule test as its own instance for biome 2, not assumed to inherit biome 1's recorded waiver (MASTER_SDLC.md > Encounter Composition Rules) | Composition rule test run against biome 2's full sequence; a missing Duel or waiver row is a Ledger finding |
| A biome-2 enemy or boss reintroduces an Enemy Behaviour or Boss edge case already closed for biome 1, because new content was built by copying biome 1's patterns rather than re-deriving them from the register | New content is easy to build by analogy to what already works, skipping the register check | P4.1.3 and P4.1.4 are checked directly against the Enemy Behaviour and Boss Edge Cases tables (MASTER_SDLC.md > Edge Cases and Failure States; Boss Structure > Boss Edge Cases), not only against biome 1's implementation | Critical agent for P4.1.3/P4.1.4 walks the relevant edge-case rows against the new resources; any unhandled or unaccepted row is a Ledger finding |
| Biome 2's new enemy types and boss push the swarm past the performance rule at reference-machine density | Entity caps and pooling are enforced structurally, but a new enemy archetype's per-node cost is unproven until it exists | New enemies are added under the existing entity-cap and pooling architecture (MASTER_SDLC.md > Risk Register > "Per-node physics cost of 300 CharacterBody2D enemies exceeds budget"); the Performance Fallback Ladder step already adopted for the slice carries forward unless a new step is recorded | The debug overlay's FPS maxima are watched during P4.1.3/P4.1.4/P4.1.7 execution even though the formal Swarm performance re-test is not an M4.1 acceptance test; a drop below the performance rule is logged as a discovered Failure Point |

## Agent assignment

Sonnet subagents implement and write every task above. Opus runs one critical agent per task (P4.1.1 through P4.1.7) plus the phase reviewer for M4.1 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. The biome hook's 40%-of-baseline degrade floor is stated as a "Provisional Default" in MASTER_SDLC.md > Biomes > Biome Edge Cases and restated in the Acceptance Test Matrix's Hook degrade test, but it does not appear as its own row in the Provisional Values Register, which the Provisional Defaults Policy calls "the only complete list of gameplay numbers in this document." Should a Provisional Values Register row be added for it before P4.1.2 builds biome 2's hook? (a) Add a Biomes row to the Register now (b) Leave it in Biome Edge Cases only and treat that as the exception (c) Author will decide separately, unblock P4.1.2 without waiting.
2. P4.1.1's Scope in/out text ("hook concept, hazard concept, arena shape") names three of the six items the Biome Requirements list says a biome must define before it enters production (hook, hazard and its telegraph, enemy pool as target intents, boss pool, progression position and difficulty band, readability palette), while P4.1.1's own exit criterion asks for a full review against Biome Requirements. Should the doc 15 biome 2 addendum from P4.1.1 cover all six items, with enemy pool and boss pool named only as target intents pending P4.1.3/P4.1.4, or is partial coverage at P4.1.1 intentional? (a) Addendum covers all six at P4.1.1, naming P4.1.3/P4.1.4 content by intent only (b) Addendum stays scoped to hook/hazard/arena shape and the full Biome Requirements review happens only once P4.1.4 closes (c) Other.

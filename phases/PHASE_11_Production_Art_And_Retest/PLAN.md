# Phase 11 - Production Art, Audio, Re-test

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.16, P3.9

## Goal

Build slice-density production art and audio (biome tileset and hazard art, sprites and animations for the roster and both elite affix markers, the Mini-Boss, the Biome Boss, Tower evolution art for all four stages, an SFX set, boss telegraph cues, one music track), then re-run the swarm stress test at slice density on the heaviest encounter, now that the art and full roster make that measurement meaningful. This is phases/README.md's phase-table row 11 outcome: "Slice-density art and audio, then the performance re-test they enable."

P3.9 sits in this phase, after P3.16, rather than earlier, because docs/29 makes it depend on P3.3, P3.8, P3.10, and P3.16: the swarm re-test needs the full biome arena, the full enemy roster, both bosses, and production-weight art all present at once to be a meaningful measurement of slice-density performance, not just placeholder-density performance.

## Entry conditions

- Phase 08 deliverables: the biome arena (P3.3) and the full enemy and affix roster (P3.8), which both P3.16 and P3.9 list as Inputs.
- Phase 09 deliverable: the bosses (P3.10), which both P3.16 and P3.9 list as Inputs.
- Phase 07 deliverable: documents 25 (Asset Pipeline) and 26 (Audio Design) at a working draft (P3.2b), which P3.16 lists as an Input.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 10) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 10 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P3.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.16 | Production art & audio | Biome art, enemy sprites/animations, stage sprites and transitions, SFX set, boss cue set, music track | Evolution silhouette test | 4 of 5 testers identify the Tower's stage from silhouette | 07, 25, 26 | XL | Sonnet (implementer) |
| P3.9 | Swarm re-test at slice density | Recorded result in document 20 | Swarm performance test | Performance rule holds with all eight enemy types and the Biome Boss active, or the next Performance Fallback Ladder step is adopted | 20 | M | Sonnet (implementer) |

Cells above are copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Acceptance test, Exit criterion, Owner, Size columns); any gameplay number a document states (frame-rate thresholds, entity caps) is owned by MASTER_SDLC.md's Provisional Values Register > Technical Caps & Performance or the cited owner document, not restated here.

## Step-by-step implementation

The step-by-step section below states each task's inputs, owning document, and deliverable paths now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 10's actual lessons exist to inform them.

### P3.16 - Production art & audio

Inputs: P3.3 deliverable (the biome, Phase 08); P3.8 deliverable (the roster, Phase 08); P3.10 deliverable (the bosses, Phase 09); P3.2b deliverable (documents 25 and 26 working drafts, Phase 07).
Deliverable file paths: biome art, enemy sprites and animations, Tower stage sprites and transitions, an SFX set, a boss cue set, one music track (paths fixed at phase entry).
Owning documents: 07 (Tower System), 25 (Asset Pipeline), 26 (Audio Design).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.9 - Swarm re-test at slice density

Inputs: P3.3 deliverable (the biome arena, Phase 08); P3.8 deliverable (the full roster, Phase 08); P3.10 deliverable (the bosses, Phase 09); P3.16 deliverable (production art, for representative load, produced earlier in this same phase).
Deliverable file paths: a recorded result written into `docs/20_Technical_Architecture.md`.
Owning document: 20 (Technical Architecture); this task steps through the Performance Fallback Ladder again at slice density, per the ladder's own note that "Phase 3 re-runs the ladder at slice density."
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Evolution silhouette test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P3.16 result, internal tester this phase; external tester probe deferred to P3.18 |
| Swarm performance test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.9 result at slice density, heaviest encounter including the Biome Boss, and the adopted Performance Fallback Ladder step if the base case does not hold |

Per the Acceptance Test Matrix's own instrument column, Evolution silhouette test carries an internal-tester result at P3.16 (this phase) and an external-tester probe at P3.18 (Phase 12); this phase's evidence is the internal-tester half only. This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An art pass that breaks the Readability Hierarchy at slice density | P3.16 is the first task to bring full production art (biome tileset, eight enemy sprites, two affix markers, both bosses, four Tower evolution stages, boss telegraph cues) onto the screen together, and MASTER_SDLC.md > Readability Hierarchy's draw-order and effect-density rules were only proven against placeholder art before now | Each art asset is checked against MASTER_SDLC.md > Readability Hierarchy's draw-order rule and reserved hazard colour rule as it lands, not only at the end of the task | Evolution silhouette test; a readability pass reusing the Effect density test's own high-intensity-effect threshold |
| The swarm re-test failing at slice density after passing at prototype density, which MASTER_SDLC.md > Performance Fallback Ladder anticipates | P3.9 is the first swarm measurement with the full eight-enemy-type roster, two affixes, and the Biome Boss all active at once, and production art (P3.16) typically costs more per frame than the placeholder art the Phase 02 swarm test used | MASTER_SDLC.md > Performance Fallback Ladder's own note - "Phase 3 re-runs the ladder at slice density" - is exactly this task; the ladder's ordered steps are stepped through again from the base case, adopting only the first step that passes | Swarm performance test |
| Audio becomes an unreadable wall of noise (MASTER_SDLC.md > Risk Register) | P3.16 adds an SFX set and boss telegraph cues on top of the six-bus layout Phase 02 built for a much smaller placeholder sound set | MASTER_SDLC.md > Risk Register's own mitigation - strict Audio Bus hierarchy and dynamic ducking enforced - and MASTER_SDLC.md > Audio's retrigger-limit and priority-voice rules apply to every new cue as it is added | Audio clarity test (boss telegraphs), fully exercised with an external tester probe at P3.18, checked by internal testers here |
| P3.16's Evolution silhouette test result reflects internal testers only, not yet the fresh external testers the VS tag ultimately requires | The Acceptance Test Matrix's own instrument column for this test reads "Internal tester at P3.16; external tester probe at P3.18," so a pass recorded in this phase is not the test's full instrument set | This phase's LEDGER.md and REVIEW.md record the result explicitly as internal-tester evidence, not a final pass, leaving external-tester confirmation to Phase 12 | Reviewer checks the recorded evidence names internal testers, not external testers, for this phase's result |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P3.16, P3.9).

Opus runs one critical agent per task (two critical agents) plus one phase reviewer for Phase 11 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. If P3.9's swarm re-test does not hold at the base case and a Performance Fallback Ladder step must be adopted (for example step 1's magnet-raycast and merge-radius change, or step 2's off-screen update reduction), does adopting that step at this phase require its own Change Log row beyond what MASTER_SDLC.md > Performance Fallback Ladder already states ("document 20 records which step was needed"), or does the existing ladder note satisfy the master's change-recording rule on its own?
   a. The ladder's own "document 20 records which step was needed" note is sufficient; no separate Change Log row is required.
   b. A separate Change Log row is required whenever a fallback step is adopted, in addition to the document 20 record.
   c. Other (please specify).
2. P3.16 is sized XL and folds together the biome, roster, boss, Tower-evolution, SFX, and music deliverables docs/29's own Deferred Review Finding P12 says P3.16 previously lacked explicit scope for. Should this phase treat P12's "final art list" re-verification as part of P3.16's own exit criterion, or does that re-verification belong only to Phase 12 (P3.18), where P12 is listed as due?
   a. P3.16 re-verifies against the final art list itself as part of this phase's exit criterion; P12 need only re-confirm at P3.18.
   b. P12's re-verification against the final art list happens only at P3.18; this phase does not check it.
   c. Other (please specify).

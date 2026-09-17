# Phase 12 - Slice Acceptance & Gate

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.18

## Goal

Run the vertical slice's acceptance pass: every VS-tagged test, five fresh external testers, and the Slice Exit Criteria, producing the vertical slice verdict. This is phases/README.md's phase-table row 12 outcome: "The vertical slice verdict." Per docs/29, "Phase 3 exit: Slice Exit Criteria pass and are recorded per the Gate Approval rule; Change Log row 'Vertical Slice accepted.'" This document does not assert that verdict; it plans the evidence the author reads to reach it.

## Entry conditions

Every deliverable from phases 07 through 11 (P3.1 through P3.17, including P3.2b), since P3.18's own Inputs field in docs/29 is "P3.1 through P3.17 deliverables (incl. P3.2b)." In particular:

- Phase 07: documents 03, 05, 07, 09, 11, 20 stable; documents 10, 12, 13, 14, 15, 17, 18, 04, 06, 08, 16, 19, 24, 25, 26, 27 at a working draft; deferred findings P6 and F20 closed; P1 at its working tier.
- Phase 08: the biome hook and hazard, the full economy, status effects, dash and the hook degrade floor, weapon evolutions, the enemy roster, and the upgrade pools.
- Phase 09: the Mini-Boss, the Biome Boss, the slice wave sequence with its Duel or waiver decision, and the transition cleanup harness; deferred finding P10 closed.
- Phase 10: the Hub, the save profile, onboarding compression, controller parity, and the reduced-effects setting, with internal-tester evidence for the VS tests that also carry an external-tester probe here; deferred finding P7b closed.
- Phase 11: slice-density production art and audio, and the swarm re-test at slice density, with internal-tester evidence for the Evolution silhouette test's external-tester probe here.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 11) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 11 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before P3.18 work begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.18 | Slice acceptance pass and external playtest | Report in document 29 | See "VS-tagged tests this phase runs," below | Slice Exit Criteria 1 to 10 pass and are recorded per the Gate Approval rule | 29 | M | Sonnet (implementer) |

The cell above is copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Exit criterion, Owner, Size columns); the Acceptance test column is expanded into its own subsection below rather than crammed into the table, because docs/29's own P3.18 row lists twenty-two tests plus a discrepancy this PLAN.md must surface rather than silently complete (see "VS-tagged tests this phase runs" and "Open questions for the author").

## Step-by-step implementation

The step-by-step section below states this task's inputs, owning document, and deliverable path now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 11's actual lessons exist to inform them.

### P3.18 - Slice acceptance pass and external playtest

Inputs: P3.1 through P3.17 deliverables, including P3.2b (every earlier Phase 3 task, spanning phases 07 through 11); five fresh external testers, distinct from the five testers used at P2.16.
Deliverable file paths: a report written into `docs/29_Milestones_and_Roadmap.md`.
Owning document: 29 (Milestones & Roadmap, this document); deferred findings P11, P12, P13, and P-m9 close here (see "Deferred findings due in this phase," below).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## VS-tagged tests this phase runs

Copied from docs/29's own P3.18 Acceptance test column: Investment split test; Channel understanding test; Composition rule test; Elite affix loop guard test; Elite drop test; Boss edge case test; Transition cleanup test; Overflow hopper test; Settlement test; Save atomicity test; Meta persistence test; Status stacking test; Hook description test; Hazard telegraph test; Evolution silhouette test; Evolution check; Hook degrade test; Reduced effects test; Controller-only run test; Onboarding compression test; Dominant pair audit; Audio clarity test (boss telegraphs); Swarm performance test (slice density).

This phase also runs three further VS-tagged tests whose Acceptance Test Matrix "First task" column names P3.18, but which docs/29's own P3.18 row does not list: Failed-run progress test; Upgrade dominance perception test; Encounter fairness test. These three are Core Tension Tests, tagged VS, with no earlier task named anywhere in the Acceptance Test Matrix as their first task. Since Slice Exit Criterion 5 requires "all mandatory acceptance tests" to pass and the Acceptance Test Matrix's own intro defines VS as "mandatory for the vertical slice," this PLAN.md runs all three here rather than leave them unrun. This is a contradiction between MASTER_SDLC.md > Acceptance Test Matrix and docs/29's P3.18 row that this PLAN.md does not resolve; see "Open questions for the author."

## Exit criteria and acceptance tests

Every test named in "VS-tagged tests this phase runs," above, is checked at MASTER_SDLC.md > Acceptance Test Matrix's own pass condition and instrument, with five fresh external testers where the test's instrument calls for a tester probe. Beyond the individual tests, the phase's own exit criterion is docs/29's stated one: Slice Exit Criteria 1 to 10 (MASTER_SDLC.md > Slice Exit Criteria) pass and are recorded per the Gate Approval rule (MASTER_SDLC.md > Document Control > Gate Approval).

This document does not assert that the gate is passed, satisfied, met, or ready. The slice gate row ("Vertical Slice accepted") is written into the Change Log only by the author; an agent working this phase may propose the gate row's text as a draft, but never writes it into the Change Log itself, per MASTER_SDLC.md > Document Control > Gate Approval and this task's own governing instruction.

## Deferred findings due in this phase

| ID | Finding | Owner doc | Must close by (docs/29) | Status this phase produces |
| --- | --- | --- | --- | --- |
| P11 | P3.9 previously ran before bosses and art existed; P3.18 was missing boss-audio and slice-swarm tests. This round adds P3.3/P3.10/P3.16 as explicit P3.9 dependencies and adds the Audio clarity and Swarm performance tests to P3.18; re-verify no further gap remains | 29 | By Phase 3 exit (P3.18) | Closes here: this phase re-verifies P3.9's dependency chain (satisfied by Phase 11's ordering) and confirms Audio clarity test and Swarm performance test both run in this phase's test list |
| P12 | The slice had no task carrying its art scope. This round expands P3.16's scope and raises it to size XL; re-verify completeness against the final art list | 29 | By Phase 3 exit (P3.18) | Closes here: this phase re-verifies P3.16's delivered art (Phase 11) against the full list in MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice |
| P13 | Tester-probe pass conditions remain embedded inside Phase 3-4 build-task exit criteria (P3.3, P3.13, P3.16, and the art/audio pattern reused later) rather than moved to the dedicated external-playtest tasks | 29 | By Phase 3 exit (P3.18) for slice tasks; by Beta gate (P4.6.5) for production tasks | Closes here for slice tasks: this phase confirms the external-tester half of every test P3.3, P3.13, and P3.16 left to this phase (Hook description test, Slice Exit Criterion 4, Evolution silhouette test's external half) is actually run here, not silently skipped because an internal-tester result already exists upstream |
| P-m9 | Phase 3 dependency minors: P3.5 and P3.6 were missing dependencies (fixed in an earlier round); P3.17's dependency minor remains open | 29 | Before Phase 3 exit (P3.18) | Closes here: this phase's review confirms P3.17's dependency row (checked in Phase 09) either was corrected there or is corrected now, before this phase's own exit |

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The slice needing new scope to become fun (MASTER_SDLC.md > Slice Exit Criteria closing note) | If playtesters report the loop is not fun, the fastest-looking fix is adding a new system, which the Scope Freeze exists to prevent this late | MASTER_SDLC.md > Slice Exit Criteria's own closing text - "If the slice requires new scope to become fun, that is a design warning. The core loop should become fun through selection, pressure, and readability, not through adding more systems" - is the standing rule; any new-scope proposal from this phase's findings goes to the author as a freeze-amendment question, not a silent addition | Reviewer checks any LEDGER.md finding that proposes new scope is flagged as a design warning, not an approved fix |
| Three VS-tagged tests whose Acceptance Test Matrix "First task" is P3.18 are not named in docs/29's own P3.18 acceptance-test list, so they risk never being run at all | See "VS-tagged tests this phase runs," above; this is a contradiction between MASTER_SDLC.md > Acceptance Test Matrix and docs/29's P3.18 row that this PLAN.md does not resolve on its own authority | This phase's task list runs Failed-run progress test, Upgrade dominance perception test, and Encounter fairness test anyway, since they are tagged VS and Slice Exit Criterion 5 requires all mandatory acceptance tests to pass | LEDGER.md carries a row for each of the three tests until run and recorded |
| Deferred findings P11, P12, P13, or P-m9 remain open when this phase's review gate runs | All four are due to close by P3.18 per MASTER_SDLC.md's Deferred Review Findings table (docs/29), and each depends on evidence from earlier phases | Each finding is checked individually against its own text in "Deferred findings due in this phase," above, not assumed closed because the phase otherwise passes | LEDGER.md rows for P11, P12, P13, and P-m9, each closed only on direct evidence |
| The five fresh external testers are not actually fresh | MASTER_SDLC.md > Acceptance Test Matrix's intro specifically distinguishes P3.18's testers as "5 fresh external testers," separate from P2.16's five; reusing the same pool would bias every tester-probe result in this phase | Tester recruitment for this phase is checked against the P2.16 roster before scheduling | Reviewer checks the recorded tester roster for overlap with P2.16's |
| An agent writes the slice gate row into the Change Log itself | MASTER_SDLC.md > Document Control > Gate Approval and this task's own governing instruction both restrict who may write a gate row; drafting the row's text and committing it to the Change Log are easy to conflate under time pressure | Agents working this phase may propose the gate row's text as a draft for the author; the Change Log write itself is the author's action, never an agent's | Reviewer checks the Change Log's actual edit history for the gate row's author |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent runs P3.18's scripted and tester-probe evidence-gathering.

Opus runs one critical agent for P3.18 plus one phase reviewer for Phase 12 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts P3.18 produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c). Neither the critical agent nor the phase reviewer may write the slice gate row into the Change Log; that action belongs to the author alone.

## Open questions for the author

1. docs/29's P3.18 row names twenty-two acceptance tests, but the Acceptance Test Matrix names three further VS-tagged Core Tension Tests (Failed-run progress test, Upgrade dominance perception test, Encounter fairness test) whose "First task" column also reads P3.18. This PLAN.md runs all three anyway, since Slice Exit Criterion 5 requires all mandatory acceptance tests to pass. Which is correct?
   a. docs/29's P3.18 row is incomplete; it should be amended to add the three missing tests.
   b. The Acceptance Test Matrix's "First task" column is wrong for these three; they belong to a different task or are not mandatory for the slice.
   c. The three tests are intentionally out of scope for the slice gate, and their VS tag should be reconsidered.
   d. Other (please specify).
2. Per "Deferred findings due in this phase," this phase's evidence for closing P11, P12, and P13 largely consists of re-verifying work already done in earlier phases, rather than new work of its own. Should this phase's review treat those three findings as closed once the re-verification confirms no gap, or does closing a deferred finding always require the author's own sign-off beyond a passing reviewer score, given these were originally raised as review findings rather than acceptance tests?
   a. A passing reviewer re-verification is sufficient to close P11, P12, and P13.
   b. The author must sign off on each of P11, P12, and P13 individually, beyond the reviewer's re-verification.
   c. Other (please specify).

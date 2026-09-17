# Phase 18 - M4.6 Beta Gate

Status: Not started; Executes: docs/29 Phase 4, milestone M4.6; Plan task IDs: P4.6.0, P4.6.1, P4.6.2, P4.6.3, P4.6.4, P4.6.5

## Goal

Decide the minimum-spec reference machine, the launch languages, and the target storefronts; then run full localization, an accessibility pass, the cloud-save go/no-go, the minimum-spec performance test, and a 20-tester external playtest covering every biome. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.6 - Beta gate)

## Entry conditions

- Phase 17 (M4.5 Alpha Gate) is complete under the phase bar (loop rule d); `phases/README.md`'s phase table lists phase 17 as phase 18's dependency.
- Every task in this phase depends on the Alpha gate directly (docs/29's Depends-on field for P4.6.0 through P4.6.4 all name "Alpha gate"), not merely on phase 17's own review bar. This document does not start any P4.6.x task before the Alpha gate's "Alpha accepted" Change Log row exists, and does not treat phase 17's review score as a substitute for that author-written row.
- P4.6.0 is the load-bearing task of this phase: P4.6.1 and P4.6.4 both list P4.6.0 as an explicit additional dependency beyond the Alpha gate, and P4.7.1 in Phase 19 (a later phase) also depends on P4.6.0's storefronts decision. This document schedules P4.6.0 first within this phase's execution, before P4.6.1 or P4.6.4 begin implementation, even though the Tasks table lists all six by ID order.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions still apply; they are not restated here.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, no Phase 4 phase has yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.6.0 | Decide minimum-spec machine, launch languages, and storefronts | Register rows (Provisional Values Register: minimum-spec machine, launch languages, storefronts) | none formal | Decision recorded per the Gate Approval rule and the Register rows exist | 20 (Technical Architecture; consults 19, 23) | S | Author decision; Sonnet subagent records the resulting Register rows |
| P4.6.1 | Localization test | Localized text tables | Localization test | Every localized string fits its container without truncation beyond the documented ellipsis rule | 19 (UI/UX) | L | Sonnet subagent |
| P4.6.2 | Accessibility pass | Accessibility checklist and fixes | none tagged directly; verified against the Visual Edge Cases colour-only-distinction rule | No mandatory information is conveyed by colour alone | 19 (UI/UX), 27 (VFX & Game Feel) | M | Sonnet subagent |
| P4.6.3 | Cloud save decision | Change Log row recording the decision | none formal | Decision recorded per the Gate Approval rule | 24 (Save System) | S | Author decision; Sonnet subagent records the Change Log row |
| P4.6.4 | Minimum-spec performance test | Minimum-spec measurement report | Minimum-spec performance test (against the Register row P4.6.0 fills) | Median >= 60 FPS and 1st-percentile >= 45 FPS on minimum spec during the heaviest encounter | 20 (Technical Architecture) | M | Sonnet subagent |
| P4.6.5 | 20-tester playtest | Playtest report in document 29 | Reuses the P-tagged and VS-tagged tester tests at full-game scale | No criterion regresses below its prototype/slice pass threshold; passes at 16 of 20 testers per criterion | 29 (Milestones & Roadmap) | M | Sonnet subagent administers and records; 20 external testers execute the probe |

## Step-by-step implementation

### P4.6.0 - Decide minimum-spec machine, launch languages, and storefronts

- Scope in/out: In: the designer's decision on the minimum-spec reference machine, the set of launch languages, and the target storefronts. Out: implementation of any of the three.
- Inputs: the Alpha gate.
- Depends on: Alpha gate.
- Owning document: 20 (Technical Architecture; consults 19, 23).
- Deliverable: Provisional Values Register rows for minimum-spec machine, launch languages, and storefronts. None of these three rows currently exist in MASTER_SDLC.md's Provisional Values Register (only "Reference machine" exists there today, under Engine & Platform); this task creates them.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.6.1 - Localization test

- Scope in/out: In: full localization pass beyond pseudo-localization. Out: voice-over.
- Inputs: P3.15's deliverable (the pseudo-localization pass); P4.6.0's deliverable (the launch-languages decision).
- Depends on: Alpha gate, P4.6.0.
- Owning document: 19 (UI/UX).
- Deliverable: Localized text tables.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.6.2 - Accessibility pass

- Scope in/out: In: colourblind-safe palette check, remappable input, reduced-effects coverage beyond the slice. Out: full assistive-tech support.
- Inputs: P3.15's deliverable (the reduced-effects setting).
- Depends on: Alpha gate.
- Owning documents: 19 (UI/UX), 27 (VFX & Game Feel).
- Deliverable: Accessibility checklist and fixes.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.6.3 - Cloud save decision

- Scope in/out: In: the designer's go/no-go on cloud saves for this platform release. Out: implementation if "no."
- Inputs: P3.14's deliverable (the local save profile).
- Depends on: Alpha gate.
- Owning document: 24 (Save System).
- Deliverable: Change Log row recording the decision.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.6.4 - Minimum-spec performance test

- Scope in/out: In: the performance rule measured on a documented minimum-spec machine, not the reference machine. Out: reference-machine re-testing.
- Inputs: P3.9's deliverable (the slice-density swarm result); P4.6.0's deliverable (the minimum-spec machine decision, Register row).
- Depends on: Alpha gate, P4.6.0.
- Owning document: 20 (Technical Architecture).
- Deliverable: Minimum-spec measurement report.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.6.5 - 20-tester playtest

- Scope in/out: In: a 20-tester external playtest covering every biome. Out: fixes.
- Inputs: P4.6.1 through P4.6.4 deliverables.
- Depends on: P4.6.1, P4.6.2, P4.6.3, P4.6.4.
- Owning document: 29 (Milestones & Roadmap).
- Deliverable: Playtest report in document 29.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

Milestone gate line, quoted from docs/29 (this document does not assert the gate is recorded; only the author's Change Log row does that): "Beta gate: P4.6.0 to P4.6.5 pass; Change Log row 'Beta accepted' per the Gate Approval rule."

The master's Definition Of Done For A Milestone (MASTER_SDLC.md, lines 2709-2716) applies in full to this phase:

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared - every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated.
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median >= 60 FPS, 1st-percentile >= 45 FPS) during the heaviest encounter in scope - this phase is the first to measure it on minimum spec rather than the reference machine, per P4.6.4 (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Performance rule").
- All acceptance tests tagged for the milestone pass.

This document does not assert that any of the above is met; reviewers and the author decide that, per loop rule (c) and the Gate Approval rule.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| P4.6.0's decisions arrive too late for the tasks that depend on them | P4.6.0 is an author decision task, not a scripted or agent-driven one; if the decision is delayed, P4.6.1 (needs launch languages) and P4.6.4 (needs the minimum-spec machine) cannot start, and P4.7.1 in Phase 19 (needs the storefronts decision) is blocked as well | P4.6.0 is scheduled first within this phase's execution (see Entry conditions above), and its S size reflects a decision task, not implementation work, so it is not queued behind larger tasks | If P4.6.1 or P4.6.4 have not started within a reasonable window after this phase begins and P4.6.0 has not closed, that delay is logged as a discovered Failure Point rather than silently absorbed into those tasks' own schedules |
| The full localization pass (P4.6.1) breaks a UI container that the pseudo-localization pass at P3.15 did not catch | Pseudo-localization approximates real text expansion at a fixed ratio; real translated strings in specific launch languages can exceed that approximation for a given string, especially in languages with longer average word length | Every localized string is checked against its container's dynamic sizing rules (MASTER_SDLC.md > Risk Register > "UI breaks during localization or scaling"; owning document 19's dynamic container rules), not only re-verified against the pseudo-loc ratio | Localization test run against the real localized text tables in every launch language P4.6.0 decided on, not only re-run against pseudo-loc; any truncation beyond the documented ellipsis rule is a Ledger finding |
| The performance rule holds on the reference machine but not on the minimum-spec machine P4.6.0 decides on | The reference machine (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Reference machine") has never been the performance floor; minimum spec, by definition, is weaker hardware that has not yet been measured against | The Performance Fallback Ladder (MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance > "Performance Fallback Ladder") is available to adopt a further step if minimum spec fails; this phase does not skip P4.6.4 or substitute reference-machine data for it | Minimum-spec performance test run on the actual minimum-spec machine the Register row names, not estimated from reference-machine results; a failing result is a Ledger finding, and any ladder-step change is recorded in the Review Decision Log |
| A storefront target decided at P4.6.0 carries a submission requirement (a checklist item) that no task in this phase or Phase 19 explicitly owns | Storefront requirements (ratings, platform-specific technical checks, content policy items) are numerous and vary by storefront; P4.6.0 decides which storefronts to target but does not itself enumerate every requirement each one carries | P4.6.0's Register row for storefronts is treated as an input to P4.7.1's later store-build checklist (Phase 19), not as a completed requirements audit on its own; this phase does not claim storefront readiness | Phase reviewer confirms P4.6.0's deliverable is limited to naming the target storefronts, and flags as an open item any storefront-specific requirement not yet assigned an owner by the time Phase 19 begins |
| The accessibility pass (P4.6.2) misses a case where mandatory information is conveyed by colour alone, because the check is run against the UI as authored rather than as a colourblind user would see it | A colour-only-distinction bug is often invisible to a reviewer with typical colour vision; the Visual Edge Cases rule this task is verified against requires deliberately simulating the failure mode, not just reading the UI spec | The accessibility checklist explicitly includes a colourblind-simulation pass over every UI element that conveys state (health, danger, affordability, rank), not only a design-intent review | Any UI element found to rely on colour alone under simulation is logged as a fix in the accessibility checklist and re-checked before this task is scored |
| The 20-tester playtest (P4.6.5) shows a regression against a prototype- or slice-era pass threshold that was never re-verified after M4.1-M4.4 content was added | Adding three milestones' worth of content since the slice gate creates many opportunities for an earlier-established pass threshold (for example, a P-tagged or VS-tagged tester test) to quietly regress without anyone re-running it until this playtest | P4.6.5's acceptance test explicitly reuses the P-tagged and VS-tagged tester tests at full-game scale, rather than only running new A-tagged tests, per its own Acceptance test cell above | Each reused test's result is compared against its original prototype/slice pass threshold, not only checked against the 16-of-20 Beta threshold in isolation; a regression on either measure is a Ledger finding |

## Agent assignment

Sonnet subagents implement and write P4.6.1, P4.6.2, P4.6.4, and P4.6.5. P4.6.0 and P4.6.3 are author decision tasks; a Sonnet subagent prepares the options and records the resulting Register rows or Change Log row, but does not make the decision itself. Opus runs one critical agent per task (P4.6.0 through P4.6.5) plus the phase reviewer for M4.6 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. P4.6.0's exit criterion asks for the decision to be "recorded per the Gate Approval rule," but P4.6.0 is not itself a milestone gate (it is one task inside M4.6). Does "per the Gate Approval rule" here mean only the author may write the Register rows into MASTER_SDLC.md's Provisional Values Register (matching how the rule is used for milestone gate rows elsewhere), or does it mean something narrower for a task-level decision? (a) Same rule as milestone gates: only the author writes the Register rows (b) A narrower task-level reading applies (c) Other.
2. This phase's minimum-spec machine, launch languages, and storefront decisions are all due at P4.6.0. Given three separate decisions bundled into one S-sized task, should the author expect to make all three in one sitting, or would splitting P4.6.0 into three smaller decision tasks (still all "none formal" / author-recorded) reduce the single-point-of-delay risk flagged in the risk table above? (a) Keep as one task (b) Split into three (c) Other.

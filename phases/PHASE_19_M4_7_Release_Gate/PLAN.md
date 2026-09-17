# Phase 19 - M4.7 Release Gate

Status: Not started; Executes: docs/29 Phase 4, milestone M4.7; Plan task IDs: P4.7.1, P4.7.2, P4.7.3

## Goal

Package and sign store builds for every target storefront, integrate a live crash and exception reporting pipeline, and complete the final release checklist. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.7 - Release gate)

## Entry conditions

- Phase 18 (M4.6 Beta Gate) is complete under the phase bar (loop rule d); `phases/README.md`'s phase table lists phase 18 as phase 19's dependency.
- P4.7.1's own Depends-on field in docs/29 names both the Beta gate and P4.6.0 specifically (the storefronts decision from Phase 18), not phase 18 generically. This document does not start P4.7.1 before both the "Beta accepted" Change Log row and P4.6.0's storefronts Register row exist.
- P4.7.2 depends on P4.7.1; P4.7.3 depends on both P4.7.1 and P4.7.2. Tasks in this phase run in that order, not in parallel from the start.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions still apply; they are not restated here.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, no Phase 4 phase has yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.7.1 | Store builds | Signed store builds | none tagged directly; verified by a storefront submission checklist | Every target storefront accepts the build for review | 20 (Technical Architecture), 23 (Folder Structure) | M | Sonnet subagent |
| P4.7.2 | Crash reporting | Crash reporting integration | none tagged directly; verified by a scripted forced-crash test | A forced crash produces a report reaching the pipeline | 20 (Technical Architecture) | S | Sonnet subagent |
| P4.7.3 | Release checklist | Signed-off release checklist | none tagged directly; verified by the designer's sign-off | Checklist complete and recorded per the Gate Approval rule | 28 (AI Development Workflow), 29 (Milestones & Roadmap) | S | Sonnet subagent prepares; author signs off |

## Step-by-step implementation

### P4.7.1 - Store builds

- Scope in/out: In: packaged builds for every target storefront. Out: platforms beyond the release plan.
- Inputs: the Beta gate; P4.6.0's deliverable (the storefronts decision).
- Depends on: Beta gate, P4.6.0.
- Owning documents: 20 (Technical Architecture), 23 (Folder Structure).
- Deliverable: Signed store builds.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.7.2 - Crash reporting

- Scope in/out: In: a crash and exception reporting pipeline live in the shipped build. Out: analytics beyond crash reporting.
- Inputs: P4.7.1's deliverable (the store build).
- Depends on: P4.7.1.
- Owning document: 20 (Technical Architecture).
- Deliverable: Crash reporting integration.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.7.3 - Release checklist

- Scope in/out: In: the final release checklist (build hash, version bump, store listing, Change Log row). Out: post-release patch process.
- Inputs: P4.7.1 and P4.7.2 deliverables.
- Depends on: P4.7.1, P4.7.2.
- Owning documents: 28 (AI Development Workflow), 29 (Milestones & Roadmap).
- Deliverable: Signed-off release checklist.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

Milestone gate line, quoted from docs/29 (this document does not assert the gate is recorded; only the author's Change Log row does that): "Release gate: P4.7.1 to P4.7.3 pass; Change Log row 'Release accepted' per the Gate Approval rule."

The master's Definition Of Done For A Milestone (MASTER_SDLC.md, lines 2709-2716) applies in full to this phase:

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared - every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated. (This phase relies on P4.5.1's Full run test result carrying forward against the signed release build; it does not re-run a separate full-run definition of its own.)
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median >= 60 FPS, 1st-percentile >= 45 FPS) during the heaviest encounter in scope (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Performance rule"), carried forward from P4.6.4's minimum-spec result.
- All acceptance tests tagged for the milestone pass.

This document does not assert that any of the above is met; reviewers and the author decide that, per loop rule (c) and the Gate Approval rule.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A storefront rejects the build for a checklist item nobody owned | P4.6.0 names which storefronts to target, but no single task before this phase enumerates every individual requirement each storefront's submission process carries; a requirement can fall between P4.6.0, P4.7.1, and P4.7.3 without anyone treating it as theirs | P4.7.1's storefront submission checklist is built per target storefront, explicitly assigning an owner to each checklist item before submission, rather than assuming coverage from the general build process | Any storefront rejection, or any checklist item discovered without a prior owner during P4.7.1, is logged as a Ledger finding naming the missing owner |
| The crash and exception reporting pipeline appears to work under the scripted forced-crash test but does not actually receive reports from the real signed, distributed build (for example, because of a build-time flag, signing, or network-endpoint difference between the dev and shipped build) | The acceptance check is a scripted forced-crash test, which can pass against a development build's configuration while the shipped build's crash handler is wired differently (different build flags, different endpoint credentials, or a reporting SDK stripped by the release export template) | The forced-crash test is run against the actual signed store build from P4.7.1, not only a development build, before P4.7.2 is marked ready for review | A forced crash on the exact artifact being submitted to storefronts must produce a report reaching the real pipeline; a pass only on a development build is not sufficient and is logged as a Ledger finding |
| A save migration that passed at P4.5.2 (Phase 17, prototype/slice format) does not hold against a save profile created during the Beta playtest (P4.6.5), because the save schema changed again between Alpha and Release | Save schema and content both changed across M4.6's localization, accessibility, and any Phase 4 content work; the migration chain documented at P4.5.2 may not yet include a Beta-era save format | The documented migration chain (MASTER_SDLC.md > Edge Cases and Failure States > Save and Persistence > "Save schema changes between versions") is checked for a Beta-format entry before this phase closes, not assumed complete from P4.5.2 alone | A save file taken from an actual P4.6.5 playtester's profile is loaded against the shipped build as part of P4.7.3's checklist; a data-loss or crash result is a Ledger finding |
| The release checklist (P4.7.3) is signed off with an item silently skipped, because the checklist's completeness is asserted rather than independently checked | A checklist that is filled in by the same process that executes it is prone to marking an item done without independent verification, especially under schedule pressure at the final gate | P4.7.3's checklist items (build hash, version bump, store listing, Change Log row) are each backed by a specific artifact (the hash itself, the version file diff, the listing text, the Change Log row) rather than a bare checkbox | Critical agent for P4.7.3 checks each checklist item against its named artifact before the designer's sign-off, per the task's own acceptance verification method |
| Documentation drifts from implementation at the final release, because release-specific configuration (signing, storefront metadata, crash-reporting endpoints) is often stored outside the documents that describe gameplay systems and is easy to leave undocumented | Release infrastructure work is less naturally tied to a system document than gameplay work is, so the "same commit" documentation rule is easier to skip by habit | Document 20 (Technical Architecture) and document 23 (Folder Structure) are updated in the same commit as the store-build and crash-reporting work, per the existing rule (MASTER_SDLC.md > Risk Register > "Documentation drifts from implementation"; docs/28 owns this rule) | Phase reviewer's pre-re-review sweep (loop rule d) checks P4.7.1 and P4.7.2's commits for a matching document change |

## Agent assignment

Sonnet subagents implement and write P4.7.1 and P4.7.2, and prepare P4.7.3's checklist and its supporting artifacts. P4.7.3's final exit criterion is the designer's sign-off, which only the author gives; a Sonnet subagent does not sign off on its own behalf. Opus runs one critical agent per task (P4.7.1, P4.7.2, P4.7.3) plus the phase reviewer for M4.7 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. P4.7.3's Out scope explicitly excludes "post-release patch process." Should a post-release patch process (versioning, hotfix criteria, re-submission to storefronts) be scoped as a new task added to document 29 after this phase closes, or is it deliberately left outside the Development Phase Map entirely, to be handled ad hoc? (a) Add a post-release task to docs/29 (b) Leave it ad hoc, outside the Phase Map (c) Other.
2. This phase's Definition Of Done reference (above) carries forward P4.5.1's full-run result and P4.6.4's minimum-spec performance result rather than re-running either at Release. Should Release require its own fresh full-run and minimum-spec performance pass against the exact signed build being submitted, rather than carrying forward results measured against an earlier (Alpha- or Beta-stage) build? (a) Re-run both against the signed build (b) Carry forward is sufficient (c) Other.

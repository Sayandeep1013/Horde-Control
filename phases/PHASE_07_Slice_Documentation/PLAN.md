# Phase 07 - Slice Documentation

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.1, P3.2, P3.2b

## Goal

Bring the system documents that every later vertical-slice task reads before it implements anything to the maturity docs/29 requires: documents 03, 05, 07, 09, 11, 20 to stable (1.0.0); documents 10, 12, 13, 14, 15, 17, 18 to a working draft; and documents 04, 06, 08, 16, 19, 24, 25, 26, 27 to a working draft. Close deferred findings P6 and F20 as part of this work. This is phases/README.md's phase-table row 07 outcome: "The system documents slice implementation depends on."

No implementation code is written in this phase. Phases 08 through 12 read these documents as their owning-document input; a document left inconsistent or placeholder-filled here becomes a build-time contradiction later, which is exactly what MASTER_SDLC.md > Risk Register's "Documentation drifts from implementation" row and this phase's doc-lint gate exist to prevent before it starts.

## Entry conditions

- Phase 06 exit recorded: every P-tagged scripted test passing at P2.15; Prototype Success Criteria 1-14 with five external testers at P2.16; the Grappling criteria review at P2.17; the Gate record check at P2.18 with the gate rows written by the author (phases/README.md phase-table row 06 gate). P3.1's own Inputs field names "P2.18 deliverable (gate rows)" directly.
- Every Provisional Default row owned by documents 03, 05, 07, 09, 11, and 20 exists in MASTER_SDLC.md > Provisional Values Register, since P3.1 stabilizes these six documents against exactly those rows (P3.1 Inputs).
- Documents 00-02 at 1.0.0 (Phase 01 deliverable) and the Phase 0 stub with its "Owns:" list for every other document (MASTER_SDLC.md > Quality Gates: "the Phase 0 stub with its Owns list satisfies the existence requirement for the prototype milestone only"), since P3.1, P3.2, and P3.2b all start from those stubs and must resolve or accept every Owns entry.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 06) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 06 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P3.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.1 | Stable docs 03, 05, 07, 09, 11, 20 | `docs/03,05,07,09,11,20.md` at 1.0.0 | none formal | Change Log rows for each; no contradiction with this file | 03, 05, 07, 09, 11, 20 | XL | Sonnet (implementer) |
| P3.2 | Working docs 10, 12, 13, 14, 15, 17, 18 | `docs/10,12,13,14,15,17,18.md` as working drafts | none formal | Each document covers its Documentation Structure remit with no open contradiction | 10, 12, 13, 14, 15, 17, 18 | XL | Sonnet (implementer) |
| P3.2b | Working docs 04, 06, 08, 16, 19, 24, 25, 26, 27 | `docs/04,06,08,16,19,24,25,26,27.md` as working drafts | none formal | Each document covers its Documentation Structure remit with no open contradiction; doc lint: zero placeholders; every Owns entry has a resolved or accepted row | 04, 06, 08, 16, 19, 24, 25, 26, 27 | XL | Sonnet (implementer) |

Cells above are copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Acceptance test, Exit criterion, Owner, Size columns); the numeric document IDs are identifiers, not gameplay numbers, and any gameplay value a document states is owned by MASTER_SDLC.md's Provisional Values Register, not restated here.

## Step-by-step implementation

The step-by-step section below states each task's inputs, owning document, and deliverable paths now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 06's actual lessons exist to inform them.

### P3.1 - Stable docs 03, 05, 07, 09, 11, 20

Inputs: P2.18 deliverable (the Minimum Playable Prototype gate rows); every Provisional Default row documents 03 (Player Controller Specification), 05 (Combat System), 07 (Tower System), 09 (Enemy AI Architecture), 11 (Wave Director), and 20 (Technical Architecture) own.
Deliverable file paths: `docs/03_Player_Controller_Specification.md`, `docs/05_Combat_System.md`, `docs/07_Tower_System.md`, `docs/09_Enemy_AI_Architecture.md`, `docs/11_Wave_Director.md`, `docs/20_Technical_Architecture.md`, each stabilized to 1.0.0.
Owning documents: 03, 05, 07, 09, 11, 20, each stabilizing itself; deferred finding P6 (owner document 20) and its typed-contract requirement close inside this task.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.2 - Working docs 10, 12, 13, 14, 15, 17, 18

Inputs: P3.1 deliverable (the six stable core documents this task's working drafts must not contradict).
Deliverable file paths: `docs/10_Boss_Design.md`, `docs/12_Difficulty_Scaling.md`, `docs/13_Roguelite_Progression.md`, `docs/14_Economy.md`, `docs/15_Biomes.md`, `docs/17_Upgrade_Pools.md`, `docs/18_Permanent_Skill_Tree.md`, each brought to a working draft.
Owning documents: 10, 12, 13, 14, 15, 17, 18, each covering its own Documentation Structure remit; deferred finding F20 (owner document 10, the Mini-Boss wording finding) closes inside this task.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.2b - Working docs 04, 06, 08, 16, 19, 24, 25, 26, 27

Inputs: P3.1 deliverable (the six stable core documents this task's working drafts must not contradict).
Deliverable file paths: `docs/04_Grappling_System.md`, `docs/06_Weapon_Framework.md`, `docs/08_Factory_System.md`, `docs/16_Resource_System.md`, `docs/19_UI_UX.md`, `docs/24_Save_System.md`, `docs/25_Asset_Pipeline.md`, `docs/26_Audio_Design.md`, `docs/27_VFX_and_Game_Feel.md`, each brought to a working draft.
Owning documents: 04, 06, 08, 16, 19, 24, 25, 26, 27; the doc-lint (zero placeholders) and Owns-entry (resolved or accepted) requirements are this task's own exit criterion in docs/29, and deferred finding P1 progresses to its "working" tier across these nine documents here.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

No task in this phase carries a named Acceptance Test Matrix entry; docs/29 lists the acceptance test for P3.1, P3.2, and P3.2b as "none formal." This phase's gate is document quality, copied from docs/29's Exit criterion column and phases/README.md's phase-table row 07 gate:

| Task | Exit criterion (docs/29) |
| --- | --- |
| P3.1 | Change Log rows for each of documents 03, 05, 07, 09, 11, 20; no contradiction with docs/29_Milestones_and_Roadmap.md |
| P3.2 | Each of documents 10, 12, 13, 14, 15, 17, 18 covers its Documentation Structure remit with no open contradiction |
| P3.2b | Each of documents 04, 06, 08, 16, 19, 24, 25, 26, 27 covers its Documentation Structure remit with no open contradiction; doc lint: zero placeholders; every Owns entry has a resolved or accepted row |

Read across the whole phase, per this task's own instruction, the gate is: doc lint finds zero placeholders across all twenty-two documents this phase touches, every Owns entry across those documents is resolved or accepted, no open contradiction exists among them or against MASTER_SDLC.md or docs/29, and deferred findings P6 and F20 close (see "Deferred findings due in this phase," below). This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Deferred findings due in this phase

| ID | Finding | Owner doc | Must close by (docs/29) | Status this phase produces |
| --- | --- | --- | --- | --- |
| P6 | Slice-only contract fields (Biome, Boss, Elite Affix, Status Effect) remain untyped or half-typed | 20 | Before Phase 3 (P3.1) | Closes here: P3.1 stabilizes document 20 to 1.0.0, typing these contract fields |
| F20 | Mini-Boss wording (overlap, suppression) is inconsistent with boss wave rules | 10 | Before Phase 3 (P3.10) | Closes here: P3.2 brings document 10 to a working draft with the wording corrected, ahead of P3.10 in Phase 09 |
| P1 | 14 owning documents were never written by any prototype-era task; withdrawn as a prototype-readiness blocker, slice-era completeness is a tracked deferral | 29 (docs/29_Milestones_and_Roadmap.md) | Progressively: P3.2b (working, Phase 3) and P4.0 (stable, before Alpha gate) | Progresses, does not close: P3.2b brings its nine documents to a working draft; the stable tier is due at P4.0 (phases/README.md phase-table row 17, PHASE_17_M4_5_Alpha_Gate), outside this folder set's scope |

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Scope creep past the Vertical Slice Scope Freeze | A document stabilized or drafted this phase could describe a system, encounter type, or count beyond MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice without a recorded freeze amendment, since this phase touches twenty-two documents at once | Every new or changed Owns entry and every stabilized Provisional Default row is checked against the Freeze's Included and Excluded lists before a document is marked stable or working; anything outside that list needs a Change Log freeze-amendment row, the pattern Decision D40 already set | Reviewer sweep comparing each document's Owns list against the Freeze's Included and Excluded lists at the review gate |
| Deferred findings P6 and F20 marked closed without the underlying wording actually fixed | It is easier to mark a finding closed because its owning document reached "stable" or "working" status than to verify the specific wording the Deferred Review Findings table names was corrected | LEDGER.md carries P6 and F20 as named rows, closed only on direct evidence (the specific document 20 contract fields typed; the specific document 10 Mini-Boss wording corrected), not on a general status claim | Critical agent for P3.1 checks document 20's typed contract fields directly; critical agent for P3.2 checks document 10's corrected wording directly against the Deferred Review Findings table's own description |
| Documentation drifts from implementation (MASTER_SDLC.md > Risk Register) | Documents 07, 09, 11, 20, 10, and others finalized here describe systems phases 08 through 12 implement; a document could still diverge once implementation starts | MASTER_SDLC.md > Risk Register's own mitigation - every system change updates its document in the same commit - applies from Phase 08 onward | phases/README.md loop rule (d)'s "sweep all changed files for superseded wording" before every re-review, repeated at the start of Phase 08 |
| The P1 deferred finding reaches only its "working" tier here, and an Owns entry reads as accepted rather than genuinely resolved | Doc lint's pass condition allows either a resolved row or an accepted row per Owns entry; an accepted row can substitute for real content if not checked | LEDGER.md records which Owns entries are accepted (a deferred acknowledgement) versus resolved (actual content), so the distinction is visible at review time | Doc lint run at phase exit, reviewed against P3.2b's own exit criterion |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P3.1, P3.2, P3.2b).

Opus runs one critical agent per task (three critical agents, P3.1, P3.2, P3.2b) plus one phase reviewer for Phase 07 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. Deferred finding P1 (14 owning documents never written) is due to reach its "working" tier "progressively" by P3.2b. This phase's three tasks together touch twenty-two documents (six in P3.1, seven in P3.2, nine in P3.2b). Should P1's "closed at working tier" claim rest on the full twenty-two-document set this phase produces, or strictly on the nine documents named in P3.2b's own deliverable list, with any of the original fourteen that fall outside those nine remaining open past this phase?
   a. The full twenty-two-document set this phase produces counts toward P1's working-tier closure.
   b. Only the nine documents in P3.2b's own list count; any of the fourteen outside that list stay open.
   c. Other (please specify).
2. P3.1's exit criterion in docs/29 reads "no contradiction with this file." Read literally inside docs/29_Milestones_and_Roadmap.md, "this file" is docs/29 itself. But MASTER_SDLC.md's own Authority statement says the master wins on intent and the Provisional Values Register wins on any numeric conflict. Should P3.1's "no contradiction" check be read as against docs/29 only, or against MASTER_SDLC.md as well?
   a. Against docs/29_Milestones_and_Roadmap.md only, as the literal text reads.
   b. Against both docs/29 and MASTER_SDLC.md, since the master is the senior document.
   c. Other (please specify).

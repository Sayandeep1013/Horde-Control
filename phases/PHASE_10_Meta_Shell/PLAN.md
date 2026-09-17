# Phase 10 - Meta Shell

Status: Not started; Executes: docs/29_Milestones_and_Roadmap.md > Phase 3 - Vertical Slice (part); Plan task IDs: P3.13, P3.14, P3.15

## Goal

Build the minimal Hub with its one skill node and meta unlock; the save profile with atomic write and corrupt-file fallback; and onboarding compression, controller parity, the reduced-effects accessibility setting, and the pseudo-localization pass. This phase's gate is checked with internal testers; the external tester probes for the same criteria are deferred to P3.18 (Phase 12). This is phases/README.md's phase-table row 10 outcome: "Hub, save profile, onboarding compression, controller parity, accessibility."

## Entry conditions

- Phase 08 deliverables: the Meta Wallet and economy resources (P3.4) and the upgrade pool (P3.12), which P3.13 lists as Inputs.
- Phase 09 deliverable: onboarding compressed into the biome, part of the slice wave sequence (P3.11), which P3.15 lists as an Input.
- Phase 07 deliverable: documents 24 (Save System), 19 (UI/UX), and 27 (VFX & Game Feel) at a working draft (P3.2b), which P3.14 and P3.15 list as Inputs.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00 through 09) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase are written into this section before implementation starts: recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 09 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P3.x work in this phase begins.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P3.13 | Hub and meta unlock | `scenes/hub.tscn` | none tagged directly; verified by Slice Exit Criterion 4 at P3.18 | 4 of 5 testers see failed-run progress in the Hub | 18, 19 | M | Sonnet (implementer) |
| P3.14 | Save profile | `src/save/*.gd` | Save atomicity test; Meta persistence test; Settlement test (crash clause) | Corrupt file recovers to a fresh profile; a partial write never loads | 24 | M | Sonnet (implementer) |
| P3.15 | Onboarding compression, controller parity, reduced effects, pseudo-loc pass | Settings and sequence data | Onboarding compression test; Controller-only run test; Reduced effects test | Compression halves T1 and T2 durations without removing a teaching wave (Author decision A1); a controller-only run completes; reduced effects still respect the Readability Hierarchy | 02, 19, 27 | M | Sonnet (implementer) |

Cells above are copied from docs/29_Milestones_and_Roadmap.md's Phase 3 table (Goal, Deliverable, Acceptance test, Exit criterion, Owner, Size columns). P3.13's Exit criterion carries a tester-probe threshold that deferred finding P13 names as embedded in a build task rather than the dedicated playtest task; see "Predetermined failure points and risks," below. Any other gameplay number a document states is owned by MASTER_SDLC.md's Provisional Values Register or the cited owner document, not restated here.

## Step-by-step implementation

The step-by-step section below states each task's inputs, owning document, and deliverable paths now, and does not carry a full walkthrough. Per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once phases 00 through 09's actual lessons exist to inform them.

### P3.13 - Hub and meta unlock

Inputs: P3.4 deliverable (the Meta Wallet, Phase 08); P3.12 deliverable (the upgrade pool, for the skill node's fourth Tower upgrade, Phase 08).
Deliverable file paths: `scenes/hub.tscn`.
Owning documents: 18 (Permanent Skill Tree), 19 (UI/UX).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.14 - Save profile

Inputs: P3.13 deliverable (the Hub and the Meta Wallet to persist, produced earlier in this same phase); P3.2b deliverable (document 24, Save System, working draft, Phase 07).
Deliverable file paths: `src/save/*.gd`.
Owning document: 24 (Save System); deferred finding P7b (the Settlement test's crash clause) closes here, since it cannot be checked without this task's save profile.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P3.15 - Onboarding compression, controller parity, reduced effects, pseudo-loc pass

Inputs: P3.11 deliverable (onboarding in biome, Phase 09); P3.14 deliverable (settings persistence, produced earlier in this same phase); P3.2b deliverable (documents 19 and 27 working drafts, Phase 07).
Deliverable file paths: settings and sequence data (paths fixed at phase entry).
Owning documents: 02 (Gameplay Loop), 19 (UI/UX), 27 (VFX & Game Feel).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Save atomicity test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.14 scripted kill-mid-write result |
| Meta persistence test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.14 save/load and failed-run persistence result |
| Settlement test (crash clause) | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.14 crash-clause result, re-run against the real save profile, closing deferred finding P7b |
| Onboarding compression test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.15 result, internal tester this phase; external tester probe deferred to P3.18 |
| Controller-only run test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P3.15 result, internal tester this phase; external tester probe deferred to P3.18 |
| Reduced effects test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P3.15 scripted-assertion result this phase; external tester probe deferred to P3.18 |

Per the Acceptance Test Matrix's own instrument column, Onboarding compression test, Controller-only run test, and Reduced effects test each carry two instruments: an internal-tester or scripted result at P3.15 (this phase) and an external-tester probe at P3.18 (Phase 12). This phase's evidence is the internal-tester half only; it does not assert the external-tester half, which belongs to Phase 12. This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Deferred findings due in this phase

| ID | Finding | Owner doc | Must close by (docs/29) | Status this phase produces |
| --- | --- | --- | --- | --- |
| P7b | The Settlement test's crash clause could not be checked without the save profile; this round places that check at P3.14, once the save profile exists | 24 | By P3.14 (Phase 3) | Closes here: P3.14 re-runs the Settlement test's crash clause against the real save profile |

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A save write interrupted mid-write | P3.14 introduces the project's first persistent file write; an interruption (crash, power loss, forced quit) mid-write is exactly the failure mode a single JSON save file is vulnerable to without atomic-write discipline | MASTER_SDLC.md > Vertical Slice Scope Freeze's save-profile line requires atomic write and corrupt-file fallback; the write path is designed so a partial write never overwrites the last complete file | Save atomicity test (scripted kill-mid-write) |
| Tester-probe pass conditions embedded in a build-task exit criterion rather than the dedicated external-playtest task (deferred finding P13, named example P3.13) | P3.13's own exit criterion in docs/29 is a tester-probe threshold ("4 of 5 testers see failed-run progress in the Hub") sitting inside a build task | This phase records P3.13's own local check using internal testers only (the designer and scripted bots); the external-tester version of this criterion is treated as belonging to Slice Exit Criterion 4 at P3.18, per docs/29's own Acceptance test column for P3.13 | Reviewer confirms this phase's evidence for P3.13 names internal testers only, and that LEDGER.md does not claim the external-tester threshold as met here |
| The Settlement test's crash clause (deferred finding P7b) cannot be checked without the save profile existing first | P3.4 (Phase 08) implemented Run-End Settlement including its crash clause, but the clause could not be checked against a real save file before P3.14 existed | This phase re-runs the Settlement test's crash clause specifically against the save profile P3.14 produces, closing P7b here rather than leaving it attached to Phase 08 | Settlement test (crash clause), cross-checked against P3.14's save file |
| Onboarding compression removes a teaching wave, contradicting Author decision A1 | A compression implementation that skips a beat rather than shortening it would violate MASTER_SDLC.md > Onboarding & Session > "Onboarding compression (Author decision, A1)" | The compression setting is implemented as a duration/budget multiplier only, never a beat-skip; A1's own wording (compressible, never skippable, all four beats always play) is the acceptance bar | Onboarding compression test |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P3.13, P3.14, P3.15).

Opus runs one critical agent per task (three critical agents) plus one phase reviewer for Phase 10 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. This phase's local gate for Onboarding compression test, Controller-only run test, and Reduced effects test rests on internal-tester or scripted evidence only, per the Acceptance Test Matrix's dual-instrument definition. Should Phase 10 be allowed to close (per phases/README.md loop rule (d)) on that internal-tester evidence alone, with the external-tester half tracked only as a Phase 12 dependency, or should Phase 10 stay open until Phase 12's external-tester results are available?
   a. Phase 10 may close on internal-tester evidence; the external-tester half is Phase 12's own dependency to satisfy.
   b. Phase 10 must stay open (or be reopened) until Phase 12 confirms the external-tester half.
   c. Other (please specify).
2. P3.13's exit criterion is a tester-probe threshold that deferred finding P13 says belongs at the dedicated external-playtest task instead. Should this phase's PLAN.md drop the tester-probe language from P3.13's local gate entirely (recording only that the Hub shows failed-run progress by scripted or internal-tester check), leaving the "4 of 5" threshold solely to Slice Exit Criterion 4 at P3.18, or should the same threshold still apply informally to the internal-tester check this phase runs?
   a. Drop the tester-probe threshold from this phase's local gate; only P3.18 applies it.
   b. Keep the same threshold informally for this phase's internal-tester check too.
   c. Other (please specify).

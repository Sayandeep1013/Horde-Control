# Phase 17 - M4.5 Alpha Gate

Status: Not started; Executes: docs/29 Phase 4, milestone M4.5; Plan task IDs: P4.0, P4.5.1, P4.5.2, P4.5.3

## Goal

Bring documents 06, 08, 10, 12 through 19, and 21 through 27 to stable (1.0.0), then prove the build with a full three-biome run, a save migration from the prototype/slice format, and a repeatable byte-identical Windows export pipeline. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.5 - Alpha gate)

Documents 29 and 30 are explicitly excluded from the stabilization P4.0 performs: docs/29 states "Docs 29 and 30 are living documents; they carry no stable-version requirement at any gate, unlike every other document this milestone stabilizes." This phase does not attempt to bring docs/29 or docs/30 to 1.0.0, and their remaining at a lower version is not treated as a P4.0 gap.

## Entry conditions

- Phase 16 (M4.4 Full Progression) is complete under the phase bar (loop rule d); `phases/README.md`'s phase table lists phase 16 as phase 17's dependency.
- P4.0's own Depends-on field in docs/29 is narrower than "all of phase 16": specifically P4.1.7, P4.2.7, P4.3.8, and P4.4.4 - the closing task of each of the four M4.1-M4.4 milestones. This document does not start P4.0 before all four of those specific deliverables exist, even if other Phase 4 tasks are still under review.
- P4.5.1's Depends-on field in docs/29 lists every task in M4.1 through M4.4 individually, plus P4.0. Full-run testing does not start until the entire content set and the stabilized documentation both exist.
- P4.5.2 and P4.5.3 both depend on P4.5.1 specifically, not on P4.0 directly.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions still apply; they are not restated here.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, no Phase 4 phase has yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.0 | Stable docs 06, 08, 10, 12-19, 21-27 | `docs/06,08,10,12-19,21-27.md` at 1.0.0 | none formal | Each document covers its Documentation Structure remit with no open contradiction; doc lint: zero placeholders; every Owns entry has a resolved or accepted row | 06, 08, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27 | XL | Sonnet subagent |
| P4.5.1 | Full run test | Recorded full-run playthrough | Full run test | A full run completes with no crash, softlock, or orphaned state | 29 (Milestones & Roadmap) | M | Sonnet subagent |
| P4.5.2 | Save migration test | Save migration script and test fixtures | Save migration test | An old-format save loads without data loss or crash | 24 (Save System) | M | Sonnet subagent |
| P4.5.3 | Windows export pipeline | Documented export pipeline | none tagged directly; verified by two consecutive matching exports | Two consecutive exports from the same commit produce byte-identical builds | 20 (Technical Architecture), 23 (Folder Structure) | S | Sonnet subagent |

## Step-by-step implementation

### P4.0 - Stable docs 06, 08, 10, 12-19, 21-27

- Scope in/out: In: bring documents 06, 08, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27 to stable (1.0.0), encoding every slice-era decision and Provisional Default they own. Out: docs 29 and 30, which remain living documents with no stable requirement.
- Inputs: the M4.1, M4.2, M4.3, and M4.4 deliverables (content these documents must describe at full-game scope).
- Depends on: P4.1.7, P4.2.7, P4.3.8, P4.4.4.
- Owning documents: 06, 08, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27.
- Deliverable: `docs/06,08,10,12-19,21-27.md` at 1.0.0.
- Stability requirement referenced: MASTER_SDLC.md > Document Control - a document is stable only when its version is 1.0.0 or higher, every edge-case register entry it owns is resolved or explicitly accepted in writing, it contains no placeholder, and it has been reviewed against the master with the review recorded in the master's change log.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.5.1 - Full run test

- Scope in/out: In: a scripted play from the Hub through all three biomes including transitions to a run-complete screen. Out: milestone content beyond M4.1-M4.4.
- Inputs: the M4.1-M4.4 deliverables (every task in each); P4.0's deliverable (stable docs).
- Depends on: every task in M4.1 through M4.4 (P4.1.1-P4.1.7, P4.2.1-P4.2.7, P4.3.1-P4.3.8, P4.4.1-P4.4.4) and P4.0.
- Owning document: 29 (Milestones & Roadmap).
- Deliverable: Recorded full-run playthrough.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.5.2 - Save migration test

- Scope in/out: In: loading a save file from the prototype/slice save format into the current schema. Out: cloud save.
- Inputs: P3.14's deliverable (the save profile).
- Depends on: P4.5.1.
- Owning document: 24 (Save System).
- Deliverable: Save migration script and test fixtures.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.5.3 - Windows export pipeline

- Scope in/out: In: a repeatable Windows release export with build hash and version stamping. Out: other platforms.
- Inputs: P0.2's deliverable (export templates).
- Depends on: P4.5.1.
- Owning documents: 20 (Technical Architecture), 23 (Folder Structure).
- Deliverable: Documented export pipeline.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

Milestone gate line, quoted from docs/29 (this document does not assert the gate is recorded; only the author's Change Log row does that): "Alpha gate: P4.0 and P4.5.1 to P4.5.3 pass; Change Log row 'Alpha accepted' per the Gate Approval rule."

The master's Definition Of Done For A Milestone (MASTER_SDLC.md, lines 2709-2716) applies in full to this phase:

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared - every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated. (This phase's own Full run test, per the Acceptance Test Matrix Build Checks table, states the Alpha-scope full-run condition directly: a scripted run through all three biomes including transitions completes without developer intervention.)
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median >= 60 FPS, 1st-percentile >= 45 FPS) during the heaviest encounter in scope (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Performance rule"), measured on the reference machine - the minimum-spec machine is not yet decided at this phase; see the Predetermined risks table below.
- All acceptance tests tagged for the milestone pass.

This document does not assert that any of the above is met; reviewers and the author decide that, per loop rule (c) and the Gate Approval rule.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The performance rule holds on the reference machine during P4.5.1 but would not hold on whatever minimum-spec machine is later decided at P4.6.0 (Phase 18) | Alpha's Full run test only measures against the reference machine (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Reference machine"); no minimum-spec figure exists yet to test against | This phase records its performance results as reference-machine-only and does not claim they generalize to minimum spec; the Minimum-spec performance test is explicitly deferred to P4.6.4 after P4.6.0 decides the machine | Phase reviewer confirms P4.5.1's recorded performance data is labeled as reference-machine data, not treated as a minimum-spec proxy |
| P4.0 stabilizes 18 documents in one task and misses a placeholder, an unresolved edge-case entry, or a cross-document contradiction, because the sheer volume makes a full sweep expensive | XL-sized, 18-document scope is the largest single documentation task in the plan; a missed item is easy to lose among the rest | Doc lint (zero placeholders) and an Owns-entry check run per document, not once across the batch; the phase reviewer's pre-re-review sweep (loop rule d) explicitly checks for superseded wording across all 18 | Critical agent for P4.0 spot-checks each document's Owns list against MASTER_SDLC.md > Documentation Structure and records any unresolved entry as a Ledger finding |
| The Full run test passes on placeholder or pseudo-localized text, masking a UI break that only appears once P4.6.1's real localization pass runs | Localization has not happened yet at this phase (P3.15 delivered only a pseudo-localization pass); the Full run test's pass condition does not itself exercise real translated strings | This phase does not claim the Localization test is satisfied; that acceptance test is explicitly scoped to P4.6.1 in the Acceptance Test Matrix, and this document does not substitute pseudo-loc results for it | Phase reviewer confirms no Ledger entry in this phase claims the Localization test passed |
| A save migration (P4.5.2) corrupts an older prototype/slice-format profile instead of cleanly migrating or rejecting it | The migration script must read a schema that predates every subsequent save-format change accumulated through the slice and all of M4.1-M4.4; a missed field mapping silently drops or misreads data | Migration is tested against the documented migration chain per version, not only the most recent prior format (MASTER_SDLC.md > Edge Cases and Failure States > Save and Persistence > "Save schema changes between versions") | Save migration test run against a real prototype/slice-era save fixture, not only a synthetic one; a data-loss or crash result is a Ledger finding at Blocker severity |
| Two consecutive Windows exports from the same commit are not byte-identical, because the build embeds a timestamp, machine-specific path, or non-deterministic asset-packing order | Export determinism is not guaranteed by default in most build pipelines; something as small as an embedded build time defeats the byte-identical requirement | The export pipeline is documented explicitly enough that a second export from the same commit can be reproduced exactly, per P4.5.3's own exit criterion | Two consecutive exports are diffed at the byte level as part of this phase's execution, not assumed from a single export |
| Content scope expands past the four milestones already closed, because stabilizing documents at full scope invites "just one more" addition while writing | Writing a document's stable form surfaces gaps that are tempting to fill immediately rather than deferring | New content ideas surfaced while stabilizing docs are logged to document 30, not folded into the doc being stabilized (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems") | Phase reviewer checks that P4.0's stabilized documents describe only what M4.1-M4.4 already delivered, not new content introduced during stabilization |

## Agent assignment

Sonnet subagents implement and write every task above. Opus runs one critical agent per task (P4.0, P4.5.1, P4.5.2, P4.5.3) plus the phase reviewer for M4.5 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. The Definition Of Done For A Milestone defines "a full run" explicitly only for the prototype (eight waves) and the vertical slice (one biome, Biome Boss defeated); it does not restate a definition for Alpha. This phase reads the Alpha-scope definition from the Full run test's own pass condition in the Acceptance Test Matrix Build Checks table (all three biomes, including transitions) instead. Should the Definition Of Done section itself be extended to name the Alpha/Beta/Release "full run" definition explicitly, or is pointing to the Acceptance Test Matrix sufficient? (a) Extend the Definition Of Done section (b) Acceptance Test Matrix reference is sufficient (c) Other.
2. P4.0 excludes docs/29 and docs/30 from stabilization by explicit docs/29 note. Should this phase's own PLAN.md, EXECUTION_LOG.md, FAILURE_POINTS.md, REVIEW.md, and LEDGER.md files (which are records about docs/29's content, not docs/29 itself) be referenced anywhere inside docs/29 once this phase closes, or do they stay purely as `phases/` records with no link back into docs/29's text? (a) Add a pointer from docs/29 to the phases/ records (b) Keep them separate (c) Other.

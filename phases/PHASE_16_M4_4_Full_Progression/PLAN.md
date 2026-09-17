# Phase 16 - M4.4 Full Progression

Status: Not started; Executes: docs/29 Phase 4, milestone M4.4; Plan task IDs: P4.4.1, P4.4.2, P4.4.3, P4.4.4

## Goal

Build out full-game progression beyond the vertical slice's minimal shell: the persistent skill tree beyond its one slice node, Factory between-run production queues, the full weapon ladder beyond the slice's single evolution path, and the full upgrade pools beyond the slice's ten player and eight Tower upgrades, each pool audited before the milestone closes. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.4 - Full progression)

## Entry conditions

- Phase 15 (M4.3 Remaining Encounters) is complete under the phase bar (loop rule d); `phases/README.md`'s phase table lists phase 15 as phase 16's dependency.
- P4.4.1 and P4.4.3's own Depends-on fields in docs/29 are both P3.18, the same slice-acceptance dependency used throughout Phase 4, not a Phase 15 task specifically.
- P4.4.2 depends on P4.4.1's deliverable (the skill tree is a queue input for Factory production); P4.4.4 depends on both P3.12 (the slice's upgrade pools, from phase 08) and P4.4.1 (skill tree upgrades). This document does not start P4.4.2 before P4.4.1's deliverable exists, or P4.4.4 before both of its listed dependencies exist.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions still apply; they are not restated here.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, no Phase 4 phase has yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.4.1 | Full skill tree | Skill tree resources and Hub UI | Dominant pair audit pattern, applied to the tree | No branch accounts for more than 65% of Cores spent across 10 or more recorded runs | 18 (Permanent Skill Tree) | L | Sonnet subagent |
| P4.4.2 | Factory between-run production | Factory production system | none tagged directly; verified by a scripted queue-completion pass | A queued item completes and is available on the next run | 08 (Factory System) | L | Sonnet subagent |
| P4.4.3 | Full weapon ladder | Weapon resources | Evolution check pattern, applied to every class | Each class's evolutions change range, shape, count, or rhythm | 06 (Weapon Framework) | L | Sonnet subagent |
| P4.4.4 | Full upgrade pools with audits | Upgrade resources and audit sheet | Dominant pair audit | No pool accounts for more than 65% of ranks acquired across 10 or more recorded runs | 17 (Upgrade Pools) | L | Sonnet subagent |

## Step-by-step implementation

### P4.4.1 - Full skill tree

- Scope in/out: In: the persistent skill tree beyond the slice's one node. Out: Factory production.
- Inputs: P3.18's deliverable (the Hub scene and its one skill node).
- Depends on: P3.18.
- Owning document: 18 (Permanent Skill Tree).
- Deliverable: Skill tree resources and Hub UI.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.4.2 - Factory between-run production

- Scope in/out: In: Factory production queues between runs, per document 08. Out: in-run queues (still banned).
- Inputs: P4.4.1's deliverable (the skill tree, a queue input).
- Depends on: P4.4.1.
- Owning document: 08 (Factory System).
- Deliverable: Factory production system.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.4.3 - Full weapon ladder

- Scope in/out: In: every weapon class and evolution beyond the slice's single path. Out: further Tower weapons.
- Inputs: P3.18's deliverable (the three slice evolution steps).
- Depends on: P3.18.
- Owning document: 06 (Weapon Framework).
- Deliverable: Weapon resources.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.4.4 - Full upgrade pools with audits

- Scope in/out: In: every remaining player and Tower upgrade beyond the slice's pools, with a dominant-pair audit before this milestone closes. Out: Console price changes.
- Inputs: P3.12's deliverable (the slice pools); P4.4.1's deliverable (skill tree upgrades).
- Depends on: P3.12, P4.4.1.
- Owning document: 17 (Upgrade Pools).
- Deliverable: Upgrade resources and audit sheet.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

docs/29 carries no single "M4.4 gate" line (docs/29 > Phase 4 preamble: only A-tagged tests gate the alpha, beta, and release milestones). M4.4's completion is defined by the four tasks' Acceptance test and Exit criterion cells above, matched against `phases/README.md` row 16's Gate column: Dominant pair audit applied to the tree and to the pools; Evolution check applied to every class; scripted queue-completion pass.

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
| The full skill tree or the full upgrade pools produce a dominant build once every branch and pool exists, rather than only the slice's small subset | The slice's dominant-pair audit passed against ten player and eight Tower upgrades and one skill node; a much larger tree and pool set is a different combinatorial space that has never been audited together | Pool audit runs before this milestone closes, as required by the Dominant pair audit acceptance test itself (MASTER_SDLC.md > Risk Register > "Upgrade pool produces a dominant build") | Dominant pair audit applied to both P4.4.1's tree and P4.4.4's pools against the recorded-run threshold in MASTER_SDLC.md > Provisional Values Register > Economy & Pickups > "Economy dominance measure"; a pool or branch over that threshold is a Ledger finding |
| Content scope expands past what documents 06, 08, 17, and 18 already define (a new weapon class, skill branch, or Factory queue type not previously scoped gets built here) | "Full" progression is an open-ended target compared to the slice's fixed small set, and it is easy to keep adding rather than stopping at what the owning documents already define | Each task's Scope in/out cell is fixed before work starts; a genuinely new system idea (not an expansion of an existing owning document's scope) is logged to document 30 instead (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems", applied here to progression systems) | Phase reviewer checks each task's delivered resources against its owning document's existing Owns list before scoring |
| Factory production queues (P4.4.2) accidentally become available during a run, violating the still-banned in-run queue rule | Between-run and in-run code paths for the same Factory UI are easy to leave both reachable if the run-state gate is not enforced explicitly | The in-run ban is stated as an explicit Out in P4.4.2's Scope in/out cell, and document 08 owns "behaviour when production outpaces demand" and the queue's between-run-only trigger | Scripted queue-completion pass includes an explicit negative case: attempting to open or queue Factory production during an active run must fail; a pass that only tests the between-run path is not sufficient |
| The Hub UI and Console/Draft card UI become unreadable once the full skill tree and full upgrade pools are both visible at once | The slice's Hub carried one skill node and ten-plus-eight upgrades; this phase multiplies both, and UI readability was never tested at that density | The Readability Hierarchy and the player-versus-Tower card differentiation rules (owned by document 19) apply to the expanded Hub and Draft/Console content the same as they did at slice density (MASTER_SDLC.md > Risk Register > "Readability degrades as content is added") | Phase reviewer checks the Hub UI and Draft/Console card set for overlap, truncation, or undifferentiated cards at full density, even though this is not one of the four named acceptance tests |
| Documentation drifts from implementation across four owning documents (06, 08, 17, 18) that P4.0 (Phase 17) must later bring to stable with zero placeholders and no open contradiction | Four parallel Sonnet subagents each touching a different owning document increases the chance that at least one document lags its implementation, which then surfaces as a P4.0 blocker rather than being caught here | Every commit that changes a system's implementation also changes that system's document in the same commit (MASTER_SDLC.md > Risk Register > "Documentation drifts from implementation"; docs/28 owns this rule) | Phase reviewer's pre-re-review sweep (loop rule d) checks each task's commit for a matching document change before this phase closes, rather than leaving the check to P4.0 |

## Agent assignment

Sonnet subagents implement and write every task above. Opus runs one critical agent per task (P4.4.1 through P4.4.4) plus the phase reviewer for M4.4 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. P4.4.4's exit criterion is a dominant-pair audit "before this milestone closes," and P4.4.1's exit criterion is the same audit pattern applied to the skill tree. If either audit finds a dominant branch or pool, does this phase stay open until the imbalance is corrected and re-audited, or is a corrective pass scheduled as separate follow-up work outside this phase? (a) Phase stays open until re-audited clean (b) Corrective pass is separate follow-up work, phase closes with the finding recorded (c) Other.
2. Document 18 "owns respec rules" per MASTER_SDLC.md > Documentation Structure, but no P4.4.x task names a respec system explicitly. Is respec in scope for the full skill tree delivered at P4.4.1, or deferred? (a) In scope for P4.4.1 (b) Deferred, log to document 30 or a later milestone (c) Other.

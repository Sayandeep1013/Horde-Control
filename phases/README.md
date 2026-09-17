# Execution Phases

This folder tracks execution of the plan in `MASTER_SDLC.md` (Development Phase Map, Phases 0-2) and `docs/29_Milestones_and_Roadmap.md` (Phases 3-4). The plan is the source of truth for what to build; this folder is the record of doing it. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

## Phase table

| # | Phase | Outcome | Plan task IDs | Depends on | Gate | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 00 | Environment & Connection | A proven agent-to-Godot control path, the repository, the Godot project skeleton, and document 28 pinning both | E0.1, E0.2, P0.1, P0.2, P0.3, P0.5 | none | Connection matrix rows all recorded with evidence; `git log` shows the master's first commit; Settings check (P0.2); docs/28 at 1.0.0 naming the primary method, the fallback, and both pinned MCP server versions | Built and reviewed; two review iterations scored the phase 6/10 against a bar of 8, with four tasks below 7. Closure is the designer's decision under the Gate Approval rule |
| 01 | Contracts, Core Documents, Harness | Typed data-contract schemas, documents 00-02 stable, headless test harness | P0.4, P0.6, P0.7 | 00 | Schema check (P0.6); Harness check (P0.7); doc lint clean on 00-02; the master's "Phase 0 accepted" row proposed to the author | Not started |
| 02 | Technical Foundations | The engine-level spine, proven under load | P1.1, P1.2, P1.3, P1.4, P1.5, P1.6, P1.7 | 01 | Keyed RNG unit check; Pause clock unit check; Registry query check; Cap unit check; Pool unit check; Recorder schema check; Ghost hit test; Audio priority check; Swarm performance test at a recorded Performance Fallback Ladder step; the master's "Phase 1 accepted" row proposed to the author | Not started |
| 03 | Core Entities & Feel Check | Player, arena, weapon, Tower, three enemy intents, HUD, and a recorded feel verdict | P2.1, P2.2, P2.3, P2.4, P2.5, P2.6, P2.7 | 02 | Player movement check; Player silhouette test; Camera bounds test; Weapon check; Tower weapon check; Same-frame death test; Health recovery check; Leash test; Opportunist test; Stuck exemption test; Tower cue audibility check; Feel check with a recorded go verdict | Not started |
| 04 | Wave Director & Pacing | Four encounter types from data, both spawn rings, the Pressure Metric, pickups | P2.8, P2.9, P2.10 | 03 | Spawn ring test; Split Assault test; Hunt test; Encounter recovery test; Wave runtime test; Overtime test; Pressure test; Pickup physics test | Not started |
| 05 | Upgrades, Interfaces, Run Flow | Both upgrade channels and a run that can be played end to end | P2.11, P2.12, P2.13, P2.14 | 04 | Upgrade effect check; Draft queue test; Draft input lockout test; Guaranteed first draft test; Encounter deferral test; Determinism test; XP cap check; Console non-pause test; Console rules test; UI scaling test; Interaction window test; Focus loss test; Movement-only test; Teaching Siege tuning check; Scrap loss test; HUD layout check; Pause authority test; Run flow check | Not started |
| 06 | Prototype Validation & Gate | The Minimum Playable Prototype verdict | P2.15, P2.16, P2.17, P2.18 | 05 | Every P-tagged scripted test passing at P2.15; Prototype Success Criteria 1-14 with five external testers at P2.16; Grappling criteria review at P2.17; Gate record check at P2.18, with the gate rows written by the author | Not started |
| 07 | Slice Documentation | The system documents slice implementation depends on | P3.1, P3.2, P3.2b | 06 | Doc lint zero placeholders; every Owns entry resolved or accepted; no open contradiction; deferred findings P6 and F20 closed (docs/29 Deferred Review Findings) | Not started |
| 08 | Slice Systems | Biome hook and hazard, full economy, status effects, dash, weapon evolutions, enemy roster, upgrade pools | P3.3, P3.4, P3.5, P3.6, P3.7, P3.8, P3.12 | 07 | Effect density test; Hazard telegraph test; Overflow hopper test; Settlement test; Status stacking test; Hook degrade test; Evolution check; Elite affix loop guard test; Elite drop test; Dominant pair audit | Not started |
| 09 | Bosses, Wave Sequence, Transition | Mini-Boss, Biome Boss, the slice wave sequence, and the transition cleanup harness | P3.10, P3.11, P3.17 | 08 | Boss edge case test; Composition rule test with the Duel decision or its recorded waiver; Transition cleanup test | Not started |
| 10 | Meta Shell | Hub, save profile, onboarding compression, controller parity, accessibility | P3.13, P3.14, P3.15 | 09 | Save atomicity test; Meta persistence test; Settlement test crash clause; Onboarding compression test; Controller-only run test; Reduced effects test (internal testers at this phase) | Not started |
| 11 | Production Art, Audio, Re-test | Slice-density art and audio, then the performance re-test they enable | P3.16, P3.9 | 10 | Evolution silhouette test (internal tester); Swarm performance test re-run at slice density on the heaviest encounter | Not started |
| 12 | Slice Acceptance & Gate | The vertical slice verdict | P3.18 | 11 | Every VS-tagged test with five fresh external testers; Slice Exit Criteria 1-10; the slice gate row written by the author | Not started |
| 13 | M4.1 Biome 2 | The second biome, end to end | P4.1.1, P4.1.2, P4.1.3, P4.1.4, P4.1.5, P4.1.6, P4.1.7 | 12 | Hazard telegraph test; Elite affix loop guard test; Boss edge case test; Composition rule test; Transition cleanup test | Not started |
| 14 | M4.2 Biome 3 | The third biome, end to end | P4.2.1, P4.2.2, P4.2.3, P4.2.4, P4.2.5, P4.2.6, P4.2.7 | 13 | Hazard telegraph test; Elite affix loop guard test; Boss edge case test; Composition rule test; Transition cleanup test | Not started |
| 15 | M4.3 Remaining Encounters | The eight remaining encounter types with their edge cases closed | P4.3.1, P4.3.2, P4.3.3, P4.3.4, P4.3.5, P4.3.6, P4.3.7, P4.3.8 | 14 | Escort test; Blackout test; Breach test; Ambush test; Pincer test; Environmental Event test; Resource Rush test; Swarm Crush test; Swarm performance test re-run | Not started |
| 16 | M4.4 Full Progression | Skill tree, Factory production, full weapon ladder, full upgrade pools | P4.4.1, P4.4.2, P4.4.3, P4.4.4 | 15 | Dominant pair audit applied to the tree and to the pools; Evolution check applied to every class; scripted queue-completion pass | Not started |
| 17 | M4.5 Alpha Gate | Stable documentation, a full run, a repeatable export | P4.0, P4.5.1, P4.5.2, P4.5.3 | 16 | Full run test; Save migration test; two consecutive byte-identical exports; the "Alpha accepted" row written by the author | Not started |
| 18 | M4.6 Beta Gate | Minimum-spec, localization, accessibility, and a 20-tester playtest | P4.6.0, P4.6.1, P4.6.2, P4.6.3, P4.6.4, P4.6.5 | 17 | Localization test; Minimum-spec performance test; accessibility colour-only check; 20-tester playtest passing at 16 of 20 per criterion; the "Beta accepted" row written by the author | Not started |
| 19 | M4.7 Release Gate | Store builds, crash reporting, release checklist | P4.7.1, P4.7.2, P4.7.3 | 18 | Storefront acceptance; forced-crash report reaching the pipeline; release checklist signed off; the "Release accepted" row written by the author | Not started |

Folder names follow Prompt 1's `PHASE_N_<Name>` shape with N zero-padded to two digits, from `PHASE_00_Environment_And_Connection` through `PHASE_19_M4_7_Release_Gate`, so that 20 phases sort correctly in a plain directory listing. The zero-padding is the only deviation; every folder keeps its descriptive name.

## Coverage

All 90 plan task IDs — P0.1-P0.7, P1.1-P1.7, P2.1-P2.18, P3.1-P3.18 plus P3.2b, P4.0, P4.1.1-P4.1.7, P4.2.1-P4.2.7, P4.3.1-P4.3.8, P4.4.1-P4.4.4, P4.5.1-P4.5.3, P4.6.0-P4.6.5, P4.7.1-P4.7.3 — appear in exactly one phase above. No plan task was left unplaced.

E0.1 and E0.2 are the only tasks in the table that did not exist in the plan before. They were added to the master's Development Phase Map (Phase 0) on 2026-09-17 by the author's decision, recorded as decision D77 in the Review Decision Log, with a Change Log row at version 0.8.1; P0.2 and P0.5 gained dependencies on them in the same pass.

## Changes from the drafted phase split

1. The draft's phase 0 and phase 1 both contained P0.1 and P0.2. P0.1, P0.3, P0.2 and P0.5 now sit in phase 00: the connection must be proven before the real project is created (NEXT_SESSION Prompt 2 step 5), P0.3 runs early because docs/28 must exist as a stub before the connection test can be written into it, and P0.5 is where the connection method and the pinned MCP server versions are recorded.
2. The draft's phase 4 (P2.8-P2.14) is split into phases 04 and 05. P2.8 alone is size L and carries six acceptance tests; two phases give two checkable gates instead of one seven-task gate.
3. P3.12 moved earlier, into phase 08. P3.6 depends on P3.12, so the draft had its systems phase depending forward on its content phase. P3.12's own dependencies (P3.2, P2.11) are both earlier.
4. P3.9 moved later, into phase 11. Per docs/29, P3.9 depends on P3.10 and P3.16; running it in the systems phase would have violated its own dependencies.
5. The slice is split into six phases (07-12) and production into seven (13-19), one per milestone. The draft's slice phases carried three XL documentation tasks alongside seven implementation tasks; each M4.x milestone already ends at its own gate.
6. E0.1 and E0.2 are new tasks carrying the work in NEXT_SESSION Prompts 2 and 3, which had no plan ID.

## Loop rules

Transcribed from NEXT_SESSION.md Prompt 1, section 3 ("LOOP FOR EVERY PHASE").

a. **Pre-implementation**: read all earlier phases' EXECUTION_LOG, FAILURE_POINTS, REVIEW, and LESSONS. Write the patterns that apply to this phase into its PLAN.md (recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved).

b. **Implementation**: execute PLAN.md step by step. Log everything in EXECUTION_LOG.md and add each new failure point the moment it appears. The documents never claim the phase is complete; the reviewers decide.

c. **Review gate** — execution stops here until the review returns:
   - Critical agents, one per task in the phase: check that task against its plan steps and acceptance tests using real evidence (files, test output, logs, screenshots) and score it out of 10.
   - Phase reviewer, one agent for the phase as a whole: score execution out of 10 against PLAN.md and the master plan and, if the score is low, explain why.
   - Reviewers never see the implementer's reasoning. They receive PLAN.md, LEDGER.md, and the artifacts, and they mark every ledger item closed, not closed, or regressed before raising new findings. New findings count only if they are contradictions or problems that block this phase's exit criteria.

d. **Fix and repeat**: gather all feedback into LEDGER.md, fix, and review again until the phase meets its bar — phase score at least 8/10, every task at least 7/10, no open Blocker or Major, every exit test passing. Before each re-review, sweep all changed files for superseded wording. If three review iterations fail to reach the bar, stop and bring the author the ledger summary and a diagnosis instead of looping further.

e. **Close**: update LESSONS.md and the README status; update the affected master and docs sections (numbers only in the Provisional Values Register; every design change gets a Review Decision Log row); add a Change Log row. Then start the next phase.

Working rules that apply across every step of the loop:
- Sonnet subagents write code and documents; Opus runs the critical agents and phase reviewers.
- Keep every rule and number in exactly one place.
- Send genuine design contradictions or scope changes to the author as short multiple-choice questions; never resolve them silently.
- Once the repository exists, commit documentation and implementation changes together.
- Documents never claim a phase is complete, is passed, is satisfied, or is ready; reviewers and the author decide.

## Folder contents

Each `PHASE_NN_<Name>\` folder holds five files:
- `PLAN.md` — goal; entry conditions; tasks mapped to plan IDs; step-by-step implementation for each task; exit criteria and acceptance tests taken from the Acceptance Test Matrix, fixed before work starts; predetermined failure points and risks with mitigations; which agent does what.
- `EXECUTION_LOG.md` — dated record of every action, command, file change, test run, and result.
- `FAILURE_POINTS.md` — "Predetermined" (from PLAN.md) and "Discovered during execution" (what happened, cause, fix, how to prevent it next time).
- `REVIEW.md` — every review iteration: per-task scores, phase execution score, findings, and the reasons behind any low score.
- `LEDGER.md` — every finding with status (open, fixed, deferred with owner, withdrawn), carried across iterations.

## Planning depth

`PLAN.md` for phases 00 and 01 carries full step-by-step implementation now. For phases 02-19, only the goal, entry conditions, task map, acceptance tests, and exit criteria are fixed now; the step-by-step section for each of those phases is written at phase entry, under loop rule (a), which requires reading the earlier phases' logs first.

This is a deliberate, recorded deviation from a literal reading of Prompt 1's PLAN.md contents (which lists step-by-step implementation as part of every phase's plan): writing full implementation steps for phase 19 today, before phases 00-18 have run and before their lessons exist, would not reflect what pre-implementation reading under loop rule (a) is likely to change.

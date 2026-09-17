# Phase 06 - Prototype Validation and Gate

Status: Not started; Executes: MASTER_SDLC.md > Development Phase Map > Phase 2 - Core Tension Prototype (the Minimum Playable Prototype) (part); Plan task IDs: P2.15, P2.16, P2.17, P2.18

## Goal

The Minimum Playable Prototype verdict. This is phases/README.md's phase-table row 06 outcome: "The Minimum Playable Prototype verdict." Per this phase's task instructions: P2.16 needs five external testers never exposed to any earlier build of this game and a Windows release build; P2.17 is time-boxed to at most two days; and an agent may propose the Change Log gate row's text at P2.18 but may never write it into the Change Log itself (MASTER_SDLC.md > Document Control > Gate Approval).

## Entry conditions

- Phase 05 exit criteria recorded: Upgrade effect check, Draft queue test, Draft input lockout test, Guaranteed first draft test, Encounter deferral test, Determinism test, XP cap check, Console non-pause test, Console rules test, UI scaling test, Interaction window test (scripted), Focus loss test, Movement-only test, Teaching Siege tuning check, Scrap loss test, HUD layout check, Pause authority test (full), and Run flow check all recorded (phases/README.md phase-table row 05 gate).
- Both upgrade channels (P2.11 deliverable `data/upgrades/*.tres`; P2.12 deliverable `scenes/ui/draft.tscn`; P2.13 deliverable `scenes/ui/console.tscn`) exist and are playable together.
- A full, playable run (P2.14 deliverable: `data/waves/prototype_sequence.tres`, `scenes/ui/run_end.tscn`, pause/settings menus) exists end to end, since P2.15's internal acceptance pass and P2.16's external playtest both require a complete build to run scripted tests and tester sessions against.
- Every earlier phase's own scripted acceptance tests (Phase 03 through Phase 05) are recorded, since P2.15's own exit criterion is "zero failing scripted tests" across every P-tagged test in the Acceptance Test Matrix, not only the ones first exercised at P2.15.
- An exportable Windows release build pipeline exists (P0.2 deliverable, the Settings check's own build), since P2.15's Swarm performance test and P2.16's playtest both require an exported release build, not an editor session.

## Carried lessons

phases/LESSONS.md and every earlier phase's (00, 01, 02, 03, 04, 05) EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry, per loop rule (a), and the patterns that apply to this phase - recurring failure types, estimates that ran over, tests that turned out unpassable, tools that misbehaved - are written into this section before implementation starts. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows and phases 00 through 05 have not run, so this section is a placeholder. It must be filled in with whatever those phases actually recorded before any P2.15-P2.18 work in this phase begins, with particular attention to which Acceptance Test Matrix rows Phase 03 through Phase 05 already exercised and which results they recorded, since P2.15 re-checks all of them together rather than re-deriving them from scratch.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2.15 | Internal acceptance pass | Test log in document 29; 10 fixed stills from designer-recorded runs and their answer key | Tower neglect test; Player neglect test; Split choice test; Safe corner test; Orbit test; Siege test; Standard Assault test; Entity cap test (P2.15; counts within caps, enemies within 300, across every P2.15 run); Swarm performance test (combat wave 4 as budgeted, at most 120 alive; the 300-enemy soak result stays P1.7's); Object pooling test (compares first and last combat wave); Stability check - all P2.15 | Zero failing scripted tests | 29 | M | Sonnet (implementer) |
| P2.16 | External playtest | Playtest report in document 29 | Failure clarity test; Tower relevance test; Threat visibility test; Health pool danger test; Cost of movement test; Effect density test; Audio clarity test (Tower cue); Could-not-protect-both test; Unseen death test; Two things test; Another run test; Stability check - all P2.16; Interaction window test (observed) | Prototype Success Criteria 1 to 14 pass, or the failing criterion is named with the design change it demands | 29 | M | Sonnet (implementer) |
| P2.17 | Grappling hook spike | Spike build and a recorded verdict | Grappling criteria review (P2.17, G) | All four criteria met and the spike stayed within two days, or the hook is moved to document 30 | 04 (consults 30) | S | Sonnet (implementer) |
| P2.18 | Gate decision rows | Change Log rows | Gate record check (P2.18, G) | Rows recorded per the Gate Approval rule | 29 (consults 04) | S | Sonnet (implementer) |

## Step-by-step implementation

The step-by-step section below states each task's inputs and deliverable file paths now, and names the owning document section it must follow. It is deliberately not a full walkthrough: per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once Phase 05's actual lessons exist to inform them.

### P2.15 - Internal acceptance pass

Inputs: every scripted P-tagged test run by the developer, including bots (orbit bot, roam bot, far/still Siege bots); results recorded in document 29 (external testers excluded); P2.14 deliverable (full run flow); P1.7 deliverable (fallback step adopted).
Deliverable file paths: test log in document 29 (docs/29_Milestones_and_Roadmap.md); 10 fixed stills from designer-recorded runs and their answer key.
Follows: MASTER_SDLC.md > Acceptance Test Matrix in full - every row tagged P across Core Tension Tests, Encounter Tests, Technical Tests, and Readability Tests whose "First task" column names P2.15 or an earlier prototype task - for each test's own pass condition and instrument; MASTER_SDLC.md > Minimum Playable Prototype Gate for the scope this internal pass validates before external testers are recruited. Document 29 is this task's nominal deliverable location, but as read for this plan it currently contains no Phase 2 section to record a test log or the 10 fixed stills in (only "Phase 3 - Vertical Slice", "Phase 4 - Production", and "Deferred Review Findings") - see "Open questions for the author"; until that is resolved, this task records its test log and stills reference in this folder's own EXECUTION_LOG.md and LEDGER.md as an interim location.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.16 - External playtest

Inputs: recruit 5 external testers never exposed to earlier builds, a session script, a Windows release build, telemetry CSVs collected; fresh testers on any repeat attempt (fixes excluded); P2.15 deliverable (test log); the Prototype Success Criteria.
Deliverable file paths: playtest report in document 29 (docs/29_Milestones_and_Roadmap.md).
Follows: MASTER_SDLC.md > Minimum Playable Prototype Gate > "Prototype Success Criteria" (1 to 14) for the pass/fail structure this task's report is built against; MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests and > Readability Tests for every row whose "First task" column names P2.16, each requiring a 5-tester probe (4 of 5 unless the criterion states otherwise; criterion 13's Another run test requires 3 of 5 and is gating). Document 29 has the same missing-Phase-2-section gap noted under P2.15 - see "Open questions for the author". The five testers must never have been exposed to any earlier build (including a P2.7 session, per Phase 03's PLAN.md restriction, and including any earlier P2.16 attempt on this build); the playtest runs on an exported Windows release build, not an editor session.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.17 - Grappling hook spike

Inputs: a spike of at most two days against the four Grappling Hook Evaluation Criteria (production integration excluded); P2.16 deliverable (prototype gate outcome).
Deliverable file paths: spike build and a recorded verdict (path to be fixed at phase entry).
Follows: MASTER_SDLC.md > Player Overview > "Grappling Hook Evaluation Criteria" for the four criteria this spike is scored against. Document 04 (nominal owner) and document 30 (consulted, the deferred-features document the hook is parked in on a no-go) do not yet exist as files - see "Open questions for the author". This task's own time box (at most two days) is fixed before the spike starts and is not extended regardless of how the spike is trending, per this phase's task instructions above.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.18 - Gate decision rows

Inputs: the prototype gate decision, the grappling hook go/no-go, the confirmed Performance Fallback step (slice work excluded); P2.16 deliverable (playtest report); P2.17 deliverable (spike verdict).
Deliverable file paths: Change Log rows (MASTER_SDLC.md > Change Log).
Follows: MASTER_SDLC.md > Document Control > "Gate Approval" rule in full: "Where this document says a gate is 'accepted,' 'approved,' or 'passed,' only the human designer writes that row in the Change Log naming the gate and the date; an AI collaborator may propose the row's text but may not write it into the Change Log itself." An agent implementing this task may draft the proposed row text (naming the prototype outcome, the grappling go/no-go, and the confirmed Performance Fallback Ladder step) as a reviewable artifact, and must not commit that text into MASTER_SDLC.md's Change Log under any circumstance.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

P2.15 tests (developer and scripted bots only; instrument is the Run Recorder, debug overlay, or a scripted assertion unless noted):

| Named test (Acceptance Test Matrix) | Source |
| --- | --- |
| Tower neglect test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Player neglect test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Split choice test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Safe corner test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Orbit test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Siege test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests |
| Standard Assault test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests |
| Entity cap test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests |
| Swarm performance test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests |
| Object pooling test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests |
| Stability check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests |

Plus every other P-tagged test first exercised at an earlier task (Phase 03 through Phase 05), re-checked here as part of P2.15's "zero failing scripted tests" exit criterion.

P2.16 tests (5 external tester probes unless noted; 4 of 5 unless stated otherwise):

| Named test (Acceptance Test Matrix) | Source |
| --- | --- |
| Failure clarity test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Tower relevance test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Could-not-protect-both test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Two things test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests |
| Another run test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests (3 of 5; gating per Prototype Success Criterion 13) |
| Threat visibility test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Health pool danger test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Cost of movement test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Effect density test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Unseen death test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Audio clarity test (Tower cue) | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests |
| Stability check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests (re-run across P2.16 sessions) |
| Interaction window test (observed) | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests (re-observed via tester probe, first scripted at P2.13) |

Plus Prototype Success Criteria 1 through 14 (MASTER_SDLC.md > Minimum Playable Prototype Gate > "Prototype Success Criteria"), each mapped to one or more of the tests above; criterion 14 is "every other test tagged P in the Acceptance Test Matrix" beyond the P2.16-specific ones listed.

P2.17: Grappling criteria review (MASTER_SDLC.md > Acceptance Test Matrix > Build Checks; tag G, a gate record, not a pass/fail milestone criterion).

P2.18: Gate record check (MASTER_SDLC.md > Acceptance Test Matrix > Build Checks; tag G).

Per MASTER_SDLC.md > Document Control > Gate Approval, no agent writes that any of these tests, the Prototype Success Criteria, or this phase, is passed, satisfied, met, or ready. That determination belongs to the reviewers named in "Agent assignment" for the scripted and internal-tester tests, and to the human designer alone for the accepted-gate Change Log rows. This document records what each test checks and where its result is recorded, nothing more.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Tester probes being run by anyone who already played an earlier build | P2.16 needs five external testers never exposed to any earlier build; if recruiting draws from anyone who watched or played the Phase 03 Feel check (P2.7), an internal build during the Phase 03-05 review loop, or an earlier P2.16 attempt on the same build, their reactions no longer measure a first encounter | Recruit five external testers confirmed to have had no exposure to any earlier build, cross-checked against Phase 03's EXECUTION_LOG.md P2.7 session log and any earlier P2.16 attempt's roster; any repeat attempt uses fresh testers (MASTER_SDLC.md > Acceptance Test Matrix: "fresh testers on any repeat") | A recruiting checklist recorded in this phase's EXECUTION_LOG.md before the P2.16 session runs, checked by the phase reviewer against Phase 03's log |
| Scripted bots whose behaviour does not match the test's definition | P2.15's internal acceptance pass depends on the orbit bot, roam bot, and far/still Siege bots behaving exactly as each test defines them (for example the orbit bot staying within its defined band of the Tower, the roam bot never entering the Tower Interaction Radius); a bot that drifts from its definition invalidates the test it stands in for | Implement each bot's movement rule directly from its Acceptance Test Matrix definition, and check the bot's own position trace against that definition before using it in a P2.15 run | Orbit test, Siege test, Standard Assault test, and Split choice test all depend on their named bots; any Run Recorder position trace inconsistent with a bot's definition invalidates that run |
| The swarm performance test being run in the editor instead of an exported release build | The Swarm performance test's pass condition is measured on an exported release build with V-Sync off; running it inside the Godot editor instead (faster to iterate, an easy mistake under time pressure) would record editor overhead as if it were shipped performance | Run the P2.15 Swarm performance test only against an exported Windows release build, per docs/20_Technical_Architecture.md > "Interim Prototype Technical Budgets" (the performance rule's own instrument definition) and MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Reference machine" row | This phase's EXECUTION_LOG.md entry for this test names the build artifact (export path/build hash) used, not an editor session |
| The entity cap being exceeded once every prototype system runs together | P2.15 is the first time Phase 03's enemies, Phase 04's Wave Director and Overtime finishers, and Phase 05's upgrades all run together across a full eight-wave sequence; a cap that held in Phase 04's isolated scripted spawns could still be exceeded once upgrades change Tower/player DPS and therefore Siege volume and Pressure Metric behaviour in combination | Re-run the Entity cap test across every P2.15 run (not just once), per its own pass condition, and treat any exceedance as a Phase 04 regression to fix before this phase proceeds to P2.16 | Entity cap test; debug overlay maxima logged per run |
| The grappling hook spike overruns its two-day box | P2.17 is explicitly time-boxed to at most two days; a spike that starts revealing promising integration work has an obvious pull to keep going past the box to "just finish it" | Fix the two-day box before the spike starts and stop at it regardless of how the four Grappling Hook Evaluation Criteria are trending; an incomplete-but-boxed spike still yields a recorded verdict (unmet criteria, or the hook moved to document 30) rather than an open-ended one (MASTER_SDLC.md > Risk Register: "Grappling hook consumes prototype time without shipping") | This phase's EXECUTION_LOG.md timestamps for the spike's start and stop; phase reviewer checks elapsed time against the two-day box |
| A gate row written by the wrong author | P2.18's deliverable is Change Log rows, and the Gate Approval rule reserves writing an accepted/approved/passed row to the human designer; an agent drafting the row's text under time pressure could be tempted to also commit it | An agent may propose the P2.18 gate row's text (prototype outcome, grappling go/no-go, confirmed Performance Fallback step) but never writes it into the Change Log; the proposed text is handed to the author as a reviewable draft only (MASTER_SDLC.md > Document Control > Gate Approval) | This phase's EXECUTION_LOG.md and LEDGER.md record the row as "proposed, not committed" until the author's own commit adds it; the phase reviewer checks the Change Log's authorship, not only its content |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P2.15 through P2.18). P2.15's internal-tester role (designer, scripted bots) and P2.16's five-external-tester role are distinct from the Sonnet implementer who builds the test harness, logs results, and drafts the playtest report; the testers themselves are not agents.

Opus runs one critical agent per task (four critical agents, P2.15 through P2.18) plus one phase reviewer for Phase 06 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced (test logs, the playtest report, the spike verdict, the proposed gate-row text), but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c). Per the Gate Approval rule, no critical agent, phase reviewer, or implementer writes an accepted-gate row into MASTER_SDLC.md's Change Log; only the human designer does.

## Open questions for the author

1. [Contradiction, reported, not resolved; first raised in Phase 03's PLAN.md and restated here because it directly blocks this phase's own deliverables] docs/29_Milestones_and_Roadmap.md, as it currently exists, has no Phase 2 section - only "Phase 3 - Vertical Slice", "Phase 4 - Production", and "Deferred Review Findings". P2.15's test log, P2.16's playtest report, and P2.18's Change Log rows (owner "29 (consults 04)") all name document 29 as involved, but the file's only sections are Phase 3, Phase 4, and Deferred Review Findings.
   a. Add a Phase 2 section to docs/29_Milestones_and_Roadmap.md before P2.7 needs it (retroactively, since P2.7 is in Phase 03), so P2.15/P2.16 have somewhere to write into by the time this phase runs.
   b. Record Phase 2 milestone outputs in MASTER_SDLC.md's own Change Log / Development Status instead, leaving document 29 to Phase 3 onward as its current first heading already implies.
   c. Other (please specify).
2. P2.17's owner is "04 (consults 30)"; neither docs/04 nor docs/30 exist yet, so the Grappling Hook Evaluation Criteria are cited from MASTER_SDLC.md > Player Overview > "Grappling Hook Evaluation Criteria" directly, the same pattern flagged for other unwritten owning documents in Phase 03 through Phase 05.
   a. MASTER_SDLC.md remains binding for P2.17 until 04 and 30 are written.
   b. Write stubs or working drafts for 04 and 30 before Phase 06 implementation starts, since 30 is also where a grappling no-go would park the mechanic.
   c. Other (please specify).
3. P2.16's tester roster and P2.15's internal-tester roster are both drawn from a small pool for a solo-or-small-team project; recruiting five external testers who have truly never seen any earlier build (including screenshots, video, or a hallway demo, not only a played build) may be harder to guarantee in practice than the rule assumes.
   a. "Never exposed to earlier builds" is interpreted strictly (no video, screenshots, or verbal walkthroughs either), as this plan assumes.
   b. "Never exposed to earlier builds" means never having played a build themselves; incidental exposure (a screenshot seen in passing) does not disqualify a tester.
   c. Other (please specify).

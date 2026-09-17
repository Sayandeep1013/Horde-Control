# Phase 15 - M4.3 Remaining Encounters

Status: Not started; Executes: docs/29 Phase 4, milestone M4.3; Plan task IDs: P4.3.1, P4.3.2, P4.3.3, P4.3.4, P4.3.5, P4.3.6, P4.3.7, P4.3.8

## Goal

Implement the eight encounter types the vertical slice did not need (Escort, Blackout, Breach, Ambush, Pincer, Environmental Event, Resource Rush, Swarm Crush), each closing every edge-case entry its encounter type owns in the Edge Cases and Failure States register in addition to its own exit criterion. (docs/29_Milestones_and_Roadmap.md > Phase 4 > M4.3 - Remaining encounter types)

## Entry conditions

- Phase 14 (M4.2 Biome 3) is complete under the same bar as every other phase (loop rule d), and `phases/README.md`'s phase table lists phase 14 as phase 15's dependency.
- However, every individual task in this phase (P4.3.1 through P4.3.8) carries its own Depends-on field in docs/29, and in every case it is P3.18 (the slice acceptance pass, which left the Wave Director at slice maturity), not any Phase 4 task. Phase-level sequencing after phase 14 is this folder's ordering choice, matching `phases/README.md`'s phase table row 15, not a docs/29 requirement that biome 2 or biome 3 exist first. This document does not start any P4.3.x task before P3.18's deliverable exists, and does not treat phase 14's completion as a substitute for that check.
- The standing conditions recorded in `phases/PHASE_13_M4_1_Biome_2/PLAN.md` > Standing conditions still apply; they are not restated here.

## Carried lessons

`phases/LESSONS.md` and every earlier phase's `EXECUTION_LOG.md`, `FAILURE_POINTS.md`, and `REVIEW.md` are read at phase entry, under loop rule (a) (`phases/README.md` > Loop rules). The patterns that apply to this phase are written into this section before implementation starts. As of this writing, no Phase 4 phase has yet run, so nothing is carried forward yet; this paragraph is replaced at phase entry.

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P4.3.1 | Escort encounter | Escort encounter resource and script | Composition rule test (reused) plus a scripted pass over Escort's edge cases; Escort test | Escort's edge case entries are all closed | 11 (Wave Director) | M | Sonnet subagent |
| P4.3.2 | Blackout encounter | Blackout encounter resource and script | Composition rule test (reused) plus a scripted pass over Blackout's edge cases; Blackout test | Blackout's edge case entries are all closed | 11 (Wave Director) | M | Sonnet subagent |
| P4.3.3 | Breach encounter | Breach encounter resource and script | Composition rule test (reused) plus a scripted pass over Breach's edge cases; Breach test | Breach's edge case entries are all closed | 11 (Wave Director) | M | Sonnet subagent |
| P4.3.4 | Ambush encounter | Ambush encounter resource and script | Composition rule test (reused) plus a scripted pass over Ambush's edge cases; Ambush test | Ambush's edge case entries are all closed | 11 (Wave Director) | M | Sonnet subagent |
| P4.3.5 | Pincer encounter | Pincer encounter resource and script | Composition rule test (reused) plus a scripted pass over Pincer's edge cases; Pincer test | Pincer's edge case entries are all closed | 11 (Wave Director) | M | Sonnet subagent |
| P4.3.6 | Environmental Event encounter | Environmental Event encounter resource and script | Composition rule test (reused) plus a scripted pass over its edge cases; Environmental Event test | Environmental Event's edge case entries are all closed | 15 (Biomes) | M | Sonnet subagent |
| P4.3.7 | Resource Rush encounter | Resource Rush encounter resource and script | Composition rule test (reused) plus a scripted pass over its edge cases; Resource Rush test | Resource Rush's edge case entries are all closed | 14 (Economy) | M | Sonnet subagent |
| P4.3.8 | Swarm Crush encounter | Swarm Crush encounter resource and script | Composition rule test (reused) plus a scripted pass over its edge cases; Swarm Crush test; Swarm performance test (re-run at this density) | Swarm Crush's edge case entries are all closed; the performance rule still holds | 11 (Wave Director), 20 (Technical Architecture) | M | Sonnet subagent |

## Step-by-step implementation

Every task below closes its encounter type's own edge-case entries from MASTER_SDLC.md > Encounter Types, in addition to the exit criterion named in the Tasks table. The edge-case text is quoted from the master rather than paraphrased, since it is the register entry each task must close, not a gameplay number to be cited elsewhere.

### P4.3.1 - Escort encounter

- Scope in/out: In: Escort per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable (Wave Director at slice maturity).
- Depends on: P3.18.
- Owning document: 11 (Wave Director).
- Deliverable: Escort encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Escort): the escort must never path into a hazard the player cannot clear; if the escort is destroyed, a partial reward is still granted; if the escort completes while the player is on the far side of the map, the reward still reaches the player rather than being dropped at the destination.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.2 - Blackout encounter

- Scope in/out: In: Blackout per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 11 (Wave Director).
- Deliverable: Blackout encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Blackout): a blackout must never disable the player's ability to see incoming damage; it may disable Tower weapons, minimap, drop indicators, or auto-collection, but never core threat readability; a blackout must have a visible countdown so it does not read as a bug. Also relevant (MASTER_SDLC.md > Edge Cases and Failure States > Interaction Between Systems): a blackout must never fully disable a build the player depends on, shared ownership with document 17.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.3 - Breach encounter

- Scope in/out: In: Breach per Encounter Types, including the Breach warning duration. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 11 (Wave Director).
- Deliverable: Breach encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Breach): a breach must be telegraphed before it opens, with enough warning to travel across the map (MASTER_SDLC.md > Provisional Values Register > Spawning & Waves > "On-screen spawn exceptions", Breach warning row); a breach must not open directly adjacent to the Tower; if multiple breaches open, their combined spawn rate must respect the global entity cap rather than summing freely; the breach point itself is a telegraphed spawn marker.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.4 - Ambush encounter

- Scope in/out: In: Ambush per Encounter Types, with its on-screen spawn markers. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 11 (Wave Director).
- Deliverable: Ambush encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Ambush): a mandatory telegraph window with a minimum duration and no exceptions for difficulty scaling (MASTER_SDLC.md > Provisional Values Register > Spawning & Waves > "On-screen spawn exceptions"); Ambushes must never spawn within the minimum radius rule stated there; Ambush is an on-screen spawn exception using telegraphed spawn markers; Ambushes must not fire during the Level-Up Draft or within the post-draft grace period.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.5 - Pincer encounter

- Scope in/out: In: Pincer per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 11 (Wave Director).
- Deliverable: Pincer encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Pincer): the pincer must have a visible gap at spawn so the correct answer is discoverable, not memorised; spawn positions must never appear inside the player's current position or immediate movement arc; Pincer is an on-screen spawn exception using telegraphed spawn markers under the same minimum-distance rule as Ambush.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.6 - Environmental Event encounter

- Scope in/out: In: Environmental Event per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 15 (Biomes).
- Deliverable: Environmental Event encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Environmental Event): an environmental event must never fully enclose the Tower in a hazard the player cannot cross; it must never spawn a hazard directly on the player; hazards must obey the same telegraph requirement as enemy attacks.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.7 - Resource Rush encounter

- Scope in/out: In: Resource Rush per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning document: 14 (Economy).
- Deliverable: Resource Rush encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Resource Rush): Resource Rush must never be strictly optimal or strictly worthless; an ignored rush expires cleanly with no orphaned entities left on the field; a player at maximum storage is warned before travelling to it.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P4.3.8 - Swarm Crush encounter

- Scope in/out: In: Swarm Crush per Encounter Types. Out: other encounter types.
- Inputs: P3.18's deliverable.
- Depends on: P3.18.
- Owning documents: 11 (Wave Director), 20 (Technical Architecture, for the performance re-test).
- Deliverable: Swarm Crush encounter resource and script.
- Edge cases to close (MASTER_SDLC.md > Encounter Types > Swarm Crush): Swarm Crush is named in the master as "the primary performance risk in the project"; it must respect the hard entity cap; when the cap is hit, spawning throttles rather than queueing; enemies culled for performance must never be culled from the player's visible screen area; drop volume must also be capped so the pickup layer does not become the bottleneck instead.

Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

docs/29 carries no single "M4.3 gate" line (docs/29 > Phase 4 preamble: only A-tagged tests gate the alpha, beta, and release milestones). M4.3's completion is defined by the eight tasks' Acceptance test and Exit criterion cells above, matched against `phases/README.md` row 15's Gate column: Escort test; Blackout test; Breach test; Ambush test; Pincer test; Environmental Event test; Resource Rush test; Swarm Crush test; Swarm performance test re-run.

The master's Definition Of Done For A Milestone (MASTER_SDLC.md, lines 2709-2716) applies in full to this phase:

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared - every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated.
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median >= 60 FPS, 1st-percentile >= 45 FPS) during the heaviest encounter in scope (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Performance rule"), which for this phase is expected to be Swarm Crush per its own edge-case entry.
- All acceptance tests tagged for the milestone pass.

This document does not assert that any of the above is met; reviewers and the author decide that, per loop rule (c) and the Gate Approval rule.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An eighth encounter type ships with an unclosed edge-case entry that only surfaces under a combination the scripted pass did not try | Eight independent encounter types, each with multiple edge cases, is a large combinatorial surface for one milestone; a scripted pass over each type's own edge cases does not by itself test cross-encounter combinations | Each task's scripted pass is written directly against the quoted edge-case text in the Step-by-step implementation section above, not against a paraphrase; the phase reviewer checks the register text against the scripted pass line by line before scoring the task | Critical agent for each P4.3.x task walks its encounter's edge-case entries one by one against the delivered script; any entry not demonstrably closed is a Ledger finding, not a pass |
| Content scope expands past the eight named encounter types (a new encounter idea gets built here instead of logged) | The taxonomy in MASTER_SDLC.md > Encounter Types is complete as written, but a new idea can feel like a natural ninth type while building the other eight | New encounter ideas are logged to document 30 rather than added to this phase's task list, which is fixed at P4.3.1 through P4.3.8 (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems", applied here to encounter types rather than biomes) | Phase reviewer checks that no `data/encounters/` resource exists outside the eight named types |
| The Pressure Metric oscillates once eight more encounter types are feeding it, producing escalation/de-escalation flapping that was not visible with the slice's smaller encounter set | Pressure and its escalation/de-escalation clamps were tuned and tested against the slice's encounter set (MASTER_SDLC.md > Risk Register > "Pressure Metric oscillates"); Escort and Resource Rush in particular apply pressure as opportunity cost rather than direct damage, a pattern the formula was not exercised against before | Pressure telemetry is reviewed for each new encounter type as it is added, per the existing mitigation (bounded de-escalation, minimum time between injections, throttle expiry) rather than assuming the slice's tuning transfers unchanged | Run Recorder pressure samples reviewed during P4.3.x execution, not deferred to the next scheduled playtest |
| Readability degrades because Breach, Ambush, and Pincer all introduce on-screen spawn markers with independent telegraph timings that were not readability-tested together | Each of the three on-screen spawn exceptions was designed and specified independently in MASTER_SDLC.md > Encounter Types; nothing yet exercises them appearing together at density | The Readability Hierarchy's effect-density limit and the existing telegraph-minimum rules apply to all three uniformly (MASTER_SDLC.md > Provisional Values Register > Spawning & Waves > "On-screen spawn exceptions") | Effect density test pattern applied to a scripted scene combining Breach, Ambush, and Pincer telegraphs; an unreadable telegraph under that combination is a Ledger finding even though it is not one of the eight named acceptance tests |
| Swarm Crush (P4.3.8) fails the re-run Swarm performance test at the density this encounter is specified to reach | Swarm Crush is explicitly named the project's primary performance risk, and this is the first task that must hold the performance rule under its own dedicated stress case rather than incidentally | Swarm Crush is built under the existing entity-cap and Performance Fallback Ladder architecture (MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance > "Performance Fallback Ladder"); the next ladder step is adopted and recorded if the current step does not hold | Swarm performance test run against Swarm Crush specifically, on the reference machine, before P4.3.8 is marked ready for review |
| Documentation drift: eight new encounter types are added to doc 11 without a matching commit, or doc 15's Environmental Event addition is not reflected in the relevant biome's own addendum | Eight parallel Sonnet subagents working through this phase's tasks increases the chance that at least one implementation commit lands without its matching document update | Every commit that changes an encounter's implementation also changes its owning document (doc 11 for most, doc 15 for Environmental Event, doc 14 for Resource Rush) in the same commit (MASTER_SDLC.md > Risk Register > "Documentation drifts from implementation") | Phase reviewer's pre-re-review sweep (loop rule d) checks each task's commit for a matching document change |

## Agent assignment

Sonnet subagents implement and write every task above. Opus runs one critical agent per task (P4.3.1 through P4.3.8) plus the phase reviewer for M4.3 as a whole. Reviewers receive `PLAN.md`, `LEDGER.md`, and the artifacts each task produced, but never the implementer's reasoning, per loop rule (c) (`phases/README.md` > Loop rules).

## Open questions for the author

1. docs/29's Deferred Review Finding P13 records that tester-probe pass conditions were moved out of most Phase 3-4 build tasks, but P4.1.2/P4.2.2/P4.1.6/P4.2.6's tester-probe exit criteria were flagged as a remaining exception to close "by Beta gate (P4.6.5)". None of the M4.3 tasks in this phase carry a tester-probe exit criterion of their own (all eight rely on scripted edge-case passes and named A-tagged tests). Should this phase's tasks be read as already compliant with P13, or does P13 still apply to something in this phase not currently visible in docs/29's table? (a) Phase 15 is already compliant, no action needed (b) Re-check P13 explicitly during this phase's review (c) Other.
2. Swarm Crush's exit criterion requires "the performance rule still holds," but the minimum-spec machine this must eventually also hold on (P4.6.4) is not decided until P4.6.0, three phases later. Should P4.3.8 record its performance result only against the reference machine now, with a minimum-spec re-check scheduled explicitly for after P4.6.0, or held open until then? (a) Reference-machine result now, minimum-spec re-check scheduled for P4.6.4 (b) Hold P4.3.8 open until minimum spec is decided (c) Other.

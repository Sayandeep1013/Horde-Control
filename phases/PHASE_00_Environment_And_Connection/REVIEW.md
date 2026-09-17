# Phase 00 - Review

Reviewers decide whether this phase meets its bar; this file records every review iteration in full. No entry here states that a gate is passed, satisfied, met, or ready - that determination belongs to the designer under the Gate Approval rule.

## The bar

Phase execution score at least 8/10; every task at least 7/10; no open Blocker or Major; every exit test passing. Three review iterations that fail to reach the bar stop the loop and bring the author the ledger summary and a diagnosis instead of looping further.

## Iteration 1 - 2026-09-17

Seven blind Opus reviewers: one critical agent per task, plus a phase reviewer. Each received PLAN.md, LEDGER.md and the artifacts, and none saw the implementer's reasoning.

| Plan ID | Score /10 | Verdict | Findings that drove the score |
| --- | --- | --- | --- |
| P0.1 | 7 | Accept with fixes | Three Majors: the GitHub remote crossed the task's declared Out boundary with no decision row; the export_presets.cfg reversal contradicted PLAN.md with no decision row; .claude/settings.local.json, granting all six restricted tools, was excluded only by a machine-global ignore file outside the repository. Every countable claim reproduced exactly |
| P0.3 | 6 | Accept with fixes | One Major: 25 generated stubs carried a Status sentence citing Document Control for a rule it does not state. Minors: docs/29's circular Owns referent; the spot-check covered 3 of 26 files; FAILURE_POINTS left empty |
| E0.1 | 5 | Accept with fixes | No fallback named; the CLI carried zero failure modes while P0.7 is bound to it; evidence cited at a session-temp path; matrix row 8 marked PASS on half its question; the audit's open risks never reached the deliverable |
| E0.2 | 5 | REJECT | The verification exercised an E0.1 capability rather than the skill's; docs/28 recorded neither the verification result nor the security read; the security read lived only in a temp directory; two author decisions landed with no Review Decision Log row |
| P0.2 | 6 | Accept with fixes | The Settings check passed on a project with its display block deleted and move_up rebound; five of seven pinned settings absent from project.godot; the check runs against the source project, not the exported build the matrix names |
| P0.5 | 5 | Accept with fixes | A required deliverable element (E0.2's verification result) absent and undisclosed; an internally wrong clause on a security control; game_multiplayer's all-interfaces bind undocumented; no way to check the pin still holds |
| **Phase** | **6** | Accept with fixes | Plan order inverted without a recorded departure; FAILURE_POINTS never maintained; CLAUDE.md left asserting no Godot project exists. Escalation discipline and ledger honesty singled out as the phase's strongest features |

Outcome: below the bar on every count. Iteration 1 fix pass applied; see EXECUTION_LOG rows dated 2026-09-17 and 2026-09-18.

## Iteration 2 - 2026-09-18

Deviation from the loop, recorded rather than hidden: iteration 2 used two reviewers - a blind closure verifier and a phase reviewer - instead of one critical agent per task. The argument was that re-review is a narrower job, since the loop requires reviewers to mark each ledger item closed, not closed, or regressed before raising new findings. The phase reviewer was explicitly asked to rule on whether that deviation weakens the gate.

### Closure verifier - REJECT, 4/10

Adjudicated 17 items: 13 closed, 1 closed with caveat, 1 partially closed, 2 not closed. No regressions.

| Item | Verdict |
| --- | --- |
| F-01 stub line breaks | Closed, 31/31 re-derived independently |
| Fabricated Status sentence | Closed, zero hits repository-wide |
| docs/29 circular referent | Closed |
| F-02 / F-04 MCP pins | Closed, both shas and both node command lines confirmed |
| F-03 recorded features | Closed, but the assertion tests containment, not equality |
| F-05 .gdignore and clean export | Closed, pack free of MCP code |
| F-06 / F-06b | Closed, deny list and residual statement accurate |
| F-07 coding-solo demoted | Closed |
| **F-08 input injection** | **NOT CLOSED - root cause falsified, see Blocker below** |
| **F-10 Settings check** | **PARTIALLY CLOSED - five material breakages still pass** |
| F-11 / F-12 gdUnit4 | Closed |
| Evidence paths | Closed, four files tracked |
| docs/20 + Risk Register + docs/28 | Closed, all three agree |
| D79 / D80 / D81 | Closed, each names a real alternative |
| CLAUDE.md sweep | Closed |
| P0.2-before-E0.1 departure | Closed |
| **FAILURE_POINTS discovered table** | **NOT CLOSED** |

Blocker raised: F-08 was marked fixed on a mechanism nobody tested. The reviewer disproved it on the pinned engine and pointed at the server's own source, checked out in this repository, which explains the observation in thirty readable lines. The rule derived from the false mechanism was binding on P2.15 in both the ledger and a 1.0.0 document.

Response: upheld, not argued. The mechanism was re-tested directly against the running game and the ledger rewritten from the tested result. See EXECUTION_LOG, 2026-09-18.

### Phase reviewer - 6/10, accept with fixes

Re-scored every task from disk at commit f4f0062, before iteration 2's later fixes landed.

| Plan ID | Iteration 1 | Iteration 2 | Movement |
| --- | --- | --- | --- |
| P0.1 | 7 | 8 | Corrections applied cleanly; every countable claim reproduced |
| P0.3 | 6 | 8 | Fabricated Status sentence properly corrected and verified against the master |
| E0.1 | 5 | 6 | Matrix strong; its own log rows still cited dead scratchpad paths |
| E0.2 | 5 | 6 | Re-verification through gdUnit4 called the best decision in the phase; left docs/28 self-contradicting |
| P0.2 | 6 | 6 | Check rewrite good; the acceptance test still did not exercise the artifact its own criterion named |
| P0.5 | 5 | 6 | Known Limitations precise; document contradicted itself on the one command P0.7 takes from it |
| **Phase** | **6** | **6** | Below the bar of 8; four tasks below the bar of 7 |

Ruling on the reviewer-count deviation, which this phase asked for explicitly: NOT DEFENSIBLE as applied. The loop fixes headcount in the sentence above the one cited to justify the cut, and the reviewer named five per-task defects that a per-task agent would have caught - the Settings check not exercising its named artifact, docs/28 contradicting itself, E0.1's dangling evidence pointers, E0.2's un-revisited pack justification, and the master edited outside its own versioning rule. It also noted the deviation was never recorded. Both points upheld: the deviation is now decision D83, and the narrowing is permitted only when decided in advance and written down.

Five new problems the fix pass itself introduced, all since addressed: the docs/28 gdUnit4 self-contradiction; a date sweep claimed complete that left four wrong dates; evidence repointed in the derived document but not in the primary record; the master edited past its own version bump; and the superseded falsification story left standing in LESSONS and docs/28.

## Outcome

Phase 00 did not reach its bar in either iteration. The substance is sound and independently reproduced - pins verified live, the export clean, the Settings check falsified ten ways, the Known Limitations re-derived from source - but four tasks sit below 7 and the phase sits below 8. Whether that is acceptable to close on is the designer's decision under the Gate Approval rule, not this file's.

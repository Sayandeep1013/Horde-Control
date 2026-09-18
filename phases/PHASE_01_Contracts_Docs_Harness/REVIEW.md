# Phase 01 - Review

Reviewers, not this document, decide whether the phase meets its bar.

## Iteration 1

Review pace set in advance by decision D83 and recorded before the gate convened: P0.4 is documentation and took a spot-check rather than a critical agent; P0.6 and P0.7 are code and took one critical agent each; one phase reviewer scored the phase as a whole. Every reviewer received PLAN.md, LEDGER.md and the artifacts, was told to treat the implementers' evidence reports as claims to verify rather than as evidence, and was instructed to mark every ledger item closed, not closed, or regressed before raising anything new. No reviewer saw an implementer's reasoning or transcript.

| Plan ID | Score /10 | Findings | Reasons for any low score |
| --- | --- | --- | --- |
| P0.4 | 7 | 2 Major (F01-11, F01-12), 6 Minor (F01-13, F01-14) | At the task bar but not above it, and carrying two Majors the phase bar does not permit to stay open. The documents' content held up better than their warrant: all 20 Register citations resolve to real rows with titles matching character for character, and both of doc 01's uniqueness claims survived a whole-file search. What pulled the score down was an exemption rule that did not exist being cited for a carve-out, and a binding precedence order asserted with no decision row behind it |
| P0.6 | 8 | 2 Major (F01-15, F01-16), 10 Minor + 1 observation (F01-17, F01-08) | At the phase bar. Conformance came back clean on an exhaustive check: zero missing required fields, zero unrequired fields, all 28 enums exact member-for-member and in order, every shared struct typed once. Seven of eight fixed-in-advance conventions followed exactly. The two Majors are about the *instrument*, not the schemas - the Schema check could not detect a field the schema never declared, and one field duplicated a Register-owned number that the samples had already drifted on |
| P0.7 | 6 | 2 Major (F01-18, F01-19), 5 Minor (F01-20 to F01-23) | Below the task bar of 7. The harness itself is sound - all four exit codes reproduce, `project.godot` is genuinely untouched, the layout isolates pass from fail, and the export-hygiene finding was the implementer's own, beyond its brief. What failed is that Carried Lesson 1 was applied thoroughly to P0.6's Schema check and not at all to P0.7's runner: the engine's exit codes were falsified, but the script consuming them never was, and it reported PASS after executing zero tests on two separate paths. The second Major is against the orchestrator, not the implementer |
| Phase | 8 | 2 Major (F01-24, F01-25), 5 Minor (F01-21, F01-26 to F01-28) | At the bar, with no Blocker. Three of four gate requirements met and verified independently; the fourth met only in its prohibition half. The phase reviewer tested 14 factual claims from the record and 13 reproduced exactly, several by a different method than the one recorded. It found one overclaim and seven instances of deliberate under-claiming |

**Bar not met at iteration 1**: the bar allows no open Major, and iteration 1 raised eight across the four reviews.

### What the gate was worth

Every one of the four reviewers went beyond its brief in a way that changed the outcome, which is the argument for the pace D83 sets. The P0.4 reviewer resolved all 20 Register citations rather than the 6-8 asked. The P0.6 reviewer independently falsified the Schema check four ways and found two gaps *before* reading that the implementer had already disclosed them. The P0.7 reviewer reproduced, in two minutes and without deleting anything, the exit code this project had twice recorded as unreproducible. The phase reviewer found a structural defect in the ledger - a missing column - that nobody reading the prose would have noticed.

Two of the eight Majors are against the orchestrator rather than any implementer (F01-10, F01-11), and a third (F01-19) falsified reasoning the orchestrator had written into the ledger. That is recorded here so a later reader does not attribute them to the implementers.

## Iteration 2 - fixes applied

Every Major from iteration 1 is now fixed or deferred with an owner, and the Minors are fixed, recorded, or routed. The substantive changes:

- **F01-15** the Schema check now carries a hand-written required-field manifest, independent of the scripts. Falsified three times, once by the orchestrator on a field the fix implementer had not touched: deleting an `@export` now fails the check naming both the MASTER field and the missing export, where before it left the check green.
- **F01-16** the duplicated merge radius is gone, replaced by resolution from the Economy Configuration. Only one such value now exists in the sample set, so the drift the reviewer found is structurally impossible rather than merely corrected.
- **F01-18** the runner script was rewritten with three guards and falsified four ways. It no longer reports PASS after executing zero tests.
- **F01-19 / F01-04** exit code 1 reproduced, and the false reasoning in the ledger corrected in place rather than quietly replaced.
- **F01-25** LEDGER.md rebuilt with its Status column present on all 28 rows.
- **F01-11, F01-12, F01-09** settled by author decisions D88, D89, D90 and D91.
- **F01-24** the "Phase 0 accepted" row is deliberately not proposed, and the reason is now on the record.
- **F01-02** deferred with the author as owner: there is no fix available from this project's side, and the author has twice decided against the only control that works.

**This document does not assert that the bar is met.** Loop rule (d) requires a re-review after fixes, and the artefacts changed substantially: the Schema check, the runner script, the ledger, four documents, CLAUDE.md and the master. A re-review is the next step, and the sweep for superseded wording that loop rule (d) requires before it has been run.

One process finding applies to that re-review. F01-27 records that implementation continued after iteration 1's gate was convened, so its reviewers were briefed on a tree that then moved under them. Iteration 2's changes were all made after every iteration 1 reviewer had reported.

## The bar

- Phase score at least 8/10.
- Every task at least 7/10.
- No open Blocker or Major finding in LEDGER.md.
- Every exit test in PLAN.md > Exit criteria and acceptance tests passing.

Three failed iterations stop the loop and bring the author the ledger summary and a diagnosis, per phases/README.md loop rule (d). Iteration 1 is the only completed iteration so far.

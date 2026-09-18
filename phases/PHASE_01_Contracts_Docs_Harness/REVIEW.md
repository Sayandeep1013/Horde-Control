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

## Iteration 2 - re-review

The same four reviewers' roles were re-run against the fixed artifacts, at the pace D83 fixes. Each was given its predecessor's report as the standard to check against, and told to verify by doing rather than by reading.

| Plan ID | Score /10 | Change | Findings | Reasons |
| --- | --- | --- | --- | --- |
| P0.4 | 7 | = | 1 Major carried (F01-12 half-closed), 1 Major newly introduced by a fix (F01-29), 3 Minor (F01-30) | Same number, different composition. The quality moved up - D91 and D88 both hold, and the reviewer judged the circularity fix "removed, not relocated" - but a fix aimed at numbers-rule fidelity broke a citation, in a phase whose strongest single result had been that all 20 citations resolved. The carried half was the enforcement mapping, which no decision row covered and one leg of which the master does not support |
| P0.6 | 9 | +1 | 4 Minor, 3 observations, no Major | Both Majors closed and verified by execution rather than reading. The manifest was falsified on four contract fields nobody had used and on the one derived field; the merge-radius fix was proved by running the resolution, including under the Fallback-Ladder escalation it had previously been beyond reach of. Held below 10 by two residuals of the same Major one level down: the manifest stops at the contract level, and the type-comparison half was never addressed under a row that read "fixed" |
| P0.7 | 7 | +1 | 1 Major (F01-36), 4 Minor | Thirteen of fifteen attacks survived, but the zero-test guard added this iteration was written in the negative form when iteration 1 had prescribed the positive one, and it fails open whenever stdout is lost. The reviewer also ran `runtest.cmd` rather than reading it and proved a docs/28 claim exactly backwards - the third recurrence in this phase of the rule about untested causes |
| Phase | 7 | -1 | 1 Major (F01-41), 6 Minor | A drop against better artifacts, and the reviewer's reason is the finding: a 9-quality artifact set held down by a 5-quality gate process. Every one of the eleven claims it tested reproduced, including the Provisional Values Register being genuinely untouched. What pulled it down is that loop rule (c) was broken continuously while it reviewed - five edits landed in the live tree, one gave it a false failure, and no reviewer was told - and that three of the phase's newest LESSONS rows were violated during the gate that wrote them |

### What iteration 2 established

Two things are worth separating, because the scores blur them.

**The artifacts held up.** Across both iterations the reviewers found zero missing and zero unrequired contract fields, all 28 enums exact, no shared struct typed twice, all four harness exit codes reproducible, the export pack clean against every excluded path, the gdUnit4 hash reproducing character for character across four clones at different line-ending settings, and the Provisional Values Register untouched. Every factual claim the phase recorded was tested by some reviewer, and all but one reproduced; the exception was corrected in place with the original left legible.

**The process did not.** Every Major raised at iteration 2 was against the orchestrator rather than an implementer: a guard written in the weaker of two forms after the stronger had been specified, a citation broken while fixing citations, a finding read as one claim when it was two, and a review gate conducted over a moving tree. Counting both iterations, **nine of the sixteen Majors were caused by the orchestrator**: F01-10 a delegation scope that contradicted a decision taken minutes earlier; F01-11 a rule invented in a prompt and then cited as if it were project policy; F01-19 a cause written into the ledger without an experiment; F01-24 a gate requirement simply not done; F01-25 a ledger whose Status column did not exist; F01-29 a citation broken while fixing citations; F01-36 a guard written in the weaker of two forms after the stronger had been specified; F01-41 a review gate run over a moving tree; and F01-47 an integrity check that could not fail. The remaining seven are implementer defects or inherited environment. That count was itself first written as "ten" from a keyword search that confused rows the orchestrator *fixed* with rows it *caused*, and corrected by listing them. The implementers' work has been more reliable than the supervision of it, which is the argument for a blind gate rather than against one.

The sharpest single observation came from the phase reviewer: a lesson in this project is reliably applied to the artifact it was learned on and reliably **not** generalised one artifact over. Iteration 1 found that pattern in P0.7 - falsification applied thoroughly to the schema check and not at all to the script consuming its exit codes. Iteration 2 found the same pattern one level up, in the gate itself. That observation is now in LESSONS.md as a caution about how to read LESSONS.md.

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

Iteration 2's own findings were then fixed in turn: the runner's guard rewritten in the positive form and falsified against both fail-open reproductions; the broken citation corrected; D92 and D93 recorded with the master raised to 0.8.5; the author-owned rows carried into `NEXT_SESSION.md`; F01-02's absolute negative claim replaced with what is established plus the untested option it had dismissed; and the README row stopped assessing the phase's own gate.

One further finding was raised by the orchestrator against itself and is recorded as F01-47: the ledger-integrity check it had been running, and twice reported to the author as evidence the bar was clear, tested the wrong column and could not have failed. Rewritten to derive its column positions from the header, and falsified against a planted open Major before being believed.

**This document does not assert that the bar is met.** Loop rule (d) requires a re-review after fixes, and the artefacts changed substantially: the Schema check, the runner script, the ledger, four documents, CLAUDE.md and the master. A re-review is the next step, and the sweep for superseded wording that loop rule (d) requires before it has been run.

One process finding applies to that re-review. F01-27 records that implementation continued after iteration 1's gate was convened, so its reviewers were briefed on a tree that then moved under them. Iteration 2's changes were all made after every iteration 1 reviewer had reported.

## Iteration 3 - re-review on a frozen tree

The tree was committed and tagged `phase01-review-iter3` at `8145333` before the gate opened, and no edit of any kind was made until all four reviewers had reported. This was the fix for F01-41, the Major raised at iteration 2, and it is the first iteration in which it held.

| Plan ID | Score /10 | Change | Findings | Reasons |
| --- | --- | --- | --- | --- |
| P0.4 | 8 | +1 | 1 Major (F01-50), 2 Minor (F01-56) | Both iteration 2 Majors closed. The reviewer resolved **all 30** citations rather than a sample, against a section-to-row map re-derived from the Register's own headings, and all 30 resolve - the property iteration 1 established and iteration 2's fix broke. The remaining Major is that document 01 undercounted its own inferred legs, graded Major because it is the third consecutive iteration in which a fix for that finding shipped with an inaccuracy about the same mapping |
| P0.6 | 9 | = | 2 Minor, 1 observation (F01-48, F01-49) | The instrument went from protecting none of the struct sub-fields to 108 of 111, verified on ground nobody had used, and the manifest is one-to-one with docs/20 in both directions. Held rather than raised because the one class left out was left out on a premise a single search of the master refutes, and because the implementer's own request to escalate it never became a row |
| P0.7 | 8 | +1 | 1 Major (F01-52), 4 Minor (F01-53) | Twenty-one attacks, no false green: forged binaries, a truncated anchor, a read-only pre-seeded log, concurrent runs, a Turkish locale, and a clean checkout with no cache all handled correctly. The Major is the mirror image of the one it replaced - the guard that stopped the script reporting success wrongly was scoped too widely and stopped it reporting 103 and 1 correctly |
| Phase | 8 | +1 | 0 Major, 7 Minor (F01-54, F01-55, F01-56) | The freeze held, verified at seventeen sampled moments. The reviewer reconstructed F01-47's bug independently, built its own corrected ledger check, **falsified it four ways**, and arrived at the same nine-of-sixteen Major attribution the record claims - calling the count "accurate and, if anything, conservative". Eleven claims tested, eleven reproduced |

### What iteration 3 changed

Iteration 2's judgement was "a 9-quality artifact set held down by a 5-quality gate process". Its successor recorded that as no longer true: the tree was frozen by a mechanism rather than an intention, and it held for every reviewer. What remained was record hygiene and provenance.

The most serious finding was not about the artifacts at all. Decision **D92 carried the label "Author decision" and had never been put to the author** - written by the orchestrator in response to a reviewer finding, with the label applied reflexively. The record's own precision is what exposed it: consultations are logged for D84-D87 and D88-D91, and D92 and D93 had none. It matters because D93, its neighbour, is the row discharging the gate requirement whose substance was that an agent had decided something on the author's behalf. Put to the author at iteration 3, who kept the substance and corrected the label; the log now records D93's genuine consultation and D92's absence of one.

Two findings landed in the same place for the third time. Document 01's inferred-leg count was wrong again, in the third successive fix for the same finding. And `LESSONS.md`'s own table was broken by blank lines so that nine of its rows rendered detached from the header - the third recurrence of the ledger-structure defect class, in the file that holds the lesson about it, because the widened structural check from F01-34 was run against one file and not the others. The phase's own trailer - that a lesson is reliably applied to the artifact it was learned on and reliably not generalised one artifact over - describes the body of the file that states it.

### Iteration 3's findings, fixed

Every Major from iteration 3 is fixed and falsified: the runner's guard rescoped so all four exit codes are distinguishable again, proven with shims returning each code; the temp-file dependency removed at the root, so an unwritable TEMP no longer turns a passing suite into a failure; `BandedValue` mapped from D87 and falsified on both cases the reviewer showed passing; the inferred-leg count corrected in document 01, D92 and the Change Log; D92 relabelled; and the LESSONS table repaired and verified contiguous.

Regression after all of it: Settings check 0, Schema check 0, harness 0 and 100, doc lint clean, no banned vocabulary in documents 00-02.

## The bar

- Phase score at least 8/10.
- Every task at least 7/10.
- No open Blocker or Major finding in LEDGER.md.
- Every exit test in PLAN.md > Exit criteria and acceptance tests passing.

Three failed iterations stop the loop and bring the author the ledger summary and a diagnosis, per phases/README.md loop rule (d). Two iterations are complete. A third would be the last before loop rule (d) requires stopping and bringing the author a ledger summary and a diagnosis instead of looping further.

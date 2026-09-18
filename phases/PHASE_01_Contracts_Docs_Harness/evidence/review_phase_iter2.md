# Phase 01 - Phase Reviewer Report, Iteration 2

Blind re-review of Phase 01 (Contracts, Core Documents, Harness) against
`phases/PHASE_01_Contracts_Docs_Harness/PLAN.md`, `phases/README.md` (phase-table row 01 and
the Loop rules), `phases/LESSONS.md`, `CLAUDE.md`, and `MASTER_SDLC.md`, plus iteration 1's
report at `evidence/review_phase.md`.

Reviewed: 2026-09-18, against commit `fb59d41` ("Phase 01: contracts, documents 00-02, gdUnit4
harness, and review iterations 1-2"). Unlike iteration 1, this phase's work is now committed, so
every check below could be run against a fixed tree rather than a moving one.

The reviewer did not see the orchestrator's or the implementers' reasoning, and did not consult
the parallel per-task critical agents re-reviewing P0.4, P0.6 and P0.7.

This report does not state that any gate is passed, satisfied, met, or ready. That determination
belongs to the reviewers scoring evidence and, finally, to the author under MASTER_SDLC.md >
Document Control > Gate Approval.

**A note on method, which became a finding.** The working tree was *not* clean during this review,
and it did not stay still. At 07:30:32 a parallel critical agent renamed
`WaveDefinition.get_spawn_budget()` to `get_spawn_budget_RENAMED` as its own falsification, and my
first Schema check run consequently exited 1. Rather than report that as a phase defect, I
reconstructed the committed state in the session scratchpad (`git archive HEAD`, plus
`git show HEAD:src/data/wave_definition.gd` over the one dirty file) and ran every check there.
**Every result in §3 is against the committed tree, not the live one.** Between 07:37 and 07:41,
while this review was open, `LEDGER.md`, `docs/01`, `docs/02` and `MASTER_SDLC.md` were all
modified in response to a parallel reviewer that had just reported. This is finding **PR2-05**,
and it is the reason §6's answer to "absorbed or merely recorded" is not the one I first wrote.

---

## 1. Gate-requirement table (phases/README.md, phase-table row 01)

| # | Gate requirement | Verdict | Evidence checked |
| --- | --- | --- | --- |
| 1 | **Schema check (P0.6)** | **Met** | Re-run against the committed tree: exit **0**. Output reproduces the record verbatim - `Pass 1 (script load): PASS (54 scripts under src/data/ loaded and instantiated with zero errors)`, all eleven contracts PASS individually, `Schema check: PASS (11 contracts validated, 0 problems)`. I also falsified it twice on artifacts **the record never touched**: deleting `@export var camera_exclusion_margin_px` from `src/data/director_configuration.gd` produced exit 1 and `Director Configuration: MASTER field "Camera exclusion margin." has no matching @export "camera_exclusion_margin_px" on the schema (REQUIRED_FIELD_MANIFEST)`; blanking element **[1]** of `wave_definition_sample.tres`'s intent mix produced exit 1 and *two* named problems, the element-index default and the proportions-sum domain rule. Both restored. The manifest's field strings are verbatim MASTER bullets (MASTER_SDLC.md lines 2277 and 2431 match character for character), so it is genuinely independent of the scripts |
| 2 | **Harness check (P0.7)** | **Met** | All four exit codes reproduced independently, three on the committed tree (**0** passing suite, **100** failing suite, **103** passing suite without `--ignoreHeadlessMode`) and the fourth on a `git archive` copy with no `.godot` cache: exit **1**, `SCRIPT ERROR: Parse Error: Could not find type "GdUnitTestCIRunner" in the current scope.` An `--import` pass on that same copy then exits 0 and the suite exits 0, confirming the record's claim that a fresh CI checkout recovers. I also falsified `tests/run_tests.ps1` on both paths that made it a Major: with `$LASTEXITCODE` deliberately seeded to 0 and a nonexistent `-GodotPath`, exit **1** naming the cause; with `-TestPath res://tests/harness/typo_does_not_exist`, gdUnit4 printed `No test cases found, abort test run!` and `Exit code: 0` and the guard still exited **1** |
| 3 | **Doc lint clean on documents 00-02** | **Met, after a mid-review repair** | A grep for `TBD`, `TODO`, `placeholder`, `[to be`, `XXX`, `FIXME`, `<fill` over all three documents returns nothing. All three are at 1.0.0. At 07:33 a word-boundary grep for the banned gate vocabulary returned a hit introduced by iteration 2's own F01-13 fix: `docs/01_Design_Pillars.md:54` read "between two features that have both already **passed** that gate". I raised it; the parallel P0.4 reviewer raised it independently as F01-30, and it was reworded at 07:39. A re-run of the same grep over documents 00-02 now returns nothing. The substantive point stood either way - the phrase described a design test applied to a game feature, not a project review gate - but `EXECUTION_LOG.md` line 32's lint claim ("No banned gate wording ... in any of the three") was false in the interim. See PR2-01, now resolved |
| 4 | **The master's "Phase 0 accepted" row proposed to the author, never written by an agent** | **Prohibition half met; affirmative half discharged by the alternative iteration 1 itself offered, not by a proposal** | The prohibition holds absolutely. `git show HEAD -- MASTER_SDLC.md` is +12/-1, and the three hunks sit at lines 2 (version 0.8.3 to 0.8.4), 62 (one Change Log row) and 3484 (decisions D84-D91). No accepted, stable or gate row was written by any agent. The affirmative half is still not a proposal - a repo-wide grep finds "Phase 0 accepted" only in statements of the requirement. What changed is that `EXECUTION_LOG.md` now carries a dated row giving the reason for withholding. **Iteration 1 explicitly named this as an acceptable close: "Cheap to close: propose the row's text to the author, or record why it is being withheld until Phase 00's closure is decided."** The phase took the second route verbatim. I therefore do not re-raise this as a Major; the residual gap is that the author was never actually told (PR2-02) |

---

## 2. Disposition of every iteration 1 finding

### F01-24 (Major) - the unproposed "Phase 0 accepted" row

**Is the reasoning sound?** Partly. The premise as written - "Phase 01 covers only three of
Phase 0's tasks" - is true but argues the opposite of what it is used for. `phases/README.md`
row 00 covers E0.1, E0.2, P0.1, P0.2, P0.3 and P0.5; row 01 covers P0.4, P0.6 and P0.7. Between
them they are the whole of the master's Phase 0, so row 01 is the *completing* phase, which is
precisely why the requirement was placed on it.

The second half of the argument is strong and, in my judgement, decisive: Phase 00 executed six
of the nine tasks, its own review scored it 6/10 against a bar of 8 with four tasks below the
task bar, and `phases/README.md` row 00 records its closure as "the designer's decision under
the Gate Approval rule". An agent proposing "Phase 0 accepted" today would be proposing
acceptance of work whose own phase did not reach its bar. Withholding is the defensible position,
and it is now on the record with a date and a reason instead of being silently absent.

**Does recording it satisfy the requirement, or does the gate still want a proposal?** On the
strict text of `phases/README.md` row 01, the gate wants a proposal and there is not one. But
iteration 1 - the reviewer that raised this finding - named "record why it is being withheld"
as an equally acceptable close. The phase did exactly that. Holding it open now would be moving
the goalposts, and I decline to. **Disposition: acceptably discharged on iteration 1's own
stated terms.** The ledger status "recorded" is honest about what happened.

Two residual gaps, carried below as Minors rather than re-raised as a Major: the withholding is
an agent decision about a stated gate requirement and carries no Review Decision Log row,
although the phase took eight author decisions in the same two days and had an open channel; and
the author is nowhere told (PR2-02).

### F01-25 (Major) - LEDGER.md's missing Status column

**Fixed, verified mechanically - then reopened as a defect class while this review was open.**
As of 07:24, `awk -F'|' '/^\|/ {print NR": "NF-2}'` over `LEDGER.md` returned **7 for every one of
the 30 table lines** - header at line 9, separator at 10, and 28 data rows at lines 11-38, with no
6-column row anywhere. The specific defect iteration 1 raised is genuinely and completely fixed.
At 07:39 two further rows were appended *outside* the table, which is the same class of defect
arriving by a different route and is raised separately as **PR2-07**; it does not retract this
disposition. The same check over the
other record files: `EXECUTION_LOG.md` 5 columns on all 43 lines; `FAILURE_POINTS.md` 4 on all 12;
`REVIEW.md` 4 on all 6; `PLAN.md` internally consistent per table (3, 8, 3, 4, 4). No malformed
row in the phase record.

**Are the Status values meaningful?** Yes. Extracted mechanically, the 28 rows carry eleven
distinct values, and every one of them says something a reader can act on: `fixed` (8),
`closed` (4), `open` (3), `recorded` (3), `fixed, verification outstanding`, `deferred, owner the
author`, `closed as a record`, `open, owner the author`, `closed as a standing fact`, `closed on
substance`, `fixed, two deliberately not`. These are not decorative - `fixed, two deliberately
not` on F01-17 and `closed on substance` on F01-10 each flag a real qualification that the
Resolution column then explains, and I confirmed both qualifications are accurate.

One nit: the file's own header declares five statuses (`open, fixed, closed, deferred with owner,
withdrawn`) and the rows use eleven. Most are informative refinements of a declared status. One,
**`recorded`**, maps to no declared status at all, and it sits on three rows including the Major
F01-24. That matters only because `phases/README.md` now asserts "no open Blocker or Major
remains", a claim that depends on reading `recorded` as closed. See PR2-03.

### F01-21 (Minor) - docs/28 has no Change Log section; master version bump

**Partly closed, honestly left open.** The master half is closed: `MASTER_SDLC.md` is at 0.8.4
with a Change Log row that names all eight decisions and explicitly states "document 28 was
raised to 1.1.0 for D86", which is a reasonable discharge of D86's "Change Log row" half. The
docs/28 half is not: I enumerated all sixteen headings in `docs/28_AI_Development_Workflow.md`
and **there is still no Change Log section**, and the gdUnit4 licence is still unrecorded there
although `addons/gdUnit4/LICENSE` is now committed. The ledger keeps F01-21 at `open`, Minor,
which is the honest status and more conservative than it needs to be.

### F01-26 (Minor) - the "doc 02 carries no numerals at all" overclaim

**Fixed, and fixed in the right way.** `EXECUTION_LOG.md` line 32 now carries the original
sentence plus a dated, labelled in-place correction naming the finding, the falsifying artifact
and why the substance survives. The row was not quietly rewritten - the superseded claim is still
legible, which is the pattern iteration 1 praised elsewhere in this phase.

### F01-27 (Minor) - implementation continuing after gate-open

**Recorded, and the underlying behaviour corrected.** `REVIEW.md` states that "Iteration 2's
changes were all made after every iteration 1 reviewer had reported", and the git history
supports it: the phase committed at 07:27:27, before this review began. Nothing implementation-
side moved under me. A `LESSONS.md` row now carries the rule. The one thing that *did* move was a
parallel reviewer's own falsification (see the method note above), which is a different problem -
PR2-05.

### F01-28 (Minor) - PLAN said EXECUTION_LOG, output went to evidence/

**Recorded, accepted honestly.** The ledger row states the deliberate reason (three concurrent
implementers would have raced on one log file), states plainly that "the plan said one thing and
the phase did another without saying so, which is the finding", and leaves it at `recorded`
rather than claiming a fix. That is the correct handling of a departure that is defensible but
was undocumented at the time.

---

## 3. Claims tested against reality

Eleven checks against the committed tree. **All eleven reproduced.** Several were run by a
different method than the one recorded, and two were falsifications on artifacts the record had
never touched.

| # | Claim in the record | What I ran | Result |
| --- | --- | --- | --- |
| 1 | Schema check exit 0; 54 scripts; 11 contracts | Re-ran on the committed tree | Exit **0**, output identical to the record |
| 2 | `REQUIRED_FIELD_MANIFEST` catches a deleted `@export` | Deleted `camera_exclusion_margin_px` from `director_configuration.gd` - a **different contract and field** from the two the record used | Exit **1**, failure names the MASTER field and the missing export. Restored and re-verified |
| 3 | Array validation "recurses into every element, not only `[0]`" (F01-17) | Blanked `proportion` on element **[1]** of the wave sample's intent mix | Exit **1**, and it caught *more* than claimed: `enemy_intent_mix[1].proportion is at its default value` **and** `proportions sum to 0.6, expected 1.0 (docs/20 ...)` - the domain assertions work too |
| 4 | Harness exit codes 0 / 100 / 103 | Re-ran all three | **0, 100, 103**. Exact match |
| 5 | **Exit code 1 reproduced on a scratch copy** (F01-19/F01-04, the phase's headline correction) | `git archive HEAD` into the scratchpad, no `.godot`, ran the suite | Exit **1** with the exact recorded message, `Parse Error: Could not find type "GdUnitTestCIRunner"`. Nothing deleted, nothing written in the repository |
| 6 | "The import pass then cures it - the suite exits 0 on the same copy" | `--import` on that copy, then the suite | import exit 0, suite exit **0**. The negative claim this project twice got wrong is now correct and independently confirmed |
| 7 | `run_tests.ps1` no longer reports PASS on zero tests (F01-18). **Superseded at ~07:46**: the script was rewritten mid-review after a reviewer showed guard 3's negative match on "No test cases found" *fails open* when stdout is not captured; it now asserts positively on `Executed test cases : (n/m)`. That is a real hole and a better fix than mine would have been - but the artifact I verified is not the artifact on disk (PR2-05) | Seeded `$LASTEXITCODE=0`, then bad `-GodotPath`; separately a typo `-TestPath` | **1** and **1**. The zero-test run visibly printed gdUnit4's own `Exit code: 0` and the guard still failed closed |
| 8 | **Export verified**: 72 KB pack, zero matches for seven strings, real content present | `du` and `grep -o -a` over `builds/windows/HordeControl.pck`, which exists at 70,532 bytes | `du` reports **72K** (the record's unit is `du`-rounded, consistently with iteration 1's "96 KB" for 95,772 bytes). `gdUnit4`, `GdUnitCmdTool`, `settings_check`, `test_trivial`, `run_tests`, `reports`, `PLACEHOLDER`, `samples`: **0 each**. `boot_check` 5, `enemy_definition` 5, `main.tscn` 2. The drop of `enemy_definition` from 11 to 5 is exactly what excluding `src/data/samples/*` predicts |
| 9 | gdUnit4 pin: v6.2.1, 516 files, SHA-256 `5ae43377...b8b9a` | Ran docs/28's own two commands verbatim | `version="6.2.1"`; `find \| wc -l` = **516**; hash **matches character for character**. The pin is reproducible from the document alone, and `.gitattributes` marks `addons/gdUnit4/** -text` so a clone with different `core.autocrlf` cannot break it - a precaution the record does not even boast about |
| 10 | **The Provisional Values Register is untouched** | `git show HEAD --numstat` plus hunk headers on `MASTER_SDLC.md` | +12/-1, three hunks at lines 2, 62 and 3484. The Register runs from line 3181 to the Review Decision Log; **no hunk falls inside it**. No row labelled "Author decision" in the Register was altered |
| 11 | Every cited path exists | Extracted every backtick-quoted file path from the five phase record files and tested each, resolving phase-relative ones against the phase folder | **No dead path.** The apparent misses are all explicable: `docs/00.md` etc. are the master's own shorthand quoted verbatim from the Development Phase Map; `test/harness/test_trivial.gd` is prefixed "for example" in PLAN.md; `sandbox/connection_test/f06b_probe.txt` is the throwaway file the F-06b probe deliberately deleted, as the log says. Phase 00's dead-evidence-path defect did not recur |

### Decisions D84-D91

All eight are present in the Review Decision Log, all eight are labelled "Author decision
(2026-09-18)", and **all eight name a real alternative** - not a strawman, and in several cases
two. Spot-checking the ones where a fake alternative would be easiest:

- **D88** (pillar precedence) names both "treat the ordering as document 01's assigned remit and
  record no row" and "strip the ranking and have the author supply the order", and concedes the
  remit argument is real before explaining why it is insufficient ("remit explains why the
  document may answer, not why the answer is this one"). That is an alternative argued, not listed.
- **D90** (Telegraph lead time) names striking "with lead time" from docs/20 as redundant, then
  distinguishes the two quantities. I verified the fix landed on both sides:
  `src/data/telegraph_data.gd:20` carries `lead_time_seconds` with a D90 comment, and
  `docs/20_Technical_Architecture.md:165` carries the field in the Telegraph data struct row with
  the same distinction.
- **D91** (numbers carve-out) names "allow no carve-out at all" and "settle each case
  individually", and carries a tie-break clause so the carve-out cannot be stretched. `CLAUDE.md`
  line 15 carries it, and `CLAUDE.md` line 10 was updated from v0.8.2 to **v0.8.4** in the same
  pass - a stale cross-reference the phase could easily have left behind and did not.

I also confirmed the code-side decisions landed: `EconomyConfiguration.xp_level_cost` is an
exported `XpLevelCost` resource with a `compute_level_cost()` method (D89);
`MergeRule.match_radius_px` is gone, replaced by `get_match_radius_px(economy)` returning
`economy.merge_radius_px`, and **exactly one `merge_radius_px` exists in the whole sample set**,
so F01-16's 71-versus-64 drift is structurally impossible as claimed (F01-16);
`has_recursive_interaction_guard` exists on both upgrade samples (F01-17).

### What I looked for and did not find

- **A fix described more strongly than the evidence supports.** I found the opposite three times.
  F01-17's claim of five fixes understates the array fix, which also enforces a domain rule. The
  gdUnit4 pin claims a version and a hash and quietly also solves the line-ending problem that
  would have broken it. F01-21 is held `open` when the master's 0.8.4 row arguably discharges
  D86's Change Log half already.
- **A finding marked fixed that is not.** None among the code findings. Every `fixed` Major I
  tested (F01-04, F01-15, F01-16, F01-18, F01-19, F01-25) reproduced.
- **A cause asserted without an experiment.** One, and it is on the row this review was asked to
  scrutinise - see PR2-04.
- **A cited path that does not exist.** None.

---

## 4. The ledger's integrity, and an explicit verdict on F01-02

### Verdict on the F01-02 deferral: **legitimate.**

Stated plainly, because this is the judgement most open to dispute: **this is not the phase
relabelling its way past its own bar.** Four reasons, each checkable:

1. **"Deferred with owner" is a status the loop itself defines.** `phases/README.md` > Folder
   contents specifies LEDGER.md as "every finding with status (open, fixed, deferred with owner,
   withdrawn)". The status was not invented to fit this row.

2. **The substance was decided by the author before iteration 1's gate, not after it.** Decision
   **D84**, dated 2026-09-18 and taken at phase entry, explicitly names the alternative -
   "Promote `delete_file` and `export_project` to `deny` as well, which is the only control the
   evidence shows actually holds against a subagent" - states why it was declined ("P0.2 and
   P4.5.3 both need the export path"), and closes with "The residual exposure is unchanged from
   D81 and is tracked as F-06b". An author-accepted risk with a named owner therefore existed on
   the record *before* the finding was relabelled. Iteration 2 changed the label to match a
   decision already taken; it did not manufacture the decision to escape the bar.

3. **It is not a Phase 01 defect.** F01-02 is upstream permission-system behaviour, carried from
   Phase 00 as F-06b, self-reported by the orchestrator at phase entry against its own tooling,
   and re-tested rather than assumed. A phase bar that forbids open Majors is aimed at defects in
   the phase's own work; a finding whose only fix requires the author to reverse two of her own
   decisions is the textbook case the "deferred with owner" status exists for.

4. **The mitigation is real and I verified part of it.** `.claude/settings.local.json` now
   contains `{"permissions": {"allow": []}}`. The five `deny`-listed tools
   (`manage_docker_export`, `manage_ci_pipeline`, `game_http_request`, `game_websocket`,
   `game_multiplayer`) are **absent from this session's tool surface**; the two `ask`-listed ones
   (`delete_file`, `export_project`) are present. That is exactly the post-D84 state the record
   predicts, observed from a session that started after the fix. CLAUDE.md and every delegation
   prompt carry the no-delete/no-export constraint explicitly.

**One qualification, and it is the only thing wrong with the row.** The Resolution column asserts
"there is no fix available from this project's side". That is a negative claim, and it was not
tested - see PR2-04.

### Other statuses a reader might dispute

- **F01-01 (Major, `fixed, verification outstanding`).** The status text discloses its own gap,
  which is the honest handling. I could confirm the tool surface is correct at this session's
  start but cannot confirm the two `ask` tools now *prompt* without invoking them, which this
  review is forbidden to do. Legitimately outstanding, legitimately labelled.
- **F01-10 (Major, `closed on substance`).** Verified: docs/28 carries the pin, at 1.1.0, with
  working verification commands and the export-exclusion warning. The qualifier points at F01-21.
  Accurate.
- **F01-06 (Minor, `open, owner the author`).** A genuine gap in the master, handled by omitting
  the figure rather than inventing a citation. Correct.
- **F01-22, F01-23 (Minor, `open`).** Both honestly open. I confirmed F01-23 is not quietly
  closed: `docs/28`'s `runtest.cmd` warning is still the untested one, and the ledger says so.

**No finding in this ledger is marked closed, fixed or deferred in a way I would dispute.** That
includes the two added at 07:39 - `F01-29` (Major, `fixed`: a fix had mis-addressed a Register
citation in doc 02) and `F01-30` (Minor, `fixed`) - whose statuses look right to me, though I note
F01-29 is a Major introduced *by* an iteration 2 fix, which is worth the orchestrator's attention
independently of its status. Both rows sit outside the table (PR2-07).

---

## 5. Loop rule (e) - the close step

All four elements exist. A caveat on timing follows.

| Element | Present? | Checked |
| --- | --- | --- |
| LESSONS.md updated | **Yes** | Seven Phase 01 rows added |
| README status updated | **Yes** | Row 01 rewritten with iteration 1's four scores and iteration 2's state. One overclaim - PR2-03 |
| Master and docs sections updated | **Yes** | `MASTER_SDLC.md` to 0.8.4 with D84-D91; `docs/20` Contract Field Semantics for D87/D89/D90; `docs/28` to 1.1.0 for D86; `CLAUDE.md` for D91 and the version reference; `docs/01`, `docs/02` for F01-11 to F01-14. Numbers only in the Register, and the Register untouched |
| Change Log row added | **Yes** | Row 0.8.4, which names all eight decisions, states "No gameplay rule, number, or gate changed; the Provisional Values Register is untouched", and closes "it does not assert that Phase 01's gate is met, which the reviewers and the author decide" |

**Are the LESSONS rows real lessons?** Yes - seven rows, each traceable to a specific thing that
happened in this phase, none of them a platitude:

| Lesson | Traces to | Verdict |
| --- | --- | --- |
| "A check that consumes another tool's exit code needs falsifying too" | F01-18; I reproduced both paths myself | Real, and the sharpest row in the file |
| "A validator that derives its expectations from the thing it validates cannot detect an omission ... ask of any check: what would it take for this to pass on work that was never done?" | F01-15; I falsified the fix on a third field | Real, and generalised correctly beyond the instance |
| "'Cannot be reproduced here' is a claim requiring an experiment" | F01-19; I reproduced the exit code in about the time the row claims | Real, and it names itself as Phase 00's F-08 lesson recurring inside the phase that carried it forward |
| "Re-read already-written delegation scopes whenever a decision lands mid-phase" | F01-10, an orchestrator self-report | Real |
| "Check the record's structure mechanically, not by reading it ... a one-line awk column count caught what four careful readers had not, and caught the botched first repair as well" | F01-25; my awk run confirms the repair | Real, and it volunteers that the first repair attempt was botched |
| "Freeze the tree when the gate opens, or tell the reviewers it moved" | F01-27 | Real |
| "Under-claiming is cheap and it compounds" | F01-26 and the seven under-claims iteration 1 counted | Real, though the least operational of the seven |

**Timing caveat, recorded not faulted.** Loop rule (e) is the *close* step, and this phase
performed most of it - master bump, Change Log row, LESSONS rows, README update, and a commit -
at iteration-2 fix time, before the re-review it says is "the next step". Nothing improper
follows from it: the Change Log row and README row both decline to claim the gate, and CLAUDE.md
independently requires documentation and implementation to be committed together, so the
decisions had to be recorded somewhere. I note it so a later reader is not confused about why
close-step artifacts predate the close.

**One stale line in LESSONS.md.** The file's closing sentence still reads "Phase 00 is in
progress" and refers to "the rows above" as Phase 00's, although seven Phase 01 rows now sit
above it and `phases/README.md` row 00 records Phase 00 as "Built and reviewed". Trivial, but it
is a superseded-wording miss in a file the phase edited.

---

## 6. Were iteration 1's lessons absorbed, or merely recorded?

**Mixed, and the answer moved against the phase while I was writing it.** My first draft of this
section said "absorbed, with one narrow exception", on the evidence of the artifacts. Then the
tree moved (§PR2-05, PR2-07) and the honest answer changed.

**Absorbed - demonstrably, in the artifacts:**

- **The mechanical column check was not just filed to LESSONS, it was run**, and the record
  volunteers that it caught a botched first repair attempt - a detail a phase optimising for
  appearance would have dropped.
- **The overclaim was corrected in place rather than replaced**, leaving the superseded sentence
  legible, which is the same honest pattern iteration 1 praised in F01-04's handling.
- **The stale cross-reference in CLAUDE.md (v0.8.2 to v0.8.4) was caught** unprompted - the class
  of thing Phase 00 was faulted for leaving behind.
- **Every fix I could falsify, falsified correctly**, including on artifacts the record had never
  touched. The lesson "ask of any check: what would it take for this to pass on work that was
  never done?" was applied to the Schema check in substance, not slogan.

**Recorded but not absorbed - three, and all three are this phase's own most recent lessons:**

1. **"Freeze the tree when the gate opens, or tell the reviewers it moved"** (LESSONS, 2026-09-18,
   written *from* F01-27). Broken during iteration 2's gate, by both a reviewer and the
   orchestrator, with no notice to reviewers. PR2-05.
2. **"Check the record's structure mechanically, not by reading it"** (LESSONS, 2026-09-18,
   written *from* F01-25). The ledger table broke again the same day, in a way the prescribed
   check cannot see. PR2-07.
3. **"'Cannot be reproduced here' is a claim requiring an experiment ... the rule covers negative
   claims as well as causes"** (LESSONS, 2026-09-18, written *from* F01-19). F01-02's Resolution
   asserts "there is no fix available from this project's side" with no experiment behind it.
   PR2-04.

The pattern is consistent and worth naming precisely, because it is more useful than a score: **in
this phase, a lesson is reliably applied to the artifact it was learned on and reliably not
generalised to the next artifact over.** That is the identical criticism iteration 1 made of P0.7
("Carried Lesson 1 was applied thoroughly to P0.6's Schema check and not at all to P0.7's
runner"), one level up. The lessons are being written from the right material; the step that is
missing is the one that asks, before the gate opens, *where else does this rule bite?*

## 7. Findings

### Blocker

None.

### Major

**PR2-05 - Loop rule (c) was broken continuously throughout iteration 2's gate. I watched it
happen five times.** Loop rule (c) says plainly: "execution stops here until the review returns."
It had not returned - this report is it. Observed directly, with timestamps:

| Time | What changed | Consequence for this review |
| --- | --- | --- |
| 07:30:32 | A parallel critical agent renamed `WaveDefinition.get_spawn_budget()` in the live working tree as its own falsification | My Schema check run seconds later exited **1** on an artifact the record correctly says exits 0. I reconstructed the committed tree in the scratchpad rather than file a Blocker against a phase that had done nothing wrong |
| 07:37-07:41 | `evidence/review_p04_iter2.md` and `review_p06_iter2.md` landed; `LEDGER.md`, `docs/01`, `docs/02` and `MASTER_SDLC.md` were edited in response | `MASTER_SDLC.md` gained decision **D92** with no version bump and no Change Log row - the pattern F01-21 records as still open. Doc 01 was reworded, invalidating the doc-lint result I had recorded minutes earlier |
| 07:39:48 | `F01-29` (Major) and `F01-30` were appended to `LEDGER.md` **above its table header**, as orphaned rows inside the prose preamble | For about five minutes the ledger's two newest findings, one a Major, sat outside the table. See PR2-07 |
| 07:44:46 | `LEDGER.md` grew from 28 findings to **35** (`F01-31` to `F01-35`, three of them `open`), and the orphaned rows were repaired | The ledger I assessed in §2 and §4 no longer exists in that form. My dispositions were written against a 28-row file |
| ~07:46 | `tests/run_tests.ps1` was rewritten - a `-TestPath` guard added, and guard 3 inverted from matching "No test cases found" to a positive `Executed test cases : (n/m)` assertion, because a reviewer showed the negative match **fails open** when stdout is not captured | The script I falsified in §3 row 7 is not the script now on disk. The new version is better - the fail-open hole is real and the fix is the right shape - but my verification no longer describes the artifact |

**Nobody told any reviewer the tree had moved**, which is the remedy `phases/LESSONS.md`
prescribes in terms: "Freeze the tree when the gate opens, or tell the reviewers it moved." That
row was written *in this iteration*, from F01-27, which was itself raised for this exact behaviour
at iteration 1. It is a straight repeat, not a first offence, which is why I rate it Major where
iteration 1 rated its predecessor Minor.

I want to be fair about what is good here, because it is substantial: the responsiveness is real,
every defect was repaired within minutes including one I had not yet reported, and the run_tests
fail-open fix is a better catch than anything in my own report. But a gate whose subject changes
every few minutes is not a blind gate - it is the orchestrator and the reviewers working the same
tree at the same time, which is the one arrangement loop rule (c) exists to prevent. The cost is
concrete and already paid: one false failure, one invalidated lint result, one falsification of a
script that no longer exists, and a ledger assessment obsolete before it was finished. A reader of
this report cannot tell, without re-running everything, which of my results still describe the
tree. **Freeze the tree for the remainder of this gate, or re-brief every reviewer with a diff of
what moved.**

Two sub-points. There is no "convened the review gate" row in `EXECUTION_LOG.md` for iteration 2 -
iteration 1 had one, and the log still ends at the F01-24 row, so the record does not show this
gate was opened. And falsification runs belong on a copy: F01-19's own exit-1 reproduction proved
a `git archive` or `tar` copy costs about two minutes and touches nothing, which is the standard
the whole phase should be held to, reviewers included.


Iteration 1's two Majors are themselves disposed of: F01-25 was fixed and verified mechanically
(before PR2-07 reopened the defect class), and F01-24 is discharged by the alternative iteration 1
itself offered (§2). I re-tested every `fixed` Major in the ledger and all of them reproduced.

### Minor

**PR2-01 (resolved during the review) - the sweep loop rule (d) requires before re-review missed
a string the phase's own lint result asserts is absent.** `EXECUTION_LOG.md` line 32 states "No
banned gate wording (\"passed\", \"satisfied\", \"ready\", \"is stable\") in any of the three".
Iteration 2's own fix for F01-13 rewrote doc 01's precedence preamble and introduced
`docs/01_Design_Pillars.md:54`: "between two features that have both already **passed** that gate".
The rule's *intent* was never violated - this is design prose about the Central Tension as a binary
test applied to a game feature, not a claim that a project gate is passed - but the recorded lint
result was inaccurate, and loop rule (d)'s "sweep all changed files for superseded wording" exists
for exactly this. The parallel P0.4 reviewer found it independently and logged it as F01-30; the
sentence was reworded at 07:39 and a re-run of the grep over documents 00-02 now returns nothing.
I record it because the sweep, not the re-review, should have caught it. F01-30's own note - that
the forbidden vocabulary is ordinary English in another sense, so a mechanical sweep yields false
positives and the fix is to avoid the word rather than argue the sense - is the right conclusion
and worth carrying to LESSONS.md.

**PR2-02 - Three ledger rows name the author as owner; none of them reaches the author.**
`NEXT_SESSION.md` > "What needs the author, and when" is the project's own queue for this, and it
was not touched by Phase 01. It still lists only Phase 00's gate row. Missing from it: F01-24's
withholding of the "Phase 0 accepted" row (the decision an agent took on the author's behalf about
a stated gate requirement), F01-06 (`open, owner the author` - the Moment-to-Moment Loop's missing
Register row), and F01-02 (`deferred, owner the author`). A finding owned by the author that lives
only in a phase-local ledger is owned by nobody. This is the residual half of F01-24: the reason
for withholding is recorded, but the author is not told, and no Review Decision Log row records
the withholding although the phase took eight author decisions in the same two days.

**PR2-03 - `phases/README.md` row 01 asserts the ledger state more strongly than the ledger
supports.** The row now reads "no open Blocker or Major remains, one Major deferred to the author
as unfixable from this project's side". That claim rests on reading F01-24's status `recorded` as
closed, and `recorded` is not one of the five statuses LEDGER.md's own header declares. It also
reads past F01-01, a Major whose status is `fixed, verification outstanding` and whose
verification is explicitly not yet demonstrated. I agree with the substance - I dispute none of
the ledger's statuses - but the phase index should not be where a phase grades its own ledger
against its own bar; that is the reviewers' sentence to write. Either add `recorded` to the
declared status vocabulary and say what it means, or state the ledger position neutrally
("28 findings: 12 fixed, 4 closed, 3 open Minor, 1 deferred to the author, 3 recorded") and let
the reviewers characterise it.

**PR2-04 - "There is no fix available from this project's side" is a negative claim with no
experiment behind it.** F01-02's Resolution says so, and grounds it on "the delegated research and
Phase 00's own F-06 both found `deny` is the only control that reliably intercepts a subagent".
Neither the phase record nor `docs/28` anywhere mentions a **PreToolUse hook** in
`.claude/settings.json`, which is the documented Claude Code mechanism for intercepting a tool
call before it runs and is a third option distinct from both `ask` and `deny` - it could deny
`delete_file` for a subagent while leaving `export_project` reachable for P0.2 and P4.5.3, which
is the exact constraint D84 says forced the compromise. I have **not** verified that a hook
intercepts a subagent's MCP tool call; that is the point. The finding is that the record forecloses
an untested option in absolute language, in the same iteration that added a LESSONS row saying
"'cannot be reproduced here' is a claim requiring an experiment ... the rule covers negative claims
as well as causes". This does not change my verdict on the deferral, which stands on D84 regardless.
Soften the wording to what is established, or test the hook and record the result.


**PR2-06 - `phases/LESSONS.md`'s closing sentence is superseded.** It reads "Phase 00 is in
progress; the rows above were captured as they occurred" while seven Phase 01 rows now sit above
it and README row 00 records Phase 00 as built and reviewed. One line, in a file this phase edited.

**PR2-07 (transient, repaired at 07:44:46) - LEDGER.md's table was malformed again, in the same
file and the same gate that fixed it.** At 07:39:48 `F01-29` (Major) and `F01-30` were written at
lines 4 and 5 of `LEDGER.md` - above the "Severities:" line, above the explanatory paragraph, and
above the table header at line 11. They were orphaned table rows inside the file's prose preamble,
with no header and no delimiter row before them; under GitHub-flavoured Markdown that is not a
table, and both lines would have been absorbed as lazy continuation of the paragraph above and
rendered as literal pipe characters. They were moved into the table at 07:44:46 and the file is
now clean - I re-ran the check and all 37 table lines carry 7 columns with no row above the header.

I record it although it was repaired, for one reason that outlives it: **the check the phase added
to LESSONS.md would not have caught this.** The row reads "run a column count over each table in
the phase record before the gate", and a column count returned 7 for the orphaned rows too, because
they were individually well-formed. Widen the lesson from "count the columns" to "count the columns
*and* confirm every row sits under a header", or the next recurrence passes the check as well.

---

## 8. Phase execution score

# 7 / 10

**This is a 9-quality set of artifacts held down by a 5-quality gate process, and the average is
where it lands.** I want to be exact about that, because the number on its own would mislead.

**What the artifacts earn.** Eleven claims tested, eleven reproduced - including every number I
could count independently: the gdUnit4 content hash character for character, 516 files, all four
gdUnit4 exit codes, the Schema check's output verbatim, the pack search returning zero for all
seven excluded strings, and the master's diff hunks falling demonstrably outside the Provisional
Values Register. The two fixes carrying the most weight were falsified by me on artifacts the
record had never touched - a different contract and field for the required-field manifest, and
array element **[1]** for the recursion fix - and both failed correctly, the second catching more
than the record claims. The exit code this project twice recorded as unreproducible reproduced in
under two minutes by the method the ledger had itself named and declined to use, and the import
pass cures it exactly as claimed. Every decision names a real alternative and several argue
against themselves first. The record under-claims far more often than it overclaims. On artifact
quality and record honesty this is the best work the project has produced, and it is clearly
better than iteration 1.

**What pulls it to 7.** Not the artifacts - the conduct of the gate itself, on three counts, two
of which I observed happening rather than inferred from the record:

1. **Loop rule (c) - "execution stops here until the review returns" - was broken continuously
   throughout this gate** (PR2-05, the one Major in this report). Between 07:30 and 07:46 a
   reviewer mutated a source file in the shared tree, and the orchestrator edited `LEDGER.md`
   (twice, taking it from 28 findings to 35), `docs/01`, `docs/02`, `MASTER_SDLC.md` and
   `tests/run_tests.ps1` in response to reviewers that had just reported, while other reviewers
   were still working. No reviewer was told. It produced a false failure in my own first check,
   invalidated a doc-lint result I had already recorded, left my falsification of `run_tests.ps1`
   describing a script that no longer exists, and put decision D92 into the master with no version
   bump and no Change Log row. This is F01-27 recurring **inside the iteration whose LESSONS row
   forbids it**, which is why it is Major here and was Minor there.
2. **The ledger table broke again** (PR2-07) - repaired within five minutes, so not a Major, but
   it happened in the same file and same gate that fixed it, and in a way the mechanical check the
   phase just adopted cannot detect.
3. **The author, whose decisions this project is built around, has not been asked anything**
   (PR2-02). Three ledger rows name her as owner and none reaches `NEXT_SESSION.md`'s author
   queue; the decision to withhold a stated gate requirement was taken by an agent, recorded in a
   phase log, and given no Review Decision Log row, in a phase that took eight author decisions in
   two days.

Points 1 and 2 are both recurrences of findings this phase itself raised and wrote lessons about,
hours earlier. That is the specific thing I was asked to judge, and the answer is that two of the
phase's three newest lessons were broken during the gate that wrote them, and a third (PR2-04) was
broken in the record (§6).

**What would move it back to 8, and it is not much work.** Move `F01-29` and `F01-30` below the
table header and re-run the column count; stop editing the record and the documents until every
iteration-2 reviewer has reported, or tell the reviewers explicitly that the tree moved and what
moved; add the three author-owned items to `NEXT_SESSION.md`; give D92 its version bump and Change
Log row; soften F01-02's "no fix available from this project's side" to what has actually been
tested. None of that touches a single artifact I verified, which is the point: the work is sound
and the process around it is not yet.

**Ledger position as I read it, as of 07:46.** No open Blocker. Of the ledger's own findings, no
open Major that I dispute: iteration 1's two are disposed of (§2), F01-02's deferral is legitimate
on the grounds set out in §4, F01-01's outstanding verification is honestly labelled and cannot be
closed from inside a running session, and F01-29 is `fixed`. Three of the five findings added at
07:44 are `open` Minors. Against that, this report raises one new Major (PR2-05) and six Minors.
I attach the timestamp because the ledger grew by seven rows while I was reading it, and any
statement I make about its contents has a shelf life measured in minutes until the tree is frozen. Whether this phase meets its bar, and whether it closes, is for the loop's
fix-and-repeat step and for the author under the Gate Approval rule - not for this report.

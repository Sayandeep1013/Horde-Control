# P0.4 Spot-Check Review, Iteration 2 - Documents 00, 01, 02 at 1.0.0

Reviewer: Opus spot-check agent, review iteration 2 of Phase 01. Scope set by decision D83 (documentation tasks get a spot-check, not a critical-agent panel) and narrowed further by the iteration-2 brief: go deep on the iteration-1 fixes and on regression, do not re-audit what iteration 1 already cleared.

Date: 2026-09-18. Artifacts: `docs/00_Vision_and_Design_Philosophy.md`, `docs/01_Design_Pillars.md`, `docs/02_Gameplay_Loop.md`. Sources read: `phases/PHASE_01_Contracts_Docs_Harness/evidence/review_p04.md` (iteration 1), `phases/PHASE_01_Contracts_Docs_Harness/LEDGER.md`, `CLAUDE.md`, `MASTER_SDLC.md` 0.8.4 (Change Log, Review Decision Log D84-D91, Document Control, Session Shape, Structure Hierarchy, The Loop Exists At Four Scales, Design Principles, Explicit Anti-Patterns, Documentation Structure, Provisional Values Register), `docs/20_Technical_Architecture.md` (field semantics for "intent mix").

**Score: 7 / 10.** Same number as iteration 1, different reasons. Stated in full under "Score and reasons". This report does not state that any gate is passed, satisfied, met, or ready; that is the reviewers' and the author's call.

---

## 1. Disposition of every iteration-1 finding

| ID | Iteration-1 finding | Disposition |
| --- | --- | --- |
| F01-11 (R1/R1b) | Six "structural" counts exempted from the numbers rule on the authority of a CLAUDE.md rule that did not exist | **Closed on the artifacts, with one gap in the rule's wording.** See section 2. |
| F01-12 (R7) | Doc 01 asserts binding new design with no Decision Log row: (a) the six-rank precedence order, (b) the anti-pattern-to-pillar enforcement mapping | **Half closed.** (a) closed by D88. (b) **not closed** - no decision row covers it and doc 01 still asserts it declaratively. See section 3. |
| F01-13 (R2) | The precedence table is circular at rank 1 | **Closed.** The circularity is removed, not relocated. One new scope wrinkle, Minor. See section 4. |
| F01-14 item 1 (R1b) | Bare "three biomes" where the master tags it a Provisional Default | **Closed.** Rewritten to cite the Register; the row resolves. |
| F01-14 item 2 (R3) | All four loop-scale durations called reference frames, contradicting the master on the Wave Loop | **Fixed on substance, but the fix introduced a Register citation that does not resolve.** See finding N1, Major. |
| F01-14 item 3 (R4) | "first ninety seconds" softened to "the opening seconds" with nothing named as deferred | **Closed.** Rewritten to name the deferred limit and landmark and to cite the row that carries both; verified. |
| F01-14 item 4 (R5) | Doc 01's safe corner omits "intent mix"; one cited item not stated where cited | **Closed, with a residual Minor.** Both halves addressed; the restored wording blunts the master's point. See finding N3. |
| F01-14 item 5 (R6) | A1's "halves" rendered "compresses" with no signal that a magnitude is deferred | **Closed.** Now "by the fixed proportion that Register row states"; the row says "halves". |

---

## 2. F01-11: does D91 actually authorise what remains?

`CLAUDE.md` line 15 now reads: "Every gameplay number lives in the Provisional Values Register; every other place references it. One carve-out, and only one (decision D91): a count the master itself states as **structure** rather than tuning - 'four nested structures', 'the four prototype encounter types', 'exactly two boss-class encounters' - is not a gameplay number and needs no Register citation. A number that could be tuned without changing the shape of the game is a gameplay number and cites the Register, even when it looks structural. If a count is arguable, cite the Register."

D91 (`MASTER_SDLC.md` line 3496) records it with two real alternatives (no carve-out at all; case-by-case with no general rule) and a real reason, and states the tie-break's purpose explicitly ("so the carve-out cannot be stretched"). The rule is well built: it has a positive test, a negative test, and a tie-break, and it does not lean on the fabricated examples F01-11 was raised about.

I re-swept every numeral and every number-word in all three documents and tested each surviving instance against D91 **as written**, not against its intent.

| Surviving count | Where | Verdict against D91 as written |
| --- | --- | --- |
| "four nested structures" | 02:64 | **Authorised**, named exemplar; master L274 verbatim. |
| "the four prototype encounter types" | 02:58, 02:135 | **Authorised**, named exemplar; master L322 and L324 verbatim. |
| "exactly two boss-class encounters" | 02:119 | **Authorised**, named exemplar; master L1082 verbatim. |
| "four loop scales" / "The Loop At Four Scales" / "four nested loops" / "the four scales" | 02:9, 27, 29, 31 | **Authorised without stretching.** Not a named exemplar, but the master states it as structure verbatim: heading "The Loop Exists At Four Scales" (L283) and "the player is experiencing four nested loops at once" (L285). Cannot be retuned without changing the loop's shape. |
| "one arena with one mechanical hook", "one or more Encounters", "one playthrough" | 02:68-71 | **Authorised**; master L275-278 verbatim. |
| "two health pools, one player, one battlefield" | 00:21, 00:55 | **Authorised**; master L216 verbatim. |
| "three biomes" | formerly 02:117 | **Rewritten, tie-break honoured.** Now "the number of biomes stated in the Provisional Values Register > Onboarding & Session > 'Session arithmetic', a Provisional Default rather than a fact about the loop's shape" (02:119). The row carries "three such biomes plus onboarding, total a run ~ 32-35 min". This is the one case the tie-break was written for and it was applied. |
| "**The Six Pillars**" | 01:27 | **Not authorised by D91 as written.** See finding N2. |
| "the vertical slice contains one biome, and the prototype contains one arena" | 02:119 | Bare, uncited, in the same sentence that sends the run's biome count to the Register. Master L222 states both, untagged; the Vertical Slice Scope Freeze lists "One complete biome". Defensible as frozen scope rather than tuning, but it is the closest thing left to an arguable count. Recorded as an observation, not a finding. |

No numeral elsewhere in the three documents is attached to a gameplay noun. Everything else is a document number, a version, a task or phase ID, a teaching-wave identifier (T1-T4), an author-decision tag (A1/A2), a precedence rank ordinal, a decision ID (D88), or the "40" inside the quoted Register row title "T4 Siege, teaching (max 40 s)", which is a citation rather than a restatement.

**F01-11's disposition: closed on the artifacts.** Five of the six counts D91 was written for are covered by its wording without stretching it; the sixth is N2.

---

## 3. F01-12: does D88 close it?

**Half (a), the precedence order - closed.**

- D88 names a real alternative, in fact two: treat the ordering as doc 01's assigned remit under Documentation Structure and record no row; or strip the ranking and have the author supply the order. Both are genuine positions, and the first is the counter-argument iteration 1 itself raised. The reason given answers it directly ("remit explains why the document may answer, not why the answer is this one"). This satisfies CLAUDE.md's rule.
- Doc 01 points at it: 01:56, "It is recorded as decision D88 in MASTER_SDLC.md > Review Decision Log, which names the alternatives considered so the author can reverse it deliberately."
- **D88's stated order matches the table exactly**, rank for rank: 1 Two things to protect (the Central Tension) / 2 Readability before spectacle / 3 Failure must teach / 4 Escalation must be visible / 5 Positioning over precision / 6 Systems isolate, effects combine. Checked against 01:60-65 individually. No drift.
- The two uniqueness claims the ranking rests on still hold as stated. A re-run of iteration 1's greps now returns more hits than it did - "does not belong" twice (master L199 and inside D88 at L3493) and "wins" at L3488 and three times at L3493 - but every new occurrence is inside the Review Decision Log describing the claim, not a pillar statement, and both claims in doc 01 are scoped to pillars. Not a defect; recorded so a later reviewer is not surprised by the changed counts.

**Half (b), the anti-pattern-to-pillar enforcement mapping - not closed.**

D88's scope is the ordering only; it says nothing about the mapping. I grepped the whole Review Decision Log for any row covering anti-patterns or the mapping: none exists. Meanwhile doc 01 still asserts it as fact:

- 01:40, the framing claim: "The following failure modes are the project's evidence that a pillar has been violated."
- 01:42-48, seven declarative mappings, including the leg iteration 1 named as the least supportable: "**The idle minute** enforces *Readability before spectacle* and *Failure must teach* together".

The master lists Design Principles (L351-378) and Explicit Anti-Patterns (L382-414) as two separate lists and makes no mapping between them. Its "The idle minute" entry (L402-404) reads in full: "Any stretch where the optimal play is to stand still and wait. Downtime is allowed; idleness is not." It says nothing about readability. The mapping is doc 01's own inference, presented as the project's.

Compounding it: `LEDGER.md` records F01-12's Status as "fixed", and its Resolution column describes only the ordering. The record now reads as though both halves closed.

**F01-12's disposition: half closed. The Major is carried.** One Decision Log row naming the alternative (or one hedge in doc 01 marking the mapping as this document's reading) closes it.

---

## 4. F01-13: is the circularity removed or relocated?

Removed, in my judgement, and the reasoning is worth stating because the fix is subtle.

The old defect was that the table's precondition scoped it to conflicts the Central Tension test "does not by itself settle", while rank 1 *was* that test - so rank 1 could never fire. The new preamble (01:54) deletes that precondition and replaces it with two stages that apply **different predicates**:

- the gate's predicate is binary and absolute: does the feature sharpen, complicate, or meaningfully reframe the tension *at all*? If not, it does not ship;
- rank 1's predicate is comparative and relative: of two features that both cleared the gate, which sharpens it *more*?

Those are not the same question, so rank 1 has work to do that the gate has not already done. The circularity does not reappear one level down, because the gate can never settle a "which of these two" question - it only ever returns ship / does not ship.

**No contradiction with doc 01's own "The Central Tension: The Supreme Test" section.** That section (01:23) already said the test "applies before any pillar-versus-pillar question does", that "No pillar below overrides this test", and that "it is the gate every feature passes through before the pillars below are even consulted". The new preamble restates exactly that and adds what happens afterwards. The two sections agree.

**No contradiction with the master.** Master L198-199 is binary-gate wording ("If a proposed feature does not sharpen, complicate, or meaningfully reframe this tension, it does not belong in the game"). The master never ranks pillars, so nothing there is contradicted by a comparative second stage.

Two residuals, both recorded below: the new preamble narrows the table's stated domain (N4), and the reframing is itself a decision procedure the master does not state, recorded in the ledger but not in the Decision Log (observation only - I do not think it needs its own row, since D88 records the order and the procedure is internal to how doc 01 applies it, but a stricter reading of CLAUDE.md would want one).

---

## 5. Citations re-resolved

The brief asked for a sample plus every citation the fixes added. I resolved all of the following against the Register's own section boundaries (`MASTER_SDLC.md` lines 3180-3392).

**Added or rewritten by the iteration-1 fixes:**

| Doc, line | Citation | Result |
| --- | --- | --- |
| 02:119 | Register > Onboarding & Session > "Session arithmetic", for the number of biomes | **Resolves.** Row: "...three such biomes plus onboarding, total a run ~ 32-35 min". Correct section, and the "Provisional Default" characterisation matches master L222. |
| 02:89 | Register > Onboarding & Session > "Teaching wave budgets", for the onboarding limit *and* the landmark | **Resolves, and carries both.** Row: "...within the restored ninety-second onboarding limit for the five lessons; ... Tower understood by end of T2 ~ 50 s". |
| 02:105 | Register > Onboarding & Session > "Onboarding compression (Author decision, A1)", for "the fixed proportion" | **Resolves.** Row: "the setting halves T1 and T2 durations and budgets". |
| 02:31 | Register > Spawning & Waves, for "the wave-length figures" | **DOES NOT RESOLVE.** See finding N1. |
| 02:31 | Register > Onboarding & Session > "Session arithmetic" and "Prototype session length" | **Resolve.** Both rows exist in that section. |
| 01:42 | MASTER_SDLC.md > Explicit Anti-Patterns, for the derivation of the armed player's minimum distance | **Resolves.** L388: "an armed player's centre is at least 174 px from the Tower's centre (160 px radius + 14 px body)". This closes iteration 1's over-claim. |
| 01:56 | MASTER_SDLC.md > Review Decision Log, D88 | **Resolves.** L3493. |

**Sample re-resolved from iteration 1's twenty:**

| Doc, line | Citation | Result |
| --- | --- | --- |
| 00:35 | Register > Arena & Camera, owners 15 and 27 | Resolves; "Arena size" and "Traversal time" owner 15, "View scale" owner 27. |
| 00:80 | Register > Interfaces | Resolves; "Platform input floor" and "Input map (C-INPUT)", owner 19. |
| 00:87 | Onboarding & Session > "Three Second Rule probes" | Resolves; carries the full measurable criteria. |
| 01:43a/b | Progression & Upgrades > "Prototype upgrade pool"; Economy & Pickups > "Economy dominance measure" | Both resolve, in the named sections. |
| 01:46 | Technical Caps & Performance > "Run Recorder" | Resolves; carries the C-IDLE threshold. |
| 01:48 | Progression & Upgrades > "Level-Up Draft" | Resolves; "Reroll 1 per run (prototype) / 1 per draft (slice)". |
| 01:42 | Register > Enemies ("Player Hunter" leash), > Tower ("Tower base weapon" range 480 px) | Both resolve. |
| 02:39 | Spawning & Waves ("Inter-wave gap") and Technical Caps & Performance > "Run Recorder" | Both resolve. |
| 02:69, 02:119 | Spawning & Waves > "Biome sequence" | Resolves. |
| 02:81 | Combat Rules > "Revive" | Resolves. |
| 02:109 | Encounter Budgets > "T4 Siege, teaching (max 40 s)" | Resolves, and carries both deferred tuning targets. Row title matches character for character. |
| 02:113 | Combat Rules > "Teaching wave XP (C-XPCAP)" | Resolves. |
| 02:121 | Onboarding & Session > "Boss duration targets" | Resolves. |
| 02:135, 02:137 | Spawning & Waves > "Encounter completion", > "Partial reward (C-PARTIAL)" | Both resolve. |

**Outcome: one citation of the twenty-odd tested does not resolve, and it is one the fixes added.**

---

## 6. Regression sweep

| Check | Result |
| --- | --- |
| Placeholder lint | **Clean.** Grep for TODO, TBD, TBC, XXX, FIXME, "placeholder", `[ ]`, ASCII `...`, the Unicode ellipsis and `<angle_brackets>` over all three files: zero matches. |
| Banned gate wording ("passed", "satisfied", "met", "ready", "is stable") | **Clean on substance; one new lint collision.** Docs 00 and 02 hit only on the Status line, which exists to deny the claim. Doc 01 now hits a second time, at 01:54, "two features that have both already passed that gate" - introduced by the F01-13 fix. This is a design test applied to a hypothetical game feature, not a claim that a project review gate has been passed, so I do not count it as a violation of the CLAUDE.md rule. It will nonetheless be flagged by any mechanical sweep from here on; one word ("cleared that test") would keep the sweep clean. Nit. |
| Versions still 1.0.0 | **Clean** in all three (line 3 of each). |
| Docs 00/01 carry "Owns: none listed in Documentation Structure" verbatim per D85 | **Clean.** Both at line 11, character for character, no Owns entries invented. |
| Doc 02's six Owns entries still resolve | **Clean.** The Owns line still matches Documentation Structure's entry for 02 (master L1965) in content and order; all six resolve to real `##` headings that do real work: Structure Hierarchy (62), Run Termination Edge Cases (75), Onboarding Edge Cases (87), Boss Cadence And Biomes Per Run (117), Boss Wave Placement (Summary) (125), Encounter Failure Resolution Default (133). |
| No "Phase 0 accepted" or "00/01/02 stable" row in the master's Change Log | **Confirmed not written.** Both strings occur in the master exactly once each, at L3124 and L3129, inside the Development Phase Map's own statement of P0.4's exit criterion and Phase 0's exit - which is the requirement's text, not a proposal or a gate row. The Change Log's newest entry is the 0.8.4 row, which is a decisions-and-corrections row and closes with "This entry records what the phase decided; it does not assert that Phase 01's gate is met, which the reviewers and the author decide." Rows D84-D91 are Review Decision Log rows, not gate rows. The distinction the brief drew holds. |
| Superseded wording sweep | **Clean** for the fixes in scope. The old table precondition ("does not by itself settle the question") appears nowhere in the repository; "three biomes" as a bare claim appears nowhere in docs 00-02; "the opening seconds" is gone. |

One process observation, outside P0.4's artifacts: `git status` shows `docs/28_AI_Development_Workflow.md` modified in the working tree while this review iteration is open. That is F01-27's finding (implementation continuing after the gate is convened) recurring in iteration 2. It touches P0.5/P0.7 rather than P0.4, and none of the three documents I reviewed has moved, but the record should carry it.

---

## 7. New findings

| ID | Finding | Severity |
| --- | --- | --- |
| N1 | **The fix for the loop-scale finding introduced a Register citation that does not resolve - the first in these documents.** Doc 02 line 31 states: "The wave-length figures are not in that exemption: the master states them as a Provisional Default, and they live in the Provisional Values Register > Spawning & Waves alongside the inter-wave gap." The inter-wave gap is indeed there. **The wave-length figures are not.** The Register's Spawning & Waves section carries 23 rows and none of them states a combat wave's target or maximum duration; two rows ("Wave end / STALLED", "Teaching wave runtime (C-TEACH)") refer to "maximum duration" without ever giving it. The 40 s / 90 s figures live in **Encounter Budgets** (in the row titles "Combat wave 1 Hunt (max 90 s)" and its siblings, and inside "Siege volume formula") and in **Onboarding & Session** ("Session arithmetic": "8 combat waves at 40 s with Sieges at 80 s"; "Prototype session length": "4 combat waves (40-90 s each)"). The substantive claim is correct - master L226 does tag the wave length "(Provisional Default)", so it is outside Document Control's Session Shape ranges carve-out - but the pointer sends the reader to a section that does not have it, in the one paragraph whose entire purpose is to say where each scale's number lives. A second clause in the same sentence over-reaches the same way: "every figure is left to the Register row that owns it" is not true of the Moment-to-Moment Loop, whose duration has no Register row at all - that is F01-06, still open with the author. Iteration 1's strongest result was twenty citations, twenty resolving; this is a regression in exactly that property, and the project has shipped a 1.0.0 document citing a place that did not carry the content before. One clause fixes it. | **Major** |
| N2 | **D91's carve-out does not, on its face, cover one of the six counts it was written for, and its tie-break over-reaches on that case.** Doc 01's heading "## The Six Pillars" states a count. D91 exempts "a count the master itself states as structure rather than tuning" - but the master states no count: its Design Principles section lists six `###` subsections and nowhere writes "six". The tie-break then applies literally ("if a count is arguable, cite the Register") and demands a Register citation for the number of design principles, for which no row exists and none could sensibly be written. The saving reading is the parent rule's own subject: it governs "every **gameplay** number", and the number of pillars in a design document is not one. On that reading the artifact needs no change and doc 01 is fine as written. What is wrong is the record: D91's reason and LEDGER F01-11 both describe "six structural counts" exempted under the carve-out, when one of the six was never inside the rule's subject-matter. Two words in D91 ("a count of gameplay content that the master itself states as structure...", and the same scoping on the tie-break) would stop the next document re-litigating it. **No change to any of the three documents is required by this finding.** | Minor |
| N3 | **The restored "intent mix" blunts the mechanism the master singles out.** Master L388: "This guarantee is delivered by **intent mix, not by any single wave**: every biome must schedule Player Hunters often enough that standing still is eventually fatal". Doc 01:42: "the guarantee that no such position exists is delivered by **the wave's intent mix** rather than by any single wave, as the master states". The possessive attributes the mechanism to the very unit the same clause denies is sufficient, where the master locates the scheduling at biome level and across waves. It is not flatly wrong - `docs/20` line 221 does type "Enemy intent mix" as a wave-level field - but the sentence now reads as self-undercutting and the master's point (the guarantee is an emergent property of the mix across waves, not of any one wave's composition) is harder to recover. Separately, the trailing attribution still grammatically sweeps all three listed items into "docs/09 and the Provisional Values Register > Enemies, > Player & Weapons, and > Tower", including the minimum distance that is in neither - though the new inline parenthetical does name its real source, which is what closed the iteration-1 over-claim. The fix landed; this is the residue. | Minor |
| N4 | **The new precedence preamble narrows the table's own domain.** 01:54 scopes the table to "between two features that have both already passed that gate", a feature-versus-feature comparison. But doc 01:17 scopes the same table to pillar-versus-pillar ("a definite order for when two of them point in different directions"), the table's own sentence reads "which pillar's claim prevails", and the section is titled "Precedence: Which Pillar Wins". Read literally, a single feature whose design pulls two pillars apart - readability against escalation inside one effect, say - is now outside the preamble's stated scope, and that is the commoner case in practice. The circularity fix is sound; this is a side effect of stating it in feature terms rather than pillar terms. One clause ("between two features, or within one feature whose design pulls two pillars apart") restores the range. | Minor |

### Things checked that came back clean

Recorded so a later reviewer does not repeat them: the full numeral and number-word sweep of all three documents (section 2); the complete Register-section map re-derived from the Register's own `##` headings, so a row cited under the wrong section would be caught; doc 01's two uniqueness claims re-tested by whole-file grep including the new Decision Log occurrences; D88's stated order compared rank by rank against doc 01's table; doc 02's Owns line diffed against Documentation Structure; the six Owns headings; Document Control compliance on all four checks; the master's Change Log for gate rows; the absence of the superseded table precondition anywhere in the repository.

---

## 8. Score and reasons

**7 / 10.** Below 8, so the reasons are stated. The number is unchanged from iteration 1 but the composition is different, and that should not be read as "nothing improved" - the underlying quality moved up materially.

What genuinely improved, and should not be lost in the findings: D91 is a well-made rule, not a patch - a positive test, a negative test, and a tie-break, with the tie-break's purpose stated in the decision row itself, and it is applied in the one case it was written for rather than merely asserted. D88 names two real alternatives, one of them the counter-argument iteration 1 itself raised, and its stated order matches doc 01's table rank for rank. The F01-13 fix is better than the minimum: it separates a binary predicate from a comparative one rather than papering over the loop, it contradicts neither doc 01's own supreme-test section nor the master, and it left the ordering intact. Four of F01-14's five items closed cleanly with citations that resolve. Placeholder lint, version headers, Owns lines, and the master's Change Log are all clean, and the gate row was again not written.

The three reasons it does not reach 8:

1. **N1.** A fix introduced a Register citation that does not resolve. Iteration 1's single strongest finding was that twenty citations out of twenty landed on the right row in the right section; a rewrite aimed at numbers-rule fidelity broke that property, in the paragraph whose only job is to tell the reader where each loop scale's number lives. The claim it supports is true; the address is wrong. Cheap to fix, but it is a regression in the documents' best attribute.
2. **F01-12(b), carried.** Half of an iteration-1 Major is untouched. Doc 01 still states seven anti-pattern-to-pillar mappings the master does not make, including the "idle minute enforces readability" leg iteration 1 named as least supportable, with no Decision Log row and no hedge - while the ledger records the finding as "fixed". A Major carried under a Status that says otherwise is worse than a Major carried openly, because the next reviewer will not look.
3. **N2 and N4 together.** Both are small, but both are the same shape: a rule or a reframing written to close a finding that does not quite cover the ground it was written for. Individually neither would move the score; together with (1) and (2) they are why this is a 7 rather than an 8.

---

## 9. What this review did NOT check

- **Not re-audited: what iteration 1 cleared.** Per the brief. The Run Termination table, the Loop Entry And Exit Conditions table, doc 00's Project Identity and Platform sections, doc 01's six pillars and seven anti-patterns against the master's lists, and the opening loop narrative were all cleared by iteration 1 and were re-read only for contradiction with the fixes, not traced clause by clause.
- **Not checked: fourteen of the twenty iteration-1 citations were re-resolved; six were not.** The six I did not re-test are ones the fixes did not touch and iteration 1 verified character for character.
- **Not checked: the master beyond the sections named above.** Roughly 2,400 lines of the master were searched only by targeted grep. A contradiction between docs 00-02 and the Risk Register, the Acceptance Test Matrix, the Glossary, or edge-case registers outside Run Termination would not have been caught.
- **Not checked: documents 03-30 for cross-document consistency.** Only the specific claims docs 00-02 make about documents 09, 11, 15, 19, 20, 27 and 28, and for 20 only the single "Enemy intent mix" field row I needed for N3.
- **Not checked: whether the structural-count carve-out is the right call on the merits.** This report establishes that D91 now exists, names alternatives, and covers five of its six cases without stretching. Whether a carve-out *should* exist and how wide it should be remains the author's question, and D91 records it as an author decision.
- **Not checked: the other Phase 01 tasks.** P0.6 and P0.7, their artifacts, `tests/`, `src/`, the export, and the ledger rows belonging to them were outside this brief. `docs/28` is modified in the working tree and I did not read it.
- **Not checked: prose quality, length, or reader usefulness.** Only correctness against the sources and against the project's rules.
- **Not run: any Godot tooling, test, or build.** No `mcp__godot-*` tool was called, per the brief's constraint. No file was created, edited, or deleted except this report.

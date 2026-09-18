# P0.4 Spot-Check Review, Iteration 3 — Documents 00, 01, 02 at 1.0.0

Reviewer: Opus spot-check agent, review iteration 3 of Phase 01. Scope set by decision D83 (documentation tasks get a spot-check, not a critical-agent panel) and narrowed by the iteration-3 brief: go deep on the iteration-2 fixes and on regression, do not re-audit what iterations 1 and 2 cleared.

Date: 2026-09-18. Gate commit: `8145333`, tag `phase01-review-iter3`.

Artifacts: `docs/00_Vision_and_Design_Philosophy.md`, `docs/01_Design_Pillars.md`, `docs/02_Gameplay_Loop.md`.

Sources read: `evidence/review_p04_iter2.md` (my predecessor), `evidence/p04_report.md`, `LEDGER.md`, `CLAUDE.md`, `MASTER_SDLC.md` 0.8.5 (Document Control, Provisional Defaults Policy, Gate Approval, Versioning Rules, Change Log, Session Shape, The Loop Exists At Four Scales, Design Principles, Explicit Anti-Patterns, Wave Director & Spawning Logic, Documentation Structure, Development Phase Map, Provisional Values Register in full, Review Decision Log D77–D93), `docs/11_Wave_Director.md` headings.

**Score: 8 / 10.** Stated in full under "Score and reasons". This report does not state that any gate is passed, satisfied, met, or ready; that is the reviewers' and the author's call.

---

## 1. Freeze check

| When | `git status --porcelain` | Reading |
| --- | --- | --- |
| Start of review | *(empty)* | Tree clean. `git log --oneline -1` = `8145333`, `git tag --points-at HEAD` = `phase01-review-iter3`. The gate opened where the brief said it would. |
| End of review | `?? phases/PHASE_01_Contracts_Docs_Harness/evidence/review_p04_iter3.md`<br>`?? phases/PHASE_01_Contracts_Docs_Harness/evidence/review_p06_iter3.md` | Two untracked files, both new iteration-3 review reports: this one, which the brief instructed me to create, and the parallel P0.6 reviewer's, created under the same freeze and by the same authorisation. **No tracked file is modified, added, deleted or staged**, and `HEAD` is still `8145333`. **The freeze held on the reviewed tree.** |

This is the first iteration of this review that ran against a tree that did not move underneath it. Iteration 2 recorded `docs/28_AI_Development_Workflow.md` modified in the working tree mid-review; iteration 3 recorded nothing. F01-41's remedy worked.

I additionally confirmed the fixes I am adjudicating are *in* the frozen commit and not later: `git diff e49aef7 8145333` touches one file (`EXECUTION_LOG.md`, one line). Every artifact fix landed in `e49aef7`, which is an ancestor of the tag.

---

## 2. Disposition of every iteration-2 finding

| ID | Iteration-2 finding | Severity then | Disposition |
| --- | --- | --- | --- |
| N1 / F01-29 | A fix introduced a Register citation that does not resolve (wave-length figures cited to Spawning & Waves), plus an over-reaching "every figure" clause | Major | **Closed, cleanly, with no second defect.** Every clause of the rewritten sentence re-resolved; see section 3. |
| F01-12(b) | The anti-pattern-to-pillar mapping asserted with no decision row, at least one leg the master does not support | Major, carried | **Structurally closed, factually not.** D92 exists and is well made; doc 01 now discloses the mapping as its own work. But the fix's own precision claim — "two legs go beyond the master's wording" — is wrong: a third entry, the solved build, is inferred on both its legs and is not flagged. See section 4 and finding N5. |
| N2 | D91's carve-out did not cover one of the six counts it was written for, and its tie-break over-reached on that case; the *record* was wrong, not the artifacts | Minor | **Closed at the record, which is where it belonged.** D91's "Why this one" now reads "at least one of the counts first listed — the number of pillars in document 01 — was never a gameplay number in the first place and needed no exemption, so the carve-out covers fewer cases than the finding originally claimed". LEDGER F01-11 carries the same correction. CLAUDE.md is unchanged apart from the version reference, which is correct: N2 explicitly said no document change was required. See section 6. |
| N3 | The restored "intent mix" clause was self-undercutting ("the wave's intent mix ... rather than by any single wave") | Minor | **Closed, better than the minimum.** 01:44 now reads "delivered by intent mix rather than by any single wave, as the master states, so every biome must schedule for it". The possessive is gone and the trailing clause restores the biome-level scheduling the master locates it at (master L388: "every biome must schedule Player Hunters often enough that standing still is eventually fatal"). Residue: "schedule for it" compresses away *what* is scheduled (Player Hunters). Nit, recorded, not a finding. The trailing-attribution sweep N3's second half described is unchanged — see section 7, observation O5. |
| N4 | The precedence preamble narrowed the table's domain to feature-versus-feature | Minor | **Closed.** 01:56 now reads "It arbitrates pillar against pillar, whether the conflict arises between two competing proposals or inside a single one that serves one pillar at another's expense". The single-proposal case N4 named as the commoner one is explicitly inside scope. Residue: the elaboration after the colon, and the "Rank 1 therefore still decides" sentence, still speak only in two-proposal terms, so the newly admitted case is asserted but not worked through. Nit, recorded, not a finding. |
| Nit (banned-word) | "passed that gate" at 01:54 would trip a mechanical sweep | Nit | **Closed.** A word-boundary grep for `\bpassed\b` over all three documents returns **zero**. The phrase is now "cleared that test", which stays consistent with the same paragraph's "that test runs first and is binary". |

Ledger accuracy: iteration 2's complaint that `LEDGER.md` recorded F01-12 as "fixed" while describing only the ordering is itself addressed. F01-12's Resolution column now says "**Iteration 2 found this only half closed**" and names what closed the second half. F01-11's row carries N2's narrowing. F01-29 and F01-30 are recorded with accurate finding text and an honest note about the banned-word collision being a class of false positive. The record no longer reads better than the artifacts.

---

## 3. F01-29: the corrected sentence, resolved clause by clause

The brief asked for the corrected sentence to be re-resolved **in full**, because this is a fix to a citation defect. Doc 02 line 31, current text, split into every claim it makes:

| # | Claim | Verdict |
| --- | --- | --- |
| 1 | "The master's Provisional Defaults Policy exempts the ranges stated in Session Shape, and only those, as reference frames rather than Provisional Defaults." | **Correct.** Master L28, last sentence: "Numbers stated as ranges in Session Shape are reference frames, not Provisional Defaults." That is the Policy's only exemption, so "and only those" holds. |
| 2 | "The wave-length figures are not in that exemption: the master states them as a Provisional Default" | **Correct.** Master L226: "A single combat wave targets 40 seconds, with a maximum of 90 seconds (Provisional Default). A Siege wave targets 80 seconds (Provisional Default)." Explicitly tagged, so outside the ranges carve-out. |
| 3 | "the per-wave maximum durations are carried by the Provisional Values Register › Encounter Budgets, **row by row**" | **RESOLVES.** Encounter Budgets carries the maximum in the row title of every wave row: `T1 (max 20 s)`, `T2 (max 25 s)`, `T3 Split, light (max 30 s)`, `T4 Siege, teaching (max 40 s)`, `Combat wave 1 Hunt (max 90 s)`, `Combat wave 2 Siege ×1.5 (max 90 s)`, `Combat wave 3 Split (max 90 s)`, `Combat wave 4 heavy Siege ×2.0, final (max 90 s, C-FINAL)`. "Row by row" is literally true. This is the exact correction F01-29 required, and it lands on the right section. |
| 4 | "The inter-wave gap is in › Spawning & Waves" | **RESOLVES.** Row `Inter-wave gap`: "max(8 s default (5 s after T1, T2, T3), the last encounter's recovery gap)". |
| 5 | "the derived session-length arithmetic in › Onboarding & Session › \"Session arithmetic\" and \"Prototype session length.\"" | **Both RESOLVE**, in that section, titles character for character. |
| 6 | "its figures are left to whichever Register row owns them" | **Correct as hedged.** The absolute "every figure ... the Register row that owns it" that over-reached at iteration 2 is gone, and the exception is stated in the same sentence rather than left implicit. |
| 7 | "the moment-to-moment frame is the only one of the four with no Register row of its own" | **Correct.** I re-derived every Register row title (129 rows across 15 sections) and searched for the four scales' figures. Wave: Encounter Budgets maxima + "Session arithmetic" (40 s / 80 s targets). Biome: "Session arithmetic" ("a biome totals ≈ 10–11 min"). Run: "Session arithmetic" ("total a run ≈ 32–35 min") and "Prototype session length". Moment-to-moment (master's "1 to 3 seconds"): **nothing, anywhere in the Register.** The claim is true on the reading that matters — no row carries its figure. `evidence/p04_report.md` line 128 independently reached the same conclusion at iteration 1. |
| 8 | "it is named as an open question in the Phase 01 ledger rather than given a citation that does not exist" | **RESOLVES.** `LEDGER.md` row F01-06: "A gap in the master: the Moment-to-Moment Loop is the only one of the four loop scales whose stated duration has no Provisional Values Register row", Status "open, owner the author". The pointer is accurate including the status. |

**F01-29 is closed.** No clause of the replacement sentence mis-addresses anything. One looseness, recorded as an observation not a finding: the sentence opens on "the wave-length figures" (master L226 states two of them, a 40 s target and a 90 s maximum) and then addresses only "the per-wave maximum durations". The 40 s and 80 s *targets* live in "Session arithmetic", which the next clause does cite — but labels "the derived session-length arithmetic", which is where they sit rather than what they are. Every figure is reachable through a cited row; only the labelling is loose.

### Citations re-resolved across all three documents

The brief asked for a sample, on the grounds that this is the phase's most fragile property. I resolved **all of them** instead — the mechanical part is cheap once the Register's section-to-row map is derived from the Register's own `##` headings, which is what catches a row cited under the wrong section.

Register citations, 24 of them:

| Doc, line | Citation | Result |
| --- | --- | --- |
| 00:35 | › Arena & Camera (arena dimensions, traversal timing) | Resolves — "Arena size" 4800 × 3200, "Traversal time" 15 s / 10 s. |
| 00:74 | › Onboarding & Session (session arithmetic, biome count, teaching sequence) | Resolves — "Session arithmetic", "Teaching wave budgets". |
| 00:80 | › Interfaces (input timings, menu mechanics) | Resolves — "Platform input floor", "Input map (C-INPUT)", "Movement-only controls setting (C-SECTORS)", "Tower Console rules". |
| 00:87 | › Onboarding & Session › "Three Second Rule probes." | Resolves; carries the full measurable criteria (≥ 8 of 10 stills for ≥ 4 of 5 testers). |
| 01:44 | › Enemies, › Player & Weapons, › Tower | All three sections resolve and each carries one listed item: "Player Hunter" (leash), "Player body / hurtbox …" (body radius 14), "Tower base weapon" (range 480 px). |
| 01:44 | MASTER_SDLC.md › Explicit Anti-Patterns, for the armed player's minimum distance | Resolves, and the *derivation* the sentence describes is exact: master L388 gives "at least 174 px … (160 px radius + 14 px body)", and the Register confirms Interaction Radius = 160 px and player body radius = 14 px. |
| 01:45 | › Progression & Upgrades › "Prototype upgrade pool," and › Economy & Pickups › "Economy dominance measure." | Both resolve, in the named sections. |
| 01:48 | › Technical Caps & Performance › "Run Recorder." | Resolves; carries the C-IDLE threshold. |
| 01:50 | › Progression & Upgrades › "Level-Up Draft." | Resolves; carries the reroll allowance for prototype and slice. |
| 02:19 | Resource & Economy System › Drop Table, and › Economy & Pickups | Both resolve (master L1365; Register row "Drop Table"). |
| 02:21 | › Economy & Pickups, › Progression & Upgrades, › Tower (caps, prices, ratios) | All three resolve — "Scrap", "Cores", "Run-End Settlement"; "Console price"; "Tower Repair price". |
| 02:31 | Encounter Budgets; Spawning & Waves; Onboarding & Session ×2 | All resolve — see the table above. **This is the repaired citation.** |
| 02:39 | › Spawning & Waves; › Technical Caps & Performance › "Run Recorder." | Both resolve ("Inter-wave gap"; C-IDLE). |
| 02:69 | › Spawning & Waves › "Biome sequence." | Resolves. |
| 02:81 | › Combat Rules › "Revive." | Resolves. |
| 02:89 | › Onboarding & Session › "Teaching wave budgets" (×2, limit and landmark) | Resolves and carries both: "within the restored ninety-second onboarding limit"; "Tower understood by end of T2 ≈ 50 s". |
| 02:105 | › Onboarding & Session › "Onboarding compression (Author decision, A1)" | Resolves; the row says "halves T1 and T2 durations and budgets", which is the "fixed proportion" the doc defers to. |
| 02:109 | › Onboarding & Session › "First Siege (T4) outcome (Author decision, A2)"; › Encounter Budgets › "T4 Siege, teaching (max 40 s)." | Both resolve; the Encounter Budgets row carries both deferred tuning targets (≥ 3 of 5 seeds; above 50%). Row title matches character for character. |
| 02:113 | › Combat Rules › "Teaching wave XP (C-XPCAP)." | Resolves. |
| 02:119 | › Onboarding & Session › "Session arithmetic"; › Spawning & Waves › "Biome sequence." | Both resolve; "three such biomes" is in the first, confirming the tie-break rewrite still lands. |
| 02:121 | › Onboarding & Session › "Boss duration targets." | Resolves (Mini-Boss 60 s, Biome Boss 120 s). |
| 02:135 | › Spawning & Waves › "Encounter completion" | Resolves; carries "these four carry no reward". |
| 02:137 | › Spawning & Waves › "Partial reward (C-PARTIAL)." | Resolves; carries "half its reward rounded down". |

Non-Register citations, 6 of them: `MASTER_SDLC.md › Review Decision Log` D88 (L3494) and D92 (L3499) — both present under that heading; `MASTER_SDLC.md › Explicit Anti-Patterns` (L383); `MASTER_SDLC.md › Encounter Types` (L742); `docs/11_Wave_Director.md › "Wave Runtime Model"` (L13) and `› "Encounter Budgets for the Prototype"` (L39) — both present; `Wave Director & Spawning Logic › Wave Runtime Model` — the master's own section (L1724) explicitly redirects that model to `docs/11_Wave_Director.md`, so the citation resolves through the master's pointer.

**Outcome: 30 of 30 citations resolve.** The property iteration 1 established and iteration 2's fix broke is restored.

---

## 4. F01-12(b): the anti-pattern-to-pillar mapping

### Does D92 name a real alternative and give a real reason?

**Yes, on both counts, and it names two alternatives rather than one.**

- Alternative 1: "List the anti-patterns in document 01 without mapping them to pillars, leaving each system document to argue the connection when it needs to."
- Alternative 2: "map only the legs the master's own wording supports and leave the rest unmapped."

Both are genuine positions a designer could take, and alternative 2 is the narrower, more conservative option — it is not a straw man. The reason is substantive and answers the alternatives directly: "The anti-patterns are the project's enforcement mechanism, so which pillar each one protects decides which argument wins when a system document pushes back. Leaving them unmapped would have made every such argument start from scratch; leaving them mapped but unrecorded would have let inference pass as quotation." That satisfies CLAUDE.md's rule. D92 also makes the decision reversible at the right granularity ("leg by leg"), which matches doc 01's "so the author can reverse any leg of it".

### Does doc 01's new paragraph flag the right legs?

Doc 01:42, in full: "The master states each anti-pattern, but does not say which pillar each one enforces. That mapping is this document's own work, recorded as decision D92 … **Two legs go beyond the master's wording** and are flagged here rather than left to look like quotation: the idle minute's entry in the master names neither readability nor failure-must-teach, and the punished experiment's names neither; both mappings are inferred from what the anti-pattern does to the player, not from the master's text."

The umbrella sentence ("That mapping is this document's own work") is right and is the load-bearing disclosure. The **"two legs"** sentence is not right. Here is every one of the seven, checked against the master's own entry text (L387–414) using doc 01's own test — does the master's entry name or state the pillar it is mapped to?

| # | Anti-pattern | Doc 01's mapping | Master's entry, what it actually says | Supported? | Flagged? | Verdict |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | The safe corner | *Two things to protect* | Does not name the pillar, but its second half is entirely about the Tower as a separate guarantee: "The same guarantee holds for the Tower … No armed standing spot covers the whole Tower, so guarding the Tower also demands movement." Two protection targets, both demanding movement. | Substantively yes | No | **Correct.** Anchored in the entry's own text, not quoted verbatim. Acceptable unflagged. |
| 2 | The solved build | *Two things to protect* **and** *Escalation must be visible* together | The entry is two sentences in full: "A single upgrade combination that trivialises all content. Upgrade pools must be checked for dominant pairs." It names neither pillar and contains neither concept — no Tower, no second pool, no escalation, no visibility. A whole-file search finds no other passage linking the solved build to either pillar (the only other hits for "trivialis" and "dominant pair" are the Hunt kiting rule at L812, doc 17's Owns line, and a slice-tagged acceptance test). | **No, on both legs** | **No** | **DEFECT — finding N5.** |
| 3 | The invisible death | *Readability before spectacle* | "Damage that the player could not have seen coming. Every damage source requires a telegraph." The pillar: "the player must always be able to see incoming threats." Near-verbatim overlap. | Yes | No | **Correct.** The strongest leg in the list. |
| 4 | The empty wave | *Two things to protect* | "A wave that generates no decision. Every wave must apply pressure to at least one of **the two health pools**." | Yes | No | **Correct.** Textually anchored on "the two health pools", which is the pillar's subject matter. Looser than #3 but not inferred. |
| 5 | The idle minute | *Readability before spectacle* **and** *Failure must teach* | "Any stretch where the optimal play is to stand still and wait. Downtime is allowed; idleness is not." Names neither. | No | **Yes** | **Correct — flag is right.** This is the leg iteration 1 named as least supportable, and it is now disclosed. |
| 6 | The unreadable screen | *Readability before spectacle* | "Enemy count or particle density that hides threats. Density is capped by **readability**, not by hardware." Uses the literal word. | Yes | No | **Correct.** |
| 7 | The punished experiment | *Failure must teach* | "A build path that is unrecoverable once chosen. Rerolls, banishes, or pivots must exist. Provisional Default: one Reroll per run …" Names neither. | No | **Yes** | **Correct — flag is right.** |

**Result: one entry inferred but not flagged (the solved build, on both of its legs); no entry flagged that is actually supported.** The two flags that were placed are the right ones. What is missing is a third.

Of the solved build's two legs, the *Escalation must be visible* leg is the weaker of the two and is worth naming separately for the author. That pillar's stated content is about **visibility** — "The player should be able to tell how far into a run they are by looking at the screen, without reading a number." Doc 01 justifies the mapping with "collapses the run's escalating pressure into nothing", which is an argument about escalation **existing**, not about it being legible. The leg is therefore not merely un-quoted; it maps to a pillar whose stated content it does not directly engage. The *Two things to protect* leg is the stronger of the two — a build that trivialises all content plausibly does "let the player fully secure both the Tower and themselves at the same time", which is the pillar's literal wording — but it is still an inference, not a quotation.

**F01-12(b)'s disposition: the structural requirement is met and the finding's substance is closed — a Decision Log row exists, it names alternatives, and doc 01 discloses the mapping as its own work. What survives is an accuracy defect inside the fix.** Recorded as N5, Major. Three edits close it: name the solved build as a third inferred entry in doc 01:42, in D92's decision column, and in the 0.8.5 Change Log row. D92's own second alternative — "map only the legs the master's own wording supports" — is the route that would have surfaced this.

---

## 5. Regression sweep

| Check | Result |
| --- | --- |
| Placeholder lint | **Clean.** Case-insensitive grep over all three files for TODO, TBD, TBC, XXX, FIXME, "placeholder", `[ ]`, ASCII `...`, the Unicode ellipsis, and `<angle_brackets>`: zero matches. |
| Banned gate vocabulary, word-boundary grep (`passed`, `passes`, `satisfied`, `satisfies`, `ready`, `met`, `approved`, `accepted`, `stable`) | **`\bpassed\b`: zero. The iteration-2 nit is closed.** Five remaining hits, all pre-existing and none a gate claim: the three Status lines (which exist to *deny* stable status), 01:23 "the gate every feature passes through", and 01:66 "two accepted features" / "already-accepted ideas". The last two are design vocabulary about a game feature, present since iteration 1 and cleared then. Recorded as observation O3 so a later mechanical sweep does not read them as new. |
| Versions still 1.0.0 | **Clean.** Line 3 of all three. |
| Docs 00/01 carry "Owns: none listed in Documentation Structure" verbatim per D85 | **Clean.** Both at line 11, character for character. No Owns entries invented. |
| Doc 02's six Owns entries still resolve to substantive sections | **Clean.** The Owns line still matches Documentation Structure's entry for 02 (master L1966) in content and order, and all six resolve to real `##` headings that do real work: Structure Hierarchy (62), Run Termination Edge Cases (75), Onboarding Edge Cases (87), Boss Cadence And Biomes Per Run (117), Boss Wave Placement (Summary) (125), Encounter Failure Resolution Default (133). |
| No "Phase 0 accepted" or "00/01/02 stable" row in the master's Change Log | **Confirmed not written.** Each string occurs exactly once in the master: "00/01/02 stable" at L3125 inside the Development Phase Map's statement of P0.4's own exit criterion, and "Phase 0 accepted" at L3130 inside Phase 0's exit statement — plus D93 at L3501, which quotes it to record the withholding. The Change Log holds 13 version rows (0.1.0 through 0.8.5) and no gate row. Both new rows (0.8.4, 0.8.5) close with "No gameplay rule, number, or gate changed"; 0.8.4 adds "it does not assert that Phase 01's gate is met, which the reviewers and the author decide". The distinction the brief drew holds: D84–D93 are Decision Log rows, not gate rows. |
| Superseded wording sweep | **Clean.** Whole-repository grep for "the wave's intent mix", "passed that gate", "alongside the inter-wave gap", and "every figure is left to the Register row": zero hits outside `LEDGER.md` and the iteration-2 evidence files, where they appear as the quoted finding text. |
| D91 carve-out still matches what the documents do (see section 6) | **Clean.** |
| Numeral and number-word re-sweep of all three documents | **Clean.** Nothing new attaches a numeral to a gameplay noun. The counts this round introduced are "Two legs" (01:42, a count of mapping legs), "two competing proposals / two acceptable features" (01:56, design procedure), and "four scales / two of them / one of the four" (02:31, the master-stated loop structure). None is a gameplay number. |

---

## 6. D93 and D91, judged

### Is D93's reasoning sound?

**Yes, with one reservation about the route it declined and one wording nit.**

Its factual premises check out. Phase 0 has nine tasks (E0.1, E0.2, P0.1–P0.7); Phase 01 executes three of them (P0.4, P0.6, P0.7), Phase 00 executed the other six — the arithmetic in D93's first sentence is correct. The Gate Approval rule (master L32) reserves the Change Log row to the human designer and permits an AI collaborator only to *propose* its text. D93's claim that the legitimately proposable row "is proposed in `evidence/p04_report.md` and is not written" is verifiable: that file's section 5 is headed "Proposed Change Log Row (PROPOSED ONLY — NOT WRITTEN TO MASTER_SDLC.md)" and states "I have not written to MASTER_SDLC.md at all". Both halves hold.

The reservation: D93 declines even the *conditional* proposal, which is the route the Gate Approval rule most obviously anticipates — proposing text is by construction not deciding, and a proposal flagged conditional on Phase 00's closure presumes nothing. D93 names that alternative explicitly and gives its reason ("without an agent implying a verdict on Phase 00"), so the decision is recorded properly and is defensible; I simply think the declined route was the marginally stronger one. That is a difference of judgement on an author decision, not a defect, and CLAUDE.md reserves it to the author. **Sound.**

The wording nit: D93's reason contains "Recording the withholding **satisfies** what the gate is for". That is the exact lexical collision F01-30's third leg was raised about, and `LEDGER.md` F01-30's own stated remedy was "to avoid the word rather than to argue the sense". The sentence does not claim the gate is satisfied — it claims the gate's *purpose* is served — but it was written into a new master row in the same commit that removed the identical construction from doc 01. Recorded as N7, Nit.

### Does D91's carve-out still match what the documents do?

**Yes.** CLAUDE.md line 15 is unchanged from iteration 2 (this round touched only the version reference, 0.8.4 → 0.8.5), and nothing in this round's edits added a count that tests the rule. Re-running the check against the post-edit text:

| Count | Where | Verdict against D91 as written |
| --- | --- | --- |
| "four nested structures" | 02:64 | Authorised, named exemplar; master L274 verbatim. |
| "the four prototype encounter types" | 02:58, 02:135 | Authorised, named exemplar. |
| "exactly two boss-class encounters" | 02:119 | Authorised, named exemplar. |
| "four loop scales" / "four nested loops" / "four scales" | 02:9, 29, 31 | Authorised without stretching; master states it as structure in a heading ("The Loop Exists At Four Scales", L284) and in prose (L286). |
| "one arena with one mechanical hook", "one or more Encounters", "one playthrough" | 02:68–71 | Authorised; master L275–278 verbatim. |
| "two health pools, one player, one battlefield" | 00:21, 00:55 | Authorised; master L216 verbatim. |
| biome count | 02:119 | **Tie-break honoured, still.** The sentence remains "the number of biomes stated in the Provisional Values Register › Onboarding & Session › 'Session arithmetic', a Provisional Default rather than a fact about the loop's shape", and the row still carries "three such biomes". This is the one case the tie-break was written for and it is still applied. |
| "The Six Pillars" | 01:27 | Outside the parent rule's subject ("every **gameplay** number"), which is now what the record says. N2 is closed at the record; nothing in the document needs to change. |
| "the vertical slice contains one biome, and the prototype contains one arena" | 02:119 | Unchanged from iteration 2. Bare and uncited, in the same sentence that sends the run's biome count to the Register; master L222 states both untagged and the Vertical Slice Scope Freeze lists "One complete biome". Defensible as frozen scope. Carried forward as an observation, not a finding — iteration 2 reached the same conclusion. |

**The carve-out's wording still matches what the documents do, and its tie-break is honoured in the one case that invokes it.**

---

## 7. New findings

| ID | Finding | Severity |
| --- | --- | --- |
| **N5** | **The fix for F01-12(b) under-counts its own inferred legs: the solved build's mapping is inferred on both legs and is not flagged.** Doc 01:42 states "Two legs go beyond the master's wording and are flagged here rather than left to look like quotation", naming the idle minute and the punished experiment. Checked against the master's own entries, a third entry belongs in that list. The master's solved-build entry is two sentences in full — "A single upgrade combination that trivialises all content. Upgrade pools must be checked for dominant pairs" — and names neither *Two things to protect* nor *Escalation must be visible*, nor any concept belonging to either: no Tower, no second health pool, no escalation, no visibility. A whole-file search confirms nothing elsewhere in the master supplies the link. Doc 01's own justification for the *Escalation must be visible* leg ("collapses the run's escalating pressure into nothing") argues that escalation ceases to **exist**, whereas that pillar is about escalation being **visible** — "tell how far into a run they are by looking at the screen, without reading a number" — so that leg does not merely go un-quoted, it engages a different proposition than the pillar states. The consequence is not that a reader is told the mapping is quoted — the paragraph's umbrella sentence, "That mapping is this document's own work", correctly covers all seven, which materially limits the harm. The consequence is that the sentence immediately after it makes a false precision claim, implying the other five legs **do not** go beyond the master's wording when two of them do. The same wrong count propagates to two further places: D92's decision column ("Two legs are inferred rather than quoted") and the 0.8.5 Change Log row ("flags the two legs of that mapping which are inferred"). This is the third iteration in which a fix for F01-12(b) has landed with an inaccuracy about this mapping, which is why it is Major rather than Minor: the finding has now been half-closed twice. Three edits close it — name the solved build as a third inferred entry in doc 01:42, in D92, and in the 0.8.5 row. Note that D92's own second alternative, "map only the legs the master's own wording supports and leave the rest unmapped", is the route that would have exposed it. | **Major** |
| **N6** | **The 0.8.5 Change Log row records D92 and omits D93, although both were added in the same pass.** Master L64 (the 0.8.5 row) names only D92. D93 was written into the Review Decision Log in the same commit (`e49aef7`) and is a Phase 01 decision of exactly the same kind. The 0.8.4 row immediately above it enumerates all eight of its decisions by ID, and the 0.8.3 and 0.8.2 rows do the same, so a reader tracing decisions through the Change Log — which is the master's own stated navigation path ("Reversing any decision requires a Change Log row and a pass over the sections the decision touched, which the Provisional Values Register and this table make findable", L3503) — will not find D93 from there. The master's Versioning Rules require "a matching note in the change log" for a version bump; the note exists, so this is an incompleteness rather than a violation, and D93 is discoverable from `LEDGER.md` F01-42. One clause added to the 0.8.5 row closes it. | Minor |
| **N7** | **D93's reason writes "satisfies" of a gate requirement, in the same commit that removed the identical construction from doc 01.** "Recording the withholding **satisfies** what the gate is for — the author is told, and told why". The claim is about the gate's purpose rather than its status, so I do not read it as asserting that a gate is satisfied, and CLAUDE.md's rule is about the latter. But F01-30's third leg was raised on exactly this collision, and the ledger's own recorded remedy was "to avoid the word rather than to argue the sense". Applying that remedy in doc 01 while writing the same word into a new master row in the same pass is an inconsistency the next mechanical sweep will surface. One word ("serves what the gate is for") closes it. | Nit |

### Observations — recorded, not findings

- **O1.** The Review Decision Log's Markdown table is fragmented by blank lines into six blocks (after D76, D78, D80, D81, D83, D87), so under strict Markdown every row from D84 onward — including D91, D92 and D93 — renders as literal pipe-delimited text rather than as table rows, there being no header/delimiter pair in those blocks. **This is pre-existing**, not introduced by this round: the blank lines at L3477, 3480, 3483, 3485, 3488 and 3493 all predate `e49aef7`. The content is present under the right heading with all four columns, so every citation to it still resolves. Worth a single cleanup pass at some point; outside this review's scope to raise as a defect against P0.4.
- **O2.** Doc 02:31 addresses the per-wave **maxima** but the sentence opens on "the wave-length figures", of which master L226 states two kinds; the 40 s and 80 s targets are reachable only through the "Session arithmetic" row, which the sentence labels "the derived session-length arithmetic". Every figure is reachable through a cited row; only the labelling is loose.
- **O3.** Pre-existing banned-vocabulary collisions that a mechanical sweep will keep reporting: 01:23 "the gate every feature passes through" and 01:66 "two accepted features" / "already-accepted ideas". Both describe a design test on a game feature, both predate iteration 1, and both were cleared then.
- **O4.** 01:56's broadened scope is asserted but not worked through: after the colon the paragraph reverts to two-proposal language ("between two proposals that have both already cleared that test"; "which of two acceptable features sharpens it more"), so what Rank 1 does inside a *single* proposal that pulls two pillars apart — the case the fix newly admits — is left to the reader. The circularity F01-13 identified does not reappear in that case (the gate returns ship / does-not-ship; rank 1 weighs a tension gain against another pillar's cost, which is a different question), but the document does not say so.
- **O5.** N3's second half is unchanged: 01:44's trailing attribution still grammatically sweeps all three listed items into "`docs/09` … and the Provisional Values Register › Enemies, › Player & Weapons, and › Tower", and the armed player's 174 px minimum distance is in none of them. The inline parenthetical names its real source correctly, which is what closed the iteration-1 over-claim, so this is residue rather than an error. I verified the derivation itself is exact (160 px Interaction Radius + 14 px player body, both in the Register).
- **O6.** Carried from iteration 2: "the vertical slice contains one biome, and the prototype contains one arena" (02:119) remains the closest thing to an arguable bare count.

### Things checked that came back clean

Recorded so a later reviewer does not repeat them: all 30 citations in all three documents, resolved against a section-to-row map re-derived from the Register's own `##` headings (129 rows, 15 sections) so a row cited under the wrong section would be caught; the full numeral and number-word sweep of all three documents against D91 as written; all seven anti-pattern mappings against the master's entries verbatim, plus whole-file searches for any other master passage supporting the two solved-build legs; D92's alternatives and reason against CLAUDE.md's rule; D93's premises against the phase table, the Gate Approval rule and `evidence/p04_report.md`; the Change Log for gate rows and for the enumeration pattern of its decision rows; the Owns lines of all three documents against Documentation Structure; the six Owns headings; placeholder lint; the superseded-wording sweep across the whole repository; the ledger rows for F01-11, F01-12, F01-13, F01-14, F01-29, F01-30, F01-06 and F01-42 against the artifacts they describe; and that the fixes under review are inside the frozen commit rather than after it.

---

## 8. Score and reasons

**8 / 10.** Up from 7, and the movement is earned rather than definitional.

What genuinely improved. F01-29, the Major that headed iteration 2's reasons, is closed with no second defect — I resolved the replacement sentence clause by clause because a fix to a citation defect deserves that, and all eight of its claims hold, including the two that are easy to get wrong (that Encounter Budgets carries the maxima "row by row", which is literally true of eight row titles, and that the moment-to-moment frame is the only scale with no Register row, which required re-deriving the whole Register to confirm). The citation property that iteration 1 established and iteration 2's fix broke is not merely repaired but extended: 30 of 30 now resolve, against iteration 1's 20 of 20 and iteration 2's 20-odd with one failure. All three Minors closed, two of them better than the minimum — the intent-mix clause now carries the biome-level scheduling the master actually states, and the precedence preamble now admits the within-one-proposal case N4 named as the commoner one. N2 was closed in the right place: at the record, in D91's reason and LEDGER F01-11, with CLAUDE.md correctly left alone. D92 is a well-made decision row with two real alternatives, one of them the conservative option, and a reason that answers them. D93's reasoning is sound and its verifiable claims verify. The ledger no longer reads better than the artifacts — F01-12's row now says in its own words that iteration 2 found it half closed. And the tree did not move: this is the first iteration whose findings are all about the artifacts rather than partly about the process reviewing them.

The two reasons it does not reach 9 or 10:

1. **N5, Major.** The fix for the carried Major landed its structure and missed its arithmetic. Doc 01, D92 and the 0.8.5 Change Log row all say two legs are inferred; three entries are. The solved build's mapping is exactly as un-quoted as the idle minute's, and one of its two legs argues about escalation existing where the pillar is about escalation being visible. The umbrella disclaimer limits the harm — the reader is told the whole mapping is the document's own work — but the sentence that follows tells them which legs are safe, and it is wrong about two of them. This is the third iteration in which a fix for F01-12(b) has shipped with an inaccuracy about this same mapping. A finding that has been half-closed twice is a finding whose fixes are not being checked against the source they claim to quote, and that is the pattern rather than the instance.
2. **N6 and N7 together, plus the shape they share with N5.** All three are the same failure mode at three sizes: a record written in a hurry that does not quite match what was done. The 0.8.5 row names one of the two decisions its own commit added. D93 uses the word the project had just finished removing from doc 01 for this exact reason. N5 miscounts its own flags. None of the three is a defect in the design or in the documents' substance, and every one of them is a one-clause edit — which is why this is an 8 and not a 6. But three of them in one pass, on top of an iteration whose whole subject was the accuracy of fixes, is why it is not a 9.

For the record, and because the trend matters more than the number: the artifacts themselves are in materially better shape than the score alone conveys. Every citation resolves, every lint is clean, the numbers rule is honoured including its tie-break, the gate row was again not written, and the three documents' substantive claims about the master held under every check I ran.

---

## 9. What this review did NOT check

- **Not re-audited: what iterations 1 and 2 cleared.** Per the brief and decision D83. The Run Termination table, the Loop Entry And Exit Conditions table, doc 00's Project Identity, Perspective, Player Fantasy, Emotional Goals and Platform sections, doc 01's six pillars and its Open Question section, and doc 02's opening narrative were read only for contradiction with the fixes, not traced clause by clause.
- **Not re-derived: D88's rank-by-rank match against doc 01's table.** Iteration 2 verified it rank for rank and neither the table nor D88 changed in this round (`git diff` confirms). I confirmed only that D88 still exists at L3494 and that doc 01:58 still cites it.
- **Not checked: the master beyond the sections named at the head of this report.** Roughly 2,300 lines were searched only by targeted grep. A contradiction between docs 00–02 and the Risk Register, the Acceptance Test Matrix, the Glossary, the Vertical Slice Scope Freeze, or edge-case registers outside Run Termination would not have been caught.
- **Not checked: documents 03–30 for cross-document consistency.** Only the specific claims docs 00–02 make about documents 09, 11, 15, 19, 20 and 27, and for docs/11 only its heading list. I did notice that `docs/11_Wave_Director.md` is at version 0.2.0 while calling itself "Working system document" and stating that it "becomes a working document at 0.5.0"; that is doc 11's problem, not P0.4's, and is outside this brief.
- **Not checked: whether the anti-pattern-to-pillar mapping is the right mapping on the merits.** This report establishes which legs the master's text supports and which are inferred. Whether the inferred ones are *correct* design judgements is the author's call, and D92 records it as reversible leg by leg, which is the point.
- **Not checked: whether the structural-count carve-out should exist.** Established only that D91 exists, names alternatives, and still matches what the documents do. Its merits are an author decision.
- **Not checked: the other Phase 01 tasks.** P0.6 and P0.7, `tests/`, `src/`, the export, `docs/28`, and the ledger rows belonging to them were outside this brief. I read `LEDGER.md` only for the rows bearing on P0.4.
- **Not checked: prose quality, length, or reader usefulness.** Only correctness against the sources and against the project's own rules.
- **Not run: any Godot tooling, test, or build.** No `mcp__godot-*` tool was called, per the brief's constraint. No file was created, edited, or deleted except this report.

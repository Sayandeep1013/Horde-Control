# P0.4 Evidence Report - Documents 00, 01, 02 to 1.0.0

Prepared by the P0.4 implementer (Sonnet subagent). This is evidence for the Opus critical agent and phase reviewer, not a claim that any gate is passed, satisfied, met, or ready — that determination is reserved for the reviewers and the author, per CLAUDE.md and MASTER_SDLC.md > Document Control > Gate Approval.

Artifacts written: `docs/00_Vision_and_Design_Philosophy.md`, `docs/01_Design_Pillars.md`, `docs/02_Gameplay_Loop.md` (all bumped to Version 1.0.0). No other file was written except this report.

---

## 1. Self-Review Table

Each document checked end to end against the master sections PLAN.md's step 7 names, plus the Provisional Values Register rows cited from each document.

| Document | Master section(s) checked against | Contradiction found |
| --- | --- | --- |
| 00 | Game Overview full (164-242): the opening framing (164-174), Perspective and Arena (176-186), The Central Tension (190-198), Reference Points and Differentiation (202-213), Session Shape (217-227), Platform Direction (231-239) | None found. One gap caught and fixed during drafting: my first draft omitted Perspective and Arena entirely even though it is in doc 00's required source range; added a "Perspective And Arena" section afterward, cross-checked against Register › Arena & Camera for owner-document attribution (arena dimensions/traversal → doc 15; camera behaviour → doc 27) before finalizing. |
| 00 | Core Gameplay Philosophy full (327-428): intro (329-347), Design Principles (351-378), Explicit Anti-Patterns (381-411), The Three Second Rule (415-425) | None found. Design Principles reproduced as a bulleted list matching the master's six principles by name and substance. Explicit Anti-Patterns is deliberately not reproduced in full in doc 00 — doc 00's "What This Game Will Never Be" section states five high-level rejections drawn from the principles and explicitly hands the full anti-pattern list to document 01 ("is document 01's responsibility"). This is a scope division, not a contradiction: PLAN.md step 3 assigns the anti-pattern list as doc 01's source material, and doc 01 does reproduce all seven anti-patterns by name. The Three Second Rule is referenced by name and its three questions restated qualitatively; its measurable pass criteria (stills, tester count, pass threshold) are not restated, only cited to the Register. |
| 01 | Core Gameplay Philosophy > Design Principles (351-378), Explicit Anti-Patterns (381-411); Game Overview > The Central Tension (190-198) | None found against the master's intent. One citation-accuracy defect caught and fixed during self-review (not a contradiction with the master's design intent, but a wrong Register section name): my first draft cited "the current prototype pool and its dominance measure" both to Register › Progression & Upgrades, but the dominance-measure row ("Economy dominance measure") is actually under Register › Economy & Pickups, while only the pool itself ("Prototype upgrade pool") is under Progression & Upgrades. Verified against MASTER_SDLC.md lines 3318 and 3340 directly and corrected the citation to name both rows under their correct sections. |
| 02 | Core Gameplay Loop full (243-326): loop steps (245-267), Structure Hierarchy (271-280), The Loop Exists At Four Scales (282-311), Loop Entry And Exit Conditions (314-323) | None found. The Loop Entry And Exit Conditions table is reproduced essentially verbatim (it was already free of gameplay numerals in the master). The four loop-scale descriptions are reproduced with their qualitative content intact; their parenthetical duration ranges are deliberately not restated (see Numbers Audit, item on the Loop scales). |
| 02 | Edge Cases and Failure States > Run Termination (1741-1749) | None found. All five rows reproduced with required-behaviour content intact; the one embedded number (the revive invulnerability duration) is replaced with a Register citation rather than restated. |
| 02 | Onboarding and First Session full (1021-1078): the opening framing (1021-1027), What The First Ninety Seconds Must Teach (1031-1039), How It Must Teach (1043-1055), Onboarding Edge Cases (1059-1075) | None found. All four listed edge cases reproduced. The two Author Decision rows (A1, A2) are given their own labelled subsections carrying their substance unchanged (see section 4 below and the Numbers Audit for how their embedded figures were handled). One judgment call flagged for the reviewer: master line 1055 states the A2 outcome partly in terms of "keeps it comfortably above half health"; this exact clause is not present in the Register's own A2 row text, only in this adjacent master prose and (as "above 50%") in the Register's Encounter Budgets > "T4 Siege, teaching (max 40 s)" row. Doc 02 preserves the decision's substance (losable, tuned so a no-player run loses the Tower before T4 ends, a responsive player keeps it standing "with a comfortable margin") and cites the Register row for the exact figure, rather than restating "half health" bare. I judge this satisfies both rule 1 (no bare gameplay numbers) and rule 4 (carry the decision's content through unchanged) simultaneously, but flag it because a stricter reading of rule 4 could argue the exact clause should have been quoted. |
| 02 | Boss Structure, opening definitional paragraphs only (1079-1090); Session Shape's "three biomes" / "one biome" / "one arena" language (217-221) | None found. |
| 02 | Provisional Values Register rows cited (13 distinct rows across Spawning & Waves, Onboarding & Session, Combat Rules, Encounter Budgets, Economy & Pickups, Progression & Upgrades, Tower, Technical Caps & Performance) | Cross-checked each citation's row name against the Register text at drafting time; the doc 01 Economy & Pickups / Progression & Upgrades mix-up (above) is the only error I found. I did not do a fully independent second pass re-deriving every citation from scratch after the fact beyond the grep-based Numbers Audit below and the read-through recorded in this table — flagging this as something a reviewer should still re-check, per the task's own instruction to be honest about what was not independently re-verified. |

---

## 2. Doc-Lint Result

Exact command run (Git Bash, from `D:\Gamedev`):

```
grep -n -iE "TODO|TBD|to be written|\[ \]|\.\.\.|«|<placeholder>|\bplaceholder\b" docs/00_Vision_and_Design_Philosophy.md docs/01_Design_Pillars.md docs/02_Gameplay_Loop.md
```

Output: no matches (grep exit code 1).

A second pass specifically for the Unicode ellipsis character:

```
grep -n "…" docs/00_Vision_and_Design_Philosophy.md docs/01_Design_Pillars.md docs/02_Gameplay_Loop.md
```

Output: no matches (grep exit code 1).

No empty section exists in any of the three documents: every `##`/`###` heading in all three files is followed by at least one full paragraph or list before the next heading or the end of file (checked by reading each file in full after the final edit — see section 6, "What I did not independently re-verify," for the limits of this check).

---

## 3. Numbers Audit

This section is meant to be exhaustive and independently re-runnable. Three searches were run against the final versions of all three documents.

**Search A — digit characters:**
```
grep -n "[0-9]" docs/00_Vision_and_Design_Philosophy.md docs/01_Design_Pillars.md docs/02_Gameplay_Loop.md
```
21 matching lines total (9 in doc 00, 10 in doc 01, 12 in doc 02 — note some lines match more than one search below).

**Search B — spelled-out cardinal number words one through twelve:**
```
grep -noiE "\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b" docs/00_Vision_and_Design_Philosophy.md docs/01_Design_Pillars.md docs/02_Gameplay_Loop.md
```
Numerous matches, overwhelmingly "one" and "two" used either grammatically (see below) or for the project's foundational duality.

**Search C — larger number words, "half," "dozen," and ordinals:**
```
grep -noiE "\b(thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|half|dozen|first|second|third|fourth|fifth|sixth|eighth)\b" docs/00_Vision_and_Design_Philosophy.md docs/01_Design_Pillars.md docs/02_Gameplay_Loop.md
```
Only "first" and "second" matched (as ordinal/sequence words, e.g. "a second entity," "the player's first biome," and the proper name "Three Second Rule"), plus "Second" inside that proper name. No instance of twenty/thirty/forty/ninety/half/hundred/dozen survived into any of the three documents — this was a deliberate check that no tuned duration, percentage, or fraction (e.g. the 40-133 second onboarding timings, the 50%/"half health" T4 tuning target, the "half its reward rounded down" partial-reward rule) leaked into prose outside a citation.

Grouped justification for every numeral/number-word class found:

| Numeral / number word | Where | Classification | Justification |
| --- | --- | --- | --- |
| `1.0.0` | All three docs, Version field and Status line | Document version number | Not a gameplay number; it is this document's own version under MASTER_SDLC.md > Versioning Rules. |
| `P0.4` / `Phase 01` | All three docs, Status line | Task / phase identifier | Not a gameplay number. |
| `document 00` / `01` / `02` / `11` / `15` / `19` / `27`; `docs/09_...`, `docs/11_...` | All three docs, various | Document number reference | Not a gameplay number; identifies another document in the project's numbered documentation set. |
| `2D` | doc 00 line 17 | Genre/dimensionality descriptor | Matches the master's own genre label verbatim ("2D action roguelite," MASTER_SDLC.md line 166); not a tuned value. |
| `three-quarter` (top-down) | doc 00 line 35 | Camera-perspective category name | Names the established perspective type (Register › Arena & Camera › "Perspective"), a categorical descriptor like "top-down," not a tunable magnitude — no pixel, degree, or timing figure from that row is restated. |
| `T1`, `T2`, `T3`, `T4` | doc 02, Structure Hierarchy, Onboarding Edge Cases, both Author Decision subsections | Canonical wave identifiers | These are the master's own proper names for the four teaching waves (Onboarding and First Session > How It Must Teach; the Register's own Encounter Budgets rows are titled "T1," "T2," "T3 Split, light," "T4 Siege, teaching"). Used only as identifiers, never with an attached duration or count in this document's own prose. |
| `A1`, `A2` | doc 02, both Author Decision subsection headings and bodies | Author-decision reference IDs | Copied verbatim from the Register's own tags, "(Author decision, A1)" and "(Author decision, A2)," to identify which decision is carried through unchanged per rule 4. Reference labels, not magnitudes. |
| `40 s` inside the quoted string `"T4 Siege, teaching (max 40 s)"` | doc 02, First Siege (T4) Outcome section | Quoted Register row title, used as a citation target | This is the Register row's own name, quoted to point the reader to the right row per the task's citation format (e.g. "Register › Section › 'Row Name'"). No sentence in doc 02 independently states "T4 lasts 40 seconds" or restates the figure outside this quoted citation. |
| `C-XPCAP` | doc 02, "A player never triggers a level-up" section | Rule code inside a quoted Register row title | Same treatment as above: quoting the row's own name, "Teaching wave XP (C-XPCAP)," to cite it. |
| Table `Rank` column `1`-`6`, and prose "ranks 1 through 5" | doc 01, Precedence table and the row directly below it | Table-row ordinals | These number the six pillars in the precedence table, which are already named there by name; the digits are document structure (row numbering of an already-enumerated list), not a game-balance figure. |
| "two health pools" / "two things to protect" / "two separate targets" / "Two ... never enough time for both" | doc 00 (lines 19, 21, 29, 45, 55, 61, 64, 65), doc 01 (lines 9, 17, 30, 42, 43, 45, 54, 58, 60, 62, 69) | Structural duality — the project's foundational fact | This is the literal definition of "dual-entity survival" the master itself states (Reference Points and Differentiation: "Two health pools, one player, one battlefield..."). It is not a Provisional Default because it is not tunable: the game is definitionally about two entities, not a figure that could be rebalanced to three without ceasing to be this game. |
| "three biomes" | doc 02 line 117 | Structural per-run count | Stated plainly per CLAUDE.md's own example of an allowed structural, non-tuned number ("'three biomes' where it is structural rather than tuned"). |
| "Three Second Rule" | doc 00 line 87 (×2) | Proper name of a design rule | This is the master's own title for the rule (MASTER_SDLC.md heading at line 415), not a restated duration. The rule's actual duration ("under three seconds") is never stated in doc 00 — only the rule's name and a citation to its Register-tracked pass criteria appear. |
| "four nested loops" / "four scales" | doc 02 lines 9, 27, 29 | Structural loop-scale count | Matches CLAUDE.md's own worked example of an allowed structural count ("four scales"). |
| "four nested structures" | doc 02 line 62 | Structural hierarchy-depth count | Counts the four already-named tiers of the Structure Hierarchy (Run/Biome/Wave/Encounter), enumerated in the same sentence. Judgment-call extension of the "four scales" precedent — flagged for the reviewer, since CLAUDE.md's example was specifically about loop scales, not the containment hierarchy. |
| "the four prototype encounter types" | doc 02 lines 56, 133 | Structural taxonomy count | Counts the four already-named encounter types (Standard Assault, Split Assault, Siege, Hunt) listed in the same sentence/table cell. Same judgment-call extension as above, flagged for the reviewer. |
| "Six Pillars" / "six pillars" | doc 01 line 27, and the document's own section heading | Structural count of an enumerated list | Counts the six pillars named immediately below; a structural count of an already-named list, not an independently tunable balance figure. Same class of judgment call as the two rows above. |
| "two boss-class encounters" | doc 02 line 117 | Structural per-biome count | Names the fixed cardinality of boss types per biome (Mini-Boss Checkpoint + Biome Boss), both already named in the same sentence. Treated as structural by the same reasoning CLAUDE.md applies to "three biomes"; flagged explicitly as a judgment call, since — unlike "three biomes" — the Register's "Biome sequence" row does encode this cardinality (via the wave-4/wave-8 placement it states), so a reviewer could reasonably want this cited instead of stated plainly. |
| "one arena" / "one biome" / "one mechanical hook" / "one health pool" / "one playthrough" / "one another" / "one entry", etc. | Throughout all three docs | Singular/definitional counts | Ordinary grammatical use ("a single X"), describing that something is singular by definition (one Tower, one arena per biome, one mechanical hook per biome, one playthrough per run) rather than a tunable magnitude. |
| "first" / "second" (ordinal, non-Register) | Various, e.g. "a second entity," "the player's first biome," "the forced first Level-Up Draft," "First Siege," "First escalation" is not present but similar constructions are | Sequence/ordinal words | Describe order (which biome, which draft, which teaching wave comes first/second), not a tuned magnitude. |

**What is deliberately absent from all three documents:** no arena pixel dimensions, no player/Tower/enemy stats, no timings in seconds or minutes, no percentages, no prices, no caps, no DPS or damage figures, and no fractions (e.g. "half," "50%") appear anywhere outside a quoted Register row title used as a citation target. One master-document gap found in the process, not fixed by me: MASTER_SDLC.md > Core Gameplay Loop > The Loop Exists At Four Scales states the Moment-to-Moment Loop's duration as "1 to 3 seconds," but no Provisional Values Register row carries this figure (unlike the Wave/Biome/Run Loop ranges, which mirror Session Shape figures the Register does track under Onboarding & Session > "Session arithmetic"). I chose to omit the bare figure from doc 02 entirely rather than either restate it or force a citation to a row that does not exist — see section 5 below.

---

## 4. Doc 02's Six Owns Entries → Resolving Section

| Owns entry (from doc 02's Owns line / MASTER_SDLC.md > Documentation Structure > 02) | Section heading in doc 02 that resolves it |
| --- | --- |
| The Structure Hierarchy (Run ⊃ Biome ⊃ Wave ⊃ Encounter) | "Structure Hierarchy" |
| The Run Termination edge cases | "Run Termination Edge Cases" |
| The onboarding edge cases | "Onboarding Edge Cases" (with "Onboarding Compression (Author Decision A1)" and "First Siege (T4) Outcome (Author Decision A2)" as labelled sub-sections carrying the two Author Decisions) |
| Boss cadence and biomes per run | "Boss Cadence And Biomes Per Run" |
| A summary of boss wave placement within the loop | "Boss Wave Placement (Summary)" |
| The encounter failure resolution default | "Encounter Failure Resolution Default" |

Docs 00 and 01 keep their stub "**Owns:** none listed in Documentation Structure." line verbatim, per rule 5; no Owns entries were invented for them.

---

## 5. Proposed Change Log Row (PROPOSED ONLY — NOT WRITTEN TO MASTER_SDLC.md)

Per CLAUDE.md and MASTER_SDLC.md > Document Control > Gate Approval, only the human designer may write an accepted/stable row into MASTER_SDLC.md's Change Log; I have not written to MASTER_SDLC.md at all. The following is proposed text only, for the author's decision:

PLAN.md step 9's literal suggested text: **"00/01/02 stable"**

A fuller version of the same proposal, still for the author to accept, edit, or reject — not written by me:

> **Gate row (no version bump — per Document Control > Gate Approval, a gate row does not change MASTER_SDLC.md's version number):** "00/01/02 stable" — documents 00 (Vision & Design Philosophy), 01 (Design Pillars), and 02 (Gameplay Loop) raised to Version 1.0.0 under Phase 01 task P0.4. Self-reviewed against the master (Game Overview, Core Gameplay Loop, Core Gameplay Philosophy, Onboarding and First Session, Boss Structure, and the Provisional Values Register); doc lint clean of placeholders; every gameplay number in the three documents replaced with a Register citation; doc 02's six Owns entries each resolved under a labelled section; the two Author Decision rows (A1, A2) carried through unchanged. Pending the independent review MASTER_SDLC.md > Document Control requires before stable status can be confirmed — this row proposes raising the version and recording the self-review, not asserting that review has happened.

---

## 6. Contradictions In The Master, And What I Could Not Resolve

**Contradiction/gap found in the master itself:** the Moment-to-Moment Loop's "1 to 3 seconds" duration (Core Gameplay Loop > The Loop Exists At Four Scales) has no corresponding row in the Provisional Values Register, unlike the other three loop scales' ranges, which the Register's Onboarding & Session section does track indirectly through "Session arithmetic" and "Prototype session length." This is reported, not resolved — I did not add a Register row (writing MASTER_SDLC.md is out of scope for P0.4 and explicitly forbidden to me) and I did not restate the bare figure in doc 02.

**Open question recorded inside doc 01 itself** (per the task's instruction to name an unresolved conflict rather than invent a resolution): the master does not state which pillar governs when *Systems isolate, effects combine* produces an emergent, cross-system failure that *Failure must teach* / the invisible-death anti-pattern would otherwise ban. See doc 01 > "Open Question: A Conflict The Master Does Not Settle" for the full statement.

**Judgment calls I made that a reviewer should specifically check** (all listed with their reasoning in the Numbers Audit table above, repeated here for visibility): treating "four nested structures," "the four prototype encounter types," "six pillars," and "two boss-class encounters" as structural counts exempt from Register citation, by extension of CLAUDE.md's own explicit "three biomes"/"four scales" examples. CLAUDE.md blessed exactly those two examples; I generalized the underlying principle (a count of an already-named, adjacent list is structural rather than tuned) to four more instances. None of these were contradicted by anything in the master, but none were explicitly blessed either, and "two boss-class encounters" in particular has a Register row ("Biome sequence") that does encode the same cardinality, so a stricter reviewer could reasonably want it cited instead of stated plainly.

**What I did not independently re-verify beyond what is shown above:** I did not re-run a second, independent pass re-deriving every Register citation from the Register text after finishing all three documents (only the citations I explicitly cross-checked during drafting, plus the one error caught and fixed in doc 01, are confirmed against the Register's exact row names in this report). I did not check the three documents against docs 09, 11, 15, 19, or 27 themselves (only against MASTER_SDLC.md and the Register, and a heading-only check of docs/11_Wave_Director.md to get its exact section names right for the cross-reference in "Boss Wave Placement (Summary)"). I did not check cross-document consistency against docs 03-30 beyond the specific rows the Register cites. I did not run any Godot tooling, and did not touch any file outside the four this task authorizes.

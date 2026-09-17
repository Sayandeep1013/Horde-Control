# Phase 01 - Contracts, Core Documents, Harness

Status: Not started; Executes: MASTER_SDLC.md > Development Phase Map > Phase 0 - Foundations (no gameplay code), tasks P0.4, P0.6, P0.7 of that phase's seven; Plan task IDs: P0.4, P0.6, P0.7

## Goal

Bring `docs/00.md`, `docs/01.md`, `docs/02.md` to 1.0.0; write one typed Godot `Resource` schema per prototype-scope data contract under `src/data/`; configure a headless gdUnit4 test harness. This is phases/README.md's phase-table row 01 outcome: "Typed data-contract schemas, documents 00-02 stable, and a headless test harness."

## Entry conditions

- Phase 00 (Environment & Connection) exit criteria recorded: connection matrix rows recorded with evidence; `git log` shows the master's first commit; Settings check (P0.2) recorded; docs/28 at 1.0.0 naming the primary connection method, the fallback, and both pinned Godot MCP server versions (phases/README.md phase-table row 00 gate).
- The Godot 4.7.1 project skeleton exists (P0.2 deliverable): P0.6 and P0.7 both list P0.2 as a dependency in MASTER_SDLC.md's Development Phase Map.
- `docs/00.md`, `docs/01.md`, `docs/02.md` exist as 0.1.0 stubs with title, remit, and an "Owns:" list copied from Documentation Structure (P0.3 deliverable).
- At the time this PLAN.md was written, `D:\Gamedev\phases\PHASE_00_Environment_And_Connection\` exists as an empty folder with none of its own five files (no PLAN.md, EXECUTION_LOG.md, FAILURE_POINTS.md, REVIEW.md, or LEDGER.md). See "Open questions for the author" below - this is reported, not resolved, here.

## Carried lessons

phases/LESSONS.md and every earlier phase's EXECUTION_LOG.md, FAILURE_POINTS.md, and REVIEW.md are read at phase entry (loop rule (a), phases/README.md), and the patterns that apply are written into this section before implementation starts. At the time this PLAN.md was drafted, phases/LESSONS.md contains no rows ("no phase has run yet") and Phase 00's own log files do not yet exist, so no lessons are carried in yet. Before real execution of this phase begins, this section must be updated with whatever Phase 00 recorded, per loop rule (a).

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P0.4 | Write documents 00, 01, 02 to stable | `docs/00.md`, `docs/01.md`, `docs/02.md` at 1.0.0 | none formal (MASTER_SDLC.md Development Phase Map) | Self-review against MASTER_SDLC.md finds no contradiction; doc lint: zero placeholders; every Owns entry has a resolved or accepted row; a Change Log row "00/01/02 stable" is proposed | 00 (consults 01, 02) | M | Sonnet (implementer) |
| P0.6 | Write the data contract schemas | `src/data/*.gd` schemas | Schema check (P0.6) | Every prototype contract field has a typed export; scripts load with no errors | 20 | M | Sonnet (implementer) |
| P0.7 | Test harness | Configured gdUnit4 harness | Harness check (P0.7) | A trivial test runs headless and reports pass/fail | 20 | S | Sonnet (implementer) |

## Step-by-step implementation

### P0.4 - Documents 00, 01, 02 to 1.0.0

1. Confirm the entry state: docs/00.md, docs/01.md, docs/02.md exist as 0.1.0 stubs (P0.3 deliverable) with title, remit, and an "Owns:" list per MASTER_SDLC.md > Documentation Structure > 00 - Vision & Design Philosophy, > 01 - Design Pillars, > 02 - Gameplay Loop. Note that only doc 02's Documentation Structure entry currently states an explicit "Owns:" list (Structure Hierarchy, Run Termination edge cases, onboarding edge cases, boss cadence and biomes per run, boss wave placement summary, encounter failure resolution default); docs 00 and 01 carry no explicit Owns list in that section as written.
2. Draft doc 00 (Vision & Design Philosophy - vision, player fantasy, design principles, emotional goals, project identity) from MASTER_SDLC.md > Game Overview in full (Perspective and Arena, The Central Tension, Reference Points and Differentiation, Session Shape, Platform Direction) and > Core Gameplay Philosophy (Design Principles, Explicit Anti-Patterns, The Three Second Rule).
3. Draft doc 01 (Design Pillars - the non-negotiable principles, and which one wins when two good ideas conflict) from MASTER_SDLC.md > Core Gameplay Philosophy > Design Principles and > Explicit Anti-Patterns, and from > The Central Tension (Game Overview).
4. Draft doc 02 (Gameplay Loop - the full flow from run start through biome completion, at all four loop scales) from MASTER_SDLC.md > Core Gameplay Loop in full (the loop steps, The Loop Exists At Four Scales, Loop Entry And Exit Conditions), then resolve every item in its Owns list: the Structure Hierarchy (Run > Biome > Wave > Encounter, from > Core Gameplay Loop > Structure Hierarchy); the Run Termination edge cases (> Edge Cases and Failure States > Run Termination); the onboarding edge cases (> Onboarding and First Session > Onboarding Edge Cases, and the surrounding > What The First Ninety Seconds Must Teach / > How It Must Teach sections for context); boss cadence and biomes per run (> Core Gameplay Loop's Mini-Boss Checkpoint / Biome Boss placement, plus the boss-duration and biome-count figures in the Register - see step 5); a summary of boss wave placement (the detailed spawn-suppression and budget rules stay owned by document 11, so doc 02 states only the summary and cross-references document 11 rather than duplicating it); and the encounter failure resolution default (> Core Gameplay Loop > Loop Entry And Exit Conditions).
5. While drafting, replace every literal gameplay number with a citation to its Provisional Values Register row instead of restating the figure, per CLAUDE.md > Rules for any agent working here ("Every gameplay number lives in the Provisional Values Register; every other place references it"). In particular, doc 02's onboarding and boss-cadence content cites MASTER_SDLC.md > Provisional Values Register > Onboarding & Session rows by name (for example "Teaching wave budgets", "Boss duration targets", "Session arithmetic", "Prototype session length"), and doc 00's Session Shape and arena content cites the > Arena & Camera and > Engine & Platform rows, rather than restating any of those numbers in doc 00/01/02 prose.
6. Two rows drafted into doc 02 are tagged "Author decision" in the Register (Onboarding & Session > "First Siege (T4) outcome", A2; > "Onboarding compression", A1). Carry their content into doc 02 unchanged and do not alter their substance; CLAUDE.md reserves changes to author-decision rows for the author's approval.
7. Self-review each of the three drafted docs against MASTER_SDLC.md end to end, specifically checking for contradiction with Game Overview, Core Gameplay Loop, Core Gameplay Philosophy, the Structure Hierarchy, Run Termination, Onboarding Edge Cases, and the Register rows cited in step 5.
8. Run a doc lint pass for zero placeholders, per MASTER_SDLC.md > Document Control's stable-document requirement ("it contains no placeholder"). Confirm every Owns entry doc 02 lists has a resolved-or-accepted disposition recorded in the doc itself (docs 00 and 01 have no Owns entries to resolve under the current Documentation Structure wording - see step 1 and "Open questions for the author").
9. Bump each doc's version header to 1.0.0. Propose, but do not write, a MASTER_SDLC.md Change Log row reading "00/01/02 stable"; MASTER_SDLC.md > Document Control > Gate Approval reserves writing an accepted/stable row into the Change Log for the human designer, and an AI collaborator may only propose the row's text.
10. Record the self-review outcome, the doc-lint result, and the proposed Change Log row text in EXECUTION_LOG.md.

### P0.6 - Data contract schemas

1. Confirm the P0.2 deliverable (Godot 4.7.1 project skeleton) exists so `src/data/` can be created inside it.
2. For each of the eleven prototype-scope contracts - Enemy, Encounter, Wave, Upgrade, Tower, Tower Upgrade, Weapon, Pickup, Player, Director Configuration, Economy Configuration - read its required field list in MASTER_SDLC.md > Content Data Contracts > `<Contract>` Definition Contract, then read every field's type and meaning in docs/20_Technical_Architecture.md > Contract Field Semantics: the "Shared fields and struct types" table for fields reused across contracts, and the contract-specific field table beneath it for fields unique to that contract.
3. Create one Godot `Resource` script per contract under `src/data/` (for example `src/data/enemy_definition.gd`), each `extends Resource` with a `class_name`, carrying one typed `@export` per required field, typed exactly as docs/20's Contract Field Semantics states (string, integer, float, boolean, typed enum, nullable value, or a nested Resource for a compound field).
4. Represent every shared struct type that docs/20 lists once (Telegraph data, Spawn group, Movement profile, Attack profile, Effect, Overtime condition, Pressure Metric constants, Drop table, Reward, Readability profile, and the others in that table) as its own small `Resource` script under `src/data/`, reused by every contract that needs it, matching docs/20 Contract Field Semantics' own statement that shared field and struct types "are typed once."
5. Represent every enum field (Target intent, Contact behaviour, Pool ownership, Encounter type, Difficulty band, and the rest in Contract Field Semantics) as a Godot `enum` whose member list matches Contract Field Semantics exactly.
6. Leave the Biome, Boss, Elite Affix, and Status Effect contracts untyped in this task; they are explicitly out of scope for P0.6 (MASTER_SDLC.md P0.6 row, Scope out) and are typed before Phase 3 per docs/29_Milestones_and_Roadmap.md's Deferred Review Findings item P6.
7. For every field docs/20 marks nullable (for example Maximum duration, Band label, Arena sub-region bounds), pick one nullable-export convention and apply it to every schema consistently (for example a typed default paired with a boolean "is set" export, or an untyped `Variant` export with a documented null meaning); record the chosen convention once in EXECUTION_LOG.md.
8. Author one sample `.tres` resource per contract under a sample path separate from real content (for example `src/data/samples/`), with every required field populated by a non-default, clearly-a-placeholder value (so an accidentally-unset field cannot be mistaken for an intentionally-populated one).
9. Load every schema script and every sample `.tres`, confirming zero script errors and that each sample validates with no missing required field, matching Acceptance Test Matrix > Build Checks > Schema check.
10. Record, per contract, the field name to Godot type mapping actually implemented in EXECUTION_LOG.md, so a reviewer can diff it against docs/20 Contract Field Semantics without re-deriving it from the scripts.

### P0.7 - Test harness

1. Confirm the P0.2 deliverable (project skeleton, including the pinned Godot 4.7.1 export templates) exists.
2. Check whether Phase 00's E0.2 task (Godot skill installation, phases/README.md phase-table row 00) already installed and verified a gdUnit4-based skill against the sandbox project at `D:\Gamedev\sandbox\connection_test` (NEXT_SESSION.md Prompt 3, step 4-5). If so, reuse that installation's gdUnit4 path and version in the real project rather than installing a second copy, per this task's own note.
3. If no gdUnit4 path exists yet from E0.2, add the gdUnit4 addon to the real project under `addons/gdUnit4`, matching the Godot 4.7.1 pin stated in MASTER_SDLC.md > Godot 4.x Implementation Standards > Version.
4. Configure gdUnit4 to run headless through the pinned console executable, `Godot_v4.7.1-stable_win64_console.exe --headless`, matching the exact invocation Acceptance Test Matrix > Build Checks > Harness check names.
5. Author one trivial passing test and one trivial failing test (for example `test/harness/test_trivial.gd`), asserting a true condition and a deliberately false condition respectively.
6. Run both through the headless console executable and capture the process exit code for each, confirming the passing suite and the failing suite report distinct, correct pass/fail exit codes.
7. Record the exact command line used, both exit codes, and the gdUnit4 addon version in EXECUTION_LOG.md.
8. Record the gdUnit4 version pin location: if E0.2 already recorded it in docs/28, cross-reference that entry here; if not, flag in EXECUTION_LOG.md that the gdUnit4 version is not yet pinned anywhere, since a gdUnit4 version drifting from Godot 4.7.1 is a predetermined risk for this phase (see below).

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Schema check | MASTER_SDLC.md > Acceptance Test Matrix > Build Checks | Result of validating every contract's sample `.tres` per P0.6 step 9 |
| Harness check | MASTER_SDLC.md > Acceptance Test Matrix > Build Checks | Both trivial-test exit codes per P0.7 step 6 |

In addition, per phases/README.md's phase-table row 01 gate: doc lint clean on documents 00-02 (P0.4 step 8); the master's "Phase 0 accepted" Change Log row proposed to the author, never written by an agent (MASTER_SDLC.md > Document Control > Gate Approval). This document does not assert that the gate is passed, satisfied, met, or ready; the reviewers and the author decide that.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A contract field typed differently from docs/20's Contract Field Semantics | Eleven contracts and a shared-struct table make it easy to guess a type (for example typing Health as float instead of integer, or Target intent as a free string instead of an enum) instead of checking docs/20 field by field | The implementer reads docs/20 > Contract Field Semantics field by field before writing each `@export` (P0.6 step 2); the EXECUTION_LOG field-to-type list (P0.6 step 10) exists specifically so this can be checked without re-reading the scripts | Critical agent cross-checks every `@export` against Contract Field Semantics; Schema check failing to load or validate a sample with a type-mismatched field |
| A `.tres` sample that validates while leaving a required field unset | Godot resources fall back to an export's default value when a `.tres` omits a field, so a sample can load cleanly without every required field actually being populated | Every required export gets a non-default, clearly-a-placeholder value (P0.6 step 8), not an empty string or a zero that could also mean "unset" | Critical agent diffs the sample `.tres` field list against the contract's required field list in MASTER_SDLC.md > Content Data Contracts, rather than trusting a clean load alone |
| gdUnit4's version drifting from Godot 4.7.1 | gdUnit4 is a third-party addon versioned independently of the engine; this task is told to reuse whatever E0.2 installed, and no gdUnit4 version is pinned in docs/28 yet | Record the exact gdUnit4 addon version in EXECUTION_LOG.md (P0.7 step 7-8) alongside the two Godot MCP server versions P0.5 already pins, matching the pattern MASTER_SDLC.md > Risk Register uses for "Godot MCP servers drift from the pinned engine version" | Headless run behaving differently from an editor run of the same test; reviewer checks whether a gdUnit4 version is recorded anywhere against its stated Godot 4.7.x compatibility |
| Documents 00-02 restating numbers instead of referencing the Register | Prose about Session Shape, onboarding timing, and boss cadence reads naturally with literal numbers inline, and the existing stub text may already carry some of that phrasing | Every number drafted into docs 00-02 is replaced with a Provisional Values Register row citation (P0.4 step 5) instead of the literal figure | Doc lint / self-review pass specifically checks drafted text for bare numerals attached to gameplay nouns and confirms each has a Register citation or is not a gameplay number |
| The author's gate row being written by an agent (banned) | The natural next action after P0.4's self-review and P0.6/P0.7's passing checks is to add the "Phase 0 accepted" Change Log row, and that step is easy to do reflexively once everything else looks done | This PLAN.md and its exit criteria only ever "propose" the row's text (P0.4 step 9; Exit criteria section above); MASTER_SDLC.md > Document Control > Gate Approval reserves writing it for the human designer | Reviewer checks that MASTER_SDLC.md's Change Log has no new accepted/stable row unless the designer is recorded as its author; EXECUTION_LOG.md shows only a proposed row text, never a committed one |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P0.4 document drafting; P0.6 schema scripts and sample resources; P0.7 harness configuration and trivial tests).

Opus runs one critical agent per task (a P0.4 critical agent, a P0.6 critical agent, a P0.7 critical agent) plus one phase reviewer for Phase 01 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced (the drafted docs; `src/data/*.gd` and its sample `.tres` files; the harness configuration and its two exit codes), but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. `D:\Gamedev\phases\PHASE_00_Environment_And_Connection\` exists but is empty - none of its five files (PLAN.md, EXECUTION_LOG.md, FAILURE_POINTS.md, REVIEW.md, LEDGER.md) exist yet, even though phases/README.md's "Planning depth" section states Phase 00's PLAN.md carries full step-by-step implementation now, and this phase (01) depends on Phase 00. Which is intended?
   a. Create and run Phase 00 fully (all five files, then the loop through review) before this Phase 01 PLAN.md is acted on.
   b. This Phase 01 PLAN.md may exist ahead of Phase 00's files; only actual execution waits on Phase 00's dependency.
   c. Other (please specify).
2. MASTER_SDLC.md > Documentation Structure lists an explicit "Owns:" entry only for doc 02, not for docs 00 or 01, yet P0.4's exit criterion reads "every Owns entry has a resolved or accepted row" without naming which document(s). Should this be read as applying only to doc 02 (the only document with a stated Owns list), or does the author want an Owns list added to docs 00 and 01's Documentation Structure entries first?
   a. Applies only to doc 02, since that is the only document with a stated Owns list today.
   b. Add Owns lists to docs 00 and 01 in Documentation Structure before or during this phase.
   c. Other (please specify).
3. No gdUnit4 version is pinned anywhere in the current documents (docs/28 pins only the two Godot MCP servers, per P0.5's scope). Should P0.7 add a gdUnit4 version pin to docs/28 itself (extending P0.5's stated scope), or is recording the version only in this phase's EXECUTION_LOG.md sufficient for now?
   a. Extend docs/28 to also pin the gdUnit4 version used.
   b. EXECUTION_LOG.md alone is sufficient; docs/28 stays scoped to the two MCP servers.
   c. Other (please specify).

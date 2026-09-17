# Phase 01 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A contract field typed differently from docs/20's Contract Field Semantics | Eleven contracts and a shared-struct table make it easy to guess a type (for example typing Health as float instead of integer, or Target intent as a free string instead of an enum) instead of checking docs/20 field by field | The implementer reads docs/20 > Contract Field Semantics field by field before writing each `@export` (PLAN.md P0.6 step 2); the EXECUTION_LOG field-to-type list (PLAN.md P0.6 step 10) exists specifically so this can be checked without re-reading the scripts | Critical agent cross-checks every `@export` against Contract Field Semantics; Schema check failing to load or validate a sample with a type-mismatched field |
| A `.tres` sample that validates while leaving a required field unset | Godot resources fall back to an export's default value when a `.tres` omits a field, so a sample can load cleanly without every required field actually being populated | Every required export gets a non-default, clearly-a-placeholder value (PLAN.md P0.6 step 8), not an empty string or a zero that could also mean "unset" | Critical agent diffs the sample `.tres` field list against the contract's required field list in MASTER_SDLC.md > Content Data Contracts, rather than trusting a clean load alone |
| gdUnit4's version drifting from Godot 4.7.1 | gdUnit4 is a third-party addon versioned independently of the engine; this task is told to reuse whatever E0.2 installed, and no gdUnit4 version is pinned in docs/28 yet | Record the exact gdUnit4 addon version in EXECUTION_LOG.md (PLAN.md P0.7 step 7-8) alongside the two Godot MCP server versions P0.5 already pins | Headless run behaving differently from an editor run of the same test; reviewer checks whether a gdUnit4 version is recorded anywhere against its stated Godot 4.7.x compatibility |
| Documents 00-02 restating numbers instead of referencing the Register | Prose about Session Shape, onboarding timing, and boss cadence reads naturally with literal numbers inline, and the existing stub text may already carry some of that phrasing | Every number drafted into docs 00-02 is replaced with a Provisional Values Register row citation (PLAN.md P0.4 step 5) instead of the literal figure | Doc lint / self-review pass specifically checks drafted text for bare numerals attached to gameplay nouns and confirms each has a Register citation or is not a gameplay number |
| The author's gate row being written by an agent (banned) | The natural next action after P0.4's self-review and P0.6/P0.7's passing checks is to add the "Phase 0 accepted" Change Log row, and that step is easy to do reflexively once everything else looks done | This PLAN.md and its exit criteria only ever "propose" the row's text (PLAN.md P0.4 step 9); MASTER_SDLC.md > Document Control > Gate Approval reserves writing it for the human designer | Reviewer checks that MASTER_SDLC.md's Change Log has no new accepted/stable row unless the designer is recorded as its author; EXECUTION_LOG.md shows only a proposed row text, never a committed one |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

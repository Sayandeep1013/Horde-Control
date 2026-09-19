# Phase 03 - Ledger

Every finding raised against this phase, carried across review iterations.

Severities: Blocker, Major, Minor. Statuses: open, fixed, closed, deferred with owner, recorded, withdrawn.

Structural rule, carried from Phases 01 and 02 where this file's shape broke four times between them: every finding row sits **below** the header, carries exactly seven columns, and holds a status word in the Status column. A column count alone catches none of the three ways it actually broke, so the check asserts all three. Escaped pipes inside a cell also break the count - write "or" instead.

| ID | Finding | Severity | Raised by | Status | Evidence | Resolution |
| --- | --- | --- | --- | --- | --- | --- |
| F03-01 | Entering this phase, the enemy fixture constants P1.5 used - HP, contact damage, Visual Death duration - have **no Provisional Values Register rows**. P1.5 correctly treated them as framework test fixtures rather than gameplay content and flagged the debt (Phase 02 F02-18). P2.5 authors the first real enemies and is where that debt comes due | Minor | Orchestrator, at phase entry | open | `phases/PHASE_02_Technical_Foundations/LEDGER.md` F02-18; the placeholder enemy's constants | Open until P2.5 lands. The rule the phase must not break: a real enemy takes its numbers from the Register, and any number the Register does not carry is escalated rather than copied forward from a fixture. Fixture values becoming de facto gameplay values by being inherited is exactly how the one-place rule gets lost |

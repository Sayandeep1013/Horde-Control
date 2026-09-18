# Phase 02 - Ledger

Every finding raised against this phase, carried across review iterations.

Severities: Blocker, Major, Minor. Statuses: open, fixed, closed, deferred with owner, recorded, withdrawn. "Recorded" is used for observations that are neither defects to fix nor claims to close.

Structural rule for this file, carried from Phase 01 where it broke three times: every finding row sits **below** the header, carries exactly seven columns, and holds a status word in the Status column. A column count alone does not catch a row inserted above the header or a row whose Status and Evidence cells are swapped, so the check asserts all three.

| ID | Finding | Severity | Raised by | Status | Evidence | Resolution |
| --- | --- | --- | --- | --- | --- | --- |
| F02-01 | This plan's entry conditions contradict its own task table. An entry condition requires the gameplay-root container layout - `Entities`, `Projectiles`, `Pickups`, `Effects`, `Environment`, `Audio` - to exist before the phase starts, but building that scene is **P1.3's own deliverable**, and `scenes/main.tscn` is a bare `Node2D` at phase entry | Minor | Orchestrator, at phase entry | recorded | `scenes/main.tscn` contains a single `Node2D` with no children; the task table lists "gameplay root scene" as P1.3's deliverable | Read as applying from P1.3's completion onward rather than at phase entry, and the entry-conditions bullet is corrected in PLAN.md to say so. Recorded rather than treated as a blocker because the phase can only satisfy it by doing the phase. Worth noting for later phase plans drafted ahead of their dependencies: an entry condition that names a deliverable of the same phase is a drafting error, not a real precondition |

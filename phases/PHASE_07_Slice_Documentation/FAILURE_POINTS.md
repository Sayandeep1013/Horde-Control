# Phase 07 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Scope creep past the Vertical Slice Scope Freeze | A document stabilized or drafted this phase could describe a system, encounter type, or count beyond MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice without a recorded freeze amendment, since this phase touches twenty-two documents at once | Every new or changed Owns entry and every stabilized Provisional Default row is checked against the Freeze's Included and Excluded lists before a document is marked stable or working; anything outside that list needs a Change Log freeze-amendment row | Reviewer sweep comparing each document's Owns list against the Freeze's Included and Excluded lists at the review gate |
| Deferred findings P6 and F20 marked closed without the underlying wording actually fixed | It is easier to mark a finding closed because its owning document reached "stable" or "working" status than to verify the specific wording the Deferred Review Findings table names was corrected | LEDGER.md carries P6 and F20 as named rows, closed only on direct evidence, not on a general status claim | Critical agent for P3.1 checks document 20's typed contract fields directly; critical agent for P3.2 checks document 10's corrected wording directly |
| Documentation drifts from implementation (MASTER_SDLC.md > Risk Register) | Documents finalized here describe systems phases 08 through 12 implement; a document could still diverge once implementation starts | Every system change updates its document in the same commit, from Phase 08 onward | phases/README.md loop rule (d)'s "sweep all changed files for superseded wording" before every re-review |
| The P1 deferred finding reaches only its "working" tier here, and an Owns entry reads as accepted rather than genuinely resolved | Doc lint's pass condition allows either a resolved row or an accepted row per Owns entry | LEDGER.md records which Owns entries are accepted versus resolved, so the distinction is visible at review time | Doc lint run at phase exit, reviewed against P3.2b's own exit criterion |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

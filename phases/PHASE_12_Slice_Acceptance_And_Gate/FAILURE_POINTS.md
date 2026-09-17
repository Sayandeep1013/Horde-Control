# Phase 12 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The slice needing new scope to become fun (MASTER_SDLC.md > Slice Exit Criteria closing note) | If playtesters report the loop is not fun, the fastest-looking fix is adding a new system, which the Scope Freeze exists to prevent this late | The core loop should become fun through selection, pressure, and readability, not through adding more systems; any new-scope proposal goes to the author as a freeze-amendment question | Reviewer checks any LEDGER.md finding that proposes new scope is flagged as a design warning, not an approved fix |
| Three VS-tagged tests whose Acceptance Test Matrix "First task" is P3.18 are not named in docs/29's own P3.18 acceptance-test list, so they risk never being run at all | This is a contradiction between MASTER_SDLC.md > Acceptance Test Matrix and docs/29's P3.18 row that this PLAN.md does not resolve on its own authority | This phase's task list runs Failed-run progress test, Upgrade dominance perception test, and Encounter fairness test anyway, since they are tagged VS | LEDGER.md carries a row for each of the three tests until run and recorded |
| Deferred findings P11, P12, P13, or P-m9 remain open when this phase's review gate runs | All four are due to close by P3.18, and each depends on evidence from earlier phases | Each finding is checked individually against its own text, not assumed closed because the phase otherwise passes | LEDGER.md rows for P11, P12, P13, and P-m9, each closed only on direct evidence |
| The five fresh external testers are not actually fresh | The Acceptance Test Matrix's intro distinguishes P3.18's testers as fresh, separate from P2.16's five; reusing the same pool would bias every tester-probe result | Tester recruitment for this phase is checked against the P2.16 roster before scheduling | Reviewer checks the recorded tester roster for overlap with P2.16's |
| An agent writes the slice gate row into the Change Log itself | Drafting the row's text and committing it to the Change Log are easy to conflate under time pressure | Agents may propose the gate row's text as a draft for the author; the Change Log write itself is the author's action, never an agent's | Reviewer checks the Change Log's actual edit history for the gate row's author |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

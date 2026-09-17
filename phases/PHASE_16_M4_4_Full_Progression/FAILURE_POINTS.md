# Failure Points - Phase 16 (M4.4 Full Progression)

## Predetermined

Restated from `PLAN.md` > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The full skill tree or the full upgrade pools produce a dominant build once every branch and pool exists, rather than only the slice's small subset | The slice's dominant-pair audit passed against ten player and eight Tower upgrades and one skill node; a much larger tree and pool set is a different combinatorial space that has never been audited together | Pool audit runs before this milestone closes, as required by the Dominant pair audit acceptance test itself (MASTER_SDLC.md > Risk Register > "Upgrade pool produces a dominant build") | Dominant pair audit applied to both P4.4.1's tree and P4.4.4's pools against the recorded-run threshold in MASTER_SDLC.md > Provisional Values Register > Economy & Pickups > "Economy dominance measure"; a pool or branch over that threshold is a Ledger finding |
| Content scope expands past what documents 06, 08, 17, and 18 already define (a new weapon class, skill branch, or Factory queue type not previously scoped gets built here) | "Full" progression is an open-ended target compared to the slice's fixed small set, and it is easy to keep adding rather than stopping at what the owning documents already define | Each task's Scope in/out cell is fixed before work starts; a genuinely new system idea (not an expansion of an existing owning document's scope) is logged to document 30 instead (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems", applied here to progression systems) | Phase reviewer checks each task's delivered resources against its owning document's existing Owns list before scoring |
| Factory production queues (P4.4.2) accidentally become available during a run, violating the still-banned in-run queue rule | Between-run and in-run code paths for the same Factory UI are easy to leave both reachable if the run-state gate is not enforced explicitly | The in-run ban is stated as an explicit Out in P4.4.2's Scope in/out cell, and document 08 owns "behaviour when production outpaces demand" and the queue's between-run-only trigger | Scripted queue-completion pass includes an explicit negative case: attempting to open or queue Factory production during an active run must fail; a pass that only tests the between-run path is not sufficient |
| The Hub UI and Console/Draft card UI become unreadable once the full skill tree and full upgrade pools are both visible at once | The slice's Hub carried one skill node and ten-plus-eight upgrades; this phase multiplies both, and UI readability was never tested at that density | The Readability Hierarchy and the player-versus-Tower card differentiation rules (owned by document 19) apply to the expanded Hub and Draft/Console content the same as they did at slice density (MASTER_SDLC.md > Risk Register > "Readability degrades as content is added") | Phase reviewer checks the Hub UI and Draft/Console card set for overlap, truncation, or undifferentiated cards at full density, even though this is not one of the four named acceptance tests |
| Documentation drifts from implementation across four owning documents (06, 08, 17, 18) that P4.0 (Phase 17) must later bring to stable with zero placeholders and no open contradiction | Four parallel Sonnet subagents each touching a different owning document increases the chance that at least one document lags its implementation, which then surfaces as a P4.0 blocker rather than being caught here | Every commit that changes a system's implementation also changes that system's document in the same commit (MASTER_SDLC.md > Risk Register > "Documentation drifts from implementation"; docs/28 owns this rule) | Phase reviewer's pre-re-review sweep (loop rule d) checks each task's commit for a matching document change before this phase closes, rather than leaving the check to P4.0 |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

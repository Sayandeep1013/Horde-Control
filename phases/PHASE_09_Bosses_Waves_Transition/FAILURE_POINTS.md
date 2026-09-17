# Phase 09 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A boss that displaces the Tower out of its own sub-region | Boss Design Requirements bind arena sub-region placement for both bosses; a boss with knockback, terrain-altering, or large-hitbox behaviour could push or place the Tower outside its intended sub-region | Boss movement and hitbox design is reviewed against MASTER_SDLC.md > Boss Design Requirements before a boss is marked implemented | Boss edge case test |
| A status effect that survives a biome transition it should not | The status effect system (Phase 08) and this phase's transition cleanup harness are built in different phases; a status applied late in the biome could still be active when the scripted transition runs | MASTER_SDLC.md > Biome Transition Rule's persistence list is checked explicitly for player-carried status effects; the harness includes a case with an active status at transition | Transition cleanup test; a dedicated status-carryover check if the persistence list does not already cover it |
| The Mini-Boss wording inconsistency (F20) resurfacing during implementation despite being recorded closed in Phase 07 | F20 closes as a documentation fix in Phase 07, but the wording is only tested against real boss-wave suppression behaviour once P3.10 implements a Mini-Boss here | Phase 07's critical-agent evidence for F20 is re-read at this phase's entry, and P3.10's implementation is checked against the corrected wording | Boss edge case test; reviewer cross-check against Phase 07's LEDGER.md F20 entry |
| The Duel-or-waiver decision remains undecided when P3.11 needs it | This is an author decision the phase cannot make on its own | The question is raised to the author before P3.11's wave sequence is finalized, with a stated default applied only if the author does not respond | Composition rule test; a LEDGER.md entry blocking phase closure until the decision or its default is recorded |
| The Tower becomes irrelevant to moment-to-moment play (MASTER_SDLC.md > Risk Register) | Adding bosses and a full eight-wave sequence changes pacing enough that the Siege/Split Assault balance could drift | At least one Siege and one Split Assault per biome, every combat wave after T1 contains a Tower Seeker or Opportunist | Composition rule test |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

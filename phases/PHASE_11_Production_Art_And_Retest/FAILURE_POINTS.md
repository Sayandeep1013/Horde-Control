# Phase 11 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An art pass that breaks the Readability Hierarchy at slice density | P3.16 is the first task to bring full production art onto the screen together, and the Readability Hierarchy's draw-order and effect-density rules were only proven against placeholder art before now | Each art asset is checked against the Readability Hierarchy's draw-order rule and reserved hazard colour rule as it lands | Evolution silhouette test; a readability pass reusing the Effect density test's own threshold |
| The swarm re-test failing at slice density after passing at prototype density, which the Performance Fallback Ladder anticipates | P3.9 is the first swarm measurement with the full roster, both affixes, and the Biome Boss all active at once, and production art typically costs more per frame than placeholder art | The Performance Fallback Ladder's own note that Phase 3 re-runs the ladder at slice density is exactly this task; the ordered steps are stepped through again from the base case | Swarm performance test |
| Audio becomes an unreadable wall of noise (MASTER_SDLC.md > Risk Register) | P3.16 adds an SFX set and boss telegraph cues on top of the six-bus layout built for a much smaller placeholder sound set | Strict Audio Bus hierarchy and dynamic ducking enforced; retrigger-limit and priority-voice rules apply to every new cue | Audio clarity test (boss telegraphs), checked by internal testers here |
| P3.16's Evolution silhouette test result reflects internal testers only, not yet fresh external testers | The Acceptance Test Matrix's own instrument column names an internal tester at P3.16 and an external tester probe at P3.18 | This phase's LEDGER.md and REVIEW.md record the result explicitly as internal-tester evidence, not a final pass | Reviewer checks the recorded evidence names internal testers, not external testers |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

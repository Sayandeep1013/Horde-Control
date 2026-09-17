# Failure Points - Phase 13 (M4.1 Biome 2)

## Predetermined

Restated from `PLAN.md` > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Content scope expands past M4.1 (biome-3-or-later material leaks into this phase's tasks) | Biome design work naturally generates ideas beyond the biome in front of it; a task drifts past its own Scope in/out cell | Every task's Scope in/out cell in PLAN.md is fixed before work starts; anything beyond biome 2 is logged to document 30 instead of built here (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems") | Critical agent for each P4.1.x task checks delivered files against that task's Scope in/out cell; any biome-3-or-later asset found in a P4.1.x deliverable is a Ledger finding |
| Readability degrades as biome 2's hazard, enemies, and boss art stack on top of biome 1's carried-over elements | Each new layer is reviewed against its own acceptance test in isolation, not against the combined on-screen density it will share with biome 1 | The Readability Hierarchy and effect-density rules gate P4.1.6 (MASTER_SDLC.md > Risk Register > "Readability degrades as content is added"; owning document 27) | Hook description test and Hazard telegraph test are run against biome 2's delivered art, not only against isolated asset review; a tester who cannot read a hazard at biome 2 density is a Ledger finding |
| The live transition (P4.1.7) leaves orphaned entities between biome 1 and biome 2 | P4.1.7 is the first non-scripted transition; the P3.17 harness proved the mechanism only on a scripted placeholder arena, not on biome 2's real content | The Transition cleanup test is re-run against the real biome 2 content, and the Biome Transition Rule's persistence list is checked item by item, not assumed from the harness result | Entity count is swept in every pooled container immediately after the transition; any nonzero count is a Ledger finding |
| The Mini-Boss or Biome Boss reuses a mechanic from biome 1 without the Duel-or-waiver decision being re-checked for biome 2 | The Composition rule test's Duel clause was satisfied once for the slice biome; biome 2 is a separate composition and needs its own instance of the check | P4.1.5's wave sequence is checked against the Composition rule test as its own instance for biome 2, not assumed to inherit biome 1's recorded waiver (MASTER_SDLC.md > Encounter Composition Rules) | Composition rule test run against biome 2's full sequence; a missing Duel or waiver row is a Ledger finding |
| A biome-2 enemy or boss reintroduces an Enemy Behaviour or Boss edge case already closed for biome 1, because new content was built by copying biome 1's patterns rather than re-deriving them from the register | New content is easy to build by analogy to what already works, skipping the register check | P4.1.3 and P4.1.4 are checked directly against the Enemy Behaviour and Boss Edge Cases tables (MASTER_SDLC.md > Edge Cases and Failure States; Boss Structure > Boss Edge Cases), not only against biome 1's implementation | Critical agent for P4.1.3/P4.1.4 walks the relevant edge-case rows against the new resources; any unhandled or unaccepted row is a Ledger finding |
| Biome 2's new enemy types and boss push the swarm past the performance rule at reference-machine density | Entity caps and pooling are enforced structurally, but a new enemy archetype's per-node cost is unproven until it exists | New enemies are added under the existing entity-cap and pooling architecture (MASTER_SDLC.md > Risk Register > "Per-node physics cost of 300 CharacterBody2D enemies exceeds budget"); the Performance Fallback Ladder step already adopted for the slice carries forward unless a new step is recorded | The debug overlay's FPS maxima are watched during P4.1.3/P4.1.4/P4.1.7 execution even though the formal Swarm performance re-test is not an M4.1 acceptance test; a drop below the performance rule is logged as a discovered Failure Point |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

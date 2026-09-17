# Failure Points - Phase 17 (M4.5 Alpha Gate)

## Predetermined

Restated from `PLAN.md` > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The performance rule holds on the reference machine during P4.5.1 but would not hold on whatever minimum-spec machine is later decided at P4.6.0 (Phase 18) | Alpha's Full run test only measures against the reference machine (MASTER_SDLC.md > Provisional Values Register > Engine & Platform > "Reference machine"); no minimum-spec figure exists yet to test against | This phase records its performance results as reference-machine-only and does not claim they generalize to minimum spec; the Minimum-spec performance test is explicitly deferred to P4.6.4 after P4.6.0 decides the machine | Phase reviewer confirms P4.5.1's recorded performance data is labeled as reference-machine data, not treated as a minimum-spec proxy |
| P4.0 stabilizes 18 documents in one task and misses a placeholder, an unresolved edge-case entry, or a cross-document contradiction, because the sheer volume makes a full sweep expensive | XL-sized, 18-document scope is the largest single documentation task in the plan; a missed item is easy to lose among the rest | Doc lint (zero placeholders) and an Owns-entry check run per document, not once across the batch; the phase reviewer's pre-re-review sweep (loop rule d) explicitly checks for superseded wording across all 18 | Critical agent for P4.0 spot-checks each document's Owns list against MASTER_SDLC.md > Documentation Structure and records any unresolved entry as a Ledger finding |
| The Full run test passes on placeholder or pseudo-localized text, masking a UI break that only appears once P4.6.1's real localization pass runs | Localization has not happened yet at this phase (P3.15 delivered only a pseudo-localization pass); the Full run test's pass condition does not itself exercise real translated strings | This phase does not claim the Localization test is satisfied; that acceptance test is explicitly scoped to P4.6.1 in the Acceptance Test Matrix, and this document does not substitute pseudo-loc results for it | Phase reviewer confirms no Ledger entry in this phase claims the Localization test passed |
| A save migration (P4.5.2) corrupts an older prototype/slice-format profile instead of cleanly migrating or rejecting it | The migration script must read a schema that predates every subsequent save-format change accumulated through the slice and all of M4.1-M4.4; a missed field mapping silently drops or misreads data | Migration is tested against the documented migration chain per version, not only the most recent prior format (MASTER_SDLC.md > Edge Cases and Failure States > Save and Persistence > "Save schema changes between versions") | Save migration test run against a real prototype/slice-era save fixture, not only a synthetic one; a data-loss or crash result is a Ledger finding at Blocker severity |
| Two consecutive Windows exports from the same commit are not byte-identical, because the build embeds a timestamp, machine-specific path, or non-deterministic asset-packing order | Export determinism is not guaranteed by default in most build pipelines; something as small as an embedded build time defeats the byte-identical requirement | The export pipeline is documented explicitly enough that a second export from the same commit can be reproduced exactly, per P4.5.3's own exit criterion | Two consecutive exports are diffed at the byte level as part of this phase's execution, not assumed from a single export |
| Content scope expands past the four milestones already closed, because stabilizing documents at full scope invites "just one more" addition while writing | Writing a document's stable form surfaces gaps that are tempting to fill immediately rather than deferring | New content ideas surfaced while stabilizing docs are logged to document 30, not folded into the doc being stabilized (MASTER_SDLC.md > Risk Register > "Scope expansion across biomes and systems") | Phase reviewer checks that P4.0's stabilized documents describe only what M4.1-M4.4 already delivered, not new content introduced during stabilization |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

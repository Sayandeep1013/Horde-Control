# Phase 08 - Failure Points

## Predetermined

Restated from PLAN.md > Predetermined failure points and risks.

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| An elite affix pair that loops | Two elite affixes can reference or amplify each other's behaviour with no terminating condition, per MASTER_SDLC.md > Elite Variants and the Elite affix loop guard test's own definition | P3.8's two affixes are designed and reviewed together specifically for their interaction, not independently; a scripted double-affix Elite must complete in finite ticks | Elite affix loop guard test |
| Scope creep past the Vertical Slice Scope Freeze | Seven tasks land in one phase, the highest task density in this folder set, raising the chance a deliverable grows past MASTER_SDLC.md > Vertical Slice Scope Freeze > Included in Vertical Slice's stated counts without a recorded freeze amendment | Each task's deliverable is checked against its own Included-in-Slice line before being marked implemented; any excess goes through a Change Log freeze-amendment row | Reviewer checks deliverable counts against the Freeze list at the review gate |
| Upgrade pool produces a dominant build (MASTER_SDLC.md > Risk Register) | Ten player and eight Tower upgrades land together (P3.12) alongside dash and evolution tasks drawing from the same pools, and an early imbalance is easy to miss without enough recorded runs | Pool audit before every content milestone, per the Risk Register's own mitigation | Dominant pair audit |
| A dash or other upgrade combination reduces the hook degrade floor below its minimum | P3.6 (dash) and P3.12 (upgrade pool) land in the same phase, and dash's lane-travel-time effect is exactly the kind of movement upgrade the hook degrade floor exists to bound | Hook degrade test is run at maximum dash rank specifically, not only at rank 1 | Hook degrade test |
| Performance ceiling during swarm encounters (MASTER_SDLC.md > Risk Register) | This phase brings the roster to its full slice size for the first time, ahead of the dedicated re-test in Phase 11 | Entity caps and pooling enforced from the first prototype, per the Risk Register's own mitigation | Debug overlay entity-count maxima checked during this phase's own scripted tests |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

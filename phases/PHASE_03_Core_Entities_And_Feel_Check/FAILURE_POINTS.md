# Phase 03 - Failure Points

## Predetermined

Restated from PLAN.md > "Predetermined failure points and risks".

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| Ghost hits from an entity that died mid-attack | P2.3 (weapon fire and hit queue) and P2.5 (enemy death, attack wind-up) are separate tasks; if the Logical Death deferred-flag sequencing is not wired into the enemy attack and hit-queue code exactly as specified, a hit already queued against a dying entity could still apply, or a dying enemy's own wind-up attack could still land | Implement Logical Death exactly per docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Logical Death" and > "Animation, Hitbox, and State Cleanup Rules" > "Animation Cancellation"; follow the SimLoop order (docs/20 > "SimLoop order") so death resolution and hit-queue sorting run in their defined step order | Re-run the same mid-attack-kill scenario the P1.5 Ghost hit test used, now against the built Seeker/Hunter/Opportunist and the Handgun/Tower weapon, in a scripted P2.5 arena; any damage event logged after an entity's death tick in the Run Recorder events.csv fails it |
| Tower becoming irrelevant to moment-to-moment play | P2.1-P2.3 build the player and weapon before the Tower (P2.4); if placeholder enemies used to validate P2.1-P2.3 target only the player, the Tower's threat model can become an afterthought, and P2.7 could record a "go" on player-only combat with nothing pressuring the Tower | Build Seeker, Hunter, and Opportunist together at P2.5, per docs/09_Enemy_AI_Architecture.md > Intent Behaviour Defaults, before P2.7 runs, so the feel check always includes at least one Tower-directed enemy; keep the Tower Targeting Rule and Interaction Radius (MASTER_SDLC.md > Tower Overview) implemented before P2.6/P2.7 (MASTER_SDLC.md > Risk Register: "Tower becomes irrelevant to moment-to-moment play") | The P2.7 Feel check verdict itself: the designer and scripted bots explicitly record whether the Tower read as a separate thing worth protecting |
| Tester probes being run by anyone who already played an earlier build | P2.7's internal testers are the designer and the AI collaborator's scripted bots only, by design; if any other person plays P2.7 informally, that person is no longer eligible for the external tester pool MASTER_SDLC.md > Development Phase Map names at P2.16 | Restrict P2.7 access to the designer and scripted bots only; log who ran each P2.7 session in this folder's EXECUTION_LOG.md | Phase 06 cross-checks its P2.16 tester roster against this phase's EXECUTION_LOG.md entries for P2.7 sessions, per loop rule (a) |
| Scripted bots whose behaviour does not match the test's definition | P2.7's scripted bots stand in for human play against three enemy intents with no Wave Director running; if a bot's movement or engagement logic drifts from what the Acceptance Test Matrix later names at P2.15/P2.16 (orbit bot, roam bot, still bot), a "go" verdict here could rest on behaviour those later bots do not reproduce | Build the P2.7 scripted bots as early, minimal versions of the same bot behaviours the Acceptance Test Matrix names, documented against their test definitions rather than invented ad hoc | The Phase 03 critical agent for P2.7 compares the bot scripts against the bot definitions cited in MASTER_SDLC.md > Acceptance Test Matrix |
| Player silhouette / Y-sort misconfiguration | P2.1 (player), P2.5 (enemies), and P2.6 (telegraphs, damage numbers) all touch the scene tree's draw order; if the player is added under the pooled `Entities` container instead of its own fixed-`z_index` node, it is Y-sorted with enemies instead of always drawing above them | Follow docs/20_Technical_Architecture.md > Godot 4.x Implementation Standards > "Scene Tree" exactly: the player is not a child of `Entities` and is not part of its Y-sort group, with a fixed `z_index` above enemies | Player silhouette test |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

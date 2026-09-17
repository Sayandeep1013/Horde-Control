# Phase 05 - Failure Points

## Predetermined

Restated from PLAN.md > "Predetermined failure points and risks".

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A partial pause caused by a timer that does not run on SimClock | P2.12 (Draft), P2.13 (Console), and P2.14 (pause menu, focus loss) each introduce their own UI timers (hold-to-confirm fill rings, the Console's purchase channel, input lockouts); a Godot `SceneTreeTimer` or `Tween` left off PauseAuthority's control would keep advancing while the Draft or pause menu is open | Route every one of these timers through SimClock and PauseAuthority only (MASTER_SDLC.md > Risk Register: "Godot pause traps (SceneTreeTimer, Tween, PROCESS_MODE_ALWAYS leakage)"; banned APIs listed under Global Simulation Authority) | Pause authority test (full); Console non-pause test as the inverse check, confirming the Console's own channel timer keeps running under SimClock while the rest of the sim is not paused |
| The Draft auto-confirming a held input on open | If a player is holding the movement-only confirm direction, a gamepad stick, or a key at the exact moment a level-up opens the Draft, a hold-to-confirm path that arms immediately would confirm a card the player never chose | Implement the neutral-return arming rule exactly per docs/19_UI_UX.md > "Upgrade Draft UI & Navigation" > "Input Lockout & Arming": hold-to-confirm inputs arm only once input has returned to neutral at least once after the lockout ends | Draft input lockout test |
| The Console opening on radius entry alone and becoming a safe stop | A simpler implementation of P2.13 might open the Console the instant the player enters the Interaction Radius, turning the radius into a place to stand safely without needing to transact | Implement the Console's documented lifecycle exactly (docs/19_UI_UX.md > "Tower Console UI" > "Lifecycle": 0.3 s below 10% base speed inside the radius, at least one affordable entry); keep the player's auto-fire disabled at any speed while overlapping the radius regardless of whether the Console is open | Console rules test; Interaction window test (scripted), which checks that opening the Console during an active encounter still costs the player something |
| Upgrade pool produces a dominant build | P2.11's six upgrades and two fallback cards are a small pool; with only three ranks and shared ranks between channels, one upgrade could end up strictly better than the others at every rank | Cross-check each upgrade's per-rank effect against the others once all six are implemented, before Phase 05 review (MASTER_SDLC.md > Risk Register: "Upgrade pool produces a dominant build" - mitigation "Pool audit before every content milestone"); the full Dominant pair audit is a VS-tagged test out of prototype scope | Upgrade effect check confirms each upgrade applies its documented effect with no drift; a qualitative pool read is added to REVIEW.md for this phase since no prototype-tagged test measures dominance directly |
| Determinism / keyed RNG drift | P2.12's Draft offers and P2.10's earlier drop rolls both consume keyed RNG; if the Draft's card-offer roll is not keyed off the run seed and a stable counter (draft index, not wall-clock time or an object instance ID), replaying the same seed will not reproduce the same three cards | Key every Draft roll exactly per MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance > "Keyed RNG" (hash of run seed plus a named, stable counter), matching the pattern already proven for spawn and drop rolls in Phase 04 | Determinism test |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

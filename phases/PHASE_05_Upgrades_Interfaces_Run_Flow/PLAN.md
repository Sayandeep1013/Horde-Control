# Phase 05 - Upgrades, Interfaces, Run Flow

Status: Not started; Executes: MASTER_SDLC.md > Development Phase Map > Phase 2 - Core Tension Prototype (the Minimum Playable Prototype) (part); Plan task IDs: P2.11, P2.12, P2.13, P2.14

## Goal

Both upgrade channels and a run that can be played end to end. This is phases/README.md's phase-table row 05 outcome: "Both upgrade channels and a run that can be played end to end." The owning detail for every task in this phase lives in docs/19_UI_UX.md: Upgrade Draft UI & Navigation, Tower Console UI, HUD, and Input Map.

## Entry conditions

- Phase 04 exit criteria recorded: Spawn ring test, Split Assault test, Hunt test, Encounter recovery test, Wave runtime test, Overtime test, Pressure test, and Pickup physics test all recorded (phases/README.md phase-table row 04 gate).
- The Wave Director (P2.8 deliverable, `src/director/wave_director.gd`, `data/encounters/*.tres`, `data/waves/*.tres`) and its Pressure fields (P2.9 deliverable) exist, since P2.12's Draft grace period hooks into wave/encounter scheduling and P2.14's T4 tuning reads Pressure-adjacent Tower/player DPS.
- Pickups, the Drop Table, and XP shards (P2.10 deliverable, `src/pickup/*.gd`, `data/pickups/*.tres`) exist, since P2.12's Level-Up Draft is triggered by the level curve those XP shards feed.
- PauseAuthority (P1.1 deliverable) exists and is the only pause writer this phase's Draft, Console, and pause menu may use.
- The player, weapon, and Tower (P2.1, P2.3, P2.4 deliverables) exist as the two upgrade channels' targets, and the HUD (P2.6 deliverable) exists for this phase's HUD layout and run-end summaries to extend.

## Carried lessons

Filled at phase entry on 2026-09-20 from `phases/LESSONS.md` and the execution records of phases 00 through 04, per loop rule (a). This phase is four interface and flow tasks, so Phase 03's UI record (P2.6) carries the most weight, alongside the falsification rules every phase has now re-learned.

1. **A UI defect can be invisible to every assertion about the UI's contents.** P2.6's XP bar was pinned off-screen at y=1080 because a raw-anchor `MarginContainer` under a plain `Control` never grows to fit content added after the anchor preset is set. Only a test asserting screen position could see it (F03-20). Every Control this phase adds is asserted at a position on a 1920x1080 viewport, not merely asserted to exist.
2. **Run tests through `tests/run_tests.ps1`, never the raw gdUnit4 command** - gdUnit4's error count excludes Godot's own engine errors, and both channels have to be clean. `pwsh` is not installed; the runner is Windows PowerShell 5.1.
3. **Every named acceptance test is falsified by real mutation, restored, and proved byte-identical.** This phase carries eighteen named tests, more than any other in the prototype, and several of them - the draft input lockout, the console rules, the pause authority test - are the shape that passes vacuously if the assertion is about existence rather than about the rule.
4. **A mutation with no effect is a finding about the implementation**, not a weak test (F03-23).
5. **Numbers come from the Provisional Values Register, and a missing row is escalated, never invented.** Four Phase 03 tasks escalated rather than inventing; P2.6 in particular escalated three interface numbers the Register does not carry (F03-18), and this phase inherits that habit.
6. **PauseAuthority is the only pause writer.** The Draft pauses fully, the Console must not pause at all, and both coexist with the pause menu and focus loss - the same authority mediates all four. There is an open, unresolved structural contradiction about `AudioDucking` needing `PROCESS_MODE_ALWAYS` under a gameplay root that forbids it (author's decision, still open); this phase must not quietly resolve it by moving nodes around.
7. **A skill's prescription loses to this project's documents, and the conflict gets recorded** - Phase 03 recorded four such conflicts, two of them in the HUD task where the `hud-system` skill prescribed signal-binding over the polling docs/20 sanctions.
8. **Parallel tasks break where they meet**; shared files have one writer per session and cross-task seams are the orchestrator's.
9. **Never call `remove_child()` in a gdUnit4 `after_test()`** (F03-35).
10. **Under-claim, and never write that a test, task or phase is passed, satisfied or ready.**

## Tasks

| Plan ID | Goal | Deliverable | Acceptance test | Exit criterion | Owner doc | Size | Agent |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P2.11 | Six upgrades and fallback cards | `data/upgrades/*.tres`, `src/upgrade/upgrade_system.gd` | Upgrade effect check (P2.11) | Ranks apply from either channel and cap correctly at rank 3 | 17 | M | Sonnet (implementer) |
| P2.12 | Level-Up Draft | `scenes/ui/draft.tscn`, `src/ui/draft.gd` | Draft queue test (P2.12); Draft input lockout test (P2.12); Guaranteed first draft test (P2.12); Encounter deferral test (P2.12); Determinism test (P2.12); XP cap check (P2.12) | Draft resolves with movement input alone; no encounter or spawn group opens during the grace period | 13 (consults 19) | M | Sonnet (implementer) |
| P2.13 | Tower Console | `scenes/ui/console.tscn`, `src/ui/console.gd` | Console non-pause test (P2.13); Console rules test (P2.13); UI scaling test (P2.13); Interaction window test (P2.13 scripted) | Buying under attack works, costs the 0.5 s channel, and never pauses the simulation | 19 (consults 07) | M | Sonnet (implementer) |
| P2.14 | Run flow | `data/waves/prototype_sequence.tres`, `scenes/ui/run_end.tscn`, pause/settings menus | Focus loss test (P2.14); Movement-only test (P2.14); Teaching Siege tuning check (P2.14); Scrap loss test (P2.14); HUD layout check (P2.14); Pause authority test (P2.14 full); Run flow check (P2.14) | A no-player T4-only run destroys the Tower before T4 ends in at least 3 of 5 seeds, and a run with a bot that responds to the Siege warning keeps the Tower above 50%; a developer run reaches wave eight or dies with a recorded cause | 19 (consults 11) | M | Sonnet (implementer) |

## Step-by-step implementation

The step-by-step section below states each task's inputs and deliverable file paths now, and names the owning document section it must follow. It is deliberately not a full walkthrough: per phases/README.md's "Planning depth" note, only phases 00 and 01 carry full step-by-step implementation ahead of time; this phase's detailed steps are written at real phase entry, once Phase 04's actual lessons exist to inform them.

### P2.11 - Six upgrades and fallback cards

Inputs: three player and three Tower upgrades as `.tres` with max rank, shared ranks, pool ownership; the two fallback cards (weapon upgrades excluded); P0.6 deliverable (schemas); P2.3 deliverable (weapon); P2.4 deliverable (Tower).
Deliverable file paths: `data/upgrades/*.tres`, `src/upgrade/upgrade_system.gd`.
Follows: MASTER_SDLC.md > Provisional Values Register > "Progression & Upgrades" for the six upgrades' per-rank effects, the Console price formula, and the fallback-card rule (C-FALLBACK-CONSOLE), cited here, not restated; MASTER_SDLC.md > Player Overview > "Upgrade Channels" for the shared-rank, either-channel rule this task's own acceptance test checks. Document 17 (Progression & Upgrades) is this task's nominal owner and does not yet exist as a file - see "Open questions for the author".

Steps, written at phase entry on 2026-09-20 and given to the implementer:

1. The six prototype upgrades authored as `.tres` against the existing Upgrade Definition schema, with per-rank effect, max rank and pool ownership cited to the Register row: player Rapid Fire, Heavy Rounds, Patch Kit; Tower Caliber, Optics, Shield Matrix.
2. The two fallback cards authored per C-FALLBACK-CONSOLE, including their no-max-rank and zero-evolution-rank properties and the exhausted-pool condition that unlocks them, so Scrap always has a sink.
3. `src/upgrade/upgrade_system.gd` owning each upgrade's rank for the run and enforcing the rules - max rank 3, and ranks SHARED between the two channels, so a rank bought at the Console and a rank taken in the Draft advance the same counter. Nothing about either interface belongs in this task; P2.12 and P2.13 call its API.
4. Effects that change live behaviour rather than a number in a dictionary, applied through a modifier layer above the authored base values. The base `.tres` files owned by P2.1, P2.3 and P2.4 are neither edited nor mutated at runtime.
5. The additive-versus-multiplicative stacking question answered explicitly against the Register's wording, and escalated rather than settled silently if the wording does not decide it.
6. A small typed public API for P2.12 and P2.13: what is offerable, current rank, is-maxed, apply a rank, and whether a pool is exhausted so fallbacks unlock.
7. The Upgrade effect check asserting exact expected values after three ranks against a computed expectation, since "no drift after 3 ranks" names floating-point accumulation as the defect the test exists to catch.

### P2.12 - Level-Up Draft

Inputs: level curve, queueing, central panel, three cards with one-of-each guarantee, differentiation, keyboard, gamepad, hold-to-confirm, one Reroll per run, guaranteed first draft after T4, full pause, the grace period including the spawn-group block (Banish excluded); P2.10 deliverable (XP); P2.11 deliverable (upgrades); P2.8 deliverable (Wave Director, for the grace-period hook); P1.1 deliverable (PauseAuthority).
Deliverable file paths: `scenes/ui/draft.tscn`, `src/ui/draft.gd`.
Follows: docs/19_UI_UX.md > "Upgrade Draft UI & Navigation" in full - Presentation, Input Lockout & Arming, Mouse/Keyboard, Gamepad, Movement-only, Draft Actions, Audio Cues, Readability, Differentiation - which is this task's complete owning section; docs/11_Wave_Director.md > "Wave Runtime Model" for the grace period's spawn-group block, which P2.12 triggers on Draft close; docs/20_Technical_Architecture.md > "SimLoop order" step 11 (XP and level-up requests) and step 14 (`PauseAuthority.flush()`) for when a level-up request becomes an open Draft for that same tick's Wave Director step. Document 13 (Progression - Draft) is this task's nominal owner, consulting document 19 (Working); 13 does not yet exist as a file - see "Open questions for the author".
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.13 - Tower Console

Inputs: dwell open, auto-close, catalogue with prices, Repair, auto-fire disable, non-pause, differentiation, all input schemes including sector selection behind the Movement-only controls setting (consumables excluded); P2.10 deliverable (Scrap); P2.11 deliverable (upgrades); P2.4 deliverable (Tower); P2.12 deliverable (Draft, for the mutual-exclusion rule).
Deliverable file paths: `scenes/ui/console.tscn`, `src/ui/console.gd`.
Follows: docs/19_UI_UX.md > "Tower Console UI" in full - Presentation, Contents, Input, Lifecycle, Placement, Differentiation - which is this task's complete owning section; MASTER_SDLC.md > Provisional Values Register > "Interfaces" > "Tower Console rules" and "Movement-only controls setting" rows, cited here, not restated. Document 19 is this task's owner and is Working; it consults document 07 (Tower Systems), which does not yet exist as a file.
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

### P2.14 - Run flow

Inputs: T4 tuning, pause menu, settings menu with the Movement-only controls toggle, run-end screens, focus-loss pause (including the harness's `--no-focus-pause` flag and a controller-disconnect trigger), temporary debug persistence (save system excluded); P2.9 deliverable (Pressure, for T4 tuning); P2.12, P2.13 deliverables (menus that must coexist with run flow); P2.6 deliverable (HUD, for run-end summaries).
Deliverable file paths: `data/waves/prototype_sequence.tres`, `scenes/ui/run_end.tscn`, pause/settings menus.
Follows: docs/19_UI_UX.md > "HUD", > "UI Layout & Dynamic Container Rules", and > "Input Map" for the run-end screen layout, the Movement-only controls setting's pause/settings-menu surfacing, and the pseudo-localization toggle; docs/11_Wave_Director.md > "Encounter Budgets for the Prototype" > T4 row for the teaching-Siege tuning target this task's own acceptance test checks; MASTER_SDLC.md > Tower Overview > "Health Recovery Rules" and > Player Overview for the run-end death-cause/wave-reached/Scrap-held/time-survived fields. Document 19 is this task's owner and is Working; it consults document 11 (Working).
Written at phase entry under loop rule (a), which requires reading every earlier phase's EXECUTION_LOG, FAILURE_POINTS, REVIEW and LESSONS first.

## Exit criteria and acceptance tests

| Named test (Acceptance Test Matrix) | Source | What this phase records |
| --- | --- | --- |
| Upgrade effect check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.11 per-rank effect result across 3 ranks, both channels |
| Draft queue test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.12 two-simultaneous-level-up sequencing result |
| Draft input lockout test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.12 scripted input-replay result (lockout, arming, cycle, hold-to-confirm) |
| Guaranteed first draft test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.12 result over 5 of 5 runs (first Draft opens at T4's end regardless of XP) |
| Encounter deferral test | MASTER_SDLC.md > Acceptance Test Matrix > Encounter Tests | P2.12 grace-period timestamp result |
| Determinism test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.12 keyed-roll repetition result across a full scripted run |
| XP cap check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.12 T1-T4 XP-cap and forced-first-Draft result |
| Console non-pause test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.13 result confirming `SimClock.now` advances with the Console open |
| Console rules test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.13 lifecycle, channel, and cancel result |
| UI scaling test | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P2.13 pseudo-localization no-truncation result |
| Interaction window test (scripted) | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests | P2.13 scripted damage-while-Console-open result; re-observed by tester probe at P2.16 |
| Focus loss test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.14 window-focus and controller-disconnect pause result, `--no-focus-pause` exercised |
| Movement-only test | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.14 internal-tester result: every Draft resolved and, with the setting on, one Console purchase completed |
| Teaching Siege tuning check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.14 T4 no-player-vs-responsive-bot result across 5 of 5 seeds each |
| Scrap loss test | MASTER_SDLC.md > Acceptance Test Matrix > Core Tension Tests | P2.14 run-end zero-Scrap-on-death result |
| HUD layout check | MASTER_SDLC.md > Acceptance Test Matrix > Readability Tests | P2.14 four-field layout result at the pinned viewport resolution |
| Pause authority test (full) | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.14 result confirming nothing changes state under Draft/pause-menu/focus-loss |
| Run flow check | MASTER_SDLC.md > Acceptance Test Matrix > Technical Tests | P2.14 run-end screen field result (death cause or wave reached, Scrap held, time survived) |

Per MASTER_SDLC.md > Document Control > Gate Approval, no agent writes that any of these tests, or this phase, is passed, satisfied, met, or ready; that determination belongs to the reviewers named in "Agent assignment" and, for any accepted-gate row, to the human designer alone. This document records what each test checks and where its result is recorded, nothing more.

## Predetermined failure points and risks

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| A partial pause caused by a timer that does not run on SimClock | P2.12 (Draft), P2.13 (Console), and P2.14 (pause menu, focus loss) each introduce their own UI timers (hold-to-confirm fill rings, the Console's purchase channel, input lockouts); a Godot `SceneTreeTimer` or `Tween` left off PauseAuthority's control would keep advancing while the Draft or pause menu is open | Route every one of these timers through SimClock and PauseAuthority only (MASTER_SDLC.md > Risk Register: "Godot pause traps (SceneTreeTimer, Tween, PROCESS_MODE_ALWAYS leakage)"; banned APIs listed under Global Simulation Authority) | Pause authority test (full); Console non-pause test as the inverse check, confirming the Console's own channel timer keeps running under SimClock while the rest of the sim is not paused |
| The Draft auto-confirming a held input on open | If a player is holding the movement-only confirm direction, a gamepad stick, or a key at the exact moment a level-up opens the Draft, a hold-to-confirm path that arms immediately would confirm a card the player never chose | Implement the neutral-return arming rule exactly per docs/19_UI_UX.md > "Upgrade Draft UI & Navigation" > "Input Lockout & Arming": hold-to-confirm inputs arm only once input has returned to neutral at least once after the lockout ends | Draft input lockout test |
| The Console opening on radius entry alone and becoming a safe stop | A simpler implementation of P2.13 might open the Console the instant the player enters the Interaction Radius, turning the radius into a place to stand safely without needing to transact | Implement the Console's documented lifecycle exactly (docs/19_UI_UX.md > "Tower Console UI" > "Lifecycle": 0.3 s below 10% base speed inside the radius, at least one affordable entry); keep the player's auto-fire disabled at any speed while overlapping the radius regardless of whether the Console is open | Console rules test; Interaction window test (scripted), which checks that opening the Console during an active encounter still costs the player something |
| Upgrade pool produces a dominant build | P2.11's six upgrades and two fallback cards are a small pool; with only three ranks and shared ranks between channels, one upgrade could end up strictly better than the others at every rank | Cross-check each upgrade's per-rank effect against the others once all six are implemented, before Phase 05 review (MASTER_SDLC.md > Risk Register: "Upgrade pool produces a dominant build" - mitigation "Pool audit before every content milestone"); the full Dominant pair audit is a VS-tagged test out of prototype scope | Upgrade effect check confirms each upgrade applies its documented effect with no drift; a qualitative pool read is added to REVIEW.md for this phase since no prototype-tagged test measures dominance directly |
| Determinism / keyed RNG drift | P2.12's Draft offers and P2.10's earlier drop rolls both consume keyed RNG; if the Draft's card-offer roll is not keyed off the run seed and a stable counter (draft index, not wall-clock time or an object instance ID), replaying the same seed will not reproduce the same three cards | Key every Draft roll exactly per MASTER_SDLC.md > Provisional Values Register > Technical Caps & Performance > "Keyed RNG" (hash of run seed plus a named, stable counter), matching the pattern already proven for spawn and drop rolls in Phase 04 | Determinism test |

## Agent assignment

Sonnet subagents implement and write: one Sonnet subagent per task (P2.11 through P2.14).

Opus runs one critical agent per task (four critical agents, P2.11 through P2.14) plus one phase reviewer for Phase 05 as a whole. Each critical agent and the phase reviewer receive this PLAN.md, LEDGER.md, and the artifacts each task produced, but never the implementer's reasoning or chat transcript, per phases/README.md loop rule (c).

## Open questions for the author

1. P2.11's owner (17) and P2.12's owner (13) do not yet exist as files; P2.13's consulted document (07) does not exist either. This plan cites MASTER_SDLC.md's own Player Overview and Provisional Values Register sections, and docs/19_UI_UX.md where it already covers the interface half of P2.12/P2.13, in their place - the same pattern flagged in Phase 03 and Phase 04.
   a. MASTER_SDLC.md and docs/19 remain binding for these tasks until 07, 13, and 17 are written.
   b. Write stubs or working drafts for 07, 13, and 17 before Phase 05 implementation starts.
   c. Other (please specify).
2. MASTER_SDLC.md > Provisional Values Register > "Level-Up Draft" row states the Reroll rule differently per milestone: one per run in the prototype, one per draft in the vertical slice. P2.12 is a prototype-scope task (tag P on its tests), so this plan implements one Reroll per run only, with no slice-scope behaviour built ahead of time.
   a. One Reroll per run only for the prototype, as this plan assumes; the slice's one-per-draft rule is Phase 3 (Vertical Slice) scope.
   b. Build the Reroll system to already support both modes, switched by a milestone flag, even though only the prototype mode is exercised now.
   c. Other (please specify).

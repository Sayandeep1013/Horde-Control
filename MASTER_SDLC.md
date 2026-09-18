# Project Codename: [Working Title] (named at the vertical slice gate)

# Master Software Development Lifecycle (Master SDLC)

**Version:** 0.8.6  
**Status:** Pre-Production (Document-Ready gate pending independent verification and the designer's acceptance; see Development Status)  
**Engine:** Godot 4.7.1 stable (Provisional Default; the installed version on the development machine)  
**Last Structural Revision:** Round 4 correction pass against a single binding brief and addendum, following round 3's six blind reviewers scoring every module 4/10 and intent 5/10. Applied the brief's canonical rules and value changes across the document set, split system-specific detail into working documents docs/09, 11, 19, 20, and 29, and recorded the author's decisions on contradictions inherited from the 0.5.0 original in the Review Decision Log. This pass does not claim every finding is resolved; verification and the designer's acceptance are still pending.

---

## Document Control

This file is the root of the documentation tree.

It is the only document permitted to describe the project as a whole. Every other document describes exactly one system.

When this document and a system document disagree, the system document wins on detail and this document wins on intent. If the disagreement is about intent, the conflict is a design bug and must be resolved before implementation continues.

If a system document is not yet stable, the default policies in this document are binding until the owning system document explicitly overrides them.

A system document is **stable** when all of the following are true: its version is 1.0.0 or higher, every edge-case register entry it owns is resolved or explicitly accepted in writing, it contains no placeholder, and it has been reviewed against this master document with the review recorded in this file's change log.

A system document is **working** when its version is at least 0.5.0, it covers every item in its Owns list, and it has no placeholder in any edge case it owns. A working document is binding for the prototype under the Provisional Defaults Policy below, the same as this file's own defaults, but it has not yet passed the review that stable status requires.

### Provisional Defaults Policy

This document is not a tuning specification, but a prototype cannot be built without numbers. Every number, formula, threshold, and named value in this document that does not appear in a system document is a **Provisional Default**: binding for the Minimum Playable Prototype and the Vertical Slice until the owning system document overrides it. Provisional Defaults may be changed, but they may not be ignored. A change is one commit that updates the Provisional Values Register and every section of this document stating the value; a change that alters intent, not just a number, also adds a row to the Review Decision Log. The Provisional Values Register is the only complete list of gameplay numbers in this document. Numbers stated as ranges in Session Shape are reference frames, not Provisional Defaults.

### Gate Approval

Where this document says a gate is "accepted", "approved", or "passed", only the human designer writes that row in the Change Log naming the gate and the date; an AI collaborator may propose the row's text but may not write it into the Change Log itself. A gate row does not change this document's version number. No other approval mechanism exists for a solo or small team; a larger team may replace this rule in document 28.

---

## Versioning Rules

The version number of this document follows three parts.

Major increments when the core loop changes shape — except before 1.0.0, when a core-loop shape change increments the minor version instead, since the whole document is still pre-release.

Minor increments when a system is added, removed, or restructured.

Patch increments for clarification, wording, and correction.

A version bump on this file requires a matching note in the change log below.

---

## Change Log

| Version | Change |
| --- | --- |
| 0.1.0 | Initial master overview. Vision, loop, systems index. |
| 0.2.0 | Added encounter taxonomy, edge case register, risk register, dependency map, glossary, and quality gates. |
| 0.3.0 | Added development readiness threshold, minimum playable prototype gate, interim technical budgets, global simulation authority, default unresolved-state policies, content data contracts, acceptance test matrix, vertical slice scope freeze, and playtest validation pass criteria. |
| 0.4.0 | Integrated critical implementation gaps: Camera & Viewport rules, Tower physical interaction mechanics, Upgrade Draft UI & Input navigation, Godot 4.x architecture standards, Directional Threat Feedback, Audio Bus mixing, Input Buffering limits, Animation/Hitbox cleanup, Debugging/Telemetry tools, and UI Text Expansion rules. |
| 0.5.0 | **Deep-Dive Stabilization:** Expanded UI Layout & Dynamic Container Rules (Godot specific). Expanded Animation, Hitbox, and State Cleanup Rules (Logical vs Visual death). Defined exact Factory & Economy flow (Run vs Meta currencies). Defined Wave Pacing & Spawn Ring algorithms. Added Pickup Physics & Magnet rules. Added Upgrade UI differentiation rules. |
| 0.6.0 | **Supervised Critical Review:** Stated the perspective (top-down 2D) and defined the arena. Fixed the Run ⊃ Biome ⊃ Wave ⊃ Encounter hierarchy and renamed the "Standard Wave" encounter to "Standard Assault". Reconciled the economy: Scrap is run-only, Cores enter the Meta Wallet by three defined routes. Defined the two upgrade channels (Level-Up Draft and Tower Console) and their pause semantics. Defined XP as a pickup. Rewrote the input floor and added movement-only confirmation. Fixed the onboarding time budget. Defined boss cadence and biomes per run. Added enemy behaviour defaults (Opportunist events, Hunter leash, body-block rule, contact damage). Defined the Spawn Ring geometry, the Pressure Metric formulas, de-escalation clamps, and a single Overtime trigger. Rewrote Godot standards (events vs queries, SimClock, PauseAuthority, binding collision layers, determinism scope, performance fallback ladder, audio priority bus). Added player and Tower recovery rules, provisional gameplay budgets, seven missing data contracts, field semantics, missing glossary terms, missing owners, dependency-map rows, measurable acceptance tests with milestone tags, the Development Phase Map, the Provisional Values Register, and the Review Decision Log. Split the Readiness Threshold into Document-Ready and Build-Ready. The "Upgrade UI differentiation rules" credited to the 0.5.0 entry above were not actually present in the 0.5.0 body; they were added in this pass. |
| 0.7.0 | **Round 3 Correction Pass:** Corrected against a single binding brief after six blind reviewers scored every module 4/10 and intent 5/10. Restored the original 0.5.0 change log entry verbatim and moved the correction about the Upgrade UI differentiation rules into the 0.6.0 entry where it belongs. Changed the perspective to three-quarter top-down and added the viewport, stretch-mode, and Y-sort conventions. Replaced the old two-input floor with movement alone, and standardised hold-to-confirm (0.4 second lockout, neutral-return arming) across every paused menu. Split the biome's eight waves into eight combat waves plus separate Mini-Boss Checkpoint and Biome Boss boss waves, called out the first biome's four teaching waves as their own wave type, and deferred all wave-timing detail to Wave Director & Spawning Logic › Wave Runtime Model rather than restating it in the Structure Hierarchy. Corrected the inter-wave gap to 8 seconds (5 seconds after teaching waves T1 through T3) and gave idleness a single definition tied to the Run Recorder's metric. Re-centred the Three Second Rule's second probe on danger rather than current health. Rewrote the safe-corner anti-pattern to cite the handgun's range and the Hunter leash rule alongside intent mix, and defined "kill zone". Split the Document-Ready and Build-Ready criteria more precisely and added a before-development reading order. Beyond this section, the same pass corrects every stale number against the Provisional Values Register, fixes document ownership across the Documentation Structure, and replaces the degenerate Orbit test with a scripted-bot comparison. |
| 0.8.0 | **Round 4 Correction Pass:** Applied the round 4 fix brief and addendum following round 3's six blind reviewers (modules 4/10, intent 5/10). Split system-specific detail this file previously restated into working documents docs/09 (Enemy AI Architecture), docs/11 (Wave Director), docs/19 (UI & UX), docs/20 (Technical Architecture), and docs/29 (Milestones & Roadmap), leaving this file the intent, pillars, loop, and the rules that have no other owner. Recorded the author's decisions resolving contradictions inherited from the 0.5.0 original — among them onboarding compression, the first Siege's losability, and boss cadence — as dated rows in the Review Decision Log. Adopted a "prototype-phase ready" bar for this pass: no contradictions anywhere in the document set, no open Major finding affecting Phases 0–2, no regressions against the round 3 ledger, and intent preservation of at least 8 out of 10, with vertical-slice and production detail tracked as owned deferrals in docs/29. This entry describes what this pass did; it does not assert that every round 3 finding is closed or that the Document-Ready gate is satisfied — see Development Status. |
| 0.8.1 | **Execution mapping pass:** added two Phase 0 tasks to the Development Phase Map — E0.1 (prove and choose the agent-to-Godot control path) and E0.2 (install and verify Godot skills) — carrying the work `NEXT_SESSION.md` Prompts 2 and 3 describe, which had no task ID, and added them as dependencies of P0.2 and P0.5. Recorded as decision D77. Also recorded decision D78, binding the two debug toggles the Settings check requires — F1 for the debug overlay, F2 for pseudo-localization — in docs/19 › Input Map, which had named none. No gameplay rule, number, or gate changed; the Provisional Values Register is untouched. Execution of the map is now tracked phase by phase in `phases/`. |
| 0.8.3 | **Phase 00 review iterations 2 and 3:** recorded decisions D81 (documents 20 and the Risk Register corrected, because the designer confirmation they asserted does not intercept delegated subagents; five tools denied outright), D82 (the Settings check's target amended to what can actually be run, since a release-template build cannot host `--script`), and D83 (the review-gate reviewer count, and the pace policy the author set for later phases). The Risk Register's MCP row and the Acceptance Test Matrix's Settings check row were rewritten accordingly. No gameplay rule or number changed; the Provisional Values Register is untouched. |
| 0.8.2 | **Phase 00 review corrections:** recorded two decisions the execution record carried but the plan did not. D79 moves remote hosting into P0.1's scope, amending its Out column to match the GitHub repository the author asked for. D80 records committing `export_presets.cfg` rather than excluding it, because P4.5.3 needs byte-identical repeat exports. Both were raised by the blind critical review of P0.1, which found the source of truth contradicting the repository. No gameplay rule, number, or gate changed. |
| 0.8.4 | **Phase 01 decisions and review corrections:** recorded eight decisions taken while executing P0.4, P0.6 and P0.7. D84 strips the local settings file back to an empty allow list, because it had silently re-opened every permission D81 closed. D85 reads P0.4's Owns criterion against document 02 alone. D86 pins the gdUnit4 version in document 28 alongside the two MCP servers. D87 types a contract "band" field as one shared value-plus-label resource, reconciling this file's contract lists with document 20's field semantics. D88 records document 01's pillar precedence order with the alternatives considered, so it can be reversed deliberately. D89 keeps the XP level-cost coefficients authored as data. D90 adds a lead-time field to the shared Telegraph data struct, distinct from wind-up duration. D91 adds a single structural-count carve-out to CLAUDE.md's numbers rule, with a tie-break clause. Document 20's Contract Field Semantics was updated for D87, D89 and D90; document 28 was raised to 1.1.0 for D86. **No gameplay rule, number, or gate changed; the Provisional Values Register is untouched.** This entry records what the phase decided; it does not assert that Phase 01's gate is met, which the reviewers and the author decide. |
| 0.8.5 | **Phase 01 review iterations 2 and 3:** recorded decisions D92 and D93. D92 puts document 01's mapping of each Explicit Anti-Pattern to the pillar it enforces on the record as a reversible decision, and flags the three legs of that mapping which are inferred from what the anti-pattern does to the player rather than quoted from this file. D93 records why the "Phase 0 accepted" row is deliberately withheld rather than proposed, Phase 00's closure being an undecided designer call. D92 was labelled an author decision in error and is corrected to an orchestrator decision; D93 was genuinely taken by the author. Raised by a blind reviewer that found the mapping asserted in the same voice as the pillars themselves with nothing behind it, and at least one leg this file does not support. Added in a separate pass from the 0.8.4 row above because it was taken after that row was written; recorded separately rather than folded in, so the sequence stays legible. No gameplay rule, number, or gate changed; the Provisional Values Register is untouched. |
| 0.8.6 | **Phase 02 entry:** recorded three decisions taken before implementation began. D94 groups Phase 02's seven tasks into four critical agents by coupled subsystem plus the phase reviewer, a narrowing of D83's pace decided in advance and written down as D83 itself requires. D95 reads document 20's audio section as binding for P1.6 while document 26 remains a stub. D96 confirms the six entity caps change under the ordinary Provisional Default rule with no separate sign-off gate. No gameplay rule, number, or gate changed; the Provisional Values Register is untouched. |

---

## Intended Audience

This document is written for four readers.

The designer, who needs the intent behind every system.

The programmer, who needs the boundaries between systems.

The artist, who needs the readability and clarity constraints.

The AI collaborator, who needs unambiguous scope when generating or refactoring code.

Every section is written so that all four readers can act on it without a meeting.

---

## Purpose

This document serves as the master overview of the project. It carries provisional implementation defaults for every system that does not yet have a stable document of its own; once a system document is stable, it supersedes this file's defaults for that system. Beyond those defaults, this document establishes the game's overall vision, gameplay direction, development philosophy, project architecture, documentation structure, prototype scope, and production safety gates.

Every major gameplay system will have its own dedicated markdown document (documents 00 to 30 in the Documentation Structure). Until a system document exists and is stable, the defaults in this file are the only binding text for that system. This file acts as the central index and should be read before opening any other documentation.

---

## What This Document Is

The single source of truth for project intent.

The index that maps a question to the document that answers it.

The record of what the game must never become.

The list of known edge cases that any implementation must survive.

The prototype and vertical-slice scope gates that prevent implementation drift.

The list of binding default rules for unresolved cross-system questions until owning documents are stable.

---

## What This Document Is Not

It is not a tuning specification. Final tuning values live in system documents. Numbers in this file are Provisional Defaults under the Provisional Defaults Policy in Document Control: binding until overridden, never final.

It is not a task tracker: it holds the Development Phase Map, and document 29 tracks progress against it.

It is not a scratchpad. Unproven ideas live in document 30.

It is not an unrestricted production approval. Production begins only after the gates in this document pass.

---

## How To Read This Document

Read the Game Overview and Core Gameplay Loop first. They define the shape of everything else.

Read the Core Gameplay Philosophy second. It defines why systems are allowed to exist.

Read the Encounter Types and Edge Cases sections before writing any gameplay code. Most implementation mistakes in this genre are not bugs in the feature. They are unhandled interactions between features.

Read the Development Readiness Threshold, Minimum Playable Prototype Gate, and Vertical Slice Scope Freeze before planning implementation work. These sections define what may be built next.

Before starting development, read in this order: the Development Readiness Threshold, the Minimum Playable Prototype Gate, the Development Phase Map, the Default Unresolved-State Policies, the Provisional Values Register, and the Review Decision Log. That order moves from whether the document is ready, to what the prototype must do, to the task-by-task plan, to the fallback rules for anything still unresolved, to the current numbers, to why past decisions were made.

Read the Documentation Structure last. It is a lookup table, not a narrative.

---

## Development Readiness Threshold

The threshold has two halves. The first half is a property of this document and can be satisfied by editing it. The second half is a property of the prototype build and can only be satisfied by building it. Conflating the two made the previous version of this gate unreachable.

### Document-Ready (this file must satisfy these)

1. The core tension can be tested without requiring final content, and the mechanism that tests it (the Tower Console vulnerability window and the encounter set) is fully defined in this file.
2. A minimum playable prototype is defined with explicit inclusion and exclusion rules, a defined run length, a defined success condition, and Provisional Defaults for every value it needs.
3. The Tower and player each have independent health pools with defined recovery rules and observable failure states.
4. Global pause, upgrade-screen, Tower Console, focus-loss, and transition rules are defined and do not contradict each other.
5. The prototype has acceptance tests that can fail, each with a numeric pass condition and a milestone tag.
6. The vertical slice scope is frozen with every mandatory system placed in or out.
7. Every design question raised against this document has a default rule, either in the Default Unresolved-State Policies table or in the section that owns the question, and Development Status lists any that are still open.
8. Every content type that must be data-driven has a data contract with typed fields.
9. Every edge-case register entry has an owning document.
10. A Development Phase Map exists in which every task has a goal, inputs, dependencies, a deliverable, an acceptance test, an exit criterion, and an owning document.

### Build-Ready (the prototype must satisfy these; tracked in Development Status)

1. The Wave Director can generate at least four distinct encounter types from data.
2. Entity caps and pooling are enforced in the prototype and tested under load.
3. A version-controlled repository exists, and every commit that changes a system's implementation also changes that system's document; this is checked at each phase gate.
4. All mandatory prototype acceptance tests pass.

If any Document-Ready condition is missing, this file is not ready to guide prototype development. If any Build-Ready condition is missing, the project is not ready for vertical slice work; full production also requires the vertical slice gate. It may still be used for exploratory prototyping, but not for system-final implementation.

---

# Game Overview

The project is a 2D action roguelite that combines elements from Horde Survival, Tower Defense, Action Roguelites, and Wave Survival games into a single gameplay loop.

The player controls a mobile defender responsible for protecting a central tower while surviving increasingly difficult enemy waves across multiple corrupted biomes.

Unlike traditional survivor games where the player is the sole focus of combat, this game introduces a second entity that is equally important: the Tower.

The Tower is not simply an object that must be defended. It is the center of gameplay. It functions as the player's base of operations, automated weapon platform, upgrade station, biome gateway, factory, and the objective that determines success or failure.

The player continuously moves around the battlefield while the Tower remains stationary at the center of the arena. Enemies approach from multiple directions with different objectives. Some prioritize attacking the Tower while others focus exclusively on the player. Two enemy categories change behaviour through a defined event rule and no other: the Opportunist may switch targets on defined events, and a Player Hunter that cannot reach the player converts permanently into a Tower Seeker through the leash rule (see Enemy Philosophy › Intent Behaviour Defaults); every other category holds its target for its entire lifetime. An enemy that is stuck falls back after a defined stuck duration: for most enemies this fallback is a direct approach and does not change their target, but a stuck Opportunist's fallback is to switch to its other candidate target; the full stuck and secondary-target rules (C-BLOCK) live in `docs/09_Enemy_AI_Architecture.md`.

## Perspective and Arena

The game is **three-quarter top-down 2D** (Provisional Default) with free 360-degree movement on a single plane. Collision is resolved as a circle at each entity's feet, and draw order is Y-sorted by that same foot position, with the player always drawn above enemies; see Visual Direction & Camera for the full draw-order rule. There is no vertical axis, no jump, and no verticality of any kind. "Flying" enemies share the plane for targeting and contact; they differ only in ignoring ground hazards and terrain collision.

The play space is called the **arena**. The words "battlefield" and "map" in this document always mean the arena; "level" always means an XP level (see Core Gameplay Loop), never the arena. Each biome is exactly one arena. The Tower stands at the exact center of the arena. The arena is bounded by hard walls; nothing leaves it, including flying enemies, which keep their arena-wall collision even though they ignore terrain and ground hazards. Bosses fight in the same arena as the Tower; there is no separate boss arena. The arena is larger than the screen, so the Tower can be off-screen while the player roams; the Directional Threat Feedback rules cover that case.

Provisional Default arena for the prototype and slice: a 4800 by 3200 pixel bounded rectangle, wider than tall like the screen, with no interior obstacles in the prototype. The Godot project viewport is fixed at 1920 by 1080 with stretch mode `canvas_items` and aspect `keep`, so a display of a different aspect ratio is letterboxed rather than cropped or stretched. The camera's base view shows 1920 by 1080 world pixels. This document describes camera zoom as a **view scale**: 1.0 is the base view, values above 1.0 show more of the world (zoomed out), and values below 1.0 show less (zoomed in). The view scale ranges from 0.9 to 1.15, so the largest view is 2208 by 1242 world pixels. In Godot 4, where a `Camera2D.zoom` above 1 magnifies, the camera's zoom is set to 1 divided by the view scale. At base speed (320 pixels per second) the player crosses the arena in 15 seconds east to west and 10 seconds north to south. The width matters: in a 3200 pixel wide arena the clamped camera could never put the Tower off-screen horizontally, and "the Tower is weakest where the player is not" needs the Tower to be able to leave the screen in every direction. The player starts each run 240 pixels south of the Tower's centre.

The player must constantly decide where their presence is most valuable. Remaining on one side of the battlefield for too long may leave the opposite side vulnerable, allowing enemies to damage the Tower. Likewise, overcommitting to defending the Tower may expose the player to dangerous enemy groups.

The gameplay is designed around battlefield positioning rather than aiming precision. Weapons fire automatically at nearby enemies, allowing the player to concentrate on movement, survival, and strategic positioning.

---

## The Central Tension

Every design decision in this project resolves back to a single tension.

The player is strongest where they are standing. The Tower is weakest where the player is not.

This produces a constant, self-generating dilemma that does not require scripted events to stay interesting. The player is always leaving something undefended. The only question is what.

If a proposed feature does not sharpen, complicate, or meaningfully reframe this tension, it does not belong in the game.

---

## Reference Points and Differentiation

The genre neighbours are well known. The differentiation must be explicit, or the project becomes an imitation.

| Reference Genre | What Is Taken | What Is Deliberately Rejected |
| --- | --- | --- |
| Horde Survival | Auto-firing weapons, dense enemy counts, upgrade draft on XP level-up | The player as the only thing that matters on the field |
| Tower Defense | A stationary asset with its own health and firepower | Pre-placement planning phases and static path mazing |
| Action Roguelite | Run-based progression, permanent meta unlocks, build variety | Room-by-room pacing and manual precision combat |
| Wave Survival | Escalating wave pressure, boss checkpoints | Purely reactive survival with no asset to protect |

The unique claim of this project is dual-entity survival. Two health pools, one player, one battlefield, and no way to fully protect both at once.

---

## Session Shape

A full run is expected to last approximately 32 to 35 minutes (Provisional Default), inside the twenty to forty minute target.

A full run contains three biomes (Provisional Default). The vertical slice contains one biome. The prototype contains one arena and no biome transition, with an expected length of 7 to 9 minutes (Provisional Default).

A single biome contains eight combat waves (Provisional Default), a Mini-Boss Checkpoint boss wave after combat wave four, and a Biome Boss boss wave after combat wave eight; a run's first biome additionally opens with four teaching waves (T1–T4) before combat wave one, exempt from the combat wave target below (see Onboarding). Eight combat waves at their target length, the inter-wave gaps between them, and the two boss waves' target durations sum to roughly 10 to 11 minutes per biome, depending on how many Sieges beyond the mandatory one the Wave Director schedules (see the Provisional Values Register for the full arithmetic). Three biomes at roughly 10 to 11 minutes each, plus roughly two minutes of first-biome teaching waves, land the run at approximately 32 to 35 minutes. Siege-heavy biomes run to about 11 minutes, slightly above the 6 to 10 minute reference frame; document 11 tunes toward the frame.

A single combat wave targets 40 seconds, with a maximum of 90 seconds (Provisional Default). A Siege wave targets 80 seconds (Provisional Default).

These targets are not final tuning values. They exist so that pacing decisions in other documents have a reference frame. If a system requires the run to be dramatically longer or shorter, that system must justify the change here first.

---

## Platform Direction

The primary target is Windows desktop (Provisional Default: Windows 10/11 x64; Linux and macOS are untested before the vertical slice), keyboard and mouse or gamepad.

The input floor is **movement alone**: a run can be completed by movement input by itself, with no other input required. Combat never requires any input beyond movement: weapons fire and target automatically, and the Tower fights on its own. Every paused menu in the game — the Level-Up Draft, the pause menu, settings, and the run-end screens — lays its choices out horizontally and can be driven by movement input alone through **hold-to-confirm**: a 0.4 second input lockout on open, after which hold-to-confirm arms only once input has returned to neutral; left and right cycle the choices; holding up (toward the highlighted choice) for 1.0 second (Provisional Default) confirms it, with a visible fill ring. The interface floor beneath every one of these menus is one stick plus Confirm and Cancel; in the Level-Up Draft, Reroll is also a focusable element beside the cards, reachable the same way.

The Tower Console is live rather than paused, so the stick must keep moving the player while it is open. The **Movement-only controls** setting (default off) replaces the Console's cycling with **sector selection** instead: seven fixed sectors around the Tower, each mapped to one Console entry regardless of where the player is standing, highlight the one the player currently occupies, and standing still in that sector for 1.0 second buys one rank (see Tower Console UI in docs/19 for the sector layout). The setting itself is offered as a hold-to-confirm choice on the run-end screens and in the pause and settings menus. Confirm, Dash, Reroll, and any other button are conveniences that make the same actions faster; none is required to complete a run.

Controller parity is a design constraint, not a post-launch port task. Any interface that cannot be driven by a stick and two buttons (Confirm and Cancel) must be redesigned (movement alone is the floor for completing a run; a stick and two buttons is the controller-parity baseline for interfaces).

---

# Core Gameplay Loop

Each run follows a structured progression.

The player enters a biome through the Tower.

Combat waves begin spawning enemies.

Enemies attack both the player and the Tower.

Defeated enemies drop experience shards, Scrap, and — for elites and bosses — Cores; see Resource & Economy System › Drop Table for the full table.

Experience fills a level bar; each level-up opens the Level-Up Draft, which offers free run-scoped upgrades for the player or the Tower while the simulation is paused.

Scrap is carried by the player and spent at the Tower Console, inside the Tower Interaction Radius, on priced run-scoped upgrades and Tower repair while the simulation keeps running. Scrap is lost if the player dies.

Cores bank instantly to the persistent Meta Wallet and fund permanent progression in the Hub between runs. Scrap beyond the player's carried cap overflows into a hopper that is carried with the player and converts to Cores only when the player enters the Tower Interaction Radius, which is the sense in which the Tower "processes" run resources into long-term progression; see Resource & Economy System › Currency Definitions & Flow.

After combat wave four of each biome a Mini-Boss Checkpoint boss wave occurs. After combat wave eight the Biome Boss boss wave occurs.

Defeating the Biome Boss completes the biome.

The Tower activates and transports the player into the next biome.

This loop repeats until the final biome is cleared (run success) or either the player or the Tower is destroyed (run failure).

---

## Structure Hierarchy

The run is built from four nested structures. The containment order is binding for every data contract and every system document.

**Run ⊃ Biome ⊃ Wave ⊃ Encounter.**

- A **Run** is one playthrough from launch to run success or run failure.
- A **Biome** is one arena with one mechanical hook, eight combat waves, a Mini-Boss Checkpoint boss wave, and a Biome Boss boss wave; a run's first biome also opens with four teaching waves before its first combat wave (see Onboarding).
- A **Wave** is a time-boxed pacing slot inside a biome — combat, boss, or (in a run's first biome) teaching — containing one or more Encounters. Its spawn budget, maximum duration, end conditions, and how surviving enemies carry over to the next wave are defined in Wave Director & Spawning Logic › Wave Runtime Model.
- An **Encounter** is one data-defined spawn pattern with an intent, a pressure target, a player answer, and a failure signature. The encounter taxonomy is listed in Encounter Types. "Standard Assault" is the default encounter. A wave is never itself an encounter.

## The Loop Exists At Four Scales

The loop above describes the run. In practice the player is experiencing four nested loops at once, and each one must be individually satisfying.

### Moment-to-Moment Loop (1 to 3 seconds)

Read threat direction. Reposition. Let auto-fire resolve. Collect what dropped.

This loop must be readable without conscious thought. If the player has to stop and interpret the screen at this scale, the visual direction has failed.

### Wave Loop (40 to 90 seconds)

Survive the spawn pattern. Decide which side of the battlefield to hold. Take an upgrade if an XP level triggers. Recover position during the inter-wave gap before the next wave.

This loop must contain at least one real decision. A wave that plays identically regardless of player choice is filler and must be redesigned or cut.

The inter-wave gap is downtime, not idleness. Provisional Default: 8 seconds of simulation time with no new spawns, or the last encounter's recovery gap if that is longer (see Encounter Composition Rules for the per-encounter-type recovery gaps, which also govern the gap after each teaching wave) — see Wave Director & Spawning Logic for the full rule. Idleness is a stretch longer than the scheduled gap plus any grace period plus 3 seconds with no enemy alive and no pickup within twice the magnet radius; the Run Recorder flags it. Because the threshold already allows for every legitimate gap, a flagged stretch is a pacing bug.

### Biome Loop (6 to 10 minutes)

Learn the biome hazard. Survive the biome's waves and its Mini-Boss Checkpoint. Accumulate resources. Defeat the Biome Boss. Cross to the next biome with everything the Biome Transition Rule allows to persist. (An explicit end-of-biome "carry forward" choice was considered and is parked in document 30; the transition is automatic.)

This loop must teach something. Each biome introduces one mechanic that changes how the player evaluates the battlefield.

### Run Loop (20 to 40 minutes)

Build a combination of player upgrades and Tower upgrades. Push as deep as the build allows. Convert the run into permanent progression whether it succeeded or failed.

This loop must never end in nothing. A failed run must still advance the meta layer, or failure becomes punishment instead of pacing.

---

## Loop Entry And Exit Conditions

| Loop | Entry | Success Exit | Failure Exit |
| --- | --- | --- | --- |
| Run | Player launches from the Hub (prototype: boots directly into the arena) | Final biome cleared (prototype: the final combat wave ends with both the player's and the Tower's health above zero — see Wave Director & Spawning Logic › Wave Runtime Model) | Player or Tower reaches zero health |
| Biome | Tower portal activates | Biome Boss defeated | Run failure |
| Wave | Wave Director opens the wave | Defined in Wave Director & Spawning Logic › Wave Runtime Model | Run failure |
| Encounter | Encounter trigger fires | All its spawn groups emitted and every enemy it spawned dead or removed — the objective for the four prototype encounter types (Standard Assault, Split Assault, Siege, Hunt), which carry no reward; other encounter types define their own objective in the Encounter Definition Contract | Encounter failure resolution applied, or run failure |

Encounter failure is not automatically run failure. Default encounter failure resolution (Provisional Default): the encounter's reward is forfeited and no further penalty is applied beyond damage already taken; the run continues. The four prototype encounter types carry no reward, so none of them can fail this way; for them the only failure exit is run failure. An encounter whose win condition becomes impossible self-resolves with a partial reward: half of its reward rounded down (an encounter with no reward grants nothing) (C-PARTIAL, see Edge Cases and Failure States). Encounters with partial rewards state them in their definition; see the Encounter Definition Contract.

---

# Core Gameplay Philosophy

The gameplay is intended to create constant decision making.

The player should never remain idle. Downtime (a short inter-wave gap with something to collect or a position to recover) is allowed; idleness (see The Loop Exists At Four Scales › Wave Loop for the exact definition) is not.

Every moment should involve choosing between competing priorities.

Examples include:

- Defending the Tower
- Chasing experience drops
- Collecting resources
- Escaping dangerous enemy groups
- Repositioning across the battlefield
- Upgrading either the player or the Tower
- Preparing for the next wave

The player is never expected to manually aim.

Instead, gameplay focuses on movement, positioning, and tactical decisions.

---

## Design Principles

These principles apply to every system document. They are the test a feature must pass before it is built.

### Positioning over precision

Skill expression comes from where the player stands, not how accurately they click. Any mechanic that rewards twitch aim is out of scope.

### Two things to protect, never enough time for both

Any feature that lets the player fully secure both the Tower and themselves at the same time removes the core tension and must be rebalanced.

### Readability before spectacle

Effects scale up as power scales up, but the player must always be able to see incoming threats. When spectacle and clarity conflict, clarity wins.

### Escalation must be visible

The player should be able to tell how far into a run they are by looking at the screen, without reading a number.

### Failure must teach

When a run ends, the player should be able to name the decision that ended it. If they cannot, the failure was noise.

### Systems isolate, effects combine

Systems must not know about each other's internals. Their outputs may combine freely. This is both a design rule and an architecture rule.

---

## Explicit Anti-Patterns

The following are known failure modes for this genre. They are banned unless a system document argues successfully against this list.

### The safe corner

Any position where the player can survive indefinitely without moving. Wave composition and enemy targeting must make every static position eventually fatal. This guarantee is delivered by intent mix, not by any single wave: every biome must schedule Player Hunters often enough that standing still is eventually fatal, and the Hunter leash rule ensures a Hunter that cannot reach the player becomes a Tower Seeker rather than giving up. The same guarantee holds for the Tower: an armed player's centre is at least 174 px from the Tower's centre (160 px radius + 14 px body); a Tower Seeker attacking the far side stands at least 120 px from the Tower's centre on the opposite side (106 px footprint + 14 px body), so it is at least 294 px away, beyond the handgun's 260 px range. No armed standing spot covers the whole Tower, so guarding the Tower also demands movement. A kill zone — the area within the Tower's own weapon range (see Tower Overview › Tower Targeting Rule) — is not a safe corner: it protects against enemies the Tower can reach, not against Player Hunters, whose intent is the player rather than the Tower.

### The solved build

A single upgrade combination that trivialises all content. Upgrade pools must be checked for dominant pairs.

### The invisible death

Damage that the player could not have seen coming. Every damage source requires a telegraph.

### The empty wave

A wave that generates no decision. Every wave must apply pressure to at least one of the two health pools.

### The idle minute

Any stretch where the optimal play is to stand still and wait. Downtime is allowed; idleness is not.

### The unreadable screen

Enemy count or particle density that hides threats. Density is capped by readability, not by hardware.

### The punished experiment

A build path that is unrecoverable once chosen. Rerolls, banishes, or pivots must exist. Provisional Default: one Reroll per run in the prototype, one Reroll per draft in the vertical slice; Banish is excluded from the prototype and defined by document 13 for the slice.

---

## The Three Second Rule

At any moment, the player should be able to answer three questions in under three seconds by looking at the screen.

1. Where is the threat coming from?
2. Which health pool is in danger?
3. What am I giving up by moving toward it?

If any of the three cannot be answered at a glance, the UI, VFX, or enemy telegraph is wrong.

Each question has a measurable probe used by the Acceptance Test Matrix, run as 10 fixed freeze-frame stills captured from designer-recorded runs, the same 10 stills shown to every tester, each with at least 5 enemies on screen. For question one the tester points at the threat, on screen or at the screen edge, checked against the Run Recorder's ground truth for that still. For question two — which pool is in danger — the tester names the pool (player or Tower) that will take damage first in the next 5 seconds, checked against the Run Recorder's ground truth, not simply which pool is currently lower. For question three the tester names what is left undefended if the player moves toward the threat, checked against a designer answer key written before the session; health is compared as a percentage of max. Every answer must land within 3 seconds of the still. Pass: at least 8 of 10 stills answered correctly for at least 4 of 5 testers.

---

# Tower Overview

The Tower is the central system around which the entire game is built.

The Tower functions as:

- Primary objective
- Automated defense platform
- Upgrade station
- Resource processor
- Factory
- Portal between biomes
- Progression hub

Both the player and the Tower possess independent health pools.

If either reaches zero, the current run immediately ends.

Tower upgrades may improve:

- Firepower
- Range
- Fire rate
- Shield generation
- Resource processing
- Support drones
- Area denial weapons
- Utility systems

The Tower should evolve visually throughout a run so that players can immediately recognize their progression.

---

## Why The Tower Has Its Own Health Pool

A shared health pool would collapse the game into standard horde survival. Two pools create four distinct run states, and each state should feel different to play.

| Player Health | Tower Health | Player Behavior This Should Produce |
| --- | --- | --- |
| High | High | Aggressive expansion, resource collection, roaming far from the Tower |
| High | Low | Emergency defence, orbiting tight, sacrificing resource income |
| Low | High | Kiting at range, using the Tower as cover and as a damage source |
| Low | Low | Desperation, high risk decisions, likely run ending |

The Wave Director should be aware of which quadrant the run is currently in. This is expanded in document 11.

---

## Tower Roles In Detail

As an objective, the Tower converts positioning into stakes. Distance from the Tower is measured risk.

As a weapon platform, the Tower gives the player a reason to fight near it even when it is not under threat, because the Tower's damage output supplements their own.

As an upgrade station, the Tower creates deliberate approach moments. The player must physically return to interact, which costs battlefield position.

As a resource processor, the Tower is where Scrap is spent and where Scrap that overflows the player's cap is converted, visibly and at a reduced rate, into Cores. Cores are what make a failed run still worth playing; the exact routes are defined in Currency Definitions & Flow.

As a factory, the Tower produces persistent battlefield assets such as drones and turret modules, which extend its threat radius over time.

As a portal, the Tower is the only transition between biomes, which keeps the fiction and the systems anchored to one object.

---

## Tower Interaction Mechanics

The Tower is not a passive menu; it is a physical location the player must risk visiting.

- **Resource Collection:** Enemies drop resources. The player has a passive "magnet" radius that pulls resources to them. Resources collected are held in the player's "run inventory."
- **Processing & Upgrading:** To spend Scrap on immediate Player or Tower upgrades, or on Tower repair, the player must physically enter the **Tower Interaction Radius** (a circle around the Tower base; Provisional Default 160 pixels in the prototype arena). The interface that opens there is the **Tower Console**.
- **The Tower Console:** The Console opens automatically once the player has been stopped (speed under 10% of base) inside the Interaction Radius for 0.3 seconds **and** at least one entry is affordable — Repair affordability follows C-REPAIR (docs/19 › Tower Console UI). It closes on leaving the radius, on Cancel (keys and buttons follow docs/19 › Input Map), on player death, or the instant a Level-Up Draft opens. After a Cancel it stays closed until the player leaves the radius and re-enters; Cancel is a deliberate exit, not a pause. The Console is a **non-pausing, world-space interface**: the simulation keeps running, enemies keep attacking, and the Global Simulation Authority explicitly excludes it from the pause list. Because the left stick keeps moving the player, entries are cycled with the D-pad, the right stick, number keys, or the mouse, and each purchase is a 0.5-second channel with a fill ring — moving faster than 10% of base speed during the channel cancels it without spending anything; the movement-only alternative is sector selection, described in Platform Direction and the Tower Console UI.
- **The Vulnerability Window:** While the player's body overlaps the Tower Interaction Radius, the player's auto-fire is disabled at any speed (Provisional Default); the Tower keeps firing. The Tower Console opens only when the player has also been moving slower than 10% of base speed for 0.3 seconds with at least one affordable entry. This forces the player to choose *when* it is safe to return to base, directly feeding the core tension: entering the radius at all, not just stopping to shop, is what disarms the player.
- **No Safe Corners:** The Interaction Radius is not a safe zone. Enemies can and will attack the player while they are interacting with the Tower. If the player takes damage while the Console is open, the Console does not close, but the player must manage their health.
- **Two channels, one question:** Run-scoped upgrades reach the player through two channels that differ in kind, not in catalogue. The **Level-Up Draft** is free, random, and pauses the simulation; opening one closes the Console immediately if it was open. The **Tower Console** is priced, deterministic, and never pauses. Both may offer player upgrades and Tower upgrades. The full rule is in Upgrade Channels under Player Overview.

## Tower Targeting Rule

The Tower auto-fires at 20 damage per shot, 1.25 shots per second (25 DPS, Provisional Default), projectile speed 900 px/s. The Tower targets the nearest Tower Seeker in range, else the nearest enemy in range; a non-Seeker target is dropped on the tick a Seeker enters range; otherwise it retargets only when its target dies or leaves range. Provisional Default range: three times the Interaction Radius (480 pixels in the prototype arena). When no enemy is in range the Tower holds fire, consumes nothing, and any upgrade cooldowns keep ticking.

---

## Tower Evolution Stages

The Tower's silhouette changes three times across a full run, producing four distinct stages. The player must be able to identify their approximate power level from the shape alone.

| Stage | Trigger (Provisional Default: count of Tower upgrade ranks held from either channel) | Visual Signal |
| --- | --- | --- |
| Base | Run start (0 ranks) | Simple structure, single barrel |
| Reinforced | 1 rank | Armour plating, wider base |
| Armed | 3 ranks | Additional barrels, visible energy core |
| Fortress | 6 ranks | Orbiting drones, shield shimmer, area denial emitters |

Document 07 may retune the thresholds or key them to cumulative Scrap spent, but the trigger must remain a measurable count.

Visual evolution is a hard requirement, not polish. It is the primary readability channel for run progress.

---

## Tower Vulnerability Design

The Tower must never be fully safe and must never be trivially destroyed.

The Tower's own weapons should handle roughly the baseline wave pressure alone, but not the elite or specialised pressure.

Shield systems should regenerate on a delay so that neglect has a cost but a single mistake is not fatal.

## Health Recovery Rules

These rules are Provisional Defaults and are load-bearing for the core tension: if the Tower healed the player, orbiting the Tower would become the dominant strategy, which the prototype success criteria forbid.

- **Player health** does not regenerate passively. It is restored only by upgrade cards or pickups defined by documents 03 and 17. In the prototype exactly one player upgrade restores health: Patch Kit restores 30 health per rank taken.
- **Tower health** does not regenerate. It is restored only by the Repair action in the Tower Console. Repair is affordable when the Tower is missing at least 2 health and the player holds at least 1 Scrap. One purchase restores min(50, missing health rounded down to an even number, 2 × Scrap held) health at 1 Scrap per 2 health. At 0 Scrap Repair is greyed and does not count toward opening the Console.
- **Tower shield**: the base Tower has a shield equal to 25% of Tower maximum health. The shield absorbs damage before health. It begins regenerating at 10% of its maximum per second after 8 seconds without the Tower taking any damage to health or shield; every hit restarts that 8-second delay, including the hit that breaks the shield.
- Overheal on either pool is discarded unless an upgrade explicitly converts it to shield (see Default Unresolved-State Policies).

Damage to the Tower must be loud. Screen edge indicators, audio cues, and a directional damage flash are required.

The Tower must never die silently while the player is engaged elsewhere with no warning.

---

# Player Overview

The player acts as the mobile defender.

Movement remains the player's primary responsibility.

Combat occurs automatically through equipped weapons.

The player begins with a simple handgun.

As the run progresses, weapons evolve into stronger forms. The following list is non-binding inspiration; document 06 owns the real weapon ladder:

- Dual Pistols
- SMGs
- Assault Rifles
- Shotguns
- Gatling Guns
- Plasma Weapons
- Laser Systems
- Experimental Weapons

A grappling hook movement system may be added later. It is evaluated after the prototype playtest, not during prototype development, against the criteria in Grappling Hook Evaluation Criteria.

---

## Player Responsibilities

The player is responsible for four things and nothing else.

### Where to be

The central decision of the entire game.

### What to pick up

Experience and resources have different values at different moments.

### What to upgrade

Player power and Tower power compete for the same investment.

### When to disengage

Knowing when a fight is not worth the position cost.

Everything else is automated. This is deliberate. Removing aim from the player's workload is what makes the positioning decision the whole game.

---

## Upgrade Channels

Run-scoped power reaches the player through two channels. They share the investment question ("myself or the Tower?") but answer it differently, which is the point.

| | Level-Up Draft | Tower Console |
| --- | --- | --- |
| Trigger | XP level-up | Stopped inside the Tower Interaction Radius with at least one entry affordable |
| Cost | Free | Scrap, priced per upgrade rank |
| Selection | Three random cards from the upgrade pool | Fixed catalogue, player chooses |
| Simulation | Fully paused | Running; enemies attack; player auto-fire disabled |
| Position cost | None | The trip home and the vulnerability window |
| Offers | Player upgrades and Tower upgrades; at least one of each in every draft | Player upgrades, Tower upgrades, and Tower Repair |
| Extra actions | Reroll: 1 per run (prototype), 1 per draft (slice); Banish (slice only) | Cancel |

Rules that follow from the table:

- Player upgrade cards and Tower upgrade cards must be distinguishable at a glance in both channels by frame shape, a fixed glyph, and a header word ("PLAYER" or "TOWER"), never by colour alone.
- An upgrade rank purchased in one channel counts in the other; maximum rank is shared. Maxed upgrades are filtered from the draft and greyed in the Console.
- Tower upgrades taken in the Draft apply remotely and skip the physical return to the Tower that a Console purchase requires, because the Draft is the free, lucky channel; Tower upgrades bought in the Console are deliberate and cost position. Both feed the Tower's visual evolution count.
- In the prototype the pool is six upgrades, shared by both channels, each with maximum rank 3: Player — Rapid Fire (+20% player fire rate per rank), Heavy Rounds (+20% player damage per rank), Patch Kit (restores 30 player health per rank taken); Tower — Caliber (+20% Tower damage per rank), Optics (+15% Tower range per rank), Shield Matrix (+10% of Tower maximum health as extra shield per rank). A Draft slot guaranteed to an exhausted pool shows that pool's fallback card instead (Player "Overdrive", Tower "Reinforce"; see Default Unresolved-State Policies for the fallback rule).

## Player Contact and Collision Rules

- The player body is solid against enemy bodies and terrain. Enemies do not push the player; the player does not push enemies.
- Only enemies whose Contact Behaviour is Damage deal contact damage; in the prototype this is Player Hunters only. Contact damage applies when an enemy hitbox overlaps the player hurtbox: 8 damage per 0.5-second tick (16 DPS, Provisional Default), player only, no knockback, no global invulnerability frames. Enemy definitions declare this through the Contact Behaviour field of the Enemy Definition Contract.
- No enemy damages the Tower by contact. Tower Seekers damage the Tower only through their telegraphed attacks (melee in the prototype).
- Body contact is exempt from the telegraph wind-up minimums: approaching into contact range is itself the telegraph.
- A player surrounded by contact-damage enemies is trapped; this is intended, not a bug to be patched around. In the prototype the only answer is not getting surrounded in the first place; the dash, added in the vertical slice, is the intended escape.

---

## Starting Weapon

The player begins with a handgun (Provisional Default): 10 damage per shot at 2 shots per second (20 DPS), range 260 pixels, projectile speed 1000 px/s, re-picking the nearest target on every shot. The range is deliberately short: an armed player's centre is at least 174 px from the Tower's centre (160 px radius + 14 px body); a Tower Seeker attacking the far side stands at least 120 px from the Tower's centre on the opposite side (106 px footprint + 14 px body), so it is at least 294 px away, beyond the handgun's 260 px range. No armed standing spot covers the whole Tower, so defending it always costs the player position rather than being solvable by camping one spot.

Base player movement speed is 320 pixels per second, the reference unit 1.0 for every relative speed value in the Provisional Values Register; the player reaches full speed in 0.08 seconds and stops in 0.05 seconds. Movement input uses the 100 millisecond input buffer defined in Movement Design & Input Buffering.

The grappling hook is not part of the starting kit; see Grappling Hook Evaluation Criteria for how and when it is evaluated.

---

## Weapon Evolution Philosophy

Weapons should evolve in a visible ladder, not merely in numbers.

An evolution must change at least one of the following, or it is a stat upgrade wearing a costume.

- Effective range
- Coverage shape, such as cone, line, or radius
- Target count
- Engagement rhythm, such as sustained versus burst

A weapon evolution that only increases damage is a balancing tool, not a progression event, and should not be presented as one.

---

## Movement Design & Input Buffering

Base movement must feel responsive with minimal acceleration ramp. In a game where positioning is the only skill, sluggish movement reads as unfairness.

Movement upgrades should widen options rather than simply increase speed. Dashes, brief phasing, and pull mechanics create new positioning solutions. Raw speed only compresses the map.

### Input Buffering Rules
To prevent "eaten" inputs during high-stress moments, a strict input buffer is applied:
- **Movement & Dash:** A 100 millisecond (6 physics ticks at 60 Hz) input buffer is permitted for dashes and directional changes. If the player presses dash slightly before a cooldown ends or before a phase movement upgrade finishes, it queues. The buffer runs on simulation time and is cleared whenever the simulation pauses. Dash and phase are movement upgrades and are not in the prototype.
- **Auto-Fire Targeting:** Input buffering is **strictly banned** for auto-fire targeting. Target acquisition must be instantaneous and frame-perfect based on current position. Buffering here violates the "positioning over precision" rule by allowing the player to pre-aim.

---

## Grappling Hook Evaluation Criteria

The grappling hook is not a committed feature. It is evaluated as a time-boxed spike, at most two days, after the prototype playtest (task P2.17 in the Development Phase Map), and ships only if it passes all four criteria below.

1. It must create new positioning decisions rather than skipping existing ones.
2. It must not allow the player to permanently outrun all enemy types.
3. It must remain readable at high enemy density.
4. It must be usable on a gamepad without aiming precision.

If it fails any criterion, it moves to document 30 and stays there.

---

# Enemy Philosophy

Enemy variety should come from behavior rather than statistics alone.

Every enemy is described on two axes. The first axis is **target intent** (what it wants), defined in the next section; it is the axis waves are composed on. The second axis is **archetype** (how it fights), which is flavour on top of intent. Archetype examples, non-binding:

- Fast melee
- Long-range attacker
- Flying (ignores ground hazards and terrain collision; same plane for targeting and contact)
- Armored
- Suicide (contact behaviour: explode)
- Boss unit

Enemy behavior should encourage constant repositioning rather than standing still.

---

## Target Intent Categories

Every enemy declares a target intent at spawn. This is the single most important property of an enemy in this game, because it determines what the player loses by ignoring it.

| Intent | Behavior | Pressure Applied | Player Answer |
| --- | --- | --- | --- |
| Tower Seeker | Ignores the player, paths to the Tower, attacks it with a telegraphed melee or ranged attack | Tower health | Intercept early, away from the Tower |
| Player Hunter | Pursues the player until the leash rule converts it | Player health | Kite, use Tower fire support |
| Opportunist | Chooses the closer target at spawn, then switches only on defined events | Both, unpredictably | Control spacing so the choice is forced |
| Zone Denier | Occupies or hazards an area | Positioning freedom | Reroute or clear at cost |
| Disruptor | Blocks pickups, drains, or debuffs | Economy and upgrades | Prioritise over raw threats |
| Splitter | Divides into smaller units on death | Crowd management | Kill in open space, not near the Tower |

A wave is designed by choosing a mix of intents, not by choosing a mix of enemy names.

The full Intent Behaviour Defaults (Tower Seeker body-block rule, Player Hunter leash conversion, Opportunist event rule, stuck rules, and attack slots) live in `docs/09_Enemy_AI_Architecture.md`, a working system document that is binding for the prototype under the Provisional Defaults Policy.


---

## Behavior Requirements

Enemies must telegraph. Every attack has a wind-up that is visible at the density the encounter will actually reach.

Enemies must commit. An enemy that constantly re-evaluates its target reads as random and cannot be planned against. Target switching must be event-driven, not continuous.

Enemies must be individually readable in groups. Silhouette and colour must survive being surrounded by twenty others.

Enemies must not stall. An enemy that cannot reach its target must eventually do something, or the wave never ends.

---

## Elite Variants

Elites are not simply larger enemies with more health.

An elite modifies a base enemy with one behavioural affix, such as shielding nearby allies, leaving hazard trails, accelerating over time, or reviving once on death.

Elites should be visually distinct at a glance and should always be worth killing. An elite that is optimal to ignore is a design failure.

---

# Encounter Types

An encounter is any structured combat situation the Wave Director can produce. Encounters are the vocabulary the pacing system speaks in.

This section defines the full taxonomy. Detailed spawn tables, timings, and scaling live in document 11. Encounter names are data identifiers; the default encounter was previously called "Standard Wave" and is now "Standard Assault" so that a wave (the container) and an encounter (the pattern) are never confused.

Each encounter is defined by five properties.

- Intent — the design purpose of the encounter.
- Pressure — which health pool or resource is threatened.
- Player Answer — the intended correct response.
- Failure Signature — what it looks like when the player handles it badly.
- Edge Cases — the situations the implementation must survive.

---

## Standard Assault

Intent. Establish rhythm and baseline pressure. This is the default encounter and the one every wave falls back to.

Pressure. Mixed and mild. Both pools take light threat.

Player Answer. Roam, collect, and let auto-fire resolve most of it.

Failure Signature. The player is forced into the Tower's radius during a Standard Assault, which means either the encounter is overtuned or the build is behind.

Edge Cases. If the player clears the encounter far faster than expected, the next wave must not open without the minimum inter-wave gap. If the player clears it far slower, what happens to survivors and to the next wave's schedule is governed entirely by the Wave Runtime Model in Wave Director & Spawning Logic; this encounter does not define its own overlap rule. Provisional Default: the Tower's base damage output alone clears the standalone 90-second Standard Assault's Tower Seeker budget in no more than 60% of its maximum duration with no player help; this is the measurable form of "the Tower handles baseline pressure alone". Teaching waves T1 and T2 are exempt from this clause (see Onboarding).

---

## Split Assault

Intent. Force the player to choose a side of the battlefield.

Pressure. Tower health, from two or more directions simultaneously.

Player Answer. Pick the heavier lane, accept damage on the lighter one, and rely on Tower weapons to hold what the player abandons.

Failure Signature. The player oscillates between lanes, arrives late to both, and loses Tower health to both.

Edge Cases. Lane asymmetry is at least 60:40, so the choice is never arbitrary or meaningless (see Definitions). If the player has a movement upgrade that trivially covers both lanes, lane separation distance must scale with player mobility.

Definitions (Provisional Defaults). Lanes are fixed when the encounter opens. Each lane is a 40° sector of the Tower ring, matching the Wave Director's Directional Weighting. Prototype lane centres are 180° apart; from the vertical slice, separation = max(120°, the angle whose arc at the Tower's 480 px weapon range the player covers in 6 seconds at maximum speed with upgrades). Spawn validation shifts stay inside the lane's sector; a spawn with no valid point waits with its budget unused. Asymmetry is at least 60:40: each lane-split spawn group assigns ceil(0.6 × n) spawns to the heavier lane (C-GROUPS); prototype lane centres are 180° apart (C-LANES).

---

## Siege

Intent. Threaten the Tower specifically and pull the player home.

Pressure. Tower health, heavily and openly.

Player Answer. Abandon the map periphery, commit to close defence, and accept the loss of resource income for the duration.

Failure Signature. The player keeps farming the map edges and returns to a critically damaged Tower.

Edge Cases. A siege must never be winnable by standing still. From the vertical slice onward, Tower Seekers in a siege must include at least one ranged type that outranges the Tower — the ranged Seeker cut from the prototype is restored for the slice — or the encounter resolves itself without player input. In the prototype, which has one enemy per intent and no ranged Seeker, a Siege is prevented from self-resolving by **volume**: the Siege volume formula (see Wave Director & Spawning Logic › Pacing & Escalation Algorithm in docs/11, which also owns the per-wave multipliers) sets each Siege's Tower Seeker spawn budget above what the Tower can clear alone within the wave's maximum duration, plus a proportional share of Hunters so the player cannot ignore the rest of the map entirely. Because the handgun's 260-pixel range is shorter than what is needed to defend the Tower's full perimeter from one fixed spot, standing still still leaves part of the Tower exposed to melee Seekers approaching from elsewhere on the ring. A 3-second Siege warning (a Tower or off-screen indicator pulse plus a priority audio cue) precedes the first Seeker spawn. If the player is dead-ended far from the Tower by terrain, siege spawn timing must account for traversal time. De-escalation never applies during a Siege.

---

## Hunt

Intent. Threaten the player specifically and pull them away from the Tower.

Pressure. Player health.

Player Answer. Kite in wide arcs, use the Tower as a damage assist, and avoid getting cornered.

Failure Signature. The player runs in a straight line, gets surrounded at a map boundary, and dies with the Tower at full health.

Edge Cases. Hunters use the leash rule in Intent Behaviour Defaults: after 20 seconds without dealing damage they convert into Tower Seekers, so an infinitely kiting player eventually loses Tower health instead of resolving the encounter for free. Hunters must not path through the Tower's kill zone so reliably that the encounter trivialises; Hunt spawn weighting is defined in Directional Weighting. When a Level-Up Draft opens, Hunters freeze under the pause rules in the Global Simulation Authority section; the Tower Console does not pause them.

---

## Pincer

Intent. Punish predictable orbit patterns.

Pressure. Player health and positioning freedom.

Player Answer. Break the orbit, cut through the gap early before it closes.

Failure Signature. The player continues their orbit into a closing ring and is caught.

Edge Cases. The pincer must have a visible gap at spawn so that the correct answer is discoverable, not memorised. Spawn positions must never appear inside the player's current position or immediate movement arc. Pincer is one of the three **on-screen spawn exceptions** to the Spawn Ring (with Ambush and Breach): its enemies spawn inside the camera view through telegraphed spawn markers of at least 1.0 second, never closer to the player than min(2 seconds of player travel, 0.8 times the view's half-height).

---

## Swarm Crush

Intent. Stress-test crowd clearing and reward area damage builds.

Pressure. Both pools, through sheer volume.

Player Answer. Funnel, kite into the Tower's area weapons, and use area-of-effect upgrades.

Failure Signature. The player attempts to fight through the middle of the swarm and is stopped by body contact damage.

Edge Cases. Swarm Crush is the primary performance risk in the project. It must respect a hard entity cap. When the cap is hit, spawning throttles rather than queueing. Enemies culled for performance must never be culled from the player's visible screen area. Drop volume must also be capped, or the pickup layer becomes the bottleneck instead of the enemy layer.

---

## Ambush

Intent. Punish tunnel vision and reward peripheral awareness.

Pressure. Player health, suddenly.

Player Answer. Notice the spawn telegraph and pre-move.

Failure Signature. The player is hit before they register that anything spawned.

Edge Cases. Ambush spawns require a mandatory telegraph window with a minimum duration (Provisional Default 1.0 second), no exceptions for difficulty scaling. Ambushes must never spawn within a minimum radius of the player (Provisional Default: min(2 seconds of player travel at current speed, 0.8 times the view's half-height)). Ambush is an on-screen spawn exception to the Spawn Ring and uses telegraphed spawn markers. Ambushes must not fire during the Level-Up Draft or within the post-draft grace period.

---

## Elite Encounter

Intent. Introduce a single high-value target that changes the local rules.

Pressure. Depends on the elite affix.

Player Answer. Identify the affix, decide whether to burst it down now or manage around it.

Failure Signature. The player ignores the elite and the affix compounds until the wave is unmanageable.

Edge Cases. An elite must not be able to become unkillable through its own affix stacking. Reviving elites must have a hard revive count. Shielding elites must not be able to shield each other in a loop.

---

## Mini-Boss Checkpoint

Intent. Test whether the player's build is on curve before the biome escalates.

Pressure. Both pools, sustained.

Player Answer. Commit fully, use accumulated upgrades, and treat it as a rehearsal for the biome boss.

Failure Signature. The fight drags long enough that the next standard wave overlaps it.

Edge Cases. Mini-boss fights must suppress or reduce regular spawns while active, or pacing collapses. If the mini-boss is somehow killed instantly by a burst build, the reward must still be delivered in full and the pacing gap must be filled rather than skipped.

---

## Boss Encounter

Intent. Serve as the biome's skill and build check.

Pressure. Both pools, with phase-specific emphasis.

Player Answer. Learn the pattern, manage the arena, protect the Tower during phases that target it.

Failure Signature. The player treats the boss as a damage race and ignores its arena mechanic.

Edge Cases. See the Boss Structure section, which carries its own edge case list.

---

## Environmental Event

Intent. Make the biome itself an opponent.

Pressure. Positioning freedom.

Player Answer. Reroute movement, use hazards against enemies where possible.

Failure Signature. The player treats hazards as scenery and takes avoidable damage.

Edge Cases. An environmental event must never fully enclose the Tower in a hazard the player cannot cross. It must never spawn a hazard directly on the player. Hazards must obey the same telegraph requirement as enemy attacks.

---

## Resource Rush

Intent. Offer a high-value, high-risk economy opportunity.

Pressure. Opportunity cost, not direct damage.

Player Answer. Judge whether the build can afford the time away from the Tower.

Failure Signature. The player takes the bait, over-commits, and returns to a damaged Tower.

Edge Cases. Resource Rush must never be strictly optimal or strictly worthless. If the player ignores it entirely, the resource must expire cleanly with no orphaned entities left on the field. If the player is at maximum storage, the rush must communicate that before the player travels to it.

---

## Blackout

Intent. Remove a system the player has come to rely on.

Pressure. Confidence and information.

Player Answer. Fall back to fundamentals, play conservatively until it lifts.

Failure Signature. The player continues playing as if the system were online.

Edge Cases. A blackout must never disable the player's ability to see incoming damage. It may disable Tower weapons, minimap, drop indicators, or auto-collection, but never core threat readability. A blackout must have a visible countdown so it does not read as a bug.

---

## Overtime

Intent. Resolve a stalling run.

Pressure. Escalating and unavoidable.

Player Answer. Finish the encounter rather than farming it.

Failure Signature. None. Overtime exists specifically to prevent an unbounded stall.

Edge Cases. Overtime must only trigger on genuine stalls, not on slow but legitimate play. There is exactly one trigger rule, defined once in the Wave Runtime Model in Wave Director & Spawning Logic and never restated with different numbers here: Overtime fires when the wave's maximum duration has elapsed **and** non-finisher kills over the last 30 seconds fall below the wave's stall threshold (5 in the prototype). The measure is kills, not damage, because the Pressure Metric already reacts to how much damage the player and Tower can deal. Elapsed time alone never triggers it; a slow player who is still killing is not stalled.

---

## Escort

Intent. Give the player a third thing to care about and break the two-pool habit.

Pressure. A temporary objective with its own health, moving across the battlefield.

Player Answer. Travel with the objective while judging how much Tower damage the detour is worth.

Failure Signature. The player abandons the escort immediately and treats it as a non-event, or protects it perfectly and loses the Tower.

Edge Cases. The escort must never path into a hazard the player cannot clear. If the escort is destroyed, a partial reward is still granted so the encounter is not pure loss. If the escort completes while the player is on the far side of the map, the reward must still be delivered to the player, not dropped at the destination.

---

## Breach

Intent. Attack the player's assumptions about where enemies can come from.

Pressure. Positioning, by opening a spawn direction that was previously safe.

Player Answer. Re-plan the orbit around the new opening rather than defending the old one.

Failure Signature. The player keeps guarding the original approach lanes and is flanked repeatedly.

Edge Cases. A breach must be telegraphed before it opens, with enough warning to travel across the map (Provisional Default: 15 seconds, the longer of the two arena traversal times). A breach must not open directly adjacent to the Tower. If multiple breaches open, their combined spawn rate must respect the global entity cap rather than summing freely. Breach is an on-screen spawn exception to the Spawn Ring: the breach point itself is a telegraphed spawn marker.

---

## Duel

Intent. Isolate the player against a single dangerous opponent with no crowd support.

Pressure. Player health, with clean readability.

Player Answer. Learn a pattern under low noise. This is the encounter that teaches mechanics the boss will reuse.

Failure Signature. The player kites without engaging and the encounter times out with nothing learned.

Edge Cases. Regular spawns must be suppressed for the duration, or the isolation is meaningless. The duel opponent must not be able to disengage permanently. If the player refuses to engage, the opponent escalates rather than the encounter stalling.

---

## Encounter Composition Rules

The Wave Director must respect the following rules when sequencing encounters.

- Two Siege encounters must never occur back to back without an intervening recovery window.
- An Ambush must never trigger within the post-draft grace period (Provisional Default 1.5 seconds of simulation time after the Level-Up Draft closes).
- A Swarm Crush must never overlap a Boss Encounter.
- An Environmental Event must not begin while an Overtime is active.
- The player must experience at least one Hunt, one Siege, and one Split Assault per biome, so both threat modes and the split decision stay taught. This is also how the "Tower becomes irrelevant" risk is mitigated.
- Every combat wave after the teaching waves contains at least one Tower Seeker or Opportunist, so the Tower is never irrelevant to a wave.
- When an encounter completes, no encounter opens until that encounter's recovery gap has elapsed. When two encounters are due at the same moment, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap. Provisional Default priorities and recovery gaps for the prototype:

| Encounter | Priority | Recovery Gap |
| --- | --- | --- |
| Siege | 80 | 10 s |
| Split Assault | 60 | 8 s |
| Hunt | 40 | 8 s |
| Standard Assault | 20 | 5 s |

  Document 11 (Wave Director & Spawning Logic) owns the full order beyond these four.
- A Duel must precede the first appearance of any mechanic the biome boss will reuse.
- No more than one objective-carrying encounter, meaning Escort or Resource Rush, may be active at a time.

---

# Onboarding and First Session

A player who does not understand the Tower within the first ninety seconds will play this as an inferior horde survival game and stop; the Tower is understood — its own health pool, and that it fights back — by the end of T2, roughly 50 seconds in. The first Siege beat, the moment the lesson has consequences, lands at the end of T4, roughly 133 seconds in.

Onboarding is therefore a design requirement of the core loop, not a menu feature.

The four teaching waves are exempt from the Session Shape wave length. Provisional Default budgets: Opening (T1) 20 seconds, First escalation (T2) 25 seconds, First real decision (T3) 30 seconds, First consequence (T4, Siege) 40 seconds. Each wave is followed by its own encounter's recovery gap under the deferral rule (see Encounter Composition Rules): 5 seconds after T1 and T2 (Standard Assault), 8 seconds after T3 (Split Assault). T1 through T3 total 20 + 5 + 25 + 5 + 30 = 85 seconds, inside the ninety-second window above. Adding the 8-second gap and T4's 40 seconds, T4 ends approximately 133 seconds after launch; the first Level-Up Draft follows immediately, then a further 10-second Siege recovery gap precedes the first combat wave. Runtime rules for how each teaching wave starts, ends, and carries survivors over are defined once in Wave Director & Spawning Logic › Wave Runtime Model (docs/11) and are not restated here.

---

## What The First Ninety Seconds Must Teach

- The player has a health pool.
- The Tower has a separate health pool.
- Enemies want different things.
- Standing in one place fails.
- The Tower fights back.

Nothing else. Upgrades, resources, biomes, and meta progression can all wait.

---

## How It Must Teach

Through encounter sequencing, not text. The first biome's opening waves should be constructed as a lesson.

| Wave | Moment | Encounter | Lesson Delivered |
| --- | --- | --- | --- |
| T1 | Opening | Standard Assault, Player Hunters only | Movement and auto-fire work |
| T2 | First escalation | Standard Assault with Tower Seekers added | The Tower is a target, and the Tower fights back |
| T3 | First real decision | Split Assault, lightly weighted | You cannot cover both sides |
| T4 | First consequence | Siege, losable if ignored | Neglecting the Tower has a cost |
| — | First reward | Level-Up Draft after the Siege | Investment is a choice |

If the player ignores the Tower during the first Siege, the Tower can be destroyed and the run can end in T4; a player who responds to the warning and closes on the Tower keeps it standing. T4 is tuned so a no-player run loses the Tower before T4 ends in most seeds, while a player who reaches the Tower promptly after the warning keeps it comfortably above half health (see Wave Director & Spawning Logic › Encounter Budgets for the Prototype in docs/11 for the exact tuning target). It is the clearest possible statement of what this game is.

---

## Onboarding Edge Cases

### An experienced player skips the lesson

The teaching waves must be short enough that they do not bore a returning player. They must never be gated behind confirmation prompts.

### A returning player starts a new profile

Onboarding is compressible through a setting, never skippable, and never gated behind a dialog at run start. The setting shortens (halves) the duration and budgets of T1 and T2 for returning players; all four teaching waves always play.

### The player unlocks a powerful meta bonus and then replays the opening

The teaching sequence loses its force. The same compression setting is the only permitted response: it halves T1 and T2, and never removes the Split Assault or the Siege beat, or any other teaching wave.

### A player never triggers a level-up during onboarding

Level-ups are suppressed for the whole of T1–T4: no Level-Up Draft opens during the teaching waves even if accrued XP would otherwise trigger one. During teaching waves shards are still collected, but XP above 14 is discarded, so no level-up fires. The forced first Level-Up Draft when T4 ends grants level 1 at no XP cost, and the XP held counts toward level 2. The first draft must still be guaranteed, not probabilistic, so the investment decision is always introduced.

---

# Boss Structure

Each biome contains exactly two boss-class encounters: a Mini-Boss Checkpoint boss wave after combat wave 4 and a Biome Boss boss wave after combat wave 8 (Provisional Default cadence, stated in Session Shape). A boss wave contains only its boss encounter: it has no maximum duration and no Overtime, and its Boss Definition states which regular spawns it suppresses. Provisional Default duration targets: Mini-Boss 60 seconds, Biome Boss 120 seconds.

Bosses serve as progression checkpoints.

Every boss should introduce unique attack patterns or battlefield mechanics rather than functioning as oversized enemies.

The Biome Boss represents completion of that biome and unlocks access to the next environment.

Bosses always fight in the biome's arena, with the Tower present and at stake. There is no separate boss arena. A boss may temporarily bound a sub-region of the arena, but the sub-region never excludes the Tower.

Every Boss Design Requirement below binds Mini-Bosses in full, the same as Biome Bosses; a Mini-Boss may satisfy them at a smaller scale, for example two short phases instead of three, but may not skip any of them.

---

## Boss Design Requirements

Every boss must satisfy all of the following.

### A signature mechanic

Something the player has not had to handle before in this biome.

### A relationship with the Tower

The boss must either threaten the Tower, be affected by it, or force the player to leave it. A boss that ignores the Tower entirely is a different game's boss.

### Distinct phases

At least two, with a clear visual and audio transition.

### Readable telegraphs at density

Boss attacks must remain visible when regular enemies are also present.

### A losable-but-survivable failure state

A mistake should cost health or position, not the run outright, except in the final phase.

---

## Phase Structure Guidelines

Phase transitions should change the player's job, not just the boss's numbers.

| Phase | Typical Emphasis |
| --- | --- |
| Opening | Teach the signature mechanic in isolation, low added pressure |
| Escalation | Add regular enemy spawns, split the player's attention |
| Desperation | Direct threat to the Tower, force the player to defend rather than attack |

---

## Boss Edge Cases

### Boss dies during a phase transition animation

The transition must be cancellable and rewards must still deliver in full.

### Player dies simultaneously with the boss

Resolution order must be deterministic. The defined behaviour is that the boss death resolves first and the player is credited with the kill. "Credited" means the boss's Core drops and run statistics are granted; the run still ends in failure and no biome clear is awarded.

### Boss is killed before its signature mechanic fires

The reward is still granted. The encounter should not attempt to force the mechanic on a dead boss.

### Boss becomes unreachable

If arena geometry or knockback places the boss outside the playable area, it must be teleported back to a valid anchor rather than left stuck.

### Boss damages the Tower to zero during its own death animation

Run failure takes precedence. The player does not get a posthumous biome clear.

### Player leaves the boss arena

Bosses fight in the biome arena, so "leaving" means leaving any temporary sub-region the boss bounds. The boss must not reset its health. Health resets in a roguelite read as a bug, not a punishment.

### Ongoing damage effects outlive the boss

Hazards created by the boss must be cleaned up on a defined schedule, not left permanently on the field.

---

# Biomes

The game world consists of multiple independent biomes connected through the Tower.

Each biome introduces:

- New environment
- New visual identity
- New enemies
- New bosses
- New environmental hazards
- New gameplay mechanics

Biomes should differ mechanically rather than only visually.

Examples currently considered include:

- Lava
- Ocean
- Frozen Wasteland
- Industrial Factory
- Corrupted Forest
- Underground Caverns

---

## Biome Mechanical Hooks

A biome earns its place by changing how the player evaluates the battlefield. The following are current directional concepts, not final designs. Full designs live in document 15.

| Biome | Mechanical Hook | Positioning Consequence |
| --- | --- | --- |
| Lava | Shifting damage zones on the ground | Safe ground is temporary; orbit paths must constantly change |
| Ocean | Currents that push entities | Movement plans must account for drift, including enemy drift |
| Frozen Wasteland | Reduced traction and slowing effects | Commitment to a direction becomes expensive |
| Industrial Factory | Moving machinery and conveyor terrain | The map itself repositions both sides |
| Corrupted Forest | Vision obstruction and dense cover | Threat reading becomes the primary challenge |
| Underground Caverns | Constricted lanes and chokepoints | Funnelling becomes powerful and being cut off becomes fatal. Flying archetypes are excluded from this biome's pool so chokepoints stay meaningful |

---

## Biome Requirements

Every biome must define the following before it enters production.

- Its hook, in one sentence.
- Its hazard, and the telegraph for that hazard.
- Its enemy pool, expressed in target intents rather than names.
- Its boss pool.
- Its position in the progression order and the difficulty band it occupies.
- Its readability palette, so hazards never blend into the background.

---

## Biome Edge Cases

### The hook interacts badly with a player upgrade

For example, a movement upgrade that ignores traction in the Frozen Wasteland. The biome hook must degrade gracefully rather than becoming irrelevant. Provisional Default: no upgrade may reduce a hook's effect below 40% of its base strength.

### A hazard traps the player against the map boundary

Every hazard must leave at least one traversable path at all times.

### A hazard damages the Tower

Whether biome hazards can damage the Tower must be decided per biome and stated explicitly. Silence on this point is a specification bug. Until a biome document states otherwise, the default rule is that biome hazards do not damage the Tower.

### The player enters a biome with a build that hard-counters the hook

This is acceptable and should feel rewarding. It must not, however, allow the player to skip the biome boss.

### Biome transition with active effects

Buffs, debuffs, hazard trails, and projectiles in flight must be resolved at transition time under an explicit rule, not left to chance.

---

# Progression

The game contains two independent progression systems.

---

## Permanent Progression

Persists between runs.

Includes:

- Skill Tree
- Weapon Unlocks
- Tower Unlocks
- Passive Bonuses
- New Upgrade Pools
- New Biomes

Permanent progression should widen the space of possible runs rather than simply making every run easier. Unlocking a new upgrade pool is a better reward than a flat percentage bonus, because it changes what runs can look like.

---

## Run Progression

Resets every run.

Includes:

- Experience Levels
- Temporary Upgrades
- Weapon Evolutions
- Tower Enhancements
- Temporary Buffs

**Experience (XP)** is a physical pickup called an XP shard, dropped by every standard enemy alongside Scrap (see Drop Table). XP shards obey the same magnet, cap, merge, and blocking rules as every other pickup. XP is not a currency: it has no sink other than the level bar. A run starts at level 0. Provisional Default level curve: advancing from level L to level L+1 costs 10 + 5(L+1) XP — 15, 20, 25 XP for the first three levels — and any XP earned beyond what a level-up consumes carries over as the remainder toward the next level. Each level-up opens one Level-Up Draft; simultaneous level-ups queue their drafts sequentially. During teaching waves shards are still collected, but XP above 14 is discarded, so no level-up fires. The forced first Level-Up Draft when T4 ends grants level 1 at no XP cost, and the XP held counts toward level 2.

This structure encourages replayability while maintaining long-term progression.

---

## The Investment Split

Every run, the player is repeatedly asked the same question in different clothing: invest in myself, or invest in the Tower?

Player investment produces immediate, mobile power that goes wherever the player goes.

Tower investment produces stationary, permanent-for-the-run power that covers the area the player cannot.

Neither should dominate. Dominance is measured, not felt: across at least 10 recorded runs, if either pool — player or Tower — accounts for more than 65% of ranks acquired, it dominates, and the upgrade pools require rebalancing, not a difficulty change.

---

## Progression Edge Cases

### Multiple level-ups trigger simultaneously

Upgrade selections must queue and present sequentially. They must never overwrite each other or be silently dropped.

### The upgrade pool is exhausted

A draft slot guaranteed to an exhausted pool must show a defined fallback rather than an empty selection screen. The fallback rule, including the per-pool fallback cards, is defined in Default Unresolved-State Policies.

### A weapon evolution requires a prerequisite the player no longer has

Evolution requirements must be validated at offer time, not at apply time.

### An upgrade is offered that the player already has at maximum rank

Maxed upgrades must be filtered from the pool before the draft is generated.

### The player levels up during a boss phase transition

The Draft defers until the phase transition animation completes, then opens and fully pauses the simulation. Partial pausing is the worst option and is banned.

### The player levels up at the moment of death

Death resolves first. No posthumous upgrade selection.

### Two upgrades produce an unintended infinite loop

For example, an on-kill effect that spawns something that counts as a kill. Every on-kill and on-hit effect must have recursion protection defined at design time.

### Percentage bonuses to the same stat stack

Percentage bonuses to the same stat add, then apply once: stat = base × (1 + sum of bonuses) (C-STACK).

---

# Resource & Economy System

The economy exists to make decisions cost something. Full design lives in documents 14, 16, and 08.

---

## Currency Definitions & Flow

The game utilizes two distinct currencies with separated flows to prevent menu-fatigue during runs; the overflow hopper is the only bridge between them. Experience is a third dropped pickup but is not a currency; it is defined under Run Progression.

### 1. Run Currency: "Scrap"
- **Source:** Dropped by all standard enemies.
- **Collection:** Pulled by the player's magnet radius.
- **Storage:** Held in the player's run inventory. Subject to a hard cap (Provisional Default 200; shown on the HUD as current over cap at all times).
- **Sinks:** Spent *during the run* at the Tower Console for immediate Player or Tower upgrades and for Tower Repair.
- **Overflow:** When the inventory is at its 200 cap, further Scrap collected does not convert on the spot; it accumulates instead in a separate overflow hopper the player carries (Provisional Default cap 100). The hopper converts to Cores at a reduced rate (Provisional Default 10 Scrap to 1 Core) the moment the player enters the Tower's Interaction Radius, not merely while standing inside it; any remainder under 10 Scrap stays in the hopper unconverted. Once the hopper itself is full, further overflow Scrap is discarded, shown with a "FULL" indicator on the HUD. The overflow hopper is the only bridge between Scrap and Cores. In the prototype, which has no hopper, overflow Scrap is discarded immediately with the same FULL indicator.
- **Failure State:** If the player dies, unspent Scrap in hand and any Scrap still in the overflow hopper are both lost; this reinforces the risk of returning to the Tower to convert the hopper before it is put at risk. Scrap left in hand or in the hopper at run end, on success as well as failure, is discarded rather than settled into Cores.

### 2. Meta Currency: "Cores"
- **Sources (three routes, no others):** (a) field drops from Elites, Mini-Bosses, and Biome Bosses; (b) Scrap overflow conversion as defined above; (c) the Run-End Settlement bonus defined in Factory Mechanics.
- **Collection:** Field drops are pulled by the player's magnet radius. A Core still on the field at the moment of player death banks instantly instead of being lost.
- **Storage:** Automatically and instantly banked to the player's persistent **Meta Wallet** upon collection. No run-inventory cap. Unlike other pickups, a field Core never merges, expires, or gets silently evicted: at the end of its pickup lifetime, or if it would otherwise be evicted to free a slot, it banks instead. "Banked" means written to the save profile; the Meta Wallet updates in memory immediately, with an atomic write to disk at most every 2 seconds while dirty, plus at wave end, run end, and on focus loss — document 24 owns the write cadence, and the default never lets a crash lose more than a few seconds of Cores.
- **Sinks:** Spent in the Hub's Factory for permanent Skill Tree nodes, weapon unlocks, and starting bonuses.
- **Failure State:** Because Cores are instantly banked, a failed run still yields permanent progress.

### Economy Flow Summary

Kill → XP shard (level bar → Level-Up Draft) + Scrap (inventory → Tower Console) [+ Core if Elite or Boss (→ Meta Wallet)]. Scrap at cap → overflow hopper → Cores at a reduced rate on entering the Tower's Interaction Radius. Run end → Run Bonus in Cores. Player death → Scrap in hand and in the hopper lost, Cores already banked kept.

---

## Drop Table

Standard enemy = any enemy spawned from an encounter's spawn groups that is not an Elite, a boss, an Overtime finisher, or a Splitter child; a converted Player Hunter drops as a standard enemy, and an enemy removed by the stuck-despawn rule still places its drops. Splitter children spawned beyond the entity cap become their own drops instead of spawning.

| Kill | XP | Scrap | Cores |
| --- | --- | --- | --- |
| Standard enemy | 1 | 1 | — |
| Elite | 3 | 3 | 1 |
| Mini-Boss | 5 | 5 | 5 |
| Biome Boss | 10 | 10 | 10 |
| Overtime finisher | 1 | — | — |
| Splitter child | — | — | — |

---

## Economy Rules

Every currency must have at least two competing sinks. A currency with one use is a progress bar.

The vertical slice is exempt from this rule for Cores: its single skill node (15 Cores) adds a fourth Tower upgrade to the pool, a single sink. The exemption ends once the full skill tree enters production, at which point Cores need a second competing sink like every other currency.

No sink may be strictly dominated by another sink at any point in progression.

The player must always be able to spend. An economy state where the player has currency and nothing worth buying is a stall. In the prototype, where the pool is six upgrades, the exhausted-pool fallback is the per-pool fallback card defined in Default Unresolved-State Policies. Tower Repair's affordability and pricing follow C-REPAIR (Tower Console UI, docs/19); it is unavailable, not just unaffordable, at full Tower health.

Meta currency must accrue from failed runs, or failure becomes pure loss.

---

## Pickup Physics & Magnet Rules

Resources do not teleport to the player. They must feel physical to reward movement.

- **Magnet Radius:** The player has a base circular pickup radius (Provisional Default 96 pixels). Upgrades can expand this.
- **Attraction:** A pickup becomes attracted when an `EntityRegistry` distance query finds it within the magnet radius; once attracted it stays attracted — sticky — until it is collected or expires, even if the player then moves back out of range. A pickup that has never been attracted does not simulate at all.
- **Acceleration:** An attracted pickup does not move at a constant speed; it starts slow and speeds up, creating a satisfying "snap" into the player. Provisional Defaults: initial 40 pixels per second, acceleration 900 pixels per second squared, maximum 700 pixels per second.
- **Blocking:** Pickups feel physical: they can be blocked by enemy bodies, the Tower, or terrain, so players must physically maneuver to collect drops trapped behind enemy lines. Implementation (Provisional Default, chosen for the performance budget): pickups are non-colliding `Area2D` nodes on the Pickups layer; each simulation tick an attracted pickup casts a ray toward the player with a collision mask of EnemyBody, TowerBody, and World (layers 2, 3, and 4); Logical-Dead enemies never block. If the ray is blocked, the pickup holds its current position while keeping its stored speed, and resumes the instant the ray clears. Document 16 may replace this with true physics bodies if profiling permits.
- **Collection:** A pickup is collected the instant it overlaps the player's `PlayerCollector` area (defined under Player Overview), not the player's body or hurtbox.
- **Merging:** At the pickup cap, the oldest pickup of the incoming drop's type merges into its nearest same-type neighbour within the merge radius (Economy Configuration, default 64 px; 128 px at Fallback Ladder step 1), which keeps its position and lifetime and takes the summed value. If no such pair exists, the oldest pickup of the incoming type expires; if none of that type exists, the oldest XP shard expires, then the oldest Scrap. Cores never merge, expire, or get evicted; a Core that would be evicted or reaches 60 seconds banks instantly.
- **Lifetime:** Every pickup expires after 60 seconds of simulation time (Provisional Default), blinking for the last 5 seconds as a warning. A pickup that cannot be reached within its lifetime simply expires; no orphan remains. Cores are the exception: instead of expiring or being merged or evicted, a field Core banks straight to the Meta Wallet at the end of its 60-second lifetime, or instantly if it would otherwise be evicted — it always resolves to a bank, never a deletion.
- **Unreachable drops:** A drop whose spawn position is inside terrain is placed at the nearest open point; there is no separate "unreachable" state.

---

## Economy Edge Cases

### Currency overflow

Caps must be stated. Overflow behaviour must be stated. Both must be visible to the player before they hit them. The Scrap cap, the overflow hopper's own cap, its conversion into Cores, and the prototype's no-hopper discard rule are all stated in Currency Definitions & Flow; the HUD shows the Scrap cap and, whenever it is non-empty, the hopper amount continuously, not only when either is reached.

### A purchase is made at the exact moment of run failure

Transaction order must be deterministic, and the purchase must either fully complete or fully roll back.

### Refunds and respecs

If respecs exist, their cost and their effect on already-spent resources must be defined before the skill tree is implemented, not after.

### Negative balance through a bug or an upgrade interaction

Balances must be clamped at zero at the system boundary, not corrected downstream.

---

# Factory & Resource Processing

The Factory is the bridge between run-scoped effort and permanent progression. It is a screen in the Hub. Fictionally it is the Tower's processing capability; mechanically nothing in the Factory runs during a run.

## The Hub

The **Hub** is the out-of-run scene. The player enters it after the run-end screen and from the main menu, and launches the next run from it. It contains the Start Run action and the Factory interface. The Tower is also described as the in-run "progression hub" in the fiction; the two uses are distinct and the word Hub, capitalised, always means the out-of-run scene. The prototype has no Hub and boots directly into the arena; the vertical slice has a minimal Hub with one skill node and Start Run. Document 18 owns the Hub scene; document 19 owns its interface.

---

## Factory Mechanics

- **Automatic Processing:** The player does not manually queue anything in the Factory during a run; there are no processing queues while a run is active, and Cores collected in the field are automatically banked. Between-run production in the Factory, and whether it uses queues at all, is document 08's call; the vertical slice ships with none.
- **Run-End Settlement:** A run ends on success, on player death, or on Tower destruction. At that point the game calculates the "Run Bonus" and adds it as a lump sum of Cores to the Meta Wallet before the run-end screen is shown: Provisional Default 5 Cores per biome cleared, 3 Cores per boss killed (Mini-Bosses count), and 1 Core per full minute of simulation time elapsed. Quitting from the pause menu counts as an abandoned run and settles as a failure. If the application crashes, only Cores already banked before the crash are kept; the Run Bonus is never calculated retroactively.
- **Hub Interaction:** In the Hub, the player accesses the Factory UI to spend Cores on the Skill Tree.
- **Visual Feedback:** When a Core is collected during a run, a distinct, high-value audio/visual cue plays, and a UI counter in the corner ticks up, providing constant dopamine and reinforcing the value of killing Elites/Bosses.

---

# Visual Direction & Camera

The game is planned as a 2D minimalist project. "Low-poly" here means the look, not the pipeline: flat-shaded 2D polygon or vector sprites, no texture detail, at most three tones per surface, and one reserved hazard colour per biome. There are no 3D meshes. Document 25 owns the asset pipeline.

Visual clarity is prioritized over realism.

Power progression should be immediately visible through:

- Larger weapons
- Bigger projectiles
- Larger explosions
- Increased particle effects, within the effect density budget
- Tower evolution

Enemy count and damage numbers are not progression signals: enemy count is the Wave Director's escalation, and damage numbers are feedback that sits last in the Readability Hierarchy.

---

## Camera & Viewport Rules

The camera is the player's eye and must never compromise the Readability Hierarchy.

- **Follow & Lead:** The camera follows the player with a lead offset in the direction of movement, Provisional Defaults: lead = velocity × 0.25 seconds, capped at 120 pixels, with the camera's position smoothed toward that target at smoothing speed 8, to provide forward visibility.
- **Dynamic Zoom:** The view scale (defined under Perspective and Arena) rises to 1.15 when the player exceeds 1.5 times base speed or when the Tower loses at least 10% of its combined maximum health and shield within 2 seconds (Provisional Defaults); once triggered it holds for 3 seconds before easing back. It drops to 0.9 only inside an authored boss sub-region or a tight-corridor biome. Otherwise it is 1.0. Every change eases over 0.4 seconds. The prototype implements only the default 1.0 and the Tower-damage 1.15 trigger; the speed trigger and the 0.9 corridor/boss drop belong to the vertical slice. Zoom never affects spawn placement: the Spawn Ring is Tower-centred and independent of camera state.
- **Hard Bounds:** The camera is strictly clamped to the arena bounds. It must never show the "void" outside the playable area. The arena is at least 1.4 times the largest camera view in each axis (4800 by 3200 against a largest view of 2208 by 1242 is 2.2 and 2.6 times) so the clamp is meaningful.
- **Screen Shake:** Screen shake is capped at a maximum pixel offset (Provisional Default 12 pixels) that decays over 0.25 seconds. It is prioritized for Player/Tower damage intake, not enemy deaths. Shake must never obscure incoming telegraphs.
- **Application Order:** Lead and shake are both applied to the camera's position before the arena clamp runs, never through `Camera2D.offset`, so the Hard Bounds above are always measured against the true, final position and the clamp stays meaningful.

---

## Directional Threat Feedback

To satisfy the Three Second Rule, the player must instantly know where the Tower is under attack.

- **Visual:** When the Tower takes shield or health damage, a red directional vignette appears at the screen edge, drawn as 8 discrete edge segments; its intensity follows the damage taken in the last second and it fades over 0.6 seconds. It points toward the Tower when the Tower is off-screen and toward the attacker when the Tower is on-screen. There is no minimap in the prototype or the vertical slice; if one is added later, the Tower's icon pulses red.
- **Audio:** Tower damage audio plays on its own `AudioStreamPlayer` routed through a dedicated `TowerCue` bus with an `AudioEffectPanner` set by the Tower's bearing from the player, so it always reads regardless of distance (full bus routing and panner formula: C-TOWERCUE, Audio Mixing, docs/20). It uses a distinct, low-frequency sound that cuts through combat noise and is limited to retriggering at most once every 250 milliseconds.
- **Off-screen Indicator:** If the Tower is off-screen, a persistent, subtle UI indicator (like a compass pip or arrow) points toward it. Below 40% Tower health, the indicator changes both shape and colour and additionally shows a short arc on the side of the Tower currently being hit.

---

## Readability Hierarchy

When the screen is full, elements must be legible in this priority order. Anything lower may be reduced, faded, or culled to protect anything higher.

1. Player character position
2. Incoming damage telegraphs
3. Tower health state
4. Enemy positions and types
5. Pickups and drops
6. Player projectiles and effects
7. Ambient environment detail
8. Damage numbers

Damage numbers are last on purpose. They are feedback, not information.

Degradation runs from the bottom of this hierarchy upward: elements are reduced, faded, or culled starting at rank 8 and moving up only as far as needed, triggered automatically whenever more than 24 high-intensity visual effects are on screen at once, or whenever 1st-percentile FPS drops below 45. The concrete render order that implements this hierarchy (`z_index` per layer) is defined under Godot 4.x Implementation Standards.

---

## Visual Edge Cases

### Effect density hides an enemy

Player-owned effects must be reducible in intensity through an accessibility setting without changing gameplay.

### The player is fully obscured by enemies

The player silhouette must render above enemy bodies at all times.

### Hazards blend into biome background

Every hazard requires a colour that is reserved and not used for decoration in that biome.

### Colour-only distinctions

No gameplay-critical information may be conveyed through colour alone. Shape and motion must carry it as well.

---

# UI/UX & Input Rules

The interface must support the core tension without adding cognitive load.

---

The interface specifications for the Level-Up Draft, the Tower Console, the HUD, the input map, and dynamic container rules live in `docs/19_UI_UX.md`, a working system document that is binding for the prototype under the Provisional Defaults Policy. The gameplay rules for both upgrade channels stay in Tower Overview and Player Overview.


---

# Technical Direction

The project is being developed using Godot Engine.

The codebase should remain modular from the beginning.

Major gameplay systems should remain isolated with clearly defined responsibilities to simplify future expansion.

---

The Godot 4.x implementation standards (project settings, events, queries and commands, the collision layer table, scene tree and draw order), audio mixing, debugging and telemetry, and animation, hitbox, and state cleanup rules live in `docs/20_Technical_Architecture.md`, a working system document that is binding for the prototype under the Provisional Defaults Policy.


---

## Architectural Rules

These rules exist so that adding a biome, an enemy, or an upgrade late in development does not require touching unrelated systems.

### One system, one responsibility

If a file needs the word "and" to describe what it does, it is two files.

### Communicate through signals and interfaces, not direct references

A system may announce what happened (signal), may answer read-only questions (query interface), or may issue a typed command on another system's public interface (Communication, commands) that the owner validates and may refuse. It may not reach into another system to make something happen by writing its fields directly.

### No cross-system state ownership

Exactly one system owns each piece of state. Everything else reads a copy or asks.

### Data over code for content

Enemies, waves, upgrades, and biomes should be data definitions consumed by generic systems, not bespoke scripts.

### Determinism where it matters

Godot's physics engine uses floating point and is not deterministic across platforms; the project does not pretend otherwise and does not require physics determinism. What must be deterministic is **resolution order** and **randomness**:

- A `SimLoop` node drives gameplay once per physics tick; entities do not run their own gameplay `_physics_process`. `Area2D` overlap callbacks never resolve damage directly — they only enqueue a hit record (attacker, target, amount, source) onto a hit queue for `SimLoop` to process in order.
- SimLoop's fixed fifteen-step per-tick resolution order (input, player movement, enemy AI, weapon targeting and firing, projectile movement, wind-up and contact ticks, the hit queue, death resolution, drops, pickups, XP and level-ups, Console purchase completion, Wave Director, pause flush, UI state) is defined in Godot 4.x Implementation Standards (docs/20, C-SIMLOOP); this document defers to it rather than restating it. When the player and the Tower both reach zero on the same tick, the cause is recorded as the Tower because it resolves first in that order; when a boss and the player both reach zero on the same tick, the boss kill is credited but the run still fails.
- `PauseAuthority` is the sole writer of `get_tree().paused` and applies any pending pause or unpause request only at the end of the tick, never mid-resolution, so a pause can never interrupt the fixed order above partway through.
- Every system that rolls (drops, drafts, spawn positions, affixes) derives its `RandomNumberGenerator` seed by hashing the run seed with a fixed per-purpose key and, where relevant, a per-roll identifier, rather than sharing one stream — for example the Level-Up Draft's k-th card hashes `[run_seed, "draft", k]`, a drop hashes `[run_seed, "drop", spawn_serial]`, and a spawn position hashes `[run_seed, "spawn", spawn_serial]`. The run seed is generated at run start and written to the Run Recorder header, so a run can be replayed for the same rolls even though physics may drift.

---

## Performance Budget

The swarm encounters define the ceiling. The budget must be set early and enforced, not discovered late.

- A hard maximum active enemy count, enforced by the spawner rather than by hope.
- A hard maximum active pickup count, with merging behaviour above it.
- A hard maximum active projectile count, with oldest-first recycling.
- Object pooling for enemies, projectiles, pickups, and effects from the first prototype onward.
- Off-screen enemies may reduce update frequency but must never freeze, or waves stop resolving. Provisional Default: an enemy whose offset from the camera centre exceeds 1.5× the camera's view half-extent on either axis moves only every 3rd physics tick, multiplying its velocity by 3 for that call so its average speed is unchanged, staggered by `spawn_serial % 3` so reduced enemies do not all update on the same tick; this reduction never applies within two Interaction Radii (320 px) of the Tower, so a Siege always resolves at full rate.

The Performance Fallback Ladder and the Interim Prototype Technical Budgets (caps, the performance rule, and the reference machine) live in `docs/20_Technical_Architecture.md`. Every cap and performance value is also listed in the Provisional Values Register.


---

## Technical Edge Cases

### Frame rate drops during a swarm

Behaviour must degrade visual fidelity before it degrades simulation. A dropped frame is acceptable; a dropped hit registration is not.

### The game is paused mid-projectile

All timers, hazards, and effects must respect a single global pause authority. Anything using its own timing source is a bug waiting to happen.

### The window loses focus

The game auto-pauses on `NOTIFICATION_APPLICATION_FOCUS_OUT` and never auto-resumes; regaining focus shows the pause menu. Debug builds accept a `--no-focus-pause` command-line flag so an automated test or a debugger break does not trigger this pause. Silence here produces a class of "I died in the alt-tab" reports.

### Save occurs during a state transition

Saves must be atomic. A partial write must never be loadable.

### A save file from an older version is loaded

Version migration must be planned before the first save format is written, not after the first breaking change.

### The player closes the game mid-run

Runs are not resumable by default. If they are not, the meta progression earned so far must still have been committed.

---

# Global Simulation Authority

The game must have one authoritative simulation clock and one authoritative pause state.

**Simulation time** is owned by a `SimClock` Autoload running `PROCESS_MODE_PAUSABLE`. Each unpaused physics tick it accumulates `now += physics_step × SimClock.time_scale` (physics_step is 1/60 second at the pinned 60 Hz physics rate). Every gameplay deadline is a simulation-time value compared against `SimClock.now`, not a running countdown. `Timer` nodes, `SceneTree.create_timer()`, and `SceneTree.create_tween()` never drive gameplay, because none of them scale with `SimClock.time_scale` or reliably pause with the gameplay tree; `Node.create_tween()` is permitted for cosmetic animation only, since a tween bound to a paused node pauses with it. All of these remain permitted in pure UI, which is not bound by `SimClock`.

**Pause** is owned by a `PauseAuthority` Autoload (`PROCESS_MODE_ALWAYS`), the only writer of `get_tree().paused`. It holds a set of pause reasons (draft, pause menu, focus loss, controller disconnect, debug) and unpauses only when the set is empty; it applies every pending pause or unpause request at the end of the current tick, never mid-resolution (Determinism where it matters). The gameplay root is `PROCESS_MODE_PAUSABLE`. Autoload process modes are not uniform: `SimClock`, `EntityRegistry`, and `CombatStats` are `PROCESS_MODE_PAUSABLE`, so they stop with the simulation; `PauseAuthority`, `EventBus`, the UI `CanvasLayer`, the ducking node (Audio Mixing & Dynamic Ducking), and the UI sound players are `PROCESS_MODE_ALWAYS`, so they keep functioning while paused. Nothing under the gameplay root may set `PROCESS_MODE_ALWAYS`. SFX buses pause with the tree; music continues.

The Tower Console is the one exception to pausing: it is a real-time, world-space interface by design (Tower Console UI), so it never adds a pause reason and is never itself frozen by another reason's effect on the tree — instead it manually hides itself and stops accepting input whenever `PauseAuthority`'s reason set is non-empty, and its own 0.5 second purchase-channel timers run on `SimClock` like every other gameplay deadline. HUD tooltips do not pause either.

**Game-feel time effects** (hit stop, slow motion, the revive zoom-in) are applied only through `SimClock.time_scale`, never through `Engine.time_scale`, and never stop damage resolution. Hit stop is a visual-only effect (`AnimationPlayer.speed_scale`, sprite effects) capped at 120 milliseconds. Slow motion drops `SimClock.time_scale` to no lower than 0.25 for at most 120 milliseconds of real time; because `move_and_slide` integrates with the fixed physics step, gameplay code applies the scale itself — movers multiply their velocity by `SimClock.time_scale` before moving, and every gameplay deadline advances by the physics step multiplied by `SimClock.time_scale`. The revive zoom-in is a camera effect only and does not touch `time_scale`. In the prototype `time_scale` is always 1.0; the rule exists so later effects cannot bypass it. This is how "the simulation does not partially pause" and document 27's hit stop coexist.

No gameplay system may use its own independent timing source for combat, spawning, hazards, telegraphs, pickups, upgrade timers, blackout timers, or encounter progression.

---

## Pause Rules

The simulation fully pauses during:

- Pause menu.
- Level-Up Draft.
- Window focus loss (`NOTIFICATION_APPLICATION_FOCUS_OUT`; never auto-resumes on its own; debug builds accept `--no-focus-pause`).
- Controller disconnect: in the prototype this opens the pause menu like any other pause reason; the vertical slice replaces this with a dedicated reconnect prompt.
- Any blocking system menu: the pause menu, settings, and the controller-reconnect prompt.
- Any debug inspector that alters gameplay state, if used in a playtest build.

The simulation does **not** pause during the **Tower Console**. The Console is a real-time, world-space interface by design (see Tower Interaction Mechanics); it is the vulnerability window, and pausing it would delete the core tension. HUD tooltips also do not pause.

The simulation does not partially pause. There is no state where enemies freeze but hazards continue, or where pickups continue but projectiles freeze. Every pause and unpause request is applied by `PauseAuthority` at the end of the tick it was requested on, never mid-tick.

---

## Timing Rules

All gameplay timers must use simulation time, not wall-clock time.

This includes:

- Wave timers.
- Encounter recovery gaps.
- Telegraph durations.
- Shield regeneration delays.
- Blackout countdowns.
- Overtime triggers.
- Pickup lifetimes.
- Status effect durations.
- Spawn cooldowns.
- Boss phase transition delays.

---

## Level-Up Draft Rule

When the Level-Up Draft is opened:

1. The simulation pauses completely.
2. All active telegraphs freeze.
3. All enemies freeze.
4. All projectiles freeze.
5. All pickups freeze.
6. All hazards freeze.
7. The draft queue is processed sequentially if multiple level-ups occurred.
8. No encounter opens and no spawn group starts until 1.5 seconds of simulation time after the draft closes; existing enemies resume immediately when the draft closes. Only Wave Director deadlines extend by that grace period — every other gameplay deadline runs normally (C-GRACE; Pacing & Escalation Algorithm, docs/11).

Partial pausing is banned.

---

## Focus Loss Rule

If the game window loses focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`), the game automatically pauses and never auto-resumes on its own; regaining focus shows the pause menu, and debug builds may pass `--no-focus-pause` to disable this for testing.

If the player is using a controller and the controller disconnects, the prototype opens the pause menu exactly as any other pause reason would; the vertical slice instead prompts for reconnection without leaving the run.

---

## Biome Transition Rule

A biome transition is not merely visual. It is a committed state change.

Before a biome transition commits, the following must occur:

- Active player and Tower state is validated.
- Field pickups are auto-collected.
- Projectiles are resolved or removed.
- Hazards are cleared.
- Active encounter state is closed.
- Run progression resources are committed.
- Temporary effects that are not allowed to persist are removed.

What persists across the transition: XP level and XP, owned upgrade ranks, weapons, Scrap and the overflow hopper, and both pools' current health; the Tower's shield fully refills in the new biome; Tower drones despawn unless explicitly flagged persistent. If the resource auto-collect above grants a level-up, the resulting Level-Up Draft is queued and opens after the new arena has loaded, before its first wave.

The transition commits on the tick the Biome Boss's Logical Death resolves with both pools above zero and no Draft pending. If a run failure occurs before that tick, run failure takes precedence. Once the transition has committed, the new biome begins and the previous biome is considered closed.

---

# Wave Director & Spawning Logic

The Wave Director is the brain of the pacing. It does not just spawn enemies; it manages the pressure curve. Full design lives in document 11.

---

The Wave Runtime Model, the Encounter Budgets for the Prototype, Spawn Rings & Placement, Directional Weighting, and the Pacing & Escalation Algorithm live in `docs/11_Wave_Director.md`, a working system document that is binding for the prototype under the Provisional Defaults Policy. Every other section of this document defers to that file for wave and encounter timing.


---

# Edge Cases and Failure States

This section is the project's register of known hard cases. It exists because in this genre, most defects are not broken features but unhandled interactions between working features.

Every entry here must be either handled in code or explicitly accepted in the owning system document. An entry may not be silently ignored.

---

## Run Termination

| Case | Required Behaviour |
| --- | --- |
| Player and Tower reach zero on the same frame | Deterministic order from the Determinism rule: the Tower's depletion resolves first. Run ends, cause recorded as Tower |
| Tower reaches zero while the player is mid-transition to a new biome | Transition takes precedence only if it has already committed; otherwise run failure |
| Player dies while a revive effect is available | Revive resolves before death is committed, once per source. A 2 second invulnerability flag is set on Health (the hurtbox stays enabled so pickups still collect) plus a camera zoom-in to reorient (a camera effect only) |
| Run ends while the Level-Up Draft or Tower Console is open | The interface closes without applying any pending choice; a Console purchase already confirmed on an earlier tick stands; run failure resolves |
| Run ends with unsaved meta progression | Meta progression commits before the failure screen is shown |

---

## Player State

| Case | Required Behaviour |
| --- | --- |
| Player is stunned or rooted during a Siege | The encounter must not be able to chain-lock the player indefinitely; diminishing returns required. Provisional Default: each subsequent stun within 5 seconds lasts 50% of the previous, floor 0.1 seconds, and the third grants 2 seconds of stun immunity |
| Player is pushed outside the playable area | Clamp to boundary, never allow out-of-bounds |
| Player has zero weapons through an upgrade interaction | A fallback weapon must always exist |
| Player movement speed reaches a value that breaks collision | Speed must be capped below the tunnelling threshold. The realistic tunnelling risk is fast projectiles against thin hurtboxes, which the Godot standards cap separately |
| Player and Tower occupy the same position | Collision must not launch the player; the Tower must have a stable footprint |

---

## Enemy Behaviour

| Case | Required Behaviour |
| --- | --- |
| Enemy cannot path to its target | Fall back to a secondary target after 3 seconds, then to direct approach, then despawn with drops after 20 seconds (Intent Behaviour Defaults) |
| Enemy spawns inside geometry | Spawn point validation is defined in Spawn Rings & Placement (Wave Director & Spawning Logic); an invalid point is shifted along its ring and, failing that, re-queued for the next tick — never forced |
| Enemy is knocked out of the arena | Return to a valid position rather than despawning silently mid-wave |
| Splitter enemy dies at the entity cap | Children spawn up to the cap; any children beyond the cap are not spawned at all — they become their own drops directly, rather than being lost silently |
| All enemies die but the wave does not end | Wave and encounter completion is driven by EntityRegistry tag queries against live entities (Wave Runtime Model), never by a counter that can desynchronise from them |
| Enemy is alive but permanently stuck | Stuck timers run only while the enemy is outside attack or contact reach of its target and is not simply being held back by other enemies already attacking that target; a queued enemy moves to the nearest free slot rather than counting as stuck. 3 seconds without path progress (distance to target shrinking by less than 8 px) falls back to a secondary target or direct approach; 8 seconds under 8 px of displacement forces direct approach; 20 seconds forces a despawn with drops placed, counted as removed rather than a kill |

---

## Wave and Encounter Flow

| Case | Required Behaviour |
| --- | --- |
| Player clears a wave instantly | Enforce a minimum inter-wave gap so pacing survives strong builds |
| Player cannot clear a wave at all | Overtime escalation triggers; waves never stack unbounded |
| Two encounters trigger on the same frame | Priority order defined per encounter definition (integer 0 to 100, higher wins, ties by ID). When an encounter completes, no encounter opens until that encounter's recovery gap has elapsed. When two encounters are due at the same moment, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap (C-DEFER). Prototype order: Siege, Split Assault, Hunt, Standard Assault |
| An encounter's win condition becomes impossible | The encounter self-resolves with a partial reward: half of its reward rounded down (an encounter with no reward grants nothing); progress is never blocked (C-PARTIAL) |
| Player is inside the Level-Up Draft when an encounter is scheduled | Encounter defers until the Draft closes plus the 1.5 second grace period. The Tower Console never defers encounters, because it does not pause |

---

## Combat Resolution

| Case | Required Behaviour |
| --- | --- |
| Damage is dealt by an entity that dies in the same frame | Damage still applies; source is resolved by value, not by reference |
| Two effects apply the same status simultaneously | Stacking rules defined per status: refresh, stack, or ignore. No undefined statuses |
| Damage over time outlives its source | Continues to a defined duration and then cleans up |
| Healing exceeds maximum health | Clamped; overheal either converts to shield or is discarded, stated explicitly |
| Critical hit interacts with a percentage-of-max-health effect | Percentage-of-max-health damage is never multiplied by critical hits, and is capped at 20% of maximum health per hit |

---

## Tower Specific

| Case | Required Behaviour |
| --- | --- |
| Tower has no valid target but has upgrades that require firing | Idle behaviour per the Tower Targeting Rule: hold fire, consume nothing, cooldowns keep ticking; no error state |
| Tower shield breaks and regenerates in the same interval | The 8 second regeneration delay restarts on every hit that lands on the shield, including the hit that breaks it — not only on the first hit of the interval |
| Tower upgrade is purchased at the instant the Tower takes fatal damage | Purchase resolves or rolls back atomically |
| Tower drones outlive the biome | Drones persist or despawn under an explicit stated rule at transition |
| Tower is fully upgraded with resources still incoming | Scrap accumulates to its 200 cap, then overflows into the overflow hopper (cap 100), which converts to Cores at 10:1 when the player enters the Tower Interaction Radius; the prototype has no hopper, so overflow is discarded immediately with a FULL indicator. Tower Repair remains purchasable regardless |

---

## Save and Persistence

| Case | Required Behaviour |
| --- | --- |
| Corrupted save file | Detect, back up the corrupt file, and fall back to a last-known-good copy rather than resetting the player |
| Two profiles written concurrently | Single-writer enforcement |
| Save schema changes between versions | Migration path per version, with a documented migration chain |
| Disk full or write permission denied | Fail loudly and visibly. Never let the player finish a run believing progress was saved when it was not |
| Cloud save conflict, if cloud save is added later | Present the choice to the player rather than resolving silently |

---

## Input and Accessibility

| Case | Required Behaviour |
| --- | --- |
| Controller disconnects mid-run | Auto-pause and prompt |
| Input device changes mid-run | UI prompts update immediately to match the active device |
| Player uses only movement input for a full run | The run must be completable. Every other input is optional |
| High effect density for photosensitive players | Reduced-effects setting must exist and must not alter gameplay outcomes |

---

## Interaction Between Systems

These are the highest-risk cases, because no single system owns them.

- A movement upgrade defeats a biome hook. Ownership is shared between documents 03 and 15. Resolution must be recorded in both.
- An upgrade that spawns entities interacts with the entity cap. Ownership is shared between documents 17 and 11.
- An on-kill effect interacts with splitter enemies. Ownership is shared between documents 17 and 09.
- A Tower area weapon collects or destroys resource drops. Ownership is shared between documents 07 and 16.
- A blackout event disables the system the player's build depends on entirely. Ownership is shared between documents 11 and 17. Blackouts must never fully disable a build.
- Overtime finishers interact with the entity cap: during Overtime no further spawn groups start, and finishers count against the 300 enemy cap and throttle like any other spawn — the cap is never exceeded (C-OVERTIME-CAP). Ownership is shared between the Wave Director (document 11) and the Performance Budget in this document.
- Carried-over survivors interact with wave budgets: an enemy that survives past its wave's maximum duration counts against the entity cap in the next wave but never against that wave's own spawn budget. Ownership is shared between the Wave Director (document 11) and the Performance Budget in this document.
- The Tower Console interacts with the Level-Up Draft and with pause: a Draft opening while the Console is open closes the Console immediately, and the Draft then pauses as normal; the Console itself never pauses the simulation and never defers a scheduled encounter. Ownership is shared between the Tower Console UI and the Upgrade Draft UI & Navigation.

Any newly discovered cross-system case must be added to this list before the fix is written, so the fix is designed rather than patched.

---

# Default Unresolved-State Policies

Until a system document provides a final rule, the following default policies are binding.

These defaults exist to prevent implementation ambiguity.

| Unresolved Question | Default Rule |
| --- | --- |
| Are runs resumable? | No. A run is not resumable after the application closes. Meta progression must still commit. |
| What happens to uncollected field resources on player death? | Run resources (Scrap, including anything already in the overflow hopper) are lost. Cores are field drops only; any Core still on the field at the moment of death banks instantly to the Meta Wallet, the same as a Core already collected — Cores never merely persist, they bank. |
| What happens to field resources during biome transition? | Field resources are auto-collected before transition commits. |
| Can biome hazards damage the Tower? | No, unless the owning biome document explicitly says yes. Silence means no. |
| Do Tower drones persist across biomes? | No, unless explicitly flagged as persistent by the owning Tower upgrade or factory system. |
| What happens to overheal? | Overheal is discarded unless a specific upgrade explicitly converts it into shield. |
| How do statuses stack by default? | Same-status applications refresh duration by default. Stacking is only allowed if explicitly defined. |
| What happens when storage is full? | Scrap fills to its 200 cap and then overflows into the overflow hopper (cap 100); the hopper converts to Cores at 10:1 the moment the player enters the Tower Interaction Radius, and any remainder under 10 Scrap stays in the hopper. Scrap that would overflow a full hopper is discarded. The prototype has no hopper: overflow Scrap is discarded immediately with a FULL indicator — visibly, never silently. |
| What happens if an upgrade pool is exhausted? | A draft slot that must guarantee a card from an exhausted pool shows that pool's fallback card instead — Overdrive (+10% weapon damage) or Reinforce (+10% Tower damage). The same fallback cards also appear at the Console for 90 Scrap once that pool is exhausted, so Scrap always has a sink (C-FALLBACK-CONSOLE). Fallback cards have no maximum rank and add 0 evolution ranks. |
| What happens if a player has no weapon? | A fallback weapon must always be granted. The player must never have zero functional weapons. |
| What happens if an enemy cannot path? | The enemy falls back to a secondary target, then direct approach, then despawns after a timeout if still invalid. |
| What happens if a wave cannot be cleared? | At a wave's maximum duration, Overtime triggers only if recent kills are also below the stall threshold — both the duration elapsing and progress being measurably too low are required, not elapsed time alone (C-STALL; Author decision A7, 2026-09-14). |
| What happens if a purchase occurs during run failure? | The transaction must atomically complete or fully roll back. |
| What happens if the player dies at the same time as a boss? | Boss death resolves first, then player death. The player is credited with the kill. |
| What happens if a blackout disables a system the build depends on? | The blackout may weaken the build but must never fully disable its core function. |
| Does the Tower Console pause the simulation? | No. It is a real-time world-space interface. Only the Level-Up Draft and blocking system menus pause. |
| Which upgrades come from which channel? | Both channels may offer player and Tower upgrades. The Draft is free and random with at least one of each; the Console is priced and deterministic. Ranks are shared. |
| Does the player's health regenerate? | No. Only upgrade cards or pickups restore it. |
| Does the Tower's health regenerate? | No. Only Tower Repair at the Console restores it, and only when affordable per C-REPAIR (docs/19) — at 0 Scrap Repair is greyed and does not count toward opening the Console. The base Tower shield regenerates after an 8 second delay. |
| How does contact damage work? | Once per 0.5 second tick per overlapping enemy with a Contact Damage attack (for example the Player Hunter, 8 damage per tick), no knockback, no global invulnerability frames; the contact hitbox radius is the enemy's body radius plus 6 px. |
| How long is the post-draft grace period? | 1.5 seconds of simulation time. |
| How many rerolls exist? | One per run in the prototype; one per draft in the slice. Banish is not in the prototype. |
| What is the encounter priority order? | Siege 80 (10 s recovery gap), Split Assault 60 (8 s), Hunt 40 (8 s), Standard Assault 20 (5 s) in the prototype. When an encounter completes, no encounter opens until that encounter's recovery gap has elapsed. When two encounters are due at the same moment, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap (C-DEFER). Document 11 owns the full order. |
| When is the health quadrant "Low"? | Below 40% of maximum health for either pool; shield is excluded from the calculation. |
| How big is the arena? | 4800 by 3200 pixels (wider than tall), Tower at centre, hard walls on the ArenaBounds layer, no interior obstacles in the prototype. |
| Where do bosses fight? | In the biome arena, with the Tower present. Never in a separate arena. |
| What does "encounter failure" cost? | The encounter's reward is forfeited; nothing else. The run continues. |
| What is the Hub? | The out-of-run scene with Start Run and the Factory. Not in the prototype. |
| What does a movement-only player do at a menu? | In any paused menu, hold up toward the highlighted choice for 1.0 second to confirm it. At the Tower Console, with the default-off Movement-only controls setting enabled from a run-end or settings menu, standing still below 10% base speed for 1.0 second inside an entry's sector around the Tower buys that rank. |
| What happens to survivors when a wave's maximum duration elapses? | If the wave is not stalled, it ends and its survivors carry over into the next wave, counting against the global entity cap but never against the next wave's own spawn budget; the next wave still emits its first spawn group on schedule. If the wave is stalled (fewer than 5 non-finisher kills in the last 30 seconds), Overtime triggers instead. |
| What counts as a "standard" enemy? | Any enemy spawned from an encounter's spawn groups that is not an elite, a boss, an Overtime finisher, or a Splitter child. |
| What persists across a biome transition? | XP level and XP, owned upgrade ranks, weapons, Scrap and the overflow hopper, and both pools' current health; the Tower's shield fully refills; Tower drones despawn unless explicitly flagged persistent. |
| What happens to level-ups earned from the transition's resource auto-collect? | They queue Level-Up Drafts that open after the new arena has loaded, before its first wave. |
| What happens if a Level-Up Draft opens while the Tower Console is open? | The Console closes immediately, then the Draft pauses the simulation as normal; the Console does not reopen on its own afterward — the player must leave and re-enter the Interaction Radius to open it again. |
| Does the health quadrant affect encounter or spawn selection? | Not in the prototype or the vertical slice. The Wave Director records the quadrant at every escalation decision but does not act on it; the earlier rule tying spawn selection to a low pool's condition is withdrawn without a replacement. Document 11 may define quadrant-aware selection later as an open question. |
| What happens at the pickup cap? | The oldest pickup of the incoming drop's type merges into its nearest same-type neighbour, or expires per the merge order, in Pickup Physics & Magnet Rules (C-MERGE); Cores are exempt. |
| What is an encounter's partial reward when it self-resolves? | Half of its reward rounded down; an encounter with no reward grants nothing (C-PARTIAL, Wave and Encounter Flow). |
| Can Overtime finishers exceed the enemy cap? | No. Finishers count against the 300 enemy cap and throttle like any other spawn; the cap is never exceeded (C-OVERTIME-CAP, Interaction Between Systems). |
| Where is the input map defined? | docs/19 › Input Map, C-INPUT: movement, Draft, Console, Pause, and their keyboard/mouse/gamepad bindings. |

If a system document changes one of these defaults, it must state the override explicitly. If the change affects project intent, the master document must also be updated.

---

# Risk Register

Known risks to the project, with the mitigation each one requires. Reviewed at every milestone.

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Scope expansion across biomes and systems | Project never reaches vertical slice | Biome count is fixed at the vertical slice; new biomes go to document 30 |
| Performance ceiling during swarm encounters | Late-run unplayability | Entity caps and pooling enforced from the first prototype |
| Tower becomes irrelevant to moment-to-moment play | Game collapses into standard horde survival | At least one Siege and one Split Assault per biome (Encounter Composition Rules); every combat wave after T1 contains at least one Tower Seeker or Opportunist; Hunter leash converts ignored Hunters into Tower pressure |
| Upgrade pool produces a dominant build | Runs become solved | Pool audit before every content milestone |
| Grappling hook consumes prototype time without shipping | Schedule loss | Hard evaluation gate defined in the Player Overview |
| Documentation drifts from implementation | Docs become untrustworthy and get ignored | Every system change updates its document in the same commit |
| Readability degrades as content is added | The core loop becomes unplayable at depth | Readability hierarchy enforced at every art review |
| Audio becomes an unreadable wall of noise | Players miss critical telegraphs | Strict Audio Bus hierarchy and dynamic ducking enforced |
| UI breaks during localization or scaling | Players cannot read upgrades | Dynamic containers and pseudo-localization testing enforced |
| Pressure Metric oscillates (escalate / de-escalate flapping) | Pacing feels random; safe-corner ban silently broken | Bounded de-escalation, minimum 4 s between injections, throttle expiry, telemetry of pressure samples reviewed every playtest |
| Per-node physics cost of 300 CharacterBody2D enemies exceeds budget | Swarm encounters unplayable; caps cut late | Swarm stress test is the last Phase 1 task (P1.7); Performance Fallback Ladder pre-agreed |
| Godot pause traps (SceneTreeTimer, Tween, PROCESS_MODE_ALWAYS leakage) | Partial pause bugs that the design bans | SimClock and PauseAuthority Autoloads are the only timing and pause writers; banned APIs listed in Global Simulation Authority |
| Two upgrade channels confuse players | Investment Split not understood | Draft and Console differ in every operational respect and are visually differentiated; slice pass criterion 2 tests it |
| No version control at project start | Docs and code drift from day one; "same commit" rule unenforceable | Phase 0 initialises the repository before any code exists |
| Godot MCP servers drift from the pinned engine version | AI-driven scene, script, and settings edits behave differently than the pinned 4.7.1 engine expects, or silently stop working | Document 28 pins both Godot MCP servers' versions alongside the engine version (task P0.5); destructive or outward-facing MCP operations require the designer's confirmation in the main session, but that gate does not intercept delegated subagents (Phase 00 finding F-06), so the five most dangerous tools are denied outright and the rest are constrained by instruction |
| NavigationServer2D pathfinding resolves asynchronously | Breaks the fixed per-tick resolution order the Determinism rule promises, since a navigation query can resolve on a different tick than it was issued | The prototype uses no NavigationAgent2D; if later biomes add obstacles, navigation results are applied inside SimLoop |
| Pressure Metric thresholds and weights are unvalidated Provisional Defaults | Escalation or de-escalation fires at the wrong moments, and pacing reads as random rather than responsive | Pressure test (P2.9) validates the formula in isolation before content depends on it; Run Recorder pressure samples are reviewed every playtest before the constants are treated as final |

---

# Documentation Structure

The complete documentation repository consists of the following design documents.

Each entry below lists what the document is responsible for and, where relevant, the edge cases it owns from the register above.

Documents 09, 11, 19, 20, and 29 exist as drafts in `docs/`, holding sections moved from this file, with ledger FIX edits applied, per the file map recorded in the Review Decision Log; each is version below 0.5.0 and not yet a working document (see Document Control) until it is brought to stable.

---

## 00 - Vision & Design Philosophy

Defines the long-term vision, player fantasy, design principles, emotional goals, and project identity.

Answers: what is this game trying to make the player feel, and what will it never be?

---

## 01 - Design Pillars

Lists the non-negotiable principles that guide every design decision.

Answers: when two good ideas conflict, which one wins?

---

## 02 - Gameplay Loop

Complete gameplay flow from starting a run through biome completion.

Answers: what exactly happens between pressing start and the run ending, at all four loop scales?

Owns: the Structure Hierarchy (Run ⊃ Biome ⊃ Wave ⊃ Encounter), the Run Termination edge cases, the onboarding edge cases, boss cadence and biomes per run, a summary of boss wave placement within the loop (the detailed spawn-suppression and budget rules are owned by document 11), and the encounter failure resolution default.

---

## 03 - Player Controller Specification

Movement, input mapping, player states, health system, interaction systems, movement upgrades, and controller architecture.

Owns: player state edge cases, player stats, input and accessibility edge cases except the reduced-effects setting (owned by document 27), movement speed caps, and input buffering rules.

---

## 04 - Grappling System

Prototype design, movement physics, controls, rope mechanics, edge cases, upgrade paths, and evaluation criteria.

Owns: the go or no-go decision against the four evaluation criteria, and the interaction between traversal and biome hooks.

---

## 05 - Combat System

Combat architecture, auto-targeting, attack timing, damage calculation, critical hits, hit reactions, status effects, and combat flow.

Owns: all combat resolution edge cases except the contact tick (owned by document 09), status stacking rules, damage-source lifetime rules, and animation/hitbox cleanup rules.

---

## 06 - Weapon Framework

Weapon classes, evolutions, rarity, balancing, projectile behavior, upgrade interactions, and future weapon expansion.

Owns: evolution prerequisite validation, the fallback weapon guarantee, and projectile recycling behaviour when the projectile cap is hit (the cap number itself is owned by document 20).

---

## 07 - Tower System

Tower behavior, health, automated weapons, upgrades, visual evolution, support systems, and interaction with player systems.

Owns: all Tower-specific edge cases, the Tower Targeting Rule, shield regeneration timing, Tower Repair and its price, drone persistence across biomes, Tower Interaction Radius rules, the Tower Console mechanics, and the evolution stage thresholds.

---

## 08 - Factory System

Resource processing, upgrade production, conversion mechanics, progression integration, and economy interaction.

Owns: the overflow hopper conversion rate, run-end settlement logic, between-run production and any queues (none run during a run; the vertical slice defines none), and behaviour when production outpaces demand.

---

## 09 - Enemy AI Architecture

Enemy categories, behaviors, targeting priorities, movement systems, elite enemies, and AI state machines. Spawning logic belongs wholly to document 11.

Owns: all enemy behaviour edge cases, target intent definitions, the Intent Behaviour Defaults (body-block, leash, Opportunist events, stuck rules, telegraph minimums), pathing fallbacks, stuck detection, contact behaviour and the contact tick, and splitter behaviour at the entity cap.

---

## 10 - Boss Design

Boss philosophy, encounter structure, phases, abilities, arena mechanics, progression scaling, and balancing.

Owns: all boss edge cases, phase transition cancellation, and arena boundary behaviour.

---

## 11 - Wave Director

Enemy spawning, wave progression, pacing, difficulty escalation, special events, and encounter generation.

Owns: the encounter taxonomy in implementation form, composition rules, the wave runtime model, boss wave placement, encounter budgets and intent mixes, the encounter priorities and recovery gaps, the Spawn Ring geometry and on-screen spawn exceptions, spawn validation, entity throttling behaviour at the cap, the inter-wave gap, the post-draft grace period, the single Overtime trigger, the Pressure Metric algorithm and its bounds, the win-condition-impossible resolution, and the prototype wave sequence.

---

## 12 - Difficulty Scaling

Health scaling, damage scaling, spawn scaling, biome scaling, player progression balancing, and replayability systems.

Owns: scaling curves and the rule that telegraph windows never scale below their minimum.

---

## 13 - Roguelite Progression

Run progression systems, experience levels, temporary upgrades, rerolls, rarity systems, and run balancing.

Owns: the XP level curve, the forced first Level-Up Draft, Reroll, Banish, simultaneous level-up queueing, exhausted pool fallbacks, and level-up during boss transitions.

---

## 14 - Economy

Currencies, resource flow, progression economy, unlock economy, balancing, sinks, and rewards.

Owns: the Scrap cap, the overflow hopper capacity, the Drop Table, upgrade prices (Console and otherwise, excluding the Tower Repair price owned by document 07), the Scrap, Core, and XP currency definitions, the Meta Wallet rules (storage in document 24), transaction atomicity, and all economy edge cases except respecs (owned by document 18).

---

## 15 - Biomes

Complete biome designs, hazards, mechanics, visual themes, enemy pools, boss pools, and progression order.

Owns: all biome edge cases, hazard traversability guarantees, whether hazards damage the Tower per biome, and the arena dimensions.

---

## 16 - Resource System

Mining (parked until a biome needs it), collection, storage, processing, resource balancing, rarity, and gameplay integration.

Owns: all resource edge cases, pickup merge and expiry behaviour when the pickup cap is hit (the cap number is owned by document 20), drop placement, the XP shard as a pickup, and pickup physics/magnet rules including the raycast-blocked magnet default.

---

## 17 - Upgrade Pools

Player upgrades, tower upgrades, weapon upgrades, utility upgrades, rarity distribution, and selection logic.

Owns: maxed-upgrade filtering, shared ranks across the two channels, the one-player-and-one-Tower-card draft guarantee, dominant pair audits, recursion protection for on-kill and on-hit effects, and the Pool ownership data that drives card differentiation (the visual rules themselves are owned by document 19).

---

## 18 - Permanent Skill Tree

Meta progression, unlock trees, permanent bonuses, branching paths, progression pacing, and reset systems.

Owns: respec rules, unlock ordering, the Hub scene, and the guarantee that failed runs still advance the meta layer; the Meta Wallet rules are owned by document 14 (storage in document 24).

---

## 19 - UI / UX

HUD, menus, upgrade screens, health bars, damage numbers, accessibility, animations, and usability guidelines.

Owns: the three second rule, the readability hierarchy, device prompt switching, pause authority in the interface layer, UI text expansion, dynamic container rules, the Level-Up Draft interface, the Tower Console interface, the HUD, hold-to-confirm, sector selection, the Movement-only controls setting, the player-versus-Tower card differentiation rules, the visual half of Directional Threat Feedback, and the Hub interface.

---

## 20 - Technical Architecture (Godot)

Project architecture, singleton design, system communication, modular architecture, signals, and coding standards.

Owns: the architectural rules, Technical Edge Cases, the performance budget and every entity cap number, the reference machine and performance protocol, the Performance Fallback Ladder, the Global Simulation Authority implementation (SimClock, PauseAuthority, process-mode mapping), the Biome Transition Rule implementation, the binding collision layer table, determinism scope and the resolution order, Godot version pinning, audio bus implementation, the test harness, debugging and telemetry tools, and animation/hitbox cleanup implementation.

---

## 21 - Scene Tree

Complete scene hierarchy for the project.

---

## 22 - Node Hierarchy

Detailed Godot node structures for every major gameplay scene.

---

## 23 - Folder Structure

Repository layout, asset organization, naming conventions, documentation organization, and project standards.

---

## 24 - Save System

Persistent save architecture, serialization, progression saving, profile management, and future cloud save support.

Owns: all save and persistence edge cases, atomicity, corruption recovery, version migration, run resumability, and the Core write cadence.

---

## 25 - Asset Pipeline

Art workflow, asset sourcing, naming standards, animation pipeline, import settings, and optimization.

---

## 26 - Audio Design

Sound effects, music direction, adaptive audio systems, mixing standards, and implementation guidelines.

Owns: the audio component of threat readability, including the Tower damage cue, and dynamic ducking rules.

---

## 27 - VFX & Game Feel

Particles, screen shake, hit stop, camera feedback, lighting, impact effects, and polish systems.

Owns: Visual Edge Cases, the reduced-effects accessibility setting, effect density limits, camera follow/zoom rules, and the camera view scale.

---

## 28 - AI Development Workflow

Claude integration, MCP workflow, documentation workflow, coding workflow, automation pipeline, and AI collaboration standards.

Owns: the rule that documentation and implementation change in the same commit.

---

## 29 - Milestones & Roadmap

Prototype milestones, vertical slice, alpha, beta, content milestones, polish phase, release planning, and post-launch roadmap.

Owns: the Development Phase Map in this document, in expanded form, and its status tracking.

---

## 30 - Future Ideas

Experimental mechanics, postponed systems, DLC ideas, multiplayer considerations, and prototype backlog.

---

# Content Data Contracts

All major content types must be data-driven. The following contracts define the minimum fields each content type must expose before it is considered implementable.

These contracts are architectural requirements. The file format is Godot `Resource` (`.tres`) per the Godot 4.x Implementation Standards; document 20 owns the schema scripts.

Contract Field Semantics (the type and meaning of every field in the contracts below) live in `docs/20_Technical_Architecture.md`, a working system document that is binding for the prototype under the Provisional Defaults Policy.


---

## Enemy Definition Contract

Every enemy definition must include:

- Unique ID.
- Target intent.
- Movement profile.
- Attack profile.
- Telegraph data.
- Health band.
- Damage band.
- Contact behavior.
- Pathing fallback behavior.
- Entity cap weight.
- Elite eligibility.
- Allowed affixes.
- Biome tags.
- Readability profile.
- Drop table.

No enemy may be implemented if its target intent is undefined.

---

## Encounter Definition Contract

Every encounter definition must include:

- Unique ID.
- Encounter type.
- Design intent.
- Pressure target.
- Player answer.
- Failure signature.
- Spawn groups.
- Intent budget overrides.
- Directional weighting override.
- Telegraph requirements.
- Minimum recovery gap.
- Priority.
- Entity cap behavior.
- Encounter alive cap.
- Allowed encounter tags.
- Excluded encounter tags.
- Reward (Reward struct; zero for the four prototype encounters).
- Failure resolution.
- Partial reward rules.
- Pause and deferral behavior.

No encounter may be implemented if it cannot define what pressure it applies and how it resolves when failed. A non-null Directional weighting override supersedes the Director Configuration entry for that encounter's type.

---

## Upgrade Definition Contract

Every upgrade definition must include:

- Unique ID.
- Pool ownership.
- Rarity.
- Maximum rank.
- Prerequisites.
- Exclusions.
- Effect description.
- Effect target.
- Effect per rank.
- Console price per rank.
- Recursive interaction guard.
- Visual readability impact.
- Performance cost category.

No upgrade may be implemented if it can trigger unbounded recursion without a defined guard.

---

## Wave Definition Contract

Every wave definition must include:

- Unique ID.
- Biome context.
- Difficulty band.
- Encounter sequence.
- Spawn budget (derived: sum of its spawn groups' cap weights).
- Enemy intent mix.
- Elite chance.
- Maximum duration (nullable; null for boss waves) and target duration.
- Inter-wave gap.
- Overtime condition (stall threshold and finisher definition).
- Pressure Metric constants (escalation and de-escalation thresholds).
- Boss overlap rules.

A wave is not a list of enemy names. A wave is a designed pressure pattern.

---

## Biome Definition Contract

Every biome definition must include:

- Unique ID.
- Mechanical hook.
- Hazard definition.
- Hazard telegraph.
- Enemy pool expressed by target intents.
- Boss pool.
- Difficulty band.
- Readability palette.
- Tower hazard damage rule.
- Transition cleanup rule.
- Exclusive mechanics.

A biome is not approved for production until its hook, hazard, and Tower interaction rule are explicit.

---

## Tower Definition Contract

The Tower definition must include:

- Unique ID.
- Maximum health and base shield fraction.
- Shield regeneration rate and delay.
- Footprint radius and Interaction Radius.
- Base weapon reference (a Weapon Definition).
- Targeting rule parameters (range, intent preference).
- Evolution stage thresholds (four stages).
- Repair price.
- Persistent asset rules (drones across biomes).

---

## Tower Upgrade Definition Contract

Every Tower upgrade definition must include every field of the Upgrade Definition Contract, with Pool ownership set to Tower, plus:

- Evolution stage contribution (integer ranks counted toward the visual stage).
- Draft weight (0 excludes; every prototype upgrade 1).

---

## Weapon and Evolution Definition Contract

Every weapon definition must include:

- Unique ID.
- Effective range.
- Coverage shape (cone, line, radius, single target).
- Target count.
- Engagement rhythm (sustained or burst) and fire rate.
- Damage band.
- Projectile definition (speed, lifetime, pooling class).
- Evolution prerequisites and the evolution target.
- Which of range, coverage, target count, or rhythm the evolution changes (at least one, per Weapon Evolution Philosophy).

---

## Boss Definition Contract

Every boss definition must include:

- Unique ID and class (Mini-Boss or Biome Boss).
- Signature mechanic.
- Tower relationship (threatens, is affected by, or displaces the player from the Tower).
- Phase list, each with a trigger, an emphasis, and a transition telegraph.
- Arena sub-region bounds, if any (never excluding the Tower).
- Regular spawn suppression rule while active.
- Hazard cleanup schedule.
- Core drop.

---

## Elite Affix Definition Contract

Every affix definition must include:

- Unique ID.
- Behavioural effect.
- Stacking and self-interaction guard (an affix may never apply to itself or loop with another affix).
- Revive count, if reviving.
- Visual marker.
- Eligible target intents.

---

## Pickup Definition Contract

Every pickup definition must include:

- Unique ID and type (XP, Scrap, Core; Health from the vertical slice).
- Value.
- Magnet behaviour (attracted or static).
- Merge rule (same type only).
- Lifetime in simulation seconds.
- Visual and audio cue.

---

## Status Effect Definition Contract

Every status effect definition must include:

- Unique ID.
- Stacking rule (refresh, stack with a cap, or ignore).
- Duration in simulation seconds.
- Tick effect and tick interval.
- Source lifetime rule (what happens when the source dies).
- Cleanup rule at biome transition.

No status may be applied if its stacking rule is undefined.

---

## Player Definition Contract

Every Player Definition must include:

- Unique ID.
- Maximum health.
- Base speed.
- Acceleration time to base speed.
- Deceleration time to stop.
- Body radius.
- Hurtbox definition.
- Collector area radius.
- Magnet radius.
- Input buffer duration.
- Starting weapon reference (a Weapon Definition).

---

## Director Configuration Contract

Every Director Configuration must include:

- Unique ID.
- Spawn ring geometry (Tower ring and view ring).
- Camera exclusion margin.
- Spawn validation retry steps and angle increment.
- Off-screen and on-screen marker lead times.
- Directional weighting rules per encounter type.
- Encounter priority table.
- Default recovery gap table.
- Inter-wave gap defaults.
- Post-draft grace period.
- Pressure Metric intent weights.
- Pressure Metric escalation and de-escalation timers.
- Off-screen update reduction thresholds.
- Siege volume formula constants.
- Health quadrant threshold.

---

## Economy Configuration Contract

Every Economy Configuration must include:

- Unique ID.
- Merge radius.
- XP shard value and level cost formula.
- XP cap during teaching waves.
- Scrap cap.
- Overflow hopper capacity.
- Hopper-to-Core conversion rate and trigger.
- Core persistence write cadence.
- Run-End Settlement rates.
- Upgrade Console price formula.
- Dominance audit threshold and sample size.

---

# Document Dependency Map

Some documents cannot be finalised before others. This ordering prevents rework.

| Document | Must Be Stable Before |
| --- | --- |
| 00, 01 | Everything |
| 02 | 11, 12, 13 |
| 03 | 04, 05 |
| 05 | 06, 09, 10, 17 |
| 06 | 17 |
| 07 | 08, 10, 11, 17 |
| 09 | 10, 11, 12 |
| 11 | 12, 15 |
| 13 | 17 |
| 15 | 10 |
| 16 | 08, 14 |
| 14 | 18 |
| 08 | 18 |
| 14, 18 | 24 |
| 20 | 21, 22, 23, 24 |

Documents 19, 25, 26, and 27 track the others continuously and are never finalised early. Document 28 is written in Phase 0 and revised whenever the workflow changes. Document 29 is the expanded form of the Development Phase Map in this file and is updated at every phase exit; documents 29 and 30 are living documents with no stable requirement.

---

# Quality Gates

A system is not complete when it works. It is complete when it satisfies all of the following.

- Its document exists and matches the implementation; the Phase 0 stub with its "Owns:" list satisfies the existence requirement for the prototype milestone only — every later milestone requires the owning document to be at least Working and to match the implementation.
- Its edge cases from the register are handled or explicitly accepted in writing.
- It communicates only through defined interfaces.
- It survives the swarm performance test.
- It behaves correctly under pause, the Level-Up Draft, the Tower Console, and, where the milestone includes them, biome transitions.
- It fails loudly rather than silently.
- It can be modified by adding data rather than editing code, where the system is content-driven.
- It has at least one acceptance test that can fail.

---

# Acceptance Test Matrix

A system is not approved for implementation unless it has at least one failing-capable acceptance test.

Every test carries a milestone tag: **P** (mandatory for the prototype), **VS** (mandatory for the vertical slice), **A** (alpha and later), or **G** (a gate record, not a pass/fail criterion counted toward any milestone). A test tagged only VS cannot execute in the prototype and is not required there. Every pass condition is numeric or observable by a named instrument (the Run Recorder, the debug overlay, an internal tester, or an external tester probe). Internal testers are the designer and the AI collaborator's scripted bots; build-task rows use scripted checks or internal testers only. External tester probes run only at P2.16 (5 external testers), P3.18 (5 fresh external testers), and P4.6.5 (20 external testers, pass at 16 of 20); elsewhere, testers pass at four out of five unless stated. Each table lists, for every test, its milestone tag, numeric pass condition, the instrument that verifies it, and the first task that exercises it.

---

## Core Tension Tests

| Test | Tag | Pass condition | Instrument | First task |
| --- | --- | --- | --- | --- |
| Tower neglect test | P | During a Siege in which the player stays outside the Tower's weapon range for the full wave, the Tower loses at least 40% of its maximum health. | Run Recorder | P2.15 |
| Player neglect test | P | A player who does not move for 20 seconds while at least three Player Hunters are alive loses at least 50% of maximum health. | Run Recorder | P2.15 |
| Split choice test | P | A no-upgrade, lane-switching scripted bot across 5 seeded attempts cannot keep Tower damage from both lanes below 10% of Tower maximum health in any attempt. | Run Recorder | P2.15 |
| Safe corner test | P | 25 standalone scripted scenarios, each starting at combat wave 1 with base stats and a still bot at one position: 20 points of a 5×4 grid inset 400 px from the walls (points within 300 px of the Tower's centre shifted outward to 300 px), 4 points 120 px from the Tower's centre (north, east, south, west), and 1 point 200 px south; at every position the bot loses player health, Tower health, or held Scrap within 60 s. | Run Recorder position, health, and Scrap traces | P2.15 |
| Orbit test | P | Over 5 paired runs with the same seeds, a scripted orbit bot (stays 120–480 px from the Tower) reaches a lower final wave or lower XP level than a scripted roam bot (goes to the nearest threat anywhere) in at least 4 of 5 pairs; no Run Recorder tick shows the roam bot inside the Tower Interaction Radius. | Run Recorder, two scripted bots | P2.15 |
| Interaction window test | P | Opening the Tower Console during any encounter with enemies alive results in measurable player damage in at least 3 of 5 tester runs, and the Console never closes on damage taken. | Scripted test; re-observed via tester probe at P2.16 | P2.13 |
| Scrap loss test | P | On player death, the Scrap counter on the run-end screen is zero and no Scrap carries to the next run. | Run-end screen, scripted assertion | P2.14 |
| Could-not-protect-both test | P | At least four out of five testers describe a specific moment they could not protect both themselves and the Tower. | Tester probe (5 testers) | P2.16 |
| Failure clarity test | P | At least four out of five testers can name the decision that ended the run. | Tester probe (5 testers) | P2.16 |
| Tower relevance test | P | At least four out of five testers describe the Tower as a separate thing they were protecting, unprompted. | Tester probe (5 testers) | P2.16 |
| Two things test | P | At least four out of five external testers describe the game as "protecting two things at once" without being prompted. | Tester probe (5 testers) | P2.16 |
| Another run test | P | At least three out of five testers ask to play another run unprompted (session script question). | Tester probe (5 testers) | P2.16 |
| Investment split test | VS | At least four out of five testers state whether they invested more in themselves or in the Tower, and give a specific reason why. | Tester probe (5 testers) | P3.18 |
| Channel understanding test | VS | At least four out of five testers state the difference between the Level-Up Draft and the Tower Console, and give one reason they chose one over the other. | Tester probe (5 testers) | P3.18 |
| Failed-run progress test | VS | At least four out of five testers believe the failed run still gave meaningful permanent progress. | Tester probe (5 testers) | P3.18 |
| Upgrade dominance perception test | VS | No tester identifies a single upgrade as making all other upgrades irrelevant. | Tester probe (5 testers) | P3.18 |
| Encounter fairness test | VS | No tester identifies one encounter type as boring, unreadable, or unfair. | Tester probe (5 testers) | P3.18 |

---

## Encounter Tests

| Test | Tag | Pass condition | Instrument | First task |
| --- | --- | --- | --- | --- |
| Siege test | P | Same seed, 5 of 5 seeds: (a) a far bot (> 1200 px from the Tower) leaves the Tower below 50% health; (b) a chase bot reaching 480 px of the Tower within 10 seconds of the Siege warning keeps the Tower at or above 50%; (c) a still bot at 200 px ends at least 15 percentage points below the chase bot and below 50%; (d) a bot hugging the Tower at 120 px, auto-fire disabled, ends below 50%. | Run Recorder, four scripted bots | P2.15 |
| Standard Assault test | P | Runs the standalone Standard Assault as a scripted 90 second encounter: the Tower loses no more than 10% of maximum health, no Run Recorder tick shows the roam bot inside the Tower Interaction Radius, and the Tower alone clears the Seeker budget within 60% of the wave maximum duration in a no-player test run; T1 and T2 are exempt from the 60% clause. | Run Recorder | P2.15 |
| Split Assault test | P | Each lane-split spawn group assigns exactly ceil(0.6 × n) spawns to the heavier lane and prototype lane centres are 180° apart, across 20 generated Split Assaults (scripted). | Debug overlay | P2.8 |
| Hunt test | P | In every scripted Hunt encounter, Player Hunters land at least one hit on the player, and the encounter's spawned mix matches its data-defined Enemy intent mix within the wave's spawn budget. | Run Recorder, debug overlay | P2.8 |
| Leash test | P | A Player Hunter that deals no damage to the player for 20 simulation seconds shows a 0.5 second telegraph then permanently converts to a full Tower Seeker profile, keeping its current HP; any damaging hit resets the 20 second timer. | Scripted assertion | P2.5 |
| Opportunist test | P | An Opportunist re-evaluates its target only on the three defined events (damaged by the other target, current target outside 400 px aggro range for 3 seconds, or current target dies), and switches only when the other target is at least 25% closer and at least 3 seconds have passed since its last switch. | Debug log, scripted assertion | P2.5 |
| Stuck exemption test | P | In a scripted queue converging on one target, an enemy blocked only by allies already in reach accumulates no stuck timer; an enemy genuinely making no progress toward its target (distance shrinks less than 8 px) triggers the 3 second reroute, the 8 second direct-approach, and the 20 second despawn exactly on schedule. | Scripted assertion | P2.5 |
| Encounter deferral test | P | No encounter opens while the Level-Up Draft is open, and none opens within 1.5 seconds of it closing. | Run Recorder timestamps | P2.12 |
| Encounter recovery test | P | When two encounters are scheduled together, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap (Siege 10 s, Split Assault 8 s, Hunt 8 s, Standard Assault 5 s), in 10 of 10 scripted double-schedules. | Run Recorder | P2.8 |
| Wave runtime test | P | A scripted wave with non-finisher kills below the stall threshold (5 per 30 s) at maximum duration enters Overtime; a wave with sufficient kills ends without it; survivors of a non-final wave carry over, counting against the enemy cap but not the next wave's spawn budget; the final combat wave never ends on its maximum duration, only when every enemy it owns is dead. | Scripted test, Run Recorder | P2.8 |
| Overtime test | P | With enemies alive past the wave maximum duration and non-finisher kills in the last 30 seconds below 5, finishers spawn at 2 per 5 seconds on the view ring within 5 seconds; at or above 5 kills, no finisher spawns. | Scripted test | P2.8 |
| Guaranteed first draft test | P | The first Level-Up Draft opens at the end of the first Siege in 5 of 5 runs regardless of XP collected. | Scripted test | P2.12 |
| Draft queue test | P | Two simultaneous level-ups produce two sequential drafts and no draft is dropped. | Scripted test | P2.12 |
| Draft input lockout test | P | Input is locked for 0.4 seconds after the Level-Up Draft opens; hold-to-confirm arms only after input returns to neutral once; left/right cycle with a 0.3 second repeat and wrap; holding up for 1.0 second confirms the highlighted card with a fill ring that resets on release. | Scripted input replay | P2.12 |
| Spawn ring test | P | In 1000 scripted spawns, no enemy instantiates inside the camera view margin or the Interaction Radius. | Scripted test | P2.8 |
| Spawn ring on-screen test | VS | No on-screen spawn exception (Ambush, Pincer, Breach) spawns without a telegraph marker of at least 1.0 second. | Scripted test | P3.11 |
| Pressure test | P | Scripted Threat and Capacity inputs reproduce Pressure = Threat ÷ (Capacity × 20 s) within floating-point tolerance; Pressure below 0.6 for 3 seconds starts the next spawn group with at least 4 seconds between escalations; Pressure above 1.8 doubles spawn intervals until it lifts below 1.2 or 10 seconds elapse, then holds a 6 second re-arm lockout before de-escalating again; never in Siege or Overtime. | Scripted assertion | P2.9 |
| Composition rule test | VS | Across a full slice biome's wave sequence, every combat wave after T1 contains at least one Tower Seeker or Opportunist, the biome contains at least one Hunt, one Siege, and one Split Assault, and it includes a Duel when the Biome Boss reuses a mechanic, or a recorded Change Log waiver row when it does not. | Scripted schema check | P3.11 |
| Elite affix loop guard test | VS | No combination of two Elite affixes applies to itself or loops with another affix; a scripted double-affix Elite completes its behaviour in finite ticks. | Scripted assertion | P3.8 |
| Elite drop test | VS | An Elite's Logical Death drops exactly 3 XP shards, 3 Scrap, and 1 Core per the Drop Table. | Scripted assertion, Run Recorder | P3.8 |
| Boss edge case test | VS | Every boss, Mini-Boss included, satisfies all Boss Design Requirements at its scale; the Tower is present and undisplaced in every boss sub-region; on a same-tick boss-and-player death the boss kill is credited (Cores and stats) and the run still fails with no biome clear. | Scripted assertion, Run Recorder | P3.10 |
| Escort test | A | A destroyed Escort objective still grants a partial reward, and a completed Escort delivers its reward to the player regardless of position on the map. | Scripted assertion | P4.3.1 |
| Blackout test | A | A Blackout never disables the player's ability to see incoming damage and always shows a visible countdown. | Scripted assertion | P4.3.2 |
| Breach test | A | Every Breach telegraphs at least 10 seconds before opening, never opens directly adjacent to the Tower, and the combined spawn rate of concurrent breaches never exceeds the global entity cap. | Scripted assertion | P4.3.3 |
| Ambush test | A | Every Ambush telegraphs at least 1.0 second with no scaling exception, never spawns within 2 seconds of player travel, and never fires during the Level-Up Draft or the grace period. | Scripted assertion | P4.3.4 |
| Pincer test | A | Every Pincer spawns with a visible gap, never inside the player's current position or immediate movement arc, and telegraphs at least 1.0 second no closer than 2 seconds of player travel. | Scripted assertion | P4.3.5 |
| Environmental Event test | A | No Environmental Event fully encloses the Tower in an impassable hazard, spawns a hazard directly on the player, or skips the telegraph requirement enemy attacks obey. | Scripted assertion | P4.3.6 |
| Resource Rush test | A | An ignored Resource Rush expires cleanly with no orphaned entities, and a player at maximum storage is warned before travelling to it. | Scripted assertion | P4.3.7 |
| Swarm Crush test | A | A Swarm Crush throttles at the entity cap rather than queueing, never culls an enemy inside the player's visible screen area, and keeps its drop volume capped. | Scripted assertion | P4.3.8 |

---

## Technical Tests

| Test | Tag | Pass condition | Instrument | First task |
| --- | --- | --- | --- | --- |
| Cap unit check | P | A scripted spawner never exceeds each entity cap (enemies 300, pickups 150, projectiles 400, damage numbers 30, telegraphs 40, VFX 24) in isolation. | Scripted assertion | P1.3 |
| Entity cap test | P | Across every P2.15 run, enemy, pickup, projectile, damage-number, telegraph, and VFX counts never exceed their caps; enemies never exceed 300. | Debug overlay maxima logged | P2.15 |
| Swarm performance test | P | At P1.7, 300 placeholder enemies soak-tested hold median ≥ 60 FPS and 1st-percentile ≥ 45 FPS over 60 seconds; at P2.15, combat wave 4 as budgeted (at most 120 enemies alive) holds the same thresholds on the reference machine. | Debug overlay, reference machine | P1.7 |
| Pause clock unit check | P | `SimClock.now` stops the instant a pause reason is active and resumes exactly where it left off, in isolation. | Scripted assertion on `SimClock.now` | P1.1 |
| Pause authority test | P | With the Level-Up Draft open, the pause menu open, or focus lost, no enemy, projectile, pickup, timer, or telegraph changes state for 10 seconds (the prototype has no hazards). | Scripted assertion on `SimClock.now` | P2.14 |
| Console non-pause test | P | With the Tower Console open, `SimClock.now` advances and enemies keep moving. | Scripted assertion | P2.13 |
| Console rules test | P | The Console opens only after 0.3 seconds inside the Interaction Radius with player speed under 10% base and at least one affordable entry (at 0 Scrap Repair is greyed and does not count toward opening the Console, C-REPAIR); it closes on leaving the radius, Cancel, death, or a Level-Up Draft opening, and stays closed after Cancel until the player leaves and re-enters; every purchase channels for 0.5 seconds and cancels without charge above 10% base speed. | Scripted assertion | P2.13 |
| Focus loss test | P | Losing window focus pauses within one frame and the game does not resume until the player confirms; a controller disconnect opens the pause menu the same way; the harness's `--no-focus-pause` flag is exercised here. | Scripted assertion | P2.14 |
| Same-frame death test | P | When both pools reach zero on the same physics tick, the Run Recorder records cause = Tower in 10 of 10 scripted trials. | Run Recorder | P2.4 |
| Camera bounds test | P | The camera never renders outside the arena at any zoom. | Scripted sweep of the arena edges | P2.2 |
| Movement-only test | P | Using only movement input, an internal tester resolves every Level-Up Draft of a prototype run and, with the Movement-only controls setting on, completes at least one Console purchase; with the setting off, standing beside the Tower for 60 seconds buys nothing. | Internal tester | P2.14 |
| Pool unit check | P | 10,000 acquire/release cycles in isolation leave the object count stable within ±1%. | Godot object monitor | P1.3 |
| Object pooling test | P | Godot's object count monitor does not grow by more than 5% between the first and the last combat wave of a run. | Godot object monitor | P2.15 |
| Ghost hit test | P | Dead enemies cannot deal damage, even if their death animation has not finished, across 100 scripted kills mid-attack. | Scripted test, zero damage events after Logical Death | P1.5 |
| Pickup physics test | P | Pickups accelerate toward the player, stop while an enemy body blocks the magnet ray, and never pass through terrain. | Scripted test | P2.10 |
| Keyed RNG unit check | P | With the same run seed, keyed rolls (draft offers, drops, spawn positions) reproduce identically in isolation across 10 of 10 repetitions. | Scripted assertion | P1.1 |
| Determinism test | P | With the same run seed, a scripted sequence of keyed rolls (draft offers, drops, spawn positions) produces identical results in 10 of 10 repetitions across a full run. Full input replay is not required for the prototype. | Scripted test | P2.12 |
| XP cap check | P | During T1–T4, XP never exceeds 14 and no level-up fires; the forced Draft at T4's end grants level 1 and keeps the held XP toward level 2. | Scripted assertion | P2.12 |
| Recorder schema check | P | The Run Recorder's ticks.csv and events.csv headers match the defined schema exactly on a scripted 60 second SimLoop run with placeholder events. | Schema diff check | P1.4 |
| Registry query check | P | A single `EntityRegistry` radius query over 300 entities completes in under 0.05 ms. | Scripted benchmark, debug overlay timer | P1.2 |
| Audio priority check | P | With more than 8 priority sounds requested simultaneously, the AudioPool steals the lowest-priority voice first, then the oldest, and steals the oldest priority voice once all 8 priority slots are full. | Scripted assertion | P1.6 |
| Player movement check | P | The player reaches full speed (320 px/s) within 0.08 seconds of input and stops within 0.05 seconds of release, with a 100 ms (6-tick) input buffer cleared on pause. | Scripted assertion | P2.1 |
| Weapon check | P | The Handgun fires 2 shots/s at 10 damage/shot (20 DPS) at 260 px range, re-picking the nearest target every shot, with a 1000 px/s projectile. | Scripted assertion | P2.3 |
| Tower weapon check | P | The Tower fires 1.25 shots/s at 20 damage/shot at 480 px range with a 900 px/s projectile, targets the nearest Tower Seeker in range, else the nearest enemy; drops a non-Seeker target on the tick a Seeker enters range (C-TOWERTARGET), using placeholder Seeker definitions from P0.6 and P1.5; 25 DPS within 5%. | Scripted assertion | P2.4 |
| Health recovery check | P | The Tower's shield regenerates at 10% per second beginning 8 seconds after the last hit, and the delay restarts on every hit. | Scripted assertion | P2.4 |
| Upgrade effect check | P | Each of the six prototype upgrades and both fallback cards applies its documented per-rank effect exactly, with no drift after 3 ranks. | Scripted assertion | P2.11 |
| Teaching Siege tuning check | P | In a scripted T4-only scenario that starts T4 directly with the player absent, the Tower is destroyed before T4 ends in at least 3 of 5 seeds; with a scripted bot that reaches within 480 px of the Tower within 10 s of the Siege warning and chases Seekers, the Tower ends above 50% in 5 of 5 seeds (author decision A2). | Run Recorder | P2.14 |
| Run flow check | P | The run-end screens show the death cause or the final wave reached, the Scrap held, and the time survived. | Scripted assertion | P2.14 |
| Stability check | P | Zero crashes, softlocks, or orphaned encounter states occur across every P2.15 and P2.16 run. | Run Recorder, scripted and tester runs | P2.15 |
| Transition cleanup test | VS | No projectiles, hazards, pickups, or orphaned entities survive biome transition unless explicitly permitted. | Entity count is zero in each pooled container after transition | P3.17 |
| Overflow hopper test | VS | Scrap collected past the 200 cap enters the overflow hopper up to its 100 cap and is lost on player death; a bot that never enters the Tower Interaction Radius for an entire run banks zero overflow Cores. | Run Recorder | P3.4 |
| Settlement test | VS | Run-End Settlement pays 5 Cores per biome cleared, 3 per boss killed (Mini-Boss included), and 1 per full minute of simulation time; a pause-menu abandon pays the failure settlement, and a crash pays only what was already banked. | Scripted assertion | P3.4 |
| Save atomicity test | VS | A save write interrupted mid-write never corrupts the profile; on next load the profile falls back to the last complete write. | Scripted kill-mid-write test | P3.14 |
| Meta persistence test | VS | The Meta Wallet and unlock state persist correctly across a save/load cycle and across a failed run. | Scripted assertion | P3.14 |
| Status stacking test | VS | Each status effect's stacking rule (refresh, stack with a cap, or ignore) behaves exactly as defined across 3 concurrent applications. | Scripted assertion | P3.5 |
| Hook degrade test | VS | No combination of owned upgrades reduces a biome's mechanical hook below 40% of its baseline effect. | Scripted assertion | P3.6 |
| Controller-only run test | VS | A tester completes a full slice run using only a controller, with device prompts switching correctly and a reconnect prompt appearing on disconnect. | Internal tester at P3.15; external tester probe at P3.18 | P3.15 |
| Onboarding compression test | VS | The compressed profile halves T1 and T2 durations and budgets and still plays all four teaching waves, and onboarding testers still pass the Tower relevance test. | Internal tester at P3.15; external tester probe at P3.18, Run Recorder | P3.15 |
| Dominant pair audit | VS | Across at least 10 recorded runs, no single pool (player or Tower) accounts for more than 65% of ranks acquired. | Run Recorder aggregate | P3.12 |
| Evolution check | VS | Each weapon evolution changes at least one of range, coverage, target count, or rhythm from its prerequisite, verified against its Weapon and Evolution Definition Contract. | Scripted schema check | P3.7 |

---

## Readability Tests

| Test | Tag | Pass condition | Instrument | First task |
| --- | --- | --- | --- | --- |
| Threat visibility test | P | On 10 fixed stills captured from designer-recorded runs (the same stills for every tester, with an answer key written before the session and Run Recorder ground truth), testers point at the correct threat direction: at least 8 of 10 answers correct within 3 seconds for at least 4 of 5 testers. | Tester probe | P2.16 |
| Health pool danger test | P | On 10 fixed stills captured from designer-recorded runs (the same stills for every tester, with an answer key written before the session and Run Recorder ground truth), testers name which pool takes damage first in the next five seconds: at least 8 of 10 answers correct within 3 seconds for at least 4 of 5 testers. | Tester probe, Run Recorder | P2.16 |
| Cost of movement test | P | On 10 fixed stills captured from designer-recorded runs (the same stills for every tester, with an answer key written before the session and Run Recorder ground truth), testers name what is left undefended if the player moves toward the threat: at least 8 of 10 answers correct within 3 seconds for at least 4 of 5 testers. | Tester probe | P2.16 |
| Effect density test | P | With 24 high-intensity effects on screen (the readability degradation threshold), an enemy telegraph placed under them is still identified by four of five testers. | Tester probe | P2.16 |
| Unseen death test | P | No tester reports a death they could not have seen coming. | Tester probe (5 testers) | P2.16 |
| Player silhouette test | P | The player sprite renders above every enemy body when surrounded. | Scripted render-order check | P2.1 |
| Audio clarity test | P for Tower cue, VS for boss telegraphs | During combat wave 4 as budgeted (at most 120 enemies alive), 5 of 5 testers hear the Tower damage cue; boss telegraph cues in 5 of 5 trials in the slice. | Tester probe | P2.16 |
| UI scaling test | P | Upgrade cards and Console entries do not break or truncate when the pseudo-localization toggle adds 30% length. | Scripted UI check | P2.13 |
| HUD layout check | P | The player health bar (top-left), Tower health bar with shield overlay and wave label (top-centre), Scrap counter (top-right), and XP bar with level and rerolls (bottom) render in their defined positions at 1920×1080 with no overlap. | Scripted layout check | P2.14 |
| Tower cue audibility check | P | The cue plays on an AudioStreamPlayer routed to the TowerCue bus (which sends to SFX_Priority) with pan = clamp((Tower x − player x) ÷ 960, −1, 1), at full volume from the far arena corner (scripted bus and pan assertion), and respects the 250 ms retrigger limit. | Scripted assertion | P2.6 |
| Hazard telegraph test | VS | Every biome hazard's telegraph renders in its reserved colour at least 1.0 second before the hazard activates (at least 10 seconds for a Breach-class warning), and 4 of 5 testers point at it correctly. | Tester probe | P3.3 |
| Reduced effects test | VS | With the reduced-effects accessibility setting on, high-intensity VFX count and screen shake drop below their normal caps while telegraphs remain fully visible. | Scripted assertion at P3.15; external tester probe at P3.18 | P3.15 |
| Evolution silhouette test | VS | Each Tower evolution stage (Reinforced, Armed, Fortress) is visually distinguishable from the others at normal play distance by 4 of 5 testers. | Internal tester at P3.16; external tester probe at P3.18 | P3.16 |
| Hook description test | VS | At least 4 of 5 fresh external testers describe the biome's mechanical hook correctly in their own words. | Tester probe | P3.18 |

---

## Build Checks

| Test | Tag | Pass condition | Instrument | First task |
| --- | --- | --- | --- | --- |
| Settings check | P | A scripted audit of the project asserts, by effective value, all 16 collision layer names in order, the full input map including number keys 1–7 and the debug toggles, every pinned project setting, the boot-check autoload, and pinned Godot 4.7.1 export templates present; and the exported Windows release build launches its empty scene with the boot check firing inside it. Amended by decision D82: a release-template build cannot host `--script`, so the audit runs against the project and the exported build is verified by launching it and by checking its pack contents. | Scripted project audit (`tests/settings_check.gd`) plus a launch of the exported build | P0.2 |
| Schema check | P | Every content type's data contract schema, including Player, Director, and Economy Configuration, validates against a sample `.tres` resource with no missing required field. | Scripted schema validation | P0.6 |
| Harness check | P | gdUnit4 runs headless via `Godot_v4.7.1-stable_win64_console.exe --headless` and reports pass/fail exit codes correctly. | Scripted CI run | P0.7 |
| Gate record check | G | The Change Log contains a gate row for the prototype milestone written by the human designer, per the Gate Approval rule. | Document review | P2.18 |
| Feel check | P | With hand-placed enemies and no Director running, the designer and the AI collaborator's scripted bots (internal testers) record a go/adjust verdict on whether the core tension is fun with one enemy per intent. | Designer and scripted bots, recorded verdict | P2.7 |
| Grappling criteria review | G | The grappling hook spike, run as a ≤ 2-day effort after the prototype playtest, is scored against all four evaluation criteria in document 04, with a go/no-go recorded in the Change Log. | Designer review | P2.17 |
| Full run test | A | A scripted run through all three biomes including transitions completes without developer intervention. | Internal tester, Run Recorder | P4.5.1 |
| Save migration test | A | A save file from the previous version field loads correctly under the current version, migrating rather than corrupting. | Scripted assertion | P4.5.2 |
| Localization test | A | With the pseudo-localization toggle adding 30% text length, no UI element truncates or breaks beyond its defined ellipsis-plus-tooltip fallback. | Scripted UI check | P4.6.1 |
| Minimum-spec performance test | A | On the minimum-spec machine recorded in the Provisional Values Register (filled by decision task P4.6.0), an exported release build holds median ≥ 60 FPS and 1st-percentile ≥ 45 FPS over 60 seconds logged to CSV during the heaviest encounter in scope. | CSV log | P4.6.4 |

If any mandatory test for the current milestone fails, the issue is treated as a design or implementation blocker, not polish.

---

# Playtest Validation Questions

Every playtest must answer these questions directly. Vague positive feedback is not data.

## On the core tension

Was there a moment where you knew you could not save both? What did you choose, and did the choice feel like yours?

## On readability

Did anything kill you that you did not see coming? Point at the screen and name it.

## On the Tower

Did you ever forget the Tower existed? For how long?

## On build agency

Name the upgrade that defined your run. If the answer is "I do not remember", the pool is not producing identity.

## On failure

Name the decision that ended your run. If the answer is "it just got too hard", the failure was not legible.

## On pacing

Was there a stretch where you had nothing to do? When?

Any playtest where three or more of these produce a weak answer is a signal to fix design, not to add content.

---

# Playtest Validation Pass Criteria

Playtest feedback must be converted into pass or fail conditions.

For prototype validation, use at least five external testers who did not design the game.

A prototype playtest passes according to the Prototype Success Criteria in Minimum Playable Prototype Gate › Prototype Success Criteria; that list is not restated here.

A vertical slice playtest passes only if all prototype criteria pass and additionally:

1. At least four out of five testers can describe the biome's mechanical hook (Hook description test).
2. At least four out of five testers understand the difference between player upgrades and Tower upgrades (Channel understanding test).
3. At least four out of five testers believe the failed run still gave meaningful permanent progress (Failed-run progress test).
4. No tester identifies a single upgrade as making all other upgrades irrelevant (Upgrade dominance perception test).
5. No tester identifies one encounter type as boring, unreadable, or unfair (Encounter fairness test).

If three or more testers give weak or vague answers to any core question, the problem is treated as a design failure, not a content shortage. A **weak answer** is one that names no specific moment, decision, enemy, or screen element: "it got hard" is weak; "I went for the Scrap on the left and the Seekers got the Tower" is specific.

---

# Definition Of Done For A Milestone

- All systems in scope pass the quality gates above.
- A full run can be completed start to finish without developer intervention. For the prototype a full run is eight waves ending with the final wave cleared — every enemy dead, both pools above zero; for the vertical slice it is one biome ending with the Biome Boss defeated.
- No known crash, softlock, or stall in the register is unresolved.
- Documentation for every touched system is updated in the same commit.
- The build meets the performance rule (median ≥ 60 FPS, 1st-percentile ≥ 45 FPS) during the heaviest encounter in scope.
- All acceptance tests tagged for the milestone pass.
- The gate is recorded in the Change Log per the Gate Approval rule.

---

# Glossary

Run — a single playthrough that starts when the player launches from the Hub (the prototype boots directly into the arena) and ends in success (the final wave cleared with both pools alive), failure (the player or the Tower destroyed), or abandonment.

Biome — a self-contained environment with its own enemies, hazards, hook, and bosses.

Wave — a time-boxed pacing slot within a biome that has a derived spawn budget and, for a combat or teaching wave, a maximum duration (boss waves have none); it contains one or more encounters. A wave is never itself an encounter.

Teaching wave — one of the four onboarding waves (T1 through T4) that open a run's first biome before its combat wave 1; not counted among the biome's eight combat waves; suppresses level-ups and caps XP at 14 while open.

Encounter — one data-defined spawn pattern with an intent, a pressure target, a player answer, and a failure signature, produced by the Wave Director inside a wave. Standard Assault is the default encounter.

Target Intent — the declared objective of an enemy, which determines what the player loses by ignoring it.

Affix — a behavioural modifier applied to an enemy to create an elite variant.

Standard enemy — any enemy spawned from an encounter's spawn groups that is not an elite, a boss, an Overtime finisher, or a Splitter child.

Hook — the single mechanic that gives a biome its identity.

Pool — a set of possible upgrades or enemies from which a selection is drawn.

Object pool — a pre-allocated set of reusable engine objects (enemies, projectiles, pickups, effects) that instances are acquired from and released to rather than instantiated or freed during a run; never confused with a Pool of upgrade or enemy definitions. See the Object pooling test.

Draft — short for Level-Up Draft, defined below. The Tower Console is never called a draft.

Meta progression — progression that persists between runs.

Run progression — progression that resets each run.

Sink — anything that consumes a currency.

Telegraph — the visible and audible warning that precedes a damaging action.

Entity cap — the hard maximum number of simultaneous active objects of a given class.

Cap weight — a spawn group's contribution to its wave's spawn budget (the wave spawn budget is the sum of its groups' cap weights); distinct from the entity cap, which limits simultaneous active objects across the whole arena regardless of which wave spawned them.

Stall — a state where the run continues but no progress is possible. In the Wave Director this is the specific condition of a wave reaching its maximum duration with fewer than the stall threshold (5) non-finisher kills in the last 30 seconds, which triggers Overtime; see Wave Runtime Model.

Softlock — a state where the run cannot progress and cannot end.

Logical Death — the tick an entity's health reaches zero: its dead flag is set and its hitboxes, hurtbox, and body stop interacting except the body's World and ArenaBounds masks (C-DEATH).

Visual Death — The cosmetic animation that plays after Logical Death.

Arena — the bounded play space of one biome, with the Tower at its centre. "Level", "battlefield", and "map" mean the arena.

View scale — the camera zoom convention where 1.0 equals a 1920×1080 world-pixel view; Godot Camera2D.zoom = 1 / view scale. Range 0.9 to 1.15; see Camera & Viewport Rules.

Hub — the out-of-run scene with Start Run and the Factory. Not in the prototype.

Meta Wallet — the persistent Core balance. Rules in document 14, storage in document 24.

Scrap — the run currency: dropped by standard enemies, elites, and bosses, capped at 200, spent at the Tower Console; Scrap collected beyond the cap enters the overflow hopper in the vertical slice (discarded, with a FULL indicator, in the prototype); any Scrap held is lost on death.

Cores — the meta currency: dropped by Elites, the Mini-Boss Checkpoint, and the Biome Boss; also produced by overflow hopper conversion at the Tower and by Run-End Settlement; banked to the Meta Wallet instantly on collection.

Overflow hopper — the container (cap 100) that holds Scrap collected beyond the 200-Scrap run inventory cap; carried by the player and lost on death; converts to Cores at 10:1 when the player enters the Tower Interaction Radius, with any remainder under 10 staying in the hopper; not present in the prototype.

XP shard — the experience pickup; fills the level bar; not a currency.

Level-Up Draft — the free, random, pausing upgrade interface opened by an XP level-up. "Draft" alone always means this.

Tower Console — the priced, deterministic, non-pausing upgrade and repair interface inside the Tower Interaction Radius.

Tower Interaction Radius — the circle around the Tower inside which the Console opens; not a safe zone.

Kill zone — the area within the Tower's weapon range (480 px).

Vulnerability window — the state of having the Tower Console open: auto-fire disabled, still damageable.

Run inventory — the player's held Scrap during a run.

Magnet radius — the circle around the player inside which pickups accelerate toward them.

Spawn Rings — two annuli, both clipped to the arena, on which off-screen spawns are placed: the Tower ring (Tower-centred), used for Tower Seekers, and the view ring (camera-centred), used for Player Hunters, Opportunists, and Overtime finishers. See Spawn Rings & Placement.

On-screen spawn exception — Ambush, Pincer, and Breach, which spawn inside the camera view through telegraphed spawn markers.

Pressure Metric — the Wave Director's ratio of enemy threat to player-plus-Tower capacity, used to escalate and to bound de-escalation.

Health quadrant — the run state given by which pools are High or Low (Low is below 40%).

Inter-wave gap — the minimum simulation time between the end of one wave and the opening of the next.

Recovery gap — the minimum simulation time after an encounter completes before another may open; when two encounters are due at once, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus that higher-priority encounter's recovery gap.

Grace period — the 1.5 seconds after the Level-Up Draft closes during which no encounter opens and no spawn group starts; enemies already active keep acting, and any pending spawn timer extends by the grace period.

Overtime — the finisher protocol that resolves a wave STALLED at its maximum duration (fewer than 5 non-finisher kills in the last 30 seconds): finishers spawn on the view ring until every non-finisher enemy the wave owns is dead, then remaining finishers despawn without drops. See Wave Runtime Model.

Elite — a base enemy with exactly one behavioural affix; always drops a Core.

Boss wave — a wave that contains only its boss encounter (the Mini-Boss Checkpoint or the Biome Boss), with no maximum duration, no Overtime, and spawn suppression stated by the Boss Definition.

Mini-Boss Checkpoint — the boss encounter inside the boss wave after combat wave four of a biome; satisfies every Boss Design Requirement, at a smaller scale than the Biome Boss (for example, two short phases instead of three).

Biome Boss — the boss encounter inside the boss wave after combat wave eight of a biome; binds every Boss Design Requirement; completes the biome.

Run Bonus — the Cores granted at run end by Run-End Settlement.

Simulation time — physics ticks multiplied by the physics step, accumulated by SimClock; the only clock gameplay may use.

Provisional Default — a number or rule in this document that binds until the owning system document overrides it.

Stable — the state of a system document defined in Document Control.

Working — a lesser document state than Stable: a system document is working when its version is at least 0.5.0, it covers every item in its Owns list, and it has no placeholder in any edge case it owns (see Document Control).

Internal tester — the designer or the AI collaborator's scripted bots; build-task acceptance tests use internal testers or scripted checks only.

External tester — a person who did not design the game and has not played an earlier build; external tester probes run only at P2.16, P3.18, and P4.6.5.

Attack slot — one of the evenly spaced positions an attacking enemy claims around its target before engaging; see the Intent Behaviour Defaults in document 09.

G tag — an Acceptance Test Matrix tag marking a gate record rather than a pass/fail criterion; a G-tagged row is not counted toward any milestone's P, VS, or A criteria.

Hold-to-confirm — the movement-only confirmation used in every paused menu: after input returns to neutral once, holding up toward the highlighted choice for 1.0 second confirms it, shown with a fill ring that resets on release.

Sector selection — the movement-only purchase method in the Tower Console when the Movement-only controls setting is on: seven fixed 51.4° sectors clockwise from north, one per entry (Repair, Rapid Fire, Heavy Rounds, Patch Kit, Caliber, Optics, Shield Matrix), where an unavailable or maxed sector stays in place and buys nothing (C-SECTORS); standing still below 10% base speed for 1.0 second in an entry's sector buys one rank; a sector re-arms only after the player moves above 10% speed or leaves it.

---

# Minimum Playable Prototype Gate

The Minimum Playable Prototype exists to prove one thing:

> The player cannot fully protect both themselves and the Tower at the same time, and that inability creates meaningful decisions.

The prototype is not a vertical slice. It is not a content demo. It is a structural proof.

---

## Prototype Scope

The prototype must include:

- One arena: 4800 by 3200 pixels, Tower at centre, hard walls, no interior obstacles. The game boots directly into it; there is no Hub.
- One central Tower with 500 health, the base shield, the Tower Targeting Rule, and no visual evolution beyond a stage counter on the debug overlay.
- One player character with 100 health, movement-only core play, no dash.
- One starting auto-fire weapon.
- Independent player health and independent Tower health with the Health Recovery Rules.
- Tower auto-fire defense.
- The Tower Interaction Radius, which disables the player's auto-fire at any speed while overlapped (see Tower Interaction Mechanics), and the Tower Console (non-pausing) with the vulnerability window.
- The Level-Up Draft (pausing) with three cards, at least one player and one Tower card per draft, one Reroll per run, no Banish.
- XP shards, the level curve, and the guaranteed first draft at the end of the first Siege (T4).
- Scrap drops, the run inventory with its 200 cap and FULL indicator (overflow discarded), Scrap loss on death.
- Three player upgrades (one of which restores health) and three Tower upgrades, the same six definitions available in both channels with shared ranks, plus Tower Repair in the Console.
- Three enemy target intents, one enemy type each, with the Intent Behaviour Defaults:
  - Tower Seeker (melee attacker with wind-up)
  - Player Hunter (with the leash rule)
  - Opportunist (with the event rule)
- Four encounter types from data:
  - Standard Assault
  - Split Assault
  - Siege (volume-based, no ranged Seeker)
  - Hunt
- The fixed prototype wave sequence: the four teaching waves (T1 Standard Assault, Hunters only; T2 Standard Assault with Seekers; T3 light Split Assault; T4 Siege, losable if ignored (author decision A2)) followed by combat wave 1 Hunt, combat wave 2 Siege, combat wave 3 Split Assault, and combat wave 4 a final heavy Siege capped at 120 enemies alive. Eight waves total; success is clearing the final wave — every enemy dead, both pools above zero; expected length 7 to 9 minutes.
- The Spawn Rings (Tower ring and view ring) with camera exclusion and spawn markers; no on-screen spawn exceptions (Ambush, Pincer, and Breach are excluded).
- The Pressure Metric with bounded de-escalation, the Overtime finisher rule, the inter-wave gap, the encounter priority order, and the post-draft grace period.
- Entity caps for enemies (300), pickups (150), and projectiles (400), enforced by the spawner.
- Object pooling for enemies, projectiles, pickups, and effects.
- SimClock, PauseAuthority, the pause triggers (pause menu, Draft, focus loss, and controller disconnect — which opens the pause menu in the prototype; the vertical slice replaces this with a reconnect prompt), and the Console non-pause exclusion.
- Contact damage, the same-frame death rule, Logical versus Visual death.
- Camera follow, lead, hard bounds; the directional Tower damage vignette and the off-screen Tower indicator; the Tower damage audio cue on the priority bus.
- The debug overlay and the Run Recorder.
- The run failure screen and the run success screen, each showing the death cause or wave reached, Scrap held, and time survived.
- Keyboard-and-mouse and gamepad input; hold-to-confirm in the Draft; sector selection in the Console behind the Movement-only controls setting.

The prototype must not include:

- Multiple biomes or any biome transition.
- Meta progression, Cores, the Meta Wallet, or the Hub.
- Persistent skill tree.
- Full economy or overflow-to-Cores conversion.
- Factory systems or Run-End Settlement.
- Bosses of any class; the final heavy Siege is the validation encounter.
- Grappling hook, evaluated separately as a spike, task P2.17; dash; or any other movement upgrade.
- Escort, Blackout, Breach, Ambush, Pincer, Duel, Elite, Environmental Event, Resource Rush, or Swarm Crush encounters.
- Environmental hazards of any kind.
- Weapon evolutions.
- Banish.
- Save system beyond temporary debug persistence.
- Tower visual evolution art (the stage counter exists; the art does not).
- Minimap.
- Advanced visual polish.

---

## Prototype Success Criteria

The prototype passes only if all of the following are true:

1. At least four out of five external testers identify that the Tower is a separate thing worth protecting (Tower relevance test).
2. At least four out of five testers describe a moment they could not protect both themselves and the Tower (Could-not-protect-both test).
3. At least four out of five testers name the decision that ended the run (Failure clarity test).
4. No static position remains safe indefinitely (Safe corner test).
5. The Tower is damaged if the player ignores it during a Siege (Tower neglect test), and a player hugging the Tower at 120 px with auto-fire disabled cannot hold a Siege (Siege test).
6. The player is punished if they orbit only around the Tower within the 120–480 px band (Orbit test, with its pre-agreed lever).
7. The game meets the performance rule during the heaviest prototype wave (Swarm performance test).
8. The Level-Up Draft pauses the simulation completely (Pause authority test) and the Tower Console never pauses it (Console non-pause test).
9. No enemy, pickup, projectile, or effect count ever exceeds the enforced caps, and enemies never exceed 300 (Entity cap test).
10. At least four out of five external testers describe the game as "protecting two things at once" without being prompted (Two things test).
11. No tester reports a death they could not have seen coming (Unseen death test).
12. No crash, softlock, or orphaned encounter state occurs (Stability check).
13. At least three out of five external testers want another run unprompted (Another run test). This criterion is gating.
14. Every other test tagged P in the Acceptance Test Matrix passes (G-tagged rows are gate records, not criteria).

If the prototype fails these criteria, the design must be revised before expanding content.

---

# Vertical Slice Scope Freeze

The vertical slice is the first production-quality proof that the game can be finished.

Until the vertical slice is complete, no new system may enter implementation unless it is listed below or explicitly approved as a replacement for an existing scope item, recorded as a freeze amendment in the Change Log. Decision D40 is itself the freeze amendment that added the items below marked with an asterisk (*) to the freeze first drafted after the prototype gate.

---

## Included in Vertical Slice

The vertical slice includes:

- One complete biome.
- One biome mechanical hook.
- One biome hazard.
- One Tower with four visual evolution stages driven by the rank thresholds.
- One player controller with movement-only core play plus one movement upgrade (dash).*
- One starting weapon.
- Three weapon evolution steps.
- Five enemy target intents:
  - Tower Seeker
  - Player Hunter
  - Opportunist
  - Zone Denier
  - Disruptor
- Eight base enemy types, including a ranged Tower Seeker.*
- Two elite affixes.
- One mini-boss.
- One biome boss.
- Eight encounter types:*
  - Standard Assault
  - Split Assault
  - Siege
  - Hunt
  - Elite Encounter
  - Mini-Boss Checkpoint
  - Boss Encounter (the Biome Boss)
  - Duel, when the Biome Boss reuses a mechanic (otherwise a Change Log waiver row)
- Ten player upgrades.
- Eight Tower upgrades.
- Run Currency (Scrap) and Meta Currency (Cores) with all three Core routes (field drops, overflow conversion, Run-End Settlement).
- Resource processing through the Tower: the Tower Console plus the overflow hopper, with no separate Factory resource-processing interface during a run.*
- A minimal Hub: one screen with Start Run and a Factory interface holding one skill node (15 Cores, adding a fourth Tower upgrade to the pool).*
- A save profile (single JSON file with a version field) sufficient to persist the Meta Wallet and the one unlock, with atomic write and corrupt-file fallback.*
- The status effect system.*
- One meta unlock unlocked after a failed run.
- The onboarding teaching sequence as defined, with the profile setting that compresses it.
- The Level-Up Draft with one Reroll per draft and Banish; the Tower Console.
- Directional Threat Feedback, the debug overlay, and the Run Recorder.
- Production art and audio for the biome, roster, and bosses in scope, including Tower evolution art for all four stages, boss telegraph cues, and one music track.*
- Object pooling and entity caps.
- Pause, upgrade draft, and focus-loss behavior.
- Controller support for movement-only play, including a reconnect prompt on disconnect.
- Reduced-effects accessibility setting.
- All mandatory acceptance tests from this document.

---

## Excluded from Vertical Slice

The vertical slice excludes:

- Multiple biomes.
- Full skill tree.
- Full factory system (beyond basic run-end settlement).
- Grappling hook, unless it passed the P2.17 spike and is added to the slice by a recorded freeze amendment.
- Escort encounters.
- Blackout encounters.
- Breach encounters.
- Ambush encounters.
- Pincer encounters.
- Environmental Event encounters.
- Resource Rush encounters.
- Swarm Crush encounters.
- A second Duel encounter, or any Duel beyond the one the composition rule requires.
- Cloud saves.
- Advanced audio adaptation.
- Localization (pseudo-localization testing only).
- Additional weapon classes beyond the slice weapon path.
- More than one biome boss.
- More than one mini-boss.
- More than two elite affixes.
- Additional resource types unless required by a mandatory system.

---

## Slice Exit Criteria

The vertical slice is complete only when:

1. A full run can be played from start to finish; for the slice a full run is eight waves, the Mini-Boss Checkpoint, and the Biome Boss, and run success is the Biome Boss defeated.
2. The biome boss can be defeated.
3. The run can fail through player or Tower death.
4. Meta progression is granted after failure.
5. All mandatory acceptance tests pass.
6. The build maintains the target performance budget during the heaviest encounter.
7. No known softlock, crash, or orphaned-entity state exists.
8. Documentation for every touched system is updated.
9. The core tension is still visible at slice-level content density.
10. Playtesters can answer the core playtest validation questions with specific answers.

If the slice requires new scope to become fun, that is a design warning. The core loop should become fun through selection, pressure, and readability, not through adding more systems.

---

# Development Status

Current Phase:

Pre-Production

Current Objective:

Prove the dual-entity core tension through a minimum playable prototype before expanding into full content production.

## Document-Ready Evidence

Every condition below has text in this document set that states it is met. A stated condition is not a verified one: per the Gate Approval rule, only the designer's Change Log row records the Document-Ready gate as passed, and this document does not write that row for itself.

| # | Document-Ready condition | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The core tension is testable without final content, and the mechanism (Tower Console vulnerability window, encounter set) is fully defined | Stated in text; awaiting independent verification and the designer's acceptance | Minimum Playable Prototype Gate (proof statement); Tower Console UI (docs/19); Encounter Types |
| 2 | The minimum playable prototype is defined with inclusion/exclusion rules, run length, success condition, and Provisional Defaults | Stated in text; awaiting independent verification and the designer's acceptance | Minimum Playable Prototype Gate › Prototype Scope, Prototype Success Criteria; Provisional Values Register |
| 3 | The Tower and player each have independent health pools with recovery rules and observable failure states | Stated in text; awaiting independent verification and the designer's acceptance | Tower Overview › Health Recovery Rules; Player Overview |
| 4 | Global pause, upgrade-screen, Console, focus-loss, and transition rules are defined and non-contradictory | Stated in text; awaiting independent verification and the designer's acceptance | Global Simulation Authority; SimLoop pause-flush order (docs/20) |
| 5 | The prototype has acceptance tests with a numeric pass condition and a milestone tag | Stated in text; awaiting independent verification and the designer's acceptance | Acceptance Test Matrix; Prototype Success Criteria; Development Phase Map |
| 6 | The vertical slice scope is frozen with every mandatory system in or out | Stated in text; awaiting independent verification and the designer's acceptance | Vertical Slice Scope Freeze |
| 7 | Every unresolved system question has a default rule, and any still open are listed | Stated in text; awaiting independent verification and the designer's acceptance | Default Unresolved-State Policies; Open Questions, below |
| 8 | Every content type that must be data-driven has a typed data contract | Stated in text; awaiting independent verification and the designer's acceptance | Content Data Contracts; Contract Field Semantics (docs/20) |
| 9 | Every edge-case register entry has an owning document | Stated in text; awaiting independent verification and the designer's acceptance | Documentation Structure; Edge Cases and Failure States |
| 10 | A Development Phase Map exists in which every task has a goal, inputs, dependencies, a deliverable, an acceptance test, an exit criterion, and an owning document | Stated in text; awaiting independent verification and the designer's acceptance | Development Phase Map (Phases 0–2); docs/29 (Phase 3–4 task tables) |

Status: each condition above is stated in text only; none carries independent verification or the designer's acceptance yet, and the Document-Ready gate is not recorded as passed until both occur.

**Prototype-phase readiness bar** (approved by the designer, 2026-09-14): the document set is prototype-phase ready when there are no contradictions anywhere in the document set, no open Major finding affecting Phases 0–2 (the Minimum Playable Prototype), no regressions against the round 3 findings ledger, and intent preservation is rated at least 8 of 10. Vertical-slice and production detail may remain as owned, tracked deferrals; see docs/29 › Deferred Review Findings. This document states the bar's definition; it does not evaluate itself against it.

## Build-Ready

None of the four Build-Ready conditions is satisfied, because no repository, project, or build exists yet. The next action is Phase 0 of the Development Phase Map. The work is split into 20 execution phases, each ending at a checkable gate and run through a supervised review loop; `phases/README.md` holds that table, the loop rules, and each phase's status, and `phases/PHASE_00_Environment_And_Connection` holds the phase in progress: prove the Godot ↔ agent connection in a sandbox (E0.1), install and verify Godot skills (E0.2), then the repository, the documentation skeleton, the project skeleton, and document 28.

## Open Questions

Design questions raised against this document that have a default rule but are not yet closed:

| Question | Default until resolved | Owner |
| --- | --- | --- |
| Does the health quadrant (Low pool) affect enemy selection? | No effect in the prototype or the vertical slice | 11 |
| Does the grappling hook enter production? | Evaluated as a spike of at most two days (P2.17) against four criteria; parked in document 30 if it fails or the spike is not approved | 04, 30 |
| Does the Biome Boss reuse a Duel-taught mechanic? | The slice includes one Duel unless the designer records a waiver in the Change Log (P3.11) | 10, 11 |
| Does "Mining" enter a biome's hook? | Parked in document 16 until a biome design calls for it | 16 |

## Approval For Full Production

The project is not approved for full production until:

1. The Minimum Playable Prototype passes its success criteria and the gate is recorded per the Gate Approval rule (Phase 2 exit).
2. Documents 00, 01, 02, 03, 05, 07, 09, 11, and 20 are stable as defined in Document Control (Phase 0 and Phase 3 tasks).
3. The Wave Director can produce at least four encounter types from data (Build-Ready 1).
4. Entity caps and pooling are tested under load (Build-Ready 2).
5. A version-controlled repository exists and every commit that changes a system's implementation also changes that system's document (Build-Ready 3).
6. All mandatory prototype acceptance tests pass (Build-Ready 4).
7. The grappling hook has been accepted through its P2.17 spike or moved to document 30 (Phase 2 decision).
8. The edge case register has no unresolved entry without an owner (re-checked at every gate).
9. The Vertical Slice Scope Freeze is accepted per the Gate Approval rule and its Slice Exit Criteria pass (Phase 3 exit).

Until those conditions are met, all new content is deferred.

---

# Development Phase Map

This section replaces the former "Immediate Next Steps". Every task carries the same fields: **ID · Goal · Scope (in / out) · Inputs (named sections of this document and deliverables of dependencies) · Depends on · Deliverable · Acceptance test · Exit criterion · Owner document · Size** (S under a day, M 2 to 4 days, L 1 to 2 weeks, XL more than 2 weeks). Tasks are listed in canonical ID order; tasks with the same dependencies may run in parallel regardless of listing order. A phase exits only when every task in it meets its exit criterion and the phase gate is recorded per the Gate Approval rule. Document 29 holds the expanded, status-tracked form of this map.

The Godot editor on the development machine is reachable from the AI collaborator's session through the Godot MCP tools (project listing, scene and node creation, script attachment, running the project, reading debug output). Document 28 defines how those tools are used; task E0.1 proves the connection in a sandbox and chooses the primary method and its fallback before P0.2 creates the real project, and their versions are pinned in P0.5. Execution of this map — phase by phase, with a supervised review loop — is tracked in `phases/`.

---

## Phase 0 — Foundations (no gameplay code)

| ID | Goal | Scope in / out | Inputs | Depends on | Deliverable | Acceptance test | Exit criterion | Owner | Size |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E0.1 | Prove and choose the agent-to-Godot control path | In: a written comparison of the ways an agent can drive Godot 4.7.1 (MCP servers driving the command line; MCP servers or editor plugins opening a localhost TCP or WebSocket bridge into the running editor and game; the built-in GDScript language server, Debug Adapter Protocol, and remote debugger ports; headless `--headless --script` runs; any newer approach found), the connection test matrix run in a throwaway sandbox, a chosen primary method and fallback, recorded failure behaviour and workarounds. Out: the real project, any port beyond localhost, any bridge addon installed outside the sandbox | `NEXT_SESSION.md` Prompt 2; docs/20 › Godot 4.x Implementation Standards (editor control from the AI collaborator); Risk Register (MCP server drift) | P0.3 | `docs/28.md` › Godot Connection, holding the matrix results with evidence; sandbox at `sandbox/connection_test`, outside the repository | none formal; every matrix row records pass or fail with evidence | Every matrix row has a recorded result, and a primary method and a fallback are named with their known failure modes | 28 | S |
| E0.2 | Install and verify Godot skills for Claude Code | In: comparison of candidate skill packages, a security read of every script and hook before installation, one primary skill plus at most one complementary skill, verification against the E0.1 sandbox. Out: any skill installed without a security read; marketplace commands, which only the designer types | `NEXT_SESSION.md` Prompt 3; E0.1 deliverable (sandbox and chosen method); P0.7's harness requirement | E0.1 | Installed skills recorded in `docs/28.md` with versions and verification results | none formal; verification is one successful use against the E0.1 sandbox | The chosen skill appears in the skill list after a restart and completes one task against the sandbox, and the security read is recorded | 28 | S |
| P0.1 | Put the project under version control | In: git init, .gitignore for Godot (the E0.1 sandbox is excluded as throwaway scaffolding), first commit of this file as 0.8.1 together with `docs/`, `CLAUDE.md`, `NEXT_SESSION.md` and `phases/` (earlier master versions were deleted on 2026-09-14 at the author's request; the Review Decision Log quotes every 0.5.0 sentence it changed). Out: CI. Remote hosting moved into scope by decision D79 | None (first task) | none | Repository at `D:\Gamedev` with one commit | none (Build-Ready 3 becomes enforceable) | `git log` shows the 0.8.1 commit | 28 | S |
| P0.2 | Create the Godot 4.7.1 project skeleton | In: `project.godot` (records engine version 4.7), folder layout, the 16-layer binding table, input map incl. number keys 1–7 and debug toggles, 4.7.1 export templates and a boot check confirming `Engine.get_version_info()` reports 4.7.1, Windows release export of an empty scene. Out: any scene content | P0.1 deliverable (repository); P0.3 deliverable (documentation skeleton the folder layout follows); E0.1 deliverable (the proven method the project is created and controlled through) | P0.1, P0.3, E0.1 | Empty project that opens without errors and exports a release build | Settings check (P0.2) | Project opens; layer names match the binding table; project.godot records engine version 4.7 while the boot check confirms 4.7.1; empty scene exports to a Windows release build | 20 (consults 23) | S |
| P0.3 | Create the documentation skeleton | In: `docs/00..30.md` stubs for the 26 documents that do not exist yet, each with title, remit, and "Owns:" list copied from the Documentation Structure, version 0.1.0 header; docs 09, 11, 19, 20, and 29 keep their content and gain the stub header fields. Out: content beyond the stub | P0.1 deliverable (repository); Documentation Structure | P0.1 | 26 new stub files; docs 09, 11, 19, 20, 29 gain stub header fields over their existing content | none formal | Every register entry's owner file exists | 28 | S |
| P0.4 | Write documents 00, 01, 02 to stable | In: vision, pillars, loop with the Structure Hierarchy, run termination cases, boss cadence, onboarding edge cases. Out: system detail | docs/00–02 stubs (P0.3); Game Overview, Core Gameplay Loop | P0.3 | `docs/00.md`, `docs/01.md`, `docs/02.md` at 1.0.0 | none formal | Self-review against this file finds no contradiction; doc lint: zero placeholders; every Owns entry has a resolved or accepted row; Change Log row "00/01/02 stable" | 00 (consults 01, 02) | M |
| P0.5 | Write document 28 (AI workflow) to 1.0.0 | In: how the AI collaborator uses the Godot MCP tools and their pinned versions, the primary and fallback connection method with their failure modes (E0.1), any installed Godot skill with its version and verification result (E0.2), the same-commit rule, the review cadence, the Gate Approval rule. Out: tooling beyond what exists | P0.3 deliverable (stub); E0.1 deliverable (chosen method and matrix); E0.2 deliverable (installed skills); Document Control (Gate Approval rule) | P0.1, P0.2, P0.3, E0.1, E0.2 | `docs/28.md` at 1.0.0, pinning both Godot MCP server versions and any installed skill | none formal | Every rule in it is enforceable with the tools present; doc lint: zero placeholders; every Owns entry has a resolved or accepted row; committed | 28 | S |
| P0.6 | Write the data contract schemas | In: one `Resource` script per prototype contract — Enemy, Encounter, Wave, Upgrade, Tower, Tower Upgrade, Weapon, Pickup, Player, Director Configuration, Economy Configuration — with typed exports. Out: content instances; the remaining contracts (Biome, Boss, Elite Affix, Status Effect) are typed before Phase 3 | P0.2 deliverable (project skeleton); Content Data Contracts › Contract Field Semantics | P0.2 | `src/data/*.gd` schemas | Schema check (P0.6) | Every prototype contract field has a typed export; scripts load with no errors | 20 | M |
| P0.7 | Test harness | In: gdUnit4 headless via the pinned Godot executable. Out: authored gameplay tests | P0.2 deliverable (project skeleton); Acceptance Test Matrix › Build Checks | P0.2 | Configured gdUnit4 harness | Harness check (P0.7) | A trivial test runs headless and reports pass/fail | 20 | S |

Phase 0 exit: E0.1, E0.2, and P0.1 to P0.7 complete; Change Log row "Phase 0 accepted" per the Gate Approval rule.

---

## Phase 1 — Technical Foundations (the swarm test closes the phase)

| ID | Goal | Scope in / out | Inputs | Depends on | Deliverable | Acceptance test | Exit criterion | Owner | Size |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P1.1 | SimClock, SimLoop, PauseAuthority, keyed RNG, banned-API grep check | In: physics-tick clock, time_scale cap, SimLoop fixed tick order, reason-set pause, process-mode mapping, keyed RNG helpers, a grep check banning `get_tree().create_tween()` and `create_timer()` calls under the gameplay root. Out: UI | P0.2 deliverable (project skeleton); P0.7 deliverable (harness); Global Simulation Authority | P0.2, P0.7 | `src/core/sim_clock.gd`, `sim_loop.gd`, `pause_authority.gd` | Keyed RNG unit check (P1.1); Pause clock unit check (P1.1) | `SimClock.now` stops under pause and resumes exactly; keyed rolls identical 10/10; grep finds zero banned calls | 20 | S |
| P1.2 | EventBus and query interfaces | In: EventBus signal list, `EntityRegistry` with radius queries, `CombatStats` (reports sheet DPS), typed commands. Out: consumers | P0.2 deliverable; P1.1 deliverable (SimClock for timestamps); docs/20 › Godot 4.x Implementation Standards | P0.2, P1.1 | `src/core/event_bus.gd`, `entity_registry.gd`, `combat_stats.gd` | Registry query check (P1.2; one radius query < 0.05 ms at 300 entities) | Query passes the timing bound; committed with document 20 section | 20 | S |
| P1.3 | Object pools and all six caps | In: pools for enemies, projectiles, pickups, effects; cap enforcement (enemies 300, pickups 150, projectiles 400, damage numbers 30, telegraphs 40, VFX 24) in the spawner API; container nodes under the gameplay root. Out: content | P1.2 deliverable (EntityRegistry) | P1.2 | `src/core/pool.gd`, gameplay root scene | Cap unit check (P1.3; scripted spawner never exceeds each cap); Pool unit check (P1.3; 10,000 acquire/release cycles, object count stable ±1%) | All six caps hold in a stress script | 20 | M |
| P1.4 | Debug overlay, Run Recorder, pseudo-localization toggle | In: every field under the debug overlay and Run Recorder rules; CSV export; run seed; pseudo-localization toggle (expansion ratio 0.3). Out: analysis tooling | P1.1 deliverable (SimClock); P1.2 deliverable (EventBus) | P1.1, P1.2 | `src/debug/overlay.tscn`, `run_recorder.gd` | Recorder schema check (P1.4) | Overlay shows all fields; `ticks.csv` and `events.csv` written per run matching the schema | 20 | M |
| P1.5 | Collision layers, hitbox/hurtbox framework, death state | In: the 16-layer binding table applied, hitbox and hurtbox components, deferred disabling on Logical Death, the Logical/Visual death state machine on a placeholder enemy. Out: enemy behaviour | P1.3 deliverable (pools) | P1.3 | `src/combat/hitbox.gd`, `hurtbox.gd`, `death_state.gd` | Ghost hit test (P1.5) | 100 mid-attack kills produce zero post-death damage events | 20 (consults 05) | M |
| P1.6 | Audio bus layout and AudioPool | In: six buses (Music, SFX, SFX_Priority, TowerCue, UI, Ambience; C-TOWERCUE), ducking on a `PROCESS_MODE_ALWAYS` node, 32-voice AudioPool with priority stealing. Out: sound content | P0.2 deliverable (project skeleton); docs/20 › Audio Mixing & Dynamic Ducking | P0.2 | Bus layout resource, `src/audio/audio_pool.gd` | Audio priority check (P1.6) | Priority cue steals a voice and remains audible in 5 of 5 trials | 26 | S |
| P1.7 | Swarm stress test | In: 300 placeholder enemies with `CharacterBody2D` moving toward a point, 400 projectiles, 150 pickups, measured on the reference machine; adopt the first passing Performance Fallback Ladder step if the base case fails. Out: gameplay | P1.3, P1.4, P1.5 deliverables; Performance Fallback Ladder | P1.3, P1.4, P1.5 | Stress scene and a recorded result in document 20 | Swarm performance test (P1.7 soak with 300 placeholder enemies) | Either the base case passes the performance rule, or the Performance Fallback Ladder step that passes is recorded and adopted; if step 4 also fails, the design is revised (fewer simultaneous enemies per wave), the change is recorded in the Review Decision Log, and the test repeats | 20 | M |

Phase 1 exit: all P1 tasks complete, Swarm performance test passed at a recorded ladder step; Change Log row "Phase 1 accepted" per the Gate Approval rule. Build-Ready 2 is now true.

---

## Phase 2 — Core Tension Prototype (the Minimum Playable Prototype)

| ID | Goal | Scope in / out | Inputs | Depends on | Deliverable | Acceptance test | Exit criterion | Owner | Size |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P2.1 | Player controller | In: movement, acceleration/stop times, health, hurtbox, input buffer, contact damage receipt, death. Out: dash, weapons | P1.5 deliverable (hitbox/hurtbox, death state) | P1.5 | `scenes/player.tscn`, `src/player/*.gd` | Player movement check (P2.1); Player silhouette test (P2.1) | Movement-only run through an empty arena at reference speed and acceleration | 03 | M |
| P2.2 | Arena and camera | In: 4800×3200 arena, hard walls, no interior obstacles, camera follow, lead, zoom rules, hard bounds. Out: art | P2.1 deliverable (player to follow) | P2.1 | `scenes/arena.tscn`, `src/camera/game_camera.gd` | Camera bounds test (P2.2) | Sweep passes at every view scale (0.9 to 1.15) | 27 (consults 20) | S |
| P2.3 | Handgun and auto-targeting | In: one auto-fire weapon, nearest-target re-pick every shot, projectile pooling, damage by value at fire time. Out: evolutions | P2.1 deliverable (player); P1.5 deliverable (hitbox framework); P0.6 deliverable (typed schemas) | P2.1, P1.5, P0.6 | `data/weapons/handgun.tres`, `src/combat/auto_weapon.gd` | Weapon check (P2.3) | Kills placeholder enemies at the sheet DPS; no targeting input exists | 06 (consults 05) | M |
| P2.4 | Tower | In: health, shield, footprint, Targeting Rule, base weapon, Interaction Radius trigger, death, stage counter. Out: evolution art, drones | P2.3 deliverable (weapon pattern to mirror); P2.2 deliverable (arena); P0.6 deliverable (typed schemas) | P2.3, P2.2, P0.6 | `scenes/tower.tscn`, `src/tower/*.gd`, `data/tower/base.tres` | Tower weapon check (P2.4); Same-frame death test (P2.4); Health recovery check (P2.4) | Tower fires, takes damage, dies, ends the run; a same-tick zero-zero is credited to the Tower | 07 | M |
| P2.5 | Three enemies, one per intent | In: Seeker, Hunter, Opportunist as `.tres` with Intent Behaviour Defaults, telegraphs, contact damage, seek-and-separation steering and attack slots (docs/09), stuck rules. Out: elites, archetypes | P1.5 deliverable (hitbox framework); P2.4 deliverable (Tower to threaten); P0.6 deliverable (typed schemas) | P1.5, P2.4, P0.6 | `data/enemies/*.tres`, `src/enemy/*.gd` | Leash test (P2.5); Opportunist test (P2.5); Stuck exemption test (P2.5) | Each intent behaves per its default in a scripted arena | 09 | L |
| P2.6 | HUD and threat feedback | In: both health bars, Scrap readout, XP bar, vignette with the two pointing rules, off-screen Tower indicator, Tower damage cue on the priority bus, placeholder VFX, damage numbers, and a debug effect spawner. Out: minimap | P2.4 deliverable (Tower health/shield); P1.6 deliverable (AudioPool) | P2.4, P1.6 | `src/ui/hud.gd`, `src/ui/threat_feedback.gd` | Tower cue audibility check (P2.6) | HUD fields readable at 1080p; cue audible over concurrent sounds | 19 (consults 26, 27) | S |
| P2.7 | Feel check | In: hand-placed enemies, one per intent, no Wave Director; the designer and the AI collaborator's scripted bots only (internal testers) play and record a go/adjust decision; no person who plays it may take part in P2.16. Out: automated pacing — restores the original "prove the core tension is fun with one enemy per intent" step | P2.5 deliverable (enemies); P2.6 deliverable (HUD/feedback) | P2.5, P2.6 | Recorded go/adjust decision in document 29 | Feel check (P2.7, designer and scripted bots, recorded go/adjust) | "Go" recorded, or the named adjustment is made and the check repeats | 29 | S |
| P2.8 | Wave Director: data, rings, runtime model, prototype sequence, Siege warning | In: Wave and Encounter resources, the two Spawn Rings, camera exclusion, spawn markers, validation, directional weighting, priority and recovery gaps, inter-wave gap, grace period, the Wave Runtime Model (stall, Overtime, carry-over, final-wave rule), the fixed prototype wave sequence as data, the Siege warning. Out: Pressure Metric | P2.2 deliverable (arena/camera); P2.5 deliverable (enemies); P2.7 deliverable (go decision); P1.4 deliverable (overlay fields); P0.6 deliverable (typed schemas) | P2.2, P2.5, P2.7, P1.4, P0.6 | `src/director/wave_director.gd`, `data/encounters/*.tres`, `data/waves/*.tres` | Spawn ring test (P2.8); Split Assault test (P2.8); Hunt test (P2.8); Encounter recovery test (P2.8); Wave runtime test (P2.8); Overtime test (P2.8) | 1000 scripted spawns valid; all four prototype encounter types load from data; a scripted stall triggers Overtime | 11 | L |
| P2.9 | Pressure Metric | In: threat and capacity formulas, escalation, bounded de-escalation, health-quadrant logging. Out: quadrant-aware selection | P2.8 deliverable (Wave Director) | P2.8 | Pressure fields on `src/director/wave_director.gd`, overlay fields | Pressure test (P2.9) | Scripted threat and capacity inputs reproduce the documented Pressure value within tolerance | 11 | M |
| P2.10 | Pickups, drop table, cap | In: pickup pool, magnet with raycast blocking, acceleration, merge, lifetime, the Drop Table, run inventory cap with FULL indicator, Scrap loss on death. Out: Cores | P1.3 deliverable (pools); P2.1 deliverable (player collector); P2.5 deliverable (enemies to drop) | P1.3, P2.1, P2.5 | `src/pickup/*.gd`, `data/pickups/*.tres` | Pickup physics test (P2.10) | Cap holds; blocked pickups stop instead of sliding; death zeroes carried Scrap | 16 (consults 14) | M |
| P2.11 | Six upgrades and fallback cards | In: three player and three Tower upgrades as `.tres` with max rank, shared ranks, pool ownership; the two fallback cards. Out: weapon upgrades | P0.6 deliverable (schemas); P2.3 deliverable (weapon); P2.4 deliverable (Tower) | P0.6, P2.3, P2.4 | `data/upgrades/*.tres`, `src/upgrade/upgrade_system.gd` | Upgrade effect check (P2.11) | Ranks apply from either channel and cap correctly at rank 3 | 17 | M |
| P2.12 | Level-Up Draft | In: level curve, queueing, central panel, three cards with one-of-each guarantee, differentiation, keyboard, gamepad, hold-to-confirm, one Reroll per run, guaranteed first draft after T4, full pause, the grace period including the spawn-group block. Out: Banish | P2.10 deliverable (XP); P2.11 deliverable (upgrades); P2.8 deliverable (Wave Director, for the grace period hook); P1.1 deliverable (PauseAuthority) | P2.10, P2.11, P2.8, P1.1 | `scenes/ui/draft.tscn`, `src/ui/draft.gd` | Draft queue test (P2.12); Draft input lockout test (P2.12); Guaranteed first draft test (P2.12); Encounter deferral test (P2.12); Determinism test (P2.12); XP cap check (P2.12) | Draft resolves with movement input alone; no encounter or spawn group opens during the grace period | 13 (consults 19) | M |
| P2.13 | Tower Console | In: dwell open, auto-close, catalogue with prices, Repair, auto-fire disable, non-pause, differentiation, all input schemes including sector selection behind the Movement-only controls setting. Out: consumables | P2.10 deliverable (Scrap); P2.11 deliverable (upgrades); P2.4 deliverable (Tower); P2.12 deliverable (Draft, for the mutual-exclusion rule) | P2.10, P2.11, P2.4, P2.12 | `scenes/ui/console.tscn`, `src/ui/console.gd` | Console non-pause test (P2.13); Console rules test (P2.13); UI scaling test (P2.13); Interaction window test (P2.13 scripted) | Buying under attack works, costs the 0.5 s channel, and never pauses the simulation | 19 (consults 07) | M |
| P2.14 | Run flow | In: T4 tuning, pause menu, settings menu with the Movement-only controls toggle, run-end screens, focus-loss pause (including the harness's `--no-focus-pause` flag and a controller-disconnect trigger), temporary debug persistence. Out: save system | P2.9 deliverable (Pressure, for T4 tuning); P2.12, P2.13 deliverables (menus that must coexist with run flow); P2.6 deliverable (HUD, for run-end summaries) | P2.9, P2.12, P2.13, P2.6 | `data/waves/prototype_sequence.tres`, `scenes/ui/run_end.tscn`, pause/settings menus | Focus loss test (P2.14); Movement-only test (P2.14); Teaching Siege tuning check (P2.14); Scrap loss test (P2.14); HUD layout check (P2.14); Pause authority test (P2.14 full); Run flow check (P2.14) | A no-player T4-only run destroys the Tower before T4 ends in at least 3 of 5 seeds, and a run with a bot that responds to the Siege warning keeps the Tower above 50%; a developer run reaches wave eight or dies with a recorded cause | 19 (consults 11) | M |
| P2.15 | Internal acceptance pass | In: every scripted P-tagged test run by the developer, including bots (orbit bot, roam bot, far/still Siege bots); results recorded in document 29. Out: external testers | P2.14 deliverable (full run flow); P1.7 deliverable (fallback step adopted) | P2.14, P1.7 | Test log in document 29; 10 fixed stills from designer-recorded runs and their answer key | Tower neglect test; Player neglect test; Split choice test; Safe corner test; Orbit test; Siege test; Standard Assault test; Entity cap test (P2.15; counts ≤ caps, enemies ≤ 300, across every P2.15 run); Swarm performance test (combat wave 4 as budgeted, ≤ 120 alive; the 300-enemy soak result stays P1.7's); Object pooling test (compares first and last combat wave); Stability check — all P2.15 | Zero failing scripted tests | 29 | M |
| P2.16 | External playtest | In: recruit 5 external testers never exposed to earlier builds, session script, Windows release build, collect telemetry CSVs; fresh testers on any repeat. Out: fixes | P2.15 deliverable (test log); Prototype Success Criteria | P2.15 | Playtest report in document 29 | Failure clarity test; Tower relevance test; Threat visibility test; Health pool danger test; Cost of movement test; Effect density test; Audio clarity test (Tower cue); Could-not-protect-both test; Unseen death test; Two things test; Another run test; Stability check — all P2.16; Interaction window test (observed) | Prototype Success Criteria 1 to 14 pass, or the failing criterion is named with the design change it demands | 29 | M |
| P2.17 | Grappling hook spike | In: a spike of at most two days against the four Grappling Hook Evaluation Criteria. Out: production integration | P2.16 deliverable (prototype gate outcome) | P2.16 | Spike build and a recorded verdict | Grappling criteria review (P2.17, G) | All four criteria met and the spike stayed within two days, or the hook is moved to document 30 | 04 (consults 30) | S |
| P2.18 | Gate decision rows | In: the prototype gate decision, the grappling hook go/no-go, the confirmed Performance Fallback step. Out: slice work | P2.16 deliverable (playtest report); P2.17 deliverable (spike verdict) | P2.16, P2.17 | Change Log rows | Gate record check (P2.18, G) | Rows recorded per the Gate Approval rule | 29 (consults 04) | S |

Phase 2 exit: Prototype Success Criteria pass and are recorded per the Gate Approval rule; Build-Ready 1, 2, and 4 are true. If the prototype fails, the design is revised in this file first and Phase 2 repeats from the changed task. Only then does vertical slice content work begin.

---

Phase 3 (Vertical Slice) and Phase 4 (Production) task tables live in `docs/29_Milestones_and_Roadmap.md`, which also tracks progress against this map and lists review findings deferred past the prototype. This document keeps Phases 0 to 2: the tasks that build and validate the Minimum Playable Prototype.


---

# Provisional Values Register

Every Provisional Default in this document, with its owner document. This table is the only complete list of gameplay numbers; a change to any value is one commit that updates this Register and every section stating the value, and an intent-altering change also gets a row in the Review Decision Log.

## Engine & Platform

| Value | Default | Owner document |
| --- | --- | --- |
| Engine version | Godot 4.7.1 stable | 20 |
| Platform | Windows 10/11 x64 primary; Linux/macOS untested before the slice | 20 |
| Physics | 60 ticks/s, max 8 steps/frame, physics interpolation off (prototype) | 20 |
| Viewport | 1920 × 1080, stretch mode canvas_items, aspect keep (letterbox) | 20, 27 |
| Vsync | On in play, off for performance tests | 20 |
| Reference machine | Ryzen 5 4600H (6C/12T), GTX 1650 Ti 4 GB (NVIDIA GPU selected; hybrid with Radeon iGPU), 15.4 GB RAM, 1080p; exported release build, vsync off, 60 s logged to CSV | 20 |
| Performance rule | Median ≥ 60 FPS and 1st-percentile ≥ 45 FPS during the heaviest in-scope encounter | 20 |
| Test harness | gdUnit4, headless via `Godot_v4.7.1-stable_win64_console.exe --headless` | 20, 28 |

## Arena & Camera

| Value | Default | Owner document |
| --- | --- | --- |
| Perspective | Three-quarter top-down 2D, collision circles at the feet, Y-sort by foot position; player drawn above enemies; no jump | 03, 27 |
| Arena size | 4800 × 3200 px (wider than tall), Tower at centre, hard walls on ArenaBounds, no interior obstacles in the prototype | 15 |
| Player start position | 240 px south of Tower centre | 03, 15 |
| Traversal time | 15 s east–west, 10 s north–south at base speed | 15 |
| View scale | 1.0 = 1920×1080 world px; range 0.9 to 1.15; Godot `Camera2D.zoom = 1 / view scale` | 27 |
| Zoom trigger 1.15 | Player speed > 1.5× base, OR Tower loses ≥ 10% max (health+shield) within 2 s; held 3 s then eases back | 27 |
| Zoom 0.9 (corridor trigger) | Boss sub-regions / corridor biomes only | 27 |
| Zoom ease | 0.4 s | 27 |
| Prototype zoom scope | Only 1.0 and the Tower-damage 1.15 trigger | 27 |
| Arena-to-view ratio | Arena ≥ 1.4× largest view per axis (2.2× and 2.6×) | 15, 27 |
| Camera lead | Velocity × 0.25 s, max 120 px | 27 |
| Position smoothing speed | 8 | 27 |
| Screen shake | Max 12 px, decaying over 0.25 s | 27 |
| Lead/shake application | Applied to position before the arena clamp, never via `Camera2D.offset` | 27 |

## Player & Weapons

| Value | Default | Owner document |
| --- | --- | --- |
| Player health / speed / accel / stop | 100 HP; 320 px/s (reference 1.0); full speed in 0.08 s; stop in 0.05 s | 03 |
| Player body / hurtbox / collector / magnet | Body radius 14; hurtbox = body; collector area radius 22 (body + 8); magnet radius 96 | 03, 16 |
| Input buffer | 100 ms (6 ticks), cleared on pause | 03, 19 |
| Handgun (Starting Weapon) | 10 dmg/shot, 2 shots/s (20 DPS), range 260 px, nearest re-picked every shot, projectile 1000 px/s | 06 |

## Tower

| Value | Default | Owner document |
| --- | --- | --- |
| Tower health / shield / regen | 500 HP; base shield 25% (125); regen 10%/s after 8 s, delay restarts on every hit including the breaking hit | 07 |
| Tower footprint / Interaction Radius | 106 px / 160 px | 07 |
| Tower base weapon | 20 dmg × 1.25 shots/s (25 DPS), range 480 px, projectile 900 px/s; targets the nearest Tower Seeker in range, else the nearest enemy in range; drops a non-Seeker target on the tick a Seeker enters range; otherwise retargets only when its target dies or leaves range (C-TOWERTARGET); idle holds fire | 07 |
| Tower HP regen | None passive; Repair only | 07 |
| Tower Console dwell / auto-fire | Console opens after 0.3 s below 10% base speed inside the Interaction Radius with ≥ 1 affordable entry; player auto-fire disabled at any speed while overlapping the radius, Tower keeps firing (C-AUTOFIRE; see docs/19 Tower Console UI) | 19 |
| Tower evolution thresholds | 0 / 1 / 3 / 6 ranks (Base / Reinforced / Armed / Fortress) | 07 |
| Tower Repair price | Affordable when the Tower is missing ≥ 2 health and the player holds ≥ 1 Scrap; one purchase restores min(50, missing health rounded down to an even number, 2 × Scrap held) health at 1 Scrap per 2 health; at 0 Scrap, Repair is greyed and does not count toward opening the Console (C-REPAIR) | 07 |

## Enemies

| Value | Default | Owner document |
| --- | --- | --- |
| Tower Seeker | Speed 0.55× (176 px/s); 60 HP; body radius 14; melee 15 dmg per 1.5 s cycle (10 DPS), 0.4 s wind-up, reach 20 px; Contact None; body-block after 2 s blocked with player in reach attacks player (15) without changing intent; intent weight 1.25 | 09 |
| Player Hunter | Speed 0.85× (272 px/s); 30 HP; radius 12; Contact 8 dmg per 0.5 s tick (16 DPS), player only; leash 20 s without reset → 0.5 s telegraph → converts to full Tower Seeker profile keeping current HP; intent weight 1.0 | 09 |
| Opportunist | Speed 0.70× (224 px/s); 45 HP; radius 14; melee 10 dmg per 1.2 s cycle (≈8.3 DPS), 0.4 s wind-up, reach 20; Contact None; event rule: damaged by other target, target outside 400 px for 3 s, or target dies; switch needs ≥ 25% closer target and ≥ 3 s since last switch; intent weight 1.1 | 09 |
| All enemies | No contact damage to the Tower; contact hitbox radius = body + 6; body contact exempt from wind-up minimums; telegraph minimums melee 0.4 s, ranged 0.8 s; a surrounded player is intentionally trapped | 09 |
| Stuck rules | 3 s without shrinking distance (< 8 px) → secondary target or direct approach; 8 s with < 8 px displacement → direct approach; 20 s → despawn with drops, counted as removed, not a kill | 09 |
| Stun diminishing returns | Each stun within 5 s is 50% of the previous, floor 0.1 s, 2 s immunity after the third | 05, 09 |
| Standard enemy | Any enemy spawned from an encounter's spawn groups that is not an elite, boss, Overtime finisher, or Splitter child | 09, 11 |

## Combat Rules

| Value | Default | Owner document |
| --- | --- | --- |
| %-max-HP damage | Never multiplied by crits, capped 20% max HP per hit | 05 |
| Revive | 2 s invulnerability flag on Health (hurtbox stays on so pickups collect) plus a camera zoom-in (camera effect only) | 05, 27 |
| XP & levels | 1 XP shard per standard enemy; start level 0; level L→L+1 costs 10 + 5(L+1) XP (15, 20, 25…), remainder carries | 13 |
| Teaching wave XP (C-XPCAP) | Shards still collected during T1–T4, but XP above 14 is discarded so no level-up fires; the forced first Draft when T4 ends grants level 1 at no XP cost, and the XP held counts toward level 2 | 13, 02 |

## Spawning & Waves

| Value | Default | Owner document |
| --- | --- | --- |
| Biome sequence | 8 combat waves; Mini-Boss Checkpoint after combat wave 4; Biome Boss after combat wave 8; T1–T4 before combat wave 1 of a run's first biome | 11, 02 |
| Prototype sequence | T1–T4 then combat waves 1–4, no boss waves ("eight waves") | 11 |
| Spawn group | {enemy definition (Enemy ID), count (int), start offset (float s from encounter open), spawn interval (float s between individual spawns), direction weighting override (nullable)} (C-GROUPS); a group starts at its offset or earlier if the Escalation Trigger starts it, groups with equal offsets run concurrently, the Escalation Trigger does nothing in a Siege; a lane split assigns ceil(0.6 × n) spawns to the heavier lane, alternating by spawn index | 11 |
| Wave spawn budget | Sum of its groups' cap weights (derived, not authored) | 11 |
| Encounter completion | All groups emitted and every enemy the encounter spawned is dead or removed; the objective for Standard Assault, Split Assault, Siege, Hunt (these four carry no reward) | 11 |
| Teaching wave runtime (C-TEACH) | T1–T4 end at their maximum duration or when every enemy they own is dead, whichever comes first; they never run the stall rule, Overtime, or escalation; spawn groups start at their listed start offsets; survivors carry over as for combat waves | 11 |
| Wave end / STALLED (non-final combat waves) | At maximum duration the stall check runs once: kills in the last 30 s (excluding finishers) below the stall threshold (5) starts Overtime and the wave continues until every non-finisher enemy it owns is dead, then remaining finishers despawn without drops; otherwise the wave ends and its living enemies carry over, counting against the enemy cap but not the next wave's spawn budget (C-STALL) | 11 |
| Overtime finishers | Player Hunters at 25% Hunter HP, 160% Hunter speed, 2 per 5 s on the view ring; exempt from de-escalation, no leash timer, the finisher flag survives any conversion; count against the 300 enemy cap and throttle like any spawn — the cap is never exceeded (C-OVERTIME-CAP); drop 1 XP, no Scrap; excluded from the stall count | 11 |
| NOT STALLED carry-over | Survivors carry over, count against the enemy cap, not against the next wave's spawn budget; the next wave still emits its first group on schedule | 11 |
| Final combat wave rule (C-FINAL) | Adopts every living enemy when it opens; ends only when the EntityRegistry live-enemy count is zero; after its maximum duration the stall check re-runs every 0.5 s until Overtime starts; prototype run success = the wave ending with both pools above zero | 11 |
| Partial reward (C-PARTIAL) | An encounter whose win condition becomes impossible self-resolves with half its reward rounded down; an encounter with no reward grants nothing | 11 |
| Inter-wave gap | max(8 s default (5 s after T1, T2, T3), the last encounter's recovery gap); no spawn group starts during a gap | 11 |
| Grace period (C-GRACE) | 1.5 s after a Level-Up Draft closes: no encounter opens, no spawn group starts; only Wave Director deadlines (spawn-group start offsets, the next emission of an emitting group, inter-wave gaps, recovery gaps) extend by 1.5 s — every other gameplay deadline runs normally | 11, 13 |
| Completion counting | Via EntityRegistry tag queries, never counters | 11, 20 |
| Encounter-level alive cap | e.g. 120 in heavy Siege; throttles like the global cap | 11 |
| Priorities & recovery gaps | Siege 80 / 10 s; Split Assault 60 / 8 s; Hunt 40 / 8 s; Standard Assault 20 / 5 s; when two encounters are due at the same moment, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap (C-DEFER) | 11 |
| Spawn Rings | Tower ring (Tower Seekers) / view ring (Hunters, Opportunists, finishers); both inner radius ≈ 1331 px (largest-view half-diagonal + 64), width 128 px (outer ≈ 1459), clipped to arena inset 32 px | 11 |
| Camera exclusion | Reject a candidate inside view + 64 px margin or inside the Interaction Radius; the 2208 px-wide view is narrower than the ring's ≈ 2660 px inner diameter, so some arc is always outside view | 11 |
| Ring validation | Shift along the ring, alternating directions, up to 8 steps of 10°; none valid → retry next tick without using budget; after 8 consecutive failed ticks, ignore direction weighting and take the nearest valid point; if that ring has none, use the other ring | 11 |
| Off-screen spawn markers | One screen-edge marker per spawn group per 30° sector; a spawn marker appears 0.75 s before its spawn, with position rolled and validated at the marker and re-validated at spawn; counts as one telegraph | 11 |
| On-screen spawn exceptions | Ambush, Pincer, Breach; markers ≥ 1.0 s; on-screen spawn minimum distance = min(2 s of player travel, 0.8 × the view's half-height); Breach warning 15 s | 11 |
| Directional weighting | Standard Assault uniform on each ring; Split Assault two 40° lanes on the Tower ring, fixed when the encounter opens, prototype lane centres 180° apart (from the vertical slice, separation = max(120°, the angle whose arc at the Tower's 480 px weapon range the player covers in 6 s at maximum speed with upgrades)), 60% heavier lane / 40% lighter, Opportunists split the same way on the view ring; spawn validation shifts stay inside the lane's sector, a spawn with no valid point waits with its budget unused (C-LANES); Siege uniform on the Tower ring; Hunt 80% inside a 120° view-ring arc pointing away from the Tower (centred on bearing Tower→camera centre; if camera centre is within 240 px of the Tower, centred on the player's last movement direction; else a keyed RNG roll), 20% uniform | 11 |
| Attack slots (C-SLOTS) | N = floor(2π × (target radius + attacker body radius + reach) ÷ (2 × attacker body radius + 4)), evenly spaced; Tower vs Tower Seekers: 27; player vs Player Hunters (reach = contact hitbox margin 6 px): 7; an enemy claims the nearest free slot within 64 px of the ring, else waits 32 px outside accruing no stuck time; steering = seek toward the claimed slot (or the target when none is claimed) plus separation from EntityRegistry neighbours within 32 px, computed inside SimLoop; the prototype uses no NavigationAgent2D | 09 |

## Pressure & Overtime

| Value | Default | Owner document |
| --- | --- | --- |
| Threat formula | threat_i = current_hp_i × intent_weight_i × (dps_i ÷ 10) for living non-dying enemies, where dps_i is the enemy's sheet DPS from its Attack profile (C-PRESSURE); weights Hunter 1.0, Seeker 1.25, Opportunist 1.1; Threat = Σ | 11 |
| Capacity formula | Sheet DPS of the player and the Tower with their current upgrades (not measured actual damage; the player term is not zeroed while the Console is open) (C-PRESSURE) | 11 |
| Pressure formula | Threat ÷ (Capacity × 20 s), dimensionless (1.0 ≈ 20 s to clear; 0.6 ≈ 12 s; 1.8 ≈ 36 s); 0 with no enemies; evaluated every 0.5 s only while a combat wave (not a teaching wave) is open and outside the grace period | 11 |
| Escalation | Pressure < 0.6 for 3 s → the current encounter's next group starts; ≥ 4 s between escalations; no-op when no group remains | 11 |
| De-escalation | Pressure > 1.8 doubles spawn intervals; lifts < 1.2; expires after 10 s; 6 s re-arm lockout; never in Siege or Overtime | 11 |
| Health quadrant | Pool Low when health (shield excluded) < 40% max; recorded at each escalation decision; no effect on selection in the prototype or the slice (open question for doc 11) | 11 |

## Encounter Budgets

| Value | Default | Owner document |
| --- | --- | --- |
| T1 (max 20 s) | Hunters 4 @0 s, 4 @6 s, 4 @12 s; interval 0.5 s (12 Hunters total) | 11 |
| T2 (max 25 s) | Hunters 4 @0 s; Seekers 5 @0 s interval 1.0 s; Hunters 4 @10 s (8 Hunters + 5 Seekers total) | 11 |
| T3 Split, light (max 30 s) | Seekers 8 @0 s interval 1.25 s (5 heavy / 3 light); Opportunists 4 @10 s interval 1.0 s (3 heavy / 1 light) | 11 |
| T4 Siege, teaching (max 40 s) | Seekers 12 @3 s interval 2.0 s (starting estimate; tuned in P2.14); Hunters 2 @10 s; exempt from the volume formula; tuning target: a no-player run loses the Tower before T4 ends in ≥ 3 of 5 seeds, and a player reaching within 480 px of the Tower within 10 s of the warning keeps it above 50% | 11 |
| Combat wave 1 Hunt (max 90 s) | Hunters 5 @0, 5 @15, 6 @30 s interval 0.5 s; Opportunists 4 @45 s (16 Hunters + 4 Opportunists total) | 11 |
| Combat wave 2 Siege ×1.5 (max 90 s) | Seekers 43 @3 s interval 1.57 s; Hunters 7 @0 s interval 9.6 s | 11 |
| Combat wave 3 Split (max 90 s) | Seekers 14 @0 s interval 1.5 s (9 heavy / 5 light); Opportunists 6 @20 s interval 1.0 s (4 heavy / 2 light) | 11 |
| Combat wave 4 heavy Siege ×2.0, final (max 90 s, C-FINAL) | Seekers 57 @3 s interval 1.18 s; Hunters 9 @0 s interval 7.5 s; encounter alive cap 120 counts ALL living enemies | 11 |
| Standalone Standard Assault (Standard Assault test and outside onboarding) | Hunters 4 @0; Seekers 6 @0 interval 1.0; Hunters 3 @16; Opportunists 3 @24 (16 enemies: 7 Hunters + 6 Seekers + 3 Opportunists); Tower alone clears its Seekers (360 HP) in ≈14.4 s, ≤ 60% of 90 s | 11 |
| Siege volume formula | Seeker count = ceil(multiplier × Tower DPS at Siege open (upgrades counted) × 0.75 × wave max duration ÷ 60), spawned evenly over the first 75% of the wave; base Tower 25 DPS, 90 s: ×1.5 → 43 Seekers (+7 Hunters); ×2.0 → 57 (+9 Hunters); the slice adds ≥ 1 ranged Tower Seeker that outranges the Tower to Sieges; T4 is exempt but, like every Siege, is not winnable by the Tower alone | 11 |
| Siege warning | 3 s before the first Seeker spawns (hence @3 s), precedes Seeker spawns; Tower / off-screen indicator pulses + priority cue | 11, 26 |
| Wave composition rule | Every combat wave after T1 contains ≥ 1 Tower Seeker or Opportunist; every biome contains ≥ 1 Hunt, Siege, and Split Assault | 11 |

## Progression & Upgrades

| Value | Default | Owner document |
| --- | --- | --- |
| Prototype upgrade pool | Player — Rapid Fire +20% fire rate/rank; Heavy Rounds +20% damage/rank; Patch Kit restores 30 health/rank taken. Tower — Caliber +20% damage/rank; Optics +15% range/rank; Shield Matrix +10% max health as extra shield/rank. Max rank 3 each, shared ranks | 17 |
| Console price | 30 Scrap × rank being bought (30/60/90) | 14, 17 |
| Fallback cards (C-FALLBACK-CONSOLE) | No max rank, add 0 evolution ranks; Player "Overdrive +10% weapon damage", Tower "Reinforce +10% Tower damage"; appear in the Draft for an exhausted pool AND at the Console for 90 Scrap once that pool is exhausted, so Scrap always has a sink | 17 |
| Level-Up Draft | Pauses fully; 3 cards in a row, background dimmed 60%; ≥ 1 player + ≥ 1 Tower card; reroll replaces all 3, keeps the guarantee, avoids the 3 just shown when the pool allows; Reroll 1 per run (prototype) / 1 per draft (slice); Banish slice only; no Cancel | 13 |
| Draft card display | Icon, name, one sentence, rank change "Rank 1 → 2 of 3"; differentiation by frame shape, fixed glyph, header word, never colour alone | 13, 19 |
| Draft input | 0.4 s input lockout on open; hold-to-confirm arms only after input returns to neutral once; left/right cycle on press with 0.3 s repeat, wrap; hold up 1.0 s confirms with a fill ring that resets on release; number keys 1/2/3 select-and-confirm; mouse click; A/Cross; Space/Enter | 13, 19 |
| Grappling spike | Evaluated as a spike of at most two days after the prototype playtest (task P2.17), against four criteria; else parked in document 30 | 04, 30 |
| Biome hook degrade floor | No combination of owned upgrades reduces a biome's mechanical hook below 40% of its baseline effect (Hook degrade test, first run at P3.6) | 15 (consults 17) |

## Economy & Pickups

| Value | Default | Owner document |
| --- | --- | --- |
| Scrap | Cap 200 (HUD "n/200"); overflow → overflow hopper (cap 100), carried and lost on death; hopper converts to Cores at 10:1 when the player enters the Interaction Radius, remainder < 10 stays; left at run end discarded; Scrap beyond a full hopper discarded; the prototype has no hopper (overflow discarded with a FULL indicator); unspent Scrap discarded at run end | 14 |
| Cores | Sources ONLY field drops (elites, Mini-Boss, Biome Boss), overflow hopper at the Tower, Run-End Settlement; bank to the Meta Wallet on collection; Cores on the field at player death bank instantly; never merge, expire, or get evicted; a Core that would be evicted or reaches 60 s banks instantly (C-MERGE); persistence in-memory at once, atomic write at most every 2 s while dirty, plus wave end, run end, focus loss | 14 (storage: 24) |
| Run-End Settlement | 5 Cores per biome cleared, 3 per boss killed (Mini-Boss included), 1 per full minute of simulation time; abandoned from the pause menu = failure settlement; a crash pays only what was banked | 08, 14 |
| Drop Table | Standard enemy 1 XP + 1 Scrap; Elite 3 XP + 3 Scrap + 1 Core; Mini-Boss 5 XP + 5 Scrap + 5 Cores; Biome Boss 10 XP + 10 Scrap + 10 Cores; Overtime finisher 1 XP, no Scrap; Splitter child nothing; converted Hunter as standard; stuck-despawned enemy drops placed; excess Splitter children beyond the cap become their drops | 14 |
| Magnet radius / pickup motion | 96 px / accelerate 40 px/s initial, 900 px/s² acceleration, 700 px/s max | 16 |
| Pickup raycast | Each tick, cast toward the player masking EnemyBody, TowerBody, World (layers 2, 3, 4); if blocked, hold position keeping stored speed; collected on overlap with PlayerCollector; never-attracted pickups don't simulate | 16 |
| Merge radius (Economy Configuration field) | Default 64 px; 128 px at Fallback Ladder step 1 | 16, 20 |
| Pickup merge (C-MERGE) | At the pickup cap, the oldest pickup of the incoming drop's type merges into its nearest same-type neighbour within the merge radius (neighbour keeps position and lifetime, sums value); if no such pair exists, the oldest pickup of the incoming type expires; if none of that type exists, the oldest XP shard expires, then the oldest Scrap; Cores are exempt (see Cores, above) | 16 |
| Pickup lifetime | 60 s simulation time with a 5 s blink; Cores bank instead of expiring or merging | 16 |
| Economy dominance measure | Across 10 or more recorded runs, if either pool (player/Tower) accounts for more than 65% of ranks acquired, it dominates | 17 |

## Interfaces

| Value | Default | Owner document |
| --- | --- | --- |
| Tower Console rules | Opens after 0.3 s inside the radius while player speed < 10% base AND ≥ 1 entry affordable (at 0 Scrap Repair is greyed and does not count toward opening the Console, C-REPAIR); closes on leaving the radius, Cancel: Q / B/Circle (docs/19 › Input Map), death, or a Level-Up Draft opening; after Cancel, stays closed until the player leaves and re-enters; player auto-fire disabled at any speed while overlapping the Interaction Radius (C-AUTOFIRE), Tower keeps firing; every purchase is a 0.5 s channel with a fill ring, moving > 10% base speed cancels it without charge; input per the Input map, above; entries show price, "Rank n of 3", greyed if unaffordable, "MAX" with no price if maxed; the Console is a world-space Node2D under the gameplay root, z_index 38 (above enemies, below telegraphs), scale set each frame to the view scale so text stays ≥ 24 px tall on screen, nearest edge 200 px from the Tower's centre along the bearing opposite the player, flipping only after a 30° change, 85% opacity (C-CONSOLE-NODE); hidden and input-dead via PauseAuthority's `reasons_changed` signal whenever any pause reason is active, timers on SimClock | 19 |
| Movement-only controls setting (C-SECTORS) | Default off; offered as a hold-to-confirm choice on run-end screens and pause/settings menus; seven fixed 51.4° sectors clockwise from north: Repair, Rapid Fire, Heavy Rounds, Patch Kit, Caliber, Optics, Shield Matrix; an unavailable or maxed sector stays in place and buys nothing; a sector purchase requires the Console to be open | 19 |
| Platform input floor | Movement alone completes a run; every paused menu (Draft, pause menu, settings, run-end screens) lays choices out horizontally and supports hold-to-confirm; interface floor: one stick + Confirm/Cancel; Reroll also a focusable element beside the cards | 19 |
| Input map (C-INPUT) | Full key/button mapping (Move, Draft cycle/select/confirm/reroll, Confirm, Console cycle/select/cancel, Pause) defined in docs/19 UI_UX › UI Layout & Dynamic Container Rules | 19 |
| HUD | Top-left player health bar; top-centre Tower health bar always on screen with shield as an overlaid segment, "Wave n/8" below it (teaching waves shown as T1–T4 in the slice); both bars tick at 40% and change border shape below it; top-right Scrap "n/200", FULL badge at cap, hopper amount when non-empty; bottom XP bar with level and rerolls remaining; HUD numbers may truncate with ellipsis plus a custom focus tooltip | 19 |
| Threat feedback | Vignette drawn as 8 edge segments, intensity follows damage in the last 1 s, fades 0.6 s, triggered by shield and health damage; points at the Tower when off-screen, at the attacker when on-screen; off-screen Tower indicator changes shape and colour below 40% health and shows a short arc on the side of the Tower being hit; Tower damage audio plays on its own AudioStreamPlayer routed to the TowerCue bus (sends to SFX_Priority) and carries an AudioEffectPanner, panned each play to clamp((Tower x − player x) ÷ 960, −1, 1) (C-TOWERCUE), 250 ms retrigger limit; no minimap in the prototype or the slice | 19, 26, 27 |
| Readability | Degradation from the bottom of the hierarchy upward when > 24 high-intensity effects are visible or 1st-percentile FPS < 45; draw order z_index: environment 0, pickups 10, enemies 20 (Y-sorted among themselves), Tower 25, player projectiles 30 (≤ 70% opacity), effects 35, telegraphs 40, player 50, damage numbers 60 | 27 |

## Audio

| Value | Default | Owner document |
| --- | --- | --- |
| Buses | Master → Music, SFX, SFX_Priority (← TowerCue), UI, Ambience — six buses (C-TOWERCUE); SFX_Priority never ducks; when it plays, SFX & Ambience duck −9 dB (50 ms attack, 300 ms release), Music −6 dB floored −18 dB; ducking is a scripted bus-volume ramp on a PROCESS_MODE_ALWAYS node | 26 |
| Retrigger limits | Player damage 150 ms, Tower damage 250 ms | 26 |
| AudioPool | 32 AudioStreamPlayer2D under the gameplay root (pauses with it), max 8 priority voices, steal lowest-priority then oldest, when 8 priority voices are full steal the oldest priority; UI sounds on their own ALWAYS players | 26 |

## Technical Caps & Performance

| Value | Default | Owner document |
| --- | --- | --- |
| Entity caps | Enemies 300 (never exceeded; Overtime finishers count against it and throttle like any spawn, C-OVERTIME-CAP), pickups 150, projectiles 400 (oldest recycled), damage numbers 30, simultaneous telegraphs 40 (player-aimed telegraphs take slots first; spawn markers aggregated one per 30° sector count as one), high-intensity VFX 24; throttle = spawn retries next tick without using budget | 20 |
| Collision layers (binding) | 1 PlayerBody masks 2,3,4,15 · 2 EnemyBody masks 1,2,3,4,15 (flying enemies drop 4) · 3 TowerBody static · 4 World · 5 PlayerProjectile masks 9, 4, 15 · 6 TowerProjectile masks 9, 4, 15 · 7 EnemyProjectile masks 8, 10, 4, 15 · 8 PlayerHurtbox · 9 EnemyHurtbox · 10 TowerHurtbox · 11 EnemyHitbox masks 8 (and 10 only for telegraphed attacks aimed at the Tower) · 12 Pickup · 13 Hazard masks 8,9 (10 only where the biome allows) · 14 InteractionRadius masks 1 · 15 ArenaBounds static · 16 PlayerCollector masks 12 | 20 |
| Logical Death | `dead` flag checked first by every damage handler (including overlaps already delivered that tick); deferred: hitboxes monitoring=false, hurtbox monitorable=false and collision_layer=0 (deferred), body keeps only World+ArenaBounds masks; pool restores layers/masks/monitoring on acquire | 20, 05 |
| Fast projectile sweep | `PhysicsDirectSpaceState2D.intersect_ray` (collide_with_areas=true) from the previous position when travel per tick > 12 px (every prototype projectile) | 20 |
| Off-screen update reduction | Enemy beyond 1.5× the view half-extent moves every 3rd tick with velocity × 3, staggered by spawn_serial % 3; never within 2 Interaction Radii (320 px) of the Tower | docs/20 › Performance Budget (defined there) |
| Performance Fallback Ladder | 1: magnet raycast every 2nd tick and merge radius 128 px; 2: off-screen update reduction enabled; 3: enemy movement via project-owned PhysicsServer2D bodies, hurtboxes/hitboxes as PhysicsServer2D area RIDs or spatial hash, MultiMeshInstance2D per archetype; 4: caps drop to 200 enemies / 300 projectiles / 100 pickups and budgets retuned; if step 4 fails, the design is revised (fewer simultaneous enemies per wave) and the change is recorded in the Review Decision Log; Phase 3 re-runs the ladder at slice density | 20 |
| Run Recorder | Per run under `user://telemetry/<run_seed>_<yyyyMMdd-HHmmss>_<controller_id>/` (controller_id = human, orbit_bot, roam_bot, still_bot, etc.) (C-TELEMETRY): header (run seed, build hash from `res://build_info.txt`, written by an EditorExportPlugin and included by the export filter, Godot version); `ticks.csv` at 2 Hz (SimClock, player position, player HP, Tower HP & shield, Pressure, quadrant, XP level, Scrap, hopper); `events.csv` (SimClock, event type, source intent, source bearing from Tower, amount; types: wave/encounter open & close, Draft open/close, Console open/close, purchase with channel, spawn, damage to either pool, death with cause, run end); idleness metric flags a stretch longer than the scheduled gap plus any grace period plus 3 s with no enemy alive and no pickup within twice the magnet radius (C-IDLE) | 20, 29 |
| Debug overlay | FPS current/median/1st percentile over 10 s, entity counts (enemies, projectiles, pickups, effects), damage-number/telegraph/high-intensity-VFX counts (C-TELEMETRY), Player/Tower HP and shield, wave/encounter ID, Pressure & throttle state, quadrant, SimClock; pseudo-localization toggle uses Godot's built-in pseudolocalization, expansion ratio 0.3 | 20 |
| Hit-stop / slow motion | Hit-stop visual only (AnimationPlayer.speed_scale, sprite effects) ≤ 120 ms; slow motion via SimClock.time_scale ≥ 0.25 for ≤ 120 ms real time, movers multiply velocity by it; revive zoom is a camera effect only; prototype time_scale always 1.0 | 20, 27 |
| Keyed RNG | draft k = hash([run_seed, "draft", k]); drops = hash([run_seed, "drop", spawn_serial]); spawn position = hash([run_seed, "spawn", spawn_serial]) | 20 |

## Onboarding & Session

| Value | Default | Owner document |
| --- | --- | --- |
| Teaching wave budgets | T1 20 + gap 5 + T2 25 + gap 5 + T3 30 = 85 s, within the restored ninety-second onboarding limit for the five lessons; + gap 8 (Split recovery gap) + T4 40 → T4 ends ≈ 133 s after launch; the forced first Draft opens when T4 ends, and the 10 s Siege recovery gap follows the Draft; Tower understood by end of T2 ≈ 50 s | 02, 11 |
| First Siege (T4) outcome (Author decision, A2) | Losable: a player who ignores the Tower can lose it and the run in T4; a player who responds to the warning survives; T4 is tuned (see the T4 row in Encounter Budgets) so a no-player run loses the Tower before T4 ends in ≥ 3 of 5 seeds | 02, 11 |
| Onboarding compression (Author decision, A1) | Compressible, never skippable, through a profile setting; the setting halves T1 and T2 durations and budgets; it never removes a teaching wave — all four beats (T1–T4) always play | 02 |
| Session arithmetic | Siege waves target 80 s; a biome totals ≈ 10–11 min (8 combat waves at 40 s with Sieges at 80 s, gaps, a 60 s Mini-Boss, a 120 s Biome Boss); three such biomes plus onboarding, total a run ≈ 32–35 min | 02 |
| Prototype session length | T4 ends ≈ 133 s after launch, then the 10 s Siege recovery gap, then 4 combat waves (40–90 s each) with their inter-wave gaps; prototype expected length 7 to 9 minutes | 02, 29 |
| Boss duration targets | Mini-Boss 60 s, Biome Boss 120 s | 10, 11 |
| Orbit test | Over 5 paired runs, a scripted orbit bot (120–480 px from the Tower) reaches a lower final wave or lower XP level than a scripted roam bot in ≥ 4 of 5 pairs; pre-agreed first lever if it fails: Tower kills drop Scrap but no XP shard, applied and logged, test re-run; no lever active by default | 11, 29 |
| Kill zone | The area within the Tower's weapon range | 07, 11 |
| Three Second Rule probes | 10 fixed stills captured from designer-recorded runs (the same stills for every tester, with an answer key written before the session and Run Recorder ground truth); Q1 point at the threat; Q2 name the pool taking damage first in the next 5 s; Q3 name what is left undefended if the player moves toward the threat; health compared as % of max; answer within 3 s; pass ≥ 8 of 10 stills correct for ≥ 4 of 5 testers | 29, 02 |

---

# Review Decision Log

Version 0.6.0 was produced by a supervised critical review: five independent modular reviewers graded the 0.5.0 document, a supervisor consolidated their findings, and every contradiction was resolved by one of the decisions below. Version 0.7.0 added a second review round: six independent reviewers graded 0.6.0 against its own stated intent, and this pass corrects every row the round found inconsistent, drifted, or under-specified, and adds new rows for decisions 0.6.0 made silently. The rule applied throughout both rounds: where two passages conflicted, the passage written later in the Change Log was treated as the author's most recent intent and the earlier one was reworded to match; where nothing decided, the option that best preserved the Central Tension and the Investment Split was chosen. Each decision names the alternative so the designer can reverse it deliberately.

| ID | Decision | Alternative considered | Why this one |
| --- | --- | --- | --- |
| D1 | Both upgrade channels may offer player and Tower upgrades; they differ in kind (free/random/paused vs priced/deterministic/live); Tower upgrades granted by the Draft apply remotely and skip the physical return to the Tower that 0.5.0 implied for those cards | Draft = player-only, Console = Tower-only | The 0.5.0 text says "Player or Tower upgrades" at the Tower and "Investment is a choice" at the Draft; only this reading keeps both true, and a remote-apply rule avoids stranding a Draft-won Tower upgrade until the player next visits the Tower. The alternative is cleaner and is one line to switch |
| D2 | Tower Console never pauses; auto-fire disabled while open | Console pauses; auto-fire merely reduced | The vulnerability window is the prototype's proof of the core tension; pausing deletes it |
| D3 | Author decision (2026-09-14): the input floor is movement alone — every menu has a movement-only path; movement-only play uses hold-to-confirm with a lockout in every paused menu, and sector selection in the live Tower Console behind a default-off accessibility setting reachable from run-end screens and pause/settings menus | 0.5.0: "movement input alone" against 0.5.0's own "a stick and two buttons" | Resolved as movement alone (round4_addendum.md A8). Hold-to-confirm keeps the draft a calm decision, and its lockout prevents an accidental confirm on open. The Console is live, so a single stick cannot both move and select; sector selection turns the purchase into a positioning act, which suits the game, and surfacing the setting from run-end screens means a player never has to survive a run to find it |
| D4 | Run ⊃ Biome ⊃ Wave ⊃ Encounter; "Standard Wave" renamed "Standard Assault" | Wave as a kind of encounter | The Wave contract already contains an encounter sequence; containment is the only model both contracts fit |
| D5 | Author decision (2026-09-14): Scrap is run-only and lost on death; Cores enter the Meta Wallet by three routes — elite/boss field drops, the overflow hopper's 10:1 conversion at the Tower, and the run-end bonus — and the Scrap-overflow route converts only when the player enters the Tower's Interaction Radius, never automatically | Settle all held Scrap to Cores at run end; convert overflow to Cores the instant it occurs. 0.5.0: Cores "dropped exclusively by Elites, Mini-Bosses, and Biome Bosses" against 0.5.0's own run-end lump sum; separately, 0.5.0's "excess converts to meta progression rather than being wasted" | Resolves both the Core-sourcing contradiction (round4_addendum.md A3) and the Scrap-overflow contradiction (A4). The round 2 review argued that instant conversion would let a hoarder bank overflow Cores without ever going near the Tower, which breaks the "the Tower processes resources" intent; gating the conversion on Interaction Radius entry keeps the hopper's value tied to a return trip, at the cost of losing it on death like the rest of Scrap. This overrides 0.5.0's "excess converts to meta progression rather than being wasted": the hopper now discards Scrap beyond its cap and at run end instead |
| D6 | Three-quarter top-down 2D, no jump; "low-poly" means flat-shaded 2D polygons | Side view; 3D meshes | Every mechanic in the document assumes planar movement around a central Tower |
| D7 | Two Spawn Rings — a Tower ring for Tower-seeking enemies and a view ring for player-seeking enemies and finishers — inside one 4800×3200 arena per biome, with bosses fought in that same arena | Single Tower ring (0.6.0); single camera ring (0.5.0) | A single Tower ring cannot place player-seeking enemies convincingly around the player or the camera; a single camera ring cannot spawn "evenly around the Tower" and cannot let a boss share the arena with the Tower. Two rings, one wide arena, and no separate boss arena satisfy both "evenly around the Tower" and "a relationship with the Tower" at once |
| D8 | Author decision (2026-09-14): pacing mercy is a bounded slowdown — spawn rate halves for at most 10 s, never in a Siege or Overtime — replacing the author's original full-pause mercy valve; the health-quadrant "never soften pressure on a low pool" rule (introduced in 0.6.0, not the 0.5.0 original) is withdrawn with it | 0.5.0: "pauses new spawns until the pressure normalizes" against 0.5.0's own "a siege must never be winnable by standing still" | Resolved as a bounded, expiring de-escalation (round4_addendum.md A5). An unbounded pause would violate the safe-corner ban and suppress its own finishers; a bounded, expiring de-escalation keeps pacing readable without reintroducing a full pause, and dropping the 0.6.0 never-soften rule leaves quadrant tracking as pure telemetry until a system document finds a use for it |
| D9 | No passive regen for either pool; Tower Repair costs Scrap and presence; base Tower shield | Passive regeneration for the player (or the Tower healing the player when nearby) | A regenerating player pool, like a Tower-heals-player rule, would let the player ignore damage instead of triaging it, which erases the tension the Orbit test measures (Prototype Success Criterion 6): damage has to matter without a passive safety net |
| D10 | Contact damage on a 0.5 s tick per enemy, no knockback, no invulnerability frames; a player surrounded by contact-capable enemies is intentionally trapped (dash in the slice is the escape); Tower Seekers hit the Tower only with telegraphed attacks, never by contact | Invulnerability frames after each contact hit | I-frames would let a surrounded player tank forever by mashing through hits, defeating the trapped-when-surrounded design; a flat tick rate is tunable and testable, and telegraphed Tower hits keep the "no invisible death" rule for the Tower too |
| D11 | Teaching waves 20/25/30/40 s exempt from Session Shape; first draft forced after the first Siege (T4) | Shorter waves (15/20/25/30 s) that would each fit inside the 90 s combat-wave maximum | Each lesson needs at least one full enemy approach cycle to land — a Seeker takes roughly 7 s to close from the spawn ring — so compressing the teaching waves to fit inside 90 s teaches less per wave; the four teaching-wave budgets plus their gaps put the first Siege at the true ≈ 130 s mark, not a reader's assumed ≤ 360 s ceiling |
| D12 | Author decision (2026-09-14): 8 combat waves + 2 boss waves per biome (Mini-Boss Checkpoint after combat wave 4, Biome Boss after combat wave 8), teaching waves T1–T4 before combat wave 1 of a run's first biome, 3 biomes per run | 0.5.0: "every few waves a boss" against 0.5.0's own "multiple boss encounters" | Resolved as a fixed cadence (round4_addendum.md A6). Only a fixed cadence reconciles the slice scope with the session arithmetic: at ≈ 10–11 minutes per biome, three biomes plus onboarding lands inside the Session Shape target (run ≈ 32–35 min); an unscheduled boss cadence cannot be budgeted |
| D13 | Opportunist event rule with hysteresis; Hunter leash converts to Seeker; Seeker body-block attack | Continuous retargeting; Hunter despawn | Event-driven switching is the document's own rule; conversion keeps the pressure on the Tower instead of deleting it |
| D14 | Events via EventBus, reads via query interfaces, and typed commands for actions needing a synchronous result (e.g., purchases, spends); SimClock; PauseAuthority; binding layer table; determinism scoped to order and seeds; fallback ladder | "Strictly signals"; request signals; physics determinism | Godot physics is not deterministic and per-tick signals cannot carry a swarm; the ladder pre-agrees the escape route. Purchases and spends must return success or refusal synchronously, which a fire-and-forget signal cannot guarantee — typed commands reverse 0.5.0's "does not call a function on another system" rule for this narrow case (see D54) |
| D15 | Pickups are non-colliding Area2D with a raycast-blocked magnet: a blocked pickup holds its position (stays sticky) rather than sliding around the obstacle; merging at the pickup cap only ever touches XP shards and Scrap, never Cores, which bank instead of expiring or merging | Physical pickup bodies | Same player-facing behaviour at a fraction of the physics cost; bodies remain the documented alternative. Keeping Cores out of the merge path protects meta-progression currency from being silently destroyed by a busy pickup field |
| D16 | Provisional gameplay budgets in absolute units anchored to the player's base speed (320 px/s), not relative units | No numbers in the master; values expressed in relative (not absolute) units | A prototype cannot be built without numbers; anchoring every budget to the player's base speed keeps values comparable and tunable together while still reading as provisional, not a locked tuning spec |
| D17 | Provisional Defaults Policy and Register | Move every number to system docs that do not exist | The register makes every number owned and changeable in one place |
| D18 | Readiness Threshold split into Document-Ready and Build-Ready; Document-Ready describes only the state of this file's text and is never itself the gate — the gate is recorded only when the designer accepts it per the Gate Approval rule, so the document never certifies its own readiness | Keep one list | The old list contained build outcomes and could never be met by editing the file |
| D19 | Development Phase Map with typed task fields; the map restores the original 0.5.0 "prove the core tension is fun with one enemy per intent" step as task P2.7, run before the Wave Director (P2.8) is built | Keep "Immediate Next Steps" | The user asked for every future point mapped; the old list had no goals, dependencies, or exit criteria, and had lost the feel-check step 0.5.0 depended on. 0.5.0's own step 4 was this feel check; 0.6.0 silently dropped it; 0.7.0 restored it here as task P2.7 |
| D20 | Hub is an out-of-run scene, not in the prototype; Meta Wallet defined | Hub is the Tower | The Factory "physically located in the Hub" only makes sense as a separate scene |
| D21 | Central three-card panel; one Reroll per run in the prototype; card differentiation by shape, glyph, and word; the Draft has no Cancel — a draft must resolve — correcting 0.5.0, which listed a cancel cue for this screen | Radial menu | Radial input conflicts with linear cycling and number keys; the anti-pattern rule requires a reroll, and a draft that could be cancelled would let a player stall a level-up indefinitely. 0.5.0 required offering "rerolls, banishes, or pivots"; the prototype narrows this to one Reroll per run, with Banish deferred to the vertical slice (P3.12) |
| D22 | Encounter failure forfeits the reward only | Health or resource penalties | The document promised the distinction and never defined it; the mildest rule preserves "failure must teach" without punishing |
| D23 | "Choose what to carry forward" removed to document 30; this honestly removes a player choice the 0.5.0 draft implied existed, and the designer may restore a carry-forward system in a later version | Define a carry-forward system | No system existed; the Biome Transition Rule is automatic |
| D24 | Version control is Phase 0.1 | Leave process rules as aspirations | Every "same commit" rule is unenforceable without it |
| D25 | SFX_Priority bus; ducking numbers | Duck the bus the priority sound is on | The original rule silenced the cue it was protecting |
| D26 | "More enemies" and "higher damage numbers" are no longer listed as power-progression signals | Keep them as signals of felt progression, per the 0.5.0 author's original list | Both scale with content density rather than player power and would mislead players about what an upgrade is doing; weapon evolution, Tower evolution stage, and Pressure headroom are progression signals the player actually caused |
| D27 | Directional Threat Feedback points at the Tower when it is off-screen and at the attacker when on-screen, with a side-of-Tower arc showing which side is hit, and its health threshold moved from 50% to 40% to match the Low health-quadrant band | 0.5.0: the vignette "appears on the edge of the screen pointing toward the damage source" (0.5.0 line 1315) and a separate indicator pointed at the off-screen Tower (line 1317) | When the Tower is off-screen the vignette now points at the Tower instead of the damage source; on-screen behaviour is unchanged; the indicator threshold moves from 50% to 40% and gains a side-of-Tower arc, keeping both the Tower and the player's own attacker readable (I7: this change had gone unlogged until this pass) |
| D28 | Author decision (2026-09-14): the Wave Runtime Model resolves a stalled wave by measurable progress (a kill-rate stall check), not elapsed time alone — in-wave Overtime finishers rather than ending the wave outright, surviving enemies carry over against the entity cap only, and the run's final wave never ends on its maximum duration | 0.5.0: "measurable progress ... not elapsed time alone" against 0.5.0's own "exceeds its maximum time limit" | Resolved as maximum duration elapsed AND low kills together (round4_addendum.md A7). Ending a wave on a timer regardless of state would let a stalled Siege quietly resolve into "success," and letting the final wave time out would let a barely-alive Tower call a win; Overtime and the never-times-out rule keep the outcome earned |
| D29 | Overtime's stall detection counts kills in the last 30 s, not damage dealt | Measure damage dealt in the stall window | Damage already feeds the Pressure Metric's capacity term; reusing it for the stall check would double-count the same signal and could show a wave as "active" from Tower or player DPS alone, with no enemy actually dying |
| D30 | Pressure's threat term weights each enemy's current HP by its intent weight and DPS relative to a fixed divisor, producing one dimensionless number | 0.5.0's "sum of health and damage potential" | Health and DPS are different units; summing them directly had no common unit and could never be compared to a capacity term, so the Pressure Metric could never be made numeric |
| D31 | Every boss, including the Mini-Boss Checkpoint, satisfies all five Boss Design Requirements, only at a smaller scale | 0.6.0's exemption letting the Mini-Boss skip some requirements | A Mini-Boss missing a requirement (no distinct phases, for example) reads as a reskinned elite rather than a checkpoint; scaling the requirements down keeps it meaningfully harder while still buildable inside its 60 s target |
| D32 | Prototype Success Criterion 6 is measured by the Orbit test (5 paired scripted runs, orbit bot vs. roam bot, pass at 4 of 5 pairs) with one pre-agreed design lever ready if it fails | 0.6.0's criterion 6 test, which round 2 reviewers found could pass trivially regardless of design | A test with a defined bot pair, a numeric pass threshold, and a named first lever is falsifiable and gives the designer a concrete next step on failure |
| D33 | The Tower Console opens only after 0.3 s below 10% base speed inside the radius with at least one affordable entry, and every purchase is a 0.5 s channel that cancels without charge if the player moves; independent of whether the Console opens, the player's auto-fire is disabled at any speed while inside the radius (C-AUTOFIRE, restoring 0.5.0's "entering the Interaction Radius ... pauses the player's auto-fire") | Console opens on radius entry alone; instant purchases; auto-fire disabled only while the Console is open | Opening on radius entry alone would turn the Interaction Radius into a free safe stop; requiring stillness and affordability, plus a channel time on every purchase, keeps the vulnerability window real. Disabling auto-fire at any speed, not just while the Console is open, closes the Tower-hugging exploit where a player stands inside the radius without opening the Console (see D60) |
| D34 | The Handgun's range is 260 px | A longer range that would let the player defend the Tower's whole footprint from one standing spot | An armed player's centre is at least 174 px from the Tower's centre (160 px radius + 14 px body); a Tower Seeker attacking the far side stands at least 120 px from the Tower's centre on the opposite side (106 px footprint + 14 px body), so it is at least 294 px away, beyond the handgun's 260 px range (C-AUTOFIRE geometry note) — no armed standing spot covers the whole Tower |
| D35 | The Siege spawn formula reads the Tower's current DPS including upgrades; the final heavy Siege is capped at 120 enemies alive; the teaching Siege (T4) is tuned separately from the volume formula; the vertical slice restores a ranged Tower Seeker to Sieges | A flat Siege spawn count independent of Tower upgrades; an uncapped heavy Siege; no ranged Seeker | A flat count would make Sieges trivial once the Tower is upgraded, or lethal before it is; an uncapped heavy Siege risks the entity cap and the performance rule; a ranged Seeker gives Sieges a threat the Tower's own range cannot ignore. Side effect worth flagging: because Seeker count scales with Tower DPS, Tower damage upgrades add Siege Seekers proportionally, which biases investment toward the player during Sieges (E-m7) |
| D36 | The arena is 4800 × 3200 px | A smaller or square arena (0.6.0's 3200×3200) | At 3200 px wide, the arena's east–west extent barely exceeds the largest view width (2208 px at view scale 1.15), so the Tower could rarely leave the screen horizontally; 4800 px wide keeps the off-screen Tower indicator and both Spawn Rings meaningful in the direction players travel most |
| D37 | No level-up fires while T1–T4 are open, and XP is capped at 14 during them | Let level-ups fire normally during onboarding | A level-up mid-teaching-wave would pause the simulation and interrupt the lesson before it lands; capping XP and forcing the first Draft only after T4 lets onboarding finish before the player's first real choice |
| D38 | The fallback cards for an exhausted pool are a flat +10% damage card per channel (Overdrive for the player, Reinforce for the Tower); these same cards also appear at the Console for 90 Scrap once their pool is exhausted, so Scrap always has a sink (C-FALLBACK-CONSOLE) | A "+20 Scrap" fallback card; fallback cards available only through the Draft | A Scrap fallback would feed the overflow hopper without the player doing anything, rewarding hoarding instead of investment; a damage card keeps the fallback inside the same Investment Split as every other card. Restricting the fallback to the Draft alone would leave Scrap with no sink once every other pool is maxed (E-m2) |
| D39 | A single, numbered Prototype Success Criteria list is the only definition of "the prototype passes," and criterion 13 (wanting another run) remains gating | Split the criteria into "hard" and "soft" tiers, with the desire-for-another-run item treated as soft | Splitting the list invites disagreement over which tier a failing criterion belongs to; keeping "wanting another run" gating holds the prototype to more than mechanical correctness |
| D40 | The Vertical Slice Scope Freeze is amended to explicitly include dash, a minimal Hub, a save profile, the status effect system, production art & audio, all eight encounter types the slice uses (naming the Boss Encounter and the conditional Duel alongside the other six), a ranged Tower Seeker, and "resource processing through the Tower" restored as the Console plus the overflow hopper | Leave the freeze as first drafted, with these items implied rather than listed | An unlisted item is not frozen; the review found each of these load-bearing enough to name explicitly — a slice without dash cannot test the hook degrade floor, and a slice without the Boss Encounter miscounts its own encounter types. Dash was not part of 0.5.0's original slice scope; it is introduced here as a freeze amendment needed to test the hook degrade floor |
| D41 | Every combat wave after T1 contains at least one Tower Seeker or Opportunist, and every biome contains at least one Split Assault | 0.5.0's rule was "at least one Hunt and one Siege per biome"; the alternative not taken is leaving it at that, with no Split Assault requirement and no every-wave-after-T1 Seeker/Opportunist rule | A wave with only Player Hunters lets the Tower sit idle, the exact Tower-irrelevance failure 0.5.0 warned against; this decision adds two mitigations on top of 0.5.0's baseline: guaranteeing a Tower-directed enemy every wave after T1, and requiring at least one Split Assault per biome |
| D42 | "No manual queues during a run" applies only while a run is in progress; between-run Factory production and queues are document 08's call | Ban queues from the Factory entirely, at every stage | A blanket ban would contradict the Factory's own between-run purpose; scoping the ban to "during a run" keeps the Console/hopper as the only in-run resource path while leaving between-run production to document 08 |
| D43 | A documentation stub satisfies the Quality Gate only for the prototype milestone; every later milestone requires the owning document to be at least working | Let a stub satisfy the Quality Gate at every milestone | Stubs were only ever meant to unblock Phase 0–2 scaffolding; letting them satisfy later gates would let the vertical slice and production phases ship without real system documentation |
| D44 | The grappling hook is evaluated as a time-boxed spike (at most two days) against four criteria, scheduled after the prototype playtest (task P2.17) | 0.5.0: "This mechanic will be evaluated during prototype development" (0.5.0 line 501), with the grappling hook already excluded from the prototype's own scope (line 2433) and Next Steps item 9 barring it until the prototype exit criteria pass (line 2588); the alternative not taken is leaving that evaluation open-ended with no time box | 0.5.0 already deferred grappling-hook evaluation until prototype exit; this decision moves that evaluation to after the prototype playtest (P2.17) and states it against four criteria that are 0.5.0's own — the only addition is the two-day time box, so the spike either passes fast or the hook is parked in document 30 |
| D45 | Phase 1 (technical foundations) completes before any gameplay system begins, and a feel check with hand-placed enemies (P2.7) runs before the Wave Director is built (P2.8) | 0.5.0 Next Steps, in order: (3) "Prototype the player controller and Tower with two health pools, the Interaction Radius, and nothing else." (4) "Prove the core tension is fun with a single enemy type of each required target intent." (5) "Build the Wave Director skeleton with encounter types as data, not code. Implement the Spawn Ring and Pressure Metric." (6) "Establish the entity cap, pooling systems, and Godot 4.x architecture (EventBus, Collision Layers) before adding content."; the alternative not taken is building gameplay features and the Wave Director ahead of, or in parallel with, the technical foundations and the feel check | Technical foundations (0.5.0 step 6) move ahead of steps 3 to 5, since step 6 itself says "before adding content"; the feel check (step 4) is kept before the Wave Director (step 5), i.e. P2.7 before P2.8. Building content on an untested pooling/collision/audio foundation risks rework; tuning a data-driven pacing system before confirming the moment-to-moment feel is fun risks tuning the wrong thing |
| D46 | The Three Second Rule probe's second question asks which pool takes damage first in the next 5 seconds — the pool "in danger" — checked against the Run Recorder | 0.6.0's drifted phrasing, which had lost the "in danger" framing | The probe exists to test whether players can read imminent danger, not narrate what already happened; restoring the "in danger" framing keeps the question testing the intended read |
| D47 | Author decision (2026-09-14): onboarding can be compressed through a profile setting, which halves T1 and T2 durations and budgets, but never skips any of the four teaching waves | 0.5.0: onboarding is "skippable through a setting" against 0.5.0's own requirement that the document "must not remove the Siege beat" | Resolved by compression that halves T1 and T2 instead of removing them, keeping every wave (including the protected Siege beat) intact while still respecting a returning player's time (round4_addendum.md A1) |
| D48 | "Mining" is restored to document 16's remit, parked until a biome design calls for it | Leave Mining out of any document's remit, as an orphaned idea | An orphaned mechanic has no owner to resolve its edge cases when a biome eventually needs it; parking it in its natural owning document keeps it findable without committing to build it now |
| D49 | The prototype keeps temporary debug persistence (in-memory or scratch state written for debugging only); it still has no save system | 0.6.0's tightened rule of no persistence of any kind in the prototype | Debug persistence is how a developer resumes a scripted test scenario without replaying setup every time; banning it entirely would have slowed the internal acceptance pass (P2.15) for no gameplay-scope reason, since it is explicitly excluded from the Prototype Success Criteria. It is listed under Minimum Playable Prototype Gate › Prototype Scope, not left implicit |
| D50 | In the prototype, a controller disconnect opens the pause menu, the same as any other pause trigger; the vertical slice replaces this with a dedicated reconnect prompt | Build the reconnect prompt for the prototype too | The reconnect prompt is production UI the prototype does not need to prove the core tension; routing disconnect through the existing pause menu reuses a system that already exists |
| D51 | An enemy's target intent changes only through the specific event rules this document defines — the Opportunist's damaged/out-of-range/target-death events, the Hunter's leash conversion, and the stuck-despawn fallback — never by unstated designer discretion | 0.5.0's "certain enemy types may switch targets," with no rule for when | An unstated switching rule cannot be tested or balanced; naming the exact events and their thresholds (25% closer, 3 s, 20 s) makes every retarget reproducible and testable. 0.5.0 also required a pathing fallback ladder for a target an enemy cannot reach — "Fall back to a secondary target, then to direct approach, then despawn after a timeout" — which this document provides as the stuck-despawn fallback's retarget step (3 s → secondary target or direct approach; 8 s → direct approach; 20 s → despawn); in the prototype only the Opportunist has a secondary target to fall back to, so it is the only enemy whose 3 s step is a secondary-target switch rather than direct approach (see D75) |
| D52 | Camera zoom is expressed as a view scale, where 1.0 equals a 1920×1080 world-pixel view (Camera2D.zoom = 1 / view scale), and the viewport uses stretch mode canvas_items with aspect keep (letterbox) | Express zoom directly as a Camera2D.zoom multiplier; disable stretch mode or letterbox | A view-scale convention reads the same regardless of window size, so every other section (encounter budgets, Spawn Ring geometry, HUD text size) can state one number instead of a resolution-dependent one; canvas_items with letterbox keeps the arena's aspect ratio intact on any monitor |
| D53 | "Upgrade draft between levels" (0.5.0's phrasing) is read as "the Level-Up Draft opens on an XP level-up," not as a draft available at any arbitrary moment between levels | Treat "between levels" as license for a draft the player can open on demand while below the next level threshold | An on-demand draft would let a player farm rerolls by never levelling up; tying the Draft strictly to the level-up event keeps XP the single gate on when new power becomes available |
| D54 | Typed commands for actions needing a synchronous result (purchases, spends) are a named cross-reference to D14, which folds the decision itself into the EventBus/query-interface row | (see D14; no separate alternative) | Keeping D54 findable by its own ID lets the I2 finding ("typed commands reverse 0.5.0's rule without a row") be closed even though the substantive decision lives in D14 |
| D55 | Author decision (2026-09-14): the first Siege (T4) can end the run again — a player who ignores the Tower can lose it and the run, a player who responds to the warning survives; T4's spawn counts are tuned to this target (see the T4 row in Encounter Budgets) | The 0.7.0 reading, where T4's failure signature was Tower damage only and could not end the run | 0.5.0: "Siege, survivable" for a responsive player, against 0.5.0's own "failing the first Siege is acceptable and intended"; the designer restored the losable reading on 2026-09-14 (round4_addendum.md A2) |
| D56 | Two structural decisions for this revision, recorded together: (a) a pre-1.0.0 versioning exception — this file may move 0.7.0 → 0.8.0 without a major bump despite substantive rule changes; (b) the master is mechanically split, sections moved, with ledger FIX edits applied, into docs/09, 11, 19, 20, and 29, leaving the master with intent, rules, gates, and the Provisional Values Register | (a) bump the major version on any substantive change; (b) keep every section in one master file | (a) Pre-1.0.0 minor bumps track review rounds, not semantic-versioning guarantees; (b) the designer chose the split on 2026-09-14 to single-source implementation detail in the documents that already own it by remit, restoring the original's "detail lives in system documents" intent, while this file keeps the one place every number is shown (writer rule 3) |
| D57 | The vertical slice is exempt from the general two-sink rule for Cores; Cores may bank through the Meta Wallet's single spend path during the slice, and a second sink is not required until later production | Require two independent Core sinks from the vertical slice onward | The slice's Hub has only one skill node (P3.13); building a second sink before there is a second thing to spend Cores on would be speculative scope |
| D58 | Prototype camera zoom scope is limited to the base 1.0 view scale and the Tower-damage 1.15 trigger; speed-boost zoom, boss zoom, and corridor-biome zoom (0.9) are out of the prototype | Implement every zoom trigger (speed, boss, corridor) in the prototype | None of those triggers exist in the prototype's scope (no dash, no bosses, no corridor biomes), so building their zoom behaviour now would have nothing to test against |
| D59 | Windows 10/11 x64 is the primary desktop target before the vertical slice; Linux/macOS are untested | Build and test all three desktop platforms from Phase 0 | 0.5.0 said "desktop" without naming an OS; narrowing to the one platform the reference machine and export pipeline actually target keeps Phase 0–2 scope buildable, and cross-platform testing is deferred to the slice |
| D60 | The player's auto-fire is disabled at any speed while the player's body overlaps the Tower's Interaction Radius, independent of whether the Tower Console opens (C-AUTOFIRE) | Disable auto-fire only while the Console is open (the 0.7.0 reading) | 0.7.0's narrower rule let a player stand still inside the radius without opening the Console and keep firing at full auto-fire, safely outside the Console's own vulnerability window; restoring 0.5.0's "entering the Interaction Radius ... pauses the player's auto-fire" closes that Tower-hugging exploit |
| D61 | The Pressure Metric's Capacity term uses the player's and Tower's sheet DPS with current upgrades, not damage actually dealt over a measured window; the player term is not zeroed while the Console is open | Measure actual damage dealt over the last 5 s, sampled every 0.5 s, with the player term floored to 0 while the Console is open | The measured-damage version let a player empty the Console of Scrap right as Pressure escalated, temporarily zeroing their own Capacity term and inflating Pressure past what their build could actually survive; sheet DPS is deterministic and cannot be gamed this way |
| D62 | Teaching waves (T1–T4) never run the stall rule, Overtime, or escalation; they end at their maximum duration or when every enemy they own is dead, whichever comes first, and their spawn groups start at fixed offsets (C-TEACH) | Let teaching waves run the same stall/Overtime/escalation rules as combat waves | A teaching wave that could stall into Overtime would out-run its own lesson; a fixed, self-contained runtime keeps every onboarding beat's length predictable |
| D63 | The 300-enemy cap is never exceeded; Overtime finishers count against it and throttle like any other spawn (C-OVERTIME-CAP) | Let Overtime finishers exceed the cap by 10, as 0.7.0 allowed | 0.5.0's cap was a hard ceiling; letting finishers exceed it risked the same performance-rule failure the cap exists to prevent, for a mechanic (Overtime) that is already a fallback path |
| D64 | An encounter whose win condition becomes impossible self-resolves with a partial reward — half its reward rounded down, or nothing if it has no reward — restored as mandatory rather than optional (C-PARTIAL) | Leave the partial reward discretionary, or withhold it entirely on self-resolution | 0.5.0 guaranteed a partial reward on this path; making it optional had quietly removed a promised consolation for an encounter the player did not fail so much as outlive |
| D65 | The ninety-second outer limit for the five onboarding lessons (T1, gap, T2, gap, T3) is restored, under the heading "What The First Ninety Seconds Must Teach" | Leave the onboarding length unbounded, tracked only by the individual wave budgets | 0.5.0 stated the ninety-second limit explicitly; later drafts dropped the heading and the stated bound even though the wave budgets never changed enough to require it |
| D66 | Split Assault lanes are fixed when the encounter opens; prototype lane centres are 180° apart, and from the vertical slice separation is the larger of 120° and the angle the player covers in 6 seconds at maximum speed with upgrades along the Tower's 480 px weapon range; spawn shifts stay inside the lane's sector (docs/11 › Directional Weighting) | 0.5.0: "If the player has a movement upgrade that trivially covers both lanes, lane separation distance must scale with player mobility." (no measurement point, no fixed-or-moving rule) | Round 3 showed the 0.7.0 wording measured separation at the spawn ring, where it never binds, and described lanes as both fixed and moving; measuring at the Tower's weapon range keeps the 0.5.0 intent that mobility must not trivially cover both lanes |
| D67 | "It is not a task tracker: it holds the Development Phase Map, and document 29 tracks progress against it." | 0.5.0: "It is not a task tracker. Milestones live in document 29." | The file now carries the Phase 0–2 map the user asked for; the reworded sentence keeps 0.5.0's intent that progress tracking lives in document 29 without contradicting the map's presence |
| D68 | "Defers" is defined by C-DEFER: after an encounter completes, no encounter opens until its recovery gap has elapsed; when two are due together, the higher priority opens and the lower waits for it to complete plus that encounter's recovery gap | 0.5.0: "Priority order defined; the lower priority defers rather than merging" (deferral length undefined) | Round 3 found the deferral stated four incompatible ways across sections; one canonical rule keeps 0.5.0's no-merge intent and makes the Encounter recovery test decidable |
| D69 | The 1.5 s post-Draft grace period extends only Wave Director deadlines (spawn-group start offsets, an emitting group's next emission, inter-wave gaps, recovery gaps); every other gameplay deadline runs normally (C-GRACE) | 0.5.0: "No encounter may begin until the draft closes plus a grace period." | 0.7.0 extended every pending timer, which froze attacks while movement resumed, a partial pause 0.5.0 bans; scoping the extension keeps 0.5.0's rule that no encounter begins during the grace period |
| D70 | Audio uses six buses (Master → Music, SFX, SFX_Priority fed by TowerCue, UI, Ambience); Tower damage audio plays on an AudioStreamPlayer routed to the TowerCue bus, whose AudioEffectPanner pans it toward the Tower (C-TOWERCUE) | 0.5.0: "Audio must be strictly routed: `Master` -> `Music`, `SFX`, `UI`, `Ambience`." and "Tower damage audio is strictly panned to the direction of the source." | A Godot AudioStreamPlayer has no pan control and priority sounds on the ducked SFX bus would silence themselves; the extra buses keep 0.5.0's intent that the Tower damage cue is directional and cuts through combat noise |
| D71 | At the pickup cap, merging follows C-MERGE: the oldest pickup of the incoming type merges into its nearest same-type neighbour within the configurable merge radius, else the oldest of that type expires, then the oldest XP shard, then the oldest Scrap; Cores never merge or expire | 0.5.0: "If the pickup entity cap is reached, identical pickups on the ground automatically merge into higher-value pickups to free up entity slots." | 0.5.0 gave no rule for when no identical pair exists and 0.7.0 stated two conflicting cascades; the canonical cascade keeps value-preserving merging first and protects meta currency |
| D72 | The quality gate requires correct behaviour under pause, the Level-Up Draft, the Tower Console, and, where the milestone includes them, biome transitions | 0.5.0: "It behaves correctly under pause, upgrade screens, and biome transitions." | The prototype has no biome transitions, so an unconditional clause made its gate unsatisfiable; the Draft and Console replace 0.5.0's generic "upgrade screens" |
| D73 | Glossary: a Run starts at launch from the Hub (the prototype boots into the arena) and ends in success, failure, or abandonment; a Wave is a pacing slot with a derived spawn budget and, for combat and teaching waves, a maximum duration (boss waves have none) | 0.5.0: "Run — a single playthrough from launch until the player or Tower is destroyed." and "Wave — a timed spawn group within a biome." | The 0.5.0 definitions had no success exit and made every wave timed, which contradicts boss waves and the run success condition elsewhere in the document |
| D74 | The Visual Death body keeps its World and ArenaBounds collision masks so its death animation stops at the arena walls, while its hurtbox's collision_layer is cleared to 0 so a swept projectile's `intersect_ray` passes through it; the `dead` flag, checked first by every damage handler, prevents any ghost hit regardless | 0.5.0: "It does not block movement (collision shapes are disabled) and does not interact with the world." | A fully non-colliding body would let a dying enemy's corpse drift through walls mid-animation, which reads as broken; keeping the World and ArenaBounds masks lets the animation settle against the arena while every other interaction is cut by the dead flag and the cleared hurtbox layer |
| D75 | In the prototype, Tower Seekers and Player Hunters have no secondary target defined, so their 3 second stuck step is direct approach rather than a secondary-target switch; only the Opportunist, whose secondary target is the other target type, uses the secondary-target step | 0.5.0's fallback ladder: "Fall back to a secondary target, then to direct approach, then despawn after a timeout" | "Enemies must commit," and the prototype defines no second target type for a Tower Seeker or a Player Hunter to fall back to; the Opportunist alone has one because its whole behaviour is choosing between two targets |
| D76 | Split Assault's lane asymmetry is implemented per spawn group as ceil(0.6 × n) spawns assigned to the heavier lane, alternating by spawn index, rather than an exact 60:40 split of the encounter's total spawns | 0.5.0: "Lanes must be weighted asymmetrically."; the alternative not taken is computing an exact 60:40 split (or a tolerance band around it) across the whole encounter rather than per group | A per-group ceiling keeps every individual spawn group's split deterministic and testable (20 generated Split Assaults, scripted) without floating-point tolerance on an aggregate ratio; ceil(0.6 × n) guarantees the heavier lane is always the majority for any group size, satisfying 0.5.0's asymmetry requirement exactly |

| D77 | Author decision (2026-09-17): the Development Phase Map gains two Phase 0 tasks, E0.1 (prove and choose the agent-to-Godot control path, in a sandbox, before the real project exists) and E0.2 (install and verify Godot skills), and P0.2 and P0.5 gain dependencies on them; the work in all phases is executed through the supervised review loop recorded in `phases/`, split into 20 execution phases that each end at a checkable gate | Leave both out of the map, tracking the connection test and the skill install only in `phases/PHASE_00_Environment_And_Connection` and document 28, and keep the execution split out of this file entirely | This map's own rule is that every task carries a goal, inputs, dependencies, a deliverable, an acceptance test, an exit criterion, and an owning document. The connection test and the skill install are prerequisites of P0.2 (the project is created through the chosen method) and P0.5 (which pins what they chose), and they were being done either way; leaving them out would have left two load-bearing tasks with no ID, no exit criterion, and no owning document. The execution split is recorded in `phases/` rather than here because this file holds the plan, not its progress (document 29 and `phases/` track that) |
| D78 | Author decision (2026-09-17): the two debug toggles the Settings check requires are bound to F1 (debug overlay) and F2 (pseudo-localization), keyboard only, with no gamepad binding; docs/19 › Input Map records them and the exported build carries them | Bind the overlay to the backtick key console-style; or leave both bindings unnamed until document 19 is brought to working and let P0.2 proceed without them | The Settings check (P0.2) requires the exported build's input map to carry "number keys 1–7 and debug toggles", but docs/19 › Input Map named no debug key at all and described the pseudo-localization toggle with no binding, so P0.2 could not be completed without inventing one. F1 and F2 collide with nothing already bound (movement, 1–7, Tab, Q, R, Space, Enter, Escape) and stay reachable on non-US keyboard layouts, which the backtick does not |

| D79 | Author decision (2026-09-18): the repository is hosted on GitHub at Sayandeep1013/Horde-Control from Phase 0 onward, and P0.1's scope column is amended accordingly. The author gave the remote URL directly and asked that only verified, committed work be pushed | Keep the repository local-only until Phase 4, as P0.1's original Out column required, and add hosting with the release pipeline | The author asked for the remote explicitly and it is where the work is reviewed, so the map had to match reality rather than the repository silently contradicting it. The narrower rule survives inside it: only committed, verified work is pushed, and the ignore rules keep the sandbox, the built MCP servers, build output and local permission overrides out |
| D80 | The Godot `.gitignore` commits `export_presets.cfg` rather than excluding it, reversing P0.1's original plan step | Keep excluding it whole, as P0.1 first specified, on the grounds that an export preset can embed signing secrets | P4.5.3 requires two consecutive byte-identical exports from the same commit, which is not reproducible while the preset is untracked. The preset carries no keystore path, password, or encryption key today. The original concern is retained as a standing rule: if signing is ever added, the keystore path and password live in environment variables, never in this file |

| D81 | Author decision (2026-09-17): document 20 and the Risk Register are corrected to state that the designer's confirmation for destructive or outward-facing MCP operations holds in the main session but does not intercept delegated subagents, and that five tools are denied outright instead. `game_multiplayer` joins the deny list because its `create_server` action binds all network interfaces rather than loopback, making it the only non-loopback surface in either server | Keep the existing wording and make it true instead by denying `delete_file` and `export_project` as well, accepting the loss of the MCP export path; or leave both documents unchanged and note the divergence only in document 28 | The connection matrix proved a subagent executes ask-gated tools with no prompt, so two documents asserted a protection that does not hold for the way this project actually works - it delegates implementation to subagents by design. Correcting them keeps all three documents stating the same true thing, and denying the five tools no phase in scope needs removes the worst of the exposure without blocking the export path P0.2 and P4.5.3 rely on |

| D82 | The Settings check is a scripted audit run against the project, plus a launch of the exported Windows release build and a check of its pack contents. The Acceptance Test Matrix row and the Phase 00 plan are amended to say so | Keep the original wording, which required the audit itself to run inside the exported build; or extend the audit to open and assert against `builds/windows/HordeControl.pck` directly | A Godot release-template build cannot host `--script`, so the original wording described a test that cannot be performed as written, and the phase had been running a differently-scoped check under the same name without disclosing it. A blind review called that the worst load-bearing gap in the phase. Amending the wording makes the document describe what is actually run; the exported build is still exercised, by launching it and confirming the boot check fires inside it and that the pack carries the layer names, input actions and features |
| D83 | Author decision (2026-09-18): the supervised review loop is applied by risk. Code phases and gate phases keep one critical agent per task plus a phase reviewer; documentation-only phases take a spot-check instead of a reviewer panel | Keep the full reviewer panel on every phase regardless of risk, as Phase 00 ran it; or drop to a single reviewer everywhere | Phase 00 ran the full panel and it earned its cost - it caught an unpatched RCE, an acceptance test that could not fail, an invented rule citation across 25 files, and an untested root cause. But Phase 00 was environment plumbing, which is unusually defect-dense. Phases 01 and beyond build against specifications the author has already frozen. Recorded separately: iteration 2 of the Phase 00 gate cut the reviewer count from one-per-task to two without recording the change, and the phase reviewer judged that deviation not defensible and named five per-task defects it let through. The narrowing is legitimate only when decided in advance and written down, which is what this row does |

| D84 | Author decision (2026-09-18): `.claude/settings.local.json` is stripped back to an empty allow list, removing the six `allow` entries it had accumulated for tools that `.claude/settings.json` gates or denies. The two `ask`-gated tools, `delete_file` and `export_project`, stay on `ask` rather than being promoted to `deny` | Promote `delete_file` and `export_project` to `deny` as well, which is the only control the evidence shows actually holds against a subagent; or leave the local allows in place and record the widened surface as an accepted risk in docs/28 > Known Limitations | The local file had silently reversed a decision the author had already made in D81, and the likely cause is ordinary use rather than intent: answering "yes, and don't ask again" to a prompt writes an `allow` rule there. Four of the six were already inert because `deny` wins even from the lower-precedence file, but the two on `ask` were live, so the gate D81 relies on was not operating even in the main session. Restoring the file is the smallest change that makes the configuration match the decision. `deny` was not chosen for the remaining two because P0.2 and P4.5.3 both need the export path, and a phase that needs it would otherwise have to edit settings and restart mid-gate. The residual exposure is unchanged from D81 and is tracked as F-06b |
| D85 | Author decision (2026-09-18): P0.4's exit criterion "every Owns entry has a resolved or accepted row" is read as applying to document 02 alone, since Documentation Structure gives an explicit Owns list only for document 02. Documents 00 and 01 keep their "Owns: none listed in Documentation Structure" line | Add Owns lists to documents 00 and 01 in Documentation Structure first, then resolve them in this phase | The criterion was written without naming which documents it binds, and inventing ownership the master never assigned would create entries no later document could be checked against. Reading it against the one document that has a stated Owns list keeps the criterion checkable and leaves Documentation Structure untouched. If documents 00 or 01 later need to own a rule, that is an ordinary Documentation Structure change with its own row |
| D86 | Author decision (2026-09-18): the gdUnit4 version pin is recorded in docs/28 alongside the two Godot MCP server pins, extending the scope P0.5 originally stated for that document | Record the version in the Phase 01 EXECUTION_LOG.md only, leaving docs/28 scoped to the two MCP servers as P0.5 defined it | The test harness is a pinned third-party tool on exactly the same footing as the two MCP servers, and a version drifting from Godot 4.7.1 is already a named risk for this phase. A pin recorded only in one phase's execution log is not where a later phase would look for it; docs/28 is the document whose remit is the toolchain. The cost is one extra section in a document already at 1.0.0, which takes a version bump and a Change Log row |
| D87 | Author decision (2026-09-18): a contract field named as a "band" - the Enemy contract's Health band and Damage band, and the Weapon contract's Damage band - is typed as one shared `BandedValue` resource holding an integer value, a `{Low, Mid, High}` band label, and a boolean recording whether the label is set. The Wave contract's Difficulty band is not this; docs/20 types it as a plain non-nullable enum | Type the value and the band label as two separate flat exports on each contract that has a band | MASTER's contract lists ask for a single "band" field while docs/20's Contract Field Semantics types the value (Health, Damage per shot) separately from the nullable Band label, so the two documents could not both be satisfied by a literal reading. One shared resource satisfies both, types the pairing once instead of repeating it on three contracts, and keeps the enum member list exactly `{Low, Mid, High}` as Contract Field Semantics states - which matters because the schemas are required to reproduce enum member lists exactly, so adding an `UNSET` member to express nullability was not available. It also gives document 12 a single place to populate band labels from the vertical slice onward |

| D88 | Author decision (2026-09-18): document 01's ranked precedence order for the six pillars is recorded as a decision that the author may reverse, rather than treated as the document simply exercising its remit. The order is: 1 Two things to protect (the Central Tension), 2 Readability before spectacle, 3 Failure must teach, 4 Escalation must be visible, 5 Positioning over precision, 6 Systems isolate, effects combine | Treat the ordering as document 01's assigned remit under Documentation Structure, which asks it exactly "which one wins when two good ideas conflict", and record no row; or strip the ranking from document 01 and have the author supply the order before the document ships | A blind reviewer found the order asserted as "binding" with nothing in the Decision Log behind it, which left the author unable to reverse a ranking that will shape every later design argument. The remit argument is real — Documentation Structure does assign this question — but remit explains why the document may answer, not why the answer is this one. The ranking is derived from how strongly the master states each pillar's claim: rank 1 carries the master's only "does not belong in the game" construction (verified unique by a whole-file search), and rank 2 its only literal "wins" resolution ("clarity wins"). Recording it costs one row and preserves reversibility |
| D89 | Author decision (2026-09-18): the XP level cost formula's coefficients are exported as authored data fields on the Economy Configuration schema rather than hardcoded to the master's literal `10 + 5(L+1)` | Hardcode the coefficients in the formula, matching the master's literal wording, and require a code edit to retune | The formula is a Provisional Default in the Register owned by document 13, and a Provisional Default is by definition a number that may change. Hardcoding it would put a tunable value out of reach of the data layer every other gameplay number lives in. This extends the Economy Configuration contract's field list, which is why it takes a row; document 20's Economy table names the sub-fields |
| D90 | Author decision (2026-09-18): the shared Telegraph data struct gains a lead-time field, so that the Encounter contract's "Telegraph requirements ... with lead time" has somewhere to live | Strike "with lead time" from document 20's Encounter wording as redundant, on the grounds that Telegraph data already carries a wind-up duration | Wind-up duration and lead time are not the same quantity: wind-up is how long the telegraph plays before the attack resolves, lead time is how far ahead of an on-screen spawn the telegraph must be scheduled. The Wave Director needs the second to schedule, and striking the phrase would have deleted a requirement rather than resolved an ambiguity. This extends a shared struct used by several contracts, which is why it takes a row |
| D91 | Author decision (2026-09-18): CLAUDE.md's numbers rule gains one carve-out — a count the master itself states as structure rather than tuning is not a gameplay number and needs no Provisional Values Register citation; anything that could be retuned without changing the shape of the game cites the Register, and an arguable count cites the Register | Allow no carve-out at all, so that every numeral attached to a gameplay noun cites a Register row including structural counts; or settle each case individually by citing the master section that states it, with no general rule | A blind reviewer found documents 00-02 exempting a handful of structural counts on the authority of a CLAUDE.md rule that did not exist. A second reviewer then narrowed the set: at least one of the counts first listed - the number of pillars in document 01 - was never a gameplay number in the first place and needed no exemption, so the carve-out covers fewer cases than the finding originally claimed — the examples had come from a delegation prompt and been mis-attributed. Three of the six stand on the master's own verbatim wording. Leaving it unsettled would have made every later document re-litigate the same question; the strict reading would have made prose like "the run is built from four nested structures" cite a tuning register for a fact about shape. The tie-break clause exists so the carve-out cannot be stretched |

| D92 | **Orchestrator decision (2026-09-18), open to the author's review - it was labelled an author decision in error and is corrected here.** No author consultation was sought for this row, unlike D84-D91 and D93; the label was written reflexively and a blind reviewer caught it. The author has since seen it and chose to keep the substance with the label corrected rather than adopt or strike it. Document 01's mapping of each Explicit Anti-Pattern to the pillar or pillars it enforces is recorded as a decision the author may reverse leg by leg. Three legs are inferred rather than quoted and are flagged as such in document 01: the master's entries for the idle minute, the punished experiment and the solved build name no pillar at all, and their mappings are derived from what the anti-pattern does to the player. The count was first written as two; a reviewer checking all seven mappings against the master found the solved-build entry unsupported as well | List the anti-patterns in document 01 without mapping them to pillars, leaving each system document to argue the connection when it needs to; or map only the legs the master's own wording supports and leave the rest unmapped | A blind reviewer found the mapping asserted declaratively, in the same voice as the pillars themselves, with nothing in the Decision Log behind it - and found at least one leg the master does not support. The anti-patterns are the project's enforcement mechanism, so which pillar each one protects decides which argument wins when a system document pushes back. Leaving them unmapped would have made every such argument start from scratch; leaving them mapped but unrecorded would have let inference pass as quotation. Recording it, and marking the two inferred legs inside the document, keeps both the usefulness and the provenance |

| D93 | Author decision (2026-09-18): the "Phase 0 accepted" Change Log row is deliberately **not** proposed at the end of Phase 01, and the reason is recorded instead. Phase 01 executes three of Phase 0's nine tasks; the other six were executed by Phase 00, whose own review scored it 6/10 against a bar of 8 and whose closure is an undecided designer call | Propose the row's text anyway, flagged as conditional on Phase 00's closure, which is the literal reading of the phase-table gate; or treat the gate requirement as discharged silently by the phase's other work | Proposing acceptance of a phase whose larger half is still awaiting the designer's decision would presume that decision, which the Gate Approval rule reserves. Recording the withholding serves what the gate is for - the author is told, and told why - without an agent implying a verdict on Phase 00. A blind reviewer raised the omission as a Major at iteration 1, offered recording-the-reason as an equally acceptable close, and confirmed at iteration 2 that this route discharges it. The row an agent may legitimately propose, P0.4's document-stability row, is proposed in `evidence/p04_report.md` and is not written |

| D94 | Author decision (2026-09-18): Phase 02's review gate groups its seven tasks into four critical agents by coupled subsystem - P1.1 with P1.2 (clock, pause and events), P1.3 with P1.5 (pools and the combat framework that reuses them), P1.4 alone (recorder), P1.6 alone (audio) - plus the phase reviewer, who also covers P1.7 as the phase's load test. Five reviewers per iteration rather than eight | Keep D83's literal one-critical-agent-per-task pace, which for seven tasks means eight reviewers per iteration; or drop to two critical agents plus the phase reviewer | D83 makes review rigour a function of risk and requires any narrowing to be decided in advance and written down, which is what this row does. Phase 01's twelve reviewer runs earned their cost, but its tasks were independent; Phase 02's are a dependency chain, and a reviewer given P1.3 without P1.5 sees a pool without the thing that reuses it - grouping by subsystem buys depth rather than spending it. Two reviewers was rejected as too thin for the phase that carries the determinism and pause guarantees every later phase inherits |
| D95 | Author decision (2026-09-18): P1.6 implements from `docs/20_Technical_Architecture.md` > Audio Mixing & Dynamic Ducking, which is binding for the prototype, even though the master's task table names document 26 as P1.6's owner and document 26 is still a stub | Raise document 26 from stub to working status before P1.6 starts, so the nominal owner actually owns it | docs/20's audio section is fully specified - six buses and their routing, the ducking curve, both retrigger limits, the panner rule, and the 32-voice pool with its priority-stealing order - and declares itself binding for the Minimum Playable Prototype. Document 26 would restate implementation detail docs/20 already owns, which is the duplication the project's one-place rule exists to prevent. Document 26 is written when audio *content* work begins |
| D96 | Author decision (2026-09-18): the six entity caps are Provisional Defaults and change under the master's ordinary change rule - one commit updating the Provisional Values Register and every place stating the value, plus a Review Decision Log row where intent changes - with no separate author sign-off gate | Require the author's sign-off before any cap is altered, even where the Performance Fallback Ladder prescribes the change | The ladder already prescribes what to do when a step fails, and gating its prescribed outcome on a round trip would stall P1.7 mid-measurement. The protection that matters is already in the ladder's own text: reaching step 4 means the design is being revised rather than tuned, and that revision takes a Decision Log row. The orchestrator still brings the author any step-4 outcome, because a design revision is a different thing from a cap adjustment |

Reversing any decision requires a Change Log row and a pass over the sections the decision touched, which the Provisional Values Register and this table make findable.

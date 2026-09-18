# 00 - Vision & Design Philosophy

**Version:** 1.0.0  
**Status:** Working system document, raised from stub to 1.0.0 under task P0.4 (Phase 01). Stable status under MASTER_SDLC.md > Document Control additionally requires this document to be reviewed against the master with that review recorded in the master's own Change Log; that review has not happened, and this document does not claim stable status for itself.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

Defines the long-term vision, player fantasy, design principles, emotional goals, and project identity.

Answers: what is this game trying to make the player feel, and what will it never be?

**Owns:** none listed in Documentation Structure.

---

## Vision

The project is a 2D action roguelite built at the intersection of genres the audience already knows: horde survival, tower defense, action roguelites, and wave survival. It borrows their most legible pleasures — auto-firing combat, escalating enemy pressure, run-based builds, and a defended asset — and fuses them into a single loop that none of them offer alone.

That fusion has one organizing idea. The player is not the only thing on the battlefield that matters. A second entity, the Tower, stands at the center of the arena with its own health pool, its own weapon, and its own stake in whether the run succeeds. The Tower is not a quest objective the player occasionally visits; it is the player's base of operations, automated weapon platform, upgrade station, biome gateway, and factory, all at once, and it is also the thing that can lose the run on its own, independent of the player's own survival.

Everything else in this document, and in every system document beneath it, exists to serve that one idea: two health pools, one player, one battlefield, and no way to fully protect both at once.

---

## The Central Tension

Every design decision in this project is required to resolve back to a single tension: the player is strongest where they are standing, and the Tower is weakest where the player is not.

This produces a dilemma that regenerates itself without any scripted event. The player is always leaving something undefended; the only live question is what. A proposed feature that does not sharpen, complicate, or meaningfully reframe that tension does not belong in the game. This is the strongest test in the design vocabulary of this project, and document 01 (Design Pillars) states how it ranks against every other principle when two good ideas conflict.

---

## Perspective And Arena

The game is played from a three-quarter top-down perspective on a single flat plane: free movement in every direction, no jump, and no verticality of any kind. The player moves continuously around a battlefield centered on the Tower, which stands fixed at the exact middle of a bounded arena. The arena is built larger than what the screen can show at once, so the Tower can be off-screen while the player is roaming far from it — the spatial expression, at the level of pure geometry, of the Central Tension above: the Tower's safety is never guaranteed just because the player is nearby somewhere else in the arena. The exact arena dimensions and traversal timing are stated in document 15, camera behaviour in document 27, and both are cross-referenced from the Provisional Values Register › Arena & Camera.

The gameplay is built around battlefield positioning rather than aiming precision: weapons fire automatically at nearby enemies, so the player's attention stays on movement, survival, and strategic positioning rather than on landing shots.

---

## Player Fantasy

The player is a mobile defender, not a static hero. They move continuously around a battlefield centered on something they did not build alone and cannot fully protect alone. Their skill expresses itself through where they choose to stand and when they choose to move, not through aiming precision: weapons fire and target automatically, freeing the player's attention for battlefield reading and positioning rather than input mechanics.

This is deliberate. The genre neighbours this project draws from each reward a different kind of mastery — twitch aim in some, static base-building in others, room-by-room precision combat in others still. This project rejects all three in favour of a single skill: reading where the pressure is building across two separate targets at once, and choosing where to be.

---

## Project Identity

The genre neighbours this project draws from are well known, and the differentiation from each of them has to be explicit or the project risks becoming an imitation rather than a synthesis.

From horde survival it keeps auto-firing weapons, dense enemy counts, and an upgrade draft on level-up — but rejects the premise that the player is the only thing on the field that matters. From tower defense it keeps a stationary asset with its own health and firepower — but rejects pre-placement planning phases and static path mazing. From action roguelites it keeps run-based progression, permanent meta unlocks, and build variety — but rejects room-by-room pacing and manual precision combat. From wave survival it keeps escalating wave pressure and boss checkpoints — but rejects purely reactive survival with no asset to protect.

What remains after each of those rejections is the project's unique claim: dual-entity survival. Two health pools, one player, one battlefield, and no way to fully protect both at once.

---

## Design Principles

The following principles apply to every system document in this project, and are the test a feature must pass before it is built. Document 01 (Design Pillars) states these as the project's non-negotiable pillars and establishes a definite precedence order among them for when two of them conflict; this document states them as the values that give the project its identity and its emotional register.

- **Positioning over precision.** Skill expression comes from where the player stands, not how accurately they aim.
- **Two things to protect, never enough time for both.** No feature may let the player fully secure both the Tower and themselves at once.
- **Readability before spectacle.** Effects scale with power, but the player must always be able to see incoming threats; when the two conflict, clarity wins.
- **Escalation must be visible.** The player should be able to tell how far into a run they are by looking at the screen, without reading a number.
- **Failure must teach.** When a run ends, the player should be able to name the decision that ended it.
- **Systems isolate, effects combine.** Systems must not know about each other's internals; their outputs may combine freely. This is both a design rule and an architecture rule.

---

## Session Shape As Vision

A run is built to be played in a single sitting: it opens directly into the arena, escalates through a sequence of biomes of increasing pressure, and always ends — in success or failure — having converted into something the player keeps. The exact session-length arithmetic, the number of biomes a full run contains, and the teaching-wave sequence that opens a player's first biome are stated in document 02 (Gameplay Loop) and, where they are tuned figures rather than structure, in the Provisional Values Register › Onboarding & Session.

---

## Platform And Access Philosophy

The input floor for this project is movement alone: a run must be completable using only movement input, because combat never requires anything beyond movement to function — weapons fire and target automatically, and the Tower fights on its own. Every paused menu in the game is required to be drivable by movement input alone, and controller parity is a design constraint from the start, not a task deferred to a later port. This is the accessibility expression of positioning over precision: if skill expression comes from where the player stands, then completing the game should never require a button the player's chosen input device does not have. The exact input timings and menu mechanics that satisfy this are stated in document 19 and the Provisional Values Register › Interfaces.

---

## Emotional Goals

- **Constant vigilance without panic.** The Central Tension is meant to be felt every moment, not just at scripted crisis points; the player should always sense that something, somewhere, is being left undefended.
- **Legible danger.** At any moment the player should be able to look at the screen and answer where the threat is coming from, which health pool is in danger, and what they give up by moving toward it. This is the Three Second Rule, and it is a hard requirement, not an aspiration: its measurable pass criteria are stated in the Provisional Values Register › Onboarding & Session › "Three Second Rule probes."
- **Visible growth.** As a run progresses, the player's escalating power and the escalating threat should both be readable from the screen itself.
- **A failure the player can name.** Losing a run should never feel like noise; it should feel like the identifiable cost of a specific decision.
- **No fully safe place to stand.** Every position on the arena is designed to eventually become untenable if the player commits to it indefinitely, so that movement itself stays meaningful for the whole run.

---

## What This Game Will Never Be

- **Not a precision-aiming game.** No mechanic may reward twitch aim; automatic targeting is a permanent feature, not a starting-difficulty concession.
- **Not a game where both entities can be made fully safe at once.** Any feature that would let the player fully secure the Tower and themselves simultaneously removes the game's central tension and must be rebalanced rather than shipped.
- **Not a game that trades clarity for spectacle.** Effects may scale with power, but never at the cost of the player being able to read incoming threats.
- **Not a game with unattributable failure.** Every damage source requires a telegraph, and every run-ending failure must trace back to a decision the player could have made differently.
- **Not a solved-build, single-safe-spot, or idle-optimal game.** The full list of banned failure patterns that follow from these principles, and how each is guaranteed against, is document 01's responsibility.

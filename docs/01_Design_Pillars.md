# 01 - Design Pillars

**Version:** 1.0.0  
**Status:** Working system document, raised from stub to 1.0.0 under task P0.4 (Phase 01). Stable status under MASTER_SDLC.md > Document Control additionally requires this document to be reviewed against the master with that review recorded in the master's own Change Log; that review has not happened, and this document does not claim stable status for itself.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

Lists the non-negotiable principles that guide every design decision.

Answers: when two good ideas conflict, which one wins?

**Owns:** none listed in Documentation Structure.

---

## What A Pillar Is

A pillar in this document is a rule a proposed feature must pass before it is built, not a preference that can be traded away for a good idea. Document 00 (Vision & Design Philosophy) states these same principles as the project's values and emotional register; this document states them as enforceable tests, and adds the one thing a values statement cannot provide on its own: a definite order for when two of them point in different directions.

---

## The Central Tension: The Supreme Test

Above every pillar sits a single test that applies before any pillar-versus-pillar question does. The player is strongest where they are standing; the Tower is weakest where the player is not. If a proposed feature does not sharpen, complicate, or meaningfully reframe that tension, it does not belong in the game — not "should be reconsidered," but does not belong. Any feature that would let the player fully secure both the Tower and themselves at the same time removes the tension outright and must be rebalanced. No pillar below overrides this test; it is the gate every feature passes through before the pillars below are even consulted.

---

## The Six Pillars

- **Positioning over precision.** Skill expression comes from where the player stands, not how accurately they aim. Any mechanic that rewards twitch aim is out of scope.
- **Two things to protect, never enough time for both.** Any feature that lets the player fully secure both the Tower and themselves at the same time removes the core tension and must be rebalanced. This pillar is the pillar-level restatement of the Central Tension above.
- **Readability before spectacle.** Effects scale up as power scales up, but the player must always be able to see incoming threats. When spectacle and clarity conflict, clarity wins.
- **Escalation must be visible.** The player should be able to tell how far into a run they are by looking at the screen, without reading a number.
- **Failure must teach.** When a run ends, the player should be able to name the decision that ended it. If they cannot, the failure was noise.
- **Systems isolate, effects combine.** Systems must not know about each other's internals. Their outputs may combine freely. This is both a design rule and an architecture rule.

---

## Anti-Patterns As Enforcement

The following failure modes are the project's evidence that a pillar has been violated. They are banned unless a system document argues successfully against this list.

The master states each anti-pattern, but does not say which pillar each one enforces. That mapping is this document's own work, recorded as decision D92 in MASTER_SDLC.md › Review Decision Log so the author can reverse any leg of it. Three legs go beyond the master's wording and are flagged here rather than left to look like quotation. The idle minute's entry in the master names neither readability nor failure-must-teach, and the punished experiment's names neither. The solved build's entry is two sentences that name neither of the pillars mapped to it, nor any of their concepts - and of its two legs, *Escalation must be visible* is the weaker: the argument offered for it is that a trivialising build collapses the run's escalating pressure, which is about escalation existing rather than about it being visible, and visibility is what the pillar asserts. All three are inferred from what the anti-pattern does to the player, not from the master's text.

- **The safe corner** enforces *Two things to protect*. Any position where the player can survive indefinitely without moving is banned; the guarantee that no such position exists is delivered by intent mix rather than by any single wave, as the master states, so every biome must schedule for it; the enemy behaviour and geometry that back it up — the Hunter leash rule, the minimum distance an armed player must keep from the Tower (derived in MASTER_SDLC.md › Explicit Anti-Patterns from the Interaction Radius and the player body radius), and the Tower's own weapon range — are stated in `docs/09_Enemy_AI_Architecture.md` and the Provisional Values Register › Enemies, › Player & Weapons, and › Tower.
- **The solved build** enforces *Two things to protect* and *Escalation must be visible* together: a single upgrade combination that trivialises all content collapses the run's escalating pressure into nothing. Upgrade pools are checked for dominant pairs; the current prototype pool is stated in the Provisional Values Register › Progression & Upgrades › "Prototype upgrade pool," and the measured dominance threshold is stated in › Economy & Pickups › "Economy dominance measure."
- **The invisible death** enforces *Readability before spectacle*: damage the player could not have seen coming is banned outright. Every damage source requires a telegraph.
- **The empty wave** enforces *Two things to protect*: a wave that generates no decision, applying pressure to neither health pool, is banned.
- **The idle minute** enforces *Readability before spectacle* and *Failure must teach* together: any stretch where the optimal play is to stand still and wait is banned. Downtime — a short recovery window with something to do — is allowed; idleness is not, and the Run Recorder's exact idleness threshold is stated in the Provisional Values Register › Technical Caps & Performance › "Run Recorder."
- **The unreadable screen** enforces *Readability before spectacle* directly: enemy count or particle density that hides threats is banned; density is capped by readability, not by hardware.
- **The punished experiment** enforces *Failure must teach*: a build path that is unrecoverable once chosen is banned. Rerolls exist for this reason; the exact reroll allowance for the prototype and the vertical slice is stated in the Provisional Values Register › Progression & Upgrades › "Level-Up Draft."

---

## Precedence: Which Pillar Wins

The Central Tension operates as a **gate**, not as a tie-breaker. A feature that violates it does not ship at all, whatever else it offers; that test runs first and is binary, and it is the subject of "The Central Tension: The Supreme Test" above. The table below is **comparative** and runs second. It arbitrates pillar against pillar, whether the conflict arises between two competing proposals or inside a single one that serves one pillar at another's expense: between two proposals that have both already cleared that test, it states which pillar's claim prevails when they pull in different directions. Rank 1 therefore still decides — not by asking whether a feature violates the tension, but by asking which of two acceptable features sharpens it more.

The order is binding, and is derived from how strongly the master's own wording states each pillar's claim, not invented independently of the text. It is recorded as decision D88 in MASTER_SDLC.md › Review Decision Log, which names the alternatives considered so the author can reverse it deliberately.

| Rank | Pillar | Why it ranks here, in the master's own wording |
| --- | --- | --- |
| 1 | Two things to protect, never enough time for both (the Central Tension) | The only pillar the master states in absolute, gating language: a violating feature "does not belong in the game" and "must be rebalanced." No other pillar carries language this strong. |
| 2 | Readability before spectacle | The only pillar the master resolves with the literal word "wins": "When spectacle and clarity conflict, clarity wins." That explicit resolution outranks every pillar below, which the master states as a requirement but never as a named winner over a competitor. |
| 3 | Failure must teach | A direct corollary of readability: a failure the player cannot see coming (the invisible death, itself a readability violation) is, by definition, a failure they cannot name. Where the two are in tension, readability's explicit "wins" wording governs first, and failure-must-teach inherits that ordering rather than contesting it. |
| 4 | Escalation must be visible | Readability's own wording already subordinates this pillar's core material — "effects scale up as power scales up, but the player must always be able to see incoming threats" describes exactly the same spectacle that carries a run's escalating power. Escalation's visibility is real, but it never overrides clarity; it operates inside the bounds clarity sets. |
| 5 | Positioning over precision | The master states this pillar as a scope exclusion ("out of scope") rather than as an active arbiter between two accepted features — it decides what may be proposed at all, not which of two already-accepted ideas wins. It therefore ranks below the pillars that resolve live conflicts. |
| 6 | Systems isolate, effects combine | The master explicitly calls this "both a design rule and an architecture rule": it governs how an already-decided design is built so that systems do not reference each other, not which competing intent prevails at the design table. It applies downstream, once ranks 1 through 5 have already settled what is being built. |

---

## Open Question: A Conflict The Master Does Not Settle

The master's own wording does not resolve every possible pillar conflict, and this document does not invent a resolution where the text is silent. One concrete gap: *Systems isolate, effects combine* explicitly permits independently-built systems' outputs to combine freely, with no central system vetting the combination. That is precisely the condition under which an emergent interaction between two unrelated systems could produce a failure the player cannot trace to one legible cause — the exact thing *Failure must teach* and the invisible-death anti-pattern ban. The master does not state which pillar governs when an emergent, freely-combined interaction produces an unreadable failure: whether *Systems isolate, effects combine* is constrained by *Failure must teach* (an emergent combination that cannot be made legible must not ship), or whether *Failure must teach* is understood to apply only to single-system, designed failure states and not to the space of possible system combinations. This is named here as an open question for the author rather than resolved by this document.

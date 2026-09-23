# 02 - Gameplay Loop

**Version:** 1.0.0  
**Status:** Working system document, raised from stub to 1.0.0 under task P0.4 (Phase 01). Stable status under MASTER_SDLC.md > Document Control additionally requires this document to be reviewed against the master with that review recorded in the master's own Change Log; that review has not happened, and this document does not claim stable status for itself.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

Complete gameplay flow from starting a run through biome completion.

Answers: what exactly happens between pressing start and the run ending, at all four loop scales?

**Owns:** the Structure Hierarchy (Run ⊃ Biome ⊃ Wave ⊃ Encounter), resolved below under "Structure Hierarchy"; the Run Termination edge cases, resolved below under "Run Termination Edge Cases"; the onboarding edge cases, resolved below under "Onboarding Edge Cases"; boss cadence and biomes per run, resolved below under "Boss Cadence And Biomes Per Run"; a summary of boss wave placement within the loop (the detailed spawn-suppression and budget rules are owned by document 11), resolved below under "Boss Wave Placement (Summary)"; and the encounter failure resolution default, resolved below under "Encounter Failure Resolution Default".

---

## The Run, From Start To Biome Completion

The player enters a biome through the Tower. Combat waves begin spawning enemies, which attack both the player and the Tower — some prioritising the Tower, some prioritising the player, with the target-switching rules for the categories that can change target defined once in `docs/09_Enemy_AI_Architecture.md`.

Defeated enemies drop experience shards, Scrap, and — for elites and bosses — Cores; the full drop composition is defined once in Resource & Economy System › Drop Table and the Provisional Values Register › Economy & Pickups, and is not restated here.

Experience fills a level bar; each level-up opens the Level-Up Draft immediately, mid-wave included, which offers free run-scoped upgrades for the player or the Tower while the simulation is paused (Author decision D116). Scrap is carried by the player and has no in-run sink (Author decision D115 removed the Tower Console and the in-run shop it offered); it converts to Cores at Run-End Settlement instead, and is lost if the player dies before then. Cores bank instantly to the persistent Meta Wallet and fund permanent progression in the Hub between runs. The exact caps, prices, and conversion ratios for all of this live in the Provisional Values Register › Economy & Pickups, › Progression & Upgrades, and › Tower.

After the biome's Mini-Boss Checkpoint boss wave and its Biome Boss boss wave (placement summarised below under "Boss Cadence And Biomes Per Run"), defeating the Biome Boss completes the biome. The Tower then activates and transports the player into the next biome. This loop repeats until the final biome is cleared, which is run success, or either the player or the Tower is destroyed, which is run failure.

---

## The Loop At Four Scales

The run-level description above is what the player is doing at the largest scale. In practice the player experiences four nested loops at once, and each one has to be individually satisfying on its own terms.

No duration is stated in this section, because the four scales do not all carry the same kind of number and flattening them would misrepresent two of them. The master's Provisional Defaults Policy exempts the ranges stated in Session Shape, and only those, as reference frames rather than Provisional Defaults. The wave-length figures are not in that exemption: the master states them as a Provisional Default, and the per-wave maximum durations are carried by the Provisional Values Register › Encounter Budgets, row by row. The inter-wave gap is in › Spawning & Waves, and the derived session-length arithmetic in › Onboarding & Session › "Session arithmetic" and "Prototype session length." Each scale below is therefore described by what the player does in it, and its figures are left to whichever Register row owns them — with one gap recorded rather than papered over: the moment-to-moment frame is the only one of the four with no Register row of its own, and it is named as an open question in the Phase 01 ledger rather than given a citation that does not exist.

### Moment-To-Moment Loop

The shortest scale: read threat direction, reposition, let auto-fire resolve, collect what dropped. This loop must be readable without conscious thought — if the player has to stop and interpret the screen at this scale, the visual direction has failed.

### Wave Loop

Survive the spawn pattern, decide which side of the battlefield to hold, take an upgrade if an XP level triggers, and recover position during the inter-wave gap before the next wave. This loop must contain at least one real decision; a wave that plays identically regardless of player choice is filler and must be redesigned or cut. The inter-wave gap is downtime, not idleness — the distinction, and the exact gap and idleness figures, are defined in Wave Director & Spawning Logic and the Provisional Values Register › Spawning & Waves and › Technical Caps & Performance › "Run Recorder."

### Biome Loop

Learn the biome hazard, survive the biome's waves and its Mini-Boss Checkpoint, accumulate resources, defeat the Biome Boss, and cross to the next biome with everything the Biome Transition Rule allows to persist. This loop must teach something: each biome introduces one mechanic that changes how the player evaluates the battlefield.

### Run Loop

Build a combination of player upgrades and Tower upgrades, push as deep as the build allows, and convert the run into permanent progression whether it succeeded or failed. This loop must never end in nothing — a failed run must still advance the meta layer, or failure becomes punishment instead of pacing.

---

## Loop Entry And Exit Conditions

| Loop | Entry | Success Exit | Failure Exit |
| --- | --- | --- | --- |
| Run | Player launches from the Hub (prototype: boots directly into the arena) | Final biome cleared (prototype: the final combat wave ends with both the player's and the Tower's health above zero — see Wave Director & Spawning Logic › Wave Runtime Model) | Player or Tower reaches zero health |
| Biome | Tower portal activates | Biome Boss defeated | Run failure |
| Wave | Wave Director opens the wave | Defined in Wave Director & Spawning Logic › Wave Runtime Model | Run failure |
| Encounter | Encounter trigger fires | All its spawn groups emitted and every enemy it spawned dead or removed — the objective for the four prototype encounter types (Standard Assault, Split Assault, Siege, Hunt), which carry no reward; other encounter types define their own objective in the Encounter Definition Contract | Encounter failure resolution applied (see "Encounter Failure Resolution Default" below), or run failure |

---

## Structure Hierarchy

The run is built from four nested structures, and this containment order is binding for every data contract and every system document in the project.

**Run ⊃ Biome ⊃ Wave ⊃ Encounter.**

- A **Run** is one playthrough from launch to run success or run failure.
- A **Biome** is one arena with one mechanical hook, a fixed sequence of combat waves, a Mini-Boss Checkpoint boss wave after a fixed point in that sequence, and a Biome Boss boss wave after a later fixed point in that sequence; a run's first biome also opens with the teaching waves T1 through T4 before its first combat wave (see "Onboarding Edge Cases" below). The exact combat-wave count and boss-wave placement points are stated in the Provisional Values Register › Spawning & Waves › "Biome sequence."
- A **Wave** is a time-boxed pacing slot inside a biome — combat, boss, or (in a run's first biome) teaching — containing one or more Encounters. Its spawn budget, maximum duration, end conditions, and how surviving enemies carry over to the next wave are defined once in Wave Director & Spawning Logic › Wave Runtime Model and are not restated here.
- An **Encounter** is one data-defined spawn pattern with an intent, a pressure target, a player answer, and a failure signature. The full encounter taxonomy is listed in MASTER_SDLC.md › Encounter Types; "Standard Assault" is the default encounter. A wave is never itself an encounter.

---

## Run Termination Edge Cases

| Case | Required Behaviour |
| --- | --- |
| Player and Tower reach zero on the same frame | Deterministic order from the Determinism rule: the Tower's depletion resolves first. Run ends, cause recorded as Tower. |
| Tower reaches zero while the player is mid-transition to a new biome | Transition takes precedence only if it has already committed; otherwise run failure. |
| Player dies while a revive effect is available | Revive resolves before death is committed, once per source; a brief invulnerability flag is set on Health (the hurtbox stays enabled so pickups still collect), plus a camera zoom-in to reorient (a camera effect only). The exact invulnerability duration is stated in the Provisional Values Register › Combat Rules › "Revive." |
| Run ends while the Level-Up Draft is open | The interface closes without applying any pending choice; run failure resolves. (The Tower Console row this used to also cover is removed by D115 -- the Console no longer exists in a run.) |
| Run ends with unsaved meta progression | Meta progression commits before the failure screen is shown. |

---

## Onboarding Edge Cases

Onboarding is a design requirement of the core loop, not a menu feature: a player who does not understand the Tower within the opening window of a run — the master states a specific limit, and both it and the landmark by which the Tower must be understood are stated in the Provisional Values Register › Onboarding & Session › "Teaching wave budgets" — will play this as an inferior horde survival game and stop. The teaching waves T1 through T4 are exempt from ordinary combat-wave length, and their exact per-wave budgets are stated in the Provisional Values Register › Onboarding & Session › "Teaching wave budgets."

### An experienced player skips the lesson

The teaching waves must be short enough that they do not bore a returning player, and must never be gated behind confirmation prompts.

### A returning player starts a new profile

Onboarding is compressible through a setting, never skippable, and never gated behind a dialog at run start.

### The player unlocks a powerful meta bonus and then replays the opening

The teaching sequence loses its force for a player who already knows it. The same compression setting is the only permitted response.

### Onboarding Compression (Author Decision A1)

This decision is carried unchanged from the Provisional Values Register › Onboarding & Session › "Onboarding compression (Author decision, A1)": onboarding is compressible, never skippable, through a profile setting. The setting reduces the duration and budgets of T1 and T2 only, by the fixed proportion that Register row states, for returning players; it never removes a teaching wave — every teaching wave, T1 through T4, always plays. This is the sole response to both edge cases immediately above; there is no separate skip path and no dialog-gated shortcut.

### First Siege (T4) Outcome (Author Decision A2)

This decision is carried unchanged from the Provisional Values Register › Onboarding & Session › "First Siege (T4) outcome (Author decision, A2)": the first Siege, T4, is losable. A player who ignores the Tower during T4 can lose it, and the run, before the wave ends. A player who responds to the warning and closes on the Tower keeps it standing. T4 is tuned so that a no-player run loses the Tower before T4 ends in most tested seeds, while a player who reaches the Tower promptly after the warning keeps it standing with a comfortable health margin; the exact tuning target for both outcomes — the seed threshold for the no-player run, and the health fraction the responding player keeps the Tower above — is stated in the Provisional Values Register › Encounter Budgets › "T4 Siege, teaching (max 40 s)." This is deliberate: it is the clearest possible statement, early in a run, of what this game is.

### A level-up can now fire during onboarding (Author decision D108, 2026-09-23)

Level-ups are no longer suppressed during T1 through T4: a Level-Up Draft opens the instant the player's XP crosses the level curve's threshold, exactly as it does during a combat wave, whether that happens in a teaching wave or later. The faster level curve (Provisional Values Register › "XP & levels") means the first Level-Up Draft now typically arrives naturally within the teaching waves rather than needing to be forced open — the old XP cap that discarded shards above a ceiling, and the forced first Draft that used to fire the instant T4 ended, are both removed. This reverses the original reasoning in the Review Decision Log's D37 (a level-up mid-teaching-wave pausing the simulation and interrupting the lesson) in favour of letting the "Investment is a choice" lesson (How It Must Teach) land whenever it naturally does; see D108 for the alternatives considered and why this one was taken.

---

## Boss Cadence And Biomes Per Run

A full run contains the number of biomes stated in the Provisional Values Register › Onboarding & Session › "Session arithmetic", a Provisional Default rather than a fact about the loop's shape; the vertical slice contains one biome, and the prototype contains one arena with no biome transition. Each biome contains exactly two boss-class encounters: a Mini-Boss Checkpoint boss wave and a Biome Boss boss wave, placed after fixed points in the biome's combat-wave sequence exactly as stated in the Provisional Values Register › Spawning & Waves › "Biome sequence." Defeating the Biome Boss is what completes a biome and triggers the transition to the next one (see "The Run, From Start To Biome Completion" above); the Mini-Boss Checkpoint does not end the biome, it checkpoints progress within it.

Bosses always fight in the biome's own arena, with the Tower present and at stake; there is no separate boss arena. A boss may temporarily bound a sub-region of the arena, but that sub-region never excludes the Tower. The duration each boss type is tuned around is stated in the Provisional Values Register › Onboarding & Session › "Boss duration targets."

---

## Boss Wave Placement (Summary)

A boss wave contains only its boss encounter: it has no maximum duration and no Overtime escalation, and its Boss Definition states which of the biome's regular spawns it suppresses while it is active. This is the summary this document owns.

The detailed spawn-suppression mechanics and the per-boss spawn budgets are owned by document 11 (`docs/11_Wave_Director.md` › "Wave Runtime Model" and › "Encounter Budgets for the Prototype"), and this document does not restate them.

---

## Encounter Failure Resolution Default

Encounter failure is not automatically run failure. The default encounter failure resolution is that a failed encounter's reward is forfeited, no further penalty is applied beyond damage already taken, and the run continues. The four prototype encounter types — Standard Assault, Split Assault, Siege, and Hunt — carry no reward by definition (Provisional Values Register › Spawning & Waves › "Encounter completion"), so none of them can fail this particular way; for these four, the only failure exit is run failure.

Separately, an encounter whose win condition becomes impossible self-resolves rather than blocking progress: it grants a partial reward, and an encounter with no reward grants nothing. The exact partial-reward fraction is stated in the Provisional Values Register › Spawning & Waves › "Partial reward (C-PARTIAL)."

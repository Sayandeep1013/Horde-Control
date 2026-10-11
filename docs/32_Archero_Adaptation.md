# 32 — Archero-inspired additions for v1.0

**Status:** binding brief for three v1.0 work packages (2026-10-11).

**Trigger.** The author's request on 2026-10-11: "check the game named archero 2 ... understand its level design .. some actual objects that are interactable in the level too ... its skill tree .. in game and outside of the game ... copy whichever we can for our own game."

**Research basis.** docs/reviews/2026-10-11_ARCHERO2_RESEARCH.md.

**Number policy.** Every number below is a starting value. The implementing package copies it into the Provisional Values Register, and the Register owns it from then on.

**Design intent.** Archero's moment-to-moment depth comes from scheduled choice events (Valkyrie, Angel, Devil), terrain you can exploit, and heroes that change the rules. Horde Control adopts those three ideas and adds what Archero lacks: objects in the arena you can break, kick and stand on. Every addition must create a decision involving **the player, the Tower, or both**.

**What we do not copy:** energy, gacha, shards, gem revives, battle passes, progress gates, and untelegraphed attacks.

---

## A. Run events (WP-RUNEVENTS)

All events pause the simulation and reuse the Level-Up Draft's card UI and input contract: 0.4 s lockout, left/right to move, hold-up / 1-2-3 / click to confirm. Each event announces itself with a banner and `Sfx.play_ui("chest_open")`. Events never stack on top of a Level-Up Draft; they queue behind it.

| Event | When (campaign) | What | Decision it creates |
| --- | --- | --- | --- |
| **Opening Pick** | Before wave 1 | Choose 1 of 3 **player abilities** from your unlocked pool, at level 1, Rare. The Armory skill node changes this to 1 of 4, rolled Epic (it no longer grants a random ability). | Commit to a build from the first second |
| **Patron's Boon** | Gap after waves 4 and 11 | 1 of 2 cards, Epic or better, from the full Draft pool, abilities included | A targeted power spike you can plan around |
| **Sanctuary** | Gap after waves 7 and 14 (before each boss) | 1 of 3 fixed blessings: **Mend** (heal the player 50% of max HP), **Restore** (repair the Tower by 30% of max HP and refill its shield), **Valor** (+10% damage for the player and Tower for the rest of the run) | Heal yourself, heal the Tower, or get stronger for the boss |
| **Blood Pact** | After the Goblin Warchief dies (after its War Chest draft); again after each Endless Warchief | A single pact card from the pact pool, offered with three options: **Pay with your blood** (-20% player max HP), **Pay with the Tower** (-20% Tower max HP), or **Refuse**. If the player took no damage during the boss wave, the cost is halved (**Flawless**) | Choose which of your two lives pays. This trade only exists because the game has two health pools |

**Pact pool** (pact-only cards; each can be taken once per run):

| Card | Effect |
| --- | --- |
| Second Life | The first lethal hit on the player instead leaves them at 50% HP. Composes with the Second Wind skill node: whichever triggers first is used up |
| Twin String | +1 arrow per volley at full damage |
| Bloodlust | Heal 1 HP per kill |
| Siege Breaker | Tower damage +40% |
| Eternal Flame | Burn damage x2, and burns last 50% longer |

**Gaps.** Event waves extend the following gap to at least 8 s, so the player sees the arena before combat resumes. The Wave Director already holds spawns while a Draft is paused.

**Endless.** Patron's Boon after every 7th wave past 15. Sanctuary before every Warchief.

### A2. Focus (Archero's stand-still rule, inverted)
- **Charge-up.** After the player stands still (speed below 8 px/s) for 0.25 s, Focus rises from 0 to 1 over 1.5 s.
- **Payoff.** At full Focus the bow fires +30% faster and the archer shows a soft gold glow.
- **Decay.** Moving drains Focus to 0 over 0.4 s. Dash resets it to 0 instantly.
- **HUD.** A small arc under the player overhead bar.
- **Purpose.** The bow still fires while moving, so the horde flow is kept, but holding position pays off. This creates Archero's core tension without its stop-start feel.
- **Balance bot.** Must handle Focus.

---

## B. Arena interactables (WP-ARENA)

Every object needs:
- a readable silhouette;
- an idle affordance, visible on both sand and grass;
- an `Sfx` cue;
- a telegraph before it causes harm;
- a pool or a count cap.

**Spawn positions** are sampled on walkable ground (the arena's Floor / sand network, never water or plateaus). Each must be at least 180 px from the Tower, at least 120 px from the player, and at least 90 px from any other interactable. Positions use KeyedRng on the run seed.

| Object | Spawns | Interaction | Effect |
| --- | --- | --- | --- |
| **Supply Crate** | 3 at each wave start from wave 2, max 6 alive | Breaks when the player walks into it, dashes into it, or any player-side area damage hits it. The auto-bow ignores crates | Drop: 55% 8 Scrap, 25% Meat, 20% 5 XP. Dust puff and `axe_hit`/wood-break SFX |
| **Powder Keg** | 1 at each wave start from wave 3 (2 from wave 9), max 3 alive | Lit by a player dash into it or by any explosion or area damage. Enemies never light it | 0.8 s fuse with a GroundTelegraph (110 px), then ExplosionFx: 140 damage to enemies within 110 px (bosses take 50%), 15 to the player if inside, none to the Tower. Lure goblins in, then kick it |
| **Shrine** | 1 per wave from wave 2, 400-850 px from the Tower, lasts 25 s (blinks during the last 5 s) | Stand within 52 px for 2.5 s total (a progress ring fills; leaving pauses the fill but keeps progress) | One random boon, shown by an icon above it: **War** (+35% player damage, 20 s), **Haste** (+30% move speed and dash recharge, 20 s), **Ward** (refill the Tower shield and -25% Tower damage taken, 20 s), **Bounty** (the next 20 kills drop double Scrap). The HUD shows an active-boon icon with a countdown |
| **Spike Trap** | 4 fixed plates on the sand paths at 380-650 px from the Tower, placed in the arena scene (data-driven list of positions) | Always present. Cycle: 2.2 s retracted, 0.6 s telegraph (tips peek and the plate glows red), 0.5 s raised | While raised: 30 damage once per entity per cycle to enemies (bosses 50%, Brutes 100%) **and** to the player. Lure Seekers across them; do not stand on them yourself |

**Art.** Project-made, pack-style pixel sprites from `tools/art/make_v1_sprites.py`: `crate.png` (+ `crate_broken.png`), `powder_keg.png`, `shrine.png` (a stone obelisk; the boon icon floats above it), and `spike_trap_0..3.png` (retracted, peek, raised, glow). Icons for the four boons go in `assets/ui/icons/icon_boon_<id>.png`.

**Damage.** All damage goes through `SimLoop.enqueue_hit` and is recorded in CombatStats under `keg` and `spikes`.

**Draw order.** Crates, kegs and shrines y-sort with the entities. Traps draw at ground level, under the entities.

---

## C. Loadout (WP-LOADOUT)

### C1. Champions
Champions are archer variants picked in the War Camp, each with one rule twist. They use the same sprite sheet with a palette tint, plus a coloured plume/cape tint where possible.

| Champion | Twist | Downside | Unlock |
| --- | --- | --- | --- |
| **Ranger** (default) | none | none | open |
| **Warden** | While the player is inside the Tower radius, the Tower regenerates 1 HP/s even with no Scrap. Tower abilities deal +15% damage | -10% player max HP | Keeper of the Keep (win with the Tower above 50%) |
| **Skirmisher** | The bow fires +15% faster while moving. +1 dash charge | Focus is disabled | Untouchable (clear a wave of 5 or later without taking damage) |
| **Pactbound** | Blood Pact costs are halved (and stack with Flawless to a quarter). An extra Blood Pact is offered after wave 11 | -15% player max HP | Warchief Slayer |

### C2. Relics
- **Slots.** 2 relic slots in the War Camp. The second slot unlocks with the first victory.
- **Unlocks.** Relics are unlocked by achievements and first boss kills.
- **No grind.** No duplicates, no levels, no fusion.

| Relic | Effect | Unlock |
| --- | --- | --- |
| Quiver of Echoes | Every 8th bow shot fires a second arrow | open |
| Mason's Trowel | Tower repair +50% per Scrap | open |
| Hunter's Charm | +20% XP | Goblin Slayer |
| Warchief's Horn | Battle Skill cooldown -15% | first Warchief kill |
| King's Crown | Elite chance +3 points; elites pay +1 Core at settlement | first Bombardier King kill |
| Lucky Coin | +1 Draft reroll per run, and Patron's Boon offers 3 cards | Hoarder |
| Iron Banner | Tower starts with +25% shield, and the shield regenerates at 25% rate during waves | Mason |
| Ember Heart | Burn damage +40% | Elite Hunter |

### C3. Profile and screens
- **Profile.** Schema 3, extended additively and reconciled like the earlier additions: `selected_champion`, `selected_relics` (an array of up to 2), and `first_kills{warchief, king}` if not already derivable from `lifetime_boss_kills`. Unlocks are derived from achievements and kills, never stored twice.
- **War Camp.** The Run Setup card gains a Champion picker and two Relic slots. Locked items are shown with their unlock condition. RunConfig gains `champion_id` and `relic_ids`.
- **Results and pause.** Both show the champion and relics. The pause build panel also lists them.
- **How to Play.** Gets one line each for Focus, the four interactables and the run events.

---

## D. Work packages

| WP | Scope | Decisions | Register subsection (insert AFTER) |
| --- | --- | --- | --- |
| WP-RUNEVENTS | §A, §A2: the four events, the pact pool, Focus, and balance-bot support for events and Focus | D280-D289 | "v1.0 Combat & Abilities" → new "v1.0 Run Events" |
| WP-ARENA | §B: four interactables, art, SFX hookup, spawn placement, HUD active-boon icon (one small HUD element) | D290-D299 | "v1.0 Enemies, Bosses & Waves" → new "v1.0 Arena Interactables" |
| WP-LOADOUT | §C: Champions, Relics, profile, War Camp, Results/pause listing | D300-D309 | "v1.0 Meta Progression" → new "v1.0 Loadout" |
| WP-BALANCE-2 | Re-measure with everything in, retune to docs/31 §6.3 | D310-D319 | edits in place |

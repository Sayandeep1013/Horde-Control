# 31 — v1.0 Release Design

**Status:** binding brief for the v1.0 build (2026-10-11). **Owner:** orchestrator, under the author's 2026-10-11 brief: *"we need to implement the game itself now ... build the difficulty, gameplay loop, skill tree, actual meaningful abilities ... im giving u free reign on the game; at the end i need it built in a proper releasable way ... right now it also is too easy, not many options both in settings and in game, the HUD isn't properly designed."*

That brief is the author's approval for the decisions below that revise earlier Author decisions (D115 no in-run Scrap use, D116/D117 Draft shape, the eight-wave prototype sequence). Each revision still gets its own Review Decision Log row naming the alternative (D171 onward).

Every number in this document is a **starting value**. The work package that implements it copies it into the Provisional Values Register, and the Register wins from then on. The balance pass (WP-BALANCE) retunes them with `src/dev/balance_bot.gd`.

---

## 1. What was wrong (audit, 2026-10-11)

| Area | Finding |
| --- | --- |
| Difficulty | Enemy damage multipliers are 0.08-0.30 in 7 of 8 waves. Climax Sieges cut enemy HP to 0.65-0.75. A competent human takes almost no damage. |
| Verbs | Movement is the only input. No dash, no active ability, no aim. Kiting 0.55-0.85x-speed enemies is trivial. |
| Build variety | 16 live cards, all +8-15% stat lines except Multishot/Piercing, and both of those are achievement-gated. No synergies, no new behaviours. |
| Enemies | Three melee archetypes. Elite, boss and ranged fields exist in data and are never read by code. |
| Run | 8 waves, ~6.5 min, ~211 enemies. No boss, no climax, no endless. |
| Economy | Scrap has no in-run use (D115). The Tower Interaction Radius has no consumer. |
| Meta | 19 nodes of flat percentages. Six achievements, three of which unlock on the first win. No difficulty to spend power against. |
| HUD | Tower HP shown three times, player HP and XP twice. 37 px word captions on every pill. No timer, kills, build display, ability cooldowns or boss bar. "Rerolls" sits on the combat HUD. |
| Settings | No rebinding, HUD scale, FPS cap/counter, UI volume, shake intensity, reduce-flashing, focus-pause toggle or reset to defaults. |
| Run end | "Continue" vs "Main Menu" is confusing. There is no Retry. |
| Audio | Bow and goblins use sci-fi laser sounds. There is one music track. |

---

## 2. The v1.0 loop

**Title → War Camp → Run → Results → (Retry | War Camp)**

- **War Camp** (Hub): choose a **Difficulty** and a **Battle Skill**, spend Cores on the **Skill Tree**, view Records and Achievements, toggle **Endless** once it is unlocked.
- **Run**: 15 waves on the island. A **Mini-Boss** comes at wave 8 and the **Final Boss** at wave 15. Killing the Final Boss wins the run. Target length is 13-16 min.
- **Endless** (unlocked by any victory): after wave 15, waves 9-14 loop with +15% enemy HP and +10% damage per loop. A Warchief appears every loop. The run ends only on defeat. The best wave is recorded.
- **Results**: outcome, cause, stats, damage by source, Cores earned, achievements. Buttons: **Retry** (same difficulty and skill), **War Camp**, **Main Menu**.

The pillar stays the same: **two health pools, the player and the Tower.** v1.0 gives the player reasons to leave the Tower (pickups, elites, Bombers) and reasons to come back (repair, Sieges, Brutes).

---

## 3. Player verbs

### 3.1 Dash
- Bound to **Space**, **Shift**, pad **B / LB** and a touch button.
- Moves 190 px over 0.16 s in the movement direction (the facing direction if idle).
- Grants invulnerability for the dash plus 0.12 s, and passes through enemy bodies.
- 1 charge, 2.8 s recharge. A skill node adds +1 charge; Draft passives reduce the cooldown.
- Shows an afterimage trail (3 fading sprite copies) and plays the `dash` SFX.
- Dash is never required. The movement-only floor (MASTER_SDLC.md:242) is kept by §3.3.

### 3.2 Battle Skill
- One Battle Skill is equipped per run, chosen in the War Camp.
- Bound to **E**, **Q**, right mouse, pad **Y / RB** and a touch button.
- Each skill has a cooldown. Its damage scales with the player damage multiplier and with "Skill Power".

| id | Name | Effect (Soldier) | Cooldown | Unlock |
| --- | --- | --- | --- | --- |
| `arrow_storm` | Arrow Storm | 10 arrow impacts over 1.5 s on the densest enemy cluster within 420 px of the player. Each impact deals 35 damage in a 64 px radius. | 16 s | free |
| `frost_nova` | Frost Nova | 40 damage within 230 px of the player and a 60% slow for 3 s. | 13 s | Skill Tree |
| `firebomb` | Firebomb | Lob dynamite at the densest cluster within 380 px: 90 damage in a 110 px radius, leaving burning ground for 4 s at 20 dps. | 15 s | Skill Tree |
| `war_horn` | War Horn | Fully restores the Tower shield. For 7 s, the Tower fire rate is x2 and the player fire rate is x1.5. | 28 s | Skill Tree |

### 3.3 Auto-cast (accessibility and movement-only floor)
- Settings has an **Auto-cast Battle Skill** toggle. When on, the skill fires as soon as it is ready and is useful:
  - for damage skills, 4 or more enemies are in the target area;
  - for War Horn, the Tower took health damage in the last 2 s, or 6 or more Seekers are within 300 px of the Tower.
- It is **on by default on touch devices** and off on desktop.
- The **Movement-only controls** setting forces Auto-cast on.
- Dash is never auto-cast.

### 3.4 Tower repair (Scrap gets a job; revises D115)
- While the player stands inside the Tower Interaction Radius (160 px), carried Scrap drains into the Tower at **8 Scrap/s**. Each Scrap restores **3 Tower health**, up to max.
- Repair only happens when Tower health is below max. It never refills the shield.
- The radius ring glows and a "REPAIRING" tag pulses on the Tower bar. A repair tick SFX plays at most 6 times per second.
- Unspent Scrap still settles to Cores at run end. That makes repairing a choice between run safety and meta progress.
- This is a movement verb. It needs no menu and no pause, so it is not the removed Console.

---

## 4. Level-Up Draft overhaul

### 4.1 Card kinds
Every card has a `kind`: **ABILITY** (player auto-ability with 5 levels), **TOWER_ABILITY** (Tower add-on with 5 levels), **PASSIVE** (stat, as today), **TOWER_PASSIVE**, or **HEAL**.

**Slot limits:** a run holds at most **4 player abilities** and **3 Tower abilities**. When the slots are full, only abilities the player already owns are offered.

The Draft keeps its shape: 3 cards, at least one Player and one Tower card, a wild slot, and the existing rarity rules. Rarity scales an ability's damage numbers. It does not change cooldowns or counts.

**New-ability weighting:** while a slot is free, each offered player card has a 45% chance to be an ability card, rolled before the pool pick. This keeps ability cards from drowning in passives.

### 4.2 Player abilities (`src/ability/`)
Values are given as Level 1 → Level 5. Damage scales with the player damage multiplier.

| id | Name | Behaviour | Unlock |
| --- | --- | --- | --- |
| `flame_arrows` | Flame Arrows | Every Nth arrow ignites the target, N = 4→2. Burn deals 6→14 dps for 3 s and refreshes rather than stacks. At L5, a burning enemy that dies spreads its burn to the nearest enemy within 90 px. | start |
| `frost_arrows` | Frost Arrows | Arrows slow by 20→40% for 1.5 s. At L3+, a hit has a 5→12% chance to freeze for 1 s. | achievement |
| `whirling_axes` | Whirling Axes | 1→4 axes orbit at 72→90 px, 14→26 damage per hit. Each enemy can be hit at most once per 0.45 s per axe. | start |
| `dynamite_satchel` | Dynamite Satchel | Every 3.2→2.2 s, throw dynamite at a random enemy within 320 px. Fuse 0.5 s, then 30→60 damage in a 70→95 px radius. At L4+, throws 2. | start |
| `storm_bolt` | Storm Bolt | Every 2.6→1.6 s, lightning strikes the nearest enemy within 300 px for 22→40 damage and chains to 2→6 more within 140 px. | achievement |
| `caltrops` | Caltrops | While moving, drop a spike patch every 0.9→0.5 s. Each patch lasts 4 s and deals 10→20 damage per 0.5 s to enemies standing on it, with a 25% slow. | start |
| `sacred_ground` | Sacred Ground | Aura of radius 85→130 px dealing 6→20 dps. At L5 it also heals the player 0.5% of max HP per enemy killed inside it. | achievement |

### 4.3 Tower abilities
Values are given as Level 1 → Level 5. Damage scales with the Tower damage multiplier.

| id | Name | Behaviour | Unlock |
| --- | --- | --- | --- |
| `ballista` | Ballista | Every 3.0→1.6 s, fires a bolt along the line to the furthest enemy in range. The bolt pierces everything for 40→90 damage. | start |
| `catapult` | Catapult | Every 5.0→3.0 s, lobs a rock (0.9 s flight, telegraphed) at the densest cluster within 620 px: 50→110 damage in a 90 px radius. | achievement |
| `frost_ward` | Frost Ward | Every 4.0→2.5 s, pulses within 210→280 px: 8→20 damage and a 30→45% slow for 2 s. | start |
| `spiked_palisade` | Spiked Palisade | An enemy striking the Tower takes 10→30 damage back. The Tower takes 5→20% less damage. | achievement |

### 4.4 Passives
Existing cards keep their effects; **Multishot** and **Piercing** become start-unlocked. New passives:

| id | Name | Effect / rank | Ranks |
| --- | --- | --- | --- |
| `fleet_step` | Fleet Step | -12% dash cooldown | 3 |
| `battle_focus` | Battle Focus | -10% Battle Skill cooldown | 3 |
| `blast_radius` | Blast Radius | +12% area of every area ability and skill | 3 |
| `keen_eye` | Keen Eye | +6% critical chance (x2 damage) on player arrows and abilities | 3 |
| `leather_armor` | Leather Armor | -7% damage taken by the player | 3 |
| `ability_power` | War Training | +10% player ability damage (not arrows) | 3 |
| `stone_mason` | Stone Mason | +30% Tower repair per Scrap | 2 |

### 4.5 Status effects (`src/combat/status_effects.gd`)
- **burn**: dps, duration, refresh on reapply.
- **slow**: fraction. The strongest slow applies; slows cap at 70%.
- **freeze**: stops movement and attacks. Bosses are immune; Brutes take half duration.

Each status has a visual tint on the enemy sprite: burn orange flicker, slow pale blue, freeze icy white. All damage goes through `SimLoop.enqueue_hit`.

### 4.6 Sources and the damage report
Every ability tags its hits with a `source_id` string (the ability id, or `bow` / `tower_bow`). `CombatStats` (autoload) accumulates damage per source per run, and the Results screen shows the top 6 sources.

---

### 4.7 Synergies (`src/ability/ability_synergy.gd`, D204)
Four named synergies read status effects set by a partner ability. Each is active while the partner is owned and is listed on the Draft card and the pause Build panel once it is. Numbers are in the Register (Ability synergies).
- **Conduction** (Storm Bolt + Frost Ward): +2 chains, x1.5 damage to a Slowed or Frozen enemy.
- **Kindling** (Caltrops + Flame Arrows): patches ignite; burning enemies take x1.25 Caltrops damage.
- **Shatter** (Ballista, Catapult + Frost Arrows): a Frozen enemy takes x2 from either Tower weapon.
- **Hallowed** (Sacred Ground + Flame Arrows / Frost Ward): a burning enemy killed in the aura heals 1% max HP; with Frost Ward the aura slows 15%.

## 5. Enemies

### 5.1 Base roster changes

| Enemy | Change |
| --- | --- |
| Tower Seeker | Unchanged base. |
| Player Hunter | Unchanged base. |
| Opportunist | Unchanged base. |
| **Bomber** (new, intent `player`, ranged) | 40 HP, speed 0.6x. Holds 240-300 px from the player and throws dynamite every 3.0 s. The landing point is the player's position, shown as a 1.0 s telegraph ring of 56 px radius, then 22 damage. Art: TNT goblin sheet (throw row) recoloured steel blue by a palette-swap shader (D206; purple belongs to the Opportunist) with a lit dynamite stick held overhead while a throw is ready. Drops 2 XP + 1 Scrap. |
| **Brute** (new, intent `tower`) | 320 HP, speed 0.42x, 34 damage per 1.8 s melee, 0.7 s wind-up. Knock-back and freeze immune (freeze becomes a slow). Art: Torch goblin at 1.55x scale with a dark-red modulate (0.75, 0.45, 0.45). Drops 5 XP + 3 Scrap. |

### 5.2 Elites
- From wave 5, each spawn rolls an elite chance of 4% at wave 5, rising 1% per wave to 12%, plus the difficulty add. Bosses and the Overtime finisher are excluded.
- An elite has x3.2 HP, x1.3 damage, x1.18 scale, a pulsing gold outline (shader) and one affix:
  - **Swift**: +45% speed.
  - **Armored**: takes -40% damage.
  - **Volatile**: on death, a 0.7 s telegraph ring, then 35 damage in a 90 px radius to the player and Tower.
  - **Vampiric**: heals 25% of damage dealt; red outline pulse.
- Elite drops: 4 XP, 4 Scrap, 1 Core (paid at Run-End Settlement, D255), and a 35% chance of **Meat**.
- **Meat** is a new pickup that heals 12% of the player's max HP. It is not magnetised and lasts 20 s. Art: Tiny Swords `M_Idle` / `M_Spawn`.

### 5.3 Bosses
Each boss has a top-centre boss bar with its name and a phase marker, plays the `boss_roar` SFX on entry, shows a 2 s entrance banner, and drops a **War Chest**: a pickup that opens an immediate Draft with every card rolled at least Rare.

**Goblin Warchief** (wave 8, and once per Endless loop)
- Torch sheet at 2.6x, gold-red modulate.
- 2600 HP on Soldier, speed 0.5x.
- Targets the Tower, but switches to the player while the player is within 220 px.
- Attacks:
  - **Slam**: 1.0 s telegraph ring, 150 px radius, 38 damage, every 4 s while in melee.
  - **Charge**: 0.8 s line telegraph, 520 px dash at 3x speed, 30 damage on contact, every 9 s.
  - **Rally**: summons 6 Hunters every 14 s.
- Below 40% HP it **enrages**: cooldowns x0.7.
- Drops a War Chest and 8 Cores.

**Bombardier King** (wave 15, the final boss)
- TNT sheet at 2.9x, purple-gold modulate.
- 7000 HP on Soldier, speed 0.4x.
- Stays 300-420 px from the Tower.
- Attacks:
  - **Barrage**: 5 dynamite at telegraphed rings around the player, 1.1 s, 26 damage each, every 6 s.
  - **Siege Bomb**: a large 1.6 s telegraph on the Tower, 110 damage to the Tower, every 10 s.
  - **Call the Horde**: spawns a burst of 8 Seekers and 2 Bombers every 16 s.
- Below 50% HP: Barrage fires 8 dynamite and Siege Bomb comes every 7 s.
- Killing him wins the run. Drops 20 Cores.

### 5.4 Spawn markers and wave banner
- Off-screen spawns show an intent-coloured chevron at the screen edge, at most one per 30° sector, 0.75 s before the spawn. This closes F04-20.
- The wave banner reads "WAVE n · <TYPE>", plus "BOSS" waves. It plays the `wave_horn` SFX.
- The Siege warning gives 3 s of Tower bar pulse plus the priority cue (Register line 3310).

---

## 6. Waves and difficulty

### 6.1 The 15-wave sequence (Soldier)
- The first four waves keep their teaching role. The existing T1-T4 encounters are retuned and renamed waves 1-4.
- HP and damage multipliers apply on top of the base enemy stats.

| # | Type | Composition (starting point) | HP x | Dmg x | Max dur |
| --- | --- | --- | --- | --- | --- |
| 1 | Standard | Hunters | 1.0 | 0.6 | 30 |
| 2 | Standard | Hunters + Seekers | 1.0 | 0.7 | 35 |
| 3 | Split | Seekers + Opportunists | 1.0 | 0.8 | 40 |
| 4 | Siege | Seekers (bursts) + Hunters | 1.0 | 0.9 | 45 |
| 5 | Hunt | Hunters + Bombers (first Bomber) + Opportunists | 1.1 | 0.9 | 60 |
| 6 | Split | Seekers + Opportunists + Bombers | 1.2 | 1.0 | 60 |
| 7 | Siege | Seekers + Brutes (first Brute) + Hunters | 1.3 | 1.0 | 70 |
| 8 | **Boss** | Goblin Warchief + Hunter escort | 1.0 | 1.0 | until dead |
| 9 | Hunt | Hunters + Bombers + Opportunists | 1.5 | 1.1 | 70 |
| 10 | Siege | Seekers + Brutes + Bombers | 1.6 | 1.1 | 75 |
| 11 | Split | All four intents | 1.75 | 1.2 | 75 |
| 12 | Hunt | Hunters + Bombers, elite-heavy (+6% elite) | 1.9 | 1.2 | 75 |
| 13 | Siege | Heavy Seekers + Brutes + Bombers | 2.1 | 1.3 | 80 |
| 14 | Grand Assault | Split + Siege lanes, everything | 2.3 | 1.35 | 85 |
| 15 | **Final Boss** | Bombardier King + trickle of Seekers/Hunters | 1.0 | 1.0 | until dead |

- Gaps between waves: 6 s, or 10 s before a boss wave. The Tower shield regenerates only in gaps (D136, kept).
- The pressure-metric de-escalation and Overtime rules stay. The finisher rule does not apply to boss waves.

### 6.2 Difficulty profiles (`data/difficulty/*.tres`, `DifficultyProfile`)

| Profile | Enemy HP | Enemy dmg | Spawn count | Elite add | Boss HP | Cores | Unlock |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Recruit | x0.7 | x0.55 | x0.8 | +0 | x0.7 | x0.75 | open |
| Soldier | x1.0 | x1.0 | x1.0 | +0 | x1.0 | x1.0 | open (default) |
| Veteran | x1.35 | x1.4 | x1.2 | +4% | x1.4 | x1.4 | win on Soldier |
| Warlord | x1.8 | x1.9 | x1.4 | +8% | x1.9 | x1.85 | win on Veteran |

The profile is read at spawn by the Wave Director: count at encounter build; HP and damage at `set_wave_scaling`. It is set in the War Camp, kept in `RunConfig` (static), and persisted in the profile as the last choice.

### 6.3 Balance targets (WP-BALANCE)
Bot policies are in `src/dev/balance_bot.gd`, with a new `kite` policy that uses dash and auto-cast.

| Difficulty | Bot | Target |
| --- | --- | --- |
| Soldier | still bot | dies before wave 6 in 5 of 5 seeds |
| Soldier | collect/kite bot with smart picks and auto-cast | reaches wave 8 in at least 4 of 5 seeds, wins 1-3 of 5 |
| Recruit | kite bot | wins at least 4 of 5 |
| Veteran | kite bot | wins 0-1 of 5 (the skill tree and a human are expected to close the gap) |

- A winning Soldier run lasts 13-16 min.
- The Tower must lose health in every Siege wave at least once without player intervention.

---

## 7. Meta progression

### 7.1 Skill Tree v2 (`data/meta/skill_tree.tres`, schema 3)
- Five branches radiate from Command Tent, laid out as real branches: Archer west, Survival north, Battle Skills north-east, Tower east, Fortune south.
- About 30 nodes. Costs follow the existing formula with the tier base raised to **8 / 16 / 28 / 45** for tiers 1-4.

| Branch | Nodes (effect per rank, ranks) |
| --- | --- |
| Archer | Sharpened Arrows +8% dmg (3); Quick Draw +6% fire rate (3); Keen Eye +4% crit (3); Eagle Eye +10% weapon range (2); Armory: start each run with a free Level-1 player ability from your unlocked pool (1, keystone) |
| Survival | Vitality +10% max HP (3); Swift Boots +4% speed (3); Iron Skin -5% damage taken (3); Fleet Foot -10% dash cooldown (2); Second Dash +1 dash charge (1); Second Wind (1, unchanged) |
| Battle Skills | Frost Nova unlock (1); Firebomb unlock (1); War Horn unlock (1); Skill Focus -8% skill cooldown (3); Skill Power +15% skill damage (3) |
| Tower | Stone Walls +10% HP (3); Arrow Slits +10% dmg (3); Shield Runes +15% shield (2); Mason's Kit +20% repair per Scrap (2); Watchtower +10% range (2); Engineers: Tower abilities +15% dmg (2); Fortress (1, unchanged) |
| Fortune | Scavenger +15 start Scrap (3); Scholar +10% XP (3); Lucky Draw +1 reroll (2); Lucky Charm +3 luck (2); Prospector +15% Cores (2); Deep Pockets +50 Scrap cap (1); War Chest (1, unchanged) |

- Node names show on the board, not only in the detail panel.
- Buying takes a 0.5 s hold, or a mouse click (the hold stays for the movement-only floor).
- **Migration 2→3:** every Core spent on v2 nodes is refunded, the tree is reset, and a one-time Hub banner says "The Skill Tree was rebuilt. Your Cores were refunded."

### 7.2 Achievements (expanded to 16)

| id | Condition | Reward |
| --- | --- | --- |
| goblin_slayer | 300 lifetime kills | unlocks `frost_arrows` |
| veteran | reach wave 8 in a run | unlocks `storm_bolt` |
| keeper_of_the_keep | win with the Tower above 50% | unlocks `spiked_palisade` |
| warchief_slayer | kill the Goblin Warchief | unlocks `catapult` |
| sanctified | win a run on any difficulty | unlocks `sacred_ground` |
| hoarder | 1000 lifetime Scrap collected | +1 reroll per run |
| founder | first victory | +5% Cores |
| marksman | 2000 lifetime kills | +5% weapon damage |
| regicide | kill the Bombardier King on Veteran | +10% Cores |
| warlord | win on Warlord | unlocks the "Warlord" title on the Results screen and a gold Tower skin tint |
| untouchable | clear a wave without taking player damage (wave ≥ 5) | +5% move speed |
| mason | repair 2000 Tower health in total | +10% repair per Scrap |
| elite_hunter | kill 50 elites | +3 luck |
| endless_20 | reach wave 20 in Endless | +5% XP |
| full_arsenal | own 4 player abilities in one run | +5% ability damage |
| survivor | play 10 runs | +10 starting Scrap |

- Achievements show **progress bars** ("1240 / 2000") and an icon.
- Progress counters live in the profile.

### 7.3 Profile schema 3
New fields:
- `selected_difficulty`, `selected_battle_skill`
- `difficulty_victories{recruit, soldier, veteran, warlord}`
- `endless_unlocked`, `best_endless_wave`
- `lifetime_elite_kills`, `lifetime_boss_kills{warchief, king}`, `lifetime_repair`, `runs_played`
- `tree_migrated_v3_notice`

The migration chain gets `_migrate_2_to_3`.

### 7.4 Settlement (rescaled for longer runs)

| Line | Cores |
| --- | --- |
| Per full minute | 1 |
| Per wave cleared | 2 |
| Per 25 kills | 1 |
| Per elite killed | 1 |
| Warchief killed | 8 (boss bounty, D255) |
| Final boss killed | 20 (boss bounty, D255) |
| Victory | 10 |
| Scrap carried | floor(Scrap / 10) |

The total is then multiplied by the difficulty's Cores multiplier and the Prospector and Founder bonuses. A Soldier win pays about 90-110 Cores. The full tree costs about 1,600, so it takes roughly 15-20 runs.

---

## 8. Interface

### 8.1 HUD (1920x1080 reference; scales with the HUD Scale setting)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ (Lv 7) ███████████ 82/100        [♜] █████████████░░ 410/500 ▮shield  (●)128 │
│        ▬▬▬▬▬▬▬▬▬ xp              WAVE 6/15 · SPLIT   04:32   ▬▬▬▬progress (☠)312│
│                                  [BOSS: GOBLIN WARCHIEF ████████████░░░]      │
│                                                                              │
│                                                                              │
│ [axe][fire][  ][  ]  [ballista][  ][  ]          (DASH ●●)  (SKILL ◔ E)      │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Top-left: Player**
- Level badge.
- HP bar with "cur/max" inside the bar.
- A thin XP bar beneath.
- No captions; the shapes and colours carry the meaning.

**Top-centre: Tower**
- Tower glyph and HP bar with the shield overlay and "cur/max" inside.
- "REPAIRING" tag while repair runs.
- Below it, one line: "WAVE n/15 · TYPE", the run timer and a thin wave-progress bar. The progress bar fills by time, or for boss waves by boss HP.
- The boss bar appears below it during boss waves.

**Top-right**
- Scrap: coin glyph and count.
- Kills: skull glyph and count.
- The Cores estimate moves to the pause menu.

**Bottom-left: build bar**
- 4 player ability slots and 3 Tower ability slots.
- Each slot shows the icon and level pips (1-5). Empty slots are dimmed.
- Passives are shown in the pause menu, not on the HUD.

**Bottom-right: action cluster**
- Dash: charge pips and a cooldown sweep, with the key hint.
- Battle Skill: a 96 px icon, a radial cooldown sweep, and the key hint.
- The key hints come from the live InputMap after rebinding.
- On touch, these are the touch buttons themselves.

**Removed**
- The full-width XP ribbon.
- "Rerolls" (now shown only in the Draft).
- The floating Tower HP label beside the off-screen arrow (the arrow stays).
- The duplicated captions.

**Overhead bars**
- Player and Tower overhead bars stay, behind a **Show overhead bars** setting (default on).

**Font sizes:** HUD numbers stay at 37 px, the legibility floor, at HUD scale 100%. Captions are removed rather than shrunk.

### 8.2 Pause menu
- Left column: Resume, Settings, How to Play, Abandon run.
- Right panel: **Build**. Abilities with their levels, passives with their ranks, the Battle Skill, the difficulty and the seed. Below it, **Run stats**: time, kills, elites, damage taken, Scrap repaired, and estimated Cores.

### 8.3 Results
- Outcome, cause and difficulty.
- Waves, time, kills and elites.
- Top-6 damage sources as bars.
- The Cores settlement lines.
- New achievements and new bests.
- Buttons: **Retry**, **War Camp**, **Main Menu**.

### 8.4 Settings (tabs)

| Tab | Options |
| --- | --- |
| Audio | Master, Music, Effects, **Interface** (new, drives the UI bus), Mute all |
| Video | Display mode, **Window size** (1280x720 / 1600x900 / 1920x1080 / 2560x1440, windowed only), V-Sync, **FPS limit** (30/60/120/144/240/Unlimited), **Show FPS** |
| Gameplay | **Auto-cast Battle Skill**, Damage numbers, **Screen shake 0-100%** (replaces the on/off toggle; 0 = off), **Show overhead bars**, **Pause when unfocused**, Movement-only controls |
| Controls | Rebind move up/down/left/right, Dash, Battle Skill and Pause (keyboard; first slot, plus one alternative). Saved in `settings.cfg` under `[controls]`. "Reset controls". Gamepad bindings are shown read-only. |
| Accessibility | **HUD scale** 75-150% in 5% steps, **Reduce flashing** (disables the vignette pulse, bar flashes and hit-flash strobing), **Enemy outlines** (an intent-coloured outline on every enemy for colour-vision support) |
| (all tabs) | **Reset to defaults**, with a confirm |

- Settings stays reachable from the title, the Hub and the pause menu, as today.
- The movement-only navigation contract still holds: up/down rows, left/right values, Back row hold-to-confirm, plus tab switching with Q/E and LB/RB.

### 8.5 Title and How to Play
- A **How to Play** page with four short sections:
  1. Protect yourself and the Tower.
  2. Dash and Battle Skill.
  3. Draft: abilities, passives and Tower cards.
  4. Repair with Scrap.
- The page names the live key bindings and is also reachable from pause.
- **Fix:** the title card overlaps the castle art at 1920x1080. This is an open item from v0.3.0.

---

## 9. Audio and art

- **SFX are project-made** by `tools/audio/make_sfx.py`, a pure-Python synth with deterministic seeds, writing 44.1 kHz mono 16-bit WAV to `assets/audio/sfx/`.
- Cues:
  - Combat: `bow_shot` (replaces the laser), `tower_bolt`, `dash`, `explosion`, `fuse`, `frost`, `ignite`, `lightning`, `axe_hit`, `caltrops`, `repair_tick`, `coin`, `xp_tick`, `level_up`, `wave_horn`, `siege_warning`, `elite_spawn`, `boss_roar`, `boss_slam`, `chest_open`, `skill_ready`.
  - Stingers: `victory`, `defeat`.
- **Music:** keep "Battle Theme A" for runs. Add one calm CC0 track for the title and War Camp if one can be sourced with provenance; otherwise the menus play the battle theme at -8 dB.
- **Icons** are 32x32, pack-style, extending `tools/art/make_pixel_icons.py`. The set covers:
  - every ability, passive, Battle Skill and difficulty;
  - dash, kills, burn, slow, freeze and elite;
  - the chest and meat pickups.
  - Files are `assets/ui/icons/icon_<id>.png`.
- **World art**:
  - Reused: `Dynamite.png` and `Explosions.png` (unused today), `Fire.png`, the meat sprites.
  - Project-made pixel sprites: the axe, caltrop, lightning segment, frost shard, war chest and ballista bolt.
  - The Bomber, Brute and bosses are modulate/scale variants of existing sheets, with SpriteFrames generated by `tools/art/generate_enemy_sprite_frames.py`.

---

## 10. Work packages

Each package runs as one Sonnet implementer in its own git worktree, branched from the WP0 commit. Each package owns a block of decision IDs and one Register subsection, so merges stay apart.

| WP | Scope | Decisions | Register subsection (insert AFTER) |
| --- | --- | --- | --- |
| WP0 (orchestrator) | This document; shared contracts: EventBus signals, `RunConfig`, `DifficultyProfile` + 4 .tres, GameSettings keys, input actions `dash` / `battle_skill`, `AbilityIds` | D171-D179 | "Onboarding & Session" → new "v1.0 Contracts" |
| WP-ASSETS | §9 SFX, icons, world sprites, SpriteFrames | D180-D189 | "Audio" |
| WP-COMBAT | §3, §4: dash, Battle Skills, auto-cast, repair, status effects, ability framework, all ability and passive cards, damage-source tagging | D190-D209 | "Player & Weapons" |
| WP-ENEMIES | §5, §6: Bomber, Brute, elites, bosses, meat and chest pickups, the 15-wave sequence, difficulty application, Endless, spawn markers, wave banner and Siege warning | D210-D229 | "Enemies" |
| WP-UI | §8.1, §8.2, §8.4, §8.5: HUD, pause build panel, Settings tabs, How to Play | D230-D249 | "Interfaces" |
| WP-META | §7, §8.3: tree v2, achievements, schema 3, Hub difficulty/skill/Endless pickers, Results with Retry and damage sources | D250-D269 | "Economy & Pickups" |
| WP-BALANCE | §6.3 bot runs and retune | D270-D279 | edits rows in place |
| WP-REVIEW | Blind Opus review → fix round | D280+ | — |

The packages share three files: `scenes/prototype.tscn`, `src/integration/prototype_integration.gd` and `MASTER_SDLC.md`. Each package keeps its edits there as small and local as it can, and the orchestrator resolves conflicts at merge.

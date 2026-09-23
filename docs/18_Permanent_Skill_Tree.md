# 18 - Permanent Skill Tree and the Hub

**Version:** 0.2.0
**Status:** Working draft, written 2026-09-23 by the orchestrator under the author's standing instruction to take the recommended option while away (decisions D109-D113 in the master's Review Decision Log). Every number below is a Provisional Default whose authority is the master's Provisional Values Register, rows "Meta: Run-End Settlement (prototype)", "Meta: Skill Tree costs", "Meta: Skill Tree effects" and "Meta: Save profile". Where this document and the Register disagree, the Register wins.

**Owns:** respec rules, unlock ordering, the Hub scene, and the guarantee that failed runs still advance the meta layer. The Meta Wallet rules are owned by document 14 (storage in document 24).

---

## 1. What the meta layer is for

A run of Horde Control is short and usually ends in failure. The meta layer makes every run, failed or not, leave something behind: **Cores** earned at run end are spent between runs on a **Skill Tree** of permanent bonuses in the **Hub** (the War Camp). The genre mould this follows (Vampire Survivors' Power Ups, Brotato, Halls of Torment, Rogue Legacy, and the author's reference, Booster Pack Heroes) has four fixed parts, and this design keeps all four:

1. A **results screen** that itemises what the run earned, shown only after the earnings are safely saved.
2. **One permanent currency** with no other sink.
3. **A tree of small, ranked, permanent bonuses**, cheap at the root and dearer at the edges, that reveals itself as the player invests.
4. **Bonuses apply at run start only.** Nothing in the meta layer changes a run that is already in progress.

## 2. Flow

```
Title --Play--> Hub (War Camp) --Start Run--> Run --ends--> Settlement (commit to disk)
                                                          --> Run-end screen (results) --Continue--> Hub
Pause menu --Main Menu--> abandon = failure settlement --> Run-end screen --> Hub
```

- Title's **Play** opens the Hub. The Hub has **Start Run**, the **Skill Tree**, the Core balance, the player's **Records**, and **Back to Title**.
- The run-end screen's primary action becomes **Continue** (to the Hub); Settings and Main Menu remain.
- The first time the Hub opens (no profile on disk), a one-line hint says: "Earn Cores in battle. Spend them here. Every run counts."

## 3. Earning Cores in the prototype (Run-End Settlement)

The master's settlement pays per biome cleared, per boss killed and per minute. The prototype has one biome and no bosses, so a failed prototype run would pay about one Core per minute, which is too slow to feel. The prototype adaptation (decision D110) pays, at every run end:

| Line | Rate |
| --- | --- |
| Time survived | 1 Core per full minute of simulation time (master rate, unchanged) |
| Waves cleared | 2 Cores per combat or teaching wave fully cleared |
| Kills | 1 Core per 25 enemies killed (floor) |
| Victory | 5 Cores for clearing the final wave, the master's "per biome cleared" rate, since the prototype arena is one biome |
| Prospector bonus | the Fortune node's percentage, applied to the sum, rounded down |

A typical first failed run (about 4 minutes, 4 waves, 100 kills) pays 4 + 8 + 4 = 16 Cores, enough for two or three root-adjacent nodes. That is the pacing target: the player buys something after every run for the first several runs.

**Settlement rules (all from the master, restated so the implementation cannot miss them):**
- Settlement is computed once per run, keyed by a run id, and is **idempotent**: a same-tick player-and-Tower death, or a death during an abandon, settles once.
- Settlement is **committed to disk before** the run-end screen is shown.
- **Abandon** (pause menu, Main Menu) settles as a failure with the same formula. **Closing the window mid-run** is treated as an abandon (decision D113): the close request settles and saves, then quits. A genuine crash pays only what was already saved.

## 4. The Skill Tree

### 4.1 Shape

A grid of nodes around a free root, the **Command Tent**, which every profile owns. Three branches leave the root: **Archer** (the player), **Tower**, and **Fortune** (economy). `grid_position` (the layout the Hub/Skill Tree screen draws) is cosmetic only; the real unlock graph is each node's explicit `prerequisite_ids` list (`src/data/skill_node_definition.gd`, `data/meta/skill_tree.tres`). **A node can be bought once EVERY node in its `prerequisite_ids` is owned at rank >= 1** — most nodes name exactly one parent, but the three tier-3 nodes (Long Reach, Watchtower, Deep Pockets) each name BOTH of their tier-2 siblings, so reaching one requires a rank in each of that branch's two tier-2 nodes first, not just one. A node is **revealed** (shown with name, effect and price rather than a locked silhouette) once it is owned or any one of its `prerequisite_ids` is owned — this is the Booster Pack Heroes fog, and it reveals strictly faster than a node becomes buyable for the two convergence nodes.

### 4.2 Nodes

Tier drives the price formula (section 4.3) and is authored per node in `data/meta/skill_tree.tres`, not derived from grid distance. Effects are applied at run start to runtime copies of the relevant definitions, never to the authored `.tres` files (`src/meta/meta_loadout_applier.gd`).

| Branch | Node | Tier | Max rank | Effect per rank |
| --- | --- | --- | --- | --- |
| Archer | Vitality | 1 | 3 | +10% player max health |
| Archer | Swift Boots | 1 | 3 | +4% player move speed |
| Archer | Sharpened Arrows | 2 | 3 | +8% player weapon damage |
| Archer | Quick Draw | 2 | 3 | +5% player fire rate |
| Archer | Long Reach | 3 | 2 | +20% pickup magnet radius |
| Archer | Second Wind (capstone) | 4 | 1 | once per run, a lethal hit leaves the player at 30% health instead |
| Tower | Stone Walls | 1 | 3 | +10% Tower max health |
| Tower | Arrow Slits | 1 | 3 | +10% Tower weapon damage |
| Tower | Shield Runes | 2 | 2 | +15% Tower max shield |
| Tower | Mason's Kit | 2 | 2 | -15% Tower Console repair price |
| Tower | Watchtower | 3 | 2 | +10% Tower weapon range |
| Tower | Fortress (capstone) | 4 | 1 | the Tower starts the run one evolution stage up |
| Fortune | Scavenger | 1 | 3 | start each run with 15 Scrap |
| Fortune | Scholar | 1 | 3 | +10% XP from shards |
| Fortune | Lucky Draw | 2 | 2 | +1 Level-Up Draft reroll per run |
| Fortune | Prospector | 2 | 2 | +15% Run-End Settlement Cores |
| Fortune | Deep Pockets | 3 | 1 | +50 Scrap carry cap |
| Fortune | War Chest (capstone) | 4 | 1 | start the run at level 1 with one free Level-Up Draft when the first wave begins |

### 4.3 Prices

Price of rank r (1-based) of a node of tier t: `base(t) x (1 + 0.5 x (r - 1))`, rounded to the nearest whole Core. `base` is 5, 10, 18 and 30 Cores for tiers 1 to 4. The whole tree costs a few hundred Cores, which at the section 3 rates is roughly 20 to 30 runs. That is the genre's usual length for a first meta pass.

### 4.4 Caps and balance

- Every percentage above stacks additively inside its node and multiplies once against the base value. Nothing in the tree may push a value past its Register cap. Where the Register states a maximum (move speed, fire rate), the tree's effect is clamped to it.
- The tree only raises stats the run already has. It never adds a new weapon, enemy or system; unlocks of new content are deferred to the vertical slice (document 17).

### 4.5 Buying, and respec

- **Buying** a rank is hold-to-confirm, matching every other confirm in the game: hold for the paused-menu hold duration on the Draft's Register row, with a fill ring. A click, a tap, or a controller press-and-hold all confirm. The Core counter animates down, the node pulses, and newly revealed neighbours fade in.
- **Can't afford:** the node shows its price in red, and the hold does nothing except a short shake.
- **Max rank:** the node shows MAX and is not holdable.
- **Respec** (decision D111): free and full. **Reset Tree** in the Hub (hold-to-confirm) refunds every Core spent and returns every node except the root to rank 0. It is available only in the Hub, never during a run. The alternative was a Core fee, as Rogue Legacy charges. It was rejected because a free refund makes experimenting safe, which is the dominant pattern in the genre (Vampire Survivors, Brotato).

## 5. Records

The profile keeps each player's best wave reached, longest time survived, most kills in a run, total runs, total victories and lifetime Cores earned. The run-end screen marks a new best with **NEW BEST**, and the Hub shows the records.

## 6. Edge cases (all must have a test)

| Case | Behaviour |
| --- | --- |
| Player and Tower die on the same tick | One settlement (idempotent by run id) |
| Abandon from the pause menu | Failure settlement, committed, then the results screen |
| Window closed mid-run | Treated as an abandon: settle, save, quit |
| Crash mid-run | Only what was already saved survives; no retroactive bonus |
| Save interrupted mid-write | The previous complete profile loads (document 24) |
| Profile unreadable or corrupt | Load the backup; if that fails too, start a fresh profile and tell the player once in the Hub ("Your save could not be read; a new profile was started. The damaged file was kept as profile.corrupt.json") |
| Save write fails (disk full or read-only) | Keep the in-memory state, show a non-blocking warning in the Hub, retry at the next save point |
| Tree definition changes between versions (a node removed, or its max rank lowered) | On load, refund the Cores spent on ranks that no longer exist |
| Buying with too few Cores | Refused, with the shake; no state change |
| Double input on purchase (held key repeats) | One rank per completed hold; the hold must release before the next |
| Currency overflow | The wallet is a 64-bit int clamped at 999,999 |
| Meta bonuses mid-run | Never. Loadout is computed once at run start and frozen for the run |
| Second Wind and Tower death | Second Wind protects only the player; the Tower's death still ends the run |
| War Chest and teaching waves | The free draft opens when the first wave begins, not during the title-to-run transition |
| Starting a run with the Console open or a Draft queued from the previous run | Impossible: a run always starts from a fresh prototype scene |
| A percentage-bonus node and the matching in-run upgrade both apply to the same stat (e.g. Sharpened Arrows and Rapid Fire, both weapon damage) | They compose as `base x (1 + meta) x (1 + upgrade)`, not `base x (1 + meta + upgrade)`. The meta bonus is folded into the BASE value a runtime-copied definition carries (`src/meta/meta_loadout_applier.gd`) before the run's own upgrade multiplier (a separate, replace-not-compound field on the same weapon/Tower component) ever reads it, so the two never collide or overwrite each other. This is a deliberate interpretation, not C-STACK's literal reading (C-STACK governs bonuses to the same stat within ONE channel): meta progression and one run's own upgrades are different systems on different timescales, and folding the meta bonus into the base is the only route available that touches neither `src/upgrade/upgrade_system.gd` nor the upgrade multiplier's own contract |

## 7. What is deliberately not here yet

Field Core drops from Elites and bosses (none exist in the prototype); the overflow-hopper conversion (the prototype has no hopper); new-content unlocks; prestige; quests and achievements. Booster Pack Heroes uses quests to gate tree regions and a prestige reset. Both are candidates for the vertical slice, recorded in docs/30_Future_Ideas.md.

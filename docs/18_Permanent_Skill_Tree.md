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
| Scrap (D115) | floor(Scrap carried / 10) Cores. D115 (no in-run shop) removed the Tower Console, so Scrap has no other sink; this converts whatever reaches settlement (the Scrap cap and loss-on-death rules still apply to what reaches this line) into permanent progression instead of discarding it |
| Prospector bonus | the Fortune node's percentage, applied to the sum (including the Scrap line above), rounded down |

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
| Tower | Mason's Kit | 2 | 2 | +10% Tower shield regen rate per rank (D115: repurposed from its former -15% Tower Console repair price now that the Console is removed) |
| Tower | Watchtower | 3 | 2 | +10% Tower weapon range |
| Tower | Fortress (capstone) | 4 | 1 | the Tower starts the run one evolution stage up, with +20% max health and +20% weapon damage (D114) |
| Fortune | Scavenger | 1 | 3 | start each run with 15 Scrap |
| Fortune | Scholar | 1 | 3 | +10% XP from shards |
| Fortune | Lucky Draw | 2 | 2 | +1 Level-Up Draft reroll per run |
| Fortune | Prospector | 2 | 2 | +15% Run-End Settlement Cores |
| Fortune | Lucky Charm | 2 | 2 | +3 rarity-luck points per rank, shifting Draft card rarity odds from Common toward Rare/Epic (D117); a side node off Scavenger, not part of the Lucky Draw/Prospector pair Deep Pockets requires |
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

| Case | Behaviour | Test |
| --- | --- | --- |
| Player and Tower die on the same tick | One settlement (idempotent by run id) | `meta_run_flow_settlement_test.gd::test_player_and_tower_dying_the_same_tick_settles_exactly_once`; `meta_progress_settlement_test.gd::test_same_tick_double_death_with_the_same_run_id_settles_once` |
| Abandon from the pause menu | Failure settlement, committed, then the results screen | `meta_run_flow_settlement_test.gd::test_abandon_via_pause_menu_settles_and_shows_the_run_end_screen_not_the_title` |
| Window closed mid-run | Treated as an abandon: settle, save, quit | `meta_run_flow_settlement_test.gd::test_window_close_during_a_run_settles_as_abandon_and_saves` |
| Crash mid-run | Only what was already saved survives; no retroactive bonus | `meta_progress_save_test.gd::test_kill_after_tmp_write_leaves_previous_profile_intact`; `::test_kill_after_bak_write_leaves_previous_profile_intact` |
| Save interrupted mid-write | The previous complete profile loads (document 24); if `profile.json` itself is missing but a fully-written `profile.json.tmp` survives (a non-atomic `DirAccess.rename` on Windows), the `.tmp` is the newest complete write and loads ahead of `.bak` | `meta_progress_save_test.gd::test_kill_after_tmp_write_leaves_previous_profile_intact`; `::test_kill_after_bak_write_leaves_previous_profile_intact`; `::test_missing_profile_json_with_a_parseable_tmp_loads_from_the_tmp` |
| Profile unreadable or corrupt | Load the backup; if that fails too, start a fresh profile and tell the player once in the Hub ("Your save could not be read; a new profile was started. The damaged file was kept as profile.corrupt.json"). The banner clears itself once shown (it does not persist across every future Hub visit) and a save must never back up a `profile.json` that itself failed to parse, or a corruption recovery's last good `.bak` would be destroyed by the very next save | `meta_progress_save_test.gd::test_corrupt_profile_falls_back_to_backup`; `::test_corrupt_profile_and_backup_falls_back_to_fresh`; `::test_a_corrupt_profile_on_disk_is_never_copied_into_bak_by_a_later_save`; `hub_screen_test.gd::test_a_recovered_from_corruption_profile_shows_the_warning_banner`; `::test_the_recovered_from_corruption_banner_never_shows_again_once_acknowledged`; `::test_the_recovered_from_corruption_flag_is_cleared_on_disk_not_only_in_memory` |
| Save write fails (disk full or read-only) | Keep the in-memory state, show a non-blocking warning in the Hub, retry at the next save point; a save that succeeds afterward must clear the warning both in memory and on disk (never carry a PREVIOUS failure into a successful write's own file) | `meta_progress_save_test.gd::test_a_failed_save_sets_last_save_failed_and_a_later_successful_save_clears_it_on_disk` |
| Newer-schema profile (a build older than the one that wrote it) | Loads read-only (`flags.read_only_newer_version`); every write is refused outright and the file on disk is never overwritten; the results screen must not claim Cores were saved when they were not | `meta_progress_save_test.gd::test_a_newer_schema_profile_loads_read_only_and_is_never_overwritten`; `run_end_outcome_style_test.gd::test_settlement_not_saved_shows_the_not_saved_message_instead_of_a_total` |
| Tree definition changes between versions (a node removed, or its max rank lowered) | On load, refund the Cores spent on ranks that no longer exist | `meta_progress_save_test.gd::test_reconcile_refunds_a_rank_above_current_max_and_clamps_it`; `::test_reconcile_refunds_and_drops_an_unknown_node_id` |
| Buying with too few Cores | Refused, with the shake; no state change | `meta_progress_economy_test.gd::test_buy_refuses_when_cores_are_insufficient`; `skill_tree_screen_test.gd::test_holding_confirm_on_an_unaffordable_node_never_buys_it` |
| Double input on purchase (held key repeats) | One rank per completed hold; the hold must release before the next | `skill_tree_screen_test.gd::test_holding_confirm_continuously_buys_only_one_rank_per_release` |
| Standing still on a buyable node (the Skill Tree screen's own movement-only path) | Only fills the hold ring and buys when the Movement-only controls setting is actually ON (the same source Console reads); Reset Tree is NEVER buyable via stand-still, in either mode -- respec always requires an explicit held confirm | `skill_tree_screen_test.gd::test_standing_still_on_a_buyable_node_buys_nothing_when_movement_only_is_off`; `::test_standing_still_on_a_buyable_node_buys_it_when_movement_only_is_on`; `::test_standing_still_on_reset_tree_never_respecs_with_movement_only_off`; `::test_standing_still_on_reset_tree_never_respecs_even_with_movement_only_on` |
| Currency overflow | The wallet is a 64-bit int clamped at 999,999; a respec refund or a settlement that would push past the cap must report the amount ACTUALLY credited, not the raw pre-clamp total | `meta_progress_economy_test.gd::test_core_wallet_is_clamped_at_the_register_cap`; `::test_respec_reports_the_clamped_amount_actually_credited_not_the_raw_refund`; `::test_settle_run_reports_the_clamped_amount_actually_credited_near_the_wallet_cap` |
| Meta bonuses mid-run | Never. Loadout is computed once at run start and frozen for the run; a later Skill Tree purchase or respec must never retroactively change a `MetaLoadout` already handed to a run | `meta_progress_skill_tree_queries_test.gd::test_a_loadout_already_built_is_never_recomputed_by_a_later_tree_change` |
| Second Wind and Tower death | Second Wind protects only the player; the Tower's death still ends the run | `meta_loadout_applier_test.gd::test_second_wind_does_not_protect_the_tower_from_lethal_damage` |
| War Chest and teaching waves | The free draft opens when the first wave begins, not during the title-to-run transition | `meta_loadout_applier_test.gd::test_war_chest_queues_a_free_draft_only_when_the_first_wave_opens` |
| Starting a run with the Console open or a Draft queued from the previous run | Impossible: a run always starts from a fresh prototype scene. Verified against the real, fully-assembled scene rather than asserted from the absence of a mechanism: neither `Console` nor `DraftController` carries any `static var` of its own (checked directly), so two independently-instantiated prototype scenes never share state | `meta_fresh_run_isolation_test.gd::test_a_fresh_prototype_scene_never_inherits_a_queued_or_showing_draft_from_a_previous_instance`; `::test_a_fresh_prototype_scenes_console_starts_closed_independent_of_a_previous_instance` |
| A percentage-bonus node and the matching in-run upgrade both apply to the same stat (e.g. Sharpened Arrows and Rapid Fire, both weapon damage) | They compose as `base x (1 + meta) x (1 + upgrade)`, not `base x (1 + meta + upgrade)`. The meta bonus is folded into the BASE value a runtime-copied definition carries (`src/meta/meta_loadout_applier.gd`) before the run's own upgrade multiplier (a separate, replace-not-compound field on the same weapon/Tower component) ever reads it, so the two never collide or overwrite each other. This is a deliberate interpretation, not C-STACK's literal reading (C-STACK governs bonuses to the same stat within ONE channel): meta progression and one run's own upgrades are different systems on different timescales, and folding the meta bonus into the base is the only route available that touches neither `src/upgrade/upgrade_system.gd` nor the upgrade multiplier's own contract | `meta_loadout_applier_test.gd::test_meta_weapon_damage_bonus_and_an_in_run_upgrade_multiplier_compose_multiplicatively_not_additively` |

Every row's own headless test is listed above; none of these rows were found to be genuinely untestable headless.

## 7. What is deliberately not here yet

Field Core drops from Elites and bosses (none exist in the prototype); the overflow-hopper conversion (the prototype has no hopper); prestige; quests. Booster Pack Heroes uses quests to gate tree regions and a prestige reset; both are candidates for the vertical slice, recorded in docs/30_Future_Ideas.md. Achievements (decision D118, section 8 below) and the small set of Draft-card unlocks they gate are no longer on this "not yet" list -- they exist in the prototype now, gating specific cards rather than whole tree regions.

## 8. Achievements (decision D118)

A small, data-driven list (`data/meta/achievements.tres`, `src/data/achievement_definition.gd`/`achievement_list.gd`) of lifetime and per-run goals tracked in the save profile (schema_version 2; document 24's migration chain) and evaluated once per run, at Run-End Settlement (`MetaProgress.settle_run()`'s own `_evaluate_achievements()`) -- kills/Scrap-collected lifetime counters are updated by that same call, from the run's own final tallies, rather than polled live mid-run. Each achievement names an `id`, a display `name`/`description`, a `metric` (a String key `_evaluate_achievements()` interprets: `lifetime_kills`/`lifetime_scrap_collected` are cumulative profile counters; `run_waves_cleared`/`run_victory`/`run_tower_health_fraction` read the CURRENT run's own settlement summary, never cumulative), a `threshold`, and exactly one of `unlocks_card_id` (a Draft card's `unique_id`) or `perk_id` (a small fixed permanent effect `MetaLoadoutApplier` applies at run start, no card involved). `src/upgrade/upgrade_system.gd`'s `get_offerable_upgrades()`/`get_fallback_card()` never return a card flagged `is_unlock` (`UpgradeDefinition.is_unlock`) until `MetaProgress.get_unlocked_card_ids()` names it -- so an UNLOCK card simply never appears in a fresh profile's Draft pool, no separate gating mechanism required. Of the ten cards the pool expansion (Register > "Progression & Upgrades") adds, exactly three are `is_unlock` (Piercing Arrows, Multishot, Tower Volley); the other seven are offerable from a profile's first run, same as the original eight.

The six prototype achievements: Goblin Slayer (300 lifetime kills -> unlocks Piercing Arrows), Veteran (reach wave 5 in one run -> unlocks Multishot), Keeper of the Keep (end a run with the Tower above 50% health -> unlocks Tower Volley), Hoarder (500 lifetime Scrap collected -> perk `bonus_reroll`, +1 Level-Up Draft reroll per run, composing additively with Lucky Draw's own ranks), Founder (win a run -> perk `settlement_cores_bonus`, +5% Run-End Settlement Cores, composing additively with Prospector), and Marksman (1000 lifetime kills -> perk `weapon_damage_bonus`, +5% player weapon damage, composing additively with Sharpened Arrows). The three card-unlock achievements were chosen to match exactly the three `is_unlock` cards the pool authors; the three perk achievements were chosen instead of a fourth-through-sixth card unlock specifically to avoid an achievement claiming to "unlock" a card the pool already offers from the start (Regeneration, for one, is NOT `is_unlock` -- an achievement cannot meaningfully gate it). A newly unlocked achievement is listed on the run-end results screen ("Achievement unlocked: <name>") and shown, with every other achievement's progress, in the Hub's Achievements panel (reusing `records_panel.gd`'s read-only-rows-from-a-MetaProgress-query pattern).

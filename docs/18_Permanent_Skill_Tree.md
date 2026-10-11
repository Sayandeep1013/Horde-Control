# 18 - Permanent Skill Tree and the Hub

**Version:** 0.3.0
**Status:** Working draft, written 2026-09-23 by the orchestrator under the author's standing instruction to take the recommended option while away (decisions D109-D113 in the master's Review Decision Log); rebuilt for v1.0 on 2026-10-11 under the author's release brief (decisions D250-D254, docs/31 section 7). Every number below is a Provisional Default whose authority is the master's Provisional Values Register, rows "Meta: Run-End Settlement (prototype)", "Meta: Skill Tree costs", "Meta: Skill Tree effects", "Meta: Save profile", "Meta: Achievements" and the "v1.0 Meta Progression" subsection. Where this document and the Register disagree, the Register wins.

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
                                                          --> Results --Retry--> a new Run (same RunConfig)
                                                                      --War Camp--> Hub     --Main Menu--> Title
Pause menu --Main Menu--> abandon = failure settlement --> Results
```

- Title's **Play** opens the Hub. The Hub has a **Run Setup** card (Difficulty, Battle Skill, Endless toggle, **Start Run**) and a menu card (the **Skill Tree**, **Records**, **Achievements**, **Settings**, **Back to Title**), plus the Core balance. Section 9 describes the setup card.
- The Results screen offers **Retry**, **War Camp** and **Main Menu** (section 10). The old "Continue" is gone: it did not say where it went.
- The first time the Hub opens (no profile on disk), a one-line hint says: "Earn Cores in battle. Spend them here. Every run counts."

## 3. Earning Cores in the prototype (Run-End Settlement)

The master's settlement pays per biome cleared, per boss killed and per minute. The prototype has one biome and no bosses, so a failed prototype run would pay about one Core per minute, which is too slow to feel. The prototype adaptation (decision D110) pays, at every run end:

| Line | Rate |
| --- | --- |
| Time survived | 1 Core per full minute of simulation time (master rate, unchanged) |
| Waves cleared | 2 Cores per combat or teaching wave fully cleared |
| Kills | 1 Core per 25 enemies killed (floor) |
| Elites (D253) | 1 Core per elite killed |
| Victory (D253) | 10 Cores for a victory (the Bombardier King killed); the prototype's 5 for "the final wave" is superseded |
| Scrap (D115) | floor(Scrap carried / 10) Cores. D115 (no in-run shop) removed the Tower Console, so Scrap has no other sink; this converts whatever reaches settlement (the Scrap cap and loss-on-death rules still apply to what reaches this line) into permanent progression instead of discarding it |
| Bonuses | the Prospector node's percentage, plus Founder's +5% and Regicide's +10% once earned, added together and applied once to the sum (including the Scrap line above), rounded down |
| Difficulty (D253) | the difficulty's Cores multiplier (Recruit x0.75, Soldier x1.0, Veteran x1.4, Warlord x1.85), applied last, shown as its own line when it is not 1 |

Boss kills pay as field drops (8 Cores for the Goblin Warchief, 20 for the Bombardier King, docs/31 section 5.3), not through settlement. A Soldier win pays about 90 to 110 Cores, and a typical first failed run pays 20 to 40: enough for a node or two after every early run. That is the pacing target.

**Unlock chain (D253).** A victory is recorded per difficulty. A Soldier win unlocks Veteran, a Veteran win unlocks Warlord, and any win unlocks Endless. A defeat unlocks nothing. An Endless run records its best wave. The settlement breakdown names what a run newly unlocked so the Results screen can say so.

**Settlement rules (all from the master, restated so the implementation cannot miss them):**
- Settlement is computed once per run, keyed by a run id, and is **idempotent**: a same-tick player-and-Tower death, or a death during an abandon, settles once.
- Settlement is **committed to disk before** the run-end screen is shown.
- **Abandon** (pause menu, Main Menu) settles as a failure with the same formula. **Closing the window mid-run** is treated as an abandon (decision D113): the close request settles and saves, then quits. A genuine crash pays only what was already saved.

## 4. The Skill Tree

### 4.1 Shape

A grid of nodes around a free root, the **Command Tent**, which every profile owns. Five branches leave the root (v1.0, D250): **Archer** (west), **Survival** (north), **Battle Skills** (north-east), **Tower** (east) and **Fortune** (south). Each node shows its name on the board (a 236 by 164 tablet with the name in two lines at most, a pixel icon, rank pips and the price), and a small tinted ribbon names each branch. `grid_position` (the layout the Hub/Skill Tree screen draws) is cosmetic only; the real unlock graph is each node's explicit `prerequisite_ids` list (`src/data/skill_node_definition.gd`, `data/meta/skill_tree.tres`). **A node can be bought once EVERY node in its `prerequisite_ids` is owned at rank >= 1** — most nodes name exactly one parent, but four nodes (Armory, Second Dash, Watchtower, Deep Pockets) each name BOTH of two parents, so reaching one requires a rank in each of them first, not just one. A node is **revealed** (shown with name, effect and price rather than a locked silhouette) once it is owned or any one of its `prerequisite_ids` is owned — this is the Booster Pack Heroes fog, and it reveals strictly faster than a node becomes buyable for the convergence nodes.

### 4.2 Nodes (v2, D250)

Tier drives the price formula (section 4.3) and is authored per node in `data/meta/skill_tree.tres` (generated from the table in `tools/meta/make_meta_data.py`), not derived from grid distance. Effects are applied at run start to runtime copies of the relevant definitions, never to the authored `.tres` files (`src/meta/meta_loadout_applier.gd`). Effects that act on systems the meta layer does not own (dash, crit, damage taken, Battle Skill cooldown and damage, ability damage, Tower repair, the Armory grant) call a small named method on the AbilityManager (group `ability_manager`), skipped silently when it is absent.

| Branch | Node | Tier | Ranks | Effect per rank | Needs |
| --- | --- | --- | --- | --- | --- |
| Archer | Sharpened Arrows | 1 | 3 | +8% arrow damage | Tent |
| Archer | Quick Draw | 1 | 3 | +6% fire rate | Tent |
| Archer | Keen Eye | 3 | 3 | +4% critical chance | Sharpened Arrows |
| Archer | Eagle Eye | 2 | 2 | +10% bow range | Quick Draw |
| Archer | Armory (keystone) | 4 | 1 | start each run with a free Level 1 player ability | Keen Eye and Eagle Eye |
| Survival | Vitality | 1 | 3 | +10% player max health | Tent |
| Survival | Swift Boots | 1 | 3 | +4% move speed | Vitality |
| Survival | Iron Skin | 3 | 3 | -5% damage taken | Vitality |
| Survival | Fleet Foot | 2 | 2 | -10% dash cooldown | Swift Boots |
| Survival | Second Dash | 3 | 1 | +1 dash charge | Fleet Foot and Iron Skin |
| Survival | Second Wind (capstone) | 4 | 1 | once per run, a lethal hit leaves the player at 30% health | Second Dash |
| Battle Skills | Skill Focus | 2 | 3 | -8% Battle Skill cooldown | Tent |
| Battle Skills | Skill Power | 4 | 3 | +15% Battle Skill damage | Skill Focus |
| Battle Skills | Frost Nova | 2 | 1 | unlocks the Frost Nova Battle Skill in the War Camp | Skill Focus |
| Battle Skills | Firebomb | 3 | 1 | unlocks the Firebomb Battle Skill | Skill Focus |
| Battle Skills | War Horn | 3 | 1 | unlocks the War Horn Battle Skill | Frost Nova |
| Tower | Stone Walls | 1 | 3 | +10% Tower max health | Tent |
| Tower | Arrow Slits | 1 | 3 | +10% Tower damage | Tent |
| Tower | Shield Runes | 2 | 2 | +15% Tower max shield | Stone Walls |
| Tower | Mason's Kit | 2 | 2 | +20% Tower repair per Scrap (D115's shield-regen use is retired) | Arrow Slits |
| Tower | Watchtower | 3 | 2 | +10% Tower range | Shield Runes and Mason's Kit |
| Tower | Engineers | 4 | 2 | +15% Tower ability damage | Mason's Kit |
| Tower | Fortress (capstone) | 4 | 1 | the Tower starts one evolution stage up, +20% max health and +20% damage (D114) | Watchtower |
| Fortune | Scavenger | 1 | 3 | start with +15 Scrap | Tent |
| Fortune | Scholar | 1 | 3 | +10% experience | Scavenger |
| Fortune | Lucky Draw | 2 | 2 | +1 Draft reroll | Scavenger |
| Fortune | Lucky Charm | 2 | 2 | +3 rarity-luck points (D117) | Lucky Draw |
| Fortune | Prospector | 3 | 2 | +15% settlement Cores | Scholar |
| Fortune | Deep Pockets | 3 | 1 | +50 Scrap carry cap | Lucky Draw and Prospector |
| Fortune | War Chest (capstone) | 4 | 1 | start at level 1 with one free Draft when the first wave begins | Deep Pockets |

The Battle Skill nodes gate what the War Camp offers: Arrow Storm is always open, and each other skill is selectable only once its node is owned. Respec relocks them, and a saved choice that is no longer unlocked falls back to Arrow Storm on the next load. Long Reach (pickup magnet) left the tree: Magnet is a Draft card.

### 4.3 Prices

Price of rank r (1-based) of a node of tier t: `base(t) x (1 + 0.5 x (r - 1))`, rounded to the nearest whole Core. `base` is 8, 16, 28 and 45 Cores for tiers 1 to 4 (v2; it was 5 / 10 / 18 / 30). The whole tree costs 1,616 Cores, which at the section 3 rates is roughly 15 to 20 victories. A test pins the figure.

### 4.4 Caps and balance

- Every percentage above stacks additively inside its node and multiplies once against the base value. Nothing in the tree may push a value past its Register cap. Where the Register states a maximum (move speed, fire rate), the tree's effect is clamped to it.
- The tree only raises stats the run already has. It never adds a new weapon, enemy or system; unlocks of new content are deferred to the vertical slice (document 17).

### 4.5 Buying, and respec

- **Buying** a rank takes a **0.5 s hold** (D250: this tree's own Register figure, shorter than the Draft's 1.0 s) with a fill ring, OR a quick **click or tap** (a press and release under 0.35 s) on the node that is already selected. Mouse hover selects, so a click buys; on a touch screen the first tap selects and the second buys. A press-and-hold with a pad button or Space still works and is the movement-only path (docs/19), and one gesture never buys twice. The board scrolls to keep the selected node in view, and opens centred on the Tent. The Core counter animates down, the node pulses, and newly revealed neighbours fade in.
- **Can't afford:** the node shows its price in red, and the hold does nothing except a short shake.
- **Max rank:** the node shows MAX and is not holdable.
- **Respec** (decision D111): free and full. **Reset Tree** in the Hub (hold-to-confirm) refunds every Core spent and returns every node except the root to rank 0. It is available only in the Hub, never during a run. The alternative was a Core fee, as Rogue Legacy charges. It was rejected because a free refund makes experimenting safe, which is the dominant pattern in the genre (Vampire Survivors, Brotato).

## 5. Records

The profile keeps each player's best wave reached, longest time survived, most kills in a run, total runs, total victories, lifetime Cores earned, best Endless wave, elites defeated and bosses defeated. The Results screen marks a new best with **NEW BEST**, and the Hub shows the records.

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
| Starting a run with a Draft queued from the previous run | Impossible: a run always starts from a fresh prototype scene. Verified against the real, fully-assembled scene rather than asserted from the absence of a mechanism: neither `Console` nor `DraftController` carries any `static var` of its own (checked directly), so two independently-instantiated prototype scenes never share state | `meta_fresh_run_isolation_test.gd::test_a_fresh_prototype_scene_never_inherits_a_queued_or_showing_draft_from_a_previous_instance`; `::test_a_fresh_prototype_scenes_console_starts_closed_independent_of_a_previous_instance` |
| A percentage-bonus node and the matching in-run upgrade both apply to the same stat (e.g. Sharpened Arrows and Rapid Fire, both weapon damage) | They compose as `base x (1 + meta) x (1 + upgrade)`, not `base x (1 + meta + upgrade)`. The meta bonus is folded into the BASE value a runtime-copied definition carries (`src/meta/meta_loadout_applier.gd`) before the run's own upgrade multiplier (a separate, replace-not-compound field on the same weapon/Tower component) ever reads it, so the two never collide or overwrite each other. This is a deliberate interpretation, not C-STACK's literal reading (C-STACK governs bonuses to the same stat within ONE channel): meta progression and one run's own upgrades are different systems on different timescales, and folding the meta bonus into the base is the only route available that touches neither `src/upgrade/upgrade_system.gd` nor the upgrade multiplier's own contract | `meta_loadout_applier_test.gd::test_meta_weapon_damage_bonus_and_an_in_run_upgrade_multiplier_compose_multiplicatively_not_additively` |

Every row's own headless test is listed above; none of these rows were found to be genuinely untestable headless.

## 7. What is deliberately not here yet

Field Core drops from Elites and bosses (none exist in the prototype); the overflow-hopper conversion (the prototype has no hopper); prestige; quests. Booster Pack Heroes uses quests to gate tree regions and a prestige reset; both are candidates for the vertical slice, recorded in docs/30_Future_Ideas.md. Achievements (decision D118, section 8 below) and the small set of Draft-card unlocks they gate are no longer on this "not yet" list -- they exist in the prototype now, gating specific cards rather than whole tree regions.

## 8. Achievements (decisions D118, D251)

A data-driven list (`data/meta/achievements.tres`, generated from `tools/meta/make_meta_data.py`; `src/data/achievement_definition.gd`) of 16 goals tracked in the save profile (schema_version 3; document 24) and evaluated once per run, at Run-End Settlement (`MetaProgress.settle_run()`). The profile's lifetime counters (kills, Scrap collected, elites, boss kills, Tower repaired, runs played, victories per difficulty, best Endless wave) are updated by that same call from the run's own tallies, before the achievements are checked, so a threshold crossed by this run unlocks on this settlement. Each achievement names an `id`, a name, a description, an `icon_id`, a `metric`, a `threshold`, and exactly one of `unlocks_card_id` (a Draft card's `unique_id`) or `perk_id` (a small fixed permanent effect `MetaLoadoutApplier` applies at run start). **Cumulative** metrics (`lifetime_kills`, `lifetime_scrap_collected`, `lifetime_elite_kills`, `lifetime_repair`, `lifetime_boss_kills_warchief`, `victories_total`, `difficulty_victories_warlord`, `best_endless_wave`, `runs_played`) read a profile counter and show a progress bar. **Per-run** metrics (`run_wave_reached`, `run_victory`, `run_victory_tower_fraction`, `run_king_killed_hard`, `run_untouchable_wave`, `run_player_abilities`) read this run's summary only, and their bar stays empty ("In one run") until earned.

| Achievement | Condition | Reward |
| --- | --- | --- |
| Goblin Slayer | 300 lifetime kills | unlocks Frost Arrows |
| Veteran | reach wave 8 in a run | unlocks Storm Bolt |
| Keeper of the Keep | win with the Tower above 50% health | unlocks Spiked Palisade |
| Warchief Slayer | defeat the Goblin Warchief | unlocks Catapult |
| Sanctified | win a run on any difficulty | unlocks Sacred Ground |
| Hoarder | 1,000 lifetime Scrap collected | +1 Draft reroll per run |
| Founder | win your first run | +5% Cores |
| Marksman | 2,000 lifetime kills | +5% weapon damage |
| Regicide | defeat the Bombardier King on Veteran or Warlord | +10% Cores |
| Warlord | win on Warlord | the Warlord title on the Results screen and a gold Tower tint |
| Untouchable | clear wave 5 or later without taking damage | +5% move speed |
| Mason | repair 2,000 Tower health in total | +10% repair per Scrap |
| Elite Hunter | defeat 50 elites | +3 luck |
| Endless Marathon | reach wave 20 in Endless | +5% experience |
| Full Arsenal | hold 4 player abilities in one run | +5% ability damage |
| Survivor | play 10 runs | +10 starting Scrap |

Perks compose additively with their tree counterpart (Mason with Mason's Kit, Founder and Regicide with Prospector, and so on). The five unlock-gated Draft cards (Frost Arrows, Storm Bolt, Sacred Ground, Catapult, Spiked Palisade) never appear in the Draft until their achievement is unlocked; Multishot and Piercing Arrows start unlocked in v1.0. Untouchable and Full Arsenal read `RunFlowController`'s own tallies (damage taken per wave from `CombatStats`, and `ability_leveled` signals for player abilities); the Achievements panel shows each goal with its icon, the reward, and a bar ("1240 / 2000").

## 9. The War Camp's run setup (decision D254)

The Hub's **Run Setup** card holds, top to bottom: the **Difficulty** picker (Recruit, Soldier, Veteran, Warlord), the **Battle Skill** picker (Arrow Storm, Frost Nova, Firebomb, War Horn), an **Endless** toggle (hidden until a victory unlocks it), a hint line and **Start Run**. A locked option is a greyed tablet; focusing or pressing it says what opens it ("Locked. Win a run on Soldier to open it." or "Locked. Buy Frost Nova in the Skill Tree."). Each choice is saved in the profile as it is made. **Start Run** writes the three choices into `RunConfig` and only then changes scene. The pickers are ordinary Buttons on Godot's native focus chain (up, down, left, right to move, Space or Enter to choose), so the movement-only contract and touch both hold. After a profile migration a one-time banner says the Skill Tree was rebuilt. The Hub plays the calm "Town Theme RPG" on the Music bus, looping.

## 10. The Results screen (decision D254)

Outcome, cause and difficulty (with "Endless" when it was on); waves, time, Scrap, kills and elites; a top-6 **damage by source** list (icon, name, a bar scaled to the biggest source, the number; sources are the ability ids, `bow`, `tower_bow`, `burn` and `spiked_palisade`); the Cores settlement lines and total; ribbons for new bests, a new Endless best, a difficulty or Endless unlock, and each new achievement. **Retry** starts a new run with the same `RunConfig` (difficulty, Battle Skill and Endless are static, so they survive the scene reload), **War Camp** goes to the Hub and **Main Menu** to the title. A Veteran or harder victory is recorded against that difficulty. Victory is the Bombardier King killed (the `boss_defeated` signal); in Endless the run ends only on defeat.

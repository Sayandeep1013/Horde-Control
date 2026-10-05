# Horde Control: Game Design Review (gameplay)

**Date:** 2026-10-05 | **Build:** `main` @ 767f279 | **Reviewer role:** senior game design engineer (gameplay). A separate UX review covers screens, HUD layout and menus (`UX_REVIEW.md`).
**Scope:** core loop, player agency, the Tower, enemies, pacing, pickups and economy, the Draft, meta progression, feel, onboarding, and win/fail states.
**Status:** This is a review input. It is not a gate verdict. Numeric fixes below are proposals. Each one needs a Provisional Values Register edit and a Review Decision Log row before it lands.

---

## 1. Verdict

Horde Control today is a well-built, good-looking single-screen Tower-defence survivor. The engine, data contracts and UI work are solid. But **it currently has no gameplay pressure: a player who never touches the keyboard wins.** I ran a headless bot that stands still at the spawn point and always takes a Draft card. It won **5 of 5 runs across 4 run seeds**, in 6:40 to 6:57. It never dropped below 28 HP, and it took no player damage at all after the first 20 seconds. The Tower takes real damage only in teaching waves T3 and T4. In every run, all four combat waves, including the two Sieges, failed to get through the Tower's regenerating shield.

Three engineering defects make this worse:
- The camera never follows the player. Its `target` is `null` at runtime, so it stays pinned on the Tower.
- Every run uses the same fixed seed, so all runs are identical.
- The Draft's rarity maths can make an upgrade weaker, and two Tower range cards overwrite each other.

**The biggest design problem: the central tension, "the player is strongest where they stand, the Tower is weakest where they are not", is not live.** Standing next to the Tower is both the safest place and the winning strategy. Pickups are the only lure away from it, and they are optional. Scrap, half of everything that drops, does nothing during a run.

---

## 2. Evidence base

| Probe | What I did | Result |
| --- | --- | --- |
| **Still bot** | A headless prototype run (`--fixed-fps 60`) with **zero input**. It confirms the first Draft card each time (or a random card, on seeds 11/222/3333). Script: `sandbox/captures/gd/bot_sim.gd` (gitignored). | **Victory 5/5.** Default seed: 400 s, player 100/100, Tower 400/500, 4 Drafts, 67 Scrap (`bot_still_default.log`). Seeds 11/222/3333: victory at 409/414/417 s. Player HP was 28/50/82 and frozen from t≈20 s to the end. Tower HP was 325/390/40 (seed 3333 fell to 40/500 in T4, then took no further health damage in 300 s). |
| **Collect bot** | Orbits the Tower at 200 px and walks to the nearest pickup within 700 px. | Victory at 372 s, 9 Drafts, Scrap capped at 200, Tower 450/500. |
| **Orbit bot** | Circles the Tower at 200 px and ignores pickups. | Victory at 382 s, 9 Drafts, Tower **285**/500. Orbiting cost the Tower more health than standing still. |
| **Far bot** | Walks to 1,400 px east of the Tower and stands. | Dead at 11.4 s. The camera defect (P0-1) makes this worse: the view-ring spawns stay centred on the Tower and land on top of the player. |
| **Camera probe** | Printed `GameCamera.global_position` and `.target` each 10 s. | `pos=(0,0)` while the player was at `(1395,0)`. `target=<null>`. Confirmed visually: `sandbox/captures/gd/gdr_move_200/330/460.png` (player holding Down is off-screen within ~3 s). |
| **Screenshots** | `sandbox/captures/review/*.png`, `docs/screenshots/*.jpg`, plus my own captures above. | Cited per question below. |

Caveat: all bot runs used the bugged camera. The still bot stands 280 px from the Tower, so fixing the camera moves the view ring only about 280 px for it. I expect its result to hold, but re-measure it after P0-1 is fixed.

---

## 3. Questions and answers

Each entry gives the question, why it matters, the factual answer with evidence, and a verdict.

### Goal, controls and onboarding

**Q1. What is my goal, and can a first-time player tell within 30 seconds?**
*Why it matters:* the dual-pool goal is the game's whole pitch. If players don't know the Tower matters, they will play it as a generic survivor.
*Answer:* The only statement of the goal is the title tagline, "Defend the Tower. Survive the horde." (`src/ui/theme/ui_strings.gd:170`). The Hub's first-visit hint talks about Cores, not the goal (`ui_strings.gd:121`). The run itself has **no prompt, objective line or wave banner**. Instead, three hand-placed feel-check enemies are already in the arena at t=0 (`scenes/prototype.tscn:45-52`). The Seeker spawns 220 px from the Tower and is hitting it before T1 opens (bot log: Tower shield 125 → 95 by t=10). That puts all three intents on screen in the first second, while T1 is meant to teach Hunters alone (Register line 3300, "T1 ... Hunters" only). The first Draft interrupts at about 13 s.
*Verdict:* **Problem (P1).**

**Q2. What does the player press during a run?**
*Why it matters:* this is the "what do I press when" part of the brief.
*Answer:* Movement only (`Input.get_vector(move_*)`, `src/player/player.gd:312`). The bow fires automatically at the nearest enemy within 260 px, re-picking a target on every shot (`src/combat/auto_weapon.gd:347-366`; Register line 3222). Esc pauses. During a Draft: Left/Right cycles, 1/2/3 picks, click picks, Space/Enter confirms, hold Up for 1 s confirms, R rerolls. These controls are listed only on the title screen's Controls page.
*Verdict:* **Fine as a control scheme.** It is a problem only because of Q3.

**Q3. With movement as the only verb, is there enough to do?**
*Why it matters:* in a movement-only game, all skill expression has to come from positioning.
*Answer:* No. The still bot proves that positioning is not required (section 2). The master bans this outright, under "The safe corner" (`MASTER_SDLC.md:392`) and "The idle minute" (`:408`). The intended verbs are "read threat → reposition → collect" (`:293-297`). Today, repositioning is optional and collecting only feeds meta progression.
*Verdict:* **Problem (P0).**

**Q4. Why doesn't the screen follow me, and why can I walk off it?**
*Why it matters:* this breaks movement, threat reading, spawning and the off-screen Tower indicator.
*Answer:* `GameCamera.target` is `null` at runtime (probe in section 2). The scene assigns `target = NodePath("..")` to a typed `Node2D` export (`scenes/prototype.tscn:41-43`), and that node header has no `node_paths=PackedStringArray("target")`. That is the likely cause. With no target, `game_camera.gd:90-112` never moves the camera, so it stays at `(0,0)`, which is the Tower. Knock-on effects: the view spawn ring is centred on the camera (`wave_director.gd:1527-1531`), so Hunters and Opportunists spawn around the Tower instead of around the player. The "Tower off-screen" threat indicator can never show.
*Verdict:* **Problem (P0).** It reads as a design choice ("single screen"), but it is a defect.

**Q5. Why is every run the same?**
*Why it matters:* run-to-run variety is the definition of a roguelite.
*Answer:* `run_seed` is a constant, `20260920` (`src/integration/prototype_integration.gd:90`). Nothing randomises it; only the Run Recorder calls `randi()`, and only for its own folder name (`src/debug/run_recorder.gd:117`). Draft offers, card rarities, spawn positions and drops are all keyed on it. Measured: three bot runs with different behaviour all got the identical first three Drafts, for example `["rapid_fire"(Rare), "caliber", "optics"]` at level 1.
*Verdict:* **Problem (P0).** The fix is one line.

### The Tower

**Q6. Why should I care about the Tower?**
*Why it matters:* this is the game's unique claim (`MASTER_SDLC.md` "The Central Tension").
*Answer:* The run ends the moment the Tower reaches 0 (`src/run/run_flow_controller.gd:623-624`). It has 500 HP and a 125 shield that regenerates at 10%/s after 8 s without a hit; its health never regenerates (Register line 3228). In practice, combat waves never break the shield (still bot, all seeds: `T=…+125` throughout combat waves 1-4), so after T4 the player has nothing to protect.
*Verdict:* **Problem (P0/P1).** The stake exists on paper but is never applied.

**Q7. Can I actively help the Tower?**
*Why it matters:* player agency over the second health pool.
*Answer:* Only indirectly: by standing where Seekers attack and letting the bow kill them, and by taking Tower Draft cards (Repair Kit heals 25%; Reinforced Plating heals the increase). D115 removed the Tower Console. The Tower Interaction Radius still exists but nothing uses it (Register line 3232). There is no verb such as "stand at the Tower to repair or recharge it".
*Verdict:* **Problem (P1).** The Tower is passive scenery between Drafts.

**Q8. Why would I ever leave the Tower's side?**
*Why it matters:* the tension needs a pull away from the Tower.
*Answer:* The only pull is pickups that land outside the 96 px magnet radius (Register line 3340). They are worth it only for more Drafts, which you don't need to win (still bot: 4 Drafts → victory), and for Cores. Meanwhile the Tower adds 25 DPS against Hunters chasing you, because it fires at the nearest enemy within 480 px (Register line 3230). Staying close is safer and stronger. The master even says the Tower "gives the player a reason to fight near it" (`MASTER_SDLC.md:488`) but provides no counterweight.
*Verdict:* **Problem (P0).** This is the root design issue.

**Q9. What are the blue segment and the white tick on the Tower bar?**
*Answer:* The blue segment is the shield, overlaid on health. The white tick marks 40% of maximum, where the bar's border shape changes (Register HUD row, line 3356). Visible in `run_60.png`.
*Verdict:* **Fine.** The tick needs no tutorial once the bar has dropped past it once.

### Enemies and telegraphs

**Q10. Who are the three goblins, and what do they want?**
*Answer:*
- Red torch goblin = **Tower Seeker**. 60 HP, 176 px/s, 10 DPS melee, ignores the player.
- Yellow TNT goblin = **Player Hunter**. 30 HP, 272 px/s, 16 DPS contact damage.
- Purple barrel goblin = **Opportunist**. 45 HP, 224 px/s, chooses the closer target.

Sources: `assets/sprite_frames/*.tres`, `data/enemies/*.tres` `reserved_colour`, Register lines 3240-3242. The silhouettes and colours are distinct, which is good. There is no legend anywhere, and the Hunter carries dynamite but never throws it, so it looks like a ranged bomber when it is actually a melee chaser.
*Verdict:* **Mostly fine (P2).**

**Q11. What are the coloured ground rings and the diamond over enemies' heads?**
*Why it matters:* this is the "random circles and rhombus" in the brief.
*Answer:* They are the attack wind-up telegraph. A squashed ring under the enemy's feet fills during the 0.4 s wind-up, and a pulsing diamond sprite (`telegraph_diamond.png`) floats 104 px above its head, both tinted in the intent colour (`src/enemy/telegraph_visual.gd:36-45`). The idea is right. But the **diamond shape is reused for four different meanings** (Q13, Q19, and the low-health off-screen Tower indicator, `threat_feedback.gd:454`).
*Verdict:* **Problem (P1)** because of the shape collision.

**Q12. How do I tell what an Opportunist is attacking?**
*Answer:* You can't. It switches target by event rules (Register line 3242) with no on-screen sign.
*Verdict:* **Problem (P2).**

### Pickups

**Q13. Why are there blue rhombuses on the ground?**
*Answer:* They are **XP shards**. Every standard enemy drops one, worth 1 XP (`data/pickups/xp_shard.tres`; Register line 3339). They last 60 s, blinking for the last 5 (line 3344), and fly to you once you are within 96 px. Levels cost 5+3(L+1) XP: 8, 11, 14, … (line 3254).
*Verdict:* **Fine as a mechanic.** The shape conflicts with Q11 and Q19.

**Q14. What are the gold circles?**
*Answer:* **Scrap** (the Tiny Swords gold pouch, `data/pickups/scrap.tres`). Every standard enemy drops one. It fills a 200-point HUD counter (`data/economy/prototype.tres`, `scrap_cap = 200`). Since D115 it has **no use during a run**. At run end it converts to Cores at 10:1 (`src/meta/meta_progress.gd:931`). It drops to 0 if the player dies (`src/economy/run_inventory.gd:101-102`), but not if the Tower falls.
*Verdict:* **Problem (P1).** Half of every drop is meaningless in the moment.

**Q15. Why do the rhombus and the circle always appear stacked together?**
*Answer:* Both are spawned at the same death position (`src/pickup/pickup_system.gd:321-324`). Every kill puts two objects on the ground, each with its own expiry, merge and raycast logic, and they always travel together.
*Verdict:* **Problem (P1).** Visual noise with no decision attached.

**Q16. Why do pickups pile up around the Tower?**
*Answer:* The Tower kills at up to 480 px, while the player's magnet reaches only 96 px. The still bot left up to **80 pickups** on the field (log at t=380). That pile is exactly the lure the design needs (go and collect, leaving the Tower). Today it costs nothing to ignore.
*Verdict:* **An opportunity, not used.**

**Q17. Is collecting pickups meaningful?**
*Answer:* For in-run power, barely. The collect bot got 9 Drafts against the still bot's 4, and both won. For meta progression, yes: about 200 against 67 Scrap is about +13 Cores per run.
*Verdict:* **Problem (P0, through Q3).**

### Economy

**Q18. What does Scrap do mid-run?**
*Answer:* Nothing (D115; Register "Scrap" row, line 3331). It still takes the HUD's top-right panel ("SCRAP n/200").
*Verdict:* **Problem (P1).**

**Q19. What are Cores, and why does their icon look like the XP crystal?**
*Answer:* Cores are the between-runs currency shown in the Hub (`hub_screen.gd:612-614`, `UiShapeGlyph.Shape.CRYSTAL`, a purple rhombus; `hub_90.png`). In-run XP is a blue rhombus crystal. A new player will reasonably read the XP shards as Cores.
*Verdict:* **Problem (P1)**, part of the shape-language fix.

**Q20. What does Reroll do, and how many do I get?**
*Answer:* It replaces all three cards, keeping the one-player/one-Tower guarantee. You get 1 per run (Register line 3320), plus Lucky Draw and the Hoarder achievement. The HUD shows "Rerolls 1"; the Draft shows "Reroll: R / Square" (`draft_controller.gd:1087`).
*Verdict:* **Fine.**

### Level-Up Draft

**Q21. What do I press when the Draft opens, and is it obvious?**
*Answer:* The only on-screen hint is "Reroll: R / Square" next to an **empty circle**. That circle is the hold-to-confirm fill ring (`draft_controller.gd:1070`), and nothing explains it. Number keys 1/2/3, mouse click, Space/Enter, and "hold Up 1 s" all work (`draft_controller.gd:862-866`, `:904-966`), but none is labelled. The cards show "Rank 1 of 3" for a card you don't own yet (`draft_card_view.gd:409-410`), which reads as "already rank 1". The Register asks for "Rank 1 → 2 of 3" style (line 3321). See `run_2400.png`.
*Verdict:* **Problem (P1).**

**Q22. Why does the Draft interrupt a fight?**
*Answer:* By design (D116). It pauses fully, has a 0.4 s input lockout, and arms only after input returns to neutral, so a held movement key can't confirm a card by accident.
*Verdict:* **Fine.**

**Q23. Does a card's rarity do what the card says?**
*Answer:* No, in two ways.
- **(a) Retroactive and downgradable.** `total = effect_per_rank × rank × rarity_of_latest_pick` (`src/upgrade/upgrade_system.gd:454`), a documented "simplification" (`:385-398`). An Epic Rapid Fire (+22%) followed by a Common one gives +20%: **taking a rank lowered the stat**. A Common followed by an Epic retroactively turns rank 1 into an Epic (+44%).
- **(b) The text lies.** `_scaled_effect_text` scales every "N%" in the description (`draft_card_view.gd:568-580`). The code does not scale Repair Kit, Patch Kit, Multishot or Piercing (`upgrade_system.gd:446-452`). So a Rare Repair Kit displays "heal 38%" but heals 25%, and an Epic Multishot displays "at 154% damage" but deals 70%. Rare Regeneration displays "2%/s" but gives 1.5%/s.

*Verdict:* **Problem (P1).**

**Q24. Do Optics and Watchtower stack?**
*Answer:* No, they **overwrite each other**. Both call `set_range_multiplier(1 + own_total)` (`upgrade_system.gd:466-467`), and the setter replaces the value (`tower_weapon.gd:216-217`). Observed on seed 11: Optics Epic, then Optics Rare (range ×1.45), then Watchtower Common → range ×**1.10**. The same overwrite exists between Heavy Rounds and Overdrive, and between Caliber and Reinforce (`:460-464`), though fallback cards appear only once a pool is exhausted.
*Verdict:* **Problem (P1).**

**Q25. Is there real tension between Player and Tower cards?**
*Answer:* The structure is right: at least one Player card and one Tower card, with a fixed Player / Tower / wild slot order (`draft_controller.gd:669-693`). In practice, Tower cards are low-value because the Tower is never threatened after T4. There are also two specific problems:
- The Siege volume formula sizes Sieges from **live Tower DPS** (Register line 3309; `prototype_integration.gd:257`). Caliber and Tower Volley therefore add Seekers one-for-one in Sieges, so Tower damage cards cancel themselves out where they would matter most.
- Optics (+15%) and Watchtower (+10%) are near-duplicates.

*Verdict:* **Problem (P1).**

**Q26. Why am I offered Patch Kit at full health?**
*Answer:* `get_offerable_upgrades` filters only maxed cards (`upgrade_system.gd:294-301`). The bot took Patch Kit at 100/100 HP.
*Verdict:* **Problem (P2).**

### Pacing and difficulty

**Q27. How long is a run, and what does the difficulty curve look like?**
*Answer:* 372-417 s (6.2-7.0 min), a little under the 7-9 min target (Register line 3391). The curve is **inverted**: player damage happens only in T1, which includes the three pre-placed enemies, and Tower health damage only in T3/T4. All four combat waves fail to get through the Tower's shield, including combat wave 4, the "heavy Siege ×2.0" (57 Seekers). The reasons:
- Siege Seekers trickle in one at a time (every 1.18-1.57 s). T4 spawns at almost the same rate (one per 1.5 s, line 3303), so the combat Sieges are longer than the teaching Siege but no denser.
- A single 60 HP Seeker crossing the Tower's 480 px range takes about 2.7 s, which is roughly 68 Tower damage, so it dies before it arrives.
- Enemy stats never scale (Q29), while player stats grow every Draft.

*Verdict:* **Problem (P0).**

**Q28. How do I know a new wave or a Siege has started?**
*Answer:* Only by watching the small "Wave n/8" number change. There is no wave banner or sound. The Register's 3-second Siege warning (line 3310: indicator pulse plus priority cue) has no implementation; a grep finds no consumer. Off-screen spawn markers (line 3280) are explicitly unbuilt (`wave_director.gd:40-46`). This violates "Escalation must be visible" (`MASTER_SDLC.md:374`).
*Verdict:* **Problem (P1).**

**Q29. Do enemies get tougher over the run?**
*Answer:* No. HP and DPS are constant from T1 to combat wave 4 (Register lines 3240-3242). The only escalation is enemy count. There are no elites in the prototype.
*Verdict:* **Problem (P1).**

### Feel, death and winning

**Q30. Does hitting things feel good?**
*Answer:* Partly. Enemies flash on hit, and you get damage numbers, blood and a skull death (`enemy_animator.gd:254-291`, `fx/death_fx.gd`). Missing:
- **Screen shake never fires.** `GameCamera.add_trauma()` has no caller anywhere in `src/`, yet Settings has a toggle for it.
- No hit-stop (the Register allows ≤120 ms visual hit-stop, line 3380).
- No pickup or level-up sound (both cue IDs are `PLACEHOLDER_cue_*` in `data/pickups/*.tres`).

*Verdict:* **Problem (P1/P2).**

**Q31. What happens when I die or the Tower falls?**
*Answer:* The results panel appears immediately (`run_flow_controller.gd:631-655`). It shows the cause ("You were defeated" / "The Tower was destroyed"), the wave reached, Scrap and time. There is no death beat (no slow motion, no lingering on the Tower collapsing), and it does not show what killed you.
*Verdict:* **Fine with polish needed (P2).** "Failure must teach" is half met.

**Q32. What does winning look like?**
*Answer:* After combat wave 4, the last of 8 waves, ends with both pools above zero, a Victory panel and the settlement appear (C-FINAL).
*Verdict:* **Fine structurally.** The win is unearned at current tuning.

### Meta progression

**Q33. What do I spend Cores on, and how long does the Skill Tree take?**
*Answer:* 20 nodes. The full tree costs **551 Cores**: base 5/10/18/30 per tier, × (1 + 0.5(r−1)), rounded (Register line 3335). A won run settles about 41 Cores standing still or about 55 collecting: 6 for minutes, 16 for waves, about 8 for kills, 6-20 for Scrap, 5 for victory (`meta_progress.gd:912-937`). That is roughly 10-13 runs to complete the tree, which is a reasonable length. But it is power creep on top of content that is already beaten, with no difficulty or "heat" setting to spend that power against.
*Verdict:* **Problem (P1 for the author).**

**Q34. Are the achievements goals?**
*Answer:* Three of the six unlock on the first winning run (Register line 3338): Veteran (reach wave 5), Keeper of the Keep (end with the Tower above 50%), and Founder (win a run). Two of the three Draft-card unlocks (Multishot, Tower Volley) come with them. Goblin Slayer (300 kills) takes about 1.5 runs.
*Verdict:* **Problem (P2).** Progression is front-loaded.

**Q35. Are any Skill Tree nodes dead?**
*Answer:* Yes, two cases.
- Sharpened Arrows rank 3 does nothing. Bonuses are rounded into an integer base damage (`meta_loadout_applier.gd:137`): 10 × 1.16 = 11.6 → 12 and 10 × 1.24 = 12.4 → 12.
- Scavenger (start with 15 Scrap) and Deep Pockets (+50 Scrap cap) only affect settlement, because Scrap has no in-run use. That is 1.5 Cores per rank. Deep Pockets matters only for runs that hit the 200 cap.

*Verdict:* **Problem (P2).**

---

## 4. Prioritized findings

Effort: **S** < half a day, **M** about a day, **L** more than a day. "Author decision" marks a scope or intent change; send those to the author as multiple-choice questions.

### P0: breaks the experience

**P0-1. The camera never follows the player.**
- *Problem:* see Q4. The camera stays on the Tower, the player can walk off-screen, and view-ring spawns centre on the Tower.
- *Evidence:* the probe printed `target=<null>` and camera `(0,0)` with the player at `(1395,0)`. Captures `sandbox/captures/gd/gdr_move_*.png`. `scenes/prototype.tscn:41-43`.
- *Fix:* add `node_paths=PackedStringArray("target")` to the `GameCamera` node header in `scenes/prototype.tscn`, or assign `camera.target = player` in `PrototypeIntegration._ready()`. Add an assembled-scene test that `GameCamera.target == Main/Player` and that the camera moves after the player moves. Check it fails before the fix. Re-take the README screenshots.
- *Effort:* S.

**P0-2. A zero-input player wins; the safe-corner and idle-minute bans are both violated.**
- *Problem:* see Q3, Q8, Q27. Positioning carries no weight, and the Tower is threatened only in T3/T4.
- *Evidence:* still bot 5/5 victories (section 2). `MASTER_SDLC.md:392`, `:408`.
- *Fix:* a tuning package, each item a Register edit and decision row. **Author decision on the targets.** Proposed acceptance bar: a still bot loses in at least 4 of 5 seeds before combat wave 4 ends, and the collect bot wins in at least 3 of 5. Levers, in order of expected impact:
  1. **Clumped Sieges.** Spawn Siege Seekers in bursts of 4-6 from one or two lanes (re-use the Split Assault lane logic, Register "Directional weighting"), so the shield breaks and the player must physically go to the hit side.
  2. **Tie Siege volume to base Tower DPS**, or to only half the upgrade bonus, instead of live DPS (Register line 3309; `prototype_integration.gd:257`), so combat Sieges are reliably denser than T4.
  3. **Per-wave enemy HP multiplier.** For example ×1.0 / 1.15 / 1.3 / 1.5 across combat waves 1-4, as a new Register row read by `EnemyController` at spawn.
  4. **Tower shield regen only between waves**, or a longer regen delay (Register line 3228), so damage accumulates over the run.
  5. **Hunters in Sieges.** Raise the Hunter share in combat waves 2 and 4 so the player is pressured while defending.
- *Tooling:* promote the bot to `src/dev/balance_bot.gd`, with still/orbit/collect policies, a `--seed`, and CSV output, and run it as the standing balance regression after every tuning change. This also delivers the Register's Orbit test (line 3393), which has never been run.
- *Effort:* M for the tooling plus a first pass; L to converge.

**P0-3. Every run uses the same seed.**
- *Problem:* see Q5.
- *Evidence:* `src/integration/prototype_integration.gd:90`. Identical Drafts across bot runs.
- *Fix:* when the run starts, if no `--seed=` user argument is given, set `run_seed = randi()` before `_wire_run_seed()`. Pass the same seed to the Run Recorder, and print it on the results screen so bug reports are reproducible. Keep the export for tests.
- *Effort:* S.

### P1: big improvement

**P1-1. Draft rarity maths and card text are wrong.**
- *Problem:* see Q23. Rarity applies retroactively, a new rank can lower a stat, and Rare/Epic text misstates four cards.
- *Evidence:* `upgrade_system.gd:385-398`, `:454`; `draft_card_view.gd:568-580`.
- *Fix:* keep a per-upgrade `Array[float]` of each rank's rarity-scaled value and set the multiplier to `1 + sum`. In `_scaled_effect_text`, scale only the numbers the card really scales; for example, add a `rarity_scales_text: bool` field on `UpgradeDefinition`, false for Patch Kit, Repair Kit, Multishot and Piercing. Alternatively, for those four, make rarity scale something real (heal amount, or Multishot's damage share). Add tests for Epic → Common never decreasing a stat, and for card text matching the applied value.
- *Effort:* S-M.

**P1-2. Cards that share a stat overwrite each other.**
- *Problem:* see Q24.
- *Evidence:* `upgrade_system.gd:460-467`; seed 11 lost Optics' ×1.45 to Watchtower's ×1.10.
- *Fix:* in `_apply_effect`, compute one combined fraction per target stat across every card routed to it (Optics + Watchtower, Heavy Rounds + Overdrive, Caliber + Reinforce), then call the setter once. Also consider merging Watchtower into Optics, or giving it a different effect, since a duplicate card dilutes Draft quality.
- *Effort:* S.

**P1-3. Scrap is dead weight; give the Tower a verb.** *Author decision (it partly revisits D115).*
- *Problem:* see Q7, Q14, Q15, Q18. Every kill drops two objects, and Scrap has no in-run use.
- *Evidence:* Register line 3331; `pickup_system.gd:321-324`.
- *Recommended option (b):* **bring Scrap home.** While the player stands inside the existing Tower Interaction Radius (160 px, already in the scene, `src/tower/tower_interaction_radius.gd`), Scrap drains automatically, for example 5 Scrap/s, into Tower repair, for example 1 HP per Scrap. This is movement-only, with no menu, no pause and no new input. It restores the master's "deliberate approach moments" (`MASTER_SDLC.md:490`) and makes collecting meaningful: you go out to collect, then come home to repair.
- *Option (a):* remove Scrap drops and pay settlement from XP collected, which halves pickup noise.
- *Option (c):* keep the status quo, but move Scrap off the main HUD and show it only on the results screen.
- *Fix detail for (b):* a new Register row (drain rate and repair ratio) and a decision row; a small `TowerRepairStation` node that consumes `RunInventory.scrap_current`; a HUD pulse on the Tower bar while repairing.
- *Effort:* M.

**P1-4. No in-run onboarding, and three pre-placed enemies.**
- *Problem:* see Q1.
- *Evidence:* `scenes/prototype.tscn:45-52`, `enemy_paths` on line 30. No in-run hint strings in `ui_strings.gd`.
- *Fix:*
  - Remove the three feel-check enemies and their `enemy_paths` entries, updating any assembled-scene tests that count them.
  - Add three one-time contextual prompts as a small HUD toast, keyed to a MetaProgress "seen" flag: at 0 s, "WASD / stick to move. Your bow fires on its own."; on the first Seeker spawn (T2), "Red goblins attack the Tower. If it falls, the run ends."; on the first XP drop, "Walk over crystals to level up."
  - Add a permanent objective line under the Wave label: "Protect the Tower · Survive 8 waves".
  - Optional: start the player at "240 px south" as the master states (`MASTER_SDLC.md:189`); the scene uses `(280, 0)`, east of the Tower.
- *Effort:* S-M.

**P1-5. Escalation is invisible.**
- *Problem:* see Q28.
- *Evidence:* Register lines 3280 and 3310; `wave_director.gd:40-46`.
- *Fix:*
  - A wave banner of about 1.2 s ("Wave 6 · SIEGE") on `WaveDirector.wave_opened`, with a horn sound.
  - The Register's Siege warning: 3 s before the first Seeker, the Tower bar pulses and a priority cue plays.
  - Build the spawn markers. docs/11 does not say how they render, so the author needs to approve a render rule; proposed: an intent-coloured chevron at the screen edge, aggregated one per 30° sector, appearing 0.75 s before the spawn. This needs a docs/11 line and a decision row.
- *Effort:* M.

**P1-6. Enemies never scale; the difficulty curve is inverted.**
- *Problem:* see Q27, Q29.
- *Fix:* covered by P0-2 levers 1-3. Additionally, make combat wave 2 and combat wave 4 visibly harder than T4: shorter Seeker intervals, or burst groups. *Author decision on the numbers.*
- *Effort:* M.

**P1-7. The Draft does not explain itself.**
- *Problem:* see Q21.
- *Fix (in `draft_card_view.gd` and `draft_controller.gd`):*
  - A "1", "2" or "3" key badge in each card's corner.
  - One footer line: "Click a card or press 1-3 · Hold ↑ to confirm · R to reroll (n left)".
  - Show the fill ring only while the hold is in progress, or label it "Hold".
  - Rank text "New · Rank 0 → 1 of 3".
  - Filter Patch Kit at full player HP and Repair Kit at full Tower HP.
- *Effort:* S.

**P1-8. Shape language collisions: one rhombus, four meanings.**
- *Problem:* see Q11, Q13, Q19. The rhombus currently means the XP pickup, an enemy attack warning, the low-health off-screen Tower indicator, and the Cores icon.
- *Fix:*
  - Keep the blue crystal for XP; it is the most frequent object.
  - Change the attack warning above the head to a "!" glyph and rely on the ground ring.
  - Change the low-Tower off-screen indicator to a cracked-Tower icon or a flashing arrow.
  - Give Cores a distinct shape, such as a hexagonal gem or a coin with a core motif, in its own colour.
  - Record the shape table in docs/19, "Differentiation".
- *Effort:* S.

**P1-9. Feel: missing shake, hit-stop and audio cues.**
- *Problem:* see Q30.
- *Evidence:* no caller of `add_trauma` in `src/`; `PLACEHOLDER_cue_*` in `data/pickups/*.tres`.
- *Fix:*
  - Call `GameCamera.add_trauma(0.35)` on player damage and `0.2` on Tower health damage.
  - Add 60-80 ms sprite hit-stop on kills (visual only, within the Register's ≤120 ms).
  - Add a pitched "tick" for XP collection, a level-up chime, and a gold "clink" for Scrap.
  - Add a Tower bar flash when the shield breaks.
- *Effort:* S.

### P2: polish

**P2-1. Opportunist target indicator.**
- *Fix:* a small pip in the intent colour that points toward the Opportunist's current target, shown for 1 s after each switch.
- *Effort:* S.

**P2-2. A death beat that teaches.**
- *Fix:* 0.5 s of slow motion (SimClock `time_scale` ≥ 0.25 is allowed) and a camera hold on the cause (the player, or the breached side of the Tower), then the panel. Add "Killed by: Player Hunter ×3" / "Tower breached from the West" from the Run Recorder's events.
- *Effort:* M.

**P2-3. Scrap is lost when the player dies but kept when the Tower falls.**
- *Problem:* a perverse incentive at the end of a run. `run_inventory.gd:101-102`.
- *Fix:* apply the same rule to both outcomes. *Author decision.*
- *Effort:* S.

**P2-4. Front-loaded achievements.**
- *Fix:* raise the thresholds. For example: Veteran = clear combat wave 4 without the Tower dropping below 50%; Keeper = win with the Tower above 75%; add a "no damage taken in a wave" achievement. *Author decision.*
- *Effort:* S.

**P2-5. A dead Skill Tree rank.**
- *Problem:* Sharpened Arrows rank 3 rounds to nothing (Q35).
- *Fix:* apply the meta damage bonus as a float multiplier on `AutoWeapon` (a separate `_meta_damage_multiplier`) instead of rounding it into the integer `damage_band.value` (`meta_loadout_applier.gd:137`). The Tower branch at `:189` is safe at its current values but uses the same pattern.
- *Effort:* S.

**P2-6. Hunter art suggests a ranged enemy.**
- *Fix:* swap the Hunter to a goblin variant without dynamite, or keep the TNT model and give it the slice's thrown-TNT attack later.
- *Effort:* S.

**P2-7. A difficulty selector for meta players.** *Author decision (scope).*
- *Fix:* once P0-2 lands, a "Threat" level 0-5 in the Hub that multiplies enemy HP and count, with a small Core bonus, so the Skill Tree has something to push against.
- *Effort:* M.

**P2-8. Superseded wording on fallback cards.**
- *Problem:* `data/upgrades/overdrive_fallback.tres:14` and `reinforce_fallback.tres:16` still say "also available at the Console".
- *Fix:* remove that clause.
- *Effort:* S.

---

## 5. Top 8 changes for the next build (in order)

1. **Fix the camera follow (P0-1).** One scene line plus a regression test. Nothing else can be judged properly until the screen follows the player.
2. **Randomise the run seed and show it on the results screen (P0-3).**
3. **Fix the Draft maths:** per-rank rarity accumulation, combined same-stat multipliers, and honest card text (P1-1, P1-2).
4. **Promote the balance bot and retune for pressure (P0-2):** clumped Sieges, Siege volume tied to base Tower DPS, a per-wave enemy HP multiplier, shield regen only between waves. Bar: the still bot loses, the collect bot wins.
5. **Give Scrap a job and the Tower a verb:** auto-repair while standing in the Interaction Radius (P1-3, author decision). This creates the "leave to collect, return to repair" loop the central tension needs.
6. **Make escalation visible:** wave banner, Siege warning, spawn markers (P1-5).
7. **Onboarding:** remove the three pre-placed enemies, add three contextual prompts and an objective line, and label the Draft controls (P1-4, P1-7).
8. **Readability and feel:** fix the shape collisions and add shake, hit-stop, pickup and level-up audio (P1-8, P1-9).

---

### Appendix: reproducing the bot runs

The bot is a review-only script at `D:\Gamedev\sandbox\captures\gd\bot_sim.gd` (gitignored, not project code). It writes its meta profile under the same sandbox folder, so the real `user://profile.json` is untouched.

```
timeout 590 D:/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path D:/Gamedev --audio-driver Dummy --fixed-fps 60 \
  -s res://sandbox/captures/gd/bot_sim.gd -- --mode=still|orbit|collect|far --pick=0|-1 [--seed=N] \
  --no-focus-pause --meta-profile-dir=D:/Gamedev/sandbox/captures/gd/meta_bot/
```

Logs: `sandbox/captures/gd/bot_still_default.log`, `bot_still_s11.log`, `bot_still_s222.log`, `bot_still_s3333.log`, `bot_collect.log`, `bot_orbit.log`, `bot_far.log`.

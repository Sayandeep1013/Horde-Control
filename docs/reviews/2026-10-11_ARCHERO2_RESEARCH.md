# Archero 2: research notes (2026-10-11)

Requested by the author: "check the game named archero 2 ... understand its level design .. some actual objects that are interactable in the level too ... its skill tree .. in game and outside of the game ... copy whichever we can for our own game."

This is web research only. Several wikis blocked access (the Fandom wiki returned 402, a few guide sites returned 403), so most sources are third-party guide sites. Claims that only one source supports are marked **[unverified]**.

## Level and stage structure
- **Chapters and modes.** About 50 chapters shipped at launch; more arrive in patches. There is also a Sky Tower of 5-level runs, each with a modifier such as "no hearts". Sources: App Store notes https://apps.apple.com/us/app/archero-2/id6502820653 and https://www.highgroundgaming.com/?p=139917.
- **Arena stages.** A stage is 50 waves with a boss every 10th. Enemies spawn at red skull markers, and XP is collected when the wave ends. Source: https://www.levelwinner.com/archero-2-beginners-guide/.
- **"Survivors" stages.** A countdown, for example 6 minutes with bosses at 3:00 and 6:00. The timer freezes while a boss is alive.
- **Fixed rhythm in every block of 10 waves:**
  - wave 5: the **Valkyrie**, a choice of 1 of 2 skills at Rare or better, plus a heart;
  - wave 9: the **Angel**, a choice of a small stat boost or a heal;
  - wave 10: the **boss**;
  - after the boss: either a **Roulette** or the **Devil**, who offers a skill in exchange for max HP. In Archero 1 the Devil was guaranteed after a no-hit boss and cost 20% max HP.
- **Terrain.** Spikes, traps, water that melee enemies must path around, walls that block shots, and narrow corridors. Skills such as Wall-Piercing, Bouncy Wall and Aqua Flight exist because of this terrain. Source: https://theriagames.com/guide/archero-2-skill-guides/.
- **Telegraphs.** Ground glyphs and dust clouds are sometimes used, but many attacks are not telegraphed, and players complain about it.
- **Not found in any source [absence unverified]:** breakable crates, shrines, merchants, mid-run chests and portals.

## In-run progression
- **Level-up.** Each level-up offers a choice of 1 of 3 skills.
- **Rarity tiers.** Fine, Rare, Epic and Legendary.
- **No stacking.** A skill cannot be levelled by picking it again.
- **Archetypes.** Close-Range, Combo, Blast, Turret and Spirit.
- **Effects multiply.** Skill effects stack multiplicatively.
- **Heroes change the rules.** Examples: Thor attacks while moving; Seraph pays no max HP to the Devil; Divine Chosen gets better Valkyrie and Angel picks. Source: https://findingdulcinea.com/archero-2-tier-list/.

## Out-of-run progression
- **Gear.**
  - Six slots.
  - Rarity runs Normal to Chaos.
  - Fusing 3 copies makes the next tier.
  - Upgrades belong to the slot, not the item.
  - Set bonuses define builds.

  Sources: https://archero2hub.com/en/guide/beginner and https://www.allclash.com/best-gear-in-archero-2-general-priority-build-specific/.
- **Heroes.** About 21, unlocked with shards, with star passives.
- **Runes.**
  - Ten slots, filled from a dig minigame.
  - Ability Runes let a run start with a chosen skill.

  Source: https://mobi.gg/en/tips/archero-2-runes/.
- **Talent cards.** Bought with gold and merged.
- **Artifacts.** Gacha.
- **Energy.** Each run costs energy.
- **Monetization-driven systems:** energy, gem revives, gacha, shard-gated heroes and battle passes. A teardown is at https://someselectedstories.substack.com/p/tiny-teardown-archero-2-habby-games.

## Combat
- **Stand still to shoot.** The hero fires only while standing still, which is still the core rule. Thor's moving fire is the premium exception.
- **No dash button** was found [absence unverified].
- **Lethality.** About four hits kill the player.
- **Ranged density.** Enemies produce bullet-hell density with curving and multi-shot patterns.

## Reception
- **Praised:** faster pacing and shorter sessions than Archero 1.
- **Criticised:** pop-up bundles and gacha, event grind, progress gates, early difficulty spikes (patched down twice), and untelegraphed attacks.

## What Horde Control adopts

docs/32_Archero_Adaptation.md is the binding spec. The table maps each Archero 2 mechanic to our version.

| Archero 2 | Horde Control v1.0 |
| --- | --- |
| Valkyrie (wave 5 of 10) | Patron's Boon: a choice of 1 of 2 cards, Epic or better, at the end of waves 4 and 11 |
| Angel (wave 9 of 10) | Sanctuary before each boss: a choice of heal yourself, repair the Tower, or a stat blessing |
| Devil after boss | Blood Pact after the Warchief: a pact-only card that you pay for with player **or** Tower max HP (unique to our two health pools); you may decline |
| Ability Runes / opening wheel | Opening pick: choose 1 of 3 starting abilities before wave 1 |
| Stand still to shoot | Focus: standing still ramps fire rate. We keep firing while moving, and Dash breaks Focus |
| Terrain and traps | Spike traps that hurt everything, so you can lure goblins through them |
| (gap) | Breakable crates that drop loot; explosive powder kegs you can kick with Dash |
| (gap) | Shrines that spawn in the arena and grant a short buff if you stand on them |
| Heroes that change the rules | Champions: 3 extra archers, each with one rule twist, unlocked by achievements |
| Gear and set bonuses | Relics-lite: 2 War Camp relic slots, filled from relics unlocked by achievements and first boss kills. No fusion and no grind |

**Not adopted:** energy, gacha, shards, revives bought with gems, battle passes, Sky-Tower-style progress gates, and untelegraphed attacks.

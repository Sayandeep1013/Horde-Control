# 33 — Playtest round (author's first hands-on play, 2026-10-11)

**Status:** binding brief for four work packages, followed by a third balance pass. This brief **overrides docs/31 and docs/32 where they conflict.** Every number below is a starting value; the implementing package moves it into the Provisional Values Register, and the Register owns it from then on.

## The author's feedback

Quoted in full, because every item below traces back to it:

> make it more prominent when a thing is getting selected .. or can be selected .. i was confused ... if im selecting this or is it preselected or can i not select this ... clear distinguished way .. which one is selected n locked in
> the dash feature is good .. make it usable more often
> more challenging .. increase enemies number by 10 times ... the player should get overwhelmed .. and increase the abilities power too .. the swarms aren't hitting that much .. every 5th level is a boss battle alongside its minions
> take abilities and challenges from archero 2 ... good abilities and opponent boss attacks too
> dont just increase boss's health .. give it attack patterns ... challenging not a chore
> specify what things are ... like a tool name ... their effects .. a written pact if i go there for the first time or give it options to disable that ... how is that thing helping me or causing me harm ... a guide n onboarding
> give each abilities a special symbol so that the player doesn't have to read everytime
> some interactable things ... doesn't work as intended ... doesn't cause any harm or not an obstacle or not a boon ... like the pond .. i cant go over the pond until i take the bridge ... the map is too big .. i just go n kill the enemies before they get close to my tower ... obstacles n interactables are too small .. make them have significant roles ... they get swarmed and overwhelmed they die first 2-3 times .. improve their skilltree and then clear the level
> abilities so insignificant ... swinging axes ... tiny ... give them range or ranged attacks or new abilities
> enemies speed stays same .. when the wave increases their speed increases too
> why wasn't the main boss attacking the tower or the player .. so easy to kill

## The target loop

A new player is swarmed and dies in their first 2-3 runs. They spend Cores on the Skill Tree, come back stronger and further, and eventually clear wave 15. Each death should feel like "I was overwhelmed, but I can see what to do better".

---

## A. Clarity: selection states, symbols, Field Guide, first-time explainers (PT-UI)

### A1. One selection-state language for every selectable thing

This applies to:
- Draft and event cards;
- War Camp pickers (difficulty, Battle Skill, champion, relics, Endless);
- Skill Tree nodes;
- Settings rows;
- pause and Results buttons;
- achievements.

| State | Look (must be readable without colour: shape + icon + word) |
| --- | --- |
| **Available** | Normal plate |
| **Focused** (hover, keyboard, gamepad) | 4 px bright gold outline, 1.05x scale, a pointer arrow beside it, and the `ui_hover` cue |
| **Selected / Equipped** (locked in) | Green check badge in the corner, plus a ribbon reading "SELECTED", "EQUIPPED" or "OWNED", plus a tinted fill. It **stays visible when focus moves away**, so focus and selection never look alike |
| **Locked / unavailable** | Desaturated, with a padlock icon and a reason line ("Win on Soldier", "Need 45 Cores"). Pressing it shakes the plate and shows the reason; it is never silently ignored |
| **Confirming** (hold-to-confirm) | The fill ring draws ON the card being confirmed. When confirmed, a "CHOSEN" stamp flashes for 0.35 s |

### A2. Symbols
- Every ability, passive, Battle Skill, pact, Sanctuary blessing, shrine boon, relic, champion and arena object has its own pixel icon.
- Missing icons get added, among them the 5 pacts, Mend, Restore and Valor, and every new ability in §D.
- Cards show the icon **large**, at least 64 px at 1080p, at the top of the card, so a returning player recognises a card by its symbol without reading it.
- The same icon is used on the HUD build bar, in the pause build panel and in the Field Guide.

### A3. Field Guide (codex)
- Opened from the War Camp and from the pause menu. Its tabs are:
  - Abilities
  - Passives
  - Battle Skills
  - Pacts & Blessings
  - Enemies
  - Bosses
  - Arena (crates, kegs, shrines and boons, spikes, water and bridges)
  - Champions & Relics
- Each entry has the icon, the name, a one-line role ("Helps: ...", "Harms: ..."), the exact effect with its current numbers, and a tip.
- Entries the player has not met yet show "???" plus a hint. Discovered ids are stored additively in the profile.

### A4. First-encounter explainers
- The first time a player meets each thing (the first time each event screen opens, the first pact, the first shrine, keg, crate, spike trap and bridge, each new enemy type, each boss, the first elite), a small explainer card pauses the game.
- The card shows the icon, the name, "Helps you:" / "Hurts you:" lines, and a "Got it" button.
- The card has a **"Don't show tips again"** checkbox, mirrored by a Settings > Gameplay toggle, **Show first-time tips** (default on).
- Each explainer is shown once per profile. These explainers replace the contextual hint toasts for the same things; control hints (dash, skill) stay as toasts.

---

## B. Arena: smaller, with obstacles and chokepoints that matter (PT-ARENA)

1. **Shrink the playable arena.** The fight must happen near the Tower: walkable space is roughly 2400 x 1600 px around it, about 2-2.5 screens wide at 1080p. Enemies spawn at the edges, and the player cannot farm far from the Tower before they arrive.
2. **Water you cannot cross.** A water moat or channels divide the arena, crossed only by **2-4 bridges**. The player and walking enemies must use the bridges, which creates chokepoints. Ponds and water block movement through real collision. Ranged attacks fly over water.
3. **Large solid obstacles.** Rock outcrops, ruined walls and palisades block movement and some projectiles, and they shape lanes.
4. **Pathfinding.** A `FlowField` service (group "flow_field") on a 32 px grid. It recomputes the field toward the Tower when the arena changes, and toward the player every 0.25 s. Contract:
   - `direction_to(target_kind: StringName, world_pos: Vector2) -> Vector2` returns a normalised direction. `target_kind` is `&"tower"` or `&"player"`. It returns `Vector2.ZERO` when the position is off-grid or unreachable, and the caller then falls back to a straight line.
   - `is_walkable(world_pos: Vector2) -> bool`
   - `random_walkable_point(rng: RandomNumberGenerator, min_dist_from: Vector2, min_dist: float, max_dist: float) -> Vector2`

   PT-SWARM's enemies consume this contract.
5. **Interactables scaled up and made to matter**:
   - **Powder Keg:** 1.6x sprite size, radius 170 px, 260 damage. Kegs sit mostly near bridges.
   - **Spike Traps:** 2x size, 8 plates, at the bridges and chokepoints.
   - **Shrine:** 1.5x size, with a stronger pillar-of-light idle effect.
   - **Supply crates:** 1.5x size, 4-6 per wave.
   - **Verification:** each object must visibly do its job in a capture: damage numbers, blocked movement, and a buff icon.
6. **Placement.** The Tower stays at the centre. Spawn edges must be reachable through the bridges. No area is ever unreachable for an enemy that targets the player.

---

## C. Swarm, speed, and bosses with patterns (PT-SWARM)

1. **10x enemies.**
   - Spawn counts go up roughly tenfold over today's numbers, so the screen fills.
   - Target alive peaks: about 120 by wave 5, about 250 by wave 10, and 350 or more by wave 14 on desktop.
   - On mobile the alive cap is 180, and HP is raised to compensate.
   - Fodder may get lower individual HP so area damage clears it in satisfying bursts. Threat comes from numbers and speed.
   - **Performance budget** (Godot 4.7.1, desktop): 60 fps with 350 enemies alive and the full ability set, measured and reported. Use whatever it takes: cheaper movement for fodder (separation through the EntityRegistry spatial hash instead of physics `move_and_slide`), staggered AI ticks, pooled projectiles, LOD on health bars and animations.
2. **Speed ramps with the wave number.** Enemy move speed is multiplied by 1 + 0.04 x (wave - 1). Hunters overtake the player's base speed by about wave 7, and the player must use Dash and their build to escape.
3. **A boss every 5th wave, together with its minions.** Normal spawns continue during a boss fight, at about 40% of a normal wave's rate. The schedule:
   - **Wave 5: Goblin Warchief.**
   - **Wave 10: Gutbarrel the Juggernaut** (new; a giant Barrel goblin).
   - **Wave 15: Bombardier King**, the final boss.
4. **Attack patterns, not HP sponges.** Bosses get Archero-style, telegraphed, dodgeable patterns and **stagger windows**: after a big attack the boss is stunned for 1.5-2 s and takes +50% damage. HP is moderate. Target fight length with a decent build is 60-90 s, and **difficulty comes from dodging**, not from chipping at a bar.
   - **Warchief:**
     - Slam ring.
     - Triple Charge. A charge into a solid obstacle stuns him and opens a stagger window.
     - Ground Fissures: 3-5 line telegraphs radiating outward.
     - Rally (summons).
     - Below 50% HP he enrages: faster combos.
   - **Juggernaut:**
     - Rolling charge that bounces off walls.
     - Drops a ring of barrels that explode after 1.5 s.
     - Shrapnel burst: 12 radial projectiles with gaps.
     - Spin-to-win.
     - Stomp shockwave rings.
   - **King:**
     - **Must actually attack.** In playtest he did not attack the Tower or the player; this is a defect to find and fix with a test.
     - Aimed 5-dynamite fan.
     - Barrage rings on the player.
     - Siege Bomb on the Tower.
     - Phase 2 (below 60%): rotating spiral bullet pattern.
     - Phase 3 (below 25%): Powder Storm, radial waves with safe gaps, plus summoned Bombers.
5. **Enemy projectile system.** `BulletPattern` emitters (radial, fan, spiral, aimed) firing pooled, readable projectiles:
   - big, bright orange or red orbs with an outline;
   - they hit the player (and the Tower when flagged);
   - they are blocked by solid obstacles.
   - Used by bosses and by one new regular ranged enemy, the **Goblin Shaman**: a fan of 3 slow orbs, from wave 6. Art is a tinted existing sheet with a staff/orb cue.
6. **Elites.** Per-wave elite chance x2. Elites also gain the speed ramp.

---

## D. Player power and presence (PT-POWER)

1. **Dash is used more often.** 2 charges from the start, 1.5 s recharge, 220 px. A new passive card, **Shadow Step**, makes the dash deal 30 → 70 damage to enemies passed through and grants 0.3 s more invulnerability.
2. **Abilities feel big.**
   - Every ability's area and visual size goes up 1.5-2x, and damage roughly doubles, matched to the swarm.
   - **Whirling Axes:** axes are 2x the size, orbit radius 110 → 160 px, and from level 3 every 2.5 s each axe flies out like a boomerang to 280 px and back.
   - **Caltrops:** bigger patches.
   - **Sacred Ground:** a larger radius.
   - **Dynamite:** more throws and a larger blast.
   - **Storm Bolt:** chains further.
3. **New Archero-style abilities and passives:**
   - **Diagonal Arrows** (ability): +2 arrows at ±45°; at level 3+, +4 at ±30°/±60°.
   - **Rear Arrow** (passive card): +1 arrow behind you, +2 at rank 2.
   - **Ricochet** (ability): arrows bounce to 2 → 5 nearby enemies at 70% damage.
   - **Lightning Sprite** (ability): an orbiting companion that fires a chain bolt every 1.2 → 0.6 s.
   - **Meteor Shower** (ability): every 6 → 3.5 s, 3 → 6 telegraphed meteors fall on enemy clusters (180 damage, 120 px).
   - **Blade Circle** (ability): a ring of 4 → 8 spinning blades at 220 px radius that shreds swarms.
4. **Slots.** Player ability slots 4 → 6; Tower ability slots stay at 3. The Draft keeps its other rules.
5. **The bow scales with the swarm.** Multishot and Piercing keep their places. Base fire rate and damage are re-checked in the balance pass.

---

## E. Balance pass 3 (after the four packages merge)

Measured with the `kite` bot plus a new **"human-ish" bot**: kite with 150 ms reaction delay, imperfect dodging (it misses 30% of telegraphs), and no perfect repair timing.

| Difficulty | Bot and starting state | Target |
| --- | --- | --- |
| Soldier | human-ish bot, fresh profile | dies in 5/5 seeds, mostly waves 5-10 |
| Soldier | human-ish bot, profile with ~400 Cores of tree bought | reaches wave 10+ in ≥3/5 |
| Soldier | human-ish bot, ~1000 Cores of tree | wins 2-4/5 |
| Soldier | kite bot, fresh profile | reaches wave 5 in 5/5, wins 0-1/5 |
| Recruit | human-ish bot, fresh profile | reaches wave 10 in ≥3/5 |
| Veteran and Warlord | human-ish bot | demand the tree |

- Bosses: 60-90 s fights with a decent build.
- Player damage taken: meaningful in every wave from wave 5 on.

## F. Work packages

| WP | Scope | Decisions | Owns these files (others don't edit them) |
| --- | --- | --- | --- |
| PT-UI | §A | D320-D329 | src/ui/*, src/ui/theme/*, tools/art/make_pixel_icons.py (new icons), the new Field Guide and explainer scripts, GameSettings key `show_first_time_tips` |
| PT-ARENA | §B | D330-D339 | scenes/arena.tscn, src/environment/*, src/arena/*, new src/navigation/flow_field.gd, assets/sprites (arena), the arena data |
| PT-SWARM | §C | D340-D349 | src/director/*, data/waves/*, data/encounters/*, data/enemies/*, src/enemy/*, scenes/entities/*, the new bullet system, src/core/entity_spawner.gd, pool caps |
| PT-POWER | §D | D350-D359 | src/ability/*, data/upgrades/*, src/combat/auto_weapon.gd, src/combat/player_projectile.gd, src/player/player.gd (dash), tools/art/make_v1_sprites.py (ability sprites) |
| BALANCE-3 | §E | D360-D369 | data numbers and src/dev/balance_bot.gd |

**Shared files** (small, stated edits only; the orchestrator merges): MASTER_SDLC.md, scenes/prototype.tscn, src/integration/prototype_integration.gd, src/ui/theme/ui_strings.gd (each package keeps its keys in one labelled block), src/dev/scene_capture.gd.

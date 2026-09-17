# 20 - Technical Architecture (Godot)

**Version:** 0.2.0 (draft; becomes a working document at 0.5.0 under the master's Document Control)  
**Status:** Working system document. Its sections were moved, with ledger FIX edits applied, from MASTER_SDLC.md 0.7.0 on 2026-09-14 so the master keeps intent, rules, gates, and the Provisional Values Register while implementation detail lives here.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

Project architecture, singleton design, system communication, modular architecture, signals, and coding standards.

**Owns:** the architectural rules, Technical Edge Cases, the performance budget and every entity cap number, the reference machine and performance protocol, the Performance Fallback Ladder, the Global Simulation Authority implementation (SimClock, PauseAuthority, process-mode mapping), the Biome Transition Rule implementation, the binding collision layer table, determinism scope and the resolution order, Godot version pinning, audio bus implementation, the test harness, debugging and telemetry tools, and animation/hitbox cleanup implementation.

---

## Godot 4.x Implementation Standards

- **Version:** The project is built exclusively in Godot 4.x. Provisional Default: Godot 4.7.1 stable, the version installed on the development machine. Godot 4.7.1 is pinned by the 4.7.1 export templates and a boot check that `Engine.get_version_info()` reports 4.7.1; `project.godot` itself records only 4.7, and this pin is changed only through document 20.
- **Editor control from the AI collaborator:** Two Godot MCP servers are configured for this project, `godot-comprehensive` and `godot-coding-solo`, both pointed at the local Godot 4.7.1 executable. Together they can create projects, scenes, nodes, scripts, and resources, edit project settings, input maps, collision layer names, and autoloads, run the project, read debug output, and inspect and drive the running game's scene tree. Anything they create must still follow every rule in this document; document 28 defines when and how they are used, and destructive or outward-facing operations (file deletion, exports, network requests) always require the designer's confirmation.
- **Runtime Data:** `Resource` (`.tres`) instances are read-only at runtime — no system writes back into a shared `.tres` while the game is running. Anything that changes during play (current HP, current rank, spawn state, pool membership, timers) lives in an instance object owned by exactly one system (a node, a plain object, or a dictionary), never in the resource that defines it.
- **Project Settings (pinned):** the following are pinned in `project.godot` and changed only through document 20: viewport `1920×1080` (`display/window/size/viewport_width` / `viewport_height`); stretch mode `canvas_items` (`display/window/stretch/mode`) with aspect `keep` (`display/window/stretch/aspect`), so the game letterboxes rather than stretches; `physics_ticks_per_second` 60 with `max_physics_steps_per_frame` 8 (`physics/common/...`); physics interpolation left off for the prototype; V-Sync (`display/window/vsync/vsync_mode`) on during play, off for performance tests (Interim Prototype Technical Budgets).
- **Data Contracts:** All content data (Enemies, Encounters, Waves, Upgrades, Biomes, Tower Upgrades, Weapons, Bosses, Affixes, Pickups, Status Effects) must be implemented as Godot `Resource` (`.tres`) files. Systems consume these via exported variables, never hardcoded dictionaries.
- **Communication, events:** State *changes* are announced through an `EventBus` Autoload using `Signals` (for example `enemy_died`, `tower_damaged`, `draft_opened`). A system emits a signal; it never calls a mutating function on another system.
- **Communication, queries:** Read-only *queries* do not go through signals. Each state owner exposes a typed query interface (for example `EntityRegistry.get_enemies_in_radius(origin, radius)`, `CombatStats.sheet_dps()`, `SimClock.now`). Tower targeting, spawn validation, the magnet raycast, and the Pressure Metric are queries. A signal emitted every tick to broadcast state is an anti-pattern and is banned.
- **Communication, commands:** A system's public interface also exposes typed *commands* — methods other systems call to request an action, for example `PauseAuthority.push_reason(reason)`, `Pool.acquire()`, `Health.apply_damage(amount, source)`, `Inventory.try_spend(amount)`. The owning system validates the request and may refuse it. Writing another system's fields directly — even through a bare setter that bypasses validation — is banned; that is a command masquerading as a mutation.
- **SimLoop order:** every physics tick runs, in order: 1 input · 2 player movement · 3 enemy AI and movement · 4 weapon targeting and firing (player, then Tower) · 5 projectile movement and sweep (enqueue hits) · 6 wind-up completion and contact ticks (enqueue hits) · 7 hit queue sorted by (target serial, attacker serial), player serial 0, Tower serial 1 · 8 death resolution in order Tower, bosses, player, other enemies · 9 drops · 10 pickup movement and collection · 11 XP and level-up requests · 12 Console channel completion (void if either pool reached 0 this tick; "confirmed" = channel completed) · 13 Wave Director · 14 `PauseAuthority.flush()` · 15 UI state. Pause requests made during a tick apply at step 14; requests made between ticks (focus loss) apply immediately. A level-up requested at step 11 counts as an open Level-Up Draft for step 13 of the same tick, so the Wave Director defers any encounter due that tick.
- **Physics & Collisions:**
  - Player and Enemies use `CharacterBody2D` for movement in the prototype. See the Performance Fallback Ladder for what replaces this if the swarm test fails.
  - Hitboxes and Hurtboxes use `Area2D`.
  - Projectiles use `Area2D`. If physical pushing is ever required, the correct node is `RigidBody2D`, not `CharacterBody2D`; no prototype projectile pushes.
  - Fast projectiles must not tunnel: `PhysicsDirectSpaceState2D.intersect_ray` (with `collide_with_areas = true`) sweeps from the projectile's previous position to its current position whenever its travel in a single physics tick exceeds 12 pixels. At 60 physics ticks per second this is every projectile defined in the prototype — even the Tower's slowest, at 900 px/s, covers 15 px per tick. A projectile enqueues at most one hit and then deactivates, so a fast projectile crossing two hurtboxes in one sweep cannot double-count. Projectile masks include ArenaBounds (15) (Collision Layers), so a missed shot ends at the arena wall instead of travelling forever.
  - Disabling a `CollisionShape2D` from inside a physics callback must use `set_deferred("disabled", true)`.
  - **Entity sizes:** collision circles sit at the feet (Perspective and Arena). Player body radius 14 px; hurtbox equals the body; Player Collector `Area2D` radius 22 px (body + 8); Tower footprint radius 106 px. Enemy body radii: Tower Seeker 14 px, Player Hunter 12 px, Opportunist 14 px. Every enemy's contact hitbox radius is its body radius plus 6 px; a telegraphed melee attack's reach (for example the Tower Seeker's 20 px) extends beyond that.
- **Collision Layers (binding, not an example):** named in `project.godot` under `layer_names/2d_physics`.

| Layer | Name | Set on | Masks |
| ---: | --- | --- | --- |
| 1 | PlayerBody | Player `CharacterBody2D` | 2, 3, 4, 15 |
| 2 | EnemyBody | Enemy `CharacterBody2D` | 1, 2, 3, 4, 15 (flying enemies drop 4) |
| 3 | TowerBody | Tower static body | none |
| 4 | World | Terrain and arena interior geometry | none |
| 5 | PlayerProjectile | Player projectile `Area2D` | 9, 4, 15 |
| 6 | TowerProjectile | Tower projectile `Area2D` | 9, 4, 15 |
| 7 | EnemyProjectile | Enemy projectile `Area2D` | 8, 10, 4, 15 |
| 8 | PlayerHurtbox | Player hurtbox `Area2D` | none |
| 9 | EnemyHurtbox | Enemy hurtbox `Area2D` | none |
| 10 | TowerHurtbox | Tower hurtbox `Area2D` | none |
| 11 | EnemyHitbox | Enemy attack and contact `Area2D` | 8 (and 10 only for telegraphed attacks aimed at the Tower) |
| 12 | Pickup | Pickup `Area2D` | none |
| 13 | Hazard | Biome hazard `Area2D` | 8, 9 (10 only where the biome allows) |
| 14 | InteractionRadius | Tower Console trigger `Area2D` | 1 |
| 15 | ArenaBounds | Arena boundary walls, static body | none |
| 16 | PlayerCollector | Player pickup-collection `Area2D` | 12 |

- **Logical Death:** the instant an entity's HP reaches 0, a `dead` flag is set on it and checked first by every damage handler, including overlaps already delivered earlier in the same tick, so a hit already queued against a dying entity is discarded rather than applied twice. Deferred within the same tick (via `set_deferred`, consistent with the collision-shape rule above): every hitbox `Area2D` sets `monitoring = false`, the hurtbox `Area2D` sets `monitorable = false` and also `collision_layer = 0` (deferred), so `intersect_ray` sweeps pass through dying entities, and the body sets `collision_layer = 0` and `collision_mask` to World (4) and ArenaBounds (15) only, so a Visual Death ragdoll or knockback still collides with terrain and the arena walls but is on no layer anything else can detect. `Pool.acquire()` restores all of these — layers, masks, and monitoring flags — before reuse.
- **Scene Tree:** the root of the gameplay scene contains specific container nodes: `Entities` (pooled enemies, `y_sort_enabled = true` so enemies sort correctly against each other), `Projectiles` (pooled), `Pickups` (pooled), `Effects` (pooled), `Environment`, and `Audio` (the 32-voice `AudioPool`, see Audio Mixing & Dynamic Ducking — it lives under the gameplay root so it pauses with the tree). The player is not a child of `Entities` and is not part of that Y-sort group: a fixed `z_index` keeps the player drawn above every enemy regardless of foot position, per the Perspective rule. Draw order by `z_index`: environment 0, pickups 10, enemies 20 (Y-sorted among themselves), Tower 25, player projectiles 30 (rendered at ≤ 70% opacity), effects 35, telegraphs 40, player 50, damage numbers 60. The Tower Console panel fits this same draw order (above enemies, below telegraphs): it is a world-space `Node2D` under the gameplay root with `z_index = 38`, whose `scale` is set each frame to the view scale so its text stays at least 24 px tall on screen. It hides and ignores input via `PauseAuthority`'s `reasons_changed` signal whenever any pause reason is active; its timers run on SimClock. Its placement beside the Tower is defined in Tower Console UI. The containers exist for pool ownership, Y-sort grouping, and per-container process-mode control, not for traversal speed.

---

## Audio Mixing & Dynamic Ducking

In a game with 300+ enemies, audio can easily become an unreadable wall of noise.

- **Audio Bus Hierarchy:** Audio must be strictly routed: `Master` -> `Music`, `SFX`, `SFX_Priority` (fed by `TowerCue`), `UI`, `Ambience`. Player damage, Tower damage, and Boss telegraphs are routed to `SFX_Priority`, which never ducks.
- **Dynamic Ducking:** When a sound plays on `SFX_Priority`, the `SFX` and `Ambience` buses duck by 9 dB with a 50 millisecond attack and a 300 millisecond release (Provisional Defaults), and `Music` ducks by 6 dB, floored at -18 dB, for the duration of the priority sound. Ducking is a scripted ramp of `AudioServer.set_bus_volume_db` on the affected buses, driven by a dedicated `PROCESS_MODE_ALWAYS` node so it keeps running even while gameplay is paused and a priority sound is still playing.
- **Retrigger Limits:** the same damage-audio cue cannot restart faster than its retrigger limit, so a stun-locked or swarmed entity does not produce a buzz: player damage 150 milliseconds, Tower damage 250 milliseconds.
- **Tower Cue Player:** Tower damage audio plays on its own `AudioStreamPlayer` routed to a sixth bus, `TowerCue`, which sends to `SFX_Priority` and carries an `AudioEffectPanner`; before each play the panner's pan is set to clamp((Tower x − player x) ÷ 960, −1, 1), so the cue stays audible and panned no matter how far off-screen the Tower is. It shares the 250 millisecond Tower-damage retrigger limit above.
- **Voice Limit:** a hard limit of 32 simultaneous SFX voices, enforced by a project-owned `AudioPool` of `AudioStreamPlayer2D` nodes with a priority field, living under the gameplay root so it pauses with the tree, because Godot exposes no voice age. Of the 32, up to 8 may be priority voices at once; the pool steals the lowest-priority voice, then the oldest, to make room for a new sound, and once all 8 priority slots are full a new priority sound steals the oldest priority voice. UI sounds do not draw from this pool; they play on their own `PROCESS_MODE_ALWAYS` players so menu audio is unaffected by pause.

---

## Debugging, Telemetry & Run Recording

You cannot balance what you cannot measure.

- **Debug Overlay:** a toggleable in-game overlay must display: FPS (current, median, and 1st percentile, all measured over a rolling 10 second window), entity counts (Enemies, Projectiles, Pickups, Effects), damage-number, telegraph, and high-intensity-VFX counts, Player/Tower HP and shield, current Wave/Encounter ID, the Pressure Metric value and its escalation/de-escalation state, the current health quadrant, and the simulation time. A pseudo-localization toggle uses Godot's built-in pseudolocalization at an expansion ratio of 0.3, so UI overflow is caught before real translations exist.
- **Run Recorder:** every run automatically writes telemetry under `user://telemetry/<run_seed>_<yyyyMMdd-HHmmss>_<controller_id>/` (controller_id = human, orbit_bot, roam_bot, still_bot, etc., so paired bot runs never share a folder): a header (run seed, build hash read from `res://build_info.txt`, Godot version); `ticks.csv`, sampled at 2 Hz, with columns SimClock time, player position, player HP, Tower HP and shield, Pressure, health quadrant, XP level, Scrap, and hopper amount; and `events.csv`, one row per discrete event, with columns SimClock time, event type, source intent, source bearing from the Tower, and amount, covering wave and encounter open/close, Draft open/close, Console open/close, purchases (with channel), spawns, damage to either pool, deaths (with cause), and run end. The dense per-tick trace and the sparse, human-readable event log are kept in separate files rather than interleaved. `res://build_info.txt` is written by an `EditorExportPlugin` that calls `add_file("res://build_info.txt", bytes, false)` inside `_export_begin`; editor and headless runs record build hash `"editor"`.
- **Idleness Metric:** Idleness is a stretch longer than the scheduled gap plus any grace period plus 3 seconds with no enemy alive and no pickup within twice the magnet radius; the Run Recorder flags it, since that is dead time the pacing failed to fill.

---

## Animation, Hitbox, and State Cleanup Rules

To prevent "ghost hits" and spatial bugs, strict rules govern entity death and state transitions.

- **Logical vs. Visual Death:** Logical Death — the `dead` flag and the deferred hitbox, hurtbox, and collision layer/mask changes — is defined once, in Godot 4.x Implementation Standards › Logical Death; this section covers what happens after. The entity can no longer deal or receive damage.
- **Visual Death:** The entity plays its "Visual Death" animation after Logical Death. During this time it is purely cosmetic: restricted to the World and ArenaBounds collision mask that Logical Death set, it can no longer block or be blocked by anything but terrain and the arena walls.
- **Animation Cancellation:** If an enemy is killed while in an attack wind-up, the attack state is immediately cancelled. The entity transitions directly to the Visual Death state.
- **Spatial Cleanup:** If a Visual Death animation involves physics (e.g., ragdoll, knockback), it must be constrained. Because the World and ArenaBounds mask is kept, an entity pushed into a wall or the arena boundary stops there rather than clipping through. Once the Visual Death timer expires, the entity is returned to the object pool (Logical Death).
- **Projectile Orphans:** If the entity that fired a projectile dies, the projectile continues, but its damage source reference is resolved by value at the time of firing, not by reference to the dead entity.

---

### Performance Budget

- **Off-screen update reduction:** an enemy whose offset from the camera centre exceeds 1.5 times the view's half-extent on either axis moves only on every third physics tick with its velocity multiplied by 3 for that call, staggered by spawn serial mod 3; never within 320 px (two Interaction Radii) of the Tower.

---

### Performance Fallback Ladder

The provisional budget of 300 `CharacterBody2D` enemies, 400 `Area2D` projectiles, and 150 pickups has not been measured on this project, and per-node physics overhead in Godot is known to be the limiting factor for survivors-like enemy counts. The swarm stress test is therefore the last Phase 1 task (P1.7), run before any gameplay content. Each step below is adopted only if the performance rule fails at the content density under test, taken in order, and testing stops at the first step that passes; document 20 records which step was needed. Phase 3 re-runs the ladder at vertical-slice content density, since a step that passed at prototype density is not guaranteed to still pass at slice density.

1. The magnet raycast (Pickup Physics & Magnet Rules) runs every 2nd tick instead of every tick, and the pickup merge radius increases from its Economy Configuration default (64 px) to 128 px.
2. Off-screen enemy update reduction (Performance Budget, above) is enabled.
3. Enemy movement moves off `CharacterBody2D` onto a project-owned movement system that calls `PhysicsServer2D` directly with pooled shapes; enemy hurtboxes and hitboxes move to `PhysicsServer2D` area RIDs or a spatial hash instead of `Area2D` nodes; rendering moves to `MultiMeshInstance2D` for enemies of the same archetype.
4. Caps drop to 200 enemies, 300 projectiles, 100 pickups, and the Wave Director budgets are retuned. If step 4 fails, the design is revised — fewer simultaneous enemies per wave — and the revision is recorded in the Decision Log.

Step 3 is the expected end state for the vertical slice; the prototype may stop at whichever step first passes the test.

---

## Interim Prototype Technical Budgets

These budgets are temporary validation budgets for the prototype. They are not final tuning values. Final cap and frame-rate numbers belong to document 20; the behaviour when a cap is hit belongs to documents 11 (enemies), 06 (projectiles), and 16 (pickups); scaling curves belong to document 12.

Until those documents are stable, the following provisional budgets govern prototype development:

| Budget | Provisional Prototype Value | Required Behavior If Exceeded |
| --- | ---: | --- |
| Target frame rate | 60 FPS | Visual effects degrade before simulation degrades |
| Minimum acceptable frame rate under load | 45 FPS | Reduce particles, damage numbers, and non-critical effects first |
| Maximum active enemies | 300 | Spawner and Overtime finishers both throttle; no unbounded queue; the cap is never exceeded (Wave Director › Wave Runtime Model) |
| Maximum active pickups | 150 | Oldest pickups merge or expire |
| Maximum active projectiles | 400 | Oldest projectiles recycle |
| Maximum active damage numbers | 30 | Oldest damage numbers are culled |
| Maximum simultaneous telegraphs | 40 | New attack wind-ups wait with their cooldown held rather than attacking untelegraphed; player-aimed telegraphs take slots first; a spawn group's off-screen markers aggregate to one telegraph per 30° sector |
| Maximum visible high-intensity VFX | 24 | Effects reduce before enemy visibility reduces |
| Scrap inventory cap | 200 (HUD "n/200") | Overflow goes to the overflow hopper (cap 100), which converts to Cores at 10:1 when the player enters the Tower Interaction Radius; the prototype has no hopper, so overflow is discarded immediately with a FULL indicator |
| Maximum screen shake offset | 12 px | Shake clamps; telegraphs stay legible |
| Maximum simultaneous SFX voices | 32 | Lowest-priority, then oldest, voice is stolen |

These numbers may be changed, but they may not be ignored. Any system that requires exceeding these budgets must justify the change in the owning system document before implementation.

Performance is measured by one rule everywhere in this document: during the heaviest in-scope encounter, the median frame rate is at least 60 FPS and the 1st-percentile frame rate is at least 45 FPS, as read from the debug overlay. The measurement is taken on the **reference machine**, the development laptop (AMD Ryzen 5 4600H with 6 cores and 12 threads, NVIDIA GeForce GTX 1650 Ti with 4 GB alongside Radeon integrated graphics, 15.4 GB of RAM, 1920 by 1080 display), with Godot running on the NVIDIA GPU, in an exported release build rather than the editor, with V-Sync off and 60 seconds of frame data logged to CSV. Document 20 records any change of reference machine. "Target frame rate", "minimum acceptable frame rate", and "acceptable performance" all refer to this rule.

The readability hierarchy always outranks visual density.

---

### Contract Field Semantics

Every field name used in the contracts below has one meaning, stated here so a programmer can type it. Shared field and struct types are typed once; fields specific to a single contract are typed in the table under that contract's name. Biome, Boss, Elite Affix, and Status Effect are slice-only contracts and may keep partial typing here; their full typing is deferred to before Phase 3.

#### Shared fields and struct types

| Field | Type | Meaning |
| --- | --- | --- |
| Unique ID | string | Stable identifier used in data references and telemetry; never reused |
| Target intent | enum | One of Tower Seeker, Player Hunter, Opportunist, Zone Denier, Disruptor, Splitter |
| Health | integer | Current or maximum HP value; the prototype stores the literal number directly (Provisional Values Register) |
| Band label | nullable enum {Low, Mid, High} | Categorical tier for a Health or Damage value; null in the prototype, populated by document 12 with its scaling curves from the vertical slice onward |
| Difficulty band | enum {Low, Mid, High} | Categorical tier for a wave or biome, not a raw stat; mapped to scaling curves by document 12 |
| Contact behaviour | enum {None, Damage, Explode, Block} | What an enemy body does on overlap with the player hurtbox; Damage uses the contact tick rule |
| Entity cap weight | integer ≥ 1 | Slots consumed against the active-enemy cap |
| Readability profile | struct {silhouette class: enum {Small, Medium, Large, Boss}, reserved colour: colour reference, minimum on-screen size: integer px} | Governs how an entity stays identifiable under the readability hierarchy |
| Priority | integer 0 to 100 | Higher wins when two encounters trigger together; ties by Unique ID ascending |
| Entity cap behaviour | enum {Throttle, Defer, Skip} | What the encounter does when its spawns would exceed the cap |
| Allowed / Excluded encounter tags | string list | Tags that may or may not be active concurrently with this encounter |
| Pause and deferral behaviour | enum {DeferUntilDraftCloses, Cancel} | What a scheduled encounter does if the Draft opens first |
| Pool ownership | enum {Player, Tower, Weapon, Utility} | Which upgrade pool owns the definition; also drives card differentiation |
| Visual readability impact | enum {None, Low, High} | Whether the effect adds screen density; High effects count against the VFX budget |
| Performance cost category | enum {Light, Medium, Heavy} | Used by the effects budget to decide what degrades first |
| Spawn budget | integer | Derived: sum of the wave's spawn groups' cap weights; not authored |
| Inter-wave gap | float seconds (simulation time) | Time that must pass after this wave ends before the next wave's first spawn group may start |
| Minimum recovery gap | float seconds (simulation time) | Time that must pass after this encounter completes before another encounter may open (C-DEFER; Wave Director › Wave Runtime Model) |
| Stall threshold | integer | Kills per 30 seconds below which Overtime may fire |
| Telegraph data | struct {wind-up duration: float seconds, telegraph shape: enum {Wedge, Line, Circle, Ring}, telegraph colour reference: colour reference, audio cue ID: string} | Describes how an attack or spawn is signalled before it resolves |
| Spawn group | struct {enemy definition: Enemy Unique ID, count: integer, start offset: float seconds from encounter open, spawn interval: float seconds between individual spawns, direction weighting override: nullable reference to the encounter's Directional Weighting rule} | One wave of enemies an encounter emits; a spawn group starts at its start offset or earlier if the Escalation Trigger starts it (Wave Director › Wave Runtime Model); an encounter is an ordered list of these |
| Movement profile | struct {speed multiplier: float (relative to the player's base speed), body radius: integer px} | The enemy's locomotion values; pathing behaviour itself is the separate Pathing fallback behavior field |
| Attack profile | struct {attack type: enum {Melee, Ranged, Contact}, damage per hit or tick: integer, cycle or tick interval: float seconds, reach or range: integer px} | The enemy's damage-dealing values; wind-up timing lives in Telegraph data |
| Effect | struct {kind: enum {Damage, Heal, StatModifier}, magnitude: float, target: enum {Player, Tower, Enemy}} | A single mechanical consequence, used by a status effect's Tick effect field |
| Overtime condition | struct {stall threshold: integer (see Stall threshold), finisher enemy reference: Enemy Unique ID, finisher spawn rate: struct {count: integer, interval: float seconds}, finisher drop override: Drop table} | When a wave enters Overtime at its maximum duration, and what its finishers are |
| Pressure Metric constants | struct {escalation threshold: float, escalation hold time: float seconds, minimum gap between escalations: float seconds, de-escalation threshold: float, de-escalation lift threshold: float, de-escalation expiry: float seconds, re-arm lockout: float seconds} | Per-wave tuning of the Pressure Metric; absent fields fall back to the Director Configuration defaults |
| Drop table | struct {XP shards: integer, Scrap: integer, Cores: integer} | The fixed reward a Logical Death places on the field; values match the entity's tier in Resource & Economy System › Drop Table (Standard, Elite, Mini-Boss, Biome Boss, Overtime finisher, or Splitter child, which drops nothing) |
| Reward | struct {XP: integer, Scrap: integer, Cores: integer} | The fixed reward an encounter grants on completion; used by Partial reward rules |

#### Enemy Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Pathing fallback behavior | enum {Standard, Custom} | Standard invokes the global Stuck rules owned by document 09; Custom points to a documented exception |
| Elite eligibility | boolean | Whether this enemy may spawn as an Elite variant carrying an affix |
| Allowed affixes | list of Elite Affix Unique IDs | Which affixes may roll onto this enemy when spawned as an Elite |
| Biome tags | list of Biome Unique IDs | Which biomes' enemy pools may include this enemy |

#### Encounter Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Encounter type | enum {StandardAssault, SplitAssault, Siege, Hunt, Elite, Duel, MiniBoss, BiomeBoss, Escort, Blackout, Breach, Ambush, Pincer, EnvironmentalEvent, ResourceRush, SwarmCrush} | Which encounter behaviour this definition instantiates |
| Directional weighting override | nullable struct, shaped like Director Configuration's per-encounter-type directional weighting entry | A non-null value overrides the Director Configuration entry for its encounter type |
| Design intent | string | One-sentence designer statement of the pressure this encounter is meant to create |
| Pressure target | float | Target Pressure Metric value this encounter is tuned to produce; used in tuning, not enforced at runtime |
| Player answer | string | The action a player is expected to take to resolve this encounter's pressure |
| Failure signature | string | The observable symptom marking this encounter as going badly, referenced by tester probes |
| Spawn groups | ordered list of Spawn group structs | The encounter's full emission sequence |
| Intent budget overrides | list of {target intent: enum, count: integer} pairs | Overrides the wave's Enemy intent mix for this specific encounter (for example T1's Hunters-only budget) |
| Telegraph requirements | list of Telegraph data references | Which telegraphs, with lead time, this encounter must schedule before any on-screen spawn |
| Encounter alive cap | integer | Maximum simultaneous entity cap weight this encounter may have alive at once; throttles like the global cap |
| Failure resolution | enum {RewardForfeited, CompletesWithPartialReward} | Default resolution per Encounter failure; an encounter with no reward defined cannot fail except via run failure |
| Partial reward rules | nullable Reward struct | The reward granted when "win condition becomes impossible"; null if the encounter defines none |

#### Upgrade Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Rarity | enum {Common, Rare, Epic} | Reserved for future rarity tiers; the prototype pool uses a single implicit tier |
| Maximum rank | nullable integer | Highest rank purchasable; null for the no-max-rank fallback cards |
| Prerequisites | list of Upgrade Unique IDs | Upgrades that must already be owned before this one may be offered |
| Exclusions | list of Upgrade Unique IDs | Upgrades that may never be owned alongside this one |
| Effect description | string | Human-readable statement of the effect, shown on the card |
| Effect target | enum {Player, Tower, PlayerWeapon, TowerWeapon} | The specific stat the effect modifies (for example fire rate, damage, health, range, shield) |
| Effect per rank | float | Numeric magnitude applied once per rank held, paired with Effect target; percentage or flat amount per Effect description |
| Console price per rank | integer Scrap | Cost to purchase the next rank at the Tower Console, following the Economy Configuration's Console price formula |
| Recursive interaction guard | enum/string, nullable | Rule preventing unbounded recursion for an on-kill or on-hit effect; null if the upgrade has no triggered effect |

#### Wave Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Biome context | Biome Unique ID | Which biome this wave belongs to |
| Encounter sequence | ordered list of Encounter Unique IDs | The encounters this wave opens, in order |
| Enemy intent mix | list of {target intent: enum, proportion: float 0–1 summing to 1} pairs | The wave's default composition, expressed as proportions; overridable per encounter via Intent budget overrides |
| Elite chance | float 0 to 1 | Probability a spawned standard enemy is upgraded to Elite; 0 in the prototype (no elites) |
| Maximum duration | nullable float seconds | Hard cutoff that triggers the stall check if reached first; null for boss waves, which have no maximum duration |
| Target duration | float seconds | The designed length this wave is tuned to finish within |
| Boss overlap rules | enum {NotApplicable, SuppressesRegularSpawns} | Whether this wave may run concurrently with a boss wave |

#### Biome Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Mechanical hook | string | The single mechanic that gives this biome its identity |
| Hazard definition | struct | The hazard's behaviour, referencing its Telegraph data |
| Hazard telegraph | Telegraph data reference | How the hazard is signalled before it activates |
| Enemy pool expressed by target intents | list of {target intent: enum, Enemy Unique IDs} | Which enemies this biome may spawn, grouped by intent |
| Boss pool | list of Boss Unique IDs | Which bosses may appear in this biome |
| Readability palette | struct {reserved colours: list, keyed by hazard/enemy class} | Colour reservations that keep this biome's threats distinguishable |
| Tower hazard damage rule | enum {HazardsIgnoreTower, HazardsDamageTower} | Whether this biome's hazards can damage the Tower |
| Transition cleanup rule | reference to the Biome Transition persistence rules | What of this biome's state persists or is cleared at transition |
| Exclusive mechanics | list of mechanic IDs | Mechanics unique to this biome |

#### Tower Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Maximum health and base shield fraction | struct {maximum health: integer, base shield fraction: float} | The Tower's health pool and its starting shield as a fraction of that pool |
| Shield regeneration rate and delay | struct {rate: float % per second, delay: float seconds} | How and when the shield regenerates after damage |
| Footprint radius and Interaction Radius | struct {footprint radius: integer px, Interaction Radius: integer px} | The Tower's physical size and its vulnerability-window radius |
| Base weapon reference | Weapon Definition Unique ID | The Tower's default weapon |
| Targeting rule parameters | struct {range: integer px, intent preference: target intent enum} | Inputs to the Tower Targeting Rule |
| Evolution stage thresholds | list of 4 integers | Upgrade-rank thresholds for Base, Reinforced, Armed, Fortress |
| Repair price | struct {Scrap cost: integer, health restored: integer, pro-ration rule} | Cost and effect of one Tower Repair purchase |
| Persistent asset rules | list of {asset class: string, persists across biomes: boolean} | Which Tower-attached assets (for example drones) survive a biome transition |

#### Tower Upgrade Definition Contract fields

Every Tower upgrade definition must include every field of the Upgrade Definition Contract, with Pool ownership set to Tower, plus:

| Field | Type | Meaning |
| --- | --- | --- |
| Evolution stage contribution | integer | Ranks this upgrade counts toward the Tower's visual evolution stage |
| Draft weight | integer ≥ 0 | 0 excludes the card from the Level-Up Draft pool; every prototype Tower upgrade uses 1 |

#### Weapon and Evolution Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Damage per shot | integer | Damage dealt by one projectile hit or one melee/contact activation |
| Effective range | integer px | Maximum distance the weapon can hit a target |
| Coverage shape | enum {Cone, Line, Radius, SingleTarget} | The shape of the weapon's effect |
| Target count | integer | How many targets the weapon can affect per activation |
| Engagement rhythm (sustained or burst) and fire rate | struct {rhythm: enum {Sustained, Burst}, fire rate: float shots per second} | How the weapon fires over time |
| Projectile definition | struct {speed: integer px/s, lifetime: float seconds, pooling class: string} | The projectile this weapon spawns, if any |
| Evolution prerequisites and the evolution target | struct {prerequisites: list of Upgrade Unique IDs, evolution target: Weapon Unique ID} | What must be owned to evolve, and what the weapon becomes |
| Which of range, coverage, target count, or rhythm the evolution changes | list of enum {Range, Coverage, TargetCount, Rhythm}, length ≥ 1 | Which stat categories the evolution alters, per Weapon Evolution Philosophy |

#### Boss Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Unique ID and class | struct {Unique ID: string, class: enum {MiniBoss, BiomeBoss}} | Identity and tier of the boss |
| Signature mechanic | string | The one mechanic that defines this boss's fight |
| Tower relationship | enum {Threatens, AffectedBy, Displaces} | How the boss interacts with the Tower |
| Phase list | ordered list of structs {trigger: string/enum, emphasis: string, transition telegraph: Telegraph data reference} | The boss's phases in order |
| Arena sub-region bounds, if any | nullable shape | Sub-region boundary for this boss, if any; never excludes the Tower |
| Regular spawn suppression rule while active | boolean | Whether normal wave spawning is suppressed while this boss is alive |
| Hazard cleanup schedule | reference | When hazards this boss created are removed |
| Core drop | integer Cores | Cores awarded on this boss's death, per Run-End Settlement and the Drop Table |

#### Elite Affix Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Behavioural effect | string | What the affix does to its host enemy |
| Stacking and self-interaction guard | enum/string | Rule preventing the affix from applying to itself or looping with another affix |
| Revive count, if reviving | nullable integer | How many times a reviving affix may trigger; null if the affix does not revive |
| Visual marker | struct {colour: colour reference, icon: string} | How an Elite carrying this affix is visually marked |
| Eligible target intents | list of target intent enum values | Which intents this affix may roll onto |

#### Pickup Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Unique ID and type | struct {Unique ID: string, type: enum {XP, Scrap, Core, Health (vertical slice only)}} | Identity and currency/kind of the pickup; the prototype spawns only XP, Scrap, and Core |
| Value | integer | Amount granted on collection |
| Magnet behaviour | enum {Attracted, Static} | Whether the pickup follows the magnet radius query and pickup physics, or stays put |
| Merge rule | struct {trigger: at pickup cap, same type only: true, match radius: reference to Economy Configuration's Merge radius field, resulting behaviour: sum into nearest same-type neighbour within radius, else expire oldest of that type} | How this pickup type behaves when the pickup cap is hit |
| Lifetime in simulation seconds | float | How long an uncollected pickup exists before expiry (Cores never expire; they bank instead) |
| Visual and audio cue | struct {sprite reference: string, audio cue ID: string} | How the pickup reads on collection |

The Pickup Definition Contract carries no Entity cap weight field; the pickup cap (Interim Prototype Technical Budgets) is a flat count, not a weighted sum.

#### Status Effect Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Stacking rule | enum {Refresh, StackWithCap, Ignore} | How repeated applications of this status combine |
| Duration in simulation seconds | float | How long one application lasts |
| Tick effect and tick interval | struct {tick effect: Effect struct, tick interval: float seconds} | What happens on each tick, and how often |
| Source lifetime rule | enum | What happens to the status when its source dies |
| Cleanup rule at biome transition | enum | Whether the status survives a biome transition |

#### Player Definition Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Maximum health | integer | Player HP pool |
| Base speed | float px/s | Reference (1.0×) movement speed |
| Acceleration time to base speed | float seconds | Time to reach full speed from rest |
| Deceleration time to stop | float seconds | Time to reach zero speed from full speed |
| Body radius | integer px | Collision circle radius at the feet; the hurtbox matches it |
| Hurtbox definition | enum {SameAsBody} | The player's damageable shape |
| Collector area radius | integer px | Pickup-collection overlap radius (body + 8) |
| Magnet radius | integer px | Distance within which pickups become attracted |
| Input buffer duration | struct {duration: float ms, ticks: integer} | How long a queued input is held, cleared on pause |
| Starting weapon reference | Weapon Definition Unique ID | The weapon the player begins a run holding |

#### Director Configuration Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| Spawn ring geometry | struct {Tower ring: {inner radius: integer px, width: integer px}, view ring: {inner radius: integer px, width: integer px}} | The two spawn ring definitions |
| Camera exclusion margin | integer px | Margin added to the camera view when rejecting spawn candidates |
| Spawn validation retry steps and angle increment | struct {steps: integer, angle: float degrees} | How spawn validation shifts along a ring before giving up for the tick |
| Off-screen and on-screen marker lead times | struct {off-screen: float seconds, on-screen minimum: float seconds} | How far ahead a spawn marker must appear before its spawn |
| Directional weighting rules per encounter type | struct, keyed by encounter type, fields {lane count: integer, lane width: float degrees, lane separation rule: enum {Fixed180, MobilityScaled}, heavy share: float, ring: enum {Tower, View}, hunt arc: float degrees, hunt arc share: float} | Lane angles, split ratios, and arc percentages per encounter type |
| Encounter priority table | list of {encounter type: enum, priority: integer} | Default Priority values by encounter type |
| Default recovery gap table | list of {encounter type: enum, recovery gap: float seconds} | Default Minimum recovery gap values by encounter type |
| Inter-wave gap defaults | struct {standard: float seconds, teaching-wave: float seconds} | Default Inter-wave gap, and its shorter value after T1–T3 |
| Post-draft grace period | float seconds | Time after a Level-Up Draft closes during which no encounter opens and no spawn group starts |
| Pressure Metric intent weights | list of {target intent: enum, weight: float} | The intent_weight term used in the Threat calculation |
| Pressure Metric escalation and de-escalation timers | Pressure Metric constants struct | Default values a Wave's own Pressure Metric constants may override |
| Off-screen update reduction thresholds | struct {distance multiplier: float, tick divisor: integer, Tower exclusion radius: integer px} | When an off-screen enemy switches to reduced-tick updates |
| Siege volume formula constants | struct {multiplier defaults: list of float, Hunter percentage: float, spawn window: float (fraction of wave duration)} | Inputs to the Siege Seeker-count formula |
| Health quadrant threshold | float fraction | Health fraction (shield excluded) below which a pool is recorded as Low |

#### Economy Configuration Contract fields

| Field | Type | Meaning |
| --- | --- | --- |
| XP shard value and level cost formula | struct {shard value: integer, cost formula: L → 10 + 5(L+1)} | XP granted per shard, and the cost to advance a level |
| XP cap during teaching waves | integer | XP ceiling while T1–T4 are open, before the forced first Draft |
| Merge radius | integer px | Default same-type pickup merge distance at the pickup cap (default 64 px; Fallback Ladder step 1 raises it to 128 px) |
| Scrap cap | integer | Maximum carried Scrap before overflow |
| Overflow hopper capacity | integer | Maximum Scrap the overflow hopper can hold |
| Hopper-to-Core conversion rate and trigger | struct {rate: integer:1, trigger: enters Tower Interaction Radius} | How hopper Scrap becomes Cores |
| Core persistence write cadence | float seconds | Maximum interval between atomic Core writes while dirty |
| Run-End Settlement rates | struct {per biome cleared: integer Cores, per boss killed: integer Cores, per full minute: integer Cores} | Core payout formula at run end |
| Upgrade Console price formula | struct {Scrap per rank: integer, formula: price = Scrap-per-rank × rank being bought} | The multiplier every prototype upgrade's Console price per rank resolves from |
| Dominance audit threshold and sample size | struct {threshold: float fraction, minimum runs: integer} | Inputs to the dominant-pair audit |

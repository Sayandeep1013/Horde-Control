# P2.x Integration Report — Assets, Wiring, and the Assembled Prototype Scene

Per MASTER_SDLC.md > Document Control > Gate Approval, this report does not state that any test, gate, or this phase is passed, satisfied, met, or ready. It records what was built, what each test checks, the commands run, their exit codes, and the falsification logs. Determinations belong to the reviewers and the author.

## GodotPrompter skills consulted

`scene-organization`, `godot-testing`, `audio-system`, `2d-essentials` — all four read in full, per this task's brief.

- **`scene-organization`** — no conflict. The wrapper scene (`scenes/prototype.tscn`) is exactly the skill's own "Level Scene Pattern": a composition root that owns layout and instances other scenes, with no gameplay logic of its own beyond typed-command wiring. Signals-up/methods-down and EventBus-for-peers were already this project's convention before this task; nothing here departs from it.
- **`godot-testing`** — same conflict already on record six times this phase (F03-08 and its repeats in the P2.3/P2.5/P2.6 evidence reports): the skill's `test_*.gd` prefix convention vs. this project's established `*_test.gd` suffix. `tests/unit/prototype_scene_test.gd` follows the project's suffix convention. Not a new finding, recorded again per CLAUDE.md's instruction to record every occurrence.
- **`audio-system`** — no conflict. Its guidance (bus-per-purpose routing, WAV for short SFX vs. OGG for longer ones, `AudioStreamPlayer` for non-positional cues, dedicated pools over ad-hoc instancing) matches what P1.6 already built (`AudioPool`, `TowerCuePlayer`) and what this task reuses rather than duplicates.
- **`2d-essentials`** — **one factual inaccuracy found in the skill's own text, not a project-vs-skill conflict**: the skill's "Canvas Layers and Draw Order" section states `z_as_relative (default: false = global)`. Godot 4.7.1's actual default is `true` (relative), confirmed empirically (`n.z_as_relative` on a fresh `Node2D.new()` prints `true` — see "A real defect this task found" below, which depends on this fact being correct). Recorded because CLAUDE.md asks for every skill-vs-reality mismatch to be on the record, not only skill-vs-project ones; this one caused no incorrect code here (this task tested the actual engine value rather than trusting the skill's stated default), but it could mislead a future reader of that skill file.

## Files written or modified

### New files

| Path | Purpose |
| --- | --- |
| `scenes/prototype.tscn` | The assembled playable prototype (P2.7's own definition): arena, Tower, player, camera, HUD, threat feedback, three hand-placed enemies (one per intent), no Wave Director |
| `src/integration/prototype_integration.gd` | `PrototypeIntegration`, attached to the wrapper scene's root — performs only typed-command wiring (no gameplay logic) between the already-built public seams every P2.1-P2.6 evidence report named and could not call itself |
| `src/enemy/telegraph_visual.gd` | `TelegraphVisual` — wires `telegraph_diamond.png` into all three enemy scenes; purely cosmetic, polls `EnemyController.is_windup_active()` |
| `src/ui/ui_sfx.gd` | `UiSfx` — the three `audio/ui/*.ogg` cues on their own `PROCESS_MODE_ALWAYS` players, per docs/20's own description of the mechanism; no caller exists yet (see "What could not be wired") |
| `tests/unit/prototype_scene_test.gd` | The integration suite (30 tests) — see "Verification" |
| This report | `phases/PHASE_03_Core_Entities_And_Feel_Check/evidence/p2x_integration_report.md` |

### Modified files

| Path | What changed |
| --- | --- |
| `scenes/arena.tscn` | Floor texture repointed to the Kenney asset; four wall Sprite2D visuals added (previously collision-only) |
| `scenes/tower.tscn` | `Platform` sprite added; `TowerVisuals` wired with `platform_texture` + `stage_textures[4]`; `TowerWeapon` wired with `projectile_texture` + `fire_sfx`; `Projectiles`' `z_as_relative` fixed (see "A real defect this task found") |
| `scenes/player.tscn` | `AutoWeapon.fire_sfx` wired; `Player.damage_sfx` wired; `Projectiles`' `z_as_relative` fixed (same defect class as tower.tscn) |
| `scenes/entities/{tower_seeker,player_hunter,opportunist}.tscn` | `TelegraphVisual` child added; `hit_sfx`/`death_sfx` wired |
| `scenes/ui/threat_feedback.tscn` | Not touched (no node changes needed) |
| `src/tower/tower_visuals.gd` | `platform_path`/`platform_texture`/`stage_textures` exports; `on_stage_changed()` |
| `src/tower/tower.gd` | Connects `evolution_stage.stage_changed` to `visuals.on_stage_changed`; primes the stage-0 texture once |
| `src/tower/tower_weapon.gd` | `projectile_texture`/`fire_sfx` exports; `_projectile_factory()` de-`static`'d to attach a Sprite2D by composition; `set_audio_pool_ref()`; plays `fire_sfx` |
| `src/combat/auto_weapon.gd` | `fire_sfx` export; `set_audio_pool_ref()`; plays `fire_sfx` |
| `src/combat/player_projectile.gd` | `PROJECTILE_TEXTURE` (a `const`) converted to `@export var projectile_texture` defaulting to the Kenney asset |
| `src/player/player.gd` | `damage_sfx` export; `set_audio_pool_ref()`; plays `damage_sfx` (as an `SFX_Priority` voice) in the existing damage handler |
| `src/enemy/enemy_controller.gd` | `hit_sfx`/`death_sfx` exports; `set_audio_pool_ref()`; plays `hit_sfx` (before the existing Opportunist-only early return) and `death_sfx` (via a new listener on this enemy's *own* `death_state.logical_death`, distinct from the existing Opportunist-target-death listener) |
| `src/ui/threat_feedback.gd` | `cue_stream` export defaulting to the real Kenney `tower_damage.ogg`, replacing the placeholder-tone default (the placeholder generator itself is kept as a fallback if `cue_stream` is ever cleared to null) |

**Files on the do-not-touch list were not touched**: confirmed by `git status --short` before finishing — `src/core/sim_loop.gd`, `src/core/event_bus.gd`, `src/combat/death_state.gd`, `src/combat/hitbox.gd`, `src/tower/tower_projectile.gd` all show no diff. `scenes/main.tscn`, `project.godot`, `export_presets.cfg`, `.claude/settings.json`, `addons/`, `tools/`, `sandbox/` were read where needed but never written.

## Every asset path wired, and what it replaced

All from `assets/third_party/kenney/` (per `PROVENANCE.md`), every path an `@export`ed field or a `.tscn` `ext_resource`, never a hardcoded string in a function body (D99):

| Asset | Wired into | Replaced |
| --- | --- | --- |
| `environment/floor_tile.png` | `scenes/arena.tscn` → `Floor.texture` | the generated `assets/sprites/floor_tile.png` |
| `environment/wall_tile.png` | `scenes/arena.tscn` → four new `Sprite2D` nodes (`WallNorthSprite` etc.), sized/positioned to match each wall's `CollisionShape2D` exactly | nothing — the walls had no visual before this task, collision-only |
| `tower/tower_platform.png` | `TowerVisuals.platform_texture`, on a new `Platform` sprite drawn beneath the stage sprite | nothing — no base plate existed |
| `tower/tower_stage1_base.png` .. `tower_stage4_fortress.png` | `TowerVisuals.stage_textures[0..3]`, applied by `on_stage_changed()`, keyed to the Register's *Tower evolution thresholds* row (0/1/3/6 ranks → Base/Reinforced/Armed/Fortress; `TowerEvolutionStage`'s own stage-index convention) | the generated `assets/sprites/tower.png`, previously the Tower's only look at every stage |
| `projectiles/projectile_player.png` | `PlayerProjectile.projectile_texture` (now an `@export`, was a `const`) | the generated `assets/sprites/projectile_player.png` |
| `projectiles/projectile_tower.png` | `TowerWeapon.projectile_texture`, attached to each fired `TowerProjectile` by composition (a plain `Sprite2D` child added in `TowerWeapon`'s own factory) | nothing — the Tower's projectile had no visual before this task (`tower_projectile.gd` itself was never touched; see "Do-not-touch list, honoured") |
| `telegraphs/telegraph_diamond.png` | `TelegraphVisual.texture`, one instance under each of the three enemy scenes | nothing — no telegraph visual existed |
| `audio/sfx/tower_damage.ogg` | `ThreatFeedback.cue_stream` | **the procedurally generated placeholder tone** (`AudioStreamWAV`) P2.6 was using — this is the gap the brief called out explicitly (F03-18's audio half). The placeholder generator is kept, unused by default, as a fallback only |
| `audio/sfx/player_fire.ogg` | `AutoWeapon.fire_sfx`, played through `AudioPool` on every shot | nothing — the Handgun was silent |
| `audio/sfx/tower_fire.ogg` | `TowerWeapon.fire_sfx`, played through `AudioPool` on every shot | nothing — the Tower's weapon was silent |
| `audio/sfx/player_damage.ogg` | `Player.damage_sfx`, played through `AudioPool` as an `SFX_Priority` voice (docs/20 > Audio Mixing: "Player damage ... routed to SFX_Priority") | nothing — the player took damage silently |
| `audio/sfx/enemy_hit.ogg` | `EnemyController.hit_sfx`, played through `AudioPool` on every hurtbox hit, for all three intents | nothing |
| `audio/sfx/enemy_death.ogg` | `EnemyController.death_sfx`, played through `AudioPool` on this enemy's own `death_state.logical_death` | nothing |
| `audio/ui/confirm.ogg`, `cancel.ogg`, `cycle.ogg` | `UiSfx.confirm_stream`/`cancel_stream`/`cycle_stream`, on three dedicated `PROCESS_MODE_ALWAYS` players routed to the `UI` bus | nothing — see "What could not be wired," no caller exists yet |

**Not wired, named rather than silently skipped**: `pickups/pickup_xp.png`, `pickup_scrap.png`, `pickup_core.png`. This task's own brief lists Arena, Tower, Projectiles, Telegraph, and Audio as the assets to wire; pickups are not named, and no pickup system exists yet (P2.8, Phase 04). They remain in `assets/third_party/kenney/pickups/` for that future task.

## A real defect this task found (not named in advance by any brief)

**`z_as_relative` accumulates through every relative ancestor, and both `Player`'s and `Tower`'s own `Projectiles` containers were vulnerable to it the moment either scene stopped being its own scene root.** Godot's own rule (confirmed empirically against the pinned 4.7.1 build, not assumed — see "Skills consulted," the `2d-essentials` inaccuracy above): a `CanvasItem`'s effective z_index is its own `z_index` plus every ancestor's `z_index`, walking up through each ancestor for as long as that ancestor's own `z_as_relative` is `true` (the actual default, confirmed via a throwaway `SceneTree` script: `Node2D.new().z_as_relative` prints `true`).

`PlayerProjectile.z_index = 30` (P2.3's own field, correct and tested — in isolation, with `Player` as the scene's own root, contributing nothing). `Player.z_index = 50` (P2.1's own field, also correct in isolation). Neither task could have seen the problem: nesting `Player` under a non-trivial parent is exactly what this integration task does for the first time. Once `Player` is a child of `Main` (`z_index = 0`, contributing nothing) — the moment this prototype scene requires — the chain `Main(0) → Player(50) → Projectiles(0) → PlayerProjectile(30)` accumulates to **80**, not 30: a fired Handgun shot would have rendered *above* the player, telegraphs, and even (at some view angles) the damage-number band, not at the Register's "player projectiles 30" band below the Tower. The identical defect existed in `scenes/tower.tscn`'s own `Projectiles` container (`Main(0) → Tower(25) → Projectiles(30) → TowerProjectile(0)` = 55, not 30).

**Fixed** by setting `z_as_relative = false` on both `Projectiles` container nodes (a one-property change in each `.tscn`, touching neither `player_projectile.gd` nor the forbidden `tower_projectile.gd`): this makes each container's own z_index (0 for Player's, 30 for Tower's, both already-correct absolute intents) the accumulation's new anchor, so the projectile's own relative offset is added to that fixed point instead of to however deep the container happens to sit. `TelegraphVisual` (a new node, nested under an enemy inside `Entities`, three ancestor levels deep) was built with this lesson already applied: `z_as_relative = false` set directly in its own `_ready()`, so its absolute z_index (40) never depends on how deep it is nested.

**Falsified three ways**, each verified to fail before being fixed and to pass after:
1. `tests/unit/prototype_scene_test.gd::test_player_projectile_effective_z_index_is_30_not_accumulated` — with the fix in place, a real fired `PlayerProjectile`'s accumulated z_index is 30.
2. The same test with the fix **temporarily removed** from `scenes/player.tscn` (one line deleted, restored via `diff`-confirmed byte-identical backup afterward): the test failed with `Expecting: 30, but was: 80` — the exact number the arithmetic above predicts.
3. `test_tower_projectile_effective_z_index_is_30_not_accumulated` for the identical class of bug in `scenes/tower.tscn`.

This is exactly the class of seam this project's own convention (F02-13, F03-05, F03-15) names repeatedly: a value correct in every task's own isolated test, wrong only once two tasks' work is actually nested together — which is this integration task's entire reason to exist.

## The Tower's stage-to-texture mapping

`TowerEvolutionStage` already tracked `ranks_held`/`_current_stage` (P2.4); nothing in it needed to change. `TowerVisuals.on_stage_changed(new_stage, ranks_held)` is a new typed listener, wired by `Tower._ready()` to `evolution_stage.stage_changed`, and also called **once, directly**, immediately after connecting — `TowerEvolutionStage.configure()` sets stage 0 but only *emits* `stage_changed` on a later change, so nothing would otherwise apply the initial Base texture until the first rank is taken (which nothing in this prototype ever does; no upgrade system exists until Phase 05). `ShieldShimmer`'s own texture is kept in sync with `Sprite`'s on every stage change, so the shimmer overlay never shows a different stage's silhouette than the sprite it overlays.

## Audio routing, per the Register's Buses row and docs/20 > Audio Mixing

- **Tower cue**: `ThreatFeedback` → the real `src/audio/tower_cue_player.gd` (P1.6, unmodified) → `TowerCue` bus → `SFX_Priority`. Not duplicated; the existing `TowerCuePlayer`/`CueRetriggerLimiter` mechanism is reused exactly as P2.6 built it, only the stream it plays changed.
- **Ordinary SFX** (player fire, Tower fire, enemy hit, enemy death): `AudioPool.play(stream, position, 0, false, "SFX")` — the existing 32-voice pool (P1.6, unmodified), never a second pool.
- **Player damage**: docs/20 > Audio Mixing states plainly that "Player damage, Tower damage, and Boss telegraphs are routed to `SFX_Priority`, which never ducks" — `AudioPool.play(damage_sfx, position, 10, true, "SFX_Priority")`, i.e. a *priority* voice on the pool AudioPool already supports (its own `is_priority_voice` parameter), not a second mechanism. **Named limitation**: docs/20 also states a 150 ms retrigger limit for player damage, matching the Tower cue's own 250 ms one via `CueRetriggerLimiter`. This task did **not** build a second retrigger limiter for player damage — building a new timing mechanism is closer to a gameplay-audio feature than to "wire an existing asset," and this task's own brief frames the Tower cue, not player damage, as "the one that closes a real gap." Recorded here rather than silently built or silently skipped.
- **UI cues**: three dedicated `PROCESS_MODE_ALWAYS` `AudioStreamPlayer`s on the `UI` bus (`src/ui/ui_sfx.gd`), matching docs/20's own description of the mechanism ("UI sounds do not draw from this pool; they play on their own PROCESS_MODE_ALWAYS players"). See "What could not be wired" below — nothing calls them yet.

### The AudioDucking placement — the one named contradiction, not resolved, avoided instead

NEXT_SESSION.md's own open row: *"`AudioDucking` needs `PROCESS_MODE_ALWAYS` but docs/20 forbids it under the gameplay root, and `main.tscn` is currently both | author — a real structural contradiction, left unwired."*

This task did **not** settle that author decision. It avoided the conflict entirely for this one assembled scene: a single `SharedAudioDucking` node (`src/audio/audio_ducking.gd`, unmodified) is a sibling of `Main` in `scenes/prototype.tscn` — **never** a child of `Main`, the gameplay root — and two already-existing, plain object references are pointed at it: `ThreatFeedback.set_ducking_node_ref(shared)` (a typed command P2.6 already built for exactly this, its own header naming "if a single global AudioDucking node is later established") and a direct assignment to `AudioPool.ducking_node` (a public, duck-typed `Node` field P1.6 already built, `audio_pool.gd`'s own header: `"duck-typed via has_method so this file does not need to preload it"`). Neither `AudioPool.ducking_node` nor `TowerCuePlayer.ducking_node` requires the ducking node to be its *child*, only reachable — docs/20's "Nothing under the gameplay root may set PROCESS_MODE_ALWAYS" is a rule about what is *parented* there, not about what a node under it may hold a plain reference to.

This is a decision this integration task made for its own scene, named plainly here so the author can override it — it is **not** a resolution of the open NEXT_SESSION.md row, which remains open for any future scene that might place things differently. Verified end to end by `tests/unit/prototype_scene_test.gd::test_shared_audio_ducking_wired_to_both_the_tower_cue_and_the_audio_pool` and `test_nothing_under_main_the_gameplay_root_sets_process_mode_always`.

Also verified as a consequence: `Hud` (which sets itself `PROCESS_MODE_ALWAYS`, by P2.6's own deliberate design) and `UiSfx` (same, this task's own design) are likewise siblings of `Main`, not descendants — `test_the_process_mode_always_nodes_this_scene_needs_exist_outside_main` checks all three by name.

## The assembled scene: `scenes/prototype.tscn`, and why a new scene rather than editing `main.tscn`

A **new** top-level scene, not an edit to `scenes/main.tscn`. Reason, stated plainly: `Hud`, the shared `AudioDucking`, and `UiSfx` all *require* `PROCESS_MODE_ALWAYS` on themselves (two by prior design, one by this task's own), and docs/20 bans exactly that under the gameplay root. Editing `main.tscn` to add them there would have broken `tests/unit/main_scene_structure_test.gd::test_nothing_under_the_gameplay_root_is_process_mode_always` the moment any of the three was added as a descendant, and would have entangled a pure container-contract file with UI/audio process-mode concerns it was never designed to carry. Instead:

```
Prototype (Node2D, script = prototype_integration.gd)
├── Main (instance of scenes/main.tscn, UNMODIFIED)
│   ├── Entities (y_sort_enabled, z=20)  — unchanged container
│   │   ├── TowerSeeker (instance)   — position (220, -160)
│   │   ├── PlayerHunter (instance)  — position (-260, 120)
│   │   └── Opportunist (instance)   — position (0, 320)
│   ├── Projectiles / Pickups / Effects / Audio / SimLoop / EntitySpawner — unchanged
│   ├── Environment
│   │   └── ArenaInstance (instance of scenes/arena.tscn)
│   ├── Tower (instance of scenes/tower.tscn)         — direct child of Main, sibling of Entities
│   └── Player (instance of scenes/player.tscn)       — direct child of Main, position (280, 0)
│       └── GameCamera (Camera2D, script = game_camera.gd, target = "..")
├── Hud (instance of scenes/ui/hud.tscn)                       — sibling of Main
├── ThreatFeedbackLayer (instance of scenes/ui/threat_feedback.tscn) — sibling of Main
├── UiSfx (script = ui_sfx.gd)                                 — sibling of Main
└── SharedAudioDucking (script = audio_ducking.gd)             — sibling of Main
```

`scenes/main.tscn` itself carries zero diff (confirmed by `git status --short` throughout this task). `tests/unit/main_scene_structure_test.gd`, which instantiates `res://scenes/main.tscn` directly, is unaffected by anything in this report and remains part of the 353-case total, passing.

This is the first scene in the repository to instance other scenes as children (every earlier `.tscn` — `arena.tscn`, `tower.tscn`, `player.tscn`, the entity scenes, the UI scenes — is standalone). The composition syntax (`[node name="X" parent="Main/Environment" instance=ExtResource(...)]`, adding new nodes under a path *inside* an already-instanced scene) was verified empirically before being relied on: a throwaway diagnostic test instantiated the scene, printed `Main`'s children, `Entities`' children, the Tower's and Player's `global_position`, and confirmed `Tower.weapon.get_current_target()` already resolved to the real `TowerSeeker` after two physics ticks — before the real test suite was written, so the pattern's correctness rested on an actual headless run, not on inference from the `.tscn` text format alone.

**Positions, not tuned for feel (P2.7 is the author's), chosen only so every wiring claim is verifiable**: Tower at the world origin (`Vector2.ZERO`, preserving F03-05's resolution — P2.2's `arena_center` assumption and P2.4's own un-positioned Tower both already agreed on this; this task changes neither); the Tower Seeker within the Tower's 480 px weapon range so `TowerWeapon`'s **real** `_physics_process` can be proven to acquire it; the Player Hunter and Opportunist placed at plausible but untuned distances. No enemy overlaps the Tower's 106 px footprint.

## LEDGER seams this task closes, named for the orchestrator to fold into `LEDGER.md`

This task cannot write `LEDGER.md` itself (outside its own established write-scope convention — every prior P2.x evidence report defers ledger edits to the orchestrator the same way); the following are offered for that pass:

- **F03-15** (the `tower_seeker` EntityRegistry tag convention): closed in this scene. `tests/unit/prototype_scene_test.gd::test_the_towers_real_targeting_query_finds_the_placed_tower_seeker` drives the **real** `TowerWeapon._physics_process`, not a synthetic query, and confirms it acquires the real, hand-placed `TowerSeeker`.
- **F03-26** (the Tower not in `EntityRegistry`; `set_tower_reference()`/`tower_path` as the workaround): the workaround is exercised for real here — `PrototypeIntegration._wire_enemies()` calls `set_tower_reference()` on all three placed enemies; `test_the_tower_is_wired_to_every_enemy_so_seeker_and_opportunist_can_find_it` confirms it.
- **F03-05** (camera's `arena_center` assumes the Tower sits at the world origin): re-confirmed true in this assembled scene (Tower's `global_position == Vector2.ZERO`), not re-litigated.
- **F03-18** (Tower damage cue was a placeholder tone): the audio half is closed — see "Audio routing" above.

Not closed, out of this task's scope, and not attempted: **F03-06** (`DeathState` broadcasting the player's own death as `enemy_died`), **F03-09**/**F03-22** (SimLoop wiring; immediate hit resolution instead of the hit queue), **F03-17** (the Tower projectile's missing `intersect_ray` sweep) — all four are on the "leave alone" list (`sim_loop.gd`, `event_bus.gd`, `death_state.gd`, `hitbox.gd`, `tower_projectile.gd`) or explicitly named as a separate architectural pass.

## What could not be wired, and why — stated plainly

1. **The three UI cues (`confirm.ogg`, `cancel.ogg`, `cycle.ogg`) have no caller.** `UiSfx` builds the routing mechanism (real streams, `UI` bus, `PROCESS_MODE_ALWAYS`) and nothing more. No menu, Level-Up Draft, or Tower Console exists in this phase (those are Phase 04/05 systems) to call `play_confirm()`/`play_cancel()`/`play_cycle()`. Verified only as "the mechanism exists and resolves to real, non-null streams" (`test_ui_sfx_cues_are_all_non_null_and_route_to_the_ui_bus`), never as "a real UI interaction plays a real cue," because no such interaction exists yet to test.
2. **Player damage has no dedicated retrigger limit** (docs/20's 150 ms figure), unlike the Tower cue's existing 250 ms one. Named above under "Audio routing," not silently omitted.
3. **Pickup textures are not wired.** Named above under "Every asset path wired."
4. **The Tower Console panel** (docs/20 > Scene Tree: a world-space `Node2D` under the gameplay root at `z_index = 38`) does not exist in this phase and is not built here — no Console system exists to give it content.
5. **`entity_hurtbox_hit.ogg`-style per-faction distinction** was not built: `enemy_hit.ogg` plays for all three intents alike (Tower Seeker, Player Hunter, Opportunist), since the Register/docs/09 name no per-intent hit-cue distinction and none was asked for.

## Verification: `tests/unit/prototype_scene_test.gd`

Instantiates `res://scenes/prototype.tscn` and asserts every wiring claim above, headlessly, in place of the feel check this task cannot run (`run_project`/`game_*` are sandbox-only by author decision; the feel check itself is the author's). 30 test cases, organised by the task's own checklist:

- **Node presence** (1 test): every required node resolves to the right class, and each enemy's `current_intent` matches its scene.
- **Container layout intact** (3 tests): the six named containers plus `SimLoop`/`EntitySpawner` are present on the instanced `Main`; `Entities` alone is y-sorted; nothing under `Main` sets `PROCESS_MODE_ALWAYS`.
- **The `PROCESS_MODE_ALWAYS` nodes this scene *does* need** (1 test): `Hud`, `SharedAudioDucking`, `UiSfx` are `PROCESS_MODE_ALWAYS` and are siblings of `Main`, not descendants.
- **Player outside `Entities`, correct z_index** (2 tests).
- **Every z_index matching the Register, measured as the EFFECTIVE (accumulated) value, not the bare property** (6 tests: environment/floor, enemies, Tower, telegraphs, and two real-fired-projectile checks) — see "A real defect this task found."
- **Enemy registration and the Tower's real targeting query** (4 tests): tag membership per enemy; the Tower's own `_physics_process` acquiring the real Seeker; every enemy's `set_tower_reference()` wiring.
- **Every wired texture/audio stream resolves to a non-null resource loaded from the expected on-disk path** (12 tests), including two that drive a real fired projectile and inspect its actual attached `Sprite2D.texture`, not just the exported field.
- **The Tower cue** (3 tests): the real asset (not `AudioStreamWAV`, i.e. not the placeholder), the `TowerCuePlayer`'s bus and the `TowerCue → SFX_Priority` send, and the shared ducking wiring.

### Commands and results

```
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"D:\godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/prototype_scene_test.gd --ignoreHeadlessMode
```
Final (post-falsification, restored) result: **30 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans, exit 0.**

### Falsification log (three mutations, all against real source/scene files, none against the test)

Per this task's own instruction, "scenario variation is not falsification" — every mutation below breaks a real mechanism, not a test parameter.

**1. A real, broken asset path.** `scenes/tower.tscn`'s `platform_texture` ext_resource path mutated to a nonexistent file (`tower_platform_WRONG.png`). Re-imported, re-ran: `test_tower_visuals_stage_and_platform_textures_are_all_non_null` **FAILED** — `TowerVisuals.platform_texture is null — broken resource path` (Godot loaded a null texture silently and continued, exactly as this task's brief warned). Restored from a pre-mutation backup; `diff` confirmed byte-identical; `git diff -- scenes/tower.tscn` captured **before** the mutation and again **after** restoration were compared and are identical (this file already carried this task's own legitimate uncommitted changes, so a raw "`git diff` is empty" check would not have been meaningful here — the correct check, and the one performed, is that the diff against HEAD is unchanged by the mutate/restore cycle). Re-imported, re-ran: 30/30 green, exit 0.

**2. One tag registration.** `src/enemy/enemy_controller.gd`'s `_register_with_entity_registry()` mutated (`if false and current_intent == ... TowerSeeker:`) so a Tower Seeker never receives the `tower_seeker` tag. Re-ran: `test_only_the_tower_seeker_carries_the_tower_seeker_tag` **FAILED** (`Expecting contains elements: [&"tower_seeker"] ... could not find`). This file is untracked (P2.5's own new file, never committed), so `git diff` shows nothing for it either before or after, matching the same precedent P2.3's own evidence report already recorded for its own untracked files ("`diff` against a saved copy is the equivalent check"); restored from a pre-mutation backup, `diff` confirmed byte-identical. Re-ran: 30/30 green, exit 0.

**3. The `z_as_relative` fix itself, falsified separately from (1) and (2)** — see "A real defect this task found" above for the full account. `scenes/player.tscn`'s `Projectiles.z_as_relative = false` line temporarily deleted; re-ran: `test_player_projectile_effective_z_index_is_30_not_accumulated` **FAILED** with `Expecting: 30, but was: 80` — the precise value the accumulation arithmetic predicts, not merely "some wrong number." Restored; `diff` confirmed byte-identical; `git diff -- scenes/player.tscn` before/after compared and matched (17 insertions, this task's own legitimate diff, unchanged by the cycle). Re-ran: 30/30 green, exit 0.

All three mutations were run through the identical cycle: mutate → `--import` → run the suite → confirm the **specific, predicted** failure → restore from a pre-mutation backup → confirm byte-identical restoration → re-run green.

## Full-suite result, banned-API check, and the 323 baseline

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit
```
**Exit 0.** `PASS (exit 0): 353 test case(s) executed under res://tests/unit, all passed.` `Overall Summary: 353 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans.` **353 = the 323 baseline this task was told not to regress, plus this task's own 30.** No `ENGINE ERRORS:` block was printed — Guard 4 (F02-14) scanned the whole run and found nothing. Run three times across this task (once before any change, once after all wiring, once after the final falsification restoration); all three matched.

```
bash tools/checks/banned_api_check.sh
```
`Banned-API check: PASS (0 banned calls under src scenes, excluding ui/ directories)`. **Exit 0**, checked directly via `$?`, never piped into a pager (the exact mistake this project's own LEDGER already records twice).

## Escalations

None new. Every number this task's own wiring depended on (draw-order z_index bands, the Tower evolution thresholds, the Buses row, the retrigger-limit figures) was already Register-cited by an earlier task and is cited again here only by reference, never restated as an independent literal this task invented.

## Contradictions and interpretations named, not silently resolved

1. **The AudioDucking placement** — see "Audio routing" above in full. Named as this task's own scene-scoped choice, not a resolution of the open author decision.
2. **`docs/25_Asset_Pipeline.md`** already described this wiring as complete before this task began (it was modified in an earlier pass this session, per the phase's own EXECUTION_LOG, "Assets" entries) — this task's own work now makes that description accurate rather than aspirational. No further edit to that document was made; its content already matches what is now actually wired.
3. **`enemy_hit.ogg` plays for every intent alike** — named under "What could not be wired," item 5, as an interpretation (no per-intent distinction exists in the Register or docs/09), not a silent gap.

## Never stated as passed, satisfied, or ready

Every result above is reported as an exit code, a test-case count, and a falsification outcome. This report does not assert that the integration suite, the banned-API check, `run_tests.ps1`, the feel check, or any project gate is passed, satisfied, or ready — that determination belongs to the reviewers and the author. In particular: this report cannot and does not claim the prototype **feels** right to play; it claims only that the scene assembles correctly, every named wiring resolves to a real resource, and the seams six prior tasks each left open for "whichever future task next owns this" are now closed and independently verified.

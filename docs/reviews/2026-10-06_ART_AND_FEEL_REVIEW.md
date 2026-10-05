# Art Consistency and Game-Feel Review (2026-10-06)

Reviewer role: art director and game-feel engineer. This is a review only. No project file was changed.
Build reviewed: `main` at 72a33b1 (v0.2.0), Godot 4.7.1, GTX 1650 Ti, **144 Hz monitor** (the probe read `DisplayServer.screen_get_refresh_rate() = 144`).
Author's brief: "make the art style more consistent ... feels a bit janky make that feel smooth".

## Verdict

**The jank has one main measurable cause, and it is not the art.** Every mover (player, enemies, projectiles, pickups) steps at the 60 Hz physics tick, and physics interpolation is off. The camera follows in `_process` at the monitor's rate and estimates velocity by finite difference from the stepped player. On a 144 Hz display this makes **the whole world lurch forward and then drift backward on 58% of frames** while the player walks in a straight line. At 60 Hz the same walk is perfectly smooth, which is why it never showed up in 60 fps captures or tests. Two smaller animation faults add to it: enemies flicker their facing, and the archer "skates" in shoot poses while running.

**The art inconsistency comes from three sources:**
1. **Mixed pixel density.** World sprites are drawn at 0.6, 0.75, 0.85, 1.0, 1.0-1.15 (random), 1.5 and 1.4x1.15 scale, all with nearest filtering. So a Tiny Swords pixel is a different size on almost every object, and down-scaled sprites lose rows of outline.
2. **Procedural vector shapes next to tile art.** Sand paths, ponds, plateaus, telegraph rings, Draft glyphs, HP bars and soft shadows are smooth geometry with a 5 px ink line or a gradient. The pack's look is a scalloped 2-texel ink edge with flat colour and hard shadows.
3. **Filtering and text.** The project default texture filter is still **Linear**, so every Control, including all of the pack's UI 9-slices, blurs at any window size other than 1920x1080. The pixel font is imported anti-aliased, with hinting and subpixel positioning on, and it is used at off-grid sizes.

The pack itself is used correctly where it is used: units, tower, trees, deco, UI frames. Almost everything that looks wrong is project-made geometry or scaling. Fixing the feel needs only settings and code (no new art). Most of the consistency work can be done with pack art the project already has (Tilemap_Flat, the vertical bridge piece, Shadows.png, UI/Icons). Three items would need new art; they are flagged below.

---

## 1. Measured evidence: the jank

### 1.1 Method

`sandbox/art_probe/probe.gd` is a throwaway file and gitignored. It instantiates `scenes/prototype.tscn`, holds `move_right` from frame 120, and on every rendered frame (at the highest `process_priority`) logs the following:
- `Engine.get_physics_frames()`
- delta
- `Main/Player.global_position`
- `GameCamera.global_position`
- the player's resulting screen x

`sandbox/art_probe/probe2.gd` counts enemy `flip_h` changes and the player's animation names over 1200 frames. To analyse the logs, run `python sandbox/art_probe/an.py`.

| Run | Physics ticks per rendered frame | Camera Δx per frame | Frames where the camera (and so the whole world on screen) moves **backward** | Player screen-x frame-to-frame |
|---|---|---|---|---|
| 60 fps cap (`Engine.max_fps=60`) | always 1 | 5.33 to 5.37, sd 0.006 | 0 of 99 | 0.27 px total range (smooth) |
| 144 fps, V-Sync on (default, author's setup) | 0 on 140 frames, 1 on 100 frames | **-0.64 to +6.22, sd 3.36** | **140 of 240 (58%)** | 0.72 px mean, 0.89 px max (rocking) |
| 144 fps, V-Sync off | identical to the row above | identical | 140 of 240 | identical |

The raw cadence at 144 Hz (from `log144.csv`) is below. The world on screen goes +6.2, -0.6, -0.6, +6.2, -0.6, ... That pattern is visible judder, not just "low fps". Note that cx goes backwards on frames 269-270:
```
frame phys  player.x  camera.x
268   129   600.445   612.218
269   129   600.445   611.582   <- no physics tick: player frozen, camera eases BACK
270   129   600.445   610.980
271   130   605.778   617.183   <- tick: player jumps 5.33 px, camera jumps +6.2
```

### 1.2 Jank table

| # | Symptom | Measured evidence | Root cause | Fix (exact) |
|---|---|---|---|---|
| J1 | The world stutters and judders while moving on any display that is not 60 Hz (144 Hz here; also 90/120 Hz phones) | Table above: 58% of frames move backward; the player steps on 100 of 240 frames and holds still on 140 | `project.godot` has no `physics/common/physics_interpolation` (default **off**) and no `physics_ticks_per_second` (60). Every mover runs in `_physics_process`: SimLoop steps 2-5 (`src/core/sim_loop.gd:179`), `player.gd:281`, `enemy_controller.gd:540`, `player_projectile.gd:263`, `tower_projectile.gd:195`, `pickup.gd:114`. So positions change only on ticks | Add to `project.godot`: `[physics] common/physics_interpolation=true` and `common/physics_jitter_fix=0.0` (Godot's guidance when interpolation is on). Do not raise the tick rate instead: it costs CPU on phones and still beats against 144 Hz |
| J2 | The camera "breathes" backward between ticks, and the camera lead differs per monitor | Lead alternates 0 px and the 120 px cap on alternate frames at 144 Hz. The mean lead is 50 px against the intended 80 px at 60 Hz | `src/camera/game_camera.gd:96-114`: in `_process`, `velocity_estimate = (target_pos - _previous_target_position) / delta`. This reads 0 on tick-less frames and 2.4x the real speed on tick frames. Also, `scenes/prototype.tscn:40` parents `GameCamera` **under `Main/Player`**, so the camera's local transform is re-derived from a parent that moves on a different clock | (a) Move the `GameCamera` node to be a sibling under `Main` and keep `target = NodePath("../Player")`. (b) In `_ready()`, set `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF`, because the camera is driven per render frame. (c) Read the position as `target.get_global_transform_interpolated().origin`, not `global_position`. (d) Take the lead from `(target as CharacterBody2D).velocity`, not a finite difference. Then rerun the probe and require camera Δx sd < 0.1 and 0 backward frames at 144 Hz. Note: the D122 camera-follow test and the `--player_pos` harness path both assume the current node path, so update them in the same change |
| J3 | After J1 lands, anything moved in `_process` or by a tween will stutter or smear, and pooled enemies will streak in from where they died | Code read (follows from Godot's interpolation contract) | Interpolated nodes must be moved only in physics. Render-driven moves today include: `pickup.gd:128` (sprite bob), `telegraph_visual.gd:84` (scale pulse), `sheep_flock.gd:128`, `damage_number_fx.gd:117-120` (tween on `global_position`), `enemy_animator.gd:276` (squash tween), `player_animator.gd:216/226` (scale and lean), `tower_visuals.gd:195`, health and overhead bars. Pool teleports happen at `wave_director.gd:1202` and `:1479` | Set `physics_interpolation_mode = OFF` on purely cosmetic children (bob sprite, damage label, telegraph, sheep, bars), or give their tweens `set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)`. Call `reset_physics_interpolation()` straight after every pool spawn or teleport: the two `wave_director` lines, plus wherever pickups, projectiles and the Draft-pause resume set positions |
| J4 | Enemies flicker left and right while walking | `probe2`, holding right for 1200 frames: **119 enemy flips, and 114 of them (96%) came within 10 frames of the previous flip on the same sprite**. About 1 flicker per enemy per second | `src/enemy/enemy_animator.gd:185-190` flips whenever `abs(facing.x) > 0.05`. Separation steering makes near-vertical walkers cross that threshold continually | Add hysteresis. Flip only when `abs(v.x) > 0.35 * v.length()` and at least 0.2 s have passed since the last flip. Keep the facing during strikes (already partly done). Target: rapid flips under 5% in probe2 |
| J5 | The archer skates: he runs right while showing upward shooting frames, and faces the target, not the direction of travel | `probe2`, holding right: **707 of 1199 frames (59%) show `shoot_*`**, including `shoot_up` 366 times, while the player is running. Only 492 frames show `run` | `player_animator.gd:240-241` suppresses idle/run until `_shoot_hold_until_sim_time`. `play_shoot()` (`:299`) sets that to `now + fire_interval`, so the hold is continuous whenever a target exists. It also sets `_facing_flip_h` from the aim (`:287`) | While moving (speed ratio above the threshold), keep `run` facing the direction of travel. The bow still fires; the arrow and the SFX carry the feedback. Play `shoot_*` only when standing still, or for a short release window (≤ 0.25 s) and not the whole interval. The pack has no run-and-shoot frames, so frames that combine both would be **new art** |
| J6 | The player sprite wobbles and its pixels crawl | Code read; also visible as uneven pixel columns in `crop_player.png` | `player_animator.gd:216` applies non-uniform squash/stretch (±14%), and `:226` rotates the sprite (lean up to 0.12 rad) every tick on nearest-filtered pixel art. Rotating or non-uniformly scaling pixel art re-samples the grid every frame | Remove the rotation lean. Limit squash to the hit reaction, at most 2 frames, or drop it. Pixel-art convention is to convey motion through frames, not transforms. `enemy_animator.gd:95` hit squash (1.18/0.82) can stay because it is short, but it is the same problem |
| J7 | Bobs and pulses step at 60 Hz even after J1 | Code read | `pickup.gd:133`, `player_animator.gd:173` and `telegraph_visual.gd:88` read `SimClock.now`, which only advances in physics ticks | For cosmetics, use a render-time clock (`Time.get_ticks_msec()`, or a local accumulator of `_process` delta that respects pause) |
| J8 | Screen shake is a high-frequency buzz at 144 Hz and softer at 60 Hz | Code read | `game_camera.gd:154`: a fresh `randf_range` offset every render frame | Sample `FastNoiseLite` by time (for example 25 Hz), scaled by `trauma²` |
| J9 | Pickups and the Draft close with hard cuts | Code read | `pickup.gd:175-199` toggles `visible` with no fade or scale. On collection the pickup simply disappears. `draft_controller.gd:1195` sets `_root.visible = false`, with no exit tween (the open already staggers in). `pause_menu.gd` has no tweens, though `menu_frame.gd:211` fades its card in | Pickup: on collection, scale 1 → 0.6 and fade over 0.08 s toward the collector. Draft: before hiding, fade the dim and cards out over `MOTION_FAST`. Low priority next to J1-J6 |

UI motion is otherwise in reasonable shape. Card stagger and lift, announcer fades, the menu card scale-in and the HUD value punch all exist. The jank the author feels is J1, J2, J4 and J5.

---

## 2. Settings audit

| Setting | Current | Recommended | Why |
|---|---|---|---|
| `physics/common/physics_interpolation` | unset (off) | **true** | J1 |
| `physics/common/physics_jitter_fix` | unset (0.5) | 0.0 | Godot's recommendation once interpolation is on |
| `physics/common/physics_ticks_per_second` | unset (60) | keep 60 | Interpolation solves smoothness without the CPU cost on phones |
| `rendering/textures/canvas_textures/default_texture_filter` | unset (**Linear**) | **0 (Nearest)** | 205 imported textures are lossless with no mipmaps (good), but every `Control`, `StyleBoxTexture` and Label falls back to Linear. In the 1280x720 capture (`crop720_hud.png`) the carved-wood HUD frame is visibly smeared. In code, about 30 `texture_filter = NEAREST` lines patch this node by node. One project setting replaces them and stops a new node regressing |
| `rendering/2d/snap/snap_2d_transforms_to_pixel` / `..._vertices_to_pixel` | off | **leave off** | With a smoothly following camera, snapping brings back stepping. Fix pixel crawl through uniform scale (A1) instead |
| `display/window/stretch/mode` | `canvas_items` | Author decision, see Q1 | At 1920x1080 everything is 1:1 and crisp. At 1280x720 the world is drawn at 0.667 times the sprite scale, for example 0.567 texels per pixel for the player, and nearest filtering drops whole outline rows (`crop720_player.png`) |
| `display/window/stretch/aspect` | unset (`keep`) | `expand`, for Android | 19.5:9 phones letterbox under `keep`. Expanding requires `game_camera.gd`'s clamp to use the live visible size, not the hardcoded `VIEWPORT_REFERENCE_SIZE` (`:52`, `:189-192`) |
| V-Sync / `max_fps` | V-Sync on (via Settings), uncapped | keep | J1 fixes the cadence. Do not cap at 60 as a workaround |
| Renderer | `Forward Plus` | Android: add `rendering/renderer/rendering_method.mobile="gl_compatibility"` | This is a pure 2D game. Compatibility gives the widest device support and the lowest overhead |
| Texture import | `compress/mode=0` (lossless), no mipmaps | keep for pixel art. For Android, enable `rendering/textures/vram_compression/import_etc2_astc=true` only if 3D or large non-pixel textures are added | Lossy VRAM compression would wreck the pixel art |
| Font import, `Jersey10-Regular.ttf.import` | `antialiasing=1`, `hinting=3`, `subpixel_positioning=4` | `antialiasing=0`, `hinting=0`, `subpixel_positioning=0` | The card crop (`crop_card.png`) shows grey AA halos on a pixel font: smooth type inside pixel art |
| Font sizes, `ui_palette.gd:180-184` | 20 / **26** / 30 / 40 / **68** | multiples of the font's pixel grid, for example 20 / 30 / 40 / 60 or 70 | Jersey 10's design grid appears to be 10 px per em. Verify by rendering, not from this table. Off-grid sizes (26, 68) give uneven stroke widths |

---

## 3. Art inventory: every visible element

"Texel scale" means screen pixels per source-art pixel at 1920x1080 with camera zoom 1.0. Zoom is never changed at runtime: `set_view_scale` has no callers.

| Element | Source | Texel scale | Consistent? | Why | Fix |
|---|---|---|---|---|---|
| Grass ground | `Derived/grass_fill_tile.png`, tiled | 1.0 | **Yes** | Authentic pack texture. The camouflage pattern is how this CC0 edition looks | none |
| Sand paths and Tower plaza | `sand_network.gd`: Polygon2D with tiled sand, plus a Line2D outline | fill 1.0 | **No** | A smooth vector outline, `outline_width_px = 5.0` (`:52`), about 2.5x the pack's 2-texel ink. No scallop: the pack's sand edge (Tilemap_Flat rows 0-3, cols 5-8) is a bumpy ink border. Curved ribbons and sharp notches where the merged polygons meet (plaza/path junction, visible in `run_60.png` near 1000,410) | **Best (M-L):** paint the plaza and paths on a `TileMapLayer` using Tilemap_Flat's sand set as a "Match Sides" terrain. Paths become axis-aligned, L-shaped runs at 64 px. That is the pack's own look, and the stair-step complaint that led to the vector version came from tile-stamping *diagonals*. **Cheaper interim (S-M):** replace the Line2D with a textured Line2D (`texture_mode = LINE_TEXTURE_TILE`, width 16, nearest), using a 64x16 strip cut from the scalloped top edge of the sand tile. This gives the pack's edge on curves. Either way, set the width to the pack's 2 texels if any plain line remains |
| Ponds | `pond_field.gd`: Polygon2D water, a sand ring, `_add_outline` 5 px ink (`:308-314`), a pale surf Line2D and a 3 px water edge | 1.0 | **No** | Same vector-line problem. Ink 5 px. The surf ring is a flat Line2D, not the pack's animated foam (`crop_pond.png`) | Same as the paths: water underneath, ground tiles with a hole, and Foam.png AnimatedSprites on the edge cells. That is the pack's convention. The coastal `foam_ring.gd` already does this correctly |
| Coast (island edge) | `ground_detail.gd` sand plus `foam_ring.gd` foam | 1.0 | **Mostly** | Tile-based and close to the pack. `foam_ring.gd:67-71` also adds a Line2D | Drop the Line2D |
| Raised plateaus | `elevation_plateau.gd`: tile top plus `Derived/cliff_face_tile`, Line2D outline width 5 (`:160-167`), scaled shadow (`:348`, non-uniform `x, 0.4`) | 1.0, shadow stretched | **Partly** | The cliff faces come from the pack, but the outline is vector and the shadow is squashed | Use Tilemap_Elevation through a TileMapLayer (cliff rows) and the pack's `Shadows.png` at 1.0. Remove the Line2D |
| Bridge | `scenes/arena.tscn:384-392`: horizontal plank sprite **rotated 90°** and scaled **1.4 x 1.15** | 1.4 / 1.15 | **No** | The light now comes from the wrong side. Pixels are non-square and uneven. The pack already contains a **vertical** bridge piece (Bridge_All.png left column, about x0-64, y80-250) | Use the vertical piece's region at scale 1, rotation 0. Tile its middle segment to length |
| Tower (stages 0-2) | `Derived/tower_stage*`, `tower_visuals.gd:139` `TOWER_FAMILY_SCALE = 1.5` | **1.5** | **No** | The only object whose pixels are larger than the player's. Nearest filtering at 1.5 gives alternating 1 px and 2 px columns (`crop_tower.png`) | Scale 1.0 (or exactly 2.0). If the Tower must look big early, start at the Castle family, which is 1.0 already. Design implication: the Tower looks smaller at stage 0 |
| Tower ground shadow | `assets/sprites/tower/tower_ground_shadow.png` (300x130, project-made) | stretched | **No** | Blurred radial gradient. Pack shadows are hard-edged flat blobs | Use the pack's `Terrain/Ground/Shadows.png` |
| Unit shadows | `assets/sprites/soft_shadow.png` (64x28, project-made) | various | **No** | Same soft gradient | Use `Shadows.png`, or a 2-tone hard ellipse at 1.0 |
| Player (blue archer) | `Archer_Blue.png` via `player_archer.tres`, `scenes/player.tscn:64` `scale = 0.85` | **0.85** | **No** | Down-scaling with nearest drops about 1 pixel row in 7, giving uneven outline thickness. Rotation lean and squash on top (J6) | 1.0 |
| Goblins (3 intents) | Torch/TNT/Barrel sheets, `scale = 0.75` (`opportunist.tscn:82`, `player_hunter.tscn:85`, `tower_seeker.tscn:83`) | **0.75** | **No** | Drops 1 row in 4. In `crop_fight.png` the goblin outlines run 2-3 px wide and break up | 1.0. Design implication: goblins about 33% larger on screen; check crowding and hit-box readability. If that is not acceptable, the consistent alternative is **one** scale for all world art, terrain included (for example everything at 0.75 with zoom 1). Today's mix is the problem, not the size |
| Trees | `tree_grove.gd:202` random **0.85-1.15** | random | **No** | Every tree has a different pixel size, so neighbouring trees visibly differ in pixel grain | 1.0. Vary with `flip_h` and animation offset instead |
| Rocks, bushes, deco, mushrooms | `scenery_scatter.gd:177` random `min_scale`..`max_scale` | random | **No** | Same as trees | 1.0 |
| Sheep, gold mine, houses, goblin camp | pack sheets | 1.0 | **Yes** | | none |
| Arrows (player and Tower) | `Arrow.png`, `PROJECTILE_ART_SCALE = 0.6` (`player_projectile.gd:138`, `tower_projectile.gd:84`); trail at 0.45 | 0.6 / 0.45 | **No** | Very small, uneven pixels, and the trail is coarser than the arrow | 1.0. If a trail is needed, use a faded copy at the same scale |
| Gold / Scrap pickup | `G_Idle_NoShadow` plus `G_Spawn` | 1.0 | **Yes** | | none |
| XP crystal | `assets/sprites/pickup_xp_crystal.png` (project-made, 128x128, drawn on a ~4-texel grid) | about 4x the pack's grain | **No** | Fat pixels next to fine pack pixels. Purple outside the pack palette (D129 chose purple on purpose for XP) | Redraw at 1-texel grain, about 24-32 px. Or recolour a pack resource icon (M_Idle meat / W_Idle wood) at 1.0. **Needs project art (small)** |
| Telegraph "!" | `assets/ui/telegraph_exclaim.png` (100x100, project-made, geometric, black outline), `MARKER_SCALE = 0.55` plus a sine pulse | 0.55, pulsing | **No** | Vector look, off-palette outline, and a non-integer pulsing scale (pixels shimmer) | Redraw a 16-20 px pixel "!" with the pack's ink colour (22,28,46) at 1.0. Pulse by alternating 2 frames or by modulate, not scale. **Needs project art (tiny)** |
| Telegraph ground ring | `telegraph_visual.gd:94-97`: `draw_circle` plus a 3 px `draw_arc`, 32 segments, squashed | n/a | **No** | Smooth AA vector circle under pixel units | Use a pixel-art ellipse texture: 3-4 fill-step frames, ink outline, scale 1.0. The fill can step through frames for progress. **Needs project art (small)**, or reuse the pack's red `Banners` pointer shapes |
| Blood | `blood_fx.gd`: CPUParticles squares at scale 1.2-5.0 (`:157-170`), splats from a 14 px procedural texture at 0.8-2.1 with **random rotation** (`:252-254`) | 1.2-5.0 | **No** | Blocks up to 5x the sprite pixel size, and rotated pixel art (`crop_fight.png`) | Particles at a fixed 2-3 px. Splats at scale 1.0. Vary them with `flip_h`/`flip_v` and 3-4 hand-placed variants, with no rotation |
| Death skull | `Knights/Troops/Dead/Dead.png` (`death_skull.tres`) | 1.0 | **Yes** | | none |
| Fire on a damaged Tower | `Effects/Fire/Fire.png` | 1.0 | **Yes** | | none |
| Enemy health bars, player and Tower overhead bars | `draw_rect` (`enemy_health_bar.gd`, `player_overhead_bar.gd`, `tower_overhead_bar.gd`) | n/a | **Acceptable** | Flat rects with a dark border read fine at 1:1 | Snap sizes and positions to whole pixels. Make the border 2 px ink (22,28,46) instead of black |
| Damage numbers | Label, Jersey10 | n/a | Partly | Anti-aliased font (see settings) | Font import fix |
| Off-screen Tower indicator (black circle, crown, arrow) | `threat_feedback.gd:580-596` `draw_colored_polygon` | n/a | **No** | Smooth vector arrow and disc | Use a pack `UI/Pointers/0N.png` arrow plus the pack's `UI/Icons` tower glyph, rotated to whole multiples of 45° only, or 8 pre-baked directions |
| Edge vignette | `vignette.gdshader`, fullscreen | n/a | Neutral | A smooth gradient, but subtle | Keep, or drop on mobile (fill-rate) |
| HUD frames (HP, Tower, Scrap, XP) | pack `Carved_9Slides`, ribbons | 1.0 at 1080p | **Yes at 1080p, blurred elsewhere** | Linear filtering (settings) | Global Nearest filter |
| HUD bars (HP, XP, Tower) | `StyleBoxFlat` with corner radius (`hud_bar.gd`) | n/a | **No** | Rounded smooth bars inside carved pixel frames (`crop720_hud.png`) | Set `corner_radius = 0` with a 2 px ink border. Or build the bar from a pack 3-slice (Ribbon or Button) tinted |
| HUD glyphs: heart, tower, recycle | `shape_glyph.gd` (29 draw calls) | n/a | **No** | AA vector shapes | Use the pack's `UI/Icons/Regular_0N.png` (30 icons already imported, never used) where one fits. Otherwise 16 px pixel glyphs. **May need project art** for heart and recycle |
| Draft cards | `StyleBoxFlat` parchment `d9c7a0` with a wood border (`ui_palette.gd:119-125`), corner radius, flat colour stripe, triangle/square glyph, grey rank dots | n/a | **No** | The one surface where the pack frame was dropped. The previous tiled swatch showed seams, so it was replaced with a flat box. It reads as a web card next to the carved HUD (`run_2100.png`) | Frame with the pack's `Carved_9Slides` (or `Banner_Vertical`) 9-slice at margin 26. That has no seam, because a 9-slice stretches its centre instead of tiling it. Replace the triangle/square glyphs and rank dots with pack icons or pixel pips. Rarity: use the pack ribbon colours (Blue/Yellow/Red 3-slices) as a header ribbon in place of the thin line |
| Draft hold ring | `draft_fill_ring.gd` `draw_arc` | n/a | No (minor) | Smooth arc | Step it in 8-12 pixel segments, or keep it as the one allowed smooth affordance |
| Banners and announcer ("Wave 1", objective strip) | pack Carved / ribbon | 1.0 | **Yes** | | none |
| Fonts | Jersey10 (pixel) | various | **No** | AA on, hinted, off-grid sizes (settings table) | Import fix plus grid sizes |
| Title / Hub backgrounds | pack textures with NEAREST set per node | 1.0 | Yes at 1080p | Not audited in depth | Covered by the global filter |
| Unused pack art | `UI/Icons` (30), `UI/Pointers` (6), `Terrain/Ground/Shadows.png` (referenced, but only by the plateau), Tilemap_Flat sand terrain, Tilemap_Elevation as a TileSet, Bridge vertical piece, Water Rocks (static per the handoff) | | | | Use as listed above. All of it is already in the repo, under CC0 with provenance |

The Kenney placeholder PNGs (`assets/third_party/kenney/*`) and `assets/sprites/*_silhouette.png` are **not referenced** by any scene or script (grep for `res://assets/...png`). They are not on screen and are out of scope.

---

## 4. Prioritised fix list

| P | Fix | Files | Effort | New art? | Matters for phones? |
|---|---|---|---|---|---|
| **P0** | Turn on physics interpolation (`physics_interpolation=true`, `jitter_fix=0`) | `project.godot` | S | no | **Yes**: 90/120 Hz screens show the same judder |
| **P0** | Camera: un-parent from Player, interpolation mode OFF, follow `get_global_transform_interpolated()`, lead from `velocity` (J2) | `scenes/prototype.tscn:40`, `src/camera/game_camera.gd:96-114`, camera test, harness `--player_pos` path | S-M | no | yes |
| **P0** | `reset_physics_interpolation()` after every pool spawn or teleport. Interpolation OFF, or physics-process tweens, on cosmetic children (J3) | `wave_director.gd:1202,1479`, pickup and projectile spawners, `pickup.gd`, `damage_number_fx.gd`, `telegraph_visual.gd`, `sheep_flock.gd`, bars | M | no | yes |
| **P0** | Verify with `sandbox/art_probe/probe.gd` at 144 fps: 0 backward camera frames, camera Δx sd < 0.1 | sandbox only | S | no | |
| **P1** | Enemy facing hysteresis (J4) | `src/enemy/enemy_animator.gd:185-190` | S | no | |
| **P1** | Archer: run while moving, shoot pose only when still or in a short release window (J5) | `src/player/player_animator.gd:237-299` | S | no (run-and-shoot frames would be new art) | |
| **P1** | Remove the rotation lean and continuous squash on the player (J6) | `player_animator.gd:207-226` | S | no | |
| **P1** | Global Nearest default filter. Remove the per-node patches afterwards (optional) | `project.godot` | S | no | **Yes**: phone resolutions are never exactly 1080p |
| **P1** | Font: AA off, hinting off, subpixel off, grid sizes | `assets/ui/fonts/Jersey10-Regular.ttf.import`, `ui_palette.gd:180-184` | S | no | yes |
| **P1** | One world texel scale: player 0.85 → 1, goblins 0.75 → 1, Tower 1.5 → 1, trees and scatter random → 1, arrows 0.6 → 1, telegraph 0.55 → native, blood ≤ 1, no rotation | `player.tscn:64`, `entities/*.tscn:82-85`, `tower_visuals.gd:139`, `tree_grove.gd:202`, `scenery_scatter.gd:177`, `*_projectile.gd`, `blood_fx.gd:157-170,252-254`, `telegraph_visual.gd:43` | M (plus a playtest for size and readability: this is a design change, so it needs a decision row) | no | yes |
| **P1** | Bridge: vertical pack piece, scale 1, no rotation | `scenes/arena.tscn:384-392` | S | no | |
| **P1** | Path, pond and plateau edges. Interim: textured scalloped Line2D, 2-texel ink. Final: TileMapLayer with Tilemap_Flat sand and Foam (Q2) | `sand_network.gd`, `pond_field.gd`, `elevation_plateau.gd`, `foam_ring.gd` | interim S-M, final L | no | TileMapLayer is cheaper to draw than large Polygon2D plus Line2D |
| **P1** | Hard pack shadows in place of the soft gradients | `soft_shadow.png` and `tower_ground_shadow.png` users → `Shadows.png` | S | no | |
| **P2** | Draft cards on the pack 9-slice, pack icons in place of vector glyphs, ribbon rarity header | `draft_card_view.gd`, `ui_palette.gd:119-125`, `shape_glyph.gd` | M | maybe (heart and recycle icons) | |
| **P2** | HUD bars square with ink border. Off-screen indicator from `UI/Pointers` | `hud_bar.gd`, `threat_feedback.gd:580-596` | S-M | no | |
| **P2** | Redraw the telegraph "!", the ground ring and the XP crystal at 1-texel grain in the pack palette | `assets/ui/telegraph_exclaim.png`, `telegraph_visual.gd:94-97`, `assets/sprites/pickup_xp_crystal.png` | M | **yes, small project art** | |
| **P2** | Cosmetic clock for bobs and pulses (J7). Noise-based shake (J8). Pickup collect tween and Draft exit fade (J9) | as listed | S each | no | |
| **P2** | Android readiness: `stretch/aspect=expand` with a live-size camera clamp, `rendering_method.mobile=gl_compatibility`, test the vignette's fill cost, keep textures lossless | `project.godot`, `game_camera.gd:52,189-192`, a new Android preset | M | no | **Yes** |

The P0 items are about half a day of work in total, and they are what the author will feel. The P1 scale and edge work is what the author will see.

---

## 5. Questions for the author

**Q1. How should the game scale to window sizes other than 1080p (laptops at 1366x768, 1440p monitors, phones)?**
- (A) Keep `canvas_items` and accept uneven pixels away from 1080p. The global Nearest filter still helps.
- (B) **Recommended:** `stretch/mode = viewport` at 1920x1080. The whole frame renders at 1080p and is scaled as one image, so every pixel scales uniformly and 4K is an exact 2x. Small UI text is scaled as an image too, so check legibility at 720p.
- (C) Integer scaling (`stretch/scale_mode = integer`). Perfectly crisp, but windows between sizes get borders.

**Q2. Should paths and ponds stay organic and curved, or follow the pack's tile grid?**
- (A) **Recommended:** follow the grid. Axis-aligned, L-shaped sand paths and ponds built from Tilemap_Flat and Foam give the authentic Tiny Swords look. This reverses the earlier vector-path choice, so it needs a decision row.
- (B) Keep the curves, but give them the textured scalloped edge. This gets most of the way there at lower cost.

**Q3. The single-scale rule makes goblins about 33% larger and the stage-0 Tower about 33% smaller. Which do you prefer?**
- (A) **Recommended:** everything at 1.0, the pack's native size.
- (B) Everything at one smaller scale (for example 0.75), terrain included.
- (C) Keep the current mix and accept the inconsistency.

---

## Artifacts (sandbox, gitignored)
- Probes: `sandbox/art_probe/probe.gd` and `probe.tscn` (camera and player per-frame log), `probe2.gd` (flip and animation counts), `an.py` (analysis), and logs `log60.csv`, `log144.csv`, `logvsync.csv`.
- Captures: `sandbox/captures/art/play_*.png`, `run_*.png`, `p720_400.png`, plus crops `crop_player.png`, `crop_pond.png`, `crop_path.png`, `crop_card.png`, `crop_fight.png`, `crop_tower.png`, `crop720_hud.png`, `crop720_player.png`, and source sheets `src_flat.png`, `src_elev.png`, `src_bridge.png`, `src_madepngs.png`.
- Captures used an isolated profile: `--meta-profile-dir=D:/Gamedev/sandbox/captures/art/meta`.

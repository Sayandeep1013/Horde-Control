# P2.2 Evidence Report — Arena and Camera

## GodotPrompter skills consulted

Both required skills were invoked first, before any file was written, per CLAUDE.md's instruction to subagents.

- **`godot-prompter:camera-system`** — read in full. Used: the "Smooth Follow" manual-lerp pattern (built-in `position_smoothing_enabled` disabled, lead + smoothing computed by hand each frame); the trauma-based screen-shake model (trauma 0..1, decays over time, offset magnitude scales with `trauma^2`); the implementation checklist item "Camera2D limits match level/tilemap bounds so no out-of-world edges are visible."
- **`godot-prompter:2d-essentials`** — read in full. Used: the CanvasLayer/`z_index` draw-order guidance (informed keeping the vignette on its own CanvasLayer rather than mixing it into world z-order); the note that CanvasLayers are for camera-independent overlays, which is exactly what the vignette needs.

**Conflict found and recorded here for the phase LEDGER** (CLAUDE.md: "Where a skill conflicts with docs/20, the Provisional Values Register, or an Author decision, this project wins and the conflict is recorded in the phase LEDGER"):

The camera-system skill's reference screen-shake implementation (`add_trauma()` / `_process()`) writes the shake offset to `Camera2D.offset`. MASTER_SDLC.md's Provisional Values Register > Arena & Camera > **"Lead/shake application"** row is explicit and binding: *"Applied to position before the arena clamp, never via `Camera2D.offset`."* The reason the Register forbids it: `offset` is applied by the engine after any position clamping (built-in `limit_*` or a manual clamp), so an offset-based shake can visibly push the rendered view past the arena walls — precisely the invariant the Camera bounds test exists to check. `src/camera/game_camera.gd` follows the Register: shake is folded into `_follow_position` before `_clamp_to_arena_bounds()` runs, and `offset` is never written anywhere in the file. The skill's trauma-decay and trauma-squared-for-magnitude *shape* is kept; only the output target changed. **This belongs in the Phase 03 LEDGER as a recorded skill-vs-project conflict resolved in the project's favour.**

## Files created (all within this task's write scope)

| Path | Purpose |
| --- | --- |
| `scenes/arena.tscn` | The arena: tiled floor + four boundary walls |
| `src/camera/game_camera.gd` | `GameCamera`, a `Camera2D` subclass: follow, lead, smoothing, shake hook, zoom hook, arena clamp, vignette |
| `src/camera/vignette.gdshader` | Screen-space edge-darkening shader, built and attached procedurally by `GameCamera._setup_vignette()` |
| `src/environment/arena_bounds.gd` | `ArenaBounds`, a small `StaticBody2D` script that sets `collision_layer`/`collision_mask` from `CollisionLayers` |
| `tests/unit/camera_bounds_test.gd` | The named Camera bounds test (P2.2), plus supporting tests |
| `tests/unit/arena_scene_test.gd` | Supplementary structural check of `scenes/arena.tscn` against the Register and docs/20 |

Nothing was written outside this list; `src/player/`, `scenes/player.tscn`, `src/tower/`, `scenes/tower.tscn`, and everything under `src/core/`, `src/combat/`, `src/debug/`, `src/audio/`, `src/data/` were left untouched (confirmed by `git status --short` before finishing — those paths show the other two parallel implementers' own files, none of them touched by this task).

## Scene tree built, against docs/20

docs/20_Technical_Architecture.md's own "Scene Tree" bullet describes the **gameplay root** (`scenes/main.tscn`'s `Entities`/`Projectiles`/`Pickups`/`Effects`/`Environment`/`Audio` containers, the player's fixed `z_index`, and the full draw-order list). `scenes/main.tscn` is explicitly off-limits to this task (owned by P1.3/P2.1's territory), so `scenes/arena.tscn` is built as a **standalone scene**, not wired into `main.tscn`'s `Environment` container — that wiring is a later, out-of-scope step for whichever task assembles the final gameplay root.

```
Arena (Node2D)
├── Floor (Sprite2D, z_index = 0)
└── ArenaBounds (StaticBody2D, script = arena_bounds.gd)
    ├── WallNorth (CollisionShape2D, RectangleShape2D 4928x64)
    ├── WallSouth (CollisionShape2D, RectangleShape2D 4928x64)
    ├── WallWest  (CollisionShape2D, RectangleShape2D 64x3200)
    └── WallEast  (CollisionShape2D, RectangleShape2D 64x3200)
```

- **`Floor`'s `z_index = 0`** matches docs/20 > Scene Tree's draw order: *"environment 0, pickups 10, enemies 20 ..."* — the floor is environment-band content.
- **No interior obstacles**, per the Register's "Arena size" row: only `Floor` and `ArenaBounds` exist under `Arena`; `arena_scene_test.gd`'s `test_arena_bounds_has_exactly_four_wall_shapes_and_no_interior_obstacles` asserts this directly (any other `CollisionObject2D` sibling would fail it).
- **`ArenaBounds`** is a single `StaticBody2D` (docs/20 Collision Layers table row 15: *"ArenaBounds | Arena boundary walls, static body | none"*) with four `CollisionShape2D` children rather than four separate bodies — one layer/mask assignment for the whole boundary, matching the table's "Set on" column (singular: one static body).

## Every Register value cited, by row name

All from MASTER_SDLC.md > Provisional Values Register > **Arena & Camera** (cited, never restated as a bare number anywhere else in the code):

| Register row | Value | Where used |
| --- | --- | --- |
| Arena size | 4800×3200 px, Tower at centre, hard walls on ArenaBounds, no interior obstacles | `GameCamera.ARENA_SIZE`; `scenes/arena.tscn`'s Floor `region_rect` and wall placements |
| View scale | 1.0 = 1920×1080 world px; range 0.9–1.15; `zoom = 1/view_scale` | `GameCamera.VIEWPORT_REFERENCE_SIZE`, `VIEW_SCALE_MIN`, `VIEW_SCALE_MAX`, `set_view_scale()` |
| Camera lead | Velocity × 0.25 s, max 120 px | `GameCamera.CAMERA_LEAD_TIME`, `CAMERA_LEAD_MAX` |
| Position smoothing speed | 8 | `GameCamera.POSITION_SMOOTHING_SPEED` |
| Screen shake | Max 12 px, decaying over 0.25 s | `GameCamera.SCREEN_SHAKE_MAX`, `SCREEN_SHAKE_DECAY_TIME` |
| Lead/shake application | Applied to position before the arena clamp, never via `Camera2D.offset` | `_process()`'s ordering: lead → smoothing → shake → `_clamp_to_arena_bounds()`; `offset` is never assigned anywhere in the file |
| Zoom ease | 0.4 s | `GameCamera.ZOOM_EASE_TIME`, used by `set_view_scale(..., animate=true)`'s `Tween` |
| Arena-to-view ratio | Arena ≥ 1.4× largest view per axis (2.2×, 2.6×) | Verified arithmetically below; not asserted by a test since it is a property of the Register's own numbers, not of this task's code |

Rows explicitly **not implemented** by this task (see "Scope boundaries" below): Zoom trigger 1.15, Zoom 0.9 (corridor trigger), Prototype zoom scope.

**Arena-to-view ratio check** (sanity, not a Register violation to restate the arithmetic once): at view_scale 1.15, visible width = 1920×1.15 = 2208 px, visible height = 1080×1.15 = 1242 px. Arena width 4800 / 2208 ≈ 2.174 (Register says 2.2×); arena height 3200 / 1242 ≈ 2.577 (Register says 2.6×). Both match the Register's own stated ratios, confirming the `zoom = 1/view_scale` reading is the one the Register's own numbers were derived from — this is presented as a consistency check on the interpretation, not as new evidence.

## Camera clamp maths

`GameCamera._clamp_to_arena_bounds(pos: Vector2) -> Vector2`, the single point where the bounds invariant is enforced:

```
half_extent = get_visible_world_size() / 2      # (VIEWPORT_REFERENCE_SIZE / zoom) / 2
arena_min   = arena_center - ARENA_SIZE / 2
arena_max   = arena_center + ARENA_SIZE / 2
clamped.x   = clamp(pos.x, arena_min.x + half_extent.x, arena_max.x - half_extent.x)
clamped.y   = clamp(pos.y, arena_min.y + half_extent.y, arena_max.y - half_extent.y)
```

This runs after lead, smoothing, and shake have all been folded into the position (Register's "Lead/shake application" row), so the clamp is the *last* step before `global_position` is assigned — no later step (there is none; `offset` is never touched) can push the rendered view outside it.

Two interpretations/decisions named rather than silently made:

1. **Deterministic reference size, not the live viewport.** The clamp uses the constant `VIEWPORT_REFERENCE_SIZE = Vector2(1920, 1080)` from the Register's own "View scale" row text, not `get_viewport_rect().size`. This was deliberate: Godot's own built-in `Camera2D.limit_left/right/top/bottom` clamp against the *live* viewport rect, which gdUnit4's `--headless` runner is not guaranteed to report as exactly 1920×1080. Using the Register's stated reference keeps the clamp — and the acceptance test's sweep — a pure, deterministic function of `view_scale` alone. This is why the code does **not** use Godot's built-in camera limits at all.
2. **Tower-at-centre read as world origin.** "Arena size" row says "Tower at centre." P2.4 (Tower) is a parallel task this implementer cannot touch or read the current state of beyond what's on disk, and had not placed `scenes/tower.tscn` at any confirmed coordinate as of this task's work. `arena_center` defaults to `Vector2.ZERO` and `scenes/arena.tscn`'s `Floor`/`ArenaBounds` are both built around that same origin (arena spans x ∈ [-2400, 2400], y ∈ [-1600, 1600]). `arena_center` is an `@export`, so this is a one-line fix if the Tower ends up placed anywhere else. **Named as an open cross-task assumption, not resolved unilaterally.**

Degenerate-axis fallback (view wider than the arena on one axis) centres the camera on `arena_center` for that axis rather than producing an inverted clamp range. The Register's own "Arena-to-view ratio" row guarantees this never triggers inside [0.9, 1.15], so it is defensive code, exercised only by `test_view_wider_than_arena_on_an_axis_centres_rather_than_errors`, and explicitly commented in the source as out of the Register's tested range.

## Scope boundaries named rather than silently crossed

- **Zoom triggers not wired.** `set_view_scale()` is the hook; nothing in this file decides *when* to call it. The Register's "Zoom trigger 1.15" (player speed > 1.5× base, or Tower losing ≥10% max health within 2 s) and "Zoom 0.9 (corridor trigger)" rows depend on the player's speed state (P2.1) and the Tower's health/shield events (P2.4), neither built yet and neither owned by this task. This task's own directive text ("Make it genuinely nice to look at... a screen-shake hook other systems can call later") named a shake hook explicitly but did not ask for the trigger wiring; PLAN.md's higher-level "zoom rules" input line is read as satisfied by providing the hook, not the trigger logic, given the cross-task dependency.
- **Vignette skipped under `--headless`.** `_setup_vignette()` returns immediately when `DisplayServer.get_name() == "headless"`. Compiling a canvas_item shader with no rendering device backing a headless display server is a real risk of exactly the class of hidden engine error LEDGER F02-14 exists to catch; the vignette is purely cosmetic, so skipping it under `--headless` costs nothing either acceptance test can see. Confirmed empirically: 0 engine error lines across every full-suite run in this report (see below).
- **Vignette `CanvasLayer.layer` picked without a real HUD to check against.** P2.6 (HUD) is not built yet and this task cannot know what CanvasLayer number it will use. `layer = 4` is a named guess, flagged in the code's own comment for whoever builds the HUD to revisit.

## Acceptance test — Camera bounds test

**Named test**: `tests/unit/camera_bounds_test.gd`. Sweeps `GameCamera` to all four corners and four edge midpoints of the arena at six view scales spanning the Register's full [0.9, 1.15] range (0.9, 0.95, 1.0, 1.05, 1.1, 1.15), using `snap_to()` (which runs the identical `_clamp_to_arena_bounds()` path `_process()` uses, just without waiting on smoothing) so each position is genuinely clamped, not merely computed once and trusted.

Also added: `tests/unit/arena_scene_test.gd`, a supplementary structural check of `scenes/arena.tscn` itself (floor region size/repeat, wall layer/mask, wall placement flush with the Register's boundary, no interior obstacles) — this project's carried lesson (F02-02, F02-16: a named acceptance test has repeatedly been found unable to catch the defect class it exists for) made a scene-level check worth adding alongside the camera-math check, since a wall placed at the wrong coordinate in the `.tscn` would not be caught by `camera_bounds_test.gd` at all — that suite only exercises `GameCamera`'s own constants, never reads the scene file.

### Command and exit codes

```
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
D:\godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
```

Final clean run (after all falsification mutations were reverted): **exit 0**, `Overall Summary: 182 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, `Executed test suites: (24/24)`, `Executed test cases: (182/182)`.

**New test total: 182** (172 pre-existing, per this task's brief, + 10 new: 6 in `camera_bounds_test.gd`, 4 in `arena_scene_test.gd`). No pre-existing test was modified; all 172 prior tests still pass.

`camera_bounds_test.gd`'s 6 tests:
1. `test_visible_rect_stays_within_arena_bounds_across_the_full_view_scale_range` — the named sweep, 6 scales × 8 positions = 48 corner/edge checks.
2. `test_camera_centred_at_arena_centre_stays_within_bounds` — near-boundary sanity at arena centre.
3. `test_visible_rect_respects_a_non_zero_arena_center` — see "A blind spot found and closed" below.
4. `test_view_scale_is_clamped_to_the_register_range` — `set_view_scale()` itself clamps to [0.9, 1.15].
5. `test_max_trauma_shake_never_pushes_the_visible_rect_past_arena_bounds` — 50 trials of max trauma near a corner at the widest valid view (1.15); shake's random direction cannot defeat the clamp.
6. `test_view_wider_than_arena_on_an_axis_centres_rather_than_errors` — degenerate-axis fallback does not NaN or crash.

### A blind spot found and closed, not silently avoided

While drafting Mutation 3 (below), this implementer noticed that **the original test suite could not have caught a bug that ignores `arena_center`'s offset**, because every test used the default `arena_center = Vector2.ZERO` — a clamp that forgets to add the offset is indistinguishable from a correct one when the offset is zero. This mirrors this project's recurring pattern (F02-02, F02-09/10, F02-16: a test that cannot fail its own defect class). Rather than run the mutation against a blind test and report a false "caught it," the suite was strengthened first: `test_visible_rect_respects_a_non_zero_arena_center` sets `arena_center = Vector2(500, -300)` and re-sweeps. This is why the final total is 182 (6 camera tests), not 181 (5) — the extra test is load-bearing for Mutation 3 below, not incidental.

### Falsification log

All three required mutations were applied to `src/camera/game_camera.gd`, one at a time, each followed by a restore-and-reimport before the next. Backups were kept in the session scratchpad (outside the repository) for diffing, not committed.

**Mutation 1 — remove the clamp entirely** (`_clamp_to_arena_bounds` returns `pos` unmodified):
`res://tests/unit/camera_bounds_test.gd > test_visible_rect_stays_within_arena_bounds_across_the_full_view_scale_range FAILED`, **exit 100**, `1 test cases | 0 errors | 72 failures`. Per LEDGER F02-08 ("after a failure gdUnit4 stops the remaining tests in that same suite file"), only that one test case ran; the other 5 in the file did not execute this pass — confirmed the same F02-08 behaviour again in this task's own run.

**Mutation 2 — clamp on only one axis** (Y-axis clamp branch removed, X-axis clamp left intact):
`test_visible_rect_stays_within_arena_bounds_across_the_full_view_scale_range FAILED`, **exit 100**, `1 test cases | 0 errors | 36 failures` (all Y-axis violations; X-axis checks passed since that axis was still clamped, which is itself confirmation the failures are axis-specific and not a wholesale break).

**Mutation 3 — clamp to the wrong rectangle (arena size but not the offset)** (`arena_min`/`arena_max` computed from `Vector2.ZERO` instead of `arena_center`):
First attempt hit an engine-level false start unrelated to the mutation's logic (see "Engine quirk observed" below) and was re-run. On the clean re-run: `test_visible_rect_stays_within_arena_bounds_across_the_full_view_scale_range PASSED`, `test_camera_centred_at_arena_centre_stays_within_bounds PASSED`, **`test_visible_rect_respects_a_non_zero_arena_center FAILED`**, **exit 100**, `3 test cases | 0 errors | 24 failures`. This is the exact result predicted by the blind-spot analysis above: the two zero-offset tests could not see the bug and passed; only the offset-aware test caught it. Had the suite not been strengthened first, this mutation would have gone green and been wrongly reported as caught.

**Restoration**: after each mutation, `src/camera/game_camera.gd` was restored from the pre-mutation backup and diffed byte-identical (`diff` reported no output) before the next mutation. Final restoration confirmed via the clean full-suite green run reported above (182/182, exit 0).

### Engine quirk observed (recorded, not diagnosed, per this project's convention for untested causes — see LEDGER F02-08's own framing)

Twice during falsification (before Mutation 1's real result, and again before Mutation 3's real result), the *first* gdUnit4 invocation immediately following an edit to `src/camera/game_camera.gd` (a `class_name`-registered script) failed test discovery entirely with `SCRIPT ERROR: Parse Error: Class "GameCamera" hides a global script class.` and exited **105**, rather than running any test. A second, otherwise-identical `--import` pass followed by the same test command succeeded normally both times (Mutation 1: then exit 100 as reported; Mutation 3: then exit 100 as reported). This looks like a global-script-class-cache staleness race specific to editing a `class_name`-declared script and immediately re-importing in the same short script, not a defect in the mutation or the test. **Recorded for the phase LEDGER as a new engine-behaviour observation**, in the spirit of F02-08: the fix in both cases was simply "run `--import` a second time before trusting a discovery failure," and every reported acceptance-test result and falsification result in this report is from a run where the class-cache had settled (discovery succeeded and real tests executed).

## `run_tests.ps1` result (the engine-error guard, per LEDGER F02-14)

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit
```

**Exit 0.** `PASS (exit 0): 182 test case(s) executed under res://tests/unit, all passed.` No `ENGINE ERRORS:` line and no `NOT A USABLE RUN:` line appeared anywhere in the captured output — the script's Guard 4 (scanning for `ERROR:`/`SCRIPT ERROR:`/`USER ERROR:`/`USER SCRIPT ERROR:` lines) found none. This run's own internal `--import` pass and test pass were both clean on the first try (the class-cache quirk above only appeared when editing the camera script and testing again within the same short window during falsification, not on this final, unmutated run).

## Contradictions and open items, named rather than silently resolved

1. **Tower's exact world position is unconfirmed.** `arena_center = Vector2.ZERO` is this task's own reading of "Tower at centre," matched to `scenes/arena.tscn`'s own origin-centred Floor/walls, but P2.4 (parallel, not readable/writable by this task beyond what's on disk) may place `scenes/tower.tscn` elsewhere. If so, `GameCamera.arena_center` needs updating to match — a one-line change, not a redesign, but a real cross-task dependency this task cannot close alone.
2. **Zoom trigger wiring is explicitly deferred**, not built — see "Scope boundaries" above. `set_view_scale()` is ready for P2.1/P2.4 (or a later integration task) to call once player speed and Tower health events exist.
3. **Vignette `CanvasLayer.layer = 4` is a guess** made with no HUD (P2.6) built yet to check against; flagged in-code for revisiting.
4. **The class-cache "hides a global script class" engine quirk** (above) is recorded, not diagnosed — consistent with this project's stated policy of recording observed engine behaviour without guessing at its cause.

## Final regression check at hand-off

P2.1 and P2.4 are running in parallel and added their own files and tests to the same working tree while this task was in progress (`src/player/*`, `scenes/player.tscn`, `src/tower/*`, `scenes/tower.tscn`, `tests/unit/player_*_test.gd`, none of it touched by this task). A last import-and-run pass immediately before hand-off, on the tree as it stood at that moment, reported `Overall Summary: 210 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`, `Executed test suites: (27/27)`, exit 0 — confirming this task's additions still hold green alongside whatever the other two implementers had landed by that point. The "182" figure earlier in this report is this task's own before/after count (172 → 182) and is the number to cite for P2.2 specifically; 210 is a snapshot of the whole tree at hand-off, not a P2.2 number, and will keep moving as P2.1/P2.4/etc. continue.

No gate, test, or phase is described here as passed, satisfied, or ready; the results above are reported for the reviewers and the author to judge.

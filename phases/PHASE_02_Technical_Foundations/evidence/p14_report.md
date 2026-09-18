# P1.4 Evidence Report — Debug Overlay, Run Recorder, Pseudo-localization Toggle

Plan ID: P1.4 (`phases/PHASE_02_Technical_Foundations/PLAN.md` § "P1.4").
This document records what was built, the overlay's field list mapped
one-to-one against docs/20, the two CSV schemas as written and how the
schema check's expectation is sourced independently of the writer, the
process-mode choice for both the overlay and the recorder with
justification, the autoload decision and its consequence for
`tests/settings_check.gd`, the acceptance test with commands/exit
codes/falsification log (including the column-order question), and every
contradiction or ambiguity found in the source documents. It does not
assert that any gate is passed, satisfied, met, or ready — that is for
reviewers and the author (CLAUDE.md; phases/README.md loop rule (e)).

## GodotPrompter skills consulted

Invoked **before** writing any code, per CLAUDE.md's rule for subagents
writing Godot code.

- **`godot-ui`**: confirms the shape used for the overlay — `Control` nodes
  under a `CanvasLayer`, containers over manual positioning, a single
  `Theme`-free `Label` acceptable for a debug-only readout. No conflict
  with this project's documents.
- **`hud-system`**: names the exact pattern used — "Keep all HUD scenes
  under a single `CanvasLayer`... Use `layer = 1` for the main HUD. Use
  higher values (e.g. `10`) for overlays." `overlay.tscn`'s `CanvasLayer`
  uses `layer = 90` (no other UI layer exists yet in this phase to collide
  with; picked high enough to stay above whatever HUD P2.x adds at `layer
  = 1`). The checklist's "HUD nodes that do not need input set
  `mouse_filter = MOUSE_FILTER_IGNORE`" is applied to the overlay's
  `PanelContainer` so it never blocks gameplay input.
- **`localization`**: covers `tr()`/translation files, not pseudolocalization
  specifically. No conflict; the pseudolocalization toggle uses
  `TranslationServer.set_pseudolocalization_enabled()` /
  `.is_pseudolocalization_enabled()` / `.reload_pseudolocalization()`,
  engine APIs outside this skill's own scope, cross-checked against Godot
  4.x's `TranslationServer` class reference from memory rather than the
  skill (the skill was still read in full first, per the rule).

No conflict between any of the three skills and docs/20, the Provisional
Values Register, or an Author decision was found; nothing to record in the
phase LEDGER for this task.

## Files created (all within this task's write scope)

- `src/debug/overlay.gd` — the Debug Overlay script (`class_name
  DebugOverlay`).
- `src/debug/overlay.tscn` — `CanvasLayer` → `PanelContainer` →
  `MarginContainer` → one `Label` whose multi-line text is written by the
  script every `_process()`.
- `src/debug/run_recorder.gd` — the Run Recorder (`class_name RunRecorder`).
- `tests/unit/run_recorder_schema_test.gd` — the named acceptance test
  (Recorder schema check).
- `tests/unit/run_recorder_behavior_test.gd` — supplementary correctness
  coverage (event recording, idleness, CSV escaping, process mode).
- `tests/unit/debug_overlay_test.gd` — supplementary field-presence and
  F1/F2 toggle coverage.
- This report.

`project.godot` was **not** touched — no autoload was added (see "Autoload
decision" below) and F1/F2 already existed (decision D78), so no input-map
edit was needed either. `tests/settings_check.gd` was **not** touched, for
the same reason.

## Debug Overlay — field list mapped one-to-one against docs/20

docs/20 § "Debugging, Telemetry & Run Recording" › Debug Overlay bullet, in
its own listed order, against the line `_refresh_text()` writes for it:

| docs/20 field | Overlay text line | Data source |
| --- | --- | --- |
| FPS current | `FPS cur/median/p1: <cur> / ...` | `Engine.get_frames_per_second()` |
| FPS median over 10 s | same line, 2nd value | rolling real-time sample window, this file's own 10 s ring buffer |
| FPS 1st percentile over 10 s | same line, 3rd value | same ring buffer, p=0.01 |
| Entity count: Enemies | `Entities Enemies:N ...` | `EntityRegistry.get_entity_count(&"enemy")` |
| Entity count: Projectiles | same line | `EntityRegistry.get_entity_count(&"projectile")` |
| Entity count: Pickups | same line | `EntityRegistry.get_entity_count(&"pickup")` |
| Entity count: Effects | same line | `EntityRegistry.get_entity_count(&"effect")` |
| Damage-number count | `DamageNumbers:N ...` | `EntityRegistry.get_entity_count(&"damage_number")` |
| Telegraph count | same line | `EntityRegistry.get_entity_count(&"telegraph")` |
| High-intensity-VFX count | same line | `EntityRegistry.get_entity_count(&"vfx_high_intensity")` |
| Player HP | `Player HP: <v>` | `set_player_state(hp)`, injected |
| Tower HP | `Tower HP: <v> ...` | `set_tower_state(hp, shield)`, injected |
| Tower shield | same line | `set_tower_state(hp, shield)`, injected |
| Current Wave ID | `Wave: <v> Encounter: <v>` | `set_wave_encounter(...)`, injected |
| Current Encounter ID | same line | `set_wave_encounter(...)`, injected |
| Pressure Metric value | `Pressure: <v> State: <v>` | `set_pressure(value, state)`, injected |
| Pressure escalation/de-escalation state | same line | `set_pressure(value, state)`, injected |
| Current health quadrant | `Health Quadrant: <v>` | `set_health_quadrant(...)`, injected |
| Simulation time | `Sim Time: <v>` | `SimClock.now` |

Every field docs/20 names has a line. One extra line beyond docs/20's list
was added — `[QA only, not a docs/20 overlay field] Pseudo-loc: ON/OFF
(ratio 0.3)` — so a developer pressing F2 has visible confirmation it
worked, since no other UI exists yet to show pseudolocalized text. It is
explicitly labelled as not one of the 19 required fields, so it cannot be
mistaken for one in a review.

**Fields with no owning system yet** (Player/Tower HP & shield, Wave/
Encounter ID, Pressure value & state, health quadrant) display the literal
string `n/a` until a real system calls the corresponding typed setter —
never a fabricated number. `debug_overlay_test.gd`'s
`test_unset_gameplay_fields_show_the_unset_label_not_a_fabricated_value`
asserts this directly. Health/doc 05 and the Wave Director/Pressure Metric
(P2.8/P2.9) do not exist yet in this phase; P2.9's own task row
(`MASTER_SDLC.md` task table, and this phase's own PLAN.md line 3163) names
"overlay fields" as part of **its own** deliverable, meaning P2.9 is
expected to call these setters, not this task.

**Tag-naming risk, named plainly**: `EntityRegistry.get_entity_count(tag)`
is a real, already-working query (P1.2). `"enemy"` is the one tag string
`EntityRegistry` itself already hard-codes internally
(`get_enemies_in_radius()`, `get_live_enemy_count()`), so it is not this
task's invention. The other six tag strings (`"projectile"`, `"pickup"`,
`"effect"`, `"damage_number"`, `"telegraph"`, `"vfx_high_intensity"`) are
this task's own convention, chosen because no pool, spawner, or VFX system
exists yet (P1.3 is concurrent with this task; P1.5+ is later) to fix one.
If a later system tags its pooled instances with different strings, these
counts silently read zero rather than erroring. This is a real
coordination risk across phases, not resolved here, flagged for whoever
builds P1.3/P1.5's actual pooled spawning to either adopt these tag
strings or for this file to be updated to match theirs.

## Run Recorder — the two CSV schemas as written

### `ticks.csv` (2 Hz, `RunRecorder.TICKS_HEADER`)

```
sim_time, player_pos_x, player_pos_y, player_hp, tower_hp, tower_shield, pressure, health_quadrant, xp_level, scrap, hopper_amount
```

docs/20's own wording: *"ticks.csv, sampled at 2 Hz, with columns SimClock
time, player position, player HP, Tower HP and shield, Pressure, health
quadrant, XP level, Scrap, and hopper amount."* "player position" is not
itself one CSV-safe scalar — this implementer's interpretation splits it
into `player_pos_x` / `player_pos_y`, named here as an interpretation call
docs/20 does not spell out, not silently assumed. "Tower HP and shield"
splits into two columns the same way, which the prose's own "and" already
implies more directly.

### `events.csv` (one row per discrete event, `RunRecorder.EVENTS_HEADER`)

```
sim_time, event_type, source_intent, source_bearing, amount
```

docs/20's own wording, transcribed directly with no interpretation gap:
*"events.csv, one row per discrete event, with columns SimClock time, event
type, source intent, source bearing from the Tower, and amount."*

### How the schema check's expectation is sourced independently

`tests/unit/run_recorder_schema_test.gd` declares `EXPECTED_TICKS_HEADER`
and `EXPECTED_EVENTS_HEADER` as its own `const PackedStringArray` literals,
typed out directly from the docs/20 prose quoted above in the test file's
own comments. Neither constant references `RunRecorder.TICKS_HEADER` /
`RunRecorder.EVENTS_HEADER` anywhere — the test does not ask the writer
what to expect (Phase 02 carried lesson 2). The falsification log below
proves the two really can disagree: three separate mutations of the
writer's own constants were each caught by the test's independent
expectation, with no change to the test file at all.

### Header file, run seed, and build hash

A third file, `header.csv`, is written alongside the two named CSVs (key,
value rows: `run_seed`, `build_hash`, `godot_version`). docs/20 does not
name a file extension or exact filename for the header — it is described in
prose only ("a header (run seed, build hash..., Godot version)") — so
`header.csv` is this task's own naming choice, kept CSV for consistency
with the other two files. The run seed is generated at `start_run()` via
`randi()` when the caller does not supply one, matching MASTER_SDLC.md's
"The run seed is generated at run start and written to the Run Recorder
header." Build hash: `res://build_info.txt` is read if present, else
`"editor"` — this task did not write the `EditorExportPlugin` that produces
that file (export tooling is outside this delegation's scope and explicitly
barred), so every run this delegation can itself produce records
`"editor"`, exactly matching docs/20's own stated case for editor and
headless runs.

### The Idleness Metric

Implemented in `RunRecorder._update_idleness()`, called every
`_physics_process()` tick while a run is open: accumulates simulation time
while `EntityRegistry.get_live_enemy_count() == 0` **and**
`EntityRegistry.get_entities_in_radius(player_position, 2 × magnet_radius,
&"pickup")` is empty, resets on any activity, and records one `"idle"`
`events.csv` row (amount = the accumulated idle duration) the first time
the accumulator exceeds `scheduled_gap + grace_period + 3.0` seconds —
re-arming only after activity resumes, so one contiguous idle stretch
produces exactly one row. `scheduled_gap` and `grace_period` default to
`0.0` (Wave Director values, P2.8, not sourced anywhere yet), so today's
effective threshold is exactly the fixed 3 seconds docs/20 states.
Magnet radius defaults to 96 px, cited from MASTER_SDLC.md's Provisional
Values Register (Interfaces / Player Overview: "Magnet radius / pickup
motion | 96 px ...", owner doc 16), not restated as a bare literal.
`set_idle_thresholds()` and `set_magnet_radius()` let a later system
override both. `force_idle_update_for_test()` is a test-only knob (mirrors
`entity_registry.gd`'s own `set_cell_size_for_test()` convention) that
calls the exact same `_update_idleness()` the production `_physics_process`
path calls, so testing it is testing production logic, not a stand-in.

## Process-mode choice, with justification

MASTER_SDLC.md › Global Simulation Authority states the mapping directly:
`SimClock`, `EntityRegistry`, `CombatStats` are `PROCESS_MODE_PAUSABLE`;
`PauseAuthority`, `EventBus`, "the UI `CanvasLayer`," the ducking node, and
UI sound players are `PROCESS_MODE_ALWAYS`.

- **Debug Overlay → `PROCESS_MODE_ALWAYS`.** The overlay's root scene IS a
  UI `CanvasLayer`, which the master already names `PROCESS_MODE_ALWAYS`
  directly — not an inference. Concretely, this means the overlay's own FPS
  sampling and text refresh keep running while the game is paused (Level-Up
  Draft, pause menu, the debug pause reason itself), which is exactly the
  behaviour wanted: a developer debugging *why* the game paused, or
  checking FPS during a paused menu, should not have the overlay itself
  freeze. This does **not** mean the gameplay values it displays keep
  moving under pause — `EntityRegistry` and `SimClock` are themselves
  `PAUSABLE`, so entity counts and simulation time correctly read as frozen
  during a pause; only this node's own sampling/refresh loop stays alive.
- **Run Recorder → `PROCESS_MODE_PAUSABLE`.** This is the one process-mode
  decision the task brief asked to be argued, not assumed, and the
  reasoning is: `ticks.csv` is a dense trace of **simulation** state, and
  simulation state is frozen while the tree is paused (`SimClock` itself is
  `PAUSABLE`). Continuing to sample during a pause would write duplicate
  rows of the identical frozen values — pure noise in the trace, and it
  would also mean the "2 Hz" cadence documented for `ticks.csv` no longer
  means "2 Hz of simulation time" the moment a pause is involved. Matching
  `SimClock`'s own process mode is the simplest way to guarantee the
  sampling cadence and the Idleness Metric's accumulator both track
  simulation time exactly, with no separate pause-awareness logic needed in
  this file at all. Critically, this choice costs nothing on the
  **event-driven** half of the class: `record_event()` and the EventBus
  signal handlers are ordinary method calls, never engine `_process`
  callbacks, so they are **never** gated by this node's `process_mode` — an
  event that genuinely happens while paused (a future Level-Up Draft
  purchase, once that system exists) is still recorded at the exact
  `SimClock.now` instant it happened, regardless of the recorder's own
  process mode. This is exactly what the task brief's warning ("a recorder
  that stops with the simulation records different data from one that does
  not") turns on: the *sampling* half stopping with the simulation is
  correct (it would otherwise misrepresent frozen state as changing data);
  the *event* half never stops, because it was never gated by process mode
  to begin with.

## Autoload decision

**No autoload was added.** Neither `DebugOverlay` nor `RunRecorder` is
registered in `project.godot`'s `[autoload]` section, and
`tests/settings_check.gd` (its `AUTOLOADS` constant, currently six entries)
was **not** touched.

Reasoning:

- `RunRecorder` has a bounded lifetime by design (`start_run()` ..
  `end_run()`, matching one run), which is the shape of a plain `Node` a
  future run-owning system instances and frees when a run starts/ends, not
  a singleton meant to outlive every run. Making it an autoload would force
  every consumer to reason about a global instance's open/closed state
  across runs for no benefit this task needs.
- `DebugOverlay` is a scene meant to be instanced once under whatever UI
  root a later phase builds (no `CanvasLayer`/HUD root exists yet in this
  phase), not a piece of simulation-authority state the way `SimClock` or
  `PauseAuthority` are. It does not need to exist before a scene tree does.
- Both classes declare `class_name` (`DebugOverlay`, `RunRecorder`),
  following `src/core/keyed_rng.gd`'s existing precedent for a non-autoload
  utility class in this codebase (`KeyedRng` also has no autoload entry),
  so they are still globally referenceable by type without an autoload.

Because no autoload was added, the two-sided proof the task's trap warning
asks for (show the updated settings check still fails on both a rogue extra
autoload and a missing expected one) does not apply — `tests/settings_check.
gd`'s `AUTOLOADS` constant is unchanged from what P1.1/P1.2 left it at, and
its own exact-set assertion (already proven to fail on both directions by
construction, since it diffs the actual `autoload/*` keys against a fixed
required list) still functions exactly as before. This was **not**
independently re-verified by this task, since nothing about it changed;
re-verifying an untouched check would not test anything this task did.

**Consequence of this choice**: neither the overlay nor the recorder is
wired into any running scene yet. `overlay.tscn` is not a child of
`scenes/main.tscn` (out of this task's write scope — that file belongs to
the concurrent P1.3 delegation, and it is a bare `Node2D` today with no
CanvasLayer/HUD to attach an overlay under regardless). `RunRecorder` is
never instantiated by any other system. Both are verified the same way
P1.1/P1.2 verify their own not-yet-wired autoload scripts:
`pause_clock_test.gd`'s own pattern of a fresh instance added to a test's
own tree. A future task (the run-start system, and whatever wires the HUD
root) is expected to instance both.

## Acceptance test — Recorder schema check

Command (run from `D:\Gamedev`):

```
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
"/d/godot/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit/run_recorder_schema_test.gd --ignoreHeadlessMode
```

Result: 5/5 tests pass, exit code 0.

### A pre-existing, unrelated blocker discovered during discovery — and how it was worked around

Running the full-directory form of the command
(`-a res://tests/unit --ignoreHeadlessMode`) fails test **discovery**
entirely (exit 105, "Abnormal exit... Script errors were detected during
test discovery") because of a parse error in `src/core/entity_spawner.gd`
(`Identifier "EntityCaps" not declared in the current scope"`) — a file
belonging to the **concurrent P1.3 delegation** (`git status` confirms
`src/core/entity_caps.gd`, `entity_spawner.gd`, `pool.gd`, and
`tests/unit/{entity_cap_test,pool_test,main_scene_structure}_test.gd` are
all untracked, mid-work, and out of this task's write scope: "A concurrent
implementer is working on `src/core/pool.gd` and `scenes/main.tscn` — stay
out of both"). This is not something this task caused, and per the explicit
scope boundary this task did not fix it, or touch any of those files.

`GdUnitTestSuiteScanner.scan()` loads a **single file directly** (skipping
the directory walk) when the given path is a file rather than a directory
(`if FileAccess.file_exists(resource_path): ... _load_is_test_suite
(resource_path)`), so every acceptance-test and full-suite run in this
report instead passes every `tests/unit/*.gd` file **individually** via
repeated `-a` flags, naming every file except the three broken/WIP ones
above, plus `-a res://tests/unit/audio` (a clean subdirectory with no
dependency on the broken chain). This reaches exactly the same test
population the directory form would reach once P1.3's WIP settles, without
this task touching P1.3's files.

### Falsification log

All three mutations below were applied directly to
`RunRecorder.TICKS_HEADER` in `src/debug/run_recorder.gd`, run against the
schema test alone, then reverted, with a full clean-baseline re-run (112
tests) confirming the revert left no trace.

1. **Drop a column** (removed `"tower_shield"`):
   ```
   test_ticks_csv_header_matches_docs20_schema FAILED
   Expecting: [..., tower_hp, tower_shield, pressure, ...]
   but was:   [..., tower_hp, pressure, ...]
   ```
   Diff table names index 5 (`pressure` where `tower_shield` was expected)
   through index 10 (`<N/A>` where `hopper_amount` was expected) — the
   missing column and its cascading shift are both visible. **Red.**
   Per the known quirk (LEDGER F02-08, confirmed again here), the suite
   stopped after this one failure; only 1 of 5 tests in the file ran.

2. **Rename a column** (`"scrap"` → `"scraps"`):
   ```
   test_ticks_csv_header_matches_docs20_schema FAILED
   Differences found: index 9: scraps (current) vs scrap (expected)
   ```
   Names exactly the renamed column and its index. **Red.**

3. **Reorder two columns** (swapped `"health_quadrant"` and `"xp_level"`):
   ```
   test_ticks_csv_header_matches_docs20_schema FAILED
   Differences found: index 7: xp_level (current) vs health_quadrant (expected)
                       index 8: health_quadrant (current) vs xp_level (expected)
   ```
   **Red**, naming both swapped indices precisely.

After each mutation, `TICKS_HEADER` was restored to its original text via
the same `Edit` operation reversed, and the schema test suite was re-run to
green before moving to the next mutation (per the F02-08 quirk note: a
suite that failed once needs a fresh green run to prove it is whole again).
A final full clean-baseline run (10 pre-existing files + `tests/unit/audio`
+ this task's 3 new files = 112 tests) confirmed 0 errors, 0 failures, exit
0 after the last restoration.

**The column-order question, answered plainly, not silently decided**:
docs/20's prose lists both CSVs' columns in one specific order but never
states in so many words that order is part of the schema (versus merely
the order the prose happens to list them in). This test's assertion
(`assert_array(got).is_equal(expected)`) is **order-sensitive** — mutation
3 above proves a two-column reorder goes red, exactly like a rename or a
drop. This was a deliberate implementation choice (the stricter of the two
readings, and the one that makes a CSV's column meaning unambiguous to any
downstream tool that reads by position rather than by header name), not
something docs/20 itself settles. If order is later ruled NOT to be part of
the schema, this assertion would need to change to
`contains_exactly_in_any_order()` instead.

### A real bug this task's own testing caught

The first full run of `run_recorder_schema_test.gd` failed with `but was
'[ ]'` (an apparently-empty array) even with the writer completely
unmutated. Root cause: the test opens a **second** `FileAccess` handle on
`ticks.csv`/`events.csv` to read the header back while the recorder's own
write handle is still open (the run has not been ended yet). Godot's
buffered `FileAccess` does not guarantee a second handle sees content
written through a first, unflushed one. Fixed by calling `file.flush()`
after every `_write_csv_row()` in `run_recorder.gd` — matching Phase 02
carried lesson 5 ("verify by reading the artifact back... a tool reporting
success is not evidence") directly: this bug existed only because the test
actually read the file back rather than trusting that `store_line()`
succeeding meant the content was visible.

## Total unit-test count

A clean baseline run — every pre-existing test file except the three
untracked, mid-work P1.3 files named above, plus this task's three new
files — reports:

```
Overall Summary: 112 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Exit code: 0
```

90 pre-existing passing tests: 46 across `combat_stats_test.gd` (10),
`entity_registry_query_perf_test.gd` (3), `entity_registry_test.gd` (15),
`event_bus_test.gd` (5), `keyed_rng_test.gd` (6), `pause_clock_test.gd` (5),
and `sim_loop_order_test.gd` (2), plus 44 under `tests/unit/audio/`
(`test_audio_ducking.gd` 10, `test_audio_pool.gd` 8, `test_bus_layout.gd` 8,
`test_cue_retrigger_limiter.gd` 9, `test_tower_cue_player.gd` 9) — **+ 22
new** (`debug_overlay_test.gd` 6, `run_recorder_behavior_test.gd` 11,
`run_recorder_schema_test.gd` 5) **= 112**, none broken. The three P1.3 files (`entity_cap_test.gd`,
`pool_test.gd`, `main_scene_structure_test.gd`) could not be included in
this count because they do not currently compile — this is the concurrent
delegation's own in-progress state, not a regression this task caused or is
responsible for reporting a pass/fail on.

## Contradictions and ambiguities — named, not resolved

1. **"player position" as a ticks.csv column is not one CSV scalar.**
   Resolved here by splitting into `player_pos_x`/`player_pos_y` — an
   interpretation, not a literal reading. See the schema section above.
2. **The header file's name and format are unspecified.** docs/20 says "a
   header (run seed, build hash..., Godot version)" with no filename or
   extension. `header.csv` (key/value rows) was chosen for consistency with
   the other two files; a different implementer could reasonably choose
   `header.json` or a single-line string.
3. **The Pressure escalation/de-escalation STATE is an overlay-only field.**
   docs/20's overlay bullet asks for "the Pressure Metric value and its
   escalation/de-escalation state," but the Run Recorder's own `ticks.csv`
   column list says only "Pressure" (the value). This means the escalation/
   de-escalation state is visible live but is **not** persisted to the
   recorded trace at all under a literal reading of docs/20 — an
   asymmetry, not a contradiction, but worth the author/reviewers noticing:
   if that state matters for post-run pacing analysis (the actual purpose
   of the Run Recorder, per its "you cannot balance what you cannot
   measure" framing), a later phase may want to add a column for it.
4. **Column order as schema.** Addressed above under "the column-order
   question" — implemented as order-sensitive, not settled by docs/20
   itself.
5. **Entity/telemetry-count tag-string convention.** Addressed above under
   the overlay's field table — a real cross-phase coordination risk, not a
   docs/20 ambiguity exactly, but adjacent to one: docs/20 names the
   overlay's count categories (Enemies, Projectiles, Pickups, Effects,
   damage-numbers, telegraphs, high-intensity VFX) without naming an
   `EntityRegistry` tag convention for any of them beyond the one
   (`"enemy"`) the registry itself already hard-codes.
6. **"editor and headless runs record build hash 'editor'"** reads as
   stating the *outcome* for those two run types, not instructing this task
   to write the `EditorExportPlugin` that produces `build_info.txt` for a
   real export — read that way here, consistent with this delegation's
   explicit "no export" constraint; recorded as a reading, not asserted as
   the only possible one.

## Never asserted

This report does not claim the Debug Overlay, Run Recorder, or
pseudo-localization toggle are "done," "correct," "complete," or that any
gate is passed, satisfied, met, or ready. It records what was built, why,
what was measured, and what remains open for reviewers, the author, and
later phases (P1.3's pooling/tagging convention, P1.5's death/hitbox
systems, P2.8's Wave Director, P2.9's Pressure Metric) to settle or wire
in.

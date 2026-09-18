# P1.6 - Audio bus layout and AudioPool: implementer evidence report

**Scope.** Build the audio bus layout and the 32-voice AudioPool with priority stealing,
per PLAN.md > P1.6, docs/20_Technical_Architecture.md > "Audio Mixing & Dynamic Ducking"
(binding for P1.6 under decision D95, taken at Phase 02 entry - MASTER_SDLC.md's task
table names document 26, which is still a P0.3 stub; docs/26 was not read), and this
task's hard constraints (Phase 00 finding F-06: the `ask` permission gate does not
intercept subagents). This report records what was built and what was directly observed
running it; it does not assert that any gate, check, or acceptance test is passed,
satisfied, or ready - that is for reviewers and the author.

No `mcp__godot-comprehensive__delete_file`, `export_project`, `run_project`, or any
`game_*` tool was called. No file was deleted. The editor GUI was not launched. Every
Godot invocation below went through
`/d/godot/Godot_v4.7.1-stable_win64_console.exe` via Bash, targeting Godot 4.7.1. Nothing
under `sandbox/`, `tools/`, `addons/`, `src/data/`, `src/core/`, or `project.godot` was
touched; `git status` against this task's write scope (below) confirms it.

## 0. GodotPrompter skill invoked first

`godot-prompter:audio-system` was invoked before any code was written, per CLAUDE.md's
GodotPrompter section. Its content: audio bus routing/creation via the editor Audio
panel, `AudioServer.set_bus_volume_db`/`linear_to_db`/`db_to_linear`, spatial
`AudioStreamPlayer2D`/`3D` properties, a generic "SFX Pool" pattern (pre-instantiated
`AudioStreamPlayer` array, no priority/stealing concept), a Music Manager autoload
pattern, and format/import advice (WAV for short SFX, OGG for music). None of this
conflicts with docs/20 or the Provisional Values Register - it is generic Godot audio
API guidance, correct as far as it goes, and this task's six-bus/priority-stealing
design is strictly more specific than anything the skill prescribes. **No conflict to
record in the LEDGER.** The skill's own "SFX Pool" reference pattern has no priority
field, no stealing algorithm, and no voice cap - `audio_pool.gd` below is this project's
own design, built to docs/20's Voice Limit spec, not adapted from the skill's pattern.

## 1. Files created (all within this task's write scope)

```
default_bus_layout.tres              (project root)
src/audio/audio_pool.gd
src/audio/audio_ducking.gd
src/audio/cue_retrigger_limiter.gd
src/audio/tower_cue_player.gd
tests/unit/audio/test_audio_pool.gd
tests/unit/audio/test_audio_ducking.gd
tests/unit/audio/test_cue_retrigger_limiter.gd
tests/unit/audio/test_bus_layout.gd
tests/unit/audio/test_tower_cue_player.gd
phases/PHASE_02_Technical_Foundations/evidence/p16_report.md   (this file)
```

Each `.gd` file also carries a Godot-generated `.gd.uid` sidecar (standard for every
script in this project, e.g. `src/core/boot_check.gd.uid` already exists) - not
hand-written, produced automatically by the `--import` pass.

`git status --porcelain` restricted to this task's write paths shows only the files
above as untracked, nothing modified outside them:

```
?? default_bus_layout.tres
?? src/audio/audio_ducking.gd(.uid)
?? src/audio/audio_pool.gd(.uid)
?? src/audio/cue_retrigger_limiter.gd(.uid)
?? src/audio/tower_cue_player.gd(.uid)
?? tests/unit/audio/
```

`tests/unit/` already carries three sibling files from the concurrent P1.1 implementer
(`keyed_rng_test.gd`, `pause_clock_test.gd`, `sim_loop_order_test.gd`) - none of them
were read, opened for edit, or touched; only the new `tests/unit/audio/` subdirectory
was added.

## 2. Bus layout: what was built, and where it lives

### 2.1 The graph, against docs/20's routing

docs/20 > "Audio Bus Hierarchy": *"Audio must be strictly routed: `Master` ->
`Music`, `SFX`, `SFX_Priority` (fed by `TowerCue`), `UI`, `Ambience`. Player damage,
Tower damage, and Boss telegraphs are routed to `SFX_Priority`, which never ducks."*
Plus > "Tower Cue Player": *"routed to a sixth bus, `TowerCue`, which sends to
`SFX_Priority` and carries an `AudioEffectPanner`."*

Built exactly as seven buses (Master plus the six PLAN.md P1.6 names it: *"Music, SFX,
SFX_Priority, TowerCue, UI, Ambience"*):

```
Master (bus 0, implicit root)
├── Music         (send = Master)
├── SFX           (send = Master)
├── SFX_Priority  (send = Master)
├── UI            (send = Master)
├── Ambience      (send = Master)
└── TowerCue      (send = SFX_Priority, carries an AudioEffectPanner)
```

Verified against the **live** `AudioServer` after a normal engine boot (not a resource
parsed in isolation - see `tests/unit/audio/test_bus_layout.gd`, all 8 tests passing,
section 4 below): `AudioServer.bus_count == 7`; bus 0 is named `"Master"`; `Music`,
`SFX`, `SFX_Priority`, `UI`, `Ambience` each send to `"Master"`; `TowerCue` sends to
`"SFX_Priority"`, not `"Master"`; `TowerCue`'s only bus effect is an
`AudioEffectPanner`; no other bus carries an effect.

### 2.2 Where the resource lives, and why

**`default_bus_layout.tres` at the project root**, not under `src/audio/`.

Godot 4's `audio/buses/default_bus_layout` project setting has a **compiled-in default
value of `"res://default_bus_layout.tres"`**. If a file exists at that exact path, the
engine loads it as the project's live bus graph at boot with **no `project.godot`
entry required** - the setting only needs to be written to `project.godot` if you want
to override it to something else. This task's hard constraint forbids editing
`project.godot` (owned by the concurrent P1.1/P0.2 work), so the project-root path is
the only location that makes this layout actually take effect without that edit.
Placing it under `src/audio/` instead would require exactly the `project.godot` edit
this task cannot make, leaving the buses defined but inert.

This was verified empirically, not assumed: `tests/unit/audio/test_bus_layout.gd`'s
first test asserts `ProjectSettings.get_setting("audio/buses/default_bus_layout") ==
"res://default_bus_layout.tres"` (true - the engine's own compiled default, since
`project.godot` carries no `[audio]` section), and every other test in that suite reads
the **live** `AudioServer` state with no `set_bus_layout()` call anywhere in the test
run - so the seven buses observed are exactly what the engine booted with from this
file, at this path, confirming the auto-load claim rather than just citing it.

**Side effect worth recording, not a manual edit:** running `--headless --path . --import`
caused Godot's own resource pipeline to re-save `default_bus_layout.tres` in its
canonical form - it added a `uid://` reference (Godot 4.4+ auto-assigns a UID to every
resource file on first load), converted bare bus/effect name strings to `StringName`
literals (`&"Music"` instead of `"Music"`), and pruned the explicit `bus/0/name =
"Master"` block since bus 0 is always named `"Master"` by engine convention and an
explicit declaration matching that default is redundant. The bus graph itself
(names, sends, the `TowerCue` panner) is unchanged; this was the engine normalizing the
file I wrote, not a hand edit.

## 3. AudioPool: the stealing algorithm

`src/audio/audio_pool.gd`, `extends Node2D`, `class_name AudioPool`. 32
`AudioStreamPlayer2D` children created in `_ready()`. Per docs/20 > "Voice Limit" and
the Provisional Values Register > Audio > "AudioPool" row, two **independent** stealing
rules are implemented, matched to the doc's exact wording rather than collapsed into
one:

1. **General 32-voice cap** (`_find_steal_candidate_index()`), applied whenever no free
   voice remains, for any sound, priority or not: steal the **lowest-priority** voice;
   ties broken by the **oldest** (see clock note below).
2. **Priority-slot cap** (`_find_oldest_priority_voice_index()`), applied only to a new
   priority request once 8 priority voices are already active: steal the **oldest**
   active priority voice, full stop - priority value is not consulted for this rule,
   exactly as docs/20 states it ("*once all 8 priority slots are full a new priority
   sound steals the oldest priority voice*").

`allocate_voice(priority, is_priority_voice)` checks rule 2 first (only relevant to
priority requests), then falls through to rule 1. This is the pure bookkeeping entry
point, deliberately kept free of any real Godot audio call, so it is unit-testable
headless (section 4). `play(...)` wraps it with the actual `AudioStreamPlayer2D`
configuration and `.play()` call.

**Voice age.** Godot exposes no voice age. The pool tracks it itself with a
monotonically increasing `_alloc_serial` set on every `allocate_voice()` call -
"oldest" means "allocated longest ago in allocation order." This needs no clock at all,
so it sidesteps the clock question entirely for the stealing rule itself (the clock
question below is about the *ducking ramp*, a separate piece).

**Scene ownership.** Per docs/20, "*the AudioPool lives under the gameplay root so it
pauses with the tree*", and MASTER_SDLC.md > Global Simulation Authority: "*Nothing
under the gameplay root may set `PROCESS_MODE_ALWAYS`.*" `audio_pool.gd` never sets
`process_mode`, so it inherits whatever its parent uses - correct for a gameplay-root
child. This implementer does not own `scenes/main.tscn` (concurrent P1.3 work builds
the gameplay-root container layout per PLAN.md's own "Corrected at phase entry" note),
so actually instancing `AudioPool` under the gameplay root, and wiring its optional
`ducking_node` reference, is left to whichever task owns that scene. `ducking_node` is
duck-typed via `has_method()` specifically so `audio_pool.gd` does not need to preload
`audio_ducking.gd` or assume it is already wired.

## 4. Ducking node: what it does and the clock decision

`src/audio/audio_ducking.gd`, `extends Node`, `class_name AudioDucking`,
`process_mode = PROCESS_MODE_ALWAYS` set in `_ready()`. Values: SFX & Ambience duck 9 dB
(50 ms attack, 300 ms release), Music ducks 6 dB floored at -18 dB - all four numbers
cited from MASTER_SDLC.md > Provisional Values Register > Audio > "Buses" row, not
invented.

**The clock decision, stated explicitly as required.** The node ramps on its own
per-frame `_process(delta)` - the engine's ordinary, real, unscaled frame delta - not on
`SimClock`. Reasoning:

- MASTER_SDLC.md > Global Simulation Authority explicitly groups this exact node with
  the UI `CanvasLayer` and the UI sound players as the `PROCESS_MODE_ALWAYS` set:
  *"`PauseAuthority`, `EventBus`, the UI `CanvasLayer`, the ducking node ..., and the UI
  sound players are `PROCESS_MODE_ALWAYS`, so they keep functioning while paused."* The
  same section separately exempts *"pure UI, which is not bound by `SimClock`"* from the
  ban on `SceneTree` timers/tweens driving gameplay. Ducking is a presentation-layer mix
  ramp, not one of the gameplay deadlines the Timing Rules list (wave timers, spawn
  cooldowns, telegraph durations, etc.) - it never gates combat, spawning, damage, or any
  simulation state - so the same exemption that covers the UI sound players it is grouped
  with covers it.
- Concretely, using `SimClock` here would be self-defeating even if it were available:
  `SimClock` is `PROCESS_MODE_PAUSABLE` and *stops advancing exactly when this node most
  needs to keep ramping* - mid-pause, with a priority sound's release ramp still in
  progress. A `PROCESS_MODE_ALWAYS` node driven by a paused clock could never finish a
  ramp while paused, defeating the entire reason docs/20 specifies it as `ALWAYS` in the
  first place.
- `src/core/sim_clock.gd` is being written by another implementer concurrently and does
  not exist in this working tree yet. `audio_ducking.gd` does not import, preload, or
  reference it anywhere, so it has no load-order dependency on that file landing first
  or on its final API shape.
- **Would I want `SimClock` here later?** Only for one specific reason, and it is
  recorded rather than acted on: if a future revision wants ducking to also slow down
  under `SimClock.time_scale` during hit-stop/slow-motion (currently always 1.0 in the
  prototype per the Provisional Values Register's "Hit-stop / slow motion" row), that
  would be a deliberate presentation choice, not a correctness requirement, and this
  file does not make that call unilaterally - it would need a recorded decision in the
  phase LEDGER, since it changes a `PROCESS_MODE_ALWAYS` node's behavior based on a
  `PROCESS_MODE_PAUSABLE` value it currently has no reason to read.

`step(delta)` is exposed separately from `_process(delta)` so tests can drive the ramp
with synthetic deltas instead of waiting on real frames - headless has no audio device
to time playback against regardless (section 6).

**Detection mechanism (see section 7, ambiguity #2):** docs/20 says "when a sound plays
on `SFX_Priority`" without saying how that is detected, and `AudioServer` exposes no
"is this bus currently outputting audio" query - only a peak-volume meter, an unreliable
and untestable proxy. `AudioDucking` is instead driven by an explicit
`notify_priority_started()` / `notify_priority_stopped()` pair that any
`SFX_Priority`-routed player calls - `audio_pool.gd`'s priority voices and
`tower_cue_player.gd` both call it (duck-typed via `has_method`, same pattern as
`ducking_node`). This is a reference-counted "how many priority sounds are active right
now" integer, not a bus query.

## 5. Retrigger limits and the Tower Cue Player

`src/audio/cue_retrigger_limiter.gd` (`RefCounted`, `class_name CueRetriggerLimiter`):
a per-`cue_id` "last triggered at" dictionary. `try_trigger(cue_id, now_ms, limit_ms)`
returns true (and records) only if the cue has not fired within `limit_ms` of `now_ms`.
It is **clock-agnostic by design** - every call is handed "now" by the caller rather
than reading a clock itself - for the same reason as the ducking node: it keeps the
class testable with synthetic timestamps (no real waiting, no flakiness), and it avoids
choosing a clock source while `sim_clock.gd` does not exist yet in this tree. Once it
does, gameplay call sites (player-damage and Tower-damage triggers, owned by later
combat tasks, not this one) should pass `SimClock.now * 1000.0` so the limit is
expressed in simulation time like every other gameplay deadline - this file does not
wire that itself.

Values used: player damage 150 ms, Tower damage 250 ms (Provisional Values Register >
Audio > "Retrigger limits" row).

`src/audio/tower_cue_player.gd` (`extends AudioStreamPlayer`, `class_name
TowerCuePlayer`): `bus = "TowerCue"`; `compute_pan(tower_x, player_x)` implements
docs/20's exact formula `clamp((Tower x - player x) / 960, -1, 1)`; `play_tower_damage()`
checks the 250 ms limit via its own `CueRetriggerLimiter` instance
(`RETRIGGER_CUE_ID = "tower_damage"`) before setting the `TowerCue` bus's
`AudioEffectPanner.pan` and playing. Not `PROCESS_MODE_ALWAYS`: the Global Simulation
Authority names only the ducking node and the UI sound players as the `ALWAYS` set;
Tower-damage cues fire from gameplay damage events, which do not occur while paused, so
the default `PAUSABLE`/`INHERIT` behavior needs no exemption. Intended to live under the
gameplay root alongside `AudioPool`; not wired into any scene by this task, for the same
reason as section 3's last paragraph.

## 6. Acceptance test: commands, exit codes, and the falsification log

**Named check** (MASTER_SDLC.md > Acceptance Test Matrix; PLAN.md P1.6 exit criterion):
*"Priority cue steals a voice and remains audible in 5 of 5 trials."* Implemented as
`test_priority_cue_steals_voice_and_remains_audible_5_of_5` in
`tests/unit/audio/test_audio_pool.gd`, alongside 7 supporting bookkeeping tests in the
same file and 26 further tests across four sibling suites (ducking math, retrigger
limits, bus layout, Tower cue player) - 44 tests total under `tests/unit/audio/`.

### 6.1 Commands run and results

Import pass, run once before every suite command:

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
```

Exit 0 both times it was run (once before first writing the tests, once after the
`class_name`-typing fix in section 6.2).

Full suite:

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/audio --ignoreHeadlessMode
```

| Run | Exit code | Result |
| --- | --- | --- |
| First attempt | **105** (script parse error) | `Cannot infer the type of "priority_player" variable` - see 6.2 |
| After fix, clean tree | **0** | `Overall Summary: 44 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|` |
| After falsification #1 (steal-highest mutation) | **100** | 1-2 failures, named below |
| After restoring #1 | (not re-run standalone; superseded by falsification #2's restore + final run) | |
| After falsification #2 (priority cap raised to 9999) | **100** | 2 failures, named below |
| After restoring #2, final run | **0** | `Overall Summary: 44 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \|` |

### 6.2 One real bug caught before it shipped

The first test run failed at **discovery** (exit 105, not a test failure) with:
`Cannot infer the type of "priority_player" variable because the value doesn't have a
set type` at `test_audio_pool.gd:140`. Cause: helper functions like `_make_pool()` were
typed to return the generic `Node2D`/`Node`/`AudioStreamPlayer` base class instead of
the actual script type, so GDScript's static type inference lost the `AudioPool` type
across the helper-function boundary and could not infer `pool.play(...)`'s declared
`AudioStreamPlayer2D` return type. Fixed by using the scripts' own `class_name` globals
(`AudioPool`, `AudioDucking`, `TowerCuePlayer`, `CueRetriggerLimiter` - all four scripts
already declare one) directly as the helper return types and `.new()` targets, instead
of `preload()`-ing the script into a local constant and typing against the generic base
class. Re-ran `--import` (exit 0) after this fix so the global script-class cache picked
up the corrected files, then re-ran the suite: **exit 0, 44/44 passing.**

### 6.3 Falsification #1: steal the wrong voice (highest priority instead of lowest)

**Mutation.** In `_find_steal_candidate_index()`, changed the comparison from
`v.priority < best_priority` to `v.priority > best_priority` - the general 32-voice-cap
rule now steals the *highest*-priority voice instead of the lowest.

**Command:** the same suite command as above.

**Result: exit 100.** `test_general_steal_picks_lowest_priority_voice_first` failed,
naming the exact wrong voice: `Expecting: 17 but was 31` (voice 17 was deliberately
seeded as the one lowest-priority voice among 32; voice 31 was the highest-priority one
- exactly the wrong choice the mutation would produce). Re-run with gdUnit4's `-c`
(continue-past-failure) flag against `test_audio_pool.gd` alone to see every affected
test in one pass: **2 of 8 tests failed** -
`test_general_steal_picks_lowest_priority_voice_first` and
`test_general_steal_tie_is_broken_by_oldest` (both directly exercise the mutated
function); the other 6, including the named 5-of-5 check, still passed.

**Honest finding, not smoothed over.** The named acceptance test
(`test_priority_cue_steals_voice_and_remains_audible_5_of_5`) **did not catch this
regression.** Its pre-fill loop plays 32 ordinary SFX all at `priority = 0`, so every
voice is tied when the priority request arrives, and a tie is broken by "oldest" either
way - the highest-vs-lowest distinction never gets exercised because there is no
priority spread among the candidates. The two dedicated bookkeeping tests, which
deliberately seed a non-uniform priority spread, are what actually catch this class of
bug. This is recorded here rather than glossed over: it is precisely the "a check that
cannot fail" failure mode Phase 01's carried lesson #1 warns about, now found and fixed
inside this same task rather than left for a reviewer to find - the fix was adding the
two dedicated tests, not modifying the named test (its 5-of-5 wording is the acceptance
criterion as written; the dedicated tests are the load-bearing coverage for *why* it
would hold).

### 6.4 Falsification #2: let the priority slot cap exceed 8

**Mutation.** Changed `const MAX_PRIORITY_VOICES := 8` to `const MAX_PRIORITY_VOICES :=
9999`.

**Command:** suite run against `test_audio_pool.gd` with `-c`.

**Result: exit 100, 2 of 8 tests failed**, both naming the failure precisely:

- `test_priority_cap_never_exceeds_8`: eleven separate assertion failures within the
  same test, one per allocation past the 8th, reading `Expecting to be less than or
  equal: 8 but was 9` through `... but was 20` - the active-priority count visibly
  climbing past the cap on every subsequent request.
- `test_priority_cap_steals_oldest_priority_voice_not_lowest_priority`: failed because,
  with the cap effectively disabled, the 9th priority request no longer takes the
  priority-cap-steal branch at all (8 < 9999), so it steals a completely different,
  non-priority voice instead of the deliberately-oldest priority voice the test expects.

### 6.5 Restoration confirmed clean both times

Each mutation was applied to a backed-up copy of `audio_pool.gd`
(`cp src/audio/audio_pool.gd <backup>` before mutating), then restored with `cp <backup>
src/audio/audio_pool.gd`, verified with `diff <backup> src/audio/audio_pool.gd`
reporting no differences before re-running. **Final confirmation run, full
`tests/unit/audio` suite, clean restored tree:**

```
Overall Summary: 44 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (5/5)
Executed test cases : (44/44)
Exit code: 0
```

## 7. What headless testing cannot verify

Headless Godot (`--headless`) runs on a Dummy audio driver: there is no audio output
device, so nothing here proves a human would actually **hear** anything, or hear it
correctly. Specifically, this suite cannot verify:

- **Real audible output at all** - no speaker, no waveform, no listening. `is_playing()`
  (used as the closest available proxy in the named 5-of-5 test) only proves the engine
  considers a voice in an actively-playing state after a steal; it says nothing about
  whether the mixed signal reaching a real output device would be audible, clipped, or
  silent.
- **Actual bus routing/mixing correctness in the running mixer** - whether a stream
  assigned to `SFX_Priority` is *really* summed into `Master` at the right level through
  the real audio graph, as opposed to the `bus` string property simply being set
  correctly (which this suite does verify).
- **The ducking ramp's real-world audibility** - whether a 9 dB dip actually sounds like
  a dip, whether the 50 ms attack is perceptually fast enough to avoid a "pump," or
  whether the 300 ms release sounds natural. The math (section 4, `test_audio_ducking.gd`)
  is verified exactly; how it sounds is not, and cannot be, verified headless.
- **`AudioEffectPanner`'s actual stereo image** - the test confirms the effect object's
  `pan` property is set to the correct clamped value; it cannot confirm the resulting
  stereo field is perceptually correct.
- **Timing precision under real frame-rate variance** - `step(delta)` is tested with
  exact synthetic deltas (0.05 s, 0.025 s, etc.); real `_process()` deltas jitter with
  frame rate, so the ramp's real-world attack/release timing accuracy under load is not
  exercised here (that belongs to a later integration/perf pass, not this unit suite).

## 8. Contradictions and ambiguities in docs/20's audio section - named, not resolved

Per this task's instruction, these are flagged rather than silently decided:

1. **Exact bus count is stated two different ways.** docs/20's own prose ("Audio Bus
   Hierarchy") lists `Master -> Music, SFX, SFX_Priority, UI, Ambience` (5 children,
   6 with Master) and adds `TowerCue` as a separate detail under "Tower Cue Player"
   ("a sixth bus, `TowerCue`"). The Provisional Values Register's own "Buses" row
   writes *"Master → Music, SFX, SFX_Priority (← TowerCue), UI, Ambience — six buses
   (C-TOWERCUE)"* - which, read literally, counts only Master+5 as "six," with TowerCue
   parenthetical and not part of the count. PLAN.md's P1.6 task-table row instead lists
   *"the six audio buses (Music, SFX, SFX_Priority, TowerCue, UI, Ambience; C-TOWERCUE)"*
   - six non-Master names that explicitly include TowerCue, implying **seven** buses
   total with Master. This implementation follows PLAN.md's explicit enumeration
   (7 total, TowerCue counted as its own bus) since it is the only phrasing that lists
   every bus by name without ambiguity, and it matches every routing detail docs/20
   states elsewhere (TowerCue sends to SFX_Priority, not Master; carries its own
   effect) - but the Register's "six buses" phrasing, read in isolation, could be
   misread as a 6-bus total that excludes TowerCue. Not resolved by an author decision
   here; flagged for whoever reconciles the Register's wording.
2. **How "a sound plays on SFX_Priority" is detected is unspecified.** `AudioServer`
   exposes no boolean "is this bus outputting audio" query, only a peak-volume meter.
   Resolved here with an explicit start/stop notification API on the ducking node
   (section 4) rather than bus polling - a design decision this implementation made,
   not one docs/20 states.
3. **The attack/release ramp's curve shape is unspecified.** "50 millisecond attack and
   a 300 millisecond release" states durations, not a curve. This implementation uses a
   linear ramp (standard attack/release envelope semantics) rather than an exponential/
   time-constant curve; docs/20 does not say which was intended.
4. **How the Music floor combines with the duck amount is unspecified.** "Music ducks by
   6 dB ... floored at -18 dB" is read here as `max(base_music_db - 6.0, -18.0)` - an
   absolute clamp on the *ducked* result, so a Music bus already near -18 dB (e.g. from a
   future user volume setting) ducks by less than 6 dB rather than going below the
   floor. An equally plausible alternative reading is a floor on the *base* volume
   before ducking, which would behave differently when a settings-driven base volume is
   introduced later; docs/20 does not distinguish between the two.
5. **Whether the general 32-voice steal rule may target an active priority voice is not
   stated.** docs/20 gives one unified sentence for the general rule ("*the pool steals
   the lowest-priority voice, then the oldest, to make room for a new sound*") with no
   carve-out protecting priority voices from it. This implementation applies the general
   rule uniformly across all 32 voices, priority or not - a priority voice is only
   specially protected by the separate 8-slot cap rule, not by the general rule. In
   practice a priority voice's higher priority value should usually protect it under the
   general "lowest first" ordering, but nothing in docs/20 makes that a guarantee.

## 9. Summary for the caller

Files created: listed in section 1. Bus graph: 7 buses (Master + Music, SFX,
SFX_Priority, UI, Ambience, TowerCue), routed and verified against the live
`AudioServer` per section 2.1; layout resource at project root, reasoning in 2.2.
Ducking node clock: real per-frame `_process(delta)`, not `SimClock` - full reasoning in
section 4. Pool stealing algorithm: two independent rules (general lowest-then-oldest;
priority-cap oldest-only), section 3. Acceptance test: 44 gdUnit4 tests under
`tests/unit/audio/`, full suite exit 0 (44/44) on a clean tree; both falsification
mutations produced exit 100 with the failure named precisely, and restoration was
verified clean by diff before the final green run (section 6). Headless coverage limits:
section 7. Ambiguities in docs/20 flagged rather than silently resolved: section 8.

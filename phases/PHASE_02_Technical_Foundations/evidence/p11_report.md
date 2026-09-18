# P1.1 Evidence Report — SimClock, PauseAuthority, SimLoop, Keyed RNG, Banned-API Check

Plan ID: P1.1 (`phases/PHASE_02_Technical_Foundations/PLAN.md` § "P1.1"). This
document records what was built, which document rule each part implements,
both named acceptance tests with commands/exit codes/falsification logs, the
Settings check update and its two falsifications, how the banned-API check
distinguishes gameplay/cosmetic/UI use, and every contradiction found in the
source documents. It does not assert that any gate is passed, satisfied, or
ready — that is for reviewers and the author (CLAUDE.md; phases/README.md
loop rule (e)).

## GodotPrompter skills consulted

`godot-prompter:gdscript-patterns` and `godot-prompter:dependency-injection`
were invoked before writing any code, per CLAUDE.md's GodotPrompter section.

- `gdscript-patterns`: static typing throughout (all vars, params, return
  types; typed `Array[String]`, `Array[StringName]`, `Dictionary`), a
  clamped/validated property setter for `SimClock.time_scale`, `match`-free
  since no state machine was needed here. Followed directly, no conflict.
- `dependency-injection`: "Autoloads... Truly global singletons: audio,
  settings, platform services" and "resist autoloading domain-specific
  systems" — SimClock and PauseAuthority are exactly the kind of
  project-wide, every-scene-needs-it service the skill recommends an
  autoload for, so no conflict with the master's own choice to make them
  Autoloads. No conflict found between either skill and this project's
  documents in this task's scope; nothing to add to the phase LEDGER on
  that account.

## What was built

| File | Document rule it implements |
| --- | --- |
| `src/core/sim_clock.gd` | Autoload, `PROCESS_MODE_PAUSABLE`. Accumulates `now += physics_step * time_scale` every unpaused physics tick (MASTER_SDLC.md > Global Simulation Authority, paragraph 1). `time_scale` is a clamped property (`[0.25, 1.0]`, docs cited below); nothing calls it yet, matching "time_scale is always 1.0 in the prototype." |
| `src/core/pause_authority.gd` | Autoload, `PROCESS_MODE_ALWAYS`. Sole writer of `get_tree().paused`; holds a reason set; unpauses only when empty; `push_reason()`/`pop_reason()` only queue, `flush()` applies — matching "every pause and unpause request is applied by PauseAuthority at the end of the tick it was requested on, never mid-tick" (Global Simulation Authority > Pause Rules). `push_reason_immediate()`/`pop_reason_immediate()` exist for the Focus Loss Rule's "applies immediately" case. Emits `reasons_changed`. |
| `src/core/sim_loop.gd` | Drives the fixed fifteen-step per-tick order (docs/20 > "SimLoop order"). See the step-by-step table below. Not registered as an autoload — see "Contradictions and interpretation calls" #2. |
| `src/core/keyed_rng.gd` | `class_name KeyedRng`, `extends RefCounted`. `KeyedRng.rng_for([run_seed, purpose, roll_id])` / `KeyedRng.seed_for(...)` implement "every system that rolls... derives its RandomNumberGenerator seed by hashing the run seed with a fixed per-purpose key and, where relevant, a per-roll identifier" (MASTER_SDLC.md > Determinism where it matters). Uses a hand-rolled FNV-1a 32-bit hash over a canonical, separator-joined string rather than Godot's built-in `hash()`, so the seed's bit pattern is defined by this file, not an unspecified engine internal. |
| `tools/checks/banned_api_check.sh` | Bans `get_tree().create_tween()` / `get_tree().create_timer()` under the gameplay root (PLAN.md P1.1 exit criterion). See "Banned-API check" section below. |
| `project.godot` | Registers `SimClock` and `PauseAuthority` as autoloads (autoload section only touched). |
| `tests/settings_check.gd` | Widened `AUTOLOADS` and added a per-autoload `AUTOLOAD_PATHS` manifest — see "Settings check" section. |
| `tests/unit/pause_clock_test.gd`, `tests/unit/keyed_rng_test.gd`, `tests/unit/sim_loop_order_test.gd` | gdUnit4 suites — see "Acceptance tests" section. |

### SimLoop step order, as implemented against docs/20's list

docs/20 > Godot 4.x Implementation Standards > "SimLoop order" lists fifteen
steps. `src/core/sim_loop.gd`'s `_physics_process()` calls fifteen private
methods in this exact order, each named after its step:

| # | docs/20's step | Implemented as | Status |
| --- | --- | --- | --- |
| 1 | input | `_step_01_input()` | stub, extension point for P2.1 |
| 2 | player movement | `_step_02_player_movement()` | stub, P2.1 |
| 3 | enemy AI and movement | `_step_03_enemy_ai_and_movement()` | stub, P1.5/later |
| 4 | weapon targeting and firing (player, then Tower) | `_step_04_weapon_targeting_and_firing()` | stub, P2.4/P2.5 |
| 5 | projectile movement and sweep (enqueue hits) | `_step_05_projectile_movement_and_sweep()` | stub; `enqueue_hit()` is the extension point |
| 6 | wind-up completion and contact ticks (enqueue hits) | `_step_06_windup_completion_and_contact_ticks()` | stub; `enqueue_hit()` is the extension point |
| 7 | hit queue sorted by (target serial, attacker serial), player serial 0, Tower serial 1 | `_step_07_hit_queue_resolution()` | **implemented**: `_hit_queue.sort_custom(_hit_less_than)`, snapshotted for tests, then cleared |
| 8 | death resolution: Tower, bosses, player, other enemies | `_step_08_death_resolution()` | stub, P1.5 |
| 9 | drops | `_step_09_drops()` | stub, P1.3/P2.8 |
| 10 | pickup movement and collection | `_step_10_pickup_movement_and_collection()` | stub, P2.8 |
| 11 | XP and level-up requests | `_step_11_xp_and_level_up_requests()` | stub, P2.10/P2.12 |
| 12 | Console channel completion | `_step_12_console_channel_completion()` | stub, P2.13 |
| 13 | Wave Director | `_step_13_wave_director()` | stub, P2.8 |
| 14 | `PauseAuthority.flush()` | `_step_14_pause_flush()` | **implemented**: calls the real `PauseAuthority` autoload |
| 15 | UI state | `_step_15_ui_state()` | stub, later UI tasks |

Only steps 7 and 14 have real logic, because they are the only two steps
whose inputs are fully specified by P1.1's own deliverables (the hit-queue
sort rule and PauseAuthority itself). Every other step is an empty, named,
documented method so a later task's system call goes inside it without
touching the order — "the order itself is the deliverable" (task brief).
Verified by `tests/unit/sim_loop_order_test.gd` (supplementary coverage, not
one of the two named P1.1 acceptance tests): one test asserts the exact
fifteen-name call order for a single tick; a second enqueues four synthetic
hits and asserts step 7 sorts them to `(target 0, attacker 3), (target 1,
attacker 9), (target 2, attacker 1), (target 2, attacker 5)`.

### Banned-API check: how it distinguishes gameplay, cosmetic, and UI use

`tools/checks/banned_api_check.sh` greps `.gd` files under `src/` and
`scenes/` (excluding any `ui/` path segment) for two patterns only:
`get_tree()\s*\.\s*create_tween\s*\(` and `get_tree()\s*\.\s*create_timer\s*\(`.

The distinction it encodes, taken directly from the master ("`Node.create_tween()`
is permitted for cosmetic animation only... All of these remain permitted in
pure UI"):

1. **Banned everywhere under the gameplay root**: any call *anchored on
   `get_tree()`* — `get_tree().create_tween()` and `get_tree().create_timer()`.
   Neither scales with `SimClock.time_scale` nor reliably pauses with the
   gameplay tree.
2. **Not banned**: a bare `create_tween()` (Node's own method, called on
   `self` or another Node, never routed through `get_tree()`). The master
   permits this for cosmetic animation only. Whether a *specific* bare
   `create_tween()` call is genuinely cosmetic or is secretly driving
   gameplay timing is a semantic judgement a grep cannot make — the check
   therefore encodes only the **textual** distinction the master itself
   draws (SceneTree-anchored vs. the bare Node method) and leaves the
   cosmetic-vs-gameplay correctness call to human/reviewer judgement and the
   `godot-code-review` skill. This is stated explicitly in the script's own
   header so a green result is never read as "every bare `create_tween()`
   here is definitely cosmetic."
3. **`create_timer()` has no cosmetic exception to carve out**: there is no
   Node-level equivalent of `SceneTreeTimer` (it only ever comes from
   `SceneTree.create_timer()`), so `get_tree().create_timer()` is banned
   unconditionally under the gameplay root.
4. **Pure UI is exempt entirely**: any path containing a `ui/` directory
   segment (`src/ui/`, `scenes/ui/`) is excluded via `grep -Ev '(^|/)ui/'`,
   matching "all of these remain permitted in pure UI, which is not bound by
   SimClock." Verified this matches only a real `ui/` directory segment, not
   any filename merely containing the substring "ui" — see the falsification
   log below.

**Known limitation, stated in the script's own header**: this is a raw-text
grep, not GDScript-aware, so it does not strip comments or string literals.
A comment that literally contains the banned pattern text will also be
flagged (reproduced below). This is a deliberate conservative bias (false
positives over false negatives), consistent with a lint-style check.

**Exit codes**: 0 = zero banned calls found under an existing, non-empty
scan scope. 1 = at least one found. 2 = neither `src/` nor `scenes/` exists
at all (misconfiguration, never read as a pass).

**Falsification log** (all commands run from `D:\Gamedev`):

Clean tree:
```
$ bash tools/checks/banned_api_check.sh
Banned-API check: PASS (0 banned calls under src scenes, excluding ui/ directories)
$ echo $?
0
```

Injected `src/core/_tmp_banned_fixture.gd` (a temporary fixture file, inside
my permitted `src/core/*.gd` write scope) containing
`get_tree().create_timer(1.0).timeout.connect(...)` and
`get_tree() . create_tween()` (whitespace-tolerant variant):
```
$ bash tools/checks/banned_api_check.sh
Banned-API check: FAIL
src/core/_tmp_banned_fixture.gd:4:# Deliberately violates the ban: get_tree().create_timer() under src/.
src/core/_tmp_banned_fixture.gd:6:	get_tree().create_timer(1.0).timeout.connect(func(): pass)
src/core/_tmp_banned_fixture.gd:7:	get_tree() . create_tween()
Banned-API check: 3 banned call(s) found under the gameplay root (src scenes, excluding ui/ directories).
$ echo $?
1
```
(Note line 4 is the fixture's own explanatory *comment*, not code — exactly
the raw-text-grep limitation named above, caught in the act.)

Restored (fixture moved out of the repo, never deleted — see "Compliance
note" below):
```
$ bash tools/checks/banned_api_check.sh
Banned-API check: PASS (0 banned calls under src scenes, excluding ui/ directories)
$ echo $?
0
```

`ui/`-exemption check: rather than write a second fixture under
`src/ui/` (outside this task's permitted write scope — see the compliance
note below), the exclusion regex was verified against synthetic path strings
with no repo file involved:
```
$ printf '%s\n' \
  'src/ui/menu.gd:5:get_tree().create_tween()' \
  'src/ui/menu.gd:6:get_tree().create_timer(1.0)' \
  'scenes/ui/hud.gd:2:get_tree() . create_tween()' \
  'src/tower/tower_ui_panel.gd:9:get_tree().create_tween()' \
  | grep -Ev '(^|/)ui/'
src/tower/tower_ui_panel.gd:9:get_tree().create_tween()
```
Both real `ui/`-directory paths were correctly filtered out; the one path
that merely *contains* the substring "ui" in a filename
(`tower_ui_panel.gd`, not a `ui/` directory segment) was correctly kept —
proving the exclusion matches a real path segment, not a substring.

**Compliance note (self-reported)**: while building this falsification I
initially wrote a UI-exemption fixture to `src/ui/_tmp_ui_fixture.gd` —
`src/ui/` is not in this task's permitted write scope (`src/core/*.gd`,
`tests/unit/**`, `tests/settings_check.gd`, `project.godot` (autoload only),
`tools/checks/**`, this report). It was moved out of the repository
immediately via `mv` (never deleted, per the hard constraints) to the
session scratchpad directory, and `src/ui/` was confirmed to contain only
its original `.gitkeep` again before continuing. The UI-exemption
verification above was then redone with no repo file involved. Flagging
this plainly rather than omitting it.

**"Under the gameplay root" — an interpretation call, not a restatement**:
docs/20 > Scene Tree describes the gameplay root's container layout
(`Entities`, `Projectiles`, `Pickups`, `Effects`, `Environment`, `Audio`),
but that scene does not exist yet — `scenes/main.tscn` is a bare `Node2D`
(PLAN.md's own entry-conditions correction, F02-01), and building it is
P1.3's deliverable. A static grep cannot walk a node hierarchy that does not
exist. This check therefore operationalises "the gameplay root" as every
`.gd` file under `src/` and `scenes/` except any `ui/` path segment — the
closest static equivalent available now, widening automatically as later
phases add gameplay directories (`src/enemy`, `src/tower`, ...). This is
recorded here as an interpretation, per the task brief's instruction to name
any place the documents do not state something directly.

## Settings check update

`tests/settings_check.gd`'s `AUTOLOADS` constant widened from `["BootCheck"]`
to `["BootCheck", "SimClock", "PauseAuthority"]`; the single `BOOTCHECK_PATH`
constant was replaced with an `AUTOLOAD_PATHS` dictionary mapping all three
names to their expected scripts, and section 6's logic now checks **every**
expected autoload's target path (not just BootCheck's) — an independent
manifest transcribed from the owning documents, not read back from the
autoloads themselves (Phase 02 carried lesson 2).

Baseline, after registering the two new autoloads in `project.godot`:
```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://tests/settings_check.gd
Settings check: PASS (16 layers, 24 actions asserted of 115 input entries present, 8 settings, 3 autoload(s), templates 4.7.1.stable)
$ echo $?
0
```

**Falsification (a) — rogue extra autoload.** Temporarily added
`RogueAutoload="*res://src/core/sim_clock.gd"` to `project.godot`'s
`[autoload]` section:
```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://tests/settings_check.gd
Settings check FAILURE: unexpected autoload/* entry(ies) present: ["RogueAutoload"]
Settings check: FAIL (1 problems)
$ echo $?
1
```
Restored (line removed); re-ran; **PASS, exit 0** (identical to baseline
above).

**Falsification (b) — missing expected autoload.** Temporarily removed the
`PauseAuthority=...` line from `project.godot`:
```
$ /d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://tests/settings_check.gd
Settings check FAILURE: expected autoload/* entry(ies) missing: ["PauseAuthority"]
Settings check: FAIL (1 problems)
$ echo $?
1
```
Restored (line re-added); re-ran; **PASS, exit 0** (identical to baseline
above). `project.godot`'s final `[autoload]` section:
```
BootCheck="*res://src/core/boot_check.gd"
SimClock="*res://src/core/sim_clock.gd"
PauseAuthority="*res://src/core/pause_authority.gd"
```

## Acceptance tests

Both suites live under `tests/unit/` (not `tests/harness/`). Command used
throughout (import pass first, then the suite):
```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . --import
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode
```
Note: `tests/unit/` is shared with a concurrently-running implementer's P1.6
(audio) work (`tests/unit/audio/*`, untracked, not part of this task); the
totals below include their 44 test cases alongside my 13. I did not touch
their files. Clean baseline for the whole directory: **57 test cases, 0
errors, 0 failures, exit 0**.

### Pause clock unit check (`tests/unit/pause_clock_test.gd`, 5 tests)

Covers: `SimClock.now` stops advancing under pause and resumes exactly (no
drift, no lost/double-counted tick across the boundary), and the end-of-tick
application rule (a pause requested mid-tick does not take effect until
`flush()`). Also covers multi-reason unpause-only-when-empty and
`reasons_changed` emission, as supplementary coverage of the same file.

Clean run (subset from the full-directory run above):
```
res://tests/unit/pause_clock_test.gd > test_now_advances_each_unpaused_physics_tick PASSED
res://tests/unit/pause_clock_test.gd > test_now_stops_under_pause_and_resumes_exactly PASSED
res://tests/unit/pause_clock_test.gd > test_push_reason_does_not_pause_until_flush PASSED
res://tests/unit/pause_clock_test.gd > test_unpauses_only_when_reason_set_is_empty PASSED
res://tests/unit/pause_clock_test.gd > test_flush_emits_reasons_changed_only_on_actual_change PASSED
```

**Falsification.** Injected, in `src/core/sim_clock.gd`'s `_ready()`:
`process_mode = Node.PROCESS_MODE_ALWAYS` in place of `PROCESS_MODE_PAUSABLE`
— the exact `PROCESS_MODE_ALWAYS` leakage the Risk Register names as the
mechanism for "partial pause bugs the design bans." Ran the full
`tests/unit` directory (documented command above):
```
res://tests/unit/pause_clock_test.gd > test_now_advances_each_unpaused_physics_tick PASSED
res://tests/unit/pause_clock_test.gd > test_now_stops_under_pause_and_resumes_exactly FAILED
  Expecting:
 0.033333
 but was
 0.083333	at 'test_now_stops_under_pause_and_resumes_exactly' in res://tests/unit/pause_clock_test.gd:70
  Expecting:
 0.116667
 in range between
 0.066666 <> 0.066668	at 'test_now_stops_under_pause_and_resumes_exactly' in res://tests/unit/pause_clock_test.gd:80
Overall Summary: 54 test cases | 0 errors | 2 failures | 0 flaky | 0 skipped | 0 orphans |
```
`echo $?` → **100**. The check went red naming exactly the injected defect:
`now` kept accumulating while `get_tree().paused` was true (0.083333 vs. the
expected 0.033333 — three extra ticks' worth of drift), and the post-resume
value inherited that drift. Reverted `process_mode` to
`Node.PROCESS_MODE_PAUSABLE`; re-ran the full directory: **57 test cases, 0
errors, 0 failures, exit 0** (identical to the clean baseline).

*Runner-behaviour note*: after the second test's failure, gdUnit4's CLI did
not execute the remaining 3 tests in that same suite file (54 = 57 − 3 for
this run), while every *other* suite file still ran in full (`Executed test
suites: (8/8)`). No error, crash, or timeout was logged for this. I could
not find a project-level gdUnit4 config causing it (no `GdUnitRunner.cfg` is
present anywhere in the repo; `GdUnitRunnerConfig.gd`'s own
`EXIT_FAIL_FAST` defaults to `false`). Reporting the observed behaviour,
not a guessed cause (Phase 02 carried lesson 3: no cause without an
experiment) — it does not affect the validity of this falsification, since
the one test that matters (`test_now_stops_under_pause_and_resumes_exactly`)
did run and did fail with the correct diagnosis both times I triggered it
(once alone, once in the full-directory run above).

### Keyed RNG unit check (`tests/unit/keyed_rng_test.gd`, 6 tests)

Covers: same-key rolls reproduce identically across 10 of 10 repetitions,
and different keys (different run seed, different purpose key, different
roll id) diverge — the divergence tests are what a constant-returning
generator would fail, per the master's own warning in the test description.
Also covers seed determinism directly and a part-boundary collision guard
(`[1, "23"]` vs. `[12, "3"]`).

Clean run:
```
res://tests/unit/keyed_rng_test.gd > test_same_key_reproduces_identically_10_of_10 PASSED
res://tests/unit/keyed_rng_test.gd > test_seed_is_deterministic_across_calls PASSED
res://tests/unit/keyed_rng_test.gd > test_different_run_seed_diverges PASSED
res://tests/unit/keyed_rng_test.gd > test_different_purpose_key_diverges PASSED
res://tests/unit/keyed_rng_test.gd > test_different_roll_id_diverges PASSED
res://tests/unit/keyed_rng_test.gd > test_part_boundary_does_not_collide PASSED
```

**Falsification.** Replaced `src/core/keyed_rng.gd`'s `seed_for()` body with
`return randi() % 0x100000000` — ignoring `parts` entirely and reseeding
randomly on every call, exactly the degenerate implementation the master's
own test description warns a same-key-only test would miss. Ran the full
`tests/unit` directory:
```
res://tests/unit/keyed_rng_test.gd > test_same_key_reproduces_identically_10_of_10 FAILED
  repetition 1 of 10 diverged from the reference sequence for the same key
  repetition 2 of 10 diverged from the reference sequence for the same key
  repetition 3 of 10 diverged from the reference sequence for the same key
  repetition 4 of 10 diverged from the reference sequence for the same key
  repetition 5 of 10 diverged from the reference sequence for the same key
  repetition 6 of 10 diverged from the reference sequence for the same key
  repetition 7 of 10 diverged from the reference sequence for the same key
  repetition 8 of 10 diverged from the reference sequence for the same key
  repetition 9 of 10 diverged from the reference sequence for the same key
  repetition 10 of 10 diverged from the reference sequence for the same key
Overall Summary: 52 test cases | 0 errors | 10 failures | 0 flaky | 0 skipped | 0 orphans |
```
`echo $?` → **100**. All 10 of 10 repetitions were reported as diverging —
the check named the exact failure the acceptance criterion itself describes
("keyed rolls identical 10 out of 10 repetitions"). (The remaining 5 tests
in this suite file did not execute this run, same runner behaviour as
above — 52 = 57 − 5.) Restored `seed_for()`; re-ran the full directory:
**57 test cases, 0 errors, 0 failures, exit 0** (identical to the clean
baseline). Confirmed both files byte-restored (`grep -n
"process_mode = Node.PROCESS_MODE_PAUSABLE" src/core/sim_clock.gd`,
`grep -n "FALSIFICATION" src/core/sim_clock.gd src/core/keyed_rng.gd`
returned no falsification markers).

## Contradictions and interpretation calls found in the documents

Per the task brief: named here, not silently resolved.

1. **`tools/` is entirely gitignored, but this task's own delegation
   authorizes writing the grep check to `tools/checks/**`.** `.gitignore`
   line 32 is a bare `tools/` — it excludes the whole directory, not just
   `tools/mcp/` (which CLAUDE.md's Tools section names specifically as
   gitignored "because npx on this machine cannot install commit-pinned git
   specs"). `tools/checks/banned_api_check.sh` therefore will **not** be
   tracked by git and will not appear in `git status` or any future commit,
   even though CLAUDE.md's own project-wide rule says "once the repository
   exists, commit documentation and implementation changes together." A
   check nobody can rely on being present after a fresh clone is a real
   gap. I did not edit `.gitignore` (not in this task's permitted write
   scope) or move the script elsewhere (the delegation names `tools/checks/**`
   specifically). Flagging for the orchestrator to resolve — e.g. an
   exception line (`!tools/checks/`) in `.gitignore`, or relocating the
   check to a tracked path in a future task.
2. **Whether `SimLoop` is an Autoload.** MASTER_SDLC.md's Global Simulation
   Authority section explicitly calls `SimClock` and `PauseAuthority`
   Autoloads ("owned by a `SimClock` Autoload," "owned by a `PauseAuthority`
   Autoload"), but never uses that word for `SimLoop` — it only says "a
   `SimLoop` node drives gameplay once per physics tick" (Determinism where
   it matters). PLAN.md P1.1 lists `sim_loop.gd` as a deliverable file path
   alongside the two autoloads without stating its registration. Since the
   gameplay root scene `SimLoop` would naturally live under does not exist
   yet (P1.3's deliverable), I made the call **not** to register `SimLoop`
   as an autoload; it is a plain `Node` script with a clear, tested
   fifteen-step order, meant to be instantiated once under the gameplay
   root when P1.3 builds it. Recorded here as an interpretation, not a
   restatement of something the master states directly.
3. **The task brief's "the clamp (never below 0.25, hit-stop capped at
   120 ms)" bundles two mechanisms the master itself keeps separate.**
   MASTER_SDLC.md > Global Simulation Authority > "Game-feel time effects"
   draws a hard line: hit stop is "a visual-only effect
   (`AnimationPlayer.speed_scale`, sprite effects) capped at 120
   milliseconds" and is explicitly **not** implemented through
   `time_scale` at all; only slow motion touches `time_scale`, "no lower
   than 0.25 for at most 120 milliseconds of real time." I implemented
   only the `time_scale`-side rule in `SimClock` (the 0.25 floor via the
   property setter's `clampf()`, and a ≤120 ms-of-real-time auto-revert on
   any reduction, via `Time.get_ticks_msec()` — deliberately not
   `SimClock.now`, since the window is bounded in wall-clock time even
   though it slows simulation time). Hit stop's own `AnimationPlayer`-based
   120 ms cap is **not** implemented anywhere in this task — no
   `AnimationPlayer` or hit-stop system exists yet, and the master says it
   is a different mechanism entirely. Flagging so nobody reads
   `SimClock`'s clamp as also covering hit stop.
4. **"Under the gameplay root" for the banned-API check has no scene to
   walk yet.** See the dedicated call-out in the Banned-API check section
   above — docs/20's container-node gameplay root does not exist until
   P1.3, so the check is scoped to source directories (`src/`, `scenes/`,
   excluding `ui/`) instead, as the closest static equivalent.

## Never asserted

This report does not claim any gate, check, or acceptance test is "passed,"
"satisfied," or "ready" in the sense CLAUDE.md and phases/README.md reserve
for reviewers and the author. It records exact commands, exit codes, and
verbatim output for every run performed, both green and red.

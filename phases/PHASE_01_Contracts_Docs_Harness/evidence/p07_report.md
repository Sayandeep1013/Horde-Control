# P0.7 - Test harness: implementer evidence report

**Scope.** Configure the headless gdUnit4 test harness in the real project, per PLAN.md
P0.7 steps 1-8, NEXT_SESSION.md > "Facts Phase 01 must not re-derive", and the hard
constraints in this task's prompt (Phase 00 finding F-06: the `ask` permission gate does
not intercept subagents). This report records what was done and what was directly
observed; it does not assert that any gate is passed, satisfied, or ready.

---

## 1. gdUnit4 version and where it came from

Copied with `cp -r` from `D:\Gamedev\sandbox\connection_test\addons\gdUnit4` to
`D:\Gamedev\addons\gdUnit4` (no files under `sandbox/` were modified; the copy is a plain
read + write, not a move). `addons/gdUnit4/bin/GdUnitCmdTool.gd` and
`addons/gdUnit4/plugin.cfg` both exist in the real project after the copy.

`plugin.cfg`, read back from the real project (`D:\Gamedev\addons\gdUnit4\plugin.cfg`),
verbatim:

```
[plugin]

name="gdUnit4"
description="Unit Testing Framework for Godot Scripts"
author="Mike Schulze"
version="6.2.1"
script="plugin.gd"
```

Version 6.2.1, matching the sandbox and NEXT_SESSION.md's pin. The addon is ~2.0 MB
across 516 files (`du -sh addons/gdUnit4` / `find addons/gdUnit4 -type f | wc -l`).

Now hosted at `godot-gdunit-labs/gdUnit4` per the org migration recorded as finding F-12;
this report does not independently re-verify that migration (NEXT_SESSION.md already
flags it for a human eyeball, not an agent one).

## 2. Was enabling the plugin required? No - verified empirically, not assumed

`addons/gdUnit4/plugin.gd`'s `_enter_tree()` (the `EditorPlugin` entry point that only
runs when the plugin is *enabled* in `project.godot`) calls
`check_running_in_test_env()` and returns immediately without installing anything if
`DisplayServer.get_name() == "headless"` or the command line carries `-a`/`--import`/etc.
Separately, `addons/gdUnit4/bin/GdUnitCmdTool.gd` (the script the verified invocation
loads via `-s`) is a `SceneTree`-derived main-loop script that instantiates
`GdUnitTestCIRunner` directly - it does not go through the `EditorPlugin` at all.

This was tested directly, not inferred from reading the source alone. The real
project's `project.godot` carries no `[editor_plugins]` section (confirmed by reading
the file both before and after this task; it was never added). All three headless runs
below (exit 0, exit 100, exit 103) were made with the plugin **not** enabled, and gdUnit4
ran and reported correctly every time. So: **enabling the plugin is not required for
headless CLI running**, and per the task's own instruction not to add a project setting
the harness does not need, `project.godot` was left untouched.

**`project.godot` diff: none.** No lines were added, removed, or changed in
`project.godot` by this task.

(Note for later, out of this task's scope: a human wanting gdUnit4's in-editor dock/
inspector for interactive use would still need to enable the plugin themselves; that is
a separate need from the headless CLI harness this task configures.)

## 3. Test layout chosen and why

```
tests/harness/pass/test_trivial_pass.gd   extends GdUnitTestSuite, asserts true
tests/harness/fail/test_trivial_fail.gd   extends GdUnitTestSuite, asserts a false condition
```

Two separate directories, exactly as PLAN.md step 5 suggests, so a run can point `-a` at
one without sweeping in the other: `-a res://tests/harness/pass` demonstrates exit 0 in
isolation, `-a res://tests/harness/fail` demonstrates exit 100 in isolation. The failing
suite is a **permanent, deliberate fixture** - it exists only to prove the harness can
report a real failure, and it must never be included in a default/CI sweep of `tests/`,
since it would then fail every run forever. `tests/run_tests.ps1` (section 6) defaults
its scan path to `res://tests/harness/pass` for exactly this reason, not to all of
`res://tests`.

Both files follow gdUnit4 convention: `extends GdUnitTestSuite`, filename `test_*.gd`,
method `test_*`.

## 4. Exit-code table

All four commands were run from `D:\Gamedev` via the Bash tool, against the pinned
console executable. `--import` was run once before the suite commands, per PLAN.md step
1 / the verified invocation's precondition.

| Exit code | Command | Observed exit | Verbatim tail of output |
| --- | --- | --- | --- |
| 0 (pass) | `Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/pass --ignoreHeadlessMode` | **0** | `Overall Summary: 1 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans \| ` / `Executed test suites: (1/1)` / `Executed test cases : (1/1)` / `Exit code: 0` |
| 100 (assertion failure) | `Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/fail --ignoreHeadlessMode` | **100** | `Expecting: 'false' but is 'true' at 'test_false_condition_fails' in res://tests/harness/fail/test_trivial_fail.gd:12` / `Overall Summary: 1 test cases \| 0 errors \| 1 failures \| ...` / `Exit code: 100` |
| 103 (`--ignoreHeadlessMode` missing) | `Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/pass` (flag omitted) | **103** | `Headless mode is not supported!` / `You can run with '--ignoreHeadlessMode' to swtich off this check.` / `Abnormal exit with 103` |
| 1 (import pass not run) | **not reproduced - see below** | **not reproduced** | **not reproduced** |

**Exit code 1 was not reproduced, and no result is invented for it.** The only trigger
this project or upstream documents for that code is a project state where gdUnit4's
class hierarchy (`GdUnitTestSuite` and friends) has not been resolved into Godot's
global script-class cache, which is what `--import` (or an editor scan) builds. This
project's `.godot/global_script_class_cache.cfg` already carries 368 GdUnit-related
entries as of this task's own `--import` run (`grep -c "GdUnit"
.godot/global_script_class_cache.cfg`), because this repository's `.godot/` cache is not
fresh - it has been built up across every prior session and phase. Reproducing "the
import pass was not run" cleanly would require either deleting that cache (or the whole
`.godot/` directory) to force a genuinely unimported state, or standing up a second,
separate project copy to get a fresh one. Both are outside what this task is permitted to
do: the hard constraints forbid deleting any file, and the permitted write scope for this
task does not extend to creating a second project. I am reporting this as **not
reproduced** rather than fabricating an exit code or a captured output tail for it.

## 5. Export hygiene

**Investigated, but the fix is outside this task's write scope - flagged, not silently
worked around.**

The mechanism: Godot 4's export system honors `.gdignore` at the *editor/engine resource
scan* level, not just in the editor GUI - a directory carrying `.gdignore` is invisible
to the engine's own resource discovery, which is exactly why this repository already
relies on it for `tools/.gdignore` and `sandbox/.gdignore` (per NEXT_SESSION.md): those
two directories are never loaded by anything at runtime, so hiding them from the
resource scanner costs nothing. `addons/gdUnit4/` is different: the headless harness
loads `res://addons/gdUnit4/bin/GdUnitCmdTool.gd` and everything it pulls in *through
that same resource scanner*, at the exact same headless invocation this harness depends
on. A `.gdignore` at the root of `addons/gdUnit4/` would make the engine skip the
directory outright, which - per this task's own explicit warning - breaks the harness
itself. I did not create one, and did not experiment with one, since the hard
constraints forbid deleting any file and I would have no way to safely undo a
`.gdignore` that turned out to break test discovery. (For context: gdUnit4 upstream
itself already ships one narrow, pre-existing `.gdignore` at
`addons/gdUnit4/src/reporters/html/template/.gdignore`, scoped only to its static HTML
report template assets, not the addon root - consistent with this same rule, and not
something this task added or touched.)

The actual Godot-native mechanism for "keep a resource-scanned directory out of the
packed build without hiding it from the engine" is the export preset's `exclude_filter`
(`export_presets.cfg`), which is independent of `.gdignore` and does not affect what the
engine can load headlessly. The current preset (`[preset.0]`, "Windows Desktop") has
`export_filter="all_resources"` and `exclude_filter=""` - nothing is excluded today, so
both `addons/gdUnit4/` (~2.0 MB) and `tests/` (~25 KB, plus the harness's own report
output - see below) would ship in a release build unchanged.

**I did not edit `export_presets.cfg`.** This task's hard constraints list an explicit,
narrow write scope - `addons/gdUnit4/`, `tests/`, this report, and `project.godot` only
conditionally - and `export_presets.cfg` is not in it. Rather than stretch that scope on
my own judgment, I am flagging this precisely so the orchestrator can route it to
whichever agent is authorized to touch export configuration:

**Recommended fix** (for someone with that authority to apply and a reviewer to check,
not applied by this task): set
`exclude_filter="addons/gdUnit4/*, tests/*, reports/*"` in `export_presets.cfg`'s
`[preset.0]` section. Godot's export-filter glob (`String.match`) treats `*` as matching
across path separators, so a single `*` per prefix should exclude each directory
recursively; a reviewer should confirm that against the live 4.7.1 export dialog before
trusting it blind.

**Bonus finding, same category:** gdUnit4's default report directory is
`res://reports/` (its own `-rd, --report-directory` option documents this default), and
every one of this task's demonstration runs wrote there - `reports/report_1` through
`reports/report_4` now exist at the project root, none of them gitignored today. These
are a side effect of running the verified invocation exactly as specified (no `-rd`
override was used, to keep the demonstrated commands identical to the one this project
verified twice); I did not delete them (forbidden), and `reports/` is not in this task's
write scope either. This should be swept into the same `exclude_filter` fix above (already
included in the recommended line) and into `.gitignore` (also outside this task's write
scope).

**Command the orchestrator should run to verify export hygiene**, once
`export_presets.cfg` carries the fix above (do not run this yourself if you are also
bound by the no-export constraint - this needs an agent/human permitted to export):

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" builds/windows/HordeControl.exe --verbose > export_log.txt 2>&1
grep -i "gdUnit4\|res://tests/\|res://reports/" export_log.txt
```

A clean pass is **zero matches** in that grep (Godot's verbose export log lists each
file it stores into the PCK; none of the three paths should appear). As a second,
independent check, compare the resulting `.exe`+`.pck` size against a baseline taken
before the fix - Phase 00's own prior finding was that unexcluded tooling added roughly
11 MB to a release build, so a multi-MB drop after this fix is the expected signal.

## 6. `tests/run_tests.ps1` behaviour and demonstration

The script (Windows PowerShell 5.1 syntax, `-GodotPath` defaulting to the pinned console
path, `-TestPath` defaulting to `res://tests/harness/pass`):

1. Runs the import pass (`--headless --path <root> --import`). A non-zero import exit
   prints "IMPORT FAILED" and the script exits **1**, without attempting the suite.
2. Runs the verified invocation (`--headless --path <root> -s
   res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a <TestPath> --ignoreHeadlessMode`).
3. Maps the suite's exit code to a distinct message and propagates that same code as the
   script's own exit status: **0** "PASS", **100** "FAIL", **103** "MISCONFIGURED", and
   any other value (including the documented **1**) falls through to a labelled
   "UNKNOWN... treat as the import-not-run case" branch that also exits **1**.

Demonstration runs (via the PowerShell tool, from `D:\Gamedev`):

```
> powershell -File tests\run_tests.ps1
...
PASS (exit 0): every test under res://tests/harness/pass passed.
SCRIPT EXIT: 0
```

```
> powershell -File tests\run_tests.ps1 -TestPath res://tests/harness/fail
...
FAIL (exit 100): the suite ran; at least one assertion failed under res://tests/harness/fail.
SCRIPT EXIT: 100
```

Both the printed message and the process's own `$LASTEXITCODE` matched the underlying
gdUnit4 exit code in both runs.

## 7. Settings check re-run

`tests/settings_check.gd` was **not modified**. Re-run to confirm it still passes after
this task's changes (`addons/gdUnit4/` added, `project.godot` untouched):

```
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/settings_check.gd
```

Output:

```
Settings check: PASS (16 layers, 24 actions asserted of 115 input entries present, 8 settings, 1 autoload(s), templates 4.7.1.stable)
Boot check: Godot 4.7.1 matches the pin in document 20.
```

Exit code 0.

## 8. Skill-conflict note (for the LEDGER)

`godot-prompter:godot-testing`'s `SKILL.md` (v1.13.3, installed at
`godot-prompter-marketplace/godot-prompter/1.13.3/skills/godot-testing/SKILL.md`)
conflicts with this project's verified P0.7 configuration in two independent ways:

1. **Wrong CLI surface.** `SKILL.md` line 67: *"Both frameworks ship a CLI runner. ...
   **gdUnit4:** `--add-gdunit-test-runner` argument, or via the editor "GdUnit Tests"
   dock."* Its `references/running-tests.md` goes further, giving concrete but
   non-existent invocations: `godot --headless -s addons/gdUnit4/GdUnitRunner.gd --
   --testsuites res://tests` (and variants with `--report-dir`). None of
   `--add-gdunit-test-runner`, `addons/gdUnit4/GdUnitRunner.gd`, or a `--testsuites` flag
   exist in the installed gdUnit4 v6.2.1 - confirmed by listing the addon
   (`GdUnitRunner.gd` is not present anywhere under `addons/gdUnit4/`; only
   `addons/gdUnit4/bin/GdUnitCmdTool.gd` is) and by reading the real option table in
   `addons/gdUnit4/src/cmd/CmdOptions.gd` inside `GdUnitTestCIRunner.gd`, which defines
   `-a/--add`, `-i/--ignore`, `-c/--continue`, `-conf/--config`, `-rd/--report-directory`,
   `-rc/--report-count`, `--info`, `--selftest`, and `--ignoreHeadlessMode` - none named
   `--testsuites`, and no `--add-gdunit-test-runner` anywhere in the addon. The skill also
   never mentions `--ignoreHeadlessMode` at all, so following it produces exit 103
   (section 4 above), not a working run. This reconfirms finding F-11 rather than
   superseding it.
2. **Wrong framework recommendation.** `SKILL.md` line 26: *"**Rule of thumb:** Use GUT
   for GDScript-only projects. Use gdUnit4 for C# projects or when you need first-class
   C# support and scene runner utilities."* This project is GDScript-only (docs/20 >
   Godot 4.x Implementation Standards) with no C# use anywhere, which by the skill's own
   rule of thumb should point to GUT - yet gdUnit4 is this project's chosen and verified
   framework (E0.2, this task). The skill's stated rationale for choosing between the two
   frameworks does not apply to why this project picked gdUnit4.

Per CLAUDE.md's GodotPrompter section, this project wins on both points and the conflict
is recorded here for the orchestrator to copy into the phase LEDGER, not resolved by
changing this project's harness.

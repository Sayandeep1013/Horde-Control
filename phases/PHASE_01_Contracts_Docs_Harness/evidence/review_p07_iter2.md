# P0.7 critical agent - review iteration 2 of the headless gdUnit4 test harness

Reviewer: blind critical agent (Opus), 2026-09-18, iteration 2. Blind to how the fixes were made.
Inputs: `evidence/review_p07.md` (iteration 1), LEDGER.md, PLAN.md, `tests/run_tests.ps1`,
`export_presets.cfg`, `.gitattributes`, `docs/28_AI_Development_Workflow.md` > Pinned Tool
Versions, EXECUTION_LOG.md, `addons/gdUnit4/runtest.cmd`, MASTER_SDLC.md > Change Log. Every
claim below was re-tested by this reviewer; nothing is taken from the orchestrator's log or from
iteration 1's report. No `mcp__godot-*` tool was called. Nothing inside the repository was
deleted, and no repository file was created or edited by this review other than this report.

**Disclosures.**

1. **I ran the release export**, as this review's constraints permit:
   `--headless --path . --export-release "Windows Desktop" builds/windows/HordeControl.exe`.
   It overwrote `builds/windows/HordeControl.exe` and `.pck`; `builds/` is gitignored
   (`git check-ignore -v` resolves to `.gitignore:18`).
2. **I added report directories to `reports/`.** It already existed with `report_1`..`report_8`
   when I began; my runs took it to twelve. `reports/` is gitignored (`.gitignore:42`). Safe to
   delete.
3. **Work outside the repository.** A copy of the project (no `.git`, no `.godot`) at a
   scratchpad path *containing a space*, three `git clone`s of the repository into the
   scratchpad, and a one-line stub `.cmd`. All outside `D:\Gamedev`.
4. **The tree moved during this review, again.** `phases/.../LEDGER.md` changed on disk at
   07:39 while this review was open (a P0.4 edit to row F01-11; no P0.7 row changed), and
   `src/data/{pickup,weapon}_definition.gd` plus two samples are modified-uncommitted. That is
   F01-27's pattern recurring in iteration 2, in the iteration its own Resolution said the rule
   applies to. Not a P0.7 finding - recorded because I observed it.

---

## 1. Disposition of every iteration 1 finding

| Iter-1 finding | Ledger row | Disposition | Evidence |
| --- | --- | --- | --- |
| **N1 Major** - PASS after zero tests, path (a): stale `$LASTEXITCODE` with a missing/wrong `-GodotPath` | F01-18 | **Closed** | Re-run verbatim (attack 1). Exits 1 with a named cause. Also closed for a *real file that is not an executable* (attack 4) and an *empty* path (attack 8) |
| **N1 Major** - PASS after zero tests, path (b): gdUnit4 exits 0 on "No test cases found" | F01-18 | **Closed for the captured-output case; NOT closed as a class** | Attacks 2, 3, 10 all now exit 1. But the guard is a *negative match on captured stdout*, so it vanishes whenever stdout is not captured. Reproduced twice (attacks 6 and 13): the script prints `PASS (exit 0)` with zero tests executed. See **NEW-1** |
| **N2 Major** - F01-04's stated ground is false | F01-19 / F01-04 | **Closed, and honestly** | See section 3 |
| **N3 Minor** - `reports/*` arm verified against a deleted directory | F01-20 | **Closed, and now proven load-bearing** | `reports/` genuinely exists (79 files, 12 dirs). Export re-run; pack has zero `reports` bytes. Falsified: removing the arm packs `res://reports/report_*/css/logo.png.import`. Section 4 |
| **N4 Minor** - eleven placeholder samples shipping | F01-20 | **Closed, and proven load-bearing** | Pack has zero matches for `samples`, `_sample`, `PLACEHOLDER`. Falsified: removing the arm packs all eleven `*_sample.tres.remap`. Section 4 |
| **N5 Minor** - D86's Change Log row | F01-21 | **Closed on substance; the ledger row is now stale** | MASTER_SDLC.md is at **0.8.4** and its Change Log row for 0.8.4 states "document 28 was raised to 1.1.0 for D86". F01-21 still reads "the master's Change Log gained no row either" and "D84-D87 were added ... with no version bump" - both now false. See **NEW-5** |
| **N5 Minor** - gdUnit4 licence unrecorded | F01-21 | **Closed** | docs/28 line 70 now carries "**Licence**: MIT, Copyright (c) 2023 Mike Schulze, vendored verbatim at `addons/gdUnit4/LICENSE`". `head -4 addons/gdUnit4/LICENSE` returns `MIT License` / `Copyright (c) 2023 Mike Schulze`. Matches character for character |
| **N6 Minor** - failing fixture guarded only by a default and a comment | F01-22 | **Not closed; honestly carried open** | `tests/harness/fail/` is unchanged; no `-i/--ignore`, no committed `GdUnitRunner.cfg`, no relocation. The only two references anywhere are `run_tests.ps1` lines 55 and 67. The ledger says so and states the mitigation. Acceptable as an open row, not as a closed one |
| **N7 Minor** - docs/28's `runtest.cmd` causal claim | F01-23 | **Not closed - and the claim is now demonstrated false** | docs/28 line 54 is unchanged. I tested it. See section 5 |
| F01-03, F01-05, F01-10 (iteration 1 dispositions) | - | **Unchanged / still closed** | Version `6.2.1` confirmed; pin figures re-verified (section 6); export filter re-verified (section 4) |

**Regressions: none found.** The failing fixture still returns 100, the passing suite still
returns 0, and `git diff project.godot` is empty (`project.godot` is untouched, still no
`[editor_plugins]` section). The 516-file count and the pinned hash are unchanged.

---

## 2. Attack log against `tests/run_tests.ps1`

Shell: Windows PowerShell **5.1.26100.9444**. `pwsh` is **not installed on this machine**
(`Get-Command pwsh` returns nothing), so the script's own `.EXAMPLE pwsh -File tests/run_tests.ps1`
is not runnable here as written; every run below used `powershell`, either `&`-invoked in a
primed shell or via `powershell -NoProfile -File`. I did not test `pwsh -File` and make no claim
about it.

| # | Attack | Command (verbatim) | Result | Verdict |
| --- | --- | --- | --- | --- |
| 1 | Iter-1 path (a): stale `$LASTEXITCODE` + missing exe | `& cmd /c exit 0; & "D:\Gamedev\tests\run_tests.ps1" -GodotPath "D:\godot\NOT_A_REAL.exe"` | `NOT A USABLE RUN: Godot executable not found at 'D:\godot\NOT_A_REAL.exe'...` · exit **1** | **fails closed** |
| 2 | Iter-1 path (b): directory with no suites | `& cmd /c exit 0; & "...\run_tests.ps1" -TestPath "res://src/core"` | gdUnit4 `No test cases found, abort test run!` / `Exit code: 0`; script: `NOT A USABLE RUN: ... Zero tests executed is never a pass` · exit **1** | **fails closed** |
| 3 | `-TestPath` that does not exist at all | `... -TestPath "res://tests/harness/does_not_exist_at_all"` | gdUnit4 `Given directory or file does not exists:` + `No test cases found` · script exit **1** | **fails closed** |
| 4 | `-GodotPath` = a real file that is not an executable | `... -GodotPath "D:\Gamedev\CLAUDE.md"` | `Cannot run a document in the middle of a pipeline` (PS error) then `NOT A USABLE RUN: the import pass produced no exit code...` · exit **1** | **fails closed** (via the null check, not guard 1) |
| 5 | `-GodotPath` = the **windowed** Godot build (the project's own documented trap) + typo path | `... -GodotPath "D:\godot\Godot_v4.7.1-stable_win64.exe" -TestPath "res://tests/harness/typo_does_not_exist"` | `NOT A USABLE RUN: the suite produced no exit code, so it never actually ran.` · exit **1** | fails closed, but **by accident**: PowerShell does not wait on a GUI-subsystem process, so `$LASTEXITCODE` stayed `$null`. The import pass was *not* caught and reported success |
| 6 | `-GodotPath` = a real console executable that exits 0 silently (`@echo off` / `exit /b 0`) | `& cmd /c exit 0; & "...\run_tests.ps1" -GodotPath "<scratchpad>\fake_godot_silent.cmd"` | **`PASS (exit 0): the suite ran and every test under res://tests/harness/pass passed.`** · exit **0** | **FALSE GREEN - zero tests executed** |
| 7 | Run from an unrelated working directory | `Set-Location C:\Windows\System32; & powershell -NoProfile -File "D:\Gamedev\tests\run_tests.ps1"` | `Executed test cases : (1/1)` · `PASS (exit 0)` · exit **0** | correct; `$PSScriptRoot` makes it cwd-independent |
| 8 | Empty `-GodotPath` (can the guards throw?) | `& cmd /c exit 0; & "...\run_tests.ps1" -GodotPath ""` | `Test-Path : Cannot bind argument to parameter 'LiteralPath' because it is an empty string.` - **guard 1 itself throws and is skipped** - then `NOT A USABLE RUN: the import pass produced no exit code` · exit **1** | fails closed, but the guard is bypassed. See **NEW-3** |
| 9 | Fresh checkout (no `.godot/`) **and** a project path containing a space | `& powershell -NoProfile -File "<scratchpad>\p07i2 copy\tests\run_tests.ps1"` | import pass → `Executed test cases : (1/1)` → `PASS (exit 0)` · exit **0** | correct; no false failure. The import pass cures the exit-1 condition |
| 10 | A discovered suite with **zero test methods** | `... -TestPath "res://tests/harness/empty"` (suite created in the copy) | `No test cases found, abort test run!` → `NOT A USABLE RUN` · exit **1** | **fails closed** |
| 11 | Empty `-TestPath` | `& cmd /c exit 0; & "...\run_tests.ps1" -TestPath ""` | gdUnit4: `The '-a' command requires an argument!` + usage, `Abnormal exit with 100`; script: **`FAIL (exit 100): the suite ran; at least one assertion failed under .`** · exit **100** | fails closed but **misdiagnoses**: a malformed invocation is reported as a test failure. See **NEW-2** |
| 12 | Unwritable `TEMP`, default (valid) test path | `$env:TEMP = "Q:\nope\nowhere"; $env:TMP = "Q:\nope\nowhere"; & "...\run_tests.ps1"` | `PASS (exit 0)` · exit **0**, **with the entire gdUnit4 output missing from the console** | correct verdict, but the suite log is gone - and with it guard 3 |
| 13 | **Unwritable `TEMP` + a `-TestPath` typo** | `$env:TEMP = "Q:\nope\nowhere"; $env:TMP = "Q:\nope\nowhere"; & cmd /c exit 0; & "...\run_tests.ps1" -TestPath "res://tests/harness/typo_not_real"` | **`PASS (exit 0): the suite ran and every test under res://tests/harness/typo_not_real passed.`** · exit **0** | **FALSE GREEN - zero tests executed, no diagnostics at all** |
| 14 | Regression: the failing fixture | `& powershell -NoProfile -File "...\run_tests.ps1" -TestPath "res://tests/harness/fail"` | `Expecting: 'false' but is 'true' ...` · `FAIL (exit 100)` · exit **100** | correct |
| 15 | Regression: clean shell, default invocation | `Set-Location D:\Gamedev; & powershell -NoProfile -File "D:\Gamedev\tests\run_tests.ps1"` | `Executed test cases : (1/1)` · `PASS (exit 0)` · exit **0** | correct |

**Did the runner survive?** On thirteen of fifteen attacks, yes - including every attack my
predecessor ran and every ordinary operator mistake I could construct (missing binary, wrong
binary, non-binary, empty binary path, typo'd test path, nonexistent test path, empty suite,
wrong working directory, spaces in the project path, fresh checkout). Attacks **6** and **13**
both produced a literal false green.

### NEW-1 - Major: the zero-test guard fails open whenever stdout is not captured

Both false greens have one root cause, at `tests/run_tests.ps1:128`:

```powershell
if ($suiteOutput -match "No test cases found") { ... exit 1 }
```

This asserts the **absence of a failure string** rather than the **presence of evidence that
tests ran**. `$suiteOutput` comes from `*> $SuiteLog` where
`$SuiteLog = Join-Path ([System.IO.Path]::GetTempPath()) "gdunit_suite_$PID.log"`. Whenever that
capture yields nothing, the guard silently evaporates while `$testExit` is still `0`, and the
switch prints PASS. Two reproduced routes:

- **Attack 6** - anything at `-GodotPath` that exists, runs and exits 0 without producing the
  expected output. Guard 1 only checks that the path is a file; nothing ever checks that it is
  Godot. A CI `godot` shim that silently no-ops is exactly this shape.
- **Attack 13** - an unwritable or bogus `TEMP`. This one is not operator error at all: it is an
  environment condition (containers, service accounts, a restricted runner, `TMP`/`TEMP` unset),
  and it converts a typo'd path into `PASS (exit 0)` **while also suppressing every line of
  diagnostic output**, so a human reading the CI log sees a green run and nothing else.

This is F01-18's finding (b) still live, on the same line of the same script the fix was written
for. Iteration 1 named the correct instrument - "an assertion that the run reported at least one
executed test case (the `Executed test cases : (n/n)` summary line, or the XML report gdUnit4
already writes)" - and the weaker negative match was implemented instead. The positive anchor
demonstrably exists: every real run above printed `Executed test cases : (1/1)`, including
attacks 7, 9, 14 and 15. A positive assertion fails closed in **both** of my routes, because
missing output cannot match. (Note when writing it: gdUnit4's `Statistics:` line prints the word
`PASSED` even on a failing run - attack 14 shows `1 failures ... PASSED` - so `Executed test
cases : (n/n)` is the right anchor and `PASSED` is not.) A second, independent hardening worth
having: verify the binary is Godot at all (a `--version` probe matching `4.7.1`), which also
closes attack 5's accidental pass and the whole "wrong build" class the project already
documents as a failure mode.

### NEW-2 - Minor: a malformed invocation is reported as an assertion failure

Attack 11. gdUnit4 exits **100** for `-a` with no argument, and the script prints
`FAIL (exit 100): the suite ran; at least one assertion failed under .` - naming a cause that did
not happen, with an empty path in the message. The script's own header says it exists so "a
caller (CI or a human) can distinguish all four without parsing output"; here it actively
misinforms. Cheap fix: reject an empty/whitespace `-TestPath` in the guard block, and have the
100 branch require that the output contains a failure summary.

### NEW-3 - Minor: guard 1 can throw and be skipped

Attack 8. `Test-Path -LiteralPath ""` raises a `ParameterBindingValidationException`, which
terminates the `if` statement; execution falls through **past** guard 1 to the `& $GodotPath`
call. The run still fails closed, but only because of the downstream `$null -eq $importExit`
check - the guard the comment block credits did not run. `[ValidateNotNullOrEmpty()]` on the
parameter, or an `[string]::IsNullOrWhiteSpace($GodotPath) -or ...` short-circuit, removes this.

### NEW-4 - Minor: the guarded runner is documented nowhere a later phase would look

`tests/run_tests.ps1` appears in no permanent document. A repository-wide grep finds it only in
`phases/PHASE_01_.../` (the plan record, the evidence files and this review). docs/28's
"Verified gdUnit4 invocation, for P0.7" still hands a later phase the **raw** command line, which
has none of the three guards; NEXT_SESSION.md and MASTER_SDLC.md do not mention the script at
all. The natural thing for Phase 02+ to copy is therefore the unguarded form. Related: the
script's two `.EXAMPLE` lines invoke `pwsh`, which is not installed on this machine.

---

## 3. F01-19 / F01-04 - is the correction genuine?

**Yes, on both tests the brief asks.**

*Corrected rather than quietly replaced.* LEDGER F01-04's Resolution now opens
"**The ledger's own earlier reasoning was wrong and is corrected here.**" and **quotes both
falsified claims verbatim** - "cannot occur here without deleting that cache or standing up a
second project" and "would require breaking the very cache the project needs" - before saying
they were falsified. The wrong text is preserved and labelled, not deleted. F01-19 exists as its
own Major row, names Carried Lesson 7 by name, and assigns fault explicitly: "The fault is the
orchestrator's reasoning, not the implementer's report, which correctly said 'not reproduced'
rather than fabricating."

*Credited honestly.* Attribution to the reviewer is explicit in four places: F01-04's Resolution
("The P0.7 critical agent falsified both in under two minutes, deleting nothing"), F01-19's
Finding ("the reviewer reproduced it in under two minutes with a scratchpad copy"),
EXECUTION_LOG row 39 ("by the method the ledger itself named and declined to use"), and
EXECUTION_LOG row 38 ("a third (F01-19) falsifies reasoning the orchestrator had written into the
ledger"). The reviewer's more useful second question is carried too: "a fresh CI checkout does
recover, because the import pass cures it" - which I independently re-confirmed as attack 9,
on a copy with no `.godot/` and a space in its path.

One blemish, folded into **NEW-5** below rather than scored as its own finding: EXECUTION_LOG
rows 28 and 36 still carry the falsified reasoning **in place with no inline correction marker**.
Row 36 still asserts "the implementer's reasoning for why it cannot recur in this repository is
confirmed correct", which is exactly the claim row 39 disproves. The phase applied an inline
marker to the equivalent case (row 32 carries "**Corrected 2026-09-18 (LEDGER F01-26)**"), so the
treatment is inconsistent, and a reader who stops at row 36 takes away the false claim.

### NEW-5 - Minor: two record rows are stale in the direction of understating the fix

- EXECUTION_LOG rows 28 and 36, above.
- LEDGER F01-21 still reads "the master's Change Log gained no row either, so half of D86 is
  undischarged" and "D84-D87 were added to the master with no version bump and no Change Log
  row". Both are now false: MASTER_SDLC.md is at **0.8.4** and its 0.8.4 Change Log row names
  D84-D91 and states "document 28 was raised to 1.1.0 for D86". The fix landed; the row that
  tracks it was not updated. (CLAUDE.md's "MASTER_SDLC.md (v0.8.4)" reference *was* swept
  correctly - I checked.)

---

## 4. Export verification

Run by me, exit **0**:

```
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . \
  --export-release "Windows Desktop" builds/windows/HordeControl.exe
```

`builds/windows/HordeControl.pck` = **70,756 bytes**, written 07:35:37. I read the pack's own
file index out of the binary (`strings -n 6 ... | grep '^res://' | sort -u`): **56 `res://`
entries**, all of them `res://scenes/main.tscn`, `res://src/core/boot_check.gd` and the 54
`res://src/data/*.gd` schemas, plus `res://.godot/global_script_class_cache.cfg`,
`res://.godot/uid_cache.bin` and `res://project.binary` from the savepack log.

Byte-search of the pack:

| marker | `addons` | `gdUnit4` | `GdUnitTestSuite` | `tests/` | `test_trivial` | `run_tests` | `settings_check` | `reports` | `report_` | `samples` | `_sample` | `PLACEHOLDER` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| matches | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Real content present: `boot_check` 5, `main.tscn` 2, `enemy_definition` 5, `project.binary` 1.

**`reports/` exists.** It was present before I started (`report_1`..`report_8`, 79 files,
including `report_*/css/logo.png` and its `.import` companion) and my runs took it to twelve
directories. So unlike iteration 1, the `reports/*` arm was exercised against a directory that
was really there.

**And I falsified both contested arms rather than only observing absence.** In the scratchpad
copy - never in the repository - I set
`exclude_filter="addons/gdUnit4/*, tests/*"` (dropping `reports/*` and `src/data/samples/*`) and
re-exported. The pack grew from **70,756 to 182,244 bytes** and the savepack log stored:

```
Storing File: res://reports/report_1/css/logo.png.import
Storing File: res://reports/report_2/css/logo.png.import
Storing File: res://src/data/samples/economy_configuration_sample.tres.remap
... (all eleven *_sample.tres.remap)
```

Both arms are therefore **load-bearing and proven**, not vacuous. The samples arm carries almost
all of the 111 KB; the reports arm is small in bytes but real - the engine does import report
assets into the pack when the filter does not stop it.

---

## 5. N7 / F01-23 - I tested `runtest.cmd`. The docs/28 claim is false.

docs/28 line 54 still says, unchanged:

> Do NOT use the addon's own `runtest.cmd` wrapper for headless CI: it was read at
> `addons/gdUnit4/runtest.cmd` and passes neither `--headless` nor `--ignoreHeadlessMode`, so
> following it reproduces the exact exit-103 failure this bullet describes.

Run in the scratchpad copy, from its project root, the way upstream intends:

```
cmd /c "addons\gdUnit4\runtest.cmd --godot_binary D:\godot\Godot_v4.7.1-stable_win64_console.exe -a res://tests/harness/pass"
```

Result: **it runs and passes.** `Vulkan 1.4.351 - Forward+ - Using Device #0: NVIDIA ...` (a real
windowed run, not headless), `Executed test cases : (1/1)`, `Exit code: 0`,
`Run tests ends with 0`, wrapper exit **0**. There is no exit 103 and no headless refusal
anywhere in the output.

The 103 appears only when `--headless` **is** supplied without `--ignoreHeadlessMode`:

```
cmd /c "addons\gdUnit4\runtest.cmd --godot_binary ... --headless -a res://tests/harness/pass"
→ Headless mode is not supported! ... You can run with '--ignoreHeadlessMode' to swtich off this check.
→ Run tests ends with 103   (wrapper exit 103)
```

This is consistent with the addon's own source: `GdUnitTestCIRunner.gd:354` gates on
`DisplayServer.get_name() == "headless"`, so with no `--headless` the check never fires.

So the causal claim is **backwards**, exactly as iteration 1 suspected and declined to assert.
The bullet's *operative advice* ("do not use `runtest.cmd` for headless CI") remains correct, and
for two better reasons the document does not give: as written it runs **windowed**, which
initialises Vulkan and needs a display - so on a headless runner it fails for a different reason
entirely - and its own `--remote-debug tcp://127.0.0.1:0` produces `ERROR: The remote port number
must be between 1 and 65535` on every run. The sentence also mis-describes the file: the trailing
`GdUnitCopyLog.gd` line **does** pass `--headless`.

Suggested replacement wording, stating only what was observed: *"`runtest.cmd`'s test-run line
passes neither `--headless` nor `--ignoreHeadlessMode`, so following it as written runs Godot
**windowed** - tested 2026-09-18 on a copy of this project: the tests execute and it exits 0,
initialising Vulkan. It is unusable for headless CI because it needs a display, and because
passing `--headless` through it without `--ignoreHeadlessMode` is what produces exit 103 - also
tested, exit 103."*

This is the third time in this phase a cause has been written without an experiment (F-08,
F01-19, and this). Iteration 1 left the row open with "either test it or reword it"; neither was
done, and testing it cost me two commands.

---

## 6. Pin and `.gitattributes` - verified, and verified the hard way

**The recorded figures reproduce exactly.** Run by me from the project root:

```
grep '^version=' addons/gdUnit4/plugin.cfg                                    → version="6.2.1"
find addons/gdUnit4 -type f | wc -l                                           → 516
find addons/gdUnit4 -type f | LC_ALL=C sort | xargs sha256sum | sha256sum
  → 5ae43377c9501520d2a6191c59e4e156aa3525ad4d9c69716db62e1d78ab8b9a
```

Character for character against docs/28. `git ls-files addons/gdUnit4 | wc -l` is also **516**,
so the hash covers exactly the tracked set - no untracked file inflates it and none is missing,
which is what makes the figure reproducible from a clone at all.

**Does `.gitattributes` actually protect the hash for someone with a different `core.autocrlf`?
Yes - and I proved it by cloning rather than by reading.** This machine is `core.autocrlf=input`
(local and global), so the interesting case is a stranger on the Windows default, `true`. Three
real clones of the repository into the scratchpad:

| clone | files | hash |
| --- | --- | --- |
| `git -c core.autocrlf=true clone` | 516 | `5ae43377...8b9a` ✔ |
| `git -c core.autocrlf=input clone` | 516 | `5ae43377...8b9a` ✔ |
| `git -c core.autocrlf=false clone` | 516 | `5ae43377...8b9a` ✔ |

**Negative control**, to show the attribute is load-bearing and not decorative: in a fourth clone
I removed `.gitattributes` from the worktree *and the index*, set `core.autocrlf=true`, deleted
and re-checked-out the addon:

```
hash WITHOUT .gitattributes, autocrlf=true:
  31b80546b57f9e6cf3de9ce88470c88888897c2a540434f7d37378d2cad670f9
file addons/gdUnit4/bin/GdUnitCmdTool.gd
  → ASCII text executable, with CRLF line terminators
```

A different hash, from CRLF checkout. So the protection claim in docs/28 - "without that, a clone
on a machine whose `core.autocrlf` differs from this one would check out different bytes and the
hash would fail for a correct copy" - is **true, precisely stated, and now demonstrated**. The
index stores LF for all 506 text files (`git ls-files --eol` → `i/lf w/lf attr/-text`), so the
`-text` marking was in effect when the addon was committed, not merely added afterwards - which
is the case that would have left the repository quietly broken.

This is the strongest piece of work in the iteration-2 fix set. One small caveat for whoever runs
the check later: the two verification commands are GNU coreutils and assume the project root as
the working directory (the `find` output embeds relative paths). They do not run in plain Windows
PowerShell. docs/28 does not say so.

---

## 7. Score

**P0.7: 7 / 10.** Above iteration 1's 6, below 8. Precisely why:

1. **The Major that defined iteration 1 is narrowed, not closed (NEW-1).** Thirteen of fifteen
   attacks fail closed, including every attack my predecessor ran and every ordinary operator
   mistake I could construct - that is real, verified progress and most of the deduction from
   iteration 1 is earned back. But the script still prints `PASS (exit 0): the suite ran and every
   test under <path> passed` for a path that does not exist, with zero tests executed, whenever
   stdout is not captured - reproduced twice, once through an environment condition rather than a
   mistake, and in that case with every diagnostic line suppressed as well. The instrument chosen
   (absence of a failure string) is the fail-open form of the one iteration 1 prescribed
   (presence of `Executed test cases : (n/n)`), and the positive anchor is present in every real
   run. A harness that can report green having run nothing is the single defect this deliverable
   must not carry, so an open Major on it holds the score below 8.
2. **F01-23 was left open and is now a proven falsehood in a 1.1.0 document.** `runtest.cmd`
   followed as written runs windowed and exits 0; 103 comes from `--headless` without
   `--ignoreHeadlessMode`. Two commands settled it. The row said "either test it or reword it";
   neither happened, and Carried Lesson 7 has now recurred three times inside a phase that
   carried it forward specifically to prevent that.
3. **Three small runner defects found this iteration** - a configuration error reported as an
   assertion failure (NEW-2), a guard that throws and is skipped (NEW-3), and a guarded runner
   that no permanent document points at while docs/28 still hands later phases the unguarded
   command line (NEW-4) - plus two stale record rows understating fixes that actually landed
   (NEW-5).

What earns the 7 rather than less, on evidence I generated myself: the stale-`$LASTEXITCODE`
path is genuinely dead; a typo'd, nonexistent, empty, or test-free path all now fail loudly; the
script is correct from any working directory, on a project path containing a space, and on a
fresh checkout with no `.godot/`; both contested `exclude_filter` arms are proven load-bearing by
falsification instead of asserted from absence; the pin reproduces exactly and its
`.gitattributes` protection survives clones under all three `core.autocrlf` settings with a
negative control showing it matters; the licence is recorded and correct; D86's Change Log
element exists in the master's 0.8.4 row; and the F01-19 correction is the model of how a phase
should handle being caught - the wrong claim quoted, not deleted, the fault assigned to the
orchestrator rather than the implementer, and the reviewer credited by name in four places.

Smallest change that would move this materially: replace the negative match at line 128 with a
positive assertion that the captured output contains `Executed test cases : (n/n)` with n ≥ 1,
and fail closed when the output is empty. That is two lines and it closes both of my false
greens. Reword docs/28 line 54 to what was actually observed, and F01-23 closes too.

This review does not state that any gate is passed, satisfied, met, or ready; that is for the
reviewers and the author.

# P0.7 critical agent - review of the headless gdUnit4 test harness

Reviewer: blind critical agent (Opus), 2026-09-18. Inputs: PLAN.md ("P0.7 - Test harness",
its Tasks row, Exit criteria, Predetermined failure points, Carried lessons), LEDGER.md,
MASTER_SDLC.md > Acceptance Test Matrix > Build Checks > Harness check, NEXT_SESSION.md >
"Facts Phase 01 must not re-derive", decision D86, and the artifacts on disk. The
implementer's `evidence/p07_report.md` was read as a claim and every assertion in it that
this review relies on was re-tested. No `mcp__godot-*` tool was called; no export was run;
no file in the repository was created, edited or deleted by this review other than this
report.

**Two disclosures.**

1. **I created `reports/` in the real project.** It did not exist when this review began.
   My six headless runs regenerated `reports/report_1` through `report_6` (gdUnit4's
   default report directory, no `-rd` override). `git check-ignore -v reports/` resolves to
   `.gitignore:42:reports/`, so nothing enters version control. They are safe to delete.
2. **The artifact moved during the review.** At my first read (~06:49) `docs/28` was at
   1.0.0 and its Pinned Tool Versions section carried only the two MCP servers. At 06:51,
   while the gate was convened, the orchestrator wrote the gdUnit4 pin and raised the
   document to 1.1.0, and added LEDGER F01-10. My first reads of LEDGER.md and docs/28 were
   therefore stale, and everything below reflects the **live** state re-read afterwards. I
   note it because PLAN.md's own rule is to sweep changed files before re-review, and this
   phase's record changed mid-gate.

I also stood up a throwaway copy of the project **in the session scratchpad, outside the
repository**, to test one thing the phase record says could not be tested (see F01-04).
Nothing under `D:\Gamedev` was deleted to do it; the real `.godot/` is untouched and
verified present.

---

## 1. Ledger disposition

Marked before any new finding was raised, per PLAN.md > Agent assignment.

| ID | Bears on P0.7? | Disposition | Reason |
| --- | --- | --- | --- |
| F01-01 | Indirectly | **Not closed** (not P0.7's to close) | Its own Resolution names the verification as outstanding until the next session start. It bears on P0.7 only because the settings-precedence hole is half of why the implementer's write scope was narrowed. Nothing in P0.7's artifacts changes its state. |
| F01-02 | Indirectly | **Not closed** (not P0.7's to close) | Open half (the `ask` gate does not intercept a subagent) is unchanged. It is the stated reason the P0.7 delegation carried a no-delete constraint - which, per finding N2 below, did not actually block what it was blamed for blocking. |
| F01-03 | Yes - raised on invoking the skill before P0.7 | **Closed as a record** | Independently verified against the installed addon: no `GdUnitRunner.gd` exists anywhere under `addons/gdUnit4/` (only `src/core/GdUnitRunnerConfig.gd`, a different file); no `--testsuites` or `--add-gdunit-test-runner` string exists in the addon; `--ignoreHeadlessMode` is real and lives in `src/core/runners/GdUnitTestCIRunner.gd`. The project used the verified command, not the skill's. CLAUDE.md requires the conflict to be recorded, not fixed, and it is recorded. **But see N7**: the docs/28 bullet attached to this conflict makes a causal claim about `runtest.cmd` that is very likely wrong. |
| F01-04 | Yes - raised by P0.7 | **Not closed, and its stated ground is falsified** | See N2. I reproduced exit code 1 in about two minutes, deleting nothing, by pointing `--path` at a copy of the project in the session scratchpad. The ledger's ground - that a genuinely un-imported state "cannot occur here without deleting that cache or standing up a second project - both outside the delegation's constraints" - conflates a throwaway copy outside the repository with a delete, and the 06:51 downgrade note ("what is missing is only a second demonstration in the real project, which would require breaking the very cache the project needs") is wrong: `--path <copy>` needs nothing from the real project's cache. The implementer's honesty in not fabricating the row is correct behaviour and I credit it; the defect is in the record's reasoning, not in the implementer's report. |
| F01-05 | Yes - raised by P0.7 | **Partly closed; the `reports/*` arm is not verified** | Re-verified independently rather than accepted: I did not rely on the orchestrator's log, I read the pack itself. `builds/windows/HordeControl.pck` (95,772 bytes) contains exactly `res://scenes/main.tscn`, `res://src/core/boot_check.gd`, the `res://src/data/*.gd` schemas and `res://src/data/samples/*.tres` - **zero** `addons/`, `tests/` or `reports/` entries, and no `.md` file. So the `addons/gdUnit4/*` and `tests/*` arms are confirmed effective, and nothing real was over-excluded. The `reports/*` arm is **not** confirmed: EXECUTION_LOG row 31 records that the four report directories were removed *before* the verification export ran, so that arm was tested against a directory that did not exist. See N3, and N4 on what the pack does contain. |
| F01-06 | No | Not applicable | P0.4 finding, doc 02 / Register gap. |
| F01-07 | No | Not applicable | P0.4 finding, resolved there. |
| F01-08 | No | Not applicable | P0.6 finding about `.tres` type-mismatch behaviour. |
| F01-09 | No | Not applicable | P0.6 contract/typing questions, routed to the P0.6 critical agent. |
| F01-10 | Yes - the D86 exit condition | **Closed on substance, one element unevidenced** | The pin now exists and every figure in it reproduces (section 4). The element of D86 that is not evidenced is its third: "a version bump **and a Change Log row**". The version bump is real (1.1.0, with a Status line saying what changed). No Change Log row exists anywhere for it - see N5. |

No regressions found against any ledger item.

---

## 2. Exit codes as I observed them

Every command below was run by me through Bash against the pinned console executable
`/d/godot/Godot_v4.7.1-stable_win64_console.exe`, from `D:\Gamedev` unless the row says
otherwise. I took no figure from the implementer's table or from the EXECUTION_LOG.

| Expected | Exact command | Observed exit | Corroborating output |
| --- | --- | --- | --- |
| import 0 | `--headless --path . --import` | **0** | `[ DONE ] loading_editor_layout` |
| 0 | `--headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/pass --ignoreHeadlessMode` | **0** | `Overall Summary: 1 test cases \| 0 errors \| 0 failures ...` / `Executed test cases : (1/1)` / `Exit code: 0` |
| 100 | `--headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/fail --ignoreHeadlessMode` | **100** | `Expecting: 'false' but is 'true' at 'test_false_condition_fails' in res://tests/harness/fail/test_trivial_fail.gd:12` / `Exit code: 100` |
| 103 | `--headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/pass` (flag omitted) | **103** | `You can run with '--ignoreHeadlessMode' to swtich off this check.` / `Abnormal exit with 103` |
| 1 | `--headless --path <scratchpad copy of the project, no .godot/> -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/harness/pass --ignoreHeadlessMode` | **1** | `SCRIPT ERROR: Parse Error: Could not find type "GdUnitTestCIRunner" in the current scope.` / `Failed to load script "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"` |
| 0 (regression guard) | `--headless --path . --script res://tests/settings_check.gd` | **0** | `Settings check: PASS (16 layers, 24 actions asserted of 115 input entries present, 8 settings, 1 autoload(s), templates 4.7.1.stable)` |

Two further runs, neither of which the phase record contains:

| What | Command | Observed |
| --- | --- | --- |
| Does the runner recover a genuinely fresh checkout? (the real CI question behind exit 1) | `powershell -NoProfile -File <scratchpad copy>\tests\run_tests.ps1`, with the copy's `.godot/` removed first | **Yes.** The import pass builds the class cache, the suite then runs, `PASS (exit 0)`, script exit **0**. This is the demonstration that actually matters for CI, and it holds. |
| Does gdUnit4 distinguish "no tests found" from "tests passed"? | `--headless --path . -s .../GdUnitCmdTool.gd -a res://src/core --ignoreHeadlessMode` | **No.** `No test cases found, abort test run!` then `Exit code: 0`. See N1(b). |

`tests/run_tests.ps1` in the real project: default path gives `PASS (exit 0)`, script exit
**0**; `-TestPath res://tests/harness/fail` gives `FAIL (exit 100)`, script exit **100**. Both
match the underlying engine codes.

**On the acceptance test.** The Harness check's pass condition - "gdUnit4 runs headless via
`Godot_v4.7.1-stable_win64_console.exe --headless` and reports pass/fail exit codes
correctly" - is evidenced by my own runs, and all four documented codes are now reproduced,
three in the real project and the fourth on a copy. This review does not state that any gate
is passed, satisfied or ready; that is for the reviewers and the author.

---

## 3. Findings

### N1 - Major: `run_tests.ps1` reports PASS after executing zero tests, on two independent paths (tested)

This is the one failure mode a CI harness must not have, and both paths were reproduced, not
reasoned.

**(a) A missing or wrong Godot executable produces a green run.** The script calls
`& $GodotPath ...` twice and reads `$LASTEXITCODE`. When the executable does not exist,
PowerShell raises `CommandNotFoundException` - a *non-terminating* error - and leaves
`$LASTEXITCODE` untouched. If the calling shell already has `$LASTEXITCODE = 0` from any
prior native command, both guards see 0 and the script prints a pass. Tested verbatim:

```
PS> & cmd /c exit 0          # priming LASTEXITCODE = 0
PS> & "D:\Gamedev\tests\run_tests.ps1" -GodotPath "D:\godot\NOT_A_REAL.exe"
... The term 'D:\godot\NOT_A_REAL.exe' is not recognized ...   (twice)
PASS (exit 0): every test under res://tests/harness/pass passed.
RESULT LASTEXITCODE: 0
```

Zero tests ran. The script said every test passed and exited 0. The documented
`pwsh -File tests/run_tests.ps1` form happens to escape this, because a fresh process has
`$LASTEXITCODE` unset (`$null -ne 0`), and there the script correctly exits 1 - but with the
malformed message `IMPORT FAILED (exit ):`, an empty code, which is itself the tell that the
variable was never set. A CI step that dot-calls or `&`-calls the script after any other
native command gets the green. There is no `Test-Path $GodotPath` guard and no
`$LASTEXITCODE = $null` reset before either invocation.

**(b) gdUnit4 exits 0 when it finds no test suites, and the script calls that a pass.**
Tested: `-a res://src/core` prints `No test cases found, abort test run!` and returns **0**.
`run_tests.ps1` maps that to `PASS (exit 0): every test under <path> passed.` This is not
hypothetical for this project: the script's own `.PARAMETER TestPath` comment instructs later
phases to *widen* the default path. A typo, a moved directory, or a renamed suite then yields
a permanently green CI with nothing running.

Both are the exact pattern PLAN.md's **Carried lesson 1** exists to prevent - "a passing check
proves nothing until it fails against its own mechanism." That lesson was applied rigorously
to P0.6's Schema check, which was falsified four ways. It was not applied to P0.7's runner at
all: the four *engine* exit codes were verified, and the *script* that consumes them was never
falsified. The fix is small - a `Test-Path` guard on `$GodotPath`, an explicit
`$LASTEXITCODE = $null` before each call, and an assertion that the run reported at least one
executed test case (the `Executed test cases : (n/n)` summary line, or the XML report gdUnit4
already writes) before printing PASS.

Ancillary, not separately scored: three distinct conditions all collapse to script exit 1
(import failed, import-not-run/code 1, any uncatalogued code), and the original code is lost in
the third case. The messages differ, so a human can tell them apart; an exit-status-only CI
cannot. The unreachable-by-construction 103 branch is *not* a finding - the script's own
comment states plainly that seeing 103 means the invocation was changed or bypassed, which is
honest and correct.

### N2 - Major: F01-04's stated ground is false, and the 06:51 downgrade compounds it

A record defect rather than an artifact defect.

The ledger says a genuinely un-imported state "cannot occur here without deleting that cache or
standing up a second project - both outside the delegation's constraints, which forbade
deletion and narrowed the write scope," and the later downgrade adds that a second
demonstration "would require breaking the very cache the project needs." Neither holds. A
`tar`-copy of the project into the session scratchpad, with `--path` pointed at the copy,
reproduces exit **1** with the documented `Parse Error: Could not find type
"GdUnitTestCIRunner"`, deletes nothing, writes nothing inside the repository, and took under
two minutes. The ledger itself already named this method - "the clean way to exercise it is a
throwaway copy of the project with no `.godot/`" - and then declined to use it while writing a
causal claim that it was unavailable.

This is the shape of Phase 00's F-08, which **Carried lesson 7** was written for: a cause
reasoned rather than tested, written into a ledger. Two things follow. First, the phase record
now contains a falsifiable statement that is false, in the same document that instructs later
phases on how to reason about this harness. Second - and more useful - the question that
actually matters was never asked: not "can I make exit 1 happen?" but "does `run_tests.ps1`
recover a fresh CI checkout?" I ran that (section 2): it does, because the import pass cures
the condition before the suite runs. That is the result the phase should have recorded, and
recording it would have made F01-04 a closed, low-value curiosity instead of an open one.

The implementer is not at fault here and should not be marked down for it: reporting "not
reproduced" rather than fabricating a row is exactly right, and its constraints were real. The
finding is against the phase record.

### N3 - Minor: the `reports/*` arm of `exclude_filter` was verified against a directory that did not exist

EXECUTION_LOG row 31 records that the four generated report directories were removed, and row
25 records the verification export run afterwards. An export cannot pack a directory that is
absent, so the `reports/*` glob was never exercised; the grep returning zero matches for
`reports/` proves only that `reports/` was gone. The `addons/gdUnit4/*` and `tests/*` arms *are*
genuinely proven, because both directories were present and both are absent from the pack index
I read myself.

`reports/` now exists again with six report directories (my runs). **I would like one release
export run now**, by whoever holds that permission, followed by re-reading the pack's file
index - that would close the arm properly. I did not run one; the constraint on this review
forbids it.

### N4 - Minor: `src/data/samples/*.tres` ship in the release build

Read directly out of the pack index, not inferred: `HordeControl.pck` contains eleven
`res://src/data/samples/*_sample.tres` files (director, economy, encounter, enemy, pickup,
player, tower, tower_upgrade, upgrade, wave, weapon). These are P0.6's Schema-check fixtures -
PLAN.md P0.6 step 8 requires every field in them to be "a non-default, clearly-a-placeholder
value" - so a shipped build carries eleven resources of deliberate nonsense content sitting
alongside the real schemas Phase 02 will start loading.

My view: they do not belong in a shipped build, for the same reason `tests/` does not. They are
test fixtures that happen to live under `src/`. They are small and harmless today, but a
placeholder resource that ships is a resource a later loader can pick up by accident, and the
project has already decided the principle for `tests/`. Excluding them cannot break anything:
`exclude_filter` affects the export only, and `tests/schema_check.gd` loads them from `res://`
at development time. The change is adding `src/data/samples/*` to the existing filter. I raise
it here rather than against P0.6 because export hygiene is the surface P0.7 owns, and because
the F01-05 fix was written and verified without anyone asking what *else* the pack contained.
Worth confirming with the P0.6 critical agent before applying, since the samples are P0.6's
deliverable.

Positively: nothing else surprising is packed. No `.md`, no `docs/`, no `phases/`, no
`.claude/`, no `MASTER_SDLC.md`, no `data/**/.gitkeep`. The filter is correct and sufficient
for what it names.

### N5 - Minor: D86's Change Log row does not exist, and may not be writable as worded

D86 requires the pin in docs/28 "alongside the two Godot MCP server pins, with a version bump
and a Change Log row." Two of three are done and verifiable. The third is not: no document
under `docs/` carries a Change Log section at all (checked across all 31), and
`MASTER_SDLC.md`'s Change Log tracks the master's own version and has no row for a docs/28
bump - nor did it get one when docs/28 first reached 1.0.0 under P0.5, so there is no precedent
to follow either.

This is not a reviewer's call to resolve. Either the requirement is met by docs/28's Status line
(which does name the change, the task and the decision) and D86's wording is loose, or a row is
owed somewhere and the author has to say where. Note that the Gate Approval rule does *not*
block it - that rule reserves gate/accepted rows, not version-history rows - so if a row is
owed, an agent may draft it. As it stands a reviewer cannot check this element, which is the
reason to flag it.

Related, folded in here rather than scored separately: the pin records version, upstream org,
file count, size and content hash but **not the licence**, although `addons/gdUnit4/LICENSE` is
present, the addon is now vendored into the repository (516 files travelling with every clone),
and the sibling `godot-prompter` entry in the same document does record "(MIT)". A vendored
dependency's licence is the attribute redistribution actually turns on.

### N6 - Minor: the failing fixture is guarded only by one script default and a comment

`tests/harness/fail/test_trivial_fail.gd` is a real `GdUnitTestSuite` with a `test_*` method in
a `test_*.gd` file under `res://tests/`. It is therefore discoverable by anything that sweeps
that subtree: gdUnit4's own `runtest.cmd` / `runtest.sh`, the editor's GdUnit dock if a human
ever enables the plugin, or a future CI step that widens `-a`. The only guard is
`run_tests.ps1`'s `-TestPath` default plus a prose warning in its comment block. The design
intent is correct and clearly documented - the separate directory does let each code be
demonstrated in isolation, and I confirmed both - but "a comment is the guard" is weaker than
what was available: gdUnit4 ships `-i/--ignore`, and a committed runner config, or siting the
fixture outside `res://tests/`, would have made the hazard structural rather than advisory.
`exclude_filter` does not help here; this is a development-time hazard, not an export one.

### N7 - Minor: docs/28's `runtest.cmd` warning states an untested cause that is probably wrong

The bullet at docs/28 line 54 says of `addons/gdUnit4/runtest.cmd`: "it was read ... and passes
neither `--headless` nor `--ignoreHeadlessMode`, so following it reproduces the exact exit-103
failure this bullet describes."

Reading the file: the test-run line is
`"!godot_binary!" --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd !filtered_args!`
- no `--headless`. A separate trailing log-copy line *does* pass `--headless`. So the sentence
is inaccurate about the file as written, and the causal claim looks backwards: gdUnit4's
headless refusal fires on the headless display server, so an invocation that passes no
`--headless` at all would run *windowed*, not exit 103. I did **not** test this, because doing
so would launch a windowed Godot from the project root, and I am stating that plainly rather
than asserting a root cause I have not run - which is the rule this project derived from F-08.
The recommendation is to either test it or reword it to what was actually observed. P0.7 edited
this document to 1.1.0, so the sweep-for-superseded-wording rule reaches this bullet.

---

## 4. Things checked that are correct, and worth recording as such

- **Version pin.** `addons/gdUnit4/plugin.cfg` in the real project reads `version="6.2.1"`.
  Confirmed by direct read, not from the report.
- **The D86 pin now exists**, and every figure in it reproduces exactly under my own run of the
  verification commands docs/28 supplies: 516 files, 2.0 MB, and
  `find addons/gdUnit4 -type f | LC_ALL=C sort | xargs sha256sum | sha256sum` gives
  `5ae43377c9501520d2a6191c59e4e156aa3525ad4d9c69716db62e1d78ab8b9a`, matching the recorded hash
  character for character. Recording a content hash instead of a sha that does not exist, and
  saying in the document that no sha exists and why, is better than the pin D86 asked for.
- **`project.godot` integrity.** `git diff project.godot` is empty and
  `git status --porcelain project.godot` returns nothing; the file's last commit is still
  `bd65fd8` (P0.2). There is no `[editor_plugins]` section, so the claim that the plugin was
  never enabled is verifiable from the file rather than from the report. The Phase 00 F-03
  pattern - a tool writing a wrong version field - did not recur. The Settings check re-runs at
  exit 0 with all its assertions intact. This was the highest-risk thing P0.7 could have broken
  and it did not.
- **The trivial tests are real gdUnit4 suites.** Both `extends GdUnitTestSuite`, both files are
  `test_*.gd`, both methods are `test_*`, both typed `-> void`, and both were discovered and
  executed in my runs (`Executed test suites: (1/1)`). They assert deliberately trivial
  conditions and say so in their own doc comments. The two-directory layout genuinely isolates
  the two codes.
- **The export-hygiene finding was the implementer's, beyond its brief**, and its reasoning for
  refusing a `.gdignore` inside `addons/gdUnit4/` is correct and non-obvious: the harness loads
  the addon through the same resource scanner a `.gdignore` would blind. Declining to widen its
  own write scope and flagging instead was the right call. This is the strongest single piece of
  work in the task.
- **`-GodotPath` is parameterised with the pinned console path as its default**, and the script
  explains why the console build rather than the windowed one. Correct.

---

## 5. Score

**P0.7: 6 / 10.** Below the phase bar of 8. Precisely why:

1. **The runner reports green having run nothing (N1), on two paths I reproduced.** P0.7's
   deliverable is not four exit codes in a log; it is the harness later phases will run. The
   engine side of it is solid and I verified every code. The script side - the part this project
   will actually invoke - was never falsified against its own mechanism, and it fails the one way
   a test harness must never fail. The phase applied Carried lesson 1 thoroughly to P0.6's Schema
   check and not at all to its own runner, which is the more surprising omission because the
   lesson was in front of the author of both.
2. **A false ground written into the ledger (N2).** Exit code 1 was reachable in two minutes by a
   method the ledger itself names, without deleting anything; the record says it was unreachable
   and the mid-gate downgrade repeats the error. The Carried lesson 7 pattern reappearing inside
   the same phase that carried it forward costs more than the finding itself. The implementer's
   refusal to fabricate the row is to its credit and is not part of this deduction.
3. **A phase exit condition was unfinished at hand-back (D86), and closed only mid-gate.** The
   orchestrator caught this itself, owned it as F01-10, and the fix that landed is better than
   the decision required. That is the right behaviour and I am not double-counting it - but the
   pin did not exist when the artifacts were handed to review, and a reviewer has to score what
   was handed over.
4. Three Minors that each cost a little: an export filter arm verified against an absent
   directory (N3), eleven placeholder fixtures shipping in the pack (N4), and an unevidenced
   Change Log element plus an unrecorded licence (N5), alongside the advisory-only guard on the
   failing fixture (N6) and an untested causal claim in the document P0.7 just raised to 1.1.0
   (N7).

What holds the score at 6 rather than lower: the acceptance test's own pass condition is met on
evidence I generated myself, all four codes are now reproduced, `project.godot` came through
untouched with the Settings check still at exit 0, the version pin is real and its hash
reproduces exactly, the export filter demonstrably keeps the test surface out of the pack, and
the implementer found and correctly diagnosed an export defect nobody asked it to look for. The
honest "not reproduced" is worth something too - this project would rather have a gap it can see
than a table it cannot trust.

Smallest set of changes that would move this materially: guard `$GodotPath` with `Test-Path`,
reset `$LASTEXITCODE` before each invocation, and refuse to print PASS unless the run reports at
least one executed test case. That is roughly six lines and it closes N1 entirely.

This review does not state that any gate is passed, satisfied, met, or ready.

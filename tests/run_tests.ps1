<#
.SYNOPSIS
    Harness check (P0.7, MASTER_SDLC.md > Acceptance Test Matrix > Build Checks).

.DESCRIPTION
    Runs the gdUnit4 import pass, then the gdUnit4 headless suite, using the
    verified invocation recorded in NEXT_SESSION.md > "Facts Phase 01 must
    not re-derive" (also phases/PHASE_00_Environment_And_Connection/
    EXECUTION_LOG.md, E0.2/P0.7 rows): --headless plus -s
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd, never the skill pack's
    documented runner or flag, which do not exist in the installed gdUnit4
    v6.2.1 (finding F-11).

    Maps each of the four exit codes this project has verified into a
    distinct, human-readable message, and exits with that same code so a
    caller (CI or a human) can distinguish all four without parsing output:
        0   pass             - the suite ran, executed at least one test,
                                 and every test passed
        100 assertion failure - the suite ran and at least one test failed
        103 misconfigured     - gdUnit4 refused to run headless (this
                                 script always passes --ignoreHeadlessMode,
                                 so seeing 103 means the invocation below
                                 was changed or bypassed)
        1   not a usable run - the executable or project is missing, the
                                 import pass did not complete cleanly, the
                                 suite executed zero tests, or gdUnit4 hit an
                                 error this project has not catalogued

    WHY THE GUARDS BELOW EXIST (Phase 01 review finding N1). An earlier
    version of this script reported "PASS (exit 0)" after executing no tests
    at all, on two separate paths, both reproduced:

      1. A missing or wrong -GodotPath. In PowerShell, `& $GodotPath` on a
         nonexistent command raises a NON-TERMINATING CommandNotFoundException
         and leaves $LASTEXITCODE untouched. If the calling shell happened to
         have $LASTEXITCODE = 0, both the import guard and the switch below
         read that stale 0 and the script declared success.
      2. gdUnit4 itself exits 0 on "No test cases found, abort test run!".
         A typo in -TestPath, or pointing it at a directory with no suites,
         therefore produced a permanent green.

    Both are the same failure the whole project keeps re-learning: a check
    that cannot fail is worse than no check, because it is trusted. The
    guards are deliberately noisy and deliberately fail closed.

.PARAMETER GodotPath
    Path to the Godot 4.7.1 console executable. Defaults to the pinned path
    (docs/20 > Godot 4.x Implementation Standards > Version; CLAUDE.md >
    Tools). Must be the console build, not the windowed one, or stdout is
    lost (NEXT_SESSION.md > Known failure modes).

.PARAMETER TestPath
    res:// path passed to gdUnit4's -a option. Defaults to
    res://tests/harness/pass, the one real always-passing suite this phase
    added. tests/harness/fail exists only to demonstrate exit code 100
    (PLAN.md P0.7 step 5) and must never be swept into this default: as
    later phases add real suites under tests/, whoever adds them should
    widen this default (or pass -TestPath explicitly) rather than pointing
    it at all of res://tests, which would permanently fail on that fixture.
    Widening it is safe now that the zero-test guard exists - a typo fails
    loudly instead of going green.

.EXAMPLE
    powershell -NoProfile -File tests/run_tests.ps1

.EXAMPLE
    powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/harness/fail
#>

param(
    [string]$GodotPath = "D:\godot\Godot_v4.7.1-stable_win64_console.exe",
    [string]$TestPath = "res://tests/harness/pass"
)

$ProjectRoot = Split-Path -Parent $PSScriptRoot

# --- Guard 1: the executable must exist. ----------------------------------
# Without this, `& $GodotPath` fails non-terminatingly and leaves a stale
# $LASTEXITCODE behind for the guards below to misread as success.
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Host "NOT A USABLE RUN: Godot executable not found at '$GodotPath'. Pass -GodotPath, or install the pinned 4.7.1 console build." -ForegroundColor Red
    exit 1
}

# --- Guard 1b: the test path must be a res:// path. ------------------------
# An empty -TestPath makes gdUnit4 exit 100, which the switch below would
# otherwise report as "an assertion failed" - the wrong cause entirely.
if ([string]::IsNullOrWhiteSpace($TestPath) -or -not $TestPath.StartsWith("res://")) {
    Write-Host "NOT A USABLE RUN: -TestPath must be a res:// path inside this project; got '$TestPath'." -ForegroundColor Red
    exit 1
}

# --- Guard 2: the project must exist. -------------------------------------
$ProjectFile = Join-Path $ProjectRoot "project.godot"
if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
    Write-Host "NOT A USABLE RUN: no project.godot under '$ProjectRoot'. This script expects to live in <project>/tests/." -ForegroundColor Red
    exit 1
}

# --- Import pass ----------------------------------------------------------
# $LASTEXITCODE is cleared first so a stale value from the calling shell can
# never be mistaken for this command's result.
Write-Host "Import pass: $GodotPath --headless --path $ProjectRoot --import"
$global:LASTEXITCODE = $null
& $GodotPath --headless --path $ProjectRoot --import | Out-Null
$importExit = $LASTEXITCODE

if ($null -eq $importExit) {
    Write-Host "NOT A USABLE RUN: the import pass produced no exit code, so it never actually ran. Check that '$GodotPath' is executable." -ForegroundColor Red
    exit 1
}
if ($importExit -ne 0) {
    Write-Host "NOT A USABLE RUN (import exit $importExit): the import pass did not run cleanly, so gdUnit4 cannot be trusted to run next. Fix the import error first." -ForegroundColor Red
    exit 1
}

# --- Test suite -----------------------------------------------------------
Write-Host "Test suite: $GodotPath --headless --path $ProjectRoot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a $TestPath --ignoreHeadlessMode"
# Captured in memory rather than through a temp file: an unwritable TEMP used to
# turn a genuinely passing suite into a reported failure, and discarded every
# diagnostic line with it (finding NEW-7a).
$global:LASTEXITCODE = $null
$suiteLines = & $GodotPath --headless --path $ProjectRoot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a $TestPath --ignoreHeadlessMode 2>&1
$testExit = $LASTEXITCODE
$suiteOutput = ($suiteLines | Out-String)
Write-Host $suiteOutput

if ($null -eq $testExit) {
    Write-Host "NOT A USABLE RUN: the suite produced no exit code, so it never actually ran." -ForegroundColor Red
    exit 1
}

# --- Guard 3: a claimed pass must prove it executed something. ------------
# This gates ONLY the exit-code-0 case, and that scoping is load-bearing.
# A real 103 (headless flag missing) and a real 1 (import pass not run) both
# fail before gdUnit4 prints any summary, so an unconditional anchor check
# swallowed those two codes and relayed both as 1 with a message naming causes
# that had not occurred - breaking the four-way distinction CI depends on
# (finding NEW-6). The four codes are only distinguishable if this guard
# refuses to speak about anything but a claimed success.
#
# Within exit 0 the check is a POSITIVE assertion, because gdUnit4 exits 0 when
# it finds no test cases at all. An earlier version matched negatively on
# "No test cases found", which failed OPEN whenever stdout was not captured:
# the marker was simply absent, the exit code was still 0, and the script
# reported PASS for a run that executed nothing (finding F01-36).
if ($testExit -eq 0) {
    if ($suiteOutput -match 'No test cases found') {
        Write-Host "NOT A USABLE RUN: gdUnit4 found no test cases under '$TestPath' and aborted. Zero tests executed is never a pass - check the path for a typo." -ForegroundColor Red
        exit 1
    }

    $executed = $null
    if ($suiteOutput -match 'Executed test cases\s*:\s*\((\d+)\s*/\s*(\d+)\)') {
        $executed = [int]$Matches[1]
    }

    if ($null -eq $executed) {
        Write-Host "NOT A USABLE RUN: the run reported exit 0, but gdUnit4's 'Executed test cases' summary is absent, so there is no evidence any test ran. This is what a lost stdout or a -GodotPath pointing at something other than Godot looks like." -ForegroundColor Red
        exit 1
    }
    if ($executed -lt 1) {
        Write-Host "NOT A USABLE RUN: gdUnit4 executed 0 test cases under '$TestPath' and exited 0. Zero tests executed is never a pass." -ForegroundColor Red
        exit 1
    }
}

switch ($testExit) {
    0   { Write-Host "PASS (exit 0): $executed test case(s) executed under $TestPath, all passed." -ForegroundColor Green; exit 0 }
    100 { Write-Host "FAIL (exit 100): the suite ran; at least one assertion failed under $TestPath." -ForegroundColor Red; exit 100 }
    103 { Write-Host "MISCONFIGURED (exit 103): gdUnit4 refused to run headless. This script always passes --ignoreHeadlessMode, so the invocation above must have been changed or bypassed." -ForegroundColor Yellow; exit 103 }
    1   { Write-Host "NOT A USABLE RUN (exit 1): gdUnit4 failed to load. On a fresh checkout this means the import pass has not built the script-class cache - reproduced in Phase 01 as 'Parse Error: Could not find type GdUnitTestCIRunner'. This script runs the import pass first, so seeing it here means the import silently did not take effect." -ForegroundColor Yellow; exit 1 }
    default { Write-Host "UNKNOWN (exit $testExit): not one of the four codes this project has catalogued (0/100/103/1). Treat as an unusable run and investigate before trusting any other result." -ForegroundColor Yellow; exit 1 }
}

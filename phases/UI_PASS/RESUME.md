# UI Pass - RESUME HERE

State on 2026-09-20 after review iteration 1 and its fixes. Everything is committed on branch `ui-pass`; nothing is on `main`.

## Where things are

- **Worktree:** `D:\Gamedev-ui-pass`, branch `ui-pass`, on top of `main` at `3ef4bc7`. `main` is at `c076fc2`; a read-only `git merge-tree` reports no conflicts and the two branches share no changed file.
- **Reviewed once, blind.** `REVIEW.md` holds the reviewer's report verbatim (verdict "accept with fixes", 5/10, no blocker). `LEDGER.md` tracks 27 findings, UR-01 to UR-27: none open; UR-08, UR-20 and UR-21 each carry a part deferred to an owner outside this branch.
- **Author decisions taken on 2026-09-20:** the UI font is Jersey 10; the Console's 24 px floor covers the row label and the price / MAX tag; the Console may use about 35% of screen height; the compact Console rows stay. Proposed docs/19 text and Review Decision Log rows: `HANDOFF.md` H-05, H-06 and `CLOSE_OUT_PROPOSALS.md`.
- **Measured:** full suite through `tests/run_tests.ps1`, started after the last code edit: 598 test cases, 0 errors, 2 failures, the baseline's two by name (`evidence/after_results_round2.xml`). 5 engine error lines, all leaks at exit, not yet attributed. Console panel 520x370 px at base resolution.
- **Looked at:** five screenshot sets, nine states each, every frame exactly 1920x1080 or 1280x720: `before_1920`, `before_1280`, `after_1920`, `after_1280`, `after_1920_pseudo`. Threat feedback is in all of them.

## What is NOT done

1. **Review iteration 2.** The fixes have not been blind-reviewed. If it is run, give the reviewer the request, the claims and paths only, and have it re-grade from disk, not from iteration 1's scores.
2. **Merge** is the author's: from `D:\Gamedev`, `git merge ui-pass`. Then, per `HANDOFF.md` H-09, run the suite on the merged tree - `main` carries an assembled-scene integration suite this branch has never run - and run the capture tool once: its stdout prints a WARNING line if the Console still has no Tower reference in the real scene.
3. **Close-out text is drafted, not applied:** `CLOSE_OUT_PROPOSALS.md` has the `phases/LESSONS.md` rows, three Review Decision Log rows and the Change Log row. All are outside this branch's write scope.
4. **HANDOFF items open for other owners:** H-02 (a real translation file; all wording in `src/ui/theme/ui_strings.gd` wants the author's eye), H-03, H-04, H-07, H-08, H-09. H-01 is already fixed on `main`.
5. **Noticed, not acted on:** the off-screen Tower indicator is a 16 px circle or 20 px diamond, set in from the screen edge; it is easy to miss and its size and placement predate the pass. The engine's leak-at-exit lines have no baseline to compare against.

## How to pick it up

```
cd /d/Gamedev-ui-pass
git status                      # expect clean
# screenshots of the launched scene (a borderless window opens for about 30 s; audio is muted):
/d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 res://src/ui/dev/ui_capture.tscn -- --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/after_1920 --size=1920x1080
# add --pseudo for the pseudo-localized set; use 1280x720 in both places for the small set
# full suite (about 10 minutes), from PowerShell:
.\tests\run_tests.ps1 -TestPath "res://tests"
```

Read `PLAN.md`, `BRIEF.md` and `BRIEF_R2.md`, then `LEDGER.md`, then `FAILURE_POINTS.md` (UP-01 to UP-13), then `HANDOFF.md`.

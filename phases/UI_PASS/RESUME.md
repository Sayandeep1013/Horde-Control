# UI Pass - RESUME HERE

Stopped 2026-09-20 at the author's request, mid-way through the review step. Everything built so far is committed on branch `ui-pass`; nothing is on `main`.

## Where things are

- **Worktree:** `D:\Gamedev-ui-pass`, branch `ui-pass`, on top of `main` at `3ef4bc7`. `main` has since moved to `c076fc2`; a read-only `git merge-tree ui-pass main` reported no conflicts.
- **Built and committed:** the palette, theme, font and runtime strings; the restyle of all seven surfaces; the capture tool; two new tests; the screenshots; this record.
- **Measured:** full suite 591 tests, 2 failing, the same 2 as the 588-test baseline (`evidence/`). Banned-API check: 0 banned calls. Console suites and the highlight test re-run on the final code: 22 cases, 0 failures.
- **Looked at:** `screenshots/after_1920`, `after_1280`, `after_1920_pseudo` - six states each, against `before_1920`.

## What is NOT done

1. **The blind Opus review was started and then stopped unfinished.** No review result exists. Re-run it: the `critical-reviewer` agent, given only the original request, the claims list, and artifact paths. `LEDGER.md` and `REVIEW.md` do not exist yet; they are written from that review.
2. **Fix what the review finds**, re-run the full suite, re-take the screenshots if anything visual changes.
3. **Known loose ends the review was asked to judge** (not yet acted on):
   - `TODO(ui-pass)` local constants in the package files that may belong in `UiPalette` (each package report lists its own).
   - `UiStrings.ensure_registered()` is called from inside `UiTheme.get_theme()`; convenient, but a hidden coupling.
   - The Console panel measures 512x377 px, about 17 px over the 360 px target and over docs/19's 30%-of-height default (324 px); seven rows at the 24 px text floor set the minimum. Scrolling was deliberately not added. This may be a question for the author.
   - The Console row label's composition changed by orchestrator decision (FAILURE_POINTS UP-08). It is the one departure from "no wording change" and wants the author's eye, as does all wording in `src/ui/theme/ui_strings.gd` (HANDOFF H-02).
   - An exact 1920x1080 frame was never captured; the desktop clamps the window to 1875x1055 (UP-05).
4. **HANDOFF.md** items H-02, H-03, H-04 are still open requests to the owners of those files. H-01 is already fixed on `main` (`66e623e`).
5. **Merge** is the author's: from `D:\Gamedev`, `git merge ui-pass`. After merging, re-run the capture tool once without its reference injection firing - its stdout prints a WARNING line if the Console still has no Tower reference - to confirm the Console opens in the real scene.
6. **Close-out not written:** no `phases/LESSONS.md` entry, no Review Decision Log row, no Change Log row. All three are outside this branch's write scope and are proposed text for the author, not yet drafted.

## How to pick it up

```
cd /d/Gamedev-ui-pass
git status                      # expect clean
# screenshots of the launched scene (a window opens for about 25 s):
/d/godot/Godot_v4.7.1-stable_win64_console.exe --path . --resolution 1920x1080 res://src/ui/dev/ui_capture.tscn -- --out=D:/Gamedev-ui-pass/phases/UI_PASS/screenshots/after_1920
# full suite (about 10 minutes):
/d/godot/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Read `PLAN.md`, then `FAILURE_POINTS.md` (UP-01 to UP-08), then `HANDOFF.md`, then the four `package_reports/`.

# UI Pass - HANDOFF

Requests for changes outside the UI pass's write allow-list. None of these edits were made on the `ui-pass` branch. Each names the file's owner-side fix and the exact proposed text.

## H-01 - The Console cannot open in the assembled scene (Major, found by measurement)

**File:** `scenes/prototype.tscn`, the `Console` node.

**What was measured.** The capture tool (`src/ui/dev/ui_capture.gd`) loaded the real `scenes/prototype.tscn`, parked the player 136 px from the Tower's centre (inside the 160 px Interaction Radius, outside the 106 px footprint), standing still, holding 150 Scrap, for 90 physics frames. The Console did not open. Its own state at that moment: `_tower == null`, `_interaction_radius == null`, `_has_any_affordable_entry() == false`, not paused, no re-entry lock.

**Cause.** The four NodePaths are authored relative to the scene root, but `Console._ready()` resolves them with `get_node_or_null()` relative to the Console node itself, which is a child of the root:

```
[node name="Console" parent="." instance=ExtResource("22_console")]
tower_path = NodePath("Main/Tower")
player_path = NodePath("Main/Player")
upgrade_system_path = NodePath("Main/UpgradeSystem")
camera_path = NodePath("Main/Player/GameCamera")
```

`Console/Main/Tower` does not exist, so all four references are null and `physics_step()` returns at its first guard on every tick. Every Console unit test injects the references through the `_for_test` setters, so none of them can see this.

**Proposed fix.**

```
tower_path = NodePath("../Main/Tower")
player_path = NodePath("../Main/Player")
upgrade_system_path = NodePath("../Main/UpgradeSystem")
camera_path = NodePath("../Main/Player/GameCamera")
```

**Proposed test**, for the assembled-scene assertion suite Phase 05 already carries as unreached work: instance `scenes/prototype.tscn`, and assert that the Console's Tower, Player, UpgradeSystem and camera references are all non-null after `_ready()`.

**Confirmation.** With the four references injected by the capture tool and nothing else changed, the Console opened on the same staging (`open=true inside=true affordable=true`).

**Status, checked 2026-09-20 after the screenshots were taken:** `main` has since moved to `c076fc2`, and its commit `66e623e` changes these four paths to exactly the `../Main/...` form above (and the RunFlowController's two paths the same way). The defect was found independently on both sides. `ui-pass` was cut before that commit, so it still carries the broken paths until it is merged; a read-only `git merge-tree ui-pass main` reports no conflicts. No further action is requested for H-01 beyond the merge, and the proposed assembled-scene assertion if `main` does not already have one.

**On this branch, until it is merged**, every Console screenshot in `screenshots/` was taken with references injected by the capture tool. They show what the Console looks like, not that it opens in the real game.

## H-02 - No translation file exists; every `tr()` key rendered as its raw key (Major for presentation)

**Files:** `project.godot` (`internationalization/locale/translations`), plus a new `.csv` or `.po`.

**What was measured.** 33 distinct `tr("...")` keys are used under `src/`. The repository tracks no `.csv`, `.po` or `.translation` file, and `project.godot` registers none. In the launched scene the HUD read `HUD_WAVE 1/8`, `HUD_LEVEL 0`, `HUD_REROLLS: 1`, and the run-end screen read `RUN_END_CAUSE: RUN_END_CAUSE_TOWER` (`screenshots/before_1920/`).

**What the UI pass did inside its scope.** `src/ui/theme/ui_strings.gd` registers an English `Translation` at runtime, from `UiTheme.get_theme()`. No test asserts a raw key; the two tests that read these strings compare against `tr()` at assertion time, so they agree either way.

**Proposed durable fix.** Move `UiStrings.MESSAGES` into `assets/i18n/ui.csv` (columns `keys,en`), register its imported `.translation` in `project.godot`, then delete `ui_strings.gd` and the single `UiStrings.ensure_registered()` call in `ui_theme.gd`. The wording needs the author's eye: it follows docs/19 where docs/19 gives wording ("Wave n/8", "FULL", "Rank n of 3", "MAX") and is otherwise the UI pass's own.

## H-03 - The debug overlay opens by default and covers the player health field (Minor)

**File:** `src/debug/overlay.gd` / `scenes/prototype.tscn`.

**What was measured.** On the first capture run, before the capture tool learned to hide it, the F1 overlay's panel sat at the top-left at roughly 490x400 px, drawn over the HUD's top-left Player Health field, the one docs/19 places there. That frame was overwritten and is not in `screenshots/`: every committed frame was taken with the overlay hidden (`src/ui/dev/ui_capture.gd`, the `DebugOverlay` lines in `_run()`), so no committed screenshot shows this. The evidence that stands on its own is the code: `src/debug/overlay.gd` declares `var _visible_overlay: bool = true`, so the overlay is on at launch until F1 is pressed.

**Proposed fix (author's choice):** start the overlay hidden (F1 shows it), or anchor it bottom-left, clear of all four HUD fields. Before the P2.16 external testers either is enough.

## H-04 - `PausedChoiceBar` marks the highlighted option by colour alone (Minor, rule conflict)

**File:** `src/run/paused_choice_bar.gd`, `_refresh_highlight()`.

**Rule.** MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions": no gameplay-critical information through colour alone. The bar's highlight is `modulate = Color(1.0, 0.85, 0.2)` and nothing else.

**What the UI pass did inside its scope.** The three menus add their own shape cue from outside the bar, driven by its `highlighted_changed` signal (see `package_reports/D_menus.md` for the mechanism and its limits).

**Proposed fix.** See `package_reports/D_menus.md`, "Proposed change to paused_choice_bar.gd", for the exact text.

## H-05 - Tower Console height allowance (Author decision 2026-09-20; needs a docs/19 edit, a Register check and a Review Decision Log row)

**Files:** `docs/19_UI_UX.md` > "Max Dimensions"; `MASTER_SDLC.md` > Review Decision Log (and the Provisional Values Register, if it carries the 30% figure as a row).

**What was measured.** Seven one-line Console entries at the Register's 24 px text floor need more than docs/19's general cap of 30% of screen height (324 px at 1080p). The author was asked on 2026-09-20 and chose a Console-specific allowance of about 35% over scrolling the list or dropping the effect footer.

**Proposed docs/19 text**, appended to the "Max Dimensions" bullet: "The Tower Console is the second exception: its cap is 35% of screen height, because it lists every entry at once at the 24 px text floor and never pauses the game, so a scrolling list would hide entries while enemies are active."

**Proposed Review Decision Log row:** "| D1xx | Author decision (2026-09-20): the Tower Console panel may be up to 35% of screen height; docs/19's general 30% container cap stays for everything else | Keep 30% and scroll the entry list, or keep 30% and drop the highlighted entry's effect footer | The Console does not pause the game. Seven entries at the 24 px floor measure about 377 px at 1080p; scrolling would hide purchasable entries during combat, and the footer is the only place the Console states what an upgrade does now that rows are one line (UI pass LEDGER UR-25, UR-26) |". Take the next free D number on `main` (D104 was the last at `c076fc2`).

## H-06 - Tower Console text floor scope and row composition (Author decision 2026-09-20; needs a Review Decision Log row)

**Files:** `MASTER_SDLC.md` > Review Decision Log; `docs/19_UI_UX.md` > Tower Console.

**Decisions.** (1) The 24 px floor covers the entry row label and the price / MAX badge, which the Register names as entry content; the panel's header title, footer hint, key number and pool word may be smaller. The alternatives were every label in the panel, or the row label only. (2) Each entry row reads "<name> <rank status>" on one line with the price in its own tag, and the highlighted entry's effect sentence is shown in a footer; the alternative was the full effect sentence in every row, which measured about 672x773 px and ran off the top of a 1080p screen (FAILURE_POINTS UP-08).

**Proposed docs/19 text**, in the Tower Console section: "Each entry is one line: name and rank status, with the price (or MAX) in a tag at the row's end. The highlighted entry's effect sentence is shown once, in a footer beneath the list. The 24 px floor applies to the entry line and its price or MAX tag."

## H-07 - `run_flow_controller.gd` calls `tr()` without registering the strings (Minor)

**File:** `src/run/run_flow_controller.gd`, around lines 487-489 (`tr("RUN_END_CAUSE_PLAYER")`, `tr("RUN_END_CAUSE_TOWER")`).

**What is wrong.** Until H-02's translation file exists, English strings come from `UiStrings.ensure_registered()`. Every `src/ui` surface now calls it explicitly, but this controller is outside the UI pass's write scope and resolves its two keys only because a UI surface registered the strings earlier in the run.

**Proposed fix**, only if H-02 is not done first: add `UiStrings.ensure_registered()` as the first line of the function that builds `cause_text`. H-02 makes this unnecessary and is the better fix.

## H-08 - Keep the capture tool out of exported builds (Minor)

**File:** `export_presets.cfg`, line 11.

**Proposed fix.** Add `src/ui/dev/*` to the preset's `exclude_filter`, which today reads `exclude_filter="addons/gdUnit4/*, tests/*, reports/*, src/data/samples/*"`; proposed: `exclude_filter="addons/gdUnit4/*, tests/*, reports/*, src/data/samples/*, src/ui/dev/*"`. Nothing in `src/`, `scenes/`, `tests/` or `project.godot` references `ui_capture` (checked by grep on 2026-09-20), so excluding it cannot break a build. A `.gdignore` in `src/ui/dev/` was not used because it would also hide the tool from the editor and from `--path` runs.

## H-09 - Re-run the full suite on the merged tree (for whoever merges)

`ui-pass` was cut from `3ef4bc7`. `main` has since changed `tests/unit/teaching_siege_tuning_test.gd` and `tests/unit/tower_damage_path_test.gd` and added `tests/unit/prototype_integration_test.gd`, which instantiates `scenes/prototype.tscn` and reads the HUD. The two branches share no changed file and `git merge-tree` reports no conflict, but no test run covers the merged tree. After `git merge ui-pass`, run the suite through `tests/run_tests.ps1` and record the summary line beside the merge.


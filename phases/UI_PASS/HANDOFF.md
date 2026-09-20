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

**Until it is fixed**, every Console screenshot in `screenshots/` was taken with references injected by the capture tool. They show what the Console looks like, not that it opens in the real game.

## H-02 - No translation file exists; every `tr()` key rendered as its raw key (Major for presentation)

**Files:** `project.godot` (`internationalization/locale/translations`), plus a new `.csv` or `.po`.

**What was measured.** 33 distinct `tr("...")` keys are used under `src/`. The repository tracks no `.csv`, `.po` or `.translation` file, and `project.godot` registers none. In the launched scene the HUD read `HUD_WAVE 1/8`, `HUD_LEVEL 0`, `HUD_REROLLS: 1`, and the run-end screen read `RUN_END_CAUSE: RUN_END_CAUSE_TOWER` (`screenshots/before_1920/`).

**What the UI pass did inside its scope.** `src/ui/theme/ui_strings.gd` registers an English `Translation` at runtime, from `UiTheme.get_theme()`. No test asserts a raw key; the two tests that read these strings compare against `tr()` at assertion time, so they agree either way.

**Proposed durable fix.** Move `UiStrings.MESSAGES` into `assets/i18n/ui.csv` (columns `keys,en`), register its imported `.translation` in `project.godot`, then delete `ui_strings.gd` and the single `UiStrings.ensure_registered()` call in `ui_theme.gd`. The wording needs the author's eye: it follows docs/19 where docs/19 gives wording ("Wave n/8", "FULL", "Rank n of 3", "MAX") and is otherwise the UI pass's own.

## H-03 - The debug overlay opens by default and covers the player health field (Minor)

**File:** `src/debug/overlay.gd` / `scenes/prototype.tscn`.

**What was measured.** `screenshots/before_1920/01_hud_gameplay.png` on the first capture run: the F1 overlay's panel sits at the top-left at roughly 490x400 px and is drawn over the HUD's top-left Player Health field, the one docs/19 places there.

**Proposed fix (author's choice):** start the overlay hidden (F1 shows it), or anchor it bottom-left, clear of all four HUD fields. Before the P2.16 external testers either is enough.

## H-04 - `PausedChoiceBar` marks the highlighted option by colour alone (Minor, rule conflict)

**File:** `src/run/paused_choice_bar.gd`, `_refresh_highlight()`.

**Rule.** MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions": no gameplay-critical information through colour alone. The bar's highlight is `modulate = Color(1.0, 0.85, 0.2)` and nothing else.

**What the UI pass did inside its scope.** The three menus add their own shape cue from outside the bar, driven by its `highlighted_changed` signal (see `package_reports/D_menus.md` for the mechanism and its limits).

**Proposed fix.** See `package_reports/D_menus.md`, "Proposed change to paused_choice_bar.gd", for the exact text.

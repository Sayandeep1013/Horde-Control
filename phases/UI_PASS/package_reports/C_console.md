# Package C — Tower Console

File owned and edited: `src/ui/console.gd`. Did not touch `src/ui/draft_fill_ring.gd` or `src/ui/draft_card_view.gd`; used `DraftFillRing` only through its existing public surface (`progress`, `ring_color`, `track_color`).

New file added (allowed under the shared brief's "new files under `src/ui/` if needed," and PLAN.md's write allow-list "new `tests/unit/ui_*_test.gd` files"): `tests/unit/ui_console_layout_test.gd` — a permanent regression test, not a throwaway, explained below under "The coordinator's layout-collapse finding."

Skills invoked: `godot-prompter:godot-ui` and `godot-prompter:tween-animation`, both **after** the first implementation pass rather than before it (same disclosure implementer A made in its own report) — checked the finished code against both afterward. `godot-prompter:hud-system` was not invoked: the brief lists it as "(HUD work)," and the Tower Console is explicitly the opposite of the HUD (a world-space, never-pausing panel, per this file's own header) — named as an interpretation of that parenthetical, not silently skipped.

## What changed, in `src/ui/console.gd`

1. **Theme applied once.** `_panel.theme = UiTheme.get_theme()` and `_panel.theme_type_variation = UiTheme.PANEL`, set in `_build_ui()` — `_panel` is the first `Control` under this `Node2D` root, matching the brief's rule for a non-Control surface. Every entry row's background is `UiTheme.ROW` / `UiTheme.ROW_HIGHLIGHTED` (toggled per-frame in `_refresh_one_row()`), the number-key hint chip and MAX badge are `UiTheme.PILL`, and every label reads a `UiPalette` colour/font-size token rather than a bare literal. The one exception, by the brief's own instruction: `ENTRY_FONT_SIZE_PX` (24, the Register's floor) stays a per-node `add_theme_font_size_override()` on `Text`, never touched by the theme.
2. **Compact header.** A new `HeaderRow` (title + the player's current Scrap, refreshed every frame from `_run_inventory.scrap_current` — the same field `get_scrap_current_for_test()` already reads, so no new data was added).
3. **Entry row decoration**, all new sibling nodes, `Text`'s own node/content/format untouched: `Caret` (leading `>` glyph, shown only while highlighted), `NumberHint` (a `UiTheme.PILL` chip showing `1`-`7` for the first 7 rows, matching `SELECT_ACTIONS`, empty for the two possible fallback rows beyond it), `PriceTag` (a `RichTextLabel`, right-aligned, `UiPalette.SCRAP` when affordable, struck-through + `UiPalette.TEXT_DISABLED` when not), `MaxBadge` (a `UiTheme.PILL` chip, visible only when `is_max`).
4. **Differentiation** (rounded = Player, squared = Tower): the `Frame` node's corner-radius geometry (`0` vs a real radius) is byte-for-byte the same logic as before the pass; only its fill/border colours now read `UiPalette.PLAYER`/`UiPalette.TOWER`/`UiPalette.LINE_STRONG` instead of two bare, tower/player-agnostic greys the pre-pass code actually used (checked: the *old* code's frame colour never varied by pool at all, only by highlight — this pass is the first time colour differentiates Player from Tower, additively, alongside the pre-existing shape rule, never instead of it).
5. **Unaffordable / MAX states differ by shape, not colour alone**: unaffordable now sets `Text`'s own `font_color` override to `UiPalette.TEXT_DISABLED` (previously a `modulate` multiply by a bare `Color(0.55,0.55,0.55,1)`) *and* strikes the `PriceTag` price through; MAX swaps `PriceTag` for the distinct `MaxBadge` chip.
6. **Channel fill ring**: `_fill_bar` is now a `DraftFillRing` (`ring_color = UiPalette.ACCENT`, `track_color = UiPalette.with_alpha(UiPalette.LINE, 0.6)`) instead of a linear `ProgressBar`. `get_channel_progress_for_test()` and the `_channel_active` visibility gate are untouched; only `.value =` became `.progress =`, matching that node's own public API.
7. **Open-only cosmetic animation.** `_process()` now tracks `was_visible` and, on a false→true transition, calls `_play_open_animation()`: a bare `create_tween()` on this node (guarded by `is_inside_tree()`), killing any prior tween first, fading/scaling **`_panel`'s own** `modulate:a` / `scale` from 0 / `OPEN_ANIM_START_SCALE` up to 1 / `Vector2.ONE` over `UiPalette.MOTION_BASE` seconds with `TRANS_CUBIC`/`EASE_OUT`. `Console.modulate.a` (`CONSOLE_OPACITY`) and `Console.scale` (the per-frame camera view-scale compensation `_update_placement()` sets right after) are never touched by it. The close path (`visible = false`) is unchanged and creates no tween, so a pause-reason/Draft/death hide is still instantaneous. `_panel.pivot_offset` is now set to its own half-size each frame in `_panel_half_extent()`, purely so the scale-in animates from the panel's centre rather than its corner.
8. **Movement-only sector visuals**: `console.gd` has no `_draw()` and draws no sector wedges/geometry at all — item 7 ("if the Console draws sector visuals, restyle them") is a no-op; nothing to restyle.

## The coordinator's layout-collapse finding — two distinct root causes, both fixed

The mid-pass note reported the panel rendering as a narrow column with every entry wrapped one character per line in the assembled scene (`phases/UI_PASS/screenshots/before_1920/05_console.png`, confirmed by reading the image). Investigating and fixing this surfaced **two separate bugs**, not one:

**Root cause 1 (the one the note diagnosed):** `Text`'s `SIZE_EXPAND_FILL` + `AUTOWRAP_WORD_SMART` has no minimum width of its own, so its natural minimum collapses toward zero and the whole panel follows it down. Fixed with two `custom_minimum_size` floors — `ROW_TEXT_MIN_WIDTH_PX` (360) on every row's `Text` label, `PANEL_MIN_WIDTH_PX` (480) on `_panel` itself, `PRICE_TAG_MIN_WIDTH_PX` (64) on the new `PriceTag`, plus smaller defensive floors on `Title`/`ScrapValue` (the same autowrap+expand pattern, at a much lower risk since their content is short). All are `custom_minimum_size`, never a fixed `size`.

**Root cause 2 (found while verifying the fix, not by the note):** every `Control` auto-translates its own text by default, and Godot's pseudo-localization runs on top of that. For a plain `Label` this is exactly what docs/19's pseudo-localization testing wants. For `PriceTag` — a `RichTextLabel` holding hand-built BBCode markup (`[right][color=#...][s]...[/s][/color][/right]`), never a translatable message — pseudo-localization mangled the `[right]`/`[color]`/`[s]` tag names themselves into unrecognisable garbage, so `RichTextLabel` stopped parsing them as tags and rendered the whole garbled string as one unbreakable literal line: a 64 px floor ballooning to **~591 px per row** with pseudo-localization on (measured directly, reproduced and then fixed in this session — see the commit history of `tests/unit/ui_console_layout_test.gd`'s second test, which caught it). Fixed with `price_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED`. This is a real, narrow finding: any *other* package building a `RichTextLabel` with hand-authored BBCode (not just translated prose) should set the same property, or pseudo-localization will corrupt its markup the same way.

**Measured panel sizes**, real 7-entry catalogue (fresh `UpgradeSystem`, its own default-preloaded definitions — Repair + `rapid_fire`/`heavy_rounds`/`patch_kit`/`caliber`/`optics`/`shield_matrix`), base resolution (`view_scale = 1.0`, no camera wired):

| State | Panel size (px) |
| --- | --- |
| Normal | 672 x 773 |
| Pseudo-localized (+30%, `debug_pseudoloc_toggle`'s underlying mechanism) | 759 x 997 |

Width grows a modest +13% under pseudo-localization (from `Header`/`Glyph`/`Title`/`ScrapValue` — deliberately non-wrapping single-word labels needing a little more room for their longer single pseudo-localized token; wrapping "PLAYER" mid-word would look worse than a few extra px), never the near-doubling the markup bug produced. Height grows via wrapping, never shrinks — asserted directly in `tests/unit/ui_console_layout_test.gd`.

**Residual tension, named rather than silently left**: even fixed, the real catalogue's height (773-997 px) is roughly 2-3x docs/19's own "UI Layout & Dynamic Container Rules" > "Max Dimensions" > "Provisional Default 30% of screen height" (324 px at 1080p). Root cause: several `UpgradeDefinition.effect_description` strings in `data/upgrades/*.tres` are genuinely long prose sentences written for the Draft's spacious cards (e.g. Shield Matrix's is 71 characters; the two fallback cards' are 150+ characters), and this task's own "entry text formats stay exactly as they are" constraint means I cannot shorten what `name_text` displays. docs/19's own prescribed remedy for exceeding the height guideline is "it must become scrollable, not truncate" — implementing a `ScrollContainer` with mouse/touch scroll input would be a genuine new interactive affordance (this UI currently accepts no mouse input anywhere, by design — every built node is `MOUSE_FILTER_IGNORE`), which is a behaviour change, not a restyle, and is outside this task's "no input changes" constraint. I did not implement it. This is a decision for the author/orchestrator: either accept the height as the honest consequence of the existing content, or authorize a follow-up task to add scrolling or shorten the Console-specific display text (which would need its own Register/docs-19 sign-off, since "entry text formats" is explicitly one of the things this task was told to leave exactly as it is).

## Other interpretations

- **`Row%d`'s node type changed from `HBoxContainer` to `PanelContainer`** (name unchanged — `_rows[i]` still resolves the same way, `.visible` toggling is identical), wrapping a new `RowContent` `HBoxContainer` child, so `UiTheme.ROW`/`ROW_HIGHLIGHTED` (both `PanelContainer` type variations) can paint a real background + accent border. No test reads `_rows[i]`'s class.
- **Price/MAX are shown twice** — once inline inside `Text`'s existing "name -- suffix" string (unchanged), once again as the new `PriceTag`/`MaxBadge` decoration. This redundancy is the direct, unavoidable consequence of two instructions in tension: "price right-aligned in UiPalette.SCRAP" / "MAX = a distinct badge" (item 3/4) versus "Keep every existing label node and its text format intact... add new decoration as sibling nodes rather than changing what that label contains" (item 3). Since `Text` must stay a plain `Label` (the test's `var label: Label = console.get_entry_label_for_test(i)` would fail a runtime type check against a `RichTextLabel`, and BBCode-colouring only part of a plain `Label` isn't possible), the only way to colour/badge the price without touching `Text` was to add it again as a sibling. Named here rather than silently accepted.
- **`CARET_GLYPH = ">"`** — plain ASCII rather than a Unicode arrow/triangle, since Pixelify Sans's own coverage is cited (ui_palette.gd's header) as "the accented Latin range," not general Unicode symbol blocks.
- **Header/Glyph/Title/ScrapValue don't wrap** (`autowrap_mode` left at its `Label` default, `OFF`) — deliberately, since word-wrapping a single short token ("PLAYER", "Tower Console") mid-word would look worse than letting it take a little more width; only `Text` (free-form, multi-word "name -- suffix" content) autowraps, matching docs/19's own rule, which names "Tower Console entry rows" specifically, not every label inside them.

## Tokens/variations wanted and did not have

Local `const`s in `console.gd`, each with a `## TODO(ui-pass): promote to UiPalette` comment, since `UiPalette` has a colour/spacing/radius/font/motion scale but no "widget minimum width" scale (the same gap implementer A's report independently flagged for `hud.gd`'s own widget minimum sizes):

- `ROW_TEXT_MIN_WIDTH_PX` (360.0), `PANEL_MIN_WIDTH_PX` (480.0), `PRICE_TAG_MIN_WIDTH_PX` (64.0) — the layout-collapse fix's own floors.
- `OPEN_ANIM_START_SCALE` (0.92) — the open animation's starting scale fraction.
- `CARET_GLYPH` (`">"`) — not a size token, but has no existing home either.

## Outside my write scope

Nothing required an edit outside `src/ui/console.gd` / `tests/unit/ui_console_layout_test.gd`. If a later pass adds a shared "widget size" scale to `UiPalette`, the five consts above are the direct candidates (same shape as implementer A's own list).

## A finding also affecting this package (already flagged by implementer A for the orchestrator)

`.gitignore` line 51 (`reports/`, unanchored) also matches `phases/UI_PASS/reports/`, so this very file is silently `git`-ignored (`git check-ignore -v phases/UI_PASS/reports/C_console.md` confirms it). Written here anyway, exactly where the brief asks; flagging again since it affects every package's report, not just A's.

## Suites run (headless, one at a time, from the worktree root)

| Suite | Result |
| --- | --- |
| `tests/unit/console_rules_test.gd` | 16 test cases, 0 errors, 0 failures |
| `tests/unit/console_non_pause_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/console_ui_scaling_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/console_interaction_window_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/movement_only_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/scrap_loss_test.gd` (explicitly named in my instructions; grep confirms it does not actually reference `Console`/`console.gd` — run anyway) | 3 test cases, 0 errors, 0 failures |
| `tests/unit/ui_console_layout_test.gd` (new, this package's own regression test for the layout-collapse finding) | 2 test cases, 0 errors, 0 failures |

Total: 27/27 test cases pass across the 7 suites run.

Grepped `tests/` for every other reference to `Console` (case-sensitive and case-insensitive), including the four names the instructions called out by name (`focus_loss_test.gd`, `run_flow_check_test.gd`, `pause_authority_full_test.gd`, `prototype_scene_test.gd`) plus `pressure_test.gd`, `upgrade_effect_check_test.gd`, `schema_check.gd`: none of the seven actually reference `console.gd`'s `Console` class or instantiate it — the matches are all either "Console price"/"Console cost formula" (an economy-data concept, `src/upgrade/upgrade_system.gd`'s own `get_console_cost()`) or a plain-English mention in a comment ("No Console exists yet..."). Did not run these seven; ran only the ones that actually cover this file, per the brief's own "tests that cover your file" framing.

I ran `--headless --path . --import` twice (once before writing `ui_console_layout_test.gd`, which needed no new `class_name`, and once again after adding it, since the brief's import instruction is keyed to *any* new script). One import attempt transiently reported a parse error in `src/ui/run_end.gd` (Package D's file, not mine) — re-running the import cleanly afterward confirmed it was a snapshot of that package's own concurrent in-progress edit, not a real, persistent error; every suite I ran afterward passed, so it never affected this package's own verification.

## Anything left undone

- The height-vs-docs/19's-30%-guideline tension above is not resolved (see "Residual tension") — it is a decision for the author/orchestrator, not something this restyle-only task can close without either a content change (shortening `effect_description`, which the Register/docs-19 own, not this file) or a new interactive affordance (scrolling, which is a behaviour change).
- `ROW_TEXT_MIN_WIDTH_PX`/`PANEL_MIN_WIDTH_PX`/`PRICE_TAG_MIN_WIDTH_PX`/`OPEN_ANIM_START_SCALE` stay local consts with `TODO(ui-pass)` comments, not promoted to `UiPalette` (outside my write scope).
- Did not visually verify the fix in the live editor/`run_project` (both `run_project` and every `game_*` MCP tool are explicitly banned for this task, and the editor launch is banned too) — verification here is the new `tests/unit/ui_console_layout_test.gd`'s direct pixel measurements plus the existing suites, not a screenshot; Package E owns the capture tool and before/after screenshots.

## Follow-up: compaction (orchestrator decision, after seeing the first restyle in the assembled scene)

The follow-up request reported the panel at ~650x750 px, its top clipped off-screen and sitting under the HUD's HP pill, every row 3-4 lines because the row label carried the FULL `effect_description` sentence plus rank plus price. The orchestrator explicitly lifted "entry text formats stay exactly as they are" for the row label's composition only, as its own recorded interpretation (not mine to have made unilaterally) — `get_entry_for_test(i)`'s own dictionary, including its `"name"` field (still the complete `effect_description`), is unchanged; only how `_refresh_one_row()` builds the *visible* `Text` string from it changed.

### What changed, this follow-up

1. **Row label shortened** to `"<short name> <rank status>"` (Repair: `"Repair +<heal> HP"`), price dropped from the label (it lives only in `PriceTag` now). `<short name>` is derived by splitting `effect_description` on its first `:` — the *exact* interpretation `src/ui/draft_card_view.gd`'s own `setup()` already documents and uses (that file's header, "Name/icon derivation"); read from there and matched, not re-invented, via a new static `Console._split_name_and_effect()`.
2. **New `Footer` label** (`UiTheme.SMALL`, bottom of the panel) shows the *highlighted* entry's effect sentence — the text after that same first `:`. `custom_minimum_size.y` reserves `FOOTER_MIN_LINES` (2) lines so the panel does not resize as the highlight moves between a short and a long description. New test seam: `get_footer_label_for_test()`.
3. **Row chrome tightened**: `Frame` (the pool differentiation element) shrank from a 24x24 swatch to a `UiPalette.SPACE_XS` (4 px) colour strip at the row's left edge — a *redundant* cue now, mirroring `DraftCardView`'s own `_accent_strip`. The *primary* shape signal (rounded = Player, squared = Tower) moved to the row's own corner radius. This needed an **owned, per-row `StyleBoxFlat`** (`_row_styles[i]`, built via `UiTheme.make_box()`) rather than `theme_type_variation = UiTheme.ROW`/`ROW_HIGHLIGHTED`, because a type variation resolves to the Theme's *one* shared, cached StyleBox — mutating it per row for a pool-dependent radius would have restyled every row (and every other ROW-styled control project-wide) at once. This is `DraftCardView`'s own established pattern for the identical reason (that file's header: "never `theme_type_variation = UiTheme.CARD` ... mutating it here would restyle every other CARD-styled control project-wide"), applied here rather than invented fresh — recorded as an interpretation. The number-key chip became a small `RADIUS_SMALL`, `SIZE_SHRINK_CENTER`-on-both-axes square (`NUMBER_CHIP_SIZE_PX` = 22) instead of a `UiTheme.PILL` capsule that used to stretch to the row's full (3-4 line) height. `MaxBadge` also got `SIZE_SHRINK_CENTER` for the same reason.
4. **`_panel`'s own padding** also moved from the shared `UiTheme.PANEL` type variation to an owned `StyleBoxFlat` (same reasoning as #3 — the pause/settings menus use the same shared PANEL box; tightening it for the Console alone would have tightened theirs too), padding `SPACE_L` → `SPACE_S`. The header row's `Title`/`ScrapValue` labels dropped from `FONT_SIZE_BODY` to `FONT_SIZE_SMALL` (the 24 px floor only ever governs `ENTRY_FONT_SIZE_PX`, the entry rows' own `Text`, never the header). `ROW_TEXT_MIN_WIDTH_PX` 360→300, `PANEL_MIN_WIDTH_PX` 480→420, `PRICE_TAG_MIN_WIDTH_PX` 64→40 (still fits "999").

### Measured panel sizes (real 7-entry catalogue, base resolution, `view_scale = 1.0`)

| State | Panel size (px) | Target |
| --- | --- | --- |
| Normal (before this follow-up) | 672 x 773 | — |
| Normal (after this follow-up) | **512 x 377** | 460-520 wide, ≤360 tall |
| Pseudo-localized (+30%) | 607 x 575 | (no explicit target; must not collapse/explode) |

Confirmed both by `tests/unit/ui_console_layout_test.gd`'s direct pixel measurement and by running the capture tool (`ui_capture.tscn`) at 1920x1080 and reading `05_console.png` with and without `--pseudo` — every row is one line in English, wraps to at most two under pseudo-localization, the pool strip/number chip/caret/struck price/MAX badge are all present and legible, and the panel now sits entirely clear of the HUD's HP pill (the original clipping complaint).

**Width** (512) lands inside the 460-520 target. **Height** (377) is ~17 px over the ~360 target — did not force it further, per the instruction's own "if you cannot get under ~360 px, report the measured height and what holds it up; do not add scrolling." What holds the remaining 17 px up, in order of contribution: (a) 7 rows at one line each, and `ENTRY_FONT_SIZE_PX` (24, the Register's floor — not mine to shrink) alone requires ~31 px of line height per row before any padding, ~217 px across 7 rows; (b) the footer's *explicitly requested* 2-line reservation (~42 px at `FONT_SIZE_SMALL`); (c) row/panel padding, already reduced to the smallest tokens the instruction itself named (`SPACE_XS`/`SPACE_S`) — going below them would mean inventing a literal outside that vocabulary, which I did not do. I did not add scrolling.

`tests/unit/ui_console_layout_test.gd` gained: a `PANEL_HEIGHT_COMPACT_TARGET_PX` (420, a measurement-noise margin over the true 377/512 measured) and `PANEL_WIDTH_COMPACT_MAX_PX` (560) assertion pair (the "bound you state" item 5 asks for) alongside the original collapse-guard ceiling (900, kept — a different, looser claim: "did not collapse," not "hit the compact target"); a hard "every row label is exactly one line in English at base resolution" assertion per entry; and a new footer assertion (empty while Repair — no `:` to split — is highlighted; contains the correct post-`:` substring, and never the pre-`:` name, once a ranked upgrade is highlighted).

### Suites re-run after the follow-up (headless, one at a time)

| Suite | Result |
| --- | --- |
| `tests/unit/console_rules_test.gd` | 16 test cases, 0 errors, 0 failures |
| `tests/unit/console_non_pause_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/console_ui_scaling_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/console_interaction_window_test.gd` | 1 test case, 0 errors, 0 failures |
| `tests/unit/movement_only_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/scrap_loss_test.gd` | 3 test cases, 0 errors, 0 failures |
| `tests/unit/ui_console_layout_test.gd` (updated this follow-up) | 2 test cases, 0 errors, 0 failures |

Total: 27/27 test cases pass, same suites as the original report, all green after the follow-up.

### Anything left undone, this follow-up

- Height is 377 px against a ~360 px target (see above) — not further reduced, since doing so would have required either shrinking `Text` below `ENTRY_FONT_SIZE_PX` (the Register's floor, not restyle-scope to touch) or the footer below its explicitly-requested 2 lines, or a spacing literal outside `SPACE_XS`/`SPACE_S` (the instruction's own named vocabulary for this tightening).
- Did not touch `scenes/prototype.tscn`'s own `tower_path`/`player_path`/etc. wiring gap (named as the coordinator's own HANDOFF item, explicitly "not yours to fix" for this package).
- `NUMBER_CHIP_SIZE_PX`/`FOOTER_MIN_LINES` join the existing `TODO(ui-pass)` const list, same reasoning as before (no matching `UiPalette` token yet).

# UI Pass - REVIEW

Iteration 1. Blind review by the `critical-reviewer` agent on Opus, 2026-09-20, against commit `2f1c8ad`. The reviewer was given only the author's original request, the orchestrator's claims at the pause point, and artifact paths - none of the working context. Its report is reproduced verbatim below; nothing in it has been edited. Each finding's handling is tracked in `LEDGER.md` under the ID given there.

The "5 / 8 / S" digit legibility note and the threat-feedback rendering finding in `LEDGER.md` (UR-15, UR-16) are the orchestrator's own, made from the frames after this review, and are not the reviewer's.

---

# Critical Review — "lets do a full ui pass .. so the game looks good even as a prototype"

**Verdict:** ACCEPT WITH FIXES
**Overall:** 5/10   (cap applied: scope silently narrowed — one named surface has no screenshot at any resolution and no `before_1280` set exists; neither is disclosed)
**Reviewed:** external artifact set — worktree `D:\Gamedev-ui-pass`, branch `ui-pass` (`1321f52`, `d6bbae6`, `2f1c8ad` on `3ef4bc7`), the `phases/UI_PASS/` record, 24 screenshots, two gdUnit4 XML reports   ·   **Mode:** blind, full

---

## Contract

> TASK: Prototype UI pass — restyle every player-facing UI surface so the build reads as a deliberate, cohesive game in front of first-time testers. LOOK AND FEEL ONLY: no behaviour, rule, number, or input change.
> SURFACES: HUD (4 fields), threat feedback, Level-Up Draft (cards + fill ring), Tower Console, pause menu, settings menu, run-end screens.
> DELIVERABLES: 1. One shared Theme (`ui_theme.tres` + `ui_palette.gd`), replace the ~31 scattered `add_theme_*_override` / `StyleBoxFlat` calls with theme type variations, one CC0/OFL font + licence. 2. Restyled surfaces with short tweened transitions under `PROCESS_MODE_ALWAYS` that never delay input. 3. Before/after screenshots of every surface at 1920x1080 and 1280x720, plus one with F2 pseudo-localization on. 4. Record in `phases/UI_PASS/` (PLAN, EXECUTION_LOG, FAILURE_POINTS, LEDGER).
> HARD CONSTRAINTS: docs/19 + Register "Interfaces" rows authoritative; every existing test still passes; colour-only distinctions rule; cosmetic values in `ui_palette.gd` only; Register values cited not restated, and if one seems to need changing, STOP and ask the author; never write that a gate/test is passed or ready.
> ISOLATION: worktree + branch; write allow-list `src/ui/**`, `scenes/ui/**`, `assets/ui/**`, new `tests/unit/ui_*_test.gd`, `phases/UI_PASS/**`; anything else goes to HANDOFF.md as exact proposed text; public APIs of `src/ui` scripts stay stable.

**Done means:** every one of the seven named surfaces is visibly restyled onto one palette/theme/font, demonstrated at both resolutions and pseudo-localized; nothing outside `src/ui`-and-friends changed; no existing test edited and none newly failing; every departure named for the author.

**Explicit criteria:** shared theme + palette + licensed font · overrides replaced by type variations · seven surfaces restyled · tweened motion under `PROCESS_MODE_ALWAYS`, never gating input · before/after screenshots, every surface, 1920 + 1280 + pseudo · PLAN/EXECUTION_LOG/FAILURE_POINTS/LEDGER · allow-list respected · existing tests unmodified and still passing · colour-only rule · no Register value changed without an author question · no "passed/ready" language.

**Implicit criteria:** the result actually reads well to a first-time tester (that is the whole point of the request) · the text on screen is legible and correct · the branch merges · the record's own claims match the files.

---

## Timeline

| Step | Who | What happened | Observation |
|---|---|---|---|
| 1–3 | orchestrator | Read reference, cut worktree at `3ef4bc7`, ran the full suite untouched → `evidence/baseline_results.xml`, 588 tests / 2 failing | Correct discipline: baseline before change. Verified. |
| 4 | orchestrator | Built `ui_palette.gd`, `ui_theme.gd` (not `.tres` — deviation stated in PLAN.md:33), font + OFL | Foundation first, deviation disclosed. Committed `1321f52`. |
| 5 | orchestrator | Four Sonnet implementers in parallel on disjoint files, all bound by `BRIEF.md` | Good decomposition; BRIEF carries every isolation constraint, per F-06. |
| 6 | capture tool | "Before" set from a throwaway checkout; found UP-01 (Console can never open in the assembled scene), UP-02 (33 raw `tr()` keys on screen), UP-03 (Console collapsed to a 450 px sliver) | Highest-value step in the whole pass. Three real defects a unit suite could not see. |
| 9–11 | orchestrator | Package A returned 73/73 green with a visibly broken HUD (UP-07); D returned duplicated captions; the menu highlight cue turned out to carry no information (UP-06), fixed by the orchestrator in `choice_highlight_row.gd` | Three of four packages needed a screenshot-driven second pass. The orchestrator caught all three. |
| 10 | package C | Returned a 672x773 panel clipping off-screen; sent back with a compaction brief; returned 512x377 | Verified by me: 512x377 exactly. |
| 12 | orchestrator | Full suite → 591/2; banned-API check; Console suites + highlight test re-run | The full-suite run started 08:22:37 UTC and `console.gd` was last written 08:26:14 UTC — the run was in flight while the file changed. Disclosed in part (the re-run), not in the headline. |
| 13–15 | orchestrator | Final captures, allow-list check, committed `d6bbae6`; merge check against `c076fc2`; blind review launched then stopped by the author | Pause point is honest; `RESUME.md` lists six open items. |

---

## Agent scorecard

| Agent | Role | Score | Worst load-bearing gap |
|---|---|---|---|
| orchestrator | orchestrator | **5**/10 | Looked at all 18 "after" screenshots and did not read the text in them (a card says "+20% player **Are** rate per rank"); never captured the threat-feedback surface at all and did not say so; headlined a full-suite result taken over a tree that changed mid-run |
| package A — HUD + threat feedback | worker | **6**/10 | Shipped a visibly broken HUD with 73/73 green and only fixed it when handed a screenshot; rewrote `threat_feedback.gd`'s `_draw()` and never looked at one frame of it (says so plainly) |
| package B — Draft | worker | **8**/10 | Never saw its own cards rendered (the brief forbade it), so the font-ligature corruption on its card text went unseen; otherwise the most rigorous package in the pass |
| package C — Tower Console | worker | **6**/10 | Its own regression test's ceiling (900 px) could not catch its own 773 px defect; moved the Register-listed price out of the 24 px floor label without raising it as a Register question; wrote "all green", which its brief forbids |
| package D — menus + run end | worker | **6**/10 | Shipped a highlight cue that carried no information (one `visible`-toggled marker per option in an HBox); its report still describes that design as what shipped |
| capture tool (package E) | worker | **7**/10 | Captures six states, not the seven surfaces; cannot produce an exact 1920x1080 frame; depends on five private members of three classes with no test guarding it |

**Outcome vs contract:** shared theme + palette + licensed font — **met** (as `.gd`, deviation disclosed) · overrides replaced by type variations — **not met** (25 → 42 calls) · seven surfaces restyled — **met** · motion under `PROCESS_MODE_ALWAYS`, never gating input — **met** · screenshots of every surface at both resolutions + pseudo — **partially met** (threat feedback absent everywhere; no `before_1280`; the "1920" frames are 1875x1055) · PLAN/EXECUTION_LOG/FAILURE_POINTS — **met**, LEDGER — **not met** (disclosed) · allow-list — **met** (verified file by file) · existing tests unmodified and still passing — **met** (verified) · colour-only rule — **met**, with one weakened cue · no Register value changed without an author question — **partially met** (the Console price question was never asked) · no "passed/ready" language — **not met** in two places.

---

## Errors

### Blockers
None found — checked: `git merge-tree` against `c076fc2` produces a tree with zero conflicts and zero file overlap; `git diff 3ef4bc7..ui-pass --name-status` shows every changed path inside the allow-list and every `tests/` entry as `A` (added), so no existing test was edited and `tests/unit/ui_console_layout_test.gd` did not exist at `3ef4bc7`; the two XMLs' failing-test *names* are byte-identical (`test_trivial_fail > test_false_condition_fails`, `teaching_siege_tuning_test > test_z_aggregate_both_halves_of_the_t4_tuning_target`) with 588 → 591 tests from exactly two new suites and no existing suite's count changed; no `get_tree().create_tween()` / `create_timer()` call exists in `src/ui` (all five grep hits are comments); every `tr()` key used anywhere in `src/` is registered in `ui_strings.gd`; every canvas-layer constant is unchanged; no public method or `_for_test` seam was removed.

### Major

- **[package B + orchestrator · `assets/ui/fonts/PixelifySans-Variable.ttf.import` `[params] opentype_features={}` → `screenshots/after_1920/02_draft.png`, third card]** OpenType ligatures are on and Pixelify Sans's `fi` ligature renders as a glyph that reads as a capital **A**. The Rapid Fire card reads **"+20% player Are rate per rank"** where the data says "fire rate" (`data/upgrades/rapid_fire.tres:14`). Evidence: I cropped and upscaled the region — the word is three glyphs where "fire" needs four, and the same string in `before_1920/02_draft.png` reads "fire" correctly. It is corrupted identically in `after_1280/02_draft.png`. `"flat price"` in both fallback upgrade descriptions will corrupt the same way. — **right looks like:** disable `liga` — either `opentype_features={"liga":0}` in the `.import`, or `variation.opentype_features` in `UiTheme._make_font()` (`src/ui/theme/ui_theme.gd:82-86`) — then re-capture the Draft. **IN-SCOPE.**

- **[orchestrator · `phases/UI_PASS/screenshots/**`]** Threat feedback — one of the seven surfaces named in the request and in `PLAN.md:9` — has **no screenshot in any set**. All four directories hold the same six states (hud_gameplay, draft, pause, settings, console, run_end); I listed and opened them. `threat_feedback.gd`'s `_draw()` was substantially rewritten (arc subdivision of all 8 vignette wedges, a new dark outline pass under every bright stroke, both indicator colours changed), and package A states plainly it "only inspected `01_hud_gameplay.png`". So the one surface whose entire output is custom drawing is the one surface nobody looked at — in a pass whose own FAILURE_POINTS UP-07 records that three of four packages shipped screenshot-only defects. The final claims say "six states each" and "All seven UI surfaces are restyled", never that a surface went unphotographed. — **right looks like:** add a threat-feedback state to `ui_capture.gd` (damage the Tower, drop player health below the 40% `LOW_HEALTH_FRACTION`), capture it in all three sets, and look at it. **IN-SCOPE.**

- **[orchestrator · `src/ui/theme/ui_strings.gd:42-43`]** `"CONSOLE_GLYPH_PLAYER": "●"` and `"CONSOLE_GLYPH_TOWER": "■"` are characters the shipped font does not contain. Package D measured exactly this with `Font.has_char()` against the actual `.ttf` and reported it (`package_reports/D_menus.md:13`: `✓ ✕ ✗ ★ ☆ ☠ ✦ ● ■ ✔ ✘` "all `false`"), which is why D drew its outcome glyph instead. The orchestrator then wrote ● and ■ into the shared string table anyway; they render only because `allow_system_fallback=true` in the font `.import`. Package B's new `HOLD_RING_GLYPH = "▲"` (`src/ui/draft_controller.gd`) and the pre-existing draft card glyphs are in the same position. Package C reasoned the other way for the same decision (`C_console.md:43`: chose ASCII `">"` "since Pixelify Sans's own coverage is cited as the accented Latin range"). Net effect: the request's direction item 4, "one outlined display font, consistent everywhere", is broken at the Console rows, the Draft glyphs and the Draft ring, and those glyphs are a system-font dependency at export. — **right looks like:** one decision applied everywhere — either draw these four glyphs (D's pattern in `outcome_glyph.gd`) or restrict every glyph to characters `Font.has_char()` confirms. **IN-SCOPE.**

- **[orchestrator · `phases/UI_PASS/` directory listing]** `LEDGER.md` is a named deliverable of the request and of `PLAN.md:60`; it does not exist. Disclosed in `RESUME.md:14` as contingent on the review that was stopped, which is why this is a Major and not a Blocker. — **right looks like:** write it from this review's findings. **IN-SCOPE.**

- **[orchestrator · final claims, bullet 1]** "the full suite ran 591 tests with 2 failing" is presented under **Done and checked** as the verification of the finished code, and it was not, at the moment it was made. Per-suite timestamps in `evidence/after_results_run1.xml`: the run spans 08:22:37 → 08:30:53 UTC and the four Console suites executed at 08:22:38–08:22:41. `src/ui/console.gd`'s last write is 08:26:14 UTC. The Console suites in that XML therefore ran against pre-final code. The orchestrator did disclose a follow-up re-run in the same bullet ("22 cases, 0 failures"), and I independently re-ran 18 of those 22 on the final tree (`console_rules_test` 16/16, `ui_console_layout_test` 2/2, both 0 errors 0 failures), so the underlying fact holds — but the headline claim was unsupported when written. — **right looks like:** re-run the suite after the last edit, or state in the same sentence which suites the number does not cover. **IN-SCOPE.**

### Minor

- **[package C + orchestrator · `src/ui/console.gd:1273-1281`, `_make_pill_label()`] — AUTHOR.** The compaction follow-up moved the price out of the `ENTRY_FONT_SIZE_PX` (24 px) `Text` label into a `PriceTag` `RichTextLabel` that takes the theme default (`UiPalette.FONT_SIZE_BODY` = 20), and the `MAX` badge label is `UiTheme.SMALL` (16). The Register (`MASTER_SDLC.md:3352`) says entries "show price … 'MAX' with no price if maxed" *and* "scale set each frame to the view scale so text stays ≥ 24 px tall on screen"; docs/19:35 narrows it to "entry text". `C_console.md:95` names the header-title relaxation but not the price. The brief's own rule is "If a Register value seems to need changing, STOP and ask the author." Confirmed visually in `after_1920/05_console.png`: "30" is clearly smaller than "Rapid Fire Rank 1 of 3". **Question for the author:** does the Console's 24 px text floor govern (a) every label inside the panel, (b) only the entry row label, or (c) the entry row label plus the price/MAX, which the Register names as entry content?

- **[all four packages · `src/ui/*.gd`]** Deliverable 1's stated mechanism is not met. `add_theme_*_override(` calls went from **25** at `3ef4bc7` to **42** now (plus 4 → 3 `StyleBoxFlat.new()`), i.e. the "~31 scattered calls" roughly doubled instead of being replaced by type variations. The *spirit* is met — I checked all 42 and every one reads a `UiPalette` token or the Register-cited font size, and there is exactly one raw colour literal left in `src/ui` outside the theme folder (`hud_bar.gd:278`, `Color(0,0,0,0)`, transparent). But 33 of the 42 are `add_theme_constant_override("separation", …)`, which is precisely what a container type variation carries. — **right looks like:** add `UiRowTight`/`UiRowWide`/`UiColumn` separation variations to `ui_theme.gd` and set `theme_type_variation` instead. **IN-SCOPE.**

- **[orchestrator · `screenshots/before_1920/`]** No `before_1280` set exists, so deliverable 3's "before/after … at 1920x1080 and 1280x720" has no 1280 baseline to compare against. Undisclosed. Separately, every "1920" frame is 1875x1055 (I read all 24 with PIL); that one *is* disclosed (UP-05, RESUME item 3) but the claim text still says "1920x1080". — **right looks like:** run the capture tool once against `1321f52` at 1280x720, and set the window borderless/fullscreen, or render to a 1920x1080 `SubViewport`, for an exact frame. **IN-SCOPE.**

- **[orchestrator · `src/ui/theme/ui_theme.gd:42`] — verdict on the listed loose end: the coupling is real.** `UiStrings.ensure_registered()` inside `get_theme()` works today, but `src/run/run_flow_controller.gd:487-489` calls `tr("RUN_END_CAUSE_PLAYER")` / `tr("RUN_END_CAUSE_TOWER")` and never touches `UiTheme` — it resolves only because a menu built earlier in the run happened to fetch the theme. A getter with a registration side effect is not where the next reader will look. HANDOFF H-02 is the right durable fix; until it lands, call `UiStrings.ensure_registered()` at the top of each `_ready()` that calls `tr()`. **IN-SCOPE** for `src/ui`; the `run_flow_controller.gd` call site is **HANDOFF**.

- **[orchestrator · `phases/UI_PASS/package_reports/*.md`]** Three of the four reports now describe code that does not exist, with no reconciliation note. `D_menus.md:12` describes `ChoiceHighlightRow` as "One marker (`ColorRect`, 180x4) per option … shown only under the highlighted index" — the shipped file is a `_draw()`-based underline computed from the option's real rect, rewritten by the orchestrator under UP-06. `A_hud.md:4,46-48` documents `src/ui/hud_strings.gd` and `B_draft.md:11` documents `src/ui/draft_strings.gd`; both files were folded into `ui_strings.gd` and deleted (EXECUTION_LOG #9). `BRIEF.md:9` says reports go to `package_reports/`, while all four reports say they were told `reports/` and complain it is gitignored — the brief was edited after the fact without a note. — **right looks like:** one "superseded by" line at the top of each affected report, per CLAUDE.md's "sweep changed files for superseded wording". **IN-SCOPE.**

- **[package C · `package_reports/C_console.md:74,123`]** "Total: 27/27 test cases pass … **all green** after the follow-up." `BRIEF.md:45` says "Never write that a test, check, or gate is passed, satisfied, or ready — give the counts". The orchestrator's own final claims do the same ("the Console suites and the new highlight test **pass** on the final code"). — **right looks like:** counts only, in both places. **IN-SCOPE.**

- **[orchestrator · `HANDOFF.md:54`]** H-03 cites `screenshots/before_1920/01_hud_gameplay.png` as showing the F1 debug overlay covering the HUD's player-health field. I opened that file: the overlay is not in it — `ui_capture.gd:43-45` hides it, and the committed set is from a later run. The finding is probably real, but its only cited evidence does not support it. — **right looks like:** cite `src/debug/overlay.gd`'s default visibility directly, or attach the earlier frame. **IN-SCOPE.**

- **[orchestrator · `evidence/after_results_run1.xml` vs `main` at `c076fc2`]** The 591/2 evidence is against `3ef4bc7`. `main` has since changed `tests/unit/teaching_siege_tuning_test.gd`, `tests/unit/tower_damage_path_test.gd` and added `tests/unit/prototype_integration_test.gd`, which instantiates `scenes/prototype.tscn` and reads `hud.economy_state`. There is **zero file overlap** between the two branches (I diffed both name lists) and `git merge-tree` reports no conflict, so merge risk is low — but no run covers the merged tree. — **right looks like:** re-run the full suite once after merging and quote the summary line. **HANDOFF** (the merge is the author's).

- **[capture tool · `src/ui/dev/ui_capture.gd:102-124, 67, 82`]** The tool depends on `console._tower`, `console._run_inventory`, `flow._end_run`, `flow._on_pause_action_pressed` and `PauseAuthority.get("_reasons")` — five private members across three classes, with no test. It will rot silently. **Verdict on the listed loose end: no shipped code path depends on it** — I grepped `src/`, `scenes/`, `tests/` and `project.godot` for `ui_capture` and found nothing outside `src/ui/dev/` itself; the dependency is strictly one-way and `ui_capture.gd` declares no `class_name`. But it does ship inside `src/ui/` with no export exclude filter in `project.godot`. — **right looks like:** a `res://src/ui/dev/.gdignore` or an export exclude filter (**HANDOFF**, `project.godot`), and a one-case test asserting those five members still resolve (**IN-SCOPE**).

- **[package C · `src/ui/console.gd:1143-1146`]** `FOOTER_MIN_LINES = 2` is reserved unconditionally, so when Repair (which has no `:` to split on) is highlighted — the default state on open — the panel shows ~50 px of empty space at the bottom. Visible in `after_1920/05_console.png`. — **right looks like:** reserve the two lines only while a ranked entry is highlighted, or put a one-line hint in the footer for Repair. **IN-SCOPE.**

- **[orchestrator · `phases/UI_PASS/screenshots/**/*.png.import`]** 24 screenshot PNGs are committed inside `res://` and each carries a generated `.import`, so Godot imports every reference screenshot as a game texture. — **right looks like:** a `.gdignore` in `phases/UI_PASS/screenshots/`. **IN-SCOPE.**

### Nits
- `ui_theme.gd:106,194-198` — `line_spacing 2` and `content_margin 5` are bare literals in the one file that exists to end bare literals.
- `choice_highlight_row.gd:85-86` — `left` is mapped through the transforms but `option.size.x` is the unscaled local width, so the underline is wider than the option while the card's open tween is still at 0.92 scale.
- `after_1920/06_run_end.png` — "Time survived: 0:03" wraps to two lines beside a one-line "Scrap held: 180"; the two stat cells' text baselines do not align.
- The hold-confirm ring renders as an unlabelled empty circle in all three menus (`menu_frame.style_fill_ring` never sets `center_glyph`, while the Draft's ring gets "▲"). In `03_pause_menu.png` / `04_settings_menu.png` / `06_run_end.png` it reads as a stray dot on the card.
- The Draft highlight border gap narrowed from 3/7 px to 2/3 px (`draft_card_view.gd:8-9`). Package B named this itself and added the 1.05 lift to compensate; in a static frame the size difference does carry it, but it is materially weaker than before. `after_1920/02_draft.png` shows it.

---

## Feedback → Orchestrator

- You built the capture tool and it found H-01 — a bug that made the Tower Console unopenable in the real game, which `main` then independently fixed with *exactly* your proposed four `../Main/...` paths (I diffed `66e623e`). That instinct — "a unit suite cannot see the screen" — is the single most valuable thing in this pass. Keep it.
- You then looked at 18 "after" screenshots and reported on them, and a Draft card in two of those sets says "+20% player **Are** rate per rank" → the deliverable was "reads as a deliberate game to a first-time tester", and a garbled word on a decision card is precisely the failure the deliverable names → when a screenshot is your evidence, read every string in it out loud against the source data, don't just check that the layout resolved.
- The request names seven surfaces; your capture tool captures six, and threat feedback has no frame in any set → `threat_feedback.gd`'s entire `_draw()` was rewritten and no human or agent has seen one pixel of it → before declaring a capture set done, diff the state list in the tool against the surface list in the request and name any surface you could not stage.
- You told the implementers "Never write that a test, check, or gate is passed" and then wrote "the Console suites and the new highlight test **pass** on the final code" in your own claims → a rule you enforce downward and break upward stops being a rule → hold your own report to the brief you wrote.
- You started the full suite at 08:22:37 UTC and package C wrote `console.gd` at 08:26:14 → "the full suite ran 591 tests with 2 failing" was not a statement about the code you shipped when you made it → do not start a 10-minute suite while a worker is still editing; start it after the last return, and quote the summary line with the commit it covers.
- Package D handed you a measurement — `Font.has_char()` says ● and ■ are not in the shipped font — and you then wrote both characters into `ui_strings.gd` → the "one font everywhere" direction is now broken by system fallback at every Console row → when a worker returns a measurement about a shared resource, apply it to the shared resource before the next edit to it.
- `RESUME.md` is unusually good: six numbered open items, five loose ends handed to the review by name, and the merge left to the author. That is the right shape for a pause point.

## Feedback → package A (HUD and threat feedback)

- You returned 73/73 green with bars 160 px tall, every glyph wrapping one character per line, and the Scrap value truncated to "0/20" → green tests over a broken screen is the most expensive kind of return, because it consumes the orchestrator's trust budget → when your surface is layout, assert a rendered dimension (a `Label`'s `get_line_count()`, a `Control`'s `size`) in at least one test, not only a parent rect.
- Your root-cause write-up for UP-07 (autowrap reports a near-zero natural minimum; a single word with no space then wraps between characters; a `SIZE_FILL` sibling stretches to match) is exact and reusable, and your `set_corner_radius_individual()` finding saved the other packages a runtime-only failure. Both are worth repeating.
- You rewrote `threat_feedback.gd`'s `_draw()` — eight arc-subdivided wedges, a new outline pass under every stroke, both indicator colours changed — and inspected only `01_hud_gameplay.png` → nobody has ever seen that surface render → when you rewrite a `_draw()`, you own a frame of it; ask for the capture tool if you do not have it.

## Feedback → package B (Level-Up Draft)

- You verified `offset_transform_*` exists and is visual-only against a live 4.7.1 build with `ClassDB.class_get_property_list("Control")` and a runtime probe, instead of trusting the property name → that is exactly how to use an engine feature past your own knowledge → keep probing before writing.
- You named the border-width narrowing (3/7 → 2/3) yourself and said what compensates for it, and you refused to assert any suite "passed". Both are the standard the other packages should meet.
- You could not see your own cards render, said so, and the one defect that shipped on your surface — the `fi` ligature — is exactly the class a rendered frame catches → when a font is new in the same pass as your text, ask for one frame of your own surface before returning.

## Feedback → package C (Tower Console)

- Your `ui_console_layout_test.gd` is the best artifact in this pass: real `UpgradeSystem`, real 7-entry catalogue, real engine frames, a per-row one-line assertion, and a second test that caught the `RichTextLabel` BBCode/pseudo-localization corruption you found yourself. I re-ran it: 2/2, and it prints `(512.0, 377.0)`, matching the orchestrator's claim exactly.
- That same test's original ceiling was 900 px, so it could not fail on the 672x773 panel that was clipping off-screen and sitting under the HUD → a bound chosen loose enough to pass is not a bound → set the ceiling at the requirement (docs/19's 30%-of-height) and let it fail loudly, with the reason in `append_failure_message`.
- You moved the price out of the 24 px `Text` label into a 20 px `PriceTag` and flagged only the *header*'s font-size relaxation → the Register names the price as entry content, so that is the one that needed the author → when you relax anything the Register touches, ask the multiple-choice question, even if a different relaxation nearby seemed obviously safe.
- "27/27 test cases pass … all green" is the phrasing your brief forbids in the same sentence that gives the counts → give the counts and stop.

## Feedback → package D (menus and run end)

- You checked `Font.has_char()` against the shipped `.ttf` before choosing a drawn glyph over a Unicode character, and your HANDOFF for `paused_choice_bar.gd` carries exact, pasteable text. Both are model behaviour.
- Your highlight cue was one `visible`-toggled marker per option in an `HBoxContainer`; a hidden child takes no space, so the one visible marker stretched across the row and never moved → a "shape cue" that is identical in every state is not a cue, and no test could see it → when you add a cue, assert its geometry in two different states.
- Your report still describes that marker design as what shipped, and cites `MARKER_MIN_WIDTH`, which no longer exists → a reader reconstructing the pass from the reports gets the wrong file → when the orchestrator rewrites your file, add one "superseded by" line rather than leaving the report to age.

## Feedback → capture tool (package E)

- Driving the real `scenes/prototype.tscn` rather than mock-ups is what found H-01, UP-02, UP-03, UP-04 and UP-07, and printing a loud WARNING line when it has to inject the Console's references — so no one reads a Console screenshot as proof the Console opens — is exactly right.
- It captures six states against a request that names seven surfaces, and it cannot produce an exact 1920x1080 frame → the evidence set has a hole in it and every downstream verification inherits that hole → drive the state list from the surface list, and render to a fixed-size `SubViewport` so the desktop's work area cannot clamp the frame.
- It reaches into five private members across three classes with nothing guarding them → the first rename breaks it silently, months from now → add one test that asserts those five members still resolve on the assembled scene.

---

## Required before acceptance

1. Disable the `fi`/`ff` ligatures (`opentype_features` in the font `.import` or on the `FontVariation` in `UiTheme._make_font()`), re-capture the Draft at both resolutions, and confirm the card reads "fire rate".
2. Add a threat-feedback state to `ui_capture.gd`, capture it in all three "after" sets, and inspect it — it is the only surface whose custom drawing was rewritten and never seen.
3. Resolve the glyph decision once, everywhere: either draw ● ■ ▲ (package D's `outcome_glyph.gd` pattern) or restrict every glyph to characters `Font.has_char()` confirms in the shipped font.
4. Write `phases/UI_PASS/LEDGER.md`.
5. Ask the author the Console 24 px question (see the AUTHOR item above) before merging, and record the answer as a Review Decision Log row naming the alternative.
6. Re-run the full suite after the final edit and quote the summary line with the commit it covers; re-run it again after the merge into `c076fc2`, which carries a new assembled-scene integration suite this branch has never seen.
7. Correct the two "passed / all green" statements (`C_console.md:74,123` and the orchestrator's claim bullet) to bare counts.
8. Add a "superseded by" line to `A_hud.md`, `B_draft.md` and `D_menus.md` for the files the orchestrator later folded in or rewrote, and reconcile `BRIEF.md:9` with the `reports/` → `package_reports/` rename.

## Not verified by reviewer

- **The full 10-minute suite** — I judged the 591/2 claim from the two XML files as instructed, and re-ran three suites individually on the final tree instead: `ui_console_layout_test` (2/2, prints `(512.0, 377.0)`), `console_rules_test` (16/16), `draft_input_lockout_test` (11/11) — all 0 errors, 0 failures, 0 orphans. That covers 18 of the orchestrator's claimed 22 Console-plus-highlight cases.
- **The banned-API check as the orchestrator ran it** — I re-derived it with grep over `src/ui` and `src/`: zero real `get_tree().create_tween()` / `create_timer()` calls, five comment-only mentions. Claim stands.
- **The reference image** `G:\screenshots\Screenshot 2026-09-20 125749.png` — no access, so I cannot judge "inspiration, never a copy". The palette, ring, font and layout in the result look internally derived, but that is an impression, not a check.
- **Motion in flight** — no windowed run, no `run_project`, no `game_*` tool, per my constraints. Tween correctness is judged from code (bare `create_tween()` on the node, `is_inside_tree()` guard on every one, `TWEEN_PAUSE_PROCESS` set explicitly, `kill()` before restart, state written synchronously before the tween starts) and from static frames only. I did not observe that motion never delays input.
- **`offset_transform_scale` / `offset_transform_position` semantics** — package B's `ClassDB` probe is its evidence; I could not extract the property table from the Godot binary. `draft_input_lockout_test` runs clean with zero errors and zero orphans while cycling the highlight, which is consistent, not conclusive.
- **Export behaviour of `src/ui/dev/`** — export is denied to me.
- **Post-merge state** — `git merge-tree` reports no conflict and the two branches share no changed file, but I did not materialise or test the merged tree.
- **Side effect to disclose:** my three suite runs wrote `D:\Gamedev-ui-pass\reports\report_77`–`report_79`. That path is gitignored (`.gitignore:51`) and `git status --porcelain` is empty; I made no other change, ran no git command that writes, and touched nothing in `D:\Gamedev`.

---

## Prompt-ready corrections

### → Orchestrator
```text
Drive your screenshot state list from the surface list in the request; name any surface you could not stage.
Read every string in a screenshot against its source data before reporting on that screenshot.
Never start a long test suite while a worker is still editing; run it after the last return and quote the summary line with the commit it covers.
Hold your own report to the brief you gave the workers: counts, never "passed", "green" or "ready".
When a worker returns a measurement about a shared file, apply it to that shared file before your next edit to it.
When you relax anything docs/19 or the Register touches, stop and ask the author a multiple-choice question before shipping it.
When you rewrite a worker's file, add a "superseded by" line to that worker's report in the same commit.
Write every named deliverable, or state in the claims which one is missing and why.
```

### → package A (HUD and threat feedback)
```text
Assert a rendered dimension, not only a parent rect: a Label's line count, a Control's size.
If you rewrite a _draw(), you own a rendered frame of it; ask for the capture tool rather than returning without one.
Never return "N/N green" as evidence for a layout change you have not seen render.
Keep writing root causes at the level of your UP-07 note, and keep flagging non-existent-API findings for the other packages.
```

### → package B (Level-Up Draft)
```text
Keep probing engine features against a live build before you use them; keep quoting the probe in your report.
When a font is new in the same pass as your text, ask for one rendered frame of your own surface before returning.
Keep naming every value change and its compensating cue, as you did for the border-width narrowing.
```

### → package C (Tower Console)
```text
Set a test's bound at the requirement, not loose enough to pass; put the requirement in append_failure_message.
When any Register-cited value or its scope changes, ask the author a multiple-choice question before implementing.
Give counts only. Never write "pass", "all green", "satisfied" or "ready".
Keep building regression tests against the real catalogue and real engine frames.
```

### → package D (menus and run end)
```text
Assert a new cue's geometry in two different states before returning; a cue identical in every state is not a cue.
Keep verifying glyph coverage with Font.has_char() against the shipped font before choosing a character.
Update your report when the orchestrator rewrites a file you wrote; one "superseded by" line is enough.
Keep writing HANDOFF requests as exact, pasteable text.
```

### → capture tool (package E)
```text
Derive the capture state list from the request's surface list; fail loudly on any surface you cannot stage.
Render to a fixed-size SubViewport so the desktop work area cannot clamp the frame.
Add one test asserting every private member you reach into still resolves on the assembled scene.
Keep printing a loud WARNING whenever you inject state, so no screenshot is mistaken for proof the real scene works.
```

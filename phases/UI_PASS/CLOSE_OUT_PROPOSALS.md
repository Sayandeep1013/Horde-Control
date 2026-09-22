# UI Pass - close-out proposals

Proposed text for files outside the UI pass's write allow-list. None of it has been written into those files. The author, or whoever owns the file, applies it after merging `ui-pass`. D numbers and the version number are placeholders: take the next free ones on `main` at the time (`main` at `c076fc2` ends at D104 and 0.8.10).

## 1. `phases/LESSONS.md` - three rows

Append to the table (columns: date, phase, lesson, applies to).

```
| 2026-09-20 | UI pass | A layout screenshot has to be read, not looked at. A decision card said "+20% player Are rate per rank" - an OpenType ligature in the new font - in two screenshot sets the orchestrator had opened, reported on, and used as evidence that the restyle was sound. Every check asked whether the layout resolved; none compared a string on screen with the string in the data. The same pass shipped a font whose 5 reads as S and whose 2 reads as 8, in a HUD that mostly shows numbers, because the font was judged on words. The blind reviewer found the first by cropping and enlarging the text; the second was found the same way afterwards | Every task whose evidence is a screenshot: read every string in the frame against its source, at native resolution, and judge a UI font on the digits and symbols the game actually shows |
| 2026-09-20 | UI pass | UI component suites stayed green while the launched scene was visibly broken, three times in one pass: a HUD with bars 160 px tall and labels wrapped one character per line under 73 of 73 tests, a Console rendered as a 450 px sliver, and a menu highlight that spanned the whole row and so marked nothing. Three of four implementers had been forbidden from running anything windowed and could not look at their own work. In round 2 every implementer had the capture tool from the first minute, and no package returned a defect a frame would have shown | Every phase that builds or restyles UI: give the implementer a way to render the real assembled scene before it reports, and add at least one test that asserts a rendered property (a label's line count, a panel's measured size) rather than a parent rect |
| 2026-09-20 | UI pass | Set a test's bound at the requirement, not at whatever currently passes. The Console layout test's first ceiling was 900 px and sat silent while the panel measured 773 px and ran off the top of the screen. Rewritten at the author's 35%-of-height allowance, it failed on the first full-suite run after a font change pushed the panel 18 px over - a regression nobody was looking for, caught within the hour it was introduced | Every test with a numeric bound: the bound is the requirement, with the requirement's source in the failure message; a separate tight regression bound may sit beside it |
```

## 2. `MASTER_SDLC.md` > Review Decision Log - three rows

```
| D1xx | Author decision (2026-09-20): the Tower Console panel may be up to 35% of screen height; docs/19's general 30% container cap stays for everything else | Keep 30% and scroll the entry list, or keep 30% and drop the highlighted entry's effect footer | The Console does not pause the game. Seven entries at the 24 px floor measure about 370 px at 1080p; scrolling would hide purchasable entries during combat, and the footer is the only place the Console states what an upgrade does now that rows are one line (UI pass LEDGER UR-25) |
| D1xx | Author decision (2026-09-20): the Tower Console's 24 px text floor covers each entry's row label and its price or MAX tag; the panel's title, footer hint, key number and pool word may be smaller. Each entry is one line - name and rank status, price in a tag - and the highlighted entry's effect sentence is shown once in a footer | Apply the floor to every label in the panel; or to the row label only; or keep the full effect sentence in every row | The Register names price and MAX as entry content, so they take the floor. Full sentences in every row measured about 672x773 px and ran off a 1080p screen (UI pass FAILURE_POINTS UP-08, LEDGER UR-05, UR-26) |
| D1xx | Author decision (2026-09-20): the prototype UI uses one font, Jersey 10 (SIL OFL 1.1), for every surface | Pixelify Sans, the UI pass's first choice; Jersey 15; VT323 | Pixelify Sans's 5 reads as S and its 2 as 8 at HUD sizes, so 150/200 Scrap read close to 180/800. Jersey 10 has unambiguous digits. Known trade: it lacks 29 Latin Extended-A characters (Esperanto and a few others); French, German, Spanish, Polish, Czech and Turkish are covered (UI pass LEDGER UR-15) |
```

docs/19 needs the matching text from `HANDOFF.md` H-05 and H-06 in the same commit.

If the Provisional Values Register carries docs/19's 30% container cap as a row, the 35% Console allowance belongs beside it; a search of `MASTER_SDLC.md` on this branch found the 30% figure only in docs/19, so no Register edit is proposed.

## 3. `MASTER_SDLC.md` > Change Log - one row

```
| 0.8.xx | **Prototype UI pass (out of sequence, author request 2026-09-20).** Every player-facing UI surface - HUD, threat feedback, Level-Up Draft, Tower Console, pause and settings menus, run-end screens - restyled onto one code-built theme, one palette of cosmetic tokens and one OFL font, with no behaviour, rule, number or input change. Recorded decisions D1xx (Console height allowance), D1xx (Console text floor scope and row composition) and D1xx (UI font), and the matching docs/19 text. The pass's own record, review and ledger are in `phases/UI_PASS/`. This entry describes what the pass did; it does not assert that any gate is met. |
```

## 4. Still open for owners outside this branch

`HANDOFF.md` H-02 (a real translation file; all wording in `src/ui/theme/ui_strings.gd` wants the author's eye, including the new "Restores %d HP for %d Scrap"), H-03 (debug overlay on by default over the HUD), H-04 (`PausedChoiceBar` highlight is colour-only), H-07 (`run_flow_controller.gd` relies on a UI surface having registered the strings), H-08 (exclude `src/ui/dev/*` from export), H-09 (full suite on the merged tree).

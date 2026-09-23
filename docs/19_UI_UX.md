# 19 - UI / UX

**Version:** 0.2.0 (draft; becomes a working document at 0.5.0 under the master's Document Control)  
**Status:** Working system document. Its sections were moved, with ledger FIX edits applied, from MASTER_SDLC.md 0.7.0 on 2026-09-14 so the master keeps intent, rules, gates, and the Provisional Values Register while implementation detail lives here.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

HUD, menus, upgrade screens, health bars, damage numbers, accessibility, animations, and usability guidelines.

**Owns:** the three second rule, the readability hierarchy, device prompt switching, pause authority in the interface layer, UI text expansion, dynamic container rules, the Level-Up Draft interface, the HUD, hold-to-confirm, the Movement-only controls setting, the player-versus-Tower card differentiation rules, the visual half of Directional Threat Feedback, and the Hub interface. The Tower Console interface and sector selection are removed by D115 (no in-run shop, 2026-09-23) — see "Tower Console UI" below.

---

## Upgrade Draft UI & Navigation

When the player levels up, the simulation pauses fully and the Level-Up Draft appears.

- **Presentation:** A focused central panel with three cards in a horizontal row, dimming the background by 60% but keeping the battlefield visible; every draft guarantees at least one Player card and at least one Tower card. (A radial menu was considered and is parked in document 30; its stick-direction input model conflicts with linear card cycling.)
- **Input Lockout & Arming:** Input is locked out for 0.4 seconds after the Draft opens. Hold-to-confirm inputs — the movement-only hold-up below, and the gamepad hold — only arm once input has returned to neutral at least once after the lockout ends, so a key or stick already held at the moment the Draft opens cannot auto-confirm a card.
- **Mouse/Keyboard:** The cursor is unlocked and visible throughout play, not only during the Draft. Hovering highlights a card. Left/right (or A/D) cycles the highlighted card on each press, repeating every 0.3 seconds while held, and wraps at the ends. Number keys 1, 2, 3 select and confirm the corresponding card in a single press. Space, Enter, or a mouse click confirms the highlighted or clicked card.
- **Gamepad:** The UI defaults to the first card. The left stick or D-pad cycles through the choices with the same 0.3 second repeat and wrap-around as keyboard. The confirm button (A/Cross) selects.
- **Movement-only:** Left and right on the stick or movement keys cycle the cards with the same repeat and wrap; holding up for 1.0 second confirms the highlighted card, filling a visible ring that resets if the hold is released before it completes. There is no auto-timeout; the draft waits.
- **Draft Actions:** Select; Reroll (Provisional Default: one per run in the prototype, bound to X/Square or R — one per draft in the vertical slice; it replaces all three cards, keeps the guarantee of at least one Player and one Tower card, and avoids showing the same three cards again when the pool allows it); Banish (excluded from the prototype, defined by document 13 for the slice). Fallback cards (Overdrive, Reinforce) appear in the Draft when a pool is exhausted, so Scrap-priced content still has a sink even with no Tower Console left to also sell them (D115, 2026-09-23). There is no Cancel: a draft must resolve.
- **Rarity (D117, 2026-09-23):** Every card carries a rarity rolled for that draft — Common, Rare, or Epic — shown as a small coloured badge beside the header word (Common parchment/grey, Rare blue, Epic purple/gold) and a matching border tint, never colour alone: the badge's TEXT ("COMMON"/"RARE"/"EPIC") is the primary signal, the tint a redundant reinforcement. See the Provisional Values Register > "Draft rarity" for the odds and value-multiplier numbers.
- **Audio Cues:** Every UI navigation (highlight change, confirm, reroll) must have a distinct, non-intrusive audio cue. A player should be able to navigate the draft by listening while keeping their eyes on the battlefield.
- **Readability:** Upgrade cards must display the icon, name, a one-sentence mechanical effect, and, for a rank the player already holds, the rank change (for example "Rank 1 → 2 of 3"). They must not require reading paragraphs of text.
- **Differentiation:** Player cards and Tower cards are distinguished by frame shape (rounded for player, squared for Tower), a fixed glyph, and a header word, never by colour alone. Every draft contains at least one of each.

## Tower Console UI — removed (decision D115, 2026-09-23)

The Tower Console (the second, priced, non-pausing upgrade interface this section used to define) is removed from runs entirely. Author decision D115 ("no in-run shop"): the Level-Up Draft is the only in-run power growth; Scrap converts to Cores at Run-End Settlement instead of being spent here (Provisional Values Register > "Meta: Run-End Settlement (prototype)"). Every rule this section used to state — the `console_open` lifecycle, the world-space panel and its placement, the purchase channel and sector-selection input, and the in-run Repair action — no longer exists. The `console_open`/`console_cycle_*`/`console_select_*`/`console_cancel` input actions are removed from the Input Map below. This section is kept, marked removed, rather than deleted, per this project's own convention for a superseded mechanic (compare the "Teaching Wave XP (C-XPCAP)" Register row, removed by D108 the same way).

---

## HUD

- **Player Health:** A health bar top-left showing the player's current health.
- **Tower Health:** A health bar top-centre, always on screen regardless of camera position, with the Tower's shield drawn as an overlaid segment on the health bar; directly below it, "Wave n/8" shows wave progress (teaching waves are shown as T1–T4 in the slice). Both the player and Tower health bars carry a tick mark at 40% of maximum and change border shape once health drops below it.
- **Scrap:** Top-right, showing current Scrap as "n/200"; a "FULL" badge appears at the cap, and the overflow hopper's amount is shown alongside it whenever the hopper is non-empty.
- **XP:** A bar along the bottom of the screen showing XP progress together with the player's current level and the number of rerolls remaining.
- **Truncation:** Any HUD number may truncate with an ellipsis when space is tight, with the full value shown in a custom focus tooltip, per UI Layout & Dynamic Container Rules.

---

## UI Layout & Dynamic Container Rules

To prevent UI breakage across languages and scaling damage numbers, strict layout rules apply.

- **Godot Implementation:** All text containers (buttons, tooltips, upgrade cards, and Tower Console entry rows) must use `Label` or `RichTextLabel` with `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` and `size_flags_horizontal = Control.SIZE_EXPAND_FILL`; a `RichTextLabel` must set `fit_content = true` so it grows vertically.
- **Max Dimensions:** Containers must have a defined `custom_minimum_size` but no fixed `size`. They must expand vertically to fit text. If a container exceeds a maximum height (Provisional Default 30% of screen height), it must become scrollable, not truncate — except upgrade cards, which never scroll: the one-sentence-effect limit under Readability keeps them within height, so a card that would exceed it is a content bug to fix, not a layout case to handle at runtime.
- **Icon + Text Alignment:** Icons must be vertically centered with the first line of text. If text wraps, the icon remains top-aligned.
- **Truncation Fallback:** If text absolutely must be truncated (e.g., in a tight HUD element), it must truncate with an ellipsis (`...`) and display the full text in a custom focus tooltip on hover or on gamepad/keyboard focus. Silent truncation is banned.
- **Pseudo-Localization:** A debug toggle (F2; Input Map) must exist that enables Godot's built-in pseudolocalization rather than a custom implementation, with its expansion ratio set to 0.3 so every string renders roughly 30% longer, wrapped in accent brackets, ensuring the UI does not break when translated later.

---

## Input Map

This is the single source for input-to-action bindings; other sections reference it rather than restating key lists.

Move WASD / arrows / left stick · Draft cycle A/D, ←/→, D-pad, left stick (Draft is paused) · Draft number keys 1/2/3 select and confirm · Confirm Space, Enter, left mouse, A/Cross · Reroll R / X/Square · Pause Escape / Start · Debug overlay toggle F1 · Pseudo-localization toggle F2.

D115 (no in-run shop, 2026-09-23) removed the Tower Console and, with it, the eleven `console_open`/`console_cycle_next`/`console_cycle_prev`/`console_select_1`–`7`/`console_cancel` actions this row used to list — none of them exist in `project.godot`'s `[input]` block any more.

The two debug toggles are keyboard-only and carry no gamepad binding; they are present in the exported build's input map, which the Settings check (P0.2) reads (Author decision, D78).

The game is playable with movement input alone, and every menu has a movement-only path: the Draft's movement-only cycle-and-hold-to-confirm path (Upgrade Draft UI & Navigation) requires none of the keys or buttons listed above. (The Console's own movement-only sector path is removed with the Console, D115.)

# 19 - UI / UX

**Version:** 0.2.0 (draft; becomes a working document at 0.5.0 under the master's Document Control)  
**Status:** Working system document. Its sections were moved, with ledger FIX edits applied, from MASTER_SDLC.md 0.7.0 on 2026-09-14 so the master keeps intent, rules, gates, and the Provisional Values Register while implementation detail lives here.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

HUD, menus, upgrade screens, health bars, damage numbers, accessibility, animations, and usability guidelines.

**Owns:** the three second rule, the readability hierarchy, device prompt switching, pause authority in the interface layer, UI text expansion, dynamic container rules, the Level-Up Draft interface, the Tower Console interface, the HUD, hold-to-confirm, sector selection, the Movement-only controls setting, the player-versus-Tower card differentiation rules, the visual half of Directional Threat Feedback, and the Hub interface.

---

## Upgrade Draft UI & Navigation

When the player levels up, the simulation pauses fully and the Level-Up Draft appears.

- **Presentation:** A focused central panel with three cards in a horizontal row, dimming the background by 60% but keeping the battlefield visible; every draft guarantees at least one Player card and at least one Tower card. (A radial menu was considered and is parked in document 30; its stick-direction input model conflicts with linear card cycling.)
- **Input Lockout & Arming:** Input is locked out for 0.4 seconds after the Draft opens. Hold-to-confirm inputs — the movement-only hold-up below, and the gamepad hold — only arm once input has returned to neutral at least once after the lockout ends, so a key or stick already held at the moment the Draft opens cannot auto-confirm a card.
- **Mouse/Keyboard:** The cursor is unlocked and visible throughout play, not only during the Draft. Hovering highlights a card. Left/right (or A/D) cycles the highlighted card on each press, repeating every 0.3 seconds while held, and wraps at the ends. Number keys 1, 2, 3 select and confirm the corresponding card in a single press. Space, Enter, or a mouse click confirms the highlighted or clicked card.
- **Gamepad:** The UI defaults to the first card. The left stick or D-pad cycles through the choices with the same 0.3 second repeat and wrap-around as keyboard. The confirm button (A/Cross) selects.
- **Movement-only:** Left and right on the stick or movement keys cycle the cards with the same repeat and wrap; holding up for 1.0 second confirms the highlighted card, filling a visible ring that resets if the hold is released before it completes. There is no auto-timeout; the draft waits.
- **Draft Actions:** Select; Reroll (Provisional Default: one per run in the prototype, bound to X/Square or R — one per draft in the vertical slice; it replaces all three cards, keeps the guarantee of at least one Player and one Tower card, and avoids showing the same three cards again when the pool allows it); Banish (excluded from the prototype, defined by document 13 for the slice). Fallback cards (Overdrive, Reinforce) appear in the Draft when a pool is exhausted, and at the Console for 90 Scrap under the same condition (Tower Console UI). There is no Cancel: a draft must resolve.
- **Audio Cues:** Every UI navigation (highlight change, confirm, reroll) must have a distinct, non-intrusive audio cue. A player should be able to navigate the draft by listening while keeping their eyes on the battlefield.
- **Readability:** Upgrade cards must display the icon, name, a one-sentence mechanical effect, and, for a rank the player already holds, the rank change (for example "Rank 1 → 2 of 3"). They must not require reading paragraphs of text.
- **Differentiation:** Player cards and Tower cards are distinguished by frame shape (rounded for player, squared for Tower), a fixed glyph, and a header word, never by colour alone. Every draft contains at least one of each.

## Tower Console UI

The Tower Console is the second upgrade interface and the opposite of the Draft in every operational respect: it never pauses the simulation. It is defined mechanically under Tower Interaction Mechanics; the interface rules are:

- **Presentation:** A compact world-space panel anchored beside the Tower, never covering the Tower or the player. The battlefield stays fully visible and fully live; the player's auto-fire is disabled while the Console is open, but the Tower keeps firing. While the player is inside the Interaction Radius and the Console is closed, a small prompt appears in its place instead: "[E / Y] Tower Console", greyed to "(nothing affordable)" when no entry is affordable (Author decision D107, 2026-09-23) — the prompt and the purchase list are mutually exclusive, never both shown at once.
- **Contents:** The fixed catalogue of purchasable Player and Tower upgrades, each entry showing its Scrap price and current progress as "Rank n of 3"; an entry already at rank 3 shows "MAX" with no price. Repair is affordable when the Tower is missing at least 2 health and the player holds at least 1 Scrap. One purchase restores min(50, missing health rounded down to an even number, 2 × Scrap held) health at 1 Scrap per 2 health. At 0 Scrap Repair is greyed and does not count toward opening the Console. Unaffordable entries are greyed, never hidden. Fallback cards (Overdrive: +10% weapon damage; Reinforce: +10% Tower damage) appear here for 90 Scrap once their pool is exhausted, so Scrap always has a sink; the same fallback cards appear in the Level-Up Draft under the same exhausted-pool condition (Upgrade Draft UI & Navigation).
- **Input:** The left stick always moves the player. Entries are cycled with Tab / Shift+Tab, the mouse wheel, the D-pad, or the right stick; number keys 1 through 7 highlight an entry and start its purchase channel directly, in the same order as the seven Movement-only sectors below (Input Map). Confirm starts a purchase; Cancel (Q / B/Circle) closes the Console — pressing `console_open` again reopens it immediately, with no need to leave and re-enter the radius. Every purchase is a 0.5 second channel shown with a fill ring; moving faster than 10% of base speed before it completes cancels the channel without spending anything. With the Movement-only controls setting enabled (off by default), the ground inside the Interaction Radius is divided into seven fixed 51.4° sectors clockwise from north: Repair, Rapid Fire, Heavy Rounds, Patch Kit, Caliber, Optics, Shield Matrix. An unavailable or maxed sector stays in place and buys nothing. Once every upgrade in a pool is maxed, that pool's three sectors (player: Rapid Fire, Heavy Rounds, Patch Kit; Tower: Caliber, Optics, Shield Matrix) each sell that pool's fallback card for 90 Scrap. A sector purchase requires the Console to be open. Standing still (below 10% of base speed) inside a sector for 1.0 second buys one rank of that sector's entry, with the same fill ring; a sector only re-arms after the player moves above 10% of base speed or leaves it, so the same window can never buy twice. Greyed or maxed sectors show no fill. (Slice catalogue paging beyond these seven sectors is a separate decision for this document.)
- **Lifecycle:** Opens on the `console_open` action while the player is inside the Interaction Radius with at least one entry affordable, at any speed (Author decision D107). With the Movement-only controls setting enabled, it also opens automatically after 0.3 seconds inside the Interaction Radius while the player's speed is below 10% of base speed and at least one entry is affordable — the same no-button path that setting has always used, kept unchanged so a Movement-only player never needs a button to open it. Closes on leaving the radius, on Cancel, on player death, or when a Level-Up Draft opens. After a Cancel, pressing `console_open` reopens the Console immediately, with no need to leave the radius and re-enter (the leave-and-reenter rule still applies to the Movement-only automatic open, so standing still right after a Cancel cannot instantly re-open it that way). While any pause reason is active the Console is hidden and ignores input (Technical Architecture: PauseAuthority); its timers run on SimClock.
- **Placement:** The panel's nearest edge sits 200 pixels from the Tower's centre, on the side opposite the player; it flips to the other side only after the player's bearing from the Tower changes by more than 30 degrees, so it does not flicker. It renders at 85% opacity, above enemies and below telegraphs, scaled each frame to the view scale so entry text stays at least 24 px tall on screen (scene-tree implementation: Technical Architecture).
- **Differentiation:** The same frame-shape and glyph rules as the Draft apply to its entries.

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

Move WASD / arrows / left stick · Draft cycle A/D, ←/→, D-pad, left stick (Draft is paused) · Draft number keys 1/2/3 select and confirm · Confirm Space, Enter, left mouse, A/Cross · Reroll R / X/Square · Console open E / Y (button index 3) (Author decision D107, 2026-09-23) · Console cycle Tab / Shift+Tab, mouse wheel, D-pad, right stick · Console number keys 1–7 highlight and start the purchase channel · Console Cancel Q / B/Circle · Pause Escape / Start · Debug overlay toggle F1 · Pseudo-localization toggle F2.

`console_open` (E / gamepad Y, button index 3) was free in the existing Input Map — checked against every other bound action before assignment (project.godot's own `[input]` block) — and does not collide with any other Player, Draft, or Console binding, keyboard or gamepad.

The two debug toggles are keyboard-only and carry no gamepad binding; they are present in the exported build's input map, which the Settings check (P0.2) reads (Author decision, D78).

The game is playable with movement input alone, and every menu has a movement-only path: the Draft's movement-only cycle-and-hold-to-confirm path (Upgrade Draft UI & Navigation) and the Console's movement-only sector path (Tower Console UI) require none of the keys or buttons listed above.

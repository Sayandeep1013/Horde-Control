# 19 - UI / UX

**Version:** 0.2.0 (draft; becomes a working document at 0.5.0 under the master's Document Control)  
**Status:** Working system document. Its sections were moved, with ledger FIX edits applied, from MASTER_SDLC.md 0.7.0 on 2026-09-14 so the master keeps intent, rules, gates, and the Provisional Values Register while implementation detail lives here.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

HUD, menus, upgrade screens, health bars, damage numbers, accessibility, animations, and usability guidelines.

**Owns:** the three second rule, the readability hierarchy, device prompt switching, pause authority in the interface layer, UI text expansion, dynamic container rules, the Level-Up Draft interface, the HUD, hold-to-confirm, the Settings screen, the Movement-only controls setting, the player-versus-Tower card differentiation rules, the visual half of Directional Threat Feedback, and the Hub interface. The Tower Console interface and sector selection are removed by D115 (no in-run shop, 2026-09-23) — see "Tower Console UI" below.

---

## Upgrade Draft UI & Navigation

When the player levels up, the simulation pauses fully and the Level-Up Draft appears.

- **Presentation:** A focused central panel with three cards in a horizontal row, dimming the background by 60% but keeping the battlefield visible; every draft guarantees at least one Player card and at least one Tower card. (A radial menu was considered and is parked in document 30; its stick-direction input model conflicts with linear card cycling.)
- **Input Lockout & Arming:** Input is locked out for 0.4 seconds after the Draft opens. Hold-to-confirm inputs — the movement-only hold-up below, and the gamepad hold — only arm once input has returned to neutral at least once after the lockout ends, so a key or stick already held at the moment the Draft opens cannot auto-confirm a card.
- **Explains itself (UX review, D128, 2026-10-05):** The panel's heading reads "Level up! Choose an upgrade" (the game is paused). A one-line footer lists every way to pick (click a card, keys 1 / 2 / 3, A / D to move then Space or Enter, or hold W / Up); each card carries a small "1" / "2" / "3" key badge at the start of its header row; the hold ring beside the Reroll pill is captioned "Hold W / Up to pick" and its idle triangle is drawn at full text strength, not a faint track colour; the Reroll pill reads "Reroll: R (n left)", greyed out as "No rerolls left" at zero, and a click on it rerolls.
- **Mouse/Keyboard:** The cursor is unlocked and visible throughout play, not only during the Draft. Hovering highlights a card. **A mouse click confirms only the card (or option) under the cursor; a click on empty space confirms nothing** (the `confirm` action also binds the left mouse button, so the Draft and the pause menu's choice bar ignore the global mouse-originated `confirm` and confirm through each card's or option's own click instead; D128). Left/right (or A/D) cycles the highlighted card on each press, repeating every 0.3 seconds while held, and wraps at the ends. Number keys 1, 2, 3 select and confirm the corresponding card in a single press. Space or Enter confirms the highlighted card; a mouse click confirms only the card it lands on.
- **Gamepad:** The UI defaults to the first card. The left stick or D-pad cycles through the choices with the same 0.3 second repeat and wrap-around as keyboard. The confirm button (A/Cross) selects.
- **Movement-only:** Left and right on the stick or movement keys cycle the cards with the same repeat and wrap; holding up for 1.0 second confirms the highlighted card, filling a visible ring that resets if the hold is released before it completes. There is no auto-timeout; the draft waits.
- **Draft Actions:** Select; Reroll (Provisional Default: one per run in the prototype, bound to X/Square or R — one per draft in the vertical slice; it replaces all three cards, keeps the guarantee of at least one Player and one Tower card, and avoids showing the same three cards again when the pool allows it); Banish (excluded from the prototype, defined by document 13 for the slice). Fallback cards (Overdrive, Reinforce) appear in the Draft when a pool is exhausted, so Scrap-priced content still has a sink even with no Tower Console left to also sell them (D115, 2026-09-23). There is no Cancel: a draft must resolve.
- **Rarity (D117, 2026-09-23):** Every card carries a rarity rolled for that draft — Common, Rare, or Epic — shown as a small coloured badge beside the header word (Common parchment/grey, Rare blue, Epic purple/gold) and a matching border tint, never colour alone: the badge's TEXT ("COMMON"/"RARE"/"EPIC") is the primary signal, the tint a redundant reinforcement. See the Provisional Values Register > "Draft rarity" for the odds and value-multiplier numbers.
- **No wasted heals (D144):** The offer avoids Patch Kit while the player is at full health and Repair Kit while the Tower is at full health, whenever another card is available; a card's text shows the value the game really applies (D123, D143): heals and counts are never rarity-scaled.
- **Audio Cues:** Every UI navigation (highlight change, confirm, reroll) must have a distinct, non-intrusive audio cue. A player should be able to navigate the draft by listening while keeping their eyes on the battlefield.
- **Readability:** Upgrade cards must display the icon, name, a one-sentence mechanical effect, and, for a rank the player already holds, the rank change (for example "Rank 1 → 2 of 3"). They must not require reading paragraphs of text.
- **Differentiation:** Player cards and Tower cards are distinguished by frame shape (rounded for player, squared for Tower), a fixed glyph, and a header word, never by colour alone. Every draft contains at least one of each.

### Run events (docs/32 §A, D280)
Opening Pick, Patron's Boon, Sanctuary and Blood Pact reuse the Draft's card widget and input contract exactly (0.4 s lockout, neutral-return arming, left/right cycle with a 0.3 s repeat, hold-up 1.0 s, keys 1/2/3, click, touch tap; no Cancel, no Reroll). Each opens with its own title plate, subtitle and tint (blue, gold, warm gold, blood red) and plays the `chest_open` cue. An event never opens on top of a Level-Up or War Chest Draft: it queues behind them. A Blood Pact card shows its cost in numbers ("-20 max HP", "-100 Tower max HP") beside Refuse. On a phone the subtitle is dropped. Focus shows as a small arc under the player's overhead bar, with a soft gold glow at full.

## Tower Console UI — removed (decision D115, 2026-09-23)

The Tower Console (the second, priced, non-pausing upgrade interface this section used to define) is removed from runs entirely. Author decision D115 ("no in-run shop"): the Level-Up Draft is the only in-run power growth; Scrap converts to Cores at Run-End Settlement instead of being spent here (Provisional Values Register > "Meta: Run-End Settlement (prototype)"). Every rule this section used to state — the `console_open` lifecycle, the world-space panel and its placement, the purchase channel and sector-selection input, and the in-run Repair action — no longer exists. The `console_open`/`console_cycle_*`/`console_select_*`/`console_cancel` input actions are removed from the Input Map below. This section is kept, marked removed, rather than deleted, per this project's own convention for a superseded mechanic (compare the "Teaching Wave XP (C-XPCAP)" Register row, removed by D108 the same way).

---

## Settings

Review Decision Log D121 made Settings a vertical list of rows (label on the left, "< value >" on the right) and D233 (v1.0) split it into five tabs. The Register's "Settings" row and "Settings tabs" row (v1.0 Interface) carry the defaults, ranges and timings; `src/core/game_settings.gd` persists them at `user://settings.cfg`.

- **Tabs.** Audio, Video, Gameplay, Controls, Accessibility. The tab strip shows the active tab with an accent underline (a shape cue, not colour alone) and Q / E keycaps. Q / E, LB / RB, a click or a tap switch tab and wrap round. Reset to Defaults and Back sit under every tab. The Controls tab is keyboard-only and is hidden on a phone, as are Display Mode, Window Size and V-Sync.
- **Rows.** Audio: Master, Music, Sound Effects (SFX, SFX_Priority, Ambience), Interface (the UI bus), Mute All. Video: Display Mode, Window Size (windowed only), V-Sync, FPS Limit, Show FPS. Gameplay: Auto-cast Battle Skill, Damage Numbers, Screen Shake (0-100%), Show Overhead Bars, Pause When Unfocused, Movement-only controls. Controls: Move up / down / left / right, Dash, Battle Skill, Pause, Reset Controls. Accessibility: HUD Scale, Reduce Flashing, Enemy Outlines. TowerCue is reached only by sending through SFX_Priority, so it is not driven a second time.
- **Change cadence.** Only the volume rows, Screen Shake and HUD Scale repeat while a direction is held, at the Draft's cadence. Every other row changes once per press, so a toggle cannot flicker and Display Mode cannot skip.
- **Opening.** Settings opens with the 0.4 s input lockout, on the first tab and first row, with keys already held at open seeded so they do not read as presses.
- **Input, keyboard and gamepad.** Up / Down move the highlighted row; Left / Right change its value, applied and saved at once. Holding Left or Right for the hold-to-confirm duration on Back closes the screen, and on Reset to Defaults resets at once; `confirm` closes from Back, and a first `confirm` on Reset shows "Press again" (lapses after 3 s or when the highlight moves) before a second one resets. A direction already held cannot auto-confirm (the neutral-return rule). A movement-only player therefore never needs a button.
- **Rebinding.** Each Controls row shows two key slots ("[W] / Up"; the bracket marks the targeted slot). Left / Right picks the slot, `confirm` or a click starts listening ("Press a key..."), the next key becomes the binding, Esc cancels. A key already used by another action swaps with the slot's old key, so no action is left without one. Bindings are saved under `[controls]` and applied by `GameSettings.apply()` on boot; gamepad and mouse bindings are fixed and listed in a note under the rows. Reset Controls restores the project keys.
- **Mouse and touch.** Hovering a row highlights it; the "<" / ">" arrows change the value; clicking Back closes at once; clicking a binding row starts a rebind; clicking Reset shows "Press again".
- **Long tabs.** The row list scrolls inside a card capped to the canvas and keeps the highlighted row in view.
- **Platform input floor carve-out.** Settings is the one paused menu that does not lay its choices out horizontally (D121); it keeps hold-to-confirm and the movement-only path on the vertical shape's own axes.
- **Reachability.** The pause menu and the run-end screens (via `RunFlowController`), the title screen and the Hub (War Camp) each open their own `SettingsMenu`, releasing keyboard focus from whatever sits behind it; Esc closes it on the title and the Hub, `pause` in a run. All instances read and write the same `GameSettings` state.
- **Settings footer (D246):** Reset to Defaults and Back sit under their own separator on bordered button plates, centred, apart from the settings rows. Results (D247): the cause line names the last enemy that hurt the player or the Tower ("Slain by a Bomber", "The Tower fell to a Brute"), falling back to the generic line when unknown. The Hub menu card's ribbon shows only in the touch layout (D249).
- **Applied at boot.** `GameSettings.load_from_disk()` and `.apply()` run once from the title screen's `_ready()`, before the title music; apply covers bus volumes, display mode, window size, V-Sync, the FPS cap, the FPS readout and the saved key bindings.
- **Live during a run.** `src/audio/audio_ducking.gd` reads Music and Sound Effects volume from `GameSettings` every tick, so a change made from pause takes effect at once. "Pause when unfocused" is read by `RunFlowController` at the moment focus is lost.

---

## HUD

v1.0 redesign (D232; docs/31 §8.1). Numbers are in the Register's "v1.0 Interface" table. Five clusters, each pinned to a screen edge by anchors; the whole HUD scales with the HUD Scale setting. No cluster carries a word caption: the icon and the colour mean the thing (docs/19 shape language, below).

- **Player (top-left):** a level badge showing the level (the internal level plus one, D133), the HP bar with "cur/max" inside it, and a thin XP bar under it. The XP bar has a visible empty track.
- **Tower (top-centre):** the Tower bar with the shield as a strip across its top and "cur/max" inside it; one info line under it, "WAVE n/15 · TYPE" with a REPAIRING tag while Scrap repairs the Tower and the run timer on the right; a thin wave-progress bar under that. In a boss wave the boss bar hangs below the cluster with the boss's name and a phase mark. Both health bars tick at 40% of maximum and change border shape below it. While a Siege warning runs, the Tower pill pulses red.
- **Scrap and kills (top-right):** the Scrap pouch with "n/cap" (FULL at the cap, the full value in a focus tooltip when truncated) and a skull with the kill count.
- **Build bar (bottom-left):** four player ability slots and three Tower ability slots with icons and 1-5 level pips; empty slots are dimmed. Passives are listed in the pause menu, not here.
- **Action cluster (bottom-right):** Dash with one pip per charge and a radial cooldown wipe; Battle Skill with a 96 px icon, a radial wipe and the seconds left; each has its key hint under it, read from the live Input Map. On touch the TouchControls buttons replace this cluster (they are the same widget).
- **Removed in v1.0:** the full-width XP ribbon, the Rerolls count (shown only in the Draft), the word captions, the "~ n Cores at run end" line (now in the pause menu's Run stats) and the floating Tower value beside the off-screen arrow (the arrow stays).
- **Overhead bars:** the player and Tower overhead bars stay behind the Show Overhead Bars setting.
- **Text size:** HUD numbers are 37 px, the legibility floor, at HUD Scale 100%; the scale setting caps itself on a narrow canvas so the top row never collides.
- **Run announcements (D129, D130):** Non-pausing, non-interactive text in a band under the top HUD (the wave banner first, the toasts below it, so neither covers the Tower at spawn; D145): a centred banner at every wave start reading "WAVE n · TYPE" (red for a boss wave) with the wave horn, a red "SIEGE INCOMING" line when a Siege warning starts (docs/11 > Siege warning: the first Seeker spawns 3 s after the wave opens), the boss's name for 2 s with the boss roar, and a short "ELITE · AFFIX" toast (the first elite gets its teaching hint instead). The banner comes only from `wave_started`, exactly once per wave number (D240). Off-screen spawns show an intent-coloured chevron at the screen edge, at most one per 30° sector, for the warning's lead time. The banner starts under the Tower cluster; toasts sit at the bottom centre. The run objective line and the contextual hints (D241) go through one queue, one toast at a time, at most 5 s each: run start ("Your bow fires on its own. Move with WASD.", live bindings), first damage to the player (the dash key), the Battle Skill first ready, the first Tower health damage while carrying Scrap (stand by the Tower to repair), and the first Bomber, Brute, elite and boss (a one-line callout naming the threat and the answer). Each is recorded once per profile in the additive `hints_seen` list in the MetaProgress profile (no schema bump; reconcile adds it); touch builds use the mobile string table. Timings: Register > "Run announcements" and > "v1.0 Interface" > "Contextual hints". They run on pausable time (D140): while the Draft or the pause menu is open they are hidden and their timers stand still, so the hints are never spent behind a menu.
- **Ground symbols (D131):** The XP crystal is drawn in the XP bar's purple so the pickup and the bar read as one thing; pickups bob 4 px; an attack telegraph is one danger colour for every enemy (enemy identity stays in the sprite) and its ground disc grows from nothing to the full ring as the wind-up reaches the strike moment.
- **Tower occlusion (D127):** The Tower and the player share one Y-sorted band, so a player standing north of the Tower is drawn behind it; while the player is inside the Tower sprite's on-screen rectangle the Tower fades to the Register's occlusion alpha and restores when the player leaves it.
- **How to Play (D236, D242):** four short sections (protect yourself and the Tower; Dash and Battle Skill; the Draft; repair with Scrap) naming the live key bindings, then "Know your enemy" (a sprite and one line each for the Seeker, Hunter, Opportunist, Bomber, Brute, elites and bosses) and the Controls list that used to be the title screen's separate page (one entry point; F1 / F2 rows only in a debug build), reachable from the title screen and from the pause menu. Desktop lays it out in two columns so it fits the canvas without scrolling (the movement keys scroll it if a debug build adds rows). The title screen's logo hides while the page is open. The title card now sits on the left half and the castle on the right (it used to be drawn behind the card).
- **Off-screen Tower indicator (D134):** The arrow always points at the Tower; below 40% health it turns the danger colour and the Tower icon gets a pulsing red ring (never a rhombus, which means XP only; D142), so the shape still changes without losing the direction. The arrow keeps its screen position between the top HUD and the bottom HUD (Register > "Threat arrow margins").
- **Pause menu (D134, D235):** Four horizontal choices, Resume, Settings, How to Play and Abandon run, with the hold-to-confirm ring, then Build / Passives / Run stats columns read from the live run (Battle Skill, difficulty, seed, abilities with levels, Tower abilities, passives with ranks; time, kills, elites, damage taken, Scrap repaired, estimated Cores). The last choice reads "Abandon run" and asks again ("Abandon run? Progress so far still earns Cores": Keep playing / Abandon, Keep playing first) before the run is abandoned; closing the menu resets the question.
- **Text on parchment (D132):** Secondary text on parchment panels (Records, Achievements, Controls, Credits, Hub hint) uses a dark umber token (`TEXT_ON_PARCHMENT`) instead of the dim tan used on dark wood. Achievement rows show their reward ("Unlocks card: ..." or the perk) and an unlocked row's state is tinted.
- **Skill Tree nodes (D132):** Node names and prices are drawn at 20 / 18 px at the 1080 base; nodes are wider than tall; "can't afford" is a dimmed tablet with an amber price rather than red.
- **Skill Tree legibility (D249):** owned nodes wear a gold rim (the legend's Owned); the branch colour appears only on the icon, the rank pips and an 8 px strip at the top of the plate; the price stays at 37 px (coin glyph and number fit the tablet).
- **Menu cards (D127):** The Title menu card (five buttons: Play, How to Play, Credits, Settings, Quit; a small "v1.0.0" sits at the bottom-right) and the Hub menu card sit in a tall band so every button, including Quit, Settings and Back to Title, lies inside 1280 x 720 (a test asserts it).
- **Truncation:** Any HUD number may truncate with an ellipsis when space is tight, with the full value shown in a custom focus tooltip, per UI Layout & Dynamic Container Rules.
- **Camera and HUD bands (D141, D230):** The camera may scroll past each arena wall by the HUD band (Register > "Camera HUD margin"), so a player standing at any wall is drawn clear of the Tower cluster with its boss bar, the bottom build bar and action cluster and the screen sides, never under them; the band grows with the HUD Scale.
- **Run-end seed (D143):** The run-end screen prints "Seed: N" small above the choices, for bug reports.
- **Draft footer and badge (D145):** The Draft's footer lines (how to pick, the hold caption, Reroll) use the bright value text, not the dim tan; the 1/2/3 key badge on each card is a square of at least 48 px, not a sliver.

### Symbol shapes (D142)

One shape, one meaning. A shape that means one thing must not be reused for another.

| Shape | Meaning | Where |
| --- | --- | --- |
| Purple rhombus (crystal) | XP | the pickup; the XP bar's colour |
| Gold coin pouch | Scrap | the pickup; the HUD Scrap icon |
| Gold hexagonal coin | Cores | Hub, Skill Tree prices, results |
| Red "!" above a head | An attack is about to land | enemy wind-up marker |
| Ground ring (filling disc) | The strike area of that attack | enemy wind-up |
| Pulsing red ring round the Tower icon | The Tower is below 40% health | off-screen Tower arrow |
| White tick inside a bar | The 40% low mark | player and Tower health bars |
| Blue strip on the Tower bar | Tower shield | Tower health bar |
| Chevron at the screen edge, red / yellow / purple | An enemy of that intent is about to spawn off-screen (Seeker / Hunter / Opportunist) | spawn markers |
| Skull | Kills | HUD top-right |
| Green frame / orange frame on a slot | Player ability / Tower ability | build bar |
| Radial wipe over an icon | Cooldown remaining | Dash and Battle Skill buttons |

---

## Visual style: one pixel grid (D156-D165)

Everything on screen is Tiny Swords pixel art at the same grain: 1 art pixel is 1 screen pixel at 1920 x 1080, and nothing is rescaled or rotated. Numbers are in the Provisional Values Register ("Pixel type grid", "World texel scale", "Ground tile grid", "Draft card frame and ribbon", "HUD bar and pointer pixel style", "Project-made pixel art", "Shadows").

- **Filtering and scaling.** The default texture filter is Nearest. `window/stretch/mode` stays `canvas_items` (D163), so crispness at other sizes comes from the filter, the font and uniform scale, not from stretch mode.
- **Type.** Jersey 10 is imported with antialiasing, hinting and subpixel positioning off, and used only at its grid sizes. Legibility rule (D166): every text a player must read is at least 37 (body, HUD numbers, buttons, card text); values and headings are 56; the title is 75 and the logo 131 (93 compact); 19 is only for non-essential tags. At a real 1280 x 720 window a 19 px glyph pixel is 0.67 screen px and glyph columns drop out, which is why 37 is the floor. Parchment surfaces (menus, pause, settings, run end, Hub and Skill Tree panels, Records, Achievements, Controls, Credits, Draft cards) use dark ink (`TEXT_ON_PARCHMENT`) with no outline and `HIGHLIGHT_ON_PARCHMENT` for the highlighted choice; light outlined text is only for the HUD and text over the world. The HP, TOWER and SCRAP captions are dropped from the HUD because the icon carries the meaning.
- **World.** Every sprite is at scale 1.0. Ground, paths, ponds, plateaus and the coast are painted from the pack's tiles (scalloped 2 px ink edge); the bridge is the pack's vertical piece; shadows are the pack's blob.
- **Surfaces.** Draft cards sit on the pack's scroll (Player) or carved panel (Tower); rarity is a ribbon; selection is four corner pointers; HUD bars are square, ink-bordered pixel bars.
- **Glyphs.** Shape tokens (triangle, square, heart, tower, recycle, crystal, core, coin, arrow, boot, tent) are 32 px pixel icons tinted at draw time; `tools/art/make_pixel_icons.py` makes them, and also the "!" marker, the telegraph ring and the XP crystal. The shape-to-meaning table above is unchanged.

## UI Layout & Dynamic Container Rules

To prevent UI breakage across languages and scaling damage numbers, strict layout rules apply.

- **Godot Implementation:** All text containers (buttons, tooltips, upgrade cards, and Tower Console entry rows) must use `Label` or `RichTextLabel` with `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` and `size_flags_horizontal = Control.SIZE_EXPAND_FILL`; a `RichTextLabel` must set `fit_content = true` so it grows vertically.
- **Max Dimensions:** Containers must have a defined `custom_minimum_size` but no fixed `size`. They must expand vertically to fit text. If a container exceeds a maximum height (Provisional Default 30% of screen height), it must become scrollable, not truncate — except upgrade cards, which never scroll: the one-sentence-effect limit under Readability keeps them within height, so a card that would exceed it is a content bug to fix, not a layout case to handle at runtime.
- **Icon + Text Alignment:** Icons must be vertically centered with the first line of text. If text wraps, the icon remains top-aligned.
- **Truncation Fallback:** If text absolutely must be truncated (e.g., in a tight HUD element), it must truncate with an ellipsis (`...`) and display the full text in a custom focus tooltip on hover or on gamepad/keyboard focus. Silent truncation is banned.
- **Pseudo-Localization:** A debug toggle (F2; Input Map; active only in a debug build, D244) must exist that enables Godot's built-in pseudolocalization rather than a custom implementation, with its expansion ratio set to 0.3 so every string renders roughly 30% longer, wrapped in accent brackets, ensuring the UI does not break when translated later.

---

## Input Map

This is the single source for input-to-action bindings; other sections reference it rather than restating key lists.

Move WASD / arrows / left stick · Dash Space, Shift, B, LB · Battle Skill E, Q, right mouse, Y, RB (keyboard bindings for Move, Dash, Battle Skill and Pause are rebindable in Settings > Controls; the lists here are the defaults) · Draft cycle A/D, ←/→, D-pad, left stick (Draft is paused) · Draft number keys 1/2/3 select and confirm · Confirm Space, Enter, left mouse, A/Cross · Reroll R / X/Square · Pause Escape / Start · Debug overlay toggle F1 · Pseudo-localization toggle F2.

D115 (no in-run shop, 2026-09-23) removed the Tower Console and, with it, the eleven `console_open`/`console_cycle_next`/`console_cycle_prev`/`console_select_1`–`7`/`console_cancel` actions this row used to list — none of them exist in `project.godot`'s `[input]` block any more.

The two debug toggles are keyboard-only and carry no gamepad binding; they are present in the exported build's input map, which the Settings check (P0.2) reads (Author decision, D78).

The game is playable with movement input alone, and every menu has a movement-only path: the Draft's movement-only cycle-and-hold-to-confirm path (Upgrade Draft UI & Navigation) requires none of the keys or buttons listed above. (The Console's own movement-only sector path is removed with the Console, D115.)

---

## Mobile (Android)

Decisions D146 and D147; numbers in the Provisional Values Register ("Touch controls", "Mobile UI scale", "Touch target minimum").

- **When it applies.** The touch controls show on a touchscreen device, on a mobile build, or with the `--touch-ui` user argument (`--no-touch-ui` forces them off). The mobile layout (compact screens, touch wording, hidden desktop rows) applies on a mobile build or with `--touch-ui`; a Windows laptop that merely has a touchscreen gets the joystick and keeps the desktop layout.
- **Movement.** A floating joystick appears where the thumb lands in the left half of the screen. It drives `move_left/right/up/down`, so the Draft's hold-up path and the movement-only controls work with it. The bow still fires on its own.
- **Dash and Battle Skill.** Two thumb buttons sit at the bottom right (Battle Skill 120 px, Dash 96 px) and show the same cooldown wipe as the desktop HUD, which hides its own action cluster on touch. Auto-cast (on by default on a phone) fires the Battle Skill for you.
- **Pause.** A pause button sits at the top right, below the Scrap and kills panel and clear of the HUD clusters. It sends the `pause` action; it hides while the Draft or the pause menu is up. Android Back does the same as Pause during a run, closes the open panel in the Hub, and leaves the app from the bare Title.
- **Everything is tappable.** Title, Hub, Settings (the < and > arrows and the Back row), Records, Achievements, the pause menu and its Abandon confirm, the Draft (tap a card picks that card; the Reroll pill is tappable) and the run-end buttons all work by tap. The Draft's hold ring and the menus' hold footers are the keyboard and gamepad way; on a phone the footers are hidden and the Draft says "Tap a card to pick it". In the Skill Tree, a finger pressed on a node selects it and holding buys it (the hold-to-buy fill); a finger held there stands in for the `confirm` action, which the engine's emulated mouse does not drive.
- **Hidden on a phone.** The Display Mode, Window Size and V-Sync rows and the whole Controls tab (it is for keyboards). A phone window is always the whole screen.
- **Size.** The UI is scaled up to 1.5 (on 16:9 phones less, so the HUD's top row still fits), which makes the 37 px body text about 20 dp. Menu rows are at least 64 px and the Title / Hub / Back buttons 80 px (logical px). Title and Hub use compact layouts. Achievements scrolls by finger drag (the engine pans only on a device that reports a touchscreen). The Skill Tree board runs unscaled while open: nodes are 140 px (about 65 dp) and show icon, pips and price; the name is in the detail panel, and the board scrolls if it does not fit (D168). On the compact layout (D167) the run-end body scrolls inside a card capped to the screen; the Draft heading starts 160 px down, cards are shorter, the rarity word sits in the header row, the hold caption is hidden (the v1.0 HUD has no XP ribbon) and "Tap a card to pick it" shares the footer row with Reroll; the Hub hint banner sits in the free column left of the menu; the Title menu is in the left half with the castle on the right; Credits scrolls.
- **Limits.** 48 dp is 132 px of the 1080 canvas; seven menu rows of that height do not fit, so menu rows are about 38 dp. The pause button is about 51 dp.
- **Test aid.** `src/dev/touch_selftest.tscn` drives the real game with synthetic finger events and prints SELFTEST PASS or FAIL lines; it needs a window (the headless runner does not deliver input to the GUI).

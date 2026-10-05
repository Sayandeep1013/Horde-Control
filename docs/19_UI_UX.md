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

## Tower Console UI — removed (decision D115, 2026-09-23)

The Tower Console (the second, priced, non-pausing upgrade interface this section used to define) is removed from runs entirely. Author decision D115 ("no in-run shop"): the Level-Up Draft is the only in-run power growth; Scrap converts to Cores at Run-End Settlement instead of being spent here (Provisional Values Register > "Meta: Run-End Settlement (prototype)"). Every rule this section used to state — the `console_open` lifecycle, the world-space panel and its placement, the purchase channel and sector-selection input, and the in-run Repair action — no longer exists. The `console_open`/`console_cycle_*`/`console_select_*`/`console_cancel` input actions are removed from the Input Map below. This section is kept, marked removed, rather than deleted, per this project's own convention for a superseded mechanic (compare the "Teaching Wave XP (C-XPCAP)" Register row, removed by D108 the same way).

---

## Settings

Review Decision Log D121 (MASTER_SDLC.md): the Settings screen (author brief:
"one option in settings to mute or lower the volume of music and other sound
effects ... and more quality settings if needed") is a vertical list of rows
— label on the left, "< value >" on the right — rather than sliders or a
single mute toggle. Provisional Values Register > "Interfaces" > "Settings"
row carries the defaults and the volume step; `src/core/game_settings.gd`
persists them at `user://settings.cfg`.

- **Rows, in order:** Master Volume, Music Volume, Sound Effects Volume
  (drives SFX, SFX_Priority, UI, and Ambience — see the Register row;
  TowerCue is reached only by sending through SFX_Priority, so it is not
  driven a second time, which would attenuate it twice), Mute All (mutes
  Master only), Display Mode (Windowed / Fullscreen / Borderless), V-Sync,
  Screen Shake, Damage Numbers, Movement-only controls, Back.
- **Volume steps:** 0–100% in 10% steps (Register > "Settings" row); 0%
  mutes that row's own bus (not merely a very quiet volume).
- **Change cadence:** only the three volume rows repeat while a direction is
  held, at the Register's own "Draft input" row cadence (reused, not
  restated, exactly like the Draft's own card-cycle — Upgrade Draft UI &
  Navigation, above). Every other row (Mute All, Display Mode, Screen Shake,
  Damage Numbers, Movement-only controls) changes ONCE per press and never
  auto-repeats, so holding a direction on a toggle cannot flicker it back and
  forth or skip past the Display Mode the player actually wanted.
- **Opening:** like every other paused menu, Settings opens with the
  Register's own "Draft input" row's 0.4 s input lockout (Platform Direction
  line 242; Author decision D3) during which no input is read at all, and
  always highlights the first row (Master Volume) — never wherever the
  highlight was left the previous time it was open.
- **Input, keyboard/gamepad:** once the lockout ends, Up/Down
  (`move_up`/`move_down`) move the highlighted row. Left/Right
  (`move_left`/`move_right`) change the highlighted row's value, applied and
  saved immediately (subject to the change-cadence rule above).
- **Back / leaving:** the `confirm` action's instant press closes the screen
  from the Back row; holding EITHER `move_left` or `move_right` for the
  Register's own hold-to-confirm duration while Back is highlighted also
  closes it (a movement-only player never needs a button at all) — the same
  neutral-return arming rule the Draft's own hold-to-confirm uses (Upgrade
  Draft UI & Navigation, above) applies here too, so a direction already
  held cannot auto-confirm it, whether held before the screen opened or
  before Back was reached.
- **Mouse:** hovering a row highlights it; clicking a row's own "<"/">"
  changes its value; clicking the Back row closes the screen immediately,
  with no hold required (matching every other paused menu's own mouse
  behaviour).
- **Platform input floor carve-out:** the Register's "Platform input floor"
  row (and Platform Direction line 242) states every paused menu "lays
  choices out horizontally." Settings is the one exception, named here
  rather than left as a silent contradiction: nine adjustable rows plus Back
  do not read as one legible horizontal row, and D121 chose the vertical
  list over shrinking the row count or overflowing a single bar — D121's own
  Review Decision Log row has the full reasoning for why this still honours
  Author decision D3.
- **Reachability:** the pause menu and the run-end screens (via
  `RunFlowController`, unchanged since P2.14), the title screen, and the Hub
  (War Camp) each open their own `SettingsMenu` instance, releasing keyboard
  focus from (and, on the Hub, hiding) whatever menu sits behind it so
  arrow/Enter input drives Settings, not the screen underneath; closing
  restores it. Esc (`ui_cancel`) closes Settings on the title screen and the
  Hub, the same way `pause` already closes it in-run. All four instances
  read and write the same `GameSettings` state, so a change from any one of
  them is visible from the others immediately.
- **Applied at boot:** `GameSettings.load_from_disk()` + `.apply()` run once,
  from the title screen's own `_ready()` (the game's `run/main_scene`),
  BEFORE the title music starts — see `src/core/game_settings.gd`'s header
  for why an Autoload's `_ready()` was rejected (it would run for every
  headless test in the suite, not only real launches).
- **Live during a run:** `src/audio/audio_ducking.gd`'s ramp reads Music and
  Sound Effects volume from `GameSettings` on every tick rather than a
  one-time snapshot, so a volume change made from pause → Settings → back
  takes effect immediately, even mid-duck.

---

## HUD

- **Player Health:** A health bar top-left showing the player's current health.
- **Tower Health:** A health bar top-centre, always on screen regardless of camera position, with the Tower's shield drawn as an overlaid segment on the health bar and the Tower's own "current/max" number beside it (D132); directly below it, as a separate ribbon that is a sibling of the Tower's frame, not nested inside it (D132), "Wave n/8" shows wave progress (teaching waves are shown as T1–T4 in the slice). Both the player and Tower health bars carry a tick mark at 40% of maximum and change border shape once health drops below it.
- **Scrap:** Top-right, showing current Scrap as "n/200"; a "FULL" badge appears at the cap, and the overflow hopper's amount is shown alongside it whenever the hopper is non-empty. A second line under it, drawn at body size in the bright text colour (D145), reads "~ n Cores at run end", the live Core equivalent of the carried Scrap at the Register's Scrap-per-Core rate (D132), so Scrap's only use is visible in the run.
- **XP:** A bar along the bottom of the screen showing XP progress together with the player's current level and the number of rerolls remaining. The level is shown as "Lv n" where n is the internal level plus one, so a fresh run reads "Lv 1" rather than "Level 0" (display offset only; the internal starting level is unchanged; D133). The "XP" caption is centred on the bar.
- **Run announcements (D129, D130):** Non-pausing, non-interactive text in a band under the top HUD (the wave banner first, the toasts below it, so neither covers the Tower at spawn; D145): a centred "Wave N" banner at every wave start, with a second "Siege incoming" banner when the wave holds a Siege (docs/11 > Siege warning: the first Seeker spawns 3 s after the wave opens); a one-line objective at run start ("Protect yourself and the Tower - survive n waves"); and, only until seen, three first-run hint toasts during wave 1 (the bow fires automatically; walk over crystals and gold to collect them; red torch goblins attack the Tower, yellow TNT goblins hunt you, purple barrels go for whichever is exposed). "Seen" is a `first_run_hints_seen` flag in the MetaProgress profile, set once all three have been shown; a profile without the key reads as not seen. Timings: Register > "Run announcements". They run on pausable time (D140): while the Draft or the pause menu is open they are hidden and their timers stand still, so the hints are never spent behind a menu.
- **Ground symbols (D131):** The XP crystal is drawn in the XP bar's purple so the pickup and the bar read as one thing; pickups bob 4 px; an attack telegraph is one danger colour for every enemy (enemy identity stays in the sprite) and its ground disc grows from nothing to the full ring as the wind-up reaches the strike moment.
- **Tower occlusion (D127):** The Tower and the player share one Y-sorted band, so a player standing north of the Tower is drawn behind it; while the player is inside the Tower sprite's on-screen rectangle the Tower fades to the Register's occlusion alpha and restores when the player leaves it.
- **Off-screen Tower indicator (D134):** The arrow always points at the Tower; below 40% health it turns the danger colour and the Tower icon gets a pulsing red ring (never a rhombus, which means XP only; D142), so the shape still changes without losing the direction. The arrow keeps its screen position between the top HUD and the bottom XP ribbon (Register > "Threat arrow margins").
- **Pause menu (D134):** The third choice reads "Abandon run" and asks again ("Abandon run? Progress so far still earns Cores": Keep playing / Abandon, Keep playing first) before the run is abandoned; closing the menu resets the question.
- **Text on parchment (D132):** Secondary text on parchment panels (Records, Achievements, Controls, Credits, Hub hint) uses a dark umber token (`TEXT_ON_PARCHMENT`) instead of the dim tan used on dark wood. Achievement rows show their reward ("Unlocks card: ..." or the perk) and an unlocked row's state is tinted.
- **Skill Tree nodes (D132):** Node names and prices are drawn at 20 / 18 px at the 1080 base; nodes are wider than tall; "can't afford" is a dimmed tablet with an amber price rather than red.
- **Menu cards (D127):** The Title and Hub menu cards are centred in a tall band so every button, including Quit, Settings and Back to Title, lies inside 1280 x 720 (a test asserts it).
- **Truncation:** Any HUD number may truncate with an ellipsis when space is tight, with the full value shown in a custom focus tooltip, per UI Layout & Dynamic Container Rules.
- **Camera and HUD bands (D141):** The camera may scroll past each arena wall by the HUD band (Register > "Camera HUD margin"), so a player standing at any wall is drawn clear of the top Tower pill and Wave ribbon, the bottom XP ribbon and the screen sides, never under them.
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

---

## Visual style: one pixel grid (D156-D165)

Everything on screen is Tiny Swords pixel art at the same grain: 1 art pixel is 1 screen pixel at 1920 x 1080, and nothing is rescaled or rotated. Numbers are in the Provisional Values Register ("Pixel type grid", "World texel scale", "Ground tile grid", "Draft card frame and ribbon", "HUD bar and pointer pixel style", "Project-made pixel art", "Shadows").

- **Filtering and scaling.** The default texture filter is Nearest. `window/stretch/mode` stays `canvas_items` (D163), so crispness at other sizes comes from the filter, the font and uniform scale, not from stretch mode.
- **Type.** Jersey 10 is imported with antialiasing, hinting and subpixel positioning off, and used only at its grid sizes: 19 (small, body), 37 (value, heading), 75 (title), 131 (logo).
- **World.** Every sprite is at scale 1.0. Ground, paths, ponds, plateaus and the coast are painted from the pack's tiles (scalloped 2 px ink edge); the bridge is the pack's vertical piece; shadows are the pack's blob.
- **Surfaces.** Draft cards sit on the pack's scroll (Player) or carved panel (Tower); rarity is a ribbon; selection is four corner pointers; HUD bars are square, ink-bordered pixel bars.
- **Glyphs.** Shape tokens (triangle, square, heart, tower, recycle, crystal, core, coin, arrow, boot, tent) are 32 px pixel icons tinted at draw time; `tools/art/make_pixel_icons.py` makes them, and also the "!" marker, the telegraph ring and the XP crystal. The shape-to-meaning table above is unchanged.

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

---

## Mobile (Android)

Decisions D146 and D147; numbers in the Provisional Values Register ("Touch controls", "Mobile UI scale", "Touch target minimum").

- **When it applies.** The touch controls show on a touchscreen device, on a mobile build, or with the `--touch-ui` user argument (`--no-touch-ui` forces them off). The mobile layout (compact screens, touch wording, hidden desktop rows) applies on a mobile build or with `--touch-ui`; a Windows laptop that merely has a touchscreen gets the joystick and keeps the desktop layout.
- **Movement.** A floating joystick appears where the thumb lands in the left half of the screen. It drives `move_left/right/up/down`, so the Draft's hold-up path and the movement-only controls work with it. The bow still fires on its own.
- **Pause.** A pause button sits at the top right, below the Scrap panel and clear of the three HUD panels. It sends the `pause` action; it hides while the Draft or the pause menu is up. Android Back does the same as Pause during a run, closes the open panel in the Hub, and leaves the app from the bare Title.
- **Everything is tappable.** Title, Hub, Settings (the < and > arrows and the Back row), Records, Achievements, the pause menu and its Abandon confirm, the Draft (tap a card picks that card; the Reroll pill is tappable) and the run-end buttons all work by tap. The Draft's hold ring and the menus' hold footers are the keyboard and gamepad way; on a phone the footers are hidden and the Draft says "Tap a card to pick it". In the Skill Tree, a finger pressed on a node selects it and holding buys it (the hold-to-buy fill); a finger held there stands in for the `confirm` action, which the engine's emulated mouse does not drive.
- **Hidden on a phone.** The Display mode and V-Sync rows. A phone window is always the whole screen.
- **Size.** The UI is scaled up to 1.5 (on 16:9 phones less, so the HUD's top row still fits), which makes the 22 px body text about 12 dp. Menu rows are at least 64 px and the Title / Hub / Back buttons 80 px (logical px). Title and Hub use compact layouts. Achievements scrolls by finger drag (the engine pans only on a device that reports a touchscreen). The Skill Tree board runs unscaled while open, so its node text is small; a Skill Tree design pass for phones is open work.
- **Limits.** 48 dp is 132 px of the 1080 canvas; seven menu rows of that height do not fit, so menu rows are about 38 dp. The pause button is about 51 dp.
- **Test aid.** `src/dev/touch_selftest.tscn` drives the real game with synthetic finger events and prints SELFTEST PASS or FAIL lines; it needs a window (the headless runner does not deliver input to the GUI).

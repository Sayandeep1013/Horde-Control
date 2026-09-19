# P2.6 Evidence Report — HUD and Threat Feedback

## GodotPrompter skills consulted

All five named skills were invoked via the Skill tool. Read in full:

- **`godot-prompter:hud-system`** — CanvasLayer HUD architecture, health-bar binding pattern, mouse-filter guidance.
- **`godot-prompter:godot-ui`** — Control hierarchy, container sizing, anchor/offset math, theme conventions.
- **`godot-prompter:responsive-ui`** — stretch mode / aspect ratio guidance, multi-resolution testing.
- **`godot-prompter:godot-testing`** — GUT/gdUnit4 conventions, naming, `auto_free()`, what not to test.
- **`godot-prompter:audio-system`** — bus architecture, `AudioStreamPlayer` vs positional players, WAV/OGG guidance.

**Two conflicts found, recorded here for the phase LEDGER** (CLAUDE.md: "Where a skill conflicts with … this project wins and the conflict is recorded in the phase LEDGER"). Neither is in `LEDGER.md` yet because that file is outside this task's write scope; both are listed here for the orchestrator to copy in, matching how F03-08 reached the ledger.

1. **`hud-system` prescribes binding a health bar to its source's `_changed` signal and never polling in `_process`** ("Health bar binds to `HealthComponent.health_changed` signal — does not poll in `_process`"). `src/ui/hud.gd` instead polls every frame (`_process()` → `_refresh_all()`). This is a deliberate, reasoned choice, not an oversight: (a) `docs/20_Technical_Architecture.md` > "Communication, queries" states the opposite house rule for exactly this shape of consumer — "Read-only queries do not go through signals. Each state owner exposes a typed query interface … A signal emitted every tick to broadcast state is an anti-pattern and is banned" — framing a HUD reading already-public state every frame as the sanctioned query pattern, not an anti-pattern; (b) two of the four fields (Scrap, XP/level/rerolls/Wave) have **no signal source at all** yet — `HudEconomyState` is a plain data holder, by design, because no Economy or Wave Director system exists to emit one (see "Cross-task seams" below) — so a fully signal-driven HUD is not achievable today regardless of what the other two fields could support; a mixed signal-for-two/poll-for-two design was judged not worth the inconsistency for a handful of label/bar updates at 60 Hz. Project wins, per CLAUDE.md, and this is the same pattern LEDGER F03-11 already names: "the skills are consistently right about generic Godot idiom and wrong about this project's own architecture."
2. **`responsive-ui` recommends `aspect = expand` as the general-purpose default**, reserving `keep` for "fixed-layout content requires it." This project's `project.godot` already pins `display/window/stretch/aspect = "keep"` (docs/20 > Godot 4.x Implementation Standards > "Project Settings (pinned)": "aspect `keep` … so the game letterboxes rather than stretches"), set before this task and outside this task's write scope (`project.godot` is explicitly forbidden). Nothing in this task's own layout code depends on which aspect mode is active — the acceptance test (below) asserts the pinned value is still `keep`, not that it should be — but the skill's own general recommendation and the project's binding pin disagree, so it is recorded rather than silently followed or silently ignored.

No conflict found with `godot-testing`'s naming convention beyond the one this phase already carries (F03-08, `*_test.gd` suffix vs. the skill's `test_*` prefix) — this task's five new suites follow the project's suffix convention, per this task's own brief, reinforcing rather than duplicating that finding. No conflict found with `audio-system`: its guidance (non-positional `AudioStreamPlayer` for global cues, WAV for short SFX, bus-based routing) matches what P1.6 already built and what this task's placeholder cue reuses.

## Files written (all within this task's write scope)

| Path | Purpose |
| --- | --- |
| `src/ui/hud.gd` | `Hud` (`CanvasLayer`): builds the four HUD fields in code, polls Player/Tower/`HudEconomyState`, exposes typed getters |
| `src/ui/hud_bar.gd` | `HudBar`: the shared custom-drawn bar widget (player health, Tower health + shield overlay, XP) — tick mark, border-shape rule |
| `src/ui/hud_truncatable_label.gd` | `HudTruncatableLabel`: the one ellipsis-plus-tooltip HUD field (Scrap) |
| `src/ui/hud_economy_state.gd` | `HudEconomyState`: the read-interface seam for Scrap/XP/level/rerolls/Wave (no owning system yet) |
| `src/ui/threat_feedback.gd` | `ThreatFeedback` (`Control`): 8-segment vignette, off-screen Tower indicator, Tower-cue wiring |
| `scenes/ui/hud.tscn` | Trivial wrapper: a bare `CanvasLayer` with `hud.gd` attached — the real tree is built in code (see `hud.gd`'s own header for why, mirroring `game_camera.gd`'s vignette) |
| `scenes/ui/threat_feedback.tscn` | `CanvasLayer` (layer 11) containing one full-rect `Control` with `threat_feedback.gd` attached |
| `tests/unit/tower_cue_audibility_test.gd` | **Named acceptance test** (P2.6): bus routing, pan formula, retrigger limit, ducking, HUD-in-viewport, pseudo-loc survival |
| `tests/unit/hud_layout_test.gd` | HUD field wiring, the 40% tick/border-shape rule for both health bars |
| `tests/unit/hud_economy_display_test.gd` | `HudEconomyState` → label/bar text and visibility |
| `tests/unit/threat_feedback_vignette_test.gd` | Damage window, fade curve, on/off-screen pointing rule |
| `tests/unit/threat_feedback_indicator_test.gd` | Off-screen indicator shape/colour change, hit arc |
| `phases/PHASE_03_Core_Entities_And_Feel_Check/evidence/p26_report.md` | This report |

Nothing else was written or modified. Confirmed by `git status --short -- src/ui scenes/ui tests/unit/*` immediately before finishing: only the paths above (plus their auto-generated `.uid` sidecars from the import pass) appear. `src/audio/`, `src/tower/`, `src/player/`, `src/combat/`, `src/core/`, `scenes/main.tscn`, `scenes/player.tscn`, `scenes/tower.tscn`, `project.godot`, and `phases/PHASE_03_Core_Entities_And_Feel_Check/LEDGER.md` were all read but never written. No `mcp__godot-comprehensive__*` or `mcp__godot-coding-solo__*` tool was called; every Godot invocation ran through Bash/PowerShell against the pinned console executable.

**Two other implementers' in-flight work shares this working tree** (P2.3 weapon/projectile, P2.5 enemy AI — `src/combat/auto_weapon.gd`, `src/combat/player_projectile.gd`, `src/enemy/*`, `data/enemies/*`, `data/weapons/*`, and their test suites, all untracked and unrelated to this task, confirmed via `git status --short`). Their files changed on disk more than once during this session; see "The `run_tests.ps1` result" below for how that shows up in the whole-project run and why it is not this task's failure to fix.

## Scene trees built (in code; see each file's own header for why)

```
Hud (CanvasLayer, layer 10, hud.gd)
└── Root (VBoxContainer, full rect)
    ├── TopMargin (MarginContainer, 16px left/top/right)
    │   └── TopRow (HBoxContainer)
    │       ├── PlayerHealthField (MarginContainer)
    │       │   └── PlayerHealthBar (HudBar, tick+border rule on)
    │       ├── TowerCenter (CenterContainer, SIZE_EXPAND_FILL)
    │       │   └── TowerHealthField (VBoxContainer)
    │       │       ├── TowerHealthBar (HudBar, tick+border+shield-segment on)
    │       │       └── WaveLabel (Label, autowrap+expand)
    │       └── ScrapField (HBoxContainer, MOUSE_FILTER_PASS)
    │           ├── ScrapValueLabel (HudTruncatableLabel — ellipsis + custom tooltip)
    │           ├── FullBadgeLabel (Label, autowrap+expand, visible only at cap)
    │           └── HopperLabel (Label, autowrap+expand, visible only when non-empty)
    ├── MiddleSpacer (Control, SIZE_EXPAND_FILL — pushes the bottom row down)
    └── BottomMargin (MarginContainer, 16px bottom)
        └── BottomCenter (CenterContainer)
            └── XpField (VBoxContainer)
                ├── XpBar (HudBar)
                └── XpInfoRow (HBoxContainer)
                    ├── LevelLabel (Label, autowrap+expand)
                    └── RerollsLabel (Label, autowrap+expand)

ThreatFeedbackLayer (CanvasLayer, layer 11)
└── Overlay (Control, full rect, threat_feedback.gd)
    ├── TowerCuePlayer (TowerCuePlayer — P1.6 class, reused not reimplemented)
    └── AudioDucking (AudioDucking — P1.6 class, reused not reimplemented; private default, see "Cross-task seams")
```

## Every Register/docs citation, and where it is enforced

| Source | Rule | Enforced in |
| --- | --- | --- |
| docs/19 > HUD | Player health top-left; Tower health top-centre with shield overlay + "Wave n/8" below; Scrap top-right "n/200" + FULL badge + hopper; XP bar bottom with level + rerolls | `hud.gd::_build_ui()` and its three `_build_*_field()` helpers |
| Register > Interfaces > "HUD" | "both bars tick at 40% of maximum and change border shape below it" | `hud_bar.gd::TICK_FRACTION`, `is_below_tick()`, `get_border_width()`/`get_border_corner_radius()` |
| Register > Economy & Pickups > "Scrap" | "Cap 200"; hopper shown only when non-empty; prototype has no hopper | `hud_economy_state.gd::SCRAP_CAP_DEFAULT`; `hud.gd::_refresh_scrap()` |
| Register > Progression & Upgrades > "Level-Up Draft" | "Reroll 1 per run (prototype)" | `hud_economy_state.gd::REROLLS_DEFAULT` |
| docs/19 > UI Layout & Dynamic Container Rules | autowrap + `SIZE_EXPAND_FILL` for growing fields; `custom_minimum_size`, never a fixed `size`; ellipsis + custom focus tooltip for the one tight field; F2 pseudo-loc at 0.3 | `hud.gd`'s label construction; `hud_truncatable_label.gd` in full |
| MASTER_SDLC.md > Visual Edge Cases > "Colour-only distinctions" | shape (not colour alone) carries low-health/low-Tower-health state | `hud_bar.gd`'s border-shape switch; `threat_feedback.gd::get_indicator_shape()`/`get_indicator_color()` |
| MASTER_SDLC.md > Directional Threat Feedback | 8 edge segments; 1 s damage window; 0.6 s fade; points at Tower off-screen / attacker on-screen; off-screen indicator shape+colour+arc below 40% Tower health | `threat_feedback.gd` in full |
| docs/20 > Audio Mixing & Dynamic Ducking > "Tower Cue Player" (C-TOWERCUE) | own `AudioStreamPlayer` → `TowerCue` bus → `SFX_Priority`; pan `clamp((tower_x−player_x)/960,−1,1)`; 250 ms retrigger | `threat_feedback.gd::_play_tower_cue()`, reusing `src/audio/tower_cue_player.gd` unmodified |
| Register > Readability | `z_index`/draw-order intent extended to CanvasLayer ordering | `hud.gd::HUD_CANVAS_LAYER` (10) and `threat_feedback.gd`'s scene (layer 11), both above `game_camera.gd`'s vignette (layer 4) |

One escalated constant (no Register row): `ThreatFeedback.DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH = 0.15 # NO REGISTER ROW — escalated` — see "Escalations."

## The named acceptance test: Tower cue audibility check (P2.6)

`tests/unit/tower_cue_audibility_test.gd`, 11 test cases, covering every clause the Acceptance Test Matrix and this task's own extended brief name:

1. **Bus routing** — `TowerCue → SFX_Priority → Master`, `AudioEffectPanner` present on `TowerCue` only; the cue player is a non-positional `AudioStreamPlayer` (never attenuates with distance).
2. **Pan formula** — driven through this task's own wiring (a real `Hurtbox.receive_hit()` → `ThreatFeedback` → the real `TowerCuePlayer` → the real bus panner), for a Tower far right, far left, and at an unclamped offset (480 px → pan 0.5).
3. **250 ms retrigger limit** — a low-level rapid-burst test (six attempts inside the window all blocked, one past it succeeds) and a second test wired through real Tower-damage events with an injected `SimClock`.
4. **Audibility over concurrent SFX** — triggering the cue calls `AudioDucking.notify_priority_started()`; stepping the ramp 50 ms (the Register's own attack time) shows SFX, Ambience, and Music all ducked, while `SFX_Priority`'s own bus volume is read before/after and found unchanged.
5. **HUD at 1080p** — pinned `viewport_width`/`height`/`stretch/mode`/`stretch/aspect` project settings asserted directly; the four fields' `get_global_rect()` confirmed inside `Rect2(0,0,1920,1080)` inside a dedicated `SubViewport` sized exactly to that reference resolution.
6. **Pseudo-localization survival** — `TranslationServer.set_pseudolocalization_enabled(true)` at ratio 0.3 (the same mechanism `src/debug/overlay.gd`'s F2 toggle already uses); the Scrap label is confirmed to be the one ellipsis+tooltip field with its full value recoverable via `tooltip_text`; every other label is confirmed configured to grow (`OVERRUN_NO_TRIMMING` + autowrap on, never `AUTOWRAP_OFF`) rather than trim; all four fields re-checked inside the viewport after the expansion.

Command and result:

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/tower_cue_audibility_test.gd
```
`PASS (exit 0): 11 test case(s) executed under res://tests/unit/tower_cue_audibility_test.gd, all passed.` No `ENGINE ERRORS:` line.

### Falsification (rule 9), with an ownership boundary stated up front

`src/audio/tower_cue_player.gd`, `src/audio/audio_ducking.gd`, `src/audio/cue_retrigger_limiter.gd`, and `default_bus_layout.tres` are **P1.6 deliverables outside this task's write scope**. Rule 9 ("mutate the real source, never the test") and rule 5 ("modify only your write scope") both apply and are followed together: every mutation below targets **this task's own code**, never the P1.6 files. The bus-routing and retrigger-limit sub-checks re-verify a mechanism P1.6 already built and already falsified in its own suites (`tests/unit/audio/test_tower_cue_player.gd`, `tests/unit/audio/test_bus_layout.gd`); this task does not repeat that class's own falsification, only its own wiring's.

Four mutations, each: mutate → run the acceptance suite → confirm the expected failure → restore from a pre-mutation backup → `diff` confirms byte-identical restoration → re-run green.

1. **Swapped `tower_x`/`player_x` in `threat_feedback.gd::_play_tower_cue()`.** `test_pan_matches_formula_for_tower_far_to_the_right` **FAILED** (expected pan ≈ 1.0, got ≈ −1.0). Restored; `diff` clean; suite re-ran **11/11 green**.
2. **Removed the `_cue_player.ducking_node = _ducking_node` hookup in `threat_feedback.gd::_ready()`.** `test_cue_triggers_ducking_on_sfx_and_ambience_but_not_sfx_priority` **FAILED** (4 failures — SFX/Ambience/Music never ducked). Restored; `diff` clean; suite re-ran **11/11 green** (this run also incidentally re-confirmed mutation 1's own test independently, since gdUnit4 runs every earlier test in the file before reaching the mutated one).
3. **Disabled ellipsis trimming in `hud_truncatable_label.gd::_ready()`** (`OVERRUN_TRIM_ELLIPSIS` → `OVERRUN_NO_TRIMMING`). `test_hud_layout_survives_pseudolocalization_without_silent_truncation` **FAILED**. Restored; `diff` clean; suite re-ran **11/11 green**.
4. **Oversized the player health bar's `custom_minimum_size` to `Vector2(5000, 24)` in `hud.gd::_build_player_health_field()`.** `test_four_hud_fields_lay_out_within_the_pinned_viewport` **FAILED** — all four fields reported out of bounds, not only the mutated one (the oversized left field pushed the centred Tower field and the right-aligned Scrap field off-screen too, which the test caught for all three). Restored; `diff` clean; suite re-ran **11/11 green**.

### A defect this falsification work found and fixed before reporting

While preparing mutation 4, the pre-mutation baseline run of `test_four_hud_fields_lay_out_within_the_pinned_viewport` was **already failing** — a real bug, not a mutation artifact. `hud.gd`'s bottom region (`BottomMargin`, holding the XP field) was a raw-anchored `MarginContainer` (`PRESET_BOTTOM_WIDE`) parented directly under a plain `Control` root. Godot only grows such a container to fit its children's minimum size via `grow_vertical`/`grow_horizontal` *after* a layout pass has already measured them; calling `set_anchors_preset()` on a still-empty, not-yet-in-tree node (as the original code did) froze a zero-height offset that never widened back out once children were added, so the XP field ended up pinned at `y = 1080` (flush with the bottom edge, extending downward, fully off-screen) instead of growing upward from it. The three TOP fields happened to pass because their region's growth direction (downward from `y = 0`) matched the frozen offset by coincidence; only the BOTTOM region's growth direction (upward) was wrong. **Fixed** by rebuilding `Root` as a `VBoxContainer` with an `SIZE_EXPAND_FILL` spacer `Control` between the top row and the bottom row — ordinary Container arrangement (a genuine parent-container relationship, which does auto-fit child minimum sizes on every layout pass) replaces the raw anchor/offset math entirely. Both `hud.gd`'s own header and this report name the fix; `test_four_hud_fields_lay_out_within_the_pinned_viewport` passed both before and after the four intentional mutations once this was fixed, and the fix itself was never what any of the four falsification mutations targeted (all four still reproduce their own distinct failures against the corrected baseline, as shown above).

## The `run_tests.ps1` result

Each of this task's five suites was run individually (clean, uncontaminated by the other two implementers' concurrently-changing files) and as part of the whole project:

```
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/tower_cue_audibility_test.gd        → PASS (exit 0), 11/11, no ENGINE ERRORS
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/hud_layout_test.gd                  → PASS (exit 0), 7/7,  no ENGINE ERRORS
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/hud_economy_display_test.gd         → PASS (exit 0), 5/5,  no ENGINE ERRORS
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/threat_feedback_vignette_test.gd    → PASS (exit 0), 7/7,  no ENGINE ERRORS
powershell -NoProfile -File tests/run_tests.ps1 -TestPath res://tests/unit/threat_feedback_indicator_test.gd   → PASS (exit 0), 5/5,  no ENGINE ERRORS
```

**Whole-project run** (`-TestPath res://tests/unit`, 44 suites, 315 test cases): **exit 100.** Every one of this task's own 35 test cases passed in this run too. The failures belong entirely to the two other implementers' in-flight, untracked files sharing this working tree, confirmed by `git status --short`:

- `enemy_tag_registration_test.gd`, `leash_test.gd`, `opportunist_test.gd`, `stuck_exemption_test.gd` — all exercise `src/enemy/*` (P2.5, untracked).
- The engine-error guard fired: **9 `SCRIPT ERROR` lines**, all `Invalid type in function 'release_claim' … (previously freed) is not a subclass of the expected argument class` — traced to `src/enemy/attack_slot_manager.gd`/`src/enemy/enemy_controller.gd` (both P2.5, untracked; `grep -rln "release_claim" src/` finds the symbol nowhere else).
- `player_projectile_test.gd` (P2.3, untracked) failed once mid-session and passed on every other run in this session — recorded as observed, not diagnosed, per this project's rule about untested causes; it is not this task's file either way.

None of the above touches `src/ui/`, `scenes/ui/`, or any file this task wrote. The engine-error guard's finding is real and worth carrying forward, but it is not this task's defect to fix — `src/enemy/` is outside this task's write scope, and both files are still being written by a parallel implementer as of this report.

The banned-API check: `bash tools/checks/banned_api_check.sh` → `Banned-API check: PASS (0 banned calls under src scenes, excluding ui/ directories)`, exit 0, run directly (not piped into a pager, per this task's own rule 7).

## Escalations (rule 6: no invented numbers)

1. **`ThreatFeedback.DAMAGE_TO_FULL_INTENSITY_FRACTION_OF_MAX_HEALTH = 0.15` — `# NO REGISTER ROW — escalated`.** The Register states the vignette's intensity "follows the damage taken in the last 1 s" but names no number for how much damage within that window reads as FULL (1.0) intensity. 15% of Tower max health (75 HP against the current 500 HP Tower) in one second is this task's own placeholder, chosen to be low enough that a single Seeker hit registers visibly without needing a full swarm volley. Needs the author's confirmation or a real value before the vertical slice.
2. **`ThreatFeedback.HIT_ARC_DISPLAY_SECONDS = FADE_SECONDS` (0.6 s), reused rather than invented separately.** No Register row times how long the off-screen indicator's "short arc on the side of the Tower currently being hit" itself stays visible after a hit. Reusing the vignette's own Register-backed 0.6 s fade figure was judged the better default than picking a second unstated number for a closely related "how long does a damage indication linger" question — named here as a reuse, not presented as if the Register stated it directly.
3. **The placeholder Tower-damage cue audio itself.** No audio asset of any kind exists anywhere in this repository (confirmed by search before writing `threat_feedback.gd`). `_build_placeholder_cue_stream()` generates a short procedural 220 Hz decaying tone purely so `TowerCuePlayer.play_tower_damage()` has a real, non-null stream to exercise routing/pan/retrigger/ducking — this is a mechanism placeholder, not sound design, consistent with LEDGER F02-03's five audio under-specifications already awaiting the author.

## Cross-task seams (named, not crossed)

**Seam 1 — EventBus signals this HUD/ThreatFeedback would use if they existed.** `src/core/event_bus.gd` declares only `enemy_died`, `tower_damaged`, `draft_opened`, and is outside this task's write scope. The signals this task actually needed and does not have:

- `player_damaged(amount, new_health, source)` / `player_died()` — would let the HUD react to Player state by event instead of polling `Player.death_state.current_hp`/`max_hp` every frame. Not usable via `enemy_died` today regardless, since LEDGER F03-06 already records that signal firing for the player's own death too.
- `scrap_changed(current, cap, hopper_amount)`, `xp_changed(current, required, level)`, `rerolls_changed(remaining)`, `wave_changed(current, total)` — would let `HudEconomyState` be driven by signal instead of direct field mutation once Economy (Phase 05) and the Wave Director (Phase 04) exist.
- A richer `tower_damaged` that also carried the attacker's position — `ThreatFeedback` works around the current signal's silence on this by connecting directly to the Tower's own `Hurtbox.damage_received(amount, source, hitbox)` instead (see `threat_feedback.gd`'s header, "The attacker-position seam").

**Seam 2 — the economy/wave read interface.** `src/ui/hud_economy_state.gd` (`HudEconomyState`) is a plain typed data holder with no owning system. Scrap, XP, level, rerolls, and the wave counter are Phase 05 (Economy) and Phase 04 (Wave Director) work respectively; this task built the HUD against that interface rather than inventing an economy. A future system either mutates an instance of this class directly (the HUD polls it every frame already) or a subclass can add its own update logic without `hud.gd` changing at all.

**Seam 3 — wiring into `scenes/main.tscn`.** Neither `scenes/ui/hud.tscn` nor `scenes/ui/threat_feedback.tscn` is instanced under the shared gameplay root; `Hud.set_player_ref()`/`set_tower_ref()` and `ThreatFeedback.set_player_ref()`/`set_tower_ref()`/`set_camera_ref()` are the typed commands the integration task calls once real `Player`/`Tower`/`GameCamera` instances exist there. This matches every other P2.x task's own standalone scene in this phase (`tower.tscn`, `player.tscn`, `arena.tscn` are all likewise unwired).

**Seam 4 — the shared `AudioDucking` node.** `ThreatFeedback._ready()` creates its own private `AudioDucking` + `TowerCuePlayer` pair so the cue mechanism works standalone with zero integration steps. If a single global `AudioDucking` node is later established for the whole game (so `AudioPool`'s own priority voices duck against the *same* ramp as this cue, rather than two independent ramps racing each other), the integration task should call `ThreatFeedback.set_ducking_node_ref()` instead of leaving the private default in place.

## Interpretations named, not silently assumed

1. **"Top-centre" for the Tower field** is read as centred within the space remaining between the other two top-row fields (via an `HBoxContainer`'s natural-fixed/expand-fill/natural-fixed layout), not centred on the literal screen midpoint. This recentres automatically as content grows (e.g. under pseudo-localization); a one-time computed anchor offset would not. At 1920×1080 with this task's field sizes the difference from true screen-centre is not visible.
2. **The pointing rule's on-screen-but-no-known-attacker fallback**: if the Tower is on-screen and no attacker position has ever been recorded (or the last one has aged out), `ThreatFeedback.get_pointing_direction()` returns `Vector2.ZERO` (no indicator drawn) rather than falling back to pointing at the Tower itself — the Register only defines "at the attacker when on-screen," and there is nothing to point at yet in that state.
3. **Shield-vs-health scaling on the Tower bar**: the shield segment is drawn to the same width scale as the health fill (against health's own max, not the shield's own max), so "shield = 25% of Tower max health" reads as one quarter of the same bar length health uses — matching "overlaid … on the health bar" as literally as possible.
4. **Damage that lands on the Tower always raises vignette intensity**, regardless of whether the shield or health pool ultimately absorbs it, because `ThreatFeedback` listens to the Tower's `Hurtbox.damage_received` signal directly — upstream of `TowerHealth`'s own shield/health split. This is what makes "triggered by shield and health damage" true by construction rather than by two separate code paths that could drift apart; `test_shield_damage_and_health_damage_both_raise_intensity` proves it end to end.

## Never stated as passed, satisfied, or ready

Every check above is reported as "N test cases, 0 errors, 0 failures, exit 0" (or, for the whole-project run, an honest exit 100 with the failures attributed to named files outside this task's scope) and every Register citation is reported as "enforced in," not "satisfied." This report does not assert that the Tower cue audibility check, the HUD, the threat feedback, or any project gate is passed, satisfied, or ready — that determination belongs to the reviewers and the author.

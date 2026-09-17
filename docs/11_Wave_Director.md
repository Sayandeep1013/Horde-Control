# 11 - Wave Director

**Version:** 0.2.0 (draft; becomes a working document at 0.5.0 under the master's Document Control)  
**Status:** Working system document. Its sections were moved, with ledger FIX edits applied, from MASTER_SDLC.md 0.7.0 on 2026-09-14 so the master keeps intent, rules, gates, and the Provisional Values Register while implementation detail lives here.  
**Authority:** Binding for the Minimum Playable Prototype under the master's Provisional Defaults Policy. The master wins on intent; the master's Provisional Values Register wins on any numeric conflict.

---

## Wave Runtime Model

A biome runs 8 combat waves: a Mini-Boss Checkpoint boss wave follows combat wave 4, and the Biome Boss boss wave follows combat wave 8. A run's first biome opens with teaching waves T1–T4 before combat wave 1, which are not counted among the 8 combat waves. The prototype covers T1–T4 followed by combat waves 1–4 only, with no boss waves, and is referred to throughout as "eight waves."

A wave runs an ordered sequence of encounters. In the prototype and the vertical slice, every combat wave has exactly one encounter; a boss wave consists only of its boss encounter, has no maximum duration and no Overtime, and its Boss Definition resource states what spawning it suppresses. Boss duration targets are 60 seconds for a Mini-Boss and 120 seconds for a Biome Boss.

An encounter's spawns are ordered **spawn groups**, each `{enemy definition (Enemy ID), count (int), start offset (float s from encounter open), spawn interval (float s between individual spawns), direction weighting override (nullable)}` (Contract Field Semantics). A spawn group starts at its start offset or earlier if the Escalation Trigger starts it; groups with equal offsets run concurrently. In a Siege the Escalation Trigger does nothing. A lane split assigns ceil(0.6 × n) spawns to the heavier lane, alternating by spawn index. A wave's spawn budget is derived — the sum of its groups' cap weights — not authored.

An encounter completes when all its groups have emitted and every enemy it spawned is dead or removed; this is the explicit objective for Standard Assault, Split Assault, Siege, and Hunt, and these four carry no reward of their own. When an encounter completes, no encounter opens until that encounter's recovery gap has elapsed. When two encounters are due at the same moment, the higher-priority one opens and the lower-priority one waits until the higher-priority one completes plus its recovery gap.

Teaching waves T1–T4 end at their maximum duration or when every enemy they own is dead, whichever comes first. They never run the stall rule, Overtime, or escalation: their spawn groups start at their listed start offsets. Survivors carry over as for combat waves.

A non-final combat wave ends when its last encounter completes, or at its maximum duration under the stall rule. At a non-final combat wave's maximum duration the stall check runs once: if kills in the last 30 seconds, not counting finishers, are below the stall threshold (5), Overtime starts and the wave continues until every non-finisher enemy it owns is dead, then remaining finishers despawn without drops; otherwise the wave ends and its living enemies carry over, counting against the enemy cap but not the next wave's spawn budget.

During Overtime no further spawn groups start. Finishers count against the 300 enemy cap and throttle like any spawn; the enemy cap is never exceeded. Finishers: Player Hunters at 25% Hunter health, 160% Hunter speed, 2 per 5 s on the view ring, exempt from de-escalation, no leash timer, the finisher flag survives any conversion, drop 1 XP and no Scrap.

The final combat wave adopts every living enemy when it opens. It ends only when the EntityRegistry live-enemy count is zero. After its maximum duration the stall check re-runs every 0.5 seconds until Overtime starts. Run success is that wave ending with both pools above zero.

The gap after a wave is `max(inter-wave gap, last encounter's recovery gap)`; the inter-wave gap is 8 seconds, or 5 seconds after T1, T2, or T3. No spawn group starts during a gap. For 1.5 seconds after a Level-Up Draft closes, no encounter opens and no spawn group starts. Only Wave Director deadlines (spawn-group start offsets, the next emission of an emitting group, inter-wave gaps, recovery gaps) extend by 1.5 seconds; every other gameplay deadline runs normally.

Wave and encounter completion is always driven by EntityRegistry tag queries against actual live entities, never by a counter that could desynchronise from them. An encounter may also declare its own alive cap (for example 120 in the heavy Siege of combat wave 4), which counts all living enemies, not just its own spawns, and throttles spawning exactly like the global entity cap.

Encounter priorities and recovery gaps: Siege 80 (10 s), Split Assault 60 (8 s), Hunt 40 (8 s), Standard Assault 20 (5 s). Deferral between two encounters due at the same moment follows the rule stated above under encounter completion.

---

## Encounter Budgets for the Prototype

Group start times below are start offsets from encounter open (Wave Runtime Model); the Escalation Trigger may start a later group earlier. Siege counts for combat waves 2 and 4 are recomputed at Siege open by the Siege volume formula below.

| Wave | Encounter Type | Spawn Groups | Maximum Duration |
| --- | --- | --- | --- |
| T1 | Standard Assault (Hunters only) | Hunters 4 @0 s, 4 @6 s, 4 @12 s; interval 0.5 s | 20 s |
| T2 | Standard Assault (with Seekers) | Hunters 4 @0 s interval 0.5 s; Seekers 5 @0 s interval 1.0 s; Hunters 4 @10 s interval 0.5 s | 25 s |
| T3 | Split Assault (light) | Seekers 8 @0 s interval 1.25 s (5 heavy / 3 light); Opportunists 4 @10 s interval 1.0 s (3 heavy / 1 light) | 30 s |
| T4 | Siege (teaching) | Seekers 12 @3 s interval 2.0 s (starting estimate; tuned in P2.14); Hunters 2 @10 s interval 0.5 s; exempt from the volume formula below | 40 s |
| Combat wave 1 | Hunt | Hunters 5 @0 s, 5 @15 s, 6 @30 s interval 0.5 s; Opportunists 4 @45 s interval 0.5 s | 90 s |
| Combat wave 2 | Siege ×1.5 | Seekers 43 @3 s interval 1.57 s; Hunters 7 @0 s interval 9.6 s | 90 s |
| Combat wave 3 | Split Assault | Seekers 14 @0 s interval 1.5 s (9 heavy / 5 light); Opportunists 6 @20 s interval 1.0 s (4 heavy / 2 light) | 90 s |
| Combat wave 4 (final) | Siege ×2.0 (heavy) | Seekers 57 @3 s interval 1.18 s; Hunters 9 @0 s interval 7.5 s; encounter alive cap 120 counts all living enemies | 90 s, never ends on time |

- **Standard Assault outside onboarding:** 16 enemies — Hunters 4 @0 s interval 0.5 s, Seekers 6 @0 s interval 1.0 s, Hunters 3 @16 s interval 0.5 s, Opportunists 3 @24 s interval 0.5 s. The Tower alone clears its Seekers (360 HP) in about 14.4 seconds, inside 60% of the 90 second wave maximum.
- **Siege volume formula:** Seeker count = `ceil(multiplier × Tower DPS at Siege open (upgrades counted) × 0.75 × wave maximum duration ÷ 60)`, spawned evenly over the first 75% of the wave. At the base Tower's 25 DPS over a 90 second wave: ×1.5 gives 43 Seekers (+7 Hunters); ×2.0 gives 57 Seekers (+9 Hunters). Hunters = `round(0.15 × Seeker count at Siege open)`, spawned evenly over the first 75% of the wave. The vertical slice adds at least one ranged Tower Seeker that outranges the Tower to every Siege.
- **Siege warning:** the Tower's off-screen indicator pulses with a priority audio cue 3 seconds before the first Seeker spawns.
- **T4 tuning target:** a no-player run — a scripted T4-only scenario that starts T4 directly with the player absent — loses the Tower (destroyed) before T4 ends in at least 3 of 5 seeds, and a player who reaches within 480 px of the Tower within 10 s of the warning keeps it above 50%. Failing the first Siege is acceptable and intended. T4 is exempt from the volume formula but, like every Siege, is not winnable by the Tower alone.
- Every combat wave after T1 contains at least one Tower Seeker or Opportunist, and each biome contains at least one Hunt, one Siege, and one Split Assault.

---

## Spawn Rings & Placement

Enemies do not spawn directly on the player or the Tower, and never inside geometry.

- **Two rings:** the **Tower ring** (Tower-centred) spawns Tower Seekers; the **view ring** (camera-centred) spawns Player Hunters, Opportunists, and Overtime finishers. Both share the same Provisional Default geometry: inner radius equals the half-diagonal of the largest camera view (view scale 1.15 gives 2208 by 1242 pixels, half-diagonal about 1267 pixels) plus 64 pixels, so about 1331 pixels; ring width 128 pixels, so the outer radius is about 1459 pixels; the ring is clipped to the arena inset by 32 pixels (2368 px east and west, 1568 px north and south in the 4800 by 3200 arena), so the whole ring fits inside the prototype arena. A Tower-centred ring is what makes "evenly around the Tower" possible for a Siege and keeps spawn placement independent of camera zoom.
- **Camera exclusion:** a candidate spawn point inside the player's current camera view plus a 64 pixel margin, or inside the Tower Interaction Radius, is rejected. Enemies therefore spawn off-screen and are seen in transit. A spawn marker appears 0.75 seconds before its spawn; the position is rolled and validated when the marker appears and re-validated at spawn — one marker per spawn group per 30° sector, counted as a single telegraph — so the player can read the direction before the enemy arrives. Because the largest camera view (2208 pixels wide) is narrower than the ring's inner diameter (about 2660 pixels), some arc of the ring is always outside the view. Ambush, Pincer, and Breach (vertical slice and later) are declared **on-screen spawn exceptions** and use telegraphed markers of at least 1.0 second instead, at or beyond the on-screen spawn minimum distance (min(2 seconds of player travel, 0.8 × the view's half-height)); Breach's warning is 15 seconds.
- **Validation:** an invalid candidate point is shifted along its ring in alternating directions, up to eight steps of 10 degrees; if none is valid, the spawn is re-queued for the next tick and its budget goes unused rather than being forced. The 8-failed-tick counter is per spawn: after eight consecutive ticks of failed validation for that spawn, direction weighting is ignored and the nearest valid point on the ring is taken instead; if that ring has no valid point at all, the other ring is used. The view-ring arc used for a spawn is clipped to the part of the ring inside the arena inset; if less than 30° remains, the arc re-centres on the nearest in-arena bearing.

---

## Directional Weighting

- **Standard Assault:** uniform across each ring.
- **Split Assault:** Lanes are fixed when the encounter opens. Each lane is a 40° sector of the Tower ring. Prototype lane centres are 180° apart; from the vertical slice, separation = max(120°, the angle whose arc at the Tower's 480 px weapon range the player covers in 6 seconds at maximum speed with upgrades). Spawn validation shifts stay inside the lane's sector; a spawn with no valid point waits with its budget unused. Each lane-split group assigns ceil(0.6 × n) spawns to the heavier lane (asymmetry at least 60:40); Opportunists split the same way across the view ring.
- **Siege:** uniform around the Tower ring.
- **Hunt:** 80% inside a 120° arc of the view ring pointing away from the Tower, centred on the bearing from the Tower to the camera centre; 20% uniform elsewhere. When the camera centre is within 240 px of the Tower, the arc instead centres on the player's last movement direction; with no such direction, a keyed RNG roll picks the centre.

---

## Pacing & Escalation Algorithm

The Wave Director does not rely on static timers. It uses a "Pressure Metric" to decide when to escalate.

- **Pressure Calculation (Provisional Default formulas; document 11 owns the final form):**
  - `threat_i = current_hp_i × intent_weight_i × (dps_i / 10)` for every living, non-dying enemy, where `dps_i` is the enemy's sheet damage per second from its Attack profile and 10 damage per second is the reference, so `threat_i` is measured in health points. `intent_weight` is 1.0 for Player Hunters, 1.25 for Tower Seekers, and 1.1 for Opportunists. `Threat = Σ threat_i`.
  - `Capacity` is the sheet damage per second of the player and the Tower with their current upgrades (the player term is not zeroed while the Console is open).
  - `Pressure = Threat ÷ (Capacity × 20 s)`, dimensionless: 1.0 means the weighted field would take about 20 seconds to clear at current output, 0.6 about 12 seconds, and 1.8 about 36 seconds. With no enemies alive, Pressure is 0. Pressure is evaluated every 0.5 seconds, only while a combat wave (not a teaching wave) is open and outside the grace period.
  - Every constant above is a field on the Wave Definition resource.
- **Escalation Trigger:** if Pressure stays below 0.6 for 3 consecutive seconds, the current encounter's next spawn group starts. At least 4 seconds must pass between escalations. If no spawn group remains, escalation does nothing.
- **De-escalation (bounded):** if Pressure exceeds 1.8, spawn intervals double — spawning never stops outright. The throttle lifts once Pressure falls below 1.2, and expires on its own after 10 seconds regardless, with a 6 second lockout before it can re-arm. De-escalation never applies during a Siege or during Overtime. These bounds exist because an unbounded de-escalation would hand a cornered player exactly the recovery the safe-corner ban forbids, and would suppress the Overtime finishers it is meant to coexist with.
- **Health quadrant:** the Wave Director reads the health quadrant (Low is below 40% of maximum health, shield excluded, for either pool) at every escalation decision and records it to telemetry. In the prototype and the vertical slice the quadrant has no effect on encounter or spawn selection; the earlier rule tying spawn selection to a low pool's condition is withdrawn without a replacement rule. Document 11 may define quadrant-aware selection later; this remains an open question.
- **Overtime:** Overtime fires when a wave's maximum duration has elapsed and kills in the last 30 seconds are below the stall threshold (Provisional Default 5); see Wave Runtime Model for the full trigger and cleanup behaviour.

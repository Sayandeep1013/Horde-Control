# Phase 04 - Failure Points

## Predetermined

Restated from PLAN.md > "Predetermined failure points and risks".

| Risk | Why it might happen | Mitigation | Detection |
| --- | --- | --- | --- |
| The entity cap being exceeded by Overtime finishers | P2.8 implements Overtime finisher spawning on top of whatever enemies already carried over from a stalled wave; if the finisher spawner does not throttle against the live global count the same way ordinary spawn groups do, finishers could push the enemy count past its cap | Implement finisher spawning as a spawn group like any other, subject to the same global entity cap and ring validation/throttle logic (docs/11_Wave_Director.md > "Wave Runtime Model" > Overtime; MASTER_SDLC.md > Provisional Values Register > Spawning & Waves > "Overtime finishers", C-OVERTIME-CAP) | Overtime test; carried into Phase 06 (P2.15) as the Entity cap test, re-checked across every run |
| The Pressure Metric flapping between escalation and de-escalation | P2.9's escalation and de-escalation triggers sit close enough in the formula's range that a threat/capacity swing near a boundary could re-trigger the opposite state before its own lockout expires, unless both cooldowns are enforced independently | Implement both cooldowns as independent timers exactly per docs/11_Wave_Director.md > "Pacing & Escalation Algorithm" > Escalation Trigger and > De-escalation (bounded); expose both states on the debug overlay for scripted inspection (MASTER_SDLC.md > Risk Register: "Pressure Metric oscillates (escalate / de-escalate flapping)") | Pressure test; debug overlay's escalation/de-escalation state field, reviewed against Run Recorder pressure samples |
| Tower becoming irrelevant to moment-to-moment play | P2.8's four prototype encounter types are authored as data; a wave's spawn groups could omit a Tower Seeker or Opportunist with nothing but data review to catch it, silently breaking the Wave Composition rule | Validate every wave's data against the Wave composition rule (docs/11_Wave_Director.md > "Encounter Budgets for the Prototype": "Every combat wave after T1 contains at least one Tower Seeker or Opportunist") as part of authoring the wave resources, not after | A build-time schema check applying the same comparison the (VS-tagged, out-of-prototype-scope) Composition rule test uses, run against every prototype wave resource before P2.8 is reviewed |
| Ghost hits reappearing under spawn density | P2.8 raises enemy counts far above the hand-placed Phase 03 arena; a Logical Death edge case that never triggered at low density (for example many simultaneous deaths on one tick) could surface only once real spawn volume exists | Re-run the same Logical Death sequencing Phase 03 relied on (docs/20_Technical_Architecture.md > "Logical Death") inside a full encounter, and inspect the hit queue's sort order (docs/20 > "SimLoop order" step 7) at high entity counts | Wave runtime test and Spawn ring test runs; any damage event logged against an already-dead entity in events.csv |
| Spawn ring validation exhaustion under Siege volume | The Siege volume formula can place many Seekers on the Tower ring within a short window (combat wave 4); if enough candidate points fail validation at once, the 8-step alternating shift could exhaust before a valid point is found on that ring | Implement the full fallback chain exactly per docs/11_Wave_Director.md > "Spawn Rings & Placement" > "Validation": 8 alternating 10-degree steps, then re-queue the spawn for the next tick without spending budget, and after 8 consecutive failed ticks ignore direction weighting and fall back to the other ring | Spawn ring test (1000 scripted spawns); a log of re-queued spawns during the heavy Siege budget, reviewed for any spawn that never resolves |

## Discovered during execution

| What happened | Cause | Fix | How to prevent it next time |
| --- | --- | --- | --- |
| | | | |

No entries yet.

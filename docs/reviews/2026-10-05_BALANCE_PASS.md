# Balance pass, 2026-10-05

Scope: review P0-2 ("a zero-input player wins"). Decisions D135-D139 in the Review Decision Log; values in the Provisional Values Register ("Wave enemy scaling", "Siege volume DPS bonus share", "Siege bursts and lanes", Tower and Attack slots rows).

Tool: `src/dev/balance_bot.gd` (header documents usage; it refuses to run without `--meta-profile-dir=` so the real profile is never touched). All runs headless, `--fixed-fps 60`, `--no-focus-pause`, seeds 11 / 222 / 3333.

## The finding that changed the pass

The still bot "won" because the game almost never let enemies attack. A dead enemy stays in the scene until the Pool reclaims it, and its attack-slot claim was only released in `_exit_tree()`, which a pooled corpse never reaches. Every dead Seeker kept one of the Tower's 27 slots, every dead Hunter one of the player's 7. A probe of the Tower at t=205 s (combat wave 2) showed 27 of 27 slots held by dead enemies and ten live Seekers waiting 32 px outside the ring, hitting nothing. So after T4, no Seeker could damage the Tower, and after the first seven Hunters died, no Hunter could damage the player. That is the "Tower takes zero damage in combat waves", "player damage frozen from t=20 s" and "difficulty flattens" in the review. The fix (release at Logical Death, D139) is a bug fix; once it was in, the original numbers were far too lethal, so the rest of the pass is a re-tune from the real baseline.

## Results (outcome, sim time in s)

Policies: `still` never moves; `collect` walks to pickups within 700 px of the player and 900 px of the Tower (350 px in Siege waves), steps away from enemies within 130 px. Draft: `pick=0` for the first three rows (the reviewer's setting), `smart` for the last (power cards first, Patch Kit under 50% player health, Repair Kit under 50% Tower health). `smart` is closer to a human; `pick=0` rows are kept for comparison with the review.

| Build | still 11 | still 222 | still 3333 | collect 11 | collect 222 | collect 3333 |
| --- | --- | --- | --- | --- | --- | --- |
| Baseline: main with the camera fix and random seed, pick=0 | WIN 401.5 | LOSS player 14.2 (T1) | WIN 400.8 | WIN 383.5 | WIN 385.3 | WIN 385.6 |
| Slot-leak fix only, original numbers, pick=0 | LOSS player 32.5 | LOSS player 14.2 | LOSS player 13.2 | LOSS player 42.2 | LOSS player 144.9 | LOSS player 63.5 |
| Levers only (before the fix), pick=0 | WIN 524.8 | LOSS player 14.2 | WIN 556.8 | WIN 495.5 | WIN 484.3 | LOSS player 220.1 |
| Final: fix + levers, smart | LOSS Tower 210.7 (wave 6) | LOSS Tower 234.3 (wave 6) | LOSS Tower 222.1 (wave 6) | WIN 373.2 | WIN 382.9 | LOSS Tower 122.1 (T4, wave 4) |

Bar: still bot loses on most seeds: met, 3 of 3. Collect bot wins on most seeds: met, 2 of 3. Run length about 7-10 minutes: not met, a winning run is 373-383 s (6.2-6.4 min), which is where the baseline was; the shortfall is recorded, not tuned away. Pressure rises through waves 5-8: the per-wave Pressure Metric samples in a collect run climb 0.41 / 0.57 / 0.66 / 0.76 (seed 11, combat waves 1-4 peaks). The metric is HP-weighted and the Siege HP multipliers are below 1.0, so it understates the load; Tower damage is the better signal, and the Tower now loses health in every combat wave instead of none.

Honest caveats. The collect bot is one fixed policy, not a player. Seed 3333 loses the Tower in T4 (the teaching Siege) before the bot has more than 3 Drafts; the `teaching_siege_tuning_test` responsive bot keeps the Tower above 50% in 5 of 5 seeds there, so this is bot behaviour in that seed, not proof the wave is unwinnable. The remaining Tower HP at a win is low (72 and 195 of about 500): the margin is thin. The baseline and "fix only" rows used `pick=0`, the final row `smart`, so the last row is not a like-for-like change; the "fix only" row shows the original numbers lose within the first three waves under either policy.

## Iteration log (smart picks unless noted; numbers are outcome and sim seconds per seed)

| Iteration | Change | Result |
| --- | --- | --- |
| it1 | Levers on the leaking build: HP 1.15/1.4/1.7/2.0, damage 1.0/1.0/1.2/1.4, bursts 6, in-wave regen 0, share 0.5 (pick=0) | Run length rose to 485-557 s, Tower still took no damage in combat waves; led to the slot probe |
| fix only | Slot release at Logical Death, all levers neutral (pick=0) | Every bot dead by player damage within 13-145 s |
| it2 | Damage 0.3-0.9 per wave, one multiplier for all enemies | All six lose to player damage, waves 3-6 |
| it3 | Damage 0.2-0.65 | Still player deaths at wave 5-6 (Hunt wave) |
| it4 | Split damage: Hunters 0.1-0.35, Seekers/Opportunists 0.4-0.9 | Tower dies in the first Siege (wave 6), all four runs |
| it5-it6 | Lower Seeker damage 0.25-0.6, HP 1.0-1.7 | Same wall at the first Siege: damage was not the lever, kill rate was |
| it7 | Smart Draft pick | Same wall |
| it8 | Siege HP down to 1.0 and 1.0-1.3 after | Collect survives the first Siege, dies wave 7 to player attrition |
| it9 | Draft takes Patch Kit / Repair Kit when low | Collect reaches wave 8, still dies by wave 6-7 |
| it11 | Hunter damage 0.08-0.18, Seeker 0.25-0.3 | Player health holds, Tower dies wave 8 |
| it13 | Collect bot steps away from enemies | Player ends at 71-100 HP, Tower dies waves 6-8 |
| it14-it15 | Siege HP 0.75 (combat 2), 0.8 (combat 4) | Collect reaches wave 8 in all three, Tower dies in the last wave |
| it17 | Combat 4 HP 0.65, T4 damage 0.3 | collect 3 of 3 WIN (375-378 s), still 0 of 3 (221-286 s) |
| final | T4 restored toward authored: damage 1.0 killed collect 3333 in T4 and two collect wins; 0.8 left the no-player T4 run losing the Tower in 0 of 5; 0.9 with HP 0.85 gives 3 of 5 and 5 of 5 in `teaching_siege_tuning_test` | collect 2 of 3, still 0 of 3 (the table above) |

## Values changed

| Register row / file | Old | New |
| --- | --- | --- |
| Wave enemy scaling: HP multiplier T1-T4, combat 1-4 (`data/waves/*.tres`) | none (1.0) | 1.0 / 1.0 / 1.0 / 0.85, 1.0 / 0.75 / 1.1 / 0.65 |
| Seeker and Opportunist damage multiplier | none (1.0) | 0.25 / 0.25 / 0.3 / 0.9, 0.25 / 0.3 / 0.3 / 0.3 |
| Hunter damage multiplier | none (1.0) | 0.08 / 0.10 / 0.12 / 0.12, 0.10 / 0.12 / 0.15 / 0.18 |
| Tower shield in-wave regen fraction (`data/tower/base.tres`) | 1.0 (always regenerates) | 0.0 |
| Siege volume DPS bonus share (`director_configuration.tres`) | 1.0 (live DPS) | 0.5 |
| Siege Seeker burst size (`combat_2_siege`, `combat_4_siege`) | 1 | 6 |
| Siege Directional Weighting entry | uniform (lane count 0) | 2 lanes, 40 degrees, heavy share 0.6 |
| Attack-slot claim release | at despawn only | at Logical Death |

Tests changed: `siege_volume_formula_test` now expects 64 Seekers and 10 Hunters at 50 live DPS (was 85 and 13) because the formula sees 37.5 DPS at share 0.5. Tests added: `attack_slot_release_on_death_test`, `tower_destruction_ends_run_test`. `teaching_siege_tuning_test` is unchanged and passes (3 of 5, 5 of 5) with the T4 values above.

## Reported hang

Not a game bug. A headless probe of the assembled prototype scene, destroying the Tower with 1000 damage, ends the run one frame later with cause TOWER_DESTROYED and the run-end panel up. The stall is the gdUnit4 process failing to exit: `_end_run()` leaves the run-ended pause reason on the PauseAuthority autoload, and a runner that exits while the tree is paused never terminates (reproduced with exit code 124 from `timeout` while the test reported PASSED; with the reason popped in `after_test()` it exits 0). The regression test pops the reason, uses a bounded frame loop and a gdUnit4 timeout guard.

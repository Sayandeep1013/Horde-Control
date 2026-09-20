# P2.11 — Six upgrades and fallback cards — Evidence report

Status note per MASTER_SDLC.md > Document Control > Gate Approval and phases/README.md loop rule (c): this report does not claim P2.11, its named test, or Phase 05 is passed, satisfied, complete, or ready. It records what was built and what was observed; the critical agent and phase reviewer decide.

## Scope

Exactly plan task P2.11 (phases/PHASE_05_Upgrades_Interfaces_Run_Flow/PLAN.md row P2.11): author the six prototype upgrades and two fallback cards as `.tres`, build `src/upgrade/upgrade_system.gd` to own ranks and apply effects, expose a typed API for P2.12 (Draft) and P2.13 (Console). The Draft UI and Console UI themselves are out of scope (P2.12, P2.13).

## Files created

- `data/upgrades/rapid_fire.tres` — Player, UpgradeDefinition
- `data/upgrades/heavy_rounds.tres` — Player, UpgradeDefinition
- `data/upgrades/patch_kit.tres` — Player, UpgradeDefinition
- `data/upgrades/caliber.tres` — Tower, TowerUpgradeDefinition
- `data/upgrades/optics.tres` — Tower, TowerUpgradeDefinition
- `data/upgrades/shield_matrix.tres` — Tower, TowerUpgradeDefinition
- `data/upgrades/overdrive_fallback.tres` — Player fallback, UpgradeDefinition
- `data/upgrades/reinforce_fallback.tres` — Tower fallback, TowerUpgradeDefinition
- `src/upgrade/upgrade_system.gd` — the rank-owning, effect-applying system and its public API
- `tests/unit/upgrade_effect_check_test.gd` — the named acceptance test (12 test methods)
- `phases/PHASE_05_Upgrades_Interfaces_Run_Flow/evidence/p211_report.md` — this report

## Files edited (all within the permitted list)

- `src/combat/auto_weapon.gd` — added `_damage_multiplier`/`_fire_rate_multiplier` fields, `set_damage_multiplier()`, `set_fire_rate_multiplier()`, `get_effective_damage_per_shot()`, `get_effective_fire_interval_seconds()`, and two `_for_test()` getters; `_fire_at()` and `physics_step()` now read the *effective* values instead of the raw base fields. The base fields (`_damage_per_shot`, `_fire_interval_seconds`) and `data/weapons/handgun.tres` are untouched.
- `src/tower/tower_weapon.gd` — same pattern: `_damage_multiplier`/`_range_multiplier`, `set_damage_multiplier()`, `set_range_multiplier()`, `get_effective_damage_per_shot()`, `get_effective_range_px()`, two `_for_test()` getters; `_retarget_if_needed()` and `_fire_at()` now use the effective values. `data/tower/base_weapon.tres` and `data/tower/base.tres` are untouched.
- `src/tower/tower_health.gd` — added `_base_max_shield` (the pristine definition-derived value) and `_bonus_max_shield_fraction`, plus `set_bonus_max_shield_fraction()` and a `_for_test()` getter. `configure()` now stores the base shield into `_base_max_shield` before assigning it to `max_shield`. `data/tower/base.tres` is untouched.
- `src/player/player.gd` — added exactly one method, `heal(amount: float) -> void`, the minimal seam Patch Kit needs. Verified via `git diff -- src/player/player.gd`: 25 insertions, 0 deletions, nothing else touched.

## Register citations and values taken

All from `MASTER_SDLC.md > Provisional Values Register > "Progression & Upgrades"` unless noted:

| Upgrade | Pool | Effect | Max rank | Console price/rank |
| --- | --- | --- | --- | --- |
| Rapid Fire | Player | +20% fire rate/rank | 3, shared | 30 |
| Heavy Rounds | Player | +20% damage/rank | 3, shared | 30 |
| Patch Kit | Player | restores 30 health/rank taken | 3, shared | 30 |
| Caliber | Tower | +20% Tower damage/rank | 3, shared | 30 |
| Optics | Tower | +15% Tower range/rank | 3, shared | 30 |
| Shield Matrix | Tower | +10% of Tower max health as extra shield/rank | 3, shared | 30 |
| Overdrive (fallback) | Player | +10% weapon damage | none | 90 (flat, C-FALLBACK-CONSOLE) |
| Reinforce (fallback) | Tower | +10% Tower damage | none | 90 (flat, C-FALLBACK-CONSOLE) |

Other cited rows:
- Console price formula "30 Scrap × rank being bought (30/60/90)" — same section — implemented as `console_price_per_rank * rank_being_bought` for the six ranked upgrades.
- C-FALLBACK-CONSOLE (same section, and Default Unresolved-State Policies row): "No max rank, add 0 evolution ranks... appear... at the Console for 90 Scrap once that pool is exhausted, so Scrap always has a sink."
- `MASTER_SDLC.md > Player Overview > "Upgrade Channels"`: "An upgrade rank purchased in one channel counts in the other; maximum rank is shared" — the exit criterion this task's `apply_rank()` and its shared `_ranks` dictionary satisfy structurally.
- `MASTER_SDLC.md > Tower Evolution Stages`: "Trigger... count of Tower upgrade ranks held from either channel," thresholds 1/3/6 — used to set `evolution_stage_contribution = 1` on Caliber/Optics/Shield Matrix and `= 0` on Reinforce (explicit "add 0 evolution ranks").
- `docs/20_Technical_Architecture.md > Contract Field Semantics > Upgrade Definition Contract fields`: "Rarity... the prototype pool uses a single implicit tier" → `rarity = Common` (0) on all eight; "Draft weight... every prototype Tower upgrade uses 1" (unconditional) → `draft_weight = 1` on Caliber, Optics, Shield Matrix, **and** Reinforce (see "Interpretations" below).
- `MASTER_SDLC.md > Tower Overview > Health Recovery Rules`: "In the prototype exactly one player upgrade restores health: Patch Kit restores 30 health per rank taken" and "Overheal on either pool is discarded unless an upgrade explicitly converts it to shield" — the clamp in `Player.heal()`.
- `MASTER_SDLC.md > Progression Edge Cases > "Percentage bonuses to the same stat stack"` (C-STACK): "stat = base × (1 + sum of bonuses)" — the stacking rule, see below.

Base values the effect check computes against (read from the .tres files owned elsewhere, never edited): `data/weapons/handgun.tres` (10 dmg, 2.0 shots/s), `data/tower/base_weapon.tres` (20 dmg, range 480 via `data/tower/base.tres` targeting_rule_parameters), `data/tower/base.tres` (max_health 500, base_shield_fraction 0.25), `data/player/prototype.tres` (max_health 100).

## Stacking decision: additive, not multiplicative — cited, not escalated

MASTER_SDLC.md > Progression Edge Cases > "Percentage bonuses to the same stat stack" states this in full: "Percentage bonuses to the same stat add, then apply once: stat = base × (1 + sum of bonuses) (C-STACK)." This directly and unambiguously settles the question for every percentage-based upgrade in this pool. `upgrade_system.gd::_apply_effect()` always recomputes `total_fraction = effect_per_rank * float(rank)` from the upgrade's **current total shared rank** and pushes that one combined value, never compounding a previous multiplier. Heavy Rounds at rank 3 is `10 × (1 + 0.6) = 16.0`, never `10 × 1.2³ = 17.28`. No escalation was needed because the Register's wording is explicit and unqualified.

Patch Kit is not a percentage-of-a-stat upgrade and does not stack in the C-STACK sense at all: "restores 30 health per rank TAKEN" is read as an on-apply, one-shot heal fired once per rank-taking event (`_player.heal(def.effect_per_rank)`, never `total_fraction`), so three ranks taken in sequence heal 30 + 30 + 30, clamped to max_health at each step — not a multiplying percentage.

## Interpretations (not settled verbatim by the Register, named rather than silently assumed)

1. **Fallback card Console price is flat, not per-rank.** C-FALLBACK-CONSOLE's plain-language "90 Scrap" (not a formula) is read as a flat price regardless of how many times the card has been taken, since a no-max-rank card has no "rank being bought" number for the six-upgrade formula to multiply against. `get_console_cost()` special-cases `has_max_rank == false` to return `console_price_per_rank` unmultiplied. Falsified indirectly by `test_console_cost_scales_per_rank_for_ranked_upgrades_and_is_flat_for_fallback_cards`, which asserts the price stays 90 after two takes.
2. **Shield Matrix's new capacity arrives already filled, not empty.** The Register states the capacity increase ("+10% of Tower maximum health as extra shield/rank") but not whether it arrives charged. `TowerHealth.set_bonus_max_shield_fraction()` tops up `current_shield` by exactly the newly granted capacity delta (clamped to the new `max_shield`), on the reasoning that a purchased/earned upgrade should not sit at 0% charge waiting on the normal regen timer. Verified with a damaged-shield fixture in `test_shield_matrix_stacks_additively_and_tops_up_current_shield_by_exactly_the_delta` (a bug that reset current_shield to full instead of adding the delta would have been caught by the same test — see "Design notes" below).
3. **Reinforce's `draft_weight` is 1, not 0.** docs/20's Upgrade Definition Contract fields table states "every prototype Tower upgrade uses 1" unconditionally, with no stated carve-out for a fallback card, so Reinforce was authored at 1 rather than inventing an exception not stated anywhere. Nothing in this task's own code reads `draft_weight` — it is data for P2.12's future weighted-draw logic to interpret however it designs the draw, since the actual fallback-substitution mechanism runs on `is_pool_exhausted()`, not on the weighted pool.
4. **Effect-routing is keyed by `unique_id`, not purely by `effect_target`.** The Upgrade Definition Contract's `effect_target` enum (`Player`/`Tower`/`PlayerWeapon`/`TowerWeapon`) names which *component* an effect reaches but not which of that component's several stats (TowerWeapon alone carries both Caliber's damage and Optics's range). For this fixed, eight-card prototype pool, `_apply_effect()` matches on `def.unique_id` against eight named constants rather than inventing an unscoped fifth contract field or a generic effect-execution engine for exactly eight known cards.
5. **`visual_readability_impact` and `performance_cost_category` were left at their schema defaults (`None`/`Light`)** on all eight `.tres` files. These are categorisation/QA metadata fields, not tunable gameplay numbers the Register assigns per upgrade (none of the six upgrades add new VFX or a measurable perf cost beyond an existing weapon firing faster/harder), so this was not treated as a `NO REGISTER ROW` escalation.

No `NO REGISTER ROW - escalated` numbers were needed for this task: every gameplay number placed on the eight `.tres` files traces to a Register row or (for rarity, draft_weight, evolution_stage_contribution) a docs/20 Contract Field Semantics row, both cited above.

## Public API for P2.12 (Draft) and P2.13 (Console)

All on `src/upgrade/upgrade_system.gd`, typed, no channel parameter anywhere (channel-agnostic by construction — see "shared-rank" falsification below):

- `get_definition(upgrade_id: String) -> UpgradeDefinition` — display fields for a card.
- `get_current_rank(upgrade_id: String) -> int`
- `is_maxed(upgrade_id: String) -> bool`
- `get_offerable_upgrades(pool_ownership: ContractEnums.PoolOwnership) -> Array[UpgradeDefinition]` — non-maxed, ranked (non-fallback) upgrades in a pool; what the Draft's random three and the Console's catalogue both start from.
- `is_pool_exhausted(pool_ownership: ContractEnums.PoolOwnership) -> bool` — true once every ranked upgrade in that pool is maxed; false for a pool with nothing authored (guards against a false positive).
- `get_fallback_card(pool_ownership: ContractEnums.PoolOwnership) -> UpgradeDefinition` — the Overdrive/Reinforce resource to substitute or list once `is_pool_exhausted()` is true.
- `get_console_cost(upgrade_id: String) -> int` — Scrap cost of the next rank (`console_price_per_rank * (current_rank + 1)` for ranked upgrades, flat `console_price_per_rank` for fallback cards); returns `-1` for unknown/maxed.
- `apply_rank(upgrade_id: String) -> bool` — the one command both channels call; false and no-op if unknown or already maxed.

Wiring seams (NodePath exports + matching `set_*_for_test()`): `player_weapon_path`/`set_player_weapon_for_test()`, `player_path`/`set_player_for_test()`, `tower_weapon_path`/`set_tower_weapon_for_test()`, `tower_health_path`/`set_tower_health_for_test()`. A null reference at any of these is tolerated (rank is tracked, effect silently not applied) rather than crashing, since scene assembly is outside this task's scope.

## Falsification table

All mutations were made to files created by this task this session (untracked in git), so restoration was verified with `diff` against a pre-mutation copy saved to the scratchpad, per the task's own instruction for untracked files.

| # | Mutation | File | Re-run | Exit code | Result | Restored byte-identical |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Changed Heavy Rounds' `effect_per_rank` from `0.2` to `0.3` | `data/upgrades/heavy_rounds.tres` | `upgrade_effect_check_test.gd` | 100 | `test_heavy_rounds_stacks_additively_to_exactly_rank_3_with_no_drift` failed: expected `16.0 ± 0.0005`, got `19.0` | Yes (`diff` clean) |
| 2 | Commented out the `is_maxed()` guard in `apply_rank()`, allowing a rank to exceed max | `src/upgrade/upgrade_system.gd` | `upgrade_effect_check_test.gd` | 100 | `test_ranks_apply_from_either_channel_and_cap_correctly_at_rank_3` failed on all three of its rank-3-cap assertions: a 4th application returned `true` instead of `false`, rank read `4` instead of `3`, and live damage read `18.0` instead of the clamped `16.0` | Yes (`diff` clean) |
| 3 | Added a second, parity-toggled `_ranks_channel_b` dictionary in `apply_rank()` so alternating calls land on different counters | `src/upgrade/upgrade_system.gd` | `upgrade_effect_check_test.gd` | 100 | The global call-parity counter affects every `apply_rank()` call in the suite, not only the dedicated two-"channel" test, so the very first test (`test_rapid_fire_...`) failed first (rank 2/3 read wrong, `get_current_rank` returned `2` instead of `3`, `is_maxed` returned `false`) — a real, observable break of the shared-counter property, just manifesting earlier than the test written specifically to name it | Yes (`diff` clean) |

None of the three mutations were a no-op against the test — all three turned it red with the exact predicted defect, so no clause here is dead code or covered only by a weak assertion.

An incidental discovery while running these: this gdUnit4 invocation stops a suite at its **first** failing test rather than running the rest (falsification 1 executed 2/12 methods before stopping, falsification 2 executed 8/12, falsification 3 executed 1/12) — the differing counts simply mark where the first failure landed in file order, not a partial/aborted run. Exit code 100 was consistent and correct in all three cases; the unmutated suite always executes and passes all 12.

## Test results

- `tests/unit/upgrade_effect_check_test.gd` in isolation (`res://tests/unit/upgrade_effect_check_test.gd`), on the clean, restored codebase: **12 test cases, 0 errors, 0 failures, 0 orphans, exit code 0.** Re-confirmed a second time after all three falsification/restoration cycles, with the same result. The engine-error guard (`run_tests.ps1`'s scan for `^(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR):` lines) found nothing in either run; the only non-assertion output was two expected `push_warning()` lines (an upgrade already at max rank refusing a further apply/cost query), which are warnings, not errors, and the guard does not — and per its own documented scope should not — flag them.
- Full `res://tests/unit` suite, run once early in this session (before other implementers' concurrent edits accumulated further): **397 test cases, 0 errors, 1 failure, 0 orphans.** The one failure, `tower_projectile_sweep_test.gd > test_sweep_detects_a_hurtbox_the_projectile_would_otherwise_jump_over`, is new coverage for another parallel implementer's in-progress, uncommitted work on `src/tower/tower_projectile.gd` (LEDGER F03-17, an intersect_ray sweep) — a file this task's hard constraints explicitly forbid touching, and one I did not touch. `git diff` at that point showed `tower_projectile.gd` already modified with that exact in-progress sweep implementation.
- Full `res://tests/unit` suite, run again later in this same session, after further concurrent edits had landed from other implementers (`git status` at that point showed additional modified files this task never touched: `scenes/player.tscn`, `scenes/prototype.tscn`, `scenes/entities/*.tscn`, `src/enemy/enemy_controller.gd`, `src/core/sim_clock.gd`, `src/core/sim_loop.gd`, `src/core/event_bus.gd`, `src/director/wave_director.gd`, `src/combat/hitbox.gd`, `src/combat/death_state.gd`, `src/combat/player_projectile.gd`, `src/tower/tower.gd`, plus new untracked pickup/economy/pressure files and tests): **394 test cases, 0 errors, 14 failures.** I verified `git diff -- src/player/player.gd` at this point still showed exactly the one intended `heal()` addition (25 insertions, 0 deletions, nothing else) and did not investigate or attempt to fix the other 13 failing tests (`leash_test.gd`, `player_input_buffer_test.gd`, `player_movement_test.gd`, `pressure_test.gd`, `tower_entity_registry_query_test.gd`, and others) since none of the files they exercise are in this task's write scope, and the volatility is consistent with the four other implementers working in parallel per this task's own briefing. This full-suite instability is reported for transparency; `tests/unit/upgrade_effect_check_test.gd` itself is the authoritative, isolated evidence for P2.11 and was re-verified clean immediately after this observation.

## Seams needed outside this task's scope

1. **`death_state.gd` has no `heal()`/symmetrical-to-`apply_damage()` command.** `Player.heal()` was added as the minimal workaround (writing `death_state.current_hp` directly, mirroring the existing `death_state.max_hp = ...` precedent a few lines above it in `player.gd`), but the more correct home for a heal primitive is `death_state.gd` itself, as a `heal(amount)` command mirroring `apply_damage(amount)` — `src/combat/death_state.gd` is outside this task's write scope, so this is named rather than done.
2. **Tower evolution-stage wiring is not connected to `UpgradeSystem`.** `evolution_stage_contribution` is authored correctly on all eight `.tres` files (1 for the three real Tower upgrades, 0 for Reinforce), but nothing in this task calls into `src/tower/tower_evolution_stage.gd` (not in this task's write-scope list) when a Tower upgrade rank is applied. A future integration task (or P2.13) needs to sum `evolution_stage_contribution × rank` across the three real Tower upgrades and push it to `TowerEvolutionStage` for the visual stage (Base/Reinforced/Armed/Fortress) to actually change.
3. **Scene wiring.** `UpgradeSystem`'s four `*_path` NodePath exports are unassigned by default; whichever task assembles the real run scene (`scenes/**`, outside this task's write scope) must add an `UpgradeSystem` node and point its paths at the real player weapon, player, Tower weapon, and Tower health nodes for ranks to have a live effect outside of tests.
4. **Console purchase flow charges nothing by itself.** `get_console_cost()` reports a price; `apply_rank()` has no notion of cost at all. P2.13 (Console) must debit Scrap itself before calling `apply_rank()` — named explicitly since a caller that calls `apply_rank()` without checking/paying the cost would grant a rank for free, and this task's API does not prevent that misuse (it isn't this task's job to own Scrap).

## Skill conflicts

- `godot-prompter:ability-system`'s worked example (`Ability`/`AbilityComponent` with cost/cooldown/cast-time fields, `try_activate()`) targets active, player-triggered abilities. The prototype's six upgrades are passive, always-on stat modifiers plus one on-apply heal, with no cost/cooldown/cast concept of their own (the Register's shape, not this skill's) and a channel-agnostic `apply_rank()` in place of `try_activate()`. The skill's core architectural principle — data in Resources (`UpgradeDefinition`/`TowerUpgradeDefinition`, already authored by P0.6), behaviour in a component (`UpgradeSystem`), communication via typed commands/queries — was followed; its specific field shape was not, since this project's own Upgrade Definition Contract (MASTER_SDLC.md, cited throughout) wins per CLAUDE.md's precedence rule. No LEDGER row was needed since this is a shape mismatch, not a contradiction with docs/20 or an Author decision.
- `godot-prompter:godot-testing`'s file-naming convention (`test_*.gd` prefix) conflicts with this project's own convention (`<name>_test.gd` suffix, stated explicitly in this task's brief); this project's convention was followed (`tests/unit/upgrade_effect_check_test.gd`).
- `godot-prompter:resource-pattern`'s guidance was followed without conflict (typed `class_name` Resources, no game logic inside them, no giant monolithic Resource — the eight upgrade `.tres` files are small and focused, matching the already-authored `UpgradeDefinition`/`TowerUpgradeDefinition` schema).

## What could not be done / was deliberately left undone

- Weapon upgrades and the Draft/Console UIs are out of scope per the task brief and were not built.
- Evolution-stage visual wiring, Console cost-charging, and scene assembly are named as seams above rather than implemented, since they require editing files outside this task's permitted list.
- The full `res://tests/unit` suite could not be brought to a clean state by this task, because 13 of its 14 currently-observed failures live in files this task is not permitted to touch and are attributable to other implementers' concurrent, in-progress work landing in the shared working tree during this session (see "Test results" above for the specific files and the `git diff` verification that `player.gd` itself was not the cause).

extends Resource
class_name EnemyAITuning

## EnemyAITuning (P2.5). docs/09_Enemy_AI_Architecture.md > "Intent
## Behaviour Defaults" gives real numbers for the attack-slot formula, the
## Tower Seeker body-block rule, the Player Hunter leash rule, the
## Opportunist event rule, and the stuck-rule ladder -- but the Enemy
## Definition Contract (docs/20_Technical_Architecture.md > Contract Field
## Semantics > "Enemy Definition Contract fields") has fields only for
## Pathing fallback behavior, Elite eligibility, Allowed affixes, and Biome
## tags. There is no Contract field anywhere for attack-slot geometry, the
## body-block window, the leash timers, the Opportunist's aggro
## range/hysteresis/lockout, or the stuck-rule seconds/pixels.
##
## **Cross-task seam, named rather than silently patched.** Extending the
## Contract itself (src/data/enemy_definition.gd) would be the "correct"
## home for these fields, but that file is outside this task's write scope
## (only src/enemy/, the three named data/enemies/*.tres files, new scenes
## under scenes/entities/, and named test suites are). Putting these
## numbers in `data/enemies/` is also out of scope -- that directory's
## write scope is exactly the three named EnemyDefinition instances. This
## resource lives under src/enemy/ instead (unrestricted by this task's
## write-scope list) so every one of docs/09's numbers still lands in an
## AUTHORED .tres (docs/20 > "Data Contracts": all content data must be a
## Resource, never a hardcoded constant) rather than a script constant.
## Recorded in the P2.5 evidence report as a Contract-gap finding, a
## candidate for the phase LEDGER and for a future revision of the Enemy
## Definition Contract itself.
##
## Every field cites its Provisional Values Register row by name; none of
## these numbers are restated as bare literals in src/enemy/*.gd logic.

## Register > Spawning & Waves > "Attack slots (C-SLOTS)": "an enemy claims
## the nearest free slot within 64 px of the ring, else waits 32 px outside
## accruing no stuck time... separation from EntityRegistry neighbours
## within 32 px".
@export var attack_slot_claim_radius_px: float = 64.0
@export var attack_slot_wait_offset_px: float = 32.0
@export var separation_neighbor_radius_px: float = 32.0

## Register > Enemies > "Tower Seeker" row: "body-block after 2 s blocked
## with player in reach attacks player (15) without changing intent";
## docs/09 > "Tower Seeker body-block rule": "Blocked means less than 8 px
## of progress over 2 seconds with the player within the Seeker's 20 px
## reach".
@export var body_block_window_seconds: float = 2.0
@export var body_block_min_progress_px: float = 8.0

## Register > Enemies > "Player Hunter" row: "leash 20 s without reset ->
## 0.5 s telegraph -> converts to full Tower Seeker profile keeping current
## HP"; docs/09 > "Player Hunter leash rule".
@export var leash_timeout_seconds: float = 20.0
@export var leash_telegraph_seconds: float = 0.5

## docs/09 > "Opportunist event rule" (Register > Enemies > "Opportunist"
## row cross-references the same rule): "the out-of-range event fires
## after 3 continuous seconds outside the 400 px aggro range... switches
## only if the other target is at least 25% closer... and at least 3
## seconds have passed since its last switch".
@export var opportunist_aggro_range_px: float = 400.0
@export var opportunist_out_of_range_seconds: float = 3.0
@export var opportunist_switch_closer_fraction: float = 0.25
@export var opportunist_switch_lockout_seconds: float = 3.0

## Register > Enemies > "Stuck rules" row; docs/09 > "Stuck rules": "After 3
## seconds without path progress... it falls back... After 8 seconds of
## less than 8 pixels of displacement the global stuck detector forces
## direct approach; after 20 seconds still stuck it despawns".
@export var stuck_no_progress_seconds: float = 3.0
@export var stuck_no_progress_px: float = 8.0
@export var stuck_global_direct_approach_seconds: float = 8.0
@export var stuck_despawn_seconds: float = 20.0

## Register > Enemies > "All enemies" row / docs/09 > "Telegraph minimums":
## "telegraph minimums melee 0.4 s, ranged 0.8 s... Difficulty scaling never
## reduces these." Not read by EnemyController directly (each enemy's own
## TelegraphData.windup_duration_seconds is already authored at or above
## its minimum on data/enemies/*.tres) -- kept here as the one place a
## future validation pass checks every TelegraphData against.
@export var melee_windup_minimum_seconds: float = 0.4
@export var ranged_windup_minimum_seconds: float = 0.8

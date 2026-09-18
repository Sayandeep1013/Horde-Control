extends RefCounted
class_name EntityCaps

## EntityCaps (P1.3; MASTER_SDLC.md > Provisional Values Register >
## Technical Caps & Performance > "Entity caps" row: "Enemies 300 (never
## exceeded; Overtime finishers count against it and throttle like any
## spawn, C-OVERTIME-CAP), pickups 150, projectiles 400 (oldest recycled),
## damage numbers 30, simultaneous telegraphs 40 (player-aimed telegraphs
## take slots first; spawn markers aggregated one per 30 degree sector count
## as one), high-intensity VFX 24; throttle = spawn retries next tick
## without using budget". Mirrored by docs/20_Technical_Architecture.md >
## Interim Prototype Technical Budgets, which the Register cites as owner
## document 20 -- the two tables agree; this file transcribes the Register
## row since MASTER_SDLC.md wins on any numeric conflict.
##
## src/core/entity_spawner.gd is the only reader of these six constants.
## Phase 02 carried lesson 2 (PLAN.md > "Carried lessons"): "P1.3's cap
## check takes the six cap values from the Provisional Values Register, not
## from the spawner's own constants" -- so tests/unit/entity_cap_test.gd
## does NOT read this file. It transcribes the same six numbers a second
## time, independently, directly from the Register text above, so a wrong
## value written here cannot pass its own check by agreeing with itself
## (this project has shipped that exact defect three times per the carried
## lesson).

const MAX_ENEMIES: int = 300
const MAX_PICKUPS: int = 150
const MAX_PROJECTILES: int = 400
const MAX_DAMAGE_NUMBERS: int = 30
const MAX_TELEGRAPHS: int = 40
const MAX_HIGH_INTENSITY_VFX: int = 24

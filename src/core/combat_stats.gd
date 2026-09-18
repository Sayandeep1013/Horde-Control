extends Node

## CombatStats Autoload (docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Communication, queries", named example
## "`CombatStats.sheet_dps()`"; MASTER_SDLC.md > Global Simulation
## Authority, process-mode paragraph: "`SimClock`, `EntityRegistry`, and
## `CombatStats` are `PROCESS_MODE_PAUSABLE`").
##
## "Sheet DPS" (not measured, actual damage dealt) is a defined term this
## project already uses: MASTER_SDLC.md > Acceptance Test Matrix > Pressure
## Metric > Threat formula, "dps_i is the enemy's sheet DPS from its Attack
## profile"; > Capacity formula, "Sheet DPS of the player and the Tower with
## their current upgrades ... not measured actual damage"; > D61, "sheet DPS
## is deterministic and cannot be gamed". No player, Tower, or enemy
## instance exists yet (P2.x); this file owns the one arithmetic RULE those
## later systems all share (damage / interval) plus a place to report and
## re-query the resulting number, so nothing downstream has to re-derive the
## formula or reach into a weapon/enemy system's fields directly to get it
## (docs/20 > "Communication, commands": writing another system's fields
## directly is banned even through a bare setter).
##
## docs/20's own example is written with no arguments,
## `CombatStats.sheet_dps()`, which cannot literally be right: the Capacity
## formula needs the PLAYER's sheet DPS and the TOWER's separately, and the
## Threat formula needs a DIFFERENT sheet DPS per living enemy, so a single
## zero-argument value cannot serve all three at once. Read as an
## illustrative name, not a literal signature -- see the P1.2 evidence
## report, "Contradictions and ambiguities," item 2. This file exposes the
## bare computation as sheet_dps(damage, interval_seconds), and a
## per-subject report/query pair (report_sheet_dps() / get_sheet_dps()) so a
## later system can publish "player", "tower", or an individual enemy's
## current figure without this file needing to know what a player, Tower,
## or enemy even is yet.

var _sheet_dps_by_subject: Dictionary = {} # StringName -> float


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


## Typed query (docs/20 named example). Pure arithmetic: damage per hit or
## tick, divided by the interval between hits or ticks, in seconds. An
## interval of 0 (or negative, which should never occur but is not this
## function's job to validate away silently) reports 0.0 DPS rather than
## dividing by zero -- an attack with no cadence deals no sustained damage.
func sheet_dps(damage: float, interval_seconds: float) -> float:
	if interval_seconds <= 0.0:
		return 0.0
	return damage / interval_seconds


## Typed query over the Attack Profile shared struct (src/data/
## attack_profile.gd: damage_per_hit_or_tick, cycle_or_tick_interval_
## seconds -- docs/20 > Contract Field Semantics > Shared fields and struct
## types > "Attack profile"). Used directly by the Pressure Metric's Threat
## formula once the Wave Director (P2.8+) exists to call it; reads any
## AttackProfile resource handed to it, since no enemy instance exists yet.
func sheet_dps_from_attack_profile(profile: AttackProfile) -> float:
	if profile == null:
		return 0.0
	return sheet_dps(float(profile.damage_per_hit_or_tick), profile.cycle_or_tick_interval_seconds)


## Typed query over the Weapon Definition Contract's rate-of-fire struct
## (src/data/weapon_definition.gd: damage_band.value, engagement_rhythm.
## fire_rate_per_second). Used by the player weapon (P2.3) and Tower weapon
## (P2.4/P2.5) systems once they exist; reads any WeaponDefinition resource
## handed to it.
##
## Deliberately NOT implemented as sheet_dps(damage, engagement_rhythm.
## fire_rate_per_second): that field is a RATE (shots per second, docs/20 >
## Contract Field Semantics: "fire rate"), the inverse of AttackProfile's
## cycle_or_tick_interval_seconds (an INTERVAL, seconds per hit). sheet_dps()
## divides by its second argument, which is correct for an interval and
## wrong for a rate -- passing fire_rate_per_second there was tried first
## and caught by combat_stats_test.gd's own coverage (10 damage at 2 shots/s
## computed as 5.0 instead of 20.0 DPS). Multiplying here, not reusing
## sheet_dps(), keeps that unit distinction explicit instead of silently
## inverting one of the two inputs to force them through one function.
func sheet_dps_from_weapon(weapon: WeaponDefinition) -> float:
	if weapon == null or weapon.damage_band == null or weapon.engagement_rhythm == null:
		return 0.0
	return float(weapon.damage_band.value) * weapon.engagement_rhythm.fire_rate_per_second


## Typed command (docs/20 > Communication, commands). The owner of a
## subject's combat stats (the player weapon system, the Tower weapon
## system, an individual enemy) reports its OWN current sheet DPS here
## whenever it changes (equip, upgrade rank taken) -- CombatStats never
## reaches into those systems itself to compute the figure; that would be
## exactly the "reach into another system to make something happen" the
## commands rule forbids, just read-direction instead of write-direction.
## Refuses (returns false, stores nothing) a negative value: DPS cannot be
## negative, so this is where the "the owning system validates and may
## refuse" half of the rule is real, not a comment with no teeth.
func report_sheet_dps(subject: StringName, dps: float) -> bool:
	if dps < 0.0:
		return false
	_sheet_dps_by_subject[subject] = dps
	return true


## Typed query. 0.0 for a subject nothing has ever reported (for example,
## before the player's weapon system exists) rather than an error, since
## "unreported" and "reported as zero" both mean "assume no sustained
## damage" to a caller such as the Pressure Metric.
func get_sheet_dps(subject: StringName) -> float:
	return float(_sheet_dps_by_subject.get(subject, 0.0))


func has_reported_sheet_dps(subject: StringName) -> bool:
	return _sheet_dps_by_subject.has(subject)

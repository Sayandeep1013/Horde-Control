extends Node
class_name TowerWeapon

## TowerWeapon (P2.4). MASTER_SDLC.md > Tower Overview > "Tower Targeting
## Rule": "The Tower auto-fires at 20 damage per shot, 1.25 shots per
## second (25 DPS, Provisional Default), projectile speed 900 px/s. The
## Tower targets the nearest Tower Seeker in range, else the nearest enemy
## in range; a non-Seeker target is dropped on the tick a Seeker enters
## range; otherwise it retargets only when its target dies or leaves range.
## Provisional Default range: three times the Interaction Radius (480
## pixels in the prototype arena). When no enemy is in range the Tower
## holds fire, consumes nothing, and any upgrade cooldowns keep ticking."
## (C-TOWERTARGET). Every number above is read from `weapon_definition` /
## `targeting_range_px`, sourced by Tower.gd from data/tower/base.tres and
## data/tower/base_weapon.tres -- never restated as a literal here.
##
## ## The EntityRegistry "tower_seeker" tag -- a new convention, named
## No real enemy (Tower Seeker / Player Hunter / Opportunist) exists yet;
## P2.5 builds them. EntityRegistry.get_entities_in_radius() filters by an
## arbitrary caller-supplied tag (entity_spawner.gd's own precedent:
## enemies register under `&"enemy"`). This file queries BOTH `&"enemy"`
## (the tag entity_spawner.gd already uses) and a NEW `&"tower_seeker"` tag
## this task introduces for "targets the nearest Tower Seeker in range,
## else the nearest enemy in range" to be satisfiable at all before P2.5
## exists. P2.5 must register real Tower Seekers with BOTH `&"enemy"` and
## `&"tower_seeker"` for this rule to work against real content -- named
## here as a convention this task establishes and P2.5 must honour, not a
## fact already true elsewhere in the codebase. See the P2.4 evidence
## report, "Contradictions and ambiguities."
##
## ## Why this runs its own _physics_process instead of SimLoop step 4/5
## docs/20's SimLoop order names step 4 ("weapon targeting and firing
## (player, then Tower)") and step 5 ("projectile movement and sweep") as
## the real integration points, but src/core/sim_loop.gd's bodies for both
## are still empty stubs and src/core/ is outside this task's write scope.
## Exactly the same reasoning as run_termination_recorder.gd's header:
## documented, deliberate, and left for whichever future task next owns
## sim_loop.gd to wire for real.
##
## ## Pooling
## Projectiles are pooled with the shared, generic src/core/pool.gd
## (already built by P1.3; referenced, not reimplemented), capped at
## EntityCaps.MAX_PROJECTILES -- the same Register-derived ceiling
## entity_spawner.gd's own projectile pool uses, so this pool cannot
## silently drift from the Register's number even though a standalone
## Tower scene has no reachable EntitySpawner instance (EntitySpawner is a
## scene-tree node under scenes/main.tscn, outside this task's write
## scope, not an Autoload). Registered with the real EntityRegistry
## Autoload (which IS reachable globally) under the `&"projectile"` tag,
## matching entity_spawner.gd's own convention, so a future central
## EntitySpawner and this Tower-owned pool at least agree on tagging even
## before anyone reconciles the two into one.

signal fired(timestamp: float)

const SEEKER_TAG: StringName = &"tower_seeker"
const ENEMY_TAG: StringName = &"enemy"

@export var origin_path: NodePath # the Node2D whose global_position projectiles fire from
@export var projectiles_container_path: NodePath # optional; null container is tolerated by Pool

var _weapon_definition: WeaponDefinition = null
var _range_px: float = 0.0
var _damage_per_shot: float = 0.0
var _fire_interval_seconds: float = 0.0
var _projectile_speed: float = 0.0
var _projectile_lifetime_seconds: float = 0.0

var _origin: Node2D = null
var _current_target: Node2D = null
var _next_fire_allowed_at: float = 0.0
var _configured: bool = false

var _pool: Pool = null

## Test-injectable references, matching this project's convention.
var _registry: Node = null
var _clock: Node = null
var _combat_stats: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_registry = EntityRegistry
	_clock = SimClock
	_combat_stats = CombatStats
	_origin = get_node_or_null(origin_path) as Node2D
	if _origin == null:
		_origin = get_parent() as Node2D


func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_combat_stats_for_test(stats: Node) -> void:
	_combat_stats = stats


func _now() -> float:
	return _clock.now if _clock != null else 0.0


## Typed command: applies the Register's numbers, read from `weapon` (a
## WeaponDefinition, e.g. data/tower/base_weapon.tres) and `range_px` (from
## TowerDefinition.targeting_rule_parameters.range_px), and builds this
## weapon's projectile pool. Must run before this weapon can fire.
func configure(weapon: WeaponDefinition, range_px: float) -> void:
	assert(weapon != null, "TowerWeapon.configure() requires a WeaponDefinition")
	assert(weapon.engagement_rhythm != null, "WeaponDefinition.engagement_rhythm is required")
	assert(weapon.damage_band != null, "WeaponDefinition.damage_band is required")
	assert(weapon.projectile_definition != null, "WeaponDefinition.projectile_definition is required")
	_weapon_definition = weapon
	_range_px = range_px
	_damage_per_shot = float(weapon.damage_band.value)
	var fire_rate: float = weapon.engagement_rhythm.fire_rate_per_second
	_fire_interval_seconds = (1.0 / fire_rate) if fire_rate > 0.0 else INF
	_projectile_speed = float(weapon.projectile_definition.speed_px_per_second)
	_projectile_lifetime_seconds = weapon.projectile_definition.lifetime_seconds
	_next_fire_allowed_at = _now()
	var container: Node = get_node_or_null(projectiles_container_path) if projectiles_container_path != NodePath() else null
	_pool = Pool.new(_projectile_factory, container, EntityCaps.MAX_PROJECTILES, Pool.OverflowPolicy.RECYCLE_OLDEST)
	if _combat_stats != null:
		_combat_stats.report_sheet_dps(&"tower", _combat_stats.sheet_dps_from_weapon(weapon))
	_configured = true


static func _projectile_factory() -> Node:
	return TowerProjectile.new()


func get_current_target() -> Node2D:
	return _current_target


func _physics_process(_delta: float) -> void:
	if not _configured or _origin == null:
		return
	_retarget_if_needed()
	if _current_target == null:
		return # idle: hold fire, consume nothing -- Register's own wording
	if _now() < _next_fire_allowed_at:
		return
	_fire_at(_current_target)
	_next_fire_allowed_at = _now() + _fire_interval_seconds


## C-TOWERTARGET, transcribed in full in this file's header. Order-
## independent of a caller's incidental call sequence: only category
## membership in `seekers_in_range` / `enemies_in_range` drives the result.
func _retarget_if_needed() -> void:
	var origin_pos: Vector2 = _origin.global_position
	var seekers_in_range: Array[Node2D] = _registry.get_entities_in_radius(origin_pos, _range_px, SEEKER_TAG)
	var enemies_in_range: Array[Node2D] = _registry.get_entities_in_radius(origin_pos, _range_px, ENEMY_TAG)

	# "a non-Seeker target is dropped on the tick a Seeker enters range"
	if _current_target != null and not seekers_in_range.is_empty() and not seekers_in_range.has(_current_target):
		_current_target = null

	# "otherwise it retargets only when its target dies or leaves range"
	if _current_target != null:
		if enemies_in_range.has(_current_target) or seekers_in_range.has(_current_target):
			return # still alive and in range -- keep it, even if a closer one exists
		_current_target = null

	if not seekers_in_range.is_empty():
		_current_target = _nearest(origin_pos, seekers_in_range)
		return
	if not enemies_in_range.is_empty():
		_current_target = _nearest(origin_pos, enemies_in_range)
		return
	_current_target = null


static func _nearest(origin_pos: Vector2, candidates: Array[Node2D]) -> Node2D:
	var best: Node2D = null
	var best_dist2: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d2: float = origin_pos.distance_squared_to(c.global_position)
		if d2 < best_dist2:
			best_dist2 = d2
			best = c
	return best


func _fire_at(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	var origin_pos: Vector2 = _origin.global_position
	var to_target: Vector2 = target.global_position - origin_pos
	var direction: Vector2 = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	var projectile: TowerProjectile = _pool.acquire() as TowerProjectile
	if projectile == null:
		return # pool at cap under THROTTLE-equivalent conditions -- RECYCLE_OLDEST means this should not happen, but never crash if it does
	# Projectile Orphans (docs/20): source resolved BY VALUE, never a live
	# Node reference to this Tower -- see tower_projectile.gd's header.
	projectile.launch(origin_pos, direction * _projectile_speed, _damage_per_shot, &"tower", _projectile_lifetime_seconds)
	fired.emit(_now())


func get_pool_for_test() -> Pool:
	return _pool

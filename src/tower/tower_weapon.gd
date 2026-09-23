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

## Integration task, docs/25_Asset_Pipeline.md: the visual this weapon's
## projectiles carry, assigned in scenes/tower.tscn -- never a hardcoded
## path in this file's logic (D99). src/tower/tower_projectile.gd itself
## has no Sprite2D and is on this integration task's explicit do-not-touch
## list (F03-17 owns that file's real defect, the missing intersect_ray
## sweep), so the visual is attached by composition from THIS file's own
## factory instead of editing that one.
@export var projectile_texture: Texture2D

## Integration task: the cue this weapon plays through the existing
## AudioPool (src/audio/audio_pool.gd) on every shot -- never a hardcoded
## path (D99). Null is tolerated (no sound, matching every other optional
## audio hook in this project).
@export var fire_sfx: AudioStream

var _weapon_definition: WeaponDefinition = null
var _range_px: float = 0.0
var _damage_per_shot: float = 0.0
var _fire_interval_seconds: float = 0.0
var _projectile_speed: float = 0.0
var _projectile_lifetime_seconds: float = 0.0

## P2.11 modifier layer (src/upgrade/upgrade_system.gd). Same contract as
## auto_weapon.gd's own `_damage_multiplier` field comment: `_range_px` and
## `_damage_per_shot` above stay exactly what configure() derived from
## `weapon`/`range_px` (data/tower/base_weapon.tres, data/tower/base.tres'
## targeting_rule_parameters -- both owned by P2.4, never mutated here);
## only these two multipliers change, combined with the base at the point
## of use via get_effective_damage_per_shot() / get_effective_range_px().
## MASTER_SDLC.md > Progression Edge Cases > "Percentage bonuses to the same
## stat stack" (C-STACK): each multiplier is the ONE already-summed
## `(1 + sum of bonuses)` value src/upgrade/upgrade_system.gd computes from
## Caliber's/Optics's current shared rank -- this file never sums bonuses
## itself and never compounds repeated calls (each REPLACES, not multiplies
## again).
var _damage_multiplier: float = 1.0
var _range_multiplier: float = 1.0
## D115/D117 pool expansion: Tower Volley (+10% Tower fire rate/rank; an
## UNLOCK card). Same replace-not-compound contract as the other two
## multipliers above; this file's own header note ("no Tower upgrade
## changes fire rate") predates this card and is superseded by it.
var _fire_rate_multiplier: float = 1.0

var _origin: Node2D = null
var _current_target: Node2D = null
var _next_fire_allowed_at: float = 0.0
var _configured: bool = false

var _pool: Pool = null

## Test-injectable references, matching this project's convention.
var _registry: Node = null
var _clock: Node = null
var _combat_stats: Node = null

## Integration task: the AudioPool (src/audio/audio_pool.gd) this weapon
## plays `fire_sfx` through -- optional (a null pool, or a null fire_sfx,
## is a silent no-op, matching every other optional audio hook in this
## project). Never a second, duplicate pool.
var _audio_pool: Node = null


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


## Typed command (integration task): wires the shared AudioPool this
## weapon's fire_sfx plays through. Never called by gameplay code on its
## own -- the integration scene's own wiring script is the real caller;
## also usable directly from a test.
func set_audio_pool_ref(pool: Node) -> void:
	_audio_pool = pool


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


## No longer `static`: attaching `projectile_texture` (an instance-level
## exported property, integration task) requires reading this instance's
## own field. `Pool` accepts any `Callable`, bound or unbound (its own
## `_init()` docstring: "factory must return a fresh, unparented Node each
## time it is called") -- a bare reference to an instance method inside
## another instance method already binds `self`, so `Pool.new(
## _projectile_factory, ...)` below needs no other change. Composition,
## not an edit to src/tower/tower_projectile.gd itself (that file is on
## this integration task's explicit do-not-touch list): the visual is a
## plain Sprite2D child added here, after construction.
func _projectile_factory() -> Node:
	var projectile: TowerProjectile = TowerProjectile.new()
	if projectile_texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = projectile_texture
		projectile.add_child(sprite)
	return projectile


func get_current_target() -> Node2D:
	return _current_target


## Typed command (P2.11 modifier layer; see this file's `_damage_multiplier`
## field comment). `multiplier` is the ONE already-summed `(1 + sum of
## bonuses)` value (C-STACK) -- REPLACES the previous multiplier, never
## compounds against it.
func set_damage_multiplier(multiplier: float) -> void:
	_damage_multiplier = multiplier


## Typed command (P2.11 modifier layer). Same replace-not-compound contract,
## applied to targeting range instead of damage (Optics).
func set_range_multiplier(multiplier: float) -> void:
	_range_multiplier = multiplier


## Typed command (D115/D117 pool expansion; Tower Volley). Same
## replace-not-compound contract, applied to fire rate.
func set_fire_rate_multiplier(multiplier: float) -> void:
	_fire_rate_multiplier = multiplier


## Typed query: the base per-shot damage (from `weapon`) times the
## currently-applied upgrade multiplier.
func get_effective_damage_per_shot() -> float:
	return _damage_per_shot * _damage_multiplier


## Typed query: the base targeting range (from `range_px`) times the
## currently-applied upgrade multiplier. Used by _retarget_if_needed()'s two
## EntityRegistry range queries so Optics affects both acquisition and
## retention of a target identically.
func get_effective_range_px() -> float:
	return _range_px * _range_multiplier


func get_damage_multiplier_for_test() -> float:
	return _damage_multiplier


func get_range_multiplier_for_test() -> float:
	return _range_multiplier


func get_fire_rate_multiplier_for_test() -> float:
	return _fire_rate_multiplier


## Typed query: the base fire interval divided by the currently-applied
## fire-rate multiplier -- a HIGHER multiplier means a SHORTER interval,
## matching AutoWeapon.get_effective_fire_interval_seconds()'s identical
## convention.
func get_effective_fire_interval_seconds() -> float:
	return (_fire_interval_seconds / _fire_rate_multiplier) if _fire_rate_multiplier > 0.0 else INF


## Integration task -- mirrors src/combat/auto_weapon.gd's own
## `get_effective_sheet_dps()` exactly (see that file's comment for the
## full reasoning: CombatStats never learns about a Caliber rank once
## reported at configure() time, since `set_damage_multiplier()` does not
## re-report). No fire-rate multiplier exists on this weapon (Optics
## affects range, Caliber affects damage; "no Tower upgrade changes fire
## rate," per `_fire_interval_seconds`'s own comment a few lines above) --
## superseded by Tower Volley (D117); reads the fire-rate-adjusted interval.
func get_effective_sheet_dps() -> float:
	var interval: float = get_effective_fire_interval_seconds()
	return get_effective_damage_per_shot() / interval if interval > 0.0 else 0.0


func _physics_process(_delta: float) -> void:
	if not _configured or _origin == null:
		return
	_retarget_if_needed()
	if _current_target == null:
		return # idle: hold fire, consume nothing -- Register's own wording
	if _now() < _next_fire_allowed_at:
		return
	_fire_at(_current_target)
	_next_fire_allowed_at = _now() + get_effective_fire_interval_seconds() # D117: Tower Volley now also changes fire rate, alongside Caliber (damage) and Optics/Watchtower (range)


## C-TOWERTARGET, transcribed in full in this file's header. Order-
## independent of a caller's incidental call sequence: only category
## membership in `seekers_in_range` / `enemies_in_range` drives the result.
func _retarget_if_needed() -> void:
	var origin_pos: Vector2 = _origin.global_position
	var effective_range: float = get_effective_range_px()
	var seekers_in_range: Array[Node2D] = _registry.get_entities_in_radius(origin_pos, effective_range, SEEKER_TAG)
	var enemies_in_range: Array[Node2D] = _registry.get_entities_in_radius(origin_pos, effective_range, ENEMY_TAG)

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
	projectile.launch(origin_pos, direction * _projectile_speed, get_effective_damage_per_shot(), &"tower", _projectile_lifetime_seconds)
	if _audio_pool != null and fire_sfx != null and _audio_pool.has_method("play"):
		_audio_pool.play(fire_sfx, origin_pos, 0, false, "SFX")
	fired.emit(_now())


func get_pool_for_test() -> Pool:
	return _pool

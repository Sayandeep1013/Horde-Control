extends Node
class_name AutoWeapon

## AutoWeapon (P2.3). MASTER_SDLC.md > Player Overview > "Starting Weapon":
## "The player begins with a handgun (Provisional Default): 10 damage per
## shot at 2 shots per second (20 DPS), range 260 pixels, projectile speed
## 1000 px/s, re-picking the nearest target on every shot." Provisional
## Values Register > Player & Weapons > "Handgun (Starting Weapon)": "10
## dmg/shot, 2 shots/s (20 DPS), range 260 px, nearest re-picked every shot,
## projectile 1000 px/s". Every number above is read from `definition` (a
## WeaponDefinition, e.g. data/weapons/handgun.tres) via configure(), never
## restated as a literal here.
##
## ## No targeting input, by construction
## MASTER_SDLC.md > Movement Design & Input Buffering > Input Buffering
## Rules: "Auto-Fire Targeting: [an] input buffer is strictly banned for
## auto-fire targeting. Target acquisition must be instantaneous and
## frame-perfect based on current position." This file never reads the
## Input singleton at all -- not even to skip buffering it -- because there
## is no aim direction, no fire button, and no target-selection input for
## this weapon to read in the first place (PLAN.md's own exit criterion:
## "no targeting input exists"). Targeting is driven entirely by
## EntityRegistry position queries, exactly like tower_weapon.gd.
##
## ## The pattern mirrored from tower_weapon.gd (P2.4), and the one
## deliberate difference
## src/tower/tower_weapon.gd implements the same overall shape -- pooling,
## the fast-projectile sweep (in its projectile, not here), test-injectable
## Registry/SimClock/CombatStats references, a configure() typed command --
## and is mirrored here. The retarget rule is NOT mirrored, per this task's
## own brief: "The player's retarget rule is different and simpler: the
## Tower holds its target until it dies or leaves range, while the handgun
## re-picks the nearest target every shot." Concretely: TowerWeapon keeps a
## `_current_target` field that PERSISTS across ticks and is only cleared
## when that target dies or leaves range (`_retarget_if_needed()`, called
## every tick regardless of fire readiness). This file holds no such
## persistent target at all -- `_pick_nearest_target()` is called fresh,
## from a live EntityRegistry query, at the exact instant a shot is about
## to be fired, and nowhere else. `_current_target` below is written only
## AT the moment of firing, purely for test introspection (matching
## TowerWeapon's own `get_current_target()` convention) -- it is never read
## back to influence which target the NEXT shot picks.
##
## ## C-AUTOFIRE (Register > Tower > "Tower Console dwell / auto-fire"):
## "player auto-fire disabled at any speed while overlapping the [Tower's
## Interaction] radius; Tower keeps firing." This file exposes
## set_auto_fire_suppressed() as a typed command (docs/20 > "Communication,
## commands") for whichever system observes that overlap to drive. Cross-
## task seam, named rather than silently left unwired: src/tower/
## tower_interaction_radius.gd (P2.4, out of this task's write scope) is
## the real Area2D that detects the overlap and already emits
## `player_entered` / `player_exited` signals, but nothing in this codebase
## yet connects those signals to this weapon's suppression command --
## src/player/player.gd (also out of this task's write scope) would be the
## natural place, or a future integration task that owns both scenes. This
## file's own test (tests/unit/weapon_check_test.gd) drives the command
## directly rather than through that unwired signal path.
##
## ## SimLoop / driven_externally (task instruction, not tower_weapon.gd's
## own precedent -- tower_weapon.gd has neither of these two members).
## docs/20's SimLoop order names step 4 ("weapon targeting and firing
## (player, then Tower)") as the real integration point, but
## src/core/sim_loop.gd's `_step_04_weapon_targeting_and_firing()` is still
## an empty stub and src/core/ is outside this task's write scope (same
## structural gap player.gd's own header names for steps 1-2, and
## tower_weapon.gd's for step 4/5 -- LEDGER F03-09). Exposing
## `physics_step()` and honouring `driven_externally`, exactly as
## src/player/player.gd does, gives whichever future task wires SimLoop a
## uniform seam across both files it must call into for step 4, rather than
## tower_weapon.gd's shape (a bare self-driving `_physics_process()` with no
## such seam) repeating a second time.

signal fired(timestamp: float)

const ENEMY_TAG: StringName = &"enemy"

## Set true by a future SimLoop integration task once sim_loop.gd's step 4
## calls into this weapon directly; while true, this node's own
## `_physics_process()` no-ops so firing is never driven twice in the same
## tick. Defaults false so the weapon fires standalone today, matching
## src/player/player.gd's own `driven_externally` convention.
@export var driven_externally: bool = false

## The typed data contract this weapon reads every tuning value from.
## Defaults to the prototype resource this task authored; swappable per
## instance (a different .tres, for a future weapon evolution) without
## touching this script.
@export var definition: WeaponDefinition = preload("res://data/weapons/handgun.tres")

@export var origin_path: NodePath # the Node2D whose global_position projectiles fire from; defaults to get_parent()
@export var projectiles_container_path: NodePath # optional; null container is tolerated by Pool

## Integration task, docs/25_Asset_Pipeline.md: the cue this weapon plays
## through the existing AudioPool (src/audio/audio_pool.gd) on every shot
## -- never a hardcoded path (D99). Null is tolerated (no sound).
@export var fire_sfx: AudioStream

var _weapon_definition: WeaponDefinition = null
var _range_px: float = 0.0
var _damage_per_shot: float = 0.0
var _fire_interval_seconds: float = 0.0
var _projectile_speed: float = 0.0
var _projectile_lifetime_seconds: float = 0.0

var _origin: Node2D = null
var _current_target: Node2D = null # write-only-at-fire-time; see header
var _next_fire_allowed_at: float = 0.0
var _configured: bool = false

## C-AUTOFIRE. See this file's header. Never set by this file's own logic --
## only by set_auto_fire_suppressed(), a typed command an external caller
## (in the prototype, whatever wires tower_interaction_radius.gd's signals)
## drives.
var _auto_fire_suppressed: bool = false

var _pool: Pool = null

## Test-injectable references, matching this project's convention.
var _registry: Node = null
var _clock: Node = null
var _combat_stats: Node = null

## Integration task: the AudioPool this weapon plays `fire_sfx` through --
## optional, never a second/duplicate pool. Same convention as
## src/tower/tower_weapon.gd's own `_audio_pool`.
var _audio_pool: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_registry = EntityRegistry
	_clock = SimClock
	_combat_stats = CombatStats
	_origin = get_node_or_null(origin_path) as Node2D
	if _origin == null:
		_origin = get_parent() as Node2D
	if definition != null:
		configure(definition)
	_check_starting_weapon_reference_id()


func set_registry_for_test(registry: Node) -> void:
	_registry = registry


func set_sim_clock_for_test(clock: Node) -> void:
	_clock = clock


func set_combat_stats_for_test(stats: Node) -> void:
	_combat_stats = stats


## Typed command (integration task): wires the shared AudioPool `fire_sfx`
## plays through. Also usable directly from a test.
func set_audio_pool_ref(pool: Node) -> void:
	_audio_pool = pool


func _now() -> float:
	return _clock.now if _clock != null else 0.0


## Typed command: applies the Register's numbers, read from `weapon` (a
## WeaponDefinition, e.g. data/weapons/handgun.tres), and builds this
## weapon's projectile pool. Must run before this weapon can fire. Unlike
## tower_weapon.gd's configure(weapon, range_px), this file takes no second
## range parameter: PlayerDefinition has no TargetingRuleParameters-style
## struct the way TowerDefinition does, and the Register states exactly one
## range figure for the Handgun -- `weapon.effective_range_px` (the Weapon
## Definition Contract's own field) IS that figure, read directly rather
## than duplicated onto a second struct with no Register row of its own.
func configure(weapon: WeaponDefinition) -> void:
	assert(weapon != null, "AutoWeapon.configure() requires a WeaponDefinition")
	assert(weapon.engagement_rhythm != null, "WeaponDefinition.engagement_rhythm is required")
	assert(weapon.damage_band != null, "WeaponDefinition.damage_band is required")
	assert(weapon.projectile_definition != null, "WeaponDefinition.projectile_definition is required")
	_weapon_definition = weapon
	_range_px = float(weapon.effective_range_px)
	_damage_per_shot = float(weapon.damage_band.value)
	var fire_rate: float = weapon.engagement_rhythm.fire_rate_per_second
	_fire_interval_seconds = (1.0 / fire_rate) if fire_rate > 0.0 else INF
	_projectile_speed = float(weapon.projectile_definition.speed_px_per_second)
	_projectile_lifetime_seconds = weapon.projectile_definition.lifetime_seconds
	_next_fire_allowed_at = _now()
	var container: Node = get_node_or_null(projectiles_container_path) if projectiles_container_path != NodePath() else null
	_pool = Pool.new(_projectile_factory, container, EntityCaps.MAX_PROJECTILES, Pool.OverflowPolicy.RECYCLE_OLDEST)
	if _combat_stats != null:
		_combat_stats.report_sheet_dps(&"player", _combat_stats.sheet_dps_from_weapon(weapon))
	_configured = true


static func _projectile_factory() -> Node:
	return PlayerProjectile.new()


func get_current_target() -> Node2D:
	return _current_target


func is_auto_fire_suppressed() -> bool:
	return _auto_fire_suppressed


## Typed command (C-AUTOFIRE; docs/20 > "Communication, commands"). See this
## file's header for the cross-task seam this drives.
func set_auto_fire_suppressed(suppressed: bool) -> void:
	_auto_fire_suppressed = suppressed


func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


## The per-tick logic docs/20 > SimLoop order names as (part of) step 4
## ("weapon targeting and firing (player, then Tower)") for this weapon.
## Public so a future SimLoop integration can call it directly once
## `driven_externally` is set true (see this file's header).
func physics_step(_delta: float) -> void:
	if not _configured or _origin == null:
		return
	if _auto_fire_suppressed:
		return # C-AUTOFIRE -- consumes nothing, exactly like Tower's own idle wording
	if _now() < _next_fire_allowed_at:
		return
	var target: Node2D = _pick_nearest_target()
	if target == null:
		_current_target = null
		return # no target in range -- hold fire, consume nothing
	_current_target = target
	_fire_at(target)
	_next_fire_allowed_at = _now() + _fire_interval_seconds


## Register: "nearest re-picked every shot" (Provisional Values Register >
## Player & Weapons > "Handgun (Starting Weapon)"). Called ONLY from
## physics_step(), at the instant a shot is about to fire -- never cached,
## never consulted by anything that would make yesterday's (or even one
## tick ago's) pick influence this one. This is the entire retarget rule;
## there is no separate "keep unless X" branch to accidentally omit or
## mis-port from tower_weapon.gd's _retarget_if_needed().
func _pick_nearest_target() -> Node2D:
	var origin_pos: Vector2 = _origin.global_position
	var enemies_in_range: Array[Node2D] = _registry.get_entities_in_radius(origin_pos, _range_px, ENEMY_TAG)
	return _nearest(origin_pos, enemies_in_range)


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
	var projectile: PlayerProjectile = _pool.acquire() as PlayerProjectile
	if projectile == null:
		return # pool at cap under THROTTLE-equivalent conditions -- RECYCLE_OLDEST means this should not happen, but never crash if it does
	# Projectile Orphans (docs/20): source resolved BY VALUE, never a live
	# Node reference to this weapon's owner -- see player_projectile.gd's
	# header.
	projectile.launch(origin_pos, direction * _projectile_speed, _damage_per_shot, &"player", _projectile_lifetime_seconds)
	if _audio_pool != null and fire_sfx != null and _audio_pool.has_method("play"):
		_audio_pool.play(fire_sfx, origin_pos, 0, false, "SFX")
	fired.emit(_now())


## Read-only consistency check against F03-09's other half (data/player/
## prototype.tres's `starting_weapon_reference_id`). Never writes anything
## on the Player -- src/player/player.gd is outside this task's write scope
## -- purely a push_warning() cross-check on mismatch, matching tower.gd's
## own precedent for base_weapon_reference_id (see this task's evidence
## report, "Cross-task seams").
func _check_starting_weapon_reference_id() -> void:
	if _weapon_definition == null:
		return
	var player: Player = get_parent() as Player
	if player == null or player.definition == null:
		return
	var expected_id: String = player.definition.starting_weapon_reference_id
	if expected_id != "" and expected_id != _weapon_definition.unique_id:
		push_warning("AutoWeapon: parent Player's starting_weapon_reference_id '%s' does not match the assigned WeaponDefinition's unique_id '%s'" % [expected_id, _weapon_definition.unique_id])


func get_pool_for_test() -> Pool:
	return _pool

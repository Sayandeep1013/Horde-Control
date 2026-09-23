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

## P2.11 modifier layer (src/upgrade/upgrade_system.gd). Multiplies the BASE
## per-shot damage / fire rate computed from `definition` in configure()
## above -- `_damage_per_shot` and `_fire_interval_seconds` are never
## rewritten by an upgrade; only these two multipliers change, and only
## get_effective_damage_per_shot() / get_effective_fire_interval_seconds()
## combine them with the base at the point of use. This keeps
## data/weapons/handgun.tres (owned by P2.3) and this weapon's own
## definition-derived base values byte-identical no matter how many Rapid
## Fire / Heavy Rounds ranks are applied.
##
## MASTER_SDLC.md > Progression Edge Cases > "Percentage bonuses to the same
## stat stack" (C-STACK): "stat = base x (1 + sum of bonuses)". Each
## multiplier here IS that one already-summed `(1 + sum of bonuses)` value
## -- src/upgrade/upgrade_system.gd computes the sum from the upgrade's
## current shared rank and pushes the single combined result through
## set_damage_multiplier()/set_fire_rate_multiplier() on every apply_rank()
## call; this file never sums bonuses itself and never compounds multiple
## calls (each call REPLACES the multiplier, it does not multiply it again).
var _damage_multiplier: float = 1.0
var _fire_rate_multiplier: float = 1.0

## D115/D117 pool expansion, both UNLOCK cards. `_pierce_bonus` (Piercing
## Arrows, +1 pierce/rank) is handed to every projectile via `launch()`'s
## new `pierce_count` parameter. `_multishot_extra` (Multishot, +1 arrow/
## rank at 70% damage, spread) fires that many EXTRA projectiles per shot,
## each at `MULTISHOT_DAMAGE_FRACTION` of the effective damage, fanned
## symmetrically around the primary target direction -- the primary shot
## (the existing behaviour) is unaffected and still fires at full damage
## straight at the target.
var _pierce_bonus: int = 0
var _multishot_extra: int = 0
## Fixed by the card's own spec ("at 70% damage"), not a Register row of
## its own -- named here beside the field it scales rather than invented as
## a second exported tunable no design document asks for.
const MULTISHOT_DAMAGE_FRACTION: float = 0.7
## Angular spread between adjacent multishot projectiles, degrees. A
## framework/feel constant (not a Register number), chosen so the fan reads
## as a spread rather than an overlapping stack at this weapon's 260 px
## range.
const MULTISHOT_SPREAD_DEGREES: float = 8.0

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


## Typed command (P2.11 modifier layer; see the field comment above this
## file's `_damage_multiplier` declaration). `multiplier` is the ONE
## already-summed `(1 + sum of bonuses)` value (C-STACK) -- REPLACES the
## previous multiplier, never compounds against it.
func set_damage_multiplier(multiplier: float) -> void:
	_damage_multiplier = multiplier


## Typed command (P2.11 modifier layer). Same replace-not-compound contract
## as set_damage_multiplier() above, applied to fire rate instead of damage.
func set_fire_rate_multiplier(multiplier: float) -> void:
	_fire_rate_multiplier = multiplier


## Typed query: the base per-shot damage (from `definition`) times the
## currently-applied upgrade multiplier, computed fresh on every call so it
## can never drift from `_damage_multiplier`'s current value.
func get_effective_damage_per_shot() -> float:
	return _damage_per_shot * _damage_multiplier


## Typed query: the base fire interval (from `definition`) divided by the
## currently-applied upgrade fire-rate multiplier -- a HIGHER multiplier
## means a SHORTER interval (faster fire rate), matching "+20% fire
## rate/rank" naming exactly (Rapid Fire increases the multiplier, which
## must decrease this interval, not increase it).
func get_effective_fire_interval_seconds() -> float:
	return (_fire_interval_seconds / _fire_rate_multiplier) if _fire_rate_multiplier > 0.0 else INF


func get_damage_multiplier_for_test() -> float:
	return _damage_multiplier


func get_fire_rate_multiplier_for_test() -> float:
	return _fire_rate_multiplier


## Typed command (Piercing Arrows). `bonus` is the upgrade's own already-
## summed total across every rank held (0 = the unranked default: no
## piercing, matching PlayerProjectile's own "no piercing: one target per
## shot" default).
func set_pierce_bonus(bonus: int) -> void:
	_pierce_bonus = maxi(0, bonus)


func get_pierce_bonus_for_test() -> int:
	return _pierce_bonus


## Typed command (Multishot). `extra_count` is the number of ADDITIONAL
## projectiles fired per shot, beyond the primary one.
func set_multishot_extra_count(extra_count: int) -> void:
	_multishot_extra = maxi(0, extra_count)


func get_multishot_extra_count_for_test() -> int:
	return _multishot_extra


## Integration task (P2.9's own capacity seam; evidence/p29_report.md,
## "The capacity seam the orchestrator must wire to the upgrade system").
## Live, upgrade-aware sheet DPS -- CombatStats.sheet_dps_from_weapon()'s
## own formula (damage / interval), computed from the CURRENT effective
## values rather than the ones reported to CombatStats at configure() time.
## `set_damage_multiplier()`/`set_fire_rate_multiplier()` (P2.11's own
## modifier layer) do not themselves re-report to CombatStats, so
## CombatStats.get_sheet_dps(&"player") silently stays at the pre-upgrade
## base figure forever -- verified, not assumed, in
## evidence/integration_report.md. This is the Callable
## `WaveDirector.set_player_capacity_provider()` is wired to, so the
## Pressure Metric's Capacity term (and Siege sizing) reflects a ranked-up
## weapon instead of always reading the base handgun.
func get_effective_sheet_dps() -> float:
	var interval: float = get_effective_fire_interval_seconds()
	return get_effective_damage_per_shot() / interval if interval > 0.0 else 0.0


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
	_next_fire_allowed_at = _now() + get_effective_fire_interval_seconds()


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
	_launch_one(origin_pos, direction, get_effective_damage_per_shot())
	# Multishot (D117): extra projectiles fanned symmetrically around the
	# primary direction, each at MULTISHOT_DAMAGE_FRACTION -- the primary
	# shot above is unaffected. Fan order (for N extra shots): alternating
	# +/- (i+1) half-steps so the set is symmetric around the primary
	# direction for both even and odd counts.
	var multishot_damage: float = get_effective_damage_per_shot() * MULTISHOT_DAMAGE_FRACTION
	for i in _multishot_extra:
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var step: float = float(i / 2 + 1)
		var angle_offset: float = deg_to_rad(MULTISHOT_SPREAD_DEGREES * step * side)
		_launch_one(origin_pos, direction.rotated(angle_offset), multishot_damage)
	if _audio_pool != null and fire_sfx != null and _audio_pool.has_method("play"):
		_audio_pool.play(fire_sfx, origin_pos, 0, false, "SFX")
	fired.emit(_now())


## D115/D117 pool expansion: factored out of `_fire_at()` so the primary
## shot and every Multishot extra go through the identical pool-acquire/
## launch/pierce path.
func _launch_one(origin_pos: Vector2, direction: Vector2, damage: float) -> void:
	var projectile: PlayerProjectile = _pool.acquire() as PlayerProjectile
	if projectile == null:
		return # pool at cap under THROTTLE-equivalent conditions -- RECYCLE_OLDEST means this should not happen, but never crash if it does
	# Projectile Orphans (docs/20): source resolved BY VALUE, never a live
	# Node reference to this weapon's owner -- see player_projectile.gd's
	# header.
	projectile.launch(origin_pos, direction * _projectile_speed, damage, &"player", _projectile_lifetime_seconds, _pierce_bonus)


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

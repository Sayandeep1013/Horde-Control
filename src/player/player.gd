extends CharacterBody2D
class_name Player

## Player Controller (Phase 03, P2.1; phases/PHASE_03_Core_Entities_And_
## Feel_Check/PLAN.md > P2.1: "Inputs: movement, acceleration/stop times,
## health, hurtbox, input buffer, contact damage receipt, death (dash and
## weapons excluded)"). Values below are read from `definition` (a
## PlayerDefinition .tres, `data/player/prototype.tres` by default) at
## _ready(), never hardcoded -- CLAUDE.md: "the whole project is
## data-driven; a hardcoded speed is a defect."
##
## Register citations (MASTER_SDLC.md > Provisional Values Register >
## Player & Weapons), read from `definition`, never restated as literals in
## this file's logic:
##   - "Player health / speed / accel / stop": max_health, base_speed_px_
##     per_second, acceleration_time_seconds, deceleration_time_seconds.
##   - "Player body / hurtbox / collector / magnet": body_radius_px,
##     hurtbox_definition (SameAsBody), collector_area_radius_px,
##     magnet_radius_px (magnet_radius_px is authored on the .tres for the
##     future pickup system, docs 16/P2.8, to read -- this controller does
##     not implement magnet behaviour itself, out of this task's scope).
##   - "Input buffer": definition.input_buffer (duration_ms=100, ticks=6).
## z_index (20) is a separate Register row (> Readability: "draw order
## z_index: ... the play layer 20 (player, Tower, and enemies, Y-sorted
## together) ..." -- Author decision D119, 2026-09-23, replacing the
## player's own earlier fixed band of 50), not a PlayerDefinition Contract
## field, so it is set directly on this scene's root node rather than read
## from the resource -- named here since it is a Register number with no
## contract field to carry it. `z_as_relative` is left at its Node2D
## default (true), deliberately: it must ACCUMULATE through whatever
## y_sort-enabled ancestor the player is nested under at runtime
## (scenes/main.tscn's own `Main` root sets `y_sort_enabled = true`), so the
## player lands at the SAME effective z_index as the Tower and every enemy
## and is reordered against them by Y-sort instead of by a fixed hierarchy
## -- see scenes/player.tscn's own `OverheadBar` node for the always-
## visible health/XP bars that now occupy the freed z_index 50 band
## instead.
##
## ## SimLoop / scenes/main.tscn wiring gap (named, not silently resolved)
## docs/20 > "SimLoop order" assigns step 1 (input) and step 2 (player
## movement) to this controller, and src/core/sim_loop.gd's own header
## states plainly: "entities do not run their own gameplay _physics_
## process" -- gameplay is meant to be driven by SimLoop calling into typed
## per-entity methods, not by each entity's own engine callback.
## sim_loop.gd's step 2 (`_step_02_player_movement`) is still an empty stub
## commented "P2.1", and scenes/main.tscn has no Player node yet (confirmed
## by tests/unit/main_scene_structure_test.gd's own
## `test_player_would_not_be_placed_inside_entities_container`, whose
## comment reads "No Player node exists yet (P2.1)"). Both files are outside
## this task's allowed write paths (src/core/, scenes/main.tscn are both
## off limits per this task's hard constraints; P2.2 and P2.4 own the only
## other in-flight edits to the gameplay root, and neither owns SimLoop
## either), so this task cannot perform that wiring itself.
##
## This controller therefore drives its own per-tick logic through
## `_physics_process()` by default, calling the exact same methods
## (`_read_input_step()`, `_movement_step()`) a future SimLoop integration
## would call instead. `driven_externally`, if set true by whoever performs
## that integration, turns off the local `_physics_process` call so SimLoop
## becomes the only driver -- the two per-tick methods do not change either
## way. This is recorded here and in the P2.1 evidence report as a
## dependency this task does not resolve, not a silent workaround.

## Set true by a future SimLoop integration task once sim_loop.gd's step 1/2
## call into this controller directly; while true, this node's own
## `_physics_process()` no-ops so movement is never driven twice in the same
## tick. Defaults false so the controller is playable and testable standalone
## today (see header, "SimLoop / scenes/main.tscn wiring gap").
@export var driven_externally: bool = false

## The typed data contract this controller reads every tuning value from.
## Defaults to the prototype resource this task authored; swappable per
## instance (a different .tres) without touching this script.
@export var definition: PlayerDefinition = preload("res://data/player/prototype.tres")

@export var body_shape_path: NodePath = NodePath("BodyShape")
@export var hurtbox_path: NodePath = NodePath("Hurtbox")
@export var hurtbox_shape_path: NodePath = NodePath("Hurtbox/HurtboxShape")
@export var collector_path: NodePath = NodePath("Collector")
@export var collector_shape_path: NodePath = NodePath("Collector/CollectorShape")
@export var death_state_path: NodePath = NodePath("DeathState")
@export var animator_path: NodePath = NodePath("Visuals")

## Art session (visuals only, no targeting/fire-rate change): the sibling
## AutoWeapon node this controller listens to purely to drive the shoot
## animation -- see `_on_weapon_fired()` below. Not read by any gameplay
## logic in this file.
@export var weapon_path: NodePath = NodePath("AutoWeapon")

var hurtbox: Hurtbox = null
var collector: PlayerCollector = null
var death_state: DeathState = null
var _animator: PlayerAnimator = null
var _weapon: AutoWeapon = null

## The controller's own persistent velocity accumulator, BEFORE SimClock.
## time_scale is applied. MASTER_SDLC.md > Global Simulation Authority:
## "movers multiply their velocity by SimClock.time_scale before moving" --
## read literally, only the value handed to move_and_slide() (this body's
## `velocity` property) is scaled; the acceleration/deceleration ramp itself
## integrates against this unscaled accumulator every tick so a later
## slow-motion effect (always time_scale == 1.0 in the prototype, per
## SimClock's own header) cannot compound across ticks by feeding an
## already-scaled value back into next tick's move_toward() base.
var _local_velocity: Vector2 = Vector2.ZERO

var _acceleration_rate_px_per_s2: float = 0.0
var _deceleration_rate_px_per_s2: float = 0.0

## D115/D117 pool expansion modifier layer (src/upgrade/upgrade_system.gd),
## mirroring AutoWeapon's own `_damage_multiplier` field comment exactly:
## `definition.base_speed_px_per_second` is never rewritten by an upgrade;
## only this multiplier changes, applied fresh every `_movement_step()`
## call (Swift Feet). REPLACES the previous value, never compounds.
var _speed_multiplier: float = 1.0
## v1.0 arena Haste boon (Register "v1.0 Arena Interactables"): separate factors so the
## absolute Draft/meta setters above never overwrite them (they multiply).
var _boon_speed_multiplier: float = 1.0
var _boon_dash_recharge_multiplier: float = 1.0

## Vitality (+15% max health and heal that amount). `_base_max_health` is
## the definition-derived value `_apply_definition()` set, untouched by
## this bonus, so the bonus recomputes fresh from an unmoving base every
## time (same shape as TowerHealth.set_bonus_max_health_fraction()).
var _base_max_health: float = 0.0
var _max_health_bonus_fraction: float = 0.0

## Magnet (+25% pickup radius/rank). PickupSystem._resolve_magnet_radius_px()
## reads get_effective_magnet_radius_px() below rather than
## `definition.magnet_radius_px` directly, so this upgrade never mutates
## the (possibly SHARED) PlayerDefinition resource -- resource-pattern
## skill's own anti-pattern warning.
var _magnet_radius_multiplier: float = 1.0

## Regeneration (heal 1% max health per second per rank, stacks). A plain
## fraction-per-second, ticked in physics_step() below -- the one upgrade
## in this pool with genuine per-tick behaviour, which is why it lives on
## Player (a Node) rather than in UpgradeSystem itself (that file's own
## header: "No per-tick work of any kind lives in this file").
var _regen_fraction_per_second: float = 0.0

## Input buffer state (Register > "Input buffer": 100 ms / 6 ticks, cleared
## on pause). See "Input buffer scope" below for why this does NOT feed back
## into `_local_velocity`.
var _buffered_direction: Vector2 = Vector2.ZERO
var _buffer_expires_at_sim_time: float = -INF
var _buffer_duration_seconds: float = 0.1 # overwritten from definition.input_buffer at _ready()

## Sentinel meaning "no override -- read the real Input singleton".
## Vector2.INF can never be a legitimate normalized direction.
var _test_input_override: Vector2 = Vector2.INF

## Test-only injection point (naming/pattern convention matches
## entity_spawner.gd's and death_state.gd's own `set_registry_for_test`):
## overrides the EntityRegistry this controller registers/updates against,
## so a test suite never touches the real Autoload singleton. Never used by
## gameplay code.
var _registry: Node = null

## Integration task, docs/25_Asset_Pipeline.md: the cue played through the
## existing AudioPool on player damage. docs/20 > "Audio Mixing & Dynamic
## Ducking" routes player damage to SFX_Priority (never ducks), so this is
## played as a priority voice on that bus, not the ordinary SFX default --
## still through the one shared AudioPool, never a second/duplicate pool.
@export var damage_sfx: AudioStream
var _audio_pool: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"player") # v1.0 (docs/31 §10): HUD / Battle Skill / ability nodes find the player by group
	z_index = 20 # Register > Readability: the shared play-layer band, Y-sorted with the Tower and enemies (Author decision D119)
	# No src/core/pool.gd `pool_body` group membership: unlike enemies,
	# pickups, projectiles, and effects (src/core/entity_spawner.gd's six
	# pools), the player is never acquired through Pool.acquire() -- there
	# is one persistent instance, not a spawn/despawn cycle -- so there is
	# no baseline snapshot for that group membership to ever be read back.
	collision_layer = CollisionLayers.LAYER_PLAYER_BODY
	collision_mask = CollisionLayers.MASK_PLAYER_BODY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING # top-down: no floor/gravity concept for the player to snap or slide against

	hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	collector = get_node_or_null(collector_path) as PlayerCollector
	death_state = get_node_or_null(death_state_path) as DeathState
	_animator = get_node_or_null(animator_path) as PlayerAnimator
	_weapon = get_node_or_null(weapon_path) as AutoWeapon

	if hurtbox != null:
		hurtbox.damage_received.connect(_on_hurtbox_damage_received)

	# Art session: cosmetic-only wiring so the animator knows WHEN a shot
	# fires and WHICH direction to aim the shoot pose in. AutoWeapon's own
	# retarget/fire-rate/damage logic (src/combat/auto_weapon.gd) is
	# untouched -- this only reads its `fired` signal and its existing
	# get_current_target()/get_effective_fire_interval_seconds() queries.
	if _weapon != null:
		_weapon.fired.connect(_on_weapon_fired)

	# Art session: lets the animator play something on death (flash + fade +
	# the Dead.png skull) without this file or death_state.gd changing WHEN
	# death happens or how long its own Visual Death window lasts --
	# death_state.visual_death_duration is read, never restated.
	if death_state != null:
		death_state.logical_death.connect(_on_logical_death)

	# Guarded (not an unconditional overwrite): this controller registers
	# itself with the registry at the end of THIS SAME _ready() call, below
	# -- unlike death_state.gd/entity_spawner.gd's own set_registry_for_test
	# seams (only ever consulted later, when a method actually needs the
	# registry), a test that wants that registration to land on a throwaway
	# instance must be able to call set_registry_for_test() BEFORE add_child
	# ever runs _ready(). The guard makes that pre-ready injection stick
	# instead of being clobbered here, while still defaulting to the real
	# Autoload for every caller that never calls the test seam at all.
	if _registry == null:
		_registry = EntityRegistry
	_apply_definition()

	if _registry != null:
		_registry.register_entity(self, global_position, [&"player"])


func _exit_tree() -> void:
	if _registry != null and _registry.is_registered(self):
		_registry.deregister_entity(self)


## Re-applies every tuning value from `definition` to this scene's live
## nodes. Called from _ready(); also callable again if `definition` is
## swapped at runtime (not done anywhere in the prototype, but a controller
## that only reads its data contract once would silently stop being
## data-driven the moment a caller changed `definition` after spawn).
func _apply_definition() -> void:
	if definition == null:
		push_error("Player: definition (PlayerDefinition) is null -- nothing to read Register values from")
		return

	var body_shape: CollisionShape2D = get_node_or_null(body_shape_path) as CollisionShape2D
	if body_shape != null and body_shape.shape is CircleShape2D:
		(body_shape.shape as CircleShape2D).radius = float(definition.body_radius_px)

	# hurtbox_definition's only member is SameAsBody (src/data/contract_
	# enums.gd) -- the hurtbox radius always mirrors the body radius, so
	# there is no branch to write for a second enum member that does not
	# exist.
	var hurtbox_shape: CollisionShape2D = get_node_or_null(hurtbox_shape_path) as CollisionShape2D
	if hurtbox_shape != null and hurtbox_shape.shape is CircleShape2D:
		(hurtbox_shape.shape as CircleShape2D).radius = float(definition.body_radius_px)

	var collector_shape: CollisionShape2D = get_node_or_null(collector_shape_path) as CollisionShape2D
	if collector_shape != null and collector_shape.shape is CircleShape2D:
		(collector_shape.shape as CircleShape2D).radius = float(definition.collector_area_radius_px)

	if definition.acceleration_time_seconds > 0.0:
		_acceleration_rate_px_per_s2 = definition.base_speed_px_per_second / definition.acceleration_time_seconds
	else:
		_acceleration_rate_px_per_s2 = INF # instant, degenerate config -- named rather than dividing by zero
	if definition.deceleration_time_seconds > 0.0:
		_deceleration_rate_px_per_s2 = definition.base_speed_px_per_second / definition.deceleration_time_seconds
	else:
		_deceleration_rate_px_per_s2 = INF

	if definition.input_buffer != null:
		_buffer_duration_seconds = definition.input_buffer.duration_ms / 1000.0

	if death_state != null:
		_base_max_health = float(definition.max_health)
		death_state.max_hp = _base_max_health
		# death_state._ready() already ran (children ready before their
		# parent) and set current_hp from its own framework default (30.0)
		# before the line above overwrote max_hp -- reset_for_reuse() is the
		# framework's own public re-initialize entry point (death_state.gd
		# header) and is used here for exactly that: resync current_hp to
		# the Register-sourced max_hp that just landed, regardless of ready
		# order, without this file reaching into death_state's private
		# state directly (Communication, commands: writing another system's
		# fields directly is banned even through a bare setter).
		death_state.reset_for_reuse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		clear_input_buffer()


func _physics_process(delta: float) -> void:
	if driven_externally:
		return
	physics_step(delta)


## The per-tick logic docs/20 > SimLoop order names as steps 1 ("input") and
## 2 ("player movement") for this controller. Public so a future SimLoop
## integration can call it directly once `driven_externally` is set true
## (see this file's header).
func physics_step(delta: float) -> void:
	var raw_direction: Vector2 = _raw_input_direction()
	_update_input_buffer(raw_direction)
	_dash_step(raw_direction)
	_movement_step(delta, raw_direction)
	_regen_step(delta)
	_focus_step(delta, raw_direction)
	if _animator != null:
		_animator.update_visuals(delta, _local_velocity, definition.base_speed_px_per_second if definition != null else 0.0)


## D115/D117 pool expansion: Regeneration (heal 1% max health per second per
## rank, stacks). A no-op at the default 0.0 fraction, matching every other
## upgrade field's "never taken changes nothing" convention.
func _regen_step(delta: float) -> void:
	if _regen_fraction_per_second <= 0.0 or death_state == null or death_state.is_dead:
		return
	heal(death_state.max_hp * _regen_fraction_per_second * delta)


func _raw_input_direction() -> Vector2:
	if _test_input_override != Vector2.INF:
		return _test_input_override
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## Eight-direction movement (Input.get_vector normalizes diagonals to the
## same magnitude as a cardinal press, so a diagonal hold reaches the same
## top speed as a straight one, never faster). Constant acceleration toward
## the target velocity (move_toward at a fixed rate) rather than an
## exponential ease, so the Register's "full speed in 0.08 s" / "stop in
## 0.05 s" are exact times-to-reach, not asymptotes a curve only approaches
## -- move_toward() clamps to the target the instant a step would overshoot
## it, matching "reaches exactly the Register's reference speed."
##
## Input buffer scope (see this file's header field comment on
## `_buffered_direction`): the buffered direction never substitutes for
## `raw_direction` here. MASTER_SDLC.md > Movement Design & Input Buffering
## describes the buffer as letting a press that arrives "slightly before a
## cooldown ends or before a phase movement upgrade finishes" queue rather
## than being lost -- a QUEUE-AHEAD pattern for a gated discrete action.
## Dash and phase movement are explicitly excluded from this task's scope
## (PLAN.md P2.1 row), and plain directional movement has no cooldown/gate
## for a press to queue against: `Input.get_vector()` polling every physics
## tick cannot "eat" a held direction the way a discrete `is_action_just_
## pressed()` check at a low tick rate can (input-handling skill's own
## pitfall table). Feeding the buffered direction back into movement after
## a real key release would instead read as unwanted coasting, directly
## contradicting "Base movement must feel responsive with minimal
## acceleration ramp" (Movement Design & Input Buffering, paragraph 1). The
## buffer is therefore implemented as real, running, pause-cleared state
## (`get_buffered_movement_direction()` below is a typed query) ready for a
## future Dash system to consume, without altering this task's own
## acceleration/deceleration curve. Named here and in the evidence report as
## an interpretation, not a restatement of an explicit rule.
func _movement_step(delta: float, raw_direction: Vector2) -> void:
	if definition == null:
		return
	if _dash_active:
		# v1.0 Dash: a fixed-speed burst overrides the ramp; the exit velocity
		# is seeded at base speed so the stop is not a hard snap.
		_local_velocity = _dash_direction * definition.base_speed_px_per_second * _speed_multiplier * _boon_speed_multiplier
		velocity = _dash_direction * (DASH_DISTANCE_PX / DASH_DURATION_SECONDS) * SimClock.time_scale
		move_and_slide()
		if _registry != null:
			_registry.update_position(self, global_position)
		return
	var target_velocity: Vector2 = raw_direction * definition.base_speed_px_per_second * _speed_multiplier * _boon_speed_multiplier
	var rate: float = _acceleration_rate_px_per_s2 if target_velocity != Vector2.ZERO else _deceleration_rate_px_per_s2
	_local_velocity = _local_velocity.move_toward(target_velocity, rate * delta)

	# Global Simulation Authority: "movers multiply their velocity by
	# SimClock.time_scale before moving." Always 1.0 in the prototype
	# (SimClock's own header), applied unconditionally so a later slow-
	# motion effect cannot bypass it by this controller having skipped the
	# multiply while time_scale was never anything but 1.0 during
	# development.
	velocity = _local_velocity * SimClock.time_scale
	move_and_slide()

	if _registry != null:
		_registry.update_position(self, global_position)


func _update_input_buffer(raw_direction: Vector2) -> void:
	if raw_direction != Vector2.ZERO:
		_buffered_direction = raw_direction
		_buffer_expires_at_sim_time = SimClock.now + _buffer_duration_seconds
	elif SimClock.now >= _buffer_expires_at_sim_time:
		_buffered_direction = Vector2.ZERO


## Typed query (docs/20 > Communication, queries). The buffered directional
## intent, or Vector2.ZERO once it has expired (Register: 100 ms / 6 ticks)
## or been cleared by a pause. No consumer exists yet in the prototype (see
## _movement_step()'s header comment) -- this is the seam a future Dash
## system reads instead of re-deriving its own buffer.
func get_buffered_movement_direction() -> Vector2:
	if SimClock.now < _buffer_expires_at_sim_time:
		return _buffered_direction
	return Vector2.ZERO


## Typed command. Cleared on pause (Register > "Input buffer": "cleared on
## pause"), called from `_notification(NOTIFICATION_PAUSED)` above --
## Godot delivers that notification to every node whose own processing
## state changes because of the pause (this node is PROCESS_MODE_PAUSABLE),
## with no polling or PauseAuthority reference needed on this file's part.
func clear_input_buffer() -> void:
	_buffered_direction = Vector2.ZERO
	_buffer_expires_at_sim_time = -INF


## Meta layer core (Second Wind seam). Was previously cosmetic-only
## (hit-flash/blood/SFX): actual damage application was auto-wired by
## DeathState itself, via scenes/player.tscn's `DeathState.hurtbox_paths =
## [../Hurtbox]`, connecting DIRECTLY to `death_state.apply_damage()` with
## no interception point -- exactly the "double-damage problem"
## src/tower/tower_health.gd's own header already documents and solves for
## the Tower. Second Wind needs to intercept a LETHAL hit before it reaches
## death_state.apply_damage() (see this file's own `apply_damage()` header),
## so scenes/player.tscn's `hurtbox_paths` is now EMPTY (mirroring
## tower.tscn's Hurtbox) and this handler -- already connected to the real
## Hurtbox's `damage_received` signal in `_ready()` -- now ALSO calls this
## file's own `apply_damage()`, once, after the cosmetic feedback below.
## Every existing caller/test observes the exact same end state
## (death_state.current_hp decreases by the same amount) since
## `apply_damage()` falls through to `death_state.apply_damage(amount,
## source)` unchanged whenever Second Wind is not both available and the
## hit lethal.
func _on_hurtbox_damage_received(amount: float, source: Variant, _hitbox: Node) -> void:
	if _animator != null:
		_animator.play_hit_flash()
	# Hit-feedback pass (restrained per brief -- a small burst only, no
	# ground splat trailing the player around the arena; see
	# src/fx/blood_fx.gd's own header for why this is not a seventh
	# EntitySpawner budget category). The player is not a child of
	# `Entities` (docs/20 > Scene Tree), so its own parent -- the gameplay
	# root -- is the container to spawn into, matching every other cosmetic
	# FX spawn in this project (enemy_animator.gd's `_spawn_death_fx()`
	# uses the exact same "spawn into my own parent" convention).
	var dir: Vector2 = BloodFx.direction_away_from(source, global_position)
	BloodFx.spawn_hit(get_parent(), global_position, dir, BloodFx.Tier.PLAYER)
	if _audio_pool != null and damage_sfx != null and _audio_pool.has_method("play"):
		# docs/20 > Audio Mixing & Dynamic Ducking: "Player damage ... routed
		# to SFX_Priority" -- a priority voice, not the ordinary SFX default.
		_audio_pool.play(damage_sfx, global_position, 10, true, "SFX_Priority")
	apply_damage(amount, source)


## Art session: AutoWeapon.fired only carries a timestamp (auto_weapon.gd's
## own signal signature), so the aim direction is derived here from the
## SAME target that weapon has already committed to firing at
## (get_current_target() is written immediately before fired.emit() in
## _fire_at() -- see that file's header on `_current_target` being
## write-only-at-fire-time). The fire interval is read live from the weapon
## (get_effective_fire_interval_seconds(), P2.11's upgrade-aware query) so a
## Rapid Fire rank changes the animation's pacing exactly the way it changes
## the real fire rate, never a restated literal.
func _on_weapon_fired(_timestamp: float) -> void:
	if _weapon == null or _animator == null:
		return
	var target: Node2D = _weapon.get_current_target()
	if target == null or not is_instance_valid(target):
		return
	var direction: Vector2 = target.global_position - global_position
	if direction.length_squared() <= 0.0001:
		return
	_animator.play_shoot(direction.normalized(), _weapon.get_effective_fire_interval_seconds())


## Art session: death_state.gd (outside this task's write scope) owns
## Logical/Visual Death timing entirely -- this only hands the animator the
## SAME visual_death_duration death_state already timed its own window to,
## so the visual finishes exactly when the logical window does.
##
## Meta layer core (Second Wind seam): `scenes/player.tscn`'s
## `DeathState.hurtbox_paths` is now EMPTY (see this file's own
## `_on_hurtbox_damage_received()` header for why), so DeathState's own
## `_enter_logical_death()` loop over `_hurtboxes` has nothing to iterate --
## `hurtbox.mark_dead()` / `apply_logical_death_layers()` are never called
## from there for the player's own Hurtbox. This replicates those two calls
## here, from the SAME `logical_death` signal, mirroring
## `src/tower/tower_health.gd`'s own `_on_death_state_logical_death()` --
## that file's header names this exact pattern ("the double-damage
## problem") for the identical reason (a component that intercepts damage
## before DeathState's auto-wiring must also replicate DeathState's own
## Logical Death cleanup by hand).
func _on_logical_death(_entity: Node2D, _position: Vector2) -> void:
	if hurtbox != null:
		hurtbox.mark_dead()
		hurtbox.apply_logical_death_layers()
	if _animator != null and death_state != null:
		_animator.play_death(death_state.visual_death_duration)


## Meta layer core (D109-D112). MASTER_SDLC.md > Provisional Values Register
## > "Meta: Skill Tree effects": "Second Wind: once per run a lethal hit
## leaves the player at 30% health (1)." The "30%" figure has no dedicated
## SkillNodeDefinition field to carry it (data/meta/skill_tree.tres'
## `second_wind` node uses `value_per_rank` only as a presence flag -- see
## that file's own header), so it is cited here as a named constant instead
## of a bare literal, matching this project's own precedent (e.g.
## src/ui/console.gd's REPAIR_MAX_HEAL).
const SECOND_WIND_SURVIVE_FRACTION: float = 0.30

## Set once at run start by `MetaLoadoutApplier` (src/meta/
## meta_loadout_applier.gd) when the Second Wind node is owned; consumed at
## most once per run by `apply_damage()` below, then cleared so a second
## lethal hit the same run kills normally ("once per run").
var _second_wind_available: bool = false


## Typed command (Meta layer core). Never called by gameplay code other than
## `MetaLoadoutApplier` at run start; also usable directly from a test.
func set_second_wind_available(available: bool) -> void:
	_second_wind_available = available


func is_second_wind_available_for_test() -> bool:
	return _second_wind_available


## v1.0 Blood Pact "Second Life" (Register "v1.0 Run Events"): the first lethal
## hit leaves the player at this fraction of max HP. Taken at most once per run.
const SECOND_LIFE_SURVIVE_FRACTION: float = 0.50
var _second_life_available: bool = false


func set_second_life_available(available: bool) -> void:
	_second_life_available = available


func is_second_life_available() -> bool:
	return _second_life_available


## Typed command forwarding to death_state.gd, mirroring placeholder_
## enemy.gd's own apply_damage() convenience wrapper -- kept here so a
## caller holding only a Player reference need not reach into a child node.
##
## Meta layer core: intercepts a hit that would be LETHAL (current_hp -
## amount <= 0) while Second Wind is available -- instead of forwarding the
## full amount to death_state.apply_damage() (which would enter Logical
## Death), this clamps current_hp to SECOND_WIND_SURVIVE_FRACTION of max_hp
## and consumes the flag, without death_state ever seeing the lethal amount
## at all. death_state.gd itself (src/combat/, a file this task does not own)
## is untouched -- this mirrors this file's own established pattern of
## writing to death_state's public fields directly (see `heal()` and
## `_apply_definition()` above) rather than adding a new command there.
func apply_damage(amount: float, source: Variant = null) -> bool:
	if death_state == null:
		return false
	amount *= _damage_taken_multiplier # v1.0 Leather Armor / Iron Skin (docs/31 §4.4)
	if amount > 0.0 and not death_state.is_dead:
		CombatStats.add_run_counter("damage_taken", amount)
	if (_second_wind_available or _second_life_available) and not death_state.is_dead and amount > 0.0 and (death_state.current_hp - amount) <= 0.0:
		# One lethal hit consumes ONE safety net: Second Wind (30%, the weaker) goes
		# first, Second Life (50%) is kept for the next lethal hit (docs/32 §A).
		if _second_wind_available:
			_second_wind_available = false
			death_state.current_hp = death_state.max_hp * SECOND_WIND_SURVIVE_FRACTION
		else:
			_second_life_available = false
			death_state.current_hp = death_state.max_hp * SECOND_LIFE_SURVIVE_FRACTION
		return true
	return death_state.apply_damage(amount, source)


## Minimal heal seam for P2.11's Patch Kit (src/upgrade/upgrade_system.gd):
## "restores 30 player health per rank taken" (MASTER_SDLC.md > Tower
## Overview > "Health Recovery Rules"). death_state.gd (src/combat/,
## outside P2.11's write scope) has no heal()/apply_damage(-amount)
## counterpart of its own -- apply_damage() rejects amount <= 0.0 by design
## (death_state.gd: "Returns false ... if amount is not positive"), so a
## negative-amount call is not a usable heal seam, and this task's hard
## constraints forbid editing src/combat/death_state.gd itself. Added here,
## on Player, as the minimal seam Patch Kit needs -- this project's own
## precedent for writing directly to death_state's public fields already
## exists a few lines above (`death_state.max_hp = ...` in
## _apply_definition()), so this is consistent local convention, not a new
## exception. Clamped to max_hp here (Register > Health Recovery Rules:
## "Overheal on either pool is discarded unless an upgrade explicitly
## converts it to shield") since death_state.apply_damage() has no
## symmetrical clamp for a heal to reuse. Named in the P2.11 evidence
## report as a seam a future task should fold into death_state.gd as a
## proper heal(amount) command mirroring apply_damage(amount), rather than
## living on Player permanently.
func heal(amount: float) -> void:
	if death_state == null or death_state.is_dead or amount <= 0.0:
		return
	death_state.current_hp = minf(death_state.max_hp, death_state.current_hp + amount)


func is_dead() -> bool:
	return death_state != null and death_state.is_dead


# --- v1.0 Focus (docs/32 §A2; Register "v1.0 Run Events" > Focus) -------------
# Standing still charges Focus; at full the bow fires faster. The bow still fires
# while moving, so holding position is a reward, not a requirement.

const FOCUS_STILL_SPEED_PX: float = 8.0 ## Register: below this speed the player counts as standing still
const FOCUS_STILL_DELAY_SECONDS: float = 0.25 ## Register: still this long before the charge starts
const FOCUS_RAMP_SECONDS: float = 1.5 ## Register: 0 to 1 while still
const FOCUS_DECAY_SECONDS: float = 0.4 ## Register: 1 to 0 while moving
const FOCUS_FIRE_RATE_BONUS: float = 0.30 ## Register: bow fire rate at full Focus
const SKIRMISHER_CHAMPION_ID: String = "skirmisher" ## docs/32 §C1: Focus is disabled

var _focus: float = 0.0
var _still_seconds: float = 0.0
var _focus_full_applied: bool = false


## 0..1 Focus charge, for the overhead arc, the HUD and the balance bot.
func get_focus() -> float:
	return _focus


var _focus_enabled: bool = true


func is_focus_enabled() -> bool:
	return _focus_enabled


## The champion rule lives with the caller (PrototypeIntegration reads RunConfig), so
## this script holds no RunConfig reference. Disabling zeroes Focus at once.
func set_focus_enabled(enabled: bool) -> void:
	_focus_enabled = enabled
	if not enabled:
		reset_focus()


## Docs/32 §C1: the Skirmisher champion has no Focus.
static func champion_has_focus(champion_id: String) -> bool:
	return champion_id != SKIRMISHER_CHAMPION_ID


## Dash and a disabled champion zero Focus instantly (no decay ramp).
func reset_focus() -> void:
	_focus = 0.0
	_still_seconds = 0.0
	_push_focus_fire_rate()


func _focus_step(delta: float, raw_direction: Vector2) -> void:
	if not is_focus_enabled() or _dash_active or is_dead():
		if _focus != 0.0 or _still_seconds != 0.0:
			reset_focus()
		return
	var still: bool = raw_direction == Vector2.ZERO and _local_velocity.length() < FOCUS_STILL_SPEED_PX
	if still:
		_still_seconds += delta
		if _still_seconds >= FOCUS_STILL_DELAY_SECONDS:
			_focus = minf(1.0, _focus + delta / FOCUS_RAMP_SECONDS)
	else:
		_still_seconds = 0.0
		_focus = maxf(0.0, _focus - delta / FOCUS_DECAY_SECONDS)
	_push_focus_fire_rate()


## The weapon gets a separate fire-rate term (like War Horn's buff), so Focus
## composes with Rapid Fire and never overwrites it.
func _push_focus_fire_rate() -> void:
	var full: bool = _focus >= 1.0
	if full == _focus_full_applied:
		return
	_focus_full_applied = full
	if _weapon != null:
		_weapon.set_focus_fire_rate_multiplier(1.0 + FOCUS_FIRE_RATE_BONUS if full else 1.0)


# --- D115/D117 pool expansion modifier layer (src/upgrade/upgrade_system.gd) --

## Typed command (Swift Feet). REPLACES the previous multiplier, never
## compounds -- same contract as AutoWeapon.set_damage_multiplier().
func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = multiplier


## Haste boon: `speed` multiplies move speed, `dash_recharge` divides the dash cooldown.
## REPLACES the previous boon values (1.0, 1.0 clears the boon).
func set_boon_haste(speed: float, dash_recharge: float) -> void:
	_boon_speed_multiplier = maxf(0.1, speed)
	_boon_dash_recharge_multiplier = maxf(0.1, dash_recharge)


func get_boon_speed_multiplier() -> float:
	return _boon_speed_multiplier


func get_speed_multiplier_for_test() -> float:
	return _speed_multiplier


## Typed command (Vitality). Raises max health by `fraction` over the
## definition-derived base and heals by exactly the increase -- mirrors
## TowerHealth.set_bonus_max_health_fraction() exactly.
func set_max_health_bonus_fraction(fraction: float) -> void:
	_max_health_bonus_fraction = fraction
	_recompute_max_health()


## v1.0 Blood Pact (docs/32 §A; Register "v1.0 Run Events"): a SEPARATE
## multiplicative term, so a pact cost composes with Vitality and the meta
## bonus instead of being overwritten by the next absolute setter call.
var _pact_max_health_multiplier: float = 1.0


## Typed command (Blood Pact "Pay with your blood"). REPLACES the pact term;
## current health is clamped to the new maximum, never raised.
func set_pact_max_health_multiplier(multiplier: float) -> void:
	_pact_max_health_multiplier = clampf(multiplier, 0.05, 1.0)
	_recompute_max_health()


func get_pact_max_health_multiplier() -> float:
	return _pact_max_health_multiplier


## max = base x (1 + Vitality bonus) x pact term. A rise heals by exactly the
## increase (Vitality's "and heal that amount"); a fall only clamps.
func _recompute_max_health() -> void:
	if death_state == null or _base_max_health <= 0.0:
		return
	var new_max: float = _base_max_health * (1.0 + _max_health_bonus_fraction) * _pact_max_health_multiplier
	var delta: float = new_max - death_state.max_hp
	death_state.max_hp = new_max
	if delta > 0.0:
		death_state.current_hp = minf(new_max, death_state.current_hp + delta)
	else:
		death_state.current_hp = minf(death_state.current_hp, new_max)


func get_max_health_bonus_fraction_for_test() -> float:
	return _max_health_bonus_fraction


## Typed command (Magnet). See `_magnet_radius_multiplier`'s own field
## comment for why this is a multiplier query, not a resource mutation.
func set_pickup_radius_multiplier(multiplier: float) -> void:
	_magnet_radius_multiplier = multiplier


## Typed query: PickupSystem._resolve_magnet_radius_px() reads this instead
## of `definition.magnet_radius_px` directly whenever it is available.
func get_effective_magnet_radius_px() -> float:
	if definition == null:
		return 0.0
	return float(definition.magnet_radius_px) * _magnet_radius_multiplier


## Typed command (Regeneration). A flat fraction of max health healed per
## second, ticked in `_regen_step()`. Stacks additively across ranks
## (UpgradeSystem sums `effect_per_rank * rank` before calling this, same
## C-STACK convention as every other percentage upgrade).
func set_regen_fraction_per_second(fraction: float) -> void:
	_regen_fraction_per_second = fraction


func get_regen_fraction_per_second_for_test() -> float:
	return _regen_fraction_per_second


# --- v1.0 Dash (docs/31 §3.1; Register "v1.0 Combat & Abilities" > Dash) ----

const DASH_DISTANCE_PX: float = 220.0 # Register: Dash distance (D350, was 190)
const DASH_DURATION_SECONDS: float = 0.16 # Register: Dash duration
const DASH_IFRAME_EXTRA_SECONDS: float = 0.12 # Register: Dash invulnerability tail
const DASH_COOLDOWN_SECONDS: float = 1.5 # Register: Dash recharge (D350, was 2.8)
const DASH_BASE_CHARGES: int = 2 # Register: Dash charges (D350, was 1)
const SHADOW_STEP_RADIUS_PX: float = 48.0 # Register: Shadow Step contact radius around the dashing player
const DASH_COOLDOWN_FLOOR: float = 0.4 # Register: Dash cooldown multiplier floor
const DASH_AFTERIMAGES: int = 3 # docs/31 §3.1: "3 fading sprite copies"

var _dash_extra_charges: int = 0
var _dash_cooldown_multiplier: float = 1.0
var _dash_charges: int = DASH_BASE_CHARGES
var _dash_recharge_ready_at: float = 0.0
var _dash_active: bool = false
var _dash_end_at: float = 0.0
var _dash_started_at: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT
var _dash_afterimages_spawned: int = 0
var _shadow_step_damage: float = 0.0 # Shadow Step (D350): contact damage per enemy per dash, 0 = card not held
var _shadow_step_invuln: float = 0.0 # and the extra invulnerability seconds it grants
var _shadow_step_hit: Dictionary = {} # enemy instance id -> true, cleared at dash start
var _dash_buffer_until: float = -INF
var _invulnerable_until: float = -INF
var _facing: Vector2 = Vector2.RIGHT
var _test_dash_pressed: bool = false
var _damage_taken_multiplier: float = 1.0


func _dash_max_charges() -> int:
	return DASH_BASE_CHARGES + _dash_extra_charges


func _dash_cooldown_total() -> float:
	return DASH_COOLDOWN_SECONDS * maxf(DASH_COOLDOWN_FLOOR, _dash_cooldown_multiplier) / maxf(0.1, _boon_dash_recharge_multiplier)


## Typed query for the HUD and the Battle Skill / balance bot (docs/31 §10).
func get_dash_state() -> Dictionary:
	var remaining: float = 0.0
	if _dash_charges < _dash_max_charges():
		remaining = maxf(0.0, _dash_recharge_ready_at - SimClock.now)
	return {"charges": _dash_charges, "max_charges": _dash_max_charges(), "cooldown_remaining": remaining, "cooldown_total": _dash_cooldown_total()}


## True while the player is moving faster than the standing-still line (the same
## 8 px/s Focus uses; Register "v1.0 Loadout"). Skirmisher's bow reads this.
func is_moving() -> bool:
	return _local_velocity.length() >= LoadoutCatalog.MOVING_SPEED_THRESHOLD_PX_PER_SECOND


func is_dashing() -> bool:
	return _dash_active


func is_invulnerable() -> bool:
	return SimClock.now < _invulnerable_until


## Reads the `dash` action through the same short buffer the movement input
## uses (Register "Input buffer": 100 ms), so a press just before a charge
## returns still dashes.
func _dash_step(raw_direction: Vector2) -> void:
	var now: float = SimClock.now
	if raw_direction != Vector2.ZERO:
		_facing = raw_direction.normalized()
	if _test_dash_pressed or Input.is_action_just_pressed(&"dash"):
		_test_dash_pressed = false
		_dash_buffer_until = now + _buffer_duration_seconds
	# Recharge: one charge at a time.
	if _dash_charges < _dash_max_charges() and now >= _dash_recharge_ready_at:
		_dash_charges += 1
		if _dash_charges < _dash_max_charges():
			_dash_recharge_ready_at = now + _dash_cooldown_total()
	if _dash_active:
		_spawn_dash_afterimages(now)
		_shadow_step_contact()
		if now >= _dash_end_at:
			_end_dash()
	if now < _dash_buffer_until and not _dash_active and _dash_charges > 0 and not is_dead():
		_start_dash(raw_direction, now)
	if hurtbox != null:
		hurtbox.invulnerable = now < _invulnerable_until
	if now >= _invulnerable_until and not _dash_active and _dash_pass_through:
		_set_pass_through(false)


var _dash_pass_through: bool = false


func _start_dash(raw_direction: Vector2, now: float) -> void:
	_dash_buffer_until = -INF
	reset_focus() # docs/32 §A2: a dash drops Focus to 0 at once
	if _dash_charges >= _dash_max_charges():
		_dash_recharge_ready_at = now + _dash_cooldown_total()
	_dash_charges -= 1
	_dash_direction = raw_direction.normalized() if raw_direction != Vector2.ZERO else _facing
	_dash_active = true
	_dash_started_at = now
	_dash_end_at = now + DASH_DURATION_SECONDS
	_invulnerable_until = _dash_end_at + DASH_IFRAME_EXTRA_SECONDS + _shadow_step_invuln
	_shadow_step_hit.clear()
	_dash_afterimages_spawned = 0
	_set_pass_through(true)
	_spawn_dash_afterimages(now)
	Sfx.play("dash", global_position)
	CombatStats.add_run_counter("dashes")
	EventBus.emit_dash_used(_dash_charges)


## Shadow Step: every enemy the dashing body overlaps takes the card's damage once per dash,
## scaled by the player's ability damage terms (Heavy Rounds, Valor, boons, meta) and able to crit.
func _shadow_step_contact() -> void:
	if _shadow_step_damage <= 0.0:
		return
	for e in AbilityDamage.enemies_in_radius(global_position, SHADOW_STEP_RADIUS_PX):
		var id: int = e.get_instance_id()
		if _shadow_step_hit.has(id):
			continue
		if AbilityDamage.hit(e, _shadow_step_damage * AbilityDamage.player_ability_mult(), AbilityIds.SOURCE_SHADOW_STEP, &"player", true) > 0.0:
			_shadow_step_hit[id] = true


## Shadow Step card (UpgradeSystem). ABSOLUTE: replaces both values; (0, 0) removes the card.
func set_shadow_step(damage: float, extra_invulnerable_seconds: float) -> void:
	_shadow_step_damage = maxf(0.0, damage)
	_shadow_step_invuln = maxf(0.0, extra_invulnerable_seconds)


func _end_dash() -> void:
	_dash_active = false
	_set_pass_through(false)


## Passes through enemy bodies: the player's body mask drops EnemyBody for the
## dash (World, Tower and ArenaBounds still block).
func _set_pass_through(on: bool) -> void:
	_dash_pass_through = on
	collision_mask = (CollisionLayers.MASK_PLAYER_BODY & ~CollisionLayers.LAYER_ENEMY_BODY) if on else CollisionLayers.MASK_PLAYER_BODY


func _spawn_dash_afterimages(now: float) -> void:
	var progress: float = clampf((now - _dash_started_at) / DASH_DURATION_SECONDS, 0.0, 1.0)
	while _dash_afterimages_spawned < DASH_AFTERIMAGES and progress >= float(_dash_afterimages_spawned) / float(DASH_AFTERIMAGES):
		_dash_afterimages_spawned += 1
		var sprite: AnimatedSprite2D = get_node_or_null("Visuals/Sprite2D") as AnimatedSprite2D
		if sprite != null and get_parent() != null:
			DashAfterimage.spawn(get_parent(), sprite, global_position)


## Meta hooks (WP-META via AbilityManager). REPLACE, never compound.
func set_dash_extra_charges(extra: int) -> void:
	var before: int = _dash_max_charges()
	_dash_extra_charges = maxi(0, extra)
	if _dash_max_charges() > before:
		_dash_charges += _dash_max_charges() - before # a bought charge starts full
	_dash_charges = mini(_dash_charges, _dash_max_charges())


func set_dash_cooldown_multiplier(multiplier: float) -> void:
	_dash_cooldown_multiplier = multiplier


func set_damage_taken_multiplier(multiplier: float) -> void:
	_damage_taken_multiplier = clampf(multiplier, 0.1, 2.0)


func get_damage_taken_multiplier() -> float:
	return _damage_taken_multiplier


func press_dash_for_test() -> void:
	_test_dash_pressed = true


# --- Test-only seams (never called by gameplay code) ----------------------

func set_registry_for_test(registry: Node) -> void:
	_registry = registry


## Typed command (integration task): wires the shared AudioPool
## `damage_sfx` plays through. Also usable directly from a test.
func set_audio_pool_ref(pool: Node) -> void:
	_audio_pool = pool


func set_input_direction_for_test(direction: Vector2) -> void:
	_test_input_override = direction


func clear_input_direction_override_for_test() -> void:
	_test_input_override = Vector2.INF


func get_local_velocity_for_test() -> Vector2:
	return _local_velocity


func set_local_velocity_for_test(v: Vector2) -> void:
	_local_velocity = v


func get_acceleration_rate_for_test() -> float:
	return _acceleration_rate_px_per_s2


func get_deceleration_rate_for_test() -> float:
	return _deceleration_rate_px_per_s2


func get_buffer_duration_seconds_for_test() -> float:
	return _buffer_duration_seconds

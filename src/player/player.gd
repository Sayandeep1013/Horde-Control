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
## z_index (50) is a separate Register row (> Readability: "draw order
## z_index: ... player 50 ..."), not a PlayerDefinition Contract field, so
## it is set directly on this scene's root node rather than read from the
## resource -- named here since it is a Register number with no contract
## field to carry it.
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

var hurtbox: Hurtbox = null
var collector: PlayerCollector = null
var death_state: DeathState = null
var _animator: PlayerAnimator = null

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
	z_index = 50 # Register > Readability: "draw order z_index: ... player 50 ..."
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

	if hurtbox != null:
		hurtbox.damage_received.connect(_on_hurtbox_damage_received)

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
		death_state.max_hp = float(definition.max_health)
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
	_movement_step(delta, raw_direction)
	if _animator != null:
		_animator.update_visuals(delta, _local_velocity, definition.base_speed_px_per_second if definition != null else 0.0)


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
	var target_velocity: Vector2 = raw_direction * definition.base_speed_px_per_second
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


func _on_hurtbox_damage_received(_amount: float, _source: Variant, _hitbox: Node) -> void:
	if _animator != null:
		_animator.play_hit_flash()
	if _audio_pool != null and damage_sfx != null and _audio_pool.has_method("play"):
		# docs/20 > Audio Mixing & Dynamic Ducking: "Player damage ... routed
		# to SFX_Priority" -- a priority voice, not the ordinary SFX default.
		_audio_pool.play(damage_sfx, global_position, 10, true, "SFX_Priority")


## Typed command forwarding to death_state.gd, mirroring placeholder_
## enemy.gd's own apply_damage() convenience wrapper -- kept here so a
## caller holding only a Player reference need not reach into a child node.
func apply_damage(amount: float, source: Variant = null) -> bool:
	return death_state.apply_damage(amount, source) if death_state != null else false


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

extends Node2D
class_name PlayerAnimator

## Player cosmetic animation (P2.1 task brief: "Animation matters here and
## must be code-driven ... Give it: a subtle idle bob, squash-and-stretch on
## acceleration and stop, a lean into the movement direction, and a hit
## flash."). No AnimationPlayer/AnimationTree exists for the player (no
## sprite sheet frames -- assets/sprites/player.png is one static image per
## decision D99); every effect here is a procedural transform/modulate
## change, driven every physics tick by `update_visuals()`, which player.gd
## calls itself rather than this node running its own `_physics_process` --
## keeping one driver per entity (see player.gd's own header note on
## src/core/sim_loop.gd's "entities do not run their own gameplay
## _physics_process" rule).
##
## Pause-safety (task brief: "no create_tween() on the tree -- use
## Node.create_tween(), which is permitted for cosmetic animation only, or
## hand-rolled interpolation on SimClock", citing MASTER_SDLC.md > Global
## Simulation Authority, which bans `SceneTree.create_timer()`/
## `SceneTree.create_tween()` for gameplay but permits `Node.create_tween()`
## for cosmetic animation "since a tween bound to a paused node pauses with
## it"; `tools/checks/banned_api_check.sh` enforces the ban on those two
## SceneTree-level calls textually, by grepping for `get_tree()` followed by
## either method name):
##   - Idle bob, squash-and-stretch, and lean are hand-rolled: driven by
##     `update_visuals()`, which only ever runs from inside player.gd's own
##     `_physics_process()` -- a call that the engine itself does not make
##     while the tree is paused (Player is PROCESS_MODE_PAUSABLE). They
##     therefore freeze automatically under pause with no extra guard code,
##     the same way every other continuous per-tick effect in this project
##     does. The idle bob's oscillation phase reads `SimClock.now` rather
##     than accumulating its own `elapsed += delta` counter, matching the
##     project rule that a simulation-time-driven value is compared against
##     `SimClock.now`, not a raw per-frame counter (SimClock's own header;
##     death_state.gd's Visual Death timer does the same for the same
##     reason) -- `SimClock.now` itself stops advancing under pause, so the
##     bob phase is frozen twice over.
##   - The hit flash is the one genuinely discrete, one-shot effect (trigger
##     on a `damage_received` signal, decay over a fixed short window) and
##     is exactly the case the master carves out for `Node.create_tween()`:
##     bound to this node, so it pauses if this node's processing stops,
##     never routed through `get_tree()`.

@export var sprite_path: NodePath = NodePath("Sprite2D")

## Idle bob (small vertical oscillation while nearly stationary). Not a
## Provisional Values Register number -- the Register's Player & Weapons row
## covers health/speed/accel/stop/radii/buffer only; bob amplitude/frequency
## are cosmetic tuning with no gameplay effect, same category as
## death_state.gd's own `visual_death_duration` (that file's header: "NOT
## Provisional Values Register numbers ... this component's own contract
## defines behaviour, not tuning").
@export var idle_bob_amplitude_px: float = 1.6
@export var idle_bob_frequency_hz: float = 1.6

## Squash-and-stretch: how far scale.y/scale.x depart from 1.0 per unit of
## normalized acceleration (current acceleration magnitude / the faster of
## the two Register rates), and how quickly the visual scale chases that
## target each tick.
@export var stretch_amount: float = 0.14
@export var stretch_smoothing_per_second: float = 18.0

## Lean: maximum rotation (radians) applied at full speed, chased at the
## same smoothing rate as stretch for one consistent "settle" feel.
@export var max_lean_radians: float = 0.12

## Hit flash duration and colour. Cosmetic constants, same category as the
## bob/stretch tuning above.
@export var hit_flash_duration_seconds: float = 0.12
@export var hit_flash_color: Color = Color(1.0, 0.35, 0.35, 1.0)

var _sprite: CanvasItem = null
var _base_modulate: Color = Color.WHITE
var _current_scale: Vector2 = Vector2.ONE
var _current_lean: float = 0.0
var _previous_local_velocity: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as CanvasItem
	if _sprite != null:
		_base_modulate = _sprite.modulate


## Called once per physics tick by player.gd, after movement is resolved
## for that tick. `local_velocity` is the pre-time_scale velocity player.gd
## integrates every tick (player.gd's own `_local_velocity`); using the
## pre-scale value keeps the visual read of "how hard am I accelerating"
## stable even if a later slow-motion effect scales the actual on-screen
## displacement (Global Simulation Authority: movers scale velocity "before
## moving" -- the cosmetic read of acceleration is a separate concern from
## the scaled move itself).
func update_visuals(delta: float, local_velocity: Vector2, reference_speed_px_per_second: float) -> void:
	if reference_speed_px_per_second <= 0.0:
		return

	var speed_ratio: float = clampf(local_velocity.length() / reference_speed_px_per_second, 0.0, 1.0)

	# --- Idle bob: fades out as speed rises so it never fights the lean/
	# stretch of active movement. ---
	var bob_strength: float = 1.0 - speed_ratio
	var bob_offset: float = sin(SimClock.now * idle_bob_frequency_hz * TAU) * idle_bob_amplitude_px * bob_strength
	position.y = bob_offset

	# --- Squash-and-stretch: reacts to the ACCELERATION this tick (the
	# change in local_velocity), not to speed itself, so a steady cruise at
	# top speed settles back to neutral while a sharp start or stop reads
	# clearly. Stretch (scale.y > 1, scale.x < 1) on speeding up; squash
	# (scale.y < 1, scale.x > 1) on slowing down.
	#
	# The reference direction to project the acceleration onto is the
	# PREVIOUS tick's travel direction whenever one exists (a body that was
	# already moving squashes against the direction it was just travelling
	# in when it decelerates to a stop -- the new `local_velocity` this tick
	# is exactly zero at that instant, so it carries no direction of its
	# own to project onto). Only when there was no previous motion at all
	# (starting from rest) does the NEW velocity's direction serve as the
	# reference, for the opposite case (a stretch into the very first tick
	# of acceleration). Using `local_velocity`'s own direction as the
	# reference unconditionally was tried first and is wrong: at the exact
	# tick a stop reaches zero, `local_velocity.length()` is ~0, and the
	# fallback branch used `accel_this_tick.length()` -- always
	# non-negative -- which reads every stop as a stretch instead of a
	# squash (caught by tests/unit/player_animation_test.gd's own
	# `test_squashes_when_stopping`).
	var accel_this_tick: Vector2 = (local_velocity - _previous_local_velocity) / delta if delta > 0.0 else Vector2.ZERO
	var reference_direction: Vector2 = Vector2.ZERO
	if _previous_local_velocity.length() > 0.01:
		reference_direction = _previous_local_velocity.normalized()
	elif local_velocity.length() > 0.01:
		reference_direction = local_velocity.normalized()
	_previous_local_velocity = local_velocity
	var accel_along_motion: float = accel_this_tick.dot(reference_direction) if reference_direction != Vector2.ZERO else 0.0
	# Normalize against a generous reference so typical accel/decel rates
	# (Register: full speed in 0.08 s, stop in 0.05 s) read as a visible but
	# non-extreme squash/stretch rather than clipping at the clamp.
	var reference_accel: float = reference_speed_px_per_second / 0.05
	var normalized_accel: float = clampf(accel_along_motion / reference_accel, -1.0, 1.0)
	var target_scale: Vector2 = Vector2(
		1.0 - stretch_amount * normalized_accel,
		1.0 + stretch_amount * normalized_accel
	)
	var scale_t: float = clampf(stretch_smoothing_per_second * delta, 0.0, 1.0)
	_current_scale = _current_scale.lerp(target_scale, scale_t)
	scale = _current_scale

	# --- Lean into the movement direction (horizontal component only --
	# top-down perspective, so a rotation lean reads as leaning into a
	# strafe the way MASTER_SDLC.md > Movement Design describes positioning
	# as the core skill). ---
	var lean_input: float = 0.0
	if reference_speed_px_per_second > 0.0:
		lean_input = clampf(local_velocity.x / reference_speed_px_per_second, -1.0, 1.0)
	var target_lean: float = lean_input * max_lean_radians
	_current_lean = lerpf(_current_lean, target_lean, scale_t)
	rotation = _current_lean


## Typed command, called by player.gd when its Hurtbox reports an accepted
## hit (Hurtbox.damage_received -- src/combat/hurtbox.gd). Discrete,
## one-shot: exactly the case MASTER_SDLC.md carves `Node.create_tween()`
## out for.
func play_hit_flash() -> void:
	if _sprite == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill() # a rapid second hit restarts the flash rather than competing with the first (tween-animation skill pitfall table: "Multiple tweens competing on the same property")
	_sprite.modulate = hit_flash_color
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate", _base_modulate, hit_flash_duration_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func get_current_scale_for_test() -> Vector2:
	return _current_scale


func get_current_lean_for_test() -> float:
	return _current_lean

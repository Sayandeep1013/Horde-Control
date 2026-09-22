extends Node2D
class_name PlayerAnimator

## Player cosmetic animation (P2.1 task brief: "Animation matters here and
## must be code-driven ... Give it: a subtle idle bob, squash-and-stretch on
## acceleration and stop, a lean into the movement direction, and a hit
## flash."). Originally written with no AnimationPlayer/AnimationTree at all
## (no sprite sheet frames -- assets/sprites/player.png was one static image
## per decision D99); every continuous effect here is still a procedural
## transform/modulate change, driven every physics tick by `update_visuals()`,
## which player.gd calls itself rather than this node running its own
## `_physics_process` -- keeping one driver per entity (see player.gd's own
## header note on src/core/sim_loop.gd's "entities do not run their own
## gameplay _physics_process" rule).
##
## Art session update: `sprite_path` now resolves to a real AnimatedSprite2D
## (scenes/player.tscn's "Visuals/Sprite2D", driving assets/sprite_frames/
## player_archer.tres -- Archer_Blue.png/Dead.png from the Tiny Swords CC0
## pack). D99's "one static image" is superseded for the player specifically;
## the bob/squash-stretch/lean/hit-flash transforms above are UNCHANGED and
## still apply to this node's own transform/the sprite's modulate -- only
## `_update_animation_state()`/`play_shoot()`/`play_death()` below, added
## this session, choose WHICH baked animation frame is showing underneath
## those transforms.
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

## Art session additions below: which animation plays (idle/run/shoot/death)
## on the AnimatedSprite2D this node drives. All of it is gated on `_sprite`
## actually BEING an AnimatedSprite2D (`_sprite_animated`, resolved in
## _ready()) -- tests/unit/player_animation_test.gd's own before_test()
## builds a standalone PlayerAnimator over a plain Sprite2D, and every method
## below no-ops cleanly against that fixture instead of erroring, so none of
## the existing continuous-effect/hit-flash coverage changes.

const ANIM_IDLE: StringName = &"idle"
const ANIM_RUN: StringName = &"run"
const ANIM_SHOOT_UP: StringName = &"shoot_up"
const ANIM_SHOOT_UP_DIAG: StringName = &"shoot_up_diag"
const ANIM_SHOOT_RIGHT: StringName = &"shoot_right"
const ANIM_SHOOT_DOWN_DIAG: StringName = &"shoot_down_diag"
const ANIM_SHOOT_DOWN: StringName = &"shoot_down"
const ANIM_DEATH_FALL: StringName = &"death_fall"

## Cosmetic-only timing constants (NOT Provisional Values Register numbers --
## same category as idle_bob_amplitude_px above): the SpriteFrames resource
## this node drives (assets/sprite_frames/player_archer.tres, generated by
## sandbox/gen_sprite_frames.gd from Archer_Blue.png/Dead.png) is baked at
## these fps/frame-count values. `play_shoot()`/`play_death()` compute
## `speed_scale` from these PLUS a value read live from the caller (the
## weapon's actual fire interval, or death_state's actual visual_death_
## duration) -- never a hardcoded interval/duration of their own.
const SHOOT_BASE_FPS: float = 10.0
const SHOOT_RELEASE_FRAME_INDEX: int = 5 # the row_right/row_up/row_down strips all show the arrow fully drawn/releasing around this frame (see this file's header measurement notes in the art-session evidence)
const DEATH_BASE_FPS: float = 10.0
const DEATH_FRAME_COUNT: int = 7
const SPEED_SCALE_MIN: float = 0.25
const SPEED_SCALE_MAX: float = 6.0

## Below this fraction of the reference speed, "run" gives way to "idle" --
## avoids flickering between the two right at a standstill from float noise.
const MOVING_SPEED_RATIO_THRESHOLD: float = 0.05

var _sprite: CanvasItem = null
var _sprite_animated: AnimatedSprite2D = null
var _base_modulate: Color = Color.WHITE
var _current_scale: Vector2 = Vector2.ONE
var _current_lean: float = 0.0
var _previous_local_velocity: Vector2 = Vector2.ZERO
var _hit_tween: Tween = null

## SimClock.now deadline (this project's own timing convention -- see this
## file's header on the idle bob's phase) until which an in-progress "shoot"
## animation is left alone rather than overwritten by the idle/run logic in
## update_visuals(). Set by play_shoot() to the weapon's own fire interval,
## so it naturally expires right as either the next shot re-triggers it or
## (target lost) idle/run resumes.
var _shoot_hold_until_sim_time: float = -INF

## The last direction actually faced (movement or aim), so idle/a shot that
## just ended does not snap back to a default facing -- only a NEW nonzero
## movement or aim direction ever changes this.
var _facing_flip_h: bool = false

## Set true by play_death() below. player.gd keeps calling update_visuals()
## every tick even after death (it has no is_dead() branch of its own -- see
## that file's physics_step()), so without this flag _update_animation_state
## would stomp the death_fall animation back to idle/run on the very next
## tick, since it runs unconditionally otherwise. Once true, this animator
## never plays another idle/run/shoot animation for the rest of this
## instance's life.
var _is_dead: bool = false


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as CanvasItem
	_sprite_animated = _sprite as AnimatedSprite2D
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

	_update_animation_state(local_velocity, reference_speed_px_per_second)


## Art session: picks idle vs. run (facing the movement direction) every
## tick, UNLESS a shoot animation played by play_shoot() below is still
## within its hold window -- in which case this leaves it alone rather than
## interrupting it. No-ops if `_sprite` is not an AnimatedSprite2D (see this
## file's header).
func _update_animation_state(local_velocity: Vector2, reference_speed_px_per_second: float) -> void:
	if _sprite_animated == null or _is_dead:
		return
	if SimClock.now < _shoot_hold_until_sim_time:
		return
	var speed_ratio: float = (local_velocity.length() / reference_speed_px_per_second) if reference_speed_px_per_second > 0.0 else 0.0
	if speed_ratio > MOVING_SPEED_RATIO_THRESHOLD:
		if absf(local_velocity.x) > 0.01:
			_facing_flip_h = local_velocity.x < 0.0
		_play_animation(ANIM_RUN)
	else:
		_play_animation(ANIM_IDLE)


func _play_animation(anim_name: StringName) -> void:
	if _sprite_animated == null:
		return
	_sprite_animated.flip_h = _facing_flip_h
	if _sprite_animated.sprite_frames == null or not _sprite_animated.sprite_frames.has_animation(anim_name):
		return
	if _sprite_animated.animation != anim_name or not _sprite_animated.is_playing():
		_sprite_animated.speed_scale = 1.0
		_sprite_animated.play(anim_name)


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


## Typed command, called by player.gd (`_on_weapon_fired()`) whenever
## AutoWeapon actually fires a shot. `aim_direction` is normalized, toward
## the target it just fired at; `fire_interval_seconds` is the weapon's
## CURRENT effective interval (read live -- see this file's header). Picks
## one of the 5 baked shoot rows from the aim angle and flips horizontally
## for a leftward aim (task brief: "up / up-diagonal / right / down-
## diagonal / down, flip_h for left"), then scales playback so
## SHOOT_RELEASE_FRAME_INDEX lands at roughly the real shot's pace.
func play_shoot(aim_direction: Vector2, fire_interval_seconds: float) -> void:
	if _sprite_animated == null or aim_direction == Vector2.ZERO or _is_dead:
		return
	_facing_flip_h = aim_direction.x < 0.0
	var anim_name: StringName = _shoot_animation_for_direction(aim_direction)
	if _sprite_animated.sprite_frames == null or not _sprite_animated.sprite_frames.has_animation(anim_name):
		return
	var speed_scale: float = 1.0
	if fire_interval_seconds > 0.0:
		speed_scale = (float(SHOOT_RELEASE_FRAME_INDEX) / SHOOT_BASE_FPS) / fire_interval_seconds
	_sprite_animated.flip_h = _facing_flip_h
	_sprite_animated.speed_scale = clampf(speed_scale, SPEED_SCALE_MIN, SPEED_SCALE_MAX)
	_sprite_animated.play(anim_name)
	if fire_interval_seconds > 0.0:
		_shoot_hold_until_sim_time = SimClock.now + fire_interval_seconds


## Buckets `direction` into 5 equal 36-degree bands measured from the
## horizontal (symmetric across left/right, since flip_h -- not a separate
## row -- handles which side the aim is on): straight down .. straight up.
func _shoot_animation_for_direction(direction: Vector2) -> StringName:
	var angle_from_horizontal_deg: float = rad_to_deg(atan2(-direction.y, absf(direction.x)))
	if angle_from_horizontal_deg >= 54.0:
		return ANIM_SHOOT_UP
	elif angle_from_horizontal_deg >= 18.0:
		return ANIM_SHOOT_UP_DIAG
	elif angle_from_horizontal_deg > -18.0:
		return ANIM_SHOOT_RIGHT
	elif angle_from_horizontal_deg > -54.0:
		return ANIM_SHOOT_DOWN_DIAG
	else:
		return ANIM_SHOOT_DOWN


## Typed command, called by player.gd (`_on_logical_death()`) when
## DeathState enters Logical Death. `duration_seconds` is death_state's own
## `visual_death_duration`, read live -- this makes the Visual Death window
## LOOK like something (flash to hit_flash_color, fade alpha to 0, play the
## Dead.png skull-falls animation scaled to fit) without re-deriving or
## overriding the timing death_state.gd already owns. Reuses `_hit_tween`
## (killing an in-flight hit flash first) rather than a second tween field,
## matching play_hit_flash()'s own "a rapid second effect restarts rather
## than competes" precedent.
func play_death(duration_seconds: float) -> void:
	if _sprite == null or duration_seconds <= 0.0:
		return
	_is_dead = true
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	if _sprite_animated != null and _sprite_animated.sprite_frames != null and _sprite_animated.sprite_frames.has_animation(ANIM_DEATH_FALL):
		_sprite_animated.speed_scale = clampf((float(DEATH_FRAME_COUNT) / DEATH_BASE_FPS) / duration_seconds, SPEED_SCALE_MIN, SPEED_SCALE_MAX)
		_sprite_animated.play(ANIM_DEATH_FALL)
	_sprite.modulate = hit_flash_color
	_hit_tween = create_tween()
	_hit_tween.tween_property(_sprite, "modulate:a", 0.0, duration_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func get_current_scale_for_test() -> Vector2:
	return _current_scale


func get_current_lean_for_test() -> float:
	return _current_lean

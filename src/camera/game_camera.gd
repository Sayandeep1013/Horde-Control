extends Camera2D
class_name GameCamera

## GameCamera (P2.2; MASTER_SDLC.md > Provisional Values Register > Arena &
## Camera; docs/20_Technical_Architecture.md's pinned viewport/stretch
## settings). Follows `target` smoothly with a velocity-based lead, clamps
## the visible rectangle to the arena bounds at every valid view scale, and
## exposes an `add_trauma()` screen-shake hook other systems (P2.1 player
## damage, P2.4 Tower damage) can call later. Runs in `_process` (visual
## interpolation), not `_physics_process`, per the godot-prompter
## camera-system skill's own implementation checklist.
##
## GodotPrompter conflict, recorded for the phase LEDGER: the camera-system
## skill's reference screen-shake implementation writes the shake offset to
## `Camera2D.offset`. This project's Provisional Values Register > Arena &
## Camera > "Lead/shake application" row is explicit and binding: "Applied
## to position before the arena clamp, never via Camera2D.offset" -- because
## `offset` is applied by the engine AFTER any position clamping, so an
## offset-based shake can visibly push the view past the arena walls, which
## is exactly the invariant this task's acceptance test checks. This file
## follows the Register: shake is folded into the position that feeds
## `_clamp_to_arena_bounds()`, and `offset` is never written. The skill's
## trauma-decay and trauma-squared-for-magnitude ideas are reused; only the
## output target changes.
##
## Assumption, named rather than silently made (P2.4 owns tower.tscn and has
## not yet placed it): "Tower at centre" (Register > "Arena size" row) is
## read as the Tower sitting at world origin, so `arena_center` defaults to
## Vector2.ZERO and the arena spans x in [-2400, 2400], y in [-1600, 1600]
## (half of the Register's 4800x3200 "Arena size" row on each axis). This
## must match scenes/arena.tscn's own Floor/ArenaBounds placement (it does;
## see that scene) and whatever world position P2.1's player.tscn and P2.4's
## tower.tscn are ultimately placed at. If a later task places the Tower
## anywhere else, `arena_center` is an @export and can be corrected without
## touching this file's logic.
##
## Interpretation, named rather than silently made: the Register's "View
## scale | 1.0 = 1920x1080 world px" row is read as a fixed reference size,
## not as "whatever the live viewport currently reports". The arena clamp
## below (`_clamp_to_arena_bounds`) is therefore a pure function of the
## current `zoom` and the constant `VIEWPORT_REFERENCE_SIZE`, deliberately
## NOT Godot's own `Camera2D.limit_left/right/top/bottom` (which clamp
## against the live `get_viewport_rect().size`, a value gdUnit4's headless
## runner is not guaranteed to report as exactly 1920x1080). This keeps the
## Camera bounds test's sweep deterministic and keeps the invariant tied to
## the Register's own stated definition rather than to window state.


# --- Provisional Values Register > Arena & Camera (cited, not restated) ---
const ARENA_SIZE: Vector2 = Vector2(4800.0, 3200.0) # "Arena size" row
const VIEW_SCALE_MIN: float = 0.9 # "View scale" row
const VIEW_SCALE_MAX: float = 1.15 # "View scale" row
const VIEWPORT_REFERENCE_SIZE: Vector2 = Vector2(1920.0, 1080.0) # "View scale" row: "1.0 = 1920x1080 world px"
const CAMERA_LEAD_TIME: float = 0.25 # "Camera lead" row: "Velocity x 0.25 s"
const CAMERA_LEAD_MAX: float = 120.0 # "Camera lead" row: "max 120 px"
const POSITION_SMOOTHING_SPEED: float = 8.0 # "Position smoothing speed" row
const SCREEN_SHAKE_MAX: float = 12.0 # "Screen shake" row: "Max 12 px"
const SCREEN_SHAKE_DECAY_TIME: float = 0.25 # "Screen shake" row: "decaying over 0.25 s"
const ZOOM_EASE_TIME: float = 0.4 # "Zoom ease" row
## "Screen shake noise frequency" row (feel pass, D152): the shake offset is
## sampled from smooth noise at this rate instead of a fresh random value per
## rendered frame, so it feels the same at 60 and 144 Hz.
const SHAKE_NOISE_FREQUENCY_HZ: float = 30.0
## "Camera HUD margin" row (D141): screen px (1920x1080 canvas) the camera may
## scroll past each arena wall, so a player standing at the wall clears the
## HUD panels instead of sitting under them. Scaled to world px by view scale.
const HUD_MARGIN_TOP: float = 200.0
const HUD_MARGIN_BOTTOM: float = 140.0
const HUD_MARGIN_SIDE: float = 96.0

## "Arena size" row: "Tower at centre" -- see header assumption note.
@export var arena_center: Vector2 = Vector2.ZERO

## The node this camera follows. Left null, the camera only responds to
## `snap_to()` / shake / zoom -- used by the Camera bounds test so a sweep
## does not depend on any other task's scene existing yet.
@export var target: Node2D

var _follow_position: Vector2 = Vector2.ZERO
var _previous_target_position: Vector2 = Vector2.ZERO
var _has_previous_target_position: bool = false
var _trauma: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_time: float = 0.0
## Last two physics-tick positions of `target`, sampled in `_physics_process`
## at the LAST physics priority so they are the settled end-of-tick positions.
## Godot 4.7 exposes no `get_global_transform_interpolated()` for 2D nodes, so
## the camera reproduces it: lerp(previous tick, current tick, fraction).
var _tick_previous: Vector2 = Vector2.ZERO
var _tick_current: Vector2 = Vector2.ZERO
var _interpolate_target: bool = false
var _shake_noise: FastNoiseLite = null


func _init() -> void:
	# Before entering the tree, so Camera2D never switches itself to its
	# physics-process callback on behalf of physics interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

## D146/D147 (mobile): the window's `content_scale_factor` that `zoom` has
## already been divided by. 1.0 on desktop, so every reading of `zoom` there is
## exactly what it was; on a phone the UI is scaled up and the camera zooms out
## by the same factor so the player sees the same amount of world.
var _applied_content_scale: float = 1.0


func _ready() -> void:
	# Built-in smoothing is disabled: lead + smoothing + shake are all
	# computed manually below so the arena clamp is guaranteed to be the
	# last step applied to the position the engine actually draws from
	# (Register > "Lead/shake application" row).
	position_smoothing_enabled = false
	_sync_content_scale()
	# Feel pass (D151): the camera is driven per RENDER frame in `_process`, so
	# it opts out of physics interpolation, and it reads the target's
	# interpolated transform instead. It lives beside the Player (not under it)
	# so its transform is never derived from a parent that moves on the tick.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE # the viewport follows the camera each render frame
	process_physics_priority = 100000 # sample the target after every mover has ticked
	_interpolate_target = bool(ProjectSettings.get_setting("physics/common/physics_interpolation", false))
	if target != null:
		_tick_previous = target.global_position
		_tick_current = target.global_position
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shake_noise.frequency = 1.0
	_shake_noise.seed = 7
	if target != null:
		var start: Vector2 = _target_render_position()
		_follow_position = start
		_previous_target_position = start
		_has_previous_target_position = true
	global_position = _clamp_to_arena_bounds(_follow_position)
	_setup_vignette()


func _process(delta: float) -> void:
	_sync_content_scale()
	if target != null:
		var target_pos: Vector2 = _target_render_position()
		var velocity_estimate: Vector2 = Vector2.ZERO
		if target is CharacterBody2D:
			# Authoritative per-tick velocity: a finite difference of a ticked
			# position reads 0 on tick-less frames and a multiple of the real
			# speed on tick frames at any refresh rate other than 60 Hz.
			velocity_estimate = (target as CharacterBody2D).velocity
		elif _has_previous_target_position and delta > 0.0:
			velocity_estimate = (target_pos - _previous_target_position) / delta
		_previous_target_position = target_pos
		_has_previous_target_position = true

		var lead: Vector2 = velocity_estimate * CAMERA_LEAD_TIME
		if lead.length() > CAMERA_LEAD_MAX:
			lead = lead.normalized() * CAMERA_LEAD_MAX

		var desired: Vector2 = target_pos + lead
		# Frame-rate-independent exponential smoothing toward `desired`,
		# tuned by POSITION_SMOOTHING_SPEED (Register row).
		var weight: float = 1.0 - exp(-POSITION_SMOOTHING_SPEED * delta)
		_follow_position = _follow_position.lerp(desired, weight)

	_update_shake(delta)

	var position_with_effects: Vector2 = _follow_position + _shake_offset
	global_position = _clamp_to_arena_bounds(position_with_effects)


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	_tick_previous = _tick_current
	_tick_current = target.global_position


## The target's position as it is DRAWN this frame: interpolated between the
## last two physics ticks by the engine's interpolation fraction. While the
## tree is paused no ticks are sampled, so it returns the settled position
## instead of replaying the last step.
func _target_render_position() -> Vector2:
	if target == null:
		return Vector2.ZERO
	if not _interpolate_target or not is_inside_tree() or get_tree().paused:
		return target.global_position
	return _tick_previous.lerp(_tick_current, Engine.get_physics_interpolation_fraction())


## Keeps `zoom` divided by the window's content scale factor (see
## `_applied_content_scale`). Cheap enough to run every frame, so a resize or
## rotation on a phone is picked up without a signal.
func _sync_content_scale() -> void:
	if not is_inside_tree():
		return
	var win: Window = get_window()
	if win == null:
		return
	var f: float = maxf(win.content_scale_factor, 0.01)
	if not is_equal_approx(f, _applied_content_scale):
		zoom = zoom * (_applied_content_scale / f)
		_applied_content_scale = f


## Test/utility hook: immediately (no smoothing lag) moves the camera to
## `pos`, clamped to the current arena bounds at the current zoom. The
## Camera bounds test uses this to sweep extreme positions without waiting
## many frames for exponential smoothing to converge.
func snap_to(pos: Vector2) -> void:
	_follow_position = pos
	_shake_offset = Vector2.ZERO
	_trauma = 0.0
	if target != null:
		_previous_target_position = _target_render_position()
	global_position = _clamp_to_arena_bounds(pos)


## Screen-shake hook (task brief: "a screen-shake hook other systems can
## call later"). `amount` is 0..1 trauma, additive, clamped to 1.0.
##
## Gated by the Settings screen's Screen Shake toggle (MASTER_SDLC.md >
## Provisional Values Register > "Interfaces" > "Settings" row;
## src/core/game_settings.gd): disabled, a call here is silently dropped
## rather than accumulating trauma that never visibly shakes anything --
## `_trauma` also decays back toward 0 on its own (`_update_shake()`), so a
## player who re-enables shake mid-decay does not see a stale backlog fire.
func add_trauma(amount: float) -> void:
	if not GameSettings.is_screen_shake_enabled():
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func get_trauma_for_test() -> float:
	return _trauma


func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		_shake_offset = Vector2.ZERO
		return
	# "decaying over 0.25 s" (Register): trauma itself decays linearly to
	# zero in SCREEN_SHAKE_DECAY_TIME seconds if not re-triggered. Offset
	# magnitude scales with trauma^2 (camera-system skill's convention) so
	# the shake eases out rather than cutting off abruptly at exactly 12 px.
	_trauma = maxf(_trauma - (1.0 / SCREEN_SHAKE_DECAY_TIME) * delta, 0.0)
	var magnitude: float = _trauma * _trauma * SCREEN_SHAKE_MAX
	_shake_time += delta
	var t: float = _shake_time * SHAKE_NOISE_FREQUENCY_HZ
	var nx: float = clampf(_shake_noise.get_noise_2d(t, 0.0) * 1.5, -1.0, 1.0)
	var ny: float = clampf(_shake_noise.get_noise_2d(t, 100.0) * 1.5, -1.0, 1.0)
	_shake_offset = Vector2(nx, ny) * magnitude


## Sets the camera's view scale (Register > "View scale" row), clamped to
## [VIEW_SCALE_MIN, VIEW_SCALE_MAX]. `animate` eases `zoom` over
## ZOOM_EASE_TIME (Register > "Zoom ease" row) using a Tween; pass false for
## an immediate jump (used by the Camera bounds test).
##
## Scope boundary, named rather than silently crossed: this method is the
## hook a later task calls; it does NOT itself decide when to zoom. The
## Register's "Zoom trigger 1.15" and "Zoom 0.9 (corridor trigger)" rows
## (player speed > 1.5x base, Tower losing >= 10% max health in 2 s, boss
## corridor biomes) depend on the player's speed state (P2.1) and the
## Tower's health/shield events (P2.4), neither of which exists yet and
## neither of which this task owns. Wiring those triggers is left to
## whichever task first has both dependencies available.
func set_view_scale(new_view_scale: float, animate: bool = true) -> void:
	var clamped_scale: float = clampf(new_view_scale, VIEW_SCALE_MIN, VIEW_SCALE_MAX)
	var target_zoom: Vector2 = Vector2.ONE / (clamped_scale * _applied_content_scale)
	if animate and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(self, "zoom", target_zoom, ZOOM_EASE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		zoom = target_zoom


## Current view scale implied by `zoom` (inverse of set_view_scale's input).
func get_view_scale() -> float:
	if zoom.x <= 0.0:
		return 1.0
	return 1.0 / (zoom.x * _applied_content_scale)


## The world-space size of the visible rectangle at the current zoom
## (Register > "View scale" row: "1.0 = 1920x1080 world px"). Exposed for
## other systems (e.g. a later off-screen Tower indicator) that need to
## reason about what is on screen.
func get_visible_world_size() -> Vector2:
	var zx: float = zoom.x if zoom.x > 0.0 else 1.0
	var zy: float = zoom.y if zoom.y > 0.0 else 1.0
	return Vector2(VIEWPORT_REFERENCE_SIZE.x / (zx * _applied_content_scale), VIEWPORT_REFERENCE_SIZE.y / (zy * _applied_content_scale))


## The one place the arena bounds invariant is enforced: the visible
## rectangle centred on the returned position, sized by `get_visible_world_size()`,
## never extends past [arena_center -/+ ARENA_SIZE/2]. Deliberately axis-
## aligned only -- this camera never sets `rotation`, because a rotated
## viewport's bounding box would no longer match this clamp's math.
func _clamp_to_arena_bounds(pos: Vector2) -> Vector2:
	var half_extent: Vector2 = get_visible_world_size() / 2.0
	var arena_min: Vector2 = arena_center - ARENA_SIZE / 2.0
	var arena_max: Vector2 = arena_center + ARENA_SIZE / 2.0
	# HUD margins: the view may extend past each wall by the HUD band (D141).
	var view_scale_now: float = get_view_scale()
	var margin_min: Vector2 = Vector2(HUD_MARGIN_SIDE, HUD_MARGIN_TOP) * view_scale_now * _applied_content_scale
	var margin_max: Vector2 = Vector2(HUD_MARGIN_SIDE, HUD_MARGIN_BOTTOM) * view_scale_now * _applied_content_scale

	var clamped: Vector2 = pos
	if half_extent.x * 2.0 <= ARENA_SIZE.x:
		clamped.x = clampf(pos.x, arena_min.x + half_extent.x - margin_min.x, arena_max.x - half_extent.x + margin_max.x)
	else:
		# Degenerate case, out of the Register's tested view-scale range
		# (Register > "Arena-to-view ratio" row guarantees the arena is at
		# least 1.4x the largest view per axis within [0.9, 1.15]): the view
		# is wider than the arena on this axis, so there is no valid clamp
		# range and the camera centres on the arena instead of oscillating.
		clamped.x = arena_center.x
	if half_extent.y * 2.0 <= ARENA_SIZE.y:
		clamped.y = clampf(pos.y, arena_min.y + half_extent.y - margin_min.y, arena_max.y - half_extent.y + margin_max.y)
	else:
		clamped.y = arena_center.y
	return clamped


## Subtle edge darkening ("genuinely nice to look at", task brief; kept
## cheap and readable per the same brief -- one fullscreen shader pass, no
## per-frame cost beyond what the GPU already pays for the frame). Built
## procedurally here (not as a scene node in scenes/arena.tscn or any other
## file this task cannot write) so any scene that instances a Camera2D with
## this script attached gets it automatically, with no edit required to
## scenes/main.tscn, scenes/player.tscn, or scenes/tower.tscn.
##
## Skipped under the headless display driver: gdUnit4's test runs are
## `--headless`, and compiling a canvas_item shader with no rendering device
## backing the headless display server is a real risk of exactly the kind of
## hidden engine error LEDGER F02-14 exists to catch. The vignette is purely
## cosmetic and has no gameplay effect, so skipping it under `--headless`
## costs nothing the acceptance test or run_tests.ps1's engine-error guard
## can see, while a shader-compile error under headless would fail both.
func _setup_vignette() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CameraVignette"
	# Assumption, named rather than silently picked: P2.6 (HUD) has not been
	# built yet and this task does not know what CanvasLayer number it will
	# use. Layer 4 is chosen so the vignette sits above the default world
	# layer (0) and below the 2d-essentials skill's own suggested HUD/pause
	# layers (1-2) is NOT guaranteed -- reviewers/P2.6 may need to revisit
	# this number once the HUD's own layer is decided.
	layer.layer = 4
	var rect: ColorRect = ColorRect.new()
	rect.name = "VignetteOverlay"
	rect.color = Color(0.0, 0.0, 0.0, 1.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader: Shader = load("res://src/camera/vignette.gdshader") as Shader
	if shader != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
	layer.add_child(rect)
	add_child(layer)

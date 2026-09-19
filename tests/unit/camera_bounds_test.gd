extends GdUnitTestSuite

## Camera bounds test (P2.2; MASTER_SDLC.md > Acceptance Test Matrix >
## Technical Tests; PLAN.md > P2.2 exit criterion: "Sweep passes at every
## view scale (0.9 to 1.15)"). Sweeps GameCamera to all four corners and
## four edge midpoints of the 4800x3200 arena (MASTER_SDLC.md > Provisional
## Values Register > Arena & Camera > "Arena size" row) at six view scales
## spanning [0.9, 1.15] (same table, "View scale" row) and asserts the
## visible rectangle -- centred on the camera's global_position, sized by
## (1920x1080 world px at view_scale 1.0) x view_scale (same table, "View
## scale" row) -- never extends past the arena's [-2400,2400] x
## [-1600,1600] bounds (Tower-at-centre origin; see
## src/camera/game_camera.gd's own header for that assumption, named there
## rather than silently made).
##
## Uses GameCamera.snap_to() to jump straight to each swept position rather
## than waiting for the exponential position-smoothing to converge over many
## frames -- snap_to() still runs through the same _clamp_to_arena_bounds()
## the normal _process() path uses, so this exercises the real clamp, not a
## stand-in for it.

const GameCameraScript: GDScript = preload("res://src/camera/game_camera.gd")

const ARENA_HALF: Vector2 = Vector2(2400.0, 1600.0) # half of the Register's 4800x3200 "Arena size" row
const VIEWPORT_REF: Vector2 = Vector2(1920.0, 1080.0) # "View scale" row: "1.0 = 1920x1080 world px"
const VIEW_SCALES: Array[float] = [0.9, 0.95, 1.0, 1.05, 1.1, 1.15] # sweeps the "View scale" row's full [0.9, 1.15] range
const EPSILON: float = 0.01 # float-comparison tolerance only; not a gameplay number

var _camera: Camera2D


func before_test() -> void:
	_camera = auto_free(Camera2D.new())
	_camera.set_script(GameCameraScript)
	add_child(_camera)


## Far outside every corner and edge midpoint of the arena, so the clamp is
## guaranteed to actually engage at every tested view scale rather than the
## target already happening to sit inside the unclamped range.
func _sweep_targets() -> Array[Vector2]:
	var reach: Vector2 = ARENA_HALF * 4.0
	return [
		Vector2(-reach.x, -reach.y), Vector2(reach.x, -reach.y), # NW, NE
		Vector2(-reach.x, reach.y), Vector2(reach.x, reach.y), # SW, SE
		Vector2(0.0, -reach.y), Vector2(0.0, reach.y), # N edge, S edge
		Vector2(-reach.x, 0.0), Vector2(reach.x, 0.0), # W edge, E edge
	]


func _assert_visible_rect_within_bounds(scale: float, target: Vector2, center: Vector2 = Vector2.ZERO) -> void:
	var half_extent: Vector2 = VIEWPORT_REF / (2.0 * Vector2(_camera.zoom.x, _camera.zoom.y))
	var visible_min: Vector2 = _camera.global_position - half_extent
	var visible_max: Vector2 = _camera.global_position + half_extent
	var bound_min: Vector2 = center - ARENA_HALF
	var bound_max: Vector2 = center + ARENA_HALF
	assert_float(visible_min.x).append_failure_message(
		"view_scale=%.2f target=%s center=%s: visible_min.x=%.3f is left of the arena's left wall at %.1f" % [scale, target, center, visible_min.x, bound_min.x]
	).is_greater_equal(bound_min.x - EPSILON)
	assert_float(visible_max.x).append_failure_message(
		"view_scale=%.2f target=%s center=%s: visible_max.x=%.3f is right of the arena's right wall at %.1f" % [scale, target, center, visible_max.x, bound_max.x]
	).is_less_equal(bound_max.x + EPSILON)
	assert_float(visible_min.y).append_failure_message(
		"view_scale=%.2f target=%s center=%s: visible_min.y=%.3f is above the arena's top wall at %.1f" % [scale, target, center, visible_min.y, bound_min.y]
	).is_greater_equal(bound_min.y - EPSILON)
	assert_float(visible_max.y).append_failure_message(
		"view_scale=%.2f target=%s center=%s: visible_max.y=%.3f is below the arena's bottom wall at %.1f" % [scale, target, center, visible_max.y, bound_max.y]
	).is_less_equal(bound_max.y + EPSILON)


# --- Camera bounds test (named acceptance test) ----------------------------

func test_visible_rect_stays_within_arena_bounds_across_the_full_view_scale_range() -> void:
	for scale in VIEW_SCALES:
		_camera.set_view_scale(scale, false)
		for target in _sweep_targets():
			_camera.snap_to(target)
			_assert_visible_rect_within_bounds(scale, target)


# --- Boundary and near-boundary sanity, so the sweep is not only extreme ---

func test_camera_centred_at_arena_centre_stays_within_bounds() -> void:
	for scale in VIEW_SCALES:
		_camera.set_view_scale(scale, false)
		_camera.snap_to(Vector2.ZERO)
		_assert_visible_rect_within_bounds(scale, Vector2.ZERO)


## Distinguishes "clamp to the right-sized rectangle" from "clamp to the
## right rectangle": with arena_center left at its default Vector2.ZERO
## (matching scenes/arena.tscn's Tower-at-centre-of-origin placement, see
## game_camera.gd's own header assumption), a clamp that has the right
## ARENA_SIZE but forgets to add arena_center's offset would still pass
## every other test in this suite, since 0 offset is indistinguishable from
## "no offset applied at all". This test sets a non-zero arena_center so
## that specific defect class has something to be visible against.
func test_visible_rect_respects_a_non_zero_arena_center() -> void:
	var center: Vector2 = Vector2(500.0, -300.0)
	_camera.arena_center = center
	var reach: Vector2 = ARENA_HALF * 4.0
	for scale in VIEW_SCALES:
		_camera.set_view_scale(scale, false)
		for target in [
			center + Vector2(-reach.x, -reach.y), center + Vector2(reach.x, -reach.y),
			center + Vector2(-reach.x, reach.y), center + Vector2(reach.x, reach.y),
		]:
			_camera.snap_to(target)
			_assert_visible_rect_within_bounds(scale, target, center)


func test_view_scale_is_clamped_to_the_register_range() -> void:
	_camera.set_view_scale(0.5, false)
	assert_float(_camera.get_view_scale()).append_failure_message(
		"set_view_scale(0.5) was not clamped up to VIEW_SCALE_MIN"
	).is_equal_approx(GameCamera.VIEW_SCALE_MIN, 0.0001)
	_camera.set_view_scale(2.0, false)
	assert_float(_camera.get_view_scale()).append_failure_message(
		"set_view_scale(2.0) was not clamped down to VIEW_SCALE_MAX"
	).is_equal_approx(GameCamera.VIEW_SCALE_MAX, 0.0001)


# --- Shake must never defeat the clamp (Register: shake applied before it) -

func test_max_trauma_shake_never_pushes_the_visible_rect_past_arena_bounds() -> void:
	_camera.set_view_scale(1.15, false) # the widest visible rect in the valid range
	for i in 50: # many samples, since shake direction is randomised
		_camera.snap_to(Vector2(ARENA_HALF.x - 50.0, ARENA_HALF.y - 50.0)) # near a corner
		_camera.add_trauma(1.0)
		_camera._update_shake(1.0 / 60.0)
		var position_with_effects: Vector2 = _camera._follow_position + _camera._shake_offset
		_camera.global_position = _camera._clamp_to_arena_bounds(position_with_effects)
		_assert_visible_rect_within_bounds(1.15, Vector2(ARENA_HALF.x - 50.0, ARENA_HALF.y - 50.0))


# --- Degenerate-axis fallback: documented in game_camera.gd as out of the --
# --- Register's tested range, but must not crash or leave a NaN position ---

func test_view_wider_than_arena_on_an_axis_centres_rather_than_errors() -> void:
	_camera.arena_center = Vector2.ZERO
	# Force an artificial zoom smaller than anything the Register allows, so
	# the visible width exceeds the whole arena on the X axis.
	_camera.zoom = Vector2(0.01, 1.0)
	_camera.snap_to(Vector2(10000.0, 0.0))
	assert_float(_camera.global_position.x).append_failure_message(
		"degenerate wider-than-arena case did not fall back to arena_center.x"
	).is_equal_approx(0.0, 0.001)
	assert_bool(is_nan(_camera.global_position.x)).is_false()
	assert_bool(is_nan(_camera.global_position.y)).is_false()

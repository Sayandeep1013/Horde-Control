extends RefCounted
class_name SpawnGeometry

## SpawnGeometry (P2.8 Wave Director). Pure geometry and validation for the
## two Spawn Rings (MASTER_SDLC.md > Provisional Values Register > Spawning
## & Waves > "Spawn Rings", "Camera exclusion", "Ring validation"). Every
## function here is a pure function of its arguments -- no SimClock, no
## EntityRegistry, no scene tree -- so it is testable in total isolation and
## reusable from src/director/wave_director.gd without that file owning the
## math. Matches this project's existing precedent for a stateless,
## RefCounted geometry helper (src/enemy/attack_slot_manager.gd,
## src/core/keyed_rng.gd).
##
## ## Register citations transcribed here
## - "Spawn Rings": "Tower ring (Tower Seekers) / view ring (Hunters,
##   Opportunists, finishers); both inner radius ~1331 px, width 128 px,
##   clipped to arena inset 32 px."
## - "Camera exclusion": "Reject a candidate inside view + 64 px margin or
##   inside the Interaction Radius."
## - "Ring validation": "Shift along the ring, alternating directions, up to
##   8 steps of 10 degrees; none valid -> retry next tick without using
##   budget; after 8 consecutive failed ticks, ignore direction weighting
##   and take the nearest valid point; if that ring has none, use the other
##   ring."
##
## ## Interpretation, named rather than silently assumed
## "Shifted ... up to eight steps of 10 degrees" is read as EIGHT SHIFT
## ATTEMPTS beyond the original (unshifted) candidate -- i.e. nine total
## checks per tick (the original, then +10 deg, -10 deg, +20 deg, -20 deg,
## +30 deg, -30 deg, +40 deg, -40 deg), not eight checks INCLUDING the
## original. The original candidate is not itself a "shift", so it is not
## counted against the eight.
##
## The camera-view exclusion is applied as an axis-aligned RECTANGLE check
## (the camera's own rectangular view, expanded by the margin on every
## side), not a circular buffer -- "the player's current camera view" is
## GameCamera.get_visible_world_size(), a rectangle, and "plus a 64 pixel
## margin" reads as expanding that rectangle uniformly.


## One point on a ring at `angle_radians` (0 = +X / east, increasing
## counter-clockwise per Godot's Vector2 convention) and `radius_fraction`
## (0..1) of the way through the ring's width, measured from its inner edge.
static func sample_ring_point(ring: RingDefinition, ring_center: Vector2, angle_radians: float, radius_fraction: float) -> Vector2:
	var radius: float = float(ring.inner_radius_px) + clampf(radius_fraction, 0.0, 1.0) * float(ring.width_px)
	return ring_center + Vector2(cos(angle_radians), sin(angle_radians)) * radius


## "Reject a candidate inside view + 64 px margin" -- true when `point` is
## OUTSIDE the expanded view rectangle (i.e. the camera-exclusion check
## passes).
static func is_outside_camera_view(point: Vector2, view_center: Vector2, view_half_size: Vector2, camera_margin_px: float) -> bool:
	var dx: float = absf(point.x - view_center.x)
	var dy: float = absf(point.y - view_center.y)
	return dx > view_half_size.x + camera_margin_px or dy > view_half_size.y + camera_margin_px


## "or inside the Interaction Radius" -- true when `point` is OUTSIDE the
## Tower's Interaction Radius circle (i.e. this check passes).
static func is_outside_tower_interaction_radius(point: Vector2, tower_center: Vector2, interaction_radius_px: float) -> bool:
	return point.distance_to(tower_center) > interaction_radius_px


## "clipped to the arena inset by 32 pixels" -- true when `point` lies
## within the arena's bounds, inset by `inset_px` on every side.
static func is_within_arena_inset(point: Vector2, arena_center: Vector2, arena_half_size: Vector2, inset_px: float) -> bool:
	var dx: float = absf(point.x - arena_center.x)
	var dy: float = absf(point.y - arena_center.y)
	return dx <= arena_half_size.x - inset_px and dy <= arena_half_size.y - inset_px


## Combines all three Register rules into one pass/fail. A candidate is
## valid only when it clears the camera exclusion AND the Tower Interaction
## Radius AND sits inside the arena inset.
static func is_candidate_valid(point: Vector2, tower_center: Vector2, interaction_radius_px: float, view_center: Vector2, view_half_size: Vector2, camera_margin_px: float, arena_center: Vector2, arena_half_size: Vector2, arena_inset_px: float) -> bool:
	if not is_outside_camera_view(point, view_center, view_half_size, camera_margin_px):
		return false
	if not is_outside_tower_interaction_radius(point, tower_center, interaction_radius_px):
		return false
	if not is_within_arena_inset(point, arena_center, arena_half_size, arena_inset_px):
		return false
	return true


## The eight-step alternating-direction shift (Register > "Ring
## validation"), tried after the original candidate. Returns
## [0.0, +step, -step, +2*step, -2*step, +3*step, -3*step, +4*step, -4*step]
## for `max_shift_steps = 8` -- see header interpretation note.
static func _shift_offsets_degrees(max_shift_steps: int, step_degrees: float) -> Array[float]:
	var offsets: Array[float] = [0.0]
	var pairs: int = max_shift_steps / 2
	for k in range(1, pairs + 1):
		offsets.append(float(k) * step_degrees)
		offsets.append(-float(k) * step_degrees)
	return offsets


## One tick's worth of validation for one spawn candidate: the original
## angle, then up to `max_shift_steps` alternating shifts of `step_degrees`.
## Returns {valid: bool, position: Vector2, angle_radians: float,
## attempts: int, shifted: bool} -- `shifted` is true iff the original
## candidate itself was rejected and a later attempt succeeded (or all
## failed).
static func validate_and_shift(candidate_angle_radians: float, radius_fraction: float, ring: RingDefinition, ring_center: Vector2, tower_center: Vector2, interaction_radius_px: float, view_center: Vector2, view_half_size: Vector2, camera_margin_px: float, arena_center: Vector2, arena_half_size: Vector2, arena_inset_px: float, max_shift_steps: int, step_degrees: float) -> Dictionary:
	var offsets: Array[float] = _shift_offsets_degrees(max_shift_steps, step_degrees)
	var attempts: int = 0
	for offset_deg in offsets:
		attempts += 1
		var angle: float = candidate_angle_radians + deg_to_rad(offset_deg)
		var point: Vector2 = sample_ring_point(ring, ring_center, angle, radius_fraction)
		if is_candidate_valid(point, tower_center, interaction_radius_px, view_center, view_half_size, camera_margin_px, arena_center, arena_half_size, arena_inset_px):
			return {"valid": true, "position": point, "angle_radians": angle, "attempts": attempts, "shifted": attempts > 1}
	return {"valid": false, "position": Vector2.ZERO, "angle_radians": candidate_angle_radians, "attempts": attempts, "shifted": true}


## "After 8 consecutive failed ticks ... ignore direction weighting and take
## the nearest valid point on the ring instead." A full sweep of the ring at
## `resolution_degrees` steps outward from `preferred_angle_radians` in both
## directions, at a fixed mid-width radius fraction (0.5 -- direction
## weighting is what is being ignored here, not ring width; the radius
## fraction is not itself a weighted quantity anywhere in the Register).
## Returns the first valid point found (nearest in angle to the preferred
## bearing) or null if the entire ring has no valid point at all.
static func nearest_valid_point_on_ring(preferred_angle_radians: float, ring: RingDefinition, ring_center: Vector2, tower_center: Vector2, interaction_radius_px: float, view_center: Vector2, view_half_size: Vector2, camera_margin_px: float, arena_center: Vector2, arena_half_size: Vector2, arena_inset_px: float, resolution_degrees: float = 5.0) -> Variant:
	const RADIUS_FRACTION_FALLBACK: float = 0.5
	var steps: int = int(180.0 / resolution_degrees)
	var offsets: Array[float] = [0.0]
	for k in range(1, steps + 1):
		offsets.append(float(k) * resolution_degrees)
		offsets.append(-float(k) * resolution_degrees)
	for offset_deg in offsets:
		var angle: float = preferred_angle_radians + deg_to_rad(offset_deg)
		var point: Vector2 = sample_ring_point(ring, ring_center, angle, RADIUS_FRACTION_FALLBACK)
		if is_candidate_valid(point, tower_center, interaction_radius_px, view_center, view_half_size, camera_margin_px, arena_center, arena_half_size, arena_inset_px):
			return point
	return null


## Deterministic lane sequence for a Split Assault spawn group (Register >
## Directional weighting > "Split Assault": "each lane-split spawn group
## assigns ceil(0.6 x n) spawns to the heavier lane" (C-GROUPS): "alternating
## by spawn index"). Returns an Array[bool] of length `count`, true = heavy
## lane, alternating Heavy/Light by index until the lighter lane's quota is
## exhausted, with any remainder going to the heavier lane (heavy_count is
## always >= light_count since ceil(0.6n) >= n/2, so light exhausts first or
## together).
static func split_assault_lane_sequence(count: int, heavy_share: float) -> Array[bool]:
	var heavy_count: int = ceili(heavy_share * float(count))
	var light_count: int = count - heavy_count
	var sequence: Array[bool] = []
	var heavy_remaining: int = heavy_count
	var light_remaining: int = light_count
	var next_is_heavy: bool = true
	for i in count:
		var take_heavy: bool
		if heavy_remaining <= 0:
			take_heavy = false
		elif light_remaining <= 0:
			take_heavy = true
		else:
			take_heavy = next_is_heavy
		if take_heavy:
			heavy_remaining -= 1
		else:
			light_remaining -= 1
		sequence.append(take_heavy)
		next_is_heavy = not next_is_heavy
	return sequence

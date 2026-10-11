extends RefCounted
class_name BulletPattern
## PT-SWARM bullet patterns (docs/33 §C5; Register "Enemy bullets", D347).
## Pure angle geometry plus one `emit()` that hands the shots to the arena's
## EnemyBulletField. Archero-style: every pattern is readable and dodgeable,
## so radial patterns carry deliberate gaps and spirals rotate at a fixed,
## learnable rate. Angles are radians, 0 = +X, clockwise on screen (+Y down).


## `count` shots evenly around a full circle starting at `start_angle`.
## Shots whose bearing falls inside any gap (centre +- `gap_half_width`) are
## left out, which is what makes a ring passable.
static func radial(count: int, start_angle: float, gap_centers: Array[float] = [], gap_half_width: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 0:
		return out
	var step: float = TAU / float(count)
	for i in count:
		var a: float = start_angle + step * float(i)
		var in_gap: bool = false
		for g in gap_centers:
			if absf(angle_difference(g, a)) <= gap_half_width:
				in_gap = true
				break
		if not in_gap:
			out.append(wrapf(a, -PI, PI))
	return out


## `count` shots spread evenly across `spread` radians centred on `center_angle`
## (one shot fires straight at the centre when `count` is 1).
static func fan(count: int, center_angle: float, spread: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 0:
		return out
	if count == 1:
		out.append(wrapf(center_angle, -PI, PI))
		return out
	for i in count:
		var t: float = float(i) / float(count - 1) - 0.5
		out.append(wrapf(center_angle + t * spread, -PI, PI))
	return out


## A fan aimed from `origin` at `target`.
static func aimed(origin: Vector2, target: Vector2, count: int, spread: float) -> PackedFloat32Array:
	return fan(count, (target - origin).angle(), spread)


## The bearings of `arms` spiral arms at `base_angle` (one volley of a spiral).
static func spiral_arms(arms: int, base_angle: float) -> PackedFloat32Array:
	return radial(arms, base_angle)


## Fires one shot per angle from `origin` into `field`.
static func emit(field: EnemyBulletField, origin: Vector2, angles: PackedFloat32Array, speed: float, radius: float, damage: float, hit_player: bool = true, hit_tower: bool = false, attacker: Node = null, color: Color = Color(1.0, 0.45, 0.1), lifetime: float = EnemyBulletField.DEFAULT_LIFETIME_SECONDS) -> int:
	if field == null:
		return 0
	for a in angles:
		field.fire(origin, Vector2.from_angle(a) * speed, radius, damage, hit_player, hit_tower, attacker, color, lifetime)
	return angles.size()


## A rotating emitter: every `next()` returns the arms' bearings and advances
## the base angle by `rotation_step` (positive = clockwise on screen).
class Spiral extends RefCounted:
	var arms: int = 3
	var rotation_step: float = deg_to_rad(12.0)
	var angle: float = 0.0

	func _init(p_arms: int = 3, p_rotation_step: float = deg_to_rad(12.0), p_start: float = 0.0) -> void:
		arms = p_arms
		rotation_step = p_rotation_step
		angle = p_start

	func next() -> PackedFloat32Array:
		var out: PackedFloat32Array = BulletPattern.spiral_arms(arms, angle)
		angle = wrapf(angle + rotation_step, -PI, PI)
		return out

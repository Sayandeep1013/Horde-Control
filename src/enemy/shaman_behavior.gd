extends EnemyBehavior
class_name ShamanBehavior
## Goblin Shaman (docs/33 §C5; Register "v1.0 Enemies, Bosses & Waves" >
## "Goblin Shaman", D349): a ranged caster from wave 6. Holds 280-380 px from
## the player and every 2.8 s, after a 0.6 s glow on its staff orb, casts a fan
## of 3 slow orbs at the player. Distinct from the Bomber (lobs to a spot) and
## the Hunter (melee): its shots travel and can be side-stepped or blocked by
## rocks. Staggered first cast like the Bomber's, so a group does not volley in
## unison.

enum State { APPROACH, HOLD, RETREAT, CASTING }

const HOLD_MIN_PX: float = 280.0
const HOLD_MAX_PX: float = 380.0
const CAST_INTERVAL_SECONDS: float = 2.8
const CAST_WINDUP_SECONDS: float = 0.6
const FAN_COUNT: int = 3
const FAN_SPREAD_DEG: float = 28.0
const ORB_SPEED: float = 150.0
const ORB_RADIUS: float = 11.0
const ORB_DAMAGE: float = 12.0
const ORB_COLOR: Color = Color(1.0, 0.38, 0.12)
const RETREAT_SPEED_SCALE: float = 0.8

var state: State = State.APPROACH
var _next_cast: float = -1.0
var _cast_at: float = -1.0
var casts_made: int = 0
var _bullets: EnemyBulletField = null


func suppress_default_attack() -> bool:
	return true


## 0..1 glow of the staff orb: rises over the wind-up (ShamanCue draws it).
func get_charge() -> float:
	if state == State.CASTING:
		return clampf(1.0 - (_cast_at - _now()) / CAST_WINDUP_SECONDS, 0.0, 1.0)
	return 0.0


func pre_step(_delta: float) -> bool:
	var player: Node2D = controller.get_player()
	if player == null or not is_instance_valid(player):
		return false
	var now: float = _now()
	var to_player: Vector2 = player.global_position - controller.global_position
	var dist: float = to_player.length()
	if state == State.CASTING:
		controller.hold_position()
		if now >= _cast_at:
			_cast(player)
			state = State.HOLD
		return true
	if _next_cast < 0.0:
		var stagger: float = float(int(absf(controller.global_position.x * 1.3 + controller.global_position.y)) % 100) / 100.0
		_next_cast = SimRate.reschedule(_next_cast, now, CAST_INTERVAL_SECONDS * (0.5 + 0.5 * stagger))
	if dist < HOLD_MIN_PX:
		state = State.RETREAT
	elif dist > HOLD_MAX_PX:
		state = State.APPROACH
	elif state != State.RETREAT or dist > (HOLD_MIN_PX + HOLD_MAX_PX) * 0.5:
		state = State.HOLD
	match state:
		State.APPROACH:
			controller.drive_toward(player.global_position, 1.0, &"player")
		State.RETREAT:
			var away: Vector2 = -to_player.normalized() if dist > 0.01 else Vector2.RIGHT
			controller.drive_toward(controller.global_position + away * 100.0, RETREAT_SPEED_SCALE)
		_:
			controller.hold_position()
	if now >= _next_cast and dist <= HOLD_MAX_PX + 80.0:
		_next_cast = SimRate.reschedule(_next_cast, now, CAST_INTERVAL_SECONDS)
		_cast_at = now + CAST_WINDUP_SECONDS
		state = State.CASTING
		controller.windup_started.emit()
	return true


func _cast(player: Node2D) -> void:
	casts_made += 1
	if _bullets == null or not is_instance_valid(_bullets):
		_bullets = EnemyBulletField.get_or_create(controller.get_parent(), controller.get_registry())
	var origin: Vector2 = controller.global_position + Vector2(0.0, -30.0)
	BulletPattern.emit(_bullets, origin, BulletPattern.aimed(origin, player.global_position, FAN_COUNT, deg_to_rad(FAN_SPREAD_DEG)), ORB_SPEED, ORB_RADIUS, scaled_damage(ORB_DAMAGE), true, false, controller, ORB_COLOR)

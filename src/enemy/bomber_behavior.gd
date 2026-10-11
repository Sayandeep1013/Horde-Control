extends EnemyBehavior
class_name BomberBehavior
## v1.0 Bomber (docs/31 §5.1; Register "v1.0 Enemies, Bosses & Waves" >
## "Bomber"): a ranged goblin that holds 240-300 px from the player and lobs
## dynamite every 3.0 s. The dynamite lands on the player's position, shown as
## a 1.0 s, 56 px telegraph ring, then deals 22 damage (x the wave/difficulty
## multiplier) to the player and to the Tower if the blast reaches it.

enum State { APPROACH, HOLD, RETREAT }

const HOLD_MIN_PX: float = 240.0
const HOLD_MAX_PX: float = 300.0
const THROW_INTERVAL_SECONDS: float = 3.0
const TELEGRAPH_SECONDS: float = 1.0
const BLAST_RADIUS_PX: float = 56.0
const BLAST_DAMAGE: float = 22.0
## Retreating is slower than approaching so a chased Bomber can still be caught.
const RETREAT_SPEED_SCALE: float = 0.8
## The held-dynamite cue is hidden for this long after a throw (Register: Bomber cue).
const RELOAD_HIDE_SECONDS: float = 0.7

var state: State = State.APPROACH
var _next_throw_time: float = -1.0
var throws_made: int = 0
var _last_throw_time: float = -INF


## True while the Bomber holds a lit stick ready to throw (BomberThrowCue draws
## it overhead): always, except for RELOAD_HIDE_SECONDS after a throw while the
## dynamite is in the air.
func is_armed() -> bool:
	return controller != null and _now() - _last_throw_time >= RELOAD_HIDE_SECONDS


## Seconds until the next throw (0 when due); drives the cue's spark rate.
func seconds_to_throw() -> float:
	return maxf(0.0, _next_throw_time - _now()) if _next_throw_time >= 0.0 else THROW_INTERVAL_SECONDS


func suppress_default_attack() -> bool:
	return true


func pre_step(_delta: float) -> bool:
	var player: Node2D = controller.get_player()
	if player == null or not is_instance_valid(player):
		return false
	var to_player: Vector2 = player.global_position - controller.global_position
	var dist: float = to_player.length()
	if dist < HOLD_MIN_PX:
		state = State.RETREAT
	elif dist > HOLD_MAX_PX:
		state = State.APPROACH
	elif state != State.RETREAT or dist > (HOLD_MIN_PX + HOLD_MAX_PX) * 0.5:
		state = State.HOLD # hysteresis: a retreating Bomber keeps backing off to mid-band before it plants
	match state:
		State.APPROACH:
			controller.drive_toward(player.global_position)
		State.RETREAT:
			var away: Vector2 = -to_player.normalized() if dist > 0.01 else Vector2.RIGHT
			controller.drive_toward(controller.global_position + away * 100.0, RETREAT_SPEED_SCALE)
		_:
			controller.hold_position()
	_try_throw(player, dist)
	return true


func _try_throw(player: Node2D, dist: float) -> void:
	var now: float = _now()
	if _next_throw_time < 0.0:
		# First throw one interval after the Bomber first has a target, staggered
		# by position so a group does not lob in unison (deterministic: no RNG).
		var stagger: float = float(int(absf(controller.global_position.x + controller.global_position.y)) % 100) / 100.0
		_next_throw_time = now + THROW_INTERVAL_SECONDS * (0.5 + 0.5 * stagger)
		return
	if now < _next_throw_time or dist > HOLD_MAX_PX + 60.0:
		return
	_next_throw_time = now + THROW_INTERVAL_SECONDS
	throws_made += 1
	_last_throw_time = now
	var parent: Node = controller.get_parent()
	if parent == null:
		return
	controller.windup_started.emit() # plays the throw clip
	EnemyBomb.launch(parent, controller.global_position, player.global_position, TELEGRAPH_SECONDS, BLAST_RADIUS_PX, scaled_damage(BLAST_DAMAGE), true, controller, controller.get_clock(), controller.get_registry())

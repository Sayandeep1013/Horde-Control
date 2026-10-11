extends BossBehavior
class_name KingBehavior
## Bombardier King, the final boss (docs/31 §5.3; Register "v1.0 Enemies,
## Bosses & Waves" > "Bombardier King"). Keeps 300-420 px from the Tower
## (circling when inside the band). Attacks: Barrage (5 dynamite on rings
## around the player, 1.1 s, 26 dmg each, every 6 s), Siege Bomb (1.6 s large
## ring on the Tower, 110 dmg to the Tower only, every 10 s), Call the Horde
## (8 Seekers + 2 Bombers every 16 s). Barrage blasts hurt the player only. Below 50% HP: Barrage throws 8 and the
## Siege Bomb comes every 7 s. Killing him wins the run (WaveDirector ends
## the sequence); in Endless he only ends wave 15.

const HOLD_MIN_PX: float = 300.0
const HOLD_MAX_PX: float = 420.0
const ORBIT_SPEED_SCALE: float = 0.5
const BARRAGE_INTERVAL_SECONDS: float = 6.0
const BARRAGE_COUNT: int = 5
const BARRAGE_COUNT_PHASE_TWO: int = 8
const BARRAGE_FLIGHT_SECONDS: float = 1.1
const BARRAGE_DAMAGE: float = 26.0
const BARRAGE_RADIUS_PX: float = 56.0
const BARRAGE_SCATTER_MIN_PX: float = 70.0
const BARRAGE_SCATTER_MAX_PX: float = 180.0
const SIEGE_INTERVAL_SECONDS: float = 10.0
const SIEGE_INTERVAL_PHASE_TWO_SECONDS: float = 7.0
const SIEGE_FLIGHT_SECONDS: float = 1.6
const SIEGE_DAMAGE: float = 110.0
const SIEGE_RADIUS_PX: float = 130.0
const HORDE_INTERVAL_SECONDS: float = 16.0
const HORDE_SEEKERS: int = 8
const HORDE_BOMBERS: int = 2
const FIRST_BARRAGE_DELAY_SECONDS: float = 3.0
const FIRST_SIEGE_DELAY_SECONDS: float = 7.0
const FIRST_HORDE_DELAY_SECONDS: float = 10.0

var _next_barrage: float = -1.0
var _next_siege: float = -1.0
var _next_horde: float = -1.0
var _orbit_sign: float = 1.0


func _init() -> void:
	boss_id = "king"
	display_name = "Bombardier King"
	phase_two_fraction = 0.5
	core_reward = 20


func suppress_default_attack() -> bool:
	return true


func pre_step(_delta: float) -> bool:
	var tower: Node2D = controller.get_tower()
	if tower == null or not is_instance_valid(tower):
		return false
	var now: float = _now()
	if _next_barrage < 0.0:
		_next_barrage = now + FIRST_BARRAGE_DELAY_SECONDS
		_next_siege = now + FIRST_SIEGE_DELAY_SECONDS
		_next_horde = now + FIRST_HORDE_DELAY_SECONDS
	var to_tower: Vector2 = tower.global_position - controller.global_position
	var dist: float = to_tower.length()
	if dist > HOLD_MAX_PX:
		controller.drive_toward(tower.global_position)
	elif dist < HOLD_MIN_PX:
		var away: Vector2 = -to_tower.normalized() if dist > 0.01 else Vector2.RIGHT
		controller.drive_toward(controller.global_position + away * 100.0)
	else:
		var tangent: Vector2 = to_tower.normalized().orthogonal() * _orbit_sign
		controller.drive_toward(controller.global_position + tangent * 100.0, ORBIT_SPEED_SCALE)
	_run_attacks(now, tower)
	return true


func _run_attacks(now: float, tower: Node2D) -> void:
	var parent: Node = controller.get_parent()
	if parent == null:
		return
	var player: Node2D = controller.get_player()
	if now >= _next_barrage and player != null and is_instance_valid(player):
		_next_barrage = now + BARRAGE_INTERVAL_SECONDS
		_barrage(parent, player)
	if now >= _next_siege:
		_next_siege = now + (SIEGE_INTERVAL_PHASE_TWO_SECONDS if phase >= 2 else SIEGE_INTERVAL_SECONDS)
		controller.windup_started.emit()
		var bomb: EnemyBomb = EnemyBomb.launch(parent, controller.global_position, tower.global_position, SIEGE_FLIGHT_SECONDS, SIEGE_RADIUS_PX, scaled_damage(SIEGE_DAMAGE), true, controller, controller.get_clock(), controller.get_registry())
		bomb.hit_player = false # the Siege Bomb is aimed at the Tower; only the Tower takes the 110
	if now >= _next_horde:
		_next_horde = now + HORDE_INTERVAL_SECONDS
		request_summon("tower_seeker", HORDE_SEEKERS)
		request_summon("bomber", HORDE_BOMBERS)
		Sfx.play("boss_roar", controller.global_position)


func _barrage(parent: Node, player: Node2D) -> void:
	var n: int = BARRAGE_COUNT_PHASE_TWO if phase >= 2 else BARRAGE_COUNT
	controller.windup_started.emit()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_now() * 1000.0) # sim-time seeded: replays identically
	var base_angle: float = rng.randf() * TAU
	for i in n:
		var target: Vector2 = player.global_position
		if i > 0:
			var a: float = base_angle + TAU * float(i) / float(n)
			target += Vector2.from_angle(a) * rng.randf_range(BARRAGE_SCATTER_MIN_PX, BARRAGE_SCATTER_MAX_PX)
		var bomb: EnemyBomb = EnemyBomb.launch(parent, controller.global_position, target, BARRAGE_FLIGHT_SECONDS, BARRAGE_RADIUS_PX, scaled_damage(BARRAGE_DAMAGE), true, controller, controller.get_clock(), controller.get_registry())
		bomb.hit_tower = false # the Barrage is aimed at the player; the Siege Bomb is the Tower attack

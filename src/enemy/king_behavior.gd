extends BossBehavior
class_name KingBehavior
## Bombardier King, the final boss (docs/33 §C4; Register "v1.0 Enemies,
## Bosses & Waves" > "Bombardier King", D340). Keeps 300-420 px from the Tower
## (circling inside the band). Attacks, each telegraphed and dodgeable:
##   Dynamite Fan   0.5 s spark at his hand, then 5 orbs in a 50 degree fan
##                  aimed where the player is heading (a moving player is not
##                  safe by default; a sidestep is).
##   Barrage        5 dynamite: one where the player is heading, four around it.
##   Siege Bomb     1.6 s, 130 px ring on the Tower: 70 to the Tower, and to a
##                  player standing in it.
##   Call the Horde Seekers and Bombers.
## Phase 2 (below 60%): a rotating 3-arm spiral for 3 s, then he is winded
## (stagger 1.5 s). Phase 3 (below 25%): Powder Storm, 5 radial waves with two
## rotating safe gaps plus 3 Bombers, then stagger 2 s.
## Killing him wins the run (WaveDirector ends the sequence); in Endless he
## only ends his wave.
##
## PT-SWARM King defect (D340): his only player attack used to be the Barrage,
## landing where the player stood 1.1 s earlier, so a moving player took 0
## damage over a whole fight (measured: the kite bot, 23 s from wave 15, 0
## player damage), and his only Tower attack was a ring indistinguishable from
## Seeker damage: in play he read as not attacking. Fan, lead-aimed Barrage and
## the phase patterns replace that; tests/unit/pt_swarm_bosses_test.gd checks a
## moving player and the Tower both take damage.

enum State { NORMAL, FAN_WIND, SPIRAL, STORM }

const HOLD_MIN_PX: float = 300.0
const HOLD_MAX_PX: float = 420.0
const ORBIT_SPEED_SCALE: float = 0.5
const PHASE_TWO_FRACTION: float = 0.6
const PHASE_THREE_FRACTION: float = 0.25
const FAN_INTERVAL_SECONDS: float = 3.5
const FAN_FIRST_DELAY_SECONDS: float = 2.0
const FAN_TELEGRAPH_SECONDS: float = 0.5
const FAN_COUNT: int = 5
const FAN_SPREAD_DEG: float = 50.0
const FAN_SPEED: float = 330.0
const FAN_RADIUS: float = 14.0
const FAN_DAMAGE: float = 18.0
## Fraction of the player's velocity x flight time the fan and Barrage lead by.
const AIM_LEAD: float = 0.8
const BARRAGE_INTERVAL_SECONDS: float = 7.0
const BARRAGE_FIRST_DELAY_SECONDS: float = 4.5
const BARRAGE_COUNT: int = 5
const BARRAGE_FLIGHT_SECONDS: float = 1.2
const BARRAGE_DAMAGE: float = 26.0
const BARRAGE_RADIUS_PX: float = 60.0
const BARRAGE_SCATTER_MIN_PX: float = 90.0
const BARRAGE_SCATTER_MAX_PX: float = 150.0
const SIEGE_INTERVAL_SECONDS: float = 10.0
const SIEGE_INTERVAL_PHASE_TWO_SECONDS: float = 7.0
const SIEGE_FIRST_DELAY_SECONDS: float = 6.0
const SIEGE_FLIGHT_SECONDS: float = 1.6
const SIEGE_DAMAGE: float = 70.0
const SIEGE_RADIUS_PX: float = 130.0
const HORDE_INTERVAL_SECONDS: float = 16.0
const HORDE_FIRST_DELAY_SECONDS: float = 10.0
const HORDE_SEEKERS: int = 8
const HORDE_BOMBERS: int = 2
const SPIRAL_INTERVAL_SECONDS: float = 11.0
const SPIRAL_SECONDS: float = 3.0
const SPIRAL_SHOT_INTERVAL_SECONDS: float = 0.12
const SPIRAL_ARMS: int = 3
const SPIRAL_ROTATION_DEG: float = 13.0
const SPIRAL_SPEED: float = 190.0
const SPIRAL_RADIUS: float = 12.0
const SPIRAL_DAMAGE: float = 14.0
const SPIRAL_STAGGER_SECONDS: float = 1.5
const STORM_INTERVAL_SECONDS: float = 14.0
const STORM_WAVES: int = 5
const STORM_WAVE_SPACING_SECONDS: float = 0.7
const STORM_ORBS: int = 22
const STORM_GAP_HALF_DEG: float = 26.0
const STORM_GAP_ROTATION_DEG: float = 25.0
const STORM_SPEED: float = 200.0
const STORM_RADIUS: float = 13.0
const STORM_DAMAGE: float = 16.0
const STORM_BOMBERS: int = 3
const STORM_STAGGER_SECONDS: float = 2.0

var state: State = State.NORMAL
var _next_fan: float = -1.0
var _next_barrage: float = -1.0
var _next_siege: float = -1.0
var _next_horde: float = -1.0
var _next_spiral: float = -1.0
var _next_storm: float = -1.0
var _state_end: float = 0.0
var _next_shot: float = 0.0
var _spiral: BulletPattern.Spiral = null
var _storm_waves_left: int = 0
var _storm_gap: float = 0.0
var _orbit_sign: float = 1.0
var _rng := RandomNumberGenerator.new()
var fans_fired: int = 0
var barrages_thrown: int = 0
var siege_bombs: int = 0
var spirals: int = 0
var storms: int = 0


func _init() -> void:
	boss_id = "king"
	display_name = "Bombardier King"
	phase_fractions = [PHASE_TWO_FRACTION, PHASE_THREE_FRACTION]
	phase_two_fraction = PHASE_TWO_FRACTION
	core_reward = 20


func suppress_default_attack() -> bool:
	return true


func _on_stagger_started() -> void:
	state = State.NORMAL


func _on_phase_entered(new_phase: int) -> void:
	var now: float = _now()
	if new_phase == 2:
		_next_spiral = now + 1.5
	elif new_phase == 3:
		_next_storm = now + 1.0
		Sfx.play("boss_roar", controller.global_position, 10, true)


func pre_step(_delta: float) -> bool:
	if _stagger_step():
		return true
	var tower: Node2D = controller.get_tower()
	if tower == null or not is_instance_valid(tower):
		return false
	var now: float = _now()
	if _next_fan < 0.0:
		_rng.seed = int(controller.get_instance_id() % 100000)
		_next_fan = now + FAN_FIRST_DELAY_SECONDS
		_next_barrage = now + BARRAGE_FIRST_DELAY_SECONDS
		_next_siege = now + SIEGE_FIRST_DELAY_SECONDS
		_next_horde = now + HORDE_FIRST_DELAY_SECONDS
	match state:
		State.FAN_WIND:
			controller.hold_position()
			if now >= _state_end:
				state = State.NORMAL
				_fire_fan()
			return true
		State.SPIRAL:
			controller.hold_position()
			while now >= _next_shot and now < _state_end:
				BulletPattern.emit(bullets(), controller.global_position, _spiral.next(), SPIRAL_SPEED, SPIRAL_RADIUS, scaled_damage(SPIRAL_DAMAGE), true, true, controller, BULLET_RED)
				_next_shot += SPIRAL_SHOT_INTERVAL_SECONDS
			if now >= _state_end:
				state = State.NORMAL
				stagger(SPIRAL_STAGGER_SECONDS)
			return true
		State.STORM:
			controller.hold_position()
			if now >= _next_shot and _storm_waves_left > 0:
				var gaps: Array[float] = [_storm_gap, _storm_gap + PI]
				BulletPattern.emit(bullets(), controller.global_position, BulletPattern.radial(STORM_ORBS, _storm_gap + PI * 0.5, gaps, deg_to_rad(STORM_GAP_HALF_DEG)), STORM_SPEED, STORM_RADIUS, scaled_damage(STORM_DAMAGE), true, true, controller, BULLET_ORANGE)
				_storm_gap += deg_to_rad(STORM_GAP_ROTATION_DEG)
				_storm_waves_left -= 1
				_next_shot = now + STORM_WAVE_SPACING_SECONDS
			if _storm_waves_left <= 0 and now >= _next_shot:
				state = State.NORMAL
				stagger(STORM_STAGGER_SECONDS)
			return true
	_move(tower)
	_run_attacks(now, tower)
	return true


func _move(tower: Node2D) -> void:
	var to_tower: Vector2 = tower.global_position - controller.global_position
	var dist: float = to_tower.length()
	if dist > HOLD_MAX_PX:
		controller.drive_toward(tower.global_position, 1.0, &"tower")
	elif dist < HOLD_MIN_PX:
		var away: Vector2 = -to_tower.normalized() if dist > 0.01 else Vector2.RIGHT
		controller.drive_toward(controller.global_position + away * 100.0)
	else:
		var tangent: Vector2 = to_tower.normalized().orthogonal() * _orbit_sign
		controller.drive_toward(controller.global_position + tangent * 100.0, ORBIT_SPEED_SCALE)


func _run_attacks(now: float, tower: Node2D) -> void:
	var parent: Node = controller.get_parent()
	if parent == null:
		return
	var player: Node2D = controller.get_player()
	if phase >= 3 and now >= _next_storm:
		_begin_storm(now)
		return
	if phase >= 2 and now >= _next_spiral:
		_begin_spiral(now)
		return
	if now >= _next_siege:
		_next_siege = now + (SIEGE_INTERVAL_PHASE_TWO_SECONDS if phase >= 2 else SIEGE_INTERVAL_SECONDS)
		siege_bombs += 1
		controller.windup_started.emit()
		EnemyBomb.launch(parent, controller.global_position, tower.global_position, SIEGE_FLIGHT_SECONDS, SIEGE_RADIUS_PX, scaled_damage(SIEGE_DAMAGE), true, controller, controller.get_clock(), controller.get_registry())
	if now >= _next_horde:
		_next_horde = now + HORDE_INTERVAL_SECONDS
		request_summon("tower_seeker", HORDE_SEEKERS)
		request_summon("bomber", HORDE_BOMBERS)
		Sfx.play("boss_roar", controller.global_position)
	if player == null or not is_instance_valid(player):
		return
	if now >= _next_barrage:
		_next_barrage = now + BARRAGE_INTERVAL_SECONDS
		_barrage(parent, player)
	if now >= _next_fan:
		_next_fan = now + FAN_INTERVAL_SECONDS
		state = State.FAN_WIND
		_state_end = now + FAN_TELEGRAPH_SECONDS
		GroundTelegraph.spawn(parent, controller.global_position, controller.get_body_radius() + 40.0, FAN_TELEGRAPH_SECONDS, Color(1.0, 0.45, 0.1))
		controller.windup_started.emit()


## Where the player will be after `flight` seconds at AIM_LEAD of their velocity.
func _lead_point(player: Node2D, flight: float) -> Vector2:
	var v: Vector2 = (player as CharacterBody2D).velocity if player is CharacterBody2D else Vector2.ZERO
	return player.global_position + v * flight * AIM_LEAD


func _fire_fan() -> void:
	var player: Node2D = controller.get_player()
	if player == null:
		return
	fans_fired += 1
	var origin: Vector2 = controller.global_position
	var flight: float = origin.distance_to(player.global_position) / FAN_SPEED
	BulletPattern.emit(bullets(), origin, BulletPattern.aimed(origin, _lead_point(player, flight), FAN_COUNT, deg_to_rad(FAN_SPREAD_DEG)), FAN_SPEED, FAN_RADIUS, scaled_damage(FAN_DAMAGE), true, false, controller, BULLET_RED)
	Sfx.play("fuse", origin)


func _barrage(parent: Node, player: Node2D) -> void:
	barrages_thrown += 1
	controller.windup_started.emit()
	var center: Vector2 = _lead_point(player, BARRAGE_FLIGHT_SECONDS)
	var base_angle: float = _rng.randf() * TAU
	for i in BARRAGE_COUNT:
		var target: Vector2 = center
		if i > 0:
			var a: float = base_angle + TAU * float(i) / float(BARRAGE_COUNT - 1)
			target += Vector2.from_angle(a) * _rng.randf_range(BARRAGE_SCATTER_MIN_PX, BARRAGE_SCATTER_MAX_PX)
		var bomb: EnemyBomb = EnemyBomb.launch(parent, controller.global_position, target, BARRAGE_FLIGHT_SECONDS, BARRAGE_RADIUS_PX, scaled_damage(BARRAGE_DAMAGE), true, controller, controller.get_clock(), controller.get_registry())
		bomb.hit_tower = false # the Barrage is aimed at the player; the Siege Bomb is the Tower attack


func _begin_spiral(now: float) -> void:
	spirals += 1
	_next_spiral = now + SPIRAL_INTERVAL_SECONDS
	state = State.SPIRAL
	_state_end = now + SPIRAL_SECONDS
	_next_shot = now
	_spiral = BulletPattern.Spiral.new(SPIRAL_ARMS, deg_to_rad(SPIRAL_ROTATION_DEG), _rng.randf() * TAU)
	controller.windup_started.emit()


func _begin_storm(now: float) -> void:
	storms += 1
	_next_storm = now + STORM_INTERVAL_SECONDS
	state = State.STORM
	_storm_waves_left = STORM_WAVES
	_storm_gap = _rng.randf() * TAU
	_next_shot = now + 0.5
	var parent: Node = controller.get_parent()
	if parent != null:
		GroundTelegraph.spawn(parent, controller.global_position, controller.get_body_radius() + 80.0, 0.5, Color(1.0, 0.45, 0.1))
	request_summon("bomber", STORM_BOMBERS)
	controller.windup_started.emit()
	Sfx.play("boss_roar", controller.global_position, 10, true)

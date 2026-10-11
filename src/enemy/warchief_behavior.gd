extends BossBehavior
class_name WarchiefBehavior
## Goblin Warchief, the wave 5 boss (docs/33 §C4; Register "v1.0 Enemies,
## Bosses & Waves" > "Goblin Warchief", D340). Heads for the Tower with the
## ordinary seek/attack-slot movement and switches to the player within
## PLAYER_SWITCH_RANGE_PX. Patterns, each telegraphed and dodgeable:
##   Slam ring       1.0 s ring at his feet, 150 px; enraged it also throws a
##                   ring of orbs with two gaps.
##   Triple Charge   three lunges at the player, each behind a 0.6 s lane.
##                   A lunge into a solid obstacle stuns him (stagger 2.0 s);
##                   finishing the combo leaves him winded (stagger 1.5 s).
##   Ground Fissures 3 lanes radiating from him (one at the player), 1.0 s
##                   telegraph, then they erupt; 5 lanes when enraged.
##   Rally           summons Hunters.
## Below 50% HP he enrages: cooldowns x0.65, telegraphs x0.8, four lunges.

enum State { NORMAL, SLAM_WIND, CHARGE_WIND, CHARGING, FISSURE_WIND }

const PLAYER_SWITCH_RANGE_PX: float = 320.0
const ENRAGE_FRACTION: float = 0.5
const ENRAGE_COOLDOWN_SCALE: float = 0.65
const ENRAGE_TELEGRAPH_SCALE: float = 0.8
const SLAM_INTERVAL_SECONDS: float = 4.0
const SLAM_TELEGRAPH_SECONDS: float = 1.0
const SLAM_RADIUS_PX: float = 150.0
const SLAM_DAMAGE: float = 30.0
const SLAM_ORB_COUNT: int = 16
const SLAM_ORB_GAP_HALF_DEG: float = 24.0
const SLAM_ORB_SPEED: float = 230.0
const SLAM_ORB_RADIUS: float = 13.0
const SLAM_ORB_DAMAGE: float = 14.0
const CHARGE_INTERVAL_SECONDS: float = 11.0
const CHARGE_FIRST_DELAY_SECONDS: float = 5.0
const CHARGE_COUNT: int = 3
const CHARGE_COUNT_ENRAGED: int = 4
const CHARGE_TELEGRAPH_SECONDS: float = 0.6
const CHARGE_DISTANCE_PX: float = 460.0
const CHARGE_SPEED_SCALE: float = 3.2
const CHARGE_DAMAGE: float = 30.0
const CHARGE_LINE_WIDTH_PX: float = 70.0
const CHARGE_MIN_RANGE_PX: float = 120.0
const CHARGE_MAX_RANGE_PX: float = 720.0
const CHARGE_WALL_STUN_SECONDS: float = 2.0
const CHARGE_COMBO_STAGGER_SECONDS: float = 1.5
const FISSURE_INTERVAL_SECONDS: float = 9.0
const FISSURE_FIRST_DELAY_SECONDS: float = 9.0
const FISSURE_TELEGRAPH_SECONDS: float = 1.0
const FISSURE_COUNT: int = 3
const FISSURE_COUNT_ENRAGED: int = 5
const FISSURE_LENGTH_PX: float = 520.0
const FISSURE_WIDTH_PX: float = 56.0
const FISSURE_DAMAGE: float = 26.0
const RALLY_INTERVAL_SECONDS: float = 14.0
const RALLY_FIRST_DELAY_SECONDS: float = 8.0
const RALLY_HUNTER_COUNT: int = 6

var state: State = State.NORMAL
var _next_slam: float = -1.0
var _next_charge: float = -1.0
var _next_fissure: float = -1.0
var _next_rally: float = -1.0
var _state_end: float = 0.0
var _slam_center: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_remaining: float = 0.0
var _charges_left: int = 0
var _charge_hit_player: bool = false
var _charge_hit_tower: bool = false
var _line: LineTelegraph = null
var _fissures: Array[LineTelegraph] = []
var _fissure_lanes: Array[Vector2] = [] # directions
var _fissure_origin: Vector2 = Vector2.ZERO
var wall_stuns: int = 0
var fissures_erupted: int = 0
var charges_made: int = 0


func _init() -> void:
	boss_id = "warchief"
	display_name = "Goblin Warchief"
	phase_fractions = [ENRAGE_FRACTION]
	phase_two_fraction = ENRAGE_FRACTION
	core_reward = 8


func cooldown_scale() -> float:
	return ENRAGE_COOLDOWN_SCALE if phase >= 2 else 1.0


func _tele(seconds: float) -> float:
	return seconds * (ENRAGE_TELEGRAPH_SCALE if phase >= 2 else 1.0)


func override_target() -> Node2D:
	var player: Node2D = controller.get_player()
	if player != null and is_instance_valid(player) and player.global_position.distance_to(controller.global_position) <= PLAYER_SWITCH_RANGE_PX:
		return player
	return null


func suppress_default_attack() -> bool:
	return true


func _on_stagger_started() -> void:
	state = State.NORMAL
	_charges_left = 0
	_free_line()
	_free_fissures()


func pre_step(delta: float) -> bool:
	if _stagger_step():
		return true
	var now: float = _now()
	if _next_slam < 0.0:
		_next_slam = now + SLAM_INTERVAL_SECONDS
		_next_charge = now + CHARGE_FIRST_DELAY_SECONDS
		_next_fissure = now + FISSURE_FIRST_DELAY_SECONDS
		_next_rally = now + RALLY_FIRST_DELAY_SECONDS
	match state:
		State.SLAM_WIND:
			controller.hold_position()
			if now >= _state_end:
				_do_slam()
			return true
		State.CHARGE_WIND:
			controller.hold_position()
			if now >= _state_end:
				state = State.CHARGING
				_charge_remaining = CHARGE_DISTANCE_PX
				_charge_hit_player = false
				_charge_hit_tower = false
				_free_line()
			return true
		State.CHARGING:
			_step_charge(delta)
			return true
		State.FISSURE_WIND:
			controller.hold_position()
			if now >= _state_end:
				_erupt_fissures()
			return true
	if now >= _next_rally:
		_next_rally = now + RALLY_INTERVAL_SECONDS * cooldown_scale()
		request_summon("player_hunter", RALLY_HUNTER_COUNT)
		Sfx.play("boss_roar", controller.global_position)
	var player: Node2D = controller.get_player()
	if player != null and is_instance_valid(player):
		var d: float = player.global_position.distance_to(controller.global_position)
		if now >= _next_charge and d >= CHARGE_MIN_RANGE_PX and d <= CHARGE_MAX_RANGE_PX:
			_next_charge = now + CHARGE_INTERVAL_SECONDS * cooldown_scale()
			_charges_left = CHARGE_COUNT_ENRAGED if phase >= 2 else CHARGE_COUNT
			_begin_charge_wind(player, now)
			return true
		if now >= _next_fissure:
			_begin_fissures(player, now)
			return true
	return false


func post_step(_delta: float, in_attack_range: bool, _target: Node2D) -> void:
	var now: float = _now()
	if state == State.NORMAL and in_attack_range and now >= _next_slam:
		state = State.SLAM_WIND
		_state_end = now + _tele(SLAM_TELEGRAPH_SECONDS)
		_slam_center = controller.global_position
		var parent: Node = controller.get_parent()
		if parent != null:
			GroundTelegraph.spawn(parent, _slam_center, SLAM_RADIUS_PX, _tele(SLAM_TELEGRAPH_SECONDS))
		controller.windup_started.emit()


func _do_slam() -> void:
	state = State.NORMAL
	_next_slam = _now() + SLAM_INTERVAL_SECONDS * cooldown_scale()
	EnemyBlast.detonate(controller.get_registry(), _slam_center, SLAM_RADIUS_PX, scaled_damage(SLAM_DAMAGE), true, true, controller)
	var parent: Node = controller.get_parent()
	if parent != null:
		ExplosionFx.spawn(parent, _slam_center, SLAM_RADIUS_PX)
	if phase >= 2:
		var gap_a: float = _aim_angle()
		var gaps: Array[float] = [gap_a + PI * 0.5, gap_a - PI * 0.5]
		BulletPattern.emit(bullets(), _slam_center, BulletPattern.radial(SLAM_ORB_COUNT, gap_a, gaps, deg_to_rad(SLAM_ORB_GAP_HALF_DEG)), SLAM_ORB_SPEED, SLAM_ORB_RADIUS, scaled_damage(SLAM_ORB_DAMAGE), true, false, controller, BULLET_ORANGE)
	Sfx.play("boss_slam", _slam_center, 10, true)


func _aim_angle() -> float:
	var player: Node2D = controller.get_player()
	if player == null:
		return 0.0
	return (player.global_position - controller.global_position).angle()


func _begin_charge_wind(player: Node2D, now: float) -> void:
	state = State.CHARGE_WIND
	_charges_left -= 1
	_state_end = now + _tele(CHARGE_TELEGRAPH_SECONDS)
	_charge_dir = (player.global_position - controller.global_position).normalized()
	if _charge_dir == Vector2.ZERO:
		_charge_dir = Vector2.RIGHT
	var parent: Node = controller.get_parent()
	if parent != null:
		_free_line()
		_line = LineTelegraph.spawn(parent, controller.global_position, _charge_dir, CHARGE_DISTANCE_PX, CHARGE_LINE_WIDTH_PX, _tele(CHARGE_TELEGRAPH_SECONDS))
	controller.windup_started.emit()


func _step_charge(delta: float) -> void:
	var speed: float = controller.get_base_speed() * CHARGE_SPEED_SCALE
	controller.drive_velocity(_charge_dir * speed)
	_charge_remaining -= speed * delta
	var contact_r: float = controller.get_body_radius() + 24.0
	if not (_charge_hit_player and _charge_hit_tower):
		var res: Dictionary = EnemyBlast.detonate(controller.get_registry(), controller.global_position, contact_r, scaled_damage(CHARGE_DAMAGE), not _charge_hit_player, not _charge_hit_tower, controller)
		_charge_hit_player = _charge_hit_player or bool(res["player"])
		_charge_hit_tower = _charge_hit_tower or bool(res["tower"])
	if _hit_solid_obstacle():
		# Charged into a rock or wall: stunned, and the combo is over.
		wall_stuns += 1
		charges_made += 1
		Sfx.play("boss_slam", controller.global_position, 10, true)
		stagger(CHARGE_WALL_STUN_SECONDS)
		return
	if _charge_remaining <= 0.0:
		charges_made += 1
		var player: Node2D = controller.get_player()
		if _charges_left > 0 and player != null and is_instance_valid(player):
			_begin_charge_wind(player, _now())
		else:
			state = State.NORMAL
			stagger(CHARGE_COMBO_STAGGER_SECONDS) # winded after the combo


## True when the last move_and_slide() pushed into the World or ArenaBounds layer.
func _hit_solid_obstacle() -> bool:
	var body: CharacterBody2D = controller as CharacterBody2D
	if body == null:
		return false
	for i in body.get_slide_collision_count():
		var col: KinematicCollision2D = body.get_slide_collision(i)
		var other: Object = col.get_collider()
		if other is CollisionObject2D and ((other as CollisionObject2D).collision_layer & (CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_ARENA_BOUNDS)) != 0:
			if col.get_normal().dot(-_charge_dir) > 0.5:
				return true
	return false


func _begin_fissures(player: Node2D, now: float) -> void:
	state = State.FISSURE_WIND
	_next_fissure = now + FISSURE_INTERVAL_SECONDS * cooldown_scale()
	var dur: float = _tele(FISSURE_TELEGRAPH_SECONDS)
	_state_end = now + dur
	_fissure_origin = controller.global_position
	_free_fissures()
	_fissure_lanes.clear()
	var n: int = FISSURE_COUNT_ENRAGED if phase >= 2 else FISSURE_COUNT
	var aim: float = (player.global_position - _fissure_origin).angle()
	for i in n:
		_fissure_lanes.append(Vector2.from_angle(aim + TAU * float(i) / float(n)))
	var parent: Node = controller.get_parent()
	if parent != null:
		for dir in _fissure_lanes:
			_fissures.append(LineTelegraph.spawn(parent, _fissure_origin, dir, FISSURE_LENGTH_PX, FISSURE_WIDTH_PX, dur))
	controller.windup_started.emit()


func _erupt_fissures() -> void:
	state = State.NORMAL
	fissures_erupted += 1
	var hit_player: bool = false
	var hit_tower: bool = false
	var player: Node2D = controller.get_player()
	var tower: Node2D = controller.get_tower()
	for dir in _fissure_lanes:
		if not hit_player and player != null and LineTelegraph.lane_contains(_fissure_origin, dir, FISSURE_LENGTH_PX, FISSURE_WIDTH_PX, player.global_position, 12.0):
			hit_player = EnemyBlast.hit_target(player, scaled_damage(FISSURE_DAMAGE), controller)
		if not hit_tower and tower != null and LineTelegraph.lane_contains(_fissure_origin, dir, FISSURE_LENGTH_PX, FISSURE_WIDTH_PX, tower.global_position, 60.0):
			hit_tower = EnemyBlast.hit_target(tower, scaled_damage(FISSURE_DAMAGE), controller)
		var parent: Node = controller.get_parent()
		if parent != null:
			for k in 3:
				ExplosionFx.spawn(parent, _fissure_origin + dir * FISSURE_LENGTH_PX * (0.3 + 0.33 * float(k)), FISSURE_WIDTH_PX * 0.8)
	_free_fissures()
	Sfx.play("boss_slam", _fissure_origin, 10, true)


func on_death() -> void:
	_free_line()
	_free_fissures()
	super.on_death()


func _free_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _free_fissures() -> void:
	for f in _fissures:
		if is_instance_valid(f):
			f.queue_free()
	_fissures.clear()


func _exit_tree() -> void:
	_free_line()
	_free_fissures()

extends BossBehavior
class_name WarchiefBehavior
## Goblin Warchief (docs/31 §5.3; Register "v1.0 Enemies, Bosses & Waves" >
## "Goblin Warchief"). Heads for the Tower with the ordinary seek/attack-slot
## movement but switches to the player while the player is within 220 px.
## Attacks: Slam (1.0 s ring, 150 px, 30 dmg (WP-BALANCE, D271), every 4 s while in melee),
## Charge (0.8 s line telegraph, 520 px at 3x speed, 30 dmg on contact, every
## 9 s) and Rally (6 Hunters every 14 s). Below 40% HP it enrages: every
## cooldown x0.7.

enum State { NORMAL, SLAM_WIND, CHARGE_WIND, CHARGING }

const PLAYER_SWITCH_RANGE_PX: float = 220.0
const SLAM_INTERVAL_SECONDS: float = 4.0
const SLAM_TELEGRAPH_SECONDS: float = 1.0
const SLAM_RADIUS_PX: float = 150.0
const SLAM_DAMAGE: float = 30.0
const CHARGE_INTERVAL_SECONDS: float = 9.0
const CHARGE_TELEGRAPH_SECONDS: float = 0.8
const CHARGE_DISTANCE_PX: float = 520.0
const CHARGE_SPEED_SCALE: float = 3.0
const CHARGE_DAMAGE: float = 30.0
const CHARGE_LINE_WIDTH_PX: float = 70.0
## A charge starts only when the player is in this band, so it reads as a lunge.
const CHARGE_MIN_RANGE_PX: float = 180.0
const CHARGE_MAX_RANGE_PX: float = 640.0
const RALLY_INTERVAL_SECONDS: float = 14.0
const RALLY_HUNTER_COUNT: int = 6
const RALLY_FIRST_DELAY_SECONDS: float = 8.0
const ENRAGE_COOLDOWN_SCALE: float = 0.7
const CHARGE_FIRST_DELAY_SECONDS: float = 6.0

var state: State = State.NORMAL
var _next_slam: float = -1.0
var _next_charge: float = -1.0
var _next_rally: float = -1.0
var _state_end: float = 0.0
var _slam_center: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_remaining: float = 0.0
var _charge_hit_player: bool = false
var _charge_hit_tower: bool = false
var _line: Node2D = null


func _init() -> void:
	boss_id = "warchief"
	display_name = "Goblin Warchief"
	phase_two_fraction = 0.4
	core_reward = 8


func cooldown_scale() -> float:
	return ENRAGE_COOLDOWN_SCALE if phase >= 2 else 1.0


func override_target() -> Node2D:
	var player: Node2D = controller.get_player()
	if player != null and is_instance_valid(player) and player.global_position.distance_to(controller.global_position) <= PLAYER_SWITCH_RANGE_PX:
		return player
	return null


func suppress_default_attack() -> bool:
	return true


func pre_step(delta: float) -> bool:
	var now: float = _now()
	if _next_slam < 0.0:
		_next_slam = now + SLAM_INTERVAL_SECONDS
		_next_charge = now + CHARGE_FIRST_DELAY_SECONDS
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
	if now >= _next_rally:
		_next_rally = now + RALLY_INTERVAL_SECONDS * cooldown_scale()
		request_summon("player_hunter", RALLY_HUNTER_COUNT)
		Sfx.play("boss_roar", controller.global_position)
	if now >= _next_charge:
		var player: Node2D = controller.get_player()
		if player != null and is_instance_valid(player):
			var d: float = player.global_position.distance_to(controller.global_position)
			if d >= CHARGE_MIN_RANGE_PX and d <= CHARGE_MAX_RANGE_PX:
				_begin_charge_wind(player, now)
				return true
	return false


func post_step(_delta: float, in_attack_range: bool, _target: Node2D) -> void:
	var now: float = _now()
	if state == State.NORMAL and in_attack_range and now >= _next_slam:
		state = State.SLAM_WIND
		_state_end = now + SLAM_TELEGRAPH_SECONDS
		_slam_center = controller.global_position
		var parent: Node = controller.get_parent()
		if parent != null:
			GroundTelegraph.spawn(parent, _slam_center, SLAM_RADIUS_PX, SLAM_TELEGRAPH_SECONDS)
		controller.windup_started.emit()


func _do_slam() -> void:
	state = State.NORMAL
	_next_slam = _now() + SLAM_INTERVAL_SECONDS * cooldown_scale()
	EnemyBlast.detonate(controller.get_registry(), _slam_center, SLAM_RADIUS_PX, scaled_damage(SLAM_DAMAGE), true, true, controller)
	var parent: Node = controller.get_parent()
	if parent != null:
		ExplosionFx.spawn(parent, _slam_center, SLAM_RADIUS_PX)
	Sfx.play("boss_slam", _slam_center, 10, true)


func _begin_charge_wind(player: Node2D, now: float) -> void:
	state = State.CHARGE_WIND
	_state_end = now + CHARGE_TELEGRAPH_SECONDS
	_next_charge = now + CHARGE_INTERVAL_SECONDS * cooldown_scale()
	_charge_dir = (player.global_position - controller.global_position).normalized()
	var parent: Node = controller.get_parent()
	if parent != null:
		_line = ChargeLine.new()
		(_line as ChargeLine).setup(controller.global_position, _charge_dir, CHARGE_DISTANCE_PX, CHARGE_LINE_WIDTH_PX, CHARGE_TELEGRAPH_SECONDS)
		parent.add_child(_line)
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
	if _charge_remaining <= 0.0:
		state = State.NORMAL


func on_death() -> void:
	_free_line()
	super.on_death()


func _free_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _exit_tree() -> void:
	_free_line()


## Line telegraph for the charge: a translucent lane that fills over the wind-up.
class ChargeLine extends Node2D:
	var _from: Vector2
	var _dir: Vector2
	var _len: float
	var _width: float
	var _dur: float
	var _t0: float

	func setup(from_pos: Vector2, dir: Vector2, length: float, width: float, duration: float) -> void:
		_from = from_pos
		_dir = dir
		_len = length
		_width = width
		_dur = maxf(duration, 0.01)
		_t0 = SimClock.now

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		z_as_relative = false
		z_index = 40
		global_position = _from

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var p: float = clampf((SimClock.now - _t0) / _dur, 0.0, 1.0)
		var side: Vector2 = _dir.orthogonal() * (_width * 0.5)
		var far: Vector2 = _dir * _len
		var edge := Color(0.9, 0.15, 0.1, 0.85)
		draw_colored_polygon(PackedVector2Array([-side, side, far * p + side, far * p - side]), Color(0.9, 0.15, 0.1, 0.2 + 0.2 * p))
		draw_polyline(PackedVector2Array([-side, -side + far, side + far, side, -side]), edge, 3.0)

extends BossBehavior
class_name JuggernautBehavior
## Gutbarrel the Juggernaut, the wave 10 boss (docs/33 §C4; Register "v1.0
## Enemies, Bosses & Waves" > "Gutbarrel the Juggernaut", D340). A giant
## Barrel goblin that hunts the player (the Tower when the player is far).
## Patterns, each telegraphed and dodgeable:
##   Rolling Charge  0.8 s lane, then he rolls at 3.4x speed and bounces off
##                   walls and rocks (up to 3 bounces); winded after (1.8 s).
##   Barrel Ring     8 barrels dropped on a ring around the player; each one's
##                   ring fills for 1.5 s, then it explodes.
##   Shrapnel Burst  0.5 s charge-up, then 12 radial orbs (gaps between them);
##                   a second, offset volley when enraged.
##   Spin to Win     3 s spinning advance spraying a 2-arm spiral; dizzy after
##                   (stagger 1.5 s).
##   Stomp           0.7 s ring at his feet, then two shockwave rings of orbs,
##                   each with one wide gap.
## Below 50% HP: cooldowns x0.7, double shrapnel, 10 barrels.

enum State { NORMAL, ROLL_WIND, ROLLING, SHRAPNEL_WIND, SPINNING, STOMP_WIND, STOMP_RINGS }

const BARREL_SHEET: Texture2D = preload("res://assets/third_party/tiny_swords/Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png")
const PLAYER_HUNT_RANGE_PX: float = 700.0
const ENRAGE_FRACTION: float = 0.5
const ENRAGE_COOLDOWN_SCALE: float = 0.7
const ROLL_INTERVAL_SECONDS: float = 12.0
const ROLL_FIRST_DELAY_SECONDS: float = 8.0
const ROLL_TELEGRAPH_SECONDS: float = 0.8
const ROLL_SPEED_SCALE: float = 3.4
const ROLL_MAX_SECONDS: float = 2.6
const ROLL_MAX_BOUNCES: int = 3
const ROLL_DAMAGE: float = 34.0
const ROLL_LANE_LENGTH_PX: float = 600.0
const ROLL_LANE_WIDTH_PX: float = 96.0
const ROLL_STAGGER_SECONDS: float = 1.8
const BARREL_INTERVAL_SECONDS: float = 10.0
const BARREL_FIRST_DELAY_SECONDS: float = 5.0
const BARREL_COUNT: int = 8
const BARREL_COUNT_ENRAGED: int = 10
const BARREL_RING_RADIUS_PX: float = 190.0
const BARREL_FUSE_SECONDS: float = 1.5
const BARREL_BLAST_RADIUS_PX: float = 72.0
const BARREL_DAMAGE: float = 30.0
const SHRAPNEL_INTERVAL_SECONDS: float = 6.0
const SHRAPNEL_FIRST_DELAY_SECONDS: float = 2.5
const SHRAPNEL_TELEGRAPH_SECONDS: float = 0.5
const SHRAPNEL_COUNT: int = 12
const SHRAPNEL_SPEED: float = 260.0
const SHRAPNEL_RADIUS: float = 14.0
const SHRAPNEL_DAMAGE: float = 16.0
const SHRAPNEL_SECOND_VOLLEY_SECONDS: float = 0.35
const SPIN_INTERVAL_SECONDS: float = 15.0
const SPIN_FIRST_DELAY_SECONDS: float = 13.0
const SPIN_SECONDS: float = 3.0
const SPIN_SHOT_INTERVAL_SECONDS: float = 0.12
const SPIN_ARMS: int = 2
const SPIN_ROTATION_DEG: float = 17.0
const SPIN_SPEED_SCALE: float = 0.8
const SPIN_BULLET_SPEED: float = 200.0
const SPIN_BULLET_RADIUS: float = 12.0
const SPIN_BULLET_DAMAGE: float = 12.0
const SPIN_STAGGER_SECONDS: float = 1.5
const STOMP_INTERVAL_SECONDS: float = 8.0
const STOMP_RANGE_PX: float = 280.0
const STOMP_TELEGRAPH_SECONDS: float = 0.7
const STOMP_RADIUS_PX: float = 120.0
const STOMP_DAMAGE: float = 30.0
const STOMP_RING_COUNT: int = 2
const STOMP_RING_ORBS: int = 24
const STOMP_RING_GAP_HALF_DEG: float = 26.0
const STOMP_RING_SPACING_SECONDS: float = 0.4
const STOMP_RING_SPEED: float = 210.0
const STOMP_RING_RADIUS: float = 12.0
const STOMP_RING_DAMAGE: float = 14.0

var state: State = State.NORMAL
var _next: Dictionary = {} # pattern -> SimClock time it may start next
var _state_end: float = 0.0
var _roll_dir: Vector2 = Vector2.RIGHT
var _roll_bounces: int = 0
var _roll_hit_player: bool = false
var _roll_hit_tower: bool = false
var _line: LineTelegraph = null
var _spiral: BulletPattern.Spiral = null
var _next_shot: float = 0.0
var _rings_left: int = 0
var _pending_volley_at: float = -1.0
var _rng := RandomNumberGenerator.new()
var patterns_used: Dictionary = {} # pattern -> count, for tests and probes


func _init() -> void:
	boss_id = "juggernaut"
	display_name = "Gutbarrel the Juggernaut"
	phase_fractions = [ENRAGE_FRACTION]
	phase_two_fraction = ENRAGE_FRACTION
	core_reward = 14


func cooldown_scale() -> float:
	return ENRAGE_COOLDOWN_SCALE if phase >= 2 else 1.0


func suppress_default_attack() -> bool:
	return true


func override_target() -> Node2D:
	var player: Node2D = controller.get_player()
	if player != null and player.global_position.distance_to(controller.global_position) <= PLAYER_HUNT_RANGE_PX:
		return player
	return null


func _on_stagger_started() -> void:
	state = State.NORMAL
	_free_line()


func _mark(pattern: String) -> void:
	patterns_used[pattern] = int(patterns_used.get(pattern, 0)) + 1


func pre_step(delta: float) -> bool:
	if _stagger_step():
		return true
	var now: float = _now()
	if _next.is_empty():
		_rng.seed = int(controller.get_instance_id() % 100000)
		_next = {"roll": now + ROLL_FIRST_DELAY_SECONDS, "barrels": now + BARREL_FIRST_DELAY_SECONDS, "shrapnel": now + SHRAPNEL_FIRST_DELAY_SECONDS, "spin": now + SPIN_FIRST_DELAY_SECONDS, "stomp": now + 3.0}
	if _pending_volley_at >= 0.0 and now >= _pending_volley_at:
		_pending_volley_at = -1.0
		_shrapnel_volley(PI / float(SHRAPNEL_COUNT))
	match state:
		State.ROLL_WIND:
			controller.hold_position()
			if now >= _state_end:
				state = State.ROLLING
				_state_end = now + ROLL_MAX_SECONDS
				_roll_bounces = 0
				_roll_hit_player = false
				_roll_hit_tower = false
				_free_line()
			return true
		State.ROLLING:
			_step_roll(delta, now)
			return true
		State.SHRAPNEL_WIND:
			controller.hold_position()
			if now >= _state_end:
				state = State.NORMAL
				_shrapnel_volley(_aim_angle())
				if phase >= 2:
					_pending_volley_at = now + SHRAPNEL_SECOND_VOLLEY_SECONDS
			return true
		State.SPINNING:
			_step_spin(now)
			return true
		State.STOMP_WIND:
			controller.hold_position()
			if now >= _state_end:
				_do_stomp(now)
			return true
		State.STOMP_RINGS:
			controller.hold_position()
			if now >= _next_shot:
				_stomp_ring()
				_rings_left -= 1
				_next_shot = now + STOMP_RING_SPACING_SECONDS
				if _rings_left <= 0:
					state = State.NORMAL
			return true
	var player: Node2D = controller.get_player()
	if player == null or not is_instance_valid(player):
		return false
	var d: float = player.global_position.distance_to(controller.global_position)
	if now >= float(_next["stomp"]) and d <= STOMP_RANGE_PX:
		_begin_stomp(now)
		return true
	if now >= float(_next["roll"]):
		_begin_roll(player, now)
		return true
	if now >= float(_next["spin"]):
		_begin_spin(now)
		return true
	if now >= float(_next["barrels"]):
		_drop_barrels(player, now)
	if now >= float(_next["shrapnel"]):
		_next["shrapnel"] = now + SHRAPNEL_INTERVAL_SECONDS * cooldown_scale()
		state = State.SHRAPNEL_WIND
		_state_end = now + SHRAPNEL_TELEGRAPH_SECONDS
		var parent: Node = controller.get_parent()
		if parent != null:
			GroundTelegraph.spawn(parent, controller.global_position, controller.get_body_radius() + 60.0, SHRAPNEL_TELEGRAPH_SECONDS, Color(1.0, 0.45, 0.1))
		controller.windup_started.emit()
		return true
	return false


func _aim_angle() -> float:
	var player: Node2D = controller.get_player()
	return (player.global_position - controller.global_position).angle() if player != null else 0.0


func _begin_roll(player: Node2D, now: float) -> void:
	_mark("roll")
	_next["roll"] = now + ROLL_INTERVAL_SECONDS * cooldown_scale()
	state = State.ROLL_WIND
	_state_end = now + ROLL_TELEGRAPH_SECONDS
	_roll_dir = (player.global_position - controller.global_position).normalized()
	if _roll_dir == Vector2.ZERO:
		_roll_dir = Vector2.RIGHT
	var parent: Node = controller.get_parent()
	if parent != null:
		_free_line()
		_line = LineTelegraph.spawn(parent, controller.global_position, _roll_dir, ROLL_LANE_LENGTH_PX, ROLL_LANE_WIDTH_PX, ROLL_TELEGRAPH_SECONDS)
	controller.windup_started.emit()


func _step_roll(_delta: float, now: float) -> void:
	controller.drive_velocity(_roll_dir * controller.get_base_speed() * ROLL_SPEED_SCALE)
	var contact_r: float = controller.get_body_radius() + 20.0
	if not (_roll_hit_player and _roll_hit_tower):
		var res: Dictionary = EnemyBlast.detonate(controller.get_registry(), controller.global_position, contact_r, scaled_damage(ROLL_DAMAGE), not _roll_hit_player, not _roll_hit_tower, controller)
		_roll_hit_player = _roll_hit_player or bool(res["player"])
		_roll_hit_tower = _roll_hit_tower or bool(res["tower"])
	var normal: Vector2 = _solid_collision_normal()
	if normal != Vector2.ZERO:
		_roll_bounces += 1
		_roll_dir = _roll_dir.bounce(normal).normalized()
		_roll_hit_player = false # a bounce is a fresh pass
		Sfx.play("boss_slam", controller.global_position, 10, true)
		if _roll_bounces > ROLL_MAX_BOUNCES:
			_state_end = now
	if now >= _state_end:
		state = State.NORMAL
		stagger(ROLL_STAGGER_SECONDS)


func get_roll_bounces() -> int:
	return _roll_bounces


func _solid_collision_normal() -> Vector2:
	var body: CharacterBody2D = controller as CharacterBody2D
	if body == null:
		return Vector2.ZERO
	for i in body.get_slide_collision_count():
		var col: KinematicCollision2D = body.get_slide_collision(i)
		var other: Object = col.get_collider()
		if other is CollisionObject2D and ((other as CollisionObject2D).collision_layer & (CollisionLayers.LAYER_WORLD | CollisionLayers.LAYER_ARENA_BOUNDS)) != 0:
			return col.get_normal()
	return Vector2.ZERO


func _drop_barrels(player: Node2D, now: float) -> void:
	_mark("barrels")
	_next["barrels"] = now + BARREL_INTERVAL_SECONDS * cooldown_scale()
	var parent: Node = controller.get_parent()
	if parent == null:
		return
	var n: int = BARREL_COUNT_ENRAGED if phase >= 2 else BARREL_COUNT
	var center: Vector2 = player.global_position
	var base: float = _rng.randf() * TAU
	for i in n:
		var p: Vector2 = center + Vector2.from_angle(base + TAU * float(i) / float(n)) * BARREL_RING_RADIUS_PX
		var bomb := EnemyBomb.new()
		bomb.from_position = p
		bomb.target_position = p
		bomb.flight_seconds = BARREL_FUSE_SECONDS
		bomb.blast_radius = BARREL_BLAST_RADIUS_PX
		bomb.blast_damage = scaled_damage(BARREL_DAMAGE)
		bomb.show_dynamite = false
		bomb.attacker = controller
		bomb.clock = controller.get_clock()
		bomb.registry = controller.get_registry()
		bomb.ground_texture = BARREL_SHEET
		bomb.ground_hframes = 6
		bomb.ground_vframes = 6
		bomb.ground_scale = 0.8
		bomb.ground_modulate = Color(1.0, 0.62, 0.45)
		parent.add_child(bomb)
	controller.windup_started.emit()


func _shrapnel_volley(start_angle: float) -> void:
	_mark("shrapnel")
	BulletPattern.emit(bullets(), controller.global_position, BulletPattern.radial(SHRAPNEL_COUNT, start_angle), SHRAPNEL_SPEED, SHRAPNEL_RADIUS, scaled_damage(SHRAPNEL_DAMAGE), true, true, controller, BULLET_ORANGE)
	Sfx.play("explosion", controller.global_position)


func _begin_spin(now: float) -> void:
	_mark("spin")
	_next["spin"] = now + SPIN_INTERVAL_SECONDS * cooldown_scale()
	state = State.SPINNING
	_state_end = now + SPIN_SECONDS
	_spiral = BulletPattern.Spiral.new(SPIN_ARMS, deg_to_rad(SPIN_ROTATION_DEG), _aim_angle())
	_next_shot = now
	controller.windup_started.emit()


func _step_spin(now: float) -> void:
	var player: Node2D = controller.get_player()
	if player != null:
		controller.drive_toward(player.global_position, SPIN_SPEED_SCALE, &"player")
	else:
		controller.hold_position()
	while now >= _next_shot and now < _state_end:
		BulletPattern.emit(bullets(), controller.global_position, _spiral.next(), SPIN_BULLET_SPEED, SPIN_BULLET_RADIUS, scaled_damage(SPIN_BULLET_DAMAGE), true, true, controller, BULLET_RED)
		_next_shot += SPIN_SHOT_INTERVAL_SECONDS
	if now >= _state_end:
		state = State.NORMAL
		stagger(SPIN_STAGGER_SECONDS) # dizzy


func _begin_stomp(now: float) -> void:
	_mark("stomp")
	_next["stomp"] = now + STOMP_INTERVAL_SECONDS * cooldown_scale()
	state = State.STOMP_WIND
	_state_end = now + STOMP_TELEGRAPH_SECONDS
	var parent: Node = controller.get_parent()
	if parent != null:
		GroundTelegraph.spawn(parent, controller.global_position, STOMP_RADIUS_PX, STOMP_TELEGRAPH_SECONDS)
	controller.windup_started.emit()


func _do_stomp(now: float) -> void:
	EnemyBlast.detonate(controller.get_registry(), controller.global_position, STOMP_RADIUS_PX, scaled_damage(STOMP_DAMAGE), true, true, controller)
	var parent: Node = controller.get_parent()
	if parent != null:
		ExplosionFx.spawn(parent, controller.global_position, STOMP_RADIUS_PX)
	Sfx.play("boss_slam", controller.global_position, 10, true)
	state = State.STOMP_RINGS
	_rings_left = STOMP_RING_COUNT
	_next_shot = now


func _stomp_ring() -> void:
	var gap: float = _aim_angle() + _rng.randf_range(-0.9, 0.9)
	var gaps: Array[float] = [gap]
	BulletPattern.emit(bullets(), controller.global_position, BulletPattern.radial(STOMP_RING_ORBS, _rng.randf() * TAU, gaps, deg_to_rad(STOMP_RING_GAP_HALF_DEG)), STOMP_RING_SPEED, STOMP_RING_RADIUS, scaled_damage(STOMP_RING_DAMAGE), true, true, controller, BULLET_ORANGE)


func on_death() -> void:
	_free_line()
	super.on_death()


func _free_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _exit_tree() -> void:
	_free_line()

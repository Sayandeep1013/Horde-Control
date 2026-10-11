extends AbilityNode
class_name SacredGroundAbility
## Sacred Ground (docs/31 §4.2): an aura of radius 85-130 px around the player
## dealing 6-20 dps. At level 5 each enemy killed inside heals the player 0.5%
## of max HP.

const TICK_SECONDS: float = 0.25 # Register: Sacred Ground tick interval

var _next_tick: float = 0.0


func _ready() -> void:
	super._ready()
	z_index = 14 # a ground decal under the play layer
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)


func radius() -> float:
	return v("radius") * AbilityDamage.area_scale()


func _physics_process(_delta: float) -> void:
	global_position = owner_pos()
	var now: float = SimClock.now
	if now < _next_tick:
		return
	_next_tick = now + TICK_SECONDS
	AbilityDamage.hit_area(global_position, radius(), dmg("dps") * TICK_SECONDS, ability_id, &"player", false)


func _on_enemy_died(_entity: Node2D, position: Vector2, _timestamp: float) -> void:
	var frac: float = v("heal_fraction")
	if frac <= 0.0 or position.distance_to(global_position) > radius():
		return
	var p: Node = owner_node()
	if p != null and p.has_method("heal") and p.death_state != null:
		p.heal(p.death_state.max_hp * frac)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r: float = radius()
	var pulse: float = 0.5 + 0.5 * sin(SimClock.now * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.9, 0.5, 0.10 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(1.0, 0.88, 0.45, 0.55 + 0.2 * pulse), 3.0, false)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.25), 2.0, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

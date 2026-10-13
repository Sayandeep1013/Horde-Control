extends AbilityNode
class_name SacredGroundAbility
## Sacred Ground (docs/31 §4.2; PT-POWER D351): an aura of radius 150-230 px around the player
## dealing 14-45 dps. At level 5 each enemy killed inside heals the player 0.5%
## of max HP.

const TICK_SECONDS: float = 0.25 # Register: Sacred Ground tick interval

var _next_tick: float = 0.0
var _runner_connected: bool = false


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
	_next_tick = SimRate.reschedule(_next_tick, now, TICK_SECONDS)
	AbilityDamage.hit_area(global_position, radius(), dmg("dps") * TICK_SECONDS, ability_id, &"player", false)
	if AbilitySynergy.owns("frost_ward"): # Hallowed: the aura slows enemies inside
		for e in AbilityDamage.enemies_in_radius(global_position, radius()):
			StatusEffects.apply_slow(e, AbilitySynergy.HALLOWED_SLOW, AbilitySynergy.HALLOWED_SLOW_REFRESH_SECONDS)
	_connect_runner()


func _connect_runner() -> void:
	if _runner_connected:
		return
	var runner: Node = StatusEffects.ensure_runner()
	if runner != null and runner.has_signal("burn_victim_died"):
		runner.burn_victim_died.connect(_on_burn_victim_died)
		_runner_connected = true


## Hallowed (Flame Arrows owned): a burning enemy that dies inside the aura heals
## the player 1% of max HP.
func _on_burn_victim_died(pos: Vector2, _dps: float, _remaining: float, _source: String) -> void:
	if not AbilitySynergy.owns("flame_arrows") or pos.distance_to(global_position) > radius():
		return
	heal_player(AbilitySynergy.HALLOWED_BURN_KILL_HEAL)


func heal_player(fraction: float) -> void:
	var p: Node = owner_node()
	if p != null and p.has_method("heal") and p.death_state != null:
		p.heal(p.death_state.max_hp * fraction)


func _on_enemy_died(_entity: Node2D, position: Vector2, _timestamp: float) -> void:
	var frac: float = v("heal_fraction")
	if frac <= 0.0 or position.distance_to(global_position) > radius():
		return
	heal_player(frac)


func _process(_delta: float) -> void:
	queue_redraw()


## Readable on sand and grass: a dark-gold outline under a bright gold rim, with
## a lighter inner band, so the edge holds against both ground colours.
func _draw() -> void:
	var r: float = radius()
	var pulse: float = 0.5 + 0.5 * sin(SimClock.now * 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.92, 0.55, 0.14 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, r - 9.0, 0.0, TAU, 56, Color(1.0, 0.97, 0.75, 0.30 + 0.10 * pulse), 20.0, false) # inner band
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(0.42, 0.27, 0.04, 0.95), 11.0, false) # dark-gold outline
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(1.0, 0.86, 0.35, 0.85 + 0.15 * pulse), 6.0, false) # bright rim
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 40, Color(0.42, 0.27, 0.04, 0.45), 3.0, false)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, 0.45), 1.5, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

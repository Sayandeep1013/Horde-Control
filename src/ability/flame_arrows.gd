extends AbilityNode
class_name FlameArrowsAbility
## Flame Arrows (docs/31 §4.2): every Nth accepted arrow hit ignites the target.
## Burn refreshes rather than stacks (StatusEffects). At level 5 a burning enemy
## that dies spreads its remaining burn to the nearest enemy within 90 px.

var _hits: int = 0
var _weapon: AutoWeapon = null
var _hook: Callable
var _runner_connected: bool = false


func _ready() -> void:
	super._ready()
	_hook = Callable(self, "_on_arrow_hit")
	var p: Node2D = owner_node()
	_weapon = p.get_node_or_null("AutoWeapon") as AutoWeapon if p != null else null
	if _weapon != null and not _weapon.arrow_hit_hooks.has(_hook):
		_weapon.arrow_hit_hooks.append(_hook)


func _exit_tree() -> void:
	if _weapon != null and is_instance_valid(_weapon):
		_weapon.arrow_hit_hooks.erase(_hook)


func _on_arrow_hit(enemy: Node, _damage: float) -> void:
	if not AbilityDamage.is_enemy_alive(enemy):
		return
	_hits += 1
	if _hits >= AbilityCatalog.ivalue(ability_id, "every_n", level):
		_hits = 0
		StatusEffects.apply_burn(enemy, dmg("dps"), v("duration"), ability_id)
		Sfx.play("ignite", enemy.global_position)


func _physics_process(_delta: float) -> void:
	if _runner_connected:
		return
	var runner: Node = StatusEffects.ensure_runner()
	if runner != null and runner.has_signal("burn_victim_died"):
		runner.burn_victim_died.connect(_on_burn_victim_died)
		_runner_connected = true


func _on_burn_victim_died(pos: Vector2, dps: float, remaining: float, source_id: String) -> void:
	if level < AbilityIds.MAX_ABILITY_LEVEL or source_id != ability_id or remaining <= 0.1:
		return
	var near: Node2D = null
	var best: float = INF
	for e in AbilityDamage.enemies_in_radius(pos, v("spread_radius") * AbilityDamage.area_scale()):
		if StatusEffects.is_burning(e):
			continue
		var d: float = pos.distance_squared_to(e.global_position)
		if d < best:
			best = d
			near = e
	if near != null:
		StatusEffects.apply_burn(near, dps, remaining, ability_id, false) # already modified at the source

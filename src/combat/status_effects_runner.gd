extends Node
class_name StatusEffectsRunner
## Ticks StatusEffects' static state: burn damage, enemy sprite tints (docs/31
## §4.5: burn orange flicker, slow pale blue, freeze icy white) and pruning of
## dead or freed enemies. Created lazily by StatusEffects and parented to the
## SceneTree root; PAUSABLE so burn stops with the Draft / pause.

## Emitted once when a burning enemy dies: Flame Arrows level 5 spreads the burn.
signal burn_victim_died(position: Vector2, dps: float, remaining: float, source_id: String)

const TINT_BURN: Color = Color(1.35, 0.8, 0.45)
const TINT_SLOW: Color = Color(0.72, 0.88, 1.15)
const TINT_FREEZE: Color = Color(0.8, 1.05, 1.5)
const FLICKER_HZ: float = 7.0
const SPRITE_PATH: NodePath = NodePath("Visuals/AnimatedSprite2D")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	tick()


## Public so tests can drive it without a physics frame.
func tick() -> void:
	var now: float = SimClock.now
	var state: Dictionary = StatusEffects.get_state()
	for id in state.keys():
		var e: Dictionary = state[id]
		var enemy: Variant = e["enemy"]
		if enemy == null or not is_instance_valid(enemy):
			state.erase(id)
			continue
		var enemy_node: Node2D = enemy as Node2D
		if not AbilityDamage.is_enemy_alive(enemy_node):
			if float(e["burn_until"]) > now:
				burn_victim_died.emit(enemy_node.global_position, float(e["burn_dps"]), float(e["burn_until"]) - now, String(e["burn_source"]))
			_set_tint(enemy_node, Color.WHITE, 0)
			state.erase(id)
			StatusEffects._immunity.erase(id)
			continue
		# Pay out every burn tick that came due, including the one landing exactly at expiry.
		var burn_end: float = float(e["burn_until"])
		while float(e["burn_next"]) <= now and float(e["burn_next"]) <= burn_end + 0.0001 and float(e["burn_dps"]) > 0.0:
			AbilityDamage.hit(enemy_node, float(e["burn_dps"]) * StatusEffects.BURN_TICK_SECONDS * StatusEffects.get_burn_damage_multiplier(), String(e["burn_source"]), &"player", false)
			e["burn_next"] = float(e["burn_next"]) + StatusEffects.BURN_TICK_SECONDS
		var burning: bool = burn_end > now
		var frozen: bool = float(e["freeze_until"]) > now
		var slowed: bool = float(e["slow_until"]) > now
		if not (burning or frozen or slowed):
			_set_tint(enemy_node, Color.WHITE, 0)
			state.erase(id)
			continue
		if frozen:
			_set_tint(enemy_node, TINT_FREEZE, 3)
		elif burning:
			var flicker: float = 0.5 + 0.5 * sin(now * TAU * FLICKER_HZ)
			if GameSettings.is_reduce_flashing():
				flicker = 0.5
			_set_tint(enemy_node, Color.WHITE.lerp(TINT_BURN, 0.5 + 0.5 * flicker), 1)
		else:
			_set_tint(enemy_node, TINT_SLOW, 2)
	var immunity: Dictionary = StatusEffects._immunity
	for id in immunity.keys():
		var who: Variant = immunity[id].get("enemy")
		if who == null or not is_instance_valid(who) or not AbilityDamage.is_enemy_alive(who):
			immunity.erase(id)


## `kind` is the same tint as an id for a batch-drawn enemy (SwarmRenderer draws burn,
## slow and freeze in its shader): 0 none, 1 burn, 2 slow, 3 freeze.
static func _set_tint(enemy: Node, color: Color, kind: int = 0) -> void:
	if enemy.has_method(&"set_swarm_tint") and enemy.is_swarm_drawn():
		enemy.set_swarm_tint(kind)
		return
	var sprite: CanvasItem = enemy.get_node_or_null(SPRITE_PATH) as CanvasItem
	if sprite != null:
		sprite.self_modulate = color
